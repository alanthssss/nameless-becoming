extends Node2D
const Model = preload("res://game_model.gd")
const Save = preload("res://save_data.gd")
const World = preload("res://world_view.gd")
const Sound = preload("res://sound.gd")
const TITLES := ["01   风起的时候","02   花桥接力","03   雨来之前"]
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
var toast: Label
var toast_left := 0.0
var muted := false
var saved_stage := -1
var test_mode := false
var paused_from := "play"
var has_saved := false
var end_time := 0.0
var played_seconds := 0.0
var pending_next := false
var capture_path := ""
var capture_seconds := -1.0

func _ready() -> void:
	font.font_names = PackedStringArray(["PingFang SC","Hiragino Sans GB","Noto Sans CJK SC","Microsoft YaHei","sans-serif"])
	for arg in OS.get_cmdline_user_args():
		if arg == "--test": test_mode = true
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

func button_at(y: float, action: Callable) -> Button:
	var b := Button.new()
	b.position = Vector2(42,y)
	b.size = Vector2(434,50)
	b.add_theme_font_override("font",font)
	b.add_theme_font_size_override("font_size",20)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("e8c879")
	normal.corner_radius_top_left = 9
	normal.corner_radius_top_right = 9
	normal.corner_radius_bottom_left = 9
	normal.corner_radius_bottom_right = 9
	b.add_theme_stylebox_override("normal",normal)
	var hover := normal.duplicate()
	hover.bg_color = Color("fff0ba")
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
	return b

func build_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	hud_title = label_at(Vector2(32,20),Vector2(700,35),18,Color("f5dfad"))
	hud_objective = label_at(Vector2(32,55),Vector2(1000,42),25,Color("fff7e3"))
	hud_bees = label_at(Vector2(960,28),Vector2(285,70),22,Color("fff3cd"))
	hud_bees.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud_hint = label_at(Vector2(30,741),Vector2(1220,45),21,Color("fff5d8"))
	hud_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast = label_at(Vector2(130,118),Vector2(1020,48),24,Color("ffe7a3"))
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for node in [hud_title,hud_objective,hud_bees,hud_hint,toast]:
		canvas.add_child(node)
	panel = Panel.new()
	panel.position = Vector2(78,155)
	panel.size = Vector2(520,490)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025,0.09,0.095,0.94)
	style.border_color = Color(0.76,0.69,0.42,0.7)
	style.set_border_width_all(1)
	style.set_corner_radius_all(18)
	panel.add_theme_stylebox_override("panel",style)
	canvas.add_child(panel)
	heading = label_at(Vector2(40,32),Vector2(448,70),40,Color("ffe3a2"))
	description = label_at(Vector2(42,117),Vector2(436,178),21,Color("e1e9d8"))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_constant_override("line_spacing",10)
	main_button = button_at(310,on_primary)
	secondary_button = button_at(370,on_secondary)
	third_button = button_at(430,on_third)
	for node in [heading,description,main_button,secondary_button,third_button]:
		panel.add_child(node)

func show_title() -> void:
	mode = "title"
	sound.set_stage(model.stage)
	panel.show()
	heading.text = "雨来之前"
	description.text = "风把小蜂们吹进了卷叶。\n你得把它们带出来，一起赶在暴雨前回家。\n\n方向键 / WASD 飞行\n按住空格收拢，松开冲刺"
	main_button.text = "从头开始   ↵"
	secondary_button.visible = saved_stage > 0
	secondary_button.text = "继续第 %d 段（从本段开头）" % (saved_stage+1)
	third_button.show()
	third_button.text = "退出"
	refresh_hud()

func begin_stage(index: int) -> void:
	held.clear()
	model.load_stage(index)
	mode = "play"
	panel.hide()
	sound.set_stage(index)
	toast_left = 4.5
	toast.text = ["“等等我！”  卷叶里传来了小小的声音。","“看我的！”  冲进风花，让花桥接你一程。","“灯还亮着。”  叶下能歇脚，雨线就在身后。 "][index]
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
			model.bursts = 0
			model.recoveries = 0
			model.rings_hit = 0
			begin_stage(0)
		"pause": resume_game()
		"transition": begin_stage(model.stage+1)
		"ending":
			model.load_stage(0)
			show_title()

