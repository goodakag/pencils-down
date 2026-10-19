class_name InkInput
extends RefCounted
## Builds one pencil stroke from pointer samples (PDF points). Rendering lives elsewhere.

const MIN_STEP_PT := 0.25

var page_key: String = ""
var stroke: Stroke = null
var _last_t: float = 0.0


func begin(key: String, p: Vector2, t: float, pressure: float) -> void:
	page_key = key
	stroke = Stroke.new()
	stroke.tool = Stroke.Tool.PENCIL
	stroke.points.append(p)
	stroke.widths.append(InkGeometry.width_for_speed(0.0, 0.9, _pressure(pressure)))
	_last_t = t


func move(p: Vector2, t: float, pressure: float) -> void:
	if stroke == null:
		return
	var last := stroke.points[stroke.points.size() - 1]
	var d := p.distance_to(last)
	if d < MIN_STEP_PT:
		return
	var dt := maxf(t - _last_t, 1.0 / 240.0)
	stroke.points.append(p)
	stroke.widths.append(InkGeometry.width_for_speed(d / dt, 0.9, _pressure(pressure)))
	_last_t = t


## The finished stroke, or null for a click without movement.
func end() -> Stroke:
	var s := stroke
	stroke = null
	if s == null or s.points.size() < 2:
		return null
	return s


func cancel() -> void:
	stroke = null


func is_active() -> bool:
	return stroke != null


## Mice report pressure 0; pen tablets report 0..1.
func _pressure(p: float) -> float:
	return 1.0 if p <= 0.0 else lerpf(0.35, 1.0, clampf(p, 0.0, 1.0))
