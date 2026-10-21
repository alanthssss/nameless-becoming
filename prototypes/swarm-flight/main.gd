extends Node2D
const Model = preload("res://game_model.gd")
const Save = preload("res://save_data.gd")
const World = preload("res://world_view.gd")
const Sound = preload("res://sound.gd")
const HANDOFF_SECONDS := 1.6
const TITLES := ["01  晨光菜圃", "02  喷泉花桥", "03  雨中停走", "04  归巢之路"]
const TRANSITIONS := ["菜圃里的呼救声，终于停了。", "花桥把大家送到了雨庭。", "最后一程，老树就在前面。"]
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
var hud_weather: Label
var energy_trail := 100.0
var toast: Label
var toast_left := 0.0
var toast_priority := 0
var toast_guard_left := 0.0
var transition_left := 0.0
var handoff_panel: Panel
var handoff_heading: Label
var handoff_detail: Label
var muted := false
var saved_stage := -1
var saved_payload: Dictionary = {}
var last_section := -1
var save_warning := false
var test_mode := false
var progress_file := ""
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
		if arg.begins_with("--progress-file="): progress_file = arg.trim_prefix("--progress-file=")
		if arg.begins_with("--capture="): capture_path = arg.trim_prefix("--capture=")
		if arg.begins_with("--capture-after="): capture_seconds = float(arg.trim_prefix("--capture-after="))
	world = World.new()
	world.model = model
	world.feedback_font = font
	world.show_behind_parent = true
	add_child(world)
	sound = Sound.new()
	add_child(sound)
	build_ui()
	saved_payload = {} if test_mode else Save.read_payload(Save.PATH if progress_file.is_empty() else progress_file)
	if not saved_payload.is_empty():
		var probe = Model.new()
		if not probe.restore_payload(saved_payload): saved_payload = {}
	saved_stage = int(saved_payload.get("stage",-1))
	get_tree().auto_accept_quit = false
	get_tree().root.close_requested.connect(quit_game)
	show_title()
	get_viewport().size_changed.connect(queue_redraw)
	# Explicit opt-in for deterministic captures, never changes normal launch behavior.
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--chapter="):
			begin_stage(clampi(int(arg.trim_prefix("--chapter=")),0,Model.STAGE_COUNT-1))
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
	hud_weather = label_at(Vector2(38,115),Vector2(184,44),15,Color("d9f4f0"))
	hud_hint = label_at(Vector2(46,737),Vector2(1188,38),19,Color("fff8d8"))
	hud_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast = label_at(Vector2(240,116),Vector2(800,46),21,Color("ffe7a3"))
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var toast_style := card(Color("314b2df5"),12)
	toast.add_theme_stylebox_override("normal",toast_style)
	for node in [hud_title,hud_objective,hud_bees,hud_energy,hud_clock,hud_weather,hud_hint,toast]:
		ui_root.add_child(node)
	cue_panel = Panel.new()
	cue_panel.size = Vector2(350,42)
	cue_panel.add_theme_stylebox_override("panel",card(Color("314b2df5"),12))
	cue_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(cue_panel)
	cue_label = label_at(Vector2(12,5),Vector2(326,32),18,Color("fff0c6"))
	cue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cue_panel.add_child(cue_label)
	handoff_panel = Panel.new()
	handoff_panel.position = Vector2(330,180)
	handoff_panel.size = Vector2(620,128)
	handoff_panel.add_theme_stylebox_override("panel",card(Color("314b2df5"),18))
	handoff_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(handoff_panel)
	handoff_heading = label_at(Vector2(24,17),Vector2(572,38),28,Color("ffd75e"))
	handoff_detail = label_at(Vector2(24,65),Vector2(572,44),19,Color("fff8d8"))
	handoff_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	handoff_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	handoff_panel.add_child(handoff_heading)
	handoff_panel.add_child(handoff_detail)
	handoff_panel.hide()
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
	menu_kicker.text = "BEFORE THE RAIN     /     第一章 · 归家 0.5.1"
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
	world.reset_presentation()
	world.presentation_active = false
	held.clear()
	handoff_panel.hide()
	sound.set_stage(model.music_index())
	panel.show()
	heading.text = "雨来之前"
	description.text = "第一章 · 归家\n穿过菜圃、花桥和雨庭，救出伙伴再回家。\n方向键 / WASD 飞行\n空格按住蓄力，光环亮起后松开冲刺\n沿途叶下自动保存，晨露可选收集。"
	main_button.text = "从头开始这一章"
	secondary_button.visible = not saved_payload.is_empty()
	secondary_button.text = "查看这一章的结尾" if saved_payload.get("completed",false) else "继续第 %d 关 · 已保存的落脚点" % (saved_stage+1)
	third_button.show()
	third_button.text = "退出"
	reset_menu()
	refresh_hud()

