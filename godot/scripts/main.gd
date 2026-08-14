extends Node2D

const WORLD := Rect2(34, 146, 970, 538)
const HIVE_X := 132.0
const FLOWER_COLORS := [Color("f2d66f"), Color("e9aab1"), Color("a995c9")]
const TERMS := ["立春", "雨水", "惊蛰", "春分", "清明", "谷雨", "立夏", "小满", "芒种", "夏至", "小暑", "大暑", "立秋", "处暑", "白露", "秋分", "寒露", "霜降", "立冬", "小雪", "大雪", "冬至", "小寒", "大寒"]

var stages: Array = []
var balance: Dictionary = {}
var upgrade_catalog: Array = []
var chosen_upgrades: Array[String] = []
var upgrade_counts := {"long_wing": 0, "forager": 0, "guard": 0}
var stage_index := 0
var phase := "intro"
var bee: BeePlayer
var flowers: Array = []
var mosquitoes: Array = []
var ants: Array = []
var tuning_blooms: Array[Vector2] = []
var boss := {"position": Vector2.ZERO, "velocity": Vector2.ZERO, "hits": 0, "hit_cooldown": 0.0}
var pollen: Array = []
var carried := 0
var delivered := 0
var hive_lives := 3
var harvest_clock := 0.0
var sting_cooldown := 0.0
var hit_cooldown := 0.0
var harvest_multiplier := 1.0
var sting_range := 88.0
var sting_cost := 8.0
var sting_cooldown_multiplier := 1.0
var extra_nectar := 0
var elapsed := 0.0
var run_elapsed := 0.0
var shake := 0.0
var flash := 0.0
var message := "飞向花朵，采蜜后亲自返回左侧蜂巢。"
var rng := RandomNumberGenerator.new()
var save_manager := HiveSaveManager.new()
var sound := SoundFeedback.new()
var paused_from_phase := "playing"
var persistence_enabled := true

var title_label: Label
var term_label: Label
var carried_label: Label
var delivered_label: Label
var energy_label: Label
var hive_label: Label
var message_label: Label
var detail_label: Label
var overlay: ColorRect
var overlay_title: Label
var overlay_body: Label
var overlay_button: Button
var upgrade_buttons: Array[Button] = []
var pause_button: Button
var fullscreen_button: Button
var sound_button: Button

func _ready() -> void:
	rng.randomize()
	save_manager.load_data()
	apply_display_settings()
	load_stage_data()
	load_balance_data()
	load_upgrade_data()
	bee = BeePlayer.new()
	bee.position = Vector2(180, 410)
	bee.sense_started.connect(on_sense_started)
	add_child(bee)
	add_child(sound)
	sound.set_enabled(save_manager.sound_enabled)
	build_interface()
	show_intro()
	queue_redraw()

func load_stage_data() -> void:
	var file := FileAccess.open("res://data/seasons.json", FileAccess.READ)
	if file == null:
		push_error("无法读取节令数据")
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Array:
		stages = parsed
	else:
		push_error("节令数据格式错误")

func load_upgrade_data() -> void:
	var file := FileAccess.open("res://data/upgrades.json", FileAccess.READ)
	if file == null:
		push_error("无法读取蜂巢成长数据")
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Array:
		upgrade_catalog = parsed
	else:
		push_error("蜂巢成长数据格式错误")

func load_balance_data() -> void:
	var file := FileAccess.open("res://data/balance.json", FileAccess.READ)
	if file == null:
		push_error("无法读取平衡参数")
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		balance = parsed
	else:
		push_error("平衡参数格式错误")

func balance_value(section: String, key: String, fallback: float) -> float:
	if balance.has(section) and balance[section] is Dictionary:
		return float(balance[section].get(key, fallback))
	return fallback

