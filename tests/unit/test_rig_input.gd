extends GutTest

var doc: PdfDoc
var attempt: Attempt
var packet: TestPacket
var rig: PlayerRig

func before_each() -> void:
	doc = PdfDoc.open(ProjectSettings.globalize_path("res://tests/fixtures/mc_letter.pdf"))
	attempt = Attempt.create(doc, {"scratch_sheets": 1})
	packet = TestPacket.new()
	packet.cache_async = false
	add_child_autofree(packet)
	packet.setup(doc, attempt, 72.0)
	rig = PlayerRig.new()
	add_child_autofree(rig)
	rig.setup(packet, attempt, doc)

func _stroke(id: int) -> Stroke:
	var s := Stroke.new()
	s.id = id
	s.points = PackedVector2Array([Vector2(100, 100), Vector2(140, 100)])
	s.widths = PackedFloat32Array([1, 1])
	return s

func test_erase_then_turn_keeps_undo_on_the_right_page() -> void:
	attempt.pages[0].strokes.append(_stroke(1))
	attempt.pages[1].strokes.append(_stroke(2))
	rig._begin_erase(false)
	attempt.pages[0].strokes.clear()  # as if erased under the cursor
	rig.turn_page(1)  # right button still held
	rig.undo()        # on page 2: must not bring page 1's ink here
	assert_eq(attempt.pages[1].strokes.size(), 1)
	assert_eq(attempt.pages[1].strokes[0].id, 2)
	rig.turn_page(-1)
	rig.undo()
	assert_eq(attempt.pages[0].strokes.size(), 1, "the erase undoes on page 1")

func test_settle_input_commits_stroke_and_releases_keys() -> void:
	rig._ink.begin("page:0", Vector2(10, 10), 0.0, 1.0)
	rig._ink.move(Vector2(30, 10), 0.05, 1.0)
	rig._space_held = true
	rig.settle_input()
	assert_false(rig._ink.is_active())
	assert_eq(attempt.pages[0].strokes.size(), 1)
	assert_false(rig._space_held)

func test_scratch_toggle_settles_erase() -> void:
	attempt.pages[0].strokes.append(_stroke(1))
	rig._begin_erase(false)
	attempt.pages[0].strokes.clear()
	rig.toggle_scratch()
	assert_false(rig._erasing)
	rig.undo()  # on the scratch sheet: nothing to undo there
	assert_eq(attempt.scratch[0].strokes.size(), 0)
