class_name WallClockMath
extends RefCounted
## Analog clock hand angles (radians, clockwise from 12). All hands sweep continuously.


static func hand_angles(seconds_of_day: float) -> Vector3:
	var hour := fposmod(seconds_of_day, 43200.0) / 43200.0 * TAU
	var minute := fposmod(seconds_of_day, 3600.0) / 3600.0 * TAU
	var second := fposmod(seconds_of_day, 60.0) / 60.0 * TAU
	return Vector3(hour, minute, second)