func make_label(parent: Node, text: String, position: Vector2, size: Vector2, font_size: int, color := Color("252a22")) -> Label:
	var label := Label.new()
	label.text = text
	label.position = position
	label.size = size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func build_interface() -> void:
	var ui := CanvasLayer.new()
	ui.name = "Interface"
	add_child(ui)

	title_label = make_label(ui, "◆  归巢之前", Vector2(34, 17), Vector2(350, 42), 24, Color("26342b"))
	make_label(ui, "HIVEBOUND · GODOT VERTICAL SLICE", Vector2(67, 48), Vector2(370, 20), 10, Color("566257"))
	term_label = make_label(ui, "春 · 春分", Vector2(520, 16), Vector2(240, 52), 25, Color("26342b"))
	term_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	fullscreen_button = Button.new()
	fullscreen_button.position = Vector2(810, 22)
	fullscreen_button.size = Vector2(100, 36)
	fullscreen_button.pressed.connect(toggle_fullscreen)
	ui.add_child(fullscreen_button)
	sound_button = Button.new()
	sound_button.position = Vector2(920, 22)
	sound_button.size = Vector2(100, 36)
	sound_button.pressed.connect(toggle_sound)
	ui.add_child(sound_button)
	var quit_button := Button.new()
	quit_button.text = "退出"
	quit_button.position = Vector2(1030, 22)
	quit_button.size = Vector2(100, 36)
	quit_button.pressed.connect(func(): get_tree().quit())
	ui.add_child(quit_button)
	pause_button = Button.new()
	pause_button.text = "暂停"
	pause_button.position = Vector2(1140, 22)
	pause_button.size = Vector2(110, 36)
	pause_button.pressed.connect(toggle_pause)
	ui.add_child(pause_button)
	refresh_setting_labels()

	carried_label = make_stat(ui, "携带", Vector2(34, 82))
	delivered_label = make_stat(ui, "本节储蜜", Vector2(234, 82))
	energy_label = make_stat(ui, "飞行体力", Vector2(434, 82))
	hive_label = make_stat(ui, "蜂巢呼吸", Vector2(634, 82))

	var side := ColorRect.new()
	side.color = Color("f3eedb", 0.94)
	side.position = Vector2(1020, 146)
	side.size = Vector2(230, 538)
	ui.add_child(side)
	make_label(side, "当前节令", Vector2(20, 20), Vector2(190, 20), 11, Color("68705d"))
	detail_label = make_label(side, "春分", Vector2(20, 50), Vector2(190, 250), 25, Color("293c32"))
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label = make_label(side, message, Vector2(20, 300), Vector2(190, 135), 13, Color("4c5548"))
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	make_label(side, "左键点地移动 · 左侧是归巢区", Vector2(20, 412), Vector2(190, 38), 11, Color("556054"))
	make_mouse_action(side, "按住采蜜", "harvest", Vector2(16, 450), true)
	make_mouse_action(side, "按住振翅", "dash", Vector2(116, 450), true)
	make_mouse_action(side, "蜂针", "sting", Vector2(16, 492), false)
	make_mouse_action(side, "感知", "sense", Vector2(116, 492), false)

	var tips := make_label(ui, "WASD / 方向键  飞行     空格  采蜜     Shift  振翅     J  蜂针     E  感知", Vector2(34, 690), Vector2(970, 24), 12, Color("f7f0d5"))
	tips.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	overlay = ColorRect.new()
	overlay.color = Color("21352c", 0.93)
	overlay.position = Vector2(34, 146)
	overlay.size = Vector2(970, 538)
	ui.add_child(overlay)
	overlay_title = make_label(overlay, "再采一朵，\n还是现在归巢？", Vector2(150, 82), Vector2(670, 150), 54, Color("fff8d9"))
	overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_body = make_label(overlay, "控制蜜蜂飞向花朵，按住空格采蜜。\n体力耗尽前，带着花蜜返回左侧蜂巢。", Vector2(190, 245), Vector2(590, 78), 17, Color("d8ddc9"))
	overlay_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_button = Button.new()
	overlay_button.text = "飞入春分"
	overlay_button.position = Vector2(374, 345)
	overlay_button.size = Vector2(220, 54)
	overlay_button.add_theme_font_size_override("font_size", 18)
	overlay_button.pressed.connect(on_overlay_button)
	overlay.add_child(overlay_button)
	for i in 3:
		var choice := Button.new()
		choice.position = Vector2(105 + i * 255, 330)
		choice.size = Vector2(235, 125)
		choice.add_theme_font_size_override("font_size", 16)
		choice.pressed.connect(on_upgrade_selected.bind(i))
		choice.visible = false
		overlay.add_child(choice)
		upgrade_buttons.append(choice)
	make_label(overlay, "四季搜打撤 · 核心交互测试", Vector2(300, 38), Vector2(370, 25), 12, Color("dfbd54")).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func make_stat(parent: Node, caption: String, position: Vector2) -> Label:
	var panel := ColorRect.new()
	panel.color = Color("f3eedb", 0.84)
	panel.position = position
	panel.size = Vector2(190, 50)
	parent.add_child(panel)
	make_label(panel, caption, Vector2(12, 5), Vector2(90, 18), 10, Color("6d715f"))
	var value := make_label(panel, "0", Vector2(100, 8), Vector2(75, 30), 17, Color("26342b"))
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return value

