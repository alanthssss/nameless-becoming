class_name JourneyState
extends RefCounted

## Session-owned state for the first product journey. Area scenes are disposable:
## changing from the hive threshold to the field must never duplicate a deposit or
## turn a rest stop into a second home.

const SolarTermChronicleScript := preload("res://scripts/world/journey_solar_term_chronicle.gd")

const SPRING_ROUTE := "spring_route"
const SIGN_INCIDENT := "sign_incident"
const SUMMER_RECOVERY := "summer_recovery"
const AUTUMN_HARVEST := "autumn_harvest"
const WINTER_WARMTH := "winter_warmth"
const FINALE_HANDOFF := "finale_handoff"
const SPRING_HONEY_GOAL := 6
const SPRING_TOTAL_HONEY := 12
const SPRING_POLLINATION_GOAL := 2
const INCIDENT_STARTING_HONEY := 6
const SUMMER_TOTAL_HONEY := 8
const SUMMER_HONEY_GOAL := 6
const SUMMER_BELONGINGS_GOAL := 3
const AUTUMN_FLOWER_GOAL := 8
const AUTUMN_ECHO_GOAL := 3
const WINTER_WARMTH_GOAL := 4
const WINTER_WINDBREAK_GOAL := 3

var reserve := 0
var sortie_count := 0
var active_token := 0
var settled_token := -1
var active_segment := ""
var last_return_kind := ""
var last_deposit := 0
var completed_pollinations := 0
var first_return_complete := false
var title_revealed := false
var sign_incident_complete := false
var incident_signs_resolved := 0
var incident_honey_lost := 0
var chapter_complete := false
var summer_complete := false
var autumn_complete := false
var winter_complete := false
var finale_complete := false
var journey_complete := false
var solar_terms = SolarTermChronicleScript.new()
var world_results: Dictionary = {
	"spring_honey_returned": 0,
	"spring_signs_resolved": 0,
	"spring_honey_lost": 0,
	"summer_honey_returned": 0,
	"summer_honey_lost": 0,
	"summer_belongings_recovered": 0,
	"summer_rest_hive_repaired": false,
	"autumn_harvested": 0,
	"autumn_seeded": 0,
	"autumn_echo_points": 0,
	"winter_warmth_links": 0,
	"winter_windbreak_segments": 0,
	"winter_bear_helped": false,
	"finale_demonstration_complete": false,
}


func can_begin_sortie(segment_id := SPRING_ROUTE) -> bool:
	if segment_id != next_segment_id():
		return false
	if segment_id == SIGN_INCIDENT:
		return reserve >= INCIDENT_STARTING_HONEY
	return not segment_id.is_empty()


func begin_sortie(segment_id := SPRING_ROUTE) -> int:
	if not can_begin_sortie(segment_id):
		return -1
	sortie_count += 1
	active_token += 1
	settled_token = -1
	active_segment = segment_id
	last_deposit = 0
	completed_pollinations = 0
	if segment_id == SIGN_INCIDENT:
		# These six drops were received at the hive after the first trip. The
		# receiving team explicitly issues the same honey for the sign errand, so
		# returning it cannot duplicate colony reserves.
		reserve -= INCIDENT_STARTING_HONEY
	return active_token


func next_segment_id() -> String:
	if not first_return_complete:
		return SPRING_ROUTE
	if not sign_incident_complete:
		return SIGN_INCIDENT
	if not summer_complete:
		return SUMMER_RECOVERY
	if not autumn_complete:
		return AUTUMN_HARVEST
	if not winter_complete:
		return WINTER_WARMTH
	if not finale_complete:
		return FINALE_HANDOFF
	return ""


func next_field_context() -> Dictionary:
	return {
		"journey_token": active_token + 1,
		"reserve": reserve,
		"sortie_count": sortie_count + 1,
		"first_sortie": not first_return_complete,
	}


