class_name TestPacket
extends Node3D
## The stapled test on the desk, with scratch paper tucked underneath. Local origin = centre of the
## packet on the desk; +Y up, the stapled top edge toward -Z (away from the player).
##
## Pages are turned by hand: grab the bottom or right edge of the top sheet and pull it up and over
## the top edge (PageCurl does the bending). Turned pages stay folded back over the top, so dragging
## that fold down turns back. A / D play the same motion.

signal page_turned(index: int)
signal target_changed(key: String)

enum Grab { NONE, FORWARD, BACK }

const FLIP_TIME := 0.5
const SETTLE_TIME := 0.28
const SHEET_T := 0.00011        # one sheet of 20 lb paper
const SHEET_GAP := 0.00035
const EDGE_BAND := 0.065        # fraction of the page near the bottom/right edges that grabs it
const PACKET_ASIDE := Vector3(-0.2, 0.0, -0.01)
const SCRATCH_REST := Vector3(0.012, -0.0008, 0.016)
const SWAP_TIME := 0.35

var state: PacketState
var cache: PageCache
var attempt: Attempt
var paper_dpi: float = 150.0
var cache_async: bool = true
var desk_far_edge: float = -0.32  # packet-local z where the desk ends (set from the room)

var _doc: PdfDoc
var _stack_root: Node3D          # moves with slide()
var _top: PaperPage
var _under: PaperPage
var _flipper: PaperPage
var _turned: PaperPage           # the last turned page, folded back over the top
var _body: MeshInstance3D        # edge thickness of the pages underneath
var _staple: Node3D
var _scratch_root: Node3D
var _scratch: Array[PaperPage] = []
var _overview_root: Node3D
var _overview_cells: Array[Dictionary] = []  # {rect: Rect2 (local XZ), index: int}
var _slide_m: float = 0.0
var _flip_tween: Tween
var _shown: Dictionary = {}  # PaperPage -> page index shown on it (for texture refresh)
var _grab: Grab = Grab.NONE
var _grab_at := Vector2.ZERO
var _drag_last := Vector2.ZERO
var _drag_speed: float = 0.0   # toward the top edge, m/s (smoothed)
var _hover: float = 0.0
var _hover_tween: Tween


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
	_body = MeshInstance3D.new()
	_body.mesh = BoxMesh.new()
	var edge := StandardMaterial3D.new()
	edge.albedo_color = Color(0.93, 0.925, 0.9)
	edge.roughness = 0.95
	_body.material_override = edge
	_stack_root.add_child(_body)
	_under = PaperPage.new()
	_top = PaperPage.new()
	_flipper = PaperPage.new()
	_turned = PaperPage.new()
	for p in [_under, _top, _turned, _flipper]:
		_stack_root.add_child(p)
	_flipper.visible = false
	_turned.visible = false
	_build_staple()
	_scratch_root = Node3D.new()
	_scratch_root.position = SCRATCH_REST
	_scratch_root.rotation.y = deg_to_rad(-2.5)
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


## A real staple: a 12.7 mm crown of 0.5 mm wire, its legs folded under the packet.
func _build_staple() -> void:
	_staple = Node3D.new()
	_stack_root.add_child(_staple)
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.8, 0.8, 0.82)
	steel.metallic = 0.9
	steel.roughness = 0.28
	var crown := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.00028
	cap.height = 0.0127
	cap.radial_segments = 8
	cap.rings = 2
	crown.mesh = cap
	crown.rotation.z = PI / 2
	crown.material_override = steel
	_staple.add_child(crown)
	for s in [-1.0, 1.0]:
		var leg := MeshInstance3D.new()
		var lc := CapsuleMesh.new()
		lc.radius = 0.00026
		lc.height = 0.0016
		leg.mesh = lc
		leg.position = Vector3(s * 0.0062, -0.0006, 0)
		leg.material_override = steel
		_staple.add_child(leg)


func _exit_tree() -> void:
	if cache:
		cache.shutdown()


func _process(_delta: float) -> void:
	if cache and cache.poll():
		_refresh_textures()


func _page_size_m(i: int) -> Vector2:
	return _doc.page_size_pt(i) / PaperPage.PT_PER_M


func _show_current() -> void:
	var i := state.current
	var below := state.page_count - i - 1
	var base := maxf(below * SHEET_T, SHEET_GAP)
	_assign(_top, i)
	_top.position.y = base
	_top.set_fold(PageCurl.flat(_top.size_m()))
	_flipper.position.y = base + SHEET_GAP
	if i + 1 < state.page_count:
		_under.visible = true
		_assign(_under, i + 1)
		_under.position.y = base - SHEET_GAP * 0.5
	else:
		_under.visible = false
	var m := _top.size_m()
	_body.visible = below > 1
	(_body.mesh as BoxMesh).size = Vector3(m.x - 0.0006, maxf(base - SHEET_GAP, 0.0001), m.y - 0.0006)
	_body.position.y = (base - SHEET_GAP) * 0.5
	_set_turned(i - 1)
	_staple.position = Vector3(-m.x * 0.5 + 0.011, base + SHEET_GAP * 2.0 + 0.0002, -m.y * 0.5 + 0.011)
	_staple.rotation.y = deg_to_rad(45.0)


