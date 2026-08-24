extends SceneTree

var failures: Array[String] = []

func _init() -> void:
	call_deferred("run_test")

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func finish_demo(mentor) -> void:
	mentor.process(float(mentor.demo_duration) + 0.1)

func run_test() -> void:
	var packed := load("res://main.tscn") as PackedScene
	var game = packed.instantiate()
	root.add_child(game)
	await process_frame
	game.persistence_enabled = false
	game.tutorial_complete = false
	game.start_game()
	var mentor = game.mentor_tutorial
	expect(mentor.profile_id == "first_trip_pollination" and mentor.lesson_id == "sortie", "首关没有启动老师傅出巢演示")
	expect(mentor.phase == "demo" and mentor.blocks_simulation() and not game.bee.active, "演示阶段没有冻结玩家与真实模拟")
	var honey_before: int = int(game.total_recoverable_honey())
	var energy_before: float = float(game.bee.energy)
	var delivered_before: int = int(game.delivered)
	var flower_snapshot: Array = game.flowers.duplicate(true)
	game.update_game(0.8)
	expect(game.total_recoverable_honey() == honey_before and game.bee.energy == energy_before and game.delivered == delivered_before, "老师傅演示偷偷修改了真实资源或体力")
	expect(game.flowers == flower_snapshot, "老师傅演示改变了真实花田")
	finish_demo(mentor)
	expect(mentor.phase == "imitate" and game.bee.active, "演示结束后没有把控制权交给玩家")
	expect(bool(mentor.prompt().visible) and mentor.allows_action("harvest") and not mentor.allows_action("sense") and not mentor.allows_action("drink") and not mentor.allows_action("decoy"), "模仿阶段没有保持单一动作顺序")
	# Advance the real first-trip evidence rather than writing step 3 directly.
	game.bee.position = game.tutorial_origin + Vector2(70, 0)
	game.update_progressive_guidance()
	expect(game.tutorial_step == 1, "真实离巢没有推进移动证据")
	game.carried = 1
	game.update_progressive_guidance()
	expect(game.tutorial_step == 2, "真实携蜜没有推进采集证据")
	game.delivered = 2
	game._on_tutorial_home(1)
	expect(game.tutorial_step == 3, "真实卸蜜没有推进归巢证据")
	mentor.process(0.0)
	expect(mentor.phase == "practice" and not bool(mentor.prompt().visible), "第一次归巢后没有收起提示进入独立练习")
	expect(game.flowers.any(func(flower): return bool(flower.get("mentor_practice", false))), "独立练习没有提供一滴真实练习蜜")
	game.delivered = 3
	mentor.process(0.0)
	expect(mentor.lesson_id == "sense" and mentor.phase == "demo", "第二次独立归巢后没有按顺序演示寻迹")
	finish_demo(mentor)
	game.tutorial_scent_revealed = true
	mentor.process(0.0)
	expect(mentor.phase == "practice" and not bool(mentor.prompt().visible), "寻迹成功后没有隐藏教学卡要求真实找花")
	game.tutorial_step = 4
	mentor.process(0.0)
	expect(mentor.lesson_id == "defense" and mentor.phase == "demo", "实际采到藏花后没有演示惊退")
	finish_demo(mentor)
	expect(mentor.notify_event("resource_cleared") == "repeat_without_prompt" and mentor.phase == "practice", "第一次真实清出资源区后没有进入无提示驱离练习")
	expect(not bool(mentor.prompt().visible), "驱离独立练习仍然显示答案")
	expect(mentor.notify_event("resource_cleared") == "advance" and mentor.lesson_id == "evade" and mentor.phase == "demo", "第二次真实清出资源区后没有演示急转")
	finish_demo(mentor)
	expect(mentor.notify_event("attack_evaded") == "repeat_without_prompt" and mentor.phase == "practice", "第一次真实闪避没有进入无提示复现")
	expect(mentor.notify_event("attack_evaded") == "advance" and mentor.lesson_id == "pollination" and mentor.phase == "demo", "第二次真实闪避没有进入授粉演示")
	finish_demo(mentor)
	var pollination = game.season_mechanics.mechanic_by_id("pollination")
	pollination.opened_buds = 1
	mentor.process(0.0)
	expect(mentor.phase == "practice" and not bool(mentor.prompt().visible), "第一朵芽打开后没有进入无提示授粉练习")
	pollination.opened_buds = 2
	mentor.process(0.0)
	expect(mentor.phase == "complete" and game.tutorial_complete and mentor.can_complete_stage(), "第二朵芽打开后首关教学仍未完成")

	game.spawn_stage(7)
	mentor = game.mentor_tutorial
	expect(mentor.profile_id == "raid_intro" and mentor.phase == "demo", "袭扰首关没有老师傅演示")
	finish_demo(mentor)
	var raid = game.season_mechanics.mechanic_by_id("conscription")
	game.season_mechanics.on_home(3, 0.1)
	var empty_raider: Dictionary = raid.raid_ants[0]
	empty_raider.position = game.bee.position
	empty_raider.stolen = 0
	raid.raid_ants[0] = empty_raider
	expect(not mentor.allows_action("seasonal"), "老师傅要求等待偷蜜时仍允许提前清空袭扰者")
	expect(raid.repel_raider_at(game.bee.position), "无赃蜜袭扰者无法被真实惊退")
	mentor.process(0.0)
	expect(mentor.phase == "imitate", "袭扰者尚未偷蜜就被误判为返蜜教学成功")
	var stolen_index := 1 if raid.raid_ants.size() > 1 else 0
	var stolen_raider: Dictionary = raid.raid_ants[stolen_index]
	stolen_raider.position = game.bee.position
	stolen_raider.target = 0
	stolen_raider.stolen = 1
	stolen_raider.state = "holding"
	raid.raid_ants[stolen_index] = stolen_raider
	var stolen_flower: Dictionary = game.flowers[0]
	stolen_flower.nectar = maxi(0, int(stolen_flower.nectar) - 1)
	game.flowers[0] = stolen_flower
	expect(mentor.allows_action("seasonal"), "袭扰者真正持有赃蜜后老师傅仍不允许惊退")
	expect(raid.repel_raider_at(game.bee.position), "持有赃蜜的袭扰者无法被真实惊退")
	mentor.process(0.0)
	expect(mentor.phase == "practice", "第一次真实返蜜后没有收起夏季提示")
	raid.state = "cleared"
	mentor.process(0.0)
	expect(mentor.can_complete_stage(), "其余袭扰者清空后夏季练习仍未完成")

	game.spawn_stage(13)
	mentor = game.mentor_tutorial
	expect(not bool(game.flowers[0].get("tutorial_locked", true)), "秋季示范没有留出第一朵真实种花")
	expect(bool(game.flowers[1].get("tutorial_locked", false)), "秋季示范前同时开放多朵种花，仍可批量跳过练习")
	finish_demo(mentor)
	var reserve = game.season_mechanics.mechanic_by_id("reserve")
	var prepared: Dictionary = game.flowers[0]
	prepared.seed_ready = true
	game.flowers[0] = prepared
	reserve.on_home(1, 0.1)
	mentor.process(0.0)
	expect(mentor.phase == "practice", "第一颗种子成熟后没有收起秋季提示")
	expect(not bool(game.flowers[1].get("tutorial_locked", true)), "进入独立练习后没有开放第二朵真实种花")
	mentor.process(0.0)
	expect(mentor.phase == "practice", "没有发生第二次取舍却自动跳过了独立练习")
	var next_seed: Dictionary = game.flowers[1]
	next_seed.seed_ready = true
	game.flowers[1] = next_seed
	reserve.on_home(1, 0.1)
	mentor.process(0.0)
	expect(mentor.can_complete_stage(), "第二朵花完成真实取舍后秋季练习仍未完成")
	expect(game.flowers.all(func(flower): return not bool(flower.get("tutorial_locked", false))), "秋季教学完成后仍锁着普通关卡花源")

	game.spawn_stage(19)
	mentor = game.mentor_tutorial
	finish_demo(mentor)
	var huddle = game.season_mechanics.mechanic_by_id("huddle")
	huddle.activated_points = 1
	mentor.process(0.0)
	expect(mentor.phase == "practice", "第一盏暖灯点亮后没有收起冬季提示")
	huddle.activated_points = huddle.warm_points.size()
	mentor.process(0.0)
	expect(mentor.can_complete_stage(), "三盏暖灯全部点亮后冬季练习仍未完成")

	if failures.is_empty():
		print("MENTOR TUTORIAL TEST PASSED")
		print("TEST PASSED")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
