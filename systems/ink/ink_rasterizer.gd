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
