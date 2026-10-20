class_name TestFlow
extends Node3D
## The test itself: settling → start bell → test (warnings) → end bell → grace → hand in.
## Expects Session.begin() (or Session.resume()) to have been called.

const SETTLE_S := 20.0
const AUTOSAVE_S := 20.0
const REVIEW_SCENE := "res://scenes/ui/review.tscn"
const BELL_START := preload("res://assets/audio/placeholder/bell_start.wav")
const BELL_END := preload("res://assets/audio/placeholder/bell_end.wav")

var room: EnvironmentContract
var packet: TestPacket
var rig: PlayerRig
var paper_dpi: float = 150.0

var _settle_left: float = 0.0
var _autosave_left: float = AUTOSAVE_S
var _facedown: PaperPage
var _facedown_tween: Tween
var _speech: Label3D
var _speech_tween: Tween
var _bell: AudioStreamPlayer
var _fade: ColorRect
var _handing_in: bool = false
var _page_time: PageTimeTracker
var _menu_holder: CenterContainer
var _menu_dim: ColorRect
var _hint: ControlsHint
var _tips: FirstRunTips


func _ready() -> void:
	room = MorningClassroom.new()
	add_child(room)
	room.apply_preset(str(Settings.get_value("graphics/preset")))
	room.populate(int(Session.options.get("class_size", 16)), hash(Session.attempt.pdf_path) % 1000)
	_build_packet()
	_build_speech()
	_bell = AudioStreamPlayer.new()
	_bell.volume_db = -4.0
	add_child(_bell)
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0.06, 0.05, 0.05, 1.0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)
	create_tween().tween_property(_fade, "color:a", 0.0, 1.2)
	var hud := CanvasLayer.new()
	hud.layer = 30
	add_child(hud)
	_hint = ControlsHint.new()
	_hint.mode = str(Settings.get_value("ui/controls"))
	hud.add_child(_hint)
	_menu_dim = ColorRect.new()
	_menu_dim.color = Color(0.1, 0.09, 0.08, 0.45)
	_menu_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu_dim.visible = false
	layer.add_child(_menu_dim)
	_menu_holder = CenterContainer.new()
	_menu_holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu_holder.theme = CozyTheme.get_theme()
	_menu_holder.visible = false
	layer.add_child(_menu_holder)

	Session.timer.warning.connect(_on_warning)
	Session.timer.test_ended.connect(_on_test_ended)
	Session.timer.grace_ended.connect(_on_grace_ended)
	Session.finishing.connect(rig.commit_in_progress)
	Session.finishing.connect(_store_page_time)
	_page_time = PageTimeTracker.new(Session.attempt.pages.size(), Session.attempt.page_time_s)
	room.wall_clock.visible = Session.options.get("clock", "wall") == "wall"
	room.board.set_lines(BoardText.format(int(Session.options.start_minute), float(Session.options.duration_s)),
		"No talking. Raise your hand if you have a question.")

	if Session.machine.state == SessionMachine.State.SETTLING:
		_settle_left = SETTLE_S
		Session.pre_roll_s = SETTLE_S
		packet.visible = false
		rig.input_enabled = false
		_slide_in_facedown()
	else:
		_settle_left = 0.0  # resumed straight into the test
		if Session.timer.phase() == ExamTimer.Phase.OVER:
			hand_in.call_deferred()  # saved after time ran out: it goes straight in
	rig.ink_committed.connect(func(_k: String, _op: Dictionary) -> void: _tip_done(0))
	packet.page_turned.connect(func(_i: int) -> void: _tip_done(1))
	rig.view_changed.connect(func(v: PlayerRig.View) -> void:
		if v == PlayerRig.View.LOOK_UP:
			_tip_done(2))


func _exit_tree() -> void:
	if Session.finishing.is_connected(rig.commit_in_progress):
		Session.finishing.disconnect(rig.commit_in_progress)
	if Session.finishing.is_connected(_store_page_time):
		Session.finishing.disconnect(_store_page_time)


func _store_page_time() -> void:
	Session.attempt.page_time_s = _page_time.totals()


func _build_packet() -> void:
	var seat := room.desk_surface()
	packet = TestPacket.new()
	packet.desk_far_edge = room.desk_far_edge
	add_child(packet)
	packet.global_transform = seat * Transform3D(Basis(Vector3.UP, deg_to_rad(2.0)), Vector3.ZERO)
	packet.setup(Session.doc, Session.attempt, paper_dpi)
	packet.page_turned.connect(func(_i: int) -> void: Session.autosave())
	rig = PlayerRig.new()
	add_child(rig)
	rig.global_transform = seat
	rig.setup(packet, Session.attempt, Session.doc)
	rig.elapsed_provider = func() -> float: return Session.timer.elapsed()
	# Looking up centres on the clock with the top of the board just below it.
	rig.look_target = room.wall_clock.global_position.lerp(room.board.global_position, 0.3)
	_apply_settings()


