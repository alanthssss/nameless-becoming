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
	for stage_index in 4:
		game.spawn_stage(stage_index)
		expect(game.total_recoverable_honey() >= int(game.stages[stage_index].goal), "节令 %d 初始总蜜量不足" % stage_index)
		for flower_index in game.flowers.size():
			for other_index in range(flower_index + 1, game.flowers.size()):
				expect(Vector2(game.flowers[flower_index].position).distance_to(Vector2(game.flowers[other_index].position)) >= 81.9, "节令 %d 花朵生成间距不足" % stage_index)
	game.spawn_stage(0)
	var movement_start: Vector2 = game.bee.position
	var d_key := InputEventKey.new()
	d_key.physical_keycode = KEY_D
	d_key.pressed = true
	expect(InputMap.event_is_action(d_key, "move_right"), "物理 D 键没有映射到向右移动")
	Input.action_press("move_right")
	game.bee._physics_process(0.1)
	Input.action_release("move_right")
	expect(game.bee.position.x > movement_start.x, "WASD 的 D 键动作没有驱动玩家")
	game.bee.energy = 100.0
	game.bee.velocity = Vector2.RIGHT
	expect(game.bee.try_evade() and game.bee.invulnerable_time > 0.0 and game.bee.energy == 88.0, "K 急转没有产生位移防护与体力消耗")
	var conserved_before: int = game.total_recoverable_honey()
	game.flowers[0].nectar = int(game.flowers[0].nectar) - 2
	game.carried = 2
	game.fail_expedition()
	expect(game.total_recoverable_honey() == conserved_before, "体力耗尽后花蜜没有回到生态循环")
	game.carried = 1
	var before_decoy: int = game.total_recoverable_honey()
	game.drop_honey_decoy()
	expect(game.decoys.size() == 1 and game.total_recoverable_honey() == before_decoy, "L 诱饵没有生效或破坏了花蜜守恒")
	game.bee.position = Vector2(100, 410)
	game.bee.energy = 50.0
	game.carried = 0
	game.update_hive_rest(1.0, true)
	expect(game.bee.energy > 50.0 and game.delivered == 0, "空手归巢没有恢复体力")
	game.mosquitoes = [{"id": 0, "position": Vector2(210, 410), "velocity": Vector2(-2, 0), "repel_time": 0.0}]
	game.update_mosquitoes(0.2)
	expect(float(game.mosquitoes[0].position.x) >= game.HIVE_SAFE_X, "蚊虫越过蜂巢安全边界")
	game.bee.position = Vector2(280, 410)
	game.mosquitoes = [{"id": 0, "position": Vector2(320, 410), "velocity": Vector2.ZERO, "repel_time": 1.0}]
	game.update_mosquitoes(0.2)
	expect(float(game.mosquitoes[0].position.x) > 320.0, "惊退状态没有让蚊虫实际远离玩家")
	game.bee.sense_time = 3.0
	expect(game.best_foraging_target() >= 0, "触角寻迹没有给出采集建议")

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
