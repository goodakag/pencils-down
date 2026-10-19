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
