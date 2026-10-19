class_name GoldenFixture
extends RefCounted
## A fixed attempt on mc_letter.pdf used to generate and check the golden export image.

const GOLDEN := "res://tests/fixtures/golden/mc_letter_p0.png"


static func attempt(doc: PdfDoc) -> Attempt:
	var a := Attempt.create(doc, {"scratch_sheets": 0})
	var ink := a.pages[0]
	var s := ScribbleGen.scribble_for(Rect2(143, 103, 14, 14), 7)  # question 1, bubble B
	s.id = ink.next_id()
	ink.strokes.append(s)
	var tick := Stroke.new()
	tick.id = ink.next_id()
	tick.points = PackedVector2Array([Vector2(320, 300), Vector2(326, 308), Vector2(342, 286)])
	tick.widths = PackedFloat32Array([1.1, 1.1, 1.1])
	ink.strokes.append(tick)
	var t := TextMark.new()
	t.id = ink.next_id()
	t.origin = Vector2(285, 114)
	t.size_pt = 15.0
	t.text = "x = 4, so f(4) = 11"
	t.seed = 4
	ink.texts.append(t)
	return a


static func render(out_path: String) -> Image:
	var doc := PdfDoc.open(ProjectSettings.globalize_path("res://tests/fixtures/mc_letter.pdf"))
	PdfExporter.export(doc, attempt(doc), out_path)
	return PdfDoc.open(out_path).render_page(0, 72.0)
