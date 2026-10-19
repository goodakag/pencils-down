class_name HandwritingLayout
extends RefCounted
## Lays out typed text as handwriting: real glyph advances, word wrap, and seeded per-glyph jitter.

const FONTS := {
	&"caveat": "res://assets/fonts/Caveat.ttf",
	&"kalam": "res://assets/fonts/Kalam-Regular.ttf",
	&"patrick_hand": "res://assets/fonts/PatrickHand-Regular.ttf",
	&"shadows": "res://assets/fonts/ShadowsIntoLight.ttf",
	&"indie_flower": "res://assets/fonts/IndieFlower-Regular.ttf",
}
const FALLBACKS := [
	"res://assets/fonts/NotoSans.ttf",
	"res://assets/fonts/NotoSansMath-Regular.ttf",
]
const LINE_HEIGHT := 1.35
const ROT_JITTER_DEG := 0.6
const SCALE_JITTER := 0.04
const BASELINE_JITTER_PT := 0.3
const MEASURE_PX := 64

static var _cache: Dictionary = {}


static func font_for(id: StringName) -> FontFile:
	return _load(FONTS.get(id, FONTS[&"caveat"]))


static func fallback_fonts() -> Array[FontFile]:
	var out: Array[FontFile] = []
	for p in FALLBACKS:
		out.append(_load(p))
	return out


static func _load(path: String) -> FontFile:
	if not _cache.has(path):
		_cache[path] = load(path)
	return _cache[path]


## First font that has the character: the chosen handwriting font, then the fallbacks.
static func font_with(ch: String, primary: FontFile) -> FontFile:
	var code := ch.unicode_at(0)
	if primary.has_char(code):
		return primary
	for f in fallback_fonts():
		if f.has_char(code):
			return f
	return primary


static func advance_of(ch: String, font: Font, size_pt: float) -> float:
	return font.get_char_size(ch.unicode_at(0), MEASURE_PX).x * size_pt / MEASURE_PX


static func layout(text: String, origin: Vector2, size_pt: float, font_id: StringName, seed: int, max_x: float) -> Array[GlyphPlacement]:
	var primary := font_for(font_id)
	var out: Array[GlyphPlacement] = []
	var line := 0
	var x := origin.x
	var chars := text.split("")  # one entry per Unicode character
	var i := 0
	while i < chars.size():
		var ch := chars[i]
		if ch == "\n":
			out.append(_place(ch, Vector2(x, _line_y(origin, line, size_pt)), 0.0, primary, line, seed, out.size()))
			line += 1
			x = origin.x
			i += 1
			continue
		# Wrap whole words: measure the word starting here.
		if ch != " " and (i == 0 or chars[i - 1] == " " or chars[i - 1] == "\n"):
			var word_w := 0.0
			var j := i
			while j < chars.size() and chars[j] != " " and chars[j] != "\n":
				word_w += advance_of(chars[j], font_with(chars[j], primary), size_pt)
				j += 1
			if x > origin.x and x + word_w > max_x:
				line += 1
				x = origin.x
		var f := font_with(ch, primary)
		var adv := advance_of(ch, f, size_pt)
		if ch != " " and x > origin.x and x + adv > max_x:
			line += 1  # a single word longer than the line breaks mid-word
			x = origin.x
		out.append(_place(ch, Vector2(x, _line_y(origin, line, size_pt)), adv, f, line, seed, out.size()))
		x += adv
		i += 1
	return out


static func _line_y(origin: Vector2, line: int, size_pt: float) -> float:
	return origin.y + line * size_pt * LINE_HEIGHT


static func _place(ch: String, pos: Vector2, adv: float, font: Font, line: int, seed: int, index: int) -> GlyphPlacement:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed, index])
	var g := GlyphPlacement.new()
	g.ch = ch
	g.rot_deg = rng.randf_range(-ROT_JITTER_DEG, ROT_JITTER_DEG)
	g.scale = 1.0 + rng.randf_range(-SCALE_JITTER, SCALE_JITTER)
	g.pos = pos + Vector2(0, rng.randf_range(-BASELINE_JITTER_PT, BASELINE_JITTER_PT))
	g.font = font
	g.line = line
	g.advance = adv
	return g


## Text size from the page's line spacing (pt). Callers use 14.0 when the spacing is unknown.
static func auto_size(line_spacing_pt: float) -> float:
	return clampf(line_spacing_pt * 0.62, 9.0, 28.0)
