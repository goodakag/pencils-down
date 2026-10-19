class_name GlyphPlacement
extends RefCounted
## One handwritten glyph: where it sits (pt, baseline-left), its jitter, and the font that has it.

var ch: String = ""
var pos: Vector2 = Vector2.ZERO
var rot_deg: float = 0.0
var scale: float = 1.0
var font: Font
var line: int = 0
var advance: float = 0.0  # pt, before scale jitter


func center(size_pt: float) -> Vector2:
	return pos + Vector2(advance * 0.5, -size_pt * 0.35)
