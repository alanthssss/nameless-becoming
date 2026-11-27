extends "res://region_game/options_art.gd"
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

var bindings
var device := "kbm"
var rows := {}
var tabs := {}
var headings := {}
var section := "飞行"
var sections := {}
var flight: Control
var reference: Control
var status: Label
var reset_button: Button
var scroll: ScrollContainer
var pending_action := ""
var pending_slot := ""
var captured: InputEvent

const REGISTER := preload("res://art/field-notes-options/register.webp")
const ACTION_X := 12.0
const KEY_X := 182.0
const MOUSE_X := 396.0
class BindingButton extends Button:
	func _draw() -> void:
		if text == "未绑定":
			draw_dashed_line(Vector2(6,29),Vector2(60,29),Color("b9a687"),1,3)

var highlights := {}
var return_button: Button

func setup(interface: Control) -> void:
	mount(interface,REGISTER)
	bindings = ui.driver.bindings
	var device_group := ButtonGroup.new()
	for id in ["kbm","pad"]:
		var b := painted_button(sheet,Rect2(470 if id == "kbm" else 660,47,178,41),
			"键盘和鼠标" if id == "kbm" else "游戏手柄",_select_device.bind(id),NAV,true)
		b.button_group = device_group
		tabs[id] = b
	_link(tabs.kbm,tabs.pad,SIDE_RIGHT)
	var section_group := ButtonGroup.new()
	for title in ["飞行","菜单","成长树","花湾"]:
		var index := sections.size()
		var b := painted_button(sheet,Rect2(89,275+48*index,175,40),title,_select_section.bind(title),CONTEXT,true)
		b.button_group = section_group
		if index > 0: _link(sections.values()[-1],b,SIDE_BOTTOM)
		sections[title] = b
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	sheet.add_child(scroll)
	place(scroll,Rect2(318,112,561,377))
	flight = _table()
	reference = _table()
	var header := _header(flight)
	for slot in ["key","mouse","pad"]:
		var title := line(header,{"key":"键盘","mouse":"鼠标","pad":"手柄按钮"}[slot],16,MUTED)
		place(title,Rect2(MOUSE_X if slot == "mouse" else KEY_X,4,138,34))
		headings[slot] = title
	for index in bindings.ACTIONS.size():
		var id: String = bindings.ACTIONS[index]
		var row := _row(flight,41+37*index,37)
		var wash := Panel.new()
		wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wash.add_theme_stylebox_override("panel",rim(Color.TRANSPARENT,Color("e4dec2"),0))
		row.add_child(wash)
		place(wash,Rect2(0,1,557,35))
		var pointer := Polygon2D.new()
		pointer.polygon = PackedVector2Array([Vector2(0,4),Vector2(7,17),Vector2(0,30)])
		pointer.color = JADE
		wash.add_child(pointer)
		wash.hide()
		highlights[id] = wash
		var caption := line(row,bindings.TITLES[id],18)
		place(caption,Rect2(ACTION_X,0,160,36))
		rows[id] = {}
		for slot in ["key","mouse","pad"]:
			var cell := Control.new()
			row.add_child(cell)
			place(cell,Rect2((MOUSE_X if slot == "mouse" else KEY_X),2,150,33))
			var button := BindingButton.new()
			button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.pressed.connect(_listen.bind(id,slot))
			button.focus_entered.connect(_show_hint.bind(id,slot))
			button.focus_exited.connect(wash.hide)
			cell.add_child(button)
			place(button,Rect2(-6,0,155,33))
			_binding_button(button)
			rows[id][slot] = button
			var strip := WaxKeycaps.new()
			strip.name = "Keycaps"
			cell.add_child(strip)
			place(strip,Rect2(0,0,144,31))
			button.button_down.connect(strip.depress.bind(true))
			button.button_up.connect(strip.depress.bind(false))
		_rule(row,36)
	status = line(sheet,REBIND_HINT,16,MUTED)
	place(status,Rect2(326,489,559,35))
	return_button = painted_button(sheet,Rect2(78,532,138,41),"‹　返回设置",ui.close_controls)
	reset_button = painted_button(sheet,Rect2(708,532,159,41),"恢复默认按键",_reset)
	hide()

func _table() -> Control:
	var table := Control.new()
	scroll.add_child(table)
	table.custom_minimum_size = Vector2(561,377)
	return table

func _header(table: Control) -> Control:
	var header := _row(table,0,38)
	place(line(header,"动作",16,MUTED),Rect2(ACTION_X,4,148,34))
	return header

func _row(table: Control,y: float,height: float) -> Control:
	var row := Control.new()
	table.add_child(row)
	place(row,Rect2(0,y,560,height))
	return row

func _rule(row: Control,y: float) -> void:
	var rule := ColorRect.new()
	rule.color = Color("d5c098")
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(rule)
	place(rule,Rect2(7,y,548,1))

