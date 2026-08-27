extends SceneTree

const CampaignStateScript := preload("res://scripts/world/journey_campaign_state.gd")
const CampaignFieldScript := preload("res://scripts/world/journey_campaign_field.gd")
const EventRuntimeScript := preload("res://scripts/world/journey_event_matrix_runtime.gd")
const SolarTermChronicleScript := preload("res://scripts/world/journey_solar_term_chronicle.gd")
const SoundScript := preload("res://scripts/sound_feedback.gd")
const CampaignScene := preload("res://campaign.tscn")
const V2_FIXTURE_PATH := "res://tests/fixtures/journey_campaign_v2_levels.json"


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


func load_v2_level_fixture() -> Dictionary:
	if not FileAccess.file_exists(V2_FIXTURE_PATH):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(V2_FIXTURE_PATH))
	return parsed as Dictionary if parsed is Dictionary else {}


func v2_save_from_fixture(fixture: Dictionary, completed_count: int) -> Dictionary:
	var levels: Array = fixture.get("levels", [])
	if completed_count < 0 or completed_count > levels.size():
		return {}
	var completed_ids: Array[String] = []
	var reward_ledger := {}
	var level_results := {}
	var best_results := {}
	var world_traces: Array[Dictionary] = []
	var reserve := 0
	var terms = SolarTermChronicleScript.new()
	for index in completed_count:
		var frozen := levels[index] as Dictionary
		var level_id := String(frozen.id)
		var reward := int(frozen.reward)
		var counts: Array = (frozen.get("goals", []) as Array).duplicate()
		var result := {
			"level_id": level_id,
			"number": index + 1,
			"run_mode": "progression",
			"reward": reward,
			"elapsed_seconds": 120.0 + float(index),
			"energy_remaining": 300.0 - float(index),
			"objective_counts": counts,
			"phases_completed": 3 if bool(frozen.climax) else 0,
			"actions": 8 + index,
		}
		completed_ids.append(level_id)
		reward_ledger[level_id] = reward
		level_results[level_id] = result.duplicate(true)
		best_results[level_id] = result.duplicate(true)
		world_traces.append({
			"level_id": level_id,
			"number": index + 1,
			"season_id": String(frozen.season_id),
			"trace": String(frozen.trace),
		})
		reserve += reward
		if terms.record_level(level_id, {}).is_empty():
			return {}
	return {
		"schema_version": int(fixture.get("schema_version", 0)),
		"campaign_id": String(fixture.get("campaign_id", "")),
		"reserve": reserve,
		"sortie_count": completed_count,
		"attempt_serial": completed_count,
		"completed_level_ids": completed_ids,
		"reward_ledger": reward_ledger,
		"level_results": level_results,
		"best_results": best_results,
		"world_traces": world_traces,
		"last_return_level_id": String(completed_ids[-1]) if completed_count > 0 else "",
		"last_reward": int((levels[completed_count - 1] as Dictionary).reward) if completed_count > 0 else 0,
		"title_revealed": completed_count > 0,
		"legacy_journey_completed": false,
		"journey_complete": completed_count == levels.size(),
		"solar_terms": terms.to_save_data(),
	}


func event_results_equivalent(left: Dictionary, right: Dictionary) -> bool:
	for list_key in ["completed_mandatory_ids", "completed_optional_ids", "skipped_optional_ids"]:
		if JSON.stringify(left.get(list_key, [])) != JSON.stringify(right.get(list_key, [])):
			return false
	if int(left.get("support_points", -1)) != int(right.get("support_points", -2)):
		return false
	var left_routes: Dictionary = left.get("route_choices", {})
	var right_routes: Dictionary = right.get("route_choices", {})
	if left_routes.size() != right_routes.size():
		return false
	for route_id in left_routes:
		if String(left_routes[route_id]) != String(right_routes.get(route_id, "")):
			return false
	var left_world: Dictionary = left.get("world_state", {})
	var right_world: Dictionary = right.get("world_state", {})
	for counter_key in [
		"observed_signals", "opened_route_segments", "delivered_loads", "caught_objects",
		"anchored_supports", "convoy_segments", "support_points", "bloom_stage",
	]:
		if int(left_world.get(counter_key, -1)) != int(right_world.get(counter_key, -2)):
			return false
	return (
		bool(left_world.get("setpiece_complete", false)) == bool(right_world.get("setpiece_complete", false))
		and left_world.get("route_choices", {}) == right_world.get("route_choices", {})
	)


