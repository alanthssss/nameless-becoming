extends Control
## Each section shows the controls used in one part of the game.
const WaxKeycaps := preload("res://region_game/wax_keycaps.gd")
const SHORTCUTS := {
	"菜单": [
		["选择选项", "方向键 / Tab / Shift+Tab", "十字键"],
		["确认", "Enter / 小键盘回车 / 空格 / 鼠标左键", "A（下）"],
		["返回", "Esc", "B（右）"],
	],
	"成长树": [
		["选择技能", "方向键 / Tab / Shift+Tab / 鼠标左键", "左摇杆 / 十字键"],
		["查看 / 购买", "Enter / 小键盘回车", "A（下）"],
		["展开 / 收起技能签", "I", "视图键（Back）"],
		["查看前置", "F / Shift+F", "按下左摇杆"],
		["切换档次", "[ / ] / PageUp / PageDown", "X（左）"],
		["试用花湾", "P", "Y（上）"],
		["平移地图", "鼠标左键拖动 / 双指滑动", "右摇杆"],
		["缩放", "滚轮 / + / = / − / 捏合", "LT / RT / LB / RB"],
		["查看全图", "Home / 0", "按下右摇杆"],
		["返回", "Esc", "B（右）"],
	],
	"花湾": [
		["选择花朵", "1–8 / ← / →", "十字键← / 十字键→"],
		["采蜜", "E / 空格", "A（下）", "按住", "按住"],
		["指向花朵采蜜", "鼠标左键", "", "按住"],
		["切换阶段", "鼠标左键", "RB", "点阶段选单"],
		["返回", "Esc", "B（右）"],
	],
}
const REBIND_HINT := "选择要修改的按键"

var ui
var bindings
var device := "kbm"
var rows := {}
var tabs := {}
var headings := {}
var section := "飞行"
var sections := {}
var flight: VBoxContainer
var reference: VBoxContainer
var status: Label
var reset_button: Button
var scroll: ScrollContainer
var pending_action := ""
var pending_slot := ""
var captured: InputEvent

func setup(interface: Control) -> void:
	ui = interface
	bindings = ui.driver.bindings
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.shade(self, Color("173d35cf"))
	var page: PanelContainer = ui.material_panel(self,"settings",Vector4(166,72,176,126))
	ui.anchored(page, Rect2(.5,.5,0,0), Rect2(-455,-366,910,732))
	var content: VBoxContainer = ui.column(page, 4)
	ui.text_line(content, "键位设置", 28, ui.TOOL_INK).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var tab_bar: HBoxContainer = ui.row(content, 12)
	var device_group := ButtonGroup.new()
	for id in ["kbm","pad"]:
		var title := "键盘和鼠标" if id == "kbm" else "游戏手柄"
		tabs[id] = _tab(tab_bar, title, device_group, _select_device.bind(id))
	var section_bar: HBoxContainer = ui.row(content, 6)
	var section_group := ButtonGroup.new()
	for title in ["飞行", "菜单", "成长树", "花湾"]:
		sections[title] = _tab(section_bar, title, section_group, _select_section.bind(title))
	scroll = ScrollContainer.new()
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(scroll)
	flight = ui.column(scroll, 1)
	flight.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reference = ui.column(scroll, 1)
	reference.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var header: HBoxContainer = ui.row(flight, 8)
	_row_label(header, "动作")
	for slot in ["key","mouse","pad"]:
		var title: Label = ui.text_line(header, {"key":"键盘","mouse":"鼠标","pad":"手柄按钮"}[slot], 17, ui.TOOL_INK)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		headings[slot] = title
	for id in bindings.ACTIONS:
		var line: HBoxContainer = ui.row(flight, 8)
		_row_label(line, bindings.TITLES[id])
		rows[id] = {}
		for slot in ["key","mouse","pad"]:
			var cell := PanelContainer.new()
			cell.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
			cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			line.add_child(cell)
			var button: Button = ui.action(cell, "", _listen.bind(id, slot))
			ui.tool_button(button)
			button.custom_minimum_size.y = WaxKeycaps.HEIGHT
			button.focus_entered.connect(_show_hint.bind(id, slot))
			button.add_theme_font_size_override("font_size",18)
			rows[id][slot] = button
			var strip := WaxKeycaps.new()
			strip.name = "Keycaps"
			strip.alignment = FlowContainer.ALIGNMENT_CENTER
			cell.add_child(strip)
			button.button_down.connect(strip.depress.bind(true))
			button.button_up.connect(strip.depress.bind(false))
	status = ui.text_line(content, "", 18, ui.TOOL_SECONDARY, true)
	var footer: HBoxContainer = ui.row(content, 16)
	reset_button = ui.action(footer,"恢复默认按键",_reset)
	ui.tool_button(reset_button)
	ui.tool_button(ui.action(footer, "返回设置", ui.close_controls))
	hide()

func _tab(bar: HBoxContainer, title: String, group: ButtonGroup, select: Callable) -> Button:
	var button: Button = ui.action(bar, title, select)
	button.toggle_mode = true
	button.button_group = group
	ui.tool_button(button)
	button.custom_minimum_size.y = 34
	button.add_theme_font_size_override("font_size",18)
	if button.get_index() > 0:
		var previous := bar.get_child(button.get_index() - 1) as Button
		previous.focus_neighbor_right = previous.get_path_to(button)
		button.focus_neighbor_left = button.get_path_to(previous)
	return button

func _row_label(line: Control, words: String) -> void:
	var label: Label = ui.text_line(line, words, 18, ui.TOOL_INK)
	label.custom_minimum_size.x = 180
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

