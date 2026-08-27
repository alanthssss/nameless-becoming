class_name JourneyCampaignState
extends RefCounted

## Checkpoint-safe progression for the formal solar-term campaign. A field can
## report what happened, but this object alone decides whether a completion is
## legal and how much permanent reserve it earns.

const LevelCatalogScript := preload("res://scripts/world/journey_level_catalog.gd")
const SolarTermChronicleScript := preload("res://scripts/world/journey_solar_term_chronicle.gd")
const LegacyJourneyStateScript := preload("res://scripts/world/journey_state.gd")
const EventMatrixRuntimeScript := preload("res://scripts/world/journey_event_matrix_runtime.gd")
const SAVE_SCHEMA_VERSION := 3
const PREVIOUS_CAMPAIGN_SCHEMA_VERSION := 2
const PREVIOUS_CAMPAIGN_ID := "solar-term-campaign-v2"
const RUN_PROGRESSION := "progression"
const RUN_REPLAY := "replay"
const CHECKPOINT_ENERGY_CAP := 100.0
## Frozen from `git show HEAD:godot/data/journey_levels.json` when campaign v2
## was the shipping schema. Migration must never validate historical results
## against a later live catalog: Yushui already changed from [2,3,4] to an event
## contract, and later edits may change more levels without changing this reader.
const V2_FROZEN_LEVELS := [
	{"id":"spring_lichun","season_id":"spring","reward":6,"climax":false,"goals":[2,6],"trace":"巢内第一格蜜架填满，接货落点开始运转。"},
	{"id":"spring_yushui","season_id":"spring","reward":4,"climax":false,"goals":[2,3,4],"trace":"叶沟形成稳定滴水线，之后能认作安全路线。"},
	{"id":"spring_jingzhe","season_id":"spring","reward":5,"climax":false,"goals":[3,4,5],"trace":"四枚种核留在花田，秋季会长成可处理的种头。"},
	{"id":"spring_chunfen","season_id":"spring","reward":8,"climax":false,"goals":[2,8],"trace":"主巢增加第二个接货落点，内侧蜜架多一排。"},
	{"id":"spring_qingming","season_id":"spring","reward":3,"climax":false,"goals":[3,3,1],"trace":"三块天气与绕行花标永久留在春图。"},
	{"id":"spring_guyu","season_id":"spring","reward":6,"climax":true,"goals":[3],"trace":"花标成为全年路线系统，蚊庄主继续在自己的花地翻牌。"},
	{"id":"summer_lixia","season_id":"summer","reward":4,"climax":false,"goals":[2,5],"trace":"花标旁增加叶荫方向记号。"},
	{"id":"summer_xiaoman","season_id":"summer","reward":4,"climax":false,"goals":[4,4],"trace":"守卫蜂改成新的巡飞环线，花田出现接应点。"},
	{"id":"summer_mangzhong","season_id":"summer","reward":3,"climax":false,"goals":[3,3],"trace":"三件材料按施工顺序摆在小蜂房旁。"},
	{"id":"summer_xiazhi","season_id":"summer","reward":3,"climax":false,"goals":[3,3],"trace":"小蜂房出现横梁和叶棚骨架。"},
	{"id":"summer_xiaoshu","season_id":"summer","reward":3,"climax":false,"goals":[3,1],"trace":"小蜂房正式可以有限休息，但仍不替主巢交货。"},
	{"id":"summer_dashu","season_id":"summer","reward":7,"climax":true,"goals":[3],"trace":"小蜂房留下完整遮阴棚、蜡补和三处风扣。"},
	{"id":"autumn_liqiu","season_id":"autumn","reward":4,"climax":false,"goals":[3,3],"trace":"地图保留短花梗、种头和未动花的混合样貌。"},
	{"id":"autumn_chushu","season_id":"autumn","reward":7,"climax":false,"goals":[1,7],"trace":"花区留下短梗，巢内秋蜜架真实填充。"},
	{"id":"autumn_bailu","season_id":"autumn","reward":2,"climax":false,"goals":[5,2],"trace":"一排种头留在秋图，后续霜线会绕出不同路径。"},
	{"id":"autumn_qiufen","season_id":"autumn","reward":2,"climax":false,"goals":[3,3],"trace":"三只种壳成为秋图永久路线标记。"},
	{"id":"autumn_hanlu","season_id":"autumn","reward":4,"climax":false,"goals":[3,3,3],"trace":"玩家真实完成的收蜜与留种组合长期留在花田。"},
	{"id":"autumn_shuangjiang","season_id":"autumn","reward":5,"climax":true,"goals":[3],"trace":"重排种壳、混合花田和画眉常来歇脚的停栖点长期保留。"},
	{"id":"winter_lidong","season_id":"winter","reward":2,"climax":false,"goals":[3,3],"trace":"三个暖点永久出现在冬图。"},
	{"id":"winter_xiaoxue","season_id":"winter","reward":2,"climax":false,"goals":[2,4],"trace":"换班蜂流开始沿连续暖路运行。"},
	{"id":"winter_daxue","season_id":"winter","reward":2,"climax":false,"goals":[3,3],"trace":"挡风墙拉绳和木钉框架留在施工区。"},
	{"id":"winter_dongzhi","season_id":"winter","reward":2,"climax":false,"goals":[2,2],"trace":"两段挡风木出现在施工区，大熊在旁休息。"},
	{"id":"winter_xiaohan","season_id":"winter","reward":2,"climax":false,"goals":[2,3],"trace":"三段墙体基本成形，只剩最后一个转角。"},
	{"id":"winter_dahan","season_id":"winter","reward":3,"climax":true,"goals":[3],"trace":"花标、小蜂房、种头、种壳、暖路和挡风墙同时留在世界里。"},
]

var catalog = LevelCatalogScript.new()
var solar_terms = SolarTermChronicleScript.new()
var reserve := 0
var sortie_count := 0
var attempt_serial := 0
var active_token := -1
var settled_token := -1
var active_level_id := ""
var active_run_mode := ""
var completed_level_ids: Array[String] = []
var reward_ledger: Dictionary = {}
var level_results: Dictionary = {}
var best_results: Dictionary = {}
var world_traces: Array[Dictionary] = []
var last_return_level_id := ""
var last_reward := 0
var title_revealed := false
var legacy_journey_completed := false
var legacy_campaign_progress: Dictionary = {}
var event_checkpoint: Dictionary = {}
var journey_complete := false


func is_ready() -> bool:
	return catalog.catalog_valid and solar_terms.catalog_valid


func completed_count() -> int:
	return completed_level_ids.size()


func next_segment_id() -> String:
	return catalog.first_incomplete_id(completed_count()) if is_ready() else ""


