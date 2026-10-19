class_name PlayerRig
extends Node3D
## First-person seat: camera views, the pencil that follows the cursor, and every input that marks
## the paper. The rig's origin is the desk surface at the centre of the test packet.

enum View { DESK, LOOK_UP, LEAN_1, LEAN_2, STANDING }

signal ink_committed(page_key: String, op: Dictionary)
signal view_changed(view: View)

const VIEW_TIME := 0.4
const ERASE_RADIUS_PT := 6.0
const SLIDE_STEP_PT := 18.0
const FREE_LOOK_YAW := 25.0
const FREE_LOOK_PITCH := 10.0
# Camera position and look target per view, relative to the rig.
const VIEWS := {
	View.DESK: [Vector3(0.0, 0.31, 0.15), Vector3(0.0, 0.0, -0.03)],
	View.LEAN_1: [Vector3(0.0, 0.24, 0.08), Vector3(0.0, 0.0, -0.05)],
	View.LEAN_2: [Vector3(0.0, 0.17, 0.0), Vector3(0.0, 0.0, -0.09)],
	View.LOOK_UP: [Vector3(0.0, 0.43, 0.33), Vector3(0.0, 0.62, -4.0)],
	View.STANDING: [Vector3(0.0, 0.95, 0.45), Vector3(0.0, 0.85, -4.0)],
}

var packet: TestPacket
var attempt: Attempt
var doc: PdfDoc
var elapsed_provider: Callable = func() -> float: return 0.0
var input_enabled: bool = true
var edge_look := EdgeLook.new()
var font_id: StringName = &"caveat"
var typing: bool = false
var pencil_override_pt: Variant = null  # set while the hand writes a typed answer
var handwriting: HandwritingNode

var camera: Camera3D
var pencil: PencilModel
var view: View = View.DESK
var _lean: int = 0
var _space_held: bool = false
var _edge_up: bool = false
var _free_look := Vector2.ZERO
var _view_tween: Tween
var _ink := InkInput.new()
var _erasing: bool = false
var _erase_before: Dictionary = {}
var _erase_text_mode: bool = false
var _erase_key: String = ""
var _undo: Dictionary = {}  # page key -> UndoStack
var _last_mouse := Vector2.ZERO
var _mouse_seen: bool = false  # edge-look only arms after the mouse has really moved


func _ready() -> void:
	InputActions.ensure()
	camera = Camera3D.new()
	camera.fov = 55.0
	camera.near = 0.02
	add_child(camera)
	pencil = PencilModel.new()
	add_child(pencil)
	_last_mouse = get_viewport().get_visible_rect().size * Vector2(0.55, 0.6)
	_place_camera(View.DESK, 1.0)


func setup(p: TestPacket, a: Attempt, d: PdfDoc) -> void:
	packet = p
	attempt = a
	doc = d
	packet.target_changed.connect(func(_k: String) -> void: _cancel_stroke())
	handwriting = HandwritingNode.new()
	handwriting.rig = self
	add_child(handwriting)


func _process(delta: float) -> void:
	_update_mouse_mode()
	var vp_h := float(get_viewport().get_visible_rect().size.y)
	var edge := _mouse_seen and input_enabled and edge_look.update(_last_mouse.y / maxf(vp_h, 1.0), delta)
	var wants_up := _space_held or edge
	if not _space_held and _edge_up and _last_mouse.y / maxf(vp_h, 1.0) > 0.25:
		wants_up = false  # moving the cursor back down returns to the paper
	elif not _space_held and _edge_up:
		wants_up = true
	_edge_up = wants_up and not _space_held
	if wants_up and view != View.LOOK_UP and view != View.STANDING:
		set_view(View.LOOK_UP)
	elif not wants_up and view == View.LOOK_UP:
		set_view(_lean_view())
	if view == View.LOOK_UP:
		_apply_free_look()
	_update_pencil()


