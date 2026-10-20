class_name SettingsCard
extends PanelContainer
## Settings, in four tabs: Test (length, start time, exam conditions), Writing, Graphics and
## Controls. Everything saves the moment it changes.

signal back()

const FONT_NAMES := {&"caveat": "Caveat", &"kalam": "Kalam", &"patrick_hand": "Patrick Hand", &"shadows": "Shadows Into Light", &"indie_flower": "Indie Flower"}
const TABS := ["Test", "Writing", "Graphics", "Controls"]

static var last_tab: int = 0

var _preview: Label
var _pages: Array[Control] = []


func _ready() -> void:
	theme_type_variation = "Card"
	custom_minimum_size = Vector2(640, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	add_child(box)
	var head := HBoxContainer.new()
	box.add_child(head)
	var h := Label.new()
	h.text = "Settings"
	h.theme_type_variation = "Heading"
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(h)
	var back_btn := Button.new()
	back_btn.text = "Done"
	back_btn.theme_type_variation = "Link"
	back_btn.pressed.connect(back.emit)
	head.add_child(back_btn)

	var tabs := ChipRow.new(TABS, [0, 1, 2, 3], last_tab)
	box.add_child(tabs)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 470)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(stack)
	for page in [TestSetupForm.new(), _writing(), _graphics(), _controls()]:
		(page as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stack.add_child(page)
		_pages.append(page)
	tabs.selected.connect(_show_tab)
	_show_tab(last_tab)


func _show_tab(i: Variant) -> void:
	last_tab = int(i)
	for k in _pages.size():
		_pages[k].visible = k == last_tab


func _writing() -> Control:
	var v := _page()
	v.add_child(_mini("Writing hand"))
	var hand := ChipRow.new(["Right", "Left"], ["right", "left"], Settings.get_value("writing/hand"))
	hand.selected.connect(func(x: Variant) -> void: Settings.set_value("writing/hand", x))
	v.add_child(hand)
	v.add_child(_mini("Handwriting for typed answers"))
	var ids: Array = FONT_NAMES.keys().map(func(k: StringName) -> String: return String(k))
	var font_row := ChipRow.new(FONT_NAMES.values(), ids, Settings.get_value("writing/font"))
	font_row.selected.connect(_on_font)
	v.add_child(font_row)
	_preview = Label.new()
	_preview.text = "The derivative of 3x² − 2x + 1 at x = 2 is 10."
	_preview.add_theme_font_size_override("font_size", 28)
	_preview.add_theme_color_override("font_color", Color("#3B3A3C"))
	v.add_child(_preview)
	_on_font(Settings.get_value("writing/font"))
	return v


func _graphics() -> Control:
	var v := _page()
	v.add_child(_mini("Quality"))
	var q := ChipRow.new(["Low (older laptops)", "Medium", "High (sunbeams, bounce light)"], ["low", "medium", "high"], Settings.get_value("graphics/preset"))
	q.selected.connect(func(x: Variant) -> void: Settings.set_value("graphics/preset", x))
	v.add_child(q)
	v.add_child(_mini("Field of view"))
	var fov_row := HBoxContainer.new()
	var fov := HSlider.new()
	fov.min_value = 40
	fov.max_value = 70
	fov.step = 1
	fov.value = float(Settings.get_value("graphics/fov"))
	fov.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var fov_l := Label.new()
	fov_l.text = "%d°" % int(fov.value)
	fov_l.custom_minimum_size.x = 48
	fov.value_changed.connect(func(x: float) -> void:
		fov_l.text = "%d°" % int(x)
		Settings.set_value("graphics/fov", int(x)))
	fov_row.add_child(fov)
	fov_row.add_child(fov_l)
	v.add_child(fov_row)
	var sway := CheckBox.new()
	sway.text = "Gentle head movement (breathing)"
	sway.button_pressed = bool(Settings.get_value("graphics/head_sway"))
	sway.toggled.connect(func(x: bool) -> void: Settings.set_value("graphics/head_sway", x))
	v.add_child(sway)
	return v


func _controls() -> Control:
	var v := _page()
	v.add_child(_mini("Keys on screen"))
	var hint := ChipRow.new(["Always", "Fade when idle", "Hidden"], ["always", "fade", "off"], Settings.get_value("ui/controls"))
	hint.selected.connect(func(x: Variant) -> void: Settings.set_value("ui/controls", x))
	v.add_child(hint)
	var edge := CheckBox.new()
	edge.text = "Look up when the cursor rests at the top of the screen"
	edge.button_pressed = bool(Settings.get_value("input/edge_look"))
	edge.toggled.connect(func(x: bool) -> void: Settings.set_value("input/edge_look", x))
	v.add_child(edge)
	var tips := Button.new()
	tips.text = "Show the first-test tips again"
	tips.theme_type_variation = "Link"
	tips.alignment = HORIZONTAL_ALIGNMENT_LEFT
	tips.pressed.connect(func() -> void:
		Settings.set_value("ui/tips_seen", false)
		tips.text = "Tips will show at the start of your next test")
	v.add_child(tips)
	v.add_child(_mini("All keys"))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 4)
	for row in ControlsHint.CONTEXTS.desk + [[["Ctrl", "Y"], "Redo"], [["Double-click"], "Type where you click"], [["F1"], "Show / hide these keys"]]:
		var k := Label.new()
		k.text = " + ".join(row[0])
		k.add_theme_font_override("font", CozyTheme.bold_font())
		k.add_theme_font_size_override("font_size", 15)
		grid.add_child(k)
		var d := Label.new()
		d.text = row[1]
		d.add_theme_font_size_override("font_size", 15)
		grid.add_child(d)
	v.add_child(grid)
	return v


func _page() -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	return v


func _on_font(id: Variant) -> void:
	Settings.set_value("writing/font", String(id))
	_preview.add_theme_font_override("font", HandwritingLayout.font_for(StringName(id)))


func _mini(text: String) -> Label:
	var l := Label.new()
	l.text = text.to_upper()
	l.theme_type_variation = "MiniLabel"
	return l
