class_name MainMenuCard
extends PanelContainer
## The first card: title and the few things you can do.

signal new_test()
signal resume_test()
signal history()
signal settings()

var resume_available: bool = false
var _notice: Label


func _ready() -> void:
	theme_type_variation = "Card"
	custom_minimum_size = Vector2(420, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
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
	box.add_child(_gap(18))
	var first := _button(box, "New test", "Primary", new_test.emit)
	if resume_available:
		_button(box, "Resume test in progress", "", resume_test.emit)
	box.add_child(_gap(4))
	_button(box, "History", "", history.emit)
	_button(box, "Settings", "", settings.emit)
	_button(box, "Quit", "", func() -> void: get_tree().quit())
	first.grab_focus.call_deferred()


func show_notice(text: String) -> void:
	_notice.text = text
	_notice.visible = true


func _button(parent: Control, text: String, variation: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT if variation == "" else HORIZONTAL_ALIGNMENT_CENTER
	if variation != "":
		b.theme_type_variation = variation
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


static func _gap(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = h
	return c