func next_incident_context() -> Dictionary:
	return {
		"journey_token": active_token + 1,
		"reserve": maxi(0, reserve - INCIDENT_STARTING_HONEY),
		"sortie_count": sortie_count + 1,
		"starting_honey": INCIDENT_STARTING_HONEY,
	}


func next_seasonal_context(segment_id: String) -> Dictionary:
	return {
		"journey_token": active_token + 1,
		"reserve": reserve,
		"sortie_count": sortie_count + 1,
		"segment_id": segment_id,
		"world_results": world_results.duplicate(true),
	}


func can_settle_return(token: int, deposit: int, pollinations: int) -> bool:
	return (
		token == active_token
		and token != settled_token
		and active_segment == SPRING_ROUTE
		and deposit >= SPRING_HONEY_GOAL
		and deposit <= SPRING_TOTAL_HONEY
		and pollinations >= SPRING_POLLINATION_GOAL
	)


func settle_return(token: int, deposit: int, pollinations: int) -> bool:
	if not can_settle_return(token, deposit, pollinations):
		return false
	settled_token = token
	last_deposit = deposit
	completed_pollinations = pollinations
	reserve += deposit
	first_return_complete = true
	last_return_kind = SPRING_ROUTE
	world_results["spring_honey_returned"] = deposit
	solar_terms.record_return(SPRING_ROUTE, {
		"deposit": deposit,
		"pollinations": pollinations,
	})
	return true


func preview_return_context(deposit: int, pollinations: int) -> Dictionary:
	var preview_results := world_results.duplicate(true)
	preview_results["spring_honey_returned"] = clampi(deposit, 0, SPRING_TOTAL_HONEY)
	return {
		"returning": true,
		"return_kind": SPRING_ROUTE,
		"deposit_amount": maxi(0, deposit),
		"pollinations": maxi(0, pollinations),
		"reserve": reserve + maxi(0, deposit),
		"first_return_complete": true,
		"title_reveal": not title_revealed,
		"chapter_complete": false,
		"journey_complete": false,
		"next_segment": SIGN_INCIDENT,
		"world_results": preview_results,
	}


func mark_title_revealed() -> void:
	title_revealed = true


func can_settle_sign_incident(token: int, deposit: int, signs_resolved: int, honey_lost: int) -> bool:
	return (
		token == active_token
		and token != settled_token
		and active_segment == SIGN_INCIDENT
		and signs_resolved == 3
		and deposit >= 0
		and deposit <= INCIDENT_STARTING_HONEY
		and honey_lost == INCIDENT_STARTING_HONEY - deposit
	)


func settle_sign_incident(token: int, deposit: int, signs_resolved: int, honey_lost: int) -> bool:
	if not can_settle_sign_incident(token, deposit, signs_resolved, honey_lost):
		return false
	settled_token = token
	last_deposit = deposit
	incident_signs_resolved = signs_resolved
	incident_honey_lost = honey_lost
	reserve += deposit
	sign_incident_complete = true
	chapter_complete = true
	last_return_kind = SIGN_INCIDENT
	world_results["spring_signs_resolved"] = signs_resolved
	world_results["spring_honey_lost"] = honey_lost
	solar_terms.record_return(SIGN_INCIDENT, {
		"deposit": deposit,
		"honey_lost": honey_lost,
	})
	return true


func can_settle_summer(
	token: int,
	deposit: int,
	recovered_honey: int,
	honey_lost: int,
	belongings_recovered: int,
	rest_hive_repaired: bool
) -> bool:
	return (
		token == active_token
		and token != settled_token
		and active_segment == SUMMER_RECOVERY
		and deposit >= SUMMER_HONEY_GOAL
		and recovered_honey == deposit + honey_lost
		and recovered_honey == SUMMER_TOTAL_HONEY
		and honey_lost >= 0
		and belongings_recovered == SUMMER_BELONGINGS_GOAL
		and rest_hive_repaired
	)


