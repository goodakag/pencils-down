class_name PageMapper
extends RefCounted
## Page UV (0,0 = top-left) <-> PDF points (origin top-left, y down).


static func uv_to_pt(uv: Vector2, size_pt: Vector2) -> Vector2:
	return uv * size_pt


static func pt_to_uv(p: Vector2, size_pt: Vector2) -> Vector2:
	return p / size_pt