func next_level() -> Dictionary:
	return catalog.level_at(completed_count()) if is_ready() else {}


func is_level_completed(level_id: String) -> bool:
	return level_id in completed_level_ids


func can_begin_level(level_id: String, replay := false) -> bool:
	if not is_ready() or not active_level_id.is_empty() or not catalog.has_level(level_id):
		return false
	if replay:
		return is_level_completed(level_id)
	return level_id == next_segment_id()


func begin_level(level_id: String, replay := false) -> int:
	if not can_begin_level(level_id, replay):
		return -1
	sortie_count += 1
	attempt_serial += 1
	active_token = attempt_serial
	settled_token = -1
	active_level_id = level_id
	active_run_mode = RUN_REPLAY if replay else RUN_PROGRESSION
	return active_token


func active_level_context() -> Dictionary:
	if active_level_id.is_empty():
		return {}
	var context := {
		"campaign_mode": true,
		"journey_token": active_token,
		"level": catalog.level_by_id(active_level_id),
		"run_mode": active_run_mode,
		"reserve": reserve,
		"sortie_count": sortie_count,
		"world_results": world_memory(),
	}
	if active_run_mode == RUN_PROGRESSION and String(event_checkpoint.get("level_id", "")) == active_level_id:
		context["event_checkpoint"] = event_checkpoint.duplicate(true)
	return context


func record_event_checkpoint(token: int, raw_checkpoint: Dictionary) -> bool:
	if (
		active_level_id.is_empty()
		or token != active_token
		or active_run_mode != RUN_PROGRESSION
	):
		return false
	var level := catalog.level_by_id(active_level_id)
	var validated_value = _validated_event_checkpoint(raw_checkpoint, level)
	if validated_value == null:
		return false
	var validated := validated_value as Dictionary
	if not event_checkpoint.is_empty():
		if String(event_checkpoint.get("level_id", "")) != active_level_id:
			return false
		var previous_number := int(event_checkpoint.get("next_event_number", 0))
		var next_number := int(validated.get("next_event_number", 0))
		if next_number < previous_number:
			return false
		if next_number == previous_number:
			return validated == event_checkpoint
	event_checkpoint = validated.duplicate(true)
	return true


func event_checkpoint_for_level(level_id: String) -> Dictionary:
	if String(event_checkpoint.get("level_id", "")) != level_id:
		return {}
	return event_checkpoint.duplicate(true)


func abandon_attempt(token: int) -> bool:
	if active_level_id.is_empty() or token != active_token or token == settled_token:
		return false
	active_level_id = ""
	active_run_mode = ""
	active_token = -1
	return true


func can_settle_level(payload: Dictionary) -> bool:
	if active_level_id.is_empty() or active_token < 0:
		return false
	if int(payload.get("journey_token", -2)) != active_token or active_token == settled_token:
		return false
	if String(payload.get("level_id", "")) != active_level_id:
		return false
	if (
		typeof(payload.get("objectives_complete", null)) != TYPE_BOOL
		or not bool(payload.objectives_complete)
		or typeof(payload.get("returned_home", null)) != TYPE_BOOL
		or not bool(payload.returned_home)
	):
		return false
	if typeof(payload.get("failed", null)) != TYPE_BOOL or bool(payload.failed):
		return false
	var level := catalog.level_by_id(active_level_id)
	var objectives = level.get("objectives", [])
	var counts = payload.get("objective_counts", [])
	if not objectives is Array or not counts is Array or counts.size() != objectives.size():
		return false
	var event_matrix: Array = level.get("event_matrix", [])
	for index in objectives.size():
		if not _is_saved_integer(counts[index]) or int(counts[index]) < 0:
			return false
		if event_matrix.is_empty() and int(counts[index]) < int((objectives[index] as Dictionary).get("goal", 0)):
			return false
	if not event_matrix.is_empty() and _validated_event_result(payload.get("event_result", null), level).is_empty():
		return false
	if String(level.get("kind", "")) == "climax" and int(payload.get("phases_completed", 0)) != 3:
		return false
	var elapsed_value = payload.get("elapsed_seconds", -1.0)
	if (
		typeof(elapsed_value) not in [TYPE_INT, TYPE_FLOAT]
		or not is_finite(float(elapsed_value))
		or float(elapsed_value) < 0.0
	):
		return false
	return true


func settle_level(payload: Dictionary) -> Dictionary:
	if not can_settle_level(payload):
		return {}
	var level := catalog.level_by_id(active_level_id)
	var level_id := active_level_id
	var replay := active_run_mode == RUN_REPLAY
	var reward := 0 if replay else int(level.get("reward_honey", 0))
	var result := _sanitized_result(payload, level, replay, reward)
	settled_token = active_token
	last_return_level_id = level_id
	last_reward = reward
	if not replay:
		# Progression can only begin at next_segment_id(), so append is both ordered
		# and exact-once. Reward values come from the catalog, never from the scene.
		completed_level_ids.append(level_id)
		reward_ledger[level_id] = reward
		reserve += reward
		level_results[level_id] = result.duplicate(true)
		world_traces.append({
			"level_id": level_id,
			"number": int(level.number),
			"season_id": String(level.season_id),
			"trace": String(level.world_trace),
		})
		var chronicle_values := _chronicle_values(level, payload, reward)
		if solar_terms.record_level(level_id, chronicle_values).is_empty():
			# This is an invariant failure, not a recoverable field result. Roll back
			# all permanent facts rather than leave a split ledger.
			completed_level_ids.pop_back()
			reward_ledger.erase(level_id)
			reserve -= reward
			level_results.erase(level_id)
			world_traces.pop_back()
			settled_token = -1
			return {}
	_update_best_result(level_id, result)
	if not replay and String(event_checkpoint.get("level_id", "")) == level_id:
		event_checkpoint.clear()
	journey_complete = completed_count() == JourneyLevelCatalog.TOTAL_LEVELS
	active_level_id = ""
	active_run_mode = ""
	active_token = -1
	return {
		"accepted": true,
		"replay": replay,
		"reward": reward,
		"reserve": reserve,
		"completed_count": completed_count(),
		"journey_complete": journey_complete,
		"level": level,
		"result": result,
	}


func _sanitized_result(payload: Dictionary, level: Dictionary, replay: bool, reward: int) -> Dictionary:
	var counts: Array[int] = []
	for value in payload.get("objective_counts", []):
		counts.append(maxi(0, int(value)))
	var result := {
		"level_id": String(level.id),
		"number": int(level.number),
		"run_mode": RUN_REPLAY if replay else RUN_PROGRESSION,
		"reward": reward,
		"elapsed_seconds": maxf(0.0, float(payload.get("elapsed_seconds", 0.0))),
		"energy_remaining": maxf(0.0, float(payload.get("energy_remaining", 0.0))),
		"objective_counts": counts,
		"phases_completed": clampi(int(payload.get("phases_completed", 0)), 0, 3),
		"actions": maxi(0, int(payload.get("actions", 0))),
	}
	if not (level.get("event_matrix", []) as Array).is_empty():
		result["event_result"] = _validated_event_result(payload.get("event_result", null), level)
	return result


