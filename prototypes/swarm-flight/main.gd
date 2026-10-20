extends Node2D
const Model = preload("res://game_model.gd")
const Save = preload("res://save_data.gd")
const World = preload("res://world_view.gd")
const Sound = preload("res://sound.gd")
const TITLES := ["01   晨光菜圃","02   喷泉花桥","03   雨来之前"]
const TRANSITIONS := [
	["一个也没有落下。", "小蜂们学着你的样子，拢起翅膀。\n前面，弯下来的风花正在一朵朵亮起。", "一起借风过去"],
	["现在，你们是九只。", "雨声越来越近。\n老树的灯还亮着——带大家跑完最后一程。", "出发，去树洞"]
]
var model = Model.new()
var world
var sound
var mode := "title"
var held: Dictionary = {}
var font := SystemFont.new()
var panel: Panel
var heading: Label
var description: Label
var main_button: Button
var secondary_button: Button
var third_button: Button
var hud_title: Label
var hud_objective: Label
var hud_hint: Label
var hud_bees: Label
var hud_energy: Label
var hud_clock: Label
var energy_trail := 100.0
var toast: Label
var toast_left := 0.0
var muted := false
var saved_stage := -1
var test_mode := false
var paused_from := "play"
var has_saved := false
var end_time := 0.0
var played_seconds := 0.0
var menu_index := 0
var cue_panel: Panel
var cue_label: Label
var menu_kicker: Label
var menu_footer: Label
var hud_cache := ""
var card_style: StyleBoxFlat
var capture_path := ""
var capture_seconds := -1.0

func _ready() -> void:
	font.font_names = PackedStringArray(["PingFang SC","Hiragino Sans GB","Noto Sans CJK SC","Microsoft YaHei","sans-serif"])
	for arg in OS.get_cmdline_user_args():
		if arg == "--swarm-qa": test_mode = true
		if arg.begins_with("--capture="): capture_path = arg.trim_prefix("--capture=")
		if arg.begins_with("--capture-after="): capture_seconds = float(arg.trim_prefix("--capture-after="))
	world = World.new()
	world.model = model
	world.show_behind_parent = true
	add_child(world)
	sound = Sound.new()
	add_child(sound)
	build_ui()
	saved_stage = -1 if test_mode else Save.read_stage()
	show_title()
	get_viewport().size_changed.connect(queue_redraw)
	# Explicit opt-in for deterministic captures, never changes normal launch behavior.
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--chapter="):
			begin_stage(clampi(int(arg.trim_prefix("--chapter=")),0,2))
	queue_redraw()

