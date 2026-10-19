extends GutTest

func _ink_with(points: Array, width: float) -> PageInk:
	var ink := PageInk.new()
	var s := Stroke.new()
	for p in points:
		s.points.append(p)
		s.widths.append(width)
	ink.strokes.append(s)
	return ink

func _alpha(img: Image, x: int, y: int) -> float:
	return img.get_pixel(x, y).a

func test_size_matches_dpi() -> void:
	var img := InkRasterizer.rasterize(PageInk.new(), Vector2(612, 792), 300.0)
	assert_eq(img.get_size(), Vector2i(2550, 3300))
	assert_eq(img.get_format(), Image.FORMAT_RGBA8)

func test_empty_is_transparent() -> void:
	var img := InkRasterizer.rasterize(PageInk.new(), Vector2(100, 100), 72.0)
	assert_eq(_alpha(img, 50, 50), 0.0)

func test_stroke_pixels_land_at_point_coordinates() -> void:
	var img := InkRasterizer.rasterize(_ink_with([Vector2(72, 72), Vector2(144, 72)], 4.0), Vector2(612, 792), 72.0)
	assert_gte(_alpha(img, 108, 72), 0.85)
	assert_eq(_alpha(img, 108, 80), 0.0)
	var c := img.get_pixel(108, 72)
	assert_almost_eq(c.r, Color("#3B3A3C").r, 0.01)

func test_dpi_scales_position() -> void:
	var img := InkRasterizer.rasterize(_ink_with([Vector2(72, 72), Vector2(144, 72)], 4.0), Vector2(612, 792), 144.0)
	assert_gte(_alpha(img, 216, 144), 0.85)

func test_max_alpha_not_additive() -> void:
	var ink := _ink_with([Vector2(72, 72), Vector2(144, 72)], 4.0)
	ink.strokes.append(ink.strokes[0])
	var img := InkRasterizer.rasterize(ink, Vector2(612, 792), 72.0)
	assert_lte(_alpha(img, 108, 72), 0.93)

func test_strokes_outside_page_are_clipped() -> void:
	var img := InkRasterizer.rasterize(_ink_with([Vector2(-50, 10), Vector2(700, 10)], 4.0), Vector2(612, 792), 72.0)
	assert_gte(_alpha(img, 300, 10), 0.85)

func test_perf_full_page() -> void:
	var ink := PageInk.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	for i in 200:
		var s := Stroke.new()
		var p := Vector2(rng.randf_range(50, 550), rng.randf_range(50, 740))
		for j in 50:
			p += Vector2(rng.randf_range(-3, 3), rng.randf_range(-3, 3))
			s.points.append(p)
			s.widths.append(1.0)
		ink.strokes.append(s)
	var t0 := Time.get_ticks_msec()
	InkRasterizer.rasterize(ink, Vector2(612, 792), 300.0)
	var ms := Time.get_ticks_msec() - t0
	gut.p("full-page rasterize: %d ms" % ms)
	assert_lt(ms, 1500)
