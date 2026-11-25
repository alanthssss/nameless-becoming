extends Control
## The flight bindings and fixed menu shortcuts are presented in the same place.
var ui
var bindings
var device := "kbm"
var rows := {}
var tabs := {}
var headings := {}
var flight_note: Label
var notes: Label
var status: Label
var scroll: ScrollContainer
var pending_action := ""
var pending_slot := ""
var captured: InputEvent

func setup(interface: Control) -> void:
	ui = interface
	bindings = ui.driver.bindings
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.shade(self, Color("173d35cf"))
	var page: PanelContainer = ui.card(self)
	ui.anchored(page, Rect2(.5,.5,0,0), Rect2(-455,-366,910,732))
	var paper := page.get_theme_stylebox("panel").duplicate() as StyleBox
	paper.content_margin_left = maxf(paper.content_margin_left, 75)
	paper.content_margin_right = maxf(paper.content_margin_right, 48)
	paper.content_margin_top = maxf(paper.content_margin_top, 36)
	paper.content_margin_bottom = maxf(paper.content_margin_bottom, 40)
	page.add_theme_stylebox_override("panel", paper)
	var content: VBoxContainer = ui.column(page, 8)
	ui.text_line(content, "操作说明与改键", 30).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var tab_bar: HBoxContainer = ui.row(content, 14)
	var group := ButtonGroup.new()
	for id in ["kbm","pad"]:
		var tab: Button = ui.action(tab_bar, "键盘和鼠标" if id == "kbm" else "游戏手柄", _select_device.bind(id))
		tab.toggle_mode = true
		tab.button_group = group
		tab.add_theme_stylebox_override("pressed", ui.style(Color("466548"), Color("435e40"), 1, 8))
		tab.add_theme_color_override("font_pressed_color", Color("fff4ce"))
		tab.add_theme_color_override("font_hover_pressed_color", Color("fff4ce"))
		tabs[id] = tab
	flight_note = ui.text_line(content, "", 18, ui.INK, true)
	scroll = ScrollContainer.new()
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(scroll)
	var list: VBoxContainer = ui.column(scroll, 4)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var header: HBoxContainer = ui.row(list, 8)
	_row_label(header, "飞行与采集")
	for slot in ["key","mouse","pad"]:
		var title: Label = ui.text_line(header, {"key":"键盘","mouse":"鼠标","pad":"手柄按钮"}[slot], 17)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		headings[slot] = title
	for id in bindings.ACTIONS:
		var line: HBoxContainer = ui.row(list, 8)
		_row_label(line, bindings.TITLES[id])
		rows[id] = {}
		for slot in ["key","mouse","pad"]:
			var button: Button = ui.action(line, "", _listen.bind(id, slot))
			button.custom_minimum_size.y = 39
			button.add_theme_font_size_override("font_size", 18)
			button.add_theme_stylebox_override("normal", ui.style(Color("f4e7c0a0"), Color("bda97b"), 1, 7))
			for state in ["normal", "hover", "pressed", "focus"]:
				var box := button.get_theme_stylebox(state).duplicate() as StyleBox
				box.content_margin_top = 3
				box.content_margin_bottom = 3
				button.add_theme_stylebox_override(state,box)
			rows[id][slot] = button
	notes = ui.text_line(list, "", 18, ui.INK, true)
	notes.focus_mode = Control.FOCUS_ALL
	status = ui.text_line(content, "", 18, ui.INK, true)
	var footer: HBoxContainer = ui.row(content, 16)
	ui.action(footer, "恢复全部默认按键", _reset)
	ui.action(footer, "返回设置", ui.close_controls)
	hide()

func _row_label(line: Control, words: String) -> void:
	var label: Label = ui.text_line(line, words, 18)
	label.custom_minimum_size.x = 180
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

func open(preferred: String) -> void:
	_finish_capture()
	_select_device(preferred)
	tabs[device].grab_focus()

func _select_device(id: String) -> void:
	device = id
	for tab_id in tabs: tabs[tab_id].set_pressed_no_signal(tab_id == id)
	status.text = "点选按键即可修改飞行操作。菜单与成长树的固定操作见下方。"
	scroll.scroll_vertical = 0
	refresh_table()

func refresh_table() -> void:
	for slot in headings:
		headings[slot].visible = (slot == "pad") == (device == "pad")
		for id in rows:
			var button: Button = rows[id][slot]
			button.visible = headings[slot].visible
			button.text = bindings.label(id, slot)
			button.tooltip_text = "%s · %s" % [bindings.TITLES[id], button.text]
	var direction := "左摇杆飞行，振翅朝蜂头。" if device == "pad" else "键盘振翅朝蜂头，鼠标振翅朝指针。"
	flight_note.text = direction + "点按与设施交互，按住采蜜。振翅可连发，冲刺按住蓄力、松开发动。"
	if device == "pad":
		notes.text = "左摇杆飞行，振翅朝蜜蜂面向。蜂舞中按冲刺键跳过。\n菜单用十字键选项、A（下）确认、B（右）返回。\n成长树用左摇杆或十字键选格，A 查看或购买，视图键收签，L3 查看前置，X 换档，Y 试用花湾。右摇杆移图，LT / RT 缩放，按下右摇杆看全图。\n花湾演示用十字键左右选花，按住 A 采蜜，RB 换阶段，B 返回。"
	else:
		notes.text = "鼠标振翅朝指针，键盘振翅朝蜜蜂面向。蜂舞中按冲刺键跳过。\n菜单可点击，也可用方向键或 Tab 选项、Enter 确认、Esc 返回。\n成长树用方向键选格，Enter 查看或购买，I 收签，F 查看前置，[ / ] 换档，P 试用花湾。滚轮缩放、拖空白移图，Home 看全图。\n花湾演示用 1–8 或左右方向键选花，按住 E 或空格采蜜，也可按住鼠标左键指向花朵。"

func _listen(id: String, slot: String) -> void:
	pending_action = id
	pending_slot = slot
	var kind: String = {"key":"键盘键", "mouse":"鼠标按钮", "pad":"手柄按钮"}[slot]
	rows[id][slot].text = "等待输入…"
	status.text = "为「%s」按下新的%s。Esc 或手柄 B 取消。" % [bindings.TITLES[id], kind]

func _finish_capture() -> void:
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
		status.text = error + "　Esc / B 取消。"
		return true
	var label: String = bindings.label(pending_action, pending_slot)
	var name_text: String = bindings.TITLES[pending_action]
	_finish_capture()
	captured = event
	refresh_table()
	status.text = "已保存 · %s　%s" % [name_text, label]
	return true
