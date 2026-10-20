class_name CozyTheme
extends RefCounted
## "Cozy stationery" UI theme (spec §7.1): index cards and manila folders, warm and quiet.

const PAPER := Color("#F7F4EC")
const CARD_EDGE := Color("#E6DFD0")
const INK := Color("#2E2B28")
const MUTED := Color("#6E675E")
const ACCENT := Color("#E8B33A")
const ACCENT_EDGE := Color("#C9962A")
const MANILA := Color("#E3C98F")
const CHIP_BG := Color("#FFFDF8")
const CHIP_EDGE := Color("#CFC6B5")
const ERROR := Color("#9C3B2E")

static var _theme: Theme


static var _heading: FontVariation


## Fraunces at semibold with a soft optical size (the variable font defaults to its heaviest look).
static func heading_font() -> Font:
	if _heading == null:
		_heading = FontVariation.new()
		_heading.base_font = load("res://assets/fonts/Fraunces.ttf")
		_heading.variation_opentype = {"wght": 600, "opsz": 72, "SOFT": 100}
	return _heading


static func body_font() -> Font:
	return load("res://assets/fonts/AtkinsonHyperlegible-Regular.ttf")


static func bold_font() -> Font:
	return load("res://assets/fonts/AtkinsonHyperlegible-Bold.ttf")


static func get_theme() -> Theme:
	if _theme == null:
		_theme = _build()
	return _theme


