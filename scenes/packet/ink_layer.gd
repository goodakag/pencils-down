class_name InkLayer
extends Node2D
## Draws one page's ink (strokes + handwriting) into its PaperPage SubViewport.
## Coordinates: PDF points scaled by dpi / 72.

var ink: PageInk
var scale_px: float = 150.0 / 72.0
var live_stroke: Stroke = null      # stroke being drawn right now
var live_text: Array = []           # [{mark: TextMark, revealed: int, caret: bool}]
var hidden_ids: PackedInt32Array = PackedInt32Array()  # strokes animated elsewhere (Quick Fill)


func show_ink(page_ink: PageInk, dpi: float) -> void:
	ink = page_ink
	scale_px = dpi / 72.0
	refresh()


func refresh() -> void:
	queue_redraw()
	var vp := get_viewport() as SubViewport
	if vp:
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE


func _draw() -> void:
	if ink == null:
		return
	for s in ink.strokes:
		if not hidden_ids.has(s.id):
			_draw_stroke(s)
	if live_stroke:
		_draw_stroke(live_stroke)
	var editing := {}
	for lt in live_text:
		editing[lt.mark] = true
		_draw_text(lt.mark, lt.revealed, lt.caret)
	for t in ink.texts:
		if not editing.has(t):
			_draw_text(t, -1, false)


func _draw_stroke(s: Stroke) -> void:
	if s.points.size() == 0:
		return
	var pts := PackedVector2Array()
	var smooth := InkGeometry.smooth(s.points) if s.points.size() > 2 else s.points
	for p in smooth:
		pts.append(p * scale_px)
	var w := 0.9
	if s.widths.size() > 0:
		var total := 0.0
		for x in s.widths:
			total += x
		w = total / s.widths.size()
	var wpx := maxf(w * scale_px, 1.0)
	if pts.size() == 1:
		draw_circle(pts[0], wpx * 0.5, Color.WHITE)
	else:
		draw_polyline(pts, Color.WHITE, wpx, true)
		draw_circle(pts[0], wpx * 0.5, Color.WHITE)
		draw_circle(pts[pts.size() - 1], wpx * 0.5, Color.WHITE)


func _draw_text(t: TextMark, revealed: int, caret: bool) -> void:
	var glyphs := HandwritingLayout.layout(t.text, t.origin, t.size_pt, t.font_id, t.seed, _max_x(t))
	var n := glyphs.size() if revealed < 0 else mini(revealed, glyphs.size())
	var last_end := t.origin
	for i in n:
		var g := glyphs[i]
		if g.ch == "\n":
			last_end = Vector2(t.origin.x, g.pos.y + t.size_pt * HandwritingLayout.LINE_HEIGHT)
			continue
		var px := g.pos * scale_px
		draw_set_transform(px, deg_to_rad(g.rot_deg), Vector2(g.scale, g.scale))
		draw_char(g.font, Vector2.ZERO, g.ch, int(round(t.size_pt * scale_px)), Color.WHITE)
		last_end = g.pos + Vector2(g.advance, 0)
	draw_set_transform(Vector2.ZERO)
	if caret and int(Time.get_ticks_msec() / 550) % 2 == 0:
		draw_circle((last_end + Vector2(t.size_pt * 0.15, -t.size_pt * 0.12)) * scale_px, 0.9 * scale_px, Color.WHITE)


## Right margin for wrapping (shared with export and hit-testing).
func _max_x(_t: TextMark) -> float:
	var vp := get_viewport() as SubViewport
	if vp == null:
		return 100000.0
	return HandwritingLayout.wrap_x(Vector2(vp.size) / scale_px)
