class_name MainMenuCard
extends PanelContainer
## The main menu: a tall paper panel down the left of the screen with the title, the main actions
## and your recent tests (one click to sit one again). The classroom stays visible beside it.

signal new_test()
signal resume_test()
signal history()
signal settings()
signal retake(path: String)

var resume_available: bool = false
var _notice: Label


func _ready() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(CozyTheme.PAPER, 0.95)
	sb.shadow_color = Color(0, 0, 0, 0.28)
	sb.shadow_size = 28
	sb.content_margin_left = 52
	sb.content_margin_right = 44
	sb.content_margin_top = 64
	sb.content_margin_bottom = 40
	add_theme_stylebox_override("panel", sb)
	custom_minimum_size = Vector2(430, 0)
	set_anchors_preset(Control.PRESET_LEFT_WIDE)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	var title := Label.new()
	title.text = "Pencils Down"
	title.theme_type_variation = "Title"
	box.add_child(title)
	var sub := Label.new()
	sub.text = "A quiet room. A real test. The clock is running."
	sub.theme_type_variation = "Muted"
	box.add_child(sub)
	_notice = Label.new()
	_notice.theme_type_variation = "Error"
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notice.visible = false
	box.add_child(_notice)
	box.add_child(_gap(30))
	var first: Button
	if resume_available:
		first = _big(box, "Resume your test", "Primary", resume_test.emit)
		_big(box, "Start a new test", "", new_test.emit)
	else:
		first = _big(box, "Start a test", "Primary", new_test.emit)
	box.add_child(_gap(6))
	_big(box, "History", "", history.emit)
	_big(box, "Settings", "", settings.emit)
	_big(box, "Quit", "", func() -> void: get_tree().quit())

	var recent: Array = Settings.get_value("recent/pdfs")
	var existing := recent.filter(func(p: Variant) -> bool: return FileAccess.file_exists(String(p)))
	if not existing.is_empty():
		box.add_child(_gap(28))
		var mini := Label.new()
		mini.text = "SIT AGAIN"
		mini.theme_type_variation = "MiniLabel"
		box.add_child(mini)
		for p in existing.slice(0, 4):
			var b := Button.new()
			b.text = "↻  " + String(p).get_file().get_basename()
			b.tooltip_text = String(p)
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			b.add_theme_font_size_override("font_size", 16)
			b.pressed.connect(func() -> void: retake.emit(String(p)))
			box.add_child(b)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	var foot := Label.new()
	foot.text = "Tip: drop a PDF anywhere on this screen to start."
	foot.theme_type_variation = "Muted"
	foot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(foot)
	first.grab_focus.call_deferred()


func show_notice(text: String) -> void:
	_notice.text = text
	_notice.visible = true


func _big(parent: Control, text: String, variation: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size.y = 46
	b.add_theme_font_size_override("font_size", 21)
	if variation != "":
		b.theme_type_variation = variation
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


static func _gap(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = h
	return c
