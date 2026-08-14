extends SceneTree

const REQUIRED_KEYS := ["name", "season", "yin", "yang", "goal", "flowers", "enemies", "ants", "energy_drain", "nectar_scale", "colors", "line"]

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
			if parsed.size() != 4:
				failures.append("MVP 应包含 4 个压缩节令")
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

	var balance_file := FileAccess.open("res://data/balance.json", FileAccess.READ)
	if balance_file == null:
		failures.append("无法读取 balance.json")
	else:
		var balance = JSON.parse_string(balance_file.get_as_text())
		for section in ["player", "mosquito", "ant", "boss"]:
			if not balance is Dictionary or not balance.has(section) or not balance[section] is Dictionary:
				failures.append("平衡参数缺少分区 %s" % section)
		if balance is Dictionary and balance.has("boss") and float(balance.boss.get("required_tunings", 0)) <= 0:
			failures.append("Boss 调律次数必须为正数")

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

	for action in ["harvest", "dash", "repel"]:
		if not InputMap.has_action(action):
			failures.append("缺少玩家动作映射 %s" % action)
	if InputMap.has_action("sense") or InputMap.has_action("sting"):
		failures.append("已移除的感知或普通蜂针动作仍存在")

	if failures.is_empty():
		print("SMOKE TEST PASSED: Godot project and 4 seasonal stages are valid")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
