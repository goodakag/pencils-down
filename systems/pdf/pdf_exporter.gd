class_name PdfExporter
extends RefCounted
## Writes the finished test: the original PDF untouched underneath, pencil strokes as vector paths,
## typed answers as real text (so an AI marker can read them), scratch sheets appended at the end.

const SCRATCH_SIZE := Vector2(612, 792)
const GRAPHITE := Color(0.231, 0.227, 0.235, 0.92)
const TEXT_COLOR := Color(0.231, 0.227, 0.235, 1.0)


## Returns {"ok": bool, "mode": "vector"|"images", "error": String}.
static func export(doc: PdfDoc, attempt: Attempt, out_path: String) -> Dictionary:
	PdfDoc.lock()  # PDFium is not thread-safe; page renders may be running on workers
	var r := _export_locked(doc, attempt, out_path)
	PdfDoc.unlock()
	return r


static func _export_locked(doc: PdfDoc, attempt: Attempt, out_path: String) -> Dictionary:
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
		InkRasterizer.rasterize_text(overlay, HandwritingLayout.layout_mark(t, size), t.size_pt, IMAGE_DPI, TEXT_COLOR)
	var out := page_img.duplicate()
	out.convert(Image.FORMAT_RGBA8)
	if overlay.get_size() != out.get_size():
		overlay.resize(out.get_width(), out.get_height())
	out.blend_rect(overlay, Rect2i(Vector2i.ZERO, overlay.get_size()), Vector2i.ZERO)
	return out


static func _draw_ink(page: PDFPage, ink: PageInk) -> void:
	var rot := page.get_rotation()
	var size := page.get_page_size()
	for s in ink.strokes:
		if s.tool != Stroke.Tool.PENCIL or s.points.is_empty():
			continue
		var pts := InkGeometry.smooth(s.points) if s.points.size() > 2 else s.points
		if pts.size() == 1:
			pts = PackedVector2Array([pts[0], pts[0] + Vector2(0.01, 0)])
		var mapped := PackedVector2Array()
		for p in pts:
			mapped.append(to_page_space(p, rot, size))
		page.add_path(mapped, Color(0, 0, 0, 0), GRAPHITE, _mean_width(s), false)
	for t in ink.texts:
		_draw_text_mark(page, t)


const TEXT_DPI := 300.0
const HIDDEN := Color(0, 0, 0, 0)


## A typed answer: the handwriting as a small cropped image (embedding the handwriting font costs
## ~200 KB per add_text call), plus the same words as invisible standard-font text so an AI
## marker can read them exactly.
static func _draw_text_mark(page: PDFPage, t: TextMark) -> void:
	var size := page.get_page_size()
	var glyphs := HandwritingLayout.layout_mark(t, size)  # get_page_size() is the rotated (display) size
	if glyphs.is_empty():
		return
	var bounds := Rect2(glyphs[0].pos, Vector2.ZERO)
	for g in glyphs:
		bounds = bounds.expand(g.pos + Vector2(0, -t.size_pt)).expand(g.pos + Vector2(g.advance, t.size_pt * 0.4))
	bounds = bounds.grow(2.0)
	var k := TEXT_DPI / 72.0
	var img := Image.create(maxi(int(ceil(bounds.size.x * k)), 1), maxi(int(ceil(bounds.size.y * k)), 1), false, Image.FORMAT_RGBA8)
	img.fill(Color(TEXT_COLOR, 0.0))
	var shifted: Array[GlyphPlacement] = []
	for g in glyphs:
		var c := GlyphPlacement.new()
		c.ch = g.ch
		c.pos = g.pos - bounds.position
		c.rot_deg = g.rot_deg
		c.scale = g.scale
		c.font = g.font
		c.line = g.line
		c.advance = g.advance
		shifted.append(c)
	InkRasterizer.rasterize_text(img, shifted, t.size_pt, TEXT_DPI, TEXT_COLOR)
	InkRasterizer.embolden(img)
	var rot := page.get_rotation()
	# The page turns its content for display, so turn the image the other way first.
	match rot:
		1: img.rotate_90(COUNTERCLOCKWISE)
		2: img.rotate_180()
		3: img.rotate_90(CLOCKWISE)
	page.add_image(img, rect_to_page_space(bounds, rot, size), false, 1.0)
	# Invisible, extractable text, one call per line.
	var line := -1
	var text := ""
	var origin := Vector2.ZERO
	for g in glyphs:
		if g.line != line:
			if text.strip_edges() != "":
				page.add_text(plain_text(text), to_page_space(origin, rot, size), "Helvetica", t.size_pt * 0.75, HIDDEN, PDFPage.ALIGN_LEFT, false, false)
			line = g.line
			text = ""
			origin = g.pos
		if g.ch != "\n":
			text += g.ch
	if text.strip_edges() != "":
		page.add_text(plain_text(text), to_page_space(origin, rot, size), "Helvetica", t.size_pt * 0.75, HIDDEN, PDFPage.ALIGN_LEFT, false, false)


