class_name JourneySolarTermBoard
extends Control

## A compact in-hive reader. It presents one earned record at a time so the
## solar terms stay attached to lived work instead of becoming an encyclopedia.

signal open_changed(open: bool)

var chronicle: JourneySolarTermChronicle
var hive_available := false
var current_index := 0
var top_button: Button
var panel: ColorRect
var count_label: Label
var term_label: Label
var title_label: Label
var record_label: Label
var work_label: Label
var page_label: Label
var previous_button: Button
var next_button: Button


func _ready() -> void:
	position = Vector2.ZERO
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_interface()
	refresh()


func configure(source: JourneySolarTermChronicle) -> void:
	chronicle = source
	refresh()


func _build_interface() -> void:
	top_button = Button.new()
	top_button.name = "SolarTermChronicleButton"
	# The commercial pause/save controls own the top-right bar. The journal sits
	# beside the departure button and only exists while the player is in the hive.
	top_button.position = Vector2(740, 596)
	top_button.size = Vector2(220, 56)
	top_button.focus_mode = Control.FOCUS_ALL
	top_button.pressed.connect(open_latest)
	add_child(top_button)

	panel = ColorRect.new()
	panel.name = "SolarTermChroniclePanel"
	panel.position = Vector2(250, 106)
	panel.size = Vector2(760, 508)
	panel.color = Color("f4edda", 0.985)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.visible = false
	add_child(panel)

	count_label = _label(panel, "巢内纪事", Vector2(38, 26), Vector2(500, 34), 16, Color("68705f"))
	var close_button := Button.new()
	close_button.name = "CloseButton"
	close_button.text = "收好"
	close_button.position = Vector2(640, 22)
	close_button.size = Vector2(82, 42)
	close_button.pressed.connect(close)
	panel.add_child(close_button)

	term_label = _label(panel, "", Vector2(38, 82), Vector2(684, 34), 20, Color("4f6a50"))
	title_label = _label(panel, "", Vector2(38, 126), Vector2(684, 54), 29, Color("27382e"))
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	record_label = _label(panel, "", Vector2(38, 202), Vector2(684, 154), 20, Color("3f4a41"))
	record_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	record_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	work_label = _label(panel, "", Vector2(38, 372), Vector2(684, 34), 15, Color("6f6248"))
	work_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	previous_button = Button.new()
	previous_button.name = "PreviousButton"
	previous_button.text = "上一张"
	previous_button.position = Vector2(38, 438)
	previous_button.size = Vector2(118, 46)
	previous_button.pressed.connect(show_previous)
	panel.add_child(previous_button)
	page_label = _label(panel, "", Vector2(255, 446), Vector2(250, 30), 15, Color("68705f"))
	page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	next_button = Button.new()
	next_button.name = "NextButton"
	next_button.text = "下一张"
	next_button.position = Vector2(604, 438)
	next_button.size = Vector2(118, 46)
	next_button.pressed.connect(show_next)
	panel.add_child(next_button)


func _label(parent: Node, text: String, label_position: Vector2, label_size: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.position = label_position
	label.size = label_size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func set_hive_available(available: bool) -> void:
	hive_available = available
	if top_button != null:
		top_button.visible = available
	if not available and is_open():
		close()


func refresh() -> void:
	if top_button == null:
		return
	var unlocked := chronicle.unlocked_count() if chronicle != null else 0
	var total := chronicle.total_count() if chronicle != null else 24
	top_button.text = "巢内纪事  %d / %d" % [unlocked, total]
	top_button.visible = hive_available
	if panel.visible:
		_refresh_page()


func open_latest() -> void:
	if not hive_available or panel == null:
		return
	var count := chronicle.unlocked_count() if chronicle != null else 0
	current_index = maxi(0, count - 1)
	panel.visible = true
	_refresh_page()
	open_changed.emit(true)


func close() -> void:
	if panel == null or not panel.visible:
		return
	panel.visible = false
	open_changed.emit(false)
	if top_button != null and top_button.visible:
		top_button.grab_focus()


func is_open() -> bool:
	return panel != null and panel.visible


func show_previous() -> void:
	if chronicle == null:
		return
	current_index = maxi(0, current_index - 1)
	_refresh_page()


func show_next() -> void:
	if chronicle == null:
		return
	current_index = mini(maxi(0, chronicle.unlocked_count() - 1), current_index + 1)
	_refresh_page()


func current_entry() -> Dictionary:
	if chronicle == null:
		return {}
	var entries: Array[Dictionary] = chronicle.unlocked_entries()
	if entries.is_empty():
		return {}
	return entries[clampi(current_index, 0, entries.size() - 1)].duplicate(true)


func _refresh_page() -> void:
	var entries: Array[Dictionary] = chronicle.unlocked_entries() if chronicle != null else []
	var total := chronicle.total_count() if chronicle != null else 24
	count_label.text = "巢内纪事 · 已贴 %d / %d" % [entries.size(), total]
	if entries.is_empty():
		term_label.text = "接货板还空着"
		title_label.text = "第一次返巢后，从这里开始贴"
		record_label.text = "飞出去、做完手头的活，再真正回到主蜂巢。接货蜂会把这些小事一张张贴在这里。"
		work_label.text = "纪事只记录已经做过的事。"
		page_label.text = "0 / %d" % total
		previous_button.disabled = true
		next_button.disabled = true
		return
	current_index = clampi(current_index, 0, entries.size() - 1)
	var entry: Dictionary = entries[current_index]
	term_label.text = "%s · %s" % [String(entry.season), String(entry.name)]
	title_label.text = String(entry.title)
	record_label.text = String(entry.resolved_record)
	var work_parts := PackedStringArray()
	for action in entry.work:
		work_parts.append(String(action))
	work_label.text = "这阵做过的活：%s" % " · ".join(work_parts)
	page_label.text = "%d / %d　（总进度 %d / %d）" % [current_index + 1, entries.size(), entries.size(), total]
	previous_button.disabled = current_index <= 0
	next_button.disabled = current_index >= entries.size() - 1


func _unhandled_input(event: InputEvent) -> void:
	if is_open() and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