func make_mouse_action(parent: Node, caption: String, action: String, position: Vector2, hold: bool) -> Button:
	var button := Button.new()
	button.text = caption
	button.position = position
	button.size = Vector2(96, 36)
	if hold:
		button.button_down.connect(func(): Input.action_press(action))
		button.button_up.connect(func(): Input.action_release(action))
	else:
		button.pressed.connect(pulse_action.bind(action))
	parent.add_child(button)
	return button

func pulse_action(action: String) -> void:
	Input.action_press(action)
	await get_tree().process_frame
	Input.action_release(action)

func show_intro() -> void:
	phase = "intro"
	bee.active = false
	overlay.visible = true
	overlay_title.text = "再采一朵，\n还是现在归巢？"
	overlay_body.text = "控制蜜蜂飞向花朵，按住空格采蜜。\n体力耗尽前，带着花蜜返回左侧蜂巢。\n\n历史最远：%s  ·  完成轮回：%d%s" % [progress_name(), save_manager.runs_completed, last_run_text()]
	overlay_button.text = "飞入春分"
	set_upgrade_buttons_visible(false)

func start_game() -> void:
	hive_lives = 3
	stage_index = 0
	run_elapsed = 0.0
	chosen_upgrades.clear()
	upgrade_counts = {"long_wing": 0, "forager": 0, "guard": 0}
	harvest_multiplier = 1.0
	sting_range = balance_value("player", "sting_range", 88.0)
	sting_cost = balance_value("player", "sting_cost", 8.0)
	sting_cooldown_multiplier = 1.0
	extra_nectar = 0
	bee.reset_upgrades()
	if persistence_enabled:
		save_manager.begin_run()
	spawn_stage(0)

func spawn_stage(index: int) -> void:
	if stages.is_empty():
		return
	stage_index = index
	phase = "playing"
	overlay.visible = false
	carried = 0
	delivered = 0
	harvest_clock = 0.0
	sting_cooldown = 0.0
	hit_cooldown = 0.0
	flowers.clear()
	mosquitoes.clear()
	ants.clear()
	tuning_blooms.clear()
	pollen.clear()
	var data: Dictionary = stages[index]
	bee.configure(float(data.energy_drain))
	bee.reset_for_expedition(Vector2(180, 410))
	for i in int(data.flowers):
		flowers.append({
			"id": i,
			"position": Vector2(rng.randf_range(300, 950), rng.randf_range(205, 620)),
			"nectar": max(2, roundi(rng.randf_range(3, 6) * float(data.nectar_scale))) + extra_nectar,
			"kind": i % 3,
			"phase": rng.randf_range(0, TAU)
		})
	for i in int(data.enemies):
		mosquitoes.append({
			"id": i,
			"position": Vector2(rng.randf_range(540, 940), rng.randf_range(210, 610)),
			"velocity": Vector2.ZERO,
			"stunned": 0.0
		})
	for i in int(data.ants):
		ants.append({
			"id": i,
			"position": Vector2(rng.randf_range(600, 940), rng.randf_range(220, 630)),
			"velocity": Vector2.ZERO,
			"steal_cooldown": 0.0,
			"flee_time": 0.0
		})
	message = "%s：%s" % [data.name, data.line]
	update_interface()
	queue_redraw()

func on_overlay_button() -> void:
	match phase:
		"intro", "won", "lost": start_game()
		"paused": toggle_pause()
		"between":
			if stage_index >= stages.size() - 1:
				start_boss()
			else:
				spawn_stage(stage_index + 1)

func _process(delta: float) -> void:
	elapsed += delta
	shake = maxf(0.0, shake - delta * 18.0)
	flash = maxf(0.0, flash - delta * 2.5)
	if phase == "playing":
		run_elapsed += delta
		update_game(delta)
	elif phase == "boss":
		run_elapsed += delta
		update_boss(delta)
	update_pollen(delta)
	update_interface()
	queue_redraw()

