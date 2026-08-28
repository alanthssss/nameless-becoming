extends SceneTree

const CatalogScript := preload("res://scripts/world/journey_level_catalog.gd")
const CampaignFieldScript := preload("res://scripts/world/journey_campaign_field.gd")
const CampaignGameScript := preload("res://scripts/world/journey_campaign_game.gd")
const EventRuntimeScript := preload("res://scripts/world/journey_event_matrix_runtime.gd")

const EVENT_LEVEL_IDS := ["spring_yushui", "spring_guyu"]
const EXPECTED_EVENT_COUNT := 30

var failures: Array[String] = []
var next_token := 9000
var optional_prompts_by_support := {}


func _init() -> void:
	call_deferred("run_test")


func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func configured_field(
	level: Dictionary,
	run_mode := "progression",
	event_checkpoint := {}
) -> JourneyCampaignField:
	var field = CampaignFieldScript.new()
	next_token += 1
	var context := {
		"campaign_mode": true,
		"journey_token": next_token,
		"level": level,
		"run_mode": run_mode,
		"reserve": 0,
		"sortie_count": 1,
		"world_results": {},
	}
	if event_checkpoint is Dictionary and not (event_checkpoint as Dictionary).is_empty():
		context["event_checkpoint"] = (event_checkpoint as Dictionary).duplicate(true)
	var error := field.configure(context)
	if error != OK:
		expect(false, "%s 无法建立正式 Field：%s" % [String(level.get("id", "未知关卡")), error_string(error)])
		field.free()
		return null
	root.add_child(field)
	return field


func dispose_field(field: JourneyCampaignField) -> void:
	if field != null and is_instance_valid(field):
		field.free()


func non_rest_position(field: JourneyCampaignField, away_from := Vector2(INF, INF)) -> Vector2:
	var candidates: Array[Vector2] = [
		field.playable_bounds.position + Vector2(90.0, 90.0),
		Vector2(field.playable_bounds.end.x - 90.0, field.playable_bounds.position.y + 90.0),
		Vector2(field.playable_bounds.position.x + 90.0, field.playable_bounds.end.y - 90.0),
		field.playable_bounds.get_center() + Vector2(170.0, -130.0),
	]
	for candidate in candidates:
		var clear := candidate.distance_to(away_from) > field.INTERACTION_RADIUS * 1.5
		for rest_point in field.rest_points:
			clear = clear and candidate.distance_to(rest_point) > 120.0
		if clear:
			return candidate
	return field.home_position


func task_index_for_type(field: JourneyCampaignField, work_type: String, objective_index := -1) -> int:
	for index in field.tasks.size():
		var task := field.tasks[index] as Dictionary
		if (
			String(task.get("type", "")) == work_type
			and not bool(task.get("resolved", false))
			and (objective_index < 0 or int(task.get("objective_index", -1)) == objective_index)
		):
			return index
	return -1


func complete_runtime_event(runtime: JourneyEventMatrixRuntime) -> bool:
	if runtime == null or runtime.is_finished():
		return false
	if runtime.optional_pending():
		runtime.accept_optional()
	if runtime.choice_pending():
		runtime.choose_route("steady")
	var event_id := String(runtime.current_event().get("id", ""))
	var guard := 0
	while not runtime.is_finished() and String(runtime.current_event().get("id", "")) == event_id and guard < 16:
		guard += 1
		if runtime.requires_evade():
			runtime.note_evade()
		var result := runtime.record_step(runtime.current_kind())
		if not bool(result.get("accepted", false)):
			return false
	return runtime.is_finished() or String(runtime.current_event().get("id", "")) != event_id


func event_checkpoint_after(
	level: Dictionary,
	completed_event_count: int,
	energy := 100.0
) -> Dictionary:
	var runtime = EventRuntimeScript.new()
	var level_id := String(level.get("id", ""))
	expect(
		runtime.configure(level.get("event_matrix", [])) == OK,
		"%s 无法为 event %d checkpoint 建立运行时" % [level_id, completed_event_count]
	)
	while not runtime.is_finished() and runtime.current_index < completed_event_count:
		if not complete_runtime_event(runtime):
			expect(false, "%s 无法推进到 event %d checkpoint" % [level_id, completed_event_count])
			return {}
	expect(
		runtime.current_index == completed_event_count,
		"%s checkpoint 停在 event %d 而非 %d" % [level_id, runtime.current_index, completed_event_count]
	)
	var checkpoint := runtime.checkpoint_snapshot()
	expect(
		not checkpoint.is_empty(),
		"%s event %d 不是可恢复的整候 checkpoint" % [level_id, completed_event_count]
	)
	if checkpoint.is_empty():
		return {}
	checkpoint["level_id"] = level_id
	checkpoint["energy"] = energy
	checkpoint["elapsed_seconds"] = 37.5 * float(completed_event_count)
	checkpoint["actions"] = completed_event_count * 3
	return checkpoint


func unique_position_count(points: Array[Vector2], tolerance := 1.0) -> int:
	var unique: Array[Vector2] = []
	for point in points:
		var already_present := false
		for existing in unique:
			if existing.distance_to(point) <= tolerance:
				already_present = true
				break
		if not already_present:
			unique.append(point)
	return unique.size()


func vector_lists_equivalent(left: Array, right: Array, tolerance := 1.0) -> bool:
	if left.size() != right.size():
		return false
	for index in left.size():
		if Vector2(left[index]).distance_to(Vector2(right[index])) > tolerance:
			return false
	return true


func additional_positions(points: Array, baseline: Array, tolerance := 1.0) -> Array[Vector2]:
	var additions: Array[Vector2] = []
	for raw_point in points:
		var point := Vector2(raw_point)
		var found := false
		for raw_baseline in baseline:
			if point.distance_to(Vector2(raw_baseline)) <= tolerance:
				found = true
				break
		if not found:
			additions.append(point)
	return additions


func event_mark_lists_equivalent(left: Array, right: Array) -> bool:
	if left.size() != right.size():
		return false
	for index in left.size():
		var left_mark := left[index] as Dictionary
		var right_mark := right[index] as Dictionary
		if Vector2(left_mark.get("position", Vector2.ZERO)).distance_to(
			Vector2(right_mark.get("position", Vector2.ZERO))
		) > 1.0:
			return false
		for key in ["kind", "mechanic", "optional", "pentad", "choice", "choice_effect"]:
			if left_mark.get(key) != right_mark.get(key):
				return false
	return true


func advance_field_runtime_to_event(field: JourneyCampaignField, event_id: String) -> bool:
	if field == null or field.event_runtime == null:
		return false
	while not field.event_runtime.is_finished() and String(field.event_runtime.current_event().get("id", "")) != event_id:
		if not complete_runtime_event(field.event_runtime):
			return false
	field._prepare_current_event()
	return (
		not field.event_runtime.is_finished()
		and String(field.event_runtime.current_event().get("id", "")) == event_id
	)


func place_field_in_clear_weather_phase(field: JourneyCampaignField) -> void:
	# Keep this movement/recovery fixture out of authored wind windows without
	# bypassing JourneyCampaignField._process(). The next 1.5 seconds remain in
	# the quiet half of the deterministic 8.5-second weather cycle.
	var variant_offset := fposmod(float(field.map_variant) * 0.73, 8.5)
	field.elapsed = fposmod(4.0 - variant_offset, 8.5)
	field.weather_window_elapsed = 0.0


func run_stationary_field_frames(
	field: JourneyCampaignField,
	frame_count: int,
	delta := 0.08
) -> Array[float]:
	var samples: Array[float] = []
	for _frame in frame_count:
		field.bee.velocity = Vector2.ZERO
		field.bee.evade_time = 0.0
		field._process(delta)
		samples.append(field.bee.energy)
	return samples


func verify_all_level_energy_contract(catalog) -> void:
	var levels: Array[Dictionary] = catalog.levels()
	expect(levels.size() == 24, "系统体力回归没有拿到完整 24 关目录")
	for level in levels:
		var level_id := String(level.get("id", ""))
		var field := configured_field(level)
		if field == null:
			continue
		expect(
			is_equal_approx(field.bee.max_energy, 100.0)
			and is_equal_approx(field.bee.energy, 100.0),
			"%s 没有以 100/100 体力进入真实 Field" % level_id
		)
		var snapshot := field.status_snapshot()
		expect(
			is_equal_approx(float(snapshot.get("energy_cap", -1.0)), 100.0),
			"%s 的 HUD 快照没有暴露 100 体力上限" % level_id
		)
		var starting_energy := 73.0
		var starting_position := non_rest_position(field)
		field.bee.position = starting_position
		field.bee.energy = starting_energy
		field.bee.velocity = Vector2.ZERO
		field.bee.move_duration = 0.0
		field.bee.active = true
		place_field_in_clear_weather_phase(field)
		var movement_target := field.clamp_to_playable_center(starting_position + Vector2(620.0, 0.0))
		if movement_target.distance_to(starting_position) < 240.0:
			movement_target = field.clamp_to_playable_center(starting_position + Vector2(-620.0, 0.0))
		field.bee.set_move_target(movement_target)
		for _frame in 16:
			field.bee._physics_process(0.08)
			field._process(0.08)
		expect(
			field.bee.position.distance_to(starting_position) > 40.0,
			"%s 的普通移动验证没有经过真实 Field 多帧飞行" % level_id
		)
		expect(
			is_equal_approx(field.bee.energy, starting_energy),
			"%s 普通移动仍消耗体力：%.2f -> %.2f" % [level_id, starting_energy, field.bee.energy]
		)
		dispose_field(field)


