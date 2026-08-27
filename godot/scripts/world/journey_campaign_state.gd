class_name JourneyCampaignState
extends RefCounted

## Checkpoint-safe progression for the formal solar-term campaign. A field can
## report what happened, but this object alone decides whether a completion is
## legal and how much permanent reserve it earns.

const LevelCatalogScript := preload("res://scripts/world/journey_level_catalog.gd")
const SolarTermChronicleScript := preload("res://scripts/world/journey_solar_term_chronicle.gd")
const LegacyJourneyStateScript := preload("res://scripts/world/journey_state.gd")
const SAVE_SCHEMA_VERSION := 2
const RUN_PROGRESSION := "progression"
const RUN_REPLAY := "replay"

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
	return {
		"campaign_mode": true,
		"journey_token": active_token,
		"level": catalog.level_by_id(active_level_id),
		"run_mode": active_run_mode,
		"reserve": reserve,
		"sortie_count": sortie_count,
		"world_results": world_memory(),
	}


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
	if not bool(payload.get("objectives_complete", false)) or not bool(payload.get("returned_home", false)):
		return false
	if bool(payload.get("failed", false)):
		return false
	var level := catalog.level_by_id(active_level_id)
	var objectives = level.get("objectives", [])
	var counts = payload.get("objective_counts", [])
	if not objectives is Array or not counts is Array or counts.size() != objectives.size():
		return false
	for index in objectives.size():
		if not _is_saved_integer(counts[index]) or int(counts[index]) < int((objectives[index] as Dictionary).get("goal", 0)):
			return false
	if String(level.get("kind", "")) == "climax" and int(payload.get("phases_completed", 0)) != 3:
		return false
	var elapsed_value = payload.get("elapsed_seconds", -1.0)
	if typeof(elapsed_value) not in [TYPE_INT, TYPE_FLOAT] or float(elapsed_value) < 0.0:
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
	return {
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
		"journey_complete": journey_complete,
		"solar_terms": solar_terms.to_save_data(),
	}


func restore_from_save_dictionary(data: Dictionary) -> Error:
	if int(data.get("schema_version", 0)) != SAVE_SCHEMA_VERSION or not data.has("campaign_id"):
		return _restore_legacy_journey(data)
	var validated := _validated_campaign_save(data)
	if validated.is_empty():
		return ERR_INVALID_DATA
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
	journey_complete = bool(validated.journey_complete)
	solar_terms = restored_terms
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
	if not is_ready() or String(data.get("campaign_id", "")) != catalog.campaign_id:
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
		var level_id := String(raw_ids[index])
		if level_id != String(level.get("id", "")):
			return {}
		if not raw_ledger.has(level_id) or int(raw_ledger[level_id]) != int(level.reward_honey):
			return {}
		if not raw_results.get(level_id) is Dictionary or not raw_best.get(level_id) is Dictionary:
			return {}
		var trace = raw_traces[index]
		if not trace is Dictionary or String(trace.get("level_id", "")) != level_id or String(trace.get("trace", "")) != String(level.world_trace):
			return {}
		expected_reserve += int(level.reward_honey)
	if raw_ledger.size() != raw_ids.size() or raw_results.size() != raw_ids.size():
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
	return data.duplicate(true)


func _is_saved_integer(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or (typeof(value) == TYPE_FLOAT and is_equal_approx(float(value), roundf(float(value))))
