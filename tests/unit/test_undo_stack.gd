extends GutTest

func _op(n: int) -> Dictionary:
	return {"kind": "add", "page": 0, "before": [], "after": [{"id": n}]}

func test_undo_redo_order() -> void:
	var u := UndoStack.new()
	u.push(_op(1))
	u.push(_op(2))
	assert_eq(u.undo().after[0].id, 2)
	assert_eq(u.undo().after[0].id, 1)
	assert_false(u.can_undo())
	assert_eq(u.redo().after[0].id, 1)
	u.push(_op(3))
	assert_false(u.can_redo())
	assert_eq(u.redo(), {})

func test_empty_undo_returns_empty() -> void:
	assert_eq(UndoStack.new().undo(), {})
