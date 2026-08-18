extends SceneTree

const REQUIRED_KEYS := ["name", "season", "yin", "yang", "goal", "flowers", "enemies", "ants", "energy_drain", "nectar_scale", "colors", "line", "mechanics"]
const EXPECTED_MECHANICS := ["pollination", "conscription", "reserve", "huddle"]

func _init() -> void:
	var failures: Array[String] = []
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
			for index in parsed.size():
				var stage = parsed[index]
				if not stage is Dictionary:
					failures.append("节令 %d 不是对象" % index)
					continue
				for key in REQUIRED_KEYS:
					if not stage.has(key):
						failures.append("节令 %d 缺少字段 %s" % [index, key])
				if stage.has("yin") and stage.has("yang") and int(stage.yin) + int(stage.yang) != 100:
					failures.append("节令 %d 阴阳总和不是 100" % index)
				if stage.has("goal") and int(stage.goal) <= 0:
					failures.append("节令 %d 目标必须为正数" % index)
				if stage.has("flowers") and stage.has("nectar_scale") and stage.has("goal"):
					var minimum_nectar := int(stage.flowers) * maxi(2, roundi(3.0 * float(stage.nectar_scale)))
					if minimum_nectar < int(stage.goal):
						failures.append("节令 %d 最差花量不足以完成目标" % index)
				if stage.has("ants") and int(stage.ants) < 0:
					failures.append("节令 %d 掠蜜蚁数量不能为负" % index)
				if stage.has("colors") and (not stage.colors is Array or stage.colors.size() != 4):
					failures.append("节令 %d 必须配置 4 个颜色" % index)
				var expected_mechanic: String = EXPECTED_MECHANICS[clampi(index / 6, 0, 3)]
				if not stage.has("mechanics") or not stage.mechanics is Array or stage.mechanics.size() != 1 or stage.mechanics[0] != expected_mechanic:
					failures.append("节令 %d 机制槽位错误（应为 %s）" % [index, expected_mechanic])
			# 轮回必须从冬至开始，按四正点结构推进
			if parsed.size() == 24 and String(parsed[0].name) != "冬至":
				failures.append("完整轮回的第一个节令必须是冬至")

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
				if int(boss.get("season_index", -1)) != index:
					failures.append("失律者 %d season_index 错误" % index)
				if int(boss.get("required_tunings", 0)) <= 0:
					failures.append("失律者 %d 调律次数必须为正数" % index)

	var balance_file := FileAccess.open("res://data/balance.json", FileAccess.READ)
	if balance_file == null:
		failures.append("无法读取 balance.json")
	else:
		var balance = JSON.parse_string(balance_file.get_as_text())
		for section in ["player", "mosquito", "ant", "boss", "mechanics"]:
			if not balance is Dictionary or not balance.has(section) or not balance[section] is Dictionary:
				failures.append("平衡参数缺少分区 %s" % section)
		if balance is Dictionary and balance.has("boss") and float(balance.boss.get("required_tunings", 0)) <= 0:
			failures.append("Boss 调律次数必须为正数")
		if balance is Dictionary and balance.has("mechanics"):
			for mechanic_id in EXPECTED_MECHANICS:
				if not balance.mechanics.has(mechanic_id) or not balance.mechanics[mechanic_id] is Dictionary:
					failures.append("机制参数缺少 %s 分区" % mechanic_id)

	for mechanic_path in ["res://scripts/mechanics/season_mechanics.gd", "res://scripts/mechanics/pollination_mechanic.gd", "res://scripts/mechanics/conscription_mechanic.gd", "res://scripts/mechanics/reserve_mechanic.gd", "res://scripts/mechanics/huddle_mechanic.gd"]:
		if load(mechanic_path) == null:
			failures.append("季节机制脚本无法加载：%s" % mechanic_path)

	var scene := load("res://main.tscn")
	if scene == null:
		failures.append("主场景无法加载")

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

	for action in ["move_left", "move_right", "move_up", "move_down", "harvest", "dash", "repel", "sense", "evade", "decoy"]:
		if not InputMap.has_action(action):
			failures.append("缺少玩家动作映射 %s" % action)
	if InputMap.has_action("sting"):
		failures.append("已移除的普通蜂针动作仍存在")
	for clustered_action in ["harvest", "dash", "sense"]:
		if InputMap.action_get_events(clustered_action).size() < 2:
			failures.append("技能区按键没有为 %s 配置兼容映射" % clustered_action)
	for movement_action in ["move_left", "move_right", "move_up", "move_down"]:
		if InputMap.action_get_events(movement_action).size() < 2:
			failures.append("WASD/方向键双映射缺失：%s" % movement_action)

	if failures.is_empty():
		print("SMOKE TEST PASSED: Godot project, 24 solar terms and 4 boss prototypes are valid")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
