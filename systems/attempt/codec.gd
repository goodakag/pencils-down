class_name AttemptCodec
extends RefCounted
## JSON helpers: packed vectors as flat number arrays rounded to 0.01 pt.


static func vec2s_to_array(v: PackedVector2Array) -> Array:
	var out := []
	for p in v:
		out.append(snappedf(p.x, 0.01))
		out.append(snappedf(p.y, 0.01))
	return out


static func array_to_vec2s(a: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(0, a.size() - 1, 2):
		out.append(Vector2(float(a[i]), float(a[i + 1])))
	return out


static func floats_to_array(v: PackedFloat32Array) -> Array:
	var out := []
	for f in v:
		out.append(snappedf(f, 0.01))
	return out


## Parses JSON without logging engine errors on bad input (JSON.parse_string logs them).
static func parse_json(text: String) -> Variant:
	var j := JSON.new()
	return j.data if j.parse(text) == OK else null
