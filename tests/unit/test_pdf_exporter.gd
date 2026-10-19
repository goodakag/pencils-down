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