func update_game(delta: float) -> void:
	var data: Dictionary = stages[stage_index]
	sting_cooldown = maxf(0.0, sting_cooldown - delta)
	hit_cooldown = maxf(0.0, hit_cooldown - delta)

	var nearby := nearest_flower(46.0)
	if Input.is_action_pressed("harvest") and nearby >= 0 and bee.energy > 0:
		harvest_clock += delta
		bee.energy = maxf(0.0, bee.energy - balance_value("player", "harvest_energy_per_second", 3.2) * delta)
		if harvest_clock >= balance_value("player", "harvest_interval", 0.42) / harvest_multiplier:
			harvest_clock = 0.0
			var flower: Dictionary = flowers[nearby]
			flower.nectar = int(flower.nectar) - 1
			flowers[nearby] = flower
			carried += 1
			sound.play_cue("harvest")
			spawn_pollen(flower.position)
			message = "花香正在变淡。还要继续停留吗？" if flower.nectar > 0 else "这朵花已经采尽。"
	else:
		harvest_clock = 0.0

	if Input.is_action_just_pressed("sting") and sting_cooldown <= 0.0 and bee.spend_energy(sting_cost):
		sting_cooldown = balance_value("player", "sting_cooldown", 1.15) * sting_cooldown_multiplier
		sound.play_cue("sting")
		for i in mosquitoes.size():
			var mosquito: Dictionary = mosquitoes[i]
			if bee.position.distance_to(mosquito.position) < sting_range:
				mosquito.stunned = 2.1
				mosquito.velocity = (mosquito.position - bee.position).normalized() * 8.0
				mosquitoes[i] = mosquito
		for i in ants.size():
			var ant: Dictionary = ants[i]
			if bee.position.distance_to(ant.position) < sting_range:
				ant.flee_time = 1.8
				ant.velocity = (ant.position - bee.position).normalized() * 3.2
				ants[i] = ant
		message = "蜂针震开了附近的蚊影。"

	update_mosquitoes(delta)
	update_ants(delta)
	if bee.position.x < HIVE_X and carried > 0:
		var amount := carried
		delivered += amount
		carried = 0
		bee.energy = minf(100.0, bee.energy + balance_value("player", "home_energy_restore", 70.0))
		message = "安全归巢，存入 %d 滴蜜。" % amount
		sound.play_cue("home")
		flash = 0.32
		if delivered >= int(data.goal):
			show_between()
	if bee.energy <= 0.0:
		fail_expedition()

func update_mosquitoes(delta: float) -> void:
	for i in mosquitoes.size():
		var mosquito: Dictionary = mosquitoes[i]
		mosquito.stunned = maxf(0.0, float(mosquito.stunned) - delta)
		if mosquito.stunned <= 0.0:
			var distance_to_player := Vector2(mosquito.position).distance_to(bee.position)
			if distance_to_player < balance_value("mosquito", "sense_range", 330.0):
				var chase := (bee.position - Vector2(mosquito.position)).normalized()
				mosquito.velocity = Vector2(mosquito.velocity).lerp(chase * 2.1, delta * 2.8)
			mosquito.position += Vector2(mosquito.velocity) * balance_value("mosquito", "move_speed", 82.0) * delta
			mosquito.position.x = clampf(mosquito.position.x, WORLD.position.x + 12, WORLD.end.x - 12)
			mosquito.position.y = clampf(mosquito.position.y, WORLD.position.y + 12, WORLD.end.y - 12)
			if distance_to_player < balance_value("mosquito", "impact_range", 26.0) and hit_cooldown <= 0.0:
				hit_cooldown = 1.05
				bee.energy = maxf(0.0, bee.energy - balance_value("mosquito", "energy_damage", 15.0))
				carried = maxi(0, carried - roundi(balance_value("mosquito", "honey_damage", 2.0)))
				shake = 7.0
				flash = 0.48
				message = "蚊虫刺中了你：体力下降，花蜜洒落。"
				sound.play_cue("hurt")
		mosquitoes[i] = mosquito

func update_ants(delta: float) -> void:
	for i in ants.size():
		var ant: Dictionary = ants[i]
		ant.steal_cooldown = maxf(0.0, float(ant.steal_cooldown) - delta)
		ant.flee_time = maxf(0.0, float(ant.flee_time) - delta)
		var ant_position: Vector2 = ant.position
		var desired := Vector2.ZERO
		if ant.flee_time > 0.0:
			desired = Vector2(ant.velocity).normalized()
		elif carried > 0:
			desired = (bee.position - ant_position).normalized()
		else:
			var flower_index := nearest_flower_to(ant_position)
			if flower_index >= 0:
				desired = (Vector2(flowers[flower_index].position) - ant_position).normalized()
		ant.velocity = Vector2(ant.velocity).lerp(desired * 1.35, delta * 2.2)
		ant.position += Vector2(ant.velocity) * balance_value("ant", "move_speed", 58.0) * delta
		ant.position.x = clampf(ant.position.x, WORLD.position.x + 14, WORLD.end.x - 14)
		ant.position.y = clampf(ant.position.y, WORLD.position.y + 14, WORLD.end.y - 14)
		if ant.flee_time <= 0.0 and ant_position.distance_to(bee.position) < balance_value("ant", "steal_range", 29.0) and carried > 0 and ant.steal_cooldown <= 0.0:
			carried -= 1
			ant.steal_cooldown = 1.2
			ant.flee_time = balance_value("ant", "flee_seconds", 1.4)
			ant.velocity = (ant_position - bee.position).normalized() * 3.0
			spawn_pollen(ant_position)
			message = "掠蜜蚁夺走了一滴花蜜，正试图逃离。"
			sound.play_cue("hurt")
			shake = 4.0
		ants[i] = ant

