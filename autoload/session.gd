extends Node
## Autoload "Session": the one live test: state machine, timer, attempt, and saving.

signal finishing()  ## emitted just before the attempt is archived; commit in-progress input
signal finished(archive_path: String)

const DEFAULT_OPTIONS := {
	"duration_s": 3600.0,
	"grace_s": 90.0,
	"warnings": [15, 5],
	"scratch_sheets": 1,
	"clock": "wall",
	"mode": "practice",
	"class_size": 16,
	"start_minute": 540,
}

var machine := SessionMachine.new()
var timer: ExamTimer
var attempt: Attempt
var store := AttemptStore.new()
var doc: PdfDoc
var options: Dictionary = {}
var last_archive_path: String = ""
var pre_roll_s: float = 0.0  ## seconds until the start bell while settling (wall clock reads earlier)


func begin(d: PdfDoc, opts: Dictionary) -> void:
	if machine.state != SessionMachine.State.PRETEST:
		machine.abort()
		machine.transition_to(SessionMachine.State.PRETEST)
	doc = d
	options = DEFAULT_OPTIONS.duplicate(true)
	options.merge(opts, true)
	attempt = Attempt.create(d, options)
	timer = _make_timer(options)
	last_archive_path = ""
	machine.transition_to(SessionMachine.State.SETTLING)


func _make_timer(o: Dictionary) -> ExamTimer:
	var t := ExamTimer.new(float(o.duration_s), float(o.grace_s), PackedInt32Array(o.warnings))
	t.pausable = o.mode == "practice"
	return t


## Restores an autosaved attempt straight into the test (no settling, no start bell).
## Returns false when the original PDF can't be opened.
func resume(a: Attempt) -> bool:
	var d := PdfService.open(a.pdf_path)
	if d == null:
		return false
	machine.abort()
	doc = d
	attempt = a
	options = DEFAULT_OPTIONS.duplicate(true)
	options.merge(a.options, true)
	timer = ExamTimer.from_dict(a.timer_state)
	timer.pausable = options.mode == "practice"
	pre_roll_s = 0.0
	last_archive_path = ""
	machine.transition_to(SessionMachine.State.TESTING)
	if timer.phase() == ExamTimer.Phase.GRACE:
		machine.transition_to(SessionMachine.State.GRACE)
	return true


func start_test() -> void:
	pre_roll_s = 0.0
	timer.start()
	machine.transition_to(SessionMachine.State.TESTING)


func _process(delta: float) -> void:
	if timer and (machine.state == SessionMachine.State.TESTING or machine.state == SessionMachine.State.GRACE):
		timer.advance(delta)


func seconds_of_day() -> float:
	var start := float(options.get("start_minute", 540)) * 60.0
	if timer == null:
		return start
	var s := start + timer.elapsed() - pre_roll_s
	if timer.phase() == ExamTimer.Phase.GRACE or timer.phase() == ExamTimer.Phase.OVER:
		s += timer.grace_elapsed()
	return s


func autosave() -> void:
	if attempt == null or attempt.finished:
		return
	attempt.timer_state = timer.to_dict()
	store.save_autosave(attempt)


## Ends the attempt: commits anything in progress, archives it, clears the autosave, → REVIEW.
func finish() -> void:
	if attempt == null or attempt.finished:
		return
	finishing.emit()
	attempt.timer_state = timer.to_dict()
	attempt.finished = true
	last_archive_path = store.archive(attempt)
	store.clear_autosave()
	if machine.state != SessionMachine.State.HANDING_IN:
		machine.transition_to(SessionMachine.State.HANDING_IN)
	machine.transition_to(SessionMachine.State.REVIEW)
	finished.emit(last_archive_path)
