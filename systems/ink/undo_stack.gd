class_name UndoStack
extends RefCounted
## Unlimited undo/redo of ink ops: {"kind": "add"|"remove"|"replace", "page": int, "before": Array, "after": Array}.

var _undo: Array[Dictionary] = []
var _redo: Array[Dictionary] = []


func push(op: Dictionary) -> void:
	_undo.append(op)
	_redo.clear()


func undo() -> Dictionary:
	if _undo.is_empty():
		return {}
	var op: Dictionary = _undo.pop_back()
	_redo.append(op)
	return op


func redo() -> Dictionary:
	if _redo.is_empty():
		return {}
	var op: Dictionary = _redo.pop_back()
	_undo.append(op)
	return op


func can_undo() -> bool:
	return not _undo.is_empty()


func can_redo() -> bool:
	return not _redo.is_empty()
