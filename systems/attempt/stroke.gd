class_name Stroke
extends RefCounted
## One pencil stroke in PDF points (origin top-left, y down).

enum Tool { PENCIL, ERASER }

var id: int = -1
var tool: Tool = Tool.PENCIL
var points: PackedVector2Array = PackedVector2Array()
var widths: PackedFloat32Array = PackedFloat32Array()  # pt, one per point
var t_start: float = 0.0  # exam elapsed seconds


func bounds() -> Rect2:
	if points.is_empty():
		return Rect2()
	var r := Rect2(points[0], Vector2.ZERO)
	for p in points:
		r = r.expand(p)
	return r


func to_dict() -> Dictionary:
	return {
		"id": id,
		"tool": int(tool),
		"points": AttemptCodec.vec2s_to_array(points),
		"widths": AttemptCodec.floats_to_array(widths),
		"t_start": t_start,
	}


static func from_dict(d: Dictionary) -> Stroke:
	var s := Stroke.new()
	s.id = int(d.get("id", -1))
	s.tool = int(d.get("tool", 0)) as Tool
	s.points = AttemptCodec.array_to_vec2s(d.get("points", []))
	s.widths = PackedFloat32Array(d.get("widths", []))
	s.t_start = float(d.get("t_start", 0.0))
	return s