func _update_best_result(level_id: String, result: Dictionary) -> void:
	var previous = best_results.get(level_id)
	if not previous is Dictionary or float(result.elapsed_seconds) < float((previous as Dictionary).get("elapsed_seconds", INF)):
		best_results[level_id] = result.duplicate(true)


func _chronicle_values(level: Dictionary, payload: Dictionary, reward: int) -> Dictionary:
	var values := {
		"deposit": reward,
		"pollinations": 0,
		"honey_lost": 0,
		"recovered_honey": 0,
		"belongings_recovered": 0,
		"harvested": 0,
		"seeded": 0,
		"echo_points": 0,
		"warmth_links": 0,
		"windbreak_segments": 0,
	}
	var event_matrix: Array = level.get("event_matrix", [])
	if not event_matrix.is_empty():
		# Event-matrix chapters record only authored events the player actually
		# completed.  The old objective counters are presentation compatibility and
		# must not turn a skipped side event into fictional pollen or honey.
		values.deposit = 0
		var event_result := _validated_event_result(payload.get("event_result", null), level)
		var completed := {}
		for event_id in event_result.get("completed_mandatory_ids", []):
			completed[String(event_id)] = true
		for event_id in event_result.get("completed_optional_ids", []):
			completed[String(event_id)] = true
		for event in event_matrix:
			var event_id := String((event as Dictionary).get("id", ""))
			if not completed.has(event_id):
				continue
			match String((event as Dictionary).get("mechanic", "")):
				"pollen_delivery": values.pollinations += 1
				"weather_window", "route_reveal", "trace_search", "weather_reread": values.echo_points += 1
				"coop_anchor", "convoy_anchor": values.windbreak_segments += 1
		return values
	var counts: Array = payload.get("objective_counts", [])
	var objectives: Array = level.get("objectives", [])
	for index in mini(counts.size(), objectives.size()):
		var objective := objectives[index] as Dictionary
		var count := int(counts[index])
		match String(objective.get("type", "")):
			"pollinate": values.pollinations += count
			"collect":
				values.deposit = count
				values.recovered_honey += count
				if String(level.get("season_id", "")) == "autumn":
					values.harvested += count
			"carry": values.belongings_recovered += count
			"seed": values.seeded += count
			"observe": values.echo_points += count
			"warmth": values.warmth_links += count
			"repair", "anchor": values.windbreak_segments += count
	return values


func mark_title_revealed() -> void:
	title_revealed = true


func level_select_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var next_id := next_segment_id()
	for level in catalog.levels():
		var level_id := String(level.id)
		var completed := is_level_completed(level_id)
		var entry := level.duplicate(true)
		entry["completed"] = completed
		entry["available"] = completed or level_id == next_id
		entry["replay"] = completed
		entry["best"] = Dictionary(best_results.get(level_id, {})).duplicate(true)
		entries.append(entry)
	return entries


func world_memory() -> Dictionary:
	var season_counts := {"spring": 0, "summer": 0, "autumn": 0, "winter": 0}
	for level_id in completed_level_ids:
		var level := catalog.level_by_id(level_id)
		var season_id := String(level.get("season_id", ""))
		if season_counts.has(season_id):
			season_counts[season_id] = int(season_counts[season_id]) + 1
	return {
		"completed_count": completed_count(),
		"season_counts": season_counts,
		"traces": world_traces.duplicate(true),
		"legacy_journey_completed": legacy_journey_completed,
		"legacy_campaign_progress": legacy_campaign_progress.duplicate(true),
	}


func hive_context(returning := false) -> Dictionary:
	return {
		"campaign_mode": true,
		"returning": returning,
		"return_level_id": last_return_level_id if returning else "",
		"reward": last_reward if returning else 0,
		"reserve": reserve,
		"completed_count": completed_count(),
		"total_count": JourneyLevelCatalog.TOTAL_LEVELS,
		"journey_complete": journey_complete,
		"next_level": next_level(),
		"level_entries": level_select_entries(),
		"world_results": world_memory(),
		"solar_terms": solar_terms.progress_snapshot(),
		"legacy_journey_completed": legacy_journey_completed,
		"legacy_campaign_progress": legacy_campaign_progress.duplicate(true),
	}


func to_save_dictionary() -> Dictionary:
	return {
		"schema_version": SAVE_SCHEMA_VERSION,
		"campaign_id": catalog.campaign_id,
		"reserve": reserve,
		"sortie_count": sortie_count,
		"attempt_serial": attempt_serial,
		"completed_level_ids": completed_level_ids.duplicate(),
		"reward_ledger": reward_ledger.duplicate(true),
		"level_results": level_results.duplicate(true),
		"best_results": best_results.duplicate(true),
		"world_traces": world_traces.duplicate(true),
		"last_return_level_id": last_return_level_id,
		"last_reward": last_reward,
		"title_revealed": title_revealed,
		"legacy_journey_completed": legacy_journey_completed,
		"legacy_campaign_progress": legacy_campaign_progress.duplicate(true),
		"event_checkpoint": event_checkpoint.duplicate(true),
		"journey_complete": journey_complete,
		"solar_terms": solar_terms.to_save_data(),
	}


func restore_from_save_dictionary(data: Dictionary) -> Error:
	if not data.has("campaign_id"):
		return _restore_legacy_journey(data)
	if not _is_saved_integer(data.get("schema_version", null)) or not data.get("campaign_id", null) is String:
		return ERR_INVALID_DATA
	var schema_version := int(data.get("schema_version", 0))
	if schema_version == PREVIOUS_CAMPAIGN_SCHEMA_VERSION and String(data.get("campaign_id", "")) == PREVIOUS_CAMPAIGN_ID:
		return _restore_v2_campaign(data)
	if schema_version != SAVE_SCHEMA_VERSION or String(data.get("campaign_id", "")) != catalog.campaign_id:
		return ERR_INVALID_DATA
	var validated := _validated_campaign_save(data)
	if validated.is_empty():
		return ERR_INVALID_DATA
	return _apply_validated_campaign(validated)