func begin_stage(index: int) -> void:
	held.clear()
	handoff_panel.hide()
	toast_priority = 0
	toast_guard_left = 0
	model.load_stage(index)
	world.reset_presentation()
	world.presentation_active = true
	energy_trail = Model.MAX_STAMINA
	mode = "play"
	panel.hide()
	sound.set_stage(model.music_index())
	last_section = model.encounter_index()
	message(["救出这一带的伙伴 · 它们会先飞回家", "冲进第一朵风花，后面的风会接住你", "暴雨从身后追来 · 借风甩开它，叶下能避雨", "最后一程 · 借风甩开暴雨，落叶下歇一口气"][index],4.5)
	persist_progress()
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
			played_seconds = 0
			model.reset_journey()
			begin_stage(0)

func on_secondary() -> void:
	if mode == "title" and not saved_payload.is_empty():
		if not model.restore_payload(saved_payload):
			message("保存的旅程暂时无法读取，可以从头开始。",4.0)
			return
		world.reset_presentation()
		world.presentation_active = true
		var saved_seconds = saved_payload.get("played_seconds",0.0)
		played_seconds = float(saved_seconds) if (saved_seconds is float or saved_seconds is int) and is_finite(float(saved_seconds)) and float(saved_seconds) >= 0 else 0.0
		held.clear()
		last_section = model.encounter_index()
		energy_trail = model.stamina
		sound.set_stage(model.music_index())
		panel.hide()
		mode = "play"
		if saved_payload.get("completed",false):
			show_ending()
		else:
			message("回到已保存的落脚点 · 重新按方向键出发",3.5)
		refresh_hud()
	elif mode == "pause" and paused_from == "play":
		model.restore_checkpoint()
		resume_game()

func on_third() -> void:
	if mode == "pause":
		persist_progress()
		held.clear()
		model.clear_input()
		show_title()
	else:
		quit_game()

func persist_progress() -> void:
	if test_mode: return
	var payload: Dictionary = model.save_payload()
	payload["played_seconds"] = played_seconds
	if model.phase == "ending": payload["completed"] = true
	has_saved = Save.write_payload(payload,Save.PATH if progress_file.is_empty() else progress_file)
	if has_saved:
		saved_payload = payload.duplicate(true)
		saved_stage = model.stage
	elif not save_warning:
		save_warning = true
		message("存档暂时失败 · 可以继续玩，请暂时不要退出。",5.0,Color("ffd3b6"),5)

func quit_game() -> void:
	if mode != "title": persist_progress()
	get_tree().quit()

func pause_game() -> void:
	if mode not in ["play","transition"]: return
	paused_from = mode
	persist_progress()
	mode = "pause"
	world.presentation_active = false
	handoff_panel.hide()
	held.clear()
	model.clear_input()
	panel.show()
	heading.text = "歇一口气"
	description.text = model.chapter_title()+" · "+model.encounter_name()+"\n方向键飞行 · 空格蓄力后松开冲刺\n宽叶下自动保存、恢复体力；可以接着飞\n"+model.section_progress_text()+"\nR 返回落脚点 · M 声音 · Esc 继续"
	main_button.text = "继续飞行"
	secondary_button.text = "回到就近休息点"
	secondary_button.visible = paused_from == "play"
	if paused_from == "transition": description.text = "段落衔接已暂停。\nEsc 或 Enter 继续旅程。"
	third_button.text = "回到标题"
	third_button.show()
	reset_menu()
	refresh_hud()

