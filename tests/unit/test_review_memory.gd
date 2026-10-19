extends GutTest

func test_review_keeps_few_full_pages_for_big_tests() -> void:
	var doc := PdfDoc.open(ProjectSettings.globalize_path("res://tests/fixtures/big_120.pdf"))
	Session.begin(doc, {"duration_s": 600.0, "scratch_sheets": 0})
	var r: ReviewScreen = load("res://scenes/ui/review.tscn").instantiate()
	add_child_autofree(r)
	for i in [0, 5, 60, 119]:
		r._show_page(i)
	assert_lte(r.full_pages_cached(), ReviewScreen.FULL_CACHE)
	Session.machine.abort()
