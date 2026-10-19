class_name InkRasterizer
extends RefCounted
## CPU rasterizer for pencil strokes (export overlay, fallback export). Works headless.

const GRAPHITE := Color("#3B3A3C")
const EXPORT_ALPHA := 0.92


## Transparent RGBA8 image of the page with pencil strokes. Overlaps use max alpha, so retraced lines
## don't darken unnaturally.
static func rasterize(ink: PageInk, page_size_pt: Vector2, dpi: float, color: Color = Color(GRAPHITE, EXPORT_ALPHA)) -> Image:
	var scale := dpi / 72.0
	var w := int(ceil(page_size_pt.x * scale - 0.001))
	var h := int(ceil(page_size_pt.y * scale - 0.001))
	var base := Image.create(w, h, false, Image.FORMAT_RGBA8)
	base.fill(Color(color.r, color.g, color.b, 0.0))
	if ink.strokes.is_empty():
		return base
	var data := base.get_data()
	var max_a := color.a
	for s in ink.strokes:
		if s.tool != Stroke.Tool.PENCIL:
			continue
		var pts := s.points
		if pts.size() == 1:
			_capsule(data, w, h, pts[0] * scale, pts[0] * scale, _r(s, 0, scale), _r(s, 0, scale), max_a)
		for i in pts.size() - 1:
			_capsule(data, w, h, pts[i] * scale, pts[i + 1] * scale, _r(s, i, scale), _r(s, i + 1, scale), max_a)
	return Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, data)


static func _r(s: Stroke, i: int, scale: float) -> float:
	var wpt := s.widths[i] if i < s.widths.size() else 1.0
	return wpt * 0.5 * scale


## Fills a capsule from a to b (radius ra → rb) with anti-aliased coverage.
static func _capsule(data: PackedByteArray, w: int, h: int, a: Vector2, b: Vector2, ra: float, rb: float, max_a: float) -> void:
	var rmax := maxf(ra, rb) + 1.0
	var x0 := maxi(int(floor(minf(a.x, b.x) - rmax)), 0)
	var x1 := mini(int(ceil(maxf(a.x, b.x) + rmax)), w - 1)
	var y0 := maxi(int(floor(minf(a.y, b.y) - rmax)), 0)
	var y1 := mini(int(ceil(maxf(a.y, b.y) + rmax)), h - 1)
	if x0 > x1 or y0 > y1:
		return
	var ab := b - a
	var len2 := ab.length_squared()
	for y in range(y0, y1 + 1):
		var py := y + 0.5
		var row := y * w
		for x in range(x0, x1 + 1):
			var p := Vector2(x + 0.5, py)
			var t := 0.0
			if len2 > 0.0:
				t = clampf((p - a).dot(ab) / len2, 0.0, 1.0)
			var d := p.distance_to(a + ab * t)
			var cov := clampf(lerpf(ra, rb, t) + 0.5 - d, 0.0, 1.0)
			if cov <= 0.0:
				continue
			var idx := (row + x) * 4 + 3
			var v := int(cov * max_a * 255.0 + 0.5)
			if v > data[idx]:
				data[idx] = v


## Draws handwritten glyphs into `img` (RGBA8) from the fonts' CPU glyph caches (works headless).
## Rotation jitter is ignored; position and scale are kept.
static func rasterize_text(img: Image, placements: Array[GlyphPlacement], size_pt: float, dpi: float, color: Color) -> void:
	var k := dpi / 72.0
	for g in placements:
		if g.ch == " " or g.ch == "\n":
			continue
		var ff := _font_file(g.font)
		if ff == null:
			continue
		var fs := maxi(int(round(size_pt * g.scale * k)), 4)
		var sz := Vector2i(fs, 0)
		var gi := ff.get_glyph_index(fs, g.ch.unicode_at(0), 0)
		ff.render_glyph(0, sz, gi)
		var tex := ff.get_glyph_texture_idx(0, sz, gi)
		if tex < 0:
			continue
		var atlas := ff.get_texture_image(0, sz, tex)
		var uv := Rect2i(ff.get_glyph_uv_rect(0, sz, gi))
		if atlas == null or uv.size.x <= 0 or uv.size.y <= 0:
			continue
		var glyph := atlas.get_region(uv)
		var luminance_coverage := glyph.get_format() == Image.FORMAT_L8
		var origin := Vector2i((g.pos * k + ff.get_glyph_offset(0, sz, gi)).round())
		for y in glyph.get_height():
			var dy := origin.y + y
			if dy < 0 or dy >= img.get_height():
				continue
			for x in glyph.get_width():
				var dx := origin.x + x
				if dx < 0 or dx >= img.get_width():
					continue
				var px := glyph.get_pixel(x, y)
				var cov := px.r if luminance_coverage else px.a
				if cov <= 0.0:
					continue
				var a := cov * color.a
				if a > img.get_pixel(dx, dy).a:
					img.set_pixel(dx, dy, Color(color.r, color.g, color.b, a))


static func _font_file(f: Font) -> FontFile:
	if f is FontFile:
		return f
	if f is FontVariation and (f as FontVariation).base_font is FontFile:
		return (f as FontVariation).base_font
	return null
