extends GutTest

const S := SessionMachine.State

func test_happy_path() -> void:
	var m := SessionMachine.new()
	watch_signals(m)
	for s in [S.PRETEST, S.SETTLING, S.TESTING, S.GRACE, S.HANDING_IN, S.REVIEW, S.MENU]:
		assert_true(m.transition_to(s), "to %s" % S.keys()[s])
	assert_eq(m.state, S.MENU)
	assert_signal_emit_count(m, "state_changed", 7)

func test_rejects_skip() -> void:
	var m := SessionMachine.new()
	m.transition_to(S.PRETEST)
	watch_signals(m)
	assert_false(m.transition_to(S.TESTING))
	assert_eq(m.state, S.PRETEST)
	assert_signal_not_emitted(m, "state_changed")

func test_resume_from_menu_to_testing() -> void:
	var m := SessionMachine.new()
	assert_true(m.transition_to(S.TESTING))

func test_early_hand_in_from_testing() -> void:
	var m := SessionMachine.new()
	m.transition_to(S.TESTING)
	assert_true(m.transition_to(S.HANDING_IN))

func test_retake() -> void:
	var m := SessionMachine.new()
	for s in [S.PRETEST, S.SETTLING, S.TESTING, S.HANDING_IN, S.REVIEW]:
		m.transition_to(s)
	assert_true(m.transition_to(S.PRETEST))

func test_abort_from_testing() -> void:
	var m := SessionMachine.new()
	m.transition_to(S.TESTING)
	watch_signals(m)
	m.abort()
	assert_eq(m.state, S.MENU)
	assert_signal_emitted_with_parameters(m, "state_changed", [S.TESTING, S.MENU])
