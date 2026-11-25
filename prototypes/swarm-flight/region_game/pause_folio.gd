extends Control
## One leaf of the garden journal, registered to the game's 1280×800 canvas.
const PAGE := preload("res://art/honey-pause-folio.webp")
const MARKS := preload("res://art/honey-pause-marks.webp")
const INK := Color("#513419")
const GOLD := Color("#ffdf95")

var buttons: Array[Button] = []
var slot: Label
var status: Label
var version: Label
var back_key: Label

func _mark(rect: Rect2) -> AtlasTexture:
	var part := AtlasTexture.new()
	part.atlas = MARKS
	part.region = rect
	part.filter_clip = true
	return part

func _label(parent: Control, words: String, pixels: int, box: Rect2) -> Label:
	var label := Label.new()
	label.text = words
	label.add_theme_font_size_override("font_size", pixels)
	label.add_theme_color_override("font_color", INK)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	label.position = box.position
	label.size = box.size
	return label

func _rule(parent: Control, box: Rect2) -> void:
	var line := ColorRect.new()
	line.color = Color("#a384518c")
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(line)
	line.position = box.position
	line.size = box.size

func _wash(fill: Color, edge: Color, thickness: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(thickness)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(0)
	return style

func _action(parent: Control, words: String, callback: Callable, box: Rect2, primary := false) -> Button:
	var button := Button.new()
	button.text = words
	button.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 29 if primary else 24)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, GOLD if primary else INK)
	button.add_theme_color_override("font_disabled_color", Color("#857357"))
	if primary:
		for state in ["normal", "hover", "pressed"]:
			var brass := StyleBoxTexture.new()
			brass.texture = _mark(Rect2(0, 0, 448, 95))
			brass.modulate_color = {"normal": Color.WHITE, "hover": Color(1.08, 1.08, 1.02),
					"pressed": Color("#d2be91")}[state]
			brass.set_content_margin_all(0)
			brass.set_content_margin(SIDE_LEFT, 69)
			button.add_theme_stylebox_override(state, brass)
		button.icon = _mark(Rect2(250, 100, 44, 49))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_constant_override("icon_max_width", 30)
		button.add_theme_constant_override("h_separation", 13)
		button.add_theme_stylebox_override("focus", _wash(Color.TRANSPARENT, Color("#a98443"), 2, 17))
	else:
		button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		button.add_theme_stylebox_override("disabled", StyleBoxEmpty.new())
		button.add_theme_stylebox_override("hover", _wash(Color("#bb9d5330"), Color.TRANSPARENT, 0, 6))
		button.add_theme_stylebox_override("pressed", _wash(Color("#a4854945"), Color.TRANSPARENT, 0, 6))
		button.add_theme_stylebox_override("focus", _wash(Color("#e3c27328"), Color("#8a682e"), 2, 6))
	parent.add_child(button)
	button.position = box.position
	button.size = box.size
	button.pressed.connect(callback)
	buttons.append(button)
	return button

func setup(ui: Control) -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	var face := SystemFont.new()
	face.font_names = PackedStringArray(["Songti SC", "Noto Serif CJK SC", "SimSun", "serif"])
	face.font_weight = 600
	var journal_theme := Theme.new()
	journal_theme.default_font = face
	theme = journal_theme
	var page := TextureRect.new()
	page.texture = PAGE
	page.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	page.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(page)
	ui.anchored(page, Rect2(0, .5, 0, 0), Rect2(66, -323, 462, 661))
	slot = _label(page, "", 23, Rect2(81, 46, 100, 36))
	_rule(page, Rect2(183, 69, 101, 1))
	_label(page, "歇一会儿", 53, Rect2(77, 82, 235, 75))
	_rule(page, Rect2(74, 164, 346, 1))
	status = _label(page, "", 21, Rect2(78, 169, 340, 52))
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_constant_override("line_spacing", -4)

	var resume := _action(page, "继续这趟出行", ui.driver.start_game, Rect2(68, 226, 360, 76), true)
	var captions := ["花路手册", "选择存档", "设置"]
	var actions := [ui.driver.open_journal, ui.driver.open_slots, ui.driver.open_settings]
	for i in captions.size():
		var y := 314 + i * 59
		var entry := _action(page, captions[i], actions[i], Rect2(76, y, 343, 58))
		entry.icon = _mark(Rect2(i * 72, 100, 70, 50))
		entry.add_theme_constant_override("icon_max_width", 50)
		entry.add_theme_constant_override("h_separation", 24)
		entry.alignment = HORIZONTAL_ALIGNMENT_LEFT
		for state in ["normal", "hover", "pressed", "disabled"]:
			var inset := entry.get_theme_stylebox(state)
			inset.set_content_margin(SIDE_LEFT, 6)
		var arrow := TextureRect.new()
		arrow.texture = _mark(Rect2(216, 100, 26, 34))
		arrow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		arrow.mouse_filter = MOUSE_FILTER_IGNORE
		entry.add_child(arrow)
		ui.anchored(arrow, Rect2(1, .5, 0, 0), Rect2(-23, -12, 18, 24))
		_rule(page, Rect2(75, y + 59, 344, 1))
	_action(page, "新的一轮", ui.ask_restart, Rect2(77, 512, 155, 60))
	_rule(page, Rect2(243, 534, 1, 24))
	_action(page, "保存并退出", ui.driver.quit_game, Rect2(253, 512, 166, 60))
	version = _label(page, "", 18, Rect2(76, 582, 180, 45))
	back_key = _label(page, "", 18, Rect2(324, 594, 43, 25))
	back_key.add_theme_stylebox_override("normal", _wash(Color.TRANSPARENT, INK, 1, 5))
	back_key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label(page, "返回", 20, Rect2(376, 582, 48, 45))
	buttons[2].disabled = not ui.driver.slots_enabled
	if buttons[2].disabled:
		buttons[2].focus_mode = FOCUS_NONE
		buttons[2].tooltip_text = "本次运行使用指定的独立存档"
	# Down reads the leaf in order. Both bottom actions return Up to Settings.
	var order: Array[Button] = [resume, buttons[1]]
	if ui.driver.slots_enabled: order.append(buttons[2])
	order.append_array([buttons[3], buttons[4], buttons[5]])
	for i in order.size():
		var button := order[i]
		button.focus_previous = button.get_path_to(order[(i - 1 + order.size()) % order.size()])
		button.focus_next = button.get_path_to(order[(i + 1) % order.size()])
		button.focus_neighbor_top = button.focus_previous
		button.focus_neighbor_bottom = button.focus_next
	buttons[4].focus_neighbor_right = buttons[4].get_path_to(buttons[5])
	buttons[5].focus_neighbor_left = buttons[5].get_path_to(buttons[4])
	buttons[5].focus_neighbor_top = buttons[5].get_path_to(buttons[3])
	hide()

func update_state(driver, build: String) -> void:
	slot.text = "存档 %d" % driver.active_slot if driver.slots_enabled else "独立存档"
	status.text = driver.model.goal_text()
	if driver.save_blocked:
		status.text = "存档无法读取，可备份后重新开始。"
	elif driver.save_warning:
		status.text = "保存失败，进度仍在。请检查保存位置后重试。"
	buttons[0].text = "备份并重新开始" if driver.save_blocked else "继续这趟出行"
	version.text = build
	back_key.text = "B" if driver.input_device == "pad" else "Esc"
