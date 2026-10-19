extends GutTest

func _entry(text := "") -> TextEntry:
	var m := TextMark.new()
	m.text = text
	var e := TextEntry.new(m)
	e.caret = text.length()
	return e

func test_insert_and_backspace() -> void:
	var e := _entry()
	e.insert("ab")
	assert_eq(e.mark.text, "ab")
	e.backspace()
	assert_eq(e.mark.text, "a")
	assert_eq(e.caret, 1)

func test_insert_at_caret() -> void:
	var e := _entry("ac")
	e.caret = 1
	e.insert("b")
	assert_eq(e.mark.text, "abc")
	assert_eq(e.caret, 2)

func test_newline_inserts_lf() -> void:
	var e := _entry("a")
	e.newline()
	assert_eq(e.mark.text, "a\n")

func test_caret_moves_clamped() -> void:
	var e := _entry("abc")
	e.move_caret(-10)
	assert_eq(e.caret, 0)
	e.move_caret(10)
	assert_eq(e.caret, 3)

func test_backspace_at_start_does_nothing() -> void:
	var e := _entry("abc")
	e.caret = 0
	e.backspace()
	assert_eq(e.mark.text, "abc")

func test_reveal_lags_35ms() -> void:
	var e := _entry()
	assert_eq(e.revealed_count(0.07, 10), 2)
	assert_eq(e.revealed_count(10.0, 10), 10)
	assert_eq(e.revealed_count(0.0, 0), 0)

func test_unicode_editing() -> void:
	var e := _entry()
	e.insert("√2")
	e.backspace()
	assert_eq(e.mark.text, "√")
