extends Node2D
const Model = preload("res://region_greybox/model.gd")
const Layout = preload("res://region_greybox/layout.gd")
var model: RefCounted
var font := SystemFont.new()
var stage := "setup"
var camera_offset := Vector2.ZERO
var map_visible := false
var paused := false
var region_select: OptionButton
var state_select: OptionButton
var growth_select: OptionButton
var setup_panel: Control
var result_panel: Control
var pause_panel: Control
var hud: Control
var status: Label
var energy_bar: ProgressBar
var hint: Label
var result_text: Label
var clock := 0.0
var _recorded := false
var session_log := "user://region_greybox/sessions.jsonl"

func _ready() -> void:
	font.font_names = PackedStringArray(["PingFang SC", "Noto Sans CJK SC", "Microsoft YaHei", "sans-serif"])
	get_window().title = "区域灰盒 · 池岸与紫花地"
	_build_ui()
	queue_redraw()

func _label(text: String, size := 22) -> Label:
	var item := Label.new()
	item.text = text
	item.add_theme_font_override("font", font)
	item.add_theme_font_size_override("font_size", size)
	item.add_theme_color_override("font_color", Color("e6ecdf"))
	return item

func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 44)
	button.add_theme_font_override("font", font)
	button.add_theme_font_size_override("font_size", 21)
	button.pressed.connect(action)
	return button

func _panel(parent: Node, width: float, height: float) -> PanelContainer:
	var panel := PanelContainer.new()
	parent.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -width / 2
	panel.offset_top = -height / 2
	panel.offset_right = width / 2
	panel.offset_bottom = height / 2
	var style := StyleBoxFlat.new()
	style.bg_color = Color("233d35")
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 22
	style.content_margin_bottom = 22
	style.set_corner_radius_all(12)
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _choices(items: Array) -> OptionButton:
	var option := OptionButton.new()
	option.custom_minimum_size.y = 44
	option.add_theme_font_override("font", font)
	option.add_theme_font_size_override("font_size", 21)
	for item in items: option.add_item(item)
	return option

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	layer.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud = MarginContainer.new()
	root.add_child(hud)
	hud.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	hud.offset_left = 20
	hud.offset_top = 12
	hud.offset_right = -20
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hud_box := VBoxContainer.new()
	hud.add_child(hud_box)
	var row := HBoxContainer.new()
	hud_box.add_child(row)
	status = _label("", 21)
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(status)
	row.add_child(_button("暂停", _toggle_pause))
	energy_bar = ProgressBar.new()
	energy_bar.custom_minimum_size.y = 14
	energy_bar.show_percentage = false
	hud_box.add_child(energy_bar)
	hint = _label("", 19)
	hud_box.add_child(hint)
	hud_box.add_child(_label("浅色地面可飞 · 深色为实体灌木 · 绿色圆区遮雨", 17))
	var help := _label("移动 WASD / 方向键   E / 左键采蜜 · 入口按 E 返回   Q / 右键振翅   空格蓄力冲刺   M 已探索图", 18)
	root.add_child(help)
	help.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	help.offset_left = 20
	help.offset_top = -38
	help.offset_right = 1260
	help.offset_bottom = -6
	setup_panel = _panel(root, 640, 570)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	setup_panel.add_child(box)
	box.add_child(_label("池岸与紫花地 · 可玩灰盒", 29))
	box.add_child(_label("探索分岔和回路，带着收获返回入口。", 21))
	box.add_child(_label("本轮只验证地图；条件出发前选定，途中不变。", 19))
	region_select = _choices(["池岸 · 内湾与远岸", "紫花地 · 正面与背坡"])
	state_select = _choices(["晴日 · 基础通路", "细雨 · 叶棚路线", "局部布局变体 · 通路改接"])
	growth_select = _choices(["成长前 · 体力36 / 容量6 / 采蜜1.8秒", "成长后 · 体力70 / 容量16 / 采蜜0.8秒"])
	box.add_child(region_select)
	box.add_child(state_select)
	box.add_child(growth_select)
	box.add_child(_label("方向键或 WASD 移动；靠近花按住 E 采蜜。\n材料点按 Q 振翅，松落后靠近拾取。\n体力耗尽会结束本趟；Esc 可暂停。", 19))
	box.add_child(_button("出发", start_trip))
	box.add_child(_button("退出灰盒", func(): get_tree().quit()))
	result_panel = _panel(root, 700, 640)
	var results := VBoxContainer.new()
	results.add_theme_constant_override("separation", 12)
	result_panel.add_child(results)
	var result_scroll := ScrollContainer.new()
	result_scroll.custom_minimum_size = Vector2(640, 360)
	result_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	results.add_child(result_scroll)
	result_text = _label("", 21)
	result_scroll.add_child(result_text)
	results.add_child(_button("相同条件再走一趟", start_trip))
	results.add_child(_button("更换区域 / 状态 / 成长", _show_setup))
	results.add_child(_button("退出灰盒", func(): get_tree().quit()))
	result_panel.hide()
	pause_panel = _panel(root, 430, 270)
	var pause_box := VBoxContainer.new()
	pause_box.add_theme_constant_override("separation", 14)
	pause_panel.add_child(pause_box)
	pause_box.add_child(_label("已暂停 · 体力不消耗", 25))
	pause_box.add_child(_button("继续出行", _toggle_pause))
	pause_box.add_child(_button("结束本趟并更换条件", _abandon))
	pause_box.add_child(_button("退出灰盒", func(): get_tree().quit()))
	pause_panel.hide()
	hud.hide()