func _update_mouse_mode() -> void:
	var desk_like := view != View.LOOK_UP and view != View.STANDING
	var mode := Input.MOUSE_MODE_HIDDEN if (desk_like and input_enabled) else Input.MOUSE_MODE_VISIBLE
	if Input.mouse_mode != mode and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = mode


func _lean_view() -> View:
	return [View.DESK, View.LEAN_1, View.LEAN_2][_lean]


func set_view(v: View) -> void:
	if v == view:
		return
	view = v
	if v != View.LOOK_UP:
		_free_look = Vector2.ZERO
	_place_camera(v, VIEW_TIME)
	view_changed.emit(v)


func _place_camera(v: View, time: float) -> void:
	var target_xform := _view_xform(v)
	if _view_tween:
		_view_tween.kill()
	if time >= 1.0:
		camera.transform = target_xform
		return
	_view_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_view_tween.tween_property(camera, "transform", target_xform, time)


func _view_xform(v: View) -> Transform3D:
	var pair: Array = VIEWS[v]
	return Transform3D(Basis(), pair[0]).looking_at(pair[1], Vector3.UP)


func _apply_free_look() -> void:
	if _view_tween and _view_tween.is_running():
		return
	var base := _view_xform(View.LOOK_UP)
	var b := base.basis.rotated(Vector3.UP, deg_to_rad(-_free_look.x * FREE_LOOK_YAW))
	b = b * Basis(Vector3.RIGHT, deg_to_rad(-_free_look.y * FREE_LOOK_PITCH))
	camera.transform = Transform3D(b, base.origin)


# --- Input -------------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled or packet == null:
		return
	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		_last_mouse = mm.position
		_mouse_seen = true
		if view == View.LOOK_UP:
			var size := get_viewport().get_visible_rect().size
			_free_look = Vector2((mm.position.x / size.x - 0.5) * 2.0, (mm.position.y / size.y - 0.5) * 2.0).clamp(Vector2(-1, -1), Vector2(1, 1))
			return
		_on_pointer_move(mm.position, mm.pressure)
	elif event is InputEventMouseButton:
		_on_mouse_button(event as InputEventMouseButton)
	elif event is InputEventKey and event.pressed and not event.echo:
		_on_key(event as InputEventKey)
	if event.is_action("look_up") and not event.is_echo():
		_space_held = event.is_pressed()
		if _space_held:
			_cancel_stroke()
	if event.is_action("overview") and not event.is_echo():
		if event.is_pressed():
			settle_input()
		packet.set_overview(event.is_pressed())


func _on_key(k: InputEventKey) -> void:
	if typing:
		return
	if k.is_action("type_mode"):
		var p: Variant = pointer_pt()
		if p != null:
			_cancel_stroke()
			handwriting.begin_at(p)
	elif k.ctrl_pressed and k.physical_keycode == KEY_Z:
		undo()
	elif k.ctrl_pressed and k.physical_keycode == KEY_Y:
		redo()
	elif k.is_action("turn_next"):
		turn_page(1)
	elif k.is_action("turn_prev"):
		turn_page(-1)
	elif k.is_action("scratch"):
		toggle_scratch()


func _on_mouse_button(b: InputEventMouseButton) -> void:
	if b.button_index == MOUSE_BUTTON_WHEEL_UP or b.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		if not b.pressed:
			return
		var dir := 1 if b.button_index == MOUSE_BUTTON_WHEEL_UP else -1
		if b.ctrl_pressed:
			_lean = clampi(_lean + dir, 0, 2)
			if view != View.LOOK_UP:
				set_view(_lean_view())
		else:
			packet.slide(-dir * SLIDE_STEP_PT)
		return
	if view == View.LOOK_UP:
		return
	if packet.is_overview() and b.pressed and b.button_index == MOUSE_BUTTON_LEFT:
		var hit: Variant = _ray_to_plane(b.position, packet.global_position.y)
		if hit != null:
			var i := packet.overview_index_at(hit)
			if i >= 0:
				settle_input()
				packet.set_overview(false)
				packet.jump(i)
		return
	if b.button_index == MOUSE_BUTTON_LEFT and b.pressed and b.double_click:
		_ink.cancel()
		var p: Variant = _pointer_pt(b.position)
		if p != null:
			handwriting.begin_at(p)
		return
	if b.button_index == MOUSE_BUTTON_LEFT and b.pressed and b.shift_pressed:
		quick_fill(b.position)
		return
	if b.button_index == MOUSE_BUTTON_RIGHT and b.pressed and b.shift_pressed:
		quick_clear(b.position)
		return
	if b.button_index == MOUSE_BUTTON_LEFT:
		if b.pressed:
			_begin_stroke(b.position)
		else:
			_end_stroke()
	elif b.button_index == MOUSE_BUTTON_RIGHT:
		if b.pressed:
			_begin_erase(b.ctrl_pressed)
			_erase_at(b.position)
		else:
			_end_erase()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and packet:
		settle_input()


