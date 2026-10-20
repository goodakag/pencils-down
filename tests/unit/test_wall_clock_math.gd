extends GutTest

func _norm(a: float) -> float:
	return fposmod(a, TAU)

func test_clock_noon() -> void:
	var a := WallClockMath.hand_angles(43200.0)
	assert_almost_eq(_norm(a.x), 0.0, 1e-4)
	assert_almost_eq(_norm(a.y), 0.0, 1e-4)
	assert_almost_eq(_norm(a.z), 0.0, 1e-4)

func test_clock_9_30() -> void:
	var a := WallClockMath.hand_angles(34200.0)
	assert_almost_eq(_norm(a.x), deg_to_rad(285.0), 1e-4)
	assert_almost_eq(_norm(a.y), deg_to_rad(180.0), 1e-4)

func test_second_hand_sweeps() -> void:
	var a := WallClockMath.hand_angles(34215.5)
	assert_almost_eq(_norm(a.z), deg_to_rad(93.0), 1e-4)

func test_digital_twelve_hour() -> void:
	assert_eq(WallClockMath.digital(9 * 3600 + 5 * 60 + 59.9, true), "9:05")
	assert_eq(WallClockMath.digital(0.0, true), "12:00")
	assert_eq(WallClockMath.digital(13 * 3600 + 30 * 60, true), "1:30")
	assert_eq(WallClockMath.digital(12 * 3600, true), "12:00")

func test_digital_twenty_four_hour() -> void:
	assert_eq(WallClockMath.digital(13 * 3600 + 30 * 60, false), "13:30")
	assert_eq(WallClockMath.digital(9 * 3600, false), "9:00")

func test_digital_wraps_past_midnight() -> void:
	assert_eq(WallClockMath.digital(24 * 3600 + 60, false), "0:01")

func test_digital_seconds() -> void:
	assert_eq(WallClockMath.digital(9 * 3600 + 7.4, true, true), "9:00:07")

func test_segments_for_digits() -> void:
	# Segments a..g as bits 0..6.
	assert_eq(WallClockMath.segments("8"), 0b1111111)
	assert_eq(WallClockMath.segments("1"), 0b0000110)
	assert_eq(WallClockMath.segments("0"), 0b0111111)
	assert_eq(WallClockMath.segments(" "), 0)

func test_is_pm() -> void:
	assert_false(WallClockMath.is_pm(9 * 3600))
	assert_true(WallClockMath.is_pm(12 * 3600))
	assert_true(WallClockMath.is_pm(23 * 3600))
