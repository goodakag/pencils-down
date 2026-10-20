extends GutTest

const SIZE := Vector2(0.2159, 0.2794)
const TOP := -0.1397
const BOTTOM := 0.1397

func test_flat_moves_nothing() -> void:
	var c := PageCurl.flat(SIZE)
	for p in [Vector2(0, 0), Vector2(0.1, BOTTOM), Vector2(-0.1, TOP)]:
		assert_eq(c.map(p), Vector3(p.x, 0, p.y))
	assert_eq(c.progress(), 0.0)

func test_turned_puts_the_sheet_past_the_top_edge_face_down() -> void:
	var c := PageCurl.turned(SIZE)
	var bottom := c.map(Vector2(0, BOTTOM))
	assert_lt(bottom.z, TOP, "the bottom edge ends up beyond the staple edge")
	assert_almost_eq(c.progress(), 1.0, 1e-5)

func test_top_edge_never_lifts() -> void:
	# Even a wild drag straight across the sheet keeps the stapled edge down.
	for at in [Vector2(-0.3, -0.2), Vector2(0.0, -0.5), Vector2(0.3, 0.0), Vector2(-0.05, 0.05)]:
		var c := PageCurl.from_drag(SIZE, Vector2(0.1, BOTTOM), at)
		assert_almost_eq(c.map(Vector2(-SIZE.x * 0.5, TOP)).y, 0.0, 1e-6)
		assert_almost_eq(c.map(Vector2(SIZE.x * 0.5, TOP)).y, 0.0, 1e-6)

func test_grabbed_corner_follows_the_hand() -> void:
	var grab := Vector2(0.1, BOTTOM)
	var at := Vector2(0.06, 0.0)
	var c := PageCurl.from_drag(SIZE, grab, at)
	var landed := c.map(grab)
	assert_almost_eq(Vector2(landed.x, landed.z).distance_to(at), 0.0, 0.01)

func test_fold_direction_depends_on_where_you_grab() -> void:
	var at := Vector2(0.0, 0.0)
	var right := PageCurl.from_drag(SIZE, Vector2(0.1, BOTTOM), at)
	var left := PageCurl.from_drag(SIZE, Vector2(-0.1, BOTTOM), at)
	assert_gt(right.normal.x, 0.1, "grabbing the right corner tilts the fold one way")
	assert_lt(left.normal.x, -0.1, "and the left corner the other")
	# The far corner from the grab stays flat for a corner peel.
	assert_almost_eq(right.map(Vector2(-SIZE.x * 0.5, BOTTOM)).y, 0.0, 1e-6)

func test_progress_grows_as_the_hand_moves_up() -> void:
	var grab := Vector2(0.0, BOTTOM)
	var a := PageCurl.from_drag(SIZE, grab, Vector2(0, 0.08)).progress()
	var b := PageCurl.from_drag(SIZE, grab, Vector2(0, -0.02)).progress()
	var c := PageCurl.from_drag(SIZE, grab, Vector2(0, -0.45)).progress()
	assert_lt(a, b)
	assert_lt(b, c)
	assert_gt(c, 0.9)

func test_pushing_toward_the_reader_does_not_lift() -> void:
	var c := PageCurl.from_drag(SIZE, Vector2(0.0, 0.1), Vector2(0.0, 0.2))
	assert_eq(c.progress(), 0.0)

func test_height_is_continuous_across_the_fold() -> void:
	var c := PageCurl.from_drag(SIZE, Vector2(0.0, BOTTOM), Vector2(0, -0.02))
	var prev := c.map(Vector2(0, TOP))
	var z := TOP
	while z < BOTTOM:
		z += 0.002
		var p := c.map(Vector2(0, z))
		assert_lt(p.distance_to(prev), 0.006, "no tears at z=%f" % z)
		prev = p

func test_should_complete() -> void:
	assert_true(PageCurl.should_complete(0.6, 0.0))
	assert_false(PageCurl.should_complete(0.4, 0.0))
	assert_true(PageCurl.should_complete(0.2, 0.8), "a flick finishes the turn")
	assert_false(PageCurl.should_complete(0.7, -0.8), "flicking back cancels it")

func test_lerp_between_flat_and_turned() -> void:
	var a := PageCurl.flat(SIZE)
	var b := PageCurl.turned(SIZE)
	assert_almost_eq(a.lerped(b, 0.0).progress(), 0.0, 1e-5)
	assert_almost_eq(a.lerped(b, 1.0).progress(), 1.0, 1e-5)
	var mid := a.lerped(b, 0.5).progress()
	assert_between(mid, 0.3, 0.7)

func test_unturn_drag_starts_turned_and_unrolls() -> void:
	var start := PageCurl.unturn_drag(SIZE, Vector2(0.0, TOP - 0.25), 0.0)
	assert_gt(start.progress(), 0.8)
	var later := PageCurl.unturn_drag(SIZE, Vector2(0.0, 0.05), 0.0)
	assert_lt(later.progress(), start.progress())