## The page folded back over the top edge (index < 0: none).
func _set_turned(i: int) -> void:
	_turned.visible = i >= 0 and not is_overview()
	if i < 0:
		_shown.erase(_turned)
		return
	_assign(_turned, i)
	_turned.position.y = _top.position.y + SHEET_GAP
	_turned.set_fold(PageCurl.turned(_turned.size_m()))


func _assign(p: PaperPage, i: int) -> void:
	p.set_page(cache.texture_for(i, state.current), _doc.page_size_pt(i), paper_dpi)
	p.set_drape(desk_far_edge - _stack_root.position.z)
	p.show_ink(attempt.pages[i])
	_shown[p] = i


func _refresh_textures() -> void:
	for p in _shown.keys():
		if (p as PaperPage).visible:
			(p as PaperPage).set_texture(cache.texture_for(_shown[p], state.current))


# --- Turning by hand ---------------------------------------------------------------------------

## What grabbing at `local` (packet-plane x, z) would do.
func grab_kind(local: Vector2) -> Grab:
	if state.showing_scratch or is_overview() or is_flipping():
		return Grab.NONE
	var p := local - Vector2(_stack_root.position.x, _stack_root.position.z)
	var m := _top.size_m()
	var inside := absf(p.x) <= m.x * 0.5 + 0.004 and absf(p.y) <= m.y * 0.5 + 0.004
	if inside:
		var band := EDGE_BAND * minf(m.x, m.y)
		var near_bottom := p.y > m.y * 0.5 - band
		var near_right := p.x > m.x * 0.5 - band
		if (near_bottom or near_right) and state.current + 1 < state.page_count:
			return Grab.FORWARD
		return Grab.NONE
	# The folded-back pages beyond the top edge.
	if state.current > 0 and absf(p.x) <= m.x * 0.5 and p.y < -m.y * 0.5 and p.y > -m.y * 0.5 - m.y * 1.05:
		return Grab.BACK
	return Grab.NONE


func begin_drag(local: Vector2) -> bool:
	var kind := grab_kind(local)
	if kind == Grab.NONE:
		return false
	var p := local - Vector2(_stack_root.position.x, _stack_root.position.z)
	_kill_flip()
	_grab = kind
	_grab_at = p
	_drag_last = p
	_drag_speed = 0.0
	set_hover(false)
	_flipper.visible = true
	if kind == Grab.FORWARD:
		_assign(_flipper, state.current)
		_flipper.set_fold(PageCurl.flat(_flipper.size_m()))
		_reveal_under(state.current + 1)
	else:
		_assign(_flipper, state.current - 1)
		_flipper.set_fold(PageCurl.turned(_flipper.size_m()))
		_set_turned(state.current - 2)
	return true


func drag_to(local: Vector2, delta: float) -> void:
	if _grab == Grab.NONE:
		return
	var p := local - Vector2(_stack_root.position.x, _stack_root.position.z)
	if delta > 0.0:
		var v := (_drag_last.y - p.y) / delta  # toward the top edge is positive
		_drag_speed = lerpf(_drag_speed, v, clampf(delta * 12.0, 0.0, 1.0))
	_drag_last = p
	var size := _flipper.size_m()
	if _grab == Grab.FORWARD:
		_flipper.set_fold(PageCurl.from_drag(size, _grab_at, p))
	else:
		_flipper.set_fold(PageCurl.unturn_drag(size, p, clampf(_grab_at.x, -size.x * 0.45, size.x * 0.45)))


## Let go: finish the turn or let the sheet fall back.
func end_drag() -> void:
	if _grab == Grab.NONE:
		return
	var kind := _grab
	_grab = Grab.NONE
	var curl := _flipper.fold
	var size := _flipper.size_m()
	if kind == Grab.FORWARD:
		var done := PageCurl.should_complete(curl.progress(), _drag_speed)
		_settle(curl, PageCurl.turned(size) if done else PageCurl.flat(size), func() -> void:
			_finish(1 if done else 0))
	else:
		var done := PageCurl.should_complete(1.0 - curl.progress(), -_drag_speed)
		_settle(curl, PageCurl.flat(size) if done else PageCurl.turned(size), func() -> void:
			_finish(-1 if done else 0))


func is_dragging() -> bool:
	return _grab != Grab.NONE


## Hovering a grabbable edge: the corner lifts a little so it looks like it can be taken.
func set_hover(on: bool) -> void:
	var target := 1.0 if on else 0.0
	if is_equal_approx(_hover, target):
		return
	_hover = target
	if _hover_tween:
		_hover_tween.kill()
	_hover_tween = create_tween()
	_hover_tween.tween_method(_top.set_lift, _top.get_lift(), target, 0.18)


func _reveal_under(i: int) -> void:
	_assign(_top, i)
	_top.set_fold(PageCurl.flat(_top.size_m()))
	if i + 1 < state.page_count:
		_assign(_under, i + 1)
		_under.visible = true
	else:
		_under.visible = false


