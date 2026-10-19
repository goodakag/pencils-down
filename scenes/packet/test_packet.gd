class_name TestPacket
extends Node3D
## The stapled test on the desk plus loose scratch sheets. Local origin = centre of the top page;
## +Y up, top edge of the page toward -Z (away from the player).

signal page_turned(index: int)
signal target_changed(key: String)

const FLIP_TIME := 0.45
const SHEET_GAP := 0.00035
const SCRATCH_OFFSET_X := 0.255
const PACKET_ASIDE_X := -0.235
const SWAP_TIME := 0.35

var state: PacketState
var cache: PageCache
var attempt: Attempt
var paper_dpi: float = 150.0
var cache_async: bool = true

var _doc: PdfDoc
var _stack_root: Node3D          # moves with slide()
var _top: PaperPage
var _under: PaperPage
var _flipper: PaperPage
var _staple: MeshInstance3D
var _scratch_root: Node3D
var _scratch: Array[PaperPage] = []
var _overview_root: Node3D
var _overview_cells: Array[Dictionary] = []  # {rect: Rect2 (local XZ), index: int}
var _slide_m: float = 0.0
var _flip_tween: Tween
var _shown: Dictionary = {}  # PaperPage -> page index shown on it (for texture refresh)


func setup(doc: PdfDoc, a: Attempt, dpi: float) -> void:
	_doc = doc
	attempt = a
	paper_dpi = dpi
	state = PacketState.new(doc.page_count(), a.scratch.size())
	cache = PageCache.new(doc, dpi)
	cache.async = cache_async
	_build()
	_show_current()


func _build() -> void:
	_stack_root = Node3D.new()
	add_child(_stack_root)
	_under = PaperPage.new()
	_top = PaperPage.new()
	_flipper = PaperPage.new()
	for p in [_under, _top, _flipper]:
		_stack_root.add_child(p)
	_under.position.y = -SHEET_GAP
	_flipper.position.y = SHEET_GAP
	_flipper.visible = false
	_staple = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.0095, 0.0004, 0.0008)
	_staple.mesh = box
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.78, 0.78, 0.8)
	steel.metallic = 0.55
	steel.roughness = 0.35
	_staple.material_override = steel
	_stack_root.add_child(_staple)
	_scratch_root = Node3D.new()
	_scratch_root.position.x = SCRATCH_OFFSET_X
	_scratch_root.rotation.y = deg_to_rad(-4.0)
	add_child(_scratch_root)
	for i in attempt.scratch.size():
		var sp := PaperPage.new()
		_scratch_root.add_child(sp)
		sp.set_page(null, Vector2(612, 792), paper_dpi)
		sp.position.y = -i * SHEET_GAP
		sp.show_ink(attempt.scratch[i])
		_scratch.append(sp)
	_overview_root = Node3D.new()
	_overview_root.visible = false
	add_child(_overview_root)


func _exit_tree() -> void:
	if cache:
		cache.shutdown()


func _process(_delta: float) -> void:
	if cache and cache.poll():
		_refresh_textures()


func _show_current() -> void:
	var i := state.current
	_assign(_top, i)
	if i + 1 < state.page_count:
		_under.visible = true
		_assign(_under, i + 1)
	else:
		_under.visible = false
	var m := _top.size_m()
	_staple.position = Vector3(-m.x * 0.5 + 0.018, SHEET_GAP * 2.0, -m.y * 0.5 + 0.014)
	_staple.rotation.y = deg_to_rad(40.0)


func _assign(p: PaperPage, i: int) -> void:
	p.set_page(cache.texture_for(i, state.current), _doc.page_size_pt(i), paper_dpi)
	p.show_ink(attempt.pages[i])
	_shown[p] = i


func _refresh_textures() -> void:
	for p in _shown.keys():
		if (p as PaperPage).visible:
			(p as PaperPage).set_texture(cache.texture_for(_shown[p], state.current))


