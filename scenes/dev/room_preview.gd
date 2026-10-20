extends Node3D
## Dev: the classroom from any camera. Args after "--":
##   --cam=x,y,z --look=x,y,z --fov=70 --preset=medium --time=34200
## Default camera is the seated eye at the player's desk.

var room: MorningClassroom


func _ready() -> void:
	room = MorningClassroom.new()
	add_child(room)
	room.populate(16)
	var cam := Camera3D.new()
	cam.fov = 70.0
	add_child(cam)
	var seat := room.player_seat.global_position
	var eye := seat + Vector3(0, 0.45, 0.42)
	var look := Vector3(0, 1.6, -4.0)
	var time := 9.0 * 3600.0 + 4.0 * 60.0
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=")
		if kv.size() != 2:
			continue
		match kv[0]:
			"cam": eye = _v(kv[1])
			"look": look = _v(kv[1])
			"fov": cam.fov = float(kv[1])
			"preset": room.apply_preset(kv[1])
			"time": time = float(kv[1])
	cam.position = eye
	cam.look_at(look)
	room.wall_clock.set_time(time)
	print("desk_top_y=", room.desk_top_y)
	room.board.set_lines(BoardText.format(540, 3600.0), "No talking. Raise your hand if you have a question.")


func _v(s: String) -> Vector3:
	var p := s.split(",")
	return Vector3(float(p[0]), float(p[1]), float(p[2]))
