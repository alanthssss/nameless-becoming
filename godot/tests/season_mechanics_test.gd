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
		expect(spring.required_open_count() == mini(2, spring.bud_indices.size()), "春季开芽目标没有要求至少两次真实连接")
		var bud_index: int = spring.bud_indices[0]
		expect(spring.visual_state_for_flower(bud_index) == "closed_bud", "锁芽仍没有真实闭芽视觉状态")
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
			expect(int(spring.pollen_charges[required]) > 0, "采花没有在蜂腿留下可用粉团")
			expect(spring.nearest_matching_bud(required, game.bee.position) >= 0, "携粉后没有导向匹配闭芽")
			expect(not game.season_mechanics.is_flower_available(bud_index), "锁芽开放前仍可被普通采集")
			game.bee.position = Vector2(game.flowers[bud_index].position)
			expect(game.season_mechanics.context_action_id(game.bee.position) == "open_pollination_bud", "闭芽附近没有暴露开芽情境动作")
			expect(game.season_mechanics.try_context_action(game.bee.position), "锁芽旁情境动作未消费")
			expect(bool(game.flowers[bud_index].opened_by_pollination) and int(game.flowers[bud_index].nectar) > 0, "匹配花粉没有打开锁芽")
			expect(int(game.flowers[bud_index].get("stored_nectar", 0)) == 0, "锁芽打开后仍重复计入暂存花蜜")
			expect(spring.visual_state_for_flower(bud_index) == "opened_bloom", "开芽后视觉状态没有变成开放花")
			expect(game.season_mechanics.can_complete() == (spring.required_open_count() <= 1), "春季只开一芽就错误完成")
			if spring.required_open_count() > 1:
				var second_bud := -1
				for candidate in spring.bud_indices:
					if bool(game.flowers[candidate].get("locked_bud", false)):
						second_bud = candidate
						break
				expect(second_bud >= 0, "春季找不到第二个闭芽")
				if second_bud >= 0:
					var second_required := int(game.flowers[second_bud].required_pollen)
					for candidate in spring.source_indices:
						if int(game.flowers[candidate].pollen_kind) == second_required:
							game.season_mechanics.on_harvest(candidate)
							break
					game.bee.position = Vector2(game.flowers[second_bud].position)
					expect(game.season_mechanics.try_context_action(game.bee.position), "第二次花粉连接未消费")
					expect(game.season_mechanics.can_complete(), "完成两次花粉连接后仍阻止结算")

	# 夏：只有真实卸蜜才触发；实体逐滴偷取，惊退会归还赃蜜。
	game.spawn_stage(7)
	var summer = game.season_mechanics.mechanic_by_id("conscription")
	expect(summer != null, "夏季机制未启动")
	if summer != null:
		game.season_mechanics.on_home(0, 1.0)
		expect(summer.state == "waiting_for_deposit", "空手停巢错误触发袭扰")
		game.season_mechanics.on_home(3, 0.1)
		expect(summer.state == "active" and not summer.raid_ants.is_empty(), "真实卸蜜没有触发实体袭扰")
		var raid_event: Dictionary = game.season_mechanics.latched_event()
		expect(String(raid_event.id) == "raid_enter" and float(raid_event.remaining) >= 1.5, "袭扰入场事件没有锁存至少1.5秒")
		expect(summer.visual_profile() == "winged_raider", "袭扰者没有独立的大型轮廓")
		if not summer.raid_ants.is_empty():
			var target_index: int = int(summer.raid_ants[0].target)
			var raider: Dictionary = summer.raid_ants[0]
			raider["position"] = Vector2(game.flowers[target_index].position)
			raider["steal_clock"] = 0.0
			summer.raid_ants[0] = raider
			var nectar_before: int = int(game.flowers[target_index].nectar)
			game.season_mechanics.process(0.1)
			expect(int(game.flowers[target_index].nectar) == nectar_before - 1 and int(summer.raid_ants[0].stolen) == 1, "袭扰者没有偷取真实花蜜")
			expect(not summer.transfer_effects.is_empty() and String(summer.transfer_effects[-1].kind) == "stolen", "花蜜被偷时没有可见搬运轨迹")
			raider = summer.raid_ants[0]
			raider["steal_clock"] = 0.0
			summer.raid_ants[0] = raider
			game.season_mechanics.process(0.1)
			expect(String(summer.raid_ants[0].state) == "holding", "袭扰者偷满后仍自行离场，玩家可以等待跳过")
			game.bee.position = Vector2(summer.raid_ants[0].position)
			expect(game.season_mechanics.context_action_id(game.bee.position) == "repel_raider", "袭扰者附近没有暴露惊退情境动作")
			expect(game.season_mechanics.try_context_action(game.bee.position), "袭扰者旁情境惊退未消费")
			expect(String(summer.raid_ants[0].state) == "escape" and int(game.flowers[target_index].nectar) == nectar_before, "惊退没有让赃蜜回到花田")
			expect(not summer.transfer_effects.is_empty() and String(summer.transfer_effects[-1].kind) == "returned", "惊退时没有可见返蜜轨迹")
			var return_event: Dictionary = game.season_mechanics.latched_event()
			expect(String(return_event.id) == "honey_return" and float(return_event.remaining) >= 1.5, "返蜜事件没有锁存至少1.5秒")
			if summer.raid_ants.size() > 1:
				# Every flower may be emptied between theft and repel. The raider must
				# retain a real return target instead of turning the stolen drop into -1.
				for flower_index in game.flowers.size():
					var emptied: Dictionary = game.flowers[flower_index]
					emptied.nectar = 0
					game.flowers[flower_index] = emptied
				var edge_raider: Dictionary = summer.raid_ants[1]
				edge_raider.position = Vector2(700, 400)
				edge_raider.target = 0
				edge_raider.state = "approach"
				edge_raider.stolen = 1
				summer.raid_ants[1] = edge_raider
				game.season_mechanics.process(0.1)
				expect(int(summer.raid_ants[1].target) == 0 and String(summer.raid_ants[1].state) == "holding", "全场采空时袭扰者丢失原返蜜目标")
				game.bee.position = Vector2(summer.raid_ants[1].position)
				expect(game.season_mechanics.try_context_action(game.bee.position), "无新目标的持蜜袭扰者无法被惊退")
				expect(int(game.flowers[0].nectar) == 1 and int(summer.raid_ants[1].stolen) == 0, "全场采空后惊退吞掉了真实花蜜")
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
		expect(int(game.flowers[0].nectar) == 2 and bool(game.flowers[0].get("showcase_seed", false)), "秋季首花没有保持一次采蜜见种核的陈列值")
		var kept: Dictionary = game.flowers[0]
		kept["nectar"] = 1
		game.flowers[0] = kept
		game.season_mechanics.on_harvest(0)
		expect(bool(game.flowers[0].seed_ready), "剩一滴没有形成种核")
		expect(game.season_mechanics.harvest_requires_release(0), "剩一滴后没有要求松开采蜜键")
		expect(autumn.visual_state_for_flower(0) == "ripe_seed_pod", "最后一滴没有切换成明显种荚轮廓")
		game.season_mechanics.notify_harvest_released(0)
		expect(not game.season_mechanics.harvest_requires_release(0) and bool(game.flowers[0].seed_final_armed), "松开后没有解除停采并武装明确的第二次采摘")
		var reserve_before: int = game.hive_reserve
		game.season_mechanics.on_home(2, 0.1)
		expect(bool(game.flowers[0].seeded) and game.hive_reserve == reserve_before + autumn.seed_reward_reserve, "停手归巢没有兑现留种收益")
		expect(autumn.visual_state_for_flower(0) == "mature_seed_head", "留种成熟后没有持久种头轮廓")
		expect(game.season_mechanics.can_complete(), "至少一颗种核成熟后仍不能结算")
		var stripped: Dictionary = game.flowers[1]
		stripped["nectar"] = 1
		game.flowers[1] = stripped
		game.season_mechanics.on_harvest(1)
		expect(game.season_mechanics.harvest_requires_release(1), "第二颗种荚没有暂停当前持续采蜜")
		game.season_mechanics.notify_harvest_released(1)
		stripped = game.flowers[1]
		stripped["nectar"] = 0
		game.flowers[1] = stripped
		game.season_mechanics.on_harvest(1)
		expect(autumn.visual_state_for_flower(1) == "broken_pod", "采尽种核后没有破荚轮廓")
		var reserve_after_strip: int = game.hive_reserve
		game.season_mechanics.on_home(2, 0.1)
		expect(bool(game.flowers[1].seed_lost) and game.hive_reserve == reserve_after_strip, "采尽后仍错误获得种核收益")

	# 冬：冷区同时掉温、减速；携蜜点亮暖点后两者反转。
	game.spawn_stage(19)
	var winter = game.season_mechanics.mechanic_by_id("huddle")
	expect(winter != null, "冬季机制未启动")
	if winter != null:
		game.warmth = 60.0
		game.bee.position = Vector2(game.HIVE_RETURN_POS.x, 220.0)
		game.season_mechanics.process(1.0)
		expect(game.warmth < 60.0, "左侧巢门之外仍被当成冬季暖巢")
		game.bee.position = game.HIVE_RETURN_POS
		var doorway_warmth: float = game.warmth
		game.season_mechanics.process(1.0)
		expect(game.warmth > doorway_warmth, "可见巢门没有恢复体温")
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
		expect(winter.visual_profile() == "wax_lamp_huddle", "暖点仍没有蜂蜡灯/蜂团物象")
		game.bee.position = Vector2(500, 250)
		var warmth_before: float = game.warmth
		game.season_mechanics.process(1.0)
		expect(game.warmth < warmth_before and game.bee.environment_speed_multiplier >= 0.95, "满温出巢仍被立刻施加重度减速")
		game.warmth = 50.0
		game.season_mechanics.process(1.0)
		expect(game.bee.environment_speed_multiplier > winter.cold_speed_multiplier and game.bee.environment_speed_multiplier < 0.95, "温度下降没有渐进改变飞行速度")
		expect(winter.frost_level > 0.0, "降温没有形成可绘制的霜层状态")
		game.warmth = winter.cold_warmth_threshold
		game.season_mechanics.process(0.1)
		expect(is_equal_approx(game.bee.environment_speed_multiplier, winter.cold_speed_multiplier), "低温没有降到配置的最低速度")
		game.carried = 0
		game.bee.position = Vector2(winter.warm_points[0].position)
		expect(game.season_mechanics.context_action_id(game.bee.position) == "warm_relay_needs_honey", "空蜜囊靠近蜂蜡灯时没有暴露燃料状态")
		expect(game.season_mechanics.try_context_action(game.bee.position), "缺蜜暖点没有消费按键，仍会误触寻迹")
		expect(not bool(winter.warm_points[0].active), "没有携蜜却点亮了暖点")
		game.carried = 3
		game.bee.position = Vector2(winter.warm_points[0].position)
		expect(game.season_mechanics.context_action_id(game.bee.position) == "light_warm_relay", "携蜜靠近蜂蜡灯时没有暴露点亮动作")
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
