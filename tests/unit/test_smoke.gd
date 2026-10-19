extends GutTest

func test_engine_version_is_4_7() -> void:
	var v := Engine.get_version_info()
	assert_eq(v.major, 4)
	assert_eq(v.minor, 7)
