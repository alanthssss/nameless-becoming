extends SceneTree

const EXPECTED_MECHANICS := ["pollination", "conscription", "reserve", "huddle"]
const GATHERING_KEYS := ["goal", "flowers", "mosquitoes", "ants", "crickets", "thrushes", "bears", "energy_drain", "nectar_scale", "mechanics"]
const SPECIES_KEYS := ["mosquitoes", "ants", "crickets", "thrushes", "bears"]
const GLYPH_SOURCE_EXTENSIONS := ["gd", "godot", "json", "tres", "tscn"]
const GLYPH_IGNORED_DIRECTORIES := [".godot", "fonts", "tests"]

func collect_glyph_source_files(directory_path: String, output: Array[String]) -> void:
	var directory := DirAccess.open(directory_path)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		var entry_path := directory_path.path_join(entry)
		if directory.current_is_dir():
			if entry not in GLYPH_IGNORED_DIRECTORIES:
				collect_glyph_source_files(entry_path, output)
		elif entry.get_extension().to_lower() in GLYPH_SOURCE_EXTENSIONS:
			output.append(entry_path)
		entry = directory.get_next()
	directory.list_dir_end()
	output.sort()

func is_cjk_codepoint(codepoint: int) -> bool:
	return (
		(codepoint >= 0x3000 and codepoint <= 0x303F)
		or (codepoint >= 0x3400 and codepoint <= 0x4DBF)
		or (codepoint >= 0x4E00 and codepoint <= 0x9FFF)
		or (codepoint >= 0xFF00 and codepoint <= 0xFFEF)
	)

func check_cjk_glyph_coverage(failures: Array[String]) -> void:
	var font := load("res://fonts/NotoSansCJKsc-ProjectSubset.otf") as Font
	if font == null:
		failures.append("无法加载项目中文字体")
		return
	var missing: Dictionary = {}
	var source_files: Array[String] = []
	collect_glyph_source_files("res://", source_files)
	if source_files.is_empty():
		failures.append("未找到任何运行时字形来源")
	for source_path in source_files:
		var source := FileAccess.open(source_path, FileAccess.READ)
		if source == null:
			failures.append("无法读取字形检查源：%s" % source_path)
			continue
		for character in source.get_as_text():
			var codepoint := character.unicode_at(0)
			if is_cjk_codepoint(codepoint) and not font.has_char(codepoint):
				missing[codepoint] = character
	if not missing.is_empty():
		var missing_characters := ""
		for codepoint in missing:
			missing_characters += String.chr(int(codepoint))
		failures.append("中文字体缺少项目字形：%s" % missing_characters)

func check_runtime_control_fonts(failures: Array[String]) -> void:
	const expected_font_path := "res://fonts/NotoSansCJKsc-ProjectSubset.otf"
	var expected_font := load(expected_font_path) as Font
	if expected_font == null:
		failures.append("无法加载项目字体进行控件检查")
		return
	if String(ProjectSettings.get_setting("gui/theme/custom_font", "")) != expected_font_path:
		failures.append("项目级中文字体未配置为 gui/theme/custom_font")
	for scene_path in ["res://main.tscn", "res://journey.tscn"]:
		var scene := load(scene_path) as PackedScene
		if scene == null:
			failures.append("无法加载场景进行控件字体检查：%s" % scene_path)
			continue
		var game := scene.instantiate()
		root.add_child(game)
		for node in game.find_children("*", "Control", true, false):
			if node is Label or node is Button:
				var control := node as Control
				if control.get_theme_font("font") != expected_font:
					failures.append("文本控件未使用项目字体：%s (%s)" % [control.get_path(), control.get_class()])
				var visible_text := String(control.get("text"))
				for character in visible_text:
					var codepoint := character.unicode_at(0)
					if codepoint > 0x20 and not expected_font.has_char(codepoint):
						failures.append("文本控件包含无法渲染的字符：%s (%s, U+%04X)" % [control.get_path(), character, codepoint])
		game.queue_free()

