extends Node3D
## Dev-only preview of the test packet on a desk. Actions for DevShot: next, prev, scratch, overview.

var packet: TestPacket
var rig: PlayerRig


func _ready() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.55, 0.52, 0.47)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.78, 0.82, 0.9)
	e.ambient_light_energy = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_AGX
	e.tonemap_exposure = 1.35
	e.ssao_enabled = true
	env.environment = e
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.86, 0.68)
	sun.light_energy = 2.2
	sun.shadow_enabled = true
	sun.rotation = Vector3(deg_to_rad(-32), deg_to_rad(-70), 0)
	sun.shadow_blur = 1.5
	sun.shadow_bias = 0.03
	sun.shadow_normal_bias = 1.5
	sun.directional_shadow_max_distance = 3.0
	add_child(sun)

	var desk := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.76, 0.02, 0.56)
	desk.mesh = box
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color("#C9A57A")
	wood.roughness = 0.55
	desk.material_override = wood
	desk.position.y = -0.0105
	add_child(desk)

	var path := ProjectSettings.globalize_path("res://tests/fixtures/mc_letter.pdf")
	var doc := PdfDoc.open(path)
	var attempt := Attempt.create(doc, {"scratch_sheets": 1})
	_sample_ink(doc, attempt)
	packet = TestPacket.new()
	packet.cache_async = false
	add_child(packet)
	packet.rotation.y = deg_to_rad(2.0)
	packet.setup(doc, attempt, 150.0)

	rig = PlayerRig.new()
	add_child(rig)
	rig.setup(packet, attempt, doc)
	# Park the pencil near question 1 for the screenshot.
	await get_tree().process_frame
	rig._last_mouse = rig.camera.unproject_position(packet.active_page().to_global(Vector3(0.02, 0, -0.085)))
	if OS.get_cmdline_user_args().has("--lean"):
		rig._lean = 2
		rig.set_view(PlayerRig.View.LEAN_2)


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
		"lookup": rig.set_view(PlayerRig.View.LOOK_UP)
		"eraser": rig.pencil.set_eraser(true)
