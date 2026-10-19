class_name InkGeometry
extends RefCounted
## Pure geometry for pencil strokes: smoothing, speed-based width, erasing.


## Centripetal Catmull-Rom through every input point. Fewer than 3 points are returned unchanged.
static func smooth(points: PackedVector2Array, samples_per_segment: int = 4) -> PackedVector2Array:
	if points.size() < 3:
		return points
	var out := PackedVector2Array()
	var n := points.size()
	for i in n - 1:
		var p0 := points[maxi(i - 1, 0)]
		var p1 := points[i]
		var p2 := points[i + 1]
		var p3 := points[mini(i + 2, n - 1)]
		out.append(p1)
		for s in range(1, samples_per_segment):
			out.append(_centripetal(p0, p1, p2, p3, float(s) / samples_per_segment))
	out.append(points[n - 1])
	return out


static func _centripetal(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, u: float) -> Vector2:
	var t0 := 0.0
	var t1 := t0 + maxf(sqrt(p0.distance_to(p1)), 1e-4)
	var t2 := t1 + maxf(sqrt(p1.distance_to(p2)), 1e-4)
	var t3 := t2 + maxf(sqrt(p2.distance_to(p3)), 1e-4)
	var t := lerpf(t1, t2, u)
	var a1 := p0 * (t1 - t) / (t1 - t0) + p1 * (t - t0) / (t1 - t0)
	var a2 := p1 * (t2 - t) / (t2 - t1) + p2 * (t - t1) / (t2 - t1)
	var a3 := p2 * (t3 - t) / (t3 - t2) + p3 * (t - t2) / (t3 - t2)
	var b1 := a1 * (t2 - t) / (t2 - t0) + a2 * (t - t0) / (t2 - t0)
	var b2 := a2 * (t3 - t) / (t3 - t1) + a3 * (t - t1) / (t3 - t1)
	return b1 * (t2 - t) / (t2 - t1) + b2 * (t - t1) / (t2 - t1)


## Faster strokes are thinner, like a real pencil.
static func width_for_speed(speed_pt_s: float, base_w_pt: float = 0.9, pressure: float = 1.0) -> float:
	return base_w_pt * pressure * lerpf(1.15, 0.7, clampf(speed_pt_s / 400.0, 0.0, 1.0))


## Removes points within radius and returns the remaining runs of 2+ points (ids = -1).
static func erase(stroke: Stroke, center: Vector2, radius: float) -> Array[Stroke]:
	if not hits(stroke, center, radius):
		var same: Array[Stroke] = []
		_flush(same, stroke.points, stroke.widths, stroke)
		return same
	stroke = _resampled(stroke, radius * 0.5)
	var out: Array[Stroke] = []
	var run_pts := PackedVector2Array()
	var run_w := PackedFloat32Array()
	for i in stroke.points.size():
		var p := stroke.points[i]
		if p.distance_to(center) <= radius:
			_flush(out, run_pts, run_w, stroke)
			run_pts = PackedVector2Array()
			run_w = PackedFloat32Array()
		else:
			run_pts.append(p)
			run_w.append(stroke.widths[i] if i < stroke.widths.size() else 1.0)
	_flush(out, run_pts, run_w, stroke)
	return out


## Inserts points so no segment is longer than max_step (fast strokes are sampled sparsely).
static func _resampled(stroke: Stroke, max_step: float) -> Stroke:
	var s := Stroke.new()
	s.tool = stroke.tool
	s.t_start = stroke.t_start
	var n := stroke.points.size()
	for i in n:
		var w := stroke.widths[i] if i < stroke.widths.size() else 1.0
		if i > 0:
			var a := stroke.points[i - 1]
			var b := stroke.points[i]
			var wa := stroke.widths[i - 1] if i - 1 < stroke.widths.size() else 1.0
			var steps := int(ceil(a.distance_to(b) / maxf(max_step, 0.01)))
			for k in range(1, steps):
				var t := float(k) / steps
				s.points.append(a.lerp(b, t))
				s.widths.append(lerpf(wa, w, t))
		s.points.append(stroke.points[i])
		s.widths.append(w)
	return s


static func _flush(out: Array[Stroke], pts: PackedVector2Array, w: PackedFloat32Array, src: Stroke) -> void:
	if pts.size() < 2:
		return
	var s := Stroke.new()
	s.tool = src.tool
	s.points = pts
	s.widths = w
	s.t_start = src.t_start
	out.append(s)


## True when any segment of the stroke passes within radius of p.
static func hits(stroke: Stroke, p: Vector2, radius: float) -> bool:
	var pts := stroke.points
	if pts.size() == 1:
		return pts[0].distance_to(p) <= radius
	for i in pts.size() - 1:
		if Geometry2D.get_closest_point_to_segment(p, pts[i], pts[i + 1]).distance_to(p) <= radius:
			return true
	return false


## Indices of glyph centers within radius of p.
static func text_hit(centers: PackedVector2Array, p: Vector2, radius: float) -> PackedInt32Array:
	var out := PackedInt32Array()
	for i in centers.size():
		if centers[i].distance_to(p) <= radius:
			out.append(i)
	return out
