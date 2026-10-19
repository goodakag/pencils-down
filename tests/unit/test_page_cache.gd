extends GutTest

var doc: PdfDoc

func before_all() -> void:
	doc = PdfDoc.open(ProjectSettings.globalize_path("res://tests/fixtures/big_120.pdf"))

func _cache() -> PageCache:
	var c := PageCache.new(doc, 150.0, 24.0)
	c.async = false
	return c

func test_page_cache_keeps_neighbors_only() -> void:
	var c := _cache()
	for i in doc.page_count():
		c.texture_for(i, 60)
	assert_eq(c.resident_full_pages(), PackedInt32Array([59, 60, 61]))

func test_page_cache_moves_window() -> void:
	var c := _cache()
	c.texture_for(60, 60)
	c.texture_for(10, 10)
	assert_eq(c.resident_full_pages(), PackedInt32Array([9, 10, 11]))

func test_current_page_gets_full_resolution() -> void:
	var c := _cache()
	var full := c.texture_for(5, 5)
	var thumb := c.texture_for(50, 5)
	assert_gt(full.get_width(), thumb.get_width() * 4)

func test_first_page_window_clamped() -> void:
	var c := _cache()
	c.texture_for(0, 0)
	assert_eq(c.resident_full_pages(), PackedInt32Array([0, 1]))

func test_poll_reports_textures_collected_elsewhere() -> void:
	var c := PageCache.new(doc, 72.0, 24.0)  # async
	c.texture_for(5, 5)
	var t0 := Time.get_ticks_msec()
	while c.resident_full_pages().size() > 0 and Time.get_ticks_msec() - t0 < 5000:
		OS.delay_msec(20)
		c.texture_for(5, 5)  # collects finished renders as a side effect
		if c.texture_for(5, 5).get_width() > 200:
			break
	assert_gt(c.texture_for(5, 5).get_width(), 200, "full-res page arrived")
	assert_true(c.poll(), "poll must still report the new texture so the packet refreshes")
	assert_false(c.poll(), "and only once")

func test_shutdown_waits_for_background_renders() -> void:
	var c := PageCache.new(doc, 150.0, 24.0)  # async
	c.texture_for(30, 30)
	c.shutdown()
	assert_eq(c.pending_count(), 0)

func test_main_thread_pdf_calls_while_worker_renders() -> void:
	# Regression guard for PDFium not being thread-safe: Quick Fill / typing call the document
	# from the main thread while neighbour pages render on workers.
	var c := PageCache.new(doc, 200.0, 24.0)
	for round in 6:
		c.texture_for(10 + round * 10, 10 + round * 10)
		for i in 4:
			doc.text_words(i)
			doc.render_page(i, 30.0)
	c.shutdown()
	assert_eq(c.pending_count(), 0)