func resume_game() -> void:
	held.clear()
	mode = paused_from
	world.presentation_active = true
	panel.hide()
	handoff_panel.visible = mode == "transition"
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
		if mode in ["play","transition"]: pause_game()
		elif mode == "pause": resume_game()
		return
	if key == KEY_R and mode == "pause":
		on_secondary()
		return
	if mode == "transition":
		if key in [KEY_ENTER,KEY_KP_ENTER]: on_primary()
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
			if event.kind in ["recover_rain","recover_exhaustion","recover_timeout"]: held.clear()
			world.emit_event(event.kind,event.pos,event)
			sound.play_event(event.kind)
			match event.kind:
				"rescue":
					event_message(event.kind,"救出 %d 只 · 它们先回家了！ · 体力 +%d" % [int(event.get("count",1)),int(round(event.get("reward",0)))],2.8)
				"charge_cancel":
					event_message(event.kind,"还没蓄好力 · 按住空格，等光环亮起再松开",2.6)
				"blocked":
					event_message(event.kind,"先完成本段 · 跟随方向标救援或抵达上一处叶下" if event.get("material") == "waiting" else "干叶帘可以冲开 · 按住空格，亮起后松开" if event.get("material") == "curtain" else "厚实的茎干冲不开 · 从空隙绕过去",2.5)
				"checkpoint":
					event_message(event.kind,"安全了 · 雨幕停在身后，体力恢复 · 已保存" if model.storm_active else "已记住这个叶亭 · 体力正在恢复",3.0)
				"recover_manual":
					event_message(event.kind,"已回到本段最近的恢复点 · 救援成果保留",3.0)
				"recover_rain":
					event_message(event.kind,"被雨打湿了 · 已回到恢复点，救援成果保留",3.5)
				"recover_exhaustion":
					event_message(event.kind,"体力耗尽 · 已回到恢复点，体力补满，救援成果保留",3.5)
				"recover_timeout":
					event_message(event.kind,"在雨里待得太久了 · 已回到叶下，露天时间重置",3.5)
				"tired":
					event_message(event.kind,"体力不足 20 · 无法冲刺，按 R 回到恢复点补充",3.2,Color("ffd3b6"))
				"burst":
					event_message(event.kind,"冲刺 · 体力 −20",1.0)
				"dew":
					event_message(event.kind,"晨露 %d / %d" % [model.garden_awards[model.stage],model.stage_dew_total()] + (" · 体力 +%d" % int(round(event.reward)) if event.reward >= 0.5 else " · 体力已满"),1.9)
				"shield":
					event_message(event.kind,"护雨五秒 · 可以顶着雨转向，留意前方叶亭",2.6,Color("bceae0"))
				"shield_end":
					event_message(event.kind,"护雨结束 · 雨滴仍可绕开或冲散",1.8)
				"flower_calm":
					event_message(event.kind,"喷嚏花安静六秒" + (" · 体力 +%d" % int(round(event.reward)) if event.reward > 0 else " · 放心过去吧"),2.0)
				"hit":
					event_message(event.kind,"体力 −12 · 喷嚏水珠可绕开、冲散" if event.get("reason") == "sneeze" else "体力 −30 · 雨追上来了，寻找大叶遮蔽" if event.get("reason") == "storm" else "体力 −30 · 雨滴可以绕开，或冲刺击散",2.4,Color("ffd3b6"))
				"ring":
					var chain := int(event.get("chain",1))
					var wind_text := "连续借风 ×%d · 不用再蓄力！" % chain if chain > 1 else "借到风 · 顺着风花接着飞"
					event_message(event.kind,wind_text+" · 体力 +%d" % int(round(event.get("reward",0))),1.8)
				"gate":
					event_message(event.kind,"叶帘打开了 · 继续向前！",1.8)
			if event.kind in ["rescue","checkpoint","checkpoint_update"]: persist_progress()
		model.events.clear()
		if model.encounter_index() != last_section:
			last_section = model.encounter_index()
			message(model.encounter_name(),2.2,Color("ffe7a3"),1)
		if model.phase == "transition": show_transition()
		elif model.phase == "ending": show_ending()
	elif mode == "transition":
		transition_left = maxf(0,transition_left-minf(delta,0.1))
		if transition_left <= 0: begin_stage(model.stage+1)
	if mode == "ending": end_time += delta
	if mode == "play":
		toast_left = maxf(0,toast_left-delta)
		toast_guard_left = maxf(0,toast_guard_left-delta)
	toast.visible = toast_left > 0 and mode == "play"
	toast.modulate.a = clampf(toast_left*3.0,0.0,1.0)
	refresh_hud()
	queue_redraw()

func event_message(kind: String, text: String, seconds: float, tint := Color("ffe7a3")) -> void:
	var priority := 1
	if kind in ["rescue","checkpoint"]: priority = 3
	elif kind in ["hit","tired","charge_cancel","blocked"]: priority = 4
	elif kind.begins_with("recover_"): priority = 5
	# Routine launch cost is already shown at the bee and in the stamina bar.
	if kind == "burst": return
	message(text,seconds,tint,priority)