func fail_expedition() -> void:
	hive_lives -= 1
	carried = 0
	bee.reset_for_expedition(Vector2(180, 410))
	shake = 10.0
	message = "你没能带回花蜜。蜂巢的呼吸弱了一分。"
	if hive_lives <= 0:
		show_loss()

func show_between() -> void:
	phase = "between"
	bee.active = false
	overlay.visible = true
	var data: Dictionary = stages[stage_index]
	if persistence_enabled:
		save_manager.record_stage(stage_index + 1)
	overlay_title.text = "%s完成 · 蜂巢成长" % data.name
	overlay_body.text = "带回的蜜哺育了新的分工。选择一种蜂群倾向；本轮效果可以叠加。"
	overlay_button.visible = false
	set_upgrade_buttons_visible(true)

func set_upgrade_buttons_visible(value: bool) -> void:
	for i in upgrade_buttons.size():
		upgrade_buttons[i].visible = value
		if value and i < upgrade_catalog.size():
			var data: Dictionary = upgrade_catalog[i]
			upgrade_buttons[i].text = "%s  %s\n\n%s" % [data.symbol, data.name, data.description]
			upgrade_buttons[i].disabled = int(upgrade_counts.get(String(data.id), 0)) >= 2

func on_upgrade_selected(index: int) -> void:
	if phase != "between" or index >= upgrade_catalog.size():
		return
	var data: Dictionary = upgrade_catalog[index]
	var upgrade_id := String(data.id)
	if int(upgrade_counts.get(upgrade_id, 0)) >= 2:
		return
	chosen_upgrades.append(upgrade_id)
	sound.play_cue("upgrade")
	upgrade_counts[upgrade_id] = int(upgrade_counts.get(upgrade_id, 0)) + 1
	match upgrade_id:
		"long_wing": bee.apply_upgrade(upgrade_id)
		"forager":
			harvest_multiplier *= 1.18
			extra_nectar += 1
		"guard":
			sting_range *= 1.18
			sting_cooldown_multiplier *= 0.85
	set_upgrade_buttons_visible(false)
	overlay_button.visible = true
	if stage_index >= stages.size() - 1:
		start_boss()
	else:
		spawn_stage(stage_index + 1)

func start_boss() -> void:
	phase = "boss"
	overlay.visible = false
	overlay_button.visible = true
	set_upgrade_buttons_visible(false)
	flowers.clear()
	mosquitoes.clear()
	ants.clear()
	pollen.clear()
	tuning_blooms = [Vector2(400, 285), Vector2(720, 250), Vector2(650, 550)]
	boss = {"position": Vector2(840, 410), "velocity": Vector2.ZERO, "hits": 0, "hit_cooldown": 0.0}
	bee.configure(1.7)
	bee.reset_for_expedition(Vector2(180, 410))
	carried = 6
	delivered = 0
	message = "失律之蚊在吸取花潮。把它引到三处共鸣花粉，再用蜂针完成调律。"

func update_boss(delta: float) -> void:
	sting_cooldown = maxf(0.0, sting_cooldown - delta)
	boss.hit_cooldown = maxf(0.0, float(boss.hit_cooldown) - delta)
	var boss_position: Vector2 = boss.position
	var to_bee := bee.position - boss_position
	var orbit := to_bee.normalized().rotated(sin(elapsed * 1.7) * 0.45)
	boss.velocity = Vector2(boss.velocity).lerp(orbit * 2.2, delta * 1.7)
	boss.position += Vector2(boss.velocity) * balance_value("boss", "move_speed", 78.0) * delta
	boss.position.x = clampf(boss.position.x, WORLD.position.x + 28, WORLD.end.x - 28)
	boss.position.y = clampf(boss.position.y, WORLD.position.y + 28, WORLD.end.y - 28)

	if boss_position.distance_to(bee.position) < balance_value("boss", "impact_range", 39.0) and boss.hit_cooldown <= 0.0:
		boss.hit_cooldown = 1.0
		bee.energy = maxf(0.0, bee.energy - balance_value("boss", "energy_damage", 18.0))
		carried = maxi(0, carried - 1)
		shake = 9.0
		sound.play_cue("hurt")
		flash = 0.55
		message = "失律之蚊夺走一滴蜜。它只知道索取。"

	if Input.is_action_just_pressed("sting") and sting_cooldown <= 0.0 and bee.spend_energy(sting_cost):
		sting_cooldown = balance_value("player", "sting_cooldown", 1.15) * sting_cooldown_multiplier
		sound.play_cue("sting")
		var bloom_index := nearest_tuning_bloom(boss.position)
		if bee.position.distance_to(boss.position) < sting_range + 7.0 and bloom_index >= 0:
			var bloom_position := tuning_blooms[bloom_index]
			tuning_blooms.remove_at(bloom_index)
			boss.hits = int(boss.hits) + 1
			boss.velocity = (boss.position - bee.position).normalized() * 8.0
			spawn_pollen(bloom_position)
			shake = 7.0
			message = "共鸣完成：%d / 3。被夺走的蜜重新开始流动。" % int(boss.hits)
			sound.play_cue("tune")
			if int(boss.hits) >= roundi(balance_value("boss", "required_tunings", 3.0)):
				show_win()
		else:
			message = "蜂针击中了它，却没有花粉共鸣。把它引向发光花团。"

	if bee.energy <= 0.0:
		show_loss()

