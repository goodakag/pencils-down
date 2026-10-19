extends GutTest

func test_turn_bounds() -> void:
	var s := PacketState.new(3, 1)
	assert_false(s.turn(-1))
	assert_true(s.turn(1))
	assert_true(s.turn(1))
	assert_eq(s.current, 2)
	assert_false(s.turn(1))

func test_turn_emits_changed() -> void:
	var s := PacketState.new(3, 0)
	watch_signals(s)
	s.turn(1)
	assert_signal_emitted(s, "changed")

func test_jump() -> void:
	var s := PacketState.new(5, 0)
	assert_true(s.jump(4))
	assert_eq(s.current, 4)
	assert_false(s.jump(5))
	assert_false(s.jump(-1))

func test_toggle_scratch_no_sheets() -> void:
	var s := PacketState.new(3, 0)
	s.toggle_scratch()
	assert_false(s.showing_scratch)

func test_active_target_scratch() -> void:
	var s := PacketState.new(3, 1)
	assert_eq(s.active_target(), {"kind": "page", "index": 0})
	s.toggle_scratch()
	assert_eq(s.active_target(), {"kind": "scratch", "index": 0})
	assert_eq(s.active_key(), "scratch:0")

func test_turn_while_on_scratch_cycles_sheets() -> void:
	var s := PacketState.new(3, 2)
	s.toggle_scratch()
	assert_true(s.turn(1))
	assert_eq(s.active_key(), "scratch:1")
	assert_eq(s.current, 0)
