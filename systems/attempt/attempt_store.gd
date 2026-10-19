class_name AttemptStore
extends RefCounted
## Saves finished attempts to <root>/attempts/<id>.json and the in-progress one to <root>/autosave.json.

var root: String = "user://"


func archive(a: Attempt) -> String:
	var dir := root.path_join("attempts")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var path := dir.path_join("%s.json" % a.id)
	_write_atomic(path, JSON.stringify(a.to_dict()))
	return path


func load_attempt(path: String) -> Attempt:
	if not FileAccess.file_exists(path):
		return null
	var data: Variant = AttemptCodec.parse_json(FileAccess.get_file_as_string(path))
	return Attempt.from_dict(data) if data is Dictionary else null


## Newest first: [{path, id, test_title, created_unix, used_s, finished}].
func list_history() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var dir := root.path_join("attempts")
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		if not f.ends_with(".json"):
			continue
		var path := dir.path_join(f)
		var a := load_attempt(path)
		if a == null:
			continue
		out.append({
			"path": path,
			"id": a.id,
			"test_title": a.test_title,
			"created_unix": a.created_unix,
			"used_s": float(a.timer_state.get("elapsed", 0.0)),
			"finished": a.finished,
		})
	out.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return x.created_unix > y.created_unix)
	return out


func save_autosave(a: Attempt) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root))
	_write_atomic(root.path_join("autosave.json"), JSON.stringify(a.to_dict()))


func load_autosave() -> Attempt:
	return load_attempt(root.path_join("autosave.json"))


func clear_autosave() -> void:
	var p := root.path_join("autosave.json")
	if FileAccess.file_exists(p):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


## Writes to a temp file, then renames, so a crash mid-write never leaves a half-written file.
func _write_atomic(path: String, text: String) -> void:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("AttemptStore: cannot write %s (%s)" % [tmp, error_string(FileAccess.get_open_error())])
		return
	f.store_string(text)
	f.close()
	var abs_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(abs_path)
	DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), abs_path)
