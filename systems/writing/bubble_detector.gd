class_name BubbleDetector
extends RefCounted
## Finds the answer bubble under a Shift-click. Rects are in PDF points (origin top-left).

const FALLBACK_DIAMETER_PT := 25.51  # 9 mm
const SNAP_DISTANCE_PT := 12.0
const MIN_R_PT := 4.0
const MAX_R_PT := 14.0
const SEARCH_PT := 12.0
const MIN_SCORE := 0.25


## A single letter A–E printed near the click (the usual "letter in a circle" bubble).
static func from_text_words(words: Array, at_pt: Vector2) -> Rect2:
	var best := Rect2()
	var best_d := SNAP_DISTANCE_PT
	for w in words:
		var t := String(w.text).strip_edges()
		var r: Rect2 = w.rect
		if t.length() != 1 or not "ABCDE".contains(t.to_upper()):
			continue
		if r.size.x < 2.0 or r.size.y < 2.0 or r.size.x > 20.0 or r.size.y > 20.0:
			continue
		var d := r.get_center().distance_to(at_pt)
		if d <= best_d:
			best_d = d
			var side := maxf(r.size.x, r.size.y) * 1.6
			best = Rect2(r.get_center() - Vector2(side, side) * 0.5, Vector2(side, side))
	return best


## Looks for a dark printed ring around at_pt in the rendered page image.
static func from_image(img: Image, px_per_pt: float, at_pt: Vector2) -> Rect2:
	var reach := SEARCH_PT + MAX_R_PT + 2.0
	var origin := ((at_pt - Vector2(reach, reach)) * px_per_pt).floor()
	var region := Rect2i(Vector2i(origin), Vector2i(Vector2(reach, reach) * 2.0 * px_per_pt))
	region = region.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	if region.size.x < 4 or region.size.y < 4:
		return Rect2()
	var crop := img.get_region(region)
	crop.convert(Image.FORMAT_L8)
	var g := _Gray.new(crop.get_data(), region.size.x, region.size.y, Vector2(region.position) / px_per_pt, px_per_pt)

	# Coarse pass: 1 pt centers, 0.5 pt radii, 16 ring samples.
	var best_score := -1.0
	var best_c := Vector2.ZERO
	var best_r := 0.0
	for dy in range(-int(SEARCH_PT), int(SEARCH_PT) + 1):
		for dx in range(-int(SEARCH_PT), int(SEARCH_PT) + 1):
			var c := at_pt + Vector2(dx, dy)
			var r := MIN_R_PT
			while r <= MAX_R_PT:
				var s := g.score(c, r, 16)
				if s > best_score:
					best_score = s
					best_c = c
					best_r = r
				r += 0.5
	if best_score < MIN_SCORE:
		return Rect2()
	# Fine pass around the best: 0.25 pt steps, 32 samples.
	var fine_score := -1.0
	var fine_c := best_c
	var fine_r := best_r
	for iy in range(-4, 5):
		for ix in range(-4, 5):
			var c := best_c + Vector2(ix, iy) * 0.25
			for ir in range(-4, 5):
				var r := best_r + ir * 0.25
				if r < MIN_R_PT * 0.75:
					continue
				var s := g.score(c, r, 32)
				if s > fine_score:
					fine_score = s
					fine_c = c
					fine_r = r
	return Rect2(fine_c - Vector2(fine_r, fine_r), Vector2(fine_r, fine_r) * 2.0)


## Never empty: printed letter (refined by the image), then image ring, then a 9 mm default.
static func find(words: Array, img: Image, px_per_pt: float, at_pt: Vector2) -> Rect2:
	var by_text := from_text_words(words, at_pt)
	if by_text != Rect2():
		var refined := from_image(img, px_per_pt, by_text.get_center()) if img else Rect2()
		return refined if refined != Rect2() else by_text
	var by_image := from_image(img, px_per_pt, at_pt) if img else Rect2()
	if by_image != Rect2():
		return by_image
	var s := Vector2(FALLBACK_DIAMETER_PT, FALLBACK_DIAMETER_PT)
	return Rect2(at_pt - s * 0.5, s)


class _Gray:
	var data: PackedByteArray
	var w: int
	var h: int
	var origin_pt: Vector2
	var ppp: float

	func _init(d: PackedByteArray, width: int, height: int, o: Vector2, px_per_pt: float) -> void:
		data = d
		w = width
		h = height
		origin_pt = o
		ppp = px_per_pt

	func dark(p_pt: Vector2) -> float:
		var p := (p_pt - origin_pt) * ppp
		var x := int(p.x)
		var y := int(p.y)
		if x < 0 or y < 0 or x >= w or y >= h:
			return 0.0
		return 1.0 - data[y * w + x] / 255.0

	## Mean darkness on the ring minus mean darkness 2 px inside it.
	func score(c: Vector2, r: float, samples: int) -> float:
		var inner_r := r - 2.0 / ppp
		var ring := 0.0
		var inner := 0.0
		for i in samples:
			var a := TAU * i / samples
			var dir := Vector2(cos(a), sin(a))
			ring += dark(c + dir * r)
			inner += dark(c + dir * inner_r)
		return (ring - inner) / samples