func settle_summer(
	token: int,
	deposit: int,
	recovered_honey: int,
	honey_lost: int,
	belongings_recovered: int,
	rest_hive_repaired: bool
) -> bool:
	if not can_settle_summer(
		token,
		deposit,
		recovered_honey,
		honey_lost,
		belongings_recovered,
		rest_hive_repaired
	):
		return false
	settled_token = token
	last_deposit = deposit
	reserve += deposit
	last_return_kind = SUMMER_RECOVERY
	summer_complete = true
	chapter_complete = true
	world_results["summer_honey_returned"] = deposit
	world_results["summer_honey_lost"] = honey_lost
	world_results["summer_belongings_recovered"] = belongings_recovered
	world_results["summer_rest_hive_repaired"] = rest_hive_repaired
	solar_terms.record_return(SUMMER_RECOVERY, {
		"deposit": deposit,
		"recovered_honey": recovered_honey,
		"honey_lost": honey_lost,
		"belongings_recovered": belongings_recovered,
	})
	return true


func can_settle_autumn(
	token: int,
	deposit: int,
	harvested: int,
	seeded: int,
	echo_points: int
) -> bool:
	return (
		token == active_token
		and token != settled_token
		and active_segment == AUTUMN_HARVEST
		and harvested >= 0
		and seeded >= 0
		and harvested + seeded == AUTUMN_FLOWER_GOAL
		and deposit == harvested
		and echo_points == AUTUMN_ECHO_GOAL
	)


func settle_autumn(
	token: int,
	deposit: int,
	harvested: int,
	seeded: int,
	echo_points: int
) -> bool:
	if not can_settle_autumn(token, deposit, harvested, seeded, echo_points):
		return false
	settled_token = token
	last_deposit = deposit
	reserve += deposit
	last_return_kind = AUTUMN_HARVEST
	autumn_complete = true
	chapter_complete = true
	world_results["autumn_harvested"] = harvested
	world_results["autumn_seeded"] = seeded
	world_results["autumn_echo_points"] = echo_points
	solar_terms.record_return(AUTUMN_HARVEST, {
		"deposit": deposit,
		"harvested": harvested,
		"seeded": seeded,
		"echo_points": echo_points,
	})
	return true


func can_settle_winter(
	token: int,
	warmth_links: int,
	windbreak_segments: int,
	bear_helped: bool
) -> bool:
	return (
		token == active_token
		and token != settled_token
		and active_segment == WINTER_WARMTH
		and warmth_links == WINTER_WARMTH_GOAL
		and windbreak_segments == WINTER_WINDBREAK_GOAL
		and bear_helped
	)


func settle_winter(
	token: int,
	warmth_links: int,
	windbreak_segments: int,
	bear_helped: bool
) -> bool:
	if not can_settle_winter(token, warmth_links, windbreak_segments, bear_helped):
		return false
	settled_token = token
	last_deposit = 0
	last_return_kind = WINTER_WARMTH
	winter_complete = true
	chapter_complete = true
	world_results["winter_warmth_links"] = warmth_links
	world_results["winter_windbreak_segments"] = windbreak_segments
	world_results["winter_bear_helped"] = bear_helped
	solar_terms.record_return(WINTER_WARMTH, {
		"warmth_links": warmth_links,
		"windbreak_segments": windbreak_segments,
	})
	return true


func can_settle_finale(token: int, demonstration_steps: int, phrase_spoken: bool) -> bool:
	return (
		token == active_token
		and token != settled_token
		and active_segment == FINALE_HANDOFF
		and demonstration_steps == 3
		and phrase_spoken
	)


func settle_finale(token: int, demonstration_steps: int, phrase_spoken: bool) -> bool:
	if not can_settle_finale(token, demonstration_steps, phrase_spoken):
		return false
	settled_token = token
	last_deposit = 0
	last_return_kind = FINALE_HANDOFF
	finale_complete = true
	journey_complete = true
	chapter_complete = true
	world_results["finale_demonstration_complete"] = true
	return true


