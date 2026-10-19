extends Control
## Placeholder until Task 17 builds the review screen.

func _ready() -> void:
	var l := Label.new()
	l.text = "Test handed in. Saved to %s" % Session.last_archive_path
	l.set_anchors_preset(Control.PRESET_CENTER)
	add_child(l)
