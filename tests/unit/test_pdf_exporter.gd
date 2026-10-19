extends GutTest

const F := "res://tests/fixtures/"
const OUT := "user://export_test/"

func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))

func _doc(name: String) -> PdfDoc:
	return PdfDoc.open(ProjectSettings.globalize_path(F + name))

func _line(a: Vector2, b: Vector2, w: float) -> Stroke:
	var s := Stroke.new()
	s.id = 1
	s.points = PackedVector2Array([a, b])
	s.widths = PackedFloat32Array([w, w])
	return s

func _out(name: String) -> String:
	return ProjectSettings.globalize_path(OUT + name)

func _lum(img: Image, x: int, y: int) -> float:
	return img.get_pixel(x, y).get_luminance()

func test_export_adds_no_pages_without_scratch() -> void:
	var doc := _doc("mc_letter.pdf")
	var a := Attempt.create(doc, {"scratch_sheets": 0})
	a.pages[0].strokes.append(_line(Vector2(300, 300), Vector2(340, 300), 2.0))
	var r := PdfExporter.export(doc, a, _out("a.pdf"))
	assert_true(r.ok, str(r))
	assert_eq(PdfDoc.open(_out("a.pdf")).page_count(), 2)

func test_export_appends_scratch_with_ink() -> void:
	var doc := _doc("mc_letter.pdf")
	var a := Attempt.create(doc, {"scratch_sheets": 2})
	a.scratch[0].strokes.append(_line(Vector2(100, 100), Vector2(200, 100), 2.0))
	var r := PdfExporter.export(doc, a, _out("b.pdf"))
	assert_true(r.ok, str(r))
	var out := PdfDoc.open(_out("b.pdf"))
	assert_eq(out.page_count(), 3)
	var img := out.render_page(2, 72.0)
	assert_lt(_lum(img, 150, 100), 0.6)

func test_mark_lands_at_same_point_on_mixed_pages() -> void:
	var doc := _doc("mixed_sizes.pdf")
	var a := Attempt.create(doc, {"scratch_sheets": 0})
	for p in a.pages:
		p.strokes.append(_line(Vector2(100, 100), Vector2(140, 100), 4.0))
	var r := PdfExporter.export(doc, a, _out("c.pdf"))
	assert_true(r.ok, str(r))
	var out := PdfDoc.open(_out("c.pdf"))
	for i in out.page_count():
		var img := out.render_page(i, 72.0)
		assert_lt(_lum(img, 120, 100), 0.5, "page %d mark" % i)
		assert_gt(_lum(img, 120, 110), 0.9, "page %d clean below" % i)

func test_typed_text_is_real_text() -> void:
	var doc := _doc("mc_letter.pdf")
	var a := Attempt.create(doc, {"scratch_sheets": 0})
	var t := TextMark.new()
	t.id = 2
	t.origin = Vector2(300, 700)
	t.size_pt = 16.0
	t.text = "cm per second"
	t.seed = 3
	a.pages[0].texts.append(t)
	var r := PdfExporter.export(doc, a, _out("d.pdf"))
	assert_true(r.ok, str(r))
	var found := ""
	for w in PdfDoc.open(_out("d.pdf")).text_words(0):
		if (w.rect as Rect2).get_center().distance_to(Vector2(340, 695)) < 60.0:
			found += String(w.text)
	assert_string_contains(found.replace(" ", ""), "cmpersecond")

func test_unicode_out_path() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + "Zoë Документы"))
	var doc := _doc("mc_letter.pdf")
	var a := Attempt.create(doc, {"scratch_sheets": 0})
	a.pages[0].strokes.append(_line(Vector2(300, 300), Vector2(340, 300), 2.0))
	var r := PdfExporter.export(doc, a, _out("Zoë Документы/out.pdf"))
	assert_true(r.ok, str(r))
	assert_true(FileAccess.file_exists(_out("Zoë Документы/out.pdf")))

func test_refuses_overwriting_source() -> void:
	var doc := _doc("mc_letter.pdf")
	var a := Attempt.create(doc, {"scratch_sheets": 0})
	var r := PdfExporter.export(doc, a, doc.path)
	assert_false(r.ok)
	assert_eq(r.error, "same_as_source")

func test_source_file_unchanged() -> void:
	var doc := _doc("mc_letter.pdf")
	var before := doc.sha1
	var a := Attempt.create(doc, {"scratch_sheets": 0})
	a.pages[0].strokes.append(_line(Vector2(300, 300), Vector2(340, 300), 2.0))
	PdfExporter.export(doc, a, _out("e.pdf"))
	assert_eq(PdfDoc.open(doc.path).sha1, before)

