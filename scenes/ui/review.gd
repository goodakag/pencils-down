class_name ReviewScreen
extends Control
## After handing in: your marked pages, a few stats, Save PDF, and the AI marking prompt (spec §4.4).

const VIEW_DPI := 110.0
const THUMB_DPI := 24.0
const FULL_CACHE := 3  # full-resolution pages kept in memory
const MAIN_SCENE := "res://scenes/main.tscn"
const TEST_SCENE := "res://scenes/flow/test_scene.tscn"

## Set by History before opening an older attempt; otherwise the attempt just finished is shown.
static var pending_attempt_path: String = ""

var attempt: Attempt
var doc: PdfDoc
var _missing_reason: String = ""
var _missing_label: Label
var _page := 0
var _zoom := 0  # 0 = fit width, 1 = 100%, 2 = 200%
var _cache: Dictionary = {}  # page -> Image at VIEW_DPI (most recent FULL_CACHE pages)
var _cache_order: Array[int] = []
var _view: TextureRect
var _scroll: ScrollContainer
var _strip: VBoxContainer
var _page_label: Label
var _status: Label
var _copy_btn: Button
var _save_dialog: FileDialog


func _ready() -> void:
	theme = CozyTheme.get_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_load_attempt()
	var bg := ColorRect.new()
	bg.color = Color("#E9E2D3")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	if attempt == null or doc == null:
		_build_missing()
		return
	_build()
	_show_page(0)


func _load_attempt() -> void:
	if pending_attempt_path != "":
		attempt = Session.store.load_attempt(pending_attempt_path)
		pending_attempt_path = ""
		if attempt:
			doc = PdfService.open(attempt.pdf_path)
			if doc and not Session.pdf_matches(attempt, doc):
				doc = null
				_missing_reason = "The PDF at %s isn't the one this test was taken on." % attempt.pdf_path
	else:
		attempt = Session.attempt
		doc = Session.doc


func _build_missing() -> void:
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(c)
	var card := PanelContainer.new()
	card.theme_type_variation = "Card"
	c.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	card.add_child(v)
	var l := Label.new()
	_missing_label = l
	l.text = _missing_reason if _missing_reason != "" else "Can't find the original PDF at %s." % (attempt.pdf_path if attempt else "?")
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 460
	v.add_child(l)
	if attempt:
		var locate := Button.new()
		locate.text = "Locate…"
		locate.theme_type_variation = "Primary"
		var dlg := FileDialog.new()
		dlg.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		dlg.access = FileDialog.ACCESS_FILESYSTEM
		dlg.use_native_dialog = true
		dlg.filters = PackedStringArray(["*.pdf ; PDF documents"])
		dlg.file_selected.connect(_relocate)
		add_child(dlg)
		locate.pressed.connect(func() -> void: dlg.popup_centered_ratio(0.6))
		v.add_child(locate)
	var back := Button.new()
	back.text = "Back to menu"
	back.pressed.connect(func() -> void: get_tree().change_scene_to_file(MAIN_SCENE))
	v.add_child(back)


## The original PDF moved: point the attempt at its new location and reopen.
func _relocate(path: String) -> void:
	var d := PdfService.open(path)
	if d == null or not Session.pdf_matches(attempt, d):
		_missing_label.text = "That isn't the PDF this test was taken on. Choose the original file."
		return
	attempt.pdf_path = path
	var archived := Session.store.archive(attempt)
	pending_attempt_path = archived
	get_tree().reload_current_scene()


func _build() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	margin.add_child(row)

	# Left: the card with stats and actions.
	var card := PanelContainer.new()
	card.theme_type_variation = "Card"
	card.custom_minimum_size.x = 380
	row.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	card.add_child(v)
	var h := Label.new()
	h.text = "Handed in"
	h.theme_type_variation = "Heading"
	v.add_child(h)
	var title := Label.new()
	title.text = attempt.test_title
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(title)
	var when := Label.new()
	when.text = MarkingPrompt.local_date_time(attempt.created_unix)
	when.theme_type_variation = "Muted"
	v.add_child(when)
	v.add_child(MainMenuCard._gap(4))
	var used := float(attempt.timer_state.get("elapsed", 0.0))
	var total := float(attempt.timer_state.get("duration_s", used))
	_stat(v, "Time used", "%s of %s" % [MarkingPrompt.mmss(used), MarkingPrompt.mmss(total)])
	_stat(v, "Erasures", str(attempt.erase_count))
	v.add_child(_mini("Time per page"))
	var per := GridContainer.new()
	per.columns = 2
	per.add_theme_constant_override("h_separation", 18)
	v.add_child(per)
	for i in attempt.page_time_s.size():
		var a := Label.new()
		a.text = "Page %d" % (i + 1)
		a.theme_type_variation = "Muted"
		per.add_child(a)
		var b := Label.new()
		b.text = MarkingPrompt.mmss(attempt.page_time_s[i])
		per.add_child(b)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)
	var save := Button.new()
	save.text = "Save PDF…"
	save.theme_type_variation = "Primary"
	save.pressed.connect(_on_save)
	v.add_child(save)
	_status = Label.new()
	_status.theme_type_variation = "Muted"
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_status)
	_copy_btn = Button.new()
	_copy_btn.text = "Copy marking prompt"
	_copy_btn.tooltip_text = "Paste it into an AI along with the saved PDF and your answer key."
	_copy_btn.pressed.connect(_on_copy)
	v.add_child(_copy_btn)
	var retake := Button.new()
	retake.text = "Retake"
	retake.pressed.connect(_on_retake)
	v.add_child(retake)
	var back := Button.new()
	back.text = "Back to menu"
	back.pressed.connect(func() -> void: get_tree().change_scene_to_file(MAIN_SCENE))
	v.add_child(back)

	# Middle: page strip.
	var strip_scroll := ScrollContainer.new()
	strip_scroll.custom_minimum_size.x = 96
	strip_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	row.add_child(strip_scroll)
	_strip = VBoxContainer.new()
	_strip.add_theme_constant_override("separation", 10)
	strip_scroll.add_child(_strip)
	for i in attempt.pages.size():
		var b := Button.new()
		b.icon = ImageTexture.create_from_image(_thumb(i))
		b.expand_icon = true
		b.custom_minimum_size = Vector2(80, 104)
		b.tooltip_text = "Page %d" % (i + 1)
		b.pressed.connect(_show_page.bind(i))
		_strip.add_child(b)

	# Right: the page.
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	var bar := HBoxContainer.new()
	right.add_child(bar)
	_page_label = Label.new()
	_page_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(_page_label)
	var zoom := ChipRow.new(["Fit", "100%", "200%"], [0, 1, 2], 0)
	zoom.custom_minimum_size.x = 230
	zoom.selected.connect(func(z: Variant) -> void:
		_zoom = int(z)
		_apply_zoom())
	bar.add_child(zoom)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(_scroll)
	_view = TextureRect.new()
	_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_scroll.add_child(_view)
	_scroll.resized.connect(_apply_zoom)

	_save_dialog = FileDialog.new()
	_save_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_save_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_save_dialog.use_native_dialog = true
	_save_dialog.filters = PackedStringArray(["*.pdf ; PDF documents"])
	_save_dialog.title = "Save your marked test"
	_save_dialog.file_selected.connect(save_to)
	add_child(_save_dialog)