static func _box(bg: Color, edge: Color, radius: int, border: int = 1, pad := Vector2(14, 8)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = edge
	s.set_border_width_all(border)
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad.x
	s.content_margin_right = pad.x
	s.content_margin_top = pad.y
	s.content_margin_bottom = pad.y
	s.anti_aliasing = true
	return s


static func _build() -> Theme:
	var t := Theme.new()
	t.default_font = body_font()
	t.default_font_size = 17

	t.set_color("font_color", "Label", INK)

	# Card: an index card with a soft shadow.
	var card := _box(PAPER, CARD_EDGE, 4, 1, Vector2(30, 26))
	card.shadow_color = Color(0, 0, 0, 0.32)
	card.shadow_size = 22
	card.shadow_offset = Vector2(0, 10)
	t.set_stylebox("panel", "PanelContainer", card)
	t.set_type_variation("Card", "PanelContainer")
	t.set_stylebox("panel", "Card", card)

	# Drop zone and inset panels.
	t.set_type_variation("Inset", "PanelContainer")
	t.set_stylebox("panel", "Inset", _box(Color("#FBF9F3"), Color("#B9B0A0"), 4, 1, Vector2(12, 10)))

	# Labels.
	t.set_type_variation("Heading", "Label")
	t.set_font("font", "Heading", heading_font())
	t.set_font_size("font_size", "Heading", 30)
	t.set_color("font_color", "Heading", INK)
	t.set_type_variation("Title", "Label")
	t.set_font("font", "Title", heading_font())
	t.set_font_size("font_size", "Title", 52)
	t.set_color("font_color", "Title", INK)
	t.set_type_variation("Muted", "Label")
	t.set_color("font_color", "Muted", MUTED)
	t.set_font_size("font_size", "Muted", 15)
	t.set_type_variation("MiniLabel", "Label")
	t.set_color("font_color", "MiniLabel", MUTED)
	t.set_font("font", "MiniLabel", bold_font())
	t.set_font_size("font_size", "MiniLabel", 12)
	t.set_type_variation("Error", "Label")
	t.set_color("font_color", "Error", ERROR)
	t.set_font_size("font_size", "Error", 15)

	# Buttons: quiet text buttons on paper.
	var flat := _box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 4, 0, Vector2(10, 6))
	var hover := _box(Color(INK, 0.06), Color(0, 0, 0, 0), 4, 0, Vector2(10, 6))
	var focus := _box(Color(0, 0, 0, 0), ACCENT, 4, 2, Vector2(10, 6))
	t.set_stylebox("normal", "Button", flat)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", hover)
	t.set_stylebox("focus", "Button", focus)
	t.set_stylebox("disabled", "Button", flat)
	t.set_color("font_color", "Button", INK)
	t.set_color("font_hover_color", "Button", INK)
	t.set_color("font_pressed_color", "Button", INK)
	t.set_color("font_focus_color", "Button", INK)
	t.set_color("font_disabled_color", "Button", Color(MUTED, 0.6))
	t.set_font_size("font_size", "Button", 18)

	# Primary: ink on paper, inverted.
	t.set_type_variation("Primary", "Button")
	t.set_stylebox("normal", "Primary", _box(INK, INK, 3, 0, Vector2(20, 11)))
	t.set_stylebox("hover", "Primary", _box(INK.lightened(0.12), INK, 3, 0, Vector2(20, 11)))
	t.set_stylebox("pressed", "Primary", _box(INK.darkened(0.2), INK, 3, 0, Vector2(20, 11)))
	t.set_stylebox("focus", "Primary", _box(Color(0, 0, 0, 0), ACCENT, 3, 2, Vector2(20, 11)))
	t.set_stylebox("disabled", "Primary", _box(Color(INK, 0.35), Color(0, 0, 0, 0), 3, 0, Vector2(20, 11)))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		t.set_color(c, "Primary", PAPER)
	t.set_color("font_disabled_color", "Primary", Color(PAPER, 0.8))
	t.set_font("font", "Primary", bold_font())

	# Chip: a pill; the selected one turns pencil-yellow.
	t.set_type_variation("Chip", "Button")
	t.set_stylebox("normal", "Chip", _box(CHIP_BG, CHIP_EDGE, 999, 1, Vector2(14, 5)))
	t.set_stylebox("hover", "Chip", _box(Color("#FFF8E6"), CHIP_EDGE, 999, 1, Vector2(14, 5)))
	t.set_stylebox("pressed", "Chip", _box(ACCENT, ACCENT_EDGE, 999, 1, Vector2(14, 5)))
	t.set_stylebox("hover_pressed", "Chip", _box(ACCENT.lightened(0.08), ACCENT_EDGE, 999, 1, Vector2(14, 5)))
	t.set_stylebox("focus", "Chip", _box(Color(0, 0, 0, 0), ACCENT_EDGE, 999, 2, Vector2(14, 5)))
	t.set_font_size("font_size", "Chip", 15)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		t.set_color(c, "Chip", INK)

	# Drop-downs (the start-time picker): a boxed field like a chip.
	t.set_stylebox("normal", "OptionButton", _box(CHIP_BG, CHIP_EDGE, 6, 1, Vector2(12, 6)))
	t.set_stylebox("hover", "OptionButton", _box(Color("#FFF8E6"), CHIP_EDGE, 6, 1, Vector2(12, 6)))
	t.set_stylebox("pressed", "OptionButton", _box(Color("#FFF8E6"), ACCENT_EDGE, 6, 1, Vector2(12, 6)))
	t.set_stylebox("focus", "OptionButton", _box(Color(0, 0, 0, 0), ACCENT_EDGE, 6, 2, Vector2(12, 6)))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		t.set_color(c, "OptionButton", INK)

	# Link-style button.
	t.set_type_variation("Link", "Button")
	t.set_stylebox("normal", "Link", flat)
	t.set_stylebox("hover", "Link", flat)
	t.set_stylebox("pressed", "Link", flat)
	t.set_stylebox("focus", "Link", focus)
	t.set_color("font_color", "Link", MUTED)
	t.set_color("font_hover_color", "Link", INK)
	t.set_font_size("font_size", "Link", 15)

	# Inputs.
	t.set_stylebox("normal", "LineEdit", _box(CHIP_BG, CHIP_EDGE, 4, 1, Vector2(10, 6)))
	t.set_stylebox("focus", "LineEdit", _box(CHIP_BG, ACCENT_EDGE, 4, 2, Vector2(10, 6)))
	t.set_color("font_color", "LineEdit", INK)
	t.set_color("font_color", "CheckBox", INK)
	t.set_color("font_hover_color", "CheckBox", INK)
	t.set_color("font_pressed_color", "CheckBox", INK)
	t.set_stylebox("normal", "CheckBox", flat)
	t.set_stylebox("hover", "CheckBox", hover)
	t.set_stylebox("pressed", "CheckBox", flat)
	t.set_stylebox("hover_pressed", "CheckBox", hover)
	# Slider: graphite track, pink-eraser grabber.
	t.set_stylebox("slider", "HSlider", _box(Color("#DDD5C6"), Color(0, 0, 0, 0), 3, 0, Vector2(0, 2)))
	t.set_stylebox("grabber_area", "HSlider", _box(MUTED, Color(0, 0, 0, 0), 3, 0, Vector2(0, 2)))
	t.set_stylebox("grabber_area_highlight", "HSlider", _box(INK, Color(0, 0, 0, 0), 3, 0, Vector2(0, 2)))
	var grab := Image.create(14, 20, false, Image.FORMAT_RGBA8)
	grab.fill(Color("#F2A5B2"))
	t.set_icon("grabber", "HSlider", ImageTexture.create_from_image(grab))
	t.set_icon("grabber_highlight", "HSlider", ImageTexture.create_from_image(grab))
	t.set_stylebox("panel", "PopupMenu", _box(PAPER, CARD_EDGE, 4, 1))
	t.set_color("font_color", "PopupMenu", INK)
	return t
