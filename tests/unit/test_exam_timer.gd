extends GutTest

func _t(dur := 3600.0, grace := 90.0) -> ExamTimer:
	var t := ExamTimer.new(dur, grace)
	t.start()
	return t

func test_counts_down() -> void:
	var t := _t()
	t.advance(60.0)
	assert_eq(t.elapsed(), 60.0)
	assert_eq(t.remaining(), 3540.0)

func test_not_started_does_not_count() -> void:
	var t := ExamTimer.new(100.0, 10.0)
	t.advance(5.0)
	assert_eq(t.elapsed(), 0.0)
	assert_eq(t.phase(), ExamTimer.Phase.NOT_STARTED)

func test_warnings_fire_once_each_at_15_and_5() -> void:
	var t := _t()
	watch_signals(t)
	t.advance(2700.0)
	t.advance(1.0)
	t.advance(600.0)
	assert_signal_emit_count(t, "warning", 2)
	assert_signal_emitted_with_parameters(t, "warning", [15], 0)
	assert_signal_emitted_with_parameters(t, "warning", [5], 1)

func test_end_enters_grace_then_over() -> void:
	var t := _t(100.0, 90.0)
	watch_signals(t)
	t.advance(100.0)
	assert_eq(t.phase(), ExamTimer.Phase.GRACE)
	assert_signal_emitted(t, "test_ended")
	t.advance(89.0)
	assert_almost_eq(t.grace_remaining(), 1.0, 0.001)
	t.advance(1.0)
	assert_eq(t.phase(), ExamTimer.Phase.OVER)
	assert_signal_emitted(t, "grace_ended")

func test_large_delta_crosses_both_boundaries() -> void:
	var t := _t(100.0, 90.0)
	watch_signals(t)
	t.advance(500.0)
	assert_eq(t.phase(), ExamTimer.Phase.OVER)
	assert_signal_emitted(t, "test_ended")
	assert_signal_emitted(t, "grace_ended")
	assert_eq(t.remaining(), 0.0)

func test_zero_grace_goes_straight_to_over() -> void:
	var t := _t(10.0, 0.0)
	t.advance(10.0)
	assert_eq(t.phase(), ExamTimer.Phase.OVER)

func test_suspend_holds_time_and_caps_at_60s() -> void:
	var t := _t()
	t.suspend(&"teacher")
	t.advance(30.0)
	assert_eq(t.elapsed(), 0.0)
	assert_true(t.is_suspended())
	t.advance(40.0)
	assert_false(t.is_suspended())
	assert_almost_eq(t.elapsed(), 10.0, 0.001)

func test_resume_ends_suspension() -> void:
	var t := _t()
	t.suspend(&"teacher")
	t.advance(5.0)
	t.resume(&"teacher")
	t.advance(5.0)
	assert_eq(t.elapsed(), 5.0)

func test_pause_only_when_pausable() -> void:
	var t := _t()
	t.pausable = false
	t.pause()
	t.advance(5.0)
	assert_eq(t.elapsed(), 5.0)
	t.pausable = true
	t.pause()
	t.advance(5.0)
	assert_eq(t.elapsed(), 5.0)
	t.unpause()
	t.advance(1.0)
	assert_eq(t.elapsed(), 6.0)

func test_round_trip_dict() -> void:
	var t := _t()
	t.advance(1234.0)
	var u := ExamTimer.from_dict(t.to_dict())
	assert_eq(u.remaining(), t.remaining())
	assert_eq(u.phase(), t.phase())

func test_restored_timer_does_not_refire_passed_warnings() -> void:
	var t := _t()
	t.advance(2800.0)   # past the 15-minute warning
	var u := ExamTimer.from_dict(t.to_dict())
	watch_signals(u)
	u.advance(1.0)
	assert_signal_not_emitted(u, "warning")

func test_restored_grace_phase() -> void:
	var t := _t(100.0, 90.0)
	t.advance(130.0)
	var u := ExamTimer.from_dict(t.to_dict())
	assert_eq(u.phase(), ExamTimer.Phase.GRACE)
	assert_almost_eq(u.grace_remaining(), 60.0, 0.001)
