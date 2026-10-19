extends GutTest

func _line_stroke() -> Stroke:
	var s := Stroke.new()
	for i in 11:
		s.points.append(Vector2(i * 10, 0))
		s.widths.append(1.0)
	return s

func test_smooth_keeps_endpoints() -> void:
	var src := PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(10, 10)])
	var out := InkGeometry.smooth(src)
	assert_gt(out.size(), src.size())
	assert_eq(out[0], src[0])
	assert_eq(out[out.size() - 1], src[2])

func test_smooth_passthrough_short() -> void:
	var src := PackedVector2Array([Vector2(0, 0), Vector2(5, 5)])
	assert_eq(InkGeometry.smooth(src), src)

func test_width_slower_is_thicker() -> void:
	assert_almost_eq(InkGeometry.width_for_speed(0.0), 1.035, 0.001)
	assert_almost_eq(InkGeometry.width_for_speed(800.0), 0.63, 0.001)

func test_width_scales_with_pressure() -> void:
	assert_almost_eq(InkGeometry.width_for_speed(0.0, 0.9, 0.5), 0.5175, 0.001)

func test_erase_splits_middle() -> void:
	var parts := InkGeometry.erase(_line_stroke(), Vector2(50, 0), 8.0)
	assert_eq(parts.size(), 2)
	assert_eq(parts[0].points.size(), 5)
	assert_eq(parts[0].points[4], Vector2(40, 0))
	assert_eq(parts[1].points[0], Vector2(60, 0))
	assert_eq(parts[1].points.size(), 5)
	assert_eq(parts[0].widths.size(), 5)
	assert_eq(parts[0].id, -1)

func test_erase_miss_returns_original_shape() -> void:
	var parts := InkGeometry.erase(_line_stroke(), Vector2(50, 100), 8.0)
	assert_eq(parts.size(), 1)
	assert_eq(parts[0].points.size(), 11)

func test_erase_removes_all() -> void:
	assert_eq(InkGeometry.erase(_line_stroke(), Vector2(50, 0), 1000.0).size(), 0)

func test_erase_drops_single_point_runs() -> void:
	# Erase 10 and 30: the lone point at 20 between them is dropped; 0 alone is dropped.
	var s := _line_stroke()
	var parts := InkGeometry.erase(s, Vector2(10, 0), 4.0)
	parts = InkGeometry.erase(parts[parts.size() - 1], Vector2(30, 0), 4.0)
	for p in parts:
		assert_gt(p.points.size(), 1)
	assert_eq(parts.size(), 1)
	assert_eq(parts[0].points[0], Vector2(40, 0))

func test_hits_stroke() -> void:
	var s := _line_stroke()
	assert_true(InkGeometry.hits(s, Vector2(55, 3), 6.0))
	assert_false(InkGeometry.hits(s, Vector2(55, 30), 6.0))

func test_text_hit_by_glyph_centers() -> void:
	var centers := PackedVector2Array([Vector2(10, 10), Vector2(20, 10), Vector2(30, 10)])
	assert_eq(InkGeometry.text_hit(centers, Vector2(21, 10), 4.0), PackedInt32Array([1]))
