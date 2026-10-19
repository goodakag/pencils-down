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