## The context is changing (page turn, scratch paper, menu, focus loss): finish whatever the hand
## is doing on the current sheet, so nothing lands on the wrong page or stays stuck down.
func settle_input() -> void:
	var s := on_focus_lost(_ink)
	if s:
		packet.active_page().ink_layer().live_stroke = null
		_commit_stroke(s)
	if _fill_tween and _fill_tween.is_running():
		_fill_tween.custom_step(10.0)
	_end_erase()
	_space_held = false
	_edge_up = false
	edge_look.reset()


func turn_page(dir: int) -> void:
	settle_input()
	packet.turn(dir)


func toggle_scratch() -> void:
	settle_input()
	packet.toggle_scratch()


## The test is ending: keep the stroke being drawn and everything typed so far.
func commit_in_progress() -> void:
	if handwriting:
		handwriting.commit_all()
	if _ink.is_active():
		var s := _ink.end()
		if packet:
			packet.active_page().ink_layer().live_stroke = null
		if s:
			_commit_stroke(s)
	if _fill_tween and _fill_tween.is_running():
		_fill_tween.custom_step(10.0)
	_end_erase()


## Alt-tabbing mid-stroke commits what was drawn instead of losing it or leaving it stuck.
static func on_focus_lost(input: InkInput) -> Stroke:
	return input.end() if input.is_active() else null


# --- Pencil ------------------------------------------------------------------------------------

func _on_pointer_move(pos: Vector2, pressure: float) -> void:
	if _ink.is_active():
		var p: Variant = _pointer_pt(pos)
		if p != null:
			_ink.move(p, _now(), pressure)
			packet.active_page().ink_layer().live_stroke = _ink.stroke
			packet.active_page().ink_layer().refresh()
	elif _erasing:
		_erase_at(pos)


func _begin_stroke(pos: Vector2) -> void:
	if packet.is_flipping():
		return
	var p: Variant = _pointer_pt(pos)
	if p == null:
		return
	_ink.begin(packet.state.active_key(), p, _now(), 1.0)


func _end_stroke() -> void:
	var s := _ink.end()
	packet.active_page().ink_layer().live_stroke = null
	if s:
		_commit_stroke(s)
	else:
		packet.active_page().ink_layer().refresh()


func _cancel_stroke() -> void:
	if _ink.is_active():
		_end_stroke()


func _commit_stroke(s: Stroke, key: String = "") -> void:
	if key == "":
		key = _ink.page_key if _ink.page_key != "" else packet.state.active_key()
	var page := attempt.ink_for(key)
	s.id = page.next_id()
	s.t_start = elapsed_provider.call()
	page.strokes.append(s)
	var op := {"kind": "add", "key": key, "after": [s.to_dict()]}
	_stack(key).push(op)
	_refresh_key(key)
	ink_committed.emit(key, op)


## Commits a stroke made elsewhere (Quick Fill) through the same undo path.
func commit_external_stroke(key: String, s: Stroke) -> void:
	_commit_stroke(s, key)


# --- Quick Fill ----------------------------------------------------------------------------------

