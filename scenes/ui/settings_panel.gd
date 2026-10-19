class_name SettingsCard
extends PanelContainer
## Plan 1 settings: writing hand, handwriting font, mouse sensitivity, edge look. Saved on change.
## Plan 4 turns this into the full manila-folder settings with tabs.

signal back()

const FONT_NAMES := {&"caveat": "Caveat", &"kalam": "Kalam", &"patrick_hand": "Patrick Hand", &"shadows": "Shadows Into Light", &"indie_flower": "Indie Flower"}

var _preview: Label


func _ready() -> void:
	theme_type_variation = "Card"
	custom_minimum_size = Vector2(560, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	var head := HBoxContainer.new()
	box.add_child(head)
	var h := Label.new()
	h.text = "Settings"
	h.theme_type_variation = "Heading"
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(h)
	var back_btn := Button.new()
	back_btn.text = "Back"
	back_btn.theme_type_variation = "Link"
	back_btn.pressed.connect(back.emit)
	head.add_child(back_btn)

	box.add_child(_mini("Writing hand"))
	var hand := ChipRow.new(["Right", "Left"], ["right", "left"], Settings.get_value("writing/hand"))
	hand.selected.connect(func(v: Variant) -> void: Settings.set_value("writing/hand", v))
	box.add_child(hand)

	box.add_child(_mini("Handwriting"))
	var ids: Array = FONT_NAMES.keys().map(func(k: StringName) -> String: return String(k))
	var font_row := ChipRow.new(FONT_NAMES.values(), ids, Settings.get_value("writing/font"))
	font_row.selected.connect(_on_font)
	box.add_child(font_row)
	_preview = Label.new()
	_preview.text = "The derivative of 3x² − 2x + 1 at x = 2 is 10."
	_preview.add_theme_font_size_override("font_size", 28)
	_preview.add_theme_color_override("font_color", Color("#3B3A3C"))
	box.add_child(_preview)
	_on_font(Settings.get_value("writing/font"))

	box.add_child(_mini("Mouse sensitivity"))
	var sens := HSlider.new()
	sens.min_value = 0.4
	sens.max_value = 2.0
	sens.step = 0.05
	sens.value = float(Settings.get_value("input/mouse_sensitivity"))
	sens.value_changed.connect(func(v: float) -> void: Settings.set_value("input/mouse_sensitivity", v))
	box.add_child(sens)

	var edge := CheckBox.new()
	edge.text = "Look up when the cursor rests at the top of the screen"
	edge.button_pressed = bool(Settings.get_value("input/edge_look"))
	edge.toggled.connect(func(v: bool) -> void: Settings.set_value("input/edge_look", v))
	box.add_child(edge)


func _on_font(id: Variant) -> void:
	Settings.set_value("writing/font", String(id))
	_preview.add_theme_font_override("font", HandwritingLayout.font_for(StringName(id)))


func _mini(text: String) -> Label:
	var l := Label.new()
	l.text = text.to_upper()
	l.theme_type_variation = "MiniLabel"
	return l