func verify_energy_tutorial_has_a_campaign_memory(catalog) -> void:
	var level: Dictionary = catalog.level_by_id("spring_jingzhe")
	var old_save_field = CampaignFieldScript.new()
	next_token += 1
	var error := old_save_field.configure({
		"campaign_mode": true,
		"journey_token": next_token,
		"level": level,
		"run_mode": "progression",
		"reserve": 0,
		"sortie_count": 3,
		"world_results": {"completed_count": 2},
	})
	expect(error == OK, "旧存档体力规则回归无法建立惊蛰 Field")
	if error == OK:
		root.add_child(old_save_field)
		expect(
			not old_save_field.energy_rule_taught
			and not old_save_field.recovery_rule_taught,
			"缺少教学版本的旧存档仍按已通关数量猜成学过新规则"
		)

		var emissions: Array[Dictionary] = []
		old_save_field.status_changed.connect(func(snapshot: Dictionary) -> void:
			emissions.append(snapshot.duplicate(true))
		)
		old_save_field.bee.energy = 100.0
		old_save_field.bee.evade_cooldown = 0.0
		var started: bool = old_save_field.bee.try_evade(
			Vector2.RIGHT,
			old_save_field.bee.position
		)
		old_save_field._play_evade_result({
			"evade_started": started,
			"evade_attempted": true,
			"origin": old_save_field.bee.position,
		})
		# Reproduce the original race: event progress rewrites the backing message in
		# the same frame. The product may only remember the lesson if the emitted
		# snapshot still contains the complete rule.
		old_save_field.message = "同帧事件进度覆盖了普通消息。"
		old_save_field._emit_status()
		var delivered := emissions[-1] if not emissions.is_empty() else {}
		var delivered_message := String(delivered.get("message", ""))
		expect(
			started
			and "普通飞行不耗体力" in delivered_message
			and "形状放错最多扣 2" in delivered_message
			and "停稳可回到 30" in delivered_message
			and "休息点可回满" in delivered_message
			and int(delivered.get("energy_tutorial_delivery_version", 0))
				== old_save_field.CAMPAIGN_ENERGY_TUTORIAL_VERSION
			and String(delivered.get("energy_tutorial_delivery_text", ""))
				== delivered_message
			and bool(delivered.get("energy_rule_taught", false))
			and bool(delivered.get("recovery_rule_taught", false)),
			"首次真实消耗没有在被同帧事件覆盖时送达完整、可记忆的体力规则：%s"
			% delivered_message
		)
		dispose_field(old_save_field)
	else:
		old_save_field.free()

	var taught_field = CampaignFieldScript.new()
	next_token += 1
	error = taught_field.configure({
		"campaign_mode": true,
		"journey_token": next_token,
		"level": level,
		"run_mode": "progression",
		"reserve": 0,
		"sortie_count": 4,
		"world_results": {"completed_count": 2},
		"campaign_energy_tutorial_version": 1,
	})
	expect(error == OK, "带教学版本的存档无法建立惊蛰 Field")
	if error == OK:
		root.add_child(taught_field)
		expect(
			taught_field.energy_rule_taught and taught_field.recovery_rule_taught,
			"已记录当前教学版本后仍会在后续节气重复体力／恢复教学"
		)
		dispose_field(taught_field)
	else:
		taught_field.free()


func verify_multiframe_breather_recovery(
	field: JourneyCampaignField,
	label: String
) -> void:
	const FRAME_DELTA := 0.08
	field.bee.velocity = Vector2.ZERO
	field.bee.evade_time = 0.0
	field.bee.energy = 0.0
	field.breather_elapsed = 0.0
	place_field_in_clear_weather_phase(field)

	var delay_frames := floori(field.CAMPAIGN_BREATHER_DELAY / FRAME_DELTA)
	var delay_samples := run_stationary_field_frames(field, delay_frames, FRAME_DELTA)
	expect(
		not delay_samples.is_empty()
		and is_zero_approx(delay_samples[-1]),
		"%s 在停稳延迟结束前就提前恢复了体力" % label
	)

	var previous_energy := field.bee.energy
	var recovery_samples := run_stationary_field_frames(field, 1, FRAME_DELTA)
	var first_recovered := recovery_samples[0] if not recovery_samples.is_empty() else -1.0
	expect(
		first_recovered > 0.0
		and first_recovered <= field.CAMPAIGN_BREATHER_RECOVERY_PER_SECOND * FRAME_DELTA + 0.001,
		"%s 跨过停稳延迟后没有按帧开始恢复：%.3f" % [label, first_recovered]
	)
	previous_energy = first_recovered

	var guard := 0
	while field.bee.energy < field.CAMPAIGN_BREATHER_CAP and guard < 100:
		guard += 1
		var samples := run_stationary_field_frames(field, 1, FRAME_DELTA)
		var current_energy := samples[0]
		expect(
			current_energy + 0.001 >= previous_energy
			and current_energy - previous_energy
				<= field.CAMPAIGN_BREATHER_RECOVERY_PER_SECOND * FRAME_DELTA + 0.001,
			"%s 停稳恢复不是连续的逐帧增长：%.3f -> %.3f"
			% [label, previous_energy, current_energy]
		)
		previous_energy = current_energy
	expect(
		guard < 100 and is_equal_approx(field.bee.energy, field.CAMPAIGN_BREATHER_CAP),
		"%s 多帧停稳没有在 30 点候档封顶：%.3f" % [label, field.bee.energy]
	)
	var capped_samples := run_stationary_field_frames(field, 4, FRAME_DELTA)
	expect(
		not capped_samples.is_empty()
		and is_equal_approx(capped_samples[-1], field.CAMPAIGN_BREATHER_CAP),
		"%s 在普通停稳中越过了 30 点候档上限" % label
	)


func verify_breather_and_standard_carry(catalog) -> void:
	var field := configured_field(catalog.level_by_id("spring_qingming"))
	if field == null:
		return
	var arbitrary_position := non_rest_position(field)
	field.bee.position = arbitrary_position
	verify_multiframe_breather_recovery(field, "任意非休息点")
	expect(
		not field.resting and is_equal_approx(field.bee.energy, field.CAMPAIGN_BREATHER_CAP),
		"任意非休息点停稳后不能从 0 回到 30"
	)

	var carry_index := task_index_for_type(field, "carry")
	expect(carry_index >= 0, "标准携带回归找不到可拿起的 carry 任务")
	if carry_index >= 0:
		var carry_task := field.tasks[carry_index] as Dictionary
		var destination := Vector2(carry_task.get("position", Vector2.ZERO))
		field.bee.position = Vector2(carry_task.get("source_position", Vector2.ZERO))
		field.bee.velocity = Vector2.ZERO
		field.request_primary_action()
		expect(field.carried_task_index == carry_index, "标准 carry 任务没有建立真实携带状态")

		field.bee.position = non_rest_position(field, destination)
		verify_multiframe_breather_recovery(field, "携带标准物件")
		expect(
			field.carried_task_index == carry_index
			and not field.resting
			and is_equal_approx(field.bee.energy, field.CAMPAIGN_BREATHER_CAP),
			"携带标准物件时停稳不能从 0 回到 30，或恢复时把物件丢了"
		)

		field.bee.sense_cooldown = 0.0
		field.bee.sense_time = 0.0
		field.bee.has_target = false
		expect(field._action_label() == "前往送达花标", "标准携带远离工位时没有显示“前往送达花标”")
		field.request_primary_action()
		expect(
			field.carried_task_index == carry_index
			and field.bee.has_target
			and field.bee.target.distance_to(destination) < 0.01
			and field.bee.sense_time > 0.0,
			"“查看送达花标”没有触发 sense 并把移动目标设为真实送达工位"
		)
	dispose_field(field)


func verify_heavy_pouch_profile_and_evade_cost(catalog) -> void:
	var field := configured_field(catalog.level_by_id("autumn_chushu"))
	if field == null:
		return
	expect(String(field.level.get("scenario_id", "")) == "heavy_pouch", "重蜜囊回归进入了错误场景")
	var previous_speed := field.bee.load_speed_multiplier
	var previous_acceleration := field.bee.load_acceleration_multiplier
	var previous_cost := field.bee.load_dash_cost_multiplier
	for load_count in field.CARGO_CAPACITY:
		var collect_index := task_index_for_type(field, "collect")
		expect(collect_index >= 0, "heavy_pouch 在 %d/4 时找不到下一份可收花蜜" % load_count)
		if collect_index < 0:
			break
		var collect_task := field.tasks[collect_index] as Dictionary
		field.bee.position = Vector2(collect_task.get("position", Vector2.ZERO))
		field.bee.velocity = Vector2.ZERO
		field.request_primary_action()
		var expected_load := load_count + 1
		expect(
			field.collected_cargo == expected_load and bool((field.tasks[collect_index] as Dictionary).get("resolved", false)),
			"heavy_pouch 第 %d 份没有真实进入蜜囊" % expected_load
		)
		expect(
			field.bee.load_speed_multiplier < previous_speed
			and field.bee.load_acceleration_multiplier < previous_acceleration
			and field.bee.load_dash_cost_multiplier > previous_cost,
			"heavy_pouch 从 %d/4 到 %d/4 没有随收集比例单调变重" % [load_count, expected_load]
		)
		expect(
			is_equal_approx(field.bee.visual_load_ratio, float(expected_load) / float(field.CARGO_CAPACITY)),
			"heavy_pouch %d/4 的视觉负载与真实收集比例不一致" % expected_load
		)
		previous_speed = field.bee.load_speed_multiplier
		previous_acceleration = field.bee.load_acceleration_multiplier
		previous_cost = field.bee.load_dash_cost_multiplier

	expect(field.has_method("_effective_evade_energy_cost"), "Field 缺少当前有效急转成本 API")
	if field.has_method("_effective_evade_energy_cost"):
		var effective_cost := float(field.call("_effective_evade_energy_cost"))
		var expected_cost := field.CAMPAIGN_EVADE_COST * field.bee.load_dash_cost_multiplier
		expect(
			is_equal_approx(effective_cost, expected_cost)
			and is_equal_approx(float(field.status_snapshot().get("evade_cost", -1.0)), expected_cost),
			"当前有效急转成本或状态快照没有反映蜜囊 load multiplier"
		)
		field.bee.energy = 100.0
		field.bee.evade_time = 0.0
		field.bee.evade_cooldown = 0.0
		var evade_started := field.bee.try_evade(Vector2.RIGHT, field.bee.position)
		expect(
			evade_started and is_equal_approx(100.0 - field.bee.energy, expected_cost),
			"重蜜囊急转实际扣除值没有使用当前有效成本"
		)

	field._deposit_collected_cargo()
	expect(
		field.collected_cargo == 0
		and is_equal_approx(field.bee.load_speed_multiplier, 1.0)
		and is_equal_approx(field.bee.load_acceleration_multiplier, 1.0)
		and is_equal_approx(field.bee.load_dash_cost_multiplier, 1.0),
		"heavy_pouch 回巢卸货后没有恢复普通 movement profile"
	)
	dispose_field(field)