func test_golden_page() -> void:
	var got := GoldenFixture.render(_out("golden.pdf"))
	var want := Image.load_from_file(ProjectSettings.globalize_path(GoldenFixture.GOLDEN))
	assert_eq(got.get_size(), want.get_size())
	got.convert(Image.FORMAT_RGBA8)
	want.convert(Image.FORMAT_RGBA8)
	var a := got.get_data()
	var b := want.get_data()
	var total := 0
	for i in a.size():
		total += absi(a[i] - b[i])
	var mean := float(total) / a.size()
	gut.p("golden mean abs diff: %.3f" % mean)
	assert_lt(mean, 2.0)

func test_typed_answers_keep_file_small() -> void:
	var doc := _doc("mc_letter.pdf")
	var base := FileAccess.get_file_as_bytes(doc.path).size()
	var a := Attempt.create(doc, {"scratch_sheets": 0})
	for i in 5:
		var t := TextMark.new()
		t.id = i + 1
		t.origin = Vector2(290, 120 + i * 66)
		t.size_pt = 15.0
		t.text = "x = 7 because 3(7) - 2 = 19"
		t.seed = i
		a.pages[0].texts.append(t)
	var r := PdfExporter.export(doc, a, _out("small.pdf"))
	assert_true(r.ok, str(r))
	var added := FileAccess.get_file_as_bytes(_out("small.pdf")).size() - base
	gut.p("5 typed answers added %d bytes" % added)
	assert_lt(added, 400_000)

func test_marks_land_correctly_on_rotated_pages() -> void:
	var doc := _doc("rotated.pdf")
	var a := Attempt.create(doc, {"scratch_sheets": 0})
	for p in a.pages:
		p.strokes.append(_line(Vector2(100, 100), Vector2(160, 100), 4.0))
	var r := PdfExporter.export(doc, a, _out("rot.pdf"))
	assert_true(r.ok, str(r))
	var out := PdfDoc.open(_out("rot.pdf"))
	for i in out.page_count():
		var img := out.render_page(i, 72.0)
		assert_lt(_lum(img, 130, 100), 0.5, "page %d: mark at (130,100) as drawn" % i)
		assert_gt(_lum(img, 100, 130), 0.85, "page %d: not rotated into a vertical line" % i)

func test_typed_text_lands_on_rotated_page() -> void:
	var doc := _doc("rotated.pdf")
	var a := Attempt.create(doc, {"scratch_sheets": 0})
	for p in a.pages:
		var t := TextMark.new()
		t.origin = Vector2(400, 300)
		t.size_pt = 20.0
		t.text = "HHHH"
		p.texts.append(t)
	PdfExporter.export(doc, a, _out("rot_text.pdf"))
	var out := PdfDoc.open(_out("rot_text.pdf"))
	for i in out.page_count():
		var img := out.render_page(i, 72.0)
		var dark := 0
		for y in range(284, 300):
			for x in range(402, 450):
				if _lum(img, x, y) < 0.5:
					dark += 1
		assert_gt(dark, 20, "page %d: handwriting drawn where it was typed" % i)

func test_math_symbols_survive_in_text_layer() -> void:
	var doc := _doc("mc_letter.pdf")
	var a := Attempt.create(doc, {"scratch_sheets": 0})
	var t := TextMark.new()
	t.origin = Vector2(72, 700)
	t.size_pt = 16.0
	t.text = "x² + √2 ≤ π θ café"
	a.pages[0].texts.append(t)
	PdfExporter.export(doc, a, _out("math.pdf"))
	var found := ""
	for w in PdfDoc.open(_out("math.pdf")).text_words(0):
		if (w.rect as Rect2).position.y > 650:
			found += String(w.text) + " "
	assert_string_contains(found, "sqrt")
	assert_string_contains(found, "<=")
	assert_string_contains(found, "pi")
	assert_string_contains(found, "theta")
	assert_string_contains(found, "café")
	assert_false(found.contains("ÿ"), "no garbled characters: " + found)

func test_plain_text_for_ai_transliterates() -> void:
	assert_eq(PdfExporter.plain_text("√2 ≤ π"), "sqrt2 <= pi")
	assert_eq(PdfExporter.plain_text("x² café"), "x² café")
	assert_eq(PdfExporter.plain_text("∑ ♞"), "sum [U+265E]")
