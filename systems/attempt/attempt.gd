class_name Attempt
extends RefCounted
## One sitting of one test: every mark, the timer state and the stats.

var id: String = ""
var pdf_path: String = ""
var pdf_sha1: String = ""
var test_title: String = ""
var page_sizes_pt: Array[Vector2] = []
var pages: Array[PageInk] = []
var scratch: Array[PageInk] = []
var options: Dictionary = {}
var created_unix: int = 0
var timer_state: Dictionary = {}
var page_time_s: PackedFloat32Array = PackedFloat32Array()
var erase_count: int = 0
var finished: bool = false


static func create(doc: PdfDoc, opts: Dictionary) -> Attempt:
	var a := Attempt.new()
	a.created_unix = int(Time.get_unix_time_from_system())
	a.id = "%d-%06x" % [a.created_unix, randi() & 0xffffff]
	a.pdf_path = doc.path
	a.pdf_sha1 = doc.sha1
	a.test_title = doc.title()
	a.options = opts.duplicate(true)
	for i in doc.page_count():
		a.page_sizes_pt.append(doc.page_size_pt(i))
		a.pages.append(PageInk.new())
	for i in int(opts.get("scratch_sheets", 0)):
		a.scratch.append(PageInk.new())
	a.page_time_s.resize(doc.page_count())
	return a


## Ink for a page key such as "page:3" or "scratch:0".
func ink_for(key: String) -> PageInk:
	var parts := key.split(":")
	var i := int(parts[1])
	return pages[i] if parts[0] == "page" else scratch[i]


func to_dict() -> Dictionary:
	var sizes := []
	for s in page_sizes_pt:
		sizes.append([snappedf(s.x, 0.01), snappedf(s.y, 0.01)])
	var p := []
	for pi in pages:
		p.append(pi.to_dict())
	var sc := []
	for si in scratch:
		sc.append(si.to_dict())
	return {
		"version": 1,
		"id": id,
		"pdf_path": pdf_path,
		"pdf_sha1": pdf_sha1,
		"test_title": test_title,
		"page_sizes_pt": sizes,
		"pages": p,
		"scratch": sc,
		"options": options,
		"created_unix": created_unix,
		"timer_state": timer_state,
		"page_time_s": AttemptCodec.floats_to_array(page_time_s),
		"erase_count": erase_count,
		"finished": finished,
	}


static func from_dict(d: Dictionary) -> Attempt:
	var a := Attempt.new()
	a.id = String(d.get("id", ""))
	a.pdf_path = String(d.get("pdf_path", ""))
	a.pdf_sha1 = String(d.get("pdf_sha1", ""))
	a.test_title = String(d.get("test_title", ""))
	for s in d.get("page_sizes_pt", []):
		a.page_sizes_pt.append(Vector2(float(s[0]), float(s[1])))
	for pd in d.get("pages", []):
		a.pages.append(PageInk.from_dict(pd))
	for sd in d.get("scratch", []):
		a.scratch.append(PageInk.from_dict(sd))
	a.options = d.get("options", {})
	a.created_unix = int(d.get("created_unix", 0))
	a.timer_state = d.get("timer_state", {})
	a.page_time_s = PackedFloat32Array(d.get("page_time_s", []))
	a.erase_count = int(d.get("erase_count", 0))
	a.finished = bool(d.get("finished", false))
	return a
