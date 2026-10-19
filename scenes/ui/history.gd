class_name HistoryCard
extends PanelContainer
## Past attempts, newest first. Clicking one opens it in Review.

signal back()
signal open_attempt(path: String)


func _ready() -> void:
	theme_type_variation = "Card"
	custom_minimum_size = Vector2(560, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	var head := HBoxContainer.new()
	box.add_child(head)
	var h := Label.new()
	h.text = "History"
	h.theme_type_variation = "Heading"
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(h)
	var back_btn := Button.new()
	back_btn.text = "Back"
	back_btn.theme_type_variation = "Link"
	back_btn.pressed.connect(back.emit)
	head.add_child(back_btn)
	var items := Session.store.list_history()
	if items.is_empty():
		var l := Label.new()
		l.text = "No tests yet. Finished tests show up here."
		l.theme_type_variation = "Muted"
		box.add_child(l)
		return
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = mini(items.size(), 8) * 46
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for it in items:
		var b := Button.new()
		var date := Time.get_datetime_string_from_unix_time(int(it.created_unix), true).replace("T", " ").substr(0, 16)
		b.text = "%s    ·    %s    ·    %s used" % [it.test_title, date, MarkingPrompt.mmss(float(it.used_s))]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(open_attempt.emit.bind(it.path))
		list.add_child(b)
