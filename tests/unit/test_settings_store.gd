extends GutTest

var path: String

func before_each() -> void:
	path = "user://settings_test_%d.cfg" % randi()

func after_each() -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func test_defaults() -> void:
	var s := SettingsStore.new()
	assert_eq(s.get_value("test/grace_s"), 90)
	assert_eq(s.get_value("writing/font"), "caveat")
	assert_eq(s.get_value("test/mode"), "practice")

func test_save_load_round_trip() -> void:
	var s := SettingsStore.new()
	s.set_value("test/duration_min", 75)
	s.set_value("writing/hand", "left")
	assert_eq(s.save(path), OK)
	var t := SettingsStore.new()
	t.load(path)
	assert_eq(t.get_value("test/duration_min"), 75)
	assert_eq(t.get_value("writing/hand"), "left")

func test_unknown_and_missing_keys() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("test", "bogus", 1)
	cfg.set_value("test", "grace_s", 60)
	cfg.save(path)
	var s := SettingsStore.new()
	s.load(path)
	assert_eq(s.get_value("test/grace_s"), 60)
	assert_eq(s.get_value("test/mode"), "practice")
	assert_null(s.get_value("test/bogus"))

func test_missing_file_keeps_defaults() -> void:
	var s := SettingsStore.new()
	s.load("user://does_not_exist.cfg")
	assert_eq(s.get_value("test/grace_s"), 90)

func test_recent_dedupe_max5() -> void:
	var s := SettingsStore.new()
	for p in ["a", "b", "c", "a", "d", "e", "f"]:
		s.push_recent(p)
	assert_eq(s.get_value("recent/pdfs"), ["f", "e", "d", "a", "c"])
