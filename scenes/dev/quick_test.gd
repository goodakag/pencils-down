extends Node
## Dev entry: a 2-minute test of the fixture PDF with a 30 s grace period.

func _ready() -> void:
	var doc := PdfService.open(ProjectSettings.globalize_path("res://tests/fixtures/mc_letter.pdf"))
	var minutes := 2.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--minutes="):
			minutes = float(a.trim_prefix("--minutes="))
	Session.begin(doc, {"duration_s": minutes * 60.0, "grace_s": 30.0, "warnings": [1]})
	get_tree().change_scene_to_file.call_deferred("res://scenes/flow/test_scene.tscn")
