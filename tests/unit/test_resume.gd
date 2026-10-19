extends GutTest

var doc: PdfDoc

func before_each() -> void:
	doc = PdfDoc.open(ProjectSettings.globalize_path("res://tests/fixtures/mc_letter.pdf"))
	Session.store.root = "user://test_resume_%d/" % randi()

func after_each() -> void:
	Session.store.root = "user://"
	Session.machine.abort()

func _saved(elapsed: float, duration := 3600.0, grace := 90.0, mode := "practice") -> Attempt:
	Session.begin(doc, {"duration_s": duration, "grace_s": grace, "mode": mode, "scratch_sheets": 1})
	Session.start_test()
	Session.timer.advance(elapsed)
	var s := Stroke.new()
	s.id = 1
	s.points = PackedVector2Array([Vector2(1, 1), Vector2(5, 5)])
	s.widths = PackedFloat32Array([1, 1])
	Session.attempt.pages[1].strokes.append(s)
	var t := TextMark.new()
	t.text = "abc"
	Session.attempt.scratch[0].texts.append(t)
	Session.autosave()
	var a := Session.store.load_autosave()
	Session.machine.abort()
	return a

func test_resume_restores_remaining_time() -> void:
	var a := _saved(1000.0)
	assert_true(Session.resume(a))
	assert_eq(Session.timer.remaining(), 2600.0)
	assert_eq(Session.machine.state, SessionMachine.State.TESTING)
	assert_eq(Session.timer.phase(), ExamTimer.Phase.TESTING)

func test_resume_in_grace() -> void:
	var a := _saved(130.0, 100.0, 90.0)
	assert_true(Session.resume(a))
	assert_eq(Session.timer.phase(), ExamTimer.Phase.GRACE)
	assert_eq(Session.machine.state, SessionMachine.State.GRACE)
	assert_almost_eq(Session.timer.grace_remaining(), 60.0, 0.001)

func test_resume_restores_ink() -> void:
	var a := _saved(10.0)
	Session.resume(a)
	assert_eq(Session.attempt.pages[1].strokes.size(), 1)
	assert_eq(Session.attempt.scratch[0].texts[0].text, "abc")

func test_resume_fails_when_pdf_missing() -> void:
	var a := _saved(10.0)
	a.pdf_path = "C:/nope/missing.pdf"
	assert_false(Session.resume(a))
	assert_eq(Session.machine.state, SessionMachine.State.MENU)

func test_strict_mode_not_pausable() -> void:
	Session.begin(doc, {"mode": "strict"})
	assert_false(Session.timer.pausable)
	Session.begin(doc, {"mode": "practice"})
	assert_true(Session.timer.pausable)

func test_resumed_strict_stays_strict() -> void:
	var a := _saved(10.0, 3600.0, 90.0, "strict")
	Session.resume(a)
	assert_false(Session.timer.pausable)