## Display point (what the player saw: top-left origin, rotation applied) → the coordinates
## PDFium-GDE's add_* calls expect on a page with /Rotate. Measured: the extension flips y with the
## rotated page height, then the page's rotation is applied on display.
## Standard PDF fonts only cover Latin-1, so the invisible text layer spells out math and Greek
## symbols an AI marker must not lose. Anything else unmapped becomes [U+XXXX].
const SPELLED := {
	"√": "sqrt", "≤": "<=", "≥": ">=", "≠": "!=", "≈": "~=", "∞": "infinity", "→": "->", "←": "<-",
	"∫": "integral", "∑": "sum", "∏": "product", "∂": "d", "∆": "Delta", "−": "-", "·": "*", "…": "...",
	"π": "pi", "θ": "theta", "α": "alpha", "β": "beta", "γ": "gamma", "δ": "delta", "Δ": "Delta",
	"ε": "epsilon", "λ": "lambda", "μ": "mu", "σ": "sigma", "Σ": "Sigma", "φ": "phi", "ω": "omega",
	"Ω": "Omega", "ρ": "rho", "τ": "tau", "⁰": "^0", "⁴": "^4", "⁵": "^5", "⁶": "^6", "⁷": "^7",
	"⁸": "^8", "⁹": "^9", "ⁿ": "^n", "₀": "_0", "₁": "_1", "₂": "_2", "₃": "_3", "“": "\"", "”": "\"",
	"‘": "'", "’": "'", "–": "-", "—": "-",
}


static func plain_text(s: String) -> String:
	var out := ""
	for ch in s.split(""):
		var code := ch.unicode_at(0)
		if code < 256:
			out += ch
		elif SPELLED.has(ch):
			out += SPELLED[ch]
		else:
			out += "[U+%04X]" % code
	return out


static func to_page_space(p: Vector2, rot: int, rotated_size: Vector2) -> Vector2:
	var w := rotated_size.y if rot % 2 == 1 else rotated_size.x  # unrotated width
	var h := rotated_size.x if rot % 2 == 1 else rotated_size.y  # unrotated height
	match rot:
		1: return Vector2(p.y, rotated_size.y - p.x)
		2: return Vector2(w - p.x, rotated_size.y - p.y)
		3: return Vector2(w - p.y, rotated_size.y - h + p.x)
	return p


static func rect_to_page_space(r: Rect2, rot: int, rotated_size: Vector2) -> Rect2:
	var a := to_page_space(r.position, rot, rotated_size)
	var out := Rect2(a, Vector2.ZERO)
	for c in [Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
		out = out.expand(to_page_space(c, rot, rotated_size))
	return out


static func _mean_width(s: Stroke) -> float:
	if s.widths.is_empty():
		return 0.9
	var total := 0.0
	for w in s.widths:
		total += w
	return total / s.widths.size()


static func _same_file(a: String, b: String) -> bool:
	return ProjectSettings.globalize_path(a).simplify_path().to_lower() == ProjectSettings.globalize_path(b).simplify_path().to_lower()