func _settle(from: PageCurl, to: PageCurl, done: Callable) -> void:
	_kill_flip()
	_flip_tween = create_tween()
	var t := SETTLE_TIME * clampf(absf(to.progress() - from.progress()) * 2.0, 0.35, 1.0)
	_flip_tween.tween_method(func(u: float) -> void: _flipper.set_fold(from.lerped(to, u)), 0.0, 1.0, t) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_flip_tween.tween_callback(done)


func _finish(dir: int) -> void:
	_flipper.visible = false
	_shown.erase(_flipper)
	if dir != 0 and state.turn(dir):
		_show_current()
		page_turned.emit(state.current)
		target_changed.emit(state.active_key())
	else:
		_show_current()


func _kill_flip() -> void:
	if _flip_tween and _flip_tween.is_running():
		_flip_tween.custom_step(10.0)  # finish the previous turn instantly
	_flip_tween = null


## A / D: the same hand motion from the bottom-right corner. Returns false at either end.
func turn(dir: int) -> bool:
	if state.showing_scratch:
		var ok := state.turn(dir)
		if ok:
			_raise_active_scratch()
			target_changed.emit(state.active_key())
		return ok
	if _grab != Grab.NONE:
		return false
	_kill_flip()
	if (dir > 0 and state.current + 1 >= state.page_count) or (dir < 0 and state.current == 0):
		return false
	var size := _top.size_m()
	var corner := Vector2(size.x * 0.42, size.y * 0.5)
	var past_top := Vector2(-size.x * 0.12, -size.y * 1.55)
	_flipper.visible = true
	if dir > 0:
		_assign(_flipper, state.current)
		_reveal_under(state.current + 1)
	else:
		_assign(_flipper, state.current - 1)
		_set_turned(state.current - 2)
	var turned := PageCurl.turned(size)
	var flat := PageCurl.flat(size)
	_flip_tween = create_tween()
	_flip_tween.tween_method(func(u: float) -> void:
		var k := u if dir > 0 else 1.0 - u
		var hand := corner.lerp(past_top, k)
		var c := PageCurl.from_drag(size, corner, hand)
		c = c.lerped(turned, smoothstep(0.65, 1.0, k))
		c = c.lerped(flat, 1.0 - smoothstep(0.0, 0.06, k))
		_flipper.set_fold(c), 0.0, 1.0, FLIP_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_flip_tween.tween_callback(func() -> void: _finish(dir))
	return true


func jump(i: int) -> void:
	_kill_flip()
	if state.jump(i):
		_show_current()
		page_turned.emit(i)
		target_changed.emit(state.active_key())


# --- Scratch paper -------------------------------------------------------------------------------

## Tab: the scratch sheet slides out from under the test onto the top (or back under).
func toggle_scratch() -> void:
	if attempt.scratch.is_empty():
		return
	_kill_flip()
	if _grab != Grab.NONE:
		end_drag()
	state.toggle_scratch()
	var t := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if state.showing_scratch:
		t.tween_property(_stack_root, "position", PACKET_ASIDE + Vector3(0, 0, _slide_m), SWAP_TIME)
		t.tween_property(_scratch_root, "position", Vector3(0.045, _top.position.y + SHEET_GAP * 6.0, _slide_m), SWAP_TIME)
		t.tween_property(_scratch_root, "rotation:y", deg_to_rad(1.5), SWAP_TIME)
		_raise_active_scratch()
	else:
		t.tween_property(_stack_root, "position", Vector3(0, 0, _slide_m), SWAP_TIME)
		t.tween_property(_scratch_root, "position", SCRATCH_REST + Vector3(0, 0, _slide_m), SWAP_TIME)
		t.tween_property(_scratch_root, "rotation:y", deg_to_rad(-2.5), SWAP_TIME)
	target_changed.emit(state.active_key())


func _raise_active_scratch() -> void:
	for i in _scratch.size():
		_scratch[i].position.y = SHEET_GAP if i == state.scratch_index else -i * SHEET_GAP


## W / S: the hand slides the paper up/down on the desk to reach the bottom of a page.
func slide(delta_pt: float) -> void:
	var limit := _top.size_m().y * 0.42
	_slide_m = clampf(_slide_m + delta_pt / PaperPage.PT_PER_M, -limit * 0.6, limit)
	_stack_root.position.z = _slide_m
	for pg in [_turned, _flipper]:
		(pg as PaperPage).set_drape(desk_far_edge - _slide_m)
	_scratch_root.position.z = (SCRATCH_REST.z if not state.showing_scratch else 0.0) + _slide_m


# --- Overview ----------------------------------------------------------------------------------

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
	return _overview_root != null and _overview_root.visible


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
	return _grab != Grab.NONE or (_flip_tween != null and _flip_tween.is_running())


## Packet-plane coordinates (x, z) of a world point, for grabbing pages.
func plane_point(world: Vector3) -> Vector2:
	var l := to_local(world)
	return Vector2(l.x, l.z)
