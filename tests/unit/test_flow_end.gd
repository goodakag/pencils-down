extends GutTest

var root: String

func before_each() -> void:
	root = "user://test_flow_%d/" % randi()
	Session.store.root = root

func after_each() -> void:
	Session.store.root = "user://"
	Session.machine.abort()

func test_finish_commits_active_stroke_and_text() -> void:
	var doc := PdfDoc.open(ProjectSettings.globalize_path("res://tests/fixtures/mc_letter.pdf"))
	Session.begin(doc, {"duration_s": 600.0, "grace_s": 30.0, "scratch_sheets": 0})
	var packet := TestPacket.new()
	packet.cache_async = false
	add_child_autofree(packet)
	packet.setup(doc, Session.attempt, 72.0)
	var rig := PlayerRig.new()
	add_child_autofree(rig)
	rig.setup(packet, Session.attempt, doc)
	Session.finishing.connect(rig.commit_in_progress)
	Session.start_test()
	# A stroke is mid-draw and an answer is mid-write when time runs out.
	rig._ink.begin("page:0", Vector2(100, 100), 0.0, 1.0)
	rig._ink.move(Vector2(120, 100), 0.05, 1.0)
	rig.handwriting.begin_at(Vector2(300, 300))
	rig.handwriting.entry.insert("abc")
	Session.finish()
	Session.finishing.disconnect(rig.commit_in_progress)
	var archived := Session.store.load_attempt(Session.last_archive_path)
	assert_not_null(archived)
	assert_true(archived.finished)
	assert_eq(archived.pages[0].strokes.size(), 1)
	assert_eq(archived.pages[0].texts.size(), 1)
	assert_eq(archived.pages[0].texts[0].text, "abc")
	assert_eq(Session.machine.state, SessionMachine.State.REVIEW)
	assert_null(Session.store.load_autosave())

func test_contract_validate_lists_missing() -> void:
	var c := EnvironmentContract.new()
	autofree(c)
	assert_eq(c.validate().size(), 7)

func test_greybox_satisfies_contract() -> void:
	var g := GreyboxClassroom.new()
	add_child_autofree(g)
	assert_eq(g.validate(), PackedStringArray())
	assert_eq(g.student_seats.size(), 24)

func test_skipping_settling_cancels_facedown_delivery() -> void:
	var doc := PdfDoc.open(ProjectSettings.globalize_path("res://tests/fixtures/mc_letter.pdf"))
	Session.begin(doc, {"duration_s": 600.0, "grace_s": 30.0, "scratch_sheets": 0})
	var flow: TestFlow = load("res://scenes/flow/test_scene.tscn").instantiate()
	flow.paper_dpi = 72.0
	add_child_autofree(flow)
	flow._start_test()  # Space pressed before the 6 s delivery
	assert_false(flow.facedown_pending(), "delivery tween must not fire after the test starts")
