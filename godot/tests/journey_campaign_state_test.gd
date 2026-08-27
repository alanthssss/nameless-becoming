extends SceneTree

const CampaignStateScript := preload("res://scripts/world/journey_campaign_state.gd")
const CampaignFieldScript := preload("res://scripts/world/journey_campaign_field.gd")
const SoundScript := preload("res://scripts/sound_feedback.gd")
const CampaignScene := preload("res://campaign.tscn")


class RetryableFailingPersistence:
	extends CommercialPersistenceService

	var save_attempts := 0
	var failures_remaining := 1


	func save_journey_state(_journey_state: Object) -> Error:
		save_attempts += 1
		if failures_remaining > 0:
			failures_remaining -= 1
			return ERR_CANT_CREATE
		return OK


var failures: Array[String] = []


func _init() -> void:
	call_deferred("run_test")


func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func completion_payload(state: JourneyCampaignState, token: int, level: Dictionary) -> Dictionary:
	var counts: Array[int] = []
	for objective in level.objectives:
		counts.append(int((objective as Dictionary).goal))
	return {
		"journey_token": token,
		"level_id": String(level.id),
		"objectives_complete": true,
		"returned_home": true,
		"objective_counts": counts,
		"phases_completed": 3 if String(level.kind) == "climax" else 0,
		"elapsed_seconds": float(level.target_minutes) * 60.0,
		"energy_remaining": 180.0,
		"actions": 12,
		"failed": false,
	}


