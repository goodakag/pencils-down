class_name TextEntry
extends RefCounted
## Editing model for one typed answer. Characters are Unicode code points (√, ², π edit as one).

const GLYPH_DELAY_S := 0.035

var mark: TextMark
var caret: int = 0


func _init(m: TextMark) -> void:
	mark = m
	caret = m.text.length()


func insert(s: String) -> void:
	mark.text = mark.text.substr(0, caret) + s + mark.text.substr(caret)
	caret += s.length()


func backspace() -> void:
	if caret <= 0:
		return
	mark.text = mark.text.substr(0, caret - 1) + mark.text.substr(caret)
	caret -= 1


func newline() -> void:
	insert("\n")


func move_caret(delta: int) -> void:
	caret = clampi(caret + delta, 0, mark.text.length())


## How many glyphs the hand has written after `elapsed_s` of writing: one every 35 ms, never
## more than were typed. Typing can run ahead; the hand catches up.
func revealed_count(elapsed_s: float, typed_total: int) -> int:
	return mini(int(floor(elapsed_s / GLYPH_DELAY_S + 1e-6)), typed_total)
