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
	assert_eq(parts[0].points[0], Vector2(0, 0))
	assert_almost_eq(parts[0].points[parts[0].points.size() - 1].x, 42.0, 2.01)
	assert_almost_eq(parts[1].points[0].x, 58.0, 2.01)
	assert_eq(parts[1].points[parts[1].points.size() - 1], Vector2(100, 0))
	assert_eq(parts[0].widths.size(), parts[0].points.size())
	assert_eq(parts[0].id, -1)

func test_erase_miss_returns_original_shape() -> void:
	var parts := InkGeometry.erase(_line_stroke(), Vector2(50, 100), 8.0)
	assert_eq(parts.size(), 1)
	assert_eq(parts[0].points.size(), 11)

func test_erase_removes_all() -> void:
	assert_eq(InkGeometry.erase(_line_stroke(), Vector2(50, 0), 1000.0).size(), 0)

func test_erase_drops_single_point_runs() -> void:
	var parts := InkGeometry.erase(_line_stroke(), Vector2(10, 0), 4.0)
	var all: Array[Stroke] = []
	for p in parts:
		all.append_array(InkGeometry.erase(p, Vector2(30, 0), 4.0))
	assert_eq(all.size(), 3)
	for p in all:
		assert_gt(p.points.size(), 1)
		for pt in p.points:
			assert_gt(pt.distance_to(Vector2(10, 0)), 4.0)
			assert_gt(pt.distance_to(Vector2(30, 0)), 4.0)

func test_hits_stroke() -> void:
	var s := _line_stroke()
	assert_true(InkGeometry.hits(s, Vector2(55, 3), 6.0))
	assert_false(InkGeometry.hits(s, Vector2(55, 30), 6.0))

func test_text_hit_by_glyph_centers() -> void:
	var centers := PackedVector2Array([Vector2(10, 10), Vector2(20, 10), Vector2(30, 10)])
	assert_eq(InkGeometry.text_hit(centers, Vector2(21, 10), 4.0), PackedInt32Array([1]))

func test_erase_middle_of_sparse_stroke() -> void:
	# A quick stroke sampled every 15 pt: erasing its middle must cut it.
	var s := Stroke.new()
	s.points = PackedVector2Array([Vector2(0, 0), Vector2(15, 0), Vector2(30, 0)])
	s.widths = PackedFloat32Array([1, 1, 1])
	var parts := InkGeometry.erase(s, Vector2(22.5, 0), 4.0)
	assert_eq(parts.size(), 2)
	for p in parts:
		for pt in p.points:
			assert_gt(pt.distance_to(Vector2(22.5, 0)), 4.0)

func test_erase_miss_keeps_stroke_unchanged() -> void:
	var s := Stroke.new()
	s.points = PackedVector2Array([Vector2(0, 0), Vector2(30, 0)])
	s.widths = PackedFloat32Array([1, 1])
	var parts := InkGeometry.erase(s, Vector2(15, 20), 4.0)
	assert_eq(parts.size(), 1)
	assert_eq(parts[0].points, s.points)
