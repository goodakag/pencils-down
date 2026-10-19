class_name BoardText
extends RefCounted
## What the teacher writes on the board and says aloud.

const WORDS := {1: "One", 2: "Two", 3: "Three", 4: "Four", 5: "Five", 10: "Ten", 15: "Fifteen", 20: "Twenty", 30: "Thirty"}


static func clock(minute_of_day: int) -> String:
	var h := (minute_of_day / 60) % 12
	return "%d:%02d" % [12 if h == 0 else h, minute_of_day % 60]


static func format(start_minute_of_day: int, duration_s: float) -> String:
	var end := start_minute_of_day + int(ceil(duration_s / 60.0 - 1e-6))
	return "Start %s · End %s" % [clock(start_minute_of_day), clock(end)]


static func warning(minutes_left: int) -> String:
	return "%d min left" % minutes_left


static func spoken_warning(minutes_left: int) -> String:
	var n: String = WORDS.get(minutes_left, str(minutes_left))
	return "%s %s left." % [n, "minute" if minutes_left == 1 else "minutes"]
