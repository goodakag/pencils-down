class_name HandwritingNode
extends Node
## Typing an answer: a graphite caret dot on the paper, letters written in handwriting one every
## 35 ms while the pencil follows along. Esc or clicking elsewhere finishes.

signal finished(key: String)

const MIN_SIZE := 8.0
const MAX_SIZE := 32.0

var rig: PlayerRig
var entry: TextEntry
var key: String = ""
var _before: Dictionary = {}
var _revealed: float = 0.0
var _layer: InkLayer
var _is_new: bool = false


func is_active() -> bool:
	return entry != null


## Starts a new answer at `at_pt` on the sheet in front, or edits the answer already there.
func begin_at(at_pt: Vector2) -> void:
	if is_active():
		finish()
	key = rig.packet.state.active_key()
	var page := rig.attempt.ink_for(key)
	_before = page.to_dict()
	var existing := _mark_at(page, at_pt)
	if existing:
		entry = TextEntry.new(existing)
		_revealed = existing.text.length()
		_is_new = false
	else:
		var m := TextMark.new()
		m.id = page.next_id()
		m.size_pt = _size_for(at_pt)
		m.origin = at_pt + Vector2(0, m.size_pt * 0.35)
		m.font_id = rig.font_id
		m.seed = randi()
		page.texts.append(m)
		entry = TextEntry.new(m)
		_revealed = 0.0
		_is_new = true
	_layer = rig.packet.active_page().ink_layer()
	rig.typing = true


func _size_for(at_pt: Vector2) -> float:
	var kind := key.split(":")[0]
	if kind != "page" or rig.doc == null:
		return 14.0
	var spacing := HandwritingLayout.line_spacing_near(rig.doc.text_words(int(key.split(":")[1])), at_pt)
	return HandwritingLayout.auto_size(spacing) if spacing > 0.0 else 14.0


func _mark_at(page: PageInk, p: Vector2) -> TextMark:
	return HandwritingLayout.mark_at(page.texts, p, rig.packet.active_page().size_pt)


func _process(delta: float) -> void:
	if not is_active():
		return
	var total := entry.mark.text.length()
	_revealed = minf(_revealed + delta / TextEntry.GLYPH_DELAY_S, float(total))
	_layer.live_text = [{"mark": entry.mark, "revealed": int(_revealed), "caret": true}]
	_layer.refresh()
	rig.pencil_override_pt = _writing_point()


## Where the pencil should be: on the last glyph written so far.
func _writing_point() -> Vector2:
	var m := entry.mark
	var glyphs := HandwritingLayout.layout_mark(m, rig.packet.active_page().size_pt)
	var n := int(_revealed)
	if n <= 0 or glyphs.is_empty():
		return m.origin
	var g := glyphs[mini(n, glyphs.size()) - 1]
	return g.pos + Vector2(g.advance, -m.size_pt * 0.25)


func _input(event: InputEvent) -> void:
	if not is_active():
		return
	if event is InputEventMouseButton and event.pressed:
		finish()  # clicking elsewhere ends the answer; the click still reaches the rig
		return
	if not (event is InputEventKey) or not event.pressed:
		return
	var k := event as InputEventKey
	get_viewport().set_input_as_handled()
	if k.ctrl_pressed and k.physical_keycode == KEY_BRACKETLEFT:
		entry.mark.size_pt = clampf(entry.mark.size_pt - 1.0, MIN_SIZE, MAX_SIZE)
	elif k.ctrl_pressed and k.physical_keycode == KEY_BRACKETRIGHT:
		entry.mark.size_pt = clampf(entry.mark.size_pt + 1.0, MIN_SIZE, MAX_SIZE)
	elif k.keycode == KEY_ESCAPE:
		finish()
	elif k.keycode == KEY_BACKSPACE:
		entry.backspace()
		_revealed = minf(_revealed, entry.mark.text.length())
	elif k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER:
		entry.newline()
	elif k.keycode == KEY_LEFT:
		entry.move_caret(-1)
	elif k.keycode == KEY_RIGHT:
		entry.move_caret(1)
	elif k.unicode >= 32 and not k.ctrl_pressed:
		entry.insert(String.chr(k.unicode))


## Ends typing; reveals everything and records one undo step.
func finish() -> void:
	if not is_active():
		return
	var page := rig.attempt.ink_for(key)
	if entry.mark.text.strip_edges() == "":
		page.texts.erase(entry.mark)
	_layer.live_text = []
	entry = null
	rig.typing = false
	rig.pencil_override_pt = null
	var after := page.to_dict()
	if JSON.stringify(after) != JSON.stringify(_before):
		rig.commit_page_edit(key, _before)
	else:
		_layer.refresh()
	finished.emit(key)


## Used when the test ends mid-answer: everything typed is kept.
func commit_all() -> void:
	if is_active():
		_revealed = entry.mark.text.length()
		finish()