func _stat(parent: Control, label: String, value: String) -> void:
	var r := HBoxContainer.new()
	parent.add_child(r)
	var a := Label.new()
	a.text = label
	a.theme_type_variation = "Muted"
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(a)
	var b := Label.new()
	b.text = value
	r.add_child(b)


func _mini(text: String) -> Label:
	var l := Label.new()
	l.text = text.to_upper()
	l.theme_type_variation = "MiniLabel"
	return l


## The page as rendered at VIEW_DPI with the pencil marks and handwriting on top. Only the most
## recently viewed FULL_CACHE pages stay in memory.
func page_image(i: int) -> Image:
	if not _cache.has(i):
		_cache[i] = _composite(i, VIEW_DPI)
	_cache_order.erase(i)
	_cache_order.append(i)
	while _cache_order.size() > FULL_CACHE:
		_cache.erase(_cache_order.pop_front())
	return _cache[i]


func full_pages_cached() -> int:
	return _cache.size()


func _composite(i: int, dpi: float) -> Image:
	var img := doc.render_page(i, dpi)
	var size := doc.page_size_pt(i)
	var ink := attempt.pages[i]
	var overlay := InkRasterizer.rasterize(ink, size, dpi)
	for t in ink.texts:
		InkRasterizer.rasterize_text(overlay, HandwritingLayout.layout_mark(t, size), t.size_pt, dpi, Color(InkRasterizer.GRAPHITE, 1.0))
	if overlay.get_size() != img.get_size():
		overlay.resize(img.get_width(), img.get_height())
	img.blend_rect(overlay, Rect2i(Vector2i.ZERO, overlay.get_size()), Vector2i.ZERO)
	return img


func _thumb(i: int) -> Image:
	return _composite(i, THUMB_DPI)


func _show_page(i: int) -> void:
	_page = i
	_view.texture = ImageTexture.create_from_image(page_image(i))
	_page_label.text = "Page %d of %d" % [i + 1, attempt.pages.size()]
	_apply_zoom()


func _apply_zoom() -> void:
	if _view == null or _view.texture == null:
		return
	var tex_size := _view.texture.get_size()
	var w := _scroll.size.x - 12.0
	match _zoom:
		1: w = tex_size.x * 72.0 / VIEW_DPI * 1.33
		2: w = tex_size.x * 72.0 / VIEW_DPI * 2.66
	_view.custom_minimum_size = Vector2(w, w * tex_size.y / tex_size.x)


func _default_name() -> String:
	var date := Time.get_date_string_from_unix_time(attempt.created_unix)
	var safe := attempt.test_title.validate_filename().strip_edges()
	return "%s-attempt-%s.pdf" % [safe if safe != "" else "test", date]


func _on_save() -> void:
	_save_dialog.current_dir = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	_save_dialog.current_file = _default_name()
	_save_dialog.popup_centered_ratio(0.6)


func save_to(path: String) -> void:
	var r := PdfExporter.export(doc, attempt, path)
	if r.ok:
		_status.text = "Saved to %s" % path.get_file() + ("\nExported as images" if r.mode == "images" else "")
	elif r.error == "same_as_source":
		_status.text = "Choose a different file name; that's the original test."
	else:
		_status.text = "Couldn't save the PDF (%s). Try another folder." % r.error


func _on_copy() -> void:
	DisplayServer.clipboard_set(MarkingPrompt.build(attempt.test_title, attempt.pages.size()))
	_copy_btn.text = "Copied"
	get_tree().create_timer(2.0).timeout.connect(func() -> void:
		if is_instance_valid(_copy_btn):
			_copy_btn.text = "Copy marking prompt")


func _on_retake() -> void:
	Session.machine.abort()
	Session.machine.transition_to(SessionMachine.State.PRETEST)
	Session.begin(doc, attempt.options)
	get_tree().change_scene_to_file(TEST_SCENE)


func dev_action(name: String) -> void:
	match name:
		"page2": _show_page(1)
		"copy": _on_copy()
		"save": save_to(ProjectSettings.globalize_path("user://review_save.pdf"))