func run_test() -> void:
	var state = CampaignStateScript.new()
	expect(state.is_ready(), "正式战役状态无法加载目录与纪事")
	expect(state.next_segment_id() == "spring_lichun", "空进度没有从立春开始")
	expect(not state.can_begin_level("spring_yushui"), "状态允许跳过立春")
	expect(not state.can_begin_level("spring_lichun", true), "未通关关卡可被伪装成重玩")
	var expected_reserve := 0
	for order in 24:
		var level: Dictionary = state.catalog.level_at(order)
		var token: int = state.begin_level(String(level.id))
		expect(token > 0, "第 %d 关无法按顺序开始" % (order + 1))
		var payload := completion_payload(state, token, level)
		expect(state.can_settle_level(payload), "第 %d 关合法完成结果被拒绝" % (order + 1))
		var settlement := state.settle_level(payload)
		expect(not settlement.is_empty(), "第 %d 关没有结算" % (order + 1))
		expected_reserve += int(level.reward_honey)
		expect(state.completed_count() == order + 1, "第 %d 关没有形成精确进度前缀" % (order + 1))
		expect(state.reserve == expected_reserve, "第 %d 关没有使用目录奖励" % (order + 1))
		expect(state.solar_terms.unlocked_count() == order + 1, "第 %d 关没有 exact-once 纪事" % (order + 1))
		expect(not state.can_settle_level(payload), "第 %d 关重复 token 可再次结算" % (order + 1))
	expect(state.journey_complete and state.next_segment_id().is_empty(), "大寒完成后战役没有完整收束")
	expect(state.world_traces.size() == 24, "24 关没有各留一条世界痕迹")

	var reserve_before_replay: int = int(state.reserve)
	var replay_token: int = state.begin_level("spring_lichun", true)
	var replay_payload := completion_payload(state, replay_token, state.catalog.level_by_id("spring_lichun"))
	replay_payload.elapsed_seconds = 120.0
	var replay_result := state.settle_level(replay_payload)
	expect(bool(replay_result.get("replay", false)), "已完成关卡没有进入重玩结算")
	expect(state.completed_count() == 24 and state.reserve == reserve_before_replay, "重玩复制了进度或储备")
	expect(state.solar_terms.unlocked_count() == 24, "重玩复制了节气纪事")
	expect(is_equal_approx(float(state.best_results.spring_lichun.elapsed_seconds), 120.0), "重玩最好用时没有更新")

	var save_data := state.to_save_dictionary()
	var restored = CampaignStateScript.new()
	expect(restored.restore_from_save_dictionary(save_data) == OK, "v2 正式战役存档无法恢复")
	expect(restored.completed_count() == 24 and restored.reserve == reserve_before_replay, "恢复后进度或资源改变")
	expect(restored.world_traces.size() == 24 and restored.solar_terms.unlocked_count() == 24, "恢复后痕迹或纪事丢失")
	var tampered := save_data.duplicate(true)
	tampered.reserve = int(tampered.reserve) + 1
	expect(CampaignStateScript.new().restore_from_save_dictionary(tampered) == ERR_INVALID_DATA, "篡改储备的战役存档被接纳")
	var skipped := save_data.duplicate(true)
	(skipped.completed_level_ids as Array)[3] = "summer_lixia"
	expect(CampaignStateScript.new().restore_from_save_dictionary(skipped) == ERR_INVALID_DATA, "跳关前缀的战役存档被接纳")

	# Runtime field contracts: standard work uses a map larger than the viewport
	# and at least one real source-to-destination task; climax work owns 3×3
	# concrete substeps rather than one repeated counter.
	var sound := SoundScript.new()
	root.add_child(sound)
	await process_frame
	var runtime_state = CampaignStateScript.new()
	var first_level: Dictionary = runtime_state.catalog.level_at(0)
	var first_token: int = runtime_state.begin_level(String(first_level.id))
	var standard_field = CampaignFieldScript.new()
	expect(standard_field.configure({
		"campaign_mode": true,
		"journey_token": first_token,
		"level": first_level,
		"run_mode": "progression",
		"reserve": 0,
		"sortie_count": 1,
		"world_results": {},
		"sound_feedback": sound,
	}) == OK, "常规关场景配置失败")
	root.add_child(standard_field)
	await process_frame
	expect(
		standard_field.world_bounds.size.x >= 3600.0 and standard_field.world_bounds.size.y >= 2000.0,
		"正式关卡没有保持至少约三屏宽、近三屏高的大地图"
	)
	expect(standard_field.tasks.size() == 8, "立春没有按 2 次授粉 + 6 次收蜜生成实际工作")
	var has_two_step := false
	for task in standard_field.tasks:
		if String(task.type) in standard_field.TWO_STEP_TYPES and Vector2(task.source_position) != Vector2(task.position):
			has_two_step = true
	expect(has_two_step, "常规关没有发现／拾取到对应投递的多步行为")
	var first_collect_index := -1
	for task_index in standard_field.tasks.size():
		if String(standard_field.tasks[task_index].type) == "collect":
			first_collect_index = task_index
			break
	expect(first_collect_index >= 0, "立春没有生成可实际带回的花蜜")
	if first_collect_index >= 0:
		standard_field.bee.position = Vector2(standard_field.tasks[first_collect_index].position)
		standard_field.request_primary_action()
		expect(standard_field.collected_cargo == 1 and standard_field.objective_counts[1] == 0, "花蜜在抵达主巢前就被算成已交目标")
		standard_field.bee.position = standard_field.home_position
		standard_field._deposit_collected_cargo()
		expect(standard_field.collected_cargo == 0 and standard_field.objective_counts[1] == 1, "主巢接货没有把随身花蜜结算到目标")
	var emitted_holder := {"payload": {}}
	standard_field.journey_completed.connect(func(payload: Dictionary): emitted_holder.payload = payload.duplicate(true))
	standard_field.force_complete_for_test()
	await process_frame
	var emitted_payload: Dictionary = emitted_holder.payload
	expect(bool(emitted_payload.get("returned_home", false)) and bool(emitted_payload.get("objectives_complete", false)), "常规关强制自测没有经过返巢完成合同")
	standard_field.queue_free()
	await process_frame

	var climax_state = CampaignStateScript.new()
	for order in 5:
		var prior: Dictionary = climax_state.catalog.level_at(order)
		var prior_token: int = climax_state.begin_level(String(prior.id))
		climax_state.settle_level(completion_payload(climax_state, prior_token, prior))
	var climax_level: Dictionary = climax_state.catalog.level_at(5)
	var climax_token: int = climax_state.begin_level(String(climax_level.id))
	var climax_field = CampaignFieldScript.new()
	expect(climax_field.configure({
		"campaign_mode": true,
		"journey_token": climax_token,
		"level": climax_level,
		"run_mode": "progression",
		"reserve": climax_state.reserve,
		"sortie_count": 6,
		"world_results": climax_state.world_memory(),
		"sound_feedback": sound,
	}) == OK, "季末三段场景配置失败")
	root.add_child(climax_field)
	await process_frame
	expect(climax_field.is_climax and climax_field.tasks.size() == 9, "季末关没有生成三阶段九个具体子任务")
	expect(String(climax_field.status_snapshot().phase_instruction).length() > 12, "季末阶段缺少具体行动说明")
	climax_field.force_complete_for_test()
	await process_frame
	climax_field.queue_free()
	sound.queue_free()
	await process_frame

	expect(CampaignScene != null, "campaign.tscn 无法加载")
	if CampaignScene != null:
		# A PROCESS_MODE_ALWAYS campaign root must not treat an unconsumed gameplay
		# action as a hive departure while the pause/settings overlay owns the screen.
		var pause_game = CampaignScene.instantiate()
		root.add_child(pause_game)
		await process_frame
		pause_game.full_transition_duration = 0.0
		pause_game.transition_duration = 0.0
		pause_game._open_pause_menu(false)
		var paused_hive: Node = pause_game.router.current_area
		var paused_load_count: int = pause_game.router.load_count
		var paused_token: int = pause_game.state.active_token
		var paused_action := InputEventAction.new()
		paused_action.action = &"action"
		paused_action.pressed = true
		pause_game._unhandled_input(paused_action)
		expect(
			pause_game.router.current_area == paused_hive
			and pause_game.router.load_count == paused_load_count
			and pause_game.state.active_token == paused_token
			and pause_game.state.active_level_id.is_empty(),
			"暂停菜单打开时，蜂巢 action 仍在覆盖层后面启动了关卡"
		)
		if pause_game.paused_by_menu:
			pause_game._resume_from_menu()
		pause_game.queue_free()
		await process_frame

		# Force the router's recoverable ERR_BUSY branch after a valid field result.
		# The field/token must remain retryable and the transition curtain must clear.
		var route_failure_game = CampaignScene.instantiate()
		root.add_child(route_failure_game)
		await process_frame
		route_failure_game.full_transition_duration = 0.0
		route_failure_game.transition_duration = 0.0
		var route_failure_level: Dictionary = route_failure_game.state.catalog.level_at(0)
		route_failure_game._begin_level(String(route_failure_level.id), false)
		await process_frame
		var route_failure_field := route_failure_game.router.current_area as JourneyCampaignField
		expect(route_failure_field != null, "返巢故障回归无法建立真实花田场景")
		if route_failure_field != null:
			var route_failure_token: int = route_failure_game.state.active_token
			var route_failure_payload := completion_payload(
				route_failure_game.state,
				route_failure_token,
				route_failure_level
			)
			route_failure_field.completion_emitted = true
			route_failure_field.bee.active = false
			route_failure_game.router.changing = true
			route_failure_game._settle_and_return(route_failure_payload)
			expect(
				route_failure_game.state.active_token == route_failure_token
				and route_failure_game.state.can_settle_level(route_failure_payload)
				and route_failure_game.router.current_area == route_failure_field,
				"返巢路由失败后没有完整保留原花田与合法尝试令牌"
			)
			expect(
				not route_failure_game.transitioning
				and is_zero_approx(route_failure_game.fade.color.a)
				and route_failure_game.fade.mouse_filter == Control.MOUSE_FILTER_IGNORE,
				"返巢路由失败后转场遮罩仍拦截输入"
			)
			expect(
				route_failure_field.input_enabled
				and not route_failure_field.completion_emitted
				and route_failure_field.bee.active,
				"返巢路由失败后原花田没有恢复为可重试状态"
			)
			route_failure_game.router.changing = false
		route_failure_game.queue_free()
		await process_frame

		# Exercise the real host/router/field/hive settlement chain for every level,
		# not just the state ledger. force_complete_for_test skips manual movement but
		# still emits the same field payload and must traverse the real return scene.
		var campaign_game = CampaignScene.instantiate()
		root.add_child(campaign_game)
		await process_frame
		# _ready applies saved accessibility settings, so remove transition time only
		# after the scene is live. This keeps the test deterministic without completing
		# a field while the real router is still inside its departure transition.
		campaign_game.full_transition_duration = 0.0
		campaign_game.transition_duration = 0.0
		for order in JourneyLevelCatalog.TOTAL_LEVELS:
			var routed_level: Dictionary = campaign_game.state.catalog.level_at(order)
			campaign_game._begin_level(String(routed_level.id), false)
			await process_frame
			var routed_field := campaign_game.router.current_area as JourneyCampaignField
			expect(routed_field != null, "第 %d 关没有从主巢切到正式花田场景" % (order + 1))
			if routed_field == null:
				break
			routed_field.force_complete_for_test()
			await process_frame
			await process_frame
			await process_frame
			expect(campaign_game.router.current_area is JourneyCampaignHive, "第 %d 关完成后没有切回主巢" % (order + 1))
			expect(campaign_game.state.completed_count() == order + 1, "第 %d 关真实场景链没有 exact-once 结算" % (order + 1))
		expect(campaign_game.state.journey_complete, "真实场景链走完 24 关后没有进入交棒完成态")
		expect(campaign_game.state.next_level().is_empty(), "真实场景链在大寒之后制造了第 25 关")
		expect(campaign_game.state.solar_terms.unlocked_count() == 24, "真实场景链没有恰好写入 24 条节气纪事")
		campaign_game.queue_free()
		await process_frame

		# A failed checkpoint remains unsaved state. Returning to title must make a
		# fresh checkpoint attempt and, if that also fails, keep the pause surface up
		# with an explicit second-confirmation warning instead of silently leaving.
		var save_failure_game = CampaignScene.instantiate()
		root.add_child(save_failure_game)
		await process_frame
		save_failure_game.full_transition_duration = 0.0
		save_failure_game.transition_duration = 0.0
		var retryable_persistence := RetryableFailingPersistence.new()
		retryable_persistence.failures_remaining = 100
		save_failure_game.persistence = retryable_persistence
		save_failure_game.session_persistence_active = true
		var save_failure_level: Dictionary = save_failure_game.state.catalog.level_at(0)
		save_failure_game._begin_level(String(save_failure_level.id), false)
		await process_frame
		var save_failure_field := save_failure_game.router.current_area as JourneyCampaignField
		expect(save_failure_field != null, "存档失败回归无法建立真实花田场景")
		if save_failure_field != null:
			save_failure_field.force_complete_for_test()
			await process_frame
			await process_frame
			await process_frame
			expect(
				save_failure_game.state.completed_count() == 1
				and retryable_persistence.save_attempts == 1
				and save_failure_game.save_label.text.begins_with("存档失败"),
				"存档失败注入没有形成明确的未保存返巢状态"
			)
			save_failure_game._open_pause_menu(false)
			save_failure_game._return_to_title()
			expect(
				retryable_persistence.save_attempts == 2
				and save_failure_game.paused_by_menu
				and save_failure_game.system_menu.is_open()
				and save_failure_game.unsaved_exit_confirmation == "return_to_title"
				and "再按一次“返回标题”" in save_failure_game.system_menu.pause_note.text,
				"返巢检查点再次写入失败后，返回标题没有停下并给出明确二次确认"
			)
			save_failure_game._resume_from_menu()
		save_failure_game.queue_free()
		await process_frame
		retryable_persistence.free()
	if failures.is_empty():
		print("JOURNEY CAMPAIGN STATE TEST PASSED")
		print("TEST PASSED")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
