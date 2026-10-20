extends GutTest

const LETTER := Vector2(0.2159, 0.2794)

func _corners() -> Array[Vector3]:
	var h := LETTER * 0.5
	return [Vector3(-h.x, 0, -h.y), Vector3(h.x, 0, -h.y), Vector3(-h.x, 0, h.y), Vector3(h.x, 0, h.y)]

func test_whole_page_is_visible_sitting_normally() -> void:
	var cam := SeatPose.desk(0.0, Vector3.ZERO)
	for c in _corners():
		assert_true(SeatPose.sees(cam, 50.0, 16.0 / 9.0, c), "corner %s visible" % c)

func test_whole_page_visible_even_on_a_4_3_screen() -> void:
	var cam := SeatPose.desk(0.0, Vector3.ZERO)
	for c in _corners():
		assert_true(SeatPose.sees(cam, 50.0, 4.0 / 3.0, c))

func test_desk_view_looks_down_like_a_seated_person() -> void:
	var cam := SeatPose.desk(0.0, Vector3.ZERO)
	var fwd := -cam.basis.z
	var pitch := rad_to_deg(asin(-fwd.y))
	assert_between(pitch, 40.0, 60.0)

func test_leaning_brings_the_eye_closer_to_the_focus() -> void:
	var focus := Vector3(0.05, 0, 0.08)
	var far := SeatPose.desk(0.0, focus).origin.distance_to(focus)
	var near := SeatPose.desk(1.0, focus).origin.distance_to(focus)
	assert_lt(near, far * 0.6)

func test_leaning_keeps_the_focus_in_view() -> void:
	var focus := Vector3(-0.08, 0, 0.1)
	for l in [0.0, 0.5, 1.0]:
		assert_true(SeatPose.sees(SeatPose.desk(l, focus), 50.0, 16.0 / 9.0, focus))

func test_look_up_centres_the_target() -> void:
	var target := Vector3(1.5, 1.64, -4.7)
	var cam := SeatPose.look_up(target, Vector2.ZERO)
	var dir := (target - cam.origin).normalized()
	assert_almost_eq((-cam.basis.z).dot(dir), 1.0, 1e-4)
	assert_true(SeatPose.sees(cam, SeatPose.LOOK_UP_FOV, 16.0 / 9.0, target))

func test_free_look_turns_but_keeps_target_on_screen() -> void:
	var target := Vector3(0, 1.64, -4.7)
	var cam := SeatPose.look_up(target, Vector2(0.4, 0.0))
	assert_true(SeatPose.sees(cam, 50.0, 16.0 / 9.0, target))
	assert_ne(cam.basis, SeatPose.look_up(target, Vector2.ZERO).basis)

func test_sway_is_tiny() -> void:
	for t in [0.0, 1.3, 7.7, 100.0]:
		assert_lt(SeatPose.sway(t).length(), 0.005)