func label_at(pos: Vector2, size: Vector2, text_size: int, color: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = size
	l.add_theme_font_override("font",font)
	l.add_theme_font_size_override("font_size",text_size)
	l.add_theme_color_override("font_color",color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func card(color: Color, radius := 14) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.border_color = Color("253d26")
	style.set_border_width_all(3)
	return style

func button_at(y: float, action: Callable) -> Button:
	var b := Button.new()
	b.position = Vector2(42,y)
	b.size = Vector2(434,50)
	b.add_theme_font_override("font",font)
	b.add_theme_font_size_override("font_size",20)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("ffc94f")
	normal.corner_radius_top_left = 9
	normal.corner_radius_top_right = 9
	normal.corner_radius_bottom_left = 9
	normal.corner_radius_bottom_right = 9
	b.add_theme_stylebox_override("normal",normal)
	var hover := normal.duplicate()
	hover.bg_color = Color("ffe58a")
	b.add_theme_stylebox_override("hover",hover)
	b.add_theme_stylebox_override("pressed",hover)
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.set_border_width_all(2)
	focus.border_color = Color("fff4d2")
	focus.set_corner_radius_all(9)
	b.add_theme_stylebox_override("focus",focus)
	b.add_theme_color_override("font_color",Color("183631"))
	b.add_theme_color_override("font_hover_color",Color("183631"))
	b.add_theme_color_override("font_pressed_color",Color("183631"))
	# Space belongs to the flight action. Menu buttons use mouse or Enter via handler.
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(action)
	b.mouse_entered.connect(func(): select_menu_button(b))
	return b

func build_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var ui_root := Control.new()
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(ui_root)
	card_style = card(Color("314b2df5"))
	hud_title = label_at(Vector2(42,24),Vector2(850,26),15,Color("d3e4a1"))
	hud_objective = label_at(Vector2(42,52),Vector2(655,38),23,Color("fff8d8"))
	hud_bees = label_at(Vector2(966,25),Vector2(142,30),20,Color("fff8d8"))
	hud_energy = label_at(Vector2(1110,25),Vector2(124,30),20,Color("fff8d8"))
	hud_energy.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud_clock = label_at(Vector2(704,53),Vector2(202,30),20,Color("fff8d8"))
	hud_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud_hint = label_at(Vector2(46,737),Vector2(1188,38),19,Color("fff8d8"))
	hud_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast = label_at(Vector2(240,116),Vector2(800,46),21,Color("ffe7a3"))
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var toast_style := card(Color("314b2df5"),12)
	toast.add_theme_stylebox_override("normal",toast_style)
	for node in [hud_title,hud_objective,hud_bees,hud_energy,hud_clock,hud_hint,toast]:
		ui_root.add_child(node)
	cue_panel = Panel.new()
	cue_panel.size = Vector2(350,42)
	cue_panel.add_theme_stylebox_override("panel",card(Color("314b2df5"),12))
	cue_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(cue_panel)
	cue_label = label_at(Vector2(12,5),Vector2(326,32),18,Color("fff0c6"))
	cue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cue_panel.add_child(cue_label)
	panel = Panel.new()
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = 64
	panel.offset_right = 584
	panel.offset_top = -270
	panel.offset_bottom = 270
	panel.add_theme_stylebox_override("panel",card(Color("314b2dfa"),22))
	ui_root.add_child(panel)
	menu_kicker = label_at(Vector2(42,24),Vector2(436,28),14,Color("d3e4a1"))
	menu_kicker.text = "BEFORE THE RAIN     /     花园奇遇 0.3.0"
	heading = label_at(Vector2(39,63),Vector2(448,68),44,Color("ffd75e"))
	description = label_at(Vector2(42,151),Vector2(436,160),19,Color("fff8d8"))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_constant_override("line_spacing",5)
	main_button = button_at(326,on_primary)
	secondary_button = button_at(386,on_secondary)
	third_button = button_at(446,on_third)
	menu_footer = label_at(Vector2(42,506),Vector2(436,26),13,Color("d3e4a1"))
	menu_footer.text = "↑ ↓ 选择    Enter 确认    M 声音"
	for node in [menu_kicker,heading,description,main_button,secondary_button,third_button,menu_footer]:
		panel.add_child(node)

func menu_buttons() -> Array[Button]:
	var buttons: Array[Button] = []
	for button in [main_button,secondary_button,third_button]:
		if button.visible: buttons.append(button)
	return buttons

func select_menu_button(button: Button) -> void:
	menu_index = maxi(0,menu_buttons().find(button))
	refresh_menu_selection()

func refresh_menu_selection() -> void:
	var buttons := menu_buttons()
	menu_index = clampi(menu_index,0,maxi(0,buttons.size()-1))
	for i in buttons.size():
		var chosen := i == menu_index
		var style := card(Color("ffc94f") if chosen else Color("3e5d31"),9)
		style.border_color = Color("fff8d8") if chosen else Color("70924d")
		style.set_border_width_all(2 if chosen else 1)
		buttons[i].add_theme_stylebox_override("normal",style)
		buttons[i].add_theme_color_override("font_color",Color("1d3c33") if chosen else Color("fff8d8"))

func reset_menu() -> void:
	menu_index = 0
	refresh_menu_selection()
	cue_panel.hide()
	toast.hide()

func show_title() -> void:
	mode = "title"
	sound.set_stage(model.stage)
	panel.show()
	heading.text = "雨来之前"
	description.text = "穿过会打喷嚏的花园，带伙伴回家。\n方向键 / WASD 飞行，缓慢消耗体力\n空格按住蓄力，亮起后松开冲刺 −20\n晨露补体力，冲刺可以安抚喷嚏花\n赶在暴雨前回家；大叶下休息、停表"
	main_button.text = "从头开始"
	secondary_button.visible = saved_stage >= 0
	secondary_button.text = "继续第 %d 段（从本段开头）" % (saved_stage+1)
	third_button.show()
	third_button.text = "退出"
	reset_menu()
	refresh_hud()

func begin_stage(index: int) -> void:
	held.clear()
	model.load_stage(index)
	energy_trail = Model.MAX_STAMINA
	mode = "play"
	panel.hide()
	sound.set_stage(index)
	toast_left = 4.5
	toast.text = ["“等等我！”  卷叶里传来了小小的声音。","“看我的！”  冲进风花，让花桥接你一程。","暴雨将在 55 秒后抵达 · 大叶下恢复体力、暂停倒计时"][index]
	if not test_mode:
		has_saved = Save.write_stage(index)
		saved_stage = index
		if not has_saved:
			toast.text = "这一趟仍可完整游玩；本段进度暂时未能保存。"
	refresh_hud()

func on_primary() -> void:
	match mode:
		"title":
			played_seconds = 0
			model.reset_journey()
			begin_stage(0)
		"pause": resume_game()
		"transition": begin_stage(model.stage+1)
		"ending":
			model.load_stage(0)
			show_title()

func on_secondary() -> void:
	if mode == "title" and saved_stage >= 0:
		played_seconds = 0
		model.reset_journey()
		begin_stage(saved_stage)
	elif mode == "pause":
		model.restore_checkpoint()
		resume_game()

func on_third() -> void:
	if mode == "pause":
		held.clear()
		model.clear_input()
		show_title()
	else:
		get_tree().quit()

func pause_game() -> void:
	if mode != "play": return
	mode = "pause"
	held.clear()
	model.clear_input()
	panel.show()
	heading.text = "歇一口气"
	description.text = "方向键 / WASD 飞行，空格蓄力后松开\n冲刺 −20 · 雨击 −30 · 喷嚏水珠 −12\n晨露 +12 · 安抚首次 +10 · 均可跳过\n救人 +40 · 借风 +8 · 叶下休息停表\nR 恢复点 · Esc 继续 · M 声音开关"
	main_button.text = "继续飞行"
	secondary_button.text = "回到就近休息点"
	secondary_button.show()
	third_button.text = "回到标题"
	third_button.show()
	reset_menu()
	refresh_hud()

func resume_game() -> void:
	held.clear()
	mode = "play"
	panel.hide()
	refresh_hud()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(panel):
		pause_game()

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or event.echo:
		return
	var key: Key = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	if not event.pressed:
		held.erase(key)
		return
	if key == KEY_M:
		muted = not muted
		sound.set_muted(muted)
		return
	if key == KEY_ESCAPE:
		if mode == "play": pause_game()
		elif mode == "pause": resume_game()
		return
	if key == KEY_R and mode == "pause":
		on_secondary()
		return
	if mode != "play":
		var buttons := menu_buttons()
		if key in [KEY_DOWN,KEY_S,KEY_TAB,KEY_UP,KEY_W] and not buttons.is_empty():
			menu_index = posmod(menu_index + (-1 if key in [KEY_UP,KEY_W] else 1),buttons.size())
			refresh_menu_selection()
		elif key in [KEY_ENTER,KEY_KP_ENTER] and not buttons.is_empty():
			buttons[menu_index].pressed.emit()
		return
	if key == KEY_R:
		model.restore_checkpoint()
		held.clear()
		return
	if key in [KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT,KEY_W,KEY_A,KEY_S,KEY_D,KEY_SPACE]:
		held[key] = true

func input_direction() -> Vector2:
	return Vector2(float(held.has(KEY_RIGHT) or held.has(KEY_D))-float(held.has(KEY_LEFT) or held.has(KEY_A)),float(held.has(KEY_DOWN) or held.has(KEY_S))-float(held.has(KEY_UP) or held.has(KEY_W))).normalized()

func tick(delta: float) -> void:
	if mode == "play":
		var was_ready: bool = model.charge >= Model.CHARGE_READY and model.can_burst()
		model.step(input_direction(),held.has(KEY_SPACE),delta)
		if model.started: played_seconds += minf(delta,0.1)
		energy_trail = maxf(model.stamina,move_toward(energy_trail,model.stamina,delta*24.0))
		if not was_ready and model.charge >= Model.CHARGE_READY and model.can_burst(): sound.play_event("ready")
		for event in model.events:
			world.emit_event(event.kind,event.pos)
			sound.play_event(event.kind)
			match event.kind:
				"rescue":
					message("救出伙伴 · 体力 +40 · %d 只同行 · 已记住这里" % model.bees,2.8)
				"charge_cancel":
					message("还没蓄好力 · 按住空格，等光环亮起再松开",2.6)
				"blocked":
					message("干叶帘可以冲开 · 按住空格，亮起后松开" if event.get("material") == "curtain" else "厚实的茎干冲不开 · 从空隙绕过去",2.5)
				"checkpoint":
					message("叶下休息 · 体力正在恢复，暴雨倒计时暂停",3.0)
				"recover_manual":
					message("已回到本段最近的恢复点 · 伙伴都在",3.0)
				"recover_rain":
					message("被雨打湿了 · 已回到恢复点，伙伴都在",3.5)
				"recover_exhaustion":
					message("体力耗尽 · 已回到恢复点，体力补满，伙伴都在",3.5)
				"recover_timeout":
					message("暴雨抵达 · 从恢复点再试，倒计时已重置",3.5)
				"tired":
					message("体力不足 20 · 无法冲刺，按 R 回到恢复点补充",3.2,Color("ffd3b6"))
				"burst":
					message("冲刺 · 体力 −20",1.0)
				"dew":
					message("晨露 %d / 3 · 体力 +%d" % [model.garden_awards[model.stage],int(round(event.reward))],1.9)
				"flower_calm":
					message("喷嚏花安静六秒" + (" · 体力 +%d" % int(round(event.reward)) if event.reward > 0 else " · 放心过去吧"),2.0)
				"hit":
					message("体力 −12 · 喷嚏水珠可绕开、冲散" if event.get("reason") == "sneeze" else "体力 −30 · 雨追上来了，寻找大叶遮蔽" if event.get("reason") == "storm" else "体力 −30 · 雨滴可以绕开，或冲刺击散",2.4,Color("ffd3b6"))
				"ring":
					message("借到风 · 体力 +8 · 花瓣收拢后就用过了",2.3)
				"gate":
					message("叶帘打开了 · 一起过去！",1.8)
		model.events.clear()
		if model.phase == "transition": show_transition()
		elif model.phase == "ending": show_ending()
	if mode == "ending": end_time += delta
	toast_left = maxf(0,toast_left-delta)
	toast.visible = toast_left > 0 and mode == "play"
	toast.modulate.a = clampf(toast_left*3.0,0.0,1.0)
	refresh_hud()
	queue_redraw()

func message(text: String, seconds: float, tint := Color("ffe7a3")) -> void:
	toast.text = text
	toast.add_theme_color_override("font_color",tint)
	toast_left = seconds

func _process(delta: float) -> void:
	tick(delta)
	if capture_seconds >= 0:
		capture_seconds -= delta
		if capture_seconds < 0 and not capture_path.is_empty():
			capture.call_deferred()

func capture() -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(capture_path)
	print("CAPTURED: " + capture_path)
	get_tree().quit()

func show_transition() -> void:
	mode = "transition"
	held.clear()
	panel.show()
	heading.text = TRANSITIONS[model.stage][0]
	description.text = TRANSITIONS[model.stage][1] + "\n\n本段晨露 %d / 3 · 本次共 %d / 9\n晨露是可选奖励，伙伴才是旅途的目的。" % [model.garden_awards[model.stage],model.garden_total()]
	main_button.text = TRANSITIONS[model.stage][2]
	secondary_button.hide()
	third_button.hide()
	reset_menu()

func show_ending() -> void:
	mode = "ending"
	held.clear()
	panel.show()
	heading.text = "九只，都到家了。"
	description.text = "雨落了下来，九对翅膀慢慢安静。\n“下次换我飞前面。”小蜂说。\n本次晨露 %d / 9 · %s\n旅程 %s · 返回恢复点 %d 次\n每一个伙伴，都平安到家。" % [model.garden_total(),"满园的花都开了！" if model.garden_total() == 9 else "小花记住了这趟旅程",clock_text(played_seconds),model.recoveries]
	main_button.text = "再来一趟"
	secondary_button.hide()
	third_button.show()
	third_button.text = "留在这一刻，退出"
	end_time = 0
	reset_menu()

func clock_text(seconds: float) -> String:
	var total := int(ceil(seconds))
	return "%02d:%02d" % [total / 60,total % 60]

func refresh_hud() -> void:
	var active := mode == "play"
	for l in [hud_title,hud_objective,hud_bees,hud_energy,hud_clock,hud_hint]: l.visible = active
	cue_panel.visible = false
	if not active: return
	var title: String = TITLES[model.stage] + "     ·     晨露 %d / 3（可选）" % model.garden_awards[model.stage] + "     ·     Esc 暂停     ·     M " + ("声音关" if muted else "声音开")
	var objective: String = model.objective()
	var hint: String = model.hint()
	var bees_text := "同行  %d / 9" % model.bees
	var energy_text := "体力 %d" % int(ceil(model.stamina))
	var clock := ("暴雨 " + clock_text(model.rain_remaining)) if model.stage == 2 else ("旅程 " + clock_text(played_seconds))
	if model.stage == 2 and model.shelter_index_at(model.p) >= 0: clock += " · 停"
	hud_clock.add_theme_color_override("font_color",Color("f0a486") if model.stage == 2 and model.rain_remaining < 15 else Color("fff8d8"))
	hud_energy.add_theme_color_override("font_color",Color("f0a486") if not model.can_burst() else Color("fff8d8"))
	# Continuous charge/cue positions update per frame; text nodes change only with state.
	var cache := title+objective+hint+bees_text+energy_text+clock
	if cache != hud_cache:
		hud_cache = cache
		hud_title.text = title
		hud_objective.text = objective
		hud_hint.text = hint
		hud_bees.text = bees_text
		hud_energy.text = energy_text
		hud_clock.text = clock
	var cue: Dictionary = model.context_cue()
	if not cue.is_empty():
		var target: Vector2 = cue.pos-Vector2(model.camera_x,0)
		cue_panel.visible = target.x > -40 and target.x < 1320
		var lift := 185.0 if cue.kind == "shelter" else 107.0
		cue_panel.position = Vector2(clampf(target.x-175,24,906),clampf(target.y-lift,175,652))
		cue_label.text = cue.text

func _draw() -> void:
	if mode != "play": return
	draw_style_box(card_style,Rect2(24,16,902,84))
	draw_style_box(card_style,Rect2(946,16,310,84))
	draw_style_box(card_style,Rect2(24,729,1232,55))
	var energy_rect := Rect2(966,64,268,14)
	draw_rect(energy_rect,Color("36564e"))
	draw_rect(Rect2(energy_rect.position,Vector2(268*energy_trail/Model.MAX_STAMINA,14)),Color("e9a88a"))
	var energy_color := Color("efbc8d") if not model.can_burst() else Color("d9d8a4")
	draw_rect(Rect2(energy_rect.position,Vector2(268*model.stamina/Model.MAX_STAMINA,14)),energy_color)
	for i in range(1,5):
		draw_line(Vector2(966+i*53.6,64),Vector2(966+i*53.6,78),Color("3e5d31"),2)
	if model.charging and model.can_burst():
		var cost_start: float = 966+268*(model.stamina-Model.BURST_COST)/Model.MAX_STAMINA
		draw_rect(Rect2(cost_start,64,53.6,14),Color(1,0.87,0.65,0.4+sin(model.time*8)*0.15))
	for i in 3:
		var color := Color("e9d099") if i <= model.stage else Color("5b7a67")
		draw_line(Vector2(44+i*42,95),Vector2(75+i*42,95),color,2.0,true)
	var target: Vector2 = model.target_position()-Vector2(model.camera_x,0)
	var on_screen := target.x > 85 and target.x < 1195
	var marker := Vector2(clampf(target.x,58,1222),clampf(target.y-75,180,680))
	if on_screen and not model.context_cue().is_empty(): return
	var pulse := sin(model.time*3)*2
	draw_circle(marker,16+pulse,Color(0.06,0.19,0.16,0.8))
	if on_screen:
		draw_colored_polygon(PackedVector2Array([marker+Vector2(-7,-3),marker+Vector2(7,-3),marker+Vector2(0,7)]),Color("ffe29a"))
	else:
		var sign_x := 1.0 if target.x > 640 else -1.0
		draw_colored_polygon(PackedVector2Array([marker+Vector2(sign_x*9,0),marker+Vector2(-sign_x*4,-7),marker+Vector2(-sign_x*4,7)]),Color("ffe29a"))