func _apply_validated_campaign(validated: Dictionary) -> Error:
	var restored_terms = SolarTermChronicleScript.new()
	if not restored_terms.load_save_data(validated.solar_terms):
		return ERR_INVALID_DATA
	if restored_terms.unlocked_count() != (validated.completed_level_ids as Array).size():
		return ERR_INVALID_DATA
	var term_entries: Array[Dictionary] = restored_terms.unlocked_entries()
	for index in term_entries.size():
		if String(term_entries[index].id) != String((validated.completed_level_ids as Array)[index]):
			return ERR_INVALID_DATA
	reserve = int(validated.reserve)
	sortie_count = int(validated.sortie_count)
	attempt_serial = int(validated.attempt_serial)
	completed_level_ids.clear()
	for raw_id in validated.completed_level_ids:
		completed_level_ids.append(String(raw_id))
	reward_ledger = (validated.reward_ledger as Dictionary).duplicate(true)
	level_results = (validated.level_results as Dictionary).duplicate(true)
	best_results = (validated.best_results as Dictionary).duplicate(true)
	world_traces.clear()
	for raw_trace in validated.world_traces:
		world_traces.append((raw_trace as Dictionary).duplicate(true))
	last_return_level_id = String(validated.last_return_level_id)
	last_reward = int(validated.last_reward)
	title_revealed = bool(validated.title_revealed)
	legacy_journey_completed = bool(validated.legacy_journey_completed)
	legacy_campaign_progress = (validated.legacy_campaign_progress as Dictionary).duplicate(true)
	event_checkpoint = (validated.event_checkpoint as Dictionary).duplicate(true)
	journey_complete = bool(validated.journey_complete)
	solar_terms = restored_terms
	active_token = -1
	settled_token = -1
	active_level_id = ""
	active_run_mode = ""
	return OK


func _restore_v2_campaign(data: Dictionary) -> Error:
	var validated := _validated_v2_campaign_save(data)
	if validated.is_empty():
		return ERR_INVALID_DATA
	var old_ids: Array = validated.completed_level_ids
	legacy_campaign_progress = {
		"schema_version": PREVIOUS_CAMPAIGN_SCHEMA_VERSION,
		"campaign_id": PREVIOUS_CAMPAIGN_ID,
		"completed_count": old_ids.size(),
		"completed_level_ids": old_ids.duplicate(),
		"reserve": int(validated.reserve),
		"journey_complete": bool(validated.journey_complete),
		"title_revealed": bool(validated.title_revealed),
	}
	event_checkpoint.clear()
	# v3 changes the authored contract at both Rain Water and Grain Rain.  A legal
	# v2 save may keep the unchanged Beginning-of-Spring prefix, while every later
	# v2 result remains a visible keepsake instead of silently bypassing new work.
	reserve = 0
	sortie_count = 0
	attempt_serial = 0
	completed_level_ids.clear()
	reward_ledger.clear()
	level_results.clear()
	best_results.clear()
	world_traces.clear()
	last_return_level_id = ""
	last_reward = 0
	journey_complete = false
	solar_terms = SolarTermChronicleScript.new()
	if not old_ids.is_empty():
		var first_level := catalog.level_at(0)
		var first_id := String(first_level.id)
		var first_result := (validated.level_results as Dictionary)[first_id] as Dictionary
		var first_reward := int(first_level.reward_honey)
		completed_level_ids.append(first_id)
		reward_ledger[first_id] = first_reward
		level_results[first_id] = first_result.duplicate(true)
		best_results[first_id] = ((validated.best_results as Dictionary)[first_id] as Dictionary).duplicate(true)
		world_traces.append(((validated.world_traces as Array)[0] as Dictionary).duplicate(true))
		reserve = first_reward
		sortie_count = 1
		attempt_serial = 1
		last_return_level_id = first_id
		last_reward = first_reward
		if solar_terms.record_level(first_id, _chronicle_values(first_level, first_result, first_reward)).is_empty():
			return ERR_INVALID_DATA
	title_revealed = bool(validated.title_revealed)
	legacy_journey_completed = bool(validated.legacy_journey_completed)
	active_token = -1
	settled_token = -1
	active_level_id = ""
	active_run_mode = ""
	return OK


func _restore_legacy_journey(data: Dictionary) -> Error:
	var legacy = LegacyJourneyStateScript.new()
	var error := legacy.restore_from_save_dictionary(data)
	if error != OK:
		return error
	# The six-sortie release remains a visible keepsake, but it cannot award or
	# silently skip any of the new twenty-four authored levels.
	legacy_journey_completed = bool(legacy.journey_complete)
	legacy_campaign_progress.clear()
	event_checkpoint.clear()
	title_revealed = bool(legacy.title_revealed)
	reserve = 0
	sortie_count = 0
	attempt_serial = 0
	completed_level_ids.clear()
	reward_ledger.clear()
	level_results.clear()
	best_results.clear()
	world_traces.clear()
	last_return_level_id = ""
	last_reward = 0
	journey_complete = false
	solar_terms = SolarTermChronicleScript.new()
	return OK


func _validated_campaign_save(data: Dictionary) -> Dictionary:
	if (
		not _is_saved_integer(data.get("schema_version", null))
		or int(data.get("schema_version", 0)) != SAVE_SCHEMA_VERSION
		or not data.get("campaign_id", null) is String
		or String(data.get("campaign_id", "")) != catalog.campaign_id
	):
		return {}
	var validated := _validated_campaign_ledger(data, true)
	if validated.is_empty():
		return {}
	var keepsake: Variant = _validated_legacy_campaign_progress(data.get("legacy_campaign_progress", null))
	if keepsake == null:
		return {}
	if not keepsake.is_empty() and int(keepsake.completed_count) > 0:
		var current_ids: Array = validated.completed_level_ids
		if current_ids.is_empty() or String(current_ids[0]) != String(catalog.level_at(0).id):
			return {}
	if not data.get("event_checkpoint", null) is Dictionary:
		return {}
	var checkpoint_level := (
		catalog.level_at((validated.completed_level_ids as Array).size())
		if (validated.completed_level_ids as Array).size() < JourneyLevelCatalog.TOTAL_LEVELS
		else {}
	)
	var checkpoint_value = _validated_event_checkpoint(data.event_checkpoint, checkpoint_level)
	if checkpoint_value == null:
		return {}
	validated["legacy_campaign_progress"] = keepsake
	validated["event_checkpoint"] = (checkpoint_value as Dictionary).duplicate(true)
	return validated