func verify_real_heavy_choice_and_continuous_cost(catalog) -> void:
	var field := configured_field(catalog.level_by_id("spring_yushui"))
	if field == null:
		return
	expect(
		advance_field_runtime_to_event(field, "yushui_11_heavy_or_light"),
		"无法抵达真实轻重载选择"
	)
	if field.event_runtime == null or field.event_runtime.is_finished():
		dispose_field(field)
		return
	field.request_primary_action()
	expect(
		field.event_runtime.choice_effect() == "heavy_single"
		and field.event_runtime.current_required_steps() == 1
		and field.event_carrying
		and field.bee.visual_load_ratio > 0.0
		and is_equal_approx(field.bee.load_speed_multiplier, field.EVENT_HEAVY_SPEED_SCALE)
		and is_equal_approx(field.bee.load_acceleration_multiplier, field.EVENT_HEAVY_ACCELERATION_SCALE)
		and is_equal_approx(field.bee.load_dash_cost_multiplier, field.EVENT_HEAVY_DASH_COST_SCALE),
		"一趟重载选择没有建立真实 carrying、可见负载和 movement profile"
	)

	field.elapsed = 4.0
	field.weather_window_elapsed = 0.0
	field.bee.position = non_rest_position(field)
	field.bee.velocity = Vector2(100.0, 0.0)
	field.bee.energy = 80.0
	var expected_after_heavy_motion := 80.0 - field.CAMPAIGN_HEAVY_DRAIN_PER_SECOND * 2.0
	field._process_chapter(2.0)
	expect(
		is_equal_approx(field.bee.energy, expected_after_heavy_motion),
		"真实重载移动没有持续耗体力，或混入了非重载成本：%.2f != %.2f" % [field.bee.energy, expected_after_heavy_motion]
	)

	field.bee.velocity = Vector2.ZERO
	field.bee.evade_time = 0.0
	field.bee.energy = 0.0
	field.breather_elapsed = 0.0
	field._update_campaign_recovery(
		field.CAMPAIGN_BREATHER_DELAY
		+ field.CAMPAIGN_BREATHER_CAP / field.CAMPAIGN_BREATHER_RECOVERY_PER_SECOND
		+ 0.1
	)
	expect(
		field.event_carrying and is_equal_approx(field.bee.energy, field.CAMPAIGN_BREATHER_CAP),
		"真实重载携带中停稳不能从 0 恢复到 30"
	)
	dispose_field(field)


func event_action_signature(field: JourneyCampaignField) -> String:
	if field == null or field.event_runtime == null:
		return "missing"
	return JSON.stringify([
		field.event_runtime.current_index,
		field.event_runtime.current_progress,
		field.event_runtime.current_optional_state,
		field.event_runtime.current_choice,
		field.event_carrying,
		field.event_observing,
		field.event_anchor_hits,
		field.event_carried_shape,
		field.bee.evade_sequence,
	])


func assert_current_event_contract(field: JourneyCampaignField, event_id: String, stage: String) -> void:
	var snapshot := field.status_snapshot()
	var runtime_snapshot := snapshot.get("event_runtime", {}) as Dictionary
	var action_label := String(snapshot.get("action_label", "")).strip_edges()
	var instruction := String(snapshot.get("player_instruction", "")).strip_edges()
	expect(
		not action_label.is_empty(),
		"%s %s 的 action label 为空" % [event_id, stage]
	)
	expect(
		not instruction.is_empty(),
		"%s %s 的 player instruction 为空" % [event_id, stage]
	)
	expect(
		String(runtime_snapshot.get("current_event_id", "")) == event_id
		and action_label == field._event_action_label()
		and instruction == field._event_player_instruction(),
		"%s %s 的快照、按钮或玩家指令没有指向当前事件" % [event_id, stage]
	)
	if (
		not field.event_runtime.optional_pending()
		and not field.event_runtime.choice_pending()
		and (
			field.event_runtime.requires_evade()
			or field._convoy_stage_requires_evade()
		)
	):
		expect(
			"体力" in action_label,
			"%s %s 的可见主动作没有在扣费前说明急转体力成本" % [event_id, stage]
		)
	var lines := snapshot.get("objective_lines", []) as Array
	var title := String(field.event_runtime.current_event().get("title", ""))
	expect(
		not lines.is_empty() and title in String(lines[0]),
		"%s %s 的目标卡没有展示当前事件标题" % [event_id, stage]
	)
	var visible_world := snapshot.get("visible_world_state", {}) as Dictionary
	var snapshot_target = visible_world.get("current_target", null)
	expect(
		typeof(snapshot_target) == TYPE_VECTOR2
		and Vector2(snapshot_target).distance_to(field._event_navigation_target()) < 0.01,
		"%s %s 的目标卡事件与导航目标不属于同一 objective" % [event_id, stage]
	)


func press_event_primary_and_expect_change(field: JourneyCampaignField, event_id: String, stage: String) -> void:
	assert_current_event_contract(field, event_id, stage)
	var before := event_action_signature(field)
	field.request_primary_action()
	var after := event_action_signature(field)
	expect(before != after, "%s %s 的主按钮在真实位置没有推进任何可玩状态" % [event_id, stage])


func open_current_rhythm_window(field: JourneyCampaignField) -> void:
	field.elapsed = 0.0
	var guard := 0
	while not field._event_rhythm_window_open() and guard < 200:
		guard += 1
		field.elapsed += 0.02
	expect(field._event_rhythm_window_open(), "%s 无法准备真实节拍窗口" % String(field.event_runtime.current_event().get("id", "")))


func prepare_current_event_position(field: JourneyCampaignField) -> void:
	field.hazard_active = false
	field.event_observing = false
	field.bee.evade_time = 0.0
	field.bee.evade_cooldown = 0.0
	if (
		field.event_runtime.requires_rhythm()
		or (
			field.event_runtime.current_kind() == EventRuntimeScript.KIND_CONVOY
			and field._convoy_stage_requires_rhythm()
		)
	):
		open_current_rhythm_window(field)
	if (
		field.event_runtime.requires_evade()
		or (
			field.event_runtime.current_kind() == EventRuntimeScript.KIND_CONVOY
			and field._convoy_stage_requires_evade()
		)
	):
		field.bee.energy = field.bee.max_energy
	field._process_event_matrix(0.0)
	field.bee.position = field._event_navigation_target()
	field.bee.velocity = (
		Vector2(32.0, 0.0)
		if field.event_runtime.current_kind() == EventRuntimeScript.KIND_AIR_CATCH and not field.event_carrying
		else Vector2.ZERO
	)


func verify_discrete_energy_state_survives_field_tick(catalog) -> void:
	var field := configured_field(catalog.level_by_id("spring_yushui"))
	if field == null:
		return
	expect(
		advance_field_runtime_to_event(field, "yushui_02_underleaf_flight"),
		"无法抵达离散体力反馈回归的急转门"
	)
	if field.event_runtime == null or field.event_runtime.is_finished():
		dispose_field(field)
		return
	prepare_current_event_position(field)
	place_field_in_clear_weather_phase(field)
	field.bee.energy = field.bee.max_energy
	field.request_primary_action()
	var discrete_state := String(field.status_snapshot().get("energy_state", ""))
	expect(
		discrete_state.begins_with("急转 -"),
		"真实急转没有先生成可见的离散体力反馈：%s" % discrete_state
	)
	field._process_chapter(0.08)
	var next_snapshot := field.status_snapshot()
	expect(
		String(next_snapshot.get("energy_state", "")) == discrete_state,
		"离散体力反馈在下一次真实 _process_chapter(0.08) 就消失了：%s -> %s"
		% [discrete_state, String(next_snapshot.get("energy_state", ""))]
	)
	dispose_field(field)


func verify_optional_acceptance_prompt(field: JourneyCampaignField, event_id: String) -> Dictionary:
	var mechanic := field.event_runtime.current_mechanic()
	var reward := float(EventRuntimeScript.OPTIONAL_ENERGY_REWARDS.get(mechanic, 4.0))
	var support_effect := String(EventRuntimeScript.OPTIONAL_SUPPORT_EFFECTS.get(mechanic, "neighbour_help"))
	var support_labels: Dictionary = CampaignFieldScript.OPTIONAL_SUPPORT_LABELS
	expect(
		EventRuntimeScript.OPTIONAL_SUPPORT_EFFECTS.has(mechanic),
		"%s 的 optional mechanic=%s 没有明确 support effect" % [event_id, mechanic]
	)
	expect(
		support_labels.has(support_effect),
		"%s 的 support=%s 没有玩家可读标签" % [event_id, support_effect]
	)
	var support_label := String(support_labels.get(support_effect, ""))
	var support_effects_before := (
		field.event_runtime.world_state.get("support_effects", {}) as Dictionary
	).duplicate(true)
	var cap_gap := minf(2.0, reward) if reward > 0.0 else 0.0
	field.bee.energy = field.bee.max_energy - cap_gap
	var probe := {
		"reward": reward,
		"support_effect": support_effect,
		"support_count_before": int(support_effects_before.get(support_effect, 0)),
		"support_points_before": field.event_runtime.support_points,
		"energy_before": field.bee.energy,
		"energy_before_reward": field.bee.energy,
		"energy_cap": field.bee.max_energy,
	}
	expect(field.has_method("_event_acceptance_message"), "%s 缺少 optional 接受提示生成 API" % event_id)
	var expected_message := ""
	if field.has_method("_event_acceptance_message"):
		expected_message = String(field.call("_event_acceptance_message"))
		expect(not expected_message.strip_edges().is_empty(), "%s 的 optional 接受提示为空" % event_id)
		expect(
			"体力恢复 %s 点" % field._format_energy_amount(reward) in expected_message,
			"%s 的接受提示没有按真实 reward=%d 生成" % [event_id, roundi(reward)]
		)
		expect(
			"现场支援：%s" % support_label in expected_message,
			"%s 的接受提示没有把 support=%s 精确翻译成“%s”"
			% [event_id, support_effect, support_label]
		)
		for other_effect in support_labels:
			if String(other_effect) == support_effect:
				continue
			var other_label := String(support_labels[other_effect])
			expect(
				other_label not in expected_message,
				"%s 的 support=%s 提示混入了其他支援标签“%s”"
				% [event_id, support_effect, other_label]
			)
		if optional_prompts_by_support.has(support_effect):
			var previous := String(optional_prompts_by_support[support_effect])
			expect(
				not previous.is_empty(),
				"%s 的 support=%s 没有留下可比较提示" % [event_id, support_effect]
			)
		else:
			optional_prompts_by_support[support_effect] = expected_message
	prepare_current_event_position(field)
	press_event_primary_and_expect_change(field, event_id, "接受自选")
	expect(field.event_runtime.optional_accepted(), "%s 主按钮没有真正接受 optional" % event_id)
	if not expected_message.is_empty():
		expect(field.message == expected_message, "%s primary 没有使用真实 reward/support 生成的接受提示" % event_id)
	return probe


