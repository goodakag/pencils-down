class_name ChipRow
extends HFlowContainer
## A row of pill chips where exactly one is selected.

signal selected(value: Variant)

var _group := ButtonGroup.new()
var _values: Array = []


func _init(labels: Array, values: Array, current: Variant) -> void:
	add_theme_constant_override("h_separation", 8)
	add_theme_constant_override("v_separation", 8)
	_values = values
	for i in labels.size():
		var b := Button.new()
		b.text = labels[i]
		b.theme_type_variation = "Chip"
		b.toggle_mode = true
		b.button_group = _group
		b.focus_mode = Control.FOCUS_ALL
		b.button_pressed = _same(values[i], current)
		b.pressed.connect(func() -> void: selected.emit(values[i]))
		add_child(b)


func select(value: Variant) -> void:
	for i in _values.size():
		(get_child(i) as Button).set_pressed_no_signal(_same(_values[i], value))


static func _same(a: Variant, b: Variant) -> bool:
	if (a is float or a is int) and (b is float or b is int):
		return is_equal_approx(float(a), float(b))
	return a == b