func _validated_v2_campaign_save(data: Dictionary) -> Dictionary:
	if (
		not _is_saved_integer(data.get("schema_version", null))
		or int(data.get("schema_version", 0)) != PREVIOUS_CAMPAIGN_SCHEMA_VERSION
		or not data.get("campaign_id", null) is String
		or String(data.get("campaign_id", "")) != PREVIOUS_CAMPAIGN_ID
		or not _has_exact_dictionary_keys(data, [
			"schema_version", "campaign_id", "reserve", "sortie_count", "attempt_serial",
			"completed_level_ids", "reward_ledger", "level_results", "best_results",
			"world_traces", "last_return_level_id", "last_reward", "title_revealed",
			"legacy_journey_completed", "journey_complete", "solar_terms",
		])
	):
		return {}
	for key in ["reserve", "sortie_count", "attempt_serial", "last_reward"]:
		if not _is_saved_integer(data.get(key, null)) or int(data[key]) < 0:
			return {}
	for key in ["title_revealed", "legacy_journey_completed", "journey_complete"]:
		if typeof(data.get(key, null)) != TYPE_BOOL:
			return {}
	if not data.last_return_level_id is String:
		return {}
	var raw_ids = data.completed_level_ids
	var raw_ledger = data.reward_ledger
	var raw_results = data.level_results
	var raw_best = data.best_results
	var raw_traces = data.world_traces
	if (
		not raw_ids is Array
		or raw_ids.size() > V2_FROZEN_LEVELS.size()
		or not raw_ledger is Dictionary
		or not raw_results is Dictionary
		or not raw_best is Dictionary
		or not raw_traces is Array
		or raw_traces.size() != raw_ids.size()
	):
		return {}
	var expected_reserve := 0
	for index in raw_ids.size():
		var frozen := V2_FROZEN_LEVELS[index] as Dictionary
		var level_id := String(frozen.id)
		if not raw_ids[index] is String or String(raw_ids[index]) != level_id:
			return {}
		if (
			not raw_ledger.has(level_id)
			or not _is_saved_integer(raw_ledger[level_id])
			or int(raw_ledger[level_id]) != int(frozen.reward)
			or not _is_valid_v2_saved_result(raw_results.get(level_id), frozen, index, RUN_PROGRESSION)
			or not _is_valid_v2_saved_result(raw_best.get(level_id), frozen, index, "")
		):
			return {}
		var trace = raw_traces[index]
		if (
			not trace is Dictionary
			or not _has_exact_dictionary_keys(trace, ["level_id", "number", "season_id", "trace"])
			or String(trace.get("level_id", "")) != level_id
			or not _is_saved_integer(trace.get("number", -1))
			or int(trace.number) != index + 1
			or String(trace.get("season_id", "")) != String(frozen.season_id)
			or String(trace.get("trace", "")) != String(frozen.trace)
		):
			return {}
		expected_reserve += int(frozen.reward)
	if (
		raw_ledger.size() != raw_ids.size()
		or raw_results.size() != raw_ids.size()
		or raw_best.size() != raw_ids.size()
		or int(data.reserve) != expected_reserve
		or int(data.attempt_serial) < int(data.sortie_count)
		or bool(data.journey_complete) != (raw_ids.size() == V2_FROZEN_LEVELS.size())
	):
		return {}
	var last_id := String(data.last_return_level_id)
	if raw_ids.is_empty():
		if not last_id.is_empty() or int(data.last_reward) != 0:
			return {}
	else:
		var last_index: int = (raw_ids as Array).find(last_id)
		if last_index < 0:
			return {}
		var progression_reward := int((V2_FROZEN_LEVELS[last_index] as Dictionary).reward)
		if int(data.last_reward) not in [0, progression_reward]:
			return {}
	if not data.solar_terms is Dictionary:
		return {}
	var restored_terms = SolarTermChronicleScript.new()
	if not restored_terms.load_save_data(data.solar_terms):
		return {}
	var term_entries: Array[Dictionary] = restored_terms.unlocked_entries()
	if term_entries.size() != raw_ids.size():
		return {}
	for index in term_entries.size():
		if String(term_entries[index].id) != String(raw_ids[index]):
			return {}
	return data.duplicate(true)


func _is_valid_v2_saved_result(
	raw: Variant,
	frozen: Dictionary,
	level_index: int,
	expected_run_mode: String
) -> bool:
	if not raw is Dictionary:
		return false
	var result := raw as Dictionary
	if not _has_exact_dictionary_keys(result, [
		"level_id", "number", "run_mode", "reward", "elapsed_seconds",
		"energy_remaining", "objective_counts", "phases_completed", "actions",
	]):
		return false
	var run_mode := String(result.get("run_mode", ""))
	if run_mode not in [RUN_PROGRESSION, RUN_REPLAY]:
		return false
	if not expected_run_mode.is_empty() and run_mode != expected_run_mode:
		return false
	var expected_reward := 0 if run_mode == RUN_REPLAY else int(frozen.reward)
	if (
		String(result.get("level_id", "")) != String(frozen.id)
		or not _is_saved_integer(result.get("number", -1))
		or int(result.number) != level_index + 1
		or not _is_saved_integer(result.get("reward", -1))
		or int(result.reward) != expected_reward
		or not _is_saved_integer(result.get("actions", -1))
		or int(result.actions) < 0
		or not _is_saved_integer(result.get("phases_completed", -1))
		or int(result.phases_completed) != (3 if bool(frozen.climax) else 0)
	):
		return false
	for numeric_key in ["elapsed_seconds", "energy_remaining"]:
		var value = result.get(numeric_key, null)
		if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)) or float(value) < 0.0:
			return false
	var counts = result.objective_counts
	var goals: Array = frozen.goals
	if not counts is Array or counts.size() != goals.size():
		return false
	for index in goals.size():
		if not _is_saved_integer(counts[index]) or int(counts[index]) < int(goals[index]):
			return false
	return true