func verify_optional_completion_contract(
	field: JourneyCampaignField,
	event_id: String,
	probe: Dictionary
) -> void:
	var reward := float(probe.get("reward", 0.0))
	var energy_before := float(probe.get("energy_before_reward", field.bee.energy))
	var energy_cap := float(probe.get("energy_cap", field.bee.max_energy))
	var expected_energy := minf(energy_cap, energy_before + reward)
	var expected_actual_reward := expected_energy - energy_before
	var support_effect := String(probe.get("support_effect", ""))
	var support_effects := field.event_runtime.world_state.get("support_effects", {}) as Dictionary
	expect(
		field.event_runtime.support_points == int(probe.get("support_points_before", -1)) + 1
		and int(support_effects.get(support_effect, 0))
			== int(probe.get("support_count_before", -1)) + 1
		and event_id in field.event_runtime.completed_optional_ids
		and event_id not in field.event_runtime.skipped_optional_ids,
		"%s 完成后没有把 %s 支援与 support point 各真实累计一次" % [event_id, support_effect]
	)
	expect(
		is_equal_approx(field.bee.energy, expected_energy)
		and field.bee.energy <= energy_cap,
		"%s 自选奖励没有按上限结算：before=%.2f reward=%.2f actual=%.2f cap=%.2f"
		% [event_id, energy_before, reward, field.bee.energy, energy_cap]
	)
	if reward > 0.0:
		expect(
			String(field.status_snapshot().get("energy_state", ""))
				== "自选奖励 +%s" % field._format_energy_amount(expected_actual_reward),
			"%s 没有显示封顶后的实际恢复量 %.2f" % [event_id, expected_actual_reward]
		)


func exercise_current_event(field: JourneyCampaignField) -> bool:
	if field.event_runtime == null or field.event_runtime.is_finished():
		return false
	var event_id := String(field.event_runtime.current_event().get("id", ""))
	var starting_index := field.event_runtime.current_index
	var optional_probe := {}
	if field.event_runtime.optional_pending():
		optional_probe = verify_optional_acceptance_prompt(field, event_id)
	if field.event_runtime.choice_pending():
		prepare_current_event_position(field)
		press_event_primary_and_expect_change(field, event_id, "选择主按钮路线")
		expect(
			field.event_runtime.current_choice == "swift",
			"%s 主按钮没有兑现 action label 对应的 swift 选择" % event_id
		)

	var guard := 0
	while (
		not field.event_runtime.is_finished()
		and field.event_runtime.current_index == starting_index
		and guard < 48
	):
		guard += 1
		prepare_current_event_position(field)
		var before_action := event_action_signature(field)
		if not optional_probe.is_empty():
			# Some optional routes legitimately spend stamina before their reward
			# (mastery_lane includes one real evade). Capture the meter immediately
			# before the action that actually completes the event, not at acceptance.
			optional_probe["energy_before_reward"] = field.bee.energy
		press_event_primary_and_expect_change(field, event_id, "执行 %d" % guard)
		if (
			field.event_runtime.current_index == starting_index
			and field.event_runtime.current_kind() == EventRuntimeScript.KIND_OBSERVATION
			and field.event_observing
		):
			field.bee.velocity = Vector2.ZERO
			field.hazard_active = false
			field._process_event_matrix(field.OBSERVE_SECONDS + 0.1)
			expect(
				event_action_signature(field) != before_action,
				"%s 观察按钮开始后没有在真实圆圈内推进" % event_id
			)
	var advanced := field.event_runtime.is_finished() or field.event_runtime.current_index == starting_index + 1
	expect(advanced, "%s 无法仅靠对应真实位置与可见主动作完成" % event_id)
	if advanced and not optional_probe.is_empty():
		verify_optional_completion_contract(field, event_id, optional_probe)
	return advanced


func verify_legal_event_result(
	level: Dictionary,
	event_result: Dictionary,
	label: String
) -> void:
	var expected_mandatory: Array[String] = []
	var expected_optional: Array[String] = []
	var expected_support_counts := {}
	for raw_event in level.get("event_matrix", []) as Array:
		var event := raw_event as Dictionary
		var event_id := String(event.get("id", ""))
		if bool(event.get("optional", false)):
			expected_optional.append(event_id)
			var mechanic := String(event.get("mechanic", ""))
			var support_effect := String(
				EventRuntimeScript.OPTIONAL_SUPPORT_EFFECTS.get(mechanic, "neighbour_help")
			)
			expected_support_counts[support_effect] = int(expected_support_counts.get(support_effect, 0)) + 1
		else:
			expected_mandatory.append(event_id)
	var completed_mandatory := event_result.get("completed_mandatory_ids", []) as Array
	var completed_optional := event_result.get("completed_optional_ids", []) as Array
	var skipped_optional := event_result.get("skipped_optional_ids", []) as Array
	var world_state := event_result.get("world_state", {}) as Dictionary
	var support_effects := world_state.get("support_effects", {}) as Dictionary
	expect(
		completed_mandatory == expected_mandatory
		and completed_optional == expected_optional
		and skipped_optional.is_empty()
		and int(event_result.get("support_points", -1)) == expected_optional.size()
		and int(world_state.get("support_points", -1)) == expected_optional.size(),
		"%s 的 event_result 没有把已接受自选与主线完整、互斥地结算" % label
	)
	expect(
		support_effects == expected_support_counts,
		"%s 的 event_result 支援计数与 OPTIONAL_SUPPORT_EFFECTS 不一致：%s != %s"
		% [label, str(support_effects), str(expected_support_counts)]
	)
	var route_choices := event_result.get("route_choices", {}) as Dictionary
	for route_event_id in route_choices:
		expect(
			String(route_choices[route_event_id]) in EventRuntimeScript.CHOICE_IDS,
			"%s 的 event_result 含非法路线：%s=%s"
			% [label, String(route_event_id), String(route_choices[route_event_id])]
		)


func comparable_event_result(event_result: Dictionary) -> String:
	return JSON.stringify({
		"completed_mandatory_ids": event_result.get("completed_mandatory_ids", []),
		"completed_optional_ids": event_result.get("completed_optional_ids", []),
		"skipped_optional_ids": event_result.get("skipped_optional_ids", []),
		"route_choices": event_result.get("route_choices", {}),
		"support_points": event_result.get("support_points", 0),
		"world_state": event_result.get("world_state", {}),
	})


func verify_all_event_buttons(catalog) -> void:
	var visited := {}
	optional_prompts_by_support.clear()
	for level_id in EVENT_LEVEL_IDS:
		var level: Dictionary = catalog.level_by_id(level_id)
		var field := configured_field(level)
		if field == null:
			continue
		var emitted_checkpoints: Array[Dictionary] = []
		var checkpoint_world_states: Array[Dictionary] = []
		var completion_payloads: Array[Dictionary] = []
		field.event_checkpoint_reached.connect(
			func(checkpoint: Dictionary):
				emitted_checkpoints.append(checkpoint.duplicate(true))
				checkpoint_world_states.append({
					"event_world_marks": field.event_world_marks.duplicate(true),
					"rest_points": field.rest_points.duplicate(),
				})
		)
		field.journey_completed.connect(
			func(payload: Dictionary): completion_payloads.append(payload.duplicate(true))
		)
		var guard := 0
		while field.event_runtime != null and not field.event_runtime.is_finished() and guard < 20:
			guard += 1
			var event_id := String(field.event_runtime.current_event().get("id", ""))
			expect(not event_id.is_empty() and not visited.has(event_id), "%s 事件遍历出现空 ID 或重复" % level_id)
			visited[event_id] = true
			if not exercise_current_event(field):
				break
		expect(
			field.event_runtime != null and field.event_runtime.is_finished(),
			"%s 的 15 个按钮承诺不能走完真实事件矩阵" % level_id
		)
		expect(
			emitted_checkpoints.size() == 2
			and checkpoint_world_states.size() == 2
			and int(emitted_checkpoints[0].get("next_event_number", 0)) == 6
			and int(emitted_checkpoints[1].get("next_event_number", 0)) == 11,
			"%s 接受自选并完成事件时没有形成 event 5/10 两份合法候档" % level_id
		)
		if emitted_checkpoints.size() == 2 and checkpoint_world_states.size() == 2:
			for checkpoint_index in 2:
				var restored_world := configured_field(
					level,
					"progression",
					emitted_checkpoints[checkpoint_index]
				)
				if restored_world == null:
					continue
				var live_world := checkpoint_world_states[checkpoint_index]
				expect(
					event_mark_lists_equivalent(
						live_world.get("event_world_marks", []) as Array,
						restored_world.event_world_marks
					)
					and vector_lists_equivalent(
						live_world.get("rest_points", []) as Array,
						restored_world.rest_points
					),
					"%s event %d 候档的 live 标记／休息点与恢复世界不一致"
					% [level_id, (checkpoint_index + 1) * EventRuntimeScript.EVENTS_PER_PENTAD]
				)
				dispose_field(restored_world)
		field.bee.position = field.home_position
		field.bee.velocity = Vector2.ZERO
		field._process_chapter(0.08)
		var completion_event_result := (
			completion_payloads[0].get("event_result", {}) as Dictionary
			if completion_payloads.size() == 1
			else {}
		)
		var has_required_result_keys := true
		for required_key in [
			"completed_mandatory_ids", "completed_optional_ids", "skipped_optional_ids",
			"route_choices", "support_points", "world_state",
		]:
			has_required_result_keys = has_required_result_keys and completion_event_result.has(required_key)
		expect(
			completion_payloads.size() == 1
			and has_required_result_keys,
			"%s 完成全部已接受自选后没有生成唯一、完整的 event_result" % level_id
		)
		var canonical_event_result := {}
		if completion_payloads.size() == 1:
			canonical_event_result = completion_event_result.duplicate(true)
			verify_legal_event_result(level, canonical_event_result, "%s 首次结算" % level_id)

		if emitted_checkpoints.size() == 2 and not canonical_event_result.is_empty():
			var restored := configured_field(level, "progression", emitted_checkpoints[1])
			if restored != null:
				var restored_payloads: Array[Dictionary] = []
				restored.journey_completed.connect(
					func(payload: Dictionary): restored_payloads.append(payload.duplicate(true))
				)
				var restore_guard := 0
				while (
					restored.event_runtime != null
					and not restored.event_runtime.is_finished()
					and restore_guard < 8
				):
					restore_guard += 1
					if not exercise_current_event(restored):
						break
				restored.bee.position = restored.home_position
				restored.bee.velocity = Vector2.ZERO
				restored._process_chapter(0.08)
				expect(
					restored_payloads.size() == 1,
					"%s 从第二候档恢复后不能完成余下事件并结算" % level_id
				)
				if restored_payloads.size() == 1:
					var restored_event_result := (
						restored_payloads[0].get("event_result", {}) as Dictionary
					)
					verify_legal_event_result(level, restored_event_result, "%s 候档恢复结算" % level_id)
					expect(
						comparable_event_result(restored_event_result)
							== comparable_event_result(canonical_event_result),
						"%s 从候档完成余下事件后的 event_result 与连续游玩不一致" % level_id
					)
				dispose_field(restored)
		dispose_field(field)
	expect(visited.size() == EXPECTED_EVENT_COUNT, "事件按钮合同只覆盖 %d/%d 项" % [visited.size(), EXPECTED_EVENT_COUNT])
	var unique_prompts := {}
	for prompt in optional_prompts_by_support.values():
		unique_prompts[String(prompt)] = true
	expect(
		unique_prompts.size() == optional_prompts_by_support.size(),
		"不同 optional support 仍生成相同接受提示，提示没有按真实支援生成"
	)


