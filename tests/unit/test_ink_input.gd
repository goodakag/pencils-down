extends GutTest

func test_ink_input_builds_stroke() -> void:
	var i := InkInput.new()
	i.begin("page:0", Vector2(10, 10), 0.0, 1.0)
	i.move(Vector2(12, 10), 0.01, 1.0)
	i.move(Vector2(14, 11), 0.02, 1.0)
	i.move(Vector2(16, 12), 0.03, 1.0)
	assert_true(i.is_active())
	var s := i.end()
	assert_eq(s.points.size(), 4)
	assert_eq(s.widths.size(), 4)
	for w in s.widths:
		assert_between(w, 0.6, 1.1)
	assert_false(i.is_active())
	assert_eq(i.page_key, "page:0")

func test_ink_input_skips_tiny_moves() -> void:
	var i := InkInput.new()
	i.begin("page:0", Vector2(10, 10), 0.0, 1.0)
	i.move(Vector2(10.05, 10), 0.01, 1.0)
	i.move(Vector2(13, 10), 0.02, 1.0)
	assert_eq(i.end().points.size(), 2)

func test_ink_input_single_click_is_null() -> void:
	var i := InkInput.new()
	i.begin("page:0", Vector2(10, 10), 0.0, 1.0)
	assert_null(i.end())

func test_cancel_discards() -> void:
	var i := InkInput.new()
	i.begin("page:0", Vector2(10, 10), 0.0, 1.0)
	i.move(Vector2(20, 10), 0.1, 1.0)
	i.cancel()
	assert_false(i.is_active())
	assert_null(i.end())

func test_focus_loss_ends_stroke() -> void:
	var i := InkInput.new()
	i.begin("page:0", Vector2(10, 10), 0.0, 1.0)
	i.move(Vector2(15, 10), 0.01, 1.0)
	i.move(Vector2(20, 10), 0.02, 1.0)
	var s := PlayerRig.on_focus_lost(i)
	assert_eq(s.points.size(), 3)
	assert_false(i.is_active())
