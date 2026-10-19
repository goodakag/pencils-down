class_name SettingsStore
extends RefCounted
## Player settings with defaults, saved to user://settings.cfg ("section/key" names).

const PATH := "user://settings.cfg"
const DEFAULTS := {
	"writing/hand": "right",
	"writing/font": "caveat",
	"input/mouse_sensitivity": 1.0,
	"input/edge_look": true,
	"graphics/preset": "medium",
	"graphics/fov": 70,
	"test/duration_min": 60,
	"test/grace_s": 90,
	"test/scratch_sheets": 1,
	"test/warnings": [15, 5],
	"test/clock": "wall",
	"test/mode": "practice",
	"test/class_size": 16,
	"test/start_minute": 540,
	"recent/pdfs": [],
}
const MAX_RECENT := 5

var _values: Dictionary = {}


func _init() -> void:
	_values = DEFAULTS.duplicate(true)


func get_value(key: String) -> Variant:
	return _values.get(key)


func set_value(key: String, v: Variant) -> void:
	if DEFAULTS.has(key):
		_values[key] = v


func save(path: String = PATH) -> Error:
	var cfg := ConfigFile.new()
	for key in _values:
		var parts: PackedStringArray = key.split("/")
		cfg.set_value(parts[0], parts[1], _values[key])
	return cfg.save(path)


## Unknown keys are ignored; missing keys keep their defaults.
func load(path: String = PATH) -> void:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	for key in DEFAULTS:
		var parts: PackedStringArray = key.split("/")
		if cfg.has_section_key(parts[0], parts[1]):
			_values[key] = cfg.get_value(parts[0], parts[1])


func push_recent(path: String) -> void:
	var list: Array = (_values["recent/pdfs"] as Array).duplicate()
	list.erase(path)
	list.push_front(path)
	_values["recent/pdfs"] = list.slice(0, MAX_RECENT)
