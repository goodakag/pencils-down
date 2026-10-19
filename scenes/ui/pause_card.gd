class_name PauseCard
extends PanelContainer
## Esc during a test. Practice mode pauses the clock; Strict mode says so and keeps it running.

signal resume()
signal settings()
signal quit_test()

var strict: bool = false


func _ready() -> void:
	theme_type_variation = "Card"
	custom_minimum_size = Vector2(400, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	var h := Label.new()
	h.text = "Paused" if not strict else "Menu"
	h.theme_type_variation = "Heading"
	box.add_child(h)
	var line := Label.new()
	line.text = "The clock is still running." if strict else "The clock is stopped until you go back."
	line.theme_type_variation = "Error" if strict else "Muted"
	box.add_child(line)
	box.add_child(MainMenuCard._gap(10))
	var back := Button.new()
	back.text = "Back to the test"
	back.theme_type_variation = "Primary"
	back.pressed.connect(resume.emit)
	box.add_child(back)
	var s := Button.new()
	s.text = "Settings"
	s.alignment = HORIZONTAL_ALIGNMENT_LEFT
	s.pressed.connect(settings.emit)
	box.add_child(s)
	var q := Button.new()
	q.text = "Save and quit to menu"
	q.tooltip_text = "Your work is kept. Choose \"Resume test in progress\" on the main menu to continue."
	q.alignment = HORIZONTAL_ALIGNMENT_LEFT
	q.pressed.connect(quit_test.emit)
	box.add_child(q)
	back.grab_focus.call_deferred()