func _validated_event_checkpoint(raw: Variant, level: Dictionary) -> Variant:
	if not raw is Dictionary:
		return null
	var source := raw as Dictionary
	if source.is_empty():
		return {}
	var keys := [
		"level_id", "next_event_number", "pentads_completed",
		"completed_mandatory_ids", "completed_optional_ids", "skipped_optional_ids",
		"route_choices", "support_points", "world_state", "energy",
		"elapsed_seconds", "actions",
	]
	if not _has_exact_dictionary_keys(source, keys):
		return null
	var matrix: Array = level.get("event_matrix", [])
	if (
		String(level.get("id", "")).is_empty()
		or matrix.size() != EventMatrixRuntimeScript.EVENT_COUNT
		or not source.level_id is String
		or String(source.level_id) != String(level.id)
		or not _is_saved_integer(source.next_event_number)
		or not _is_saved_integer(source.pentads_completed)
		or not _is_saved_integer(source.support_points)
		or not _is_saved_integer(source.actions)
	):
		return null
	var next_event_number := int(source.next_event_number)
	var pentads_completed := int(source.pentads_completed)
	if (
		next_event_number not in [
			EventMatrixRuntimeScript.EVENTS_PER_PENTAD + 1,
			EventMatrixRuntimeScript.EVENTS_PER_PENTAD * 2 + 1,
		]
		or pentads_completed != (1 if next_event_number == EventMatrixRuntimeScript.EVENTS_PER_PENTAD + 1 else 2)
		or int(source.support_points) < 0
		or int(source.actions) < 0
	):
		return null
	for numeric_key in ["energy", "elapsed_seconds"]:
		var value = source.get(numeric_key, null)
		if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)):
			return null
	if float(source.energy) < 0.0 or float(source.energy) > CHECKPOINT_ENERGY_CAP or float(source.elapsed_seconds) < 0.0:
		return null
	var mandatory_value = _validated_string_list(source.completed_mandatory_ids)
	var completed_optional_value = _validated_string_list(source.completed_optional_ids)
	var skipped_optional_value = _validated_string_list(source.skipped_optional_ids)
	var route_value = _normalized_route_choices(source.route_choices)
	var world_value = _normalized_event_world_state(source.world_state)
	if (
		mandatory_value == null
		or completed_optional_value == null
		or skipped_optional_value == null
		or route_value == null
		or world_value == null
	):
		return null
	var runtime_source := {
		"next_event_number": next_event_number,
		"pentads_completed": pentads_completed,
		"completed_mandatory_ids": (mandatory_value as Array).duplicate(),
		"completed_optional_ids": (completed_optional_value as Array).duplicate(),
		"skipped_optional_ids": (skipped_optional_value as Array).duplicate(),
		"route_choices": (route_value as Dictionary).duplicate(true),
		"support_points": int(source.support_points),
		"world_state": (world_value as Dictionary).duplicate(true),
	}
	var verifier = EventMatrixRuntimeScript.new()
	if verifier.configure(matrix) != OK or verifier.restore_checkpoint(runtime_source) != OK:
		return null
	if verifier.checkpoint_snapshot() != runtime_source:
		return null
	return {
		"level_id": String(source.level_id),
		"next_event_number": next_event_number,
		"pentads_completed": pentads_completed,
		"completed_mandatory_ids": (runtime_source.completed_mandatory_ids as Array).duplicate(),
		"completed_optional_ids": (runtime_source.completed_optional_ids as Array).duplicate(),
		"skipped_optional_ids": (runtime_source.skipped_optional_ids as Array).duplicate(),
		"route_choices": (runtime_source.route_choices as Dictionary).duplicate(true),
		"support_points": int(runtime_source.support_points),
		"world_state": (runtime_source.world_state as Dictionary).duplicate(true),
		"energy": float(source.energy),
		"elapsed_seconds": float(source.elapsed_seconds),
		"actions": int(source.actions),
	}


func _validated_campaign_ledger(data: Dictionary, require_event_contract: bool) -> Dictionary:
	if not is_ready():
		return {}
	for key in ["reserve", "sortie_count", "attempt_serial", "last_reward"]:
		if not data.has(key) or not _is_saved_integer(data[key]) or int(data[key]) < 0:
			return {}
	for key in ["title_revealed", "legacy_journey_completed", "journey_complete"]:
		if not data.has(key) or typeof(data[key]) != TYPE_BOOL:
			return {}
	if not data.get("last_return_level_id", null) is String:
		return {}
	var raw_ids = data.get("completed_level_ids", null)
	var raw_ledger = data.get("reward_ledger", null)
	var raw_results = data.get("level_results", null)
	var raw_best = data.get("best_results", null)
	var raw_traces = data.get("world_traces", null)
	if not raw_ids is Array or raw_ids.size() > JourneyLevelCatalog.TOTAL_LEVELS:
		return {}
	if not raw_ledger is Dictionary or not raw_results is Dictionary or not raw_best is Dictionary:
		return {}
	if not raw_traces is Array or raw_traces.size() != raw_ids.size():
		return {}
	var expected_reserve := 0
	for index in raw_ids.size():
		var level := catalog.level_at(index)
		if not raw_ids[index] is String:
			return {}
		var level_id := String(raw_ids[index])
		if level_id != String(level.get("id", "")):
			return {}
		if (
			not raw_ledger.has(level_id)
			or not _is_saved_integer(raw_ledger[level_id])
			or int(raw_ledger[level_id]) != int(level.reward_honey)
		):
			return {}
		if (
			not _is_valid_saved_result(raw_results.get(level_id), level, RUN_PROGRESSION, require_event_contract)
			or not _is_valid_saved_result(raw_best.get(level_id), level, "", require_event_contract)
		):
			return {}
		var trace = raw_traces[index]
		if (
			not trace is Dictionary
			or String(trace.get("level_id", "")) != level_id
			or not _is_saved_integer(trace.get("number", -1))
			or int(trace.number) != int(level.number)
			or String(trace.get("season_id", "")) != String(level.season_id)
			or String(trace.get("trace", "")) != String(level.world_trace)
		):
			return {}
		expected_reserve += int(level.reward_honey)
	if raw_ledger.size() != raw_ids.size() or raw_results.size() != raw_ids.size() or raw_best.size() != raw_ids.size():
		return {}
	if int(data.reserve) != expected_reserve:
		return {}
	if int(data.attempt_serial) < int(data.sortie_count):
		return {}
	var expected_complete: bool = raw_ids.size() == JourneyLevelCatalog.TOTAL_LEVELS
	if bool(data.journey_complete) != expected_complete:
		return {}
	var last_id := String(data.last_return_level_id)
	if raw_ids.is_empty():
		if not last_id.is_empty() or int(data.last_reward) != 0:
			return {}
	elif not catalog.has_level(last_id) or not raw_ledger.has(last_id) or int(data.last_reward) != int(raw_ledger[last_id]):
		# A replay may make an earlier completed level the last return, but its
		# permanent reward is zero. Accept that stable replay checkpoint explicitly.
		if not catalog.has_level(last_id) or last_id not in raw_ids or int(data.last_reward) != 0:
			return {}
	if not data.get("solar_terms", null) is Dictionary:
		return {}
	var restored_terms = SolarTermChronicleScript.new()
	if not restored_terms.load_save_data(data.solar_terms):
		return {}
	if restored_terms.unlocked_count() != raw_ids.size():
		return {}
	var term_entries: Array[Dictionary] = restored_terms.unlocked_entries()
	for index in term_entries.size():
		if String(term_entries[index].id) != String(raw_ids[index]):
			return {}
	return data.duplicate(true)


