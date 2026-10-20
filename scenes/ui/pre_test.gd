class_name PreTestCard
extends PanelContainer
## One card: the PDF, a line saying how the test will run (length and start time, changeable),
## and "Take your seat" (spec §4.1).

signal take_seat(doc: PdfDoc, options: Dictionary)
signal back()

const ERR_ENCRYPTED := "This PDF is password-protected; remove the password and try again."
const ERR_OPEN := "Couldn't open this PDF."

var doc: PdfDoc
var _box: VBoxContainer
var _drop: PanelContainer
var _drop_label: Label
var _thumbs: HBoxContainer
var _recent_box: VBoxContainer
var _error: Label
var _error_detail: Label
var _start_btn: Button
var _summary: Label
var _form: TestSetupForm
var _pages_note: Label
var _dialog: FileDialog


func _ready() -> void:
	theme_type_variation = "Card"
	custom_minimum_size = Vector2(560, 0)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 10)
	add_child(_box)

	var head := HBoxContainer.new()
	_box.add_child(head)
	var h := Label.new()
	h.text = "New test"
	h.theme_type_variation = "Heading"
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(h)
	var back_btn := Button.new()
	back_btn.text = "Back"
	back_btn.theme_type_variation = "Link"
	back_btn.pressed.connect(back.emit)
	head.add_child(back_btn)

	_box.add_child(_mini("Test PDF"))
	_drop = PanelContainer.new()
	_drop.theme_type_variation = "Inset"
	_drop.mouse_filter = Control.MOUSE_FILTER_STOP
	_drop.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_drop.gui_input.connect(_on_drop_input)
	_box.add_child(_drop)
	var drop_row := HBoxContainer.new()
	drop_row.add_theme_constant_override("separation", 12)
	_drop.add_child(drop_row)
	_thumbs = HBoxContainer.new()
	_thumbs.add_theme_constant_override("separation", 4)
	drop_row.add_child(_thumbs)
	_drop_label = Label.new()
	_drop_label.text = "Drop a PDF here or click to choose"
	_drop_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_drop_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	drop_row.add_child(_drop_label)

	_error = Label.new()
	_error.theme_type_variation = "Error"
	_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_error.visible = false
	_box.add_child(_error)
	_error_detail = Label.new()
	_error_detail.theme_type_variation = "Muted"
	_error_detail.visible = false
	_box.add_child(_error_detail)

	_recent_box = VBoxContainer.new()
	_box.add_child(_recent_box)
	_fill_recent()

	_pages_note = Label.new()
	_pages_note.theme_type_variation = "Muted"
	_pages_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_pages_note.visible = false
	_box.add_child(_pages_note)

	# What will happen, in one line; "Change" opens the full form (saved as defaults).
	var sum_row := HBoxContainer.new()
	sum_row.add_theme_constant_override("separation", 12)
	_box.add_child(sum_row)
	_summary = Label.new()
	_summary.add_theme_font_override("font", CozyTheme.bold_font())
	_summary.add_theme_font_size_override("font_size", 19)
	_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sum_row.add_child(_summary)
	var change := Button.new()
	change.text = "Change"
	change.theme_type_variation = "Link"
	sum_row.add_child(change)
	_form = TestSetupForm.new()
	_form.visible = false
	_form.changed.connect(_validate)
	_box.add_child(_form)
	change.pressed.connect(func() -> void:
		_form.visible = not _form.visible
		change.text = "Done" if _form.visible else "Change")

	_box.add_child(MainMenuCard._gap(6))
	_start_btn = Button.new()
	_start_btn.text = "Take your seat"
	_start_btn.theme_type_variation = "Primary"
	_start_btn.disabled = true
	_start_btn.pressed.connect(_on_start)
	_box.add_child(_start_btn)
	_validate()

	get_window().files_dropped.connect(_on_files_dropped)
	_dialog = FileDialog.new()
	_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_dialog.use_native_dialog = true
	_dialog.filters = PackedStringArray(["*.pdf ; PDF documents"])
	_dialog.title = "Choose a test PDF"
	_dialog.file_selected.connect(load_pdf)
	add_child(_dialog)


func _exit_tree() -> void:
	if get_window().files_dropped.is_connected(_on_files_dropped):
		get_window().files_dropped.disconnect(_on_files_dropped)


func _fill_recent() -> void:
	for c in _recent_box.get_children():
		c.queue_free()
	var recent: Array = Settings.get_value("recent/pdfs")
	if recent.is_empty() or doc != null:
		return
	_recent_box.add_child(_mini("Recent"))
	for p in recent:
		var b := Button.new()
		b.text = String(p).get_file()
		b.tooltip_text = p
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(load_pdf.bind(p))
		_recent_box.add_child(b)


func _mini(text: String) -> Label:
	var l := Label.new()
	l.text = text.to_upper()
	l.theme_type_variation = "MiniLabel"
	return l


func _on_drop_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		_dialog.popup_centered_ratio(0.6)


func _on_files_dropped(files: PackedStringArray) -> void:
	for f in files:
		if f.get_extension().to_lower() == "pdf":
			load_pdf(f)
			return
	_show_error(ERR_OPEN, "That file isn't a PDF.")


func load_pdf(path: String) -> void:
	var d := PdfService.open(path)
	if d == null:
		doc = null
		_start_btn.disabled = true
		match PdfService.last_error:
			"encrypted": _show_error(ERR_ENCRYPTED, "")
			"not_found": _show_error(ERR_OPEN, "The file wasn't found: %s" % path)
			_: _show_error(ERR_OPEN, "It may be damaged or not a real PDF: %s" % path.get_file())
		return
	doc = d
	_error.visible = false
	_error_detail.visible = false
	Settings.push_recent(path)
	_fill_recent()
	_drop_label.text = "%s\n%d pages" % [path.get_file(), d.page_count()]
	for c in _thumbs.get_children():
		c.queue_free()
	for i in mini(d.page_count(), 5):
		var tr := TextureRect.new()
		tr.texture = ImageTexture.create_from_image(d.render_page(i, 10.0))
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		tr.custom_minimum_size = Vector2(26, 34)
		_thumbs.add_child(tr)
	_validate()


func _show_error(msg: String, detail: String) -> void:
	_error.text = msg
	_error.visible = true
	_error_detail.text = detail
	_error_detail.visible = detail != ""


func _validate() -> bool:
	var opts := PretestOptions.from_settings(Settings.store)
	_summary.text = PretestOptions.summary(opts, bool(Settings.get_value("test/clock_24h")))
	var ok := PretestOptions.validate(opts) == ""
	if not ok:
		_form.visible = true
	_form.is_valid()
	_start_btn.disabled = doc == null or not ok
	return ok


func _on_start() -> void:
	if doc and _validate():
		take_seat.emit(doc, PretestOptions.from_settings(Settings.store))
