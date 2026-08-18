extends Node2D

const WORLD := Rect2(34, 146, 970, 538)
const HIVE_X := 132.0
const HIVE_SAFE_X := 225.0
const FLOWER_COLORS := [Color("f2d66f"), Color("e9aab1"), Color("a995c9")]
const TERMS := ["立春", "雨水", "惊蛰", "春分", "清明", "谷雨", "立夏", "小满", "芒种", "夏至", "小暑", "大暑", "立秋", "处暑", "白露", "秋分", "寒露", "霜降", "立冬", "小雪", "大雪", "冬至", "小寒", "大寒"]
const SEASON_LENGTH := 6
const UPGRADE_CAP := 6
const SeasonMechanicsScript := preload("res://scripts/mechanics/season_mechanics.gd")

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
var crickets: Array = []
var thrushes: Array = []
var bears: Array = []
var phantom_flowers: Array = []
var field_afterimages: Array = []
var tuning_blooms: Array[Vector2] = []
var boss := {"position": Vector2.ZERO, "velocity": Vector2.ZERO, "hits": 0, "hit_cooldown": 0.0}
var pollen: Array = []
var decoys: Array = []
var recovery_flower_serial := 1000
var carried := 0
var delivered := 0
var hive_lives := 3
var harvest_clock := 0.0
var sting_cooldown := 0.0
var hit_cooldown := 0.0
var was_in_hive := false
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
var action_hold_time := 0.0
var action_decoy_fired := false
var last_dir_tap := {"left": 0.0, "right": 0.0, "up": 0.0, "down": 0.0}
const DOUBLE_TAP_WINDOW := 0.25
const DECOY_HOLD_THRESHOLD := 0.5
const HIVE_RETURN_POS := Vector2(180, 410)
var rng := RandomNumberGenerator.new()
var save_manager := NamelessSaveManager.new()
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
var overlay_history: Label
var upgrade_buttons: Array[Button] = []
var zh_font: Font
var pause_button: Button
var fullscreen_button: Button
var sound_button: Button
var sense_button: Button
var energy_bar: ColorRect
var energy_bar_fill: ColorRect
var season_label: Label
var season_rule: ColorRect
var energy_change_label: Label
var energy_feedback_time := 0.0
var reserve_label: Label
var season_mechanics
var hive_reserve := 0
var larval_boost := 0
var warmth := 100.0
var energy_cap_override := 100.0
var cold_warmth_threshold := 15.0
var allocation_panel: Control
var allocation_body_label: Label
var allocation_left_label: Label
var allocation_right_label: Label
var allocation_slider: HSlider
var allocation_pending := false
var allocation_harvest := 0
var allocation_fraction := 0.5
var boss_catalog: Array = []
var current_boss_data: Dictionary = {}
var current_boss_index := 0
var boss_afterimages: Array = []
var preserve_warmth := false

func _ready() -> void:
	zh_font = load("res://fonts/hivebound_font.ttf")
	if zh_font == null:
		push_warning("无法加载中文字体，将使用回退字体")
	rng.randomize()
	ensure_keyboard_controls()
	save_manager.load_data()
	apply_display_settings()
	load_stage_data()
	load_balance_data()
	load_upgrade_data()
	load_boss_data()
	bee = BeePlayer.new()
	bee.position = Vector2(180, 410)
	bee.sense_started.connect(on_sense_started)
	add_child(bee)
	add_child(sound)
	sound.set_enabled(save_manager.sound_enabled)
	build_interface()
	season_mechanics = SeasonMechanicsScript.new()
	season_mechanics.configure(self)
	add_child(season_mechanics)
	show_intro()
	queue_redraw()

func ensure_keyboard_controls() -> void:
	var bindings := {
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"move_up": [KEY_W, KEY_UP],
		"move_down": [KEY_S, KEY_DOWN],
		"action": [KEY_SPACE, KEY_ENTER],
		"return_hive": [KEY_Q]
	}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for keycode in bindings[action]:
			var exists := false
			for current_event in InputMap.action_get_events(action):
				if current_event is InputEventKey and current_event.physical_keycode == keycode:
					exists = true
					break
			if not exists:
				var key_event := InputEventKey.new()
				key_event.physical_keycode = keycode
				InputMap.action_add_event(action, key_event)

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

func load_boss_data() -> void:
	var file := FileAccess.open("res://data/bosses.json", FileAccess.READ)
	if file == null:
		push_error("无法读取失律者数据")
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Array:
		boss_catalog = parsed
	else:
		push_error("失律者数据格式错误")

# 游戏季（0-3）：每 6 个节令为一季，难度与机制按此分派
func season_index_of(index: int) -> int:
	return clampi(index / SEASON_LENGTH, 0, 3)

# 正色节点（春分/夏至/秋分）本身是失律者关卡；冬至由循环终点（大雪之后）的熊守卫
func is_boss_stage(index: int) -> bool:
	return index >= 0 and index < stages.size() and stages[index].has("boss")