func message(text: String, seconds: float, tint := Color("ffe7a3"), priority := 1) -> void:
	if toast_guard_left > 0 and priority < toast_priority: return
	toast_priority = priority
	toast_guard_left = minf(seconds,1.2) if priority >= 3 else 0.0
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
	panel.hide()
	transition_left = HANDOFF_SECONDS
	handoff_heading.text = TRANSITIONS[model.stage]
	handoff_detail.text = "接下来  %s\n自动出发 · Enter 提前 · Esc 歇一会儿" % TITLES[model.stage+1]
	handoff_panel.show()
	cue_panel.hide()
	toast.hide()

func show_ending() -> void:
	mode = "ending"
	world.presentation_active = true
	handoff_panel.hide()
	held.clear()
	panel.show()
	heading.text = "大家，都到家了。"
	description.text = "四段路，终于连成了一次归途。\n“你回来啦！”伙伴们早已在树洞前等你。\n救出伙伴 %d 只 · 晨露 %d / %d\n旅程 %s · 返回落脚点 %d 次\n第一章 · 归家   完" % [model.bees-1,model.garden_total(),model.journey_dew_total(),clock_text(played_seconds),model.recoveries]
	main_button.text = "再飞完整一章"
	secondary_button.hide()
	third_button.show()
	third_button.text = "留在这一刻，退出"
	end_time = 0
	persist_progress()
	reset_menu()

func clock_text(seconds: float) -> String:
	var total := int(ceil(seconds))
	return "%02d:%02d" % [total / 60,total % 60]

func refresh_hud() -> void:
	var active := mode == "play"
	for l in [hud_title,hud_objective,hud_bees,hud_energy,hud_clock,hud_hint]: l.visible = active
	hud_weather.visible = active and model.storm_active
	cue_panel.visible = false
	if not active: return
	var title: String = "%s · %d/%d %s" % [TITLES[model.stage],model.encounter_index()+1,model.chapter.encounters.size(),model.encounter_name()]
	if model.stage_dew_total() > 0: title += "   ·   晨露 %d/%d" % [model.garden_awards[model.stage],model.stage_dew_total()]
	var objective: String = model.objective()
	var hint: String = model.hint()
	var bees_text := "已救  %d / %d" % [model.bees-1,model.journey_bees_total()-1]
	var energy_text := "体力 %d" % int(ceil(model.stamina))
	var clock := ("露天 " + clock_text(model.rain_remaining)) if model.storm_active else ("旅程 " + clock_text(played_seconds))
	if model.storm_active and model.shelter_index_at(model.p) >= 0: clock += " · 停"
	if model.storm_active:
		hud_weather.text = weather_text()
		hud_weather.add_theme_color_override("font_color",Color("ffd3b6") if model.shelter_index_at(model.p) < 0 and model.storm_gap() < 220 else Color("d9f4f0"))
	hud_clock.add_theme_color_override("font_color",Color("f0a486") if model.storm_active and model.rain_remaining < 15 else Color("fff8d8"))
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
	# Spent petals now show the result in-world; keep text for actionable cues.
	if not cue.is_empty() and cue.kind != "spent":
		var target: Vector2 = cue.pos-Vector2(model.camera_x,0)
		cue_panel.visible = target.x > -40 and target.x < 1320
		var lift := 185.0 if cue.kind == "shelter" else 107.0
		cue_panel.position = Vector2(clampf(target.x-175,24,906),clampf(target.y-lift,175,652))
		cue_label.text = cue.text

func weather_text() -> String:
	if model.shelter_index_at(model.p) >= 0:
		return "叶下安全 · 雨幕停住\n体力恢复，准备再出发"
	if model.storm_gap() < 220:
		return "暴雨逼近 ››\n借风冲向下一片叶下"
	if model.storm_gap() < 640:
		return "暴雨从后方追来 ››\n碰到雨幕会掉体力"
	return "已经甩开雨幕\n向下一片叶下前进"

func _draw() -> void:
	if mode != "play": return
	draw_style_box(card_style,Rect2(24,16,902,84))
	draw_style_box(card_style,Rect2(946,16,310,84))
	draw_style_box(card_style,Rect2(24,729,1232,55))
	if model.storm_active:
		draw_style_box(card_style,Rect2(24,109,208,54))
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
	for i in Model.STAGE_COUNT:
		var color := Color("e9d099") if i <= model.stage else Color("5b7a67")
		draw_line(Vector2(44+i*42,95),Vector2(75+i*42,95),color,2.0,true)
	var section_fill: float = float(model.completed_sections()) / model.section_count()
	draw_line(Vector2(236,95),Vector2(902,95),Color("5b7a67"),2)
	draw_line(Vector2(236,95),Vector2(236+666*section_fill,95),Color("e9d099"),3)
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
