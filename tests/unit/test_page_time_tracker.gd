extends GutTest

func test_tracks_only_pages() -> void:
	var t := PageTimeTracker.new(2)
	t.tick(5.0, {"kind": "page", "index": 0})
	t.tick(3.0, {"kind": "scratch", "index": 0})
	t.tick(2.0, {"kind": "page", "index": 1})
	assert_eq(t.totals(), PackedFloat32Array([5.0, 2.0]))

func test_ignores_out_of_range() -> void:
	var t := PageTimeTracker.new(1)
	t.tick(1.0, {"kind": "page", "index": 3})
	assert_eq(t.totals(), PackedFloat32Array([0.0]))

func test_resumes_from_existing_totals() -> void:
	var t := PageTimeTracker.new(2, PackedFloat32Array([4.0, 1.0]))
	t.tick(1.0, {"kind": "page", "index": 0})
	assert_eq(t.totals(), PackedFloat32Array([5.0, 1.0]))
