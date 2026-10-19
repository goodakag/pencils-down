extends GutTest

func _stroke() -> Stroke:
	var s := Stroke.new()
	s.id = 3
	s.tool = Stroke.Tool.PENCIL
	s.points = PackedVector2Array([Vector2(1.234, 5.678), Vector2(10.5, 20.25), Vector2(30, 40)])
	s.widths = PackedFloat32Array([0.9, 1.0, 0.8])
	s.t_start = 12.5
	return s

func test_stroke_round_trip() -> void:
	var s := _stroke()
	var r := Stroke.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	assert_eq(r.id, 3)
	assert_eq(r.tool, Stroke.Tool.PENCIL)
	assert_eq(r.points.size(), 3)
	assert_almost_eq(r.points[0], Vector2(1.23, 5.68), Vector2(0.011, 0.011))
	assert_almost_eq(r.widths[1], 1.0, 0.011)
	assert_eq(r.t_start, 12.5)

func test_text_round_trip_unicode() -> void:
	var t := TextMark.new()
	t.id = 1
	t.origin = Vector2(72, 100)
	t.size_pt = 14.0
	t.font_id = &"caveat"
	t.text = "x² + √2 ≤ π"
	t.seed = 99
	var r := TextMark.from_dict(JSON.parse_string(JSON.stringify(t.to_dict())))
	assert_eq(r.text, "x² + √2 ≤ π")
	assert_eq(r.font_id, &"caveat")
	assert_eq(r.seed, 99)
	assert_eq(r.origin, Vector2(72, 100))

func test_page_ink_empty_and_ids() -> void:
	var p := PageInk.new()
	assert_true(p.is_empty())
	var a := p.next_id()
	var b := p.next_id()
	assert_ne(a, b)
	p.strokes.append(_stroke())
	assert_false(p.is_empty())

func test_attempt_round_trip() -> void:
	var a := Attempt.new()
	a.id = "100-abcdef"
	a.pdf_path = "C:/tests/x.pdf"
	a.pdf_sha1 = "a".repeat(40)
	a.test_title = "Unit 3"
	a.page_sizes_pt = [Vector2(612, 792), Vector2(595.28, 841.89)]
	a.pages = [PageInk.new(), PageInk.new()]
	a.pages[0].strokes.append(_stroke())
	a.scratch = [PageInk.new()]
	a.options = {"duration_s": 3600.0, "mode": "practice"}
	a.created_unix = 100
	a.timer_state = {"elapsed": 12.0}
	a.page_time_s = PackedFloat32Array([5.0, 7.0])
	a.erase_count = 4
	a.finished = true
	var r := Attempt.from_dict(JSON.parse_string(JSON.stringify(a.to_dict())))
	assert_eq(r.pages.size(), 2)
	assert_eq(r.scratch.size(), 1)
	assert_eq(r.pages[0].strokes.size(), 1)
	assert_eq(r.options.mode, "practice")
	assert_eq(r.timer_state.elapsed, 12.0)
	assert_almost_eq(r.page_sizes_pt[1], Vector2(595.28, 841.89), Vector2(0.01, 0.01))
	assert_eq(r.page_time_s[1], 7.0)
	assert_eq(r.erase_count, 4)
	assert_true(r.finished)
	assert_eq(r.test_title, "Unit 3")

func test_create_from_doc() -> void:
	var doc := PdfDoc.open(ProjectSettings.globalize_path("res://tests/fixtures/mc_letter.pdf"))
	var a := Attempt.create(doc, {"scratch_sheets": 2})
	assert_eq(a.pages.size(), 2)
	assert_eq(a.scratch.size(), 2)
	assert_eq(a.page_time_s.size(), 2)
	assert_eq(a.test_title, "Fixture Test")
	assert_eq(a.pdf_sha1, doc.sha1)
	assert_true(a.id.contains("-"))