func start_trip() -> void:
	model = Model.new()
	model.configure(["pond", "violet"][region_select.selected], ["sunny", "rain", "variant"][state_select.selected], growth_select.selected)
	stage = "active"
	paused = false
	map_visible = false
	_recorded = false
	setup_panel.hide()
	result_panel.hide()
	pause_panel.hide()
	hud.show()
	_update_camera()
	queue_redraw()

func _show_setup() -> void:
	stage = "setup"
	paused = false
	result_panel.hide()
	pause_panel.hide()
	hud.hide()
	setup_panel.show()
	queue_redraw()

func _abandon() -> void:
	model.finish("abandoned")
	_record()
	_show_setup()

func _toggle_pause() -> void:
	if stage != "active": return
	paused = not paused
	pause_panel.visible = paused

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and stage == "active" and not paused:
		paused = true
		if is_instance_valid(pause_panel): pause_panel.show()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE: _toggle_pause()
		if event.keycode == KEY_M and stage == "active": map_visible = not map_visible

func _process(delta: float) -> void:
	clock += delta
	if stage != "active" or paused:
		queue_redraw()
		return
	var move := Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)), float(Input.is_physical_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)))
	var pulse := Input.is_physical_key_pressed(KEY_Q) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	var aim: Vector2 = get_viewport().get_mouse_position() + camera_offset - model.p if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) else Vector2.ZERO
	model.step(delta, move, Input.is_physical_key_pressed(KEY_E) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT), Input.is_physical_key_pressed(KEY_SPACE), pulse, aim)
	_update_camera()
	var name: String = "池岸" if model.region == "pond" else "紫花地"
	var weather: String = {"sunny": "晴日", "rain": "细雨", "variant": "支路变体"}[model.condition]
	status.text = "%s · %s    体力 %.1f / %.0f    花蜜 %d / %d    材料 %d    %.0f秒" % [name, weather, model.energy, model.max_energy(), model.cargo, model.capacity(), model.material_count, model.elapsed]
	energy_bar.max_value = model.max_energy()
	energy_bar.value = model.energy
	hint.text = "已到入口，按 E 返回并查看这趟记录" if model.departed and model.at_entry() else "体力偏低：留意来路，选择返程" if model.energy < 12 else model.last_action
	if model.condition == "rain": hint.text += "  ·  " + ("叶棚遮雨" if not model.exposed() else "露天淋雨")
	if model.phase != "active": _show_result()
	queue_redraw()

func _update_camera() -> void:
	var size := get_viewport_rect().size
	var bounds: Rect2 = model.layout.bounds
	camera_offset = model.p - Vector2(size.x * 0.48, size.y * 0.57)
	camera_offset.x = clampf(camera_offset.x, bounds.position.x, maxf(bounds.position.x, bounds.end.x - size.x))
	camera_offset.y = clampf(camera_offset.y, bounds.position.y, maxf(bounds.position.y, bounds.end.y - size.y))

func _show_result() -> void:
	stage = "result"
	_record()
	var title := "顺利返回" if model.phase == "returned" else "体力耗尽 · 本趟结束"
	var names: Array[String] = []
	for id in model.visits: names.append(model.layout.nodes[id].name)
	result_text.text = "%s\n\n用时 %.1f 秒    飞行 %.0f 像素\n剩余体力 %.1f / %.0f    花蜜 %d    材料 %d\n露天淋雨 %.1f 秒    采蜜 %.1f 秒\n\n经过：\n%s\n\n记录只属于灰盒，不影响正式存档。" % [title, model.elapsed, model.distance, model.energy, model.max_energy(), model.cargo, model.material_count, model.rain_seconds, model.harvest_seconds, " → ".join(names)]
	result_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_text.custom_minimum_size.x = 640
	result_panel.show()

func _record() -> void:
	if _recorded: return
	_recorded = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://region_greybox"))
	var file := FileAccess.open(session_log, FileAccess.READ_WRITE if FileAccess.file_exists(session_log) else FileAccess.WRITE_READ)
	if file:
		file.seek_end()
		var data: Dictionary = model.summary()
		data["observed_at"] = Time.get_datetime_string_from_system()
		file.store_line(JSON.stringify(data))

