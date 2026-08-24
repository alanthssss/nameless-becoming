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

	# 连环花：路线奖励只能多取该花已有的一滴，不能补回或创造花蜜。
	game.flowers = [
		{"position": Vector2(100, 100), "nectar": 2, "type": "chain_bloom"},
		{"position": Vector2(150, 100), "nectar": 1, "type": "chain_bloom"}
	]
	game.carried = 1
	game.chain_window_s = 2.0
	game.chain_timer = 1.0
	game.chain_last_index = 0
	game.chain_bonus_count = 0
	game.chain_harvest_bonus = 1
	var chain_result: Dictionary = game._apply_chain_route_harvest(game.flowers[1].duplicate(), 1)
	expect(int(chain_result.extra_harvest) == 1 and int(chain_result.flower.nectar) == 0, "连环路线没有从目标花现有库存多采一滴")
	expect(int(chain_result.flower.nectar) + 1 + int(chain_result.extra_harvest) == 2, "连环路线凭空生成或吞掉了花蜜")
	game.carried = 1
	game.chain_timer = 1.0
	game.chain_last_index = 1
	game.chain_bonus_count = 0
	var same_flower_result: Dictionary = game._apply_chain_route_harvest({"position": Vector2(150, 100), "nectar": 1, "type": "chain_bloom"}, 1)
	expect(int(same_flower_result.extra_harvest) == 0 and int(same_flower_result.flower.nectar) == 1, "持续采同一朵花错误触发连环路线奖励")
	game.carried = int(game.carry_capacity) - 1
	game.chain_timer = 1.0
	game.chain_last_index = 0
	game.chain_bonus_count = 0
	var full_crop_result: Dictionary = game._apply_chain_route_harvest({"position": Vector2(150, 100), "nectar": 1, "type": "chain_bloom"}, 1)
	expect(int(full_crop_result.extra_harvest) == 0 and int(full_crop_result.flower.nectar) == 1, "连环路线在蜜囊只剩一格时溢出或吞蜜")

	# 春：开放花的可见变体同时决定花粉兼容；授粉只进入结籽，不回填花蜜。
	game.spawn_stage(0)
	var spring = game.season_mechanics.mechanic_by_id("pollination")
	expect(spring != null, "春季机制未启动")
	if spring != null:
		expect(not spring.donor_indices.is_empty() and not spring.receptive_indices.is_empty(), "春季没有开放花药或可接受柱头")
		expect(spring.required_pollination_count() == mini(2, spring.receptive_indices.size()), "春季结籽目标没有要求两次真实授粉")
		expect(spring.hud_status() == "传粉 0 / 2", "春季状态栏没有常驻显示明确传粉进度")
		expect(game.flowers.all(func(flower): return not flower.has("locked_bud") and not flower.has("stored_nectar") and not flower.has("required_pollen") and not flower.has("pollen_kind")), "春季仍保留锁芽或隐藏索引兼容字段")
		var donor_index: int = spring.donor_indices[0]
		var receptive_index: int = spring.receptive_indices[0]
		var donor: Dictionary = game.flowers[donor_index]
		var receptive: Dictionary = game.flowers[receptive_index]
		expect(bool(donor.has_anthers) and int(donor.pollen_variant) == int(donor.visual_variant), "花药没有由可见花变体决定花粉")
		expect(bool(receptive.receptive_stigma) and int(receptive.stigma_variant) == int(receptive.visual_variant), "柱头没有由可见花变体决定兼容")
		expect(spring.visual_state_for_flower(donor_index) == "donor_anthers" and spring.visual_state_for_flower(receptive_index) == "receptive_stigma", "花药与柱头没有暴露不同视觉状态")
		expect(game.season_mechanics.is_flower_available(donor_index) and game.season_mechanics.is_flower_available(receptive_index), "授粉花没有保持开放可采")
		var required_variant := int(receptive.stigma_variant)
		var filtered: Dictionary = game.flowers[receptive_index]
		filtered["tutorial_locked"] = true
		game.flowers[receptive_index] = filtered
		expect(spring.nearest_matching_receptive(required_variant, Vector2(filtered.position)) != receptive_index, "匹配查询仍指向教学锁定花")
		filtered["tutorial_locked"] = false
		filtered["tutorial_hidden"] = true
		filtered["discovered"] = false
		game.flowers[receptive_index] = filtered
		expect(spring.nearest_matching_receptive(required_variant, Vector2(filtered.position)) != receptive_index, "匹配查询仍指向未发现藏花")
		filtered["tutorial_hidden"] = false
		filtered["discovered"] = true
		game.flowers[receptive_index] = filtered
		var matching_donor := -1
		var mismatching_donor := -1
		for candidate in spring.donor_indices:
			var candidate_variant := int(game.flowers[candidate].pollen_variant)
			if candidate_variant == required_variant:
				matching_donor = candidate
			elif mismatching_donor < 0:
				mismatching_donor = candidate
		expect(matching_donor >= 0, "柱头找不到同可见花型的花粉")
		var nectar_before: int = int(game.flowers[receptive_index].nectar)
		game.bee.position = Vector2(game.flowers[receptive_index].position)
		if mismatching_donor >= 0:
			game.season_mechanics.on_harvest(mismatching_donor)
			expect(game.season_mechanics.try_context_action(game.bee.position), "异花型柱头附近没有消费传粉动作")
			expect(not bool(game.flowers[receptive_index].pollinated) and int(game.flowers[receptive_index].nectar) == nectar_before, "异花型散粉错误授粉或改变花蜜")
		if matching_donor >= 0:
			game.season_mechanics.on_harvest(matching_donor)
			expect(spring.carried_pollen_variant == required_variant and int(spring.pollen_charges[required_variant]) > 0, "采花药没有在蜂身留下可用散粉")
			expect(spring.nearest_matching_receptive(required_variant, game.bee.position) >= 0, "携粉后找不到同花型柱头")
			expect(game.season_mechanics.context_action_id(game.bee.position) == "deposit_pollen", "柱头附近没有暴露传粉情境动作")
			expect(game.season_mechanics.try_context_action(game.bee.position), "同花型传粉动作未消费")
			expect(bool(game.flowers[receptive_index].pollinated) and bool(game.flowers[receptive_index].seed_setting), "同花型散粉没有标记授粉与结籽")
			expect(int(game.flowers[receptive_index].nectar) == nectar_before, "成功授粉改变了柱头花的花蜜")
			expect(spring.visual_state_for_flower(receptive_index) == "seed_setting", "授粉后没有切换到可见结籽状态")
			expect(spring.hud_status() == "传粉 1 / 2", "第一次传粉后状态栏没有更新数字进度")
			expect(game.season_mechanics.can_complete() == (spring.required_pollination_count() <= 1), "春季只授粉一朵就错误完成")
			if spring.required_pollination_count() > 1:
				var second_receptive := -1
				for candidate in spring.receptive_indices:
					if not bool(game.flowers[candidate].pollinated):
						second_receptive = candidate
						break
				expect(second_receptive >= 0, "春季找不到第二个柱头")
				if second_receptive >= 0:
					var second_variant := int(game.flowers[second_receptive].stigma_variant)
					for candidate in spring.donor_indices:
						if int(game.flowers[candidate].pollen_variant) == second_variant:
							game.season_mechanics.on_harvest(candidate)
							break
					var second_nectar_before := int(game.flowers[second_receptive].nectar)
					game.bee.position = Vector2(game.flowers[second_receptive].position)
					expect(game.season_mechanics.try_context_action(game.bee.position), "第二次开花传粉未消费")
					expect(int(game.flowers[second_receptive].nectar) == second_nectar_before, "第二次授粉产生了花蜜")
					expect(game.season_mechanics.can_complete(), "两朵花进入结籽后仍阻止结算")
		var completed_pollinations := int(spring.pollinated_flowers)
		spring.pollinated_flowers = spring.required_pollination_count() + 1
		expect(spring.hud_status() == "传粉 2 / 2", "额外传粉让状态栏显示超过目标的 3 / 2")
		spring.pollinated_flowers = completed_pollinations
		var spent_donor: Dictionary = game.flowers[donor_index]
		var donor_nectar_before := int(spent_donor.nectar)
		spent_donor["nectar"] = 0
		game.flowers[donor_index] = spent_donor
		expect(spring.visual_state_for_flower(donor_index) == "spent_donor", "采空花仍显示可供粉花药")
		spent_donor["nectar"] = donor_nectar_before
		game.flowers[donor_index] = spent_donor
		for dynamic_spec in [
			{"visual_variant": 0, "mentor_practice": true, "recovery": false},
			{"visual_variant": 1, "mentor_practice": false, "recovery": true}
		]:
			var dynamic_index: int = int(game.flowers.size())
			game.flowers.append({
				"id": 9900 + dynamic_index,
				"position": Vector2(700 + dynamic_index * 3, 600),
				"nectar": 1,
				"max_nectar": 1,
				"kind": 0,
				"visual_variant": int(dynamic_spec.visual_variant),
				"large_bloom": bool(dynamic_spec.visual_variant),
				"phase": 0.0,
				"recovery": bool(dynamic_spec.recovery),
				"mentor_practice": bool(dynamic_spec.mentor_practice),
				"type": "nectar_bloom"
			})
			spring.process(0.0)
			var dynamic_flower: Dictionary = game.flowers[dynamic_index]
			var has_role: bool = bool(dynamic_flower.has_anthers) != bool(dynamic_flower.receptive_stigma)
			var role_variant: int = int(dynamic_flower.pollen_variant) if bool(dynamic_flower.has_anthers) else int(dynamic_flower.stigma_variant)
			expect(has_role and role_variant == int(dynamic_flower.visual_variant), "后加教学/返蜜花没有按可见变体注册传粉角色")
			expect(spring.donor_indices.has(dynamic_index) or spring.receptive_indices.has(dynamic_index), "后加花没有进入传粉查询")
			expect(spring.visual_state_for_flower(dynamic_index) in ["donor_anthers", "receptive_stigma"], "后加花没有对应的可见花心")

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
