extends GutTest

const OUT := "user://fallback_test/"

func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))

func _img(w: int, h: int, c: Color) -> Image:
	var i := Image.create(w, h, false, Image.FORMAT_RGBA8)
	i.fill(c)
	return i

func test_rasterize_text_draws_inside_line() -> void:
	var img := Image.create(612, 792, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var g := HandwritingLayout.layout("Hi", Vector2(72, 100), 20.0, &"caveat", 1, 1000.0)
	InkRasterizer.rasterize_text(img, g, 20.0, 72.0, Color.BLACK)
	var hit := false
	for y in range(80, 104):
		for x in range(72, 102):
			if img.get_pixel(x, y).a > 0.5:
				hit = true
	assert_true(hit)
	assert_eq(img.get_pixel(300, 300).a, 0.0)

func test_writes_openable_pdf() -> void:
	var path := ProjectSettings.globalize_path(OUT + "two.pdf")
	var sizes: Array[Vector2] = [Vector2(612, 792), Vector2(595.28, 841.89)]
	var pages: Array[Image] = [_img(200, 300, Color.WHITE), _img(200, 300, Color(0.3, 0.3, 0.3))]
	assert_eq(FallbackPdfWriter.write(pages, sizes, path), OK)
	var d := PdfDoc.open(path)
	assert_not_null(d)
	assert_eq(d.page_count(), 2)
	assert_almost_eq(d.page_size_pt(0), Vector2(612, 792), Vector2(1, 1))
	assert_almost_eq(d.page_size_pt(1), Vector2(595.28, 841.89), Vector2(1, 1))
	assert_lt(d.render_page(1, 72.0).get_pixel(100, 100).get_luminance(), 0.7)

func test_header_and_eof() -> void:
	var path := ProjectSettings.globalize_path(OUT + "h.pdf")
	var sizes: Array[Vector2] = [Vector2(612, 792)]
	var pages: Array[Image] = [_img(50, 60, Color.WHITE)]
	FallbackPdfWriter.write(pages, sizes, path)
	var bytes := FileAccess.get_file_as_bytes(path)
	assert_eq(bytes.slice(0, 8).get_string_from_ascii(), "%PDF-1.4")
	assert_true(bytes.slice(bytes.size() - 8).get_string_from_ascii().strip_edges().ends_with("%%EOF"))

func test_xref_offsets_point_at_objects() -> void:
	var path := ProjectSettings.globalize_path(OUT + "x.pdf")
	var sizes: Array[Vector2] = [Vector2(612, 792)]
	var pages: Array[Image] = [_img(50, 60, Color.WHITE)]
	FallbackPdfWriter.write(pages, sizes, path)
	var bytes := FileAccess.get_file_as_bytes(path)
	var tail := bytes.slice(bytes.size() - 64).get_string_from_ascii()
	var start := int(tail.split("startxref")[1].strip_edges().split("\n")[0])
	var xref := bytes.slice(start, start + 400).get_string_from_ascii()
	var lines := xref.split("\n")
	var count := int(lines[1].split(" ")[1])
	for n in range(1, count):
		var off := int(lines[2 + n].substr(0, 10))
		assert_eq(bytes.slice(off, off + 12).get_string_from_ascii().begins_with("%d 0 obj" % n), true, "object %d" % n)

func test_exporter_image_mode_produces_marks() -> void:
	var doc := PdfDoc.open(ProjectSettings.globalize_path("res://tests/fixtures/mixed_sizes.pdf"))
	var a := Attempt.create(doc, {"scratch_sheets": 1})
	var s := Stroke.new()
	s.points = PackedVector2Array([Vector2(100, 100), Vector2(140, 100)])
	s.widths = PackedFloat32Array([4.0, 4.0])
	a.pages[2].strokes.append(s)
	a.scratch[0].strokes.append(s)
	var path := ProjectSettings.globalize_path(OUT + "img.pdf")
	var r := PdfExporter.export_images(doc, a, path)
	assert_true(r.ok, str(r))
	assert_eq(r.mode, "images")
	var out := PdfDoc.open(path)
	assert_eq(out.page_count(), 4)
	assert_almost_eq(out.page_size_pt(2), Vector2(792, 612), Vector2(1, 1))
	assert_lt(out.render_page(2, 72.0).get_pixel(120, 100).get_luminance(), 0.5)