func nearest_tuning_bloom(origin: Vector2) -> int:
	for i in tuning_blooms.size():
		if origin.distance_to(tuning_blooms[i]) < balance_value("boss", "tuning_radius", 82.0):
			return i
	return -1

func show_win() -> void:
	phase = "won"
	bee.active = false
	overlay.visible = true
	overlay_button.visible = true
	set_upgrade_buttons_visible(false)
	if persistence_enabled:
		save_manager.record_completion(run_elapsed)
	sound.play_cue("win")
	overlay_title.text = "冬至一阳生"
	overlay_body.text = "蜂群熬过了四个压缩节令。\n本轮主动游玩时间：%s\n未来，它们之间将展开为完整的二十四个小关卡。" % format_duration(run_elapsed)
	overlay_button.text = "再走一次四季"

func show_loss() -> void:
	phase = "lost"
	bee.active = false
	overlay.visible = true
	overlay_button.visible = true
	set_upgrade_buttons_visible(false)
	sound.play_cue("loss")
	if persistence_enabled:
		save_manager.record_failure(run_elapsed)
	overlay_title.text = "这一次没能\n等到春天"
	overlay_body.text = "远花仍在那里，但带回家的蜜才真正属于蜂群。\n本轮主动游玩时间：%s" % format_duration(run_elapsed)
	overlay_button.text = "重新出巢"

func nearest_flower(radius: float) -> int:
	var best := -1
	var best_distance := radius
	for i in flowers.size():
		var flower: Dictionary = flowers[i]
		if int(flower.nectar) <= 0:
			continue
		var current := bee.position.distance_to(flower.position)
		if current < best_distance:
			best = i
			best_distance = current
	return best

func nearest_flower_to(origin: Vector2) -> int:
	var best := -1
	var best_distance := INF
	for i in flowers.size():
		var flower: Dictionary = flowers[i]
		if int(flower.nectar) <= 0:
			continue
		var current := origin.distance_to(flower.position)
		if current < best_distance:
			best = i
			best_distance = current
	return best

func spawn_pollen(origin: Vector2) -> void:
	for i in 6:
		pollen.append({"position": origin, "velocity": Vector2.from_angle(rng.randf_range(0, TAU)) * rng.randf_range(20, 65), "life": rng.randf_range(0.35, 0.7)})

func update_pollen(delta: float) -> void:
	for i in range(pollen.size() - 1, -1, -1):
		var mote: Dictionary = pollen[i]
		mote.life = float(mote.life) - delta
		mote.position += Vector2(mote.velocity) * delta
		mote.velocity = Vector2(mote.velocity) * 0.96
		if mote.life <= 0:
			pollen.remove_at(i)
		else:
			pollen[i] = mote

func update_interface() -> void:
	if stages.is_empty():
		return
	var data: Dictionary = stages[stage_index]
	term_label.text = "%s · %s" % [data.season, data.name]
	carried_label.text = str(carried)
	delivered_label.text = "调律 %d / 3" % int(boss.hits) if phase == "boss" else "%d / %d" % [delivered, int(data.goal)]
	energy_label.text = str(roundi(bee.energy))
	hive_label.text = "●".repeat(maxi(0, hive_lives)) + "○".repeat(maxi(0, 3 - hive_lives))
	message_label.text = message
	if phase == "boss":
		detail_label.text = "失律之蚊\n\n只索取，\n不流转。\n\n调律  %d / 3\n\n引向花粉团\n再使用蜂针" % int(boss.hits)
	else:
		detail_label.text = "%s\n\n%s\n\n阴 %d  ·  阳 %d\n目标  %d 滴\n蚊群  %s\n掠蜜蚁  %s" % [data.name, data.line, int(data.yin), int(data.yang), int(data.goal), "◆".repeat(int(data.enemies)), "◆".repeat(int(data.ants))]

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		toggle_pause()
		get_viewport().set_input_as_handled()
		return
	if phase != "playing" and phase != "boss":
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if WORLD.has_point(event.position):
			bee.set_move_target(event.position)

