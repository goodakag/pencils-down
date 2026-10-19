extends Node
## Autoload "DevShot": development screenshots. Run the game with
##   -- --shot=<absolute.png> [--shot-delay=2.5] [--shot-actions=a,b,c] [--shot-tail=0.2]
## It waits, optionally fires named actions through the scene's `dev_action(name)` method,
## saves the viewport to the PNG and quits. Does nothing without --shot.

var _path := ""
var _delay := 2.5
var _actions: PackedStringArray = []
var _tail := -1.0  # seconds between the last action and the capture (default: even spacing)


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			_path = arg.trim_prefix("--shot=")
		elif arg.begins_with("--shot-delay="):
			_delay = float(arg.trim_prefix("--shot-delay="))
		elif arg.begins_with("--shot-actions="):
			_actions = arg.trim_prefix("--shot-actions=").split(",", false)
		elif arg.begins_with("--shot-tail="):
			_tail = float(arg.trim_prefix("--shot-tail="))
	if _path != "":
		_run.call_deferred()


func _run() -> void:
	var step := _delay / float(_actions.size() + 1)
	for a in _actions:
		await get_tree().create_timer(step).timeout
		var scene := get_tree().current_scene
		if scene and scene.has_method("dev_action"):
			scene.dev_action(a)
	await get_tree().create_timer(_tail if _tail >= 0.0 else step).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(_path)
	print("DevShot saved ", _path)
	get_tree().quit()