func _build_speech() -> void:
	_speech = Label3D.new()
	_speech.font = load("res://assets/fonts/AtkinsonHyperlegible-Regular.ttf")
	_speech.font_size = 64
	_speech.pixel_size = 0.0016
	_speech.modulate = Color("#2E2B28")
	_speech.outline_modulate = Color("#FBFAF6")
	_speech.outline_size = 28
	_speech.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_speech.no_depth_test = true
	_speech.width = 900
	_speech.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_speech.position = room.teacher_desk.global_position + Vector3(0, 1.95, 0)
	_speech.modulate.a = 0.0
	_speech.outline_modulate.a = 0.0
	add_child(_speech)


## Placeholder for Plan 4's speech bubble: the teacher's line fades in, stays, fades out.
func say(text: String) -> void:
	_speech.text = text
	if _speech_tween:
		_speech_tween.kill()
	var hold := 2.5 + 0.05 * text.split(" ").size()
	_speech_tween = create_tween()
	_speech_tween.tween_method(_set_speech_alpha, 0.0, 1.0, 0.3)
	_speech_tween.tween_interval(hold)
	_speech_tween.tween_method(_set_speech_alpha, 1.0, 0.0, 0.5)


func _set_speech_alpha(a: float) -> void:
	_speech.modulate.a = a
	_speech.outline_modulate.a = a


