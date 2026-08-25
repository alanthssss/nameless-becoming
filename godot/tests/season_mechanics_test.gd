extends SceneTree

const PollenVisualLanguageScript := preload("res://scripts/mechanics/pollen_visual_language.gd")

var failures: Array[String] = []

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func pollen_total(values: Array[int]) -> int:
	var total := 0
	for value in values:
		total += value
	return total

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
		# Random flower selection may initially expose only one visible variant. Add
		# deterministic open flowers until both variants have a donor and receptor so
		# the dual-load truth can be tested without depending on RNG.
		for variant in 2:
			for ensure_attempt in 3:
				var has_variant_donor: bool = spring.donor_indices.any(func(index): return int(game.flowers[index].pollen_variant) == variant)
				var has_variant_receptor: bool = spring.receptive_indices.any(func(index): return int(game.flowers[index].stigma_variant) == variant)
				if has_variant_donor and has_variant_receptor:
					break
				var ensured_index: int = game.flowers.size()
				game.flowers.append({
					"id": 9800 + ensured_index,
					"position": Vector2(720 + ensured_index * 4, 575 - variant * 45),
					"nectar": 2,
					"max_nectar": 2,
					"kind": variant,
					"visual_variant": variant,
					"large_bloom": bool(variant),
					"phase": 0.0,
					"recovery": false,
					"type": "nectar_bloom"
				})
				spring.process(0.0)
		var matching_donor := -1
		var mismatching_donor := -1
		for candidate in spring.donor_indices:
			var candidate_variant := int(game.flowers[candidate].pollen_variant)
			if candidate_variant == required_variant:
				matching_donor = candidate
			elif mismatching_donor < 0:
				mismatching_donor = candidate
		expect(matching_donor >= 0, "柱头找不到同可见花型的花粉")
		expect(mismatching_donor >= 0, "柱头找不到可验证拒绝反馈的异型花粉")
		var nectar_before: int = int(game.flowers[receptive_index].nectar)
		game.bee.position = Vector2(game.flowers[receptive_index].position)
		var empty_charges: Array[int] = spring.pollen_charges.duplicate()
		game.sound.last_cue = ""
		expect(game.season_mechanics.context_action_id(game.bee.position) == "needs_pollen", "零载粉靠近柱头时动作位仍谎称可以传粉")
		game.update_interface()
		expect(game.sense_button.visible and game.sense_button.text == "先取散粉" and game.context_hint_label.text == "蜂身没有散粉", "零载粉动作位没有提前说明先取散粉")
		expect(game.season_mechanics.try_context_action(game.bee.position), "零载粉柱头附近没有消费说明动作")
		expect(String(spring.last_feedback.get("kind", "")) == "empty_load" and int(spring.last_feedback.get("variant", -2)) == -1, "零载粉错误伪造成某种异型散粉")
		expect(game.sound.last_cue != "mismatch" and game.message.contains("没有散粉"), "零载粉错误播放形态不匹配音或给出不真实说明")
		expect(spring.pollen_charges == empty_charges, "零载粉说明动作改变了散粉状态")
		spring.process(0.43)
		if mismatching_donor >= 0:
			game.season_mechanics.on_harvest(mismatching_donor)
			var charges_before_rejection: Array[int] = spring.pollen_charges.duplicate()
			game.sound.last_cue = ""
			expect(game.season_mechanics.try_context_action(game.bee.position), "异花型柱头附近没有消费传粉动作")
			expect(String(spring.last_feedback.get("kind", "")) == "rejection" and int(spring.last_feedback.variant) != required_variant, "异花型尝试没有显示实际携粉弹回")
			expect(game.sound.last_cue == "mismatch", "异花型拒绝没有独立短音")
			expect(spring.pollen_charges == charges_before_rejection, "异花型拒绝错误扣除了散粉")
			expect(not bool(game.flowers[receptive_index].pollinated) and not bool(game.flowers[receptive_index].seed_setting) and int(game.flowers[receptive_index].nectar) == nectar_before, "异花型散粉错误授粉、结籽或改变花蜜")
			var rejected_variant := int(spring.last_feedback.variant)
			var visible_during_rejection: Array[int] = charges_before_rejection.duplicate()
			visible_during_rejection[rejected_variant] -= 1
			expect(game.bee.pollen_loads == visible_during_rejection, "异型散粉飞出时蜂身没有临时少画同一粒，造成展示重复")
			expect(pollen_total(game.bee.pollen_loads) + 1 == pollen_total(spring.pollen_charges), "异型拒绝的蜂身与飞行粒没有保持展示总量守恒")
			var frozen_source := Vector2(spring.feedback_event.source_position)
			var source_local: Vector2 = (frozen_source - Vector2(game.bee.position)).rotated(-float(game.bee.facing))
			expect(absf(source_local.x) > 41.0 or absf(source_local.y) > 30.0, "异型散粉从 82×60 蜂轮廓内部起飞，第一拍会被贴图遮挡")
			expect(spring._rejection_grain_position(spring.feedback_event, 0.0).is_equal_approx(frozen_source), "异型散粉轨迹没有从已知外侧体表锚区连续起飞")
			var outbound_mid: Vector2 = spring._rejection_grain_position(spring.feedback_event, 0.25)
			var outbound_local: Vector2 = (outbound_mid - Vector2(spring.feedback_event.bee_origin)).rotated(-float(spring.feedback_event.bee_facing))
			expect(absf(outbound_local.x) > 41.0 or absf(outbound_local.y) > 30.0, "异型散粉出发到转折的中段重新穿过蜂轮廓")
			spring._clear_feedback_event()
			expect(spring.pollen_charges == charges_before_rejection and game.bee.pollen_loads == charges_before_rejection, "取消异型反馈后没有恢复身体显示，或错误改写权威散粉")
			expect(game.season_mechanics.try_context_action(game.bee.position), "取消后无法重新触发异型拒绝")
			expect(String(spring.feedback_event.get("kind", "")) == "rejection", "重新触发后没有进入异型拒绝")
			var fixed_bee_position := Vector2(game.bee.position)
			game.bee.facing = PI * 0.5
			# Independent geometry: do not call the production exterior-slot helper. The
			# expected endpoint is the load-slot ray intersecting a 41×30 body plus 9px.
			var local_slot: Vector2 = PollenVisualLanguageScript.load_slot(rejected_variant)
			var exterior_half: Vector2 = Vector2(41.0, 30.0) + Vector2.ONE * 9.0
			var exterior_scale: float = minf(exterior_half.x / absf(local_slot.x), exterior_half.y / absf(local_slot.y))
			var expected_return_slot: Vector2 = fixed_bee_position + (local_slot * exterior_scale).rotated(float(game.bee.facing))
			var rejection_end: Vector2 = spring._rejection_grain_position(spring.feedback_event, 1.0)
			expect(game.bee.position == fixed_bee_position and rejection_end.is_equal_approx(expected_return_slot), "只转向不移动时，异型散粉没有回到当前朝向的轮廓外体表锚区")
			expect(spring.pollen_charges == charges_before_rejection and game.bee.pollen_loads == visible_during_rejection, "转向中的弹回改写权威散粉或提前恢复身体重复显示")
			game.bee.position += Vector2(36.0, -18.0)
			for route_progress in [0.0, 0.12, 0.25, 0.5, 0.72, 0.90, 1.0]:
				var moving_route_position: Vector2 = spring._rejection_grain_position(spring.feedback_event, route_progress)
				var moving_route_local: Vector2 = (moving_route_position - Vector2(game.bee.position)).rotated(-float(game.bee.facing))
				expect(absf(moving_route_local.x) > 41.0 or absf(moving_route_local.y) > 30.0, "蜜蜂移动后的拒绝轨迹有一拍重新进入 82×60 蜂轮廓")
			var moved_expected_return_slot: Vector2 = Vector2(game.bee.position) + (local_slot * exterior_scale).rotated(float(game.bee.facing))
			expect(spring._rejection_grain_position(spring.feedback_event, 1.0).is_equal_approx(moved_expected_return_slot), "蜜蜂移动后拒绝回程没有实时追到当前轮廓外体表锚区")
			game.bee.facing = 0.0
			spring.process(0.43)
			expect(spring.feedback_event.is_empty() and game.bee.pollen_loads == charges_before_rejection, "异型拒绝结束后没有准确恢复身体载粉显示")
		if matching_donor >= 0:
			for harvest_repeat in 3:
				game.season_mechanics.on_harvest(matching_donor)
			expect(int(spring.pollen_charges[required_variant]) == 2, "同类松散花粉没有在两份上限准确封顶")
			expect(game.bee.pollen_loads == spring.pollen_charges, "蜂身体表散粉锚区没有逐类精确镜像 0/1/2 份规则状态")
			expect(spring.active_pollen_variants() == [0, 1], "同时携带两类散粉时状态被坍缩成单一 current")
			expect(spring.motif_id_for_variant(0) != spring.motif_id_for_variant(1), "两类散粉仍只靠颜色区分")
			expect(spring.nearest_matching_receptive(required_variant, game.bee.position) >= 0, "携粉后找不到同花型柱头")
			game.bee.sense_time = 3.0
			var sense_targets: Dictionary = spring.matching_sense_targets()
			expect(sense_targets.size() == 2 and game.season_mechanics.sense_focus_active(), "双载粉寻迹没有为两类分别接管同型柱头目标")
			for sensed_variant in sense_targets:
				var sensed_index := int(sense_targets[sensed_variant])
				expect(int(game.flowers[sensed_index].stigma_variant) == int(sensed_variant), "寻迹路线指向了异型柱头")
			expect(game.season_mechanics.context_action_id(game.bee.position) == "deposit_pollen", "柱头附近没有暴露传粉情境动作")
			var required_charge_before := int(spring.pollen_charges[required_variant])
			expect(game.season_mechanics.try_context_action(game.bee.position), "同花型传粉动作未消费")
			expect(bool(game.flowers[receptive_index].pollination_pending) and not bool(game.flowers[receptive_index].pollinated), "散粉起飞时没有进入防重复 pending，或过早结籽")
			expect(int(spring.pollen_charges[required_variant]) == required_charge_before - 1 and game.bee.pollen_loads[required_variant] == required_charge_before - 1, "散粉起飞时身体没有先准确减一")
			expect(String(spring.last_feedback.kind) == "deposit_started" and spring.visual_state_for_flower(receptive_index) == "pollination_pending", "传递起点和 pending 可见状态没有留下诊断证据")
			var charges_during_flight: Array[int] = spring.pollen_charges.duplicate()
			expect(game.season_mechanics.try_context_action(game.bee.position), "飞行中的重复传粉按键没有被安全消费")
			expect(spring.pollen_charges == charges_during_flight and int(spring.pollinated_flowers) == 0 and bool(game.flowers[receptive_index].pollination_pending), "重复按键覆盖了飞行事件、重复扣粉或提前计数")
			spring.process(0.23)
			expect(not bool(game.flowers[receptive_index].pollinated) and int(game.flowers[receptive_index].nectar) == nectar_before, "散粉仍在飞行时过早结籽或改变花蜜")
			spring.process(0.24)
			expect(bool(game.flowers[receptive_index].pollinated) and bool(game.flowers[receptive_index].seed_setting), "同花型散粉落地后没有标记授粉与结籽")
			expect(int(game.flowers[receptive_index].nectar) == nectar_before, "成功授粉改变了柱头花的花蜜")
			expect(String(spring.last_feedback.kind) == "deposit_landed" and game.sound.last_cue == "pollinate", "散粉落地没有独立成功因果与音色")
			expect(spring.visual_state_for_flower(receptive_index) == "seed_setting", "散粉落地后没有切换到可见结籽状态")
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
					expect(bool(game.flowers[second_receptive].pollination_pending) and not spring.can_complete(), "第二粒尚未落地就提前完成春季")
					spring.process(0.47)
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

		# Stage-end cancellation must clear both the transient withheld grain and all
		# spring loads before another seasonal mechanic owns the bee presentation.
		if mismatching_donor >= 0:
			spring.on_harvest(mismatching_donor)
			spring._start_rejection(receptive_index, required_variant)
			expect(String(spring.feedback_event.get("kind", "")) == "rejection" and game.bee.pollen_loads != spring.pollen_charges, "阶段结束用例没有建立飞行中的异型反馈")

	# 夏：只有真实卸蜜才触发；实体逐滴偷取，惊退会归还赃蜜。
	game.spawn_stage(7)
	expect(game.bee.pollen_loads == [0, 0], "春季在异型反馈中结束后没有清空身体载粉显示")
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