func preview_incident_return_context(deposit: int, signs_resolved: int, honey_lost: int) -> Dictionary:
	var preview_results := world_results.duplicate(true)
	preview_results["spring_signs_resolved"] = signs_resolved
	preview_results["spring_honey_lost"] = honey_lost
	return {
		"returning": true,
		"return_kind": SIGN_INCIDENT,
		"deposit_amount": clampi(deposit, 0, INCIDENT_STARTING_HONEY),
		"pollinations": 0,
		"reserve": reserve + clampi(deposit, 0, INCIDENT_STARTING_HONEY),
		"first_return_complete": true,
		"title_reveal": false,
		"chapter_complete": true,
		"journey_complete": false,
		"next_segment": SUMMER_RECOVERY,
		"world_results": preview_results,
		"signs_resolved": signs_resolved,
		"honey_lost": honey_lost,
	}


func preview_seasonal_return_context(payload: Dictionary) -> Dictionary:
	var journey_kind := String(payload.get("journey_kind", ""))
	var deposit := maxi(0, int(payload.get("deposit", 0)))
	if journey_kind in [WINTER_WARMTH, FINALE_HANDOFF]:
		deposit = 0
	var next_segment := ""
	if journey_kind == SUMMER_RECOVERY:
		next_segment = AUTUMN_HARVEST
	elif journey_kind == AUTUMN_HARVEST:
		next_segment = WINTER_WARMTH
	elif journey_kind == WINTER_WARMTH:
		next_segment = FINALE_HANDOFF
	var preview_results := world_results.duplicate(true)
	if journey_kind == SUMMER_RECOVERY:
		preview_results["summer_honey_returned"] = deposit
		preview_results["summer_honey_lost"] = int(payload.get("honey_lost", 0))
		preview_results["summer_belongings_recovered"] = int(payload.get("belongings_recovered", 0))
		preview_results["summer_rest_hive_repaired"] = bool(payload.get("rest_hive_repaired", false))
	elif journey_kind == AUTUMN_HARVEST:
		preview_results["autumn_harvested"] = int(payload.get("harvested", 0))
		preview_results["autumn_seeded"] = int(payload.get("seeded", 0))
		preview_results["autumn_echo_points"] = int(payload.get("echo_points", 0))
	elif journey_kind == WINTER_WARMTH:
		preview_results["winter_warmth_links"] = int(payload.get("warmth_links", 0))
		preview_results["winter_windbreak_segments"] = int(payload.get("windbreak_segments", 0))
		preview_results["winter_bear_helped"] = bool(payload.get("bear_helped", false))
	elif journey_kind == FINALE_HANDOFF:
		preview_results["finale_demonstration_complete"] = true
	return {
		"returning": true,
		"return_kind": journey_kind,
		"deposit_amount": deposit,
		"pollinations": 0,
		"reserve": reserve + deposit,
		"first_return_complete": true,
		"title_reveal": false,
		"chapter_complete": true,
		"journey_complete": journey_kind == FINALE_HANDOFF,
		"next_segment": next_segment,
		"world_results": preview_results,
	}


func field_context() -> Dictionary:
	return {
		"journey_token": active_token,
		"reserve": reserve,
		"sortie_count": sortie_count,
		"segment_id": active_segment,
	}


