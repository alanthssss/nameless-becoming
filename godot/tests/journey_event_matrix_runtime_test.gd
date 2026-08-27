extends SceneTree

const CatalogScript := preload("res://scripts/world/journey_level_catalog.gd")
const EventRuntimeScript := preload("res://scripts/world/journey_event_matrix_runtime.gd")
const CampaignFieldScript := preload("res://scripts/world/journey_campaign_field.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("run_test")


func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func complete_current(runtime: JourneyEventMatrixRuntime, accept_optional := true) -> Dictionary:
	if runtime.optional_pending():
		if not accept_optional:
			return runtime.skip_optional()
		runtime.accept_optional()
	if runtime.choice_pending():
		runtime.choose_route("steady")
	var result := {}
	var event_id := String(runtime.current_event().get("id", ""))
	while not runtime.is_finished() and String(runtime.current_event().get("id", "")) == event_id:
		if runtime.requires_evade():
			runtime.note_evade()
		result = runtime.record_step(runtime.current_kind())
		if not bool(result.get("accepted", false)):
			break
	return result


func exercise_runtime(level: Dictionary, expected_optional: int) -> void:
	var runtime = EventRuntimeScript.new()
	expect(runtime.configure(level.get("event_matrix", [])) == OK, "%s 的 15 项矩阵不能建立运行时" % String(level.id))
	expect(runtime.event_count() == 15, "%s 运行时没有真实加载 15 项" % String(level.id))
	expect(runtime.mandatory_total() + runtime.optional_total() == 15, "%s 主线／自选合同不覆盖全部项目" % String(level.id))
	expect(runtime.optional_total() == expected_optional, "%s 自选项数量在运行时改变" % String(level.id))
	expect(not bool(runtime.skip_optional().get("accepted", false)), "%s 允许略过第一项主线" % String(level.id))
	var previous_pentad := 1
	var optional_rewards: Array[float] = []
	while not runtime.is_finished():
		var pentad := runtime.current_pentad()
		expect(pentad >= previous_pentad and pentad <= previous_pentad + 1, "%s 没有按三候顺序推进" % String(level.id))
		previous_pentad = pentad
		var was_optional := bool(runtime.current_event().get("optional", false))
		var mechanic_before := runtime.current_mechanic()
		var support_before: int = runtime.support_points
		var result := complete_current(runtime, true)
		expect(bool(result.get("accepted", false)), "%s 的 %s 无法按 mechanic 合同推进" % [String(level.id), runtime.current_mechanic()])
		if was_optional:
			var expected_reward := float(EventRuntimeScript.OPTIONAL_ENERGY_REWARDS.get(mechanic_before, 4.0))
			optional_rewards.append(float(result.get("energy_reward", -1.0)))
			expect(
				is_equal_approx(float(result.get("energy_reward", -1.0)), expected_reward)
				and runtime.support_points == support_before + 1,
				"%s 自选项没有按具体工作兑现差异奖励与支援" % String(level.id)
			)
	expect(runtime.can_finish(), "%s 完成 15 项后仍不能正式收束" % String(level.id))
	expect(runtime.completed_mandatory_ids.size() == runtime.mandatory_total(), "%s 没有完成全部主线" % String(level.id))
	expect(runtime.completed_optional_ids.size() == expected_optional, "%s 做完的自选项没有形成支援" % String(level.id))
	expect(runtime.support_points == expected_optional, "%s 自选支援没有真实累积" % String(level.id))
	var distinct_rewards := {}
	for reward in optional_rewards:
		distinct_rewards[reward] = true
	expect(distinct_rewards.size() >= 3, "%s 自选项仍退化成同一种体力奖励" % String(level.id))
	expect(runtime.hazard_scale() < 1.0, "%s 自选支援没有影响后续天气强度" % String(level.id))
	expect(bool(runtime.world_state.get("setpiece_complete", false)), "%s 最终蜂流 setpiece 没有留下世界结果" % String(level.id))
	expect(int(runtime.world_state.get("bloom_stage", 0)) == 3, "%s 最终结果没有进入可见花期状态" % String(level.id))


func verify_mechanic_grammars(yushui: Dictionary, guyu: Dictionary) -> void:
	var runtime = EventRuntimeScript.new()
	runtime.configure(yushui.get("event_matrix", []))
	var expected_yushui := [
		["weather_window", EventRuntimeScript.KIND_OBSERVATION],
		["stabilize_lane", EventRuntimeScript.KIND_ROUTE],
		["coop_anchor", EventRuntimeScript.KIND_COOP_ANCHOR],
		["pollen_delivery", EventRuntimeScript.KIND_CARGO],
	]
	for contract in expected_yushui:
		var mechanic := String(contract[0])
		var found := false
		for event in runtime.events:
			if String(event.get("mechanic", "")) == mechanic:
				found = true
				expect(String(event.get("runtime_kind", "")) == String(contract[1]), "%s 没有驱动独立任务状态" % mechanic)
		expect(found, "雨水运行时缺少 %s" % mechanic)
	runtime.configure(guyu.get("event_matrix", []))
	var expected_guyu := [
		["air_catch", EventRuntimeScript.KIND_AIR_CATCH],
		["support_choice", EventRuntimeScript.KIND_ROUTE_CHOICE],
		["convoy_anchor", EventRuntimeScript.KIND_COOP_ANCHOR],
		["convoy_setpiece", EventRuntimeScript.KIND_CONVOY],
	]
	for contract in expected_guyu:
		var mechanic := String(contract[0])
		var found := false
		for event in runtime.events:
			if String(event.get("mechanic", "")) == mechanic:
				found = true
				expect(String(event.get("runtime_kind", "")) == String(contract[1]), "%s 没有驱动独立任务状态" % mechanic)
		expect(found, "谷雨运行时缺少 %s" % mechanic)


func verify_optional_skip(level: Dictionary) -> void:
	var runtime = EventRuntimeScript.new()
	runtime.configure(level.get("event_matrix", []))
	while not runtime.is_finished() and not runtime.optional_pending():
		complete_current(runtime)
	var optional_id := String(runtime.current_event().get("id", ""))
	var skip_result := runtime.skip_optional()
	expect(bool(skip_result.get("accepted", false)), "自选项无法在本候选择略过")
	expect(optional_id in runtime.skipped_optional_ids, "略过的自选项没有记录合同结果")
	expect(runtime.support_points == 0, "略过自选项却凭空获得了支援")
	expect(not runtime.is_finished(), "略过一项自选错误地结束了整个关卡")


func verify_authored_choices_and_causality(yushui: Dictionary, guyu: Dictionary) -> void:
	var choice_count := 0
	for level in [yushui, guyu]:
		var runtime = EventRuntimeScript.new()
		expect(runtime.configure(level.get("event_matrix", [])) == OK, "选择合同测试无法建立 %s" % String(level.id))
		while not runtime.is_finished():
			var event := runtime.current_event()
			var has_authored_choice := not (event.get("choice_options", {}) as Dictionary).is_empty()
			if runtime.optional_pending():
				runtime.accept_optional()
			expect(runtime.choice_pending() == has_authored_choice, "%s 的选择文案与可玩状态不一致" % String(event.id))
			if has_authored_choice:
				choice_count += 1
				var options := event.choice_options as Dictionary
				expect(
					runtime.choice_label("swift") == String((options.swift as Dictionary).label)
					and runtime.choice_label("steady") == String((options.steady as Dictionary).label),
					"%s 的两种做法没有进入按钮合同" % String(event.id)
				)
				expect(runtime.choose_route("steady"), "%s 的稳妥做法无法被选择" % String(event.id))
				var expected_steps := int((options.steady as Dictionary).steps)
				if (
					String(event.id) == "guyu_12_air_chase"
					and int((runtime.world_state.get("support_effects", {}) as Dictionary).get("spare_sign", 0)) > 0
				):
					expected_steps -= 1
				expect(
					runtime.current_required_steps() == expected_steps,
					"%s 的选择没有改变实际步骤" % String(event.id)
				)
			var result := {}
			var event_id := String(event.id)
			while not runtime.is_finished() and String(runtime.current_event().get("id", "")) == event_id:
				if runtime.requires_evade():
					runtime.note_evade()
				result = runtime.record_step(runtime.current_kind())
			expect(bool(result.get("event_complete", false)), "%s 选择后无法完整执行" % event_id)
			var outcome := (runtime.world_state.get("event_outcomes", {}) as Dictionary).get(event_id, {}) as Dictionary
			expect(String(outcome.get("consequence", "")) == String(event.consequence), "%s 的剧情后果仍是死数据" % event_id)
			if has_authored_choice:
				expect(String(outcome.get("choice_effect", "")).length() > 0, "%s 的做法没有留下结果" % event_id)
	expect(choice_count == 12, "首批内容应恰好有 12 个真实二选一，而不是 30 个假选择")

	var rain_runtime = EventRuntimeScript.new()
	rain_runtime.configure(yushui.get("event_matrix", []))
	while not rain_runtime.is_finished() and rain_runtime.current_index < 9:
		var skip_pollen := String(rain_runtime.current_event().get("id", "")) == "yushui_04_pollen_rainline"
		complete_current(rain_runtime, not skip_pollen)
	expect(
		int(rain_runtime.world_state.get("pollination_deliveries", 0)) == 0
		and int(rain_runtime.world_state.get("bloom_stage", 0)) == 0,
		"雨水在没有完成任何传粉投递时提前开花"
	)
	complete_current(rain_runtime, true)
	expect(
		int(rain_runtime.world_state.get("pollination_deliveries", 0)) == 1
		and int(rain_runtime.world_state.get("bloom_stage", 0)) >= 1,
		"雨水的必要移动投粉没有形成开花因果"
	)

	var traced_pollen_runtime = EventRuntimeScript.new()
	traced_pollen_runtime.configure(yushui.get("event_matrix", []))
	while traced_pollen_runtime.current_index < 4:
		complete_current(traced_pollen_runtime, true)
	expect(
		int(traced_pollen_runtime.world_state.get("pollination_deliveries", 0)) == 1
		and int(traced_pollen_runtime.world_state.get("bloom_stage", 0)) == 0,
		"第一候投粉后没有等待第三候雨窗修复就提前画出花朵"
	)


func advance_runtime_to_event(runtime: JourneyEventMatrixRuntime, event_id: String, skipped_id := "") -> bool:
	while not runtime.is_finished() and String(runtime.current_event().get("id", "")) != event_id:
		var current_id := String(runtime.current_event().get("id", ""))
		var result := complete_current(runtime, current_id != skipped_id)
		if not bool(result.get("accepted", false)):
			return false
	return not runtime.is_finished() and String(runtime.current_event().get("id", "")) == event_id


func verify_evade_and_support_contracts(guyu: Dictionary) -> void:
	var evade_runtime = EventRuntimeScript.new()
	evade_runtime.configure(guyu.get("event_matrix", []))
	expect(advance_runtime_to_event(evade_runtime, "guyu_02_wind_review"), "无法抵达谷雨逐风口急转复习")
	evade_runtime.note_evade()
	var first_gate: Dictionary = evade_runtime.record_step(evade_runtime.current_kind())
	var leaked_gate: Dictionary = evade_runtime.record_step(evade_runtime.current_kind())
	expect(
		bool(first_gate.get("accepted", false))
		and not bool(first_gate.get("event_complete", false))
		and bool(leaked_gate.get("needs_evade", false)),
		"一次急转仍然授权了谷雨 02 的全部风口"
	)
	evade_runtime.note_evade()
	expect(
		bool(evade_runtime.record_step(evade_runtime.current_kind()).get("event_complete", false)),
		"第二个风口重新急转后仍无法完成"
	)

	var with_spare = EventRuntimeScript.new()
	with_spare.configure(guyu.get("event_matrix", []))
	expect(advance_runtime_to_event(with_spare, "guyu_12_air_chase"), "无法抵达带备用牌的空中追牌")
	with_spare.choose_route("swift")
	var with_spare_steps := with_spare.current_required_steps()
	var without_spare = EventRuntimeScript.new()
	without_spare.configure(guyu.get("event_matrix", []))
	expect(
		advance_runtime_to_event(without_spare, "guyu_12_air_chase", "guyu_07_puddle_spare"),
		"无法抵达略过备用牌的空中追牌"
	)
	without_spare.choose_route("swift")
	expect(
		with_spare_steps == 2 and without_spare.current_required_steps() == 3,
		"水洼旧牌没有兑现为一次真实接牌容错"
	)


func verify_pentad_checkpoint(level: Dictionary) -> void:
	var runtime = EventRuntimeScript.new()
	expect(runtime.configure(level.get("event_matrix", [])) == OK, "候级检查点测试无法建立运行时")
	expect(runtime.checkpoint_snapshot().is_empty(), "尚未完成一候就生成了检查点")

	# 第一候故意同时留下主线完成、自选完成与自选略过，确保恢复不是
	# 只把 current_index 粗暴地跳到第六项。
	for event_offset in EventRuntimeScript.EVENTS_PER_PENTAD:
		var result := {}
		if event_offset == 3:
			expect(runtime.optional_pending(), "第一候第四项应当允许测试自选略过")
			result = runtime.skip_optional()
		else:
			result = complete_current(runtime, true)
		expect(bool(result.get("accepted", false)), "第一候第 %d 项无法写入检查点履历" % (event_offset + 1))
		if event_offset < EventRuntimeScript.EVENTS_PER_PENTAD - 1:
			expect(runtime.checkpoint_snapshot().is_empty(), "第一候尚未完整结束就生成了检查点")

	var checkpoint: Dictionary = runtime.checkpoint_snapshot()
	expect(not checkpoint.is_empty(), "完成五项后没有在整候边界生成检查点")
	expect(int(checkpoint.get("next_event_number", 0)) == 6, "第一候检查点没有指向第六项")
	expect(int(checkpoint.get("pentads_completed", 0)) == 1, "第一候检查点的候数不正确")
	expect((checkpoint.get("completed_mandatory_ids", []) as Array).size() == 3, "第一候主线完成数组不完整")
	expect((checkpoint.get("completed_optional_ids", []) as Array).size() == 1, "第一候自选完成数组不完整")
	expect((checkpoint.get("skipped_optional_ids", []) as Array).size() == 1, "第一候自选略过数组不完整")

	var restored = EventRuntimeScript.new()
	expect(restored.configure(level.get("event_matrix", [])) == OK, "恢复目标无法建立运行时")
	expect(restored.restore_checkpoint(checkpoint) == OK, "合法整候检查点不能恢复")
	expect(restored.checkpoint_snapshot() == checkpoint, "恢复后重新生成的检查点并非全字段一致")
	expect(restored.snapshot() == runtime.snapshot(), "恢复后的完整运行时状态与原状态不一致")

	var tampered_world := checkpoint.duplicate(true)
	var tampered_world_state := tampered_world.get("world_state", {}) as Dictionary
	tampered_world_state["observed_signals"] = int(tampered_world_state.get("observed_signals", 0)) + 1
	var world_reject = EventRuntimeScript.new()
	world_reject.configure(level.get("event_matrix", []))
	expect(world_reject.restore_checkpoint(tampered_world) == ERR_INVALID_DATA, "篡改 world_state 的检查点仍被接受")
	expect(
		world_reject.current_index == 0 and world_reject.current_progress == 0,
		"拒绝篡改检查点后留下了半重放的脏运行时"
	)

	var tampered_pentad := checkpoint.duplicate(true)
	tampered_pentad["pentads_completed"] = 2
	var pentad_reject = EventRuntimeScript.new()
	pentad_reject.configure(level.get("event_matrix", []))
	expect(
		pentad_reject.restore_checkpoint(tampered_pentad) == ERR_INVALID_DATA,
		"事件号与候数互相矛盾的检查点仍被接受"
	)
	var fractional_number := checkpoint.duplicate(true)
	fractional_number["next_event_number"] = 6.5
	var fraction_reject = EventRuntimeScript.new()
	fraction_reject.configure(level.get("event_matrix", []))
	expect(
		fraction_reject.restore_checkpoint(fractional_number) == ERR_INVALID_DATA,
		"非整数事件号被宽松截断成合法检查点"
	)

	for array_key in ["completed_mandatory_ids", "completed_optional_ids", "skipped_optional_ids"]:
		var tampered_array := checkpoint.duplicate(true)
		(tampered_array.get(array_key, []) as Array).append("tampered_event_id")
		var array_reject = EventRuntimeScript.new()
		array_reject.configure(level.get("event_matrix", []))
		expect(
			array_reject.restore_checkpoint(tampered_array) == ERR_INVALID_DATA,
			"篡改 %s 的检查点仍被接受" % array_key
		)

	var partial_result: Dictionary = runtime.record_step(runtime.current_kind())
	expect(bool(partial_result.get("accepted", false)), "无法进入第二候的非边界状态")
	expect(runtime.current_progress > 0, "第二候的部分进度没有被记录")
	expect(runtime.checkpoint_snapshot().is_empty(), "进入下一候的半项进度后仍生成了整候检查点")


func advance_field_to_mechanic(field: JourneyCampaignField, mechanic: String) -> bool:
	while not field.event_runtime.is_finished() and field.event_runtime.current_mechanic() != mechanic:
		var result := complete_current(field.event_runtime, true)
		if not bool(result.get("accepted", false)):
			return false
	field._prepare_current_event()
	return not field.event_runtime.is_finished() and field.event_runtime.current_mechanic() == mechanic


func advance_field_to_event(field: JourneyCampaignField, event_id: String) -> bool:
	while not field.event_runtime.is_finished() and String(field.event_runtime.current_event().get("id", "")) != event_id:
		var result := complete_current(field.event_runtime, true)
		if not bool(result.get("accepted", false)):
			return false
	field._prepare_current_event()
	return (
		not field.event_runtime.is_finished()
		and String(field.event_runtime.current_event().get("id", "")) == event_id
	)


func configured_field(level: Dictionary, token: int, checkpoint := {}) -> JourneyCampaignField:
	var field = CampaignFieldScript.new()
	var context := {
		"campaign_mode": true,
		"journey_token": token,
		"level": level,
		"run_mode": "progression",
		"reserve": 0,
		"sortie_count": 1,
		"world_results": {},
	}
	if checkpoint is Dictionary and not (checkpoint as Dictionary).is_empty():
		context["event_checkpoint"] = (checkpoint as Dictionary).duplicate(true)
	if field.configure(context) != OK:
		return null
	root.add_child(field)
	return field


func resolve_current_field_event(field: JourneyCampaignField, skip_optional := false) -> bool:
	if field == null or field.event_runtime == null or field.event_runtime.is_finished():
		return false
	var runtime := field.event_runtime
	var starting_index := runtime.current_index
	if runtime.optional_pending():
		if skip_optional:
			field.request_secondary_action()
			return runtime.current_index == starting_index + 1
		field.request_primary_action()
	if runtime.choice_pending():
		field._select_event_route("steady")
	var event_id := String(runtime.current_event().get("id", ""))
	var guard := 0
	while (
		not runtime.is_finished()
		and String(runtime.current_event().get("id", "")) == event_id
		and guard < 16
	):
		guard += 1
		if runtime.requires_evade():
			runtime.note_evade()
		var completed_at := field._current_event_point()
		var result := runtime.record_step(runtime.current_kind())
		if not bool(result.get("accepted", false)):
			return false
		field._handle_event_step_result(result, completed_at)
	return runtime.current_index == starting_index + 1


func verify_field_checkpoint_signal(level: Dictionary) -> void:
	var field := configured_field(level, 603)
	expect(field != null, "候级信号测试无法建立真实雨水花田")
	if field == null:
		return
	var emitted_checkpoints: Array[Dictionary] = []
	field.event_checkpoint_reached.connect(
		func(checkpoint: Dictionary): emitted_checkpoints.append(checkpoint.duplicate(true))
	)
	for event_offset in EventRuntimeScript.EVENTS_PER_PENTAD - 1:
		var should_skip := event_offset == 3
		expect(
			resolve_current_field_event(field, should_skip),
			"Field 无法通过第 %d 项抵达候级边界" % (event_offset + 1)
		)
		expect(emitted_checkpoints.is_empty(), "Field 在五项收齐前提前发出了候级信号")

	# Freeze recognizable live values immediately before the boundary.  The signal
	# must carry these values, rather than defaults or a stale state-layer copy.
	field.bee.energy = 67.25
	field.elapsed = field.time_limit_seconds - 0.05
	field.weather_window_elapsed = field.time_limit_seconds - 0.05
	field.action_count = 19
	expect(resolve_current_field_event(field), "Field 无法完成第一候最后一项")
	expect(emitted_checkpoints.size() == 1, "整候边界没有恰好发出一次 checkpoint 信号")
	if emitted_checkpoints.size() == 1:
		var emitted: Dictionary = emitted_checkpoints[0]
		var runtime_checkpoint := field.event_runtime.checkpoint_snapshot()
		expect(
			String(emitted.get("level_id", "")) == String(level.get("id", ""))
			and int(emitted.get("next_event_number", 0)) == 6
			and int(emitted.get("pentads_completed", 0)) == 1,
			"候级信号没有标明当前关卡与第 6 项续接边界"
		)
		expect(
			is_equal_approx(float(emitted.get("energy", -1.0)), 67.25)
			and is_equal_approx(float(emitted.get("elapsed_seconds", -1.0)), field.time_limit_seconds - 0.05)
			and int(emitted.get("actions", -1)) == 19,
			"候级信号没有携带边界瞬间的体力、用时与行动数"
		)
		expect(
			field._runtime_checkpoint_payload(emitted) == runtime_checkpoint,
			"候级信号的事件履历与边界 runtime 快照不一致"
		)
		expect(is_zero_approx(field.weather_window_elapsed), "整候保存后没有获得新的天气窗口")
		var resumed := configured_field(level, 604, emitted)
		expect(resumed != null, "临界累计用时的合法候档无法重新建场")
		if resumed != null:
			expect(
				is_equal_approx(resumed.elapsed, float(emitted.elapsed_seconds))
				and is_zero_approx(resumed.weather_window_elapsed),
				"候档没有同时保留累计成绩时间与刷新天气窗口"
			)
			resumed._process_chapter(0.25)
			expect(not resumed.failed, "临界累计用时的候档恢复后一帧必败")
			resumed.queue_free()
			await process_frame
	field.queue_free()
	await process_frame


func verify_field_mechanic_fidelity(yushui: Dictionary, guyu: Dictionary) -> void:
	var rain_field := configured_field(yushui, 601)
	expect(rain_field != null, "雨水 mechanic 实景测试无法建场")
	if rain_field == null:
		return
	await process_frame
	rain_field.bee.position = rain_field._current_event_point()
	rain_field.bee.velocity = Vector2.ZERO
	rain_field.hazard_active = true
	rain_field._select_event_route("steady")
	rain_field.request_primary_action()
	expect(not rain_field.event_observing, "weather_window 在雨线压住时仍可站圈完成")
	rain_field.hazard_active = false
	rain_field.request_primary_action()
	expect(rain_field.event_observing, "weather_window 在安全雨隙没有开始观察")

	expect(advance_field_to_mechanic(rain_field, "rhythm_lane"), "无法走到三滴一空节拍门")
	rain_field.bee.position = rain_field._current_event_point()
	rain_field.elapsed = 0.10
	var rhythm_before: int = rain_field.event_runtime.current_progress
	rain_field.request_primary_action()
	expect(rain_field.event_runtime.current_progress == rhythm_before, "rhythm_lane 在错误拍点仍推进")
	rain_field.elapsed = 0.0
	while not rain_field._event_rhythm_window_open():
		rain_field.elapsed += 0.05
	rain_field.request_primary_action()
	expect(rain_field.event_runtime.current_progress == rhythm_before + 1, "rhythm_lane 在开放拍点没有推进")

	expect(advance_field_to_mechanic(rain_field, "moving_shelter"), "无法走到移动雨窗")
	expect(
		rain_field._event_navigation_target().distance_to(rain_field.event_source_position) < 0.01,
		"moving_shelter 未取花粉时没有先指向真实货源"
	)
	rain_field.bee.position = rain_field.event_source_position
	rain_field.request_primary_action()
	rain_field._process_event_matrix(0.1)
	expect(
		rain_field.event_carrying
		and rain_field._event_navigation_target().distance_to(rain_field.event_dynamic_position) < 0.01,
		"moving_shelter 携粉后没有追随真实移动雨窗"
	)

	expect(advance_field_to_mechanic(rain_field, "load_choice"), "无法走到轻重载选择")
	rain_field.request_primary_action()
	expect(
		rain_field.event_runtime.choice_effect() == "heavy_single"
		and rain_field.event_runtime.current_required_steps() == 1
		and rain_field.bee.load_speed_multiplier < 0.75,
		"一趟重载没有形成独立步数与操控代价"
	)

	var energy_before_axis := rain_field.bee.energy
	var axis_event := InputEventJoypadMotion.new()
	axis_event.axis = JOY_AXIS_LEFT_X
	axis_event.axis_value = 0.82
	rain_field._unhandled_input(axis_event)
	axis_event.axis_value = 0.86
	rain_field._unhandled_input(axis_event)
	expect(is_equal_approx(rain_field.bee.energy, energy_before_axis), "摇杆持续轴事件被误判为方向双击")
	axis_event.axis_value = 0.0
	rain_field._unhandled_input(axis_event)
	rain_field.queue_free()
	await process_frame

	var sign_field := configured_field(guyu, 602)
	expect(sign_field != null, "谷雨 mechanic 实景测试无法建场")
	if sign_field == null:
		return
	await process_frame
	expect(advance_field_to_mechanic(sign_field, "heavy_carry"), "无法走到宽牌重载")
	sign_field.bee.position = sign_field.event_source_position
	sign_field.request_primary_action()
	expect(
		sign_field.event_carrying
		and sign_field.bee.load_speed_multiplier == sign_field.EVENT_HEAVY_SPEED_SCALE
		and sign_field.bee.load_acceleration_multiplier == sign_field.EVENT_HEAVY_ACCELERATION_SCALE,
		"heavy_carry 只换贴图，没有改变速度与转向响应"
	)
	sign_field.bee.position = sign_field._current_event_point()
	sign_field.request_primary_action()
	expect(
		not sign_field.event_carrying and sign_field.bee.load_speed_multiplier == 1.0,
		"宽牌交接后没有恢复普通操控"
	)

	expect(advance_field_to_mechanic(sign_field, "moving_match"), "无法走到不停飞核对")
	expect(
		sign_field._moving_match_sequence() == [2, 1, 0],
		"谷雨 03 选择的按路线盘点没有改变谷雨 13 的实际核对顺序"
	)
	var required_shape := sign_field._moving_match_required_shape()
	var wrong_shape := (required_shape + 1) % 3
	var energy_before_wrong := sign_field.bee.energy
	sign_field.bee.position = sign_field._moving_match_source_position(wrong_shape)
	sign_field.request_primary_action()
	expect(
		not sign_field.event_carrying
		and is_equal_approx(
			sign_field.bee.energy,
			energy_before_wrong - sign_field.EVENT_WRONG_MATCH_ENERGY_COST
		),
		"不停飞核对拿错牌没有被识别或没有形成轻微代价"
	)
	sign_field.bee.position = sign_field._moving_match_source_position(required_shape)
	sign_field.request_primary_action()
	sign_field.elapsed = 4.0
	sign_field._process_event_matrix(0.1)
	expect(
		sign_field.event_carrying
		and sign_field.event_carried_shape == required_shape
		and sign_field._event_navigation_target().distance_to(sign_field.event_dynamic_position) < 0.01,
		"moving_match 没有拿起正确牌形并继续追移动工位"
	)
	sign_field.queue_free()
	await process_frame

	var evade_field := configured_field(guyu, 617)
	await process_frame
	expect(advance_field_to_event(evade_field, "guyu_02_wind_review"), "无法抵达急转空间门测试")
	evade_field.bee.position = evade_field.home_position
	evade_field._play_evade_result({"evade_started": true})
	expect(not evade_field.event_runtime.evade_registered, "远离风口的普通急转被缓存成任务通行证")
	evade_field.bee.position = evade_field._current_event_point()
	evade_field._play_evade_result({"evade_started": true})
	expect(
		evade_field.event_runtime.current_progress == 1
		and not evade_field.event_runtime.evade_registered,
		"风口内急转没有推进一段，或一次急转仍残留给下一段"
	)
	evade_field.bee.position = evade_field._current_event_point()
	evade_field.request_primary_action()
	expect(evade_field.event_runtime.current_progress == 1, "下一风口未重新急转就被普通互动放行")
	evade_field.queue_free()
	await process_frame


func verify_playable_branches_and_finales(yushui: Dictionary, guyu: Dictionary) -> void:
	var rain_swift := configured_field(yushui, 611)
	var rain_steady := configured_field(yushui, 612)
	await process_frame
	expect(
		advance_field_to_event(rain_swift, "yushui_03_dry_landing")
		and advance_field_to_event(rain_steady, "yushui_03_dry_landing"),
		"无法抵达雨水落脚板分支"
	)
	rain_swift.event_runtime.accept_optional()
	rain_steady.event_runtime.accept_optional()
	rain_swift._select_event_route("swift")
	rain_steady._select_event_route("steady")
	expect(
		rain_swift.event_runtime.current_required_steps() == 2
		and rain_steady.event_runtime.current_required_steps() == 3,
		"雨水 03 两种落脚板做法仍是相同操作长度"
	)
	rain_swift.queue_free()
	rain_steady.queue_free()
	await process_frame

	var chase_swift := configured_field(guyu, 613)
	var chase_steady := configured_field(guyu, 614)
	await process_frame
	expect(
		advance_field_to_event(chase_swift, "guyu_12_air_chase")
		and advance_field_to_event(chase_steady, "guyu_12_air_chase"),
		"无法抵达谷雨空中追牌分支"
	)
	chase_swift._select_event_route("swift")
	chase_steady._select_event_route("steady")
	expect(
		chase_swift.event_points.size() >= 2
		and chase_steady.event_points.size() >= 2
		and chase_swift.event_points[0].distance_to(chase_steady.event_points[-1]) < 0.01
		and chase_swift.event_points[-1].distance_to(chase_steady.event_points[0]) < 0.01,
		"谷雨 12 两种接牌顺序仍沿完全相同的空间路线"
	)
	chase_swift.queue_free()
	chase_steady.queue_free()
	await process_frame

	var rain_finale := configured_field(yushui, 615)
	await process_frame
	expect(advance_field_to_event(rain_finale, "yushui_15_full_rain_route"), "无法抵达雨水复合终局")
	rain_finale._select_event_route("swift")
	var support_effects := rain_finale.event_runtime.world_state.get("support_effects", {}) as Dictionary
	var rhythm_phase := (
		rain_finale.EVENT_RHYTHM_PERIOD - rain_finale.EVENT_RHYTHM_OPEN_SECONDS - 0.08
	)
	rain_finale.elapsed = rhythm_phase - float(rain_finale.event_runtime.current_index) * 0.17
	while rain_finale.elapsed < 0.0:
		rain_finale.elapsed += rain_finale.EVENT_RHYTHM_PERIOD
	var saved_handoff := int(support_effects.get("handoff_rhythm", 0))
	support_effects["handoff_rhythm"] = 0
	var base_window_open := rain_finale._event_rhythm_window_open()
	support_effects["handoff_rhythm"] = saved_handoff
	expect(
		not base_window_open and rain_finale._event_rhythm_window_open(),
		"湿载荷交接支援没有在雨水终局拓宽真实节拍窗"
	)
	rain_finale.bee.position = rain_finale._current_event_point()
	rain_finale.request_primary_action()
	expect(rain_finale.event_runtime.current_progress == 1, "雨水终局没有通过第一段节拍门")
	rain_finale.bee.position = rain_finale._current_event_point()
	rain_finale.request_primary_action()
	expect(rain_finale.event_runtime.current_progress == 1, "雨水终局未急转就通过了第二段风口")
	rain_finale.event_runtime.note_evade()
	rain_finale.request_primary_action()
	expect(rain_finale.event_runtime.current_progress == 2, "雨水终局急转后没有带蜂流过风口")
	expect(
		rain_finale._event_navigation_target().distance_to(rain_finale.event_source_position) < 0.01,
		"雨水终局载荷段没有先指向真实花粉叶托"
	)
	rain_finale.bee.position = rain_finale.event_source_position
	rain_finale.request_primary_action()
	expect(rain_finale.event_carrying, "雨水终局没有真正托起花粉")
	rain_finale.bee.position = rain_finale._current_event_point()
	rain_finale.request_primary_action()
	expect(
		rain_finale.event_runtime.current_progress == 3 and not rain_finale.event_carrying,
		"雨水终局花粉没有送回队首"
	)
	rain_finale.bee.position = rain_finale._current_event_point()
	rain_finale.request_primary_action()
	expect(
		rain_finale.event_runtime.is_finished()
		and bool(rain_finale.event_runtime.world_state.get("setpiece_complete", false)),
		"雨水终局没有以蜂流收线形成可见结果"
	)
	rain_finale.queue_free()
	await process_frame

	var sign_finale := configured_field(guyu, 616)
	await process_frame
	expect(advance_field_to_event(sign_finale, "guyu_15_full_route"), "无法抵达谷雨复合终局")
	sign_finale._select_event_route("swift")
	for route_step in 3:
		sign_finale.bee.position = sign_finale._current_event_point()
		sign_finale.request_primary_action()
	expect(sign_finale.event_runtime.current_progress == 3, "谷雨终局前三段路线没有依次亮起")
	sign_finale.bee.position = sign_finale._current_event_point()
	sign_finale.request_primary_action()
	expect(sign_finale.event_runtime.current_progress == 3, "谷雨终局未急转就收掉了最后风口")
	sign_finale.event_runtime.note_evade()
	sign_finale.request_primary_action()
	expect(
		sign_finale.event_runtime.is_finished()
		and bool(sign_finale.event_runtime.world_state.get("setpiece_complete", false)),
		"谷雨终局最后急转没有完成全年路网收线"
	)
	sign_finale.queue_free()
	await process_frame


func verify_field_integration(level: Dictionary, token: int) -> void:
	var field = CampaignFieldScript.new()
	expect(field.configure({
		"campaign_mode": true,
		"journey_token": token,
		"level": level,
		"run_mode": "progression",
		"reserve": 0,
		"sortie_count": 1,
		"world_results": {},
	}) == OK, "%s 正式 Campaign 场景配置失败" % String(level.id))
	root.add_child(field)
	await process_frame
	expect(field.event_matrix_mode, "%s 仍退化为旧 objective 运行时" % String(level.id))
	expect(field.event_runtime.event_count() == 15, "%s 场景没有接入全部 15 项" % String(level.id))
	expect(field.tasks.is_empty(), "%s 仍生成旧 objective 的批量任务标记" % String(level.id))
	var snapshot: Dictionary = field.status_snapshot()
	expect((snapshot.get("objective_lines", []) as Array).size() == 1, "%s HUD 一次展示了不止当前行动" % String(level.id))
	expect(String((snapshot.get("event_runtime", {}) as Dictionary).get("current_mechanic", "")) == String(((level.get("event_matrix", []) as Array)[0] as Dictionary).get("mechanic", "")), "%s mechanic 没有进入正式状态快照" % String(level.id))
	expect((snapshot.get("visible_world_state", {}) as Dictionary).has("persistent_mark_count"), "%s 可见世界状态没有进入快照" % String(level.id))
	if field.event_runtime.choice_pending():
		var first_options := (((level.get("event_matrix", []) as Array)[0] as Dictionary).get("choice_options", {}) as Dictionary)
		expect(
			String(snapshot.get("action_label", "")) == String((first_options.swift as Dictionary).label)
			and String(snapshot.get("return_label", "")) == String((first_options.steady as Dictionary).label),
			"%s 真实 Field 快照没有把两种做法映射到主/次动作" % String(level.id)
		)
	var first_kind: String = field.event_runtime.current_kind()
	if field.event_runtime.choice_pending():
		field._select_event_route("steady")
	field.bee.position = field._current_event_point()
	field.bee.velocity = Vector2.ZERO
	field.hazard_active = false
	field.request_primary_action()
	if first_kind == EventRuntimeScript.KIND_OBSERVATION:
		field._process_event_matrix(field.OBSERVE_SECONDS + 0.05)
		expect(field.event_runtime.current_progress == 1, "%s 的观察窗口没有驱动正式任务进度" % String(level.id))
	elif first_kind == EventRuntimeScript.KIND_CONVOY:
		expect(field.event_runtime.current_progress == 1, "%s 的蜂流路线没有驱动正式任务进度" % String(level.id))
	field.bee.position = field.home_position
	field.bee.has_target = false
	field.evade_input_controller.clear(field.bee)
	var touch_world_target: Vector2 = field.home_position + Vector2(210.0, 80.0)
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = field.get_canvas_transform() * touch_world_target
	field._unhandled_input(touch)
	expect(
		field.bee.has_target and field.bee.target.distance_to(touch_world_target) < 1.0,
		"%s 的单次触屏被急转控制器吞掉，没有保留普通移动" % String(level.id)
	)
	field.force_complete_for_test()
	expect(field.completion_emitted, "%s 的 15 项最终不能完成正式 Campaign 结算" % String(level.id))
	expect(field.event_runtime.can_finish(), "%s 强制完成后主线合同仍不完整" % String(level.id))
	if String(level.get("kind", "")) == "climax":
		expect(field.phases_completed == 3, "%s 三候完成后高潮阶段数不是 3" % String(level.id))
	field.queue_free()
	await process_frame


func run_test() -> void:
	var catalog = CatalogScript.new()
	var yushui: Dictionary = catalog.level_by_id("spring_yushui")
	var guyu: Dictionary = catalog.level_by_id("spring_guyu")
	exercise_runtime(yushui, 6)
	exercise_runtime(guyu, 4)
	verify_mechanic_grammars(yushui, guyu)
	verify_optional_skip(yushui)
	verify_authored_choices_and_causality(yushui, guyu)
	verify_evade_and_support_contracts(guyu)
	verify_pentad_checkpoint(yushui)
	await verify_field_checkpoint_signal(yushui)
	await verify_field_mechanic_fidelity(yushui, guyu)
	await verify_playable_branches_and_finales(yushui, guyu)
	await verify_field_integration(yushui, 501)
	await verify_field_integration(guyu, 502)

	if failures.is_empty():
		print("TEST PASSED: 三候内容矩阵已进入正式 Campaign，并按 mechanic 形成可完成的主线／自选运行时")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