const QUICK_FILL_TIME := 0.6
var _page_images: Dictionary = {}  # page index -> Image at 144 DPI, for bubble detection
var _fill_tween: Tween


func _bubble_rect(p: Vector2) -> Rect2:
	var key := packet.state.active_key()
	if key.begins_with("page:") and doc != null:
		var i := int(key.split(":")[1])
		if not _page_images.has(i):
			_page_images[i] = doc.render_page(i, 144.0)
		return BubbleDetector.find(doc.text_words(i), _page_images[i], 2.0, p)
	return BubbleDetector.find([], null, 2.0, p)


## Shift+click: the hand scribbles the bubble in over 0.6 s.
func quick_fill(screen: Vector2) -> void:
	var p: Variant = _pointer_pt(screen)
	if p == null:
		return
	_cancel_stroke()
	var key := packet.state.active_key()
	var s := ScribbleGen.scribble_for(_bubble_rect(p), randi())
	var layer := packet.active_page().ink_layer()
	if _fill_tween and _fill_tween.is_running():
		_fill_tween.custom_step(10.0)
	var partial := Stroke.new()
	_fill_tween = create_tween()
	_fill_tween.tween_method(func(t: float) -> void:
		var n := maxi(int(ceil(t * s.points.size())), 1)
		partial.points = s.points.slice(0, n)
		partial.widths = s.widths.slice(0, n)
		layer.live_stroke = partial
		pencil_override_pt = partial.points[n - 1]
		layer.refresh(), 0.0, 1.0, QUICK_FILL_TIME)
	_fill_tween.tween_callback(func() -> void:
		layer.live_stroke = null
		pencil_override_pt = null
		commit_external_stroke(key, s))


## Shift+right-click: clears pencil marks inside the bubble.
func quick_clear(screen: Vector2) -> void:
	var p: Variant = _pointer_pt(screen)
	if p == null:
		return
	var key := packet.state.active_key()
	var page := attempt.ink_for(key)
	var r := _bubble_rect(p).grow(1.0)
	var before := page.to_dict()
	var kept: Array[Stroke] = []
	for s in page.strokes:
		if not r.has_point(s.bounds().get_center()):
			kept.append(s)
	if kept.size() == page.strokes.size():
		return
	page.strokes = kept
	commit_page_edit(key, before)


# --- Eraser ------------------------------------------------------------------------------------

func _begin_erase(text_mode: bool) -> void:
	_cancel_stroke()
	_erasing = true
	_erase_text_mode = text_mode
	_erase_key = packet.state.active_key()
	_erase_before = attempt.ink_for(_erase_key).to_dict()
	pencil.set_eraser(true)


func _erase_at(pos: Vector2) -> void:
	var p: Variant = _pointer_pt(pos)
	if p == null:
		return
	var page := attempt.ink_for(packet.state.active_key())
	var changed := false
	if _erase_text_mode:
		changed = _erase_glyphs(page, p)
	else:
		var kept: Array[Stroke] = []
		for s in page.strokes:
			if InkGeometry.hits(s, p, ERASE_RADIUS_PT):
				changed = true
				for part in InkGeometry.erase(s, p, ERASE_RADIUS_PT):
					part.id = page.next_id()
					kept.append(part)
			else:
				kept.append(s)
		page.strokes = kept
	if changed:
		packet.active_page().ink_layer().refresh()


func _erase_glyphs(page: PageInk, p: Vector2) -> bool:
	var changed := false
	for t in page.texts:
		var glyphs := HandwritingLayout.layout_mark(t, packet.active_page().size_pt)
		var centers := PackedVector2Array()
		for g in glyphs:
			centers.append(g.center(t.size_pt))
		var hit := InkGeometry.text_hit(centers, p, ERASE_RADIUS_PT)
		if hit.is_empty():
			continue
		var chars := t.text.split("")
		for i in range(hit.size() - 1, -1, -1):
			chars.remove_at(hit[i])
		t.text = "".join(chars)
		changed = true
	page.texts = page.texts.filter(func(t: TextMark) -> bool: return t.text.strip_edges() != "")
	return changed


