class_name PageInk
extends RefCounted
## All marks on one page or scratch sheet.

var strokes: Array[Stroke] = []
var texts: Array[TextMark] = []
var _next_id: int = 1


func is_empty() -> bool:
	return strokes.is_empty() and texts.is_empty()


func next_id() -> int:
	var id := _next_id
	_next_id += 1
	return id


func to_dict() -> Dictionary:
	var s := []
	for st in strokes:
		s.append(st.to_dict())
	var t := []
	for tm in texts:
		t.append(tm.to_dict())
	return {"strokes": s, "texts": t, "next_id": _next_id}


static func from_dict(d: Dictionary) -> PageInk:
	var p := PageInk.new()
	for sd in d.get("strokes", []):
		p.strokes.append(Stroke.from_dict(sd))
	for td in d.get("texts", []):
		p.texts.append(TextMark.from_dict(td))
	p._next_id = int(d.get("next_id", 1))
	return p