func on_secondary() -> void:
	if mode == "title" and saved_stage > 0:
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
	description.text = "方向键 / WASD 飞行\n按住空格蓄力，松开向当前方向冲刺\n\nR 回到就近休息点\nM 开关声音 · Esc 继续"
	main_button.text = "继续飞行   ↵"
	secondary_button.text = "回到就近休息点"
	secondary_button.show()
	third_button.text = "回到标题"
	third_button.show()
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
	if mode != "play":
		if key == KEY_ENTER or key == KEY_KP_ENTER: on_primary()
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
		played_seconds += minf(delta,0.1)
		var was_ready: bool = model.charge >= 0.75
		model.step(input_direction(),held.has(KEY_SPACE),delta)
		if not was_ready and model.charge >= 0.75: sound.play_event("ready")
		for event in model.events:
			world.emit_event(event.kind,event.pos)
			sound.play_event(event.kind)
			match event.kind:
				"rescue":
					toast.text = "“我也会啦！”  %d 只小蜂一起飞。" % model.bees
					toast_left = 2.6
				"recover":
					toast.text = "大家都在。喘口气，再一起走。"
					toast_left = 2.5
				"ring":
					toast.text = "顺着风——接上了！"
					toast_left = 1.5
		model.events.clear()
		if model.phase == "transition": show_transition()
		elif model.phase == "ending": show_ending()
	if mode == "ending": end_time += delta
	toast_left = maxf(0,toast_left-delta)
	toast.visible = toast_left > 0 and mode == "play"
	refresh_hud()
	queue_redraw()

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
	description.text = TRANSITIONS[model.stage][1]
	main_button.text = TRANSITIONS[model.stage][2] + "   ↵"
	secondary_button.hide()
	third_button.hide()

func show_ending() -> void:
	mode = "ending"
	held.clear()
	panel.show()
	heading.text = "九只，都到家了。"
	description.text = "雨落了下来。\n树洞里，有九对翅膀慢慢安静。\n\n“下次换我飞前面。”\n刚才躲在卷叶里的小蜂说。"
	main_button.text = "再来一趟   ↵"
	secondary_button.hide()
	third_button.show()
	third_button.text = "留在这一刻，退出"
	end_time = 0

func refresh_hud() -> void:
	var active := mode == "play"
	for l in [hud_title,hud_objective,hud_bees,hud_hint]: l.visible = active
	if not active: return
	hud_title.text = TITLES[model.stage] + "       Esc 暂停  ·  M " + ("声音关" if muted else "声音开")
	hud_objective.text = model.objective()
	hud_hint.text = model.hint()
	hud_bees.text = "%d 只同行\n%s" % [model.bees,"●".repeat(model.hp) + "○".repeat(3-model.hp)]

func _draw() -> void:
	if mode != "play": return
	draw_rect(Rect2(0,0,1280,107),Color(0.02,0.07,0.08,0.8))
	draw_rect(Rect2(0,735,1280,65),Color(0.02,0.07,0.08,0.82))
	var target: Vector2 = model.target_position()-Vector2(model.camera_x,0)
	var on_screen := target.x > 85 and target.x < 1195
	var marker := Vector2(clampf(target.x,58,1222),clampf(target.y-75,165,680))
	var pulse := sin(model.time*3)*3
	draw_circle(marker,15+pulse,Color(0.98,0.83,0.45,0.2))
	if on_screen:
		draw_colored_polygon(PackedVector2Array([marker+Vector2(-7,-3),marker+Vector2(7,-3),marker+Vector2(0,7)]),Color("ffe29a"))
	else:
		var sign_x := 1.0 if target.x > 640 else -1.0
		draw_colored_polygon(PackedVector2Array([marker+Vector2(sign_x*9,0),marker+Vector2(-sign_x*4,-7),marker+Vector2(-sign_x*4,7)]),Color("ffe29a"))