func open(preferred: String) -> void:
	_finish_capture()
	section = "飞行"
	_select_device(preferred)
	tabs[device].grab_focus()

func _select_device(id: String) -> void:
	device = id
	for tab_id in tabs: tabs[tab_id].set_pressed_no_signal(tab_id == id)
	refresh_table()
	_select_section(section)

func _select_section(title: String) -> void:
	section = title
	for name_text in sections: sections[name_text].set_pressed_no_signal(name_text == section)
	for tab: Button in tabs.values():
		tab.focus_neighbor_bottom = tab.get_path_to(sections[section])
	flight.visible = section == "飞行"
	reference.visible = not flight.visible
	reset_button.visible = flight.visible
	status.visible = flight.visible
	status.text = REBIND_HINT
	scroll.scroll_vertical = 0
	for child in reference.get_children():
		reference.remove_child(child)
		child.queue_free()
	if reference.visible:
		var header: HBoxContainer = ui.row(reference, 8)
		_row_label(header, "动作")
		ui.text_line(header, "固定按键", 17, ui.TOOL_SECONDARY)
		for shortcut in SHORTCUTS[section]:
			var binding: String = shortcut[2] if device == "pad" else shortcut[1]
			if binding.is_empty(): continue
			var line: HBoxContainer = ui.row(reference, 8)
			_row_label(line, shortcut[0])
			var strip := WaxKeycaps.new()
			line.add_child(strip)
			var note_index := 4 if device == "pad" else 3
			strip.display(binding.split(" / "), shortcut[note_index] if shortcut.size() > note_index else "")

func refresh_table() -> void:
	for slot in headings:
		headings[slot].visible = (slot == "pad") == (device == "pad")
		for id in rows:
			var button: Button = rows[id][slot]
			button.get_parent().visible = headings[slot].visible
			var names: PackedStringArray = bindings.labels(id, slot)
			var strip := _keycaps(button)
			strip.display(names)
			strip.visible = not names.is_empty()
			button.text = "未绑定" if names.is_empty() else ""
			var current := button.text if names.is_empty() else " / ".join(names)
			button.accessibility_name = "%s · %s · %s" % [bindings.TITLES[id], headings[slot].text, current]
			button.tooltip_text = _binding_hint(id, slot)

func _keycaps(button: Button) -> WaxKeycaps:
	return button.get_parent().get_node("Keycaps")

func _binding_hint(id: String, slot: String) -> String:
	match id:
		"interact": return "点按互动，按住采蜜"
		"pulse": return "朝指针振翅，按住连发" if slot == "mouse" else "朝蜂头振翅，按住连发"
		"dash": return "按住蓄力，松开冲刺。蜂舞中点按跳过"
	if slot == "pad" and id in bindings.STICK_HINTS: return "%s 也可飞行（固定）" % bindings.STICK_HINTS[id]
	if id == "pause": return "%s 始终可暂停" % ("Start" if slot == "pad" else "Esc")
	return REBIND_HINT

func _show_hint(id: String, slot: String) -> void:
	if pending_action.is_empty(): status.text = _binding_hint(id, slot)

func _listen(id: String, slot: String) -> void:
	pending_action = id
	pending_slot = slot
	var kind: String = {"key":"键盘键", "mouse":"鼠标按钮", "pad":"手柄按钮"}[slot]
	_keycaps(rows[id][slot]).hide()
	_capture_message("等待输入…", false)
	status.text = "为「%s」按下新的%s。Esc 或手柄 B 取消。" % [bindings.TITLES[id], kind]

func _capture_message(words: String, rejected: bool) -> void:
	var button: Button = rows[pending_action][pending_slot]
	button.text = words
	button.accessibility_name = "%s · %s" % [bindings.TITLES[pending_action], words]
	var box: StyleBoxFlat = button.get_theme_stylebox("normal").duplicate()
	box.bg_color = Color("78442c") if rejected else Color("5f5d35")
	box.border_color = Color("ffc594") if rejected else Color("ffe2a0")
	box.set_border_width_all(2)
	for state in ["normal", "hover", "pressed"]:
		button.add_theme_stylebox_override(state, box)

func _finish_capture() -> void:
	if not pending_action.is_empty():
		var button: Button = rows[pending_action][pending_slot]
		ui.tool_button(button)
		button.custom_minimum_size.y = WaxKeycaps.HEIGHT
	pending_action = ""
	pending_slot = ""
	captured = null

func _reset() -> void:
	var error: String = bindings.reset_defaults()
	refresh_table()
	status.text = "已恢复键鼠和手柄的默认按键。" if error.is_empty() else error

func handle_input(event: InputEvent) -> bool:
	if not visible or not is_inside_tree(): return false
	if captured != null and captured.is_match(event):
		if not event.is_pressed(): captured = null
		return true
	var back: bool = event.is_action("ui_cancel") or (event is InputEventJoypadButton and event.button_index == JOY_BUTTON_B)
	if pending_action.is_empty():
		if back and event.is_pressed() and not event.is_echo():
			ui.close_controls()
			return true
		return false
	if not (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton): return true
	if not event.is_pressed() or event.is_echo(): return true
	if back:
		_finish_capture()
		captured = event
		refresh_table()
		status.text = "已取消，原按键保留。"
		return true
	var error: String = bindings.rebind(pending_action, pending_slot, event)
	if not error.is_empty():
		_capture_message("请换一个键", true)
		status.text = error + "　Esc / B 取消。"
		return true
	var label: String = bindings.label(pending_action, pending_slot)
	var name_text: String = bindings.TITLES[pending_action]
	_finish_capture()
	captured = event
	refresh_table()
	status.text = "已保存 · %s　%s" % [name_text, label]
	return true
