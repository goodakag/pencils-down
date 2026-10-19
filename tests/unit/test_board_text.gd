extends GutTest

func test_board_format() -> void:
	assert_eq(BoardText.format(540, 3600), "Start 9:00 · End 10:00")
	assert_eq(BoardText.format(765, 4500), "Start 12:45 · End 2:00")

func test_board_format_rounds_partial_minutes_up() -> void:
	assert_eq(BoardText.format(540, 3630), "Start 9:00 · End 10:01")

func test_board_warning() -> void:
	assert_eq(BoardText.warning(15), "15 min left")
	assert_eq(BoardText.warning(1), "1 min left")

func test_spoken_warning() -> void:
	assert_eq(BoardText.spoken_warning(15), "Fifteen minutes left.")
	assert_eq(BoardText.spoken_warning(5), "Five minutes left.")
	assert_eq(BoardText.spoken_warning(1), "One minute left.")
	assert_eq(BoardText.spoken_warning(45), "45 minutes left.")
