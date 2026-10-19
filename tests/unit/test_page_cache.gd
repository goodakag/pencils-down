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
