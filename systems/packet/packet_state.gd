class_name PacketState
extends RefCounted
## Which page of the stapled test (or which scratch sheet) is in front.

signal changed()

var page_count: int
var scratch_count: int
var current: int = 0
var showing_scratch: bool = false
var scratch_index: int = 0


func _init(pages: int, scratch_sheets: int) -> void:
	page_count = pages
	scratch_count = scratch_sheets


## Turns the test page, or cycles scratch sheets while scratch paper is in front.
func turn(dir: int) -> bool:
	if showing_scratch:
		var n := scratch_index + dir
		if n < 0 or n >= scratch_count:
			return false
		scratch_index = n
	else:
		var n := current + dir
		if n < 0 or n >= page_count:
			return false
		current = n
	changed.emit()
	return true


func jump(i: int) -> bool:
	if i < 0 or i >= page_count:
		return false
	current = i
	showing_scratch = false
	changed.emit()
	return true


func toggle_scratch() -> void:
	if scratch_count == 0:
		return
	showing_scratch = not showing_scratch
	changed.emit()


func active_target() -> Dictionary:
	if showing_scratch:
		return {"kind": "scratch", "index": scratch_index}
	return {"kind": "page", "index": current}


func active_key() -> String:
	var t := active_target()
	return "%s:%d" % [t.kind, t.index]