func _draw() -> void:
	var size := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, size), Color("293f35"))
	if model == null: return
	draw_set_transform(-camera_offset)
	# Every visibly pale surface is the same union used by collision. Dark mass is solid hedge.
	for path in model.layout.paths:
		draw_polyline(path, Color("9d9d7f"), model.layout.corridor_radius * 2 + 4, true)
		draw_polyline(path, Color("d6d2b9"), model.layout.corridor_radius * 2, true)
		for p in path: draw_circle(p, model.layout.corridor_radius, Color("d6d2b9"))
	for node in model.layout.nodes:
		draw_circle(node.p, node.radius + 2, Color("9d9d7f"))
		draw_circle(node.p, node.radius, Color("d6d2b9"))
		var center: Vector2 = node.p
		if model.region == "pond" and node.id == 3: draw_circle(center + Vector2(25, 15), 70, Color("94b8bc"))
		# Labels identify locations; the route itself is discovered by moving the camera.
		draw_string(font, center + Vector2(-108, -122), node.name, HORIZONTAL_ALIGNMENT_CENTER, 216, 23, Color("203d34"))
		if node.id == 0:
			draw_circle(center, 62, Color("86aa85"))
			draw_string(font, center + Vector2(-75, 8), "E 返回", HORIZONTAL_ALIGNMENT_CENTER, 150, 22, Color("203d34"))
	for roof in model.layout.shelters:
		draw_circle(roof.p, roof.radius, Color(0.26, 0.48, 0.33, 0.22))
		draw_arc(roof.p, roof.radius, 0, TAU, 28, Color("75947c"), 3, true)
	for flower in model.flowers:
		if flower.stock <= 0:
			draw_circle(flower.p, 7, Color("a2a38c"))
			continue
		var color := Color("ead575") if model.region == "pond" else Color("ab86cb")
		draw_circle(flower.p, 15, color)
		draw_circle(flower.p, 5, Color("faf0bf"))
		if flower.progress > 0: draw_arc(flower.p, 22, -PI / 2, -PI / 2 + flower.progress * TAU, 22, Color("f4ba48"), 4, true)
	for item in model.materials:
		if item.taken: continue
		draw_rect(Rect2(item.p - Vector2.ONE * 13, Vector2.ONE * 26), Color("cc9b64") if item.dropped else Color("927b61"))
		draw_string(font, item.p + Vector2(-45, -27), "拾取" if item.dropped else "Q 材料", HORIZONTAL_ALIGNMENT_CENTER, 90, 18, Color("3c483b"))
	var bee: Vector2 = model.p
	draw_circle(bee + Vector2(-10, -9), 12, Color("ecf2df"))
	draw_circle(bee + Vector2(10, -9), 12, Color("ecf2df"))
	draw_circle(bee, 15, Color("efc955"))
	draw_line(bee - Vector2(8, 3), bee + Vector2(8, 3), Color("483f2d"), 5, true)
	draw_line(bee, bee + model.face * 27, Color("fff6cf"), 4, true)
	if model.pulse_flash > 0: draw_arc(bee, 70, model.face.angle() - .7, model.face.angle() + .7, 18, Color("fff6cf"), 5, true)
	if model.condition == "rain":
		for i in 85:
			var drop := camera_offset + Vector2(fmod(i * 173.0 + clock * 20, size.x), fmod(i * 97.0 + clock * 310, size.y))
			if not Layout.sheltered(model.layout, drop): draw_line(drop, drop + Vector2(-5, 15), Color(.66, .80, .87, .6), 2)
	draw_set_transform(Vector2.ZERO)
	if map_visible: _draw_explored_map(size)
	if stage != "active" or paused: draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.08, 0.06, .45))

func _draw_explored_map(size: Vector2) -> void:
	var box := Rect2(size.x - 330, 126, 305, 240)
	draw_rect(box, Color(.08, .16, .12, .94))
	draw_string(font, box.position + Vector2(15, 27), "已探索路线 · M 收起", HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color("e6ecdf"))
	var bounds: Rect2 = model.layout.bounds
	var scale_factor := minf(270 / bounds.size.x, 180 / bounds.size.y)
	var origin := box.position + Vector2(15, 45)
	var points := PackedVector2Array()
	for sample in model.trace:
		points.append(origin + (Vector2(sample.x, sample.y) - bounds.position) * scale_factor)
	if points.size() > 1: draw_polyline(points, Color("abbba0"), 2, true)
	for id in model.visits:
		draw_circle(origin + (model.layout.nodes[id].p - bounds.position) * scale_factor, 4, Color("e9c65b"))
	draw_circle(origin + (model.p - bounds.position) * scale_factor, 5, Color("faf8de"))
