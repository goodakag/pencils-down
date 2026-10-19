extends Node3D
## Boot scene: the empty morning classroom, softly blurred, with one paper card on top.

const TEST_SCENE := "res://scenes/flow/test_scene.tscn"

var _cam: Camera3D
var _t: float = 0.0
var _holder: CenterContainer
var _card: Control


func _ready() -> void:
	InputActions.ensure()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	add_child(GreyboxClassroom.new())
	_cam = Camera3D.new()
	_cam.fov = 60
	add_child(_cam)
	var layer := CanvasLayer.new()
	add_child(layer)
	var blur := ColorRect.new()
	blur.set_anchors_preset(Control.PRESET_FULL_RECT)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scenes/ui/blur.gdshader")
	blur.material = mat
	blur.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(blur)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = CozyTheme.get_theme()
	layer.add_child(root)
	_holder = CenterContainer.new()
	_holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(_holder)
	show_menu()


func _process(delta: float) -> void:
	# A slow drift across the room from the back corner.
	_t += delta
	var p := Vector3(2.6 + sin(_t * 0.05) * 0.8, 1.35 + sin(_t * 0.07) * 0.05, 3.4)
	_cam.position = p
	_cam.look_at(Vector3(-1.2 + sin(_t * 0.04) * 0.6, 1.2, -2.0))


func _swap(card: Control) -> void:
	if _card:
		_card.queue_free()
	_card = card
	_holder.add_child(card)
	card.modulate.a = 0.0
	create_tween().tween_property(card, "modulate:a", 1.0, 0.25)


func show_menu() -> void:
	var m := MainMenuCard.new()
	m.resume_available = Session.store.load_autosave() != null
	m.new_test.connect(show_pretest)
	m.settings.connect(show_settings)
	m.history.connect(show_history)
	m.resume_test.connect(resume)
	_swap(m)


func show_pretest() -> void:
	var p := PreTestCard.new()
	p.back.connect(show_menu)
	p.take_seat.connect(start_test)
	_swap(p)


func show_settings() -> void:
	var s := SettingsCard.new()
	s.back.connect(show_menu)
	_swap(s)


func show_history() -> void:
	var h := HistoryCard.new()
	h.back.connect(show_menu)
	h.open_attempt.connect(func(path: String) -> void:
		ReviewScreen.pending_attempt_path = path
		get_tree().change_scene_to_file("res://scenes/ui/review.tscn"))
	_swap(h)


func resume() -> void:
	pass  # Task 18


func start_test(doc: PdfDoc, options: Dictionary) -> void:
	Session.machine.abort()
	Session.machine.transition_to(SessionMachine.State.PRETEST)
	Session.begin(doc, options)
	get_tree().change_scene_to_file(TEST_SCENE)


func dev_action(name: String) -> void:
	match name:
		"pretest": show_pretest()
		"settings": show_settings()
		"history": show_history()
		"load": (_card as PreTestCard).load_pdf(ProjectSettings.globalize_path("res://tests/fixtures/mc_letter.pdf"))
		"badpdf": (_card as PreTestCard).load_pdf(ProjectSettings.globalize_path("res://tests/fixtures/encrypted.pdf"))
		"start": for b in _card.find_children("*", "Button", true, false):
			if (b as Button).text == "Take your seat":
				(b as Button).pressed.emit()
		"more": for b in _card.find_children("*", "Button", true, false):
			if (b as Button).text.ends_with("More options"):
				(b as Button).pressed.emit()
