extends Node2D

const WORLD := Rect2(34, 146, 970, 538)
const HIVE_SAFE_X := 225.0
const HIVE_ENTRY_AREA := Rect2(34, 350, 176, 120)
const FLOWER_COLORS := [Color("f2d66f"), Color("e9aab1"), Color("a995c9")]
const FLOWER_TYPE_COLORS := {
	"nectar_bloom": Color("f2d66f"),
	"first_bloom": Color("c8e89a"),
	"chain_bloom": Color("e8a0d4"),
	"peak_bloom": Color("e07845"),
	"fading_bloom": Color("b89070"),
	"late_bloom": Color("d4b060"),
	"seed_bloom": Color("a8c878"),
	"hidden_bloom": Color("8899bb"),
	"warmth_bloom": Color("e8a06a"),
	"frozen_bloom": Color("a0c4d4"),
	"cascade_bloom": Color("cc66aa")
}
const TERMS := ["立春", "雨水", "惊蛰", "春分", "清明", "谷雨", "立夏", "小满", "芒种", "夏至", "小暑", "大暑", "立秋", "处暑", "白露", "秋分", "寒露", "霜降", "立冬", "小雪", "大雪", "冬至", "小寒", "大寒"]
const SEASON_LENGTH := 6
const UPGRADE_CAP := 6
const SeasonMechanicsScript := preload("res://scripts/mechanics/season_mechanics.gd")
const BossEncounterDirectorScript := preload("res://scripts/boss_encounter_director.gd")
const ProductionHUDScript := preload("res://scripts/ui/production_hud.gd")
const RelayHiveMechanicScript := preload("res://scripts/mechanics/relay_hive_mechanic.gd")
const MentorTutorialScript := preload("res://scripts/tutorial/mentor_tutorial.gd")
const EvadeRulesScript := preload("res://scripts/mechanics/evade_rules.gd")
const EvadeInputControllerScript := preload("res://scripts/player/evade_input_controller.gd")
const JOURNEY_SCENE := preload("res://journey.tscn")
const CommercialMenuScript := preload("res://scripts/ui/commercial_system_menu.gd")
const FLOWER_COMMON_TEXTURE := preload("res://assets/art/flower_textile_common.svg")
const FLOWER_HIGH_VALUE_TEXTURE := preload("res://assets/art/flower_textile_high_value.svg")
const HIVE_ENTRANCE_TEXTURE := preload("res://assets/art/hive_textile_entrance.svg")
const FIELD_TEXTILE_OVERLAY := preload("res://assets/art/field_textile_overlay.svg")
const SPRING_FIELD_PATH := "res://assets/art/launch/spring_field_v2.png"
const SPRING_FLOWER_COMMON_PATH := "res://assets/art/launch/flower_common_v1.png"
const SPRING_FLOWER_HIGH_VALUE_PATH := "res://assets/art/launch/flower_high_value_v1.png"
const SPRING_HIVE_ENTRANCE_PATH := "res://assets/art/launch/hive_city_entrance_v1.png"
const SPRING_MOSQUITO_PATH := "res://assets/art/launch/mosquito_v1.png"
const COLONY_BEE_PATH := "res://assets/art/launch/player_bee_v1.png"
const BUILD_PROVENANCE_PATH := "res://data/build_provenance.json"
const SEASON_FLOWER_TEXTURES := {
	"summer": [
		preload("res://assets/art/seasonal/summer_hibiscus_v1.png"),
		preload("res://assets/art/seasonal/summer_sunflower_v1.png")
	],
	"autumn": [
		preload("res://assets/art/seasonal/autumn_aster_v1.png"),
		preload("res://assets/art/seasonal/autumn_chrysanthemum_v1.png")
	],
	"winter": [
		preload("res://assets/art/seasonal/winter_camellia_v1.png"),
		preload("res://assets/art/seasonal/winter_wintersweet_v1.png")
	]
}

var stages: Array = []
var balance: Dictionary = {}
var spring_field_texture: Texture2D
var spring_flower_common_texture: Texture2D
var spring_flower_high_value_texture: Texture2D
var spring_hive_entrance_texture: Texture2D
var spring_mosquito_texture: Texture2D
var colony_bee_texture: Texture2D
var field_draw_offset := Vector2.ZERO
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
var boss_director = BossEncounterDirectorScript.new()
var boss_hive_heals_remaining := 2
var boss_hive_was_inside := false
var pollen: Array = []
var decoys: Array = []
var recovery_flower_serial := 1000
var carried := 0
# 显式饮蜜：本节气已饮下的续力次数，每节气出勤开始时重置（上限 crop_fuel_limit）
var crop_fuel_used := 0
var delivered := 0
var hive_lives := 3
var harvest_clock := 0.0
var sting_cooldown := 0.0
var hit_cooldown := 0.0
var was_in_hive := false
# 入巢卸蜜延迟：落巢后需站稳 hive_deposit_delay 秒才开始卸蜜（防蹭巢速存速撤）
var hive_dwell_time := 0.0
var harvest_multiplier := 1.0
# 蜜囊携带上限：满额时停下采蜜。采蜜蜂成长每级 +3。
var carry_capacity := 8.0
var sting_range := 88.0
var sting_cost := 8.0
var sting_cooldown_multiplier := 1.0
var extra_nectar := 0
var elapsed := 0.0
var run_elapsed := 0.0
var shake := 0.0
var commercial_screen_shake_enabled := true
var flash := 0.0
var message := "飞向花朵，采蜜后亲自返回左侧蜂巢。"
var action_hold_time := 0.0
var action_decoy_fired := false
var action_was_harvesting := false
var evade_input_controller = EvadeInputControllerScript.new()
# Compatibility accessors keep tests and snapshot tooling on the old Main API
# while the authoritative caches now live in the reusable input controller.
var last_dir_tap: Dictionary:
	get:
		return evade_input_controller.direction_tap_times
	set(value):
		evade_input_controller.direction_tap_times = value
var last_dir_tap_origin: Dictionary:
	get:
		return evade_input_controller.direction_tap_origins
	set(value):
		evade_input_controller.direction_tap_origins = value
var last_world_tap_time: float:
	get:
		return evade_input_controller.world_tap_time
	set(value):
		evade_input_controller.world_tap_time = value
var last_world_tap_direction: Vector2:
	get:
		return evade_input_controller.world_tap_direction
	set(value):
		evade_input_controller.world_tap_direction = value
var last_world_tap_position: Vector2:
	get:
		return evade_input_controller.world_tap_position
	set(value):
		evade_input_controller.world_tap_position = value
var last_world_tap_origin: Vector2:
	get:
		return evade_input_controller.world_tap_origin
	set(value):
		evade_input_controller.world_tap_origin = value
const DOUBLE_TAP_WINDOW := EvadeRulesScript.DOUBLE_TAP_WINDOW
const EVADE_PATH_CLEARANCE := EvadeRulesScript.PATH_CLEARANCE
const EVADE_LOCK_ORIGIN_TOLERANCE := EvadeRulesScript.LOCK_ORIGIN_TOLERANCE
const WORLD_TAP_REPEAT_RADIUS := EvadeRulesScript.WORLD_TAP_REPEAT_RADIUS
const DECOY_HOLD_THRESHOLD := 0.5
const HIVE_RETURN_POS := Vector2(150, 410)
var rng := RandomNumberGenerator.new()
var save_manager := NamelessSaveManager.new()
var sound := SoundFeedback.new()
var music := MusicDirector.new()
var paused_from_phase := "playing"
var lost_from_phase := "playing"
var persistence_enabled := true

# 花物候学：花型配置与连环花状态
var flower_configs: Dictionary = {}
var chain_timer := 0.0
var chain_last_index := -1
var chain_bonus_count := 0
var chain_window_s := 2.0
var chain_cap := 3
var chain_range_px := 120.0
var chain_harvest_bonus := 1

var title_label: Label
var term_label: Label
var carried_label: Label
var delivered_title_label: Label
var delivered_label: Label
var energy_label: Label
var hive_label: Label
var message_label: Label
var detail_label: Label
var overlay: ColorRect
var overlay_title: Label
var overlay_body: Label
var overlay_button: Button
var secondary_link: Button
var build_provenance_label: Label
var title_settings_button: Button
var title_credits_button: Button
var title_exit_button: Button
var commercial_system_menu: CommercialSystemMenu
var new_journey_confirmation_armed := false
var upgrade_buttons: Array[Button] = []
# 历史信息是「持久状态」（跨 run 的轮回计数 + 最远记录），
# 属于 HUD 侧栏常驻元素 runs_meter，不寄生在 overlay 弹窗里——
# overlay_history 这个独立 Label 在 PR #12 临时补救时被引进来，
# 生命周期写在 show_intro 但从未关闭，会跟着 overlay 浮到 upgrade 界面
# 直接压在升级卡片上造成视觉错位（背景碎片化、读不清）。
var runs_meter: Label
var runs_meter_farthest: Label
var zh_font: Font
var pause_button: Button
var production_hud: ProductionHUD
var fullscreen_button: Button
var sound_button: Button
var quit_button: Button
var sense_button: Button
var return_button: Button
var drink_button: Button
var drink_touch_index := -1
var drink_touch_armed := false
var context_hint_label: Label
var tutorial_panel: ColorRect
var tutorial_title: Label
var tutorial_body: Label
var pause_system_buttons: Array[Button] = []
var energy_bar: ColorRect
var energy_bar_fill: ColorRect
var season_label: Label
var season_rule: ColorRect
var energy_change_label: Label
var energy_feedback_time := 0.0
# 代价可见性演出：蜜囊续命时体力条短暂提亮，扣蜂巢命时圆点闪红
var energy_bar_flash_time := 0.0
# 蜜囊满额：携带条闪红，替代每帧飘字
var carry_full_flash_time := 0.0
var hive_flash_time := 0.0
var reserve_label: Label
var season_mechanics
var relay_hive = RelayHiveMechanicScript.new()
var relay_was_resting := false
var mentor_tutorial = MentorTutorialScript.new()
var hive_reserve := 0
var larval_boost := 0
var warmth := 100.0
var energy_cap_override := 100.0
# 力竭停顿拍：体力见底先静止展示 0 与损失清单，再回巢重置
var exhaustion_timer := 0.0
var cold_warmth_threshold := 15.0
var allocation_panel: Control
var allocation_body_label: Label
var allocation_left_label: Label
var allocation_right_label: Label
var allocation_slider: HSlider
var allocation_confirm: Button
var allocation_pending := false
var allocation_harvest := 0
var allocation_fraction := 0.5
var last_overlay_focus: Control
var overlay_focus_restore_queued := false
var boss_catalog: Array = []
var current_boss_data: Dictionary = {}
var current_boss_index := 0
var boss_afterimages: Array = []
var preserve_warmth := false
var tutorial_step := 0
var tutorial_origin := Vector2.ZERO
var tutorial_complete := false
var tutorial_hidden_index := -1
var tutorial_resource_index := -1
var tutorial_resource_position := Vector2.ZERO
var tutorial_scent_revealed := false
var tutorial_charge_state := "idle"
var tutorial_charge_time := 0.0
var tutorial_charge_direction := Vector2.LEFT
var tutorial_failed_crossings := 0
var evade_confirmation_time := 0.0
var evade_confirmation_position := Vector2.ZERO
var evade_confirmation_direction := Vector2.LEFT
var context_lesson_id := ""
var context_lesson_time := 0.0
var context_lessons_seen := {"sense": false, "danger": false, "low_energy": false}
var hive_activity_time := 0.0
var build_product_version := ""
var build_commit := ""
var playtest_session_context: Dictionary = {}

func configure_playtest_session(context: Dictionary) -> Error:
	if is_inside_tree() or not playtest_session_context.is_empty():
		return ERR_ALREADY_IN_USE
	var expected_keys: Array[String] = ["artifact", "catalog_sha256", "product", "schema_version", "session_id", "slice", "task", "ticket_sha256"]
	var actual_keys: Array[String] = []
	for key in context.keys():
		actual_keys.append(String(key))
	actual_keys.sort()
	expected_keys.sort()
	if actual_keys != expected_keys:
		return ERR_INVALID_DATA
	if context.get("schema_version") != 1 or not context.get("task") is Dictionary:
		return ERR_INVALID_DATA
	var task: Dictionary = context.task
	var task_keys: Array[String] = []
	for key in task.keys():
		task_keys.append(String(key))
	task_keys.sort()
	if task_keys != ["code", "slice_code"] or task.get("code") != "B" or not task.get("slice_code") is String:
		return ERR_INVALID_DATA
	if not context.get("slice") is Dictionary or not context.get("product") is Dictionary or not context.get("artifact") is Dictionary:
		return ERR_INVALID_DATA
	var slice: Dictionary = context.slice
	var slice_keys: Array[String] = []
	for key in slice.keys():
		slice_keys.append(String(key))
	slice_keys.sort()
	if slice_keys != ["assignment", "code", "maximum_minutes", "status"] or slice.get("code") != task.slice_code or slice.get("status") != "ready":
		return ERR_INVALID_DATA
	var catalog_pattern := RegEx.new()
	if catalog_pattern.compile("^[0-9a-f]{64}$") != OK or catalog_pattern.search(String(context.get("catalog_sha256", ""))) == null:
		return ERR_INVALID_DATA
	var namespace_error := save_manager.configure_playtest_namespace(String(context.get("ticket_sha256", "")))
	if namespace_error != OK:
		return namespace_error
	playtest_session_context = context.duplicate(true)
	return OK

func _ready() -> void:
	zh_font = load("res://fonts/NotoSansCJKsc-ProjectSubset.otf")
	if zh_font == null:
		push_warning("无法加载中文字体，将使用回退字体")
	rng.randomize()
	ensure_keyboard_controls()
	save_manager.load_data()
	apply_display_settings()
	load_stage_data()
	load_balance_data()
	load_flower_data()
	load_upgrade_data()
	load_boss_data()
	load_spring_launch_art()
	load_build_provenance()
	bee = BeePlayer.new()
	bee.position = Vector2(180, 410)
	bee.max_energy = balance_value("player", "max_energy", 100.0)
	bee.evade_invuln = balance_value("player", "evade_invuln_seconds", 0.18)
	bee.sense_started.connect(on_sense_started)
	add_child(bee)
	add_child(sound)
	sound.set_enabled(save_manager.sound_enabled)
	add_child(music)
	music.set_enabled(save_manager.sound_enabled)
	build_interface()
	var commercial_persistence := _commercial_persistence()
	if commercial_persistence != null:
		commercial_system_menu = CommercialMenuScript.new()
		commercial_system_menu.name = "CommercialSystemMenu"
		commercial_system_menu.configure(commercial_persistence)
		add_child(commercial_system_menu)
		commercial_system_menu.quit_requested.connect(func(): get_tree().quit())
		commercial_system_menu.menu_closed.connect(_on_title_system_menu_closed)
		commercial_persistence.settings_changed.connect(_apply_title_commercial_settings)
		commercial_persistence.apply_runtime_settings()
		_apply_title_commercial_settings(commercial_persistence.settings_snapshot())
	get_viewport().gui_focus_changed.connect(_on_gui_focus_changed)
	connect_overlay_focus_recovery()
	season_mechanics = SeasonMechanicsScript.new()
	mentor_tutorial.configure(self)
	season_mechanics.configure(self)
	add_child(season_mechanics)
	show_intro()
	queue_redraw()

