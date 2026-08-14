extends SceneTree

var failures: Array[String] = []

func _init() -> void:
	call_deferred("run_test")

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func run_test() -> void:
	var packed := load("res://main.tscn") as PackedScene
	var game = packed.instantiate()
	root.add_child(game)
	await process_frame
	game.persistence_enabled = false
	game.start_game()
	expect(game.phase == "playing" and game.stage_index == 0, "新循环未进入春分")
	game.bee.position = Vector2(100, 410)
	game.bee.energy = 50.0
	game.carried = 0
	game.update_hive_rest(1.0, true)
	expect(game.bee.energy > 50.0 and game.delivered == 0, "空手归巢没有恢复体力")
	game.mosquitoes = [{"id": 0, "position": Vector2(210, 410), "velocity": Vector2(-2, 0), "stunned": 0.0}]
	game.update_mosquitoes(0.2)
	expect(float(game.mosquitoes[0].position.x) >= game.HIVE_SAFE_X, "蚊虫越过蜂巢安全边界")

	for index in 4:
		game.delivered = int(game.stages[index].goal)
		game.show_between()
		expect(game.phase == "between", "节令 %d 未进入蜂巢成长" % index)
		game.on_upgrade_selected(index % 3)
		if index < 3:
			expect(game.phase == "playing" and game.stage_index == index + 1, "节令 %d 无法推进" % index)
		else:
			expect(game.phase == "boss", "冬至后未进入失律者遭遇")

	expect(game.chosen_upgrades.size() == 4, "四次蜂巢成长没有全部生效")
	expect(game.tuning_blooms.size() == 3, "失律者调律花粉数量错误")
	game.show_win()
	expect(game.phase == "won", "失律者结算未进入胜利状态")

	game.spawn_stage(0)
	game.toggle_pause()
	expect(game.phase == "paused" and not game.bee.active, "暂停未冻结玩家")
	game.toggle_pause()
	expect(game.phase == "playing" and game.bee.active, "继续未恢复玩家")

	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("FLOW TEST PASSED: title-to-boss state path is reachable")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
