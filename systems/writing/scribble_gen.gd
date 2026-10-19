class_name ScribbleGen
extends RefCounted
## Generates the back-and-forth pencil scribble that fills a bubble.

const WIDTH_PT := 2.2


static func scribble_for(rect: Rect2, seed: int) -> Stroke:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var s := Stroke.new()
	s.tool = Stroke.Tool.PENCIL
	var c := rect.get_center()
	var half := rect.size * 0.5
	var inset := WIDTH_PT * 0.5
	var ry := half.y - inset
	var spacing := WIDTH_PT * 0.6
	var rows := maxi(int(ceil(ry * 2.0 / spacing)), 1)
	var left_to_right := true
	for i in rows + 1:
		var y := -ry + i * (ry * 2.0 / rows)
		# Half-width of the ellipse at this row, pulled in by the stroke radius.
		var t := clampf(1.0 - (y * y) / (half.y * half.y), 0.0, 1.0)
		var hx := maxf(half.x * sqrt(t) - inset, 0.0)
		var jitter := rng.randf_range(-0.15, 0.15)
		var a := c + Vector2(-hx, y + jitter)
		var b := c + Vector2(hx, y - jitter)
		if not left_to_right:
			var tmp := a
			a = b
			b = tmp
		s.points.append(a)
		s.points.append(b)
		left_to_right = not left_to_right
	var inner := rect.grow(-0.5)
	for i in s.points.size():
		s.points[i] = s.points[i].clamp(inner.position + Vector2(0.01, 0.01), inner.end - Vector2(0.01, 0.01))
		s.widths.append(WIDTH_PT)
	return s