func reconcile_solar_term_progress() -> void:
	## Backfill only the returns that an older save has already completed. The
	## chronicle itself still guarantees exact-once insertion and catalog order.
	if first_return_complete:
		solar_terms.record_return(SPRING_ROUTE, {
			"deposit": int(world_results.get("spring_honey_returned", last_deposit if last_return_kind == SPRING_ROUTE else 0)),
			"pollinations": completed_pollinations,
		})
	if sign_incident_complete:
		solar_terms.record_return(SIGN_INCIDENT, {
			"deposit": 0,
			"honey_lost": int(world_results.get("spring_honey_lost", incident_honey_lost)),
		})
	if summer_complete:
		solar_terms.record_return(SUMMER_RECOVERY, {
			"deposit": int(world_results.get("summer_honey_returned", 0)),
			"recovered_honey": int(world_results.get("summer_honey_returned", 0)) + int(world_results.get("summer_honey_lost", 0)),
			"honey_lost": int(world_results.get("summer_honey_lost", 0)),
			"belongings_recovered": int(world_results.get("summer_belongings_recovered", 0)),
		})
	if autumn_complete:
		solar_terms.record_return(AUTUMN_HARVEST, {
			"harvested": int(world_results.get("autumn_harvested", 0)),
			"seeded": int(world_results.get("autumn_seeded", 0)),
			"echo_points": int(world_results.get("autumn_echo_points", 0)),
		})
	if winter_complete:
		solar_terms.record_return(WINTER_WARMTH, {
			"warmth_links": int(world_results.get("winter_warmth_links", 0)),
			"windbreak_segments": int(world_results.get("winter_windbreak_segments", 0)),
		})


func hive_context(returning: bool) -> Dictionary:
	return {
		"returning": returning,
		"return_kind": last_return_kind if returning else "",
		"deposit_amount": last_deposit if returning else 0,
		"pollinations": completed_pollinations if returning else 0,
		"reserve": reserve,
		"first_return_complete": first_return_complete,
		"title_reveal": false,
		"title_revealed": title_revealed,
		"chapter_complete": chapter_complete,
		"journey_complete": journey_complete,
		"next_segment": next_segment_id(),
		"world_results": world_results.duplicate(true),
		"signs_resolved": incident_signs_resolved if returning else 0,
		"honey_lost": incident_honey_lost if returning else 0,
		"solar_terms": solar_terms.progress_snapshot(),
	}


func to_save_dictionary() -> Dictionary:
	## Only stable, cross-scene facts belong here. Live player position, temporary
	## energy and unhanded field objects intentionally restart from the hive
	## checkpoint after an interrupted sortie.
	return {
		"reserve": reserve,
		"sortie_count": sortie_count,
		"active_token": active_token,
		"settled_token": settled_token,
		"active_segment": active_segment,
		"last_return_kind": last_return_kind,
		"last_deposit": last_deposit,
		"completed_pollinations": completed_pollinations,
		"first_return_complete": first_return_complete,
		"title_revealed": title_revealed,
		"sign_incident_complete": sign_incident_complete,
		"incident_signs_resolved": incident_signs_resolved,
		"incident_honey_lost": incident_honey_lost,
		"chapter_complete": chapter_complete,
		"summer_complete": summer_complete,
		"autumn_complete": autumn_complete,
		"winter_complete": winter_complete,
		"finale_complete": finale_complete,
		"journey_complete": journey_complete,
		"world_results": world_results.duplicate(true),
		"solar_terms": solar_terms.to_save_data(),
	}


