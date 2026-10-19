extends GutTest

func test_edge_look_needs_dwell() -> void:
	var e := EdgeLook.new()
	assert_false(e.update(0.01, 0.2))
	assert_true(e.update(0.01, 0.2))

func test_edge_look_resets_when_leaving() -> void:
	var e := EdgeLook.new()
	e.update(0.01, 0.2)
	e.update(0.5, 0.1)
	assert_false(e.update(0.01, 0.2))

func test_edge_look_outside_band() -> void:
	var e := EdgeLook.new()
	assert_false(e.update(0.05, 1.0))

func test_edge_look_disabled() -> void:
	var e := EdgeLook.new()
	e.enabled = false
	assert_false(e.update(0.0, 1.0))
