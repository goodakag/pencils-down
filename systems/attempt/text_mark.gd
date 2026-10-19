class_name TextMark
extends RefCounted
## Typed answer drawn in a handwriting font. origin = baseline-left of the first line, in points.

var id: int = -1
var origin: Vector2 = Vector2.ZERO
var size_pt: float = 14.0
var font_id: StringName = &"caveat"
var text: String = ""
var seed: int = 0


func to_dict() -> Dictionary:
	return {
		"id": id,
		"origin": [snappedf(origin.x, 0.01), snappedf(origin.y, 0.01)],
		"size_pt": size_pt,
		"font_id": String(font_id),
		"text": text,
		"seed": seed,
	}


static func from_dict(d: Dictionary) -> TextMark:
	var t := TextMark.new()
	t.id = int(d.get("id", -1))
	var o: Array = d.get("origin", [0, 0])
	t.origin = Vector2(float(o[0]), float(o[1]))
	t.size_pt = float(d.get("size_pt", 14.0))
	t.font_id = StringName(d.get("font_id", "caveat"))
	t.text = String(d.get("text", ""))
	t.seed = int(d.get("seed", 0))
	return t