func _validated_legacy_campaign_progress(raw: Variant) -> Variant:
	if not raw is Dictionary:
		return null
	var source := raw as Dictionary
	if source.is_empty():
		return {}
	var keys := [
		"schema_version", "campaign_id", "completed_count", "completed_level_ids",
		"reserve", "journey_complete", "title_revealed",
	]
	if not _has_exact_dictionary_keys(source, keys):
		return null
	if (
		not _is_saved_integer(source.schema_version)
		or int(source.schema_version) != PREVIOUS_CAMPAIGN_SCHEMA_VERSION
		or not source.campaign_id is String
		or String(source.campaign_id) != PREVIOUS_CAMPAIGN_ID
		or not _is_saved_integer(source.completed_count)
		or int(source.completed_count) < 0
		or int(source.completed_count) > JourneyLevelCatalog.TOTAL_LEVELS
		or not source.completed_level_ids is Array
		or (source.completed_level_ids as Array).size() != int(source.completed_count)
		or not _is_saved_integer(source.reserve)
		or int(source.reserve) < 0
		or typeof(source.journey_complete) != TYPE_BOOL
		or typeof(source.title_revealed) != TYPE_BOOL
	):
		return null
	var expected_reserve := 0
	var normalized_ids: Array[String] = []
	for index in int(source.completed_count):
		var raw_id = (source.completed_level_ids as Array)[index]
		var frozen := V2_FROZEN_LEVELS[index] as Dictionary
		if not raw_id is String or String(raw_id) != String(frozen.id):
			return null
		normalized_ids.append(String(raw_id))
		expected_reserve += int(frozen.reward)
	if int(source.reserve) != expected_reserve:
		return null
	if bool(source.journey_complete) != (normalized_ids.size() == JourneyLevelCatalog.TOTAL_LEVELS):
		return null
	return {
		"schema_version": PREVIOUS_CAMPAIGN_SCHEMA_VERSION,
		"campaign_id": PREVIOUS_CAMPAIGN_ID,
		"completed_count": normalized_ids.size(),
		"completed_level_ids": normalized_ids,
		"reserve": expected_reserve,
		"journey_complete": bool(source.journey_complete),
		"title_revealed": bool(source.title_revealed),
	}


func _is_valid_saved_result(
	raw: Variant,
	level: Dictionary,
	expected_run_mode: String,
	require_event_contract: bool
) -> bool:
	if not raw is Dictionary:
		return false
	var result := raw as Dictionary
	var keys := [
		"level_id", "number", "run_mode", "reward", "elapsed_seconds",
		"energy_remaining", "objective_counts", "phases_completed", "actions",
	]
	var event_matrix: Array = level.get("event_matrix", [])
	if require_event_contract and not event_matrix.is_empty():
		keys.append("event_result")
	if not _has_exact_dictionary_keys(result, keys):
		return false
	var run_mode := String(result.get("run_mode", ""))
	if run_mode not in [RUN_PROGRESSION, RUN_REPLAY]:
		return false
	if not expected_run_mode.is_empty() and run_mode != expected_run_mode:
		return false
	var expected_reward := 0 if run_mode == RUN_REPLAY else int(level.reward_honey)
	if (
		String(result.get("level_id", "")) != String(level.id)
		or not _is_saved_integer(result.get("number", -1))
		or int(result.number) != int(level.number)
		or not _is_saved_integer(result.get("reward", -1))
		or int(result.reward) != expected_reward
	):
		return false
	for numeric_key in ["elapsed_seconds", "energy_remaining"]:
		var value = result.get(numeric_key, null)
		if (
			typeof(value) not in [TYPE_INT, TYPE_FLOAT]
			or not is_finite(float(value))
			or float(value) < 0.0
		):
			return false
	if not _is_saved_integer(result.get("actions", -1)) or int(result.actions) < 0:
		return false
	var expected_phases := 3 if String(level.kind) == "climax" else 0
	if not _is_saved_integer(result.get("phases_completed", -1)) or int(result.phases_completed) != expected_phases:
		return false
	var counts = result.get("objective_counts", null)
	var objectives: Array = level.get("objectives", [])
	if not counts is Array or counts.size() != objectives.size():
		return false
	for index in objectives.size():
		if not _is_saved_integer(counts[index]) or int(counts[index]) < 0:
			return false
		if (not require_event_contract or event_matrix.is_empty()) and int(counts[index]) < int((objectives[index] as Dictionary).goal):
			return false
	if require_event_contract and not event_matrix.is_empty():
		return not _validated_event_result(result.get("event_result", null), level).is_empty()
	return true


func _validated_event_result(raw: Variant, level: Dictionary) -> Dictionary:
	if not raw is Dictionary:
		return {}
	var source := raw as Dictionary
	var keys := [
		"completed_mandatory_ids", "completed_optional_ids", "skipped_optional_ids",
		"route_choices", "support_points", "world_state",
	]
	if not _has_exact_dictionary_keys(source, keys):
		return {}
	var mandatory_value = _validated_string_list(source.completed_mandatory_ids)
	var completed_optional_value = _validated_string_list(source.completed_optional_ids)
	var skipped_optional_value = _validated_string_list(source.skipped_optional_ids)
	if mandatory_value == null or completed_optional_value == null or skipped_optional_value == null:
		return {}
	var completed_mandatory := mandatory_value as Array
	var completed_optional := completed_optional_value as Array
	var skipped_optional := skipped_optional_value as Array
	var matrix: Array = level.get("event_matrix", [])
	if matrix.is_empty():
		return {}
	var authored_mandatory: Array[String] = []
	var authored_optional: Array[String] = []
	for raw_event in matrix:
		var event := raw_event as Dictionary
		if bool(event.get("optional", false)):
			authored_optional.append(String(event.id))
		else:
			authored_mandatory.append(String(event.id))
	if completed_mandatory != authored_mandatory:
		return {}
	var completed_lookup := {}
	var skipped_lookup := {}
	for event_id in completed_optional:
		completed_lookup[String(event_id)] = true
	for event_id in skipped_optional:
		skipped_lookup[String(event_id)] = true
	var ordered_completed: Array[String] = []
	var ordered_skipped: Array[String] = []
	for event_id in authored_optional:
		var was_completed := completed_lookup.has(event_id)
		var was_skipped := skipped_lookup.has(event_id)
		if was_completed == was_skipped:
			return {}
		if was_completed:
			ordered_completed.append(event_id)
		else:
			ordered_skipped.append(event_id)
	if completed_optional != ordered_completed or skipped_optional != ordered_skipped:
		return {}
	if not _is_saved_integer(source.support_points) or int(source.support_points) != completed_optional.size():
		return {}
	var all_completed := {}
	for event_id in completed_mandatory:
		all_completed[String(event_id)] = true
	for event_id in completed_optional:
		all_completed[String(event_id)] = true
	var route_value = _normalized_route_choices(source.route_choices)
	if route_value == null:
		return {}
	var route_choices := route_value as Dictionary
	var expected_route_ids: Array[String] = []
	for raw_event in matrix:
		var event := raw_event as Dictionary
		var event_id := String(event.id)
		var choice_options = event.get("choice_options", {})
		if all_completed.has(event_id) and choice_options is Dictionary and not (choice_options as Dictionary).is_empty():
			expected_route_ids.append(event_id)
	if route_choices.size() != expected_route_ids.size():
		return {}
	for event_id in expected_route_ids:
		if not route_choices.has(event_id) or String(route_choices[event_id]) not in ["swift", "steady"]:
			return {}
	var normalized_world = _normalized_event_world_state(source.world_state)
	if normalized_world == null:
		return {}
	var expected_world := _expected_event_world_state(matrix, all_completed, route_choices, completed_optional.size())
	if normalized_world != expected_world:
		return {}
	if (normalized_world as Dictionary).route_choices != route_choices:
		return {}
	return {
		"completed_mandatory_ids": completed_mandatory.duplicate(),
		"completed_optional_ids": completed_optional.duplicate(),
		"skipped_optional_ids": skipped_optional.duplicate(),
		"route_choices": route_choices.duplicate(true),
		"support_points": completed_optional.size(),
		"world_state": (normalized_world as Dictionary).duplicate(true),
	}


