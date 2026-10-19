class_name SessionMachine
extends RefCounted
## The test session's states and the only transitions allowed between them.

enum State { MENU, PRETEST, SETTLING, TESTING, GRACE, HANDING_IN, REVIEW }

signal state_changed(from: State, to: State)

const ALLOWED := {
	State.MENU: [State.PRETEST, State.TESTING],  # TESTING = resume after a crash
	State.PRETEST: [State.MENU, State.SETTLING],
	State.SETTLING: [State.TESTING],
	State.TESTING: [State.GRACE, State.HANDING_IN],
	State.GRACE: [State.HANDING_IN],
	State.HANDING_IN: [State.REVIEW],
	State.REVIEW: [State.MENU, State.PRETEST],
}

var state: State = State.MENU


func transition_to(to: State) -> bool:
	if not (ALLOWED[state] as Array).has(to):
		return false
	_enter(to)
	return true


## Forces MENU from any state ("Quit test").
func abort() -> void:
	if state != State.MENU:
		_enter(State.MENU)


func _enter(to: State) -> void:
	var from := state
	state = to
	state_changed.emit(from, to)
