class_name PageTimeTracker
extends RefCounted
## Seconds spent with each test page in front (scratch paper time isn't counted).

var _totals: PackedFloat32Array


func _init(page_count: int, existing: PackedFloat32Array = PackedFloat32Array()) -> void:
	_totals = existing.duplicate()
	_totals.resize(page_count)


func tick(delta: float, target: Dictionary) -> void:
	if target.get("kind") != "page":
		return
	var i := int(target.get("index", -1))
	if i >= 0 and i < _totals.size():
		_totals[i] += delta


func totals() -> PackedFloat32Array:
	return _totals