func on_sense_started() -> void:
	message = "花香、敌意与归巢方向在一瞬间变得清晰。"

func toggle_pause() -> void:
	if phase == "paused":
		phase = paused_from_phase
		bee.active = true
		overlay.visible = false
		pause_button.text = "暂停"
		return
	if phase != "playing" and phase != "boss":
		return
	paused_from_phase = phase
	phase = "paused"
	bee.active = false
	overlay.visible = true
	set_upgrade_buttons_visible(false)
	overlay_title.text = "蜂翼暂歇"
	overlay_body.text = "当前进度已自动保存。\n按 Esc 或下方按钮继续。"
	overlay_button.visible = true
	overlay_button.text = "继续出巢"
	pause_button.text = "继续"

func toggle_fullscreen() -> void:
	save_manager.fullscreen = not save_manager.fullscreen
	save_manager.save_data()
	apply_display_settings()
	refresh_setting_labels()

func toggle_sound() -> void:
	save_manager.sound_enabled = not save_manager.sound_enabled
	save_manager.save_data()
	sound.set_enabled(save_manager.sound_enabled)
	refresh_setting_labels()

func apply_display_settings() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if save_manager.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)

func refresh_setting_labels() -> void:
	if fullscreen_button:
		fullscreen_button.text = "窗口化" if save_manager.fullscreen else "全屏"
	if sound_button:
		sound_button.text = "声音：开" if save_manager.sound_enabled else "声音：关"

func progress_name() -> String:
	if save_manager.best_stage >= 5:
		return "四季已归律"
	if save_manager.best_stage <= 0 or stages.is_empty():
		return "尚未出巢"
	return String(stages[mini(save_manager.best_stage - 1, stages.size() - 1)].name)

func last_run_text() -> String:
	if save_manager.last_run_seconds <= 0.0:
		return ""
	return "  ·  上轮 %s" % format_duration(save_manager.last_run_seconds)

func format_duration(duration_seconds: float) -> String:
	var minutes := floori(duration_seconds / 60.0)
	var seconds := floori(fmod(duration_seconds, 60.0))
	return "%d:%02d" % [minutes, seconds]

func stage_color(index: int) -> Color:
	if stages.is_empty():
		return Color("d9e8c2")
	var colors: Array = stages[stage_index].colors
	return Color(colors[index])

func _draw() -> void:
	if stages.is_empty():
		return
	var offset := Vector2(rng.randf_range(-shake, shake), rng.randf_range(-shake, shake)) if shake > 0 else Vector2.ZERO
	draw_set_transform(offset)
	var top := stage_color(0)
	var bottom := stage_color(1)
	draw_rect(WORLD, top)
	for band in 18:
		var ratio := float(band) / 17.0
		var band_rect := Rect2(WORLD.position.x, WORLD.position.y + WORLD.size.y * ratio, WORLD.size.x, WORLD.size.y / 17.0 + 1)
		draw_rect(band_rect, top.lerp(bottom, ratio * 0.68))

	draw_rect(Rect2(WORLD.position.x, WORLD.position.y, 108, WORLD.size.y), Color("26392f", 0.88))
	for y in range(178, 664, 42):
		draw_circle(Vector2(86, y), 17, Color("e5bd4a", 0.08), false, 2)
	draw_string(ThemeDB.fallback_font, Vector2(58, 176), "蜂 巢", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("fff1bd"))
	draw_string(ThemeDB.fallback_font, Vector2(57, 661), "撤 离 区", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("d8d4b8"))

	var deep := stage_color(2)
	for i in 34:
		var x := WORLD.position.x + fmod(float(i * 97 + stage_index * 31), WORLD.size.x)
		var y := 570.0 + sin(float(i) * 2.1) * 60.0
		draw_line(Vector2(x, WORLD.end.y), Vector2(x + 10, y), Color(deep, 0.2), 3)

	for flower in flowers:
		draw_flower(flower)
	for mosquito in mosquitoes:
		draw_mosquito(mosquito)
	for ant in ants:
		draw_ant(ant)
	if phase == "boss":
		for bloom in tuning_blooms:
			draw_tuning_bloom(bloom)
		draw_boss(boss)
	for mote in pollen:
		draw_circle(mote.position, 2.5, Color(stage_color(3), clampf(float(mote.life) * 2.0, 0, 1)))
	if bee.sense_time > 0.0 and (phase == "playing" or phase == "boss"):
		for flower in flowers:
			if int(flower.nectar) > 0:
				draw_line(bee.position, flower.position, Color(stage_color(3), 0.12), 1)
		for mosquito in mosquitoes:
			draw_circle(mosquito.position, 20, Color("8d3d36", 0.12), false, 2)
		for ant in ants:
			draw_circle(ant.position, 20, Color("6b412d", 0.12), false, 2)
		if phase == "boss":
			draw_circle(boss.position, 50, Color("8d3d36", 0.16), false, 3)
		draw_line(bee.position, Vector2(HIVE_X, bee.position.y), Color("fff0a0", 0.42), 2)

	var nearby := nearest_flower(46.0)
	if nearby >= 0 and phase == "playing":
		var flower: Dictionary = flowers[nearby]
		draw_arc(flower.position, 32 + sin(elapsed * 6.0) * 3, 0, TAU, 28, stage_color(3), 2)
		draw_string(ThemeDB.fallback_font, flower.position + Vector2(-30, -42), "按住空格采蜜", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, deep)
	if flash > 0:
		draw_rect(WORLD, Color("fff1b0", flash * 0.25))
	draw_set_transform(Vector2.ZERO)