func restore_from_save_dictionary(data: Dictionary) -> Error:
	var validated := _validated_save_dictionary(data)
	if validated.is_empty():
		return ERR_INVALID_DATA
	var restored_terms = SolarTermChronicleScript.new()
	var has_solar_term_data := validated.has("solar_terms")
	if has_solar_term_data and not restored_terms.load_save_data(validated.solar_terms):
		return ERR_INVALID_DATA
	if has_solar_term_data:
		var expected_term_count := _expected_solar_term_count(validated)
		if restored_terms.unlocked_count() != expected_term_count:
			return ERR_INVALID_DATA
		# Count alone is insufficient: three late-winter IDs must not masquerade as
		# the first three spring records. A valid Journey save always unlocks the
		# catalog's exact prefix in chapter order.
		var unlocked_entries: Array[Dictionary] = restored_terms.unlocked_entries()
		var catalog_entries: Array[Dictionary] = restored_terms.catalog_entries()
		for index in expected_term_count:
			if String(unlocked_entries[index].id) != String(catalog_entries[index].id):
				return ERR_INVALID_DATA
	reserve = int(validated.reserve)
	sortie_count = int(validated.sortie_count)
	active_token = int(validated.active_token)
	settled_token = int(validated.settled_token)
	active_segment = String(validated.active_segment)
	last_return_kind = String(validated.last_return_kind)
	last_deposit = int(validated.last_deposit)
	completed_pollinations = int(validated.completed_pollinations)
	first_return_complete = bool(validated.first_return_complete)
	title_revealed = bool(validated.title_revealed)
	sign_incident_complete = bool(validated.sign_incident_complete)
	incident_signs_resolved = int(validated.incident_signs_resolved)
	incident_honey_lost = int(validated.incident_honey_lost)
	chapter_complete = bool(validated.chapter_complete)
	summer_complete = bool(validated.summer_complete)
	autumn_complete = bool(validated.autumn_complete)
	winter_complete = bool(validated.winter_complete)
	finale_complete = bool(validated.finale_complete)
	journey_complete = bool(validated.journey_complete)
	world_results = (validated.world_results as Dictionary).duplicate(true)
	solar_terms = restored_terms
	if not has_solar_term_data:
		reconcile_solar_term_progress()
	return OK


func _expected_solar_term_count(validated: Dictionary) -> int:
	if bool(validated.winter_complete):
		return 24
	if bool(validated.autumn_complete):
		return 18
	if bool(validated.summer_complete):
		return 12
	if bool(validated.sign_incident_complete):
		return 6
	if bool(validated.first_return_complete):
		return 3
	return 0


