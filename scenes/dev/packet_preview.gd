extends Node3D
## Dev-only preview of the test packet on a desk. Actions for DevShot: next, prev, scratch, overview.

var packet: TestPacket
var rig: PlayerRig


var room: MorningClassroom


func _ready() -> void:
	room = MorningClassroom.new()
	add_child(room)
	room.wall_clock.set_time(9 * 3600 + 12 * 60)

	var path := ProjectSettings.globalize_path("res://tests/fixtures/mc_letter.pdf")
	var doc := PdfDoc.open(path)
	var attempt := Attempt.create(doc, {"scratch_sheets": 1})
	_sample_ink(doc, attempt)
	packet = TestPacket.new()
	packet.desk_far_edge = room.desk_far_edge
	packet.cache_async = false
	add_child(packet)
	packet.global_transform = room.desk_surface() * Transform3D(Basis(Vector3.UP, deg_to_rad(2.0)), Vector3.ZERO)
	packet.setup(doc, attempt, 150.0)

	rig = PlayerRig.new()
	add_child(rig)
	rig.global_transform = room.desk_surface()
	rig.setup(packet, attempt, doc)
	rig.look_target = room.wall_clock.global_position.lerp(room.board.global_position, 0.3)
	# Park the pencil near question 1 for the screenshot.
	await get_tree().process_frame
	rig._last_mouse = rig.camera.unproject_position(packet.active_page().to_global(Vector3(0.02, 0, -0.085)))
	if OS.get_cmdline_user_args().has("--lean"):
		rig.lean_by(1.0)


func _sample_ink(doc: PdfDoc, attempt: Attempt) -> void:
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/mc_letter.json"))
	var img := doc.render_page(0, 144.0)
	var words := doc.text_words(0)
	var ink := attempt.pages[0]
	for q in [0, 1, 2]:
		var b: Dictionary = meta.bubbles[q * 4 + [1, 3, 0][q]]
		var r := BubbleDetector.find(words, img, 2.0, Vector2(b.center[0], b.center[1]))
		var s := ScribbleGen.scribble_for(r, q)
		s.id = ink.next_id()
		ink.strokes.append(s)
	var t := TextMark.new()
	t.id = ink.next_id()
	t.origin = Vector2(285, 114)
	t.size_pt = 15.0
	t.text = "x = 4, so f(4) = 11"
	t.seed = 4
	ink.texts.append(t)
	var tick := Stroke.new()
	tick.id = ink.next_id()
	for p in [Vector2(320, 300), Vector2(326, 308), Vector2(342, 286)]:
		tick.points.append(p)
		tick.widths.append(1.1)
	ink.strokes.append(tick)


func dev_action(name: String) -> void:
	match name:
		"next": packet.turn(1)
		"prev": packet.turn(-1)
		"scratch": packet.toggle_scratch()
		"overview": packet.set_overview(true)
		"lookup": rig._space_held = true
		"drag_corner": _drag(Vector2(0.1, 0.135), Vector2(0.03, -0.04))
		"drag_side": _drag(Vector2(0.105, 0.02), Vector2(-0.06, -0.08))
		"drag_left": _drag(Vector2(-0.07, 0.137), Vector2(-0.02, -0.03))
		"drag_back": _drag(Vector2(0.0, -0.3), Vector2(0.0, -0.05))
		"fill": _click_pt(Vector2(150, 7 * 0 + 80 + 4 * 66 + 30), true)
		"type": _type_at(Vector2(290, 80 + 5 * 66 + 34), "x = 7 because 3(7) - 2 = 19")
		"eraser": rig.pencil.set_eraser(true)


## Takes hold of the sheet at packet-plane point `from` and holds it at `to` (no release).
func _drag(from: Vector2, to: Vector2) -> void:
	if not packet.begin_drag(from):
		push_warning("nothing to grab at %s" % from)
		return
	for i in 12:
		packet.drag_to(from.lerp(to, (i + 1) / 12.0), 1.0 / 60.0)


func _screen_of(pt: Vector2) -> Vector2:
	var page := packet.active_page()
	return rig.camera.unproject_position(page.to_global(page.pt_to_local(pt)))


func _click_pt(pt: Vector2, shift: bool) -> void:
	var pos := _screen_of(pt)
	var m := InputEventMouseMotion.new()
	m.position = pos
	get_viewport().push_input(m, true)
	for pressed in [true, false]:
		var b := InputEventMouseButton.new()
		b.button_index = MOUSE_BUTTON_LEFT
		b.position = pos
		b.pressed = pressed
		b.shift_pressed = shift
		get_viewport().push_input(b, true)


func _type_at(pt: Vector2, text: String) -> void:
	var m := InputEventMouseMotion.new()
	m.position = _screen_of(pt)
	get_viewport().push_input(m, true)
	_key(KEY_T, 0)
	for ch in text:
		_key(KEY_NONE, ch.unicode_at(0))


func _key(code: Key, uni: int) -> void:
	var k := InputEventKey.new()
	k.pressed = true
	k.physical_keycode = code
	k.keycode = code
	k.unicode = uni
	get_viewport().push_input(k)
