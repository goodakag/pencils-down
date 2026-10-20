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


## 12-hour clock parts → minute of the day.
static func to_minute(hour12: int, minute: int, pm: bool) -> int:
	return (hour12 % 12 + (12 if pm else 0)) * 60 + minute


## Minute of the day → [hour12, minute, pm].
static func from_minute(m: int) -> Array:
	var h := (m / 60) % 24
	var h12 := h % 12
	return [12 if h12 == 0 else h12, m % 60, h >= 12]


static func clock_text(m: int, twenty_four: bool) -> String:
	if twenty_four:
		return "%d:%02d" % [(m / 60) % 24, m % 60]
	var p := from_minute(m)
	return "%d:%02d %s" % [p[0], p[1], "PM" if p[2] else "AM"]


## "60 min · starts 9:00 AM": what the pre-test card says it will do.
static func summary(d: Dictionary, twenty_four: bool) -> String:
	var minutes := int(round(float(d.get("duration_s", 3600.0)) / 60.0))
	return "%d min · starts %s" % [minutes, clock_text(int(d.get("start_minute", 540)), twenty_four)]


## Very long PDFs work, but page renders cost memory: say so before starting (spec §10.4).
static func page_warning(pages: int) -> String:
	if pages <= 60:
		return ""
	return "This test has %d pages. That's fine, but pages may take a moment to sharpen as you turn them." % pages