func _validated_save_dictionary(data: Dictionary) -> Dictionary:
	var required_numeric := [
		"reserve", "sortie_count", "active_token", "settled_token", "last_deposit",
		"completed_pollinations", "incident_signs_resolved", "incident_honey_lost",
	]
	var required_bools := [
		"first_return_complete", "title_revealed", "sign_incident_complete",
		"chapter_complete", "summer_complete", "autumn_complete", "winter_complete",
		"finale_complete", "journey_complete",
	]
	for key in required_numeric:
		if not data.has(key) or not _is_saved_integer(data[key]):
			return {}
	for key in required_bools:
		if not data.has(key) or typeof(data[key]) != TYPE_BOOL:
			return {}
	for key in ["active_segment", "last_return_kind"]:
		if not data.has(key) or not data[key] is String:
			return {}
	var restored_reserve := int(data.reserve)
	var restored_sorties := int(data.sortie_count)
	var restored_active_token := int(data.active_token)
	var restored_settled_token := int(data.settled_token)
	if restored_reserve < 0 or restored_sorties < 0 or restored_active_token < 0:
		return {}
	if restored_reserve > 1_000_000 or restored_sorties > 1_000_000 or restored_active_token > 1_000_000:
		return {}
	if restored_active_token > restored_sorties or restored_settled_token < -1 or restored_settled_token > restored_active_token:
		return {}
	for key in ["last_deposit", "completed_pollinations", "incident_signs_resolved", "incident_honey_lost"]:
		if int(data[key]) < 0 or int(data[key]) > 1_000_000:
			return {}
	var valid_segments := ["", SPRING_ROUTE, SIGN_INCIDENT, SUMMER_RECOVERY, AUTUMN_HARVEST, WINTER_WARMTH, FINALE_HANDOFF]
	if String(data.active_segment) not in valid_segments or String(data.last_return_kind) not in valid_segments:
		return {}
	var first_done := bool(data.first_return_complete)
	var sign_done := bool(data.sign_incident_complete)
	var summer_done := bool(data.summer_complete)
	var autumn_done := bool(data.autumn_complete)
	var winter_done := bool(data.winter_complete)
	var finale_done := bool(data.finale_complete)
	if sign_done and not first_done:
		return {}
	if summer_done and not sign_done:
		return {}
	if autumn_done and not summer_done:
		return {}
	if winter_done and not autumn_done:
		return {}
	if finale_done and not winter_done:
		return {}
	if bool(data.journey_complete) != finale_done:
		return {}
	if bool(data.chapter_complete) != sign_done:
		return {}
	# Progress files are hive checkpoints, never half-finished field snapshots.
	# Exact token/segment relations keep an accidental mid-sortie save from
	# restoring as though its unhanded carried items had already been settled.
	if restored_active_token != restored_sorties:
		return {}
	var expected_segment := ""
	if finale_done:
		expected_segment = FINALE_HANDOFF
	elif winter_done:
		expected_segment = WINTER_WARMTH
	elif autumn_done:
		expected_segment = AUTUMN_HARVEST
	elif summer_done:
		expected_segment = SUMMER_RECOVERY
	elif sign_done:
		expected_segment = SIGN_INCIDENT
	elif first_done:
		expected_segment = SPRING_ROUTE
	if restored_active_token == 0:
		if restored_settled_token != -1 or not expected_segment.is_empty():
			return {}
		if not String(data.active_segment).is_empty() or not String(data.last_return_kind).is_empty():
			return {}
	else:
		if restored_settled_token != restored_active_token:
			return {}
		if String(data.active_segment) != expected_segment or String(data.last_return_kind) != expected_segment:
			return {}
	var restored_results := _validated_world_results(data.get("world_results", null))
	if restored_results.is_empty():
		return {}
	var source_results = data.get("world_results", {})
	if first_done and source_results is Dictionary and not (source_results as Dictionary).has("spring_honey_returned"):
		# Schema-v1 checkpoints predate the explicit spring ledger. That build only
		# accepted exactly six drops, so the missing value has one unambiguous
		# migration and does not need to invalidate an otherwise safe hive save.
		restored_results.spring_honey_returned = SPRING_HONEY_GOAL
	if not _world_results_match_progress(data, restored_results, expected_segment):
		return {}
	var expected_reserve := 0
	if first_done:
		expected_reserve = int(restored_results.spring_honey_returned)
	if sign_done:
		expected_reserve -= int(restored_results.spring_honey_lost)
	if summer_done:
		expected_reserve += int(restored_results.summer_honey_returned)
	if autumn_done:
		expected_reserve += int(restored_results.autumn_harvested)
	if restored_reserve != expected_reserve:
		return {}
	var validated := data.duplicate(true)
	validated.world_results = restored_results
	if data.has("solar_terms"):
		if not data.solar_terms is Dictionary:
			return {}
		var solar_version = data.solar_terms.get("schema_version", 0)
		if not _is_saved_integer(solar_version):
			return {}
		validated.solar_terms = (data.solar_terms as Dictionary).duplicate(true)
	return validated


