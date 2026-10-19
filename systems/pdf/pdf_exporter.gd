class_name PdfExporter
extends RefCounted
## Writes the finished test: the original PDF untouched underneath, pencil strokes as vector paths,
## typed answers as real text (so an AI marker can read them), scratch sheets appended at the end.

const SCRATCH_SIZE := Vector2(612, 792)
const GRAPHITE := Color(0.231, 0.227, 0.235, 0.92)
const TEXT_COLOR := Color(0.231, 0.227, 0.235, 1.0)


## Returns {"ok": bool, "mode": "vector"|"images", "error": String}.
static func export(doc: PdfDoc, attempt: Attempt, out_path: String) -> Dictionary:
	if _same_file(out_path, doc.path):
		return {"ok": false, "mode": "vector", "error": "same_as_source"}
	# Work on a fresh copy: the in-game document must never change.
	var pdf := PDFDocument.new()
	var err: int = pdf.load_from_buffer(FileAccess.get_file_as_bytes(doc.path), "")
	if err != OK:
		return {"ok": false, "mode": "vector", "error": "cannot_open_source (%s)" % error_string(err)}
	for i in mini(attempt.pages.size(), pdf.get_page_count()):
		_draw_ink(pdf.get_page(i), attempt.pages[i])
	for sheet in attempt.scratch:
		if sheet.is_empty():
			continue
		_draw_ink(pdf.create_page(SCRATCH_SIZE), sheet)
	err = pdf.save_to_file(out_path)
	if err != OK:
		# Vector export failed: fall back to flattened page images.
		return export_images(doc, attempt, out_path)
	return {"ok": true, "mode": "vector", "error": ""}


const IMAGE_DPI := 200.0


## Fallback: every page rendered at 200 DPI with the pencil marks and handwriting flattened on top.
static func export_images(doc: PdfDoc, attempt: Attempt, out_path: String) -> Dictionary:
	if _same_file(out_path, doc.path):
		return {"ok": false, "mode": "images", "error": "same_as_source"}
	var images: Array[Image] = []
	var sizes: Array[Vector2] = []
	for i in mini(attempt.pages.size(), doc.page_count()):
		var size := doc.page_size_pt(i)
		images.append(_flatten(doc.render_page(i, IMAGE_DPI), attempt.pages[i], size))
		sizes.append(size)
	for sheet in attempt.scratch:
		if sheet.is_empty():
			continue
		var blank := Image.create(int(SCRATCH_SIZE.x * IMAGE_DPI / 72.0), int(SCRATCH_SIZE.y * IMAGE_DPI / 72.0), false, Image.FORMAT_RGBA8)
		blank.fill(Color.WHITE)
		images.append(_flatten(blank, sheet, SCRATCH_SIZE))
		sizes.append(SCRATCH_SIZE)
	var err := FallbackPdfWriter.write(images, sizes, out_path)
	if err != OK:
		return {"ok": false, "mode": "images", "error": "cannot_save (%s)" % error_string(err)}
	return {"ok": true, "mode": "images", "error": ""}


static func _flatten(page_img: Image, ink: PageInk, size: Vector2) -> Image:
	var overlay := InkRasterizer.rasterize(ink, size, IMAGE_DPI)
	for t in ink.texts:
		InkRasterizer.rasterize_text(overlay, HandwritingLayout.layout(t.text, t.origin, t.size_pt, t.font_id, t.seed, 100000.0), t.size_pt, IMAGE_DPI, TEXT_COLOR)
	var out := page_img.duplicate()
	out.convert(Image.FORMAT_RGBA8)
	if overlay.get_size() != out.get_size():
		overlay.resize(out.get_width(), out.get_height())
	out.blend_rect(overlay, Rect2i(Vector2i.ZERO, overlay.get_size()), Vector2i.ZERO)
	return out


static func _draw_ink(page: PDFPage, ink: PageInk) -> void:
	for s in ink.strokes:
		if s.tool != Stroke.Tool.PENCIL or s.points.is_empty():
			continue
		var pts := InkGeometry.smooth(s.points) if s.points.size() > 2 else s.points
		if pts.size() == 1:
			pts = PackedVector2Array([pts[0], pts[0] + Vector2(0.01, 0)])
		page.add_path(pts, Color(0, 0, 0, 0), GRAPHITE, _mean_width(s), false)
	for t in ink.texts:
		for g in HandwritingLayout.layout(t.text, t.origin, t.size_pt, t.font_id, t.seed, 100000.0):
			if g.ch == " " or g.ch == "\n":
				continue
			page.add_text(g.ch, g.pos, _font_path(g.font), t.size_pt * g.scale, TEXT_COLOR, PDFPage.ALIGN_LEFT, false, false)


static func _mean_width(s: Stroke) -> float:
	if s.widths.is_empty():
		return 0.9
	var total := 0.0
	for w in s.widths:
		total += w
	return total / s.widths.size()


## TTF path for the glyph's font (emboldened variations export as their base font).
static func _font_path(f: Font) -> String:
	if f is FontVariation and (f as FontVariation).base_font:
		return (f as FontVariation).base_font.resource_path
	return f.resource_path


static func _same_file(a: String, b: String) -> bool:
	return ProjectSettings.globalize_path(a).simplify_path().to_lower() == ProjectSettings.globalize_path(b).simplify_path().to_lower()
