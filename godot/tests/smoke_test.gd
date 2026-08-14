extends SceneTree

const REQUIRED_KEYS := ["name", "season", "yin", "yang", "goal", "flowers", "enemies", "energy_drain", "nectar_scale", "colors", "line"]

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
				if stage.has("colors") and (not stage.colors is Array or stage.colors.size() != 4):
					failures.append("节令 %d 必须配置 4 个颜色" % index)

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
		bee.free()

	if failures.is_empty():
		print("SMOKE TEST PASSED: Godot project and 4 seasonal stages are valid")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
