class_name EnvironmentContract
extends Node3D
## Every classroom provides these, so new rooms drop in without code changes (spec §10.2).

@export var player_seat: Marker3D
@export var student_seats: Array[Marker3D] = []
@export var teacher_desk: Marker3D
@export var teacher_patrol: Path3D
@export var handin_path: Path3D
@export var wall_clock: WallClock
@export var board: Whiteboard


## Names of missing pieces; empty when the room is complete.
func validate() -> PackedStringArray:
	var missing := PackedStringArray()
	if player_seat == null: missing.append("player_seat")
	if student_seats.is_empty(): missing.append("student_seats")
	if teacher_desk == null: missing.append("teacher_desk")
	if teacher_patrol == null: missing.append("teacher_patrol")
	if handin_path == null: missing.append("handin_path")
	if wall_clock == null: missing.append("wall_clock")
	if board == null: missing.append("board")
	return missing


## Desk-surface transform at the player's seat (where the packet and rig go).
func desk_surface() -> Transform3D:
	return player_seat.global_transform