func completion_payload(
	state: JourneyCampaignState,
	token: int,
	level: Dictionary,
	complete_optional := true
) -> Dictionary:
	var counts: Array[int] = []
	for objective in level.objectives:
		counts.append(int((objective as Dictionary).goal))
	var payload := {
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
	var matrix: Array = level.get("event_matrix", [])
	if not matrix.is_empty():
		# Event chapters prove completion through authored event IDs and world
		# consequences.  Zero compatibility counters make the test fail if state ever
		# falls back to the pre-v3 "fill every objective" shortcut.
		for index in counts.size():
			counts[index] = 0
		var runtime = EventRuntimeScript.new()
		if runtime.configure(matrix) == OK:
			while not runtime.is_finished():
				if runtime.optional_pending():
					if complete_optional:
						runtime.accept_optional()
					else:
						runtime.skip_optional()
						continue
				if runtime.choice_pending():
					runtime.choose_route("swift")
				if runtime.requires_evade():
					runtime.note_evade()
				runtime.record_step(runtime.current_kind())
			var event_snapshot := runtime.snapshot()
			payload["event_result"] = {
				"completed_mandatory_ids": event_snapshot.completed_mandatory_ids,
				"completed_optional_ids": event_snapshot.completed_optional_ids,
				"skipped_optional_ids": event_snapshot.skipped_optional_ids,
				"route_choices": event_snapshot.route_choices,
				"support_points": event_snapshot.support_points,
				"world_state": event_snapshot.world_state,
			}
	return payload


func pentad_checkpoint(level: Dictionary, completed_pentads: int) -> Dictionary:
	var runtime = EventRuntimeScript.new()
	if runtime.configure(level.get("event_matrix", [])) != OK:
		return {}
	var target_index := completed_pentads * EventRuntimeScript.EVENTS_PER_PENTAD
	var guard := 0
	while runtime.current_index < target_index and guard < 128:
		guard += 1
		var event := runtime.current_event()
		if runtime.optional_pending():
			# Exercise both sides of the saved optional partition instead of creating
			# a checkpoint in which every side activity happened to be accepted.
			if int(event.get("order", 0)) % 2 == 0:
				runtime.skip_optional()
				continue
			runtime.accept_optional()
		if runtime.choice_pending():
			runtime.choose_route("swift")
		if runtime.requires_evade():
			runtime.note_evade()
		runtime.record_step(runtime.current_kind())
	var checkpoint := runtime.checkpoint_snapshot()
	if checkpoint.is_empty():
		return {}
	checkpoint["level_id"] = String(level.get("id", ""))
	checkpoint["energy"] = 86.0 - float(completed_pentads * 7)
	checkpoint["elapsed_seconds"] = 91.25 * float(completed_pentads)
	checkpoint["actions"] = completed_pentads * 9
	return checkpoint


func progression_state_for(level_id: String) -> JourneyCampaignState:
	var prepared = CampaignStateScript.new()
	var guard := 0
	while prepared.next_segment_id() != level_id and not prepared.next_segment_id().is_empty() and guard < 24:
		guard += 1
		var prior: Dictionary = prepared.next_level()
		var token: int = prepared.begin_level(String(prior.get("id", "")))
		if token <= 0:
			break
		if prepared.settle_level(completion_payload(prepared, token, prior)).is_empty():
			break
	return prepared


func verify_restored_field_context(level_id: String, completed_pentads: int) -> void:
	var prepared := progression_state_for(level_id)
	expect(prepared.next_segment_id() == level_id, "%s 的真实进度 context 无法准备" % level_id)
	if prepared.next_segment_id() != level_id:
		return
	var level: Dictionary = prepared.catalog.level_by_id(level_id)
	var checkpoint := pentad_checkpoint(level, completed_pentads)
	var token: int = prepared.begin_level(level_id)
	expect(
		token > 0 and prepared.record_event_checkpoint(token, checkpoint),
		"%s 第 %d 候 checkpoint 无法进入真实 Campaign context" % [level_id, completed_pentads]
	)
	if token <= 0 or prepared.event_checkpoint.is_empty():
		return
	prepared.abandon_attempt(token)
	var resumed_token: int = prepared.begin_level(level_id)
	var context := prepared.active_level_context()
	expect(
		resumed_token > 0 and context.get("event_checkpoint", {}) == prepared.event_checkpoint,
		"%s 第 %d 候恢复没有使用 active_level_context" % [level_id, completed_pentads]
	)
	var field = CampaignFieldScript.new()
	var configure_error := field.configure(context)
	expect(
		configure_error == OK,
		"%s 第 %d 候真实 context 无法配置 Field" % [level_id, completed_pentads]
	)
	if configure_error != OK:
		field.free()
		return
	root.add_child(field)

	# add_child synchronously completes _ready, so these values are checked before
	# a process frame can add time.  This catches defaults silently replacing the
	# saved boundary values.
	var next_event_index := completed_pentads * EventRuntimeScript.EVENTS_PER_PENTAD
	var expected_event: Dictionary = (level.get("event_matrix", []) as Array)[next_event_index]
	expect(
		field.event_runtime.current_index == next_event_index
		and String(field.event_runtime.current_event().get("id", "")) == String(expected_event.get("id", ""))
		and field.event_runtime.current_progress == 0,
		"%s 第 %d 候没有从 event %d 的干净起点恢复" % [
			level_id, completed_pentads, next_event_index + 1,
		]
	)
	expect(
		is_equal_approx(field.bee.energy, float(checkpoint.get("energy", -1.0)))
		and is_equal_approx(field.elapsed, float(checkpoint.get("elapsed_seconds", -1.0)))
		and field.action_count == int(checkpoint.get("actions", -1)),
		"%s 第 %d 候 Field 没有恢复体力、用时或行动数" % [level_id, completed_pentads]
	)
	var expected_phases := completed_pentads if String(level.get("kind", "")) == "climax" else 0
	expect(
		field.phases_completed == expected_phases,
		"%s 第 %d 候恢复后的高潮阶段数错误" % [level_id, completed_pentads]
	)

	var completed_lookup := {}
	for completed_id in checkpoint.get("completed_mandatory_ids", []):
		completed_lookup[String(completed_id)] = true
	for completed_id in checkpoint.get("completed_optional_ids", []):
		completed_lookup[String(completed_id)] = true
	var expected_mark_events: Array[Dictionary] = []
	for event_index in next_event_index:
		# Use the configured runtime entry: it owns normalized step counts and kinds,
		# which are part of the deterministic restored marker position.
		var prior_event := field.event_runtime.events[event_index] as Dictionary
		if completed_lookup.has(String(prior_event.get("id", ""))):
			expected_mark_events.append(prior_event)
	expect(
		(checkpoint.get("skipped_optional_ids", []) as Array).size() > 0
		and field.event_world_marks.size() == expected_mark_events.size()
		and field.event_world_marks.size() < next_event_index,
		"%s 第 %d 候恢复后的世界标记混入了略过项" % [level_id, completed_pentads]
	)
	var route_choices: Dictionary = checkpoint.get("route_choices", {})
	for mark_index in mini(field.event_world_marks.size(), expected_mark_events.size()):
		var mark: Dictionary = field.event_world_marks[mark_index]
		var marked_event: Dictionary = expected_mark_events[mark_index]
		var choice := String(route_choices.get(String(marked_event.get("id", "")), ""))
		expect(
			String(mark.get("mechanic", "")) == String(marked_event.get("mechanic", ""))
			and bool(mark.get("optional", false)) == bool(marked_event.get("optional", false))
			and int(mark.get("pentad", 0)) == int(marked_event.get("pentad", -1))
			and Vector2(mark.get("position", Vector2.ZERO)).distance_to(
				field._restored_event_mark_position(marked_event, choice)
			) < 0.01,
			"%s 第 %d 候恢复标记并非逐项来自已完成事件" % [level_id, completed_pentads]
		)
	expect(
		not field.event_carrying
		and not field.event_observing
		and is_zero_approx(field.event_observe_time)
		and field.event_anchor_hits == 0
		and field.event_runtime.current_choice.is_empty()
		and not field.event_runtime.evade_registered
		and is_equal_approx(field.bee.visual_load_ratio, 0.0)
		and is_equal_approx(field.bee.load_speed_multiplier, 1.0)
		and is_equal_approx(field.bee.load_acceleration_multiplier, 1.0)
		and is_equal_approx(field.bee.load_dash_cost_multiplier, 1.0),
		"%s 第 %d 候把搬运、观察、急转或载荷瞬态跨场景带回来了" % [
			level_id, completed_pentads,
		]
	)
	field.queue_free()
	prepared.abandon_attempt(resumed_token)
	await process_frame


func verify_game_checkpoint_handler() -> void:
	var game = CampaignScene.instantiate()
	expect(game != null, "Game checkpoint handler 测试无法实例化 Campaign")
	if game == null:
		return
	var prepared := progression_state_for("spring_yushui")
	game.state = prepared
	var level: Dictionary = prepared.catalog.level_by_id("spring_yushui")
	var token: int = prepared.begin_level("spring_yushui")
	var checkpoint := pentad_checkpoint(level, 1)
	game._on_event_checkpoint_reached(checkpoint)
	expect(
		token > 0
		and prepared.active_token == token
		and prepared.event_checkpoint == checkpoint
		and prepared.active_level_context().get("event_checkpoint", {}) == checkpoint,
		"JourneyCampaignGame handler 没有把 Field 边界 payload 记录进当前状态"
	)
	game.free()


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
	expect(restored.restore_from_save_dictionary(save_data) == OK, "v3 正式战役存档无法恢复")
	expect(restored.completed_count() == 24 and restored.reserve == reserve_before_replay, "恢复后进度或资源改变")
	expect(restored.world_traces.size() == 24 and restored.solar_terms.unlocked_count() == 24, "恢复后痕迹或纪事丢失")
	var tampered := save_data.duplicate(true)
	tampered.reserve = int(tampered.reserve) + 1
	expect(CampaignStateScript.new().restore_from_save_dictionary(tampered) == ERR_INVALID_DATA, "篡改储备的战役存档被接纳")
	var skipped := save_data.duplicate(true)
	var skipped_ids: Array = []
	for id_index in (skipped.completed_level_ids as Array).size():
		skipped_ids.append(
			"summer_lixia" if id_index == 3 else String(skipped.completed_level_ids[id_index])
		)
	skipped.completed_level_ids = skipped_ids
	expect(CampaignStateScript.new().restore_from_save_dictionary(skipped) == ERR_INVALID_DATA, "跳关前缀的战役存档被接纳")

	# Event chapters settle from their authored event partition and deterministic
	# world result, not from the deprecated objective compatibility counters.
	var skipped_event_state = CampaignStateScript.new()
	var lichun: Dictionary = skipped_event_state.catalog.level_by_id("spring_lichun")
	var lichun_token: int = skipped_event_state.begin_level(String(lichun.id))
	skipped_event_state.settle_level(completion_payload(skipped_event_state, lichun_token, lichun))
	var yushui: Dictionary = skipped_event_state.catalog.level_by_id("spring_yushui")
	var yushui_token: int = skipped_event_state.begin_level(String(yushui.id))
	var yushui_payload := completion_payload(skipped_event_state, yushui_token, yushui, false)
	expect(
		(yushui_payload.objective_counts as Array).all(func(value: int): return value == 0)
		and skipped_event_state.can_settle_level(yushui_payload),
		"雨水仍依赖填满旧 objective_counts 才能结算"
	)
	var skipped_chronicle := skipped_event_state._chronicle_values(yushui, yushui_payload, int(yushui.reward_honey))
	expect(
		int(skipped_chronicle.pollinations) == 0
		and int(skipped_chronicle.deposit) == 0
		and int(skipped_chronicle.recovered_honey) == 0,
		"略过可选送粉后，纪事仍伪造了授粉或收蜜"
	)
	var skipped_settlement := skipped_event_state.settle_level(yushui_payload)
	var settled_event_result: Dictionary = skipped_settlement.result.event_result
	expect(
		(settled_event_result.completed_optional_ids as Array).is_empty()
		and (settled_event_result.skipped_optional_ids as Array).size() == 6
		and int(settled_event_result.support_points) == 0,
		"真实完成／略过的雨水事件分区没有进入结算"
	)
	var skipped_event_save := skipped_event_state.to_save_dictionary()
	var skipped_event_restored = CampaignStateScript.new()
	expect(
		skipped_event_restored.restore_from_save_dictionary(skipped_event_save) == OK
		and skipped_event_restored.level_results.spring_yushui.event_result == settled_event_result,
		"事件 ID、路线和世界状态没有完整存档往返"
	)
	var json_event_save = JSON.parse_string(JSON.stringify(skipped_event_save))
	var json_event_restored = CampaignStateScript.new()
	var json_restore_error := (
		json_event_restored.restore_from_save_dictionary(json_event_save)
		if json_event_save is Dictionary
		else ERR_INVALID_DATA
	)
	expect(
		json_restore_error == OK,
		"事件结果经真实 JSON 数字／数组往返后无法恢复"
	)
	if json_restore_error == OK:
		expect(
			event_results_equivalent(
				json_event_restored.level_results.spring_yushui.event_result,
				settled_event_result
			),
			"JSON 往返恢复后改写了事件结果语义"
		)
	var tampered_event_world := skipped_event_save.duplicate(true)
	tampered_event_world.level_results.spring_yushui.event_result.world_state.observed_signals = (
		int(tampered_event_world.level_results.spring_yushui.event_result.world_state.observed_signals) + 1
	)
	expect(
		CampaignStateScript.new().restore_from_save_dictionary(tampered_event_world) == ERR_INVALID_DATA,
		"篡改事件世界结果的存档被接纳"
	)
	var tampered_event_partition := skipped_event_save.duplicate(true)
	var forged_optional_id: String = String(tampered_event_partition.level_results.spring_yushui.event_result.skipped_optional_ids[0])
	tampered_event_partition.level_results.spring_yushui.event_result.completed_optional_ids.append(forged_optional_id)
	expect(
		CampaignStateScript.new().restore_from_save_dictionary(tampered_event_partition) == ERR_INVALID_DATA,
		"同一可选事件同时完成又略过的存档被接纳"
	)
	var tampered_route := skipped_event_save.duplicate(true)
	tampered_route.level_results.spring_yushui.event_result.route_choices.yushui_11_heavy_or_light = "secret"
	expect(
		CampaignStateScript.new().restore_from_save_dictionary(tampered_route) == ERR_INVALID_DATA,
		"未授权的路线选择被存档接纳"
	)

	# A field checkpoint is a whole-pentad restart point, not an active-scene
	# serialization.  It must move monotonically from event 6 to event 11, survive
	# leaving the field and a real JSON roundtrip, then disappear only after the
	# corresponding progression level settles.
	var checkpoint_state = CampaignStateScript.new()
	var checkpoint_lichun: Dictionary = checkpoint_state.catalog.level_by_id("spring_lichun")
	var checkpoint_lichun_token: int = checkpoint_state.begin_level(String(checkpoint_lichun.id))
	checkpoint_state.settle_level(
		completion_payload(checkpoint_state, checkpoint_lichun_token, checkpoint_lichun)
	)
	var checkpoint_yushui: Dictionary = checkpoint_state.catalog.level_by_id("spring_yushui")
	var checkpoint_token: int = checkpoint_state.begin_level(String(checkpoint_yushui.id))
	var first_pentad_checkpoint := pentad_checkpoint(checkpoint_yushui, 1)
	var second_pentad_checkpoint := pentad_checkpoint(checkpoint_yushui, 2)
	expect(
		int(first_pentad_checkpoint.get("next_event_number", 0)) == 6
		and int(first_pentad_checkpoint.get("pentads_completed", 0)) == 1,
		"候一运行时没有生成从第 6 项继续的合法 checkpoint"
	)
	expect(
		int(second_pentad_checkpoint.get("next_event_number", 0)) == 11
		and int(second_pentad_checkpoint.get("pentads_completed", 0)) == 2,
		"候二运行时没有生成从第 11 项继续的合法 checkpoint"
	)
	expect(
		not checkpoint_state.record_event_checkpoint(checkpoint_token + 1, first_pentad_checkpoint)
		and checkpoint_state.event_checkpoint.is_empty(),
		"错误尝试令牌写入了候级 checkpoint"
	)
	expect(
		checkpoint_state.record_event_checkpoint(checkpoint_token, first_pentad_checkpoint)
		and int(checkpoint_state.event_checkpoint.get("pentads_completed", 0)) == 1,
		"合法候一 checkpoint 被状态层拒绝"
	)
	expect(
		checkpoint_state.record_event_checkpoint(checkpoint_token, second_pentad_checkpoint)
		and int(checkpoint_state.event_checkpoint.get("pentads_completed", 0)) == 2,
		"合法候二 checkpoint 没有前移覆盖候一"
	)
	expect(
		not checkpoint_state.record_event_checkpoint(checkpoint_token, first_pentad_checkpoint)
		and int(checkpoint_state.event_checkpoint.get("pentads_completed", 0)) == 2,
		"状态层允许候二 checkpoint 回退到候一"
	)
	var invalid_live_checkpoint := second_pentad_checkpoint.duplicate(true)
	invalid_live_checkpoint.world_state.opened_route_segments = (
		int(invalid_live_checkpoint.world_state.opened_route_segments) + 1
	)
	var checkpoint_before_invalid_write: Dictionary = checkpoint_state.event_checkpoint.duplicate(true)
	expect(
		not checkpoint_state.record_event_checkpoint(checkpoint_token, invalid_live_checkpoint)
		and checkpoint_state.event_checkpoint == checkpoint_before_invalid_write,
		"候级 checkpoint 校验失败后改写了上一份合法状态"
	)
	expect(
		checkpoint_state.abandon_attempt(checkpoint_token)
		and int(checkpoint_state.event_checkpoint.get("next_event_number", 0)) == 11,
		"离开当前花田时误删了已落盘的候级 checkpoint"
	)
	var checkpoint_save := checkpoint_state.to_save_dictionary()
	var checkpoint_json = JSON.parse_string(JSON.stringify(checkpoint_save))
	var checkpoint_restored = CampaignStateScript.new()
	var checkpoint_restore_error := (
		checkpoint_restored.restore_from_save_dictionary(checkpoint_json)
		if checkpoint_json is Dictionary
		else ERR_INVALID_DATA
	)
	expect(checkpoint_restore_error == OK, "候级 checkpoint 无法通过真实 JSON 存档往返")
	if checkpoint_restore_error == OK:
		var resumed_token: int = checkpoint_restored.begin_level("spring_yushui")
		var resumed_context := checkpoint_restored.active_level_context()
		var resumed_checkpoint: Dictionary = resumed_context.get("event_checkpoint", {})
		expect(
			resumed_token > 0
			and int(resumed_checkpoint.get("next_event_number", 0)) == 11
			and is_equal_approx(float(resumed_checkpoint.get("energy", -1.0)), float(second_pentad_checkpoint.energy))
			and int(resumed_checkpoint.get("actions", -1)) == int(second_pentad_checkpoint.actions),
			"恢复存档后 begin context 没有交回完整的候二 checkpoint"
		)
		var resumed_payload := completion_payload(
			checkpoint_restored,
			resumed_token,
			checkpoint_yushui
		)
		expect(
			not checkpoint_restored.settle_level(resumed_payload).is_empty()
			and checkpoint_restored.event_checkpoint.is_empty(),
			"对应关卡合法结算后没有清除候级 checkpoint"
		)
		var checkpoint_replay_token: int = checkpoint_restored.begin_level("spring_yushui", true)
		expect(
			checkpoint_replay_token > 0
			and not checkpoint_restored.record_event_checkpoint(
				checkpoint_replay_token,
				first_pentad_checkpoint
			)
			and checkpoint_restored.event_checkpoint.is_empty(),
			"重玩模式写入了会污染正式进度的候级 checkpoint"
		)
		checkpoint_restored.abandon_attempt(checkpoint_replay_token)
	var tampered_checkpoint := checkpoint_save.duplicate(true)
	tampered_checkpoint.event_checkpoint.world_state.observed_signals = (
		int(tampered_checkpoint.event_checkpoint.world_state.observed_signals) + 1
	)
	expect(
		CampaignStateScript.new().restore_from_save_dictionary(tampered_checkpoint) == ERR_INVALID_DATA,
		"篡改候级 checkpoint 世界状态的存档被接纳"
	)
	var malformed_checkpoint := checkpoint_save.duplicate(true)
	malformed_checkpoint.event_checkpoint.next_event_number = 7
	expect(
		CampaignStateScript.new().restore_from_save_dictionary(malformed_checkpoint) == ERR_INVALID_DATA,
		"非候边界的 checkpoint 被存档恢复接纳"
	)
	await verify_restored_field_context("spring_yushui", 1)
	await verify_restored_field_context("spring_yushui", 2)
	await verify_restored_field_context("spring_guyu", 1)
	await verify_restored_field_context("spring_guyu", 2)
	verify_game_checkpoint_handler()

	# Real v2 fixtures are frozen from the pre-v3 catalog in git HEAD, not rebuilt
	# from today's live objectives. Yushui's historical [2,3,4] result is the
	# regression boundary which the previous synthetic test accidentally hid.
	var v2_fixture := load_v2_level_fixture()
	var fixture_levels: Array = v2_fixture.get("levels", [])
	var frozen_yushui_goals: Array = (
		(fixture_levels[1] as Dictionary).get("goals", []) if fixture_levels.size() > 1 else []
	)
	expect(
		String(v2_fixture.get("source", "")) == "git show HEAD:godot/data/journey_levels.json"
		and fixture_levels.size() == 24
		and frozen_yushui_goals.size() == 3
		and int(frozen_yushui_goals[0]) == 2
		and int(frozen_yushui_goals[1]) == 3
		and int(frozen_yushui_goals[2]) == 4
		and state.catalog.level_at(1).objectives.size() == 2,
		"v2 fixture 没有归档真实旧雨水三目标，或再次偷用了当前目录"
	)
	for old_completed_count in [2, 6, 24]:
		var real_v2_save := v2_save_from_fixture(v2_fixture, old_completed_count)
		var migrated_v2 = CampaignStateScript.new()
		expect(
			not real_v2_save.is_empty()
			and migrated_v2.restore_from_save_dictionary(real_v2_save) == OK,
			"真实 v2 %d/24 存档无法迁移" % old_completed_count
		)
		expect(
			migrated_v2.completed_level_ids == ["spring_lichun"]
			and migrated_v2.next_segment_id() == "spring_yushui"
			and not migrated_v2.is_level_completed("spring_yushui")
			and not migrated_v2.is_level_completed("spring_guyu")
			and migrated_v2.reserve == int(lichun.reward_honey)
			and migrated_v2.level_results.size() == 1,
			"旧 v2 %d/24 结果被冒充成 v3 雨水／谷雨事件完成" % old_completed_count
		)
		expect(
			int(migrated_v2.legacy_campaign_progress.completed_count) == old_completed_count
			and bool(migrated_v2.legacy_campaign_progress.journey_complete) == (old_completed_count == 24)
			and migrated_v2.event_checkpoint.is_empty(),
			"v2 %d/24 历史进度没有完整进入只读纪念摘要" % old_completed_count
		)
		var migrated_roundtrip = CampaignStateScript.new()
		expect(
			migrated_roundtrip.restore_from_save_dictionary(migrated_v2.to_save_dictionary()) == OK
			and int(migrated_roundtrip.legacy_campaign_progress.completed_count) == old_completed_count
			and migrated_roundtrip.next_segment_id() == "spring_yushui",
			"v2 %d/24 迁移结果没有进入稳定 v3 存档" % old_completed_count
		)
	var tampered_v2 := v2_save_from_fixture(v2_fixture, 2)
	tampered_v2.level_results.spring_yushui.objective_counts[0] = 0
	expect(
		CampaignStateScript.new().restore_from_save_dictionary(tampered_v2) == ERR_INVALID_DATA,
		"低于冻结 v2 目标的旧结果被迁移"
	)
	var v3_shaped_fake_v2 := v2_save_from_fixture(v2_fixture, 2)
	v3_shaped_fake_v2.level_results.spring_yushui.objective_counts = [9, 6]
	expect(
		CampaignStateScript.new().restore_from_save_dictionary(v3_shaped_fake_v2) == ERR_INVALID_DATA,
		"套用当前 v3 雨水目标伪造的 v2 结果被接受"
	)

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
	expect(
		is_equal_approx(standard_field.bee.max_energy, 100.0)
			and is_equal_approx(standard_field.bee.energy, 100.0),
		"正式战役体力没有改为一眼可读的 100 制"
	)
	var rightmost_bee_center := Vector2(
		standard_field.playable_bounds.end.x - 18.0,
		standard_field.home_position.y
	)
	expect(
		standard_field.projected_screen_position(rightmost_bee_center).x
			+ standard_field.BEE_VISUAL_SAFE_EXTENTS.x
			<= standard_field.CAMPAIGN_HUD_SAFE_RECT.end.x + 0.01,
		"正式战役右边界仍允许整只蜂飞进 HUD 遮挡区"
	)
	for generated_task in standard_field.tasks:
		for generated_position in [
			Vector2(generated_task.position),
			Vector2(generated_task.source_position),
		]:
			expect(
				standard_field.projected_screen_position(generated_position).x
					+ standard_field.TASK_MARKER_SAFE_EXTENT
					<= standard_field.CAMPAIGN_HUD_SAFE_RECT.end.x + 0.01,
				"正式战役任务标记生成到了右侧 HUD 后面"
			)

	# Campaign energy is a short, visible loop: waiting is free, a brief cruise is
	# cheap, sustained acceleration costs more, and a shelter takes time to refill.
	standard_field.bee.energy = 80.0
	standard_field.bee.velocity = Vector2.ZERO
	standard_field.bee.has_target = false
	standard_field.bee.move_duration = 0.0
	standard_field.bee._physics_process(0.5)
	expect(is_equal_approx(standard_field.bee.energy, 80.0), "原地看路线仍在暗中消耗战役体力")
	standard_field.bee.set_move_target(standard_field.bee.position + Vector2(700.0, 0.0))
	standard_field.bee._physics_process(0.5)
	var energy_after_short_cruise: float = standard_field.bee.energy
	standard_field.bee._physics_process(0.5)
	expect(
		80.0 - energy_after_short_cruise < 1.0
			and energy_after_short_cruise - standard_field.bee.energy > 1.0,
		"短巡航与持续加速没有形成清楚不同的体力成本"
	)
	standard_field.bee.has_target = false
	standard_field.bee.velocity = Vector2.ZERO
	standard_field.bee.position = standard_field.rest_points[0]
	standard_field.bee.energy = 40.0
	standard_field._process_chapter(1.0)
	expect(
		standard_field.bee.energy >= 47.9 and standard_field.bee.energy < standard_field.bee.max_energy,
		"叶棚休息没有稳定缓慢恢复，或一碰就瞬间回满"
	)
	standard_field.bee.position = standard_field.home_position
	standard_field.bee.energy = 0.0
	standard_field._process_chapter(0.1)
	expect(
		not standard_field.failed
			and not standard_field.completion_emitted
			and standard_field.bee.environment_speed_multiplier <= 0.46,
		"战役体力归零仍触发失败，或没有进入可慢飞的疲惫态"
	)

	# Keyboard/gamepad directions and pointer/touch share the same active urgent
	# turn. The second tap spends a visible fixed cost and produces campaign text,
	# while ordinary flight remains available even when that cost cannot be paid.
	standard_field.bee.energy = 50.0
	standard_field.bee.evade_cooldown = 0.0
	standard_field.bee.evade_time = 0.0
	standard_field.evade_input_controller.clear(standard_field.bee)
	standard_field.evade_input_controller.register_direction_tap(
		"up", Vector2.UP, 20.0, standard_field.bee
	)
	var campaign_evade_result: Dictionary = standard_field.evade_input_controller.register_direction_tap(
		"up", Vector2.UP, 20.1, standard_field.bee
	)
	standard_field._play_evade_result(campaign_evade_result)
	expect(
		bool(campaign_evade_result.evade_started)
			and is_equal_approx(standard_field.bee.energy, 38.0)
			and "体力 -12" in standard_field.message,
		"正式战役没有接入带明确响应与成本的双击急转"
	)
	standard_field.bee.position = standard_field.home_position
	standard_field.bee.velocity = Vector2.ZERO
	standard_field.bee.energy = 50.0
	standard_field.bee.evade_time = 0.0
	standard_field.bee.evade_cooldown = 0.0
	standard_field.evade_input_controller.clear(standard_field.bee)
	var touch_target: Vector2 = Vector2(standard_field.home_position) + Vector2(160.0, 0.0)
	standard_field.evade_input_controller.handle_world_tap(
		touch_target, 30.0, standard_field.bee, standard_field.playable_bounds, true
	)
	var campaign_touch_evade: Dictionary = standard_field.evade_input_controller.handle_world_tap(
		touch_target, 30.1, standard_field.bee, standard_field.playable_bounds, true
	)
	expect(
		bool(campaign_touch_evade.evade_started)
			and is_equal_approx(standard_field.bee.energy, 38.0),
		"正式战役触屏／鼠标的重复方向点击没有发动同一套急转"
	)
	standard_field.bee.energy = standard_field.bee.max_energy
	standard_field.bee.evade_time = 0.0
	standard_field.bee.evade_cooldown = 0.0
	standard_field.bee.velocity = Vector2.ZERO
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
	expect(
		climax_field.is_climax
			and climax_field.event_matrix_mode
			and climax_field.tasks.is_empty()
			and climax_field.event_runtime.event_count() == 15,
		"谷雨季末关没有用三候十五项 mechanic 运行时取代旧九任务"
	)
	expect(String(climax_field.status_snapshot().phase_instruction).length() > 12, "季末阶段缺少具体行动说明")
	var climax_payload_holder := {"payload": {}}
	climax_field.journey_completed.connect(
		func(payload: Dictionary): climax_payload_holder.payload = payload.duplicate(true)
	)
	climax_field.force_complete_for_test()
	await process_frame
	var climax_payload: Dictionary = climax_payload_holder.payload
	expect(
		climax_payload.has("event_result")
		and climax_state.can_settle_level(climax_payload),
		"谷雨实景没有提交可验证的事件 ID／路线／世界结果合同"
	)
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