func _world_results_match_progress(data: Dictionary, results: Dictionary, expected_segment: String) -> bool:
	var first_done := bool(data.first_return_complete)
	var sign_done := bool(data.sign_incident_complete)
	var summer_done := bool(data.summer_complete)
	var autumn_done := bool(data.autumn_complete)
	var winter_done := bool(data.winter_complete)
	var finale_done := bool(data.finale_complete)
	var spring_returned := int(results.spring_honey_returned)
	var spring_signs := int(results.spring_signs_resolved)
	var spring_lost := int(results.spring_honey_lost)
	if int(data.incident_signs_resolved) != spring_signs or int(data.incident_honey_lost) != spring_lost:
		return false
	if first_done:
		if spring_returned < SPRING_HONEY_GOAL or spring_returned > SPRING_TOTAL_HONEY:
			return false
	elif spring_returned != 0:
		return false
	if sign_done:
		if spring_signs != 3 or spring_lost < 0 or spring_lost > INCIDENT_STARTING_HONEY:
			return false
	else:
		if spring_signs != 0 or spring_lost != 0:
			return false
	if summer_done:
		if (
			int(results.summer_honey_returned) < SUMMER_HONEY_GOAL
			or int(results.summer_honey_returned) + int(results.summer_honey_lost) != SUMMER_TOTAL_HONEY
			or int(results.summer_belongings_recovered) != SUMMER_BELONGINGS_GOAL
			or not bool(results.summer_rest_hive_repaired)
		):
			return false
	elif (
		int(results.summer_honey_returned) != 0
		or int(results.summer_honey_lost) != 0
		or int(results.summer_belongings_recovered) != 0
		or bool(results.summer_rest_hive_repaired)
	):
		return false
	if autumn_done:
		if (
			int(results.autumn_harvested) + int(results.autumn_seeded) != AUTUMN_FLOWER_GOAL
			or int(results.autumn_echo_points) != AUTUMN_ECHO_GOAL
		):
			return false
	elif int(results.autumn_harvested) != 0 or int(results.autumn_seeded) != 0 or int(results.autumn_echo_points) != 0:
		return false
	if winter_done:
		if (
			int(results.winter_warmth_links) != WINTER_WARMTH_GOAL
			or int(results.winter_windbreak_segments) != WINTER_WINDBREAK_GOAL
			or not bool(results.winter_bear_helped)
		):
			return false
	elif int(results.winter_warmth_links) != 0 or int(results.winter_windbreak_segments) != 0 or bool(results.winter_bear_helped):
		return false
	if bool(results.finale_demonstration_complete) != finale_done:
		return false
	var last_deposit := int(data.last_deposit)
	var pollinations := int(data.completed_pollinations)
	match expected_segment:
		"":
			if last_deposit != 0 or pollinations != 0 or int(data.reserve) != 0:
				return false
		SPRING_ROUTE:
			if not first_done or last_deposit != spring_returned or int(data.reserve) != spring_returned:
				return false
		SIGN_INCIDENT:
			if last_deposit != INCIDENT_STARTING_HONEY - spring_lost or pollinations != 0:
				return false
		SUMMER_RECOVERY:
			if last_deposit != int(results.summer_honey_returned) or pollinations != 0:
				return false
		AUTUMN_HARVEST:
			if last_deposit != int(results.autumn_harvested) or pollinations != 0:
				return false
		WINTER_WARMTH, FINALE_HANDOFF:
			if last_deposit != 0 or pollinations != 0:
				return false
	var known_later_deposits := 0
	if sign_done:
		known_later_deposits += INCIDENT_STARTING_HONEY - spring_lost
	if summer_done:
		known_later_deposits += int(results.summer_honey_returned)
	if autumn_done:
		known_later_deposits += int(results.autumn_harvested)
	return int(data.reserve) >= known_later_deposits


func _validated_world_results(source: Variant) -> Dictionary:
	if not source is Dictionary:
		return {}
	var defaults := {
		"spring_honey_returned": 0,
		"spring_signs_resolved": 0,
		"spring_honey_lost": 0,
		"summer_honey_returned": 0,
		"summer_honey_lost": 0,
		"summer_belongings_recovered": 0,
		"summer_rest_hive_repaired": false,
		"autumn_harvested": 0,
		"autumn_seeded": 0,
		"autumn_echo_points": 0,
		"winter_warmth_links": 0,
		"winter_windbreak_segments": 0,
		"winter_bear_helped": false,
		"finale_demonstration_complete": false,
	}
	var result := defaults.duplicate(true)
	var dictionary := source as Dictionary
	for key in defaults:
		if not dictionary.has(key):
			continue
		if defaults[key] is bool:
			if typeof(dictionary[key]) != TYPE_BOOL:
				return {}
			result[key] = bool(dictionary[key])
		else:
			if not _is_saved_integer(dictionary[key]) or int(dictionary[key]) < 0:
				return {}
			result[key] = int(dictionary[key])
	return result


func _is_saved_integer(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and float(value) == floorf(float(value))