func verify_accepted_optional_can_be_abandoned(catalog) -> void:
	var field := configured_field(catalog.level_by_id("spring_yushui"))
	if field == null:
		return
	var event_id := "yushui_04_pollen_rainline"
	expect(advance_field_runtime_to_event(field, event_id), "无法抵达已接受 optional 放弃回归")
	if field.event_runtime == null or field.event_runtime.is_finished():
		dispose_field(field)
		return
	field.request_primary_action()
	var accepted_return_label := String(field.status_snapshot().get("return_label", ""))
	expect(
		field.event_runtime.optional_accepted()
		and accepted_return_label == field.event_runtime.choice_label("steady"),
		"%s 接受后没有先把 Q/次按钮留给明确写出的稳路线" % event_id
	)
	field.request_primary_action()
	expect(
		field.event_runtime.current_choice == "swift",
		"%s 没有记录主按钮所选的一趟重载路线" % event_id
	)
	expect(
		"放下" in String(field.status_snapshot().get("return_label", "")),
		"%s 选完路线后 Q/次按钮没有切换为安全放下" % event_id
	)
	field.bee.position = field.event_source_position
	field.bee.velocity = Vector2.ZERO
	field.request_primary_action()
	expect(field.event_carrying, "%s 到达真实货源后没有建立可供安全清理的携带状态" % event_id)
	var starting_index := field.event_runtime.current_index
	var starting_support := field.event_runtime.support_points
	var starting_energy := field.bee.energy
	field.request_secondary_action()
	expect(
		field.event_runtime.current_index == starting_index + 1
		and event_id in field.event_runtime.skipped_optional_ids
		and event_id not in field.event_runtime.completed_optional_ids
		and not (field.event_runtime.world_state.get("route_choices", {}) as Dictionary).has(event_id)
		and field.event_runtime.support_points == starting_support
		and is_equal_approx(field.bee.energy, starting_energy)
		and not field.event_carrying
		and is_equal_approx(field.bee.load_speed_multiplier, 1.0)
		and is_equal_approx(field.bee.load_acceleration_multiplier, 1.0)
		and is_equal_approx(field.bee.load_dash_cost_multiplier, 1.0),
		"已接受 optional 不能安全放弃，或放弃后泄漏奖励/携带/profile"
	)
	dispose_field(field)

	# The secondary button must remain the authored steady choice until a route is
	# selected; otherwise adding safe abandonment makes half the choices unreachable.
	var steady_field := configured_field(catalog.level_by_id("spring_yushui"))
	if steady_field != null:
		expect(advance_field_runtime_to_event(steady_field, event_id), "无法抵达 optional 稳路线公开输入回归")
		steady_field.request_primary_action()
		steady_field.request_secondary_action()
		expect(
			steady_field.event_runtime.current_choice == "steady"
			and steady_field.event_runtime.optional_accepted()
			and steady_field.event_runtime.current_index == 3
			and event_id not in steady_field.event_runtime.skipped_optional_ids
			and "放下" in String(steady_field.status_snapshot().get("return_label", "")),
			"optional 接受后的公开 Q/次按钮无法选择稳路线，或误把事件直接略过"
		)
		dispose_field(steady_field)

	# Safe abandonment is transactional even after real partial progress. Otherwise
	# the skipped event leaves a ghost world counter that later save validation
	# cannot reproduce from completed/skipped IDs.
	var partial_field := configured_field(catalog.level_by_id("spring_yushui"))
	if partial_field == null:
		return
	var partial_event_id := "yushui_03_dry_landing"
	expect(
		advance_field_runtime_to_event(partial_field, partial_event_id),
		"无法抵达 optional 部分进度放弃回归"
	)
	if partial_field.event_runtime == null or partial_field.event_runtime.is_finished():
		dispose_field(partial_field)
		return
	partial_field.request_primary_action()
	partial_field.request_primary_action()
	var partial_starting_index := partial_field.event_runtime.current_index
	var anchors_before := int(partial_field.event_runtime.world_state.get("anchored_supports", 0))
	partial_field.bee.position = partial_field._event_navigation_target()
	partial_field.bee.velocity = Vector2.ZERO
	partial_field.request_primary_action()
	partial_field.request_primary_action()
	expect(
		partial_field.event_runtime.current_progress == 1
		and int(partial_field.event_runtime.world_state.get("anchored_supports", 0)) == anchors_before + 1,
		"optional 部分进度回归没有先形成一段真实世界变化"
	)
	partial_field.request_secondary_action()
	expect(
		partial_field.event_runtime.current_index == partial_starting_index + 1
		and partial_event_id in partial_field.event_runtime.skipped_optional_ids
		and partial_event_id not in partial_field.event_runtime.completed_optional_ids
		and int(partial_field.event_runtime.world_state.get("anchored_supports", 0)) == anchors_before
		and not (partial_field.event_runtime.world_state.get("route_choices", {}) as Dictionary).has(partial_event_id),
		"已接受 optional 的部分进度放弃后留下幽灵 world_state 或选择"
	)
	dispose_field(partial_field)


func verify_checkpoint_energy_migration(catalog) -> void:
	var level: Dictionary = catalog.level_by_id("spring_yushui")
	var template := event_checkpoint_after(level, EventRuntimeScript.EVENTS_PER_PENTAD, 100.0)
	if template.is_empty():
		return
	var stored_energy_cases: Array[float] = [0.0, 0.001, 0.01]
	for integer_energy in range(1, 30):
		stored_energy_cases.append(float(integer_energy))
	for stored_energy in stored_energy_cases:
		var checkpoint := template.duplicate(true)
		checkpoint["energy"] = stored_energy
		var field := configured_field(level, "progression", checkpoint)
		if field == null:
			continue
		var expected_energy := (
			field.CAMPAIGN_BREATHER_CAP
			if is_zero_approx(stored_energy)
			else stored_energy
		)
		expect(
			field.event_runtime.current_index == EventRuntimeScript.EVENTS_PER_PENTAD
			and is_equal_approx(field.bee.energy, expected_energy),
			"v3 checkpoint energy=%.3f 恢复成 %.3f；应为 %.3f（仅精确 0 可抬到 30）"
			% [stored_energy, field.bee.energy, expected_energy]
		)
		dispose_field(field)


func verify_progression_and_replay_pentad_refill(catalog) -> void:
	var level: Dictionary = catalog.level_by_id("spring_yushui")
	for run_mode in ["progression", "replay"]:
		var field := configured_field(level, run_mode)
		if field == null:
			continue
		var emitted: Array[Dictionary] = []
		field.event_checkpoint_reached.connect(
			func(checkpoint: Dictionary): emitted.append(checkpoint.duplicate(true))
		)
		var tested_boundaries: Array[int] = []
		var guard := 0
		while field.event_runtime.current_index < EventRuntimeScript.EVENTS_PER_PENTAD * 2 and guard < 16:
			guard += 1
			var completing_number := field.event_runtime.current_index + 1
			if completing_number in [5, 10]:
				field.bee.energy = 9.0 + float(completing_number)
				field.weather_window_elapsed = field.time_limit_seconds - 0.25
			if not exercise_current_event(field):
				break
			if field.event_runtime.current_index in [5, 10]:
				var boundary := field.event_runtime.current_index
				tested_boundaries.append(boundary)
				expect(
					is_equal_approx(field.bee.energy, field.bee.max_energy)
					and is_zero_approx(field.weather_window_elapsed)
					and field.energy_state == "换班 · 体力回满",
					"%s 完成 event %d 后没有真实回满体力并刷新天气窗口"
					% [run_mode, boundary]
				)
		expect(
			tested_boundaries == [5, 10],
			"%s 没有依次实际经过 event 5/10 两个候级边界：%s"
			% [run_mode, str(tested_boundaries)]
		)
		if run_mode == "progression":
			expect(
				emitted.size() == 2
				and int(emitted[0].get("next_event_number", 0)) == 6
				and int(emitted[1].get("next_event_number", 0)) == 11
				and is_equal_approx(float(emitted[0].get("energy", -1.0)), field.bee.max_energy)
				and is_equal_approx(float(emitted[1].get("energy", -1.0)), field.bee.max_energy),
				"progression 的 event 5/10 没有发出两份满体力 checkpoint"
			)
		else:
			expect(
				emitted.is_empty(),
				"replay 的换班错误写出了会污染正式进度的 checkpoint"
			)
		dispose_field(field)