func _slide_in_facedown() -> void:
	_facedown = PaperPage.new()
	add_child(_facedown)
	_facedown.set_page(null, Session.doc.page_size_pt(0), 72.0)
	var target := packet.global_transform
	_facedown.global_transform = target.translated(Vector3(0.0, 0.01, -0.45))
	_facedown.visible = false
	var t := create_tween()
	_facedown_tween = t
	t.tween_interval(6.0)  # the teacher works their way down the row (Plan 3 animates them)
	t.tween_callback(func() -> void: _facedown.visible = true)
	t.tween_property(_facedown, "global_transform", target.translated(Vector3(0, 0.001, 0)), 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	room.wall_clock.set_time(Session.seconds_of_day())
	room.update_student_lod(rig.camera.global_position)
	_update_hint()
	if _menu_holder.visible:
		return  # paused (the menu is open)
	if _settle_left > 0.0:
		_settle_left -= delta
		Session.pre_roll_s = maxf(_settle_left, 0.0)
		if _settle_left <= 0.0:
			_start_test()
		return
	if Session.machine.state == SessionMachine.State.TESTING or Session.machine.state == SessionMachine.State.GRACE:
		if not Session.timer.is_paused():
			_page_time.tick(delta, packet.state.active_target())
		_autosave_left -= delta
		if _autosave_left <= 0.0:
			_autosave_left = AUTOSAVE_S
			_store_page_time()
			Session.autosave()


func _update_hint() -> void:
	var ctx := "desk"
	if _settle_left > 0.0:
		ctx = "settling"
	elif rig.typing:
		ctx = "typing"
	elif packet.is_dragging():
		ctx = "drag"
	elif packet.is_overview():
		ctx = "overview"
	elif rig.view == PlayerRig.View.LOOK_UP:
		ctx = "lookup"
	_hint.set_context(ctx, {"scratch": not Session.attempt.scratch.is_empty(),
		"hand_in_now": Session.machine.state == SessionMachine.State.GRACE})
	_hint.visible = not _menu_holder.visible and not _handing_in


func _start_tips() -> void:
	if bool(Settings.get_value("ui/tips_seen")) or _tips != null:
		return
	_tips = FirstRunTips.new()
	_hint.get_parent().add_child(_tips)
	_tips.finished.connect(func() -> void:
		Settings.set_value("ui/tips_seen", true)
		_tips = null)


func _tip_done(i: int) -> void:
	if _tips:
		_tips.done(i)


func _unhandled_input(event: InputEvent) -> void:
	if _settle_left > 0.0 and event.is_action_pressed("look_up"):
		_settle_left = 0.01  # Space skips the settling-in
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("menu") and not rig.typing:
		get_viewport().set_input_as_handled()
		if _menu_holder.visible:
			close_menu()
		else:
			open_menu()
	elif event.is_action_pressed("hand_in") and not rig.typing and not _menu_holder.visible:
		hand_in()


## Esc: Practice pauses the clock; Strict keeps it running and says so.
func open_menu() -> void:
	var st := Session.machine.state
	if not (st == SessionMachine.State.TESTING or st == SessionMachine.State.GRACE or st == SessionMachine.State.SETTLING):
		return
	rig.settle_input()
	Session.timer.pause()
	rig.input_enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_menu_dim.visible = true
	_menu_holder.visible = true
	_show_pause_card()


func _show_pause_card() -> void:
	for c in _menu_holder.get_children():
		c.queue_free()
	var card := PauseCard.new()
	card.strict = not Session.timer.pausable
	card.resume.connect(close_menu)
	card.settings.connect(func() -> void:
		for c in _menu_holder.get_children():
			c.queue_free()
		var sc := SettingsCard.new()
		sc.back.connect(func() -> void:
			_apply_settings()
			_show_pause_card())
		_menu_holder.add_child(sc))
	card.quit_test.connect(_save_and_quit)
	_menu_holder.add_child(card)


func close_menu() -> void:
	for c in _menu_holder.get_children():
		c.queue_free()
	_menu_dim.visible = false
	_menu_holder.visible = false
	Session.timer.unpause()
	rig.input_enabled = not _handing_in and _settle_left <= 0.0


func _apply_settings() -> void:
	rig.font_id = StringName(Settings.get_value("writing/font"))
	rig.edge_look.enabled = bool(Settings.get_value("input/edge_look"))
	rig.pencil.set_left_handed(Settings.get_value("writing/hand") == "left")
	rig.base_fov = float(Settings.get_value("graphics/fov"))
	rig.head_sway = bool(Settings.get_value("graphics/head_sway"))
	room.wall_clock.twelve_hour = not bool(Settings.get_value("test/clock_24h"))


func _save_and_quit() -> void:
	if _settle_left > 0.0:
		# The test hadn't started yet: nothing to keep.
		Session.machine.abort()
		get_tree().change_scene_to_file("res://scenes/main.tscn")
		return
	rig.commit_in_progress()
	_store_page_time()
	Session.timer.unpause()
	Session.autosave()
	Session.machine.abort()
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _start_test() -> void:
	_bell.stream = BELL_START
	_bell.play()
	say("You may begin.")
	if _facedown_tween and _facedown_tween.is_valid():
		_facedown_tween.kill()
	if _facedown:
		_facedown.queue_free()
		_facedown = null
	packet.visible = true
	rig.input_enabled = true
	Session.start_test()
	_start_tips()


func facedown_pending() -> bool:
	return _facedown_tween != null and _facedown_tween.is_valid() and _facedown_tween.is_running()


func _on_warning(minutes: int) -> void:
	room.board.set_note(BoardText.warning(minutes))
	say(BoardText.spoken_warning(minutes))


func _on_test_ended() -> void:
	_bell.stream = BELL_END
	_bell.play()
	say("Pencils down, please. Bring your tests up when you're done.")
	if Session.timer.phase() == ExamTimer.Phase.GRACE:
		Session.machine.transition_to(SessionMachine.State.GRACE)


func _on_grace_ended() -> void:
	if Session.timer.grace_s > 0.0:
		say("Time's up, I'll take that.")
	hand_in()


## H during the test or grace period (Plan 1: a fade instead of the walk to the front).
func hand_in() -> void:
	var st := Session.machine.state
	if _handing_in or not (st == SessionMachine.State.TESTING or st == SessionMachine.State.GRACE):
		return
	_handing_in = true
	rig.commit_in_progress()  # finishes any typing, so keys during the fade go nowhere
	rig.input_enabled = false
	Session.machine.transition_to(SessionMachine.State.HANDING_IN)
	var t := create_tween()
	t.tween_interval(0.6)
	t.tween_property(_fade, "color:a", 1.0, 1.0)
	t.tween_callback(func() -> void:
		Session.finish()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_tree().change_scene_to_file(REVIEW_SCENE))


func dev_action(name: String) -> void:
	match name:
		"skip": _settle_left = 0.01
		"lookup": rig._space_held = true
		"handin": hand_in()
		"menu": open_menu()
		"warn": _on_warning(15)
		"sample": _dev_sample_ink()


## Dev-only: fill in a few answers so the review screen has something to show.
func _dev_sample_ink() -> void:
	var page := Session.attempt.pages[0]
	for q in 4:
		var c := Vector2(100 + [1, 3, 0, 2][q] * 50, 110 + q * 66)
		var s := ScribbleGen.scribble_for(Rect2(c - Vector2(7, 7), Vector2(14, 14)), q)
		rig.commit_external_stroke("page:0", s)
	rig.handwriting.begin_at(Vector2(290, 376))
	rig.handwriting.entry.insert("x = 7 because 3(7) − 2 = 19")
	rig.handwriting.commit_all()
