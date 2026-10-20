class_name WallClockMath
extends RefCounted
## Analog clock hand angles (radians, clockwise from 12). All hands sweep continuously.


static func hand_angles(seconds_of_day: float) -> Vector3:
	var hour := fposmod(seconds_of_day, 43200.0) / 43200.0 * TAU
	var minute := fposmod(seconds_of_day, 3600.0) / 3600.0 * TAU
	var second := fposmod(seconds_of_day, 60.0) / 60.0 * TAU
	return Vector3(hour, minute, second)


## Digital clock readout: "9:05" (12-hour) or "13:05" (24-hour); seconds optional.
static func digital(seconds_of_day: float, twelve_hour: bool, with_seconds: bool = false) -> String:
	var s := int(floor(fposmod(seconds_of_day, 86400.0)))
	var h := s / 3600
	if twelve_hour:
		h %= 12
		if h == 0:
			h = 12
	var out := "%d:%02d" % [h, (s / 60) % 60]
	if with_seconds:
		out += ":%02d" % (s % 60)
	return out


static func is_pm(seconds_of_day: float) -> bool:
	return fposmod(seconds_of_day, 86400.0) >= 43200.0


## Seven-segment pattern for one character, segments a..g as bits 0..6
## (a top, b top-right, c bottom-right, d bottom, e bottom-left, f top-left, g middle).
const SEGMENTS := {
	"0": 0b0111111, "1": 0b0000110, "2": 0b1011011, "3": 0b1001111, "4": 0b1100110,
	"5": 0b1101101, "6": 0b1111101, "7": 0b0000111, "8": 0b1111111, "9": 0b1101111,
}


static func segments(ch: String) -> int:
	return SEGMENTS.get(ch, 0)
