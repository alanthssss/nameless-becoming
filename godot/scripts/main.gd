extends Node2D

const WORLD := Rect2(34, 146, 970, 538)
const HIVE_X := 132.0
const FLOWER_COLORS := [Color("f2d66f"), Color("e9aab1"), Color("a995c9")]
const TERMS := ["立春", "雨水", "惊蛰", "春分", "清明", "谷雨", "立夏", "小满", "芒种", "夏至", "小暑", "大暑", "立秋", "处暑", "白露", "秋分", "寒露", "霜降", "立冬", "小雪", "大雪", "冬至", "小寒", "大寒"]

var stages: Array = []
var stage_index := 0
var phase := "intro"
var player := Vector2(180, 410)
var target := Vector2.ZERO
var has_target := false
var flowers: Array = []
var mosquitoes: Array = []
var pollen: Array = []
var carried := 0
var delivered := 0
var energy := 100.0
var hive_lives := 3
var harvest_clock := 0.0
var sting_cooldown := 0.0
var hit_cooldown := 0.0
var elapsed := 0.0
var shake := 0.0
var flash := 0.0
var message := "飞向花朵，采蜜后亲自返回左侧蜂巢。"
var rng := RandomNumberGenerator.new()

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

func _ready() -> void:
	rng.randomize()
	load_stage_data()
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

	var restart := Button.new()
	restart.text = "重新开始"
	restart.position = Vector2(1140, 22)
	restart.size = Vector2(110, 36)
	restart.pressed.connect(start_game)
	ui.add_child(restart)

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
	make_label(side, "搜  寻找仍有蜜的花\n打  蜂针震开蚊虫\n撤  飞回左侧蜂巢", Vector2(20, 445), Vector2(190, 80), 12, Color("556054"))

	var tips := make_label(ui, "WASD / 方向键  飞行     空格  采蜜     Shift  振翅     J  蜂针", Vector2(34, 690), Vector2(970, 24), 12, Color("f7f0d5"))
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

func show_intro() -> void:
	phase = "intro"
	overlay.visible = true
	overlay_title.text = "再采一朵，\n还是现在归巢？"
	overlay_body.text = "控制蜜蜂飞向花朵，按住空格采蜜。\n体力耗尽前，带着花蜜返回左侧蜂巢。"
	overlay_button.text = "飞入春分"

func start_game() -> void:
	hive_lives = 3
	stage_index = 0
	spawn_stage(0)