func load_build_provenance() -> void:
	build_product_version = String(ProjectSettings.get_setting("application/config/version", "unknown"))
	build_commit = "unavailable"
	var file := FileAccess.open(BUILD_PROVENANCE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_warning("Ignoring malformed build provenance")
		return
	var injected_version := String(parsed.get("product_version", ""))
	var injected_commit := String(parsed.get("commit", "")).to_lower()
	var injected_dirty = parsed.get("dirty", null)
	var commit_pattern := RegEx.new()
	commit_pattern.compile("^[0-9a-f]{7,40}$")
	if injected_version != build_product_version or commit_pattern.search(injected_commit) == null or typeof(injected_dirty) != TYPE_BOOL:
		push_warning("Ignoring inconsistent build provenance")
		return
	build_commit = injected_commit.left(8) + ("+dirty" if bool(injected_dirty) else "")

func build_provenance_text() -> String:
	return "v%s · %s" % [build_product_version, build_commit]

func load_optional_texture(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	return ResourceLoader.load(path, "Texture2D") as Texture2D

func load_spring_launch_art() -> void:
	spring_field_texture = load_optional_texture(SPRING_FIELD_PATH)
	spring_flower_common_texture = load_optional_texture(SPRING_FLOWER_COMMON_PATH)
	spring_flower_high_value_texture = load_optional_texture(SPRING_FLOWER_HIGH_VALUE_PATH)
	spring_hive_entrance_texture = load_optional_texture(SPRING_HIVE_ENTRANCE_PATH)
	spring_mosquito_texture = load_optional_texture(SPRING_MOSQUITO_PATH)
	colony_bee_texture = load_optional_texture(COLONY_BEE_PATH)

func spring_launch_art_ready() -> bool:
	return (
		spring_field_texture != null
		and spring_flower_common_texture != null
		and spring_flower_high_value_texture != null
		and spring_hive_entrance_texture != null
		and spring_mosquito_texture != null
		and colony_bee_texture != null
		and bee != null
		and bee.has_spring_launch_art()
	)

func world_art_ready() -> bool:
	return spring_launch_art_ready()

func is_in_hive_entry(world_position: Vector2) -> bool:
	# Deposit, healing and winter warmth all use the doorway-shaped landing area.
	# Merely touching the left edge above or below the visible hive is not home.
	return HIVE_ENTRY_AREA.has_point(world_position)

func current_flower_set() -> String:
	# HUD and world art must preserve the same Boss origin behind static overlays.
	if _uses_boss_interface_context():
		return ["spring", "summer", "autumn", "winter"][clampi(current_boss_index, 0, 3)]
	if stage_index < 0 or stage_index >= stages.size():
		return "spring"
	var configured := String(stages[stage_index].get("flower_set", ""))
	if not configured.is_empty():
		return configured
	return ["spring", "summer", "autumn", "winter"][season_index_of(stage_index)]

func is_spring_gathering_stage(index: int) -> bool:
	if index < 0 or index >= stages.size():
		return false
	var data: Dictionary = stages[index]
	# Art follows the mechanic family the player can perceive, not the legacy
	# calendar label. Otherwise the first pollination trip gets fallback art while
	# the first raider trip is incorrectly dressed as spring.
	return String(data.get("flower_set", "")) == "spring" and not data.has("boss")

func uses_spring_launch_art() -> bool:
	return is_spring_gathering_stage(stage_index) and spring_launch_art_ready()

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

func load_flower_data() -> void:
	var file := FileAccess.open("res://data/flowers.json", FileAccess.READ)
	if file == null:
		push_warning("无法读取花型数据，将使用基线蜜花")
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		flower_configs = parsed
	else:
		push_warning("花型数据格式错误，将使用基线蜜花")

func balance_value(section: String, key: String, fallback: float) -> float:
	if balance.has(section) and balance[section] is Dictionary:
		return float(balance[section].get(key, fallback))
	return fallback

## 实际体力上限：基准（balance.json player.max_energy）与季节性覆盖
## （越冬抱团的幼虫加成可把上限提到基准之上）取较大者，恢复/饮蜜/体力条共用
func effective_energy_cap() -> float:
	return maxf(bee.max_energy, energy_cap_override)

## 花物候学：按权重随机选取花型
func _pick_flower_type(types: Array) -> Dictionary:
	if types.is_empty():
		return {"id": "nectar_bloom", "nectar_base": 3}
	var total_weight := 0.0
	for t in types:
		total_weight += float(t.get("weight", 1.0))
	if total_weight <= 0.0:
		return types[0]
	var roll := rng.randf() * total_weight
	var cumulative := 0.0
	for t in types:
		cumulative += float(t.get("weight", 1.0))
		if roll <= cumulative:
			return t
	return types[-1]

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
	production_hud = ProductionHUDScript.new()
	ui.add_child(production_hud)

	title_label = make_label(ui, "◆  一会儿巢里见", Vector2(34, 17), Vector2(350, 42), 24, Color("26342b"))
	term_label = make_label(ui, "", Vector2(520, 16), Vector2(240, 52), 25, Color("26342b"))
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
	quit_button = Button.new()
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
	# System controls live behind pause; play keeps one pause entry.
	fullscreen_button.visible = false
	sound_button.visible = false
	quit_button.visible = false
	refresh_setting_labels()

	# Three HUD groups: forage, flight, and hive.
	var forage_panel := ColorRect.new()
	forage_panel.name = "ForagePanel"
	forage_panel.color = Color("f3eedb", 0.88)
	forage_panel.position = Vector2(34, 82)
	forage_panel.size = Vector2(300, 50)
	ui.add_child(forage_panel)
	make_label(forage_panel, "携带", Vector2(12, 5), Vector2(40, 18), 10, Color("6d715f"))
	carried_label = make_label(forage_panel, "0 / 8", Vector2(50, 8), Vector2(64, 30), 17, Color("26342b"))
	carried_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	delivered_title_label = make_label(forage_panel, "归巢蜜", Vector2(126, 5), Vector2(72, 18), 10, Color("6d715f"))
	delivered_label = make_label(forage_panel, "0 / 5", Vector2(198, 8), Vector2(88, 30), 17, Color("26342b"))
	delivered_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	var flight_panel := ColorRect.new()
	flight_panel.name = "FlightPanel"
	flight_panel.color = Color("f3eedb", 0.88)
	flight_panel.position = Vector2(348, 82)
	flight_panel.size = Vector2(310, 50)
	ui.add_child(flight_panel)
	make_label(flight_panel, "飞行体力", Vector2(12, 5), Vector2(90, 18), 10, Color("6d715f"))
	energy_label = make_label(flight_panel, "100", Vector2(242, 7), Vector2(54, 25), 17, Color("26342b"))
	energy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	energy_bar = ColorRect.new()
	energy_bar.position = Vector2(12, 35)
	energy_bar.size = Vector2(284, 6)
	energy_bar.color = Color("33483d")
	flight_panel.add_child(energy_bar)
	energy_bar_fill = ColorRect.new()
	energy_bar_fill.size = Vector2(284, 6)
	energy_bar_fill.color = Color("ddb84c")
	energy_bar.add_child(energy_bar_fill)
	energy_change_label = make_label(flight_panel, "", Vector2(188, 4), Vector2(48, 24), 12, Color("b34b3f"))
	energy_change_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	var hive_panel := ColorRect.new()
	hive_panel.name = "HivePanel"
	hive_panel.color = Color("f3eedb", 0.88)
	hive_panel.position = Vector2(672, 82)
	hive_panel.size = Vector2(332, 50)
	ui.add_child(hive_panel)
	make_label(hive_panel, "蜂巢", Vector2(12, 5), Vector2(52, 18), 10, Color("6d715f"))
	hive_label = make_label(hive_panel, "●●●", Vector2(66, 8), Vector2(92, 30), 17, Color("26342b"))
	make_label(hive_panel, "公共储备", Vector2(174, 5), Vector2(72, 18), 10, Color("6d715f"))
	reserve_label = make_label(hive_panel, "0", Vector2(260, 8), Vector2(58, 30), 17, Color("26342b"))
	reserve_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	var side := ColorRect.new()
	side.name = "ContextRail"
	side.color = Color("f3eedb", 0.94)
	side.position = Vector2(1020, 146)
	side.size = Vector2(230, 538)
	ui.add_child(side)
	make_label(side, "当前局面", Vector2(20, 18), Vector2(190, 18), 10, Color("68705d"))
	season_label = make_label(side, "过关条件", Vector2(20, 38), Vector2(190, 38), 24, Color("1f2c24"))
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
	# The side rail exposes only the action valid in the current context.
	var input_rule := ColorRect.new()
	input_rule.color = Color("c7c0a4", 0.6)
	input_rule.position = Vector2(20, 348)
	input_rule.size = Vector2(190, 1)
	side.add_child(input_rule)
	context_hint_label = make_label(side, "", Vector2(20, 360), Vector2(190, 32), 11, Color("556054"))
	context_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# 情境动作按钮：近花=采蜜 / 近敌=惊退 / 静止=寻迹 / 长按携蜜=诱饵
	sense_button = make_mouse_action(side, "动作", "action", Vector2(14, 402), true, Vector2(135, 36))
	return_button = make_mouse_action(side, "归巢", "return_hive", Vector2(155, 402), false, Vector2(62, 36))
	# 饮蜜按钮不走一帧全局 Input 状态：测试中可能同时有多个 game 实例，
	# 否则所有实例都会响应。这里先确认动作是否可用，再直接饮蜜；Button
	# 默认松手确认，滑出控件不会误触。
	drink_button = Button.new()
	drink_button.name = "DrinkHoneyButton"
	drink_button.text = "饮蜜续力"
	drink_button.tooltip_text = "消耗 1 滴携带蜜，恢复飞行体力"
	drink_button.position = Vector2(16, 374)
	drink_button.size = Vector2(200, 56)
	drink_button.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	drink_button.pressed.connect(on_drink_honey_pressed)
	drink_button.visible = false
	side.add_child(drink_button)
	# 历史信息是跨 run 的持久状态，留给 HUD 侧栏底部常驻显示——属于状态不属于弹窗
	var meter_rule := ColorRect.new()
	meter_rule.color = Color("c7c0a4", 0.6)
	meter_rule.position = Vector2(20, 520)
	meter_rule.size = Vector2(190, 1)
	side.add_child(meter_rule)
	runs_meter = make_label(side, "", Vector2(20, 528), Vector2(190, 18), 11, Color("3a4a3e"))
	runs_meter.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	runs_meter_farthest = make_label(side, "", Vector2(20, 548), Vector2(190, 18), 11, Color("68705d"))
	runs_meter_farthest.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	runs_meter.visible = false
	runs_meter_farthest.visible = false
	refresh_runs_meter()

	# Tutorial prompts are temporary and contextual, never a permanent key list.
	tutorial_panel = ColorRect.new()
	tutorial_panel.color = Color("26392f", 0.94)
	tutorial_panel.position = Vector2(292, 616)
	tutorial_panel.size = Vector2(454, 54)
	ui.add_child(tutorial_panel)
	tutorial_title = make_label(tutorial_panel, "", Vector2(16, 7), Vector2(120, 20), 12, Color("dfbd54"))
	tutorial_body = make_label(tutorial_panel, "", Vector2(118, 7), Vector2(320, 38), 12, Color("f7f0d5"))
	tutorial_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	overlay = ColorRect.new()
	overlay.color = Color("21352c", 0.93)
	overlay.position = Vector2(34, 146)
	overlay.size = Vector2(970, 538)
	ui.add_child(overlay)
	overlay_title = make_label(overlay, "蜂巢仍在呼吸", Vector2(150, 82), Vector2(670, 150), 54, Color("fff8d9"))
	overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_body = make_label(overlay, "控制蜜蜂飞向花朵，按住空格采蜜。\n体力耗尽前，带着花蜜返回左侧蜂巢。", Vector2(190, 245), Vector2(590, 78), 17, Color("d8ddc9"))
	overlay_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_button = Button.new()
	overlay_button.text = "出巢"
	overlay_button.position = Vector2(334, 340)
	overlay_button.size = Vector2(300, 60)
	overlay_button.add_theme_font_size_override("font_size", 21)
	overlay_button.pressed.connect(on_overlay_button)
	overlay.add_child(overlay_button)
	secondary_link = Button.new()
	secondary_link.flat = true
	secondary_link.text = ""
	secondary_link.position = Vector2(334, 404)
	secondary_link.size = Vector2(300, 44)
	secondary_link.add_theme_font_size_override("font_size", 13)
	secondary_link.add_theme_color_override("font_color", Color("a8aa90"))
	secondary_link.add_theme_color_override("font_hover_color", Color("fff8d9"))
	secondary_link.add_theme_color_override("font_pressed_color", Color("d8ddc9"))
	secondary_link.pressed.connect(on_secondary_link)
	secondary_link.visible = false
	overlay.add_child(secondary_link)
	title_settings_button = Button.new()
	title_settings_button.text = "设置"
	title_settings_button.position = Vector2(280, 452)
	title_settings_button.size = Vector2(130, 44)
	title_settings_button.pressed.connect(_open_title_settings)
	title_settings_button.visible = false
	overlay.add_child(title_settings_button)
	title_credits_button = Button.new()
	title_credits_button.text = "制作人员与许可"
	title_credits_button.position = Vector2(420, 452)
	title_credits_button.size = Vector2(180, 44)
	title_credits_button.pressed.connect(_open_title_credits)
	title_credits_button.visible = false
	overlay.add_child(title_credits_button)
	title_exit_button = Button.new()
	title_exit_button.text = "退出游戏"
	title_exit_button.position = Vector2(610, 452)
	title_exit_button.size = Vector2(130, 44)
	title_exit_button.pressed.connect(func(): get_tree().quit())
	title_exit_button.visible = false
	overlay.add_child(title_exit_button)
	build_provenance_label = make_label(overlay, build_provenance_text(), Vector2(190, 512), Vector2(590, 18), 10, Color("89978b"))
	build_provenance_label.name = "BuildProvenanceLabel"
	build_provenance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for spec in [["全屏", toggle_fullscreen], ["声音", toggle_sound], ["退出", func(): get_tree().quit()]]:
		var system_button := Button.new()
		system_button.text = String(spec[0])
		system_button.position = Vector2(262 + pause_system_buttons.size() * 150, 412)
		system_button.size = Vector2(140, 38)
		system_button.pressed.connect(spec[1])
		system_button.visible = false
		overlay.add_child(system_button)
		pause_system_buttons.append(system_button)
	# —— overlay 区以内的元素到此为止 ——升级卡片直接挂在 overlay 上
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
	var allocation_title := make_label(allocation_panel, "分配收成", Vector2(0, 26), Vector2(670, 44), 28, Color("fff8d9"))
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
	allocation_confirm = Button.new()
	allocation_confirm.name = "AllocationConfirm"
	allocation_confirm.text = "确认分配"
	allocation_confirm.position = Vector2(255, 296)
	allocation_confirm.size = Vector2(160, 52)
	allocation_confirm.add_theme_font_size_override("font_size", 17)
	allocation_confirm.pressed.connect(confirm_allocation)
	allocation_panel.add_child(allocation_confirm)
	allocation_slider.focus_next = allocation_slider.get_path_to(allocation_confirm)
	allocation_slider.focus_previous = allocation_slider.get_path_to(allocation_confirm)
	allocation_confirm.focus_next = allocation_confirm.get_path_to(allocation_slider)
	allocation_confirm.focus_previous = allocation_confirm.get_path_to(allocation_slider)
	make_label(allocation_panel, "一边维持蜂巢，一边哺育幼虫。没有对错，只有不同的活法。", Vector2(90, 368), Vector2(490, 24), 11, Color("aab5a0")).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	if zh_font != null:
		# 运行时创建的控件没有 scene owner；owned=true 会漏掉全部按钮。
		for node in ui.find_children("*", "Button", true, false):
			if node is Button:
				node.add_theme_font_override("font", zh_font)
	production_hud.apply_to(self, ui)

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
	new_journey_confirmation_armed = false
	bee.active = false
	overlay.visible = true
	overlay_title.text = "一会儿巢里见"
	overlay_body.text = "花田有事，搭把翅膀。\n飞一圈，巢里见。"
	var commercial_persistence := _commercial_persistence()
	var save_file_present := commercial_persistence != null and commercial_persistence.progress_file_exists()
	var can_continue := commercial_persistence != null and commercial_persistence.has_progress()
	overlay_button.disabled = save_file_present and not can_continue
	if can_continue:
		overlay_button.text = "继续旅程"
	elif save_file_present:
		overlay_button.text = "旧存档暂时无法载入"
		overlay_body.text += "\n这个版本不会覆盖它；可更新游戏，或在下方明确清除。"
	else:
		overlay_button.text = "开始新旅程"
	overlay_button.visible = true
	set_upgrade_buttons_visible(false)
	set_pause_system_controls_visible(false)
	set_secondary_link("清除存档并开始新旅程" if save_file_present else "", save_file_present)
	if title_settings_button != null:
		title_settings_button.visible = true
		title_credits_button.visible = true
		title_exit_button.visible = true
	if can_continue:
		var summary := commercial_persistence.progress_summary()
		if bool(summary.get("ok", false)):
			overlay_body.text += "\n巢中蜜 %d · 从主蜂巢继续" % int(summary.get("reserve", 0))
	focus_overlay_primary()
	refresh_runs_meter()

# Overlay keyboard focus has one source of truth. Each newly shown state chooses
# a deterministic primary control; transient focus loss restores the most recent
# valid control inside that same state instead of falling back to a hidden main
# button or letting Enter leak into a second transition.
func is_valid_overlay_focus(control: Control) -> bool:
	if control == null or overlay == null or not overlay.visible:
		return false
	if control != overlay and not overlay.is_ancestor_of(control):
		return false
	if not control.is_visible_in_tree() or control.focus_mode == Control.FOCUS_NONE:
		return false
	if control is BaseButton and (control as BaseButton).disabled:
		return false
	return true

func overlay_primary_focus() -> Control:
	if overlay == null or not overlay.visible:
		return null
	if allocation_panel != null and allocation_panel.visible:
		if is_valid_overlay_focus(allocation_slider):
			return allocation_slider
		if is_valid_overlay_focus(allocation_confirm):
			return allocation_confirm
	for button in upgrade_buttons:
		if is_valid_overlay_focus(button):
			return button
	if is_valid_overlay_focus(overlay_button):
		return overlay_button
	if is_valid_overlay_focus(secondary_link):
		return secondary_link
	for button in pause_system_buttons:
		if is_valid_overlay_focus(button):
			return button
	return null

func focus_overlay_primary() -> void:
	var target := overlay_primary_focus()
	if target == null:
		return
	last_overlay_focus = target
	target.grab_focus()

func queue_overlay_focus_restore() -> void:
	if overlay_focus_restore_queued:
		return
	overlay_focus_restore_queued = true
	call_deferred("restore_overlay_focus")

func connect_overlay_focus_recovery() -> void:
	for node in overlay.find_children("*", "Control", true, false):
		var control := node as Control
		if control != null and control.focus_mode != Control.FOCUS_NONE:
			control.focus_exited.connect(queue_overlay_focus_restore)

func restore_overlay_focus() -> void:
	overlay_focus_restore_queued = false
	if not is_inside_tree() or get_viewport() == null or overlay == null or not overlay.visible:
		return
	var current := get_viewport().gui_get_focus_owner()
	if is_valid_overlay_focus(current):
		return
	var target: Control = null
	if is_instance_valid(last_overlay_focus) and is_valid_overlay_focus(last_overlay_focus):
		target = last_overlay_focus
	else:
		target = overlay_primary_focus()
	if target != null:
		last_overlay_focus = target
		target.grab_focus()

func _on_gui_focus_changed(control: Control) -> void:
	if overlay == null or not overlay.visible:
		return
	if is_valid_overlay_focus(control):
		last_overlay_focus = control
		return
	# Focus changes may briefly report null while Tab moves between two controls.
	# Deferring lets that normal transition settle before repairing a true loss.
	queue_overlay_focus_restore()

func start_game() -> void:
	for title_control in [title_settings_button, title_credits_button, title_exit_button]:
		if title_control != null:
			title_control.visible = false
	hive_lives = 3
	stage_index = 0
	lost_from_phase = "playing"
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
	carry_capacity = balance_value("player", "carry_capacity", 8.0)
	bee.reset_upgrades()
	tutorial_step = 6 if tutorial_complete else 0
	tutorial_origin = HIVE_RETURN_POS
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
	music.enter_explore(season_index_of(index))
	phase = "playing"
	overlay.visible = false
	set_pause_system_controls_visible(false)
	# 蜂巢成长面板的 title/body 必须跟随 overlay 一起清空，
	# 否则下一节令若再次让 overlay 可见（例如失律者战败），玩家会读到上一关
	# 「XX 完成 · 蜂巢成长」的 stale 文案，把败北误判成「我在哪个选择升级」。
	overlay_title.text = ""
	overlay_body.text = ""
	carried = 0
	# 蜜囊续力按节气计数：出勤开始时重置；失败重试不重置，饮蜜是每节气的有限资源
	crop_fuel_used = 0
	delivered = 0
	harvest_clock = 0.0
	sting_cooldown = 0.0
	hit_cooldown = 0.0
	was_in_hive = false
	hive_dwell_time = 0.0
	flowers.clear()
	mosquitoes.clear()
	ants.clear()
	crickets.clear()
	thrushes.clear()
	bears.clear()
	phantom_flowers.clear()
	field_afterimages.clear()
	evade_confirmation_time = 0.0
	_clear_evade_tap_buffers()
	decoys.clear()
	tuning_blooms.clear()
	pollen.clear()
	# 花物候学：重置连环花状态
	chain_timer = 0.0
	chain_last_index = -1
	chain_bonus_count = 0
	var data: Dictionary = stages[index]
	relay_hive.configure(data.get("relay_hive", {}))
	relay_was_resting = false
	bee.configure(float(data.energy_drain))
	bee.reset_for_expedition(Vector2(180, 410))
	# 花物候学：按 flower_set 读取花型权重生成
	var flower_set_id := str(data.get("flower_set", ""))
	var ftypes: Array = []
	chain_window_s = 0.0
	chain_harvest_bonus = 0
	if flower_set_id != "" and flower_configs.has(flower_set_id):
		var fset: Dictionary = flower_configs[flower_set_id]
		ftypes = fset.get("types", [])
		if fset.has("chain_bloom"):
			var cb: Dictionary = fset["chain_bloom"]
			chain_window_s = float(cb.get("window_s", 2.0))
			chain_cap = int(cb.get("cap", 3))
			chain_range_px = float(cb.get("range_px", 120.0))
			chain_harvest_bonus = maxi(0, int(cb.get("bonus", 1)))
	for i in int(data.flowers):
		var flower_position := find_spaced_flower_position(82.0)
		var ftype := _pick_flower_type(ftypes)
		var base_nectar := int(ftype.get("nectar_base", 3))
		var nectar_val: int = max(2, roundi(base_nectar * float(data.nectar_scale))) + extra_nectar
		flowers.append({
			"id": i,
			"position": flower_position,
			"nectar": nectar_val,
			"max_nectar": nectar_val,
			"kind": i % 3,
			"visual_variant": i % 2,
			"large_bloom": i % 2 == 1,
			"phase": rng.randf_range(0, TAU),
			"recovery": false,
			"type": ftype.get("id", "nectar_bloom"),
			"triggers_growth": bool(ftype.get("triggers_growth", false))
		})
	if index == 0 and not tutorial_complete:
		_configure_authored_first_trip()
	elif index in [7, 13, 19]:
		_configure_season_showcase(index)
	elif index == 9:
		_configure_relay_showcase()
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
		energy_cap_override = bee.max_energy
	season_mechanics.start_stage(index)
	bee.set_spring_launch_art(world_art_ready())
	_ensure_stage_resource_budget()
	mentor_tutorial.start_stage(index, data)
	message = "远路旁的中继巢还暗着。" if relay_hive.enabled else ""
	update_interface()
	queue_redraw()

## First-session level authored as a small journey instead of a random sandbox.
## Only the resource required by the current lesson is open, so every tutorial
## completion is evidence that the ability changed the world rather than that a
## key happened to be pressed.
func _configure_authored_first_trip() -> void:
	# Keep the authored lesson route finite and free of unrelated route bonuses.
	chain_window_s = 0.0
	var authored := [
		{"position": Vector2(315, 410), "nectar": 2, "type": "first_bloom", "locked": false, "hidden": false},
		{"position": Vector2(500, 292), "nectar": 3, "type": "hidden_bloom", "locked": true, "hidden": true},
		{"position": Vector2(650, 410), "nectar": 5, "type": "peak_bloom", "locked": true, "hidden": false},
		{"position": Vector2(815, 255), "nectar": 4, "type": "nectar_bloom", "locked": true, "hidden": false},
		{"position": Vector2(850, 515), "nectar": 4, "type": "nectar_bloom", "locked": true, "hidden": false},
		{"position": Vector2(430, 565), "nectar": 3, "type": "nectar_bloom", "locked": true, "hidden": false}
	]
	for i in mini(flowers.size(), authored.size()):
		var flower: Dictionary = flowers[i]
		var design: Dictionary = authored[i]
		flower.position = design.position
		flower.nectar = design.nectar
		flower.max_nectar = design.nectar
		flower.type = design.type
		flower.visual_variant = [1, 0, 1, 0, 1, 0][i]
		flower.large_bloom = bool(flower.visual_variant == 1)
		flower.tutorial_locked = bool(design.locked)
		flower.tutorial_hidden = bool(design.hidden)
		flower.discovered = not bool(design.hidden)
		flowers[i] = flower
	tutorial_hidden_index = 1
	tutorial_resource_index = 2
	tutorial_resource_position = Vector2(authored[tutorial_resource_index].position)
	tutorial_scent_revealed = false
	tutorial_charge_state = "idle"
	tutorial_charge_time = 0.0
	tutorial_failed_crossings = 0
	tutorial_origin = HIVE_RETURN_POS

## The first trip in each new mechanic family is composed as a readable exhibit:
## one dominant route, one new physical rule, and no dependence on random spawn
## luck. Later trips keep the systemic layouts and combine the rule with hazards.
func _configure_season_showcase(index: int) -> void:
	var routes := {
		7: [
			Vector2(305, 410), Vector2(430, 292), Vector2(445, 525),
			Vector2(610, 255), Vector2(625, 445), Vector2(790, 318), Vector2(855, 525)
		],
		13: [
			Vector2(315, 410), Vector2(445, 305), Vector2(455, 520),
			Vector2(620, 260), Vector2(630, 455), Vector2(800, 325), Vector2(850, 535)
		],
		19: [
			Vector2(285, 405), Vector2(335, 515), Vector2(455, 290), Vector2(515, 450),
			Vector2(620, 545), Vector2(690, 330), Vector2(790, 270), Vector2(865, 505)
		]
	}
	var route: Array = routes.get(index, [])
	for i in mini(flowers.size(), route.size()):
		var flower: Dictionary = flowers[i]
		flower.position = route[i]
		flower.kind = i % 2
		flower.visual_variant = i % 2
		flower.large_bloom = i % 2 == 1
		if index == 13 and i < 2:
			# Two authored seed flowers support one prompted decision followed by one
			# unprompted practice decision; each reaches its pod after one harvest tick.
			flower.nectar = 2
			flower.max_nectar = 2
			flower.type = "seed_bloom"
			flower.showcase_seed = true
		flowers[i] = flower

## The first relay-hive field is a fixed long route. The post sits between the
## near and far flower clusters, so activating it changes traversal instead of
## behaving like another HUD upgrade.
func _configure_relay_showcase() -> void:
	var route := [
		Vector2(310, 350), Vector2(395, 245), Vector2(445, 510),
		Vector2(575, 285), Vector2(750, 245), Vector2(825, 410), Vector2(895, 570)
	]
	for i in mini(flowers.size(), route.size()):
		var flower: Dictionary = flowers[i]
		flower.position = route[i]
		flower.visual_variant = i % 2
		flower.large_bloom = i % 2 == 1
		flowers[i] = flower

func on_overlay_button() -> void:
	# 相位护栏：异常状态下点穿弹窗不推进关卡
	if not ["intro", "won", "lost", "paused", "boss_victory", "between", "boss_loss"].has(phase):
		return
	match phase:
		"intro":
			# Exported/runtime Main is the active title scene and opens the new product
			# journey. Embedded regression fixtures intentionally keep the legacy loop
			# reachable through start_game() without replacing their SceneTree root.
			if get_tree().current_scene == self:
				var commercial_persistence := _commercial_persistence()
				if commercial_persistence != null:
					var save_file_present := commercial_persistence.progress_file_exists()
					var can_continue := commercial_persistence.has_progress()
					if save_file_present and not can_continue:
						show_intro()
						return
					var mode := "continue" if can_continue else "new"
					commercial_persistence.request_journey_launch(mode)
				get_tree().change_scene_to_packed(JOURNEY_SCENE)
			else:
				start_game()
		"won", "lost": start_game()
		"paused": toggle_pause()
		"boss_victory":
			if stage_index + 1 < stages.size():
				spawn_stage(stage_index + 1)
			else:
				show_win()
		# 失律者战败但还有命：从当前节令重开，不把玩家发配回立春
		"boss_loss":
			# This phase can only be entered by update_boss(). The terminal bear
			# reuses the ordinary final-stage index, so stage shape is not a safe
			# discriminator for retry routing.
			start_boss()
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
	energy_bar_flash_time = maxf(0.0, energy_bar_flash_time - delta)
	carry_full_flash_time = maxf(0.0, carry_full_flash_time - delta)
	context_lesson_time = maxf(0.0, context_lesson_time - delta)
	hive_flash_time = maxf(0.0, hive_flash_time - delta)
	hive_activity_time = maxf(0.0, hive_activity_time - delta)
	evade_confirmation_time = maxf(0.0, evade_confirmation_time - delta)
	if phase == "playing":
		run_elapsed += delta
		update_game(delta)
	elif phase == "boss":
		run_elapsed += delta
		update_boss(delta)
	elif phase == "exhausted":
		# 力竭停顿拍：世界静止，体力条停在 0，随后结算损失并回巢重置
		exhaustion_timer -= delta
		if exhaustion_timer <= 0.0:
			resolve_exhaustion()
	update_pollen(delta)
	update_interface()
	queue_redraw()

func update_game(delta: float) -> void:
	var data: Dictionary = stages[stage_index]
	mentor_tutorial.process(delta)
	if mentor_tutorial.blocks_simulation():
		return
	bee.active = true
	sting_cooldown = maxf(0.0, sting_cooldown - delta)
	hit_cooldown = maxf(0.0, hit_cooldown - delta)
	update_decoys(delta)

	# 双击方向键 = 急转闪避
	_check_double_tap_evade(delta)

	# 花物候学：连环花窗口倒计时
	chain_timer = maxf(0.0, chain_timer - delta)

	# 归巢：Q 键自动飞回蜂巢
	if Input.is_action_just_pressed("return_hive") and mentor_tutorial.allows_action("return"):
		bee.set_move_target(HIVE_RETURN_POS)
		message = "归巢路线已锁定。"

	# 显式饮蜜：E 键主动饮下蜜囊里的一滴蜜续力（每节气受 crop_fuel_limit 限制）
	if Input.is_action_just_pressed("drink_honey") and mentor_tutorial.allows_action("drink"):
		_drink_honey()

	# 情境动作：空格/回车根据上下文执行不同操作
	var nearby := nearest_flower(46.0)
	var near_enemy := _nearest_enemy_distance() < sting_range
	var is_still := bee.velocity.length_squared() < 4.0 and not bee.has_target

	if Input.is_action_just_pressed("action"):
		action_hold_time = 0.0
		action_decoy_fired = false
		action_was_harvesting = false
		var seasonal_action_used := false
		var relay_action_used := false
		if not near_enemy:
			relay_action_used = _try_activate_relay_hive()
		if not relay_action_used and mentor_tutorial.allows_action("seasonal") and season_mechanics.has_method("try_context_action"):
			seasonal_action_used = bool(season_mechanics.try_context_action(bee.position))
		# 优先级：近敌→惊退 > 静止→寻迹
		if relay_action_used or seasonal_action_used:
			action_decoy_fired = true
		elif near_enemy and mentor_tutorial.allows_action("repel"):
			_do_repel()
		elif is_still and nearby < 0 and mentor_tutorial.allows_action("sense"):
			_do_sense()
		elif nearby >= 0:
			# 近花时按下开始采蜜（持续按住逻辑在下面）
			pass

	if Input.is_action_pressed("action"):
		action_hold_time += delta
		if nearby >= 0 and bee.energy > 0 and not near_enemy and mentor_tutorial.allows_action("harvest"):
			# 采蜜（持续）
			var release_required := false
			if season_mechanics.has_method("harvest_requires_release"):
				release_required = bool(season_mechanics.harvest_requires_release(nearby))
			if release_required:
				# 秋季种核必须真的松手一次。停在最后一滴时不再持续耗体力，
				# 也不会因为玩家持续按键而越过这个可见取舍。
				action_was_harvesting = true
				harvest_clock = 0.0
			else:
				harvest_clock += delta
				bee.energy = maxf(0.0, bee.energy - balance_value("player", "harvest_energy_per_second", 3.2) * delta)
			if not release_required and harvest_clock >= balance_value("player", "harvest_interval", 0.42) / harvest_multiplier:
				harvest_clock = 0.0
				if carried >= int(carry_capacity):
					# 蜜囊已满：花蜜不扣、花粉不落，避免白白耗掉一朵花。
					# 反馈身体化：条闪红与提示音，飘字只在初次出现（按住不再提示）
					if carry_full_flash_time <= 0.0:
						message = "蜜囊已满，先归巢。"
						sound.play_cue("full")
					carry_full_flash_time = 0.6
				else:
					var flower: Dictionary = flowers[nearby]
					flower.nectar = int(flower.nectar) - 1
					var route_result := _apply_chain_route_harvest(flower, nearby)
					flower = route_result.flower
					var extra_harvest: int = int(route_result.extra_harvest)
					var harvest_msg: String = str(route_result.message)
					flowers[nearby] = flower
					carried += 1 + extra_harvest
					action_was_harvesting = true
					sound.play_cue("harvest")
					spawn_pollen(flower.position)
					var msg_before := message
					season_mechanics.on_harvest(nearby)
					_on_tutorial_harvest(nearby)
					if harvest_msg != "":
						message = harvest_msg
					elif message != msg_before:
						pass
					elif flower.nectar <= 0:
						# 采尽只提示一次；采蜜中的常态反馈交给音效与花粉，不再每滴飘字
						message = "这朵花已经采尽。"

		elif not action_was_harvesting and not action_decoy_fired and action_hold_time >= DECOY_HOLD_THRESHOLD and carried > 0 and not near_enemy and mentor_tutorial.allows_action("decoy"):
			# 长按空格 + 携蜜 + 无花无敌 = 投蜜诱饵（采过蜜的同一按键不会触发，需松开重按）
			action_decoy_fired = true
			drop_honey_decoy()
	else:
		if season_mechanics.has_method("notify_harvest_released"):
			season_mechanics.notify_harvest_released()
		action_hold_time = 0.0
		action_decoy_fired = false
		action_was_harvesting = false
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
	_update_relay_hive(delta)
	update_hive_rest(delta, true)
	# 目标与能力演示共同组成首趟路线；后续季节机制也可声明自己的
	# 因果目标尚未完成（例如尚未传粉/点暖），但没有计时门。
	var mechanics_ready := true
	if season_mechanics.has_method("can_complete"):
		mechanics_ready = bool(season_mechanics.can_complete())
	var tutorial_ready := tutorial_complete or stage_index != 0
	var mentor_ready := mentor_tutorial.can_complete_stage()
	if delivered >= int(data.goal) and tutorial_ready and mechanics_ready and mentor_ready and phase == "playing":
		show_between()
	if bee.energy <= 0.0 and phase == "playing":
		# 相位护栏：同一帧已达标进入蜂巢成长时不再误触力竭
		begin_exhaustion()

## A chain route rewards execution speed by taking another existing drop in the
## same harvest tick. It never creates nectar, and it never overfills the crop.
func _apply_chain_route_harvest(flower: Dictionary, flower_index: int) -> Dictionary:
	var result := {"flower": flower, "extra_harvest": 0, "message": ""}
	if str(flower.get("type", "")) == "chain_bloom" and chain_window_s > 0.0:
		var previous_is_valid := chain_timer > 0.0 \
			and chain_last_index >= 0 \
			and chain_last_index < flowers.size() \
			and chain_last_index != flower_index \
			and chain_bonus_count < chain_cap
		if previous_is_valid:
			var prev_pos: Vector2 = flowers[chain_last_index].position
			if Vector2(flower.position).distance_to(prev_pos) <= chain_range_px:
				var remaining_nectar := maxi(0, int(flower.get("nectar", 0)))
				var spare_capacity := maxi(0, int(carry_capacity) - carried - 1)
				var extra_harvest := mini(chain_harvest_bonus, mini(remaining_nectar, spare_capacity))
				if extra_harvest > 0:
					flower["nectar"] = remaining_nectar - extra_harvest
					chain_bonus_count += 1
					result["extra_harvest"] = extra_harvest
					result["message"] = "连环花路线：一次带走两滴。（%d/%d）" % [chain_bonus_count, chain_cap]
		chain_last_index = flower_index
		chain_timer = chain_window_s
	else:
		if chain_window_s > 0.0:
			chain_timer = 0.0
			chain_last_index = -1
			chain_bonus_count = 0
	result["flower"] = flower
	return result

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
	if not mentor_tutorial.allows_action("repel"):
		return
	if sting_cooldown > 0.0 or not bee.spend_energy(sting_cost):
		return
	show_energy_change(-sting_cost)
	sting_cooldown = balance_value("player", "repel_cooldown", 1.15) * sting_cooldown_multiplier
	sound.play_cue("repel")
	var repelled_any := false
	for i in mosquitoes.size():
		var mosquito: Dictionary = mosquitoes[i]
		if bee.position.distance_to(mosquito.position) < sting_range:
			repelled_any = true
			mosquito.repel_time = balance_value("player", "repel_duration", 3.5)
			mosquito.velocity = (mosquito.position - bee.position).normalized() * 8.0
			mosquitoes[i] = mosquito
	for i in ants.size():
		var ant: Dictionary = ants[i]
		if bee.position.distance_to(ant.position) < sting_range:
			repelled_any = true
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
			repelled_any = true
			cricket.repel_time = balance_value("player", "repel_duration", 3.5)
			cricket.hopping = false
			cricket.hop_clock = balance_value("cricket", "rest_seconds", 1.2)
			crickets[i] = cricket
	for i in thrushes.size():
		var thrush: Dictionary = thrushes[i]
		if bee.position.distance_to(thrush.position) < sting_range + 20.0:
			repelled_any = true
			thrush.silence_time = balance_value("player", "repel_duration", 3.5)
			thrushes[i] = thrush
	if repelled_any:
		season_mechanics.on_repel_success()
		message = "航线重新露了出来。"
	for bear_unit in bears:
		if bee.position.distance_to(bear_unit.position) < sting_range + 40.0:
			message = "熊对震翼毫无反应。绕开它，抢在它之前收完这片花田。"

func _do_sense() -> void:
	if not mentor_tutorial.allows_action("sense"):
		return
	if bee.sense_cooldown > 0.0:
		return
	var huddle = season_mechanics.mechanic_by_id("huddle")
	if huddle != null and huddle.is_scouting_ready():
		bee.trigger_sense()
		bee.sense_cooldown = huddle.scout_cooldown_value()
		message = "摇摆舞传来花源方位：蜜最丰的花田已标出。"
	else:
		bee.trigger_sense()
	if not tutorial_complete and tutorial_step == 3 and bee.sense_time > 0.0:
		tutorial_scent_revealed = true
		context_lessons_seen["sense"] = true
		if tutorial_hidden_index >= 0 and tutorial_hidden_index < flowers.size():
			var hidden: Dictionary = flowers[tutorial_hidden_index]
			hidden.discovered = true
			hidden.tutorial_locked = false
			flowers[tutorial_hidden_index] = hidden
		message = "一缕花香越过了安静的空地。"

func _try_activate_relay_hive() -> bool:
	var action_id := relay_hive.context_action_id(bee.position, carried)
	if action_id.is_empty():
		return false
	var result: Dictionary = relay_hive.try_activate(bee.position, carried)
	match String(result.get("event", "")):
		"needs_honey":
			message = "中继巢需要一滴蜜才能醒来。"
		"activated":
			var consumed := int(result.get("consumed", 0))
			carried = maxi(0, carried - consumed)
			flash = maxf(flash, 0.28)
			sound.play_cue("relay")
			message = "中继巢亮了。它只能让翅膀歇一歇，蜜仍要带回主巢。"
	return true

func _update_relay_hive(delta: float) -> void:
	var resting := bee.velocity.length_squared() < 4.0 and not bee.has_target
	var result: Dictionary = relay_hive.process(
		delta,
		bee.position,
		resting,
		bee.energy,
		effective_energy_cap(),
		warmth,
		season_index_of(stage_index) == 3
	)
	bee.energy = float(result.get("energy", bee.energy))
	warmth = float(result.get("warmth", warmth))
	var is_resting := bool(result.get("resting", false))
	if is_resting and not relay_was_resting:
		message = "中继巢的工蜂托住了翅膀；这里只能恢复一部分。"
	relay_was_resting = is_resting

func spawn_tutorial_mosquito() -> void:
	for mosquito in mosquitoes:
		if bool(mosquito.get("tutorial", false)):
			return
	mosquitoes.append({
		"id": 9000,
		"position": tutorial_resource_position + Vector2(8, -8),
		"velocity": Vector2.ZERO,
		"repel_time": 0.0,
		"tutorial": true,
		"attack_state": "guard",
		"attack_time": 0.0,
		"aim_direction": Vector2.LEFT
	})

func _on_tutorial_harvest(flower_index: int) -> void:
	if tutorial_complete or stage_index != 0:
		return
	if tutorial_step == 3 and tutorial_scent_revealed and flower_index == tutorial_hidden_index:
		tutorial_step = 4
		spawn_tutorial_mosquito()
		message = "蜜源被占住了；把来客推出花圈。"

func _on_tutorial_home(_amount: int) -> void:
	if tutorial_complete or stage_index != 0:
		return
	if tutorial_step == 2 and delivered > 0:
		tutorial_step = 3
		message = "远处有花香，但花还藏在风里。"

func _check_double_tap_evade(_delta: float) -> void:
	if not mentor_tutorial.allows_action("evade"):
		return
	var now := Time.get_ticks_msec() / 1000.0
	var directions := {
		"left": "move_left",
		"right": "move_right",
		"up": "move_up",
		"down": "move_down"
	}
	var pressed_directions: Array[String] = []
	for dir_key in directions:
		if Input.is_action_just_pressed(String(directions[dir_key])):
			pressed_directions.append(String(dir_key))
	_process_evade_pressed_directions(pressed_directions, now)

func _active_evade_attack_direction() -> Vector2:
	if tutorial_step == 5:
		for mosquito in mosquitoes:
			if bool(mosquito.get("tutorial", false)) and String(mosquito.get("attack_state", "")) in ["locked", "dash"]:
				return Vector2(mosquito.get("aim_direction", Vector2.ZERO)).normalized()
	if phase == "boss" and String(current_boss_data.get("move_pattern", "")) == "charge" and String(boss.get("charge_state", "")) in ["aim", "dash"]:
		return Vector2(boss.get("aim_direction", Vector2.ZERO)).normalized()
	return Vector2.ZERO

func _process_evade_pressed_directions(pressed_directions: Array[String], now: float, attack_direction_override := Vector2.ZERO) -> bool:
	# Keep the compatibility/test entry point subject to the same mentor gate as
	# real keyboard input. The reusable controller deliberately knows nothing
	# about Main's tutorial state.
	if not mentor_tutorial.allows_action("evade"):
		_clear_evade_tap_buffers()
		return false
	var attack_direction: Vector2 = attack_direction_override.normalized() if attack_direction_override.length_squared() > 0.01 else _active_evade_attack_direction()
	var result: Dictionary = evade_input_controller.process_pressed_directions(pressed_directions, now, bee, attack_direction)
	return _apply_evade_input_result(result)

func _register_direction_tap(direction_key: String, direction: Vector2, now: float) -> bool:
	if not mentor_tutorial.allows_action("evade"):
		_clear_evade_tap_buffers()
		return false
	var result: Dictionary = evade_input_controller.register_direction_tap(direction_key, direction, now, bee)
	return _apply_evade_input_result(result)

func _clear_evade_tap_buffers() -> void:
	evade_input_controller.clear(bee)

func _apply_evade_input_result(result: Dictionary) -> bool:
	if bool(result.get("evade_started", false)):
		on_evade_started()
		return true
	if bool(result.get("evade_attempted", false)):
		_show_evade_unavailable_feedback()
	return false

func _show_evade_unavailable_feedback() -> void:
	if bee.evade_cooldown > 0.0:
		message = "翅膀还没收稳；急转尚未恢复。"
	elif bee.energy < 12.0:
		message = "体力不足；急转需要 12 点体力。"

func _try_start_evade(direction: Vector2, attempt_origin = null) -> bool:
	if not mentor_tutorial.allows_action("evade"):
		return false
	if bee.try_evade(direction, attempt_origin):
		on_evade_started()
		return true
	_show_evade_unavailable_feedback()
	return false

# This callback confirms the movement input only. A real dodge is confirmed
# separately when a committed attack crosses the position it had locked.
func on_evade_started() -> void:
	show_energy_change(-12.0)
	sound.play_cue("evade")
	message = "急转已发动；是否躲开，要看冲刺有没有穿过旧位置。" if tutorial_step == 5 else "急转。"

func _attack_crossed_locked_target(previous: Vector2, current: Vector2, locked_target: Vector2, radius: float) -> bool:
	return EvadeRulesScript.attack_crossed_locked_target(previous, current, locked_target, radius)

func _evade_cleared_locked_path(attack_direction: Vector2, locked_target: Vector2, sequence_at_lock: int, clearance := EVADE_PATH_CLEARANCE) -> bool:
	return EvadeRulesScript.cleared_locked_path(bee, attack_direction, locked_target, sequence_at_lock, clearance)

func _show_evade_confirmation(locked_target: Vector2, attack_direction: Vector2) -> void:
	evade_confirmation_time = 0.8
	evade_confirmation_position = locked_target
	evade_confirmation_direction = attack_direction.normalized()
	sound.play_cue("evade_clear")

func update_mosquitoes(delta: float) -> void:
	# 蜜香招敌：携带的蜜越多，蚊虫嗅觉半径越大——满载在蚁蚊眼里是显眼的
	var scent_range := balance_value("mosquito", "sense_range", 330.0) + balance_value("mosquito", "sense_per_carry", 0.0) * carried
	for i in mosquitoes.size():
		var mosquito: Dictionary = mosquitoes[i]
		if bool(mosquito.get("tutorial", false)) and not tutorial_complete:
			mosquitoes[i] = _update_tutorial_mosquito(mosquito, delta)
			continue
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
			elif distance_to_player < scent_range and bee.position.x > HIVE_SAFE_X:
				var chase := (bee.position - Vector2(mosquito.position)).normalized()
				mosquito.velocity = Vector2(mosquito.velocity).lerp(chase * 2.1, delta * 2.8)
			mosquito.position += Vector2(mosquito.velocity) * balance_value("mosquito", "move_speed", 82.0) * delta
		mosquito.position.x = clampf(mosquito.position.x, HIVE_SAFE_X, WORLD.end.x - 12)
		mosquito.position.y = clampf(mosquito.position.y, WORLD.position.y + 12, WORLD.end.y - 12)
		# 教学蚊虫只负责制造可读的练习情境；完成急转前不造成惩罚。
		var tutorial_guard := bool(mosquito.get("tutorial", false)) and not tutorial_complete
		if mosquito.repel_time <= 0.0 and not tutorial_guard:
			if distance_to_player < balance_value("mosquito", "impact_range", 26.0) and hit_cooldown <= 0.0 and bee.invulnerable_time <= 0.0:
				hit_cooldown = balance_value("player", "hit_cooldown", 0.9)
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

func _update_tutorial_mosquito(mosquito: Dictionary, delta: float) -> Dictionary:
	mosquito.repel_time = maxf(0.0, float(mosquito.get("repel_time", 0.0)) - delta)
	var position := Vector2(mosquito.position)
	if tutorial_step == 4:
		if float(mosquito.repel_time) > 0.0:
			var away := (position - bee.position).normalized()
			if away.length_squared() < 0.01:
				away = Vector2.RIGHT
			mosquito.velocity = Vector2(mosquito.velocity).lerp(away * 4.2, delta * 9.0)
			position += Vector2(mosquito.velocity) * 96.0 * delta
		else:
			position = position.lerp(tutorial_resource_position + Vector2(8, -8), delta * 4.0)
			mosquito.velocity = Vector2.ZERO
		if position.distance_to(tutorial_resource_position) > 105.0:
			var mentor_result := mentor_tutorial.notify_event("resource_cleared")
			if mentor_result == "repeat_without_prompt":
				# Put the same harmless guard back on the flower. The first clear was
				# prompted imitation; the second must be reproduced without the ribbon.
				position = tutorial_resource_position + Vector2(8, -8)
				mosquito.velocity = Vector2.ZERO
				mosquito.repel_time = 0.0
				message = "花又被占住了。提示收起；再独立清出一次。"
				mosquito.position = position
				return mosquito
			tutorial_step = 5
			context_lessons_seen["danger"] = true
			tutorial_charge_state = "aim"
			tutorial_charge_time = 0.72
			position = Vector2(
				clampf(bee.position.x + 190.0, HIVE_SAFE_X + 80.0, WORLD.end.x - 35.0),
				clampf(bee.position.y - 36.0, WORLD.position.y + 40.0, WORLD.end.y - 40.0)
			)
			tutorial_charge_direction = (bee.position - position).normalized()
			mosquito.attack_state = "aim"
			mosquito.attack_time = tutorial_charge_time
			message = "红色虚线正在跟随；等它变亮、停住，再向线外急转。"
	elif tutorial_step == 5:
		var attack_state := String(mosquito.get("attack_state", "aim"))
		var attack_time := float(mosquito.get("attack_time", 0.0)) - delta
		match attack_state:
			"aim":
				mosquito.velocity = Vector2.ZERO
				tutorial_charge_direction = (bee.position - position).normalized()
				mosquito.aim_direction = tutorial_charge_direction
				if attack_time <= 0.0:
					mosquito.attack_state = "locked"
					mosquito.attack_time = 0.48
					_clear_evade_tap_buffers()
					mosquito.locked_origin = position
					mosquito.locked_target = bee.position
					mosquito.evade_sequence_at_lock = bee.evade_sequence
					tutorial_charge_state = "locked"
					sound.play_cue("attack_lock")
					message = "路线锁定：沿亮色侧标，同一方向连按两次。"
			"locked":
				mosquito.velocity = Vector2.ZERO
				if attack_time <= 0.0:
					mosquito.attack_state = "dash"
					mosquito.attack_time = 0.85
					mosquito.velocity = Vector2(mosquito.get("aim_direction", tutorial_charge_direction)).normalized() * 520.0
					tutorial_charge_state = "dash"
			"dash":
				var previous := position
				position += Vector2(mosquito.velocity) * delta
				var locked_target := Vector2(mosquito.get("locked_target", bee.position))
				var attack_direction := Vector2(mosquito.get("aim_direction", tutorial_charge_direction)).normalized()
				var sequence_at_lock := int(mosquito.get("evade_sequence_at_lock", bee.evade_sequence))
				if _attack_crossed_locked_target(previous, position, locked_target, 29.0):
					if _evade_cleared_locked_path(attack_direction, locked_target, sequence_at_lock):
						_show_evade_confirmation(locked_target, attack_direction)
						var mentor_result := mentor_tutorial.notify_event("attack_evaded")
						if mentor_result == "repeat_without_prompt":
							mosquito.attack_state = "recover"
							mosquito.attack_time = 0.72
							mosquito.velocity = Vector2.ZERO
							message = "急转 1 / 2：冲刺穿过残影；提示收起，再独立完成一次。"
						else:
							if mentor_result == "ignored":
								_complete_contextual_tutorial()
							mosquito.attack_state = "flee"
							mosquito.attack_time = 2.0
							mosquito.velocity = Vector2.RIGHT * 280.0
							message = "急转 2 / 2：冲刺穿过旧位置；已经学会。"
					else:
						tutorial_failed_crossings += 1
						mosquito.attack_state = "recover"
						mosquito.attack_time = 0.72
						shake = 4.0
						flash = 0.22
						if bee.evade_sequence <= sequence_at_lock:
							message = "冲刺穿过旧位置；要在实线锁定后再连按两次。"
						else:
							message = "急转没有离开红色通道；下一次沿亮色侧标连按。"
				elif attack_time <= 0.0 or not WORLD.grow(70.0).has_point(position):
					mosquito.attack_state = "recover"
					mosquito.attack_time = 0.72
			"recover":
				mosquito.velocity = Vector2.ZERO
				if attack_time <= 0.0:
					position = Vector2(
						clampf(bee.position.x + 190.0, HIVE_SAFE_X + 80.0, WORLD.end.x - 35.0),
						clampf(bee.position.y - 36.0, WORLD.position.y + 40.0, WORLD.end.y - 40.0)
					)
					mosquito.attack_state = "aim"
					mosquito.attack_time = 0.72
					mosquito.aim_direction = (bee.position - position).normalized()
					tutorial_charge_state = "aim"
					message = "虚线重新跟随；等它变成实线。"
			"flee":
				position += Vector2(mosquito.velocity) * delta
		if String(mosquito.get("attack_state", "")) == attack_state:
			mosquito.attack_time = attack_time
	mosquito.position = Vector2(
		clampf(position.x, HIVE_SAFE_X, WORLD.end.x - 12.0),
		clampf(position.y, WORLD.position.y + 12.0, WORLD.end.y - 12.0)
	)
	return mosquito

func _complete_contextual_tutorial() -> void:
	if tutorial_complete:
		return
	tutorial_step = 6
	tutorial_complete = true
	tutorial_charge_state = "complete"
	for i in flowers.size():
		var flower: Dictionary = flowers[i]
		flower.tutorial_locked = false
		flowers[i] = flower
	if mentor_tutorial.profile_id == "first_trip_pollination" and mentor_tutorial.lesson_id == "pollination":
		message = "第二朵花也开始结籽。老师傅退回巢口；接下来由你判断。"
	else:
		message = "攻击穿过了急转留下的空隙；前路开了。"
	sound.play_cue("tune")

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
			hit_cooldown = balance_value("player", "hit_cooldown", 0.9)
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
			hit_cooldown = balance_value("player", "hit_cooldown", 0.9)
			bee.energy = maxf(0.0, bee.energy - balance_value("bear", "contact_damage", 16.0))
			show_energy_change(-balance_value("bear", "contact_damage", 16.0))
			shake = 8.0
			flash = 0.5
			message = "你撞上了熊的肩膀。别和它较劲——绕开。"
			sound.play_cue("hurt")
		bears[i] = bear

func update_hive_rest(delta: float, deposit_honey: bool) -> void:
	var inside := is_in_hive_entry(bee.position)
	if not inside:
		was_in_hive = false
		hive_dwell_time = 0.0
		return
	hive_dwell_time += delta
	# 入巢延迟：站稳 hive_deposit_delay 秒才卸蜜——归巢是停靠决策，不是贴边擦存
	var deposit_ready := deposit_honey and carried > 0 and hive_dwell_time >= balance_value("player", "hive_deposit_delay", 0.4)
	var message_before_home := message
	season_mechanics.on_home(carried if deposit_ready else 0, delta)
	var mechanics_home_message := message if message != message_before_home else ""
	var home_event: Dictionary = {}
	if season_mechanics.has_method("latched_event"):
		home_event = season_mechanics.latched_event()
	if not String(home_event.get("id", "")).is_empty():
		hive_activity_time = maxf(hive_activity_time, 1.2)
	var rest_rate := balance_value("player", "hive_rest_per_second", 36.0)
	if season_index_of(stage_index) == 3 and warmth <= cold_warmth_threshold:
		rest_rate *= 0.5
	bee.energy = minf(effective_energy_cap(), bee.energy + rest_rate * delta)
	if deposit_ready:
		var amount := carried
		delivered += amount
		carried = 0
		var message_before_tutorial := message
		_on_tutorial_home(amount)
		var tutorial_home_message := message if message != message_before_tutorial else ""
		if not tutorial_home_message.is_empty():
			message = tutorial_home_message
		elif not mechanics_home_message.is_empty():
			# 袭扰出现、种核成熟等世界事件不能被同帧的通用卸蜜提示盖掉。
			message = mechanics_home_message
		else:
			message = "安全归巢，存入 %d 滴蜜。蜂群的照料正在恢复体力。" % amount
		sound.play_cue("home")
		flash = 0.32
		hive_activity_time = 1.2
	elif not was_in_hive:
		if deposit_honey and carried > 0:
			message = "落巢了。卸蜜需要站稳片刻——别急着再飞。"
		else:
			message = "即使空手归来，蜂巢也会接纳你。停留片刻恢复体力。"
	was_in_hive = true

func fail_expedition() -> void:
	hive_lives -= 1
	var lost_honey := carried
	carried = 0
	# 力竭代价加重：已入库的进度也按 exhaustion_delivered_penalty 回退——
	# 回退的蜜以返蜜花回到花田，花蜜守恒不破
	var lost_delivered := mini(int(balance_value("player", "exhaustion_delivered_penalty", 2)), delivered)
	delivered -= lost_delivered
	return_honey_to_field(lost_honey + lost_delivered, bee.position)
	# 扣命演出：蜂巢呼吸的圆点闪红——代价必须被看见，而不是右上角悄悄变一个符号
	hive_flash_time = 1.0
	if hive_lives <= 0:
		# 终局失败页保留体力 0 与倒下的位置。此前先回巢重置再判负，
		# 失败页体力条会显示满格 100，玩家以为体力没耗尽过。
		bee.active = false
		show_loss()
		return
	bee.reset_for_expedition(Vector2(180, 410))
	# 力竭归巢不再满体力：蜂群的照料需要时间，回巢停留才靠 hive_rest_per_second 恢复
	bee.energy = balance_value("player", "post_failure_energy", 45.0)
	shake = 10.0
	message = "你没能带回花蜜，蜂巢的呼吸弱了一分。洒落的 %d 滴蜜将孕育返蜜花。" % lost_honey
	if lost_delivered > 0:
		message += "已入库的 %d 滴也被搬回了花田。" % lost_delivered

# 显式饮蜜：E 键主动饮下蜜囊里的一滴蜜续力。蜜蜂飞行燃料本就来自蜜囊，
# 被饮下的蜜不生成返蜜花：它转化成了飞行本身，仍在能量意义上守恒。
# 每节气受 crop_fuel_limit 限制：用尽后即使仍有蜜也不再续力。
func _drink_honey() -> bool:
	if carried <= 0:
		message = "蜜囊已经空了。"
		return false
	if crop_fuel_used >= int(balance_value("player", "crop_fuel_limit", 2)):
		message = "这趟出勤，蜜囊续力已到尽头。"
		return false
	if bee.energy >= effective_energy_cap() - 0.01:
		message = "翅膀正有力，先留下这滴蜜。"
		return false
	carried -= 1
	crop_fuel_used += 1
	# 续力是加法而非设定：旧自动续命只在体力见底时触发，「设为 refill」碰巧等价于
	# 「+refill」；显式饮蜜可在体力未满时主动触发，必须改成增量并钳到体力上限，
	# 否则高体力时饮蜜只回零头、甚至被倒扣。飘字显示真实增量而非绝对值。
	var before_energy := bee.energy
	bee.energy = clampf(bee.energy + balance_value("player", "crop_fuel_refill", 22.0), 0.0, effective_energy_cap())
	show_energy_change(bee.energy - before_energy)
	# 续力必须被看见：体力条短暂提亮，配合飘字说明这份力气是喝出来的
	energy_bar_flash_time = 0.8
	flash = 0.28
	sound.play_cue("drink")
	message = "你饮下蜜囊里的一滴蜜，翅膀重新有了力气。"
	return true

## 鼠标/触控的饮蜜入口只在动作真实有效时出现；公开这个判定也让 HUD、
## 键盘路径和自动测试共用一份事实，避免“按钮看得见但按了没反应”。
func can_drink_honey() -> bool:
	return (
		phase == "playing"
		and bee != null
		and mentor_tutorial.allows_action("drink")
		and carried > 0
		and crop_fuel_used < int(balance_value("player", "crop_fuel_limit", 2))
		and bee.energy < effective_energy_cap() - 0.01
	)

func on_drink_honey_pressed() -> void:
	if not can_drink_honey():
		return
	_drink_honey()
	update_interface()

## The project deliberately disables touch-to-mouse emulation so one physical
## tap cannot count twice toward evade. BaseButton therefore owns mouse input,
## while this small state machine gives the drink control equivalent single-touch
## semantics: start inside, keep the same finger inside, release to confirm.
func _handle_drink_touch_input(event: InputEvent) -> bool:
	if drink_button == null:
		return false
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			if not drink_button.visible or drink_button.disabled or not can_drink_honey():
				return false
			if not drink_button.get_global_rect().has_point(touch.position):
				return false
			# Extra fingers over the same button are consumed but never replace the
			# finger that began the action.
			if drink_touch_index < 0:
				drink_touch_index = touch.index
				drink_touch_armed = true
				drink_button.set_pressed_no_signal(drink_touch_armed)
			return true
		if touch.index != drink_touch_index:
			return false
		var should_drink := (
			drink_touch_armed
			and not touch.canceled
			and drink_button.visible
			and not drink_button.disabled
			and drink_button.get_global_rect().has_point(touch.position)
			and can_drink_honey()
		)
		_cancel_drink_touch()
		if should_drink:
			on_drink_honey_pressed()
		return true
	if event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index != drink_touch_index:
			return false
		drink_touch_armed = (
			drink_button.visible
			and not drink_button.disabled
			and drink_button.get_global_rect().has_point(drag.position)
			and can_drink_honey()
		)
		drink_button.set_pressed_no_signal(drink_touch_armed)
		return true
	return false

func _cancel_drink_touch() -> void:
	drink_touch_index = -1
	drink_touch_armed = false
	if drink_button != null:
		drink_button.set_pressed_no_signal(false)

# 力竭停顿拍：蜜尽才真正倒下。短暂静止 + 画面转暗，让玩家看清
# 体力条归零与损失清单（此前同帧重置导致体力条从未显示过 0）。
func begin_exhaustion() -> void:
	phase = "exhausted"
	bee.active = false
	bee.velocity = Vector2.ZERO
	bee.has_target = false
	exhaustion_timer = balance_value("player", "exhaustion_beat_seconds", 1.1)
	shake = 10.0
	sound.play_cue("loss")
	message = "翅膀停在了半空。携带的 %d 滴蜜将洒落花田，蜂巢的呼吸弱了一分……" % carried

func resolve_exhaustion() -> void:
	fail_expedition()
	if phase == "exhausted":
		phase = "playing"

func show_between() -> void:
	phase = "between"
	bee.active = false
	music.enter_hive()
	overlay.visible = true
	var data: Dictionary = stages[stage_index]
	if persistence_enabled:
		save_manager.record_stage(stage_index + 1)
	refresh_runs_meter()
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
	allocation_panel.visible = false
	var any_available := false
	for i in upgrade_catalog.size():
		var entry: Dictionary = upgrade_catalog[i]
		if int(upgrade_counts.get(String(entry.id), 0)) < UPGRADE_CAP:
			any_available = true
			break
	if not any_available:
		overlay_title.text = "归巢 · 蜂群安定"
		overlay_body.text = "三种分工都已成熟。蜂群按既定的节奏继续运转。" + next_boss_hint()
		overlay_button.text = "再次出巢"
		overlay_button.visible = true
		set_upgrade_buttons_visible(false)
		set_secondary_link("或者退出游戏", true)
		focus_overlay_primary()
		return
	overlay_title.text = "归巢 · 蜂群成长"
	overlay_body.text = "带回的蜜哺育了新的分工。选择一种蜂群倾向；本轮效果可以叠加。" + next_boss_hint()
	overlay_button.visible = false
	set_upgrade_buttons_visible(true)
	set_secondary_link("", false)
	focus_overlay_primary()

# 通关横幅只写「刚刚完成的节令」，玩家无从知道下一个节点是失律者关卡——
# 在蜂巢成长界面直接预告，消除「惊蛰完成却撞上春分 Boss」的错位感
func next_boss_hint() -> String:
	if stage_index + 1 >= stages.size():
		return ""
	if not is_boss_stage(stage_index + 1):
		return ""
	var next_boss := boss_data_for_stage(stage_index + 1)
	var boss_name := String(next_boss.get("name", "失律者"))
	return "\n\n前方的节律忽然断了——%s在等着你。" % boss_name

func show_allocation_panel() -> void:
	overlay_title.text = "分配收成"
	overlay_body.text = ""
	set_upgrade_buttons_visible(false)
	set_secondary_link("", false)
	overlay_button.visible = false
	allocation_body_label.text = "带回 %d 滴蜜。公共储备维持蜂巢；幼虫会提高之后的飞行上限。" % allocation_harvest
	allocation_panel.visible = true
	allocation_slider.value = 50.0
	refresh_allocation_labels()
	focus_overlay_primary()

func refresh_allocation_labels() -> void:
	if allocation_panel == null or not allocation_panel.visible:
		return
	var fed := roundi(allocation_harvest * allocation_fraction)
	var stored := allocation_harvest - fed
	allocation_left_label.text = "公共储备　%02d 滴" % stored
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
	configure_upgrade_focus_navigation()

func configure_upgrade_focus_navigation() -> void:
	var available: Array[Button] = []
	for button in upgrade_buttons:
		button.focus_neighbor_left = NodePath("")
		button.focus_neighbor_right = NodePath("")
		button.focus_previous = NodePath("")
		button.focus_next = NodePath("")
		if button.visible and not button.disabled:
			available.append(button)
	if available.size() < 2:
		return
	for i in available.size():
		var previous := available[(i - 1 + available.size()) % available.size()]
		var next := available[(i + 1) % available.size()]
		available[i].focus_neighbor_left = available[i].get_path_to(previous)
		available[i].focus_neighbor_right = available[i].get_path_to(next)
		available[i].focus_previous = available[i].get_path_to(previous)
		available[i].focus_next = available[i].get_path_to(next)

func set_secondary_link(text_: String, value: bool) -> void:
	if secondary_link == null:
		return
	secondary_link.text = text_
	secondary_link.visible = value and text_ != ""

func on_secondary_link() -> void:
	# overlay 阶段次要操作：退出游戏（让玩家不必回到 HUD 顶部点「退出」）
	# boss_loss 已被 on_overlay_button 路由，不允许用此函数逃避重玩。
	if phase not in ["intro", "won", "lost", "paused"]:
		return
	if phase == "intro" and get_tree().current_scene == self:
		var commercial_persistence := _commercial_persistence()
		if commercial_persistence != null and commercial_persistence.progress_file_exists():
			if not new_journey_confirmation_armed:
				new_journey_confirmation_armed = true
				secondary_link.text = "再按一次：清除旧旅程"
				overlay_body.text = "旧旅程会被清除；声音、显示与无障碍设置会保留。\n若不想清除，请选择继续或按 Esc 离开。"
				secondary_link.grab_focus()
				return
			var delete_error := commercial_persistence.delete_progress()
			if delete_error != OK:
				overlay_body.text = "旧旅程没有安全清除（错误 %d）。没有开始新旅程。" % delete_error
				return
			commercial_persistence.request_journey_launch("new")
			get_tree().change_scene_to_packed(JOURNEY_SCENE)
			return
	# Web 平台浏览器拦截主动关闭窗口：玩家已主动点「或者退出游戏」时，
	# 直接调 quit() 让浏览器兜底拦截（关 tab 即可离开），避免重复弹窗干扰。
	get_tree().quit()

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
	# Boss encounters own their exposure rules and tuning blooms. End ordinary
	# stage mechanics before clearing flowers so no stale route index can draw.
	season_mechanics.end_stage()
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
	sting_cooldown = 0.0
	hit_cooldown = 0.0
	sound.set_season(int(data.season_index))
	music.enter_boss(current_boss_index)
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
	evade_confirmation_time = 0.0
	_clear_evade_tap_buffers()
	pollen.clear()
	decoys.clear()
	boss_afterimages.clear()
	tuning_blooms.clear()
	for i in int(data.bloom_count):
		tuning_blooms.append(Vector2(360.0 + i * 180.0, clampf(285.0 + sin(float(i) * 2.4) * 150.0, 200.0, 600.0)))
	boss_director.reset(String(data.move_pattern), int(data.required_tunings))
	boss = {
		"position": Vector2(840, 410),
		"velocity": Vector2.ZERO,
		"hits": 0,
		"hit_cooldown": 0.0,
		"pattern_time": 0.0,
		"next_shift": 0.0,
		"charge_state": "wander",
		"state_time": 0.0,
		"aim_direction": Vector2.RIGHT,
		"locked_origin": Vector2.ZERO,
		"locked_target": Vector2.ZERO,
		"evade_sequence_at_lock": 0,
		"feed_clock": 1.4,
		"landing_clock": 1.2,
		"illusion_clock": 1.0,
		"evade_armed": false,
		"telegraph": ""
	}
	boss_hive_heals_remaining = 2
	boss_hive_was_inside = false
	bee.configure(1.45 + float(data.season_index) * 0.2)
	bee.set_spring_launch_art(world_art_ready())
	bee.reset_for_expedition(Vector2(180, 410))
	carried = 6
	delivered = 0
	message = ""
	# 关卡间唯一需要清理的 overlay 状态：上一节令蜂巢成长面板的 title/body
	# 还会保留在内存里——一旦 overlay 因为任何理由再变可见（例如调试、热键、
	# 红点回放），stale 的「春分完成 · 蜂巢成长」会让玩家误判当前还在选蜂倾向，
	# 进而怀疑失律者战败提示是不是错位。这里显式清空，避免幽灵文本。
	overlay_title.text = ""
	overlay_body.text = ""

func update_boss(delta: float) -> void:
	if current_boss_data.is_empty():
		return
	var data: Dictionary = current_boss_data
	_check_double_tap_evade(delta)
	sting_cooldown = maxf(0.0, sting_cooldown - delta)
	boss.hit_cooldown = maxf(0.0, float(boss.hit_cooldown) - delta)
	boss.pattern_time = float(boss.pattern_time) + delta
	var pattern := String(data.move_pattern)
	boss_director.update(delta)
	var director_state: Dictionary = boss_director.draw_state()
	var parameters: Dictionary = director_state.get("parameters", {})
	var speed_multiplier := float(parameters.get("speed_multiplier", 1.0))
	var attack_interval := float(parameters.get("attack_interval", 2.4))
	var previous_position := Vector2(boss.position)
	var to_bee := bee.position - previous_position
	var move_speed := float(data.move_speed) * speed_multiplier
	var action_pressed := Input.is_action_just_pressed("action")
	var action_became_sense := false

	# The thrush cannot be solved by blind vibration. The first action while its
	# true voice is hidden is a real sense pulse; the next, during the reveal
	# window and at close range, is the tuning attempt.
	if action_pressed and pattern == "lure" and not boss_director.can_tune() and bee.sense_cooldown <= 0.0:
		_reveal_boss_truth()
		action_became_sense = true

	match pattern:
		"orbital":
			# 蚊先以一条逐渐收紧的吸食线索取花蜜；腹部饱胀后的短暂停顿才是破绽。
			boss.feed_clock = float(boss.feed_clock) - delta
			boss.telegraph = ""
			if boss_director.can_tune():
				boss.velocity = Vector2(boss.velocity).lerp(Vector2.ZERO, delta * 7.0)
				boss.telegraph = "sated"
			else:
				if float(boss.feed_clock) <= 0.0:
					if to_bee.length() <= 175.0:
						carried = maxi(0, carried - 1)
						boss_director.notify_feed_completed()
						boss.feed_clock = attack_interval
						boss.telegraph = "sated"
						message = "它吸得太满，飞行忽然失了拍。"
					else:
						boss.feed_clock = 0.35
				elif float(boss.feed_clock) < 0.65 and to_bee.length() <= 220.0:
					boss.telegraph = "siphon"
				var orbit := to_bee.normalized().rotated(sin(elapsed * 1.7) * 0.45)
				boss.velocity = Vector2(boss.velocity).lerp(orbit * 2.2, delta * 1.7)
		"erratic":
			# 油葫芦的虚影仍在飞，只有实体落地留下的压低影子可调律。
			boss.landing_clock = float(boss.landing_clock) - delta
			boss.telegraph = ""
			if boss_director.can_tune():
				boss.velocity = Vector2.ZERO
				boss.telegraph = "landing"
			elif float(boss.landing_clock) <= 0.0:
				boss_director.notify_landed()
				boss.landing_clock = attack_interval
				boss.velocity = Vector2.ZERO
				boss.telegraph = "landing"
			else:
				if float(boss.pattern_time) >= float(boss.next_shift):
					boss.next_shift = float(boss.pattern_time) + rng.randf_range(0.28, 0.65)
					var heading := to_bee.normalized() if to_bee.length() > 380.0 else Vector2.from_angle(rng.randf() * TAU)
					boss.velocity = heading * 2.6
					boss_afterimages.append({"position": previous_position, "life": 0.7, "false_echo": true})
		"lure":
			# 画眉用多个假回声拉开路线；寻迹会一次清空假声并照亮真身。
			var tangent_sign := 1.0 if int(data.season_index) % 2 == 0 else -1.0
			var tangent := to_bee.normalized().rotated(PI * 0.5 * tangent_sign)
			var radial := clampf((to_bee.length() - 240.0) / 240.0, -1.0, 1.0)
			boss.velocity = Vector2(boss.velocity).lerp((to_bee.normalized() * radial + tangent * 0.85) * 1.5, delta * 2.2)
			boss.illusion_clock = float(boss.illusion_clock) - delta
			if float(boss.illusion_clock) <= 0.0 and not boss_director.can_tune():
				boss.illusion_clock = attack_interval
				var feints := int(parameters.get("feint_count", 2))
				for feint_index in feints:
					var angle := TAU * float(feint_index) / maxf(1.0, float(feints)) + elapsed
					boss_afterimages.append({"position": previous_position + Vector2.from_angle(angle) * (58.0 + feint_index * 16.0), "life": attack_interval, "false_echo": true})
			boss.telegraph = "truth" if boss_director.can_tune() else "song"
		"charge":
			# 熊必须在冲锋中逼出一次急转，再撞进暖花；普通停顿不是调律窗口。
			boss.telegraph = "warm_stun" if boss_director.can_tune() else String(boss.charge_state)
			if boss_director.can_tune():
				boss.velocity = Vector2.ZERO
			else:
				match String(boss.charge_state):
					"wander":
						boss.velocity = Vector2(boss.velocity).lerp(to_bee.normalized() * 0.7, delta * 1.2)
						if to_bee.length() < 320.0:
							boss.charge_state = "aim"
							boss.state_time = 0.9 / speed_multiplier
							_clear_evade_tap_buffers()
							boss.aim_direction = to_bee.normalized()
							boss.locked_origin = previous_position
							boss.locked_target = bee.position
							boss.evade_sequence_at_lock = bee.evade_sequence
							boss.evade_armed = false
					"aim":
						boss.state_time = float(boss.state_time) - delta
						boss.velocity = Vector2(boss.velocity).lerp(Vector2.ZERO, delta * 6.0)
						if float(boss.state_time) <= 0.0:
							boss.charge_state = "dash"
							boss.state_time = 1.0 / speed_multiplier
							boss.velocity = Vector2(boss.aim_direction) * 4.2
					"dash":
						boss.state_time = float(boss.state_time) - delta
						boss.velocity = Vector2(boss.velocity).lerp(Vector2(boss.aim_direction) * 4.2, delta * 2.0)
						if float(boss.state_time) <= 0.0:
							boss.charge_state = "wander"
							boss.state_time = 0.0
					"rest":
						boss.state_time = float(boss.state_time) - delta
						boss.velocity = Vector2(boss.velocity).lerp(Vector2.ZERO, delta * 5.0)
						if float(boss.state_time) <= 0.0:
							boss.charge_state = "wander"

	boss.position += Vector2(boss.velocity) * move_speed * delta
	boss.position.x = clampf(boss.position.x, HIVE_SAFE_X + 18.0, WORLD.end.x - 28)
	boss.position.y = clampf(boss.position.y, WORLD.position.y + 28, WORLD.end.y - 28)
	var boss_position := Vector2(boss.position)

	if pattern == "charge" and String(boss.charge_state) == "dash" and not bool(boss.evade_armed):
		if _evade_cleared_locked_path(
			Vector2(boss.get("aim_direction", Vector2.RIGHT)),
			Vector2(boss.get("locked_target", bee.position)),
			int(boss.get("evade_sequence_at_lock", bee.evade_sequence)),
			float(data.impact_range)
		):
			boss.evade_armed = true
			_show_evade_confirmation(Vector2(boss.locked_target), Vector2(boss.aim_direction))
			message = "急转离开了锁定路线；现在让冲锋撞向暖花。"

	if pattern == "charge" and String(boss.charge_state) == "dash" and bool(boss.evade_armed):
		for bloom_position in tuning_blooms:
			if boss_position.distance_to(bloom_position) < 52.0:
				if boss_director.notify_evade_collision(true):
					boss.charge_state = "rest"
					boss.state_time = float(parameters.get("window_seconds", 1.2))
					boss.velocity = Vector2.ZERO
					boss.telegraph = "warm_stun"
					message = "暖花接住了冲锋，冰壳裂开了。"
				break

	for i in range(boss_afterimages.size() - 1, -1, -1):
		boss_afterimages[i].life = float(boss_afterimages[i].life) - delta
		if float(boss_afterimages[i].life) <= 0.0:
			boss_afterimages.remove_at(i)

	var closest_on_attack := Geometry2D.get_closest_point_to_segment(bee.position, previous_position, boss_position)
	if closest_on_attack.distance_to(bee.position) < float(data.impact_range) and bee.invulnerable_time <= 0.0 and boss.hit_cooldown <= 0.0:
		boss.hit_cooldown = 1.0
		bee.energy = maxf(0.0, bee.energy - float(data.energy_damage))
		show_energy_change(-float(data.energy_damage))
		carried = maxi(0, carried - int(data.honey_damage))
		shake = 9.0
		sound.play_cue("hurt")
		flash = 0.55
		message = String(data.damage_message)

	if action_pressed and not action_became_sense:
		_attempt_boss_tune()

	_update_boss_hive_rest()

	if bee.energy <= 0.0:
		# 失律者战败扣 1 命；若归律前蜂巢已散，走全轮结算页
		hive_lives -= 1
		hive_flash_time = 1.0
		message = "你没能完成调律，蜂群的节律又弱了一分。"
		shake = 10.0
		sound.play_cue("loss")
		if hive_lives <= 0:
			show_loss()
		else:
			show_boss_loss()

func _reveal_boss_truth() -> bool:
	if phase != "boss" or current_boss_data.is_empty() or String(current_boss_data.move_pattern) != "lure":
		return false
	if bee.sense_cooldown > 0.0 or not boss_director.notify_sense():
		return false
	bee.trigger_sense()
	boss_afterimages.clear()
	message = "回声散开，真声短暂露了出来。"
	sound.play_cue("sense")
	return true

func _attempt_boss_tune() -> bool:
	if phase != "boss" or current_boss_data.is_empty() or sting_cooldown > 0.0:
		return false
	var pattern := String(current_boss_data.move_pattern)
	var bloom_index := nearest_tuning_bloom(boss.position)
	if bee.position.distance_to(boss.position) >= sting_range + 7.0 or bloom_index < 0 or not boss_director.can_tune():
		message = _boss_exposure_hint(pattern)
		return false
	if not bee.spend_energy(sting_cost):
		message = "翅膀太沉，先撤回蜂巢。"
		return false
	show_energy_change(-sting_cost)
	sting_cooldown = balance_value("player", "repel_cooldown", 1.15) * sting_cooldown_multiplier
	var bloom_position := tuning_blooms[bloom_index]
	if not boss_director.register_tune():
		return false
	tuning_blooms.remove_at(bloom_index)
	boss.hits = boss_director.tunings
	music.set_boss_tuning_progress(int(boss.hits))
	boss.velocity = (boss.position - bee.position).normalized() * 8.0
	spawn_pollen(bloom_position)
	shake = 7.0
	message = String(current_boss_data.tuning_message).replace("{n}", str(int(boss.hits)))
	sound.play_cue("tune")
	var next_parameters: Dictionary = boss_director.parameters
	var next_interval := float(next_parameters.get("attack_interval", 2.4))
	boss.feed_clock = next_interval
	boss.landing_clock = next_interval
	boss.illusion_clock = next_interval
	boss.charge_state = "wander"
	if int(boss.hits) >= int(current_boss_data.required_tunings):
		if current_boss_index >= boss_catalog.size() - 1:
			show_win()
		else:
			show_boss_victory()
	return true

func _boss_exposure_hint(pattern: String) -> String:
	match pattern:
		"orbital":
			return "吸食线收紧后，它会因饱胀停拍。"
		"erratic":
			return "虚影还在飞；等实体真正落地。"
		"lure":
			return "先停稳寻迹，真声只会露出片刻。"
		"charge":
			return "把暖花留在冲锋路上；红线锁定后向线外连按两次。"
	return "观察动作，等破绽出现。"

func _update_boss_hive_rest() -> void:
	var inside := is_in_hive_entry(bee.position)
	if not inside:
		boss_hive_was_inside = false
		return
	if boss_hive_was_inside:
		return
	boss_hive_was_inside = true
	if boss_hive_heals_remaining <= 0:
		message = "蜂巢已把这一战能给的力气都给了。"
		return
	boss_hive_heals_remaining -= 1
	var before := bee.energy
	bee.energy = minf(effective_energy_cap(), bee.energy + 28.0)
	show_energy_change(bee.energy - before)
	sound.play_cue("home")
	message = "蜂巢托住你一次；还剩 %d 次照料。" % boss_hive_heals_remaining

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
	overlay_body.text = "花田重新流动。\n\n%s" % next_term_hint()
	overlay_button.text = "继续前行"
	set_secondary_link("", false)
	focus_overlay_primary()

func next_term_hint() -> String:
	if stage_index + 1 >= stages.size():
		return ""
	return "前路重新打开。"

func show_win() -> void:
	phase = "won"
	bee.active = false
	overlay.visible = true
	overlay_button.visible = true
	set_upgrade_buttons_visible(false)
	if persistence_enabled:
		save_manager.record_completion(run_elapsed)
	refresh_runs_meter()
	sound.play_cue("win")
	overlay_title.text = "蜂巢重新发亮"
	overlay_body.text = "蜂群走完了完整循环，四位失律者重归节拍。\n本轮主动游玩时间：%s" % format_duration(run_elapsed)
	overlay_button.text = "再走一次"
	set_secondary_link("或者退出游戏", true)
	focus_overlay_primary()

func show_loss() -> void:
	# `lost` is shared by ordinary gathering and the last life of a Boss fight.
	# Keep the origin before changing phase so the always-updating HUD does not
	# read the goal-less Boss stage dictionary as an ordinary gathering stage.
	lost_from_phase = phase
	phase = "lost"
	bee.active = false
	overlay.visible = true
	overlay_button.visible = true
	set_upgrade_buttons_visible(false)
	sound.play_cue("loss")
	if persistence_enabled:
		save_manager.record_failure(run_elapsed)
	refresh_runs_meter()
	# hive_lives 已经在 fail_expedition / boss_loss 里清零：
	# 整轮散了，强制回到起点；不再重复讲解内部章节结构。
	overlay_title.text = "这一次，\n蜂巢没有撑住"
	overlay_body.text = "蜂巢已经散落。\n远花仍在那里，但带回家的蜜才真正属于蜂群。\n本轮主动游玩时间：%s" % format_duration(run_elapsed)
	overlay_button.text = "重新出巢"
	set_secondary_link("或者退出游戏", true)
	focus_overlay_primary()

# 失律者战败但蜂巢还有余力：不要把玩家推回立春，用上一节令的成长心得也能再试一次。
# 同时把上一节令「蜂巢成长」面板的 stale 文案显式覆盖掉，避免红点/回放
# 让玩家误以为「我还在蜂巢成长界面」。
func show_boss_loss() -> void:
	phase = "boss_loss"
	bee.active = false
	overlay.visible = true
	overlay_button.visible = true
	set_upgrade_buttons_visible(false)
	sound.play_cue("loss")
	var boss_name := "失律者"
	if not current_boss_data.is_empty():
		boss_name = String(current_boss_data.get("name", "失律者"))
	overlay_title.text = "%s · 调律未竟" % boss_name
	overlay_body.text = (
		"它还在花田上游荡。\n回到蜂巢歇一歇，这场交锋还会再来；剩余机会："
		+ "●".repeat(maxi(0, hive_lives)) + "○".repeat(maxi(0, 3 - hive_lives))
		+ "\n本次已落蜜 %d 滴。" % delivered
	)
	overlay_button.text = "再试一次"
	set_secondary_link("", false)
	focus_overlay_primary()

func nearest_flower(radius: float) -> int:
	var best := -1
	var best_distance := radius
	for i in flowers.size():
		var flower: Dictionary = flowers[i]
		if int(flower.nectar) <= 0 or bool(flower.get("sleeping", false)) or float(flower.get("flatten_time", 0.0)) > 0.0:
			continue
		if bool(flower.get("tutorial_locked", false)) or (bool(flower.get("tutorial_hidden", false)) and not bool(flower.get("discovered", false))):
			continue
		if season_mechanics != null and season_mechanics.has_method("is_flower_available") and not bool(season_mechanics.is_flower_available(i)):
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
		if bool(flower.get("tutorial_locked", false)) or (bool(flower.get("tutorial_hidden", false)) and not bool(flower.get("discovered", false))):
			continue
		if season_mechanics != null and season_mechanics.has_method("is_flower_available") and not bool(season_mechanics.is_flower_available(i)):
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
		if valid and relay_hive.enabled and candidate.distance_to(relay_hive.position) < 92.0:
			valid = false
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
	flowers.append({
		"id": recovery_flower_serial,
		"position": recovery_position,
		"nectar": amount,
		"max_nectar": amount,
		"kind": 1,
		"visual_variant": 1,
		"large_bloom": true,
		"phase": rng.randf_range(0, TAU),
		"recovery": true,
		"type": "nectar_bloom"
	})
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

# Legal player choices consume honey permanently: up to two drinks in every
# field, every autumn flower may become a seed, and all winter relays require
# fuel. Reserve that budget when the stage is authored so choosing a mechanic
# can never make the remaining goal mathematically impossible.
func stage_permanent_honey_budget(index: int) -> int:
	if index < 0 or index >= stages.size() or stages[index].has("boss"):
		return 0
	var budget := int(balance_value("player", "crop_fuel_limit", 2))
	var mechanic_ids: Array = stages[index].get("mechanics", [])
	if mechanic_ids.has("reserve"):
		budget += flowers.size()
	if mechanic_ids.has("huddle"):
		var huddle = season_mechanics.mechanic_by_id("huddle")
		if huddle != null:
			budget += huddle.warm_points.size() * int(huddle.activation_honey_cost)
	if relay_hive.enabled:
		budget += int(relay_hive.activation_cost)
	return budget

func _ensure_stage_resource_budget() -> void:
	if stage_index < 0 or stage_index >= stages.size() or stages[stage_index].has("boss"):
		return
	var required_total := int(stages[stage_index].goal) + stage_permanent_honey_budget(stage_index)
	var deficit := required_total - total_recoverable_honey()
	if deficit <= 0:
		return
	# Add the safety margin to a real, already-open flower. Recovery flowers are
	# inappropriate here because winter route locking is built before this audit.
	for i in range(flowers.size() - 1, -1, -1):
		var flower: Dictionary = flowers[i]
		if bool(flower.get("showcase_seed", false)):
			continue
		if bool(flower.get("tutorial_locked", false)) or bool(flower.get("tutorial_hidden", false)):
			continue
		flower.nectar = int(flower.get("nectar", 0)) + deficit
		flower.max_nectar = maxi(int(flower.get("max_nectar", 0)), int(flower.nectar))
		flowers[i] = flower
		return

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

func mentor_completion_requirement() -> String:
	if mentor_tutorial.profile_id.is_empty() or mentor_tutorial.phase in ["inactive", "complete"]:
		return ""
	var lesson := String(mentor_tutorial.lesson_id)
	match String(mentor_tutorial.phase):
		"demo":
			var demonstrations := {
				"sortie": "采蜜归巢",
				"sense": "停稳寻迹",
				"defense": "惊退占花者",
				"evade": "急转闪避",
				"pollination": "同型花传粉",
				"raid": "花田袭扰",
				"seed": "留种取舍",
				"warmth": "点亮暖点"
			}
			var demonstration := String(demonstrations.get(lesson, ""))
			return "教学 · 观看%s示范" % demonstration if not demonstration.is_empty() else ""
		"imitate":
			return String({
				"sortie": "教学 · 完成一次采蜜归巢",
				"sense": "教学 · 停稳寻迹，找出藏花",
				"defense": "教学 · 把占花者推出资源区",
				"evade": "教学 · 用急转避开一次冲刺",
				"pollination": "教学 · 让第一朵同花型花结籽",
				"raid": "教学 · 等它偷蜜后再惊退",
				"seed": "教学 · 留种并归巢一次",
				"warmth": "教学 · 点亮第一处暖点"
			}.get(lesson, ""))
		"practice":
			return String({
				"sortie": "教学 · 再独立采蜜归巢一次",
				"sense": "教学 · 采到寻迹找出的藏花",
				"defense": "教学 · 再把占花者推出资源区",
				"evade": "教学 · 再用急转避开一次冲刺",
				"pollination": "教学 · 再让一朵同花型花结籽",
				"raid": "教学 · 惊退剩余袭扰者",
				"seed": "教学 · 再独立完成一次留种取舍",
				"warmth": "教学 · 点亮剩余暖点"
			}.get(lesson, ""))
	return ""

func update_interface() -> void:
	if stages.is_empty():
		return
	var data: Dictionary = stages[stage_index]
	# The HUD still updates every frame behind overlays. Preserve Boss context
	# through victory, retry, pause and final loss. Explicit Boss stages have no
	# `goal`, while the terminal bear reuses an ordinary stage index, so phase
	# origin is the only safe discriminator.
	var boss_context := _uses_boss_interface_context()
	if boss_context:
		term_label.text = ""
	else:
		# 节令只在章节转场出现；行动中让色彩、花型、敌害与音乐承担季候表达。
		term_label.text = ""
	carried_label.text = "%d / %d" % [carried, int(carry_capacity)]
	# 蜜囊满额：携带条闪红，飘字只在初次
	if carry_full_flash_time > 0.0:
		var carry_pulse := 0.5 + 0.5 * sin(carry_full_flash_time * 24.0)
		carried_label.modulate = Color("e5604f").lerp(Color.WHITE, carry_pulse)
	else:
		carried_label.modulate = Color.WHITE
	if boss_context:
		delivered_title_label.text = "调律"
		delivered_label.text = "%d / %d" % [int(boss.hits), int(current_boss_data.required_tunings)]
	else:
		delivered_title_label.text = "归巢蜜"
		delivered_label.text = "%d / %d" % [mini(delivered, int(data.goal)), int(data.goal)]
	energy_label.text = str(roundi(bee.energy))
	# 分母跟随实际上限（越冬抱团可把上限提到基准之上），避免条提前满格
	var energy_cap := effective_energy_cap()
	energy_bar_fill.size.x = 284.0 * clampf(bee.energy / energy_cap, 0.0, 1.0)
	# 蜜囊续命提亮：让「这 30 点体力是吃掉一滴蜜换来的」在体力条上可见
	if energy_bar_flash_time > 0.0:
		energy_bar_fill.color = Color("ddb84c").lerp(Color("fff6cf"), clampf(energy_bar_flash_time * 1.8, 0.0, 1.0))
	else:
		energy_bar_fill.color = Color("ddb84c")
	energy_change_label.modulate.a = clampf(energy_feedback_time * 2.0, 0.0, 1.0)
	update_progressive_guidance()
	hive_label.text = "●".repeat(maxi(0, hive_lives)) + "○".repeat(maxi(0, 3 - hive_lives))
	# 扣命闪红：从红渐褪回白，与震动/音效一起把损失推到台前
	if hive_flash_time > 0.0:
		hive_label.modulate = Color("e5604f").lerp(Color.WHITE, 1.0 - clampf(hive_flash_time * 1.6, 0.0, 1.0))
	else:
		hive_label.modulate = Color.WHITE
	reserve_label.text = str(hive_reserve)
	message_label.text = message
	if boss_context:
		var boss_data: Dictionary = current_boss_data
		season_label.text = String(boss_data.name)
		detail_label.text = "调律 · %d / %d" % [int(boss.hits), int(boss_data.required_tunings)]
	else:
		season_label.text = "过关条件"
		var condition_parts: Array[String] = ["归巢蜜 %d / %d" % [mini(delivered, int(data.goal)), int(data.goal)]]
		if season_mechanics != null and season_mechanics.has_method("hud_status"):
			var mechanics_status := String(season_mechanics.hud_status())
			if not mechanics_status.is_empty():
				condition_parts.append(mechanics_status)
		var mentor_requirement := mentor_completion_requirement()
		if not mentor_requirement.is_empty():
			condition_parts.append(mentor_requirement)
		detail_label.text = "\n".join(condition_parts)
	if production_hud != null:
		production_hud.update_state(self)

func _uses_boss_interface_context() -> bool:
	if current_boss_data.is_empty():
		return false
	if phase in ["boss", "boss_victory", "boss_loss"]:
		return true
	if phase == "paused":
		return paused_from_phase == "boss"
	if phase == "lost":
		return lost_from_phase == "boss"
	return false

func _handle_world_tap(world_position: Vector2) -> bool:
	if not WORLD.has_point(world_position):
		return false
	if not mentor_tutorial.allows_action("move"):
		return true
	var now := Time.get_ticks_msec() / 1000.0
	var result: Dictionary = evade_input_controller.handle_world_tap(
		world_position,
		now,
		bee,
		WORLD,
		mentor_tutorial.allows_action("evade")
	)
	_apply_evade_input_result(result)
	return bool(result.get("consumed", false))

func _input(event: InputEvent) -> void:
	if _handle_drink_touch_input(event):
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and commercial_system_menu != null and commercial_system_menu.is_open():
		commercial_system_menu.request_cancel()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		# overlay 阶段 Esc 路由：
		# boss_loss = 鼓励再试（等同 Enter，触发再入节令）
		# intro/won/lost/paused = 退出游戏（次要链接）
		# playing/boss = 暂停
		if phase == "boss_loss":
			on_overlay_button()
		elif phase == "intro":
			get_tree().quit()
		elif phase in ["won", "lost", "paused"]:
			on_secondary_link()
		else:
			toggle_pause()
		get_viewport().set_input_as_handled()
		return
	# Focused Controls own ui_accept. Keeping phase transitions out of this
	# fallback prevents the same Enter release from activating a newly revealed
	# control (allocation confirm -> upgrade/all-mature continue) a second time.
	# If focus vanished between OS/window events, consume this press after repair;
	# the next deliberate press then activates exactly one focused control.
	if event.is_action_pressed("ui_accept") and overlay.visible:
		if not is_valid_overlay_focus(get_viewport().gui_get_focus_owner()):
			restore_overlay_focus()
			get_viewport().set_input_as_handled()
		return
	if phase != "playing" and phase != "boss":
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if _handle_world_tap(event.position):
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch and event.pressed:
		if _handle_world_tap(event.position):
			get_viewport().set_input_as_handled()

# 切走程序时自动暂停（体力照扣、失律者照追是设计事故）；
# 切回来时把焦点交还当前弹层最近的有效控件，键盘可直接继续。
# toggle_pause 内部有相位护栏，between/boss_victory 等静态界面不会被误暂停覆盖。
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_cancel_drink_touch()
		if phase in ["playing", "boss"]:
			toggle_pause()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		restore_overlay_focus()

func on_sense_started() -> void:
	if season_mechanics != null and season_mechanics.has_method("sense_focus_active") and bool(season_mechanics.sense_focus_active()):
		message = "身上的散粉回应同形花心；敌虫范围与归巢方向仍在风里。"
	else:
		message = "触角捕捉到蜜量、敌虫警戒范围和一条相对安全的采集方向。"

func best_foraging_target() -> int:
	var best := -1
	var best_score := -INF
	for i in flowers.size():
		var flower: Dictionary = flowers[i]
		if int(flower.nectar) <= 0 or bool(flower.get("sleeping", false)) or float(flower.get("flatten_time", 0.0)) > 0.0:
			continue
		if bool(flower.get("tutorial_locked", false)) or (bool(flower.get("tutorial_hidden", false)) and not bool(flower.get("discovered", false))):
			continue
		if season_mechanics != null and season_mechanics.has_method("is_flower_available") and not bool(season_mechanics.is_flower_available(i)):
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
		set_pause_system_controls_visible(false)
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
	overlay_body.text = "游戏过程已经停下。\n可在这里调整显示和声音，或退出游戏。"
	overlay_button.visible = true
	overlay_button.text = "继续出巢"
	set_secondary_link("", false)
	set_pause_system_controls_visible(true)
	focus_overlay_primary()
	pause_button.text = "继续"

func set_pause_system_controls_visible(visible: bool) -> void:
	for button in pause_system_buttons:
		button.visible = visible
	if visible and pause_system_buttons.size() >= 2:
		pause_system_buttons[0].text = "窗口化" if save_manager.fullscreen else "全屏"
		pause_system_buttons[1].text = "声音：开" if save_manager.sound_enabled else "声音：关"

# First-run state machine: move -> harvest -> return -> sense -> repel -> evade.
# Each tool should be performed once; unfinished steps may continue across stages
# and never override a completed stage objective.
func update_progressive_guidance() -> void:
	if tutorial_panel == null or sense_button == null or return_button == null or drink_button == null:
		return
	var drink_available := can_drink_honey()
	drink_button.visible = drink_available
	drink_button.disabled = not drink_available
	if not drink_available and drink_touch_index >= 0:
		_cancel_drink_touch()
	if drink_available:
		var refill := minf(balance_value("player", "crop_fuel_refill", 22.0), effective_energy_cap() - bee.energy)
		var drinks_left := int(balance_value("player", "crop_fuel_limit", 2)) - crop_fuel_used
		drink_button.text = "饮蜜 +%d · 余%d" % [ceili(refill), drinks_left]
	if phase == "boss":
		tutorial_panel.visible = false
		return_button.visible = false
		var boss_pattern := String(current_boss_data.get("move_pattern", ""))
		if boss_director.can_tune():
			sense_button.visible = true
			sense_button.text = "调律"
			context_hint_label.text = "破绽亮起"
		elif boss_pattern == "lure":
			sense_button.visible = true
			sense_button.text = "寻迹"
			context_hint_label.text = "停稳 · 寻迹"
		else:
			sense_button.visible = false
			context_hint_label.text = _boss_exposure_hint(boss_pattern)
		return
	if phase != "playing":
		tutorial_panel.visible = false
		sense_button.visible = false
		return_button.visible = false
		return
	# The elder owns presentation and action ordering, but the first real sortie
	# still advances from movement -> carried honey -> deposited honey. Keeping
	# this evidence update before the mentor branch prevents the ribbon from
	# accidentally freezing the underlying causal state machine.
	if not tutorial_complete:
		if tutorial_step == 0 and bee.position.distance_to(tutorial_origin) >= 64.0:
			tutorial_step = 1
		elif tutorial_step == 1 and carried > 0:
			tutorial_step = 2
	if mentor_tutorial.owns_guidance():
		_update_mentor_guidance()
		return
	if not tutorial_complete:
		tutorial_panel.visible = tutorial_step < 6
		return_button.visible = tutorial_step == 2
		match tutorial_step:
			0:
				tutorial_title.text = "飞出去"
				tutorial_body.text = "WASD / 方向键 / 点击"
				context_hint_label.text = ""
				sense_button.visible = false
			1:
				var near_flower := nearest_flower(46.0) >= 0
				tutorial_title.text = "花心亮了"
				tutorial_body.text = "按住空格，蜜囊 +1 再松开"
				context_hint_label.text = "" if near_flower else ""
				sense_button.visible = near_flower
				sense_button.text = "继续按住" if harvest_clock > 0.0 else "按住采蜜"
			2:
				tutorial_title.text = "带它回家"
				tutorial_body.text = "Q / 归巢"
				context_hint_label.text = ""
				sense_button.visible = false
			3:
				tutorial_title.text = "风里有花香"
				tutorial_body.text = "停稳 · 空格；循香找到它"
				context_hint_label.text = ""
				sense_button.visible = true
				sense_button.text = "寻迹"
			4:
				tutorial_title.text = "花被占住了"
				tutorial_body.text = "靠近 · 空格"
				context_hint_label.text = ""
				sense_button.visible = true
				sense_button.text = "惊退"
			5:
				tutorial_title.text = "等攻击线压来"
				tutorial_body.text = "同一方向连按两次"
				context_hint_label.text = ""
				sense_button.visible = false
		return

	var nearby := nearest_flower(46.0)
	var near_enemy := _nearest_enemy_distance() < sting_range
	var is_still := bee.velocity.length_squared() < 4.0 and not bee.has_target
	var seasonal_action_id := ""
	var relay_action_id := relay_hive.context_action_id(bee.position, carried)
	if not relay_action_id.is_empty():
		seasonal_action_id = relay_action_id
	elif season_mechanics.has_method("context_action_id"):
		seasonal_action_id = String(season_mechanics.context_action_id(bee.position))
	if bee.energy <= 35.0:
		trigger_context_lesson("low_energy", "翅膀变沉", "E 饮蜜 / 回巢")
	elif seasonal_action_id == "repel_raider" or near_enemy:
		trigger_context_lesson("danger", "航线被占", "靠近 · 空格")
	elif is_still and nearby < 0:
		trigger_context_lesson("sense", "风里有花香", "停稳 · 空格")
	if context_lesson_time > 0.0:
		tutorial_panel.visible = true
		match context_lesson_id:
			"low_energy":
				tutorial_title.text = "翅膀变沉"
				tutorial_body.text = "E 饮蜜 / 回巢"
			"danger":
				tutorial_title.text = "航线被占"
				tutorial_body.text = "靠近 · 空格"
			"sense":
				tutorial_title.text = "风里有花香"
				tutorial_body.text = "停稳 · 空格"
	else:
		tutorial_panel.visible = false
	return_button.visible = carried > 0
	sense_button.visible = nearby >= 0 or near_enemy or is_still or not seasonal_action_id.is_empty()
	if seasonal_action_id == "deposit_pollen":
		sense_button.text = "传粉"
		context_hint_label.text = ""
	elif seasonal_action_id == "needs_pollen":
		sense_button.text = "先取散粉"
		context_hint_label.text = "蜂身没有散粉"
	elif seasonal_action_id == "repel_raider":
		sense_button.text = "惊退"
		context_hint_label.text = ""
	elif seasonal_action_id == "light_warm_relay":
		sense_button.text = "点亮"
		context_hint_label.text = ""
	elif seasonal_action_id == "warm_relay_needs_honey":
		sense_button.text = "需一滴蜜"
		context_hint_label.text = ""
	elif seasonal_action_id == "activate_relay_hive":
		sense_button.text = "点亮中继巢"
		context_hint_label.text = "远路中继"
	elif seasonal_action_id == "relay_hive_needs_honey":
		sense_button.text = "需一滴蜜"
		context_hint_label.text = "中继巢未亮"
	elif near_enemy:
		sense_button.text = "惊退"
		context_hint_label.text = ""
	elif nearby >= 0:
		sense_button.text = "继续按住" if harvest_clock > 0.0 else "按住采蜜"
		context_hint_label.text = "蜜囊 +1 再松开" if harvest_clock > 0.0 else ""
	elif is_still:
		sense_button.text = "寻迹"
		context_hint_label.text = ""
	elif bee.energy <= 35.0 and carried > 0 and crop_fuel_used < int(balance_value("player", "crop_fuel_limit", 2)):
		context_hint_label.text = "E / Q"
	elif carried > 0:
		context_hint_label.text = ""
	else:
		context_hint_label.text = ""

func _update_mentor_guidance() -> void:
	var guidance: Dictionary = mentor_tutorial.prompt()
	tutorial_panel.visible = bool(guidance.get("visible", false))
	if tutorial_panel.visible:
		tutorial_title.text = String(guidance.get("title", ""))
		tutorial_body.text = String(guidance.get("body", ""))
	if mentor_tutorial.blocks_simulation():
		sense_button.visible = false
		return_button.visible = false
		context_hint_label.text = "演示中"
		return
	var nearby := nearest_flower(46.0)
	var near_enemy := _nearest_enemy_distance() < sting_range
	var is_still := bee.velocity.length_squared() < 4.0 and not bee.has_target
	var contextual_action := relay_hive.context_action_id(bee.position, carried)
	if contextual_action.is_empty() and season_mechanics.has_method("context_action_id"):
		contextual_action = String(season_mechanics.context_action_id(bee.position))
	var recovery_return_needed: bool = mentor_tutorial.lesson_id in ["defense", "evade"] and bee.energy < 24.0
	return_button.visible = mentor_tutorial.allows_action("return") and (carried > 0 or recovery_return_needed)
	sense_button.visible = false
	context_hint_label.text = ""
	if mentor_tutorial.lesson_id == "sense" and mentor_tutorial.phase == "imitate":
		sense_button.visible = true
		sense_button.text = "寻迹"
		context_hint_label.text = "先停稳"
	elif not contextual_action.is_empty() and mentor_tutorial.allows_action("seasonal"):
		sense_button.visible = true
		match contextual_action:
			"deposit_pollen": sense_button.text = "传粉"
			"needs_pollen":
				sense_button.text = "先取散粉"
				context_hint_label.text = "蜂身没有散粉"
			"repel_raider": sense_button.text = "惊退"
			"light_warm_relay": sense_button.text = "点亮"
			"warm_relay_needs_honey": sense_button.text = "需一滴蜜"
			"activate_relay_hive": sense_button.text = "点亮中继巢"
			"relay_hive_needs_honey": sense_button.text = "需一滴蜜"
			_: sense_button.text = "行动"
	elif near_enemy and mentor_tutorial.allows_action("repel"):
		sense_button.visible = true
		sense_button.text = "惊退"
	elif nearby >= 0 and mentor_tutorial.allows_action("harvest"):
		sense_button.visible = true
		sense_button.text = "继续按住" if harvest_clock > 0.0 else "按住采蜜"
		context_hint_label.text = "采蜜中 · 蜜囊 +1 后松开" if harvest_clock > 0.0 else "花心已对准"
	elif is_still and mentor_tutorial.allows_action("sense"):
		sense_button.visible = true
		sense_button.text = "寻迹"

func trigger_context_lesson(id: String, title: String, body: String) -> void:
	if bool(context_lessons_seen.get(id, false)) or context_lesson_time > 0.0:
		return
	context_lessons_seen[id] = true
	context_lesson_id = id
	context_lesson_time = 5.0
	tutorial_title.text = title
	tutorial_body.text = body

func toggle_fullscreen() -> void:
	save_manager.fullscreen = not save_manager.fullscreen
	save_manager.save_data()
	apply_display_settings()
	refresh_setting_labels()

func toggle_sound() -> void:
	save_manager.sound_enabled = not save_manager.sound_enabled
	save_manager.save_data()
	sound.set_enabled(save_manager.sound_enabled)
	music.set_enabled(save_manager.sound_enabled)
	refresh_setting_labels()

func apply_display_settings() -> void:
	if OS.has_feature("web") or DisplayServer.get_name().to_lower() == "headless":
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if save_manager.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)

func refresh_setting_labels() -> void:
	if fullscreen_button:
		fullscreen_button.text = "窗口化" if save_manager.fullscreen else "全屏"
	if sound_button:
		sound_button.text = "声音：开" if save_manager.sound_enabled else "声音：关"
	if phase == "paused":
		set_pause_system_controls_visible(true)


func _commercial_persistence() -> CommercialPersistenceService:
	return get_node_or_null("/root/CommercialPersistence") as CommercialPersistenceService


func _open_title_settings() -> void:
	if phase == "intro" and commercial_system_menu != null:
		new_journey_confirmation_armed = false
		commercial_system_menu.open_settings_only()


func _open_title_credits() -> void:
	if phase == "intro" and commercial_system_menu != null:
		new_journey_confirmation_armed = false
		commercial_system_menu.open_credits_only()


func _on_title_system_menu_closed() -> void:
	if phase == "intro":
		show_intro()


func _apply_title_commercial_settings(next_settings: Dictionary) -> void:
	if overlay == null:
		return
	commercial_screen_shake_enabled = bool(next_settings.get("screen_shake", true)) and not bool(next_settings.get("reduce_motion", false))
	if not commercial_screen_shake_enabled:
		shake = 0.0
	var ui_scale := float(next_settings.get("ui_scale", 1.0))
	for node in overlay.find_children("*", "Control", true, false):
		var control := node as Control
		if control == null:
			continue
		if not control.has_meta("commercial_base_font_size"):
			var inherited_size := control.get_theme_font_size("font_size")
			if inherited_size > 0:
				control.set_meta("commercial_base_font_size", inherited_size)
		if control.has_meta("commercial_base_font_size"):
			var base_size := int(control.get_meta("commercial_base_font_size"))
			control.add_theme_font_size_override("font_size", roundi(float(base_size) * ui_scale))

func progress_name() -> String:
	if not stages.is_empty() and save_manager.best_stage >= stages.size():
		return "完整循环已归律"
	if save_manager.best_stage <= 0 or stages.is_empty():
		return "尚未出巢"
	return "第 %d 段花田" % mini(save_manager.best_stage, stages.size())

# 把跨 run 的历史信息从 overlay 弹窗里搬出来，放进 HUD 侧栏底部永久位：
# 三行小字——轮回次数 / 前路最远 / 上轮时长。
# 跨 run 但属于「持久状态」，不属于任何弹窗。
func refresh_runs_meter() -> void:
	if runs_meter == null or runs_meter_farthest == null:
		return
	var runs := int(save_manager.runs_completed)
	if runs <= 0:
		runs_meter.text = "尚未启程"
	else:
		runs_meter.text = "已走过 %d 轮" % runs
	var farthest := progress_name()
	if farthest == "尚未出巢":
		runs_meter_farthest.text = "前路：远方还是远方"
	elif farthest == "完整循环已归律":
		runs_meter_farthest.text = "前路：完整循环归律"
	else:
		runs_meter_farthest.text = "前路：%s" % farthest
	var last_seconds := save_manager.last_run_seconds
	if last_seconds > 0.0:
		runs_meter.text += "  ·  上轮 %s" % format_duration(last_seconds)

func format_duration(duration_seconds: float) -> String:
	var minutes := floori(duration_seconds / 60.0)
	var seconds := floori(fmod(duration_seconds, 60.0))
	return "%d:%02d" % [minutes, seconds]

func stage_color(index: int) -> Color:
	if stages.is_empty():
		return Color("d9e8c2")
	var colors: Array = stages[stage_index].colors
	return Color(colors[index])

func season_field_tint(id: String) -> Color:
	match id:
		"summer":
			return Color("ffe3ad")
		"autumn":
			return Color("e6b77f")
		"winter":
			return Color("b9d2df")
		_:
			return Color.WHITE

func draw_season_ambience(id: String) -> void:
	match id:
		"summer":
			# Short moving highlights make the field feel hot and busy without
			# placing another permanent UI symbol over the flowers.
			for i in 10:
				var x := WORLD.position.x + 180.0 + fmod(float(i * 113) + elapsed * 18.0, WORLD.size.x - 220.0)
				var y := WORLD.position.y + 64.0 + fmod(float(i * 71), WORLD.size.y - 128.0)
				draw_line(Vector2(x, y), Vector2(x + 22.0, y - 7.0), Color("fff1b8", 0.24), 3.0)
		"autumn":
			# Leaves, not labels, announce the field's turn toward seed and reserve.
			for i in 16:
				var x := WORLD.position.x + fmod(float(i * 83) + elapsed * (9.0 + float(i % 3) * 3.0), WORLD.size.x)
				var y := WORLD.position.y + fmod(float(i * 117) + elapsed * 11.0, WORLD.size.y)
				var leaf := PackedVector2Array([
					Vector2(x - 5.0, y), Vector2(x, y - 3.0),
					Vector2(x + 6.0, y), Vector2(x, y + 3.0)
				])
				draw_colored_polygon(leaf, Color("9e5d2f", 0.28))
		"winter":
			var frost := clampf((82.0 - warmth) / 82.0, 0.08, 1.0)
			draw_rect(WORLD, Color("d9edf4", 0.08 + frost * 0.16))
			for i in 14:
				var fx := WORLD.position.x + float(i) * WORLD.size.x / 13.0
				draw_line(Vector2(fx, WORLD.end.y), Vector2(fx + 17.0, WORLD.end.y - 42.0 - frost * 30.0), Color("f4fbff", 0.12 + frost * 0.22), 2.0)

func draw_hive_world() -> void:
	var hive_rect := Rect2(38, 254, 164, 198)
	var activity := clampf(hive_activity_time * 1.5, 0.0, 1.0)
	var reserve_glow := clampf(float(hive_reserve) / 24.0, 0.0, 1.0)
	var damage := clampf(hive_flash_time * 1.5, 0.0, 1.0)
	# The light is a doorway-shaped landing lane rather than another abstract ring.
	draw_colored_polygon(PackedVector2Array([
		Vector2(104, 384), Vector2(178, 384), Vector2(205, 437), Vector2(92, 437)
	]), Color("f8d66b", 0.10 + reserve_glow * 0.16 + activity * 0.22))
	var hive_tint := Color.WHITE.lerp(Color("e96658"), damage * 0.7)
	if spring_hive_entrance_texture != null:
		draw_texture_rect(spring_hive_entrance_texture, hive_rect, false, hive_tint)
	else:
		draw_texture_rect(HIVE_ENTRANCE_TEXTURE, Rect2(47, 325, 118, 150), false, hive_tint)
	# Stored honey visibly lights individual chambers; damage dims them.
	var lit_cells := clampi(1 + int(hive_reserve / 4), 1, 6)
	for i in lit_cells:
		var cell_pos := Vector2(76.0 + float(i % 3) * 25.0, 318.0 + float(i / 3) * 27.0)
		draw_circle(cell_pos, 4.0 + activity * 1.5, Color("ffd968", 0.58 + reserve_glow * 0.32))
	draw_hive_workers()

func draw_relay_hive_world() -> void:
	if not relay_hive.enabled:
		return
	var pos: Vector2 = relay_hive.position
	var active := bool(relay_hive.active)
	var glow := clampf(float(relay_hive.activity_time), 0.0, 1.0)
	# A small, grounded landing patch makes this a place in the field rather than
	# another abstract interaction radius. Reusing the primary hive material and
	# silhouette keeps the two structures in one visual family.
	draw_colored_polygon(PackedVector2Array([
		pos + Vector2(-46, 14), pos + Vector2(40, 14),
		pos + Vector2(54, 48), pos + Vector2(-55, 48)
	]), Color("efd37b", 0.06 + (0.16 if active else 0.02) + glow * 0.12))
	var texture: Texture2D = spring_hive_entrance_texture if spring_hive_entrance_texture != null else HIVE_ENTRANCE_TEXTURE
	var tint := Color.WHITE if active else Color("b6ab88")
	draw_texture_rect(texture, Rect2(pos + Vector2(-51, -75), Vector2(102, 128)), false, tint)
	# The post never pretends to be a second scoring hive: one wax lamp communicates
	# rest, while the main hive alone displays stored-honey chambers.
	draw_line(pos + Vector2(0, 7), pos + Vector2(0, -8), Color("4b3a2d"), 3.0)
	if active:
		draw_colored_polygon(PackedVector2Array([
			pos + Vector2(0, -23), pos + Vector2(-6, -9),
			pos + Vector2(0, -4), pos + Vector2(6, -9)
		]), Color("f6aa3f", 0.92))
		draw_circle(pos + Vector2(0, -10), 3.0 + glow, Color("fff0a0"))
	else:
		draw_colored_polygon(PackedVector2Array([
			pos + Vector2(0, -22), pos + Vector2(-5, -12),
			pos + Vector2(0, -6), pos + Vector2(5, -12)
		]), Color("766b57", 0.72))

func draw_hive_workers() -> void:
	if colony_bee_texture == null:
		return
	var worker_count := clampi(2 + int(hive_reserve / 6) + int(chosen_upgrades.size() / 2), 2, 6)
	var role_tints := [Color("fff2bd"), Color("b8dcff"), Color("f0a36a")]
	var raid_active := false
	var raid = season_mechanics.mechanic_by_id("conscription") if season_mechanics != null else null
	if raid != null:
		raid_active = String(raid.state) == "active"
	for i in worker_count:
		var role := i % 3 # scout / forager / guard
		var phase_offset := elapsed * (1.3 + float(i % 3) * 0.2) + float(i) * 1.7
		var pos := Vector2(
			132.0 + float(i % 3) * 24.0 + sin(phase_offset) * 9.0,
			352.0 + float(i / 3) * 52.0 + cos(phase_offset * 1.2) * 8.0
		)
		if role == 0 and bee.sense_time > 0.0:
			# Scout leaves the doorway toward the field while scent is being read.
			pos += Vector2(62.0 + sin(phase_offset) * 12.0, -38.0)
		elif role == 1 and hive_activity_time > 0.0:
			# Forager shuttles through the landing lane during a real deposit.
			pos += Vector2(32.0 * sin(phase_offset * 2.1), 34.0)
		elif role == 2 and raid_active:
			# Guard holds the outer lip of the door when the field is raided.
			pos = Vector2(196.0 + sin(phase_offset) * 6.0, 398.0 + cos(phase_offset) * 12.0)
		draw_set_transform(field_draw_offset + pos, sin(phase_offset) * 0.24)
		draw_texture_rect(colony_bee_texture, Rect2(-13, -9, 26, 18), false, role_tints[role])
		if role == 1 and hive_activity_time > 0.0:
			draw_colored_polygon(PackedVector2Array([
				Vector2(0, 9), Vector2(-3, 14), Vector2(0, 18), Vector2(3, 14)
			]), Color("f2cf5b"))
		elif role == 2 and raid_active:
			draw_line(Vector2(8, -6), Vector2(19, -13), Color("9f4b35"), 3.0)
		draw_set_transform(field_draw_offset)

func _draw() -> void:
	if stages.is_empty():
		return
	var offset := (
		Vector2(rng.randf_range(-shake, shake), rng.randf_range(-shake, shake))
		if commercial_screen_shake_enabled and shake > 0
		else Vector2.ZERO
	)
	field_draw_offset = offset
	draw_set_transform(offset)
	var coherent_world := world_art_ready()
	var field_theme := current_flower_set()
	if coherent_world:
		draw_texture_rect(spring_field_texture, WORLD, false, season_field_tint(field_theme))
	else:
		var top := stage_color(0)
		var bottom := stage_color(1)
		draw_rect(WORLD, top)
		for band in 18:
			var ratio := float(band) / 17.0
			var band_rect := Rect2(WORLD.position.x, WORLD.position.y + WORLD.size.y * ratio, WORLD.size.x, WORLD.size.y / 17.0 + 1)
			draw_rect(band_rect, top.lerp(bottom, ratio * 0.68))
		draw_texture_rect(FIELD_TEXTILE_OVERLAY, WORLD, false, Color(1, 1, 1, 0.34))
	draw_season_ambience(field_theme)
	draw_hive_world()
	draw_relay_hive_world()

	var deep := stage_color(2)
	if not coherent_world:
		for i in 34:
			var x := WORLD.position.x + fmod(float(i * 97 + stage_index * 31), WORLD.size.x)
			var y := 570.0 + sin(float(i) * 2.1) * 60.0
			draw_line(Vector2(x, WORLD.end.y), Vector2(x + 10, y), Color(deep, 0.2), 3)

	# 花物候学：连环花连接线（窗口内时，从上一朵连环花画指引线到附近同型花）
	if chain_timer > 0.0 and chain_last_index >= 0 and chain_last_index < flowers.size():
		var chain_pos: Vector2 = flowers[chain_last_index].position
		for i in flowers.size():
			var fl: Dictionary = flowers[i]
			if i == chain_last_index or int(fl.nectar) <= 0:
				continue
			if str(fl.get("type", "")) != "chain_bloom":
				continue
			if chain_pos.distance_to(fl.position) <= chain_range_px:
				var pulse := 0.3 + 0.2 * sin(elapsed * 5.0)
				draw_line(chain_pos, fl.position, Color("e8a0d4", pulse), 2.0)
	# The first scent is environmental: a few barely visible motes collect in the
	# quiet gap. Sensing turns the hidden bloom into a real harvest target.
	if stage_index == 0 and not tutorial_complete and tutorial_step == 3 and not tutorial_scent_revealed:
		for mote_index in 5:
			var ratio := float(mote_index + 1) / 6.0
			var scent_pos := Vector2(390, 410).lerp(Vector2(500, 292), ratio)
			scent_pos.y += sin(elapsed * 2.4 + mote_index) * 7.0
			draw_circle(scent_pos, 2.5 + ratio * 1.5, Color("f4d994", 0.16 + ratio * 0.08))
	for flower in flowers:
		draw_flower(flower)
	for phantom in phantom_flowers:
		draw_phantom_flower(phantom)
	for ant in ants:
		draw_ant_trail(ant)
	for mosquito in mosquitoes:
		draw_mosquito(mosquito)
	draw_evade_confirmation()
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
		var decoy_sway := sin(elapsed * 7.0) * 2.0
		draw_colored_polygon(PackedVector2Array([
			decoy_position + Vector2(0, -13 + decoy_sway),
			decoy_position + Vector2(-9, 2), decoy_position + Vector2(0, 11),
			decoy_position + Vector2(9, 2)
		]), Color("e8b83f", 0.92))
		draw_line(decoy_position + Vector2(-5, 10), decoy_position + Vector2(7, 10), Color("8b6231", 0.72), 3.0)
	if bee.sense_time > 0.0 and (phase == "playing" or phase == "boss"):
		# A carried pollen load makes compatible stigmas the recoverable question.
		# PollinationMechanic draws one motif route per carried variant later in this
		# frame; suppressing the ordinary best-nectar line prevents two contradictory
		# destinations. Danger zones and the hive line remain available below.
		var seasonal_sense_focus: bool = season_mechanics != null \
			and season_mechanics.has_method("sense_focus_active") \
			and bool(season_mechanics.sense_focus_active())
		if not seasonal_sense_focus:
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
		draw_line(bee.position, HIVE_RETURN_POS, Color("fff0a0", 0.55), 3)
	if flash > 0:
		draw_rect(WORLD, Color("fff1b0", flash * 0.25))
	if phase == "exhausted":
		# 力竭停顿拍：世界转暗，唯一的光留给体力条上的 0
		draw_rect(WORLD, Color("10160c", 0.5))
	season_mechanics.draw()
	mentor_tutorial.draw()
	draw_set_transform(Vector2.ZERO)

func draw_flower(flower: Dictionary) -> void:
	var pos: Vector2 = flower.position
	if bool(flower.get("tutorial_hidden", false)) and not bool(flower.get("discovered", false)):
		return
	if bool(flower.get("tutorial_locked", false)):
		# A folded bud is a world object; the former empty target ring looked like
		# debug UI and gave no clue what would open.
		draw_line(pos + Vector2(0, 8), pos + Vector2(0, 38), Color("587449", 0.8), 4)
		draw_colored_polygon(PackedVector2Array([
			pos + Vector2(-11, 8), pos + Vector2(0, -10), pos + Vector2(4, 9)
		]), Color("d98caa", 0.82))
		draw_colored_polygon(PackedVector2Array([
			pos + Vector2(-4, 9), pos + Vector2(2, -12), pos + Vector2(12, 8)
		]), Color("f0b8cb", 0.88))
		draw_colored_polygon(PackedVector2Array([
			pos + Vector2(-13, 10), pos + Vector2(-2, 4), pos + Vector2(-5, 17)
		]), Color("6f9255", 0.9))
		draw_colored_polygon(PackedVector2Array([
			pos + Vector2(13, 10), pos + Vector2(2, 4), pos + Vector2(5, 17)
		]), Color("6f9255", 0.9))
		return
	var sleeping := bool(flower.get("sleeping", false))
	var newly_open := bool(flower.get("newly_open", false))
	var alive := int(flower.nectar) > 0 and not sleeping
	var recovery := bool(flower.get("recovery", false))
	var alpha := 1.0 if alive else 0.28
	var ftype := str(flower.get("type", "nectar_bloom"))
	var petal_base: Color = FLOWER_TYPE_COLORS.get(ftype, FLOWER_COLORS[int(flower.kind)])
	if sleeping:
		draw_line(pos + Vector2(0, 16), pos + Vector2(0, 45), Color(stage_color(2), 0.35), 3)
		draw_circle(pos + Vector2(0, 14), 5, Color("3d4a3a", 0.55))
		draw_arc(pos, 13, 0, TAU, 16, Color(stage_color(2), 0.4), 2)
		return
	if float(flower.get("flatten_time", 0.0)) > 0.0:
		# 被熊压平：花没有死，flatten_time 走完后会重新立起
		var petal_color := Color(petal_base, 0.38)
		draw_line(pos + Vector2(0, 16), pos + Vector2(0, 38), Color(stage_color(2), 0.28), 2)
		draw_circle(pos + Vector2(-7, 3), 6, petal_color)
		draw_circle(pos + Vector2(6, 6), 5, petal_color)
		draw_circle(pos + Vector2(0, 9), 4, Color(stage_color(3), 0.35))
		draw_line(pos + Vector2(-18, 13), pos + Vector2(20, 13), Color("5c4433", 0.5), 3)
		return
	var high_value_types := ["peak_bloom", "cascade_bloom", "late_bloom", "warmth_bloom", "first_bloom", "chain_bloom"]
	var visual_variant := clampi(int(flower.get("visual_variant", 1 if ftype in high_value_types else int(flower.kind) % 2)), 0, 1)
	var large_bloom := bool(flower.get("large_bloom", ftype in high_value_types))
	var flower_texture := seasonal_flower_texture(current_flower_set(), visual_variant == 1)
	var flower_height := 82.0 if large_bloom else 66.0
	var flower_ratio := float(flower_texture.get_width()) / maxf(1.0, float(flower_texture.get_height()))
	var flower_size := Vector2(flower_height * flower_ratio, flower_height)
	# Every independent sprite shares a grounded contact shadow. The old colored
	# halo was too faint to explain type and read as yet another empty ring.
	draw_set_transform(field_draw_offset + pos, 0.0, Vector2(1.0, 0.34))
	draw_circle(Vector2.ZERO, 20.0 if large_bloom else 16.0, Color("26352a", 0.22 * alpha))
	draw_set_transform(field_draw_offset)
	var flower_anchor_y := flower_size.y * 0.42
	draw_texture_rect(flower_texture, Rect2(pos - Vector2(flower_size.x * 0.5, flower_anchor_y), flower_size), false, Color(1, 1, 1, alpha))
	if recovery and alive:
		for drop_index in 3:
			var drop_pos := pos + Vector2(float(drop_index - 1) * 10.0, -42.0 - abs(drop_index - 1) * 4.0)
			draw_colored_polygon(PackedVector2Array([
				drop_pos + Vector2(0, -6), drop_pos + Vector2(-4, 1),
				drop_pos + Vector2(0, 6), drop_pos + Vector2(4, 1)
			]), Color("fff1a8", 0.88))
	if newly_open and alive:
		for spark_index in 4:
			var spark_angle := float(spark_index) * TAU / 4.0 + elapsed * 0.3
			var spark_pos := pos + Vector2.from_angle(spark_angle) * 28.0
			draw_line(spark_pos, spark_pos + Vector2.from_angle(spark_angle) * 5.0, Color("fff1a8", 0.72), 2.0)
	if not alive:
		draw_line(pos + Vector2(-14, 49), pos + Vector2(14, 49), Color(stage_color(2), 0.45), 2)

func seasonal_flower_texture(set_id: String, second_variant: bool) -> Texture2D:
	if set_id == "spring" and spring_flower_common_texture != null and spring_flower_high_value_texture != null:
		return spring_flower_high_value_texture if second_variant else spring_flower_common_texture
	if SEASON_FLOWER_TEXTURES.has(set_id):
		var pair: Array = SEASON_FLOWER_TEXTURES[set_id]
		return pair[1 if second_variant else 0] as Texture2D
	return FLOWER_HIGH_VALUE_TEXTURE if second_variant else FLOWER_COMMON_TEXTURE

func draw_evade_side_arrows(target: Vector2, attack_direction: Vector2, alpha := 1.0) -> void:
	var bee_center_bounds := WORLD.grow(-18.0)
	var shown_directions: Array[Vector2] = EvadeRulesScript.cardinal_escape_directions(
		target,
		attack_direction,
		bee_center_bounds,
		EVADE_PATH_CLEARANCE
	)
	# Side markers snap to valid single WASD axes. A slightly diagonal line must
	# never invite a chord that the shared detector cannot repeat.
	for shown_direction in shown_directions:
		for tap_index in 2:
			var tip: Vector2 = target + shown_direction * (42.0 + float(tap_index) * 15.0)
			var wing: Vector2 = shown_direction.orthogonal() * 6.0
			draw_line(tip - shown_direction * 11.0 + wing, tip, Color("f4d36f", alpha), 3.0)
			draw_line(tip - shown_direction * 11.0 - wing, tip, Color("f4d36f", alpha), 3.0)

func draw_committed_attack_corridor(origin: Vector2, attack_direction: Vector2, target: Vector2, half_width: float, alpha := 1.0, show_arrows := true) -> void:
	var geometry: Dictionary = EvadeRulesScript.committed_corridor_geometry(origin, attack_direction, WORLD, half_width)
	if not bool(geometry.get("valid", false)):
		return
	var aim: Vector2 = geometry.aim
	var side: Vector2 = geometry.side
	var start: Vector2 = geometry.start
	var finish: Vector2 = geometry.finish
	var polygon: PackedVector2Array = geometry.polygon
	draw_colored_polygon(polygon, Color("d95d54", 0.11 * alpha))
	draw_line(start + side * half_width, finish + side * half_width, Color("d95d54", 0.44 * alpha), 2.0)
	draw_line(start - side * half_width, finish - side * half_width, Color("d95d54", 0.44 * alpha), 2.0)
	draw_line(start, finish, Color("f06b60", 0.70 * alpha), 3.0)
	if show_arrows:
		draw_evade_side_arrows(target, aim, alpha)

func draw_evade_confirmation() -> void:
	if evade_confirmation_time <= 0.0:
		return
	var ratio := clampf(evade_confirmation_time / 0.8, 0.0, 1.0)
	var radius := 20.0 + (1.0 - ratio) * 34.0
	draw_arc(evade_confirmation_position, radius, 0.0, TAU, 32, Color("f4d36f", ratio * 0.85), 4.0)
	if colony_bee_texture != null:
		draw_set_transform(field_draw_offset + evade_confirmation_position, evade_confirmation_direction.angle(), Vector2(0.72, 0.72))
		draw_texture_rect(colony_bee_texture, Rect2(-34, -24, 68, 48), false, Color(0.88, 0.92, 1.0, ratio * 0.30))
		draw_set_transform(field_draw_offset)

func draw_mosquito(mosquito: Dictionary) -> void:
	var pos: Vector2 = mosquito.position
	var repelled := float(mosquito.repel_time) > 0.0
	var mentor_demonstrating_evade: bool = mentor_tutorial.lesson_id == "evade" and mentor_tutorial.phase == "demo"
	if bool(mosquito.get("tutorial", false)) and mentor_demonstrating_evade:
		# The mentor demo draws one authored attacker on the demonstration route.
		# Hiding the live tutorial mosquito avoids showing two conflicting threats.
		return
	if bool(mosquito.get("tutorial", false)):
		var attack_state := String(mosquito.get("attack_state", ""))
		var aim := Vector2(mosquito.get("aim_direction", Vector2.LEFT)).normalized()
		if attack_state == "aim":
			draw_dashed_line(pos - aim * 28.0, pos + aim * 820.0, Color("d95d54", 0.34 + sin(elapsed * 10.0) * 0.08), 3.0, 12.0)
			draw_circle(pos, 18.0 + sin(elapsed * 14.0) * 3.0, Color("d95d54", 0.16))
		elif attack_state == "locked":
			var locked_origin := Vector2(mosquito.get("locked_origin", pos))
			var locked_target := Vector2(mosquito.get("locked_target", bee.position))
			draw_committed_attack_corridor(locked_origin, aim, locked_target, EVADE_PATH_CLEARANCE, 0.88 + sin(elapsed * 18.0) * 0.12)
		elif attack_state == "dash":
			var locked_origin := Vector2(mosquito.get("locked_origin", pos))
			var locked_target := Vector2(mosquito.get("locked_target", bee.position))
			draw_committed_attack_corridor(locked_origin, aim, locked_target, EVADE_PATH_CLEARANCE, 0.55, false)
			draw_line(pos - aim * 90.0, pos, Color("f4d994", 0.88), 7.0)
	if world_art_ready():
		var velocity := Vector2(mosquito.get("velocity", Vector2.ZERO))
		var angle := velocity.angle() if velocity.length_squared() > 0.01 else 0.0
		draw_set_transform(field_draw_offset + pos, angle)
		draw_texture_rect(spring_mosquito_texture, Rect2(-34, -24, 68, 48), false, Color("c9855f") if repelled else Color.WHITE)
		draw_set_transform(field_draw_offset)
	else:
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
		for drop_index in int(ant.stolen_honey):
			draw_circle(pos + Vector2(-6 + drop_index * 8, -22), 3.5, Color("f4ce67"))

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
		draw_line(pos + Vector2(-13, -20), pos + Vector2(13, -20), Color("e8dcc2", 0.75), 3)

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
	elif state == "leaving":
		draw_arc(pos, 29.0, -PI * 0.8, -PI * 0.2, 12, Color("b7a98c", 0.7), 3)
	else:
		draw_circle(pos + Vector2(0, 24), 26.0, Color("5c4433", 0.08))

func draw_tuning_bloom(pos: Vector2) -> void:
	var bloom_color := Color(String(current_boss_data.get("bloom_color", "fff0a0"))) if not current_boss_data.is_empty() else Color("fff0a0")
	var breathe := 1.0 + sin(elapsed * 4.0) * 0.08
	# Boss 调律目标现在是一朵有花心、有花片的实体，不再是空圈。
	for i in 8:
		var angle := float(i) * TAU / 8.0 + sin(elapsed * 0.9) * 0.08
		var petal_center := pos + Vector2.from_angle(angle) * 18.0 * breathe
		var tangent := Vector2.from_angle(angle + PI * 0.5)
		var radial := Vector2.from_angle(angle)
		draw_colored_polygon(PackedVector2Array([
			petal_center + radial * 13.0,
			petal_center + tangent * 8.0,
			petal_center - radial * 7.0,
			petal_center - tangent * 8.0
		]), Color(bloom_color, 0.78))
	draw_circle(pos, 12.0, Color("5c3f27"))
	for stamen_index in 6:
		var stamen_angle := float(stamen_index) * TAU / 6.0 + elapsed * 0.15
		draw_circle(pos + Vector2.from_angle(stamen_angle) * 6.0, 2.2, Color("fff0a0"))

func draw_ellipse_shadow(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for point_index in 24:
		var angle := TAU * float(point_index) / 24.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)

func draw_boss(state: Dictionary) -> void:
	if current_boss_data.is_empty():
		return
	var data: Dictionary = current_boss_data
	var pos: Vector2 = state.position
	var radius := float(data.size) + sin(elapsed * 5.0) * 2.0
	var body := Color(String(data.body_color))
	var accent := Color(String(data.accent_color))
	var vulnerable := boss_director.can_tune()
	for afterimage in boss_afterimages:
		var a_pos: Vector2 = afterimage.position
		draw_circle(a_pos, radius * 0.8, Color(body, clampf(float(afterimage.life) * 1.6, 0.0, 0.4)))
	if vulnerable:
		draw_circle(pos, radius + 14.0, Color("f5d975", 0.14))
		draw_arc(pos, radius + 20.0 + sin(elapsed * 9.0) * 3.0, 0, TAU, 36, Color("f5d975", 0.88), 4.0)
	match String(data.move_pattern):
		"orbital":
			# 蚊：圆躯 + 长口器
			draw_circle(pos, radius, body)
			draw_circle(pos + Vector2(radius * 0.8, 0), radius * 0.45, accent)
			draw_line(pos + Vector2(radius * 1.1, 0), pos + Vector2(radius * 1.9, -2), Color("2e2327"), 4)
			draw_arc(pos, radius + 9, -2.4, 2.4, 22, Color("d7b56a", 0.55), 3)
			if String(state.get("telegraph", "")) == "siphon":
				draw_line(pos, bee.position, Color("d95d54", 0.5 + sin(elapsed * 12.0) * 0.15), 3.0)
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
			if String(state.get("telegraph", "")) == "landing":
				draw_ellipse_shadow(pos + Vector2(0, radius + 15.0), Vector2(radius * 1.35, 9.0), Color("2a3028", 0.55))
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
			if charge_state in ["aim", "dash"]:
				var aim: Vector2 = state.get("aim_direction", Vector2.RIGHT)
				var locked_origin := Vector2(state.get("locked_origin", pos))
				var locked_target := Vector2(state.get("locked_target", bee.position))
				draw_committed_attack_corridor(locked_origin, aim, locked_target, float(data.impact_range), 0.72 if charge_state == "aim" else 0.42, charge_state == "aim")
				if charge_state == "dash":
					draw_line(pos - aim.normalized() * 110.0, pos, Color("f4d994", 0.75), 8.0)
			draw_circle(pos + Vector2(-radius * 0.55, -radius * 0.6), radius * 0.32, body)
			draw_circle(pos + Vector2(radius * 0.55, -radius * 0.6), radius * 0.32, body)
			draw_circle(pos, radius, body)
			draw_circle(pos + Vector2(0, radius * 0.25), radius * 0.34, accent)
			draw_circle(pos + Vector2(-radius * 0.28, radius * 0.18), radius * 0.07, Color("1c222b"))
			draw_circle(pos + Vector2(radius * 0.28, radius * 0.18), radius * 0.07, Color("1c222b"))
			if String(state.get("telegraph", "")) == "warm_stun":
				for shard in 5:
					var shard_angle := float(shard) * TAU / 5.0 + elapsed
					draw_line(pos + Vector2.from_angle(shard_angle) * (radius + 5.0), pos + Vector2.from_angle(shard_angle) * (radius + 18.0), Color("f5d975", 0.8), 3.0)
	for i in int(state.hits):
		draw_circle(pos + Vector2(-12 + i * 12, -radius - 30), 4, Color("f5d975"))