## +1 = next page (flips the top sheet over the staple edge), -1 = previous.
func turn(dir: int) -> bool:
	if state.showing_scratch:
		var ok := state.turn(dir)
		if ok:
			_raise_active_scratch()
			target_changed.emit(state.active_key())
		return ok
	var from := state.current
	if not state.turn(dir):
		return false
	if _flip_tween and _flip_tween.is_running():
		_flip_tween.kill()
	_flipper.visible = true
	if dir > 0:
		_assign(_flipper, from)
		_flipper.set_curl(0.0)
		_show_current()
		_flip_tween = create_tween()
		_flip_tween.tween_method(_flipper.set_curl, 0.0, 1.0, FLIP_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	else:
		_assign(_flipper, state.current)
		_flipper.set_curl(1.0)
		_flip_tween = create_tween()
		_flip_tween.tween_method(_flipper.set_curl, 1.0, 0.0, FLIP_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_flip_tween.tween_callback(_show_current)
	_flip_tween.tween_callback(func() -> void: _flipper.visible = false)
	page_turned.emit(state.current)
	target_changed.emit(state.active_key())
	return true


func jump(i: int) -> void:
	if state.jump(i):
		_show_current()
		page_turned.emit(i)
		target_changed.emit(state.active_key())


## Tab: slide the packet aside and bring scratch paper in front (or back).
func toggle_scratch() -> void:
	if attempt.scratch.is_empty():
		return
	state.toggle_scratch()
	var t := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if state.showing_scratch:
		t.tween_property(_stack_root, "position:x", PACKET_ASIDE_X, SWAP_TIME)
		t.tween_property(_scratch_root, "position", Vector3(0, SHEET_GAP * 6.0, _slide_m), SWAP_TIME)
		t.tween_property(_scratch_root, "rotation:y", 0.0, SWAP_TIME)
		_raise_active_scratch()
	else:
		t.tween_property(_stack_root, "position:x", 0.0, SWAP_TIME)
		t.tween_property(_scratch_root, "position", Vector3(SCRATCH_OFFSET_X, 0, 0), SWAP_TIME)
		t.tween_property(_scratch_root, "rotation:y", deg_to_rad(-4.0), SWAP_TIME)
	target_changed.emit(state.active_key())


func _raise_active_scratch() -> void:
	for i in _scratch.size():
		_scratch[i].position.y = SHEET_GAP if i == state.scratch_index else -i * SHEET_GAP


## Mouse wheel: the hand slides the paper up/down on the desk to reach the bottom of a page.
func slide(delta_pt: float) -> void:
	var limit := _top.size_m().y * 0.45
	_slide_m = clampf(_slide_m + delta_pt / PaperPage.PT_PER_M, -limit, limit)
	_stack_root.position.z = _slide_m
	if state.showing_scratch:
		_scratch_root.position.z = _slide_m


## Hold Q: fan the pages out in a grid. Clicking one jumps to it (see overview_index_at).
func set_overview(on: bool) -> void:
	_overview_root.visible = on
	_stack_root.visible = not on
	_scratch_root.visible = not on
	if not on:
		return
	for c in _overview_root.get_children():
		c.queue_free()
	_overview_cells.clear()
	var n := state.page_count
	var cols := mini(n, 5 if n <= 10 else 8)
	var cell := minf(0.6 / cols, 0.15)
	var rows := int(ceil(float(n) / cols))
	for i in n:
		var r := i / cols
		var c := i % cols
		var size_pt := _doc.page_size_pt(i)
		var aspect := size_pt.y / size_pt.x
		var w := cell * 0.86
		var h := w * aspect
		var center := Vector3((c - (cols - 1) * 0.5) * cell, SHEET_GAP * 4.0, (r - (rows - 1) * 0.5) * cell * 1.35)
		var q := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(w, h)
		q.mesh = plane
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = _overview_texture(i)
		mat.roughness = 0.9
		if i == state.current:
			mat.emission_enabled = true
			mat.emission = Color(0.91, 0.70, 0.23) * 0.25
		q.material_override = mat
		q.position = center
		_overview_root.add_child(q)
		_overview_cells.append({"rect": Rect2(center.x - w * 0.5, center.z - h * 0.5, w, h), "index": i})


## Thumbnail with the page's pencil marks on top, so answered pages are easy to spot.
func _overview_texture(i: int) -> Texture2D:
	var base := cache.texture_for(i, state.current)
	var ink := attempt.pages[i]
	if ink.is_empty():
		return base
	var img := base.get_image()
	img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var dpi := 72.0 * img.get_width() / _doc.page_size_pt(i).x
	var overlay := InkRasterizer.rasterize(ink, _doc.page_size_pt(i), dpi, Color(InkRasterizer.GRAPHITE, 1.0))
	overlay.resize(img.get_width(), img.get_height())
	img.blend_rect(overlay, Rect2i(Vector2i.ZERO, overlay.get_size()), Vector2i.ZERO)
	return ImageTexture.create_from_image(img)


func overview_index_at(world: Vector3) -> int:
	var l := _overview_root.to_local(world)
	for cell in _overview_cells:
		if (cell.rect as Rect2).has_point(Vector2(l.x, l.z)):
			return cell.index
	return -1


func is_overview() -> bool:
	return _overview_root.visible


## The sheet currently in front (where the pencil writes).
func active_page() -> PaperPage:
	if state.showing_scratch:
		return _scratch[state.scratch_index]
	return _top


func page_node(kind: String, index: int) -> PaperPage:
	if kind == "scratch":
		return _scratch[index] if index < _scratch.size() else null
	return _top if index == state.current else null


func is_flipping() -> bool:
	return _flip_tween != null and _flip_tween.is_running()