func _expected_event_world_state(
	matrix: Array,
	completed_lookup: Dictionary,
	route_choices: Dictionary,
	_support_points: int
) -> Dictionary:
	# Replaying the small deterministic runtime keeps persistence validation tied
	# to the same authored mechanic rules (including asymmetric route choices)
	# without trusting any counter supplied by the save file.
	var verifier = EventMatrixRuntimeScript.new()
	if verifier.configure(matrix) != OK:
		return {}
	var guard := 0
	while not verifier.is_finished() and guard < 256:
		guard += 1
		var event_id := String(verifier.current_event().get("id", ""))
		if verifier.optional_pending():
			if completed_lookup.has(event_id):
				if not verifier.accept_optional():
					return {}
			else:
				if not bool(verifier.skip_optional().get("accepted", false)):
					return {}
				continue
		if verifier.choice_pending():
			if not verifier.choose_route(String(route_choices.get(event_id, ""))):
				return {}
		if verifier.requires_evade():
			verifier.note_evade()
		var step_result: Dictionary = verifier.record_step(verifier.current_kind())
		if not bool(step_result.get("accepted", false)):
			return {}
	if not verifier.is_finished() or not verifier.can_finish():
		return {}
	return (verifier.snapshot().get("world_state", {}) as Dictionary).duplicate(true)


func _normalized_event_world_state(raw: Variant) -> Variant:
	if not raw is Dictionary:
		return null
	var source := raw as Dictionary
	var counter_keys := [
		"observed_signals", "opened_route_segments", "delivered_loads", "caught_objects",
		"anchored_supports", "convoy_segments", "pollination_deliveries",
		"route_work_completed", "caught_signs", "anchored_signs",
	]
	var keys := counter_keys + [
		"route_choices", "support_points", "support_effects", "event_outcomes",
		"setpiece_complete", "bloom_stage",
	]
	if not _has_exact_dictionary_keys(source, keys):
		return null
	var normalized := {}
	for key in counter_keys + ["support_points", "bloom_stage"]:
		if not _is_saved_integer(source.get(key, -1)) or int(source[key]) < 0:
			return null
		normalized[key] = int(source[key])
	if typeof(source.setpiece_complete) != TYPE_BOOL:
		return null
	normalized["setpiece_complete"] = bool(source.setpiece_complete)
	var routes = _normalized_route_choices(source.route_choices)
	if routes == null:
		return null
	normalized["route_choices"] = (routes as Dictionary).duplicate(true)
	var support_effects = _normalized_nonnegative_integer_dictionary(source.support_effects)
	if support_effects == null:
		return null
	normalized["support_effects"] = (support_effects as Dictionary).duplicate(true)
	var event_outcomes = _normalized_event_outcomes(source.event_outcomes)
	if event_outcomes == null:
		return null
	normalized["event_outcomes"] = (event_outcomes as Dictionary).duplicate(true)
	return normalized


func _normalized_nonnegative_integer_dictionary(raw: Variant) -> Variant:
	if not raw is Dictionary:
		return null
	var normalized := {}
	for raw_key in (raw as Dictionary).keys():
		if not raw_key is String or String(raw_key).is_empty():
			return null
		var raw_value = (raw as Dictionary)[raw_key]
		if not _is_saved_integer(raw_value) or int(raw_value) < 0:
			return null
		normalized[String(raw_key)] = int(raw_value)
	return normalized


func _normalized_event_outcomes(raw: Variant) -> Variant:
	if not raw is Dictionary:
		return null
	var normalized := {}
	for raw_event_id in (raw as Dictionary).keys():
		if not raw_event_id is String or String(raw_event_id).is_empty():
			return null
		var raw_outcome = (raw as Dictionary)[raw_event_id]
		if not raw_outcome is Dictionary:
			return null
		var outcome := raw_outcome as Dictionary
		if not _has_exact_dictionary_keys(outcome, ["choice", "choice_effect", "consequence", "optional"]):
			return null
		if (
			not outcome.choice is String
			or String(outcome.choice) not in ["", "swift", "steady"]
			or not outcome.choice_effect is String
			or not outcome.consequence is String
			or String(outcome.consequence).is_empty()
			or typeof(outcome.optional) != TYPE_BOOL
		):
			return null
		normalized[String(raw_event_id)] = {
			"choice": String(outcome.choice),
			"choice_effect": String(outcome.choice_effect),
			"consequence": String(outcome.consequence),
			"optional": bool(outcome.optional),
		}
	return normalized


func _normalized_route_choices(raw: Variant) -> Variant:
	if not raw is Dictionary:
		return null
	var normalized := {}
	for raw_key in (raw as Dictionary).keys():
		if not raw_key is String:
			return null
		var value = (raw as Dictionary)[raw_key]
		if not value is String or String(value) not in ["swift", "steady"]:
			return null
		normalized[String(raw_key)] = String(value)
	return normalized


func _validated_string_list(raw: Variant) -> Variant:
	if not raw is Array:
		return null
	var normalized: Array[String] = []
	var seen := {}
	for raw_value in raw:
		if not raw_value is String:
			return null
		var value := String(raw_value)
		if value.is_empty() or seen.has(value):
			return null
		seen[value] = true
		normalized.append(value)
	return normalized


func _has_exact_dictionary_keys(source: Dictionary, keys: Array) -> bool:
	if source.size() != keys.size():
		return false
	for key in keys:
		if not source.has(key):
			return false
	return true


func _is_saved_integer(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or (typeof(value) == TYPE_FLOAT and is_equal_approx(float(value), roundf(float(value))))
