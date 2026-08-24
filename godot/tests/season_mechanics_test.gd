extends SceneTree

var failures: Array[String] = []

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _init() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var packed := load("res://main.tscn") as PackedScene
	expect(packed != null, "无法加载主场景")
	if packed == null:
		finish()
		return
	var game = packed.instantiate()
	root.add_child(game)
	await process_frame
	game.persistence_enabled = false
	game.tutorial_complete = true
	game.start_game()

	var flower_set_by_mechanic := {"pollination": "spring", "conscription": "summer", "reserve": "autumn", "huddle": "winter"}
	for stage in game.stages:
		if stage.has("boss"):
			continue
		var mechanic_id := String(stage.mechanics[0])
		expect(String(stage.get("flower_set", "")) == String(flower_set_by_mechanic[mechanic_id]), "花型未连接机制：%s" % String(stage.name))

	# 春：采花形成携粉状态；匹配花粉把不可采的锁芽变成真花。
	game.spawn_stage(0)
	var spring = game.season_mechanics.mechanic_by_id("pollination")
	expect(spring != null, "春季机制未启动")
	if spring != null:
		expect(not spring.source_indices.is_empty() and not spring.bud_indices.is_empty(), "春季没有花粉源或锁芽")
		var bud_index: int = spring.bud_indices[0]
		var required: int = int(game.flowers[bud_index].required_pollen)
		var source_index := -1
		for candidate in spring.source_indices:
			if int(game.flowers[candidate].pollen_kind) == required:
				source_index = candidate
				break
		expect(source_index >= 0, "锁芽找不到匹配花粉")
		if source_index >= 0:
			game.season_mechanics.on_harvest(source_index)
			expect(spring.carried_pollen == required, "采花没有形成携粉状态")
			expect(not game.season_mechanics.is_flower_available(bud_index), "锁芽开放前仍可被普通采集")
			game.bee.position = Vector2(game.flowers[bud_index].position)
			expect(game.season_mechanics.try_context_action(game.bee.position), "锁芽旁情境动作未消费")
			expect(bool(game.flowers[bud_index].opened_by_pollination) and int(game.flowers[bud_index].nectar) > 0, "匹配花粉没有打开锁芽")
			expect(int(game.flowers[bud_index].get("stored_nectar", 0)) == 0, "锁芽打开后仍重复计入暂存花蜜")
			expect(game.season_mechanics.can_complete(), "打开锁芽后春季机制仍阻止结算")

	# 夏：只有真实卸蜜才触发；实体逐滴偷取，惊退会归还赃蜜。
	game.spawn_stage(7)
	var summer = game.season_mechanics.mechanic_by_id("conscription")
	expect(summer != null, "夏季机制未启动")
	if summer != null:
		game.season_mechanics.on_home(0, 1.0)
		expect(summer.state == "waiting_for_deposit", "空手停巢错误触发袭扰")
		game.season_mechanics.on_home(3, 0.1)
		expect(summer.state == "active" and not summer.raid_ants.is_empty(), "真实卸蜜没有触发实体袭扰")
		if not summer.raid_ants.is_empty():
			var target_index: int = int(summer.raid_ants[0].target)
			var raider: Dictionary = summer.raid_ants[0]
			raider["position"] = Vector2(game.flowers[target_index].position)
			raider["steal_clock"] = 0.0
			summer.raid_ants[0] = raider
			var nectar_before: int = int(game.flowers[target_index].nectar)
			game.season_mechanics.process(0.1)
			expect(int(game.flowers[target_index].nectar) == nectar_before - 1 and int(summer.raid_ants[0].stolen) == 1, "袭扰者没有偷取真实花蜜")
			raider = summer.raid_ants[0]
			raider["steal_clock"] = 0.0
			summer.raid_ants[0] = raider
			game.season_mechanics.process(0.1)
			expect(String(summer.raid_ants[0].state) == "holding", "袭扰者偷满后仍自行离场，玩家可以等待跳过")
			game.bee.position = Vector2(summer.raid_ants[0].position)
			expect(game.season_mechanics.try_context_action(game.bee.position), "袭扰者旁情境惊退未消费")
			expect(String(summer.raid_ants[0].state) == "escape" and int(game.flowers[target_index].nectar) == nectar_before, "惊退没有让赃蜜回到花田")
			expect(not game.season_mechanics.can_complete(), "只惊退一只袭扰者就提前允许结算")
			for i in summer.raid_ants.size():
				var leaving: Dictionary = summer.raid_ants[i]
				if String(leaving.get("state", "approach")) != "escape":
					leaving["position"] = game.bee.position + Vector2(float(i) * 2.0, 0)
					summer.raid_ants[i] = leaving
			for attempt in summer.raid_ants.size():
				game.season_mechanics.try_context_action(game.bee.position)
			for i in summer.raid_ants.size():
				var leaving: Dictionary = summer.raid_ants[i]
				expect(String(leaving.get("state", "")) == "escape", "仍有袭扰者未被真实惊退")
				leaving["position"] = Vector2(game.WORLD.end.x - 9.0, 300.0)
				summer.raid_ants[i] = leaving
			game.season_mechanics.process(0.2)
			expect(summer.state == "cleared" and game.season_mechanics.can_complete(), "袭扰航线清空后仍不能结算")

	# 秋：停在一滴与采尽产生相反后果。
	game.spawn_stage(13)
	var autumn = game.season_mechanics.mechanic_by_id("reserve")
	expect(autumn != null, "秋季机制未启动")
	if autumn != null:
		var kept: Dictionary = game.flowers[0]
		kept["nectar"] = 1
		game.flowers[0] = kept
		game.season_mechanics.on_harvest(0)
		expect(bool(game.flowers[0].seed_ready), "剩一滴没有形成种核")
		var reserve_before: int = game.hive_reserve
		game.season_mechanics.on_home(2, 0.1)
		expect(bool(game.flowers[0].seeded) and game.hive_reserve == reserve_before + autumn.seed_reward_reserve, "停手归巢没有兑现留种收益")
		expect(game.season_mechanics.can_complete(), "至少一颗种核成熟后仍不能结算")
		var stripped: Dictionary = game.flowers[1]
		stripped["nectar"] = 1
		game.flowers[1] = stripped
		game.season_mechanics.on_harvest(1)
		stripped = game.flowers[1]
		stripped["nectar"] = 0
		game.flowers[1] = stripped
		game.season_mechanics.on_harvest(1)
		var reserve_after_strip: int = game.hive_reserve
		game.season_mechanics.on_home(2, 0.1)
		expect(bool(game.flowers[1].seed_lost) and game.hive_reserve == reserve_after_strip, "采尽后仍错误获得种核收益")

	# 冬：冷区同时掉温、减速；携蜜点亮暖点后两者反转。
	game.spawn_stage(19)
	var winter = game.season_mechanics.mechanic_by_id("huddle")
	expect(winter != null, "冬季机制未启动")
	if winter != null:
		var far_flower: int = winter.flower_route[-1]
		expect(not game.season_mechanics.is_flower_available(far_flower), "未点暖点时远花仍可直接采集")
		# A legal decoy returns its honey as a bloom after the winter route was
		# snapshotted. That dynamic bloom must remain harvestable or repeated
		# decoys can strand every remaining drop behind a permanent lock.
		game.carried = 1
		game.bee.position = Vector2(850, 410)
		game.drop_honey_decoy()
		game.update_decoys(5.1)
		var recovery_index: int = game.flowers.size() - 1
		expect(bool(game.flowers[recovery_index].get("recovery", false)), "诱饵到期没有生成返蜜花")
		expect(game.season_mechanics.is_flower_available(recovery_index), "冬季返蜜花被永久锁在暖路之外")
		game.bee.position = Vector2(500, 250)
		var warmth_before: float = game.warmth
		game.season_mechanics.process(1.0)
		expect(game.warmth < warmth_before and game.bee.environment_speed_multiplier == winter.cold_speed_multiplier, "冷区没有同时掉温和减速")
		game.carried = 3
		game.bee.position = Vector2(winter.warm_points[0].position)
		expect(game.season_mechanics.try_context_action(game.bee.position), "暖点旁情境动作未消费")
		expect(bool(winter.warm_points[0].active) and game.carried == 2, "暖点没有消费一滴携蜜激活")
		expect(not game.season_mechanics.can_complete(), "只点亮一个暖点就提前允许结算")
		game.bee.position = Vector2(winter.warm_points[2].position)
		expect(not game.season_mechanics.try_context_action(game.bee.position), "越过第二暖点直接点亮末端，接力顺序失效")
		game.bee.position = Vector2(winter.warm_points[1].position)
		expect(game.season_mechanics.try_context_action(game.bee.position), "第二暖点无法接续点亮")
		expect(not game.season_mechanics.can_complete(), "只点亮两个暖点就提前允许结算")
		game.bee.position = Vector2(winter.warm_points[2].position)
		expect(game.season_mechanics.try_context_action(game.bee.position), "末端暖点无法在完整接力后点亮")
		expect(game.season_mechanics.can_complete(), "三个暖点全部点亮后仍阻止结算")
		game.bee.position = Vector2(winter.warm_points[0].position)
		game.warmth = 50.0
		var cold_warmth: float = game.warmth
		game.season_mechanics.process(1.0)
		expect(game.warmth > cold_warmth and game.bee.environment_speed_multiplier == 1.0, "暖区没有恢复温暖与正常速度")
		expect(game.season_mechanics.can_complete(), "完整暖链后冬季机制仍阻止结算")

	# 冬季每一关都必须完成三个真实中继；资源预算另由全流程测试覆盖。
	for winter_stage in [19, 20, 21, 22, 23]:
		game.spawn_stage(winter_stage)
		winter = game.season_mechanics.mechanic_by_id("huddle")
		for relay_count in 4:
			winter.activated_points = relay_count
			expect(game.season_mechanics.can_complete() == (relay_count == 3), "冬季节点 %d 的完整暖链接管卡条件错误" % winter_stage)

	expect(not String(game.season_mechanics.hud_status()).is_empty(), "季节机制没有提供短状态")
	game.queue_free()
	await process_frame
	finish()

func finish() -> void:
	if failures.is_empty():
		print("SEASON MECHANICS TEST PASSED: four seasons change route, interruption, restraint and range")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
