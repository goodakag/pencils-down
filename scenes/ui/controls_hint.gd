class_name ControlsHint
extends MarginContainer
## The keys for what you can do right now, in a slim column on the left edge of the screen.
## It changes with the moment (writing, typing, looking up, holding a page), fades back after a
## few seconds without input so it stays out of the way, and comes back when you touch anything.
## F1 shows or hides it; Settings chooses Always / Fade / Off.

const FADE_AFTER := 8.0
const DIM := 0.28

const CONTEXTS := {
	"desk": [
		[["LMB"], "Write"],
		[["RMB"], "Erase"],
		[["Shift", "Click"], "Fill a bubble"],
		[["T"], "Type an answer"],
		[["Drag corner"], "Turn the page"],
		[["A", "D"], "Previous / next page"],
		[["Space"], "Look up at the clock"],
		[["Wheel"], "Lean in"],
		[["W", "S"], "Slide the paper"],
		[["Tab"], "Scratch paper"],
		[["Q"], "All pages"],
		[["Ctrl", "Z"], "Undo"],
		[["H"], "Hand in"],
		[["Esc"], "Menu"],
	],
	"typing": [
		[["Type"], "Your answer, in handwriting"],
		[["Enter"], "New line"],
		[["Ctrl", "[ ]"], "Smaller / bigger"],
		[["Esc"], "Done"],
	],
	"lookup": [
		[["Mouse"], "Look around"],
		[["Space"], "Release to look down"],
	],
	"drag": [
		[["Pull up"], "Turn the page"],
		[["Let go"], "Finish or drop back"],
	],
	"settling": [
		[["Space"], "Skip the wait"],
	],
	"overview": [
		[["Click"], "Go to that page"],
		[["Q"], "Release to close"],
	],
}

var mode: String = "fade"   # "always", "fade" or "off"
var _context := ""
var _list: VBoxContainer
var _idle: float = 0.0
var _hidden_by_user: bool = false
var _alpha_tween: Tween
var _extra: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_CENTER_LEFT)
	add_theme_constant_override("margin_left", 18)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.11, 0.1, 0.09, 0.52)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 14
	sb.content_margin_right = 16
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", sb)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_list)
	set_context("desk")


## `extra` can hide rows: {"scratch": false} drops the scratch-paper row, {"hand_in_now": true}
## highlights handing in after the end bell.
func set_context(c: String, extra: Dictionary = {}) -> void:
	if c == _context and extra == _extra:
		return
	var changed := c != _context
	_context = c
	_extra = extra
	for child in _list.get_children():
		_list.remove_child(child)
		child.free()
	for row in CONTEXTS.get(c, []):
		var label: String = row[1]
		if label == "Scratch paper" and not extra.get("scratch", true):
			continue
		_list.add_child(_row(row[0], label, label == "Hand in" and extra.get("hand_in_now", false)))
	if changed:
		poke()
	# Shrink to the new list and stay vertically centred on the left edge.
	_list.get_parent().reset_size()
	reset_size()
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT, Control.PRESET_MODE_MINSIZE, 18)


func context() -> String:
	return _context


func _row(keys: Array, text: String, highlight: bool) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 5)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for k in keys:
		h.add_child(_cap(k))
	var l := Label.new()
	l.text = "  " + text
	l.add_theme_font_override("font", CozyTheme.body_font())
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", CozyTheme.ACCENT if highlight else Color(0.96, 0.94, 0.9, 0.92))
	h.add_child(l)
	return h


func _cap(key: String) -> Control:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.97, 0.95, 0.9, 0.92)
	sb.border_color = Color(0.7, 0.66, 0.58)
	sb.border_width_bottom = 2
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := Label.new()
	l.text = key
	l.add_theme_font_override("font", CozyTheme.bold_font())
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", CozyTheme.INK)
	p.add_child(l)
	return p


func _process(delta: float) -> void:
	if mode == "off" or _hidden_by_user:
		visible = false
		return
	visible = true
	if mode == "always":
		modulate.a = 1.0
		return
	_idle += delta
	if _idle >= FADE_AFTER and modulate.a > DIM + 0.01 and not (_alpha_tween and _alpha_tween.is_running()):
		_fade_to(DIM, 1.2)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).physical_keycode == KEY_F1:
		_hidden_by_user = not _hidden_by_user
		poke()
		return
	if event is InputEventKey or event is InputEventMouseButton:
		poke()


## Something happened: show the keys fully again.
func poke() -> void:
	_idle = 0.0
	if modulate.a < 0.99:
		_fade_to(1.0, 0.2)


func _fade_to(a: float, t: float) -> void:
	if _alpha_tween:
		_alpha_tween.kill()
	_alpha_tween = create_tween()
	_alpha_tween.tween_property(self, "modulate:a", a, t)