func verify_escort_shelter_restore_is_idempotent(catalog) -> void:
	var level: Dictionary = catalog.level_by_id("spring_yushui")
	var clean := configured_field(level)
	if clean == null:
		return
	var authored_rest_points: Array = clean.rest_points.duplicate()
	var authored_rest_count := authored_rest_points.size()
	var authored_unique_count := unique_position_count(clean.rest_points)
	dispose_field(clean)

	var live := configured_field(level)
	if live == null:
		return
	var escort_id := "yushui_09_beetle_shelter"
	expect(
		advance_field_runtime_to_event(live, escort_id),
		"escort_shelter live 回归无法抵达雨水 09"
	)
	if live.event_runtime == null or live.event_runtime.is_finished():
		dispose_field(live)
		return
	var checkpoints: Array[Dictionary] = []
	live.event_checkpoint_reached.connect(
		func(checkpoint: Dictionary): checkpoints.append(checkpoint.duplicate(true))
	)
	expect(exercise_current_event(live), "escort_shelter 无法通过真实 Field 动作完成")
	var live_additions := additional_positions(live.rest_points, authored_rest_points)
	expect(
		live_additions.size() == 1
		and live.rest_points.size() == authored_rest_count + 1
		and unique_position_count(live.rest_points) == live.rest_points.size(),
		"escort_shelter live 完成没有产生恰好一个无重复休息点：%s"
		% str(live_additions)
	)
	expect(
		not live.event_runtime.is_finished()
		and String(live.event_runtime.current_event().get("id", ""))
			== "yushui_10_moving_rain_window"
		and exercise_current_event(live),
		"escort_shelter 完成后无法用真实雨水 10 动作形成整候 checkpoint"
	)
	expect(
		checkpoints.size() == 1
		and escort_id in (checkpoints[0].get("completed_optional_ids", []) as Array),
		"真实雨水 09/10 路径没有写出包含 escort_shelter 的 checkpoint"
	)
	if checkpoints.is_empty():
		dispose_field(live)
		return
	var restored := configured_field(level, "progression", checkpoints[0])
	if restored == null:
		dispose_field(live)
		return
	var restored_additions := additional_positions(restored.rest_points, authored_rest_points)
	expect(
		authored_rest_count == authored_unique_count
		and restored.rest_points.size() == authored_rest_count + 1
		and unique_position_count(restored.rest_points) == restored.rest_points.size()
		and live_additions.size() == 1
		and restored_additions.size() == 1
		and restored_additions[0].distance_to(live_additions[0]) <= 1.0,
		"escort_shelter checkpoint 没有把 live 新增休息点恢复到同一坐标：base=%d live=%s restored=%s unique=%d"
		% [
			authored_rest_count,
			str(live_additions),
			str(restored_additions),
			unique_position_count(restored.rest_points),
		]
	)
	dispose_field(restored)
	dispose_field(live)


func verify_moving_event_mark_survives_checkpoint(catalog) -> void:
	var level: Dictionary = catalog.level_by_id("spring_yushui")
	var field := configured_field(level)
	if field == null:
		return
	var event_id := "yushui_10_moving_rain_window"
	expect(
		advance_field_runtime_to_event(field, event_id),
		"动态事件标记回归无法抵达雨水 10"
	)
	field.elapsed = 3.17
	expect(exercise_current_event(field), "雨水 10 无法通过真实移动目标动作完成")
	var live_position := Vector2(INF, INF)
	for mark in field.event_world_marks:
		var mark_data := mark as Dictionary
		if String(mark_data.get("mechanic", "")) == "moving_shelter":
			live_position = Vector2(mark_data.get("position", Vector2(INF, INF)))
	var checkpoint := field.event_runtime.checkpoint_snapshot()
	expect(
		live_position.x != INF and not checkpoint.is_empty(),
		"雨水 10 完成后没有留下动态事件标记或第二候 checkpoint"
	)
	if live_position.x == INF or checkpoint.is_empty():
		dispose_field(field)
		return
	checkpoint["level_id"] = "spring_yushui"
	checkpoint["energy"] = field.bee.energy
	checkpoint["elapsed_seconds"] = field.elapsed
	checkpoint["actions"] = field.action_count
	var restored := configured_field(level, "progression", checkpoint)
	if restored != null:
		var restored_positions: Array[Vector2] = []
		for mark in restored.event_world_marks:
			var mark_data := mark as Dictionary
			if String(mark_data.get("mechanic", "")) == "moving_shelter":
				restored_positions.append(Vector2(mark_data.get("position", Vector2.ZERO)))
		expect(
			restored_positions.size() == 1
			and restored_positions[0].distance_to(live_position) < 0.01,
			"雨水 10 的完成标记在候档恢复后跳位：live=%s restored=%s"
			% [str(live_position), str(restored_positions)]
		)
		dispose_field(restored)
	dispose_field(field)


func nearby_outside_event_position(
	field: JourneyCampaignField,
	gate_position: Vector2
) -> Vector2:
	var offset := field.EVENT_INTERACTION_RADIUS * 1.75
	for direction in [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]:
		var candidate: Vector2 = gate_position + Vector2(direction) * offset
		if field.playable_bounds.grow(-24.0).has_point(candidate):
			return candidate
	return non_rest_position(field, gate_position)


func nearby_pointer_target(
	field: JourneyCampaignField,
	origin: Vector2
) -> Vector2:
	for offset in [Vector2(72.0, 0.0), Vector2(-72.0, 0.0), Vector2(0.0, 72.0), Vector2(0.0, -72.0)]:
		var candidate: Vector2 = origin + Vector2(offset)
		if field.playable_bounds.grow(-18.0).has_point(candidate):
			return candidate
	return field.clamp_to_playable_center(origin + Vector2(36.0, 0.0))


func dispatch_pointer_press(
	field: JourneyCampaignField,
	input_kind: String,
	world_position: Vector2
) -> void:
	field._update_camera()
	var screen_position := field.get_canvas_transform() * world_position
	if input_kind == "mouse":
		var mouse_event := InputEventMouseButton.new()
		mouse_event.button_index = MOUSE_BUTTON_LEFT
		mouse_event.position = screen_position
		mouse_event.pressed = true
		field._unhandled_input(mouse_event)
	else:
		var touch_event := InputEventScreenTouch.new()
		touch_event.index = 0
		touch_event.position = screen_position
		touch_event.pressed = true
		field._unhandled_input(touch_event)


func verify_pointer_double_tap_case(
	catalog,
	input_kind: String,
	first_tap_inside: bool
) -> void:
	var field := configured_field(catalog.level_by_id("spring_yushui"))
	if field == null:
		return
	var case_label := "%s %s→%s" % [
		input_kind,
		"门内" if first_tap_inside else "门外",
		"门外" if first_tap_inside else "门内",
	]
	expect(
		advance_field_runtime_to_event(field, "yushui_02_underleaf_flight"),
		"无法抵达 %s 双击首次落点回归" % case_label
	)
	if field.event_runtime == null or field.event_runtime.is_finished():
		dispose_field(field)
		return
	var gate_position := field._event_interaction_target()
	var outside_position := nearby_outside_event_position(field, gate_position)
	expect(
		outside_position.distance_to(gate_position) > field.EVENT_INTERACTION_RADIUS * 1.25,
		"%s 没有找到明确位于强制门外的首次落点" % case_label
	)
	field.bee.energy = 0.0
	field.bee.evade_time = 0.0
	field.bee.evade_cooldown = 0.0
	field.evade_input_controller.clear(field.bee)
	var first_origin := gate_position if first_tap_inside else outside_position
	var second_origin := outside_position if first_tap_inside else gate_position
	var pointer_target := nearby_pointer_target(field, first_origin)
	field.bee.position = first_origin
	var sequence_before := field.bee.evade_sequence
	dispatch_pointer_press(field, input_kind, pointer_target)
	field.bee.position = second_origin
	dispatch_pointer_press(field, input_kind, pointer_target)
	if first_tap_inside:
		expect(
			field.bee.evade_sequence == sequence_before + 1
			and field.bee.last_evade_was_assisted
			and field.bee.last_evade_origin.distance_to(first_origin) < 0.01
			and field.event_runtime.current_progress == 1,
			"%s 没有按第一次 pointer/touch 落点发放 assist 并推进" % case_label
		)
	else:
		expect(
			field.bee.evade_sequence == sequence_before
			and not field.bee.last_evade_was_assisted
			and field.event_runtime.current_progress == 0,
			"%s 错误按第二次 pointer/touch 落点发放 assist" % case_label
		)
	dispose_field(field)


