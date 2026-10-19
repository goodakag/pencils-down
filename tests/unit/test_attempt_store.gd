extends GutTest

var root: String

func before_each() -> void:
	root = "user://test_store_%d/" % randi()

func after_each() -> void:
	_rm(ProjectSettings.globalize_path(root))

func _rm(dir: String) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		d.remove(f)
	for sub in d.get_directories():
		_rm(dir.path_join(sub))
	DirAccess.remove_absolute(dir)

func _attempt(created: int, title := "T") -> Attempt:
	var a := Attempt.new()
	a.id = "%d-%06x" % [created, randi() & 0xffffff]
	a.test_title = title
	a.created_unix = created
	a.pages = [PageInk.new()]
	a.timer_state = {"elapsed": 30.0}
	return a

func _store() -> AttemptStore:
	var s := AttemptStore.new()
	s.root = root
	return s

func test_archive_and_history_newest_first() -> void:
	var s := _store()
	s.archive(_attempt(100, "old"))
	s.archive(_attempt(200, "new"))
	var h := s.list_history()
	assert_eq(h.size(), 2)
	assert_eq(h[0].created_unix, 200)
	assert_eq(h[0].test_title, "new")
	assert_eq(h[0].used_s, 30.0)

func test_load_archived() -> void:
	var s := _store()
	var path := s.archive(_attempt(100, "x"))
	assert_eq(s.load_attempt(path).test_title, "x")

func test_autosave_round_trip_and_clear() -> void:
	var s := _store()
	assert_null(s.load_autosave())
	s.save_autosave(_attempt(5, "auto"))
	assert_eq(s.load_autosave().test_title, "auto")
	s.clear_autosave()
	assert_null(s.load_autosave())

func test_corrupt_autosave_returns_null() -> void:
	var s := _store()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root))
	var f := FileAccess.open(root + "autosave.json", FileAccess.WRITE)
	f.store_string("{")
	f.close()
	assert_null(s.load_autosave())

func test_unicode_root_path() -> void:
	root = "user://Zoë Документы %d/" % randi()
	var s := _store()
	var path := s.archive(_attempt(7, "uni"))
	assert_eq(s.load_attempt(path).test_title, "uni")