func _init() -> void:
	var failures: Array[String] = []
	check_cjk_glyph_coverage(failures)
	check_runtime_control_fonts(failures)
	var file := FileAccess.open("res://data/seasons.json", FileAccess.READ)
	if file == null:
		failures.append("无法读取 seasons.json")
	else:
		var parsed = JSON.parse_string(file.get_as_text())
		if not parsed is Array:
			failures.append("seasons.json 顶层必须是数组")
		else:
			if parsed.size() != 24:
				failures.append("完整轮回应包含 24 个节令")
			var boss_stage_count := 0
			for index in parsed.size():
				var stage = parsed[index]
				if not stage is Dictionary:
					failures.append("节令 %d 不是对象" % index)
					continue
				for key in ["name", "season", "yin", "yang", "colors", "line"]:
					if not stage.has(key):
						failures.append("节令 %d 缺少字段 %s" % [index, key])
				if stage.has("yin") and stage.has("yang") and int(stage.yin) + int(stage.yang) != 100:
					failures.append("节令 %d 阴阳总和不是 100" % index)
				if stage.has("colors") and (not stage.colors is Array or stage.colors.size() != 4):
					failures.append("节令 %d 必须配置 4 个颜色" % index)
				# 正色节点本身是失律者关卡，不携带采蜜字段
				if stage.has("boss"):
					boss_stage_count += 1
					for key in GATHERING_KEYS:
						if stage.has(key):
							failures.append("失律者关卡 %d 不应携带采蜜字段 %s" % [index, key])
					continue
				for key in GATHERING_KEYS:
					if not stage.has(key):
						failures.append("采蜜关 %d 缺少字段 %s" % [index, key])
				# 五物候种数量都不能为负；熊作为碾压型敌害每关至多 1 只
				for species in SPECIES_KEYS:
					if stage.has(species) and int(stage[species]) < 0:
						failures.append("节令 %d 的 %s 数量不能为负" % [index, species])
				if stage.has("bears") and int(stage.bears) > 1:
					failures.append("节令 %d 的熊至多 1 只（碾压型敌害不宜成群）" % index)
				if stage.has("goal") and int(stage.goal) <= 0:
					failures.append("节令 %d 目标必须为正数" % index)
				if stage.has("flowers") and stage.has("nectar_scale") and stage.has("goal"):
					var minimum_nectar := int(stage.flowers) * maxi(2, roundi(3.0 * float(stage.nectar_scale)))
					if minimum_nectar < int(stage.goal):
						failures.append("节令 %d 最差花量不足以完成目标" % index)
				var expected_mechanic: String = EXPECTED_MECHANICS[clampi(index / 6, 0, 3)]
				if not stage.has("mechanics") or not stage.mechanics is Array or stage.mechanics.size() != 1 or stage.mechanics[0] != expected_mechanic:
					failures.append("节令 %d 机制槽位错误（应为 %s）" % [index, expected_mechanic])
			# 轮回从冬至开始；正色节点为失律者关卡，熊守着循环终点（大雪之后）
			if parsed.size() == 24:
				if String(parsed[0].name) != "冬至":
					failures.append("完整轮回的第一个节令必须是冬至")
				if boss_stage_count != 3:
					failures.append("正色失律者关卡应恰好 3 个（春分/夏至/秋分），实为 %d" % boss_stage_count)
				var cardinal_bosses := {6: ["春分", "mosquito"], 12: ["夏至", "cricket"], 18: ["秋分", "thrush"]}
				for position in cardinal_bosses:
					var expected: Array = cardinal_bosses[position]
					if String(parsed[position].name) != expected[0] or String(parsed[position].get("boss", "")) != expected[1]:
						failures.append("节令 %d 应为正色失律者关卡 %s（%s）" % [position, expected[0], expected[1]])
				if String(parsed[23].name) != "大雪":
					failures.append("最后一个采蜜关应为大雪，此后回到冬至的熊")
				# 越冬段体温延续标记：寒露重置，其余越冬关延续
				var huddle_stages: Array[String] = []
				for index in parsed.size():
					if parsed[index].get("mechanics", []).size() == 1 and parsed[index].mechanics[0] == "huddle":
						huddle_stages.append(String(parsed[index].name))
				if huddle_stages.size() == 5 and huddle_stages[0] != "寒露":
					failures.append("越冬段应从寒露开始（体温在此重置）")
				for stage in parsed:
					if stage.get("mechanics", []).size() == 1 and stage.mechanics[0] == "huddle" and String(stage.name) != "寒露" and not bool(stage.get("warmth_carry", false)):
						failures.append("越冬关 %s 缺少 warmth_carry 标记" % String(stage.name))
				# 每个大关的花型必须与实际机制相连；数据里只有名字但没有 stage 接线不算实现。
				var flower_set_by_mechanic := {
					"pollination": "spring",
					"conscription": "summer",
					"reserve": "autumn",
					"huddle": "winter"
				}
				for stage in parsed:
					if stage.has("boss"):
						continue
					var mechanic_id := String(stage.mechanics[0])
					var expected_flower_set := String(flower_set_by_mechanic.get(mechanic_id, ""))
					if String(stage.get("flower_set", "")) != expected_flower_set:
						failures.append("节令 %s 的 %s 机制应连接 flower_set=%s" % [String(stage.name), mechanic_id, expected_flower_set])

	var upgrade_file := FileAccess.open("res://data/upgrades.json", FileAccess.READ)
	if upgrade_file == null:
		failures.append("无法读取 upgrades.json")
	else:
		var upgrades = JSON.parse_string(upgrade_file.get_as_text())
		if not upgrades is Array or upgrades.size() != 3:
			failures.append("MVP 必须提供 3 种蜂巢分工")
		else:
			for upgrade in upgrades:
				for key in ["id", "name", "description", "color"]:
					if not upgrade.has(key):
						failures.append("蜂巢成长缺少字段 %s" % key)

	var boss_file := FileAccess.open("res://data/bosses.json", FileAccess.READ)
	if boss_file == null:
		failures.append("无法读取 bosses.json")
	else:
		var bosses = JSON.parse_string(boss_file.get_as_text())
		if not bosses is Array or bosses.size() != 4:
			failures.append("四位失律者原型必须齐全（蚊/油葫芦/画眉/熊）")
		else:
			var expected_patterns := ["orbital", "erratic", "lure", "charge"]
			var expected_terms := ["春分", "夏至", "秋分", "冬至"]
			var boss_keys := ["id", "name", "season_index", "term", "line", "move_pattern", "move_speed", "impact_range", "energy_damage", "tuning_radius", "required_tunings", "bloom_count", "bloom_color", "body_color", "accent_color", "size", "encounter_message", "tuning_message", "miss_message", "damage_message"]
			for index in bosses.size():
				var boss = bosses[index]
				if not boss is Dictionary:
					failures.append("失律者 %d 不是对象" % index)
					continue
				for key in boss_keys:
					if not boss.has(key):
						failures.append("失律者 %d 缺少字段 %s" % [index, key])
				if String(boss.get("move_pattern", "")) != expected_patterns[index]:
					failures.append("失律者 %d 移动模式错误（应为 %s）" % [index, expected_patterns[index]])
				if String(boss.get("term", "")) != expected_terms[index]:
					failures.append("失律者 %d 应位于四正点 %s" % [index, expected_terms[index]])
				# season_index 对应新游戏季分段：春分=1、夏至=2、秋分=3、冬至终点=3
				var expected_season_indices := [1, 2, 3, 3]
				if int(boss.get("season_index", -1)) != expected_season_indices[index]:
					failures.append("失律者 %d season_index 错误" % index)
				if int(boss.get("required_tunings", 0)) <= 0:
					failures.append("失律者 %d 调律次数必须为正数" % index)

	var balance_file := FileAccess.open("res://data/balance.json", FileAccess.READ)
	if balance_file == null:
		failures.append("无法读取 balance.json")
	else:
		var balance = JSON.parse_string(balance_file.get_as_text())
		for section in ["player", "mosquito", "ant", "cricket", "thrush", "bear", "boss", "mechanics"]:
			if not balance is Dictionary or not balance.has(section) or not balance[section] is Dictionary:
				failures.append("平衡参数缺少分区 %s" % section)
		if balance is Dictionary and balance.has("boss") and float(balance.boss.get("required_tunings", 0)) <= 0:
			failures.append("Boss 调律次数必须为正数")
		if balance is Dictionary and balance.has("mechanics"):
			for mechanic_id in EXPECTED_MECHANICS:
				if not balance.mechanics.has(mechanic_id) or not balance.mechanics[mechanic_id] is Dictionary:
					failures.append("机制参数缺少 %s 分区" % mechanic_id)

	var flower_file := FileAccess.open("res://data/flowers.json", FileAccess.READ)
	if flower_file == null:
		failures.append("无法读取 flowers.json")
	else:
		var flower_data = JSON.parse_string(flower_file.get_as_text())
		if not flower_data is Dictionary:
			failures.append("flowers.json 顶层必须是对象")
		else:
			for season_id in ["spring", "summer", "autumn", "winter"]:
				if not flower_data.has(season_id):
					failures.append("flowers.json 缺少季节分组 %s" % season_id)
				else:
					var fset = flower_data[season_id]
					if not fset is Dictionary or not fset.has("types") or not fset.types is Array:
						failures.append("flowers.json %s 缺少 types 数组" % season_id)
					else:
						for ftype in fset.types:
							for key in ["id", "nectar_base", "weight"]:
								if not ftype.has(key):
									failures.append("flowers.json %s 花型缺少字段 %s" % [season_id, key])
			if flower_data.has("spring") and flower_data.spring is Dictionary:
				if flower_data.spring.has("pollen_transfer"):
					failures.append("flowers.json spring 仍保留快速访花加蜜的 pollen_transfer 规则")
				if not flower_data.spring.has("chain_bloom"):
					failures.append("flowers.json spring 缺少 chain_bloom 配置")

	# 花物候学：春季节令必须携带 flower_set
	# (checked inside seasons.json validation block above)

	for mechanic_path in ["res://scripts/mechanics/season_mechanics.gd", "res://scripts/mechanics/pollination_mechanic.gd", "res://scripts/mechanics/conscription_mechanic.gd", "res://scripts/mechanics/reserve_mechanic.gd", "res://scripts/mechanics/huddle_mechanic.gd"]:
		if load(mechanic_path) == null:
			failures.append("季节机制脚本无法加载：%s" % mechanic_path)

	var scene := load("res://main.tscn")
	if scene == null:
		failures.append("主场景无法加载")
	var bootstrap_scene := load("res://bootstrap.tscn")
	if bootstrap_scene == null:
		failures.append("bootstrap 场景无法加载")
	var b01_scene := load("res://playtest/b01_evade_slice.tscn") as PackedScene
	if b01_scene == null:
		failures.append("B01 typed scene 无法加载")
	var b01_registry_scene := PlaytestSliceRegistry.new().scene_for_code("B01")
	if b01_registry_scene == null or b01_registry_scene.resource_path != "res://playtest/b01_evade_slice.tscn":
		failures.append("生产 registry 未编译真实 B01 typed scene")
	for evade_runtime_path in ["res://scripts/mechanics/evade_rules.gd", "res://scripts/player/evade_input_controller.gd"]:
		if load(evade_runtime_path) == null:
			failures.append("共享急转运行时无法加载：%s" % evade_runtime_path)
	if String(ProjectSettings.get_setting("application/run/main_scene", "")) != "res://bootstrap.tscn":
		failures.append("导出主入口必须是 bootstrap.tscn")

	var bee_script := load("res://scripts/player/bee_player.gd")
	if bee_script == null:
		failures.append("玩家控制脚本无法加载")
	else:
		var bee = bee_script.new()
		bee.reset_for_expedition(Vector2(180, 410))
		if bee.energy != 100.0:
			failures.append("出巢时体力未正确重置")
		if not bee.spend_energy(8.0) or bee.energy != 92.0:
			failures.append("体力消耗公式错误")
		if bee.spend_energy(100.0):
			failures.append("体力不足时不应允许消费")
		bee.reset_upgrades()
		bee.apply_upgrade("long_wing")
		if bee.speed_multiplier <= 1.0 or bee.dash_cost_multiplier >= 1.0:
			failures.append("长翼蜂成长未改变飞行属性")
		bee.free()

	var save_script := load("res://scripts/save_manager.gd")
	if save_script == null:
		failures.append("存档脚本无法加载")
	else:
		var save_manager = save_script.new()
		if save_manager.best_stage != 0 or save_manager.fullscreen:
			failures.append("新存档默认值错误")
		if save_manager.last_run_seconds != 0.0:
			failures.append("新存档不应含有上局时长")

	if load("res://scripts/sound_feedback.gd") == null:
		failures.append("程序化音效脚本无法加载")

	for action in ["move_left", "move_right", "move_up", "move_down", "action", "return_hive", "drink_honey"]:
		if not InputMap.has_action(action):
			failures.append("缺少玩家动作映射 %s" % action)
	for removed_action in ["harvest", "dash", "repel", "sense", "evade", "decoy", "sting"]:
		if InputMap.has_action(removed_action):
			failures.append("已移除的旧动作仍存在：%s" % removed_action)
	for movement_action in ["move_left", "move_right", "move_up", "move_down"]:
		if InputMap.action_get_events(movement_action).size() < 2:
			failures.append("WASD/方向键双映射缺失：%s" % movement_action)
	if InputMap.action_get_events("action").size() < 2:
		failures.append("动作键缺少 Space/Enter 双映射")
	if bool(ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch", true)):
		failures.append("触摸已由主循环显式处理，不应再模拟鼠标把一次触摸误算成双击")

	# 失律者战败必须可见、可重入：避免「XX完成 · 蜂巢成长」stale 文案重新浮上来。
	# 范围检查：主脚本必须暴露 show_boss_loss，且 on_overlay_button 接受 boss_loss 相位。
	# 历史信息（轮回计数 + 前路最远）应寄生在 HUD 侧栏持久位，而不是 overlay 弹窗里的临时 Label：
	# 旧 overlay_history Label 只在 show_intro 写了 visible=true，从未关闭，会跟着 overlay 一起浮到
	# 升级选择界面盖在三张升级卡片上，导致卡片读不清、按钮区域视觉碎片化。
	var main_script := load("res://scripts/main.gd")
	if main_script == null:
		failures.append("主脚本无法加载")
	else:
		var main_node = main_script.new()
		if not main_node.has_method("show_boss_loss"):
			failures.append("缺失 show_boss_loss：失律者战败需要专属结算页，不能复用 show_loss")
		if not main_node.has_method("refresh_runs_meter"):
			failures.append("缺失 refresh_runs_meter：历史信息应从 overlay 弹窗搬到 HUD 侧栏底部")
		# 失败 overlay「主操作 + 二级链接」双交互：
		# overlay 上的"重新走四季"按钮历史只有一处极小的 button，玩家会以为失败页面
		# 只能依赖顶部 HUD 按钮。需要 on_secondary_link / set_secondary_link 等辅助函数
		# 给出次要出口（退出游戏）。
		if not main_node.has_method("on_secondary_link"):
			failures.append("缺失 on_secondary_link：失败页面需要二级链接，给玩家退出选项")
		if not main_node.has_method("set_secondary_link"):
			failures.append("缺失 set_secondary_link：次要链接的显示/隐藏应该集中管理")
		# main_node 未进入场景树，_ready() 不会把预创建的 sound 注册为子节点；
		# 测试夹具需显式释放它，避免退出时产生 Node/GDScript 资源泄漏警告。
		main_node.sound.free()
		main_node.free()

	if failures.is_empty():
		print("SMOKE TEST PASSED: Godot project, 24 solar terms and 4 boss prototypes are valid")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
