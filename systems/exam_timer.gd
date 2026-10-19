class_name ExamTimer
extends RefCounted
## Test time: counts down the test, then the grace period. Holds (teacher questions) and pauses
## (Practice mode) stop the count without any visible "paused" state.

enum Phase { NOT_STARTED, TESTING, GRACE, OVER }

signal warning(minutes_left: int)
signal test_ended()
signal grace_ended()

const SUSPEND_CAP_S := 60.0

var duration_s: float
var grace_s: float
var warning_minutes: PackedInt32Array
var pausable: bool = true
var suspend_cap_s: float = SUSPEND_CAP_S

var _phase: Phase = Phase.NOT_STARTED
var _elapsed: float = 0.0
var _grace_elapsed: float = 0.0
var _fired: PackedInt32Array = PackedInt32Array()
var _suspend_reasons: Dictionary = {}
var _suspended_for: float = 0.0
var _paused: bool = false


func _init(duration: float, grace: float, warnings: PackedInt32Array = PackedInt32Array([15, 5])) -> void:
	duration_s = duration
	grace_s = grace
	warning_minutes = warnings.duplicate()
	warning_minutes.sort()
	warning_minutes.reverse()


func start() -> void:
	_phase = Phase.TESTING
	# Warnings at or above the full duration would fire immediately; treat them as already passed.
	for m in warning_minutes:
		if m * 60.0 >= duration_s:
			_fired.append(m)


func advance(delta: float) -> void:
	while delta > 0.0:
		if _phase == Phase.NOT_STARTED or _phase == Phase.OVER or _paused:
			return
		if is_suspended():
			var hold := minf(delta, suspend_cap_s - _suspended_for)
			_suspended_for += hold
			delta -= hold
			if _suspended_for >= suspend_cap_s:
				_suspend_reasons.clear()
				_suspended_for = 0.0
			continue
		if _phase == Phase.TESTING:
			var step := minf(delta, duration_s - _elapsed)
			_elapsed += step
			delta -= step
			_check_warnings()
			if _elapsed >= duration_s:
				_phase = Phase.GRACE if grace_s > 0.0 else Phase.OVER
				test_ended.emit()
				if _phase == Phase.OVER:
					grace_ended.emit()
		elif _phase == Phase.GRACE:
			var step := minf(delta, grace_s - _grace_elapsed)
			_grace_elapsed += step
			delta -= step
			if _grace_elapsed >= grace_s:
				_phase = Phase.OVER
				grace_ended.emit()


func _check_warnings() -> void:
	for m in warning_minutes:
		if not _fired.has(m) and remaining() <= m * 60.0:
			_fired.append(m)
			warning.emit(m)


func elapsed() -> float:
	return _elapsed


func remaining() -> float:
	return maxf(duration_s - _elapsed, 0.0)


func grace_remaining() -> float:
	return maxf(grace_s - _grace_elapsed, 0.0)


func grace_elapsed() -> float:
	return _grace_elapsed


func phase() -> Phase:
	return _phase


func suspend(reason: StringName) -> void:
	if _suspend_reasons.is_empty():
		_suspended_for = 0.0
	_suspend_reasons[reason] = true


func resume(reason: StringName) -> void:
	_suspend_reasons.erase(reason)
	if _suspend_reasons.is_empty():
		_suspended_for = 0.0


func is_suspended() -> bool:
	return not _suspend_reasons.is_empty()


func pause() -> void:
	if pausable:
		_paused = true


func unpause() -> void:
	_paused = false


func is_paused() -> bool:
	return _paused


func to_dict() -> Dictionary:
	return {
		"duration_s": duration_s,
		"grace_s": grace_s,
		"warnings": Array(warning_minutes),
		"fired": Array(_fired),
		"phase": int(_phase),
		"elapsed": _elapsed,
		"grace_elapsed": _grace_elapsed,
		"pausable": pausable,
	}


static func from_dict(d: Dictionary) -> ExamTimer:
	var t := ExamTimer.new(float(d.duration_s), float(d.grace_s), PackedInt32Array(d.get("warnings", [15, 5])))
	t._phase = int(d.get("phase", Phase.NOT_STARTED)) as Phase
	t._elapsed = float(d.get("elapsed", 0.0))
	t._grace_elapsed = float(d.get("grace_elapsed", 0.0))
	t._fired = PackedInt32Array(d.get("fired", []))
	t.pausable = bool(d.get("pausable", true))
	return t