func _binding_button(button: Button) -> void:
	var clear := rim(Color.TRANSPARENT,Color.TRANSPARENT,0)
	clear.content_margin_left = 6
	for state in ["normal","pressed"]: button.add_theme_stylebox_override(state,clear)
	button.add_theme_stylebox_override("hover",rim(Color("b29b73"),Color("eadabd72"),1))
	button.add_theme_stylebox_override("focus",rim(JADE))
	for state in ["font_color","font_hover_color","font_focus_color","font_pressed_color"]:
		button.add_theme_color_override(state,MUTED)
	button.add_theme_font_size_override("font_size",15)

func _link(a: Button,b: Button,dir: Side) -> void:
	a.set_focus_neighbor(dir,a.get_path_to(b))
	var opposite := SIDE_LEFT if dir == SIDE_RIGHT else SIDE_TOP
	b.set_focus_neighbor(opposite,b.get_path_to(a))

func _layout_caps(strip: WaxKeycaps,has_note := false) -> void:
	if has_note: strip.move_child(strip.get_child(0),-1)
	for label: Label in strip.get_children():
		if label.has_theme_stylebox_override("normal"):
			label.add_theme_font_size_override("font_size",16)
		else:
			label.add_theme_font_size_override("font_size",13)
			label.add_theme_color_override("font_color",MUTED)

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
	for text in sections: sections[text].set_pressed_no_signal(text == section)
	flight.visible = section == "飞行"
	reference.visible = not flight.visible
	reset_button.visible = flight.visible
	status.visible = flight.visible
	status.text = REBIND_HINT
	scroll.scroll_vertical = 0
	for tab: Button in tabs.values(): tab.focus_neighbor_bottom = tab.get_path_to(sections[section])
	var first: Button = rows.up.pad if device == "pad" else rows.up.key
	for b: Button in sections.values():
		b.focus_neighbor_right = b.get_path_to(first if flight.visible else return_button)
	sections["飞行"].focus_neighbor_top = sections["飞行"].get_path_to(tabs[device])
	sections["花湾"].focus_neighbor_bottom = sections["花湾"].get_path_to(return_button)
	return_button.focus_neighbor_top = return_button.get_path_to(sections[section])
	if flight.visible:
		for i in bindings.ACTIONS.size():
			var id: String = bindings.ACTIONS[i]
			for slot in ["pad"] if device == "pad" else ["key","mouse"]:
				var b: Button = rows[id][slot]
				b.focus_neighbor_top = b.get_path_to(tabs[device] if i == 0 else rows[bindings.ACTIONS[i-1]][slot])
				b.focus_neighbor_bottom = b.get_path_to(reset_button if i == bindings.ACTIONS.size()-1 else rows[bindings.ACTIONS[i+1]][slot])
				b.focus_neighbor_left = b.get_path_to(rows[id].key if slot == "mouse" else sections[section])
			if device == "kbm": _link(rows[id].key,rows[id].mouse,SIDE_RIGHT)
		return
	for child in reference.get_children():
		reference.remove_child(child)
		child.queue_free()
	var header := _header(reference)
	place(line(header,"固定按键",16,MUTED),Rect2(KEY_X,4,138,34))
	var listed: Array = SHORTCUTS[section].filter(func(shortcut): return not str(shortcut[2 if device == "pad" else 1]).is_empty())
	var step := mini(49,floori(330.0/listed.size()))
	for i in listed.size():
		var shortcut: Array = listed[i]
		var row := _row(reference,42+i*step,step)
		place(line(row,shortcut[0],17),Rect2(ACTION_X,0,165,32))
		var strip := WaxKeycaps.new()
		row.add_child(strip)
		place(strip,Rect2(KEY_X,1,374,31))
		var note_index := 4 if device == "pad" else 3
		var note: String = shortcut[note_index] if shortcut.size() > note_index else ""
		strip.display(shortcut[2 if device == "pad" else 1].split(" / "),note)
		_layout_caps(strip,not note.is_empty())
		_rule(row,step-1)

func refresh_table() -> void:
	for slot in headings:
		headings[slot].visible = (slot == "pad") == (device == "pad")
		for id in rows:
			var button: Button = rows[id][slot]
			button.get_parent().visible = headings[slot].visible
			var names: PackedStringArray = bindings.labels(id, slot)
			var strip := _keycaps(button)
			strip.display(names)
			_layout_caps(strip)
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
	highlights[id].show()
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
	box.bg_color = Color("f3d3b4") if rejected else Color("f4e1b9")
	box.border_color = Color("995336") if rejected else JADE
	box.set_border_width_all(2)
	for state in ["normal", "hover", "pressed"]:
		button.add_theme_stylebox_override(state, box)

func _finish_capture() -> void:
	if not pending_action.is_empty():
		var button: Button = rows[pending_action][pending_slot]
		_binding_button(button)
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
