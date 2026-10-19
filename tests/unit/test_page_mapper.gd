extends GutTest

const LETTER := Vector2(612, 792)

func test_uv_to_pt() -> void:
	assert_eq(PageMapper.uv_to_pt(Vector2(0.5, 0.25), LETTER), Vector2(306, 198))
	assert_eq(PageMapper.uv_to_pt(Vector2.ZERO, LETTER), Vector2.ZERO)

func test_uv_round_trip() -> void:
	var p := Vector2(123.4, 567.8)
	assert_almost_eq(PageMapper.uv_to_pt(PageMapper.pt_to_uv(p, LETTER), LETTER), p, Vector2(0.001, 0.001))