func verify_double_tap_uses_first_press_position(catalog) -> void:
	var level: Dictionary = catalog.level_by_id("spring_yushui")
	var inside_first := configured_field(level)
	if inside_first == null:
		return
	expect(
		advance_field_runtime_to_event(inside_first, "yushui_02_underleaf_flight"),
		"无法抵达双击首次位置回归的强制急转门"
	)
	if inside_first.event_runtime == null or inside_first.event_runtime.is_finished():
		dispose_field(inside_first)
		return
	var gate_position := inside_first._event_interaction_target()
	var outside_position := non_rest_position(inside_first, gate_position)
	expect(
		outside_position.distance_to(gate_position) > inside_first.EVENT_INTERACTION_RADIUS * 1.25,
		"双击首次位置回归没有找到门外位置"
	)
	inside_first.bee.energy = 0.0
	inside_first.bee.evade_time = 0.0
	inside_first.bee.evade_cooldown = 0.0
	inside_first.evade_input_controller.clear(inside_first.bee)
	inside_first.bee.position = gate_position
	var sequence_before := inside_first.bee.evade_sequence
	inside_first._register_evade_direction_tap("right")
	inside_first.bee.position = outside_position
	inside_first._register_evade_direction_tap("right")
	expect(
		inside_first.bee.evade_sequence == sequence_before + 1
		and inside_first.bee.last_evade_was_assisted
		and inside_first.bee.last_evade_origin.distance_to(gate_position) < 0.01
		and inside_first.event_runtime.current_progress == 1,
		"第一次按键在强制门内、第二次已飞出时，没有按首次位置给予 assist 并推进"
	)
	dispose_field(inside_first)

	var outside_first := configured_field(level)
	if outside_first == null:
		return
	expect(
		advance_field_runtime_to_event(outside_first, "yushui_02_underleaf_flight"),
		"无法建立双击门外首次按键的反例"
	)
	if outside_first.event_runtime == null or outside_first.event_runtime.is_finished():
		dispose_field(outside_first)
		return
	gate_position = outside_first._event_interaction_target()
	outside_position = non_rest_position(outside_first, gate_position)
	outside_first.bee.energy = 0.0
	outside_first.bee.evade_time = 0.0
	outside_first.bee.evade_cooldown = 0.0
	outside_first.evade_input_controller.clear(outside_first.bee)
	outside_first.bee.position = outside_position
	sequence_before = outside_first.bee.evade_sequence
	outside_first._register_evade_direction_tap("right")
	outside_first.bee.position = gate_position
	outside_first._register_evade_direction_tap("right")
	expect(
		outside_first.bee.evade_sequence == sequence_before
		and not outside_first.bee.last_evade_was_assisted
		and outside_first.event_runtime.current_progress == 0,
		"第一次按键在强制门外、第二次才进入时，错误按第二次位置发放 assist"
	)
	dispose_field(outside_first)

	for input_kind in ["mouse", "touch"]:
		verify_pointer_double_tap_case(catalog, input_kind, true)
		verify_pointer_double_tap_case(catalog, input_kind, false)


func verify_mastery_lane_has_one_third_step_evade(catalog) -> void:
	var level: Dictionary = catalog.level_by_id("spring_yushui")
	var runtime = EventRuntimeScript.new()
	expect(runtime.configure(level.get("event_matrix", [])) == OK, "mastery_lane 回归无法建立运行时")
	while not runtime.is_finished() and String(runtime.current_event().get("id", "")) != "yushui_13_dry_mastery":
		if not complete_runtime_event(runtime):
			expect(false, "无法抵达 mastery_lane")
			return
	expect(runtime.accept_optional(), "mastery_lane 无法接受 optional")
	expect(runtime.current_required_steps() == 4, "mastery_lane 不再是四步路线")
	var evade_requirements: Array[bool] = []
	var result := {}
	for step in 4:
		var needs_evade := runtime.requires_evade()
		evade_requirements.append(needs_evade)
		if step == 2:
			var blocked := runtime.record_step(runtime.current_kind())
			expect(
				bool(blocked.get("needs_evade", false)) and runtime.current_progress == 2,
				"mastery_lane 第三步没有在未急转时停住"
			)
			runtime.note_evade()
		result = runtime.record_step(runtime.current_kind())
		expect(bool(result.get("accepted", false)), "mastery_lane 第 %d 步无法推进" % (step + 1))
	expect(
		evade_requirements == [false, false, true, false]
		and bool(result.get("event_complete", false))
		and "yushui_13_dry_mastery" in runtime.completed_optional_ids,
		"mastery_lane 的四步急转语法不是 [普通, 普通, 急转, 普通]：%s"
		% str(evade_requirements)
	)

	var field := configured_field(level)
	if field == null:
		return
	expect(
		advance_field_runtime_to_event(field, "yushui_13_dry_mastery"),
		"Field 无法抵达 mastery_lane 单次急转回归"
	)
	if field.event_runtime == null or field.event_runtime.is_finished():
		dispose_field(field)
		return
	field.request_primary_action()
	var evade_sequence_before := field.bee.evade_sequence
	var starting_index := field.event_runtime.current_index
	expect(exercise_current_event(field), "Field mastery_lane 无法通过四个真实主动作完成")
	expect(
		field.event_runtime.current_index == starting_index + 1
		and field.bee.evade_sequence == evade_sequence_before + 1,
		"Field mastery_lane 四步没有恰好执行一次第三步急转"
	)
	dispose_field(field)


func verify_spare_sign_shortens_live_air_chase_mark(catalog) -> void:
	var field := configured_field(catalog.level_by_id("spring_guyu"))
	if field == null:
		return
	var event_id := "guyu_12_air_chase"
	expect(
		advance_field_runtime_to_event(field, event_id),
		"备用花牌落点回归无法抵达谷雨 12"
	)
	if field.event_runtime == null or field.event_runtime.is_finished():
		dispose_field(field)
		return
	var support_effects := field.event_runtime.world_state.get("support_effects", {}) as Dictionary
	expect(
		int(support_effects.get("spare_sign", 0)) > 0
		and field.event_runtime.choice_pending(),
		"抵达谷雨 12 时没有带入备用花牌支援或路线选择"
	)
	field._select_event_route("swift")
	var required := field.event_runtime.current_required_steps()
	expect(
		required == 2 and field.event_points.size() == 2,
		"备用花牌没有把谷雨 12 swift 追牌从 3 步真实缩成 2 步"
	)
	if field.event_points.size() != required:
		dispose_field(field)
		return
	var actual_final_position := field.event_points[required - 1]
	var marks_before := field.event_world_marks.size()
	expect(exercise_current_event(field), "谷雨 12 swift 无法通过真实公开动作完成")
	var live_mark_position := (
		Vector2((field.event_world_marks[-1] as Dictionary).get("position", Vector2.ZERO))
		if field.event_world_marks.size() == marks_before + 1
		else Vector2(INF, INF)
	)
	expect(
		field.event_world_marks.size() == marks_before + 1
		and live_mark_position.distance_to(actual_final_position) <= 1.0,
		"备用花牌缩短追牌后，完成标记仍落在玩家没有经过的第三点：actual=%s mark=%s"
		% [str(actual_final_position), str(live_mark_position)]
	)
	dispose_field(field)


func verify_low_energy_wrong_match_feedback(catalog) -> void:
	var field := configured_field(catalog.level_by_id("spring_guyu"))
	if field == null:
		return
	var event_id := "guyu_13_moving_match"
	expect(
		advance_field_runtime_to_event(field, event_id),
		"低体力误配回归无法抵达谷雨 13"
	)
	if field.event_runtime == null or field.event_runtime.is_finished():
		dispose_field(field)
		return
	expect(field.event_match_sources.size() == 3, "谷雨 13 没有建立三块可识别花牌")
	if field.event_match_sources.is_empty():
		dispose_field(field)
		return
	var required_shape := field._moving_match_required_shape()
	var wrong_shape := (required_shape + 1) % field.event_match_sources.size()
	field.bee.position = field.event_match_sources[wrong_shape]
	field.bee.velocity = Vector2.ZERO
	field.bee.energy = 1.0
	field.request_primary_action()
	expect(
		is_zero_approx(field.bee.energy)
		and field.energy_state == "误配 -1"
		and "体力 -1" in field.message
		and "形状放错最多扣 2" in field.tutorial_overlay_message,
		"只剩 1 点体力时，误配实扣与教学上限互相矛盾：state=%s message=%s tutorial=%s"
		% [field.energy_state, field.message, field.tutorial_overlay_message]
	)
	field.bee.energy = 0.0
	field.request_primary_action()
	expect(
		is_zero_approx(field.bee.energy)
		and field.energy_state == "误配 · 未再扣体力"
		and "体力已经见底，这次不再扣" in field.message
		and not "-0" in field.energy_state
		and not "-0" in field.message,
		"体力见底后的误配仍显示不存在的 -0 消耗：state=%s message=%s"
		% [field.energy_state, field.message]
	)
	dispose_field(field)


func verify_reverse_route_mark_case(
	catalog,
	level_id: String,
	event_id: String,
	checkpoint_event_count: int
) -> void:
	var level: Dictionary = catalog.level_by_id(level_id)
	var field := configured_field(level)
	if field == null:
		return
	expect(
		advance_field_runtime_to_event(field, event_id),
		"%s 无法抵达反向路线标记回归" % event_id
	)
	if field.event_runtime == null or field.event_runtime.is_finished():
		dispose_field(field)
		return
	if field.event_runtime.optional_pending():
		field.event_runtime.accept_optional()
	expect(field.event_runtime.choice_pending(), "%s 没有可选 steady 反向路线" % event_id)
	field._select_event_route("steady")
	var normalized_event := field.event_runtime.current_event()
	var required := field.event_runtime.current_required_steps()
	expect(
		field.event_runtime.current_choice == "steady"
		and required > 1
		and field.event_points.size() >= required,
		"%s steady 路线没有建立可反转的真实点列" % event_id
	)
	if field.event_points.size() < required:
		dispose_field(field)
		return
	var actual_final_position := field.event_points[required - 1]
	var marks_before := field.event_world_marks.size()
	var guard := 0
	while (
		not field.event_runtime.is_finished()
		and String(field.event_runtime.current_event().get("id", "")) == event_id
		and guard < 12
	):
		guard += 1
		var completed_at := field._current_event_point()
		var result := field.event_runtime.record_step(field.event_runtime.current_kind())
		expect(bool(result.get("accepted", false)), "%s steady 第 %d 步无法记录" % [event_id, guard])
		field._handle_event_step_result(result, completed_at)
	var live_mark_position := (
		Vector2((field.event_world_marks[-1] as Dictionary).get("position", Vector2.ZERO))
		if field.event_world_marks.size() == marks_before + 1
		else Vector2(INF, INF)
	)
	expect(
		field.event_world_marks.size() == marks_before + 1
		and live_mark_position.distance_to(actual_final_position) < 0.01,
		"%s 真正写入 event_world_marks 的标记没有落在反转点列末端" % event_id
	)
	while not field.event_runtime.is_finished() and field.event_runtime.current_index < checkpoint_event_count:
		if not complete_runtime_event(field.event_runtime):
			expect(false, "%s 完成后无法推进到 event %d checkpoint" % [event_id, checkpoint_event_count])
			break
	var checkpoint := field.event_runtime.checkpoint_snapshot()
	expect(not checkpoint.is_empty(), "%s 没有生成可恢复 checkpoint" % event_id)
	if checkpoint.is_empty():
		dispose_field(field)
		return
	checkpoint["level_id"] = level_id
	checkpoint["energy"] = 64.0
	checkpoint["elapsed_seconds"] = 210.0
	checkpoint["actions"] = 18
	var restored := configured_field(level, "progression", checkpoint)
	if restored == null:
		dispose_field(field)
		return
	var mechanic := String(normalized_event.get("mechanic", ""))
	var restored_positions: Array[Vector2] = []
	for mark in restored.event_world_marks:
		var mark_data := mark as Dictionary
		if (
			String(mark_data.get("mechanic", "")) == mechanic
			and String(mark_data.get("choice", "")) == "steady"
		):
			restored_positions.append(Vector2(mark_data.get("position", Vector2.ZERO)))
	var deterministic_position := restored._restored_event_mark_position(normalized_event, "steady")
	expect(
		restored_positions.size() == 1
		and restored_positions[0].distance_to(actual_final_position) < 0.01
		and deterministic_position.distance_to(actual_final_position) < 0.01,
		"%s checkpoint 恢复标记没有落在真实反向路线终点：live=%s restored=%s deterministic=%s"
		% [
			event_id,
			str(actual_final_position),
			str(restored_positions),
			str(deterministic_position),
		]
	)
	dispose_field(restored)
	dispose_field(field)


