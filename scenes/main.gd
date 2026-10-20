extends Node3D
## Boot scene: the empty morning classroom before anyone arrives, a slow camera drift through it,
## the menu down the left and whatever you open (new test, settings, history) beside it.
## "Take your seat" flies the camera to your desk before the test begins.

const TEST_SCENE := "res://scenes/flow/test_scene.tscn"
const PANEL_W := 430.0

var room: MorningClassroom
var _cam: Camera3D
var _t: float = 0.0
var _holder: CenterContainer
var _card: Control
var _menu: MainMenuCard
var _ui: Control
var _flying: bool = false


func _ready() -> void:
	InputActions.ensure()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	room = MorningClassroom.new()
	add_child(room)
	room.populate(0)
	room.apply_preset(str(Settings.get_value("graphics/preset")))
	room.wall_clock.set_time(float(Settings.get_value("test/start_minute")) * 60.0 - 600.0)
	room.wall_clock.twelve_hour = not bool(Settings.get_value("test/clock_24h"))
	room.board.set_lines("Good morning!", "Tests today. Phones away, please.")
	_cam = Camera3D.new()
	_cam.fov = 52
	add_child(_cam)
	var layer := CanvasLayer.new()
	add_child(layer)
	_ui = Control.new()
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.theme = CozyTheme.get_theme()
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_ui)
	# A soft shade behind the menu side so the room stays the subject.
	var shade := TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(0.1, 0.09, 0.08, 0.35))
	grad.set_color(1, Color(0.1, 0.09, 0.08, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_to = Vector2(1, 0)
	shade.texture = gt
	shade.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	shade.offset_right = PANEL_W + 360
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(shade)
	var right := MarginContainer.new()
	right.set_anchors_preset(Control.PRESET_FULL_RECT)
	right.add_theme_constant_override("margin_left", int(PANEL_W) + 40)
	right.add_theme_constant_override("margin_right", 40)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(right)
	_holder = CenterContainer.new()
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(_holder)
	show_menu()
	get_window().files_dropped.connect(_on_files_dropped)


func _exit_tree() -> void:
	if get_window().files_dropped.is_connected(_on_files_dropped):
		get_window().files_dropped.disconnect(_on_files_dropped)


func _process(delta: float) -> void:
	if _flying:
		return
	# A slow walk down the window side of the room, looking across the desks to the front.
	_t += delta
	var k := 0.5 + 0.5 * sin(_t * 0.035)
	_cam.position = Vector3(lerpf(-3.4, -2.6, k), 1.42 + sin(_t * 0.11) * 0.02, lerpf(3.4, 1.2, k))
	_cam.look_at(Vector3(lerpf(0.4, 1.2, k), 1.05, -3.2))


func _swap(card: Control) -> void:
	if _card:
		_card.queue_free()
	_card = card
	if card == null:
		return
	_holder.add_child(card)
	card.modulate.a = 0.0
	create_tween().tween_property(card, "modulate:a", 1.0, 0.2)


func show_menu() -> void:
	if _menu:
		_menu.queue_free()
	_menu = MainMenuCard.new()
	_menu.resume_available = Session.store.load_autosave() != null
	_menu.new_test.connect(show_pretest)
	_menu.settings.connect(show_settings)
	_menu.history.connect(show_history)
	_menu.resume_test.connect(resume)
	_menu.retake.connect(func(p: String) -> void:
		show_pretest()
		(_card as PreTestCard).load_pdf(p))
	_ui.add_child(_menu)
	_menu.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	_menu.offset_right = PANEL_W
	_swap(null)


func show_pretest() -> void:
	if _card is PreTestCard:
		return
	var p := PreTestCard.new()
	p.back.connect(func() -> void: _swap(null))
	p.take_seat.connect(start_test)
	_swap(p)


func show_settings() -> void:
	var s := SettingsCard.new()
	s.back.connect(func() -> void:
		room.apply_preset(str(Settings.get_value("graphics/preset")))
		_swap(null))
	_swap(s)


func show_history() -> void:
	var h := HistoryCard.new()
	h.back.connect(func() -> void: _swap(null))
	h.open_attempt.connect(func(path: String) -> void:
		ReviewScreen.pending_attempt_path = path
		get_tree().change_scene_to_file("res://scenes/ui/review.tscn"))
	_swap(h)


func _on_files_dropped(files: PackedStringArray) -> void:
	if _flying or _card is PreTestCard:
		return  # the pre-test card handles its own drops
	for f in files:
		if f.get_extension().to_lower() == "pdf":
			show_pretest()
			(_card as PreTestCard).load_pdf(f)
			return


func resume() -> void:
	var a := Session.store.load_autosave()
	if a and Session.resume(a):
		get_tree().change_scene_to_file(TEST_SCENE)
		return
	if Session.last_resume_error == "changed":
		_menu.show_notice("The PDF at %s has changed since this test was started, so it can't be resumed." % a.pdf_path)
	else:
		_menu.show_notice("Can't find the original PDF for the test in progress%s." % ((" at " + a.pdf_path) if a else ""))


func start_test(doc: PdfDoc, options: Dictionary) -> void:
	Session.shelve_autosave()
	Session.machine.abort()
	Session.machine.transition_to(SessionMachine.State.PRETEST)
	Session.begin(doc, options)
	_fly_to_seat()


## The camera walks over to your desk and sits down, then the test scene takes over.
func _fly_to_seat() -> void:
	_flying = true
	var seat := room.desk_surface()
	var target := seat * SeatPose.desk(0.0, Vector3.ZERO)
	var fade := ColorRect.new()
	fade.color = Color(0.06, 0.05, 0.05, 0.0)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_STOP
	_ui.add_child(fade)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(_menu, "modulate:a", 0.0, 0.35)
	if _card:
		t.tween_property(_card, "modulate:a", 0.0, 0.35)
	t.tween_property(_cam, "global_transform", target, 1.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(_cam, "fov", float(Settings.get_value("graphics/fov")), 1.7)
	t.chain().tween_property(fade, "color:a", 1.0, 0.3)
	t.chain().tween_callback(func() -> void: get_tree().change_scene_to_file(TEST_SCENE))


func dev_action(name: String) -> void:
	match name:
		"pretest": show_pretest()
		"settings": show_settings()
		"history": show_history()
		"resume": resume()
		"load": (_card as PreTestCard).load_pdf(_dev_pdf())
		"badpdf": (_card as PreTestCard).load_pdf(ProjectSettings.globalize_path("res://tests/fixtures/encrypted.pdf"))
		"start": for b in _card.find_children("*", "Button", true, false):
			if (b as Button).text == "Take your seat":
				(b as Button).pressed.emit()
		"more": for b in _card.find_children("*", "Button", true, false):
			if (b as Button).text == "Change":
				(b as Button).pressed.emit()


func _dev_pdf() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--pdf="):
			return a.trim_prefix("--pdf=")
	return ProjectSettings.globalize_path("res://tests/fixtures/mc_letter.pdf")