func _end_erase() -> void:
	if not _erasing:
		return
	_erasing = false
	pencil.set_eraser(false)
	var key := _erase_key
	var after := attempt.ink_for(key).to_dict()
	if JSON.stringify(after) != JSON.stringify(_erase_before):
		attempt.erase_count += 1
		var op := {"kind": "page", "key": key, "before": _erase_before, "after": after}
		_stack(key).push(op)
		ink_committed.emit(key, op)


## Records a whole-page edit (typed text, Quick Fill clear) for undo.
func commit_page_edit(key: String, before: Dictionary) -> void:
	var op := {"kind": "page", "key": key, "before": before, "after": attempt.ink_for(key).to_dict()}
	_stack(key).push(op)
	_refresh_key(key)
	ink_committed.emit(key, op)


# --- Undo --------------------------------------------------------------------------------------

func _stack(key: String) -> UndoStack:
	if not _undo.has(key):
		_undo[key] = UndoStack.new()
	return _undo[key]


func undo() -> void:
	var key := packet.state.active_key()
	var op := _stack(key).undo()
	if op.is_empty():
		return
	var page := attempt.ink_for(key)
	match op.kind:
		"add":
			var ids: Array = op.after.map(func(d: Dictionary) -> int: return int(d.id))
			page.strokes = page.strokes.filter(func(s: Stroke) -> bool: return not ids.has(s.id))
		"page":
			_restore(key, op.before)
	_refresh_key(key)
	ink_committed.emit(key, op)


func redo() -> void:
	var key := packet.state.active_key()
	var op := _stack(key).redo()
	if op.is_empty():
		return
	var page := attempt.ink_for(key)
	match op.kind:
		"add":
			for d in op.after:
				page.strokes.append(Stroke.from_dict(d))
		"page":
			_restore(key, op.after)
	_refresh_key(key)
	ink_committed.emit(key, op)


func _restore(key: String, d: Dictionary) -> void:
	var restored := PageInk.from_dict(d)
	var page := attempt.ink_for(key)
	page.strokes = restored.strokes
	page.texts = restored.texts


func _refresh_key(key: String) -> void:
	if key == packet.state.active_key():
		packet.active_page().show_ink(attempt.ink_for(key))


# --- Geometry ----------------------------------------------------------------------------------

func _now() -> float:
	return Time.get_ticks_usec() / 1_000_000.0


## Screen position → PDF points on the sheet in front, or null when off the paper.
func _pointer_pt(screen: Vector2) -> Variant:
	var page := packet.active_page()
	var hit: Variant = _ray_to_plane(screen, page.global_position.y)
	if hit == null:
		return null
	var p := page.local_to_pt(page.to_local(hit))
	if p.x < 0 or p.y < 0 or p.x > page.size_pt.x or p.y > page.size_pt.y:
		return null
	return p


func _ray_to_plane(screen: Vector2, y: float) -> Variant:
	var from := camera.project_ray_origin(screen)
	var dir := camera.project_ray_normal(screen)
	if absf(dir.y) < 1e-5:
		return null
	var t := (y - from.y) / dir.y
	return from + dir * t if t > 0.0 else null


func pointer_pt() -> Variant:
	return _pointer_pt(_last_mouse)


func last_mouse() -> Vector2:
	return _last_mouse


func _update_pencil() -> void:
	var desk_like := view != View.LOOK_UP and view != View.STANDING
	pencil.visible = desk_like and input_enabled and packet != null and not packet.is_overview()
	if not pencil.visible:
		return
	var page := packet.active_page()
	if pencil_override_pt != null:
		pencil.global_position = page.to_global(page.pt_to_local(pencil_override_pt)) + Vector3(0, 0.0004, 0)
		return
	var hit: Variant = _ray_to_plane(_last_mouse, page.global_position.y)
	if hit != null:
		pencil.global_position = (hit as Vector3) + Vector3(0, 0.0004, 0)
