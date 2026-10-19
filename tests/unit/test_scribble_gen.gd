extends GutTest

const RECT := Rect2(100, 100, 14, 14)

func test_scribble_is_pencil_with_widths() -> void:
	var s := ScribbleGen.scribble_for(RECT, 3)
	assert_eq(s.tool, Stroke.Tool.PENCIL)
	assert_gt(s.points.size(), 10)
	assert_eq(s.widths.size(), s.points.size())

func test_scribble_points_inside_rect() -> void:
	for p in ScribbleGen.scribble_for(RECT, 3).points:
		assert_true(RECT.grow(-0.5).has_point(p), str(p))

func test_scribble_stays_inside_and_covers() -> void:
	var ink := PageInk.new()
	ink.strokes.append(ScribbleGen.scribble_for(RECT, 3))
	var dpi := 144.0
	var k := dpi / 72.0
	var img := InkRasterizer.rasterize(ink, Vector2(300, 300), dpi)
	var inside := 0
	var covered := 0
	var c := RECT.get_center() * k
	var rx := RECT.size.x * 0.5 * k
	var outer := RECT.grow(1.0)
	for y in range(int((RECT.position.y - 3) * k), int((RECT.end.y + 3) * k)):
		for x in range(int((RECT.position.x - 3) * k), int((RECT.end.x + 3) * k)):
			var p := Vector2(x + 0.5, y + 0.5)
			var a := img.get_pixel(x, y).a
			if ((p - c) / rx).length() <= 1.0:
				inside += 1
				if a > 0.5:
					covered += 1
			if not outer.has_point(p / k):
				assert_eq(a, 0.0, "outside at %s" % p)
	assert_gte(float(covered) / inside, 0.85)

func test_scribble_deterministic() -> void:
	assert_eq(ScribbleGen.scribble_for(RECT, 9).points, ScribbleGen.scribble_for(RECT, 9).points)
