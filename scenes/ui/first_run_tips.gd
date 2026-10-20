class_name FirstRunTips
extends MarginContainer
## Three short tips the first time someone sits a test, one at a time across the top of the
## screen. Each moves on by itself (or when you do the thing it describes); then they never
## show again (Settings "ui/tips_seen").

signal finished()

const TIPS := [
	"Write with the left mouse button. Shift + click fills in a bubble.",
	"To turn the page, grab its bottom corner and pull it up, or press D.",
	"Hold Space to look up at the clock. The keys are always on the left; F1 hides them.",
]
const SHOW_S := 7.0

var _label: Label
var _index: int = -1
var _left: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_CENTER_TOP)
	add_theme_constant_override("margin_top", 28)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(CozyTheme.PAPER, 0.94)
	sb.border_color = CozyTheme.CARD_EDGE
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.shadow_color = Color(0, 0, 0, 0.25)
	sb.shadow_size = 12
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", sb)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	_label = Label.new()
	_label.add_theme_font_override("font", CozyTheme.body_font())
	_label.add_theme_font_size_override("font_size", 17)
	_label.add_theme_color_override("font_color", CozyTheme.INK)
	panel.add_child(_label)
	modulate.a = 0.0
	next()


func next() -> void:
	_index += 1
	if _index >= TIPS.size():
		var t := create_tween()
		t.tween_property(self, "modulate:a", 0.0, 0.4)
		t.tween_callback(func() -> void:
			finished.emit()
			queue_free())
		return
	_left = SHOW_S
	var t := create_tween()
	if modulate.a > 0.0:
		t.tween_property(self, "modulate:a", 0.0, 0.25)
	t.tween_callback(func() -> void:
		_label.text = TIPS[_index]
		reset_size()
		set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 28))
	t.tween_property(self, "modulate:a", 1.0, 0.35)


## The player just did what tip `i` describes.
func done(i: int) -> void:
	if i == _index and _left < SHOW_S - 1.5:
		next()


func index() -> int:
	return _index


func _process(delta: float) -> void:
	_left -= delta
	if _left <= 0.0 and _index < TIPS.size():
		next()
