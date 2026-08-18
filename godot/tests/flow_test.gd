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
		var expected_id: String = ["pollination", "conscription", "reserve", "huddle"][stage_index]
		expect(game.season_mechanics.mechanic_by_id(expected_id) != null, "节令 %d 未激活 %s 机制" % [stage_index, expected_id])
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
		var reserve_m = game.season_mechanics.mechanic_by_id("reserve")
		if reserve_m != null and reserve_m.pending_allocation:
			expect(game.allocation_pending, "秋分未进入分配界面")
			game.confirm_allocation()
			expect(not game.allocation_pending, "秋分分配后界面未关闭")
		game.on_upgrade_selected(index % 3)
		if index < 3:
			expect(game.phase == "playing" and game.stage_index == index + 1, "节令 %d 无法推进" % index)
		else:
			expect(game.phase == "boss", "冬至后未进入失律者遭遇")

	expect(game.chosen_upgrades.size() == 4, "四次蜂巢成长没有全部生效")
	expect(game.tuning_blooms.size() == 3, "失律者调律花粉数量错误")
	expect(game.hive_reserve > 0, "公共储备没有在四季间积累")
	# 冬至抱团机制
	game.spawn_stage(3)
	expect(game.warmth == 100.0, "冬至出巢温暖未初始化")
	var reserve_before: int = game.hive_reserve
	game.bee.position = Vector2(500, 410)
	game.season_mechanics.process(1.0)
	expect(game.warmth < 100.0, "冬至野外温暖没有下降")
	game.bee.position = Vector2(100, 410)
	game.carried = 3
	game.update_hive_rest(1.0, true)
	expect(game.warmth >= 99.0 and game.hive_reserve == reserve_before - 1, "冬至归巢抱团未按预期回暖或消耗储备")
	game.show_win()
	expect(game.phase == "won", "失律者结算未进入胜利状态")

	game.spawn_stage(0)
	game.toggle_pause()
	expect(game.phase == "paused" and not game.bee.active, "暂停未冻结玩家")
	game.toggle_pause()
	expect(game.phase == "playing" and game.bee.active, "继续未恢复玩家")

	# 四季机制单元探针
	# 春分·授粉：休眠与新花开放
	game.spawn_stage(0)
	var pollinator = game.season_mechanics.mechanic_by_id("pollination")
	expect(pollinator != null, "春分授粉机制缺失")
	if pollinator != null:
		var dozing: Dictionary = game.flowers[0]
		dozing["sleep_timer"] = 0.1
		game.flowers[0] = dozing
		game.season_mechanics.process(0.3)
		expect(bool(game.flowers[0].get("sleeping", false)), "授粉：久不采的花未休眠")
		var flower_count_before: int = game.flowers.size()
		var pollinated: Dictionary = game.flowers[1]
		pollinated["nectar"] = 1
		pollinated["max_nectar"] = 6
		game.flowers[1] = pollinated
		game.season_mechanics.on_harvest(1)
		expect(game.flowers.size() == flower_count_before + 1, "授粉：采蜜未使新花开放")
	# 夏至·征召：事件触发与响应
	game.spawn_stage(1)
	var conscription = game.season_mechanics.mechanic_by_id("conscription")
	expect(conscription != null, "夏至征召机制缺失")
	if conscription != null:
		conscription.state = "idle"
		conscription.timer = 0.1
		game.season_mechanics.process(0.2)
		expect(conscription.state == "active", "征召：事件未触发")
		if conscription.kind == "hive":
			game.bee.position = Vector2(100, 410)
			var reserve_before_reward: int = game.hive_reserve
			conscription.response_progress = 0.9
			game.season_mechanics.on_home(0, 0.2)
			expect(conscription.state == "idle" and game.hive_reserve > reserve_before_reward, "征召：巢口响应未获奖励")
		else:
			conscription.raid_ants = [{"position": Vector2(320, 300), "velocity": Vector2.ZERO, "flee_time": 0.0}]
			game.bee.position = Vector2(300, 300)
			var nectar_before_response: int = int(game.flowers[0].nectar)
			conscription.field_repels_done = 1
			game.season_mechanics.on_repel_success()
			expect(conscription.state == "idle", "征召：花区响应未完成")
			expect(int(game.flowers[0].nectar) > nectar_before_response, "征召：花区响应后花田未恢复")

	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("FLOW TEST PASSED: title-to-boss state path is reachable")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
