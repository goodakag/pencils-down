class_name TestSetupForm
extends VBoxContainer
## How the test runs: its length, what time the clock in the room says when it starts, and the
## rest of the exam conditions. Every change is saved straight to Settings, so the Settings screen
## and the pre-test card share one form. `compact` leaves out the less common options.

signal changed()

const TIMES := [30, 45, 60, 75, 90, 120]

var compact: bool = false
var _custom: SpinBox
var _hour: OptionButton
var _minute: OptionButton
var _ampm: ChipRow
var _validation: Label


func _init(is_compact: bool = false) -> void:
	compact = is_compact


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	add_child(_mini("Test length"))
	var minutes := int(Settings.get_value("test/duration_min"))
	var labels: Array = []
	var values: Array = []
	for m in TIMES:
		labels.append("%d min" % m)
		values.append(m)
	labels.append("Custom")
	values.append(-1)
	var chips := ChipRow.new(labels, values, minutes if TIMES.has(minutes) else -1)
	chips.selected.connect(_on_time)
	add_child(chips)
	_custom = SpinBox.new()
	_custom.min_value = 1
	_custom.max_value = 600
	_custom.suffix = "min"
	_custom.value = minutes
	_custom.visible = not TIMES.has(minutes)
	_custom.custom_minimum_size.x = 140
	_custom.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_custom.value_changed.connect(func(v: float) -> void:
		Settings.set_value("test/duration_min", int(v))
		_emit())
	add_child(_custom)
	_validation = Label.new()
	_validation.theme_type_variation = "Error"
	_validation.visible = false
	add_child(_validation)

	add_child(_mini("Starts at (on the classroom clock)"))
	add_child(_start_picker())

	if compact:
		return
	_option("Grace period after the bell", ["None", "1 min", "1.5 min", "2 min"], [0, 60, 90, 120], "test/grace_s")
	_option("Time warnings", ["None", "15 & 5 min", "30, 15 & 5 min"], [[], [15, 5], [30, 15, 5]], "test/warnings")
	_option("Scratch paper", ["Off", "1 sheet", "2 sheets"], [0, 1, 2], "test/scratch_sheets")
	_option("Mode", ["Practice (Esc pauses)", "Strict (time keeps running)"], ["practice", "strict"], "test/mode")
	_option("Classmates", ["None", "A few", "Half full", "Full"], [0, 8, 16, 24], "test/class_size")
	_option("Clock", ["12-hour", "24-hour", "No clock"], ["12", "24", "none"], "", _clock_value(), _set_clock)


func _start_picker() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var parts := PretestOptions.from_minute(int(Settings.get_value("test/start_minute")))
	_hour = OptionButton.new()
	for h in range(1, 13):
		_hour.add_item(str(h), h)
	_hour.select(int(parts[0]) - 1)
	_hour.item_selected.connect(func(_i: int) -> void: _save_start())
	row.add_child(_hour)
	var colon := Label.new()
	colon.text = ":"
	row.add_child(colon)
	_minute = OptionButton.new()
	for m in range(0, 60, 5):
		_minute.add_item("%02d" % m, m)
	_minute.select(int(parts[1]) / 5)
	_minute.item_selected.connect(func(_i: int) -> void: _save_start())
	row.add_child(_minute)
	_ampm = ChipRow.new(["AM", "PM"], [false, true], parts[2])
	_ampm.selected.connect(func(_v: Variant) -> void: _save_start())
	_ampm.size_flags_horizontal = Control.SIZE_EXPAND_FILL  # a flow row in an HBox wraps at min width otherwise
	_ampm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_ampm)
	for ob in [_hour, _minute]:
		(ob as OptionButton).add_theme_font_size_override("font_size", 18)
		(ob as OptionButton).custom_minimum_size.x = 74
	return row


func _save_start() -> void:
	var pm := false
	for c in _ampm.get_children():
		if (c as Button).button_pressed and (c as Button).text == "PM":
			pm = true
	var m := PretestOptions.to_minute(_hour.get_selected_id(), _minute.get_selected_id(), pm)
	Settings.set_value("test/start_minute", m)
	_emit()


func _clock_value() -> String:
	if Settings.get_value("test/clock") == "none":
		return "none"
	return "24" if bool(Settings.get_value("test/clock_24h")) else "12"


func _set_clock(v: Variant) -> void:
	Settings.set_value("test/clock", "none" if v == "none" else "wall")
	if v != "none":
		Settings.set_value("test/clock_24h", v == "24")


func _option(label: String, labels: Array, values: Array, key: String, current: Variant = null, setter: Callable = Callable()) -> void:
	add_child(_mini(label))
	var row := ChipRow.new(labels, values, Settings.get_value(key) if key != "" else current)
	row.selected.connect(func(v: Variant) -> void:
		if setter.is_valid():
			setter.call(v)
		else:
			Settings.set_value(key, v)
		_emit())
	add_child(row)


func _on_time(minutes: Variant) -> void:
	_custom.visible = int(minutes) < 0
	Settings.set_value("test/duration_min", int(minutes) if int(minutes) > 0 else int(_custom.value))
	_emit()


func is_valid() -> bool:
	var msg := PretestOptions.validate(PretestOptions.from_settings(Settings.store))
	_validation.text = msg
	_validation.visible = msg != ""
	return msg == ""


func _emit() -> void:
	is_valid()
	changed.emit()


func _mini(text: String) -> Label:
	var l := Label.new()
	l.text = text.to_upper()
	l.theme_type_variation = "MiniLabel"
	return l