# 按节点查失律者数据：boss 关用 stages[index].boss，循环终点默认回到失律之熊
func boss_data_for_stage(index: int) -> Dictionary:
	var boss_id := "bear"
	if is_boss_stage(index):
		boss_id = String(stages[index].boss)
	for entry in boss_catalog:
		if String(entry.get("id", "")) == boss_id:
			return entry
	return {}

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
	if zh_font != null:
		label.add_theme_font_override("font", zh_font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func build_interface() -> void:
	var ui := CanvasLayer.new()
	ui.name = "Interface"
	add_child(ui)

	title_label = make_label(ui, "◆  无名：成蜂", Vector2(34, 17), Vector2(350, 42), 24, Color("26342b"))
	make_label(ui, "NAMELESS: BECOMING · GODOT VERTICAL SLICE", Vector2(67, 48), Vector2(370, 20), 10, Color("566257"))
	term_label = make_label(ui, "冬 · 冬至", Vector2(520, 16), Vector2(240, 52), 25, Color("26342b"))
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
	energy_bar = ColorRect.new()
	energy_bar.position = Vector2(12, 35)
	energy_bar.size = Vector2(166, 6)
	energy_bar.color = Color("33483d")
	energy_label.get_parent().add_child(energy_bar)
	energy_bar_fill = ColorRect.new()
	energy_bar_fill.size = Vector2(166, 6)
	energy_bar_fill.color = Color("ddb84c")
	energy_bar.add_child(energy_bar_fill)
	energy_change_label = make_label(energy_label.get_parent(), "", Vector2(50, 4), Vector2(48, 24), 12, Color("b34b3f"))
	energy_change_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hive_label = make_stat(ui, "蜂巢呼吸", Vector2(634, 82))
	reserve_label = make_stat(ui, "公共储备", Vector2(824, 82))

	var side := ColorRect.new()
	side.color = Color("f3eedb", 0.94)
	side.position = Vector2(1020, 146)
	side.size = Vector2(230, 538)
	ui.add_child(side)
	make_label(side, "当前节令", Vector2(20, 18), Vector2(190, 18), 10, Color("68705d"))
	season_label = make_label(side, "冬至", Vector2(20, 38), Vector2(190, 38), 24, Color("1f2c24"))
	# 节令名下的细分隔条：用 4px 高的色块代替“空行造成的虚假分隔”，视觉上更稳重
	season_rule = ColorRect.new()
	season_rule.color = Color("c8a86b", 0.7)
	season_rule.position = Vector2(20, 84)
	season_rule.size = Vector2(36, 2)
	side.add_child(season_rule)
	detail_label = make_label(side, "·", Vector2(20, 96), Vector2(190, 84), 13, Color("3a4a3e"))
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label = make_label(side, message, Vector2(20, 250), Vector2(190, 88), 13, Color("4c5548"))
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# 提示消息下方用一根更细的线把「输入层」和「行动层」分开
	var input_rule := ColorRect.new()
	input_rule.color = Color("c7c0a4", 0.6)
	input_rule.position = Vector2(20, 348)
	input_rule.size = Vector2(190, 1)
	side.add_child(input_rule)
	make_label(side, "左键点地移动 · 左侧是安全蜂巢", Vector2(20, 360), Vector2(190, 28), 11, Color("556054"))
	# 情境动作按钮：近花=采蜜 / 近敌=惊退 / 静止=寻迹 / 长按携蜜=诱饵
	sense_button = make_mouse_action(side, "动作", "action", Vector2(14, 402), true, Vector2(135, 36))
	make_mouse_action(side, "归巢", "return_hive", Vector2(155, 402), false, Vector2(62, 36))
	make_label(side, "近花采蜜 · 近敌惊退 · 静止寻迹", Vector2(14, 447), Vector2(200, 18), 10, Color("68705d"))
	make_label(side, "长按携蜜=投诱饵 · 双击方向=急转", Vector2(14, 465), Vector2(200, 18), 10, Color("68705d"))
	make_label(side, "持续飞行=自动振翅加速", Vector2(14, 483), Vector2(200, 18), 10, Color("68705d"))

	var tips_background := ColorRect.new()
	tips_background.color = Color("26392f", 0.96)
	tips_background.position = Vector2(34, 684)
	tips_background.size = Vector2(970, 36)
	ui.add_child(tips_background)
	var tips := make_label(ui, "WASD 飞行（持续飞=振翅加速） ｜ 空格 动作（近花采/近敌退/静止寻/长按诱饵） ｜ Q 归巢 ｜ 双击方向 急转", Vector2(34, 691), Vector2(970, 22), 12, Color("f7f0d5"))
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
	overlay_button.text = "飞入冬至"
	overlay_button.position = Vector2(374, 345)
	overlay_button.size = Vector2(220, 54)
	overlay_button.add_theme_font_size_override("font_size", 18)
	overlay_button.pressed.connect(on_overlay_button)
	overlay.add_child(overlay_button)
	overlay_history = make_label(overlay, "", Vector2(190, 415), Vector2(590, 28), 14, Color("9fb1a3"))
	overlay_history.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_history.visible = false
	for i in 3:
		var choice := Button.new()
		choice.position = Vector2(105 + i * 255, 330)
		choice.size = Vector2(235, 125)
		choice.add_theme_font_size_override("font_size", 16)
		choice.pressed.connect(on_upgrade_selected.bind(i))
		choice.visible = false
		overlay.add_child(choice)
		upgrade_buttons.append(choice)

	allocation_panel = Control.new()
	allocation_panel.position = Vector2(150, 70)
	allocation_panel.size = Vector2(670, 400)
	allocation_panel.visible = false
	overlay.add_child(allocation_panel)
	var allocation_bg := ColorRect.new()
	allocation_bg.color = Color("16281f", 0.97)
	allocation_bg.size = allocation_panel.size
	allocation_panel.add_child(allocation_bg)
	var allocation_title := make_label(allocation_panel, "秋分 · 为来年投资", Vector2(0, 26), Vector2(670, 44), 28, Color("fff8d9"))
	allocation_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	allocation_body_label = make_label(allocation_panel, "", Vector2(60, 96), Vector2(550, 66), 15, Color("d8ddc9"))
	allocation_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	allocation_left_label = make_label(allocation_panel, "", Vector2(60, 176), Vector2(190, 30), 17, Color("f4d893"))
	allocation_right_label = make_label(allocation_panel, "", Vector2(420, 176), Vector2(190, 30), 17, Color("d8ddc9"))
	allocation_right_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	allocation_slider = HSlider.new()
	allocation_slider.position = Vector2(100, 224)
	allocation_slider.size = Vector2(470, 28)
	allocation_slider.min_value = 0.0
	allocation_slider.max_value = 100.0
	allocation_slider.step = 25.0
	allocation_slider.value = 50.0
	allocation_slider.value_changed.connect(func(v: float): allocation_fraction = v / 100.0; refresh_allocation_labels())
	allocation_panel.add_child(allocation_slider)
	var allocation_confirm := Button.new()
	allocation_confirm.text = "确认分配"
	allocation_confirm.position = Vector2(255, 296)
	allocation_confirm.size = Vector2(160, 52)
	allocation_confirm.add_theme_font_size_override("font_size", 17)
	allocation_confirm.pressed.connect(confirm_allocation)
	allocation_panel.add_child(allocation_confirm)
	make_label(allocation_panel, "向左为越冬留足储备，向右为来年哺育更多幼虫。没有对错，只有不同的活法。", Vector2(90, 368), Vector2(490, 24), 11, Color("aab5a0")).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	make_label(overlay, "四季搜打撤 · 核心交互测试", Vector2(300, 38), Vector2(370, 25), 12, Color("dfbd54")).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	if zh_font != null:
		for node in ui.find_children("*", "Button", true):
			if node is Button:
				node.add_theme_font_override("font", zh_font)

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

func make_mouse_action(parent: Node, caption: String, action: String, position: Vector2, hold: bool, button_size := Vector2(96, 36)) -> Button:
	var button := Button.new()
	button.text = caption
	button.position = position
	button.size = button_size
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
	overlay_body.text = "WASD 飞向花朵，空格采蜜。\n近花=采蜜 · 近敌=惊退 · 静止=寻迹\n长按携蜜=投诱饵 · 双击方向=急转 · Q=归巢"
	overlay_history.text = "历史最远：%s  ·  完成轮回：%d%s" % [progress_name(), save_manager.runs_completed, last_run_text()]
	overlay_button.text = "飞入冬至"
	set_upgrade_buttons_visible(false)
	overlay_button.visible = true
	overlay_history.visible = true

func start_game() -> void:
	hive_lives = 3
	stage_index = 0
	run_elapsed = 0.0
	chosen_upgrades.clear()
	upgrade_counts = {"long_wing": 0, "forager": 0, "guard": 0}
	current_boss_index = 0
	current_boss_data = {}
	boss_afterimages.clear()
	preserve_warmth = false
	harvest_multiplier = 1.0
	sting_range = balance_value("player", "repel_range", 88.0)
	sting_cost = balance_value("player", "repel_cost", 8.0)
	sting_cooldown_multiplier = 1.0
	extra_nectar = 0
	bee.reset_upgrades()
	if persistence_enabled:
		save_manager.begin_run()
	spawn_stage(0)

func spawn_stage(index: int) -> void:
	if stages.is_empty():
		return
	# 正色节点即失律者关卡：春分/夏至/秋分直接进入调律遭遇
	if is_boss_stage(index):
		stage_index = index
		start_boss()
		return
	stage_index = index
	sound.set_season(season_index_of(index))
	phase = "playing"
	overlay.visible = false
	carried = 0
	delivered = 0
	harvest_clock = 0.0
	sting_cooldown = 0.0
	hit_cooldown = 0.0
	was_in_hive = false
	flowers.clear()
	mosquitoes.clear()
	ants.clear()
	crickets.clear()
	thrushes.clear()
	bears.clear()
	phantom_flowers.clear()
	field_afterimages.clear()
	decoys.clear()
	tuning_blooms.clear()
	pollen.clear()
	var data: Dictionary = stages[index]
	bee.configure(float(data.energy_drain))
	bee.reset_for_expedition(Vector2(180, 410))
	for i in int(data.flowers):
		var flower_position := find_spaced_flower_position(82.0)
		flowers.append({
			"id": i,
			"position": flower_position,
			"nectar": max(2, roundi(rng.randf_range(3, 6) * float(data.nectar_scale))) + extra_nectar,
			"kind": i % 3,
			"phase": rng.randf_range(0, TAU),
			"recovery": false
		})
	# 敌物候学：五类小怪按节令物候生成（见 docs/design/enemy-phenology.md）
	for i in int(data.get("mosquitoes", 0)):
		mosquitoes.append({
			"id": i,
			"position": Vector2(rng.randf_range(540, 940), rng.randf_range(210, 610)),
			"velocity": Vector2.ZERO,
			"repel_time": 0.0
		})
	for i in int(data.get("ants", 0)):
		ants.append(build_ant_with_trail(i))
	for i in int(data.get("crickets", 0)):
		crickets.append({
			"id": i,
			"position": Vector2(rng.randf_range(420, 920), rng.randf_range(240, 600)),
			"velocity": Vector2.ZERO,
			"repel_time": 0.0,
			"hopping": false,
			"hop_clock": rng.randf_range(0.3, 1.2),
			"hop_time": 0.0,
			"hop_direction": Vector2.RIGHT
		})
	for i in int(data.get("thrushes", 0)):
		thrushes.append({
			"id": i,
			"position": Vector2(rng.randf_range(480, 900), rng.randf_range(240, 580)),
			"song_clock": rng.randf_range(2.0, 5.0),
			"silence_time": 0.0
		})
	for i in int(data.get("bears", 0)):
		bears.append({
			"id": i,
			"position": Vector2(WORLD.end.x - 26.0, rng.randf_range(300.0, 560.0)),
			"state": "forage",
			"eat_clock": balance_value("bear", "eat_interval", 4.0),
			"eaten": 0,
			"bored": 0
		})
	# 体温在越冬段（寒露→大雪）内延续：由数据字段 warmth_carry 标记，
	# 只有入冬第一个节令（寒露）重置体温
	preserve_warmth = bool(data.get("warmth_carry", false))
	if season_index_of(index) != 3:
		energy_cap_override = 100.0
	season_mechanics.start_stage(index)
	message = "%s：%s" % [data.name, data.line]
	update_interface()
	queue_redraw()

func on_overlay_button() -> void:
	# 相位护栏：异常状态下点穿弹窗不推进关卡
	if not ["intro", "won", "lost", "paused", "boss_victory", "between"].has(phase):
		return
	match phase:
		"intro", "won", "lost": start_game()
		"paused": toggle_pause()
		"boss_victory":
			if stage_index + 1 < stages.size():
				spawn_stage(stage_index + 1)
			else:
				show_win()
		"between":
			advance_stage()

# 从蜂巢成长界面推进：下一个节令若是正色节点则直接进入失律者关卡；
# 大雪是最后的采蜜关，此后回到冬至——失律之熊守着循环的终点。
func advance_stage() -> void:
	if stage_index + 1 < stages.size():
		spawn_stage(stage_index + 1)
	else:
		start_boss()

func _process(delta: float) -> void:
	elapsed += delta
	shake = maxf(0.0, shake - delta * 18.0)
	flash = maxf(0.0, flash - delta * 2.5)
	energy_feedback_time = maxf(0.0, energy_feedback_time - delta)
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
	update_decoys(delta)

	# 双击方向键 = 急转闪避
	_check_double_tap_evade(delta)

	# 归巢：Q 键自动飞回蜂巢
	if Input.is_action_just_pressed("return_hive"):
		bee.set_move_target(HIVE_RETURN_POS)
		message = "归巢路线已锁定。"

	# 情境动作：空格/回车根据上下文执行不同操作
	var nearby := nearest_flower(46.0)
	var near_enemy := _nearest_enemy_distance() < sting_range
	var is_still := bee.velocity.length_squared() < 4.0 and not bee.has_target

	if Input.is_action_just_pressed("action"):
		action_hold_time = 0.0
		action_decoy_fired = false
		# 优先级：近敌→惊退 > 静止→寻迹
		if near_enemy and nearby < 0:
			_do_repel()
		elif is_still and nearby < 0 and not near_enemy:
			_do_sense()
		elif nearby >= 0:
			# 近花时按下开始采蜜（持续按住逻辑在下面）
			pass

	if Input.is_action_pressed("action"):
		action_hold_time += delta
		if nearby >= 0 and bee.energy > 0:
			# 采蜜（持续）
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
				season_mechanics.on_harvest(nearby)
				message = "花香正在变淡。还要继续停留吗？" if flower.nectar > 0 else "这朵花已经采尽。"
		elif not action_decoy_fired and action_hold_time >= DECOY_HOLD_THRESHOLD and carried > 0 and not near_enemy:
			# 长按空格 + 携蜜 + 无花无敌 = 投蜜诱饵
			action_decoy_fired = true
			drop_honey_decoy()
	else:
		action_hold_time = 0.0
		action_decoy_fired = false
		harvest_clock = 0.0

	update_mosquitoes(delta)
	update_ants(delta)
	update_crickets(delta)
	update_thrushes(delta)
	update_bears(delta)
	# 花被熊压平后的恢复倒计时
	for i in flowers.size():
		var flower_timer: Dictionary = flowers[i]
		if float(flower_timer.get("flatten_time", 0.0)) > 0.0:
			flower_timer.flatten_time = maxf(0.0, float(flower_timer.flatten_time) - delta)
			flowers[i] = flower_timer
	season_mechanics.process(delta)
	update_hive_rest(delta, true)
	if delivered >= int(data.goal) and phase == "playing":
		show_between()
	if bee.energy <= 0.0:
		fail_expedition()

func _nearest_enemy_distance() -> float:
	var min_dist := INF
	for mosquito in mosquitoes:
		min_dist = minf(min_dist, bee.position.distance_to(mosquito.position))
	for ant in ants:
		min_dist = minf(min_dist, bee.position.distance_to(ant.position))
	for cricket in crickets:
		min_dist = minf(min_dist, bee.position.distance_to(cricket.position))
	for thrush in thrushes:
		min_dist = minf(min_dist, bee.position.distance_to(thrush.position))
	for bear_unit in bears:
		min_dist = minf(min_dist, bee.position.distance_to(bear_unit.position))
	return min_dist

func _do_repel() -> void:
	if sting_cooldown > 0.0 or not bee.spend_energy(sting_cost):
		return
	show_energy_change(-sting_cost)
	sting_cooldown = balance_value("player", "repel_cooldown", 1.15) * sting_cooldown_multiplier
	sound.play_cue("repel")
	for i in mosquitoes.size():
		var mosquito: Dictionary = mosquitoes[i]
		if bee.position.distance_to(mosquito.position) < sting_range:
			mosquito.repel_time = balance_value("player", "repel_duration", 3.5)
			mosquito.velocity = (mosquito.position - bee.position).normalized() * 8.0
			mosquitoes[i] = mosquito
	for i in ants.size():
		var ant: Dictionary = ants[i]
		if bee.position.distance_to(ant.position) < sting_range:
			ant.flee_time = 1.8
			ant.velocity = (ant.position - bee.position).normalized() * 3.2
			if int(ant.stolen_honey) > 0:
				return_honey_to_field(int(ant.stolen_honey), ant.position)
				message = "掠蜜蚁受惊后丢下了 %d 滴蜜，花田会重新吸收它们。" % int(ant.stolen_honey)
				ant.stolen_honey = 0
			ants[i] = ant
	for i in crickets.size():
		var cricket: Dictionary = crickets[i]
		if bee.position.distance_to(cricket.position) < sting_range:
			cricket.repel_time = balance_value("player", "repel_duration", 3.5)
			cricket.hopping = false
			cricket.hop_clock = balance_value("cricket", "rest_seconds", 1.2)
			crickets[i] = cricket
	for i in thrushes.size():
		var thrush: Dictionary = thrushes[i]
		if bee.position.distance_to(thrush.position) < sting_range + 20.0:
			thrush.silence_time = balance_value("player", "repel_duration", 3.5)
			thrushes[i] = thrush
	season_mechanics.on_repel_success()
	message = "急促的震翼把附近敌虫推离了航线。"
	for bear_unit in bears:
		if bee.position.distance_to(bear_unit.position) < sting_range + 40.0:
			message = "熊对震翼毫无反应。绕开它，抢在它之前收完这片花田。"

func _do_sense() -> void:
	if bee.sense_cooldown > 0.0:
		return
	var huddle = season_mechanics.mechanic_by_id("huddle")
	if huddle != null and huddle.is_scouting_ready():
		bee.sense_cooldown = huddle.scout_cooldown_value()
		message = "摇摆舞传来花源方位：蜜最丰的花田已标出。"
	else:
		bee.trigger_sense()

func _check_double_tap_evade(_delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var directions := {
		"left": "move_left",
		"right": "move_right",
		"up": "move_up",
		"down": "move_down"
	}
	for dir_key in directions:
		if Input.is_action_just_pressed(directions[dir_key]):
			if now - last_dir_tap[dir_key] < DOUBLE_TAP_WINDOW:
				if bee.try_evade():
					show_energy_change(-12.0)
					sound.play_cue("evade")
					message = "急转掠过攻击线：短暂避开碰撞。"
			last_dir_tap[dir_key] = now

func update_mosquitoes(delta: float) -> void:
	for i in mosquitoes.size():
		var mosquito: Dictionary = mosquitoes[i]
		mosquito.repel_time = maxf(0.0, float(mosquito.repel_time) - delta)
		var distance_to_player := Vector2(mosquito.position).distance_to(bee.position)
		if mosquito.repel_time > 0.0:
			var away := (Vector2(mosquito.position) - bee.position).normalized()
			if away.length_squared() < 0.01:
				away = Vector2.RIGHT
			mosquito.velocity = Vector2(mosquito.velocity).lerp(away * 3.2, delta * 7.0)
			mosquito.position += Vector2(mosquito.velocity) * balance_value("mosquito", "move_speed", 82.0) * 1.35 * delta
		else:
			var lure_position := nearest_decoy_position(Vector2(mosquito.position))
			if lure_position != Vector2.INF:
				var chase := (lure_position - Vector2(mosquito.position)).normalized()
				mosquito.velocity = Vector2(mosquito.velocity).lerp(chase * 2.1, delta * 2.8)
			elif distance_to_player < balance_value("mosquito", "sense_range", 330.0) and bee.position.x > HIVE_SAFE_X:
				var chase := (bee.position - Vector2(mosquito.position)).normalized()
				mosquito.velocity = Vector2(mosquito.velocity).lerp(chase * 2.1, delta * 2.8)
			mosquito.position += Vector2(mosquito.velocity) * balance_value("mosquito", "move_speed", 82.0) * delta
		mosquito.position.x = clampf(mosquito.position.x, HIVE_SAFE_X, WORLD.end.x - 12)
		mosquito.position.y = clampf(mosquito.position.y, WORLD.position.y + 12, WORLD.end.y - 12)
		if mosquito.repel_time <= 0.0:
			if distance_to_player < balance_value("mosquito", "impact_range", 26.0) and hit_cooldown <= 0.0 and bee.invulnerable_time <= 0.0:
				hit_cooldown = 1.05
				bee.energy = maxf(0.0, bee.energy - balance_value("mosquito", "energy_damage", 15.0))
				show_energy_change(-balance_value("mosquito", "energy_damage", 15.0))
				var lost_honey := mini(carried, roundi(balance_value("mosquito", "honey_damage", 2.0)))
				carried -= lost_honey
				return_honey_to_field(lost_honey, mosquito.position)
				shake = 7.0
				flash = 0.48
				message = "蚊虫刺中了你：体力下降，花蜜洒落。"
				sound.play_cue("hurt")
		mosquitoes[i] = mosquito
	separate_units(mosquitoes, 28.0)
	for i in mosquitoes.size():
		var mosquito_clamp: Dictionary = mosquitoes[i]
		var clamp_position: Vector2 = mosquito_clamp.position
		mosquito_clamp.position = Vector2(
			clampf(clamp_position.x, HIVE_SAFE_X, WORLD.end.x - 12),
			clampf(clamp_position.y, WORLD.position.y + 12, WORLD.end.y - 12)
		)
		mosquitoes[i] = mosquito_clamp

# 掠蜜蚁沿信息素轨迹在巢口与富花之间巡逻：轨迹可读、可预判（生态化重设计）
func build_ant_with_trail(id: int) -> Dictionary:
	var nest := Vector2(WORLD.end.x - 18.0, rng.randf_range(220.0, 620.0))
	var richest := -1
	var richest_nectar := -1
	for i in flowers.size():
		var flower: Dictionary = flowers[i]
		if int(flower.nectar) > richest_nectar and not bool(flower.get("recovery", false)):
			richest_nectar = int(flower.nectar)
			richest = i
	var target := Vector2(WORLD.end.x - 120.0, 410.0)
	if richest >= 0:
		target = Vector2(flowers[richest].position)
	var waypoint := Vector2(
		(nest.x + target.x) * 0.5 + rng.randf_range(-60.0, 60.0),
		clampf((nest.y + target.y) * 0.5 + rng.randf_range(-80.0, 80.0), WORLD.position.y + 60.0, WORLD.end.y - 60.0)
	)
	return {
		"id": id,
		"position": nest,
		"velocity": Vector2.ZERO,
		"steal_cooldown": 0.0,
		"flee_time": 0.0,
		"stolen_honey": 0,
		"trail": [nest, waypoint, target],
		"trail_index": 0,
		"trail_forward": true
	}

func update_ants(delta: float) -> void:
	for i in ants.size():
		var ant: Dictionary = ants[i]
		ant.steal_cooldown = maxf(0.0, float(ant.steal_cooldown) - delta)
		ant.flee_time = maxf(0.0, float(ant.flee_time) - delta)
		var ant_position: Vector2 = ant.position
		var desired := Vector2.ZERO
		if ant.flee_time > 0.0:
			desired = Vector2(ant.velocity).normalized()
		else:
			var trail: Array = ant.get("trail", [])
			if trail.is_empty():
				var flower_index := nearest_flower_to(ant_position)
				if flower_index >= 0:
					desired = (Vector2(flowers[flower_index].position) - ant_position).normalized()
			else:
				var arrive := balance_value("ant", "trail_arrive_range", 14.0)
				var target_position: Vector2 = trail[int(ant.trail_index)]
				if ant_position.distance_to(target_position) < arrive:
					if int(ant.trail_index) >= trail.size() - 1:
						ant.trail_forward = false
					elif int(ant.trail_index) <= 0:
						ant.trail_forward = true
					ant.trail_index = clampi(int(ant.trail_index) + (1 if bool(ant.trail_forward) else -1), 0, trail.size() - 1)
					target_position = trail[int(ant.trail_index)]
				desired = (target_position - ant_position).normalized()
		ant.velocity = Vector2(ant.velocity).lerp(desired * 1.35, delta * 2.2)
		ant.position += Vector2(ant.velocity) * balance_value("ant", "move_speed", 58.0) * delta
		ant.position.x = clampf(ant.position.x, HIVE_SAFE_X, WORLD.end.x - 14)
		ant.position.y = clampf(ant.position.y, WORLD.position.y + 14, WORLD.end.y - 14)
		if ant.flee_time <= 0.0 and ant_position.distance_to(bee.position) < balance_value("ant", "steal_range", 29.0) and carried > 0 and ant.steal_cooldown <= 0.0:
			carried -= 1
			ant.stolen_honey = int(ant.stolen_honey) + 1
			ant.steal_cooldown = 1.2
			ant.flee_time = balance_value("ant", "flee_seconds", 1.4)
			ant.velocity = (ant_position - bee.position).normalized() * 3.0
			spawn_pollen(ant_position)
			message = "掠蜜蚁夺走了一滴花蜜，正试图逃离。"
			sound.play_cue("hurt")
			shake = 4.0
		ants[i] = ant
	separate_units(ants, 26.0)
	for i in ants.size():
		var ant_clamp: Dictionary = ants[i]
		var clamp_position: Vector2 = ant_clamp.position
		ant_clamp.position = Vector2(
			clampf(clamp_position.x, HIVE_SAFE_X, WORLD.end.x - 14),
			clampf(clamp_position.y, WORLD.position.y + 14, WORLD.end.y - 14)
		)
		ants[i] = ant_clamp

# 油葫芦：间歇跳跃（0.4s 爆发 + 一个虚影 → 1.2s 停顿），威胁在落点预判
func update_crickets(delta: float) -> void:
	for i in crickets.size():
		var cricket: Dictionary = crickets[i]
		cricket.repel_time = maxf(0.0, float(cricket.repel_time) - delta)
		if bool(cricket.hopping):
			cricket.hop_time = float(cricket.hop_time) - delta
			cricket.position = Vector2(cricket.position) + Vector2(cricket.hop_direction) * balance_value("cricket", "burst_speed", 110.0) * delta
			if float(cricket.hop_time) <= 0.0:
				cricket.hopping = false
				cricket.hop_clock = balance_value("cricket", "rest_seconds", 1.2)
		else:
			cricket.hop_clock = float(cricket.hop_clock) - delta
			if float(cricket.repel_time) > 0.0:
				var away := (Vector2(cricket.position) - bee.position).normalized()
				cricket.position = Vector2(cricket.position) + away * 60.0 * delta
			elif float(cricket.hop_clock) <= 0.0:
				cricket.hopping = true
				cricket.hop_time = balance_value("cricket", "burst_seconds", 0.4)
				var to_player: Vector2 = bee.position - Vector2(cricket.position)
				if to_player.length() < balance_value("cricket", "sense_range", 220.0):
					cricket.hop_direction = to_player.normalized().rotated(rng.randf_range(-0.5, 0.5))
				else:
					cricket.hop_direction = Vector2.from_angle(rng.randf() * TAU)
				field_afterimages.append({"position": Vector2(cricket.position), "life": balance_value("cricket", "afterimage_life", 0.5)})
		var cricket_position: Vector2 = cricket.position
		cricket_position.x = clampf(cricket_position.x, HIVE_SAFE_X, WORLD.end.x - 14)
		cricket_position.y = clampf(cricket_position.y, WORLD.position.y + 14, WORLD.end.y - 14)
		cricket.position = cricket_position
		if float(cricket.repel_time) <= 0.0 and cricket_position.distance_to(bee.position) < balance_value("cricket", "impact_range", 28.0) and hit_cooldown <= 0.0 and bee.invulnerable_time <= 0.0:
			hit_cooldown = 1.05
			bee.energy = maxf(0.0, bee.energy - balance_value("cricket", "energy_damage", 10.0))
			show_energy_change(-balance_value("cricket", "energy_damage", 10.0))
			shake = 6.0
			flash = 0.4
			message = "油葫芦擦身跃过，气流扫得你失去平衡。"
			sound.play_cue("hurt")
		crickets[i] = cricket
	separate_units(crickets, 24.0)
	for i in range(field_afterimages.size() - 1, -1, -1):
		field_afterimages[i].life = float(field_afterimages[i].life) - delta
		if float(field_afterimages[i].life) <= 0.0:
			field_afterimages.remove_at(i)

# 画眉：栖息鸣唱催生幻花（无蜜的骗局），靠近才识破；惊退可打断歌声
func update_thrushes(delta: float) -> void:
	for i in thrushes.size():
		var thrush: Dictionary = thrushes[i]
		thrush.silence_time = maxf(0.0, float(thrush.silence_time) - delta)
		thrush.song_clock = float(thrush.song_clock) - delta
		if float(thrush.silence_time) <= 0.0 and float(thrush.song_clock) <= 0.0:
			thrush.song_clock = balance_value("thrush", "song_interval", 8.0)
			if phantom_flowers.size() < int(balance_value("thrush", "max_phantoms", 3.0)):
				var angle := rng.randf() * TAU
				var distance := rng.randf_range(46.0, balance_value("thrush", "phantom_radius", 120.0))
				var thrush_position: Vector2 = thrush.position
				var phantom_position := Vector2(
					clampf(thrush_position.x + cos(angle) * distance, HIVE_SAFE_X + 30.0, WORLD.end.x - 40.0),
					clampf(thrush_position.y + sin(angle) * distance, WORLD.position.y + 50.0, WORLD.end.y - 50.0)
				)
				phantom_flowers.append({"position": phantom_position, "life": balance_value("thrush", "phantom_life", 20.0), "kind": rng.randi() % 3, "phase": rng.randf_range(0, TAU)})
				message = "画眉的歌声在花田里催出一朵幻花。"
		thrushes[i] = thrush
	for i in range(phantom_flowers.size() - 1, -1, -1):
		var phantom: Dictionary = phantom_flowers[i]
		phantom.life = float(phantom.life) - delta
		var revealed := Vector2(phantom.position).distance_to(bee.position) < balance_value("thrush", "phantom_reveal_range", 34.0)
		if revealed or float(phantom.life) <= 0.0:
			if revealed:
				spawn_pollen(phantom.position)
				message = "这朵花没有蜜——歌声的骗局消散了。"
			phantom_flowers.remove_at(i)
		else:
			phantom_flowers[i] = phantom

# 熊：不可对抗的碾压型威胁——压平沿途花朵，抵达巢区吃储备，吃饱自行离开
func update_bears(delta: float) -> void:
	var anchor_x := HIVE_SAFE_X + balance_value("bear", "hive_anchor_offset", 70.0)
	var flatten_radius := balance_value("bear", "flatten_radius", 30.0)
	for i in range(bears.size() - 1, -1, -1):
		var bear: Dictionary = bears[i]
		var bear_position: Vector2 = bear.position
		if String(bear.state) == "leaving":
			bear_position.x += balance_value("bear", "move_speed", 30.0) * 1.6 * delta
			bear.position = bear_position
			if bear_position.x > WORLD.end.x + 60.0:
				bears.remove_at(i)
			continue
		if bear_position.x > anchor_x:
			var target := Vector2(anchor_x, bear_position.y)
			bear_position += (target - bear_position).normalized() * balance_value("bear", "move_speed", 30.0) * delta
			bear.position = bear_position
		else:
			bear.state = "feeding"
			bear.eat_clock = float(bear.eat_clock) - delta
			if float(bear.eat_clock) <= 0.0:
				bear.eat_clock = balance_value("bear", "eat_interval", 4.0)
				if hive_reserve > 0:
					hive_reserve -= 1
					bear.eaten = int(bear.eaten) + 1
					shake = 6.0
					sound.play_cue("hurt")
					message = "熊在巢口吃掉一滴储备蜜。绕不开它，就抢在它前面收蜜。"
				else:
					bear.bored = int(bear.bored) + 1
				if int(bear.eaten) >= int(balance_value("bear", "appetite", 3.0)) or int(bear.bored) >= 2:
					bear.state = "leaving"
					message = "熊吃饱了，摇摇摆摆地离开花田。"
		for flower_index in flowers.size():
			var flower: Dictionary = flowers[flower_index]
			if Vector2(flower.position).distance_to(bear_position) < flatten_radius:
				flower.flatten_time = balance_value("bear", "flatten_seconds", 9.0)
				flowers[flower_index] = flower
		if bear_position.distance_to(bee.position) < balance_value("bear", "contact_range", 30.0) and hit_cooldown <= 0.0 and bee.invulnerable_time <= 0.0:
			hit_cooldown = 1.05
			bee.energy = maxf(0.0, bee.energy - balance_value("bear", "contact_damage", 16.0))
			show_energy_change(-balance_value("bear", "contact_damage", 16.0))
			shake = 8.0
			flash = 0.5
			message = "你撞上了熊的肩膀。别和它较劲——绕开。"
			sound.play_cue("hurt")
		bears[i] = bear

func update_hive_rest(delta: float, deposit_honey: bool) -> void:
	var inside := bee.position.x < HIVE_X
	if not inside:
		was_in_hive = false
		return
	season_mechanics.on_home(carried if deposit_honey else 0, delta)
	var rest_rate := balance_value("player", "hive_rest_per_second", 36.0)
	if season_index_of(stage_index) == 3 and warmth <= cold_warmth_threshold:
		rest_rate *= 0.5
	bee.energy = minf(energy_cap_override, bee.energy + rest_rate * delta)
	if deposit_honey and carried > 0:
		var amount := carried
		delivered += amount
		carried = 0
		message = "安全归巢，存入 %d 滴蜜。蜂群的照料正在恢复体力。" % amount
		sound.play_cue("home")
		flash = 0.32
	elif not was_in_hive:
		message = "即使空手归来，蜂巢也会接纳你。停留片刻恢复体力。"
	was_in_hive = true

func fail_expedition() -> void:
	hive_lives -= 1
	var lost_honey := carried
	carried = 0
	return_honey_to_field(lost_honey, bee.position)
	bee.reset_for_expedition(Vector2(180, 410))
	shake = 10.0
	message = "你没能带回花蜜，蜂巢的呼吸弱了一分。洒落的 %d 滴蜜将孕育返蜜花。" % lost_honey
	if hive_lives <= 0:
		show_loss()

func show_between() -> void:
	phase = "between"
	bee.active = false
	overlay.visible = true
	var data: Dictionary = stages[stage_index]
	if persistence_enabled:
		save_manager.record_stage(stage_index + 1)
	season_mechanics.on_stage_complete()
	# 储备机制：白露是储备段最后的采蜜关，本季的蜜需要分配（储冬蜜 / 哺育幼虫）
	var reserve_m = season_mechanics.mechanic_by_id("reserve")
	if reserve_m != null and reserve_m.pending_allocation:
		allocation_pending = true
		allocation_harvest = int(reserve_m.pending_harvest)
		show_allocation_panel()
	else:
		hive_reserve += delivered
		show_upgrade_choices(data)

func show_upgrade_choices(data: Dictionary) -> void:
	# 二十四个节令会让成长点远多于旧 MVP：三种倾向全部满级后，
	# 不再强制选择，直接给出「继续」按钮，避免成长界面死锁。
	var any_available := false
	for i in upgrade_catalog.size():
		var entry: Dictionary = upgrade_catalog[i]
		if int(upgrade_counts.get(String(entry.id), 0)) < UPGRADE_CAP:
			any_available = true
			break
	if not any_available:
		overlay_title.text = "%s完成 · 蜂巢安定" % data.name
		overlay_body.text = "三种分工都已成熟。蜂群按既定的节奏继续运转。" + next_boss_hint()
		overlay_button.text = "继续下一个节令"
		overlay_button.visible = true
		set_upgrade_buttons_visible(false)
		return
	overlay_title.text = "%s完成 · 蜂巢成长" % data.name
	overlay_body.text = "带回的蜜哺育了新的分工。选择一种蜂群倾向；本轮效果可以叠加。" + next_boss_hint()
	overlay_button.visible = false
	set_upgrade_buttons_visible(true)

# 通关横幅只写「刚刚完成的节令」，玩家无从知道下一个节点是失律者关卡——
# 在蜂巢成长界面直接预告，消除「惊蛰完成却撞上春分 Boss」的错位感
func next_boss_hint() -> String:
	if stage_index + 1 >= stages.size():
		return ""
	if not is_boss_stage(stage_index + 1):
		return ""
	var next: Dictionary = stages[stage_index + 1]
	var next_boss := boss_data_for_stage(stage_index + 1)
	var boss_name := String(next_boss.get("name", "失律者"))
	return "\n\n下一个节令是正色节点：%s——%s盘踞其上，调律在等着你。" % [String(next.name), boss_name]

func show_allocation_panel() -> void:
	overlay_title.text = "白露 · 为来年投资"
	overlay_body.text = ""
	set_upgrade_buttons_visible(false)
	overlay_button.visible = false
	allocation_body_label.text = "本季带回 %d 滴蜜。储冬蜜撑起越冬；哺育的幼虫将成为来年劳动力。" % allocation_harvest
	allocation_panel.visible = true
	allocation_slider.value = 50.0
	refresh_allocation_labels()

func refresh_allocation_labels() -> void:
	if allocation_panel == null or not allocation_panel.visible:
		return
	var fed := roundi(allocation_harvest * allocation_fraction)
	var stored := allocation_harvest - fed
	allocation_left_label.text = "储冬蜜　%02d 滴" % stored
	allocation_right_label.text = "哺育幼虫　%02d 滴" % fed

func confirm_allocation() -> void:
	if phase != "between" or not allocation_pending:
		return
	var reserve_m = season_mechanics.mechanic_by_id("reserve")
	if reserve_m == null:
		return
	reserve_m.apply_split(allocation_fraction)
	allocation_pending = false
	allocation_panel.visible = false
	show_upgrade_choices(stages[stage_index])

func set_upgrade_buttons_visible(value: bool) -> void:
	for i in upgrade_buttons.size():
		upgrade_buttons[i].visible = value
		if value and i < upgrade_catalog.size():
			var data: Dictionary = upgrade_catalog[i]
			upgrade_buttons[i].text = "%s  %s\n\n%s" % [data.symbol, data.name, data.description]
			upgrade_buttons[i].disabled = int(upgrade_counts.get(String(data.id), 0)) >= UPGRADE_CAP

func on_upgrade_selected(index: int) -> void:
	if phase != "between" or index >= upgrade_catalog.size():
		return
	var data: Dictionary = upgrade_catalog[index]
	var upgrade_id := String(data.id)
	if int(upgrade_counts.get(upgrade_id, 0)) >= UPGRADE_CAP:
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
	advance_stage()

func start_boss() -> void:
	if boss_catalog.is_empty():
		push_error("失律者数据缺失，无法开启调律遭遇")
		return
	# 失律者由所在节气节点决定；循环终点（大雪之后）默认回到失律之熊
	current_boss_data = boss_data_for_stage(stage_index)
	if current_boss_data.is_empty():
		push_error("失律者数据中找不到本节点的失律者")
		return
	for i in boss_catalog.size():
		if boss_catalog[i] == current_boss_data:
			current_boss_index = i
			break
	var data: Dictionary = current_boss_data
	phase = "boss"
	sound.set_season(int(data.season_index))
	overlay.visible = false
	overlay_button.visible = true
	set_upgrade_buttons_visible(false)
	flowers.clear()
	mosquitoes.clear()
	ants.clear()
	crickets.clear()
	thrushes.clear()
	bears.clear()
	phantom_flowers.clear()
	field_afterimages.clear()
	pollen.clear()
	decoys.clear()
	boss_afterimages.clear()
	tuning_blooms.clear()
	for i in int(data.bloom_count):
		tuning_blooms.append(Vector2(360.0 + i * 180.0, clampf(285.0 + sin(float(i) * 2.4) * 150.0, 200.0, 600.0)))
	boss = {
		"position": Vector2(840, 410),
		"velocity": Vector2.ZERO,
		"hits": 0,
		"hit_cooldown": 0.0,
		"pattern_time": 0.0,
		"next_shift": 0.0,
		"charge_state": "wander",
		"state_time": 0.0,
		"aim_direction": Vector2.RIGHT
	}
	bee.configure(1.45 + float(data.season_index) * 0.2)
	bee.reset_for_expedition(Vector2(180, 410))
	carried = 6
	delivered = 0
	message = String(data.encounter_message)

func update_boss(delta: float) -> void:
	if current_boss_data.is_empty():
		return
	var data: Dictionary = current_boss_data
	sting_cooldown = maxf(0.0, sting_cooldown - delta)
	boss.hit_cooldown = maxf(0.0, float(boss.hit_cooldown) - delta)
	boss.pattern_time = float(boss.pattern_time) + delta
	var boss_position: Vector2 = boss.position
	var to_bee := bee.position - boss_position
	var pattern := String(data.move_pattern)
	var move_speed := float(data.move_speed)

	match pattern:
		"orbital":
			# 蚊：绕着玩家盘旋吸取，航线随时间摆动
			var orbit := to_bee.normalized().rotated(sin(elapsed * 1.7) * 0.45)
			boss.velocity = Vector2(boss.velocity).lerp(orbit * 2.2, delta * 1.7)
		"erratic":
			# 油葫芦：随机变向乱窜，离开虚影；远离玩家时靠回来
			if float(boss.pattern_time) >= float(boss.next_shift):
				boss.next_shift = float(boss.pattern_time) + rng.randf_range(0.35, 0.8)
				var heading := to_bee.normalized() if to_bee.length() > 380.0 else Vector2.from_angle(rng.randf() * TAU)
				boss.velocity = heading * 2.6
				boss_afterimages.append({"position": boss_position, "life": 0.5})
		"lure":
			# 画眉：与玩家保持中距离徘徊打转，把战线缓缓拖离蜂巢
			var tangent_sign := 1.0 if int(data.season_index) % 2 == 0 else -1.0
			var tangent := to_bee.normalized().rotated(PI * 0.5 * tangent_sign)
			var radial := clampf((to_bee.length() - 240.0) / 240.0, -1.0, 1.0)
			boss.velocity = Vector2(boss.velocity).lerp((to_bee.normalized() * radial + tangent * 0.85) * 1.5, delta * 2.2)
		"charge":
			# 熊：游走 → 蓄势（直线预告）→ 冲撞 → 晕眩（调律窗口）
			match String(boss.charge_state):
				"wander":
					boss.velocity = Vector2(boss.velocity).lerp(to_bee.normalized() * 0.7, delta * 1.2)
					if to_bee.length() < 320.0:
						boss.charge_state = "aim"
						boss.state_time = 0.8
						boss.aim_direction = to_bee.normalized()
				"aim":
					boss.state_time = float(boss.state_time) - delta
					boss.velocity = Vector2(boss.velocity).lerp(Vector2.ZERO, delta * 6.0)
					if float(boss.state_time) <= 0.0:
						boss.charge_state = "dash"
						boss.state_time = 1.0
						boss.velocity = Vector2(boss.aim_direction) * 4.2
				"dash":
					boss.state_time = float(boss.state_time) - delta
					boss.velocity = Vector2(boss.velocity).lerp(Vector2(boss.aim_direction) * 4.2, delta * 2.0)
					if float(boss.state_time) <= 0.0:
						boss.charge_state = "rest"
						boss.state_time = 1.3
				"rest":
					boss.state_time = float(boss.state_time) - delta
					boss.velocity = Vector2(boss.velocity).lerp(Vector2.ZERO, delta * 5.0)
					if float(boss.state_time) <= 0.0:
						boss.charge_state = "wander"

	boss.position += Vector2(boss.velocity) * move_speed * delta
	boss.position.x = clampf(boss.position.x, HIVE_SAFE_X + 18.0, WORLD.end.x - 28)
	boss.position.y = clampf(boss.position.y, WORLD.position.y + 28, WORLD.end.y - 28)

	for i in range(boss_afterimages.size() - 1, -1, -1):
		boss_afterimages[i].life = float(boss_afterimages[i].life) - delta
		if float(boss_afterimages[i].life) <= 0.0:
			boss_afterimages.remove_at(i)

	if boss_position.distance_to(bee.position) < float(data.impact_range) and boss.hit_cooldown <= 0.0:
		boss.hit_cooldown = 1.0
		bee.energy = maxf(0.0, bee.energy - float(data.energy_damage))
		show_energy_change(-float(data.energy_damage))
		carried = maxi(0, carried - int(data.honey_damage))
		shake = 9.0
		sound.play_cue("hurt")
		flash = 0.55
		message = String(data.damage_message)

	if Input.is_action_just_pressed("action") and sting_cooldown <= 0.0 and bee.spend_energy(sting_cost):
		show_energy_change(-sting_cost)
		sting_cooldown = balance_value("player", "repel_cooldown", 1.15) * sting_cooldown_multiplier
		sound.play_cue("repel")
		var bloom_index := nearest_tuning_bloom(boss.position)
		if bee.position.distance_to(boss.position) < sting_range + 7.0 and bloom_index >= 0:
			var bloom_position := tuning_blooms[bloom_index]
			tuning_blooms.remove_at(bloom_index)
			boss.hits = int(boss.hits) + 1
			boss.velocity = (boss.position - bee.position).normalized() * 8.0
			spawn_pollen(bloom_position)
			shake = 7.0
			message = String(data.tuning_message).replace("{n}", str(int(boss.hits)))
			sound.play_cue("tune")
			if int(boss.hits) >= int(data.required_tunings):
				if current_boss_index >= boss_catalog.size() - 1:
					show_win()
				else:
					show_boss_victory()
		else:
			message = String(data.miss_message)

	update_hive_rest(delta, false)

	if bee.energy <= 0.0:
		show_loss()

func nearest_tuning_bloom(origin: Vector2) -> int:
	var radius := float(current_boss_data.get("tuning_radius", balance_value("boss", "tuning_radius", 82.0)))
	for i in tuning_blooms.size():
		if origin.distance_to(tuning_blooms[i]) < radius:
			return i
	return -1

func show_boss_victory() -> void:
	phase = "boss_victory"
	bee.active = false
	overlay.visible = true
	overlay_button.visible = true
	set_upgrade_buttons_visible(false)
	sound.play_cue("win")
	var data: Dictionary = current_boss_data
	overlay_title.text = "%s · 归律" % String(data.name)
	overlay_body.text = "%s\n\n%s" % [String(data.line), next_term_hint()]
	overlay_button.text = "继续前行"

func next_term_hint() -> String:
	if stage_index + 1 >= stages.size():
		return ""
	var data: Dictionary = stages[stage_index + 1]
	return "下一个节令：%s。%s" % [String(data.name), String(data.line)]

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
	overlay_body.text = "蜂群走完了完整的二十四个节令，四位失律者重归循环。\n本轮主动游玩时间：%s" % format_duration(run_elapsed)
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
		if int(flower.nectar) <= 0 or bool(flower.get("sleeping", false)) or float(flower.get("flatten_time", 0.0)) > 0.0:
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
		if int(flower.nectar) <= 0 or bool(flower.get("sleeping", false)) or float(flower.get("flatten_time", 0.0)) > 0.0:
			continue
		var current := origin.distance_to(flower.position)
		if current < best_distance:
			best = i
			best_distance = current
	return best

func spawn_pollen(origin: Vector2) -> void:
	for i in 6:
		pollen.append({"position": origin, "velocity": Vector2.from_angle(rng.randf_range(0, TAU)) * rng.randf_range(20, 65), "life": rng.randf_range(0.35, 0.7)})

func find_spaced_flower_position(minimum_distance: float) -> Vector2:
	var candidate := Vector2.ZERO
	for attempt in 40:
		candidate = Vector2(rng.randf_range(300, 950), rng.randf_range(205, 620))
		var valid := true
		for flower in flowers:
			if candidate.distance_to(Vector2(flower.position)) < minimum_distance:
				valid = false
				break
		if valid:
			return candidate
	return candidate

func separate_units(units: Array, minimum_distance: float) -> void:
	# 防止同种敌人完全重叠：每帧成对推开一半的缺口。
	# 强度取 0.5 让推力是渐进的，视觉上仍然自然、不会瞬移。
	for i in units.size():
		for j in range(i + 1, units.size()):
			var a: Dictionary = units[i]
			var b: Dictionary = units[j]
			var diff: Vector2 = Vector2(a.position) - Vector2(b.position)
			var dist := diff.length()
			if dist < minimum_distance and dist > 0.001:
				var push: Vector2 = diff / dist * (minimum_distance - dist) * 0.5
				a.position = Vector2(a.position) + push
				b.position = Vector2(b.position) - push
				units[i] = a
				units[j] = b
			elif dist <= 0.001:
				# 完全重合：沿随机方向各推开半个最小距离。
				var angle := rng.randf() * TAU
				var offset := Vector2.from_angle(angle) * minimum_distance * 0.5
				a.position = Vector2(a.position) + offset
				b.position = Vector2(b.position) - offset
				units[i] = a
				units[j] = b

func drop_honey_decoy() -> void:
	if carried <= 0:
		message = "投蜜诱饵需要至少携带 1 滴蜜。"
		return
	carried -= 1
	decoys.append({"position": bee.position, "life": 5.0})
	sound.play_cue("decoy")
	message = "一滴蜜落成诱饵，附近蚊虫会暂时改追它。"

func update_decoys(delta: float) -> void:
	for i in range(decoys.size() - 1, -1, -1):
		decoys[i].life = float(decoys[i].life) - delta
		if float(decoys[i].life) <= 0.0:
			return_honey_to_field(1, Vector2(decoys[i].position))
			decoys.remove_at(i)

func nearest_decoy_position(from: Vector2) -> Vector2:
	var best := Vector2.INF
	var best_distance := 230.0
	for decoy in decoys:
		var candidate: Vector2 = decoy.position
		var distance_to_decoy := from.distance_to(candidate)
		if distance_to_decoy < best_distance:
			best_distance = distance_to_decoy
			best = candidate
	return best

func return_honey_to_field(amount: int, origin: Vector2) -> void:
	if amount <= 0:
		return
	for i in flowers.size():
		var flower: Dictionary = flowers[i]
		if bool(flower.get("recovery", false)) and Vector2(flower.position).distance_to(origin) < 130.0:
			flower.nectar = int(flower.nectar) + amount
			flowers[i] = flower
			spawn_pollen(flower.position)
			return
	var recovery_position := Vector2(
		clampf(origin.x + rng.randf_range(-45.0, 45.0), HIVE_SAFE_X + 45.0, WORLD.end.x - 50.0),
		clampf(origin.y + rng.randf_range(-45.0, 45.0), WORLD.position.y + 55.0, WORLD.end.y - 55.0)
	)
	flowers.append({"id": recovery_flower_serial, "position": recovery_position, "nectar": amount, "kind": 1, "phase": rng.randf_range(0, TAU), "recovery": true})
	recovery_flower_serial += 1
	spawn_pollen(recovery_position)

func total_recoverable_honey() -> int:
	var total := delivered + carried
	for flower in flowers:
		total += maxi(0, int(flower.nectar))
	for ant in ants:
		total += maxi(0, int(ant.get("stolen_honey", 0)))
	total += decoys.size()
	return total

func show_energy_change(amount: float) -> void:
	energy_feedback_time = 1.0
	energy_change_label.text = "%+d" % roundi(amount)
	energy_change_label.add_theme_color_override("font_color", Color("b53f35") if amount < 0.0 else Color("4f8758"))

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
	# 失律者上下文从 boss 延续到 boss_victory：调律完成的瞬间，
	# 顶栏与侧栏不应突然切回关卡数据（春分无 goal/flowers，会显示「目标 · 0 滴」的空状态）
	var boss_context := (phase == "boss" or phase == "boss_victory") and not current_boss_data.is_empty()
	if boss_context:
		# 失律者关卡显示其盘踞的正色节点（熊的节点是循环终点：冬至）
		term_label.text = "%s · %s" % [data.season, String(current_boss_data.get("term", data.name))]
	else:
		term_label.text = "%s · %s" % [data.season, data.name]
	carried_label.text = str(carried)
	if boss_context:
		delivered_label.text = "调律 %d / %d" % [int(boss.hits), int(current_boss_data.required_tunings)]
	else:
		delivered_label.text = "%d / %d" % [delivered, int(data.goal)]
	energy_label.text = str(roundi(bee.energy))
	energy_bar_fill.size.x = 166.0 * clampf(bee.energy / 100.0, 0.0, 1.0)
	energy_change_label.modulate.a = clampf(energy_feedback_time * 2.0, 0.0, 1.0)
	if sense_button:
		sense_button.disabled = false
		sense_button.text = "动作"
	hive_label.text = "●".repeat(maxi(0, hive_lives)) + "○".repeat(maxi(0, 3 - hive_lives))
	reserve_label.text = str(hive_reserve)
	message_label.text = message
	if boss_context:
		var boss_data: Dictionary = current_boss_data
		season_label.text = String(boss_data.name)
		detail_label.text = "%s\n\n▸ 调律  %d / %d\n\n引向共鸣点\n再以震翼调律" % [String(boss_data.line), int(boss.hits), int(boss_data.required_tunings)]
	else:
		# 阴阳数值是内部设计依据（驱动节令难度），不向玩家暴露；
		# 用「▸」做状态行节奏符，把敌害收进同一行避免被误读为玩家可选角色。
		season_label.text = data.name
		var threat_parts := []
		var species := [["蚊", "mosquitoes"], ["蚁", "ants"], ["蛐", "crickets"], ["眉", "thrushes"], ["熊", "bears"]]
		for entry in species:
			var count := int(data.get(entry[1], 0))
			if count > 0:
				threat_parts.append("%s %s" % [entry[0], "◆".repeat(mini(count, 4))])
		var threat_row := "▸ 敌害 · " + ("  ".join(threat_parts) if not threat_parts.is_empty() else "无（寒冷与匮乏本身）")
		var status_rows := "▸ 目标 · %d 滴\n%s" % [int(data.goal), threat_row]
		if season_index_of(stage_index) == 3:
			status_rows += "\n▸ 体温 · %d%%  储蜜 · %d 滴" % [roundi(warmth), hive_reserve]
		detail_label.text = "%s\n\n%s" % [data.line, status_rows]

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		toggle_pause()
		get_viewport().set_input_as_handled()
		return
	# 弹窗阶段允许键盘确认（Enter/空格）：切走程序回来后不依赖鼠标重按按钮
	if event.is_action_pressed("ui_accept") and overlay.visible and overlay_button.visible:
		if phase == "boss_victory" or phase == "won" or phase == "lost" or phase == "intro":
			on_overlay_button()
			get_viewport().set_input_as_handled()
			return
	if phase != "playing" and phase != "boss":
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if WORLD.has_point(event.position):
			bee.set_move_target(event.position)

# 切走程序时自动暂停（体力照扣、失律者照追是设计事故）；
# 切回来时把焦点交还主按钮，键盘 Enter 可直接继续。
# toggle_pause 内部有相位护栏，between/boss_victory 等静态界面不会被误暂停覆盖。
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		toggle_pause()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		if overlay_button != null and overlay.visible and overlay_button.visible:
			overlay_button.grab_focus()

func on_sense_started() -> void:
	message = "触角捕捉到蜜量、敌虫警戒范围和一条相对安全的采集方向。"

func best_foraging_target() -> int:
	var best := -1
	var best_score := -INF
	for i in flowers.size():
		var flower: Dictionary = flowers[i]
		if int(flower.nectar) <= 0 or bool(flower.get("sleeping", false)) or float(flower.get("flatten_time", 0.0)) > 0.0:
			continue
		var score := float(flower.nectar) * 42.0 - bee.position.distance_to(flower.position) * 0.12
		for mosquito in mosquitoes:
			var danger_distance := Vector2(flower.position).distance_to(mosquito.position)
			if danger_distance < balance_value("mosquito", "sense_range", 330.0):
				score -= (330.0 - danger_distance) * 0.35
		for ant in ants:
			var ant_distance := Vector2(flower.position).distance_to(ant.position)
			if ant_distance < 180.0:
				score -= (180.0 - ant_distance) * 0.18
		# 油葫芦的突进警戒圈：静止时也随时可能弹跳过来
		for cricket in crickets:
			var cricket_distance := Vector2(flower.position).distance_to(cricket.position)
			if cricket_distance < balance_value("cricket", "sense_range", 220.0):
				score -= (220.0 - cricket_distance) * 0.2
		# 熊的碾压半径：花随时会被压平，风险远高于虫害
		for bear_unit in bears:
			var bear_distance := Vector2(flower.position).distance_to(bear_unit.position)
			if bear_distance < balance_value("bear", "flatten_radius", 30.0) + 90.0:
				score -= (balance_value("bear", "flatten_radius", 30.0) + 90.0 - bear_distance) * 0.5
		if score > best_score:
			best_score = score
			best = i
	return best

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
	if not stages.is_empty() and save_manager.best_stage >= stages.size():
		return "二十四节令已归律"
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
	draw_string(zh_font, Vector2(58, 176), "蜂 巢", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("fff1bd"))
	draw_string(zh_font, Vector2(57, 661), "撤 离 区", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("d8d4b8"))

	var deep := stage_color(2)
	for i in 34:
		var x := WORLD.position.x + fmod(float(i * 97 + stage_index * 31), WORLD.size.x)
		var y := 570.0 + sin(float(i) * 2.1) * 60.0
		draw_line(Vector2(x, WORLD.end.y), Vector2(x + 10, y), Color(deep, 0.2), 3)

	for flower in flowers:
		draw_flower(flower)
	for phantom in phantom_flowers:
		draw_phantom_flower(phantom)
	for ant in ants:
		draw_ant_trail(ant)
	for mosquito in mosquitoes:
		draw_mosquito(mosquito)
	for ant in ants:
		draw_ant(ant)
	for afterimage in field_afterimages:
		var a_pos: Vector2 = afterimage.position
		draw_circle(a_pos, 8, Color("6d5a35", clampf(float(afterimage.life) / balance_value("cricket", "afterimage_life", 0.5), 0.0, 0.4)))
	for cricket in crickets:
		draw_cricket(cricket)
	for thrush in thrushes:
		draw_thrush(thrush)
	for bear_unit in bears:
		draw_bear_unit(bear_unit)
	if phase == "boss" or phase == "boss_victory":
		for bloom in tuning_blooms:
			draw_tuning_bloom(bloom)
		draw_boss(boss)
	for mote in pollen:
		draw_circle(mote.position, 2.5, Color(stage_color(3), clampf(float(mote.life) * 2.0, 0, 1)))
	for decoy in decoys:
		var decoy_position: Vector2 = decoy.position
		draw_circle(decoy_position, 8.0, Color("e8b83f", 0.9))
		draw_arc(decoy_position, 18.0 + sin(elapsed * 7.0) * 3.0, 0, TAU, 24, Color("fff1a8", 0.75), 2)
	if bee.sense_time > 0.0 and (phase == "playing" or phase == "boss"):
		var recommended := best_foraging_target()
		for i in flowers.size():
			var flower: Dictionary = flowers[i]
			if int(flower.nectar) <= 0 or bool(flower.get("sleeping", false)) or float(flower.get("flatten_time", 0.0)) > 0.0:
				continue
			var is_best := i == recommended
			draw_line(bee.position, flower.position, Color("fff0a0", 0.42 if is_best else 0.12), 3.0 if is_best else 1.0)
			var badge_position: Vector2 = flower.position + Vector2(0, -29)
			draw_circle(badge_position, 10, Color("26392f", 0.88))
			draw_string(zh_font, badge_position + Vector2(-8, 5), str(flower.nectar), HORIZONTAL_ALIGNMENT_CENTER, 16, 12, Color("fff4bf"))
			if is_best:
				draw_arc(flower.position, 38, 0, TAU, 32, Color("fff0a0", 0.9), 3)
		for mosquito in mosquitoes:
			draw_arc(mosquito.position, balance_value("mosquito", "sense_range", 330.0), 0, TAU, 64, Color("9d4238", 0.15), 2)
		for ant in ants:
			draw_circle(ant.position, 26, Color("74452d", 0.15), false, 2)
		for cricket in crickets:
			draw_arc(cricket.position, balance_value("cricket", "sense_range", 220.0), 0, TAU, 48, Color("9d4238", 0.13), 2)
		for bear_unit in bears:
			draw_circle(bear_unit.position, balance_value("bear", "flatten_radius", 30.0) + 6.0, Color("5c4433", 0.16), false, 3)
		draw_line(bee.position, Vector2(HIVE_X, bee.position.y), Color("fff0a0", 0.55), 3)
	var nearby := nearest_flower(46.0)
	if nearby >= 0 and phase == "playing":
		var flower: Dictionary = flowers[nearby]
		draw_arc(flower.position, 32 + sin(elapsed * 6.0) * 3, 0, TAU, 28, stage_color(3), 2)
		draw_string(zh_font, flower.position + Vector2(-30, -42), "按住空格采蜜", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, deep)
	if flash > 0:
		draw_rect(WORLD, Color("fff1b0", flash * 0.25))
	season_mechanics.draw()
	draw_set_transform(Vector2.ZERO)

func draw_flower(flower: Dictionary) -> void:
	var pos: Vector2 = flower.position
	var sleeping := bool(flower.get("sleeping", false))
	var newly_open := bool(flower.get("newly_open", false))
	var alive := int(flower.nectar) > 0 and not sleeping
	var recovery := bool(flower.get("recovery", false))
	var alpha := 1.0 if alive else 0.28
	if sleeping:
		draw_line(pos + Vector2(0, 16), pos + Vector2(0, 45), Color(stage_color(2), 0.35), 3)
		draw_circle(pos + Vector2(0, 14), 5, Color("3d4a3a", 0.55))
		draw_arc(pos, 13, 0, TAU, 16, Color(stage_color(2), 0.4), 2)
		draw_string(zh_font, pos + Vector2(-15, 66), "休眠", HORIZONTAL_ALIGNMENT_CENTER, 30, 11, Color(stage_color(2), 0.8))
		return
	if float(flower.get("flatten_time", 0.0)) > 0.0:
		# 被熊压平：花没有死，flatten_time 走完后会重新立起
		var petal_color := Color(FLOWER_COLORS[int(flower.kind)], 0.38)
		draw_line(pos + Vector2(0, 16), pos + Vector2(0, 38), Color(stage_color(2), 0.28), 2)
		draw_circle(pos + Vector2(-7, 3), 6, petal_color)
		draw_circle(pos + Vector2(6, 6), 5, petal_color)
		draw_circle(pos + Vector2(0, 9), 4, Color(stage_color(3), 0.35))
		draw_line(pos + Vector2(-18, 13), pos + Vector2(20, 13), Color("5c4433", 0.5), 3)
		draw_string(zh_font, pos + Vector2(-15, 66), "压平", HORIZONTAL_ALIGNMENT_CENTER, 30, 11, Color("8a6a4d", 0.9))
		return
	draw_line(pos + Vector2(0, 16), pos + Vector2(0, 45), Color(stage_color(2), alpha), 3)
	for petal in 5:
		var angle := float(petal) * TAU / 5.0 + float(flower.phase)
		draw_circle(pos + Vector2.from_angle(angle) * 11, 7, Color(FLOWER_COLORS[int(flower.kind)], alpha))
	draw_circle(pos, 6, Color(stage_color(3), alpha))
	if recovery and alive:
		draw_arc(pos, 24 + sin(elapsed * 4.0) * 2.0, 0, TAU, 24, Color("fff1a8", 0.9), 3)
		draw_string(zh_font, pos + Vector2(-22, 66), "返蜜", HORIZONTAL_ALIGNMENT_CENTER, 44, 11, Color("fff1a8"))
	if newly_open and alive:
		draw_arc(pos, 26 + sin(elapsed * 5.0) * 2.0, 0, TAU, 24, Color("fff1a8", 0.8), 2)
		draw_string(zh_font, pos + Vector2(-15, 66), "新开", HORIZONTAL_ALIGNMENT_CENTER, 30, 11, Color("fff1a8"))
	if not alive:
		draw_line(pos + Vector2(-14, 49), pos + Vector2(14, 49), Color(stage_color(2), 0.45), 2)

func draw_mosquito(mosquito: Dictionary) -> void:
	var pos: Vector2 = mosquito.position
	var repelled := float(mosquito.repel_time) > 0.0
	draw_circle(pos, 9, Color("b77b3e") if repelled else Color("402e34"))
	draw_line(pos + Vector2(-5, -4), pos + Vector2(-15, -12), Color("f5f2df", 0.7), 3)
	draw_line(pos + Vector2(5, 4), pos + Vector2(15, 12), Color("f5f2df", 0.7), 3)
	if repelled:
		var ratio := clampf(float(mosquito.repel_time) / balance_value("player", "repel_duration", 3.5), 0.0, 1.0)
		draw_line(pos + Vector2(10, -4), pos + Vector2(25, -4), Color("fff0aa", 0.7), 2)
		draw_line(pos + Vector2(10, 4), pos + Vector2(25, 4), Color("fff0aa", 0.7), 2)
		draw_rect(Rect2(pos + Vector2(-18, -27), Vector2(36, 5)), Color("332b27", 0.75))
		draw_rect(Rect2(pos + Vector2(-17, -26), Vector2(34 * ratio, 3)), Color("e9b84f"))

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
	if fleeing:
		var ratio := clampf(float(ant.flee_time) / 1.8, 0.0, 1.0)
		draw_rect(Rect2(pos + Vector2(-18, -24), Vector2(36, 5)), Color("332b27", 0.75))
		draw_rect(Rect2(pos + Vector2(-17, -23), Vector2(34 * ratio, 3)), Color("e9b84f"))
	if int(ant.get("stolen_honey", 0)) > 0:
		draw_string(zh_font, pos + Vector2(-18, -30), "蜜%d" % int(ant.stolen_honey), HORIZONTAL_ALIGNMENT_CENTER, 36, 11, Color("f4ce67"))

func draw_ant_trail(ant: Dictionary) -> void:
	# 信息素迹：蚁沿固定的巢—花往返线巡逻，虚线点提示玩家可预判
	var points: Array = ant.get("trail", [])
	if points.size() < 2:
		return
	for i in points.size() - 1:
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		var length := a.distance_to(b)
		var steps := maxi(2, int(length / 34.0))
		for step_i in steps:
			var ratio := (float(step_i) + 0.5) / float(steps)
			var dot_position := a.lerp(b, ratio)
			var pulse := 0.14 + 0.08 * sin(elapsed * 3.0 + float(i) + float(step_i) * 0.8)
			draw_circle(dot_position, 2.0, Color("74452d", pulse))

func draw_phantom_flower(phantom: Dictionary) -> void:
	# 画眉的幻花：外形与真花一致，唯有花心颜色偏灰绿是唯一破绽
	var pos: Vector2 = phantom.position
	draw_line(pos + Vector2(0, 16), pos + Vector2(0, 45), Color(stage_color(2), 0.85), 3)
	for petal in 5:
		var angle := float(petal) * TAU / 5.0 + float(phantom.phase)
		draw_circle(pos + Vector2.from_angle(angle) * 11, 7, Color(FLOWER_COLORS[int(phantom.kind)]))
	draw_circle(pos, 6, Color("cfe0b4"))

func draw_cricket(cricket: Dictionary) -> void:
	# 油葫芦：三节躯体 + 后腿；静止蓄力、突进时留残影
	var pos: Vector2 = cricket.position
	var hopping := bool(cricket.hopping)
	var repelled := float(cricket.repel_time) > 0.0
	var body := Color("8d7f4a") if repelled else Color("4f4a2c")
	if hopping:
		body = Color("6d6438")
	draw_circle(pos + Vector2(-8, 0), 5, body)
	draw_circle(pos + Vector2(0, 0), 6, body)
	draw_circle(pos + Vector2(8, -1), 4, body)
	draw_line(pos + Vector2(-8, -3), pos + Vector2(-17, -11), body, 2)
	draw_line(pos + Vector2(8, -3), pos + Vector2(17, -11), body, 2)
	# 粗壮后腿（跳跃足）
	for side in [-1, 1]:
		draw_line(pos + Vector2(-4, 3 * side), pos + Vector2(-10, 12 * side), body, 3)
		draw_line(pos + Vector2(-10, 12 * side), pos + Vector2(1, 8 * side), body, 3)
	if not hopping:
		var charge_ratio := 1.0 - clampf(float(cricket.hop_clock) / balance_value("cricket", "rest_seconds", 1.2), 0.0, 1.0)
		draw_rect(Rect2(pos + Vector2(-16, -25), Vector2(32, 4)), Color("332b27", 0.7))
		draw_rect(Rect2(pos + Vector2(-15, -24), Vector2(30 * charge_ratio, 2)), Color("d9c26a"))
	if repelled:
		draw_line(pos + Vector2(12, -4), pos + Vector2(26, -4), Color("fff0aa", 0.7), 2)
		draw_line(pos + Vector2(12, 4), pos + Vector2(26, 4), Color("fff0aa", 0.7), 2)

func draw_thrush(thrush: Dictionary) -> void:
	# 画眉：地栖鸟，栖在花田中低处，鸣唱间隔催生幻花
	var pos: Vector2 = thrush.position
	var silenced := float(thrush.silence_time) > 0.0
	var body := Color("8a6f52") if silenced else Color("6b543d")
	draw_circle(pos, 10, body)
	draw_circle(pos + Vector2(9, -5), 6, body)
	draw_circle(pos + Vector2(11.5, -5.5), 1.6, Color("2c231b"))
	draw_line(pos + Vector2(14, -4), pos + Vector2(22, -2), Color("4a3a29"), 3)
	# 眉线（名字来源）
	draw_line(pos + Vector2(6, -8), pos + Vector2(14, -7), Color("e8dcc2"), 2)
	# 尾羽
	draw_line(pos + Vector2(-9, 0), pos + Vector2(-19, 4), body, 4)
	for side in [-1, 1]:
		draw_line(pos + Vector2(-2, 6 * side), pos + Vector2(-8, 13 * side), Color("4a3a29"), 2)
	if not silenced:
		var note_phase := elapsed * 2.5
		for i in 2:
			var note_pos := pos + Vector2(-14.0 - i * 10.0, -14.0 - sin(note_phase + i * 1.7) * 4.0)
			draw_circle(note_pos, 2.4, Color("e8dcc2", 0.75))
			draw_line(note_pos + Vector2(2, -1), note_pos + Vector2(2, -7), Color("e8dcc2", 0.75), 1.5)
	else:
		draw_string(zh_font, pos + Vector2(-15, -22), "噤声", HORIZONTAL_ALIGNMENT_CENTER, 30, 10, Color("e8dcc2", 0.85))

func draw_bear_unit(bear_unit: Dictionary) -> void:
	# 熊：不可对抗的移动地形，压平花、直取储蜜
	var pos: Vector2 = bear_unit.position
	var state := String(bear_unit.state)
	var body := Color("4a3a30")
	var gait := sin(elapsed * 4.0) * 2.0 if state != "feeding" else 0.0
	draw_circle(pos + Vector2(0, 0), 20, body)
	draw_circle(pos + Vector2(-16, -6 + gait * 0.3), 12, body)
	draw_circle(pos + Vector2(-13, -14), 4, Color("2e231c"))
	draw_circle(pos + Vector2(-19, -13), 4, Color("2e231c"))
	draw_circle(pos + Vector2(-18, -6), 5, Color("8a6f52"))
	for side in [-1, 1]:
		draw_circle(pos + Vector2(8, 14 * side), 8, body)
		draw_circle(pos + Vector2(-8, 14 * side), 8, body)
	if state == "feeding":
		var eat_pulse := 0.5 + 0.5 * sin(elapsed * 6.0)
		draw_arc(pos + Vector2(-16, -6), 24 + eat_pulse * 4.0, PI * 0.75, PI * 1.6, 16, Color("e9b84f", 0.6 * eat_pulse + 0.2), 2)
		draw_string(zh_font, pos + Vector2(-24, -34), "吞蜜 %d/%d" % [int(bear_unit.eaten), int(balance_value("bear", "appetite", 3))], HORIZONTAL_ALIGNMENT_CENTER, 48, 11, Color("e9b84f"))
	elif state == "leaving":
		draw_string(zh_font, pos + Vector2(-12, -34), "饱足", HORIZONTAL_ALIGNMENT_CENTER, 24, 11, Color("b7a98c"))
	else:
		draw_string(zh_font, pos + Vector2(-12, -34), "压平花田", HORIZONTAL_ALIGNMENT_CENTER, 48, 11, Color("c9a06a", 0.9))

func draw_tuning_bloom(pos: Vector2) -> void:
	var bloom_color := Color(String(current_boss_data.get("bloom_color", "fff0a0"))) if not current_boss_data.is_empty() else Color("fff0a0")
	var pulse := 28.0 + sin(elapsed * 4.0) * 4.0
	draw_circle(pos, 18, Color(bloom_color, 0.24))
	draw_arc(pos, pulse, 0, TAU, 32, Color(bloom_color, 0.75), 3)
	for i in 8:
		var angle := float(i) * TAU / 8.0 + elapsed * 0.25
		draw_circle(pos + Vector2.from_angle(angle) * pulse, 3, Color(bloom_color, 0.85))

func draw_boss(state: Dictionary) -> void:
	if current_boss_data.is_empty():
		return
	var data: Dictionary = current_boss_data
	var pos: Vector2 = state.position
	var radius := float(data.size) + sin(elapsed * 5.0) * 2.0
	var body := Color(String(data.body_color))
	var accent := Color(String(data.accent_color))
	for afterimage in boss_afterimages:
		var a_pos: Vector2 = afterimage.position
		draw_circle(a_pos, radius * 0.8, Color(body, clampf(float(afterimage.life) * 1.6, 0.0, 0.4)))
	match String(data.move_pattern):
		"orbital":
			# 蚊：圆躯 + 长口器
			draw_circle(pos, radius, body)
			draw_circle(pos + Vector2(radius * 0.8, 0), radius * 0.45, accent)
			draw_line(pos + Vector2(radius * 1.1, 0), pos + Vector2(radius * 1.9, -2), Color("2e2327"), 4)
			draw_arc(pos, radius + 9, -2.4, 2.4, 22, Color("d7b56a", 0.55), 3)
		"erratic":
			# 油葫芦：三节躯体 + 长触角
			draw_circle(pos + Vector2(-radius * 0.55, 2), radius * 0.42, body)
			draw_circle(pos + Vector2(radius * 0.2, 0), radius * 0.6, body)
			draw_circle(pos + Vector2(radius * 0.8, -1), radius * 0.3, accent)
			for side in [-1, 1]:
				draw_line(pos + Vector2(-radius * 0.3, 2.0 * side), pos + Vector2(-radius * 1.2, radius * 0.8 * side), accent, 3)
				draw_line(pos + Vector2(radius * 0.4, 2.0 * side), pos + Vector2(radius * 1.3, radius * 0.9 * side), accent, 3)
			draw_line(pos + Vector2(radius * 0.9, -4), pos + Vector2(radius * 1.7, -14), body, 2)
			draw_line(pos + Vector2(radius * 0.9, 2), pos + Vector2(radius * 1.8, -4), body, 2)
		"lure":
			# 画眉：鸟身 + 喙 + 振翅弧线 + 漂浮音符
			draw_circle(pos, radius, body)
			draw_circle(pos + Vector2(radius * 0.55, -radius * 0.3), radius * 0.16, Color("fff4bd"))
			draw_line(pos + Vector2(radius, 0), pos + Vector2(radius * 1.7, radius * 0.15), Color("e8c47a"), 4)
			var flap := sin(elapsed * 9.0) * 0.25
			draw_arc(pos + Vector2(-radius * 0.2, -radius * 0.4), radius * 0.85, PI * (1.05 + flap), PI * (1.95 - flap), 12, accent, 3)
			draw_arc(pos + Vector2(-radius * 0.2, radius * 0.4), radius * 0.85, PI * (0.05 - flap), PI * (0.95 + flap), 12, accent, 3)
			for i in 3:
				var note_pos := pos + Vector2(-radius * 1.5 - i * 14.0, -radius * 0.9 - sin(elapsed * 3.0 + i) * 6.0)
				draw_circle(note_pos, 3, Color(accent, 0.8))
				draw_line(note_pos + Vector2(3, -1), note_pos + Vector2(3, -9), Color(accent, 0.8), 2)
		"charge":
			# 熊：大圆身 + 双耳 + 口鼻；蓄势时画出冲撞预告线，晕眩时头顶提示
			var charge_state := String(state.get("charge_state", "wander"))
			if charge_state == "aim":
				var aim: Vector2 = state.get("aim_direction", Vector2.RIGHT)
				draw_line(pos, pos + aim * 340.0, Color("e05a4a", 0.55), 4)
			draw_circle(pos + Vector2(-radius * 0.55, -radius * 0.6), radius * 0.32, body)
			draw_circle(pos + Vector2(radius * 0.55, -radius * 0.6), radius * 0.32, body)
			draw_circle(pos, radius, body)
			draw_circle(pos + Vector2(0, radius * 0.25), radius * 0.34, accent)
			draw_circle(pos + Vector2(-radius * 0.28, radius * 0.18), radius * 0.07, Color("1c222b"))
			draw_circle(pos + Vector2(radius * 0.28, radius * 0.18), radius * 0.07, Color("1c222b"))
			if charge_state == "rest":
				draw_string(zh_font, pos + Vector2(-22, -radius - 12), "晕眩", HORIZONTAL_ALIGNMENT_CENTER, 44, 12, Color("f5d975"))
	for i in int(state.hits):
		draw_circle(pos + Vector2(-12 + i * 12, -radius - 30), 4, Color("f5d975"))