func verify_reverse_route_restored_marks(catalog) -> void:
	verify_reverse_route_mark_case(
		catalog,
		"spring_yushui",
		"yushui_07_blocked_gutter",
		EventRuntimeScript.EVENTS_PER_PENTAD * 2
	)
	verify_reverse_route_mark_case(
		catalog,
		"spring_guyu",
		"guyu_03_keeper_inventory",
		EventRuntimeScript.EVENTS_PER_PENTAD
	)


func verify_standard_objective_alignment(catalog) -> void:
	var level: Dictionary = catalog.level_by_id("spring_lichun")
	var field := configured_field(level)
	if field == null:
		return
	var collect_objective_index := 1
	var collect_task_index := task_index_for_type(field, "collect", collect_objective_index)
	expect(collect_task_index >= 0, "标准目标一致性回归找不到第二 objective 的真实任务")
	if collect_task_index >= 0:
		var task := field.tasks[collect_task_index] as Dictionary
		var target := Vector2(task.get("position", Vector2.ZERO))
		field.bee.position = target
		field.bee.velocity = Vector2.ZERO
		var navigation_target := field._navigation_target()
		var snapshot := field.status_snapshot()
		var hud_logic = CampaignGameScript.new()
		var objective_text := String(hud_logic._current_objective_text(snapshot))
		hud_logic.free()
		var expected_label := String(
			((level.get("objectives", []) as Array)[collect_objective_index] as Dictionary).get("label", "")
		)
		expect(
			navigation_target.distance_to(target) < 0.01
			and int(snapshot.get("active_objective_index", -1)) == collect_objective_index
			and expected_label in objective_text
			and String(snapshot.get("action_label", "")) == "收进蜜囊",
			"标准目标卡、导航和主动作没有同时指向当前 collect objective：nav=%.1f active=%d text=%s action=%s"
			% [
				navigation_target.distance_to(target),
				int(snapshot.get("active_objective_index", -1)),
				objective_text,
				String(snapshot.get("action_label", "")),
			]
		)
		var other_resolved_before := 0
		for other_task in field.tasks:
			other_resolved_before += 1 if bool((other_task as Dictionary).get("resolved", false)) else 0
		field.request_primary_action()
		var other_resolved_after := 0
		for other_task in field.tasks:
			other_resolved_after += 1 if bool((other_task as Dictionary).get("resolved", false)) else 0
		expect(
			bool((field.tasks[collect_task_index] as Dictionary).get("resolved", false))
			and field.collected_cargo == 1
			and other_resolved_after == other_resolved_before + 1,
			"标准主动作没有推进目标卡与导航所指的同一个 objective"
		)
		for _extra_load in field.CARGO_CAPACITY - 1:
			var next_collect_index := task_index_for_type(field, "collect", collect_objective_index)
			expect(next_collect_index >= 0, "装满蜜囊回归缺少可用 collect 任务")
			if next_collect_index < 0:
				break
			field.bee.position = Vector2((field.tasks[next_collect_index] as Dictionary).get("position", Vector2.ZERO))
			field.bee.velocity = Vector2.ZERO
			field.request_primary_action()
		var full_snapshot := field.status_snapshot()
		expect(
			field.collected_cargo == field.CARGO_CAPACITY
			and int(full_snapshot.get("active_objective_index", -1)) == collect_objective_index
			and field._navigation_target().distance_to(field.home_position) < 0.01
			and String(full_snapshot.get("action_label", "")) == "蜜囊已满，回巢卸货",
			"蜜囊装满后目标卡、导航和主动作没有共同指向真实卸货闭环"
		)
	dispose_field(field)


func verify_observation_lock_and_partial_cargo_return(catalog) -> void:
	var observation_field := configured_field(catalog.level_by_id("spring_chunfen"))
	if observation_field != null:
		var observe_index := task_index_for_type(observation_field, "observe")
		var collect_index := task_index_for_type(observation_field, "collect")
		expect(
			observe_index >= 0 and collect_index >= 0,
			"观察输入锁回归找不到观察与采集任务"
		)
		if observe_index >= 0 and collect_index >= 0:
			observation_field.bee.position = Vector2(
				(observation_field.tasks[observe_index] as Dictionary).get("position", Vector2.ZERO)
			)
			observation_field.bee.velocity = Vector2.ZERO
			observation_field.request_primary_action()
			var collect_task_before := (
				observation_field.tasks[collect_index] as Dictionary
			).duplicate(true)
			observation_field.bee.position = Vector2(
				collect_task_before.get("position", Vector2.ZERO)
			)
			observation_field.request_primary_action()
			var locked_snapshot := observation_field.status_snapshot()
			expect(
				observation_field.focus_task_index == observe_index
				and not bool((observation_field.tasks[collect_index] as Dictionary).get("resolved", false))
				and observation_field.collected_cargo == 0
				and not bool(locked_snapshot.get("action_enabled", true))
				and "正在观察" in observation_field.message,
				"观察期间键盘／手柄动作绕过禁用按钮，推进了另一项工作"
			)
		dispose_field(observation_field)

	var partial_field := configured_field(catalog.level_by_id("autumn_liqiu"))
	if partial_field == null:
		return
	var collect_objective_index := -1
	for index in partial_field.tasks.size():
		var task := partial_field.tasks[index] as Dictionary
		if String(task.get("type", "")) != "collect":
			continue
		collect_objective_index = int(task.get("objective_index", -1))
		partial_field.bee.position = Vector2(task.get("position", Vector2.ZERO))
		partial_field.bee.velocity = Vector2.ZERO
		partial_field.request_primary_action()
	for index in partial_field.tasks.size():
		var task := partial_field.tasks[index] as Dictionary
		if String(task.get("type", "")) == "collect":
			continue
		task["resolved"] = true
		task["state"] = 2
		partial_field.tasks[index] = task
		var objective_index := int(task.get("objective_index", -1))
		if objective_index >= 0:
			partial_field.objective_counts[objective_index] = partial_field.objective_goals[objective_index]
	partial_field.bee.position = non_rest_position(partial_field)
	partial_field.bee.velocity = Vector2.ZERO
	partial_field.bee.has_target = false
	var partial_snapshot := partial_field.status_snapshot()
	expect(
		partial_field.collected_cargo == 3
		and collect_objective_index >= 0
		and int(partial_snapshot.get("active_objective_index", -1)) == collect_objective_index
		and partial_field._navigation_target().distance_to(partial_field.home_position) < 0.01
		and String(partial_snapshot.get("action_label", "")) == "把这批送回主巢",
		"不足一整囊的最后一批收完后，目标卡、导航与动作没有共同指回主巢"
	)
	partial_field.request_primary_action()
	expect(
		partial_field.bee.has_target
		and partial_field.bee.target.distance_to(partial_field.home_position) < 0.01,
		"不足一整囊时按主动作没有真实导航到主巢"
	)
	partial_field.bee.position = partial_field.home_position
	partial_field.bee.velocity = Vector2.ZERO
	partial_field._process_chapter(0.08)
	expect(
		partial_field.collected_cargo == 0
		and partial_field.objective_counts[collect_objective_index]
			== partial_field.objective_goals[collect_objective_index]
		and partial_field.completion_emitted,
		"最后 1～3 份花蜜抵达主巢后没有逐份计入并完成真实交接"
	)
	dispose_field(partial_field)


func run_test() -> void:
	var catalog = CatalogScript.new()
	expect(catalog.catalog_valid, "系统契约测试无法加载正式战役目录：%s" % catalog.catalog_error)
	verify_all_level_energy_contract(catalog)
	verify_energy_tutorial_has_a_campaign_memory(catalog)
	verify_breather_and_standard_carry(catalog)
	verify_heavy_pouch_profile_and_evade_cost(catalog)
	verify_real_heavy_choice_and_continuous_cost(catalog)
	verify_discrete_energy_state_survives_field_tick(catalog)
	verify_checkpoint_energy_migration(catalog)
	verify_progression_and_replay_pentad_refill(catalog)
	verify_escort_shelter_restore_is_idempotent(catalog)
	verify_moving_event_mark_survives_checkpoint(catalog)
	verify_double_tap_uses_first_press_position(catalog)
	verify_mastery_lane_has_one_third_step_evade(catalog)
	verify_spare_sign_shortens_live_air_chase_mark(catalog)
	verify_low_energy_wrong_match_feedback(catalog)
	verify_reverse_route_restored_marks(catalog)
	verify_all_event_buttons(catalog)
	verify_accepted_optional_can_be_abandoned(catalog)
	verify_standard_objective_alignment(catalog)
	verify_observation_lock_and_partial_cargo_return(catalog)

	if failures.is_empty():
		print("CAMPAIGN SYSTEMIC CONTRACT TEST PASSED")
		print("TEST PASSED")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