func spawn_stage(index: int) -> void:
	if stages.is_empty():
		return
	stage_index = index
	phase = "playing"
	overlay.visible = false
	player = Vector2(180, 410)
	has_target = false
	carried = 0
	delivered = 0
	energy = 100.0
	harvest_clock = 0.0
	sting_cooldown = 0.0
	hit_cooldown = 0.0
	flowers.clear()
	mosquitoes.clear()
	pollen.clear()
	var data: Dictionary = stages[index]
	for i in int(data.flowers):
		flowers.append({
			"id": i,
			"position": Vector2(rng.randf_range(300, 950), rng.randf_range(205, 620)),
			"nectar": max(2, roundi(rng.randf_range(3, 6) * float(data.nectar_scale))),
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
	message = "%s：%s" % [data.name, data.line]
	update_interface()
	queue_redraw()

func on_overlay_button() -> void:
	match phase:
		"intro", "won", "lost": start_game()
		"between":
			if stage_index >= stages.size() - 1:
				show_win()
			else:
				spawn_stage(stage_index + 1)

func _process(delta: float) -> void:
	elapsed += delta
	shake = maxf(0.0, shake - delta * 18.0)
	flash = maxf(0.0, flash - delta * 2.5)
	if phase == "playing":
		update_game(delta)
	update_pollen(delta)
	update_interface()
	queue_redraw()

func update_game(delta: float) -> void:
	var data: Dictionary = stages[stage_index]
	sting_cooldown = maxf(0.0, sting_cooldown - delta)
	hit_cooldown = maxf(0.0, hit_cooldown - delta)
	var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if direction.length_squared() < 0.01 and has_target:
		var to_target := target - player
		if to_target.length() > 8:
			direction = to_target.normalized()
		else:
			has_target = false
	var dashing := Input.is_action_pressed("dash") and energy > 8.0
	var speed := 360.0 if dashing else 215.0
	player += direction * speed * delta
	player.x = clampf(player.x, WORLD.position.x + 18, WORLD.end.x - 18)
	player.y = clampf(player.y, WORLD.position.y + 18, WORLD.end.y - 18)
	energy = maxf(0.0, energy - float(data.energy_drain) * delta - (9.5 * delta if dashing else 0.0))

	var nearby := nearest_flower(46.0)
	if Input.is_action_pressed("harvest") and nearby >= 0 and energy > 0:
		harvest_clock += delta
		energy = maxf(0.0, energy - 3.2 * delta)
		if harvest_clock >= 0.42:
			harvest_clock = 0.0
			var flower: Dictionary = flowers[nearby]
			flower.nectar = int(flower.nectar) - 1
			flowers[nearby] = flower
			carried += 1
			spawn_pollen(flower.position)
			message = "花香正在变淡。还要继续停留吗？" if flower.nectar > 0 else "这朵花已经采尽。"
	else:
		harvest_clock = 0.0

	if Input.is_action_just_pressed("sting") and sting_cooldown <= 0.0 and energy >= 8.0:
		sting_cooldown = 1.15
		energy -= 8.0
		for i in mosquitoes.size():
			var mosquito: Dictionary = mosquitoes[i]
			if player.distance_to(mosquito.position) < 88:
				mosquito.stunned = 2.1
				mosquito.velocity = (mosquito.position - player).normalized() * 8.0
				mosquitoes[i] = mosquito
		message = "蜂针震开了附近的蚊影。"

	update_mosquitoes(delta)
	if player.x < HIVE_X and carried > 0:
		var amount := carried
		delivered += amount
		carried = 0
		energy = 100.0
		message = "安全归巢，存入 %d 滴蜜。" % amount
		flash = 0.32
		if delivered >= int(data.goal):
			show_between()
	if energy <= 0.0:
		fail_expedition()

func update_mosquitoes(delta: float) -> void:
	for i in mosquitoes.size():
		var mosquito: Dictionary = mosquitoes[i]
		mosquito.stunned = maxf(0.0, float(mosquito.stunned) - delta)
		if mosquito.stunned <= 0.0:
			var distance_to_player := Vector2(mosquito.position).distance_to(player)
			if distance_to_player < 330:
				var chase := (player - Vector2(mosquito.position)).normalized()
				mosquito.velocity = Vector2(mosquito.velocity).lerp(chase * 2.1, delta * 2.8)
			mosquito.position += Vector2(mosquito.velocity) * 82.0 * delta
			mosquito.position.x = clampf(mosquito.position.x, WORLD.position.x + 12, WORLD.end.x - 12)
			mosquito.position.y = clampf(mosquito.position.y, WORLD.position.y + 12, WORLD.end.y - 12)
			if distance_to_player < 26 and hit_cooldown <= 0.0:
				hit_cooldown = 1.05
				energy = maxf(0.0, energy - 15.0)
				carried = maxi(0, carried - 2)
				shake = 7.0
				flash = 0.48
				message = "蚊虫刺中了你：体力下降，花蜜洒落。"
		mosquitoes[i] = mosquito

func fail_expedition() -> void:
	hive_lives -= 1
	carried = 0
	energy = 100.0
	player = Vector2(180, 410)
	has_target = false
	shake = 10.0
	message = "你没能带回花蜜。蜂巢的呼吸弱了一分。"
	if hive_lives <= 0:
		show_loss()

func show_between() -> void:
	phase = "between"
	overlay.visible = true
	var data: Dictionary = stages[stage_index]
	overlay_title.text = "%s完成" % data.name
	overlay_body.text = "%s\n\n你已为蜂巢带回足够的蜜。阴阳推移，下一节令正在靠近。" % data.line
	overlay_button.text = "等待来年" if stage_index >= stages.size() - 1 else "进入下一节令"

func show_win() -> void:
	phase = "won"
	overlay.visible = true
	overlay_title.text = "冬至一阳生"
	overlay_body.text = "蜂群熬过了四个压缩节令。\n未来，它们之间将展开为完整的二十四个小关卡。"
	overlay_button.text = "再走一次四季"

func show_loss() -> void:
	phase = "lost"
	overlay.visible = true
	overlay_title.text = "这一次没能\n等到春天"
	overlay_body.text = "远花仍在那里，但带回家的蜜才真正属于蜂群。"
	overlay_button.text = "重新出巢"

func nearest_flower(radius: float) -> int:
	var best := -1
	var best_distance := radius
	for i in flowers.size():
		var flower: Dictionary = flowers[i]
		if int(flower.nectar) <= 0:
			continue
		var current := player.distance_to(flower.position)
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
	delivered_label.text = "%d / %d" % [delivered, int(data.goal)]
	energy_label.text = str(roundi(energy))
	hive_label.text = "●".repeat(maxi(0, hive_lives)) + "○".repeat(maxi(0, 3 - hive_lives))
	message_label.text = message
	detail_label.text = "%s\n\n%s\n\n阴 %d  ·  阳 %d\n目标  %d 滴\n蚊群  %s" % [data.name, data.line, int(data.yin), int(data.yang), int(data.goal), "◆".repeat(int(data.enemies))]

func _unhandled_input(event: InputEvent) -> void:
	if phase != "playing":
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if WORLD.has_point(event.position):
			target = event.position
			has_target = true

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
	for mote in pollen:
		draw_circle(mote.position, 2.5, Color(stage_color(3), clampf(float(mote.life) * 2.0, 0, 1)))
	draw_bee(player)

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

func draw_bee(pos: Vector2) -> void:
	draw_circle(pos + Vector2(-5, -10), 8, Color("f7f5dd", 0.65))
	draw_circle(pos + Vector2(-5, 10), 8, Color("f7f5dd", 0.65))
	draw_circle(pos, 13, Color("292921"))
	draw_rect(Rect2(pos + Vector2(-7, -12), Vector2(5, 24)), Color("e1aa2c"))
	draw_rect(Rect2(pos + Vector2(3, -11), Vector2(5, 22)), Color("e1aa2c"))
	draw_circle(pos + Vector2(13, 0), 7, Color("efcf69"))
	if sting_cooldown > 0:
		draw_arc(pos, 27, -PI * 0.7, PI * 0.7, 18, Color("e8c452", 0.55), 2)