func draw_flower(flower: Dictionary) -> void:
	var pos: Vector2 = flower.position
	var alive := int(flower.nectar) > 0
	var alpha := 1.0 if alive else 0.28
	draw_line(pos + Vector2(0, 16), pos + Vector2(0, 45), Color(stage_color(2), alpha), 3)
	for petal in 5:
		var angle := float(petal) * TAU / 5.0 + float(flower.phase)
		draw_circle(pos + Vector2.from_angle(angle) * 11, 7, Color(FLOWER_COLORS[int(flower.kind)], alpha))
	draw_circle(pos, 6, Color(stage_color(3), alpha))
	if not alive:
		draw_line(pos + Vector2(-14, 49), pos + Vector2(14, 49), Color(stage_color(2), 0.45), 2)

func draw_mosquito(mosquito: Dictionary) -> void:
	var pos: Vector2 = mosquito.position
	var stunned := float(mosquito.stunned) > 0
	draw_circle(pos, 9, Color("78908b") if stunned else Color("402e34"))
	draw_line(pos + Vector2(-5, -4), pos + Vector2(-15, -12), Color("f5f2df", 0.7), 3)
	draw_line(pos + Vector2(5, 4), pos + Vector2(15, 12), Color("f5f2df", 0.7), 3)
	if stunned:
		draw_arc(pos, 17, 0, TAU * 0.75, 12, Color("fff0aa"), 2)

func draw_ant(ant: Dictionary) -> void:
	var pos: Vector2 = ant.position
	var fleeing := float(ant.flee_time) > 0.0
	var color := Color("a66d38") if fleeing else Color("5a382a")
	draw_circle(pos + Vector2(-7, 0), 6, color)
	draw_circle(pos + Vector2(2, 0), 7, color)
	draw_circle(pos + Vector2(11, 0), 5, color)
	for side in [-1, 1]:
		draw_line(pos + Vector2(-2, 2 * side), pos + Vector2(-11, 10 * side), color, 2)
		draw_line(pos + Vector2(5, 2 * side), pos + Vector2(13, 10 * side), color, 2)

func draw_tuning_bloom(pos: Vector2) -> void:
	var pulse := 28.0 + sin(elapsed * 4.0) * 4.0
	draw_circle(pos, 18, Color(stage_color(3), 0.24))
	draw_arc(pos, pulse, 0, TAU, 32, Color("fff0a0", 0.75), 3)
	for i in 8:
		var angle := float(i) * TAU / 8.0 + elapsed * 0.25
		draw_circle(pos + Vector2.from_angle(angle) * pulse, 3, Color("fff4bd", 0.85))

func draw_boss(data: Dictionary) -> void:
	var pos: Vector2 = data.position
	var radius := 24.0 + sin(elapsed * 5.0) * 2.0
	draw_circle(pos, radius, Color("35242d"))
	draw_circle(pos + Vector2(20, 0), 11, Color("704044"))
	draw_line(pos + Vector2(28, 0), pos + Vector2(47, -2), Color("2e2327"), 4)
	draw_arc(pos, radius + 9, -2.4, 2.4, 22, Color("d7b56a", 0.55), 3)
	for i in int(data.hits):
		draw_circle(pos + Vector2(-12 + i * 12, -34), 4, Color("f5d975"))
