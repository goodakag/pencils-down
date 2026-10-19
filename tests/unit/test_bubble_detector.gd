extends GutTest

func _word(text: String, r: Rect2) -> Dictionary:
	return {"text": text, "rect": r}

func _ring_image(center_px: Vector2, r_px: float) -> Image:
	var img := Image.create(300, 300, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	for i in 720:
		var a := TAU * i / 720.0
		for dr in [-0.75, 0.0, 0.75]:
			var p := center_px + Vector2(cos(a), sin(a)) * (r_px + float(dr))
			img.set_pixel(int(p.x), int(p.y), Color(0.15, 0.15, 0.15))
	return img

func test_text_word_snap() -> void:
	var r := BubbleDetector.from_text_words([_word("B", Rect2(100, 200, 8, 10))], Vector2(103, 204))
	assert_almost_eq(r.get_center(), Vector2(104, 205), Vector2(0.01, 0.01))
	assert_almost_eq(r.size, Vector2(16, 16), Vector2(0.01, 0.01))

func test_text_word_ignored_when_far() -> void:
	assert_eq(BubbleDetector.from_text_words([_word("B", Rect2(100, 200, 8, 10))], Vector2(143, 244)), Rect2())

func test_text_word_ignores_long_words() -> void:
	assert_eq(BubbleDetector.from_text_words([_word("Box", Rect2(100, 200, 18, 10))], Vector2(103, 204)), Rect2())

func test_image_detects_drawn_circle() -> void:
	var r := BubbleDetector.from_image(_ring_image(Vector2(150, 150), 20.0), 2.0, Vector2(74, 76))
	assert_almost_eq(r.get_center(), Vector2(75, 75), Vector2(1.5, 1.5))
	assert_almost_eq(r.size.x, 20.0, 2.0)

func test_image_none_on_blank() -> void:
	var img := Image.create(300, 300, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	assert_eq(BubbleDetector.from_image(img, 2.0, Vector2(75, 75)), Rect2())

func test_find_falls_back_to_9mm() -> void:
	var img := Image.create(300, 300, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	var r := BubbleDetector.find([], img, 2.0, Vector2(70, 80))
	assert_almost_eq(r.size, Vector2(25.51, 25.51), Vector2(0.01, 0.01))
	assert_almost_eq(r.get_center(), Vector2(70, 80), Vector2(0.01, 0.01))

func test_fixture_mc_letter_snaps() -> void:
	var doc := PdfDoc.open(ProjectSettings.globalize_path("res://tests/fixtures/mc_letter.pdf"))
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/mc_letter.json"))
	var b: Dictionary = meta.bubbles[0]
	var c := Vector2(b.center[0], b.center[1])
	var img := doc.render_page(0, 144.0)
	var r := BubbleDetector.find(doc.text_words(0), img, 2.0, c + Vector2(2, -1))
	assert_almost_eq(r.get_center(), c, Vector2(2, 2))
	assert_almost_eq(r.size.x, b.r * 2.0, 2.0)

func test_fixture_scanned_uses_image() -> void:
	var doc := PdfDoc.open(ProjectSettings.globalize_path("res://tests/fixtures/scanned.pdf"))
	assert_eq(doc.text_words(0).size(), 0)
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/scanned.json"))
	var circle: Dictionary = meta.circles[1]
	var c := Vector2(circle.center[0], circle.center[1])
	var r := BubbleDetector.find([], doc.render_page(0, 144.0), 2.0, c + Vector2(-2, 2))
	assert_almost_eq(r.get_center(), c, Vector2(2, 2))
	assert_almost_eq(r.size.x, circle.r * 2.0, 2.5)

func test_detection_is_fast() -> void:
	var img := _ring_image(Vector2(150, 150), 20.0)
	var t0 := Time.get_ticks_msec()
	BubbleDetector.from_image(img, 2.0, Vector2(74, 76))
	assert_lt(Time.get_ticks_msec() - t0, 400)
