extends GutTest

const F := "res://tests/fixtures/"

func _p(rel: String) -> String:
	return ProjectSettings.globalize_path(F + rel)

func test_opens_and_counts_pages() -> void:
	var d := PdfDoc.open(_p("mc_letter.pdf"))
	assert_not_null(d)
	assert_eq(d.page_count(), 2)
	assert_eq(d.title(), "Fixture Test")

func test_page_sizes_in_points() -> void:
	var d := PdfDoc.open(_p("mixed_sizes.pdf"))
	assert_almost_eq(d.page_size_pt(0), Vector2(595.28, 841.89), Vector2(1, 1))
	assert_almost_eq(d.page_size_pt(1), Vector2(612, 792), Vector2(1, 1))
	assert_almost_eq(d.page_size_pt(2), Vector2(792, 612), Vector2(1, 1))

func test_render_dpi_controls_pixel_size() -> void:
	var d := PdfDoc.open(_p("mc_letter.pdf"))
	var img := d.render_page(0, 144.0)
	assert_almost_eq(img.get_width(), 1224, 2)
	assert_almost_eq(img.get_height(), 1584, 2)
	assert_eq(img.get_format(), Image.FORMAT_RGBA8)

func test_encrypted_reports_encrypted() -> void:
	assert_null(PdfDoc.open(_p("encrypted.pdf")))
	assert_eq(PdfDoc.last_error, "encrypted")
	assert_engine_error("password")

func test_corrupt_reports_corrupt() -> void:
	assert_null(PdfDoc.open(_p("corrupt.pdf")))
	assert_eq(PdfDoc.last_error, "corrupt")
	assert_engine_error("not a valid PDF")

func test_missing_reports_not_found() -> void:
	assert_null(PdfDoc.open("C:/nope/none.pdf"))
	assert_eq(PdfDoc.last_error, "not_found")

func test_unicode_path_opens() -> void:
	var d := PdfDoc.open(_p("unicode/Zoë Документы/mc.pdf"))
	assert_not_null(d)
	assert_eq(d.page_count(), 2)

func test_sha1_is_stable() -> void:
	var p := _p("mc_letter.pdf")
	assert_eq(PdfDoc.open(p).sha1, PdfDoc.open(p).sha1)
	assert_eq(PdfDoc.open(p).sha1.length(), 40)

func test_text_words_have_letters_and_rects() -> void:
	var d := PdfDoc.open(_p("mc_letter.pdf"))
	var words := d.text_words(0)
	var found := false
	for w in words:
		if w.text == "A" and (w.rect as Rect2).get_center().distance_to(Vector2(100, 110)) < 6.0:
			found = true
	assert_true(found, "bubble letter A of question 1 at (100,110)")
	assert_eq(d.text_boxes(0).size(), words.size())

func test_service_mirrors_last_error() -> void:
	assert_null(PdfService.open(_p("corrupt.pdf")))
	assert_eq(PdfService.last_error, "corrupt")
	assert_engine_error("not a valid PDF")
