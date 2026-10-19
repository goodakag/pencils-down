extends GutTest

const O := Vector2(72, 100)

func _lay(text: String, seed := 7, size := 20.0, max_x := 10000.0) -> Array[GlyphPlacement]:
	return HandwritingLayout.layout(text, O, size, &"caveat", seed, max_x)

func test_one_placement_per_character() -> void:
	assert_eq(_lay("hello").size(), 5)

func test_deterministic() -> void:
	var a := _lay("hello")
	var b := _lay("hello")
	for i in a.size():
		assert_eq(a[i].pos, b[i].pos)
		assert_eq(a[i].rot_deg, b[i].rot_deg)
		assert_eq(a[i].scale, b[i].scale)

func test_seed_changes_jitter() -> void:
	assert_ne(_lay("hello", 7)[2].rot_deg, _lay("hello", 8)[2].rot_deg)

func test_advances_left_to_right() -> void:
	var g := _lay("abc")
	assert_almost_eq(g[0].pos.x, O.x, 0.001)
	assert_gt(g[1].pos.x, g[0].pos.x)
	assert_gt(g[2].pos.x, g[1].pos.x)

func test_jitter_within_bounds() -> void:
	for g in _lay("the quick brown fox jumps over the lazy dog ".repeat(5)):
		assert_lte(absf(g.rot_deg), 0.6)
		assert_lte(absf(g.scale - 1.0), 0.04 + 1e-6)
		if g.line == 0:
			assert_lte(absf(g.pos.y - O.y), 0.3 + 1e-6)

func test_wraps_at_max_x() -> void:
	var g := _lay("the quick brown fox jumps over the lazy dog", 7, 20.0, O.x + 150.0)
	var wrapped := false
	for p in g:
		if p.line > 0:
			wrapped = true
		if p.ch != " ":
			assert_lte(p.pos.x, O.x + 150.0)
	assert_true(wrapped)

func test_newline_moves_down_one_line_height() -> void:
	var g := _lay("a\nb")
	var b: GlyphPlacement = g[g.size() - 1]
	assert_eq(b.ch, "b")
	assert_eq(b.line, 1)
	assert_almost_eq(b.pos.y - g[0].pos.y, 27.0, 0.61)
	assert_almost_eq(b.pos.x, O.x, 0.001)

func test_missing_glyphs_use_fallback() -> void:
	for ch in ["é", "√", "²", "π", "θ", "≤"]:
		var g := _lay(ch)
		assert_true(g[0].font.has_char(ch.unicode_at(0)), "font for %s" % ch)

func test_font_for_known_ids() -> void:
	for id in HandwritingLayout.FONTS.keys():
		assert_not_null(HandwritingLayout.font_for(id), str(id))

func test_auto_size() -> void:
	assert_almost_eq(HandwritingLayout.auto_size(24.0), 14.88, 0.001)
	assert_eq(HandwritingLayout.auto_size(4.0), 9.0)
	assert_eq(HandwritingLayout.auto_size(80.0), 28.0)

func _w(y: float) -> Dictionary:
	return {"text": "word", "rect": Rect2(72, y - 5, 30, 10)}

func test_line_spacing_near_uses_median_gap() -> void:
	var words := [_w(100), _w(100), _w(124), _w(148), _w(172), _w(400)]
	assert_almost_eq(HandwritingLayout.line_spacing_near(words, Vector2(80, 130)), 24.0, 0.01)

func test_line_spacing_unknown_is_zero() -> void:
	assert_eq(HandwritingLayout.line_spacing_near([_w(100)], Vector2(80, 100)), 0.0)
