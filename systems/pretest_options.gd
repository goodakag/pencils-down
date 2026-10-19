class_name PretestOptions
extends RefCounted
## Turns saved settings into Session options, and checks a custom time.

const MIN_MINUTES := 5
const MAX_MINUTES := 300


static func from_settings(s: SettingsStore) -> Dictionary:
	return {
		"duration_s": float(s.get_value("test/duration_min")) * 60.0,
		"grace_s": float(s.get_value("test/grace_s")),
		"warnings": (s.get_value("test/warnings") as Array).duplicate(),
		"scratch_sheets": int(s.get_value("test/scratch_sheets")),
		"clock": String(s.get_value("test/clock")),
		"mode": String(s.get_value("test/mode")),
		"class_size": int(s.get_value("test/class_size")),
		"start_minute": int(s.get_value("test/start_minute")),
	}


static func validate(d: Dictionary) -> String:
	var minutes := float(d.get("duration_s", 0.0)) / 60.0
	if minutes < MIN_MINUTES or minutes > MAX_MINUTES:
		return "Choose a time between %d and %d minutes." % [MIN_MINUTES, MAX_MINUTES]
	return ""
