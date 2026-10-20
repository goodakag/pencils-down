extends GutTest

func test_options_from_settings() -> void:
	var s := SettingsStore.new()
	s.set_value("test/duration_min", 45)
	s.set_value("test/mode", "strict")
	var o := PretestOptions.from_settings(s)
	assert_eq(o.duration_s, 2700.0)
	assert_eq(o.grace_s, 90.0)
	assert_eq(o.mode, "strict")
	assert_eq(o.scratch_sheets, 1)
	assert_eq(o.warnings, [15, 5])
	assert_eq(o.start_minute, 540)

func test_validate_custom_time() -> void:
	assert_eq(PretestOptions.validate({"duration_s": 180.0}), "Choose a time between 5 and 300 minutes.")
	assert_eq(PretestOptions.validate({"duration_s": 5400.0}), "")
	assert_eq(PretestOptions.validate({"duration_s": 18060.0}), "Choose a time between 5 and 300 minutes.")

func test_start_time_round_trip() -> void:
	assert_eq(PretestOptions.to_minute(9, 0, false), 540)
	assert_eq(PretestOptions.to_minute(12, 0, false), 0, "12 AM is midnight")
	assert_eq(PretestOptions.to_minute(12, 30, true), 750, "12:30 PM is just after noon")
	assert_eq(PretestOptions.to_minute(1, 15, true), 795)
	for m in [0, 5, 540, 719, 720, 795, 1435]:
		var p := PretestOptions.from_minute(m)
		assert_eq(PretestOptions.to_minute(p[0], p[1], p[2]), m)

func test_clock_text() -> void:
	assert_eq(PretestOptions.clock_text(540, false), "9:00 AM")
	assert_eq(PretestOptions.clock_text(795, false), "1:15 PM")
	assert_eq(PretestOptions.clock_text(795, true), "13:15")

func test_summary() -> void:
	var o := {"duration_s": 3600.0, "start_minute": 540}
	assert_eq(PretestOptions.summary(o, false), "60 min · starts 9:00 AM")
	o.duration_s = 5400.0
	o.start_minute = 795
	assert_eq(PretestOptions.summary(o, true), "90 min · starts 13:15")

func test_long_test_warning() -> void:
	assert_eq(PretestOptions.page_warning(12), "")
	assert_string_contains(PretestOptions.page_warning(75), "75 pages")
