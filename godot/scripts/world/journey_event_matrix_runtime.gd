class_name JourneyEventMatrixRuntime
extends RefCounted

## Runtime contract for the two authored three-pentad content slices.  The JSON
## remains the narrative source, while this object turns every `mechanic` into a
## small, testable interaction grammar.  It deliberately exposes only one event
## at a time so the field never becomes a fifteen-line checklist.

const EVENT_COUNT := 15
const EVENTS_PER_PENTAD := 5

const KIND_OBSERVATION := "observation"
const KIND_ROUTE := "route"
const KIND_CARGO := "cargo"
const KIND_AIR_CATCH := "air_catch"
const KIND_COOP_ANCHOR := "coop_anchor"
const KIND_ROUTE_CHOICE := "route_choice"
const KIND_CONVOY := "convoy"
const CHOICE_IDS := ["swift", "steady"]

const MECHANIC_KINDS := {
	"weather_window": KIND_OBSERVATION,
	"route_reveal": KIND_OBSERVATION,
	"trace_search": KIND_OBSERVATION,
	"weather_reread": KIND_OBSERVATION,
	"stabilize_lane": KIND_ROUTE,
	"rhythm_lane": KIND_ROUTE,
	"moving_shelter": KIND_CARGO,
	"mastery_lane": KIND_ROUTE,
	"evade_lane": KIND_ROUTE,
	"pollen_delivery": KIND_CARGO,
	"sequence_carry": KIND_CARGO,
	"handoff_timing": KIND_CARGO,
	"heavy_carry": KIND_CARGO,
	"moving_match": KIND_CARGO,
	"escort_shelter": KIND_AIR_CATCH,
	"partner_rescue": KIND_AIR_CATCH,
	"optional_recovery": KIND_AIR_CATCH,
	"air_catch": KIND_AIR_CATCH,
	"coop_anchor": KIND_COOP_ANCHOR,
	"spatial_match": KIND_COOP_ANCHOR,
	"convoy_anchor": KIND_COOP_ANCHOR,
	"load_choice": KIND_ROUTE_CHOICE,
	"support_choice": KIND_ROUTE_CHOICE,
	"convoy_route": KIND_CONVOY,
	"route_trial": KIND_CONVOY,
	"convoy_setpiece": KIND_CONVOY,
}

const MECHANIC_STEPS := {
	"weather_window": 2,
	"route_reveal": 3,
	"trace_search": 3,
	"weather_reread": 3,
	"stabilize_lane": 3,
	"rhythm_lane": 2,
	"moving_shelter": 3,
	"mastery_lane": 4,
	"evade_lane": 2,
	"pollen_delivery": 2,
	"sequence_carry": 3,
	"handoff_timing": 3,
	"heavy_carry": 1,
	"moving_match": 3,
	"escort_shelter": 2,
	"partner_rescue": 2,
	"optional_recovery": 1,
	"air_catch": 3,
	"coop_anchor": 2,
	"spatial_match": 3,
	"convoy_anchor": 3,
	"load_choice": 2,
	"support_choice": 2,
	"convoy_route": 3,
	"route_trial": 3,
	"convoy_setpiece": 5,
}

const EVADE_MECHANICS := ["stabilize_lane", "mastery_lane", "evade_lane"]
const MOVING_TARGET_MECHANICS := [
	"moving_shelter", "escort_shelter", "partner_rescue", "air_catch", "moving_match",
]
const WEATHER_WINDOW_MECHANICS := ["weather_window"]
const RHYTHM_MECHANICS := ["rhythm_lane", "handoff_timing"]
const HEAVY_LOAD_MECHANICS := ["heavy_carry"]

const OPTIONAL_ENERGY_REWARDS := {
	"coop_anchor": 4.0,
	"pollen_delivery": 6.0,
	"handoff_timing": 8.0,
	"escort_shelter": 5.0,
	"mastery_lane": 0.0,
	"weather_reread": 3.0,
	"spatial_match": 4.0,
	"optional_recovery": 12.0,
	"support_choice": 5.0,
}
const OPTIONAL_SUPPORT_EFFECTS := {
	"coop_anchor": "route_fixture",
	"pollen_delivery": "bloom_help",
	"handoff_timing": "handoff_rhythm",
	"escort_shelter": "leaf_shelter",
	"mastery_lane": "route_mastery",
	"weather_reread": "weather_read",
	"spatial_match": "inventory_order",
	"optional_recovery": "spare_sign",
	"support_choice": "storm_support",
}

var events: Array[Dictionary] = []
var current_index := 0
var current_progress := 0
var current_optional_state := "none"
var current_choice := ""
var evade_registered := false
var completed_event_ids: Array[String] = []
var completed_mandatory_ids: Array[String] = []
var completed_optional_ids: Array[String] = []
var skipped_optional_ids: Array[String] = []
var support_points := 0
var world_state := {}


func configure(source_events: Array) -> Error:
	events.clear()
	if source_events.size() != EVENT_COUNT:
		return ERR_INVALID_DATA
	for index in source_events.size():
		var source = source_events[index]
		if not source is Dictionary:
			return ERR_INVALID_DATA
		var event := (source as Dictionary).duplicate(true)
		var mechanic := String(event.get("mechanic", ""))
		if (
			String(event.get("id", "")).is_empty()
			or not MECHANIC_KINDS.has(mechanic)
			or int(event.get("order", -1)) != index + 1
			or int(event.get("pentad", -1)) != index / EVENTS_PER_PENTAD + 1
		):
			return ERR_INVALID_DATA
		event["runtime_kind"] = String(MECHANIC_KINDS[mechanic])
		var authored_steps := int(event.get("runtime_steps", MECHANIC_STEPS[mechanic]))
		if authored_steps <= 0 or authored_steps > 6:
			return ERR_INVALID_DATA
		event["steps_required"] = authored_steps
		event["requires_evade"] = mechanic in EVADE_MECHANICS
		event["moving_target"] = mechanic in MOVING_TARGET_MECHANICS
		event["requires_weather_window"] = mechanic in WEATHER_WINDOW_MECHANICS
		event["requires_rhythm"] = mechanic in RHYTHM_MECHANICS
		event["heavy_load"] = mechanic in HEAVY_LOAD_MECHANICS
		var choice_options = event.get("choice_options", {})
		if not choice_options is Dictionary:
			return ERR_INVALID_DATA
		if not (choice_options as Dictionary).is_empty():
			if (choice_options as Dictionary).size() != CHOICE_IDS.size():
				return ERR_INVALID_DATA
			for choice_id in CHOICE_IDS:
				var option = (choice_options as Dictionary).get(choice_id, {})
				if (
					not option is Dictionary
					or String((option as Dictionary).get("label", "")).is_empty()
					or String((option as Dictionary).get("effect", "")).is_empty()
					or int((option as Dictionary).get("steps", 0)) <= 0
				):
					return ERR_INVALID_DATA
		events.append(event)
	_reset_progress()
	return OK


func checkpoint_snapshot() -> Dictionary:
	# Only whole-pentad boundaries are restart-safe. Mid-event state includes
	# physical positions and carried objects, so pretending it can be resumed
	# would be less honest than replaying the current five-event block.
	if current_progress != 0 or current_index not in [EVENTS_PER_PENTAD, EVENTS_PER_PENTAD * 2]:
		return {}
	return {
		"next_event_number": current_index + 1,
		"pentads_completed": pentads_completed(),
		"completed_mandatory_ids": completed_mandatory_ids.duplicate(),
		"completed_optional_ids": completed_optional_ids.duplicate(),
		"skipped_optional_ids": skipped_optional_ids.duplicate(),
		"route_choices": (world_state.get("route_choices", {}) as Dictionary).duplicate(true),
		"support_points": support_points,
		"world_state": world_state.duplicate(true),
	}


func restore_checkpoint(source: Dictionary) -> Error:
	if events.size() != EVENT_COUNT:
		return ERR_UNCONFIGURED
	var error := _restore_checkpoint_in_place(source)
	if error != OK:
		# A rejected save must never leave a half-replayed runtime behind.  The
		# caller can safely fall back to a fresh sortie after any validation error.
		_reset_progress()
	return error


func _restore_checkpoint_in_place(source: Dictionary) -> Error:
	var keys := [
		"next_event_number", "pentads_completed", "completed_mandatory_ids",
		"completed_optional_ids", "skipped_optional_ids", "route_choices",
		"support_points", "world_state",
	]
	if source.size() != keys.size():
		return ERR_INVALID_DATA
	for key in keys:
		if not source.has(key):
			return ERR_INVALID_DATA
	if (
		not _is_saved_integer(source.next_event_number)
		or not _is_saved_integer(source.pentads_completed)
		or not _is_saved_integer(source.support_points)
	):
		return ERR_INVALID_DATA
	var next_event_number := int(source.next_event_number)
	if next_event_number not in [EVENTS_PER_PENTAD + 1, EVENTS_PER_PENTAD * 2 + 1]:
		return ERR_INVALID_DATA
	var expected_pentads := 1 if next_event_number == EVENTS_PER_PENTAD + 1 else 2
	if int(source.pentads_completed) != expected_pentads or int(source.support_points) < 0:
		return ERR_INVALID_DATA
	for key in [
		"completed_mandatory_ids", "completed_optional_ids", "skipped_optional_ids",
	]:
		if not source.get(key, null) is Array:
			return ERR_INVALID_DATA
	if not source.get("route_choices", null) is Dictionary or not source.get("world_state", null) is Dictionary:
		return ERR_INVALID_DATA
	var completed_mandatory: Array = source.completed_mandatory_ids
	var completed_optional: Array = source.completed_optional_ids
	var skipped_optional: Array = source.skipped_optional_ids
	var completed_lookup := {}
	var skipped_lookup := {}
	for event_id in completed_mandatory:
		completed_lookup[String(event_id)] = true
	for event_id in completed_optional:
		completed_lookup[String(event_id)] = true
	for event_id in skipped_optional:
		skipped_lookup[String(event_id)] = true
	var route_choices := source.route_choices as Dictionary
	_reset_progress()
	var target_index := next_event_number - 1
	var guard := 0
	while current_index < target_index and guard < 128:
		guard += 1
		var event_id := String(current_event().get("id", ""))
		if optional_pending():
			if skipped_lookup.has(event_id):
				if not bool(skip_optional().get("accepted", false)):
					return ERR_INVALID_DATA
				continue
			if not completed_lookup.has(event_id) or not accept_optional():
				return ERR_INVALID_DATA
		elif not completed_lookup.has(event_id):
			return ERR_INVALID_DATA
		if choice_pending() and not choose_route(String(route_choices.get(event_id, ""))):
			return ERR_INVALID_DATA
		if requires_evade():
			note_evade()
		var step_result := record_step(current_kind())
		if not bool(step_result.get("accepted", false)):
			return ERR_INVALID_DATA
	if current_index != target_index or current_progress != 0:
		return ERR_INVALID_DATA
	var restored := checkpoint_snapshot()
	if (
		(restored.get("completed_mandatory_ids", []) as Array) != completed_mandatory
		or (restored.get("completed_optional_ids", []) as Array) != completed_optional
		or (restored.get("skipped_optional_ids", []) as Array) != skipped_optional
		or (restored.get("route_choices", {}) as Dictionary) != route_choices
		or int(restored.get("pentads_completed", -1)) != int(source.pentads_completed)
		or int(restored.get("support_points", -1)) != int(source.support_points)
		or (restored.get("world_state", {}) as Dictionary) != (source.world_state as Dictionary)
	):
		return ERR_INVALID_DATA
	return OK


func _is_saved_integer(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or (
		typeof(value) == TYPE_FLOAT
		and is_finite(float(value))
		and is_equal_approx(float(value), roundf(float(value)))
	)


func _reset_progress() -> void:
	current_index = 0
	current_progress = 0
	current_choice = ""
	evade_registered = false
	completed_event_ids.clear()
	completed_mandatory_ids.clear()
	completed_optional_ids.clear()
	skipped_optional_ids.clear()
	support_points = 0
	world_state = {
		"observed_signals": 0,
		"opened_route_segments": 0,
		"delivered_loads": 0,
		"caught_objects": 0,
		"anchored_supports": 0,
		"convoy_segments": 0,
		"route_choices": {},
		"support_points": 0,
		"support_effects": {},
		"event_outcomes": {},
		"pollination_deliveries": 0,
		"route_work_completed": 0,
		"caught_signs": 0,
		"anchored_signs": 0,
		"setpiece_complete": false,
		"bloom_stage": 0,
	}
	_refresh_optional_state()


func _refresh_optional_state() -> void:
	if is_finished():
		current_optional_state = "none"
		return
	current_optional_state = "pending" if bool(events[current_index].get("optional", false)) else "none"


func is_finished() -> bool:
	return current_index >= events.size()


func event_count() -> int:
	return events.size()


func current_event() -> Dictionary:
	if is_finished():
		return {}
	return events[current_index].duplicate(true)


func current_kind() -> String:
	return "complete" if is_finished() else String(events[current_index].get("runtime_kind", ""))


func current_mechanic() -> String:
	return "" if is_finished() else String(events[current_index].get("mechanic", ""))


func current_required_steps() -> int:
	if is_finished():
		return 0
	var required := 1
	var options := _current_choice_options()
	if not options.is_empty():
		if not current_choice.is_empty():
			required = int((options.get(current_choice, {}) as Dictionary).get("steps", 1))
		else:
			for choice_id in CHOICE_IDS:
				required = maxi(
					required,
					int((options.get(choice_id, {}) as Dictionary).get("steps", 1))
				)
	else:
		required = int(events[current_index].get("steps_required", 1))
	# Recovering the optional old sign does not skip the chase.  It gives one
	# concrete catch tolerance in Guyu's three-sign pursuit, so an earlier small
	# kindness changes the later route without becoming a generic stat bonus.
	if (
		String(events[current_index].get("id", "")) == "guyu_12_air_chase"
		and int((world_state.get("support_effects", {}) as Dictionary).get("spare_sign", 0)) > 0
	):
		required -= 1
	return maxi(1, required)


func _current_choice_options() -> Dictionary:
	if is_finished():
		return {}
	var options = events[current_index].get("choice_options", {})
	return (options as Dictionary) if options is Dictionary else {}


func current_pentad() -> int:
	if is_finished():
		return 3
	return int(events[current_index].get("pentad", 1))


func pentads_completed() -> int:
	if is_finished():
		return 3
	return clampi(current_index / EVENTS_PER_PENTAD, 0, 2)


func optional_pending() -> bool:
	return not is_finished() and current_optional_state == "pending"


func optional_accepted() -> bool:
	return not is_finished() and current_optional_state == "accepted"


func choice_pending() -> bool:
	return not is_finished() and not _current_choice_options().is_empty() and current_choice.is_empty()


func requires_evade() -> bool:
	return not is_finished() and bool(events[current_index].get("requires_evade", false))


func has_moving_target() -> bool:
	return not is_finished() and bool(events[current_index].get("moving_target", false))


func requires_weather_window() -> bool:
	return not is_finished() and bool(events[current_index].get("requires_weather_window", false))


func requires_rhythm() -> bool:
	return not is_finished() and bool(events[current_index].get("requires_rhythm", false))


func uses_heavy_load() -> bool:
	if is_finished():
		return false
	return bool(events[current_index].get("heavy_load", false)) or choice_effect() == "heavy_single"


func choice_effect() -> String:
	if is_finished() or current_choice.is_empty():
		return ""
	return String((_current_choice_options().get(current_choice, {}) as Dictionary).get("effect", ""))


func choice_label(choice_id: String) -> String:
	if choice_id not in CHOICE_IDS:
		return ""
	return String((_current_choice_options().get(choice_id, {}) as Dictionary).get("label", ""))


func accept_optional() -> bool:
	if not optional_pending():
		return false
	current_optional_state = "accepted"
	return true


func skip_optional() -> Dictionary:
	if not optional_pending():
		return {"accepted": false}
	var skipped := current_event()
	skipped_optional_ids.append(String(skipped.get("id", "")))
	_advance_event()
	return {
		"accepted": true,
		"skipped": true,
		"event": skipped,
		"level_complete": is_finished(),
	}


func choose_route(choice: String) -> bool:
	if optional_pending() or not choice_pending() or choice not in CHOICE_IDS:
		return false
	current_choice = choice
	(world_state["route_choices"] as Dictionary)[String(events[current_index].get("id", ""))] = choice
	return true


func note_evade() -> void:
	if not is_finished():
		evade_registered = true


func clear_evade() -> void:
	evade_registered = false


func record_step(kind: String) -> Dictionary:
	if is_finished() or optional_pending() or kind != current_kind():
		return {"accepted": false}
	if choice_pending():
		return {"accepted": false, "needs_choice": true}
	if requires_evade() and not evade_registered:
		return {"accepted": false, "needs_evade": true}
	current_progress += 1
	_accumulate_world_step(kind)
	if current_progress < current_required_steps():
		# A multi-gate evade lane asks for a fresh turn at every wind mouth.  One
		# early double-tap must not silently authorize the rest of the event.
		if requires_evade():
			evade_registered = false
		return {
			"accepted": true,
			"event_complete": false,
			"progress": current_progress,
			"required": current_required_steps(),
		}
	return _complete_current_event()


func _accumulate_world_step(kind: String) -> void:
	match kind:
		KIND_OBSERVATION: world_state["observed_signals"] = int(world_state["observed_signals"]) + 1
		KIND_ROUTE: world_state["opened_route_segments"] = int(world_state["opened_route_segments"]) + 1
		KIND_CARGO: world_state["delivered_loads"] = int(world_state["delivered_loads"]) + 1
		KIND_AIR_CATCH: world_state["caught_objects"] = int(world_state["caught_objects"]) + 1
		KIND_COOP_ANCHOR: world_state["anchored_supports"] = int(world_state["anchored_supports"]) + 1
		KIND_ROUTE_CHOICE: world_state["opened_route_segments"] = int(world_state["opened_route_segments"]) + 1
		KIND_CONVOY: world_state["convoy_segments"] = int(world_state["convoy_segments"]) + 1


func _complete_current_event() -> Dictionary:
	var completed := current_event()
	var event_id := String(completed.get("id", ""))
	var optional := bool(completed.get("optional", false))
	completed_event_ids.append(event_id)
	var energy_reward := 0.0
	if optional:
		completed_optional_ids.append(event_id)
		support_points += 1
		var mechanic := String(completed.get("mechanic", ""))
		energy_reward = float(OPTIONAL_ENERGY_REWARDS.get(mechanic, 4.0))
		world_state["support_points"] = support_points
		var support_effect := String(OPTIONAL_SUPPORT_EFFECTS.get(mechanic, "neighbour_help"))
		var support_effects := world_state.get("support_effects", {}) as Dictionary
		support_effects[support_effect] = int(support_effects.get(support_effect, 0)) + 1
	else:
		completed_mandatory_ids.append(event_id)
	_record_event_outcome(completed)
	_update_causal_world_progress(completed)
	var result := {
		"accepted": true,
		"event_complete": true,
		"event": completed,
		"optional_completed": optional,
		"energy_reward": energy_reward,
		"support_points": support_points,
	}
	_advance_event()
	result["level_complete"] = is_finished()
	result["pentads_completed"] = pentads_completed()
	return result


func _record_event_outcome(completed: Dictionary) -> void:
	var event_id := String(completed.get("id", ""))
	var outcomes := world_state.get("event_outcomes", {}) as Dictionary
	outcomes[event_id] = {
		"choice": current_choice,
		"choice_effect": choice_effect(),
		"consequence": String(completed.get("consequence", "")),
		"optional": bool(completed.get("optional", false)),
	}


func _update_causal_world_progress(completed: Dictionary) -> void:
	var event_id := String(completed.get("id", ""))
	var mechanic := String(completed.get("mechanic", ""))
	if mechanic in ["pollen_delivery", "moving_shelter"]:
		world_state["pollination_deliveries"] = int(world_state["pollination_deliveries"]) + 1
	if mechanic in [
		"stabilize_lane", "rhythm_lane", "route_reveal", "sequence_carry",
		"load_choice", "convoy_route", "evade_lane", "route_trial",
	]:
		world_state["route_work_completed"] = int(world_state["route_work_completed"]) + 1
	if mechanic in ["air_catch", "optional_recovery"]:
		world_state["caught_signs"] = int(world_state["caught_signs"]) + 1
	if mechanic in ["coop_anchor", "spatial_match", "convoy_anchor"]:
		world_state["anchored_signs"] = int(world_state["anchored_signs"]) + 1
	if event_id.begins_with("yushui_"):
		var pollen := int(world_state["pollination_deliveries"])
		var route_work := int(world_state["route_work_completed"])
		var event_order := int(completed.get("order", 0))
		var stage := 0
		# The first-hou delivery leaves only pollen traces.  Visible bloom waits
		# until the moving rain window is actually repaired in event 10.
		if pollen >= 1 and event_order >= 10:
			stage = 1
		if pollen >= 1 and route_work >= 3 and event_order >= 11:
			stage = 2
		if mechanic == "convoy_setpiece" and pollen >= 1 and route_work >= 4:
			stage = 3
			world_state["setpiece_complete"] = true
		world_state["bloom_stage"] = maxi(int(world_state["bloom_stage"]), stage)
	elif event_id.begins_with("guyu_"):
		var caught := int(world_state["caught_signs"])
		var anchored := int(world_state["anchored_signs"])
		var route_work := int(world_state["route_work_completed"])
		var stage := 0
		if caught >= 1:
			stage = 1
		if caught >= 2 and anchored >= 1:
			stage = 2
		if mechanic == "convoy_setpiece" and caught >= 2 and anchored >= 1 and route_work >= 2:
			stage = 3
			world_state["setpiece_complete"] = true
		world_state["bloom_stage"] = maxi(int(world_state["bloom_stage"]), stage)


func _advance_event() -> void:
	current_index += 1
	current_progress = 0
	current_choice = ""
	evade_registered = false
	_refresh_optional_state()


func mandatory_total() -> int:
	var total := 0
	for event in events:
		total += 0 if bool(event.get("optional", false)) else 1
	return total


func optional_total() -> int:
	return events.size() - mandatory_total()


func can_finish() -> bool:
	return (
		is_finished()
		and completed_mandatory_ids.size() == mandatory_total()
		and bool(world_state.get("setpiece_complete", false))
	)


func hazard_scale() -> float:
	# Different optional jobs leave different support. Inventory and bloom help do
	# not masquerade as a generic wind buff; only route/weather support softens it.
	var effects := world_state.get("support_effects", {}) as Dictionary
	var scale := 1.0
	scale -= float(effects.get("leaf_shelter", 0)) * 0.10
	scale -= float(effects.get("weather_read", 0)) * 0.08
	scale -= float(effects.get("route_fixture", 0)) * 0.06
	scale -= float(effects.get("route_mastery", 0)) * 0.04
	scale -= float(effects.get("storm_support", 0)) * 0.08
	for event_id in world_state.get("route_choices", {}):
		var choice := String((world_state["route_choices"] as Dictionary).get(event_id, ""))
		if String(event_id).ends_with("seal_or_rope"):
			scale -= 0.08 if choice == "steady" else 0.04
		elif String(event_id).ends_with("replace_wet_rope"):
			scale -= 0.05 if choice == "steady" else 0.03
	return maxf(0.62, scale)


func snapshot() -> Dictionary:
	var event := current_event()
	return {
		"event_count": events.size(),
		"current_event_number": mini(current_index + 1, events.size()),
		"current_event_id": String(event.get("id", "")),
		"current_event_title": String(event.get("title", "")),
		"current_mechanic": String(event.get("mechanic", "")),
		"runtime_kind": current_kind(),
		"ui_hint": String(event.get("ui_hint", "")),
		"pentad": current_pentad(),
		"pentads_completed": pentads_completed(),
		"optional": bool(event.get("optional", false)),
		"optional_state": current_optional_state,
		"choice": current_choice,
		"choice_pending": choice_pending(),
		"swift_label": choice_label("swift"),
		"steady_label": choice_label("steady"),
		"progress": current_progress,
		"required": current_required_steps(),
		"requires_evade": requires_evade(),
		"evade_registered": evade_registered,
		"moving_target": has_moving_target(),
		"requires_weather_window": requires_weather_window(),
		"requires_rhythm": requires_rhythm(),
		"heavy_load": uses_heavy_load(),
		"choice_effect": choice_effect(),
		"mandatory_completed": completed_mandatory_ids.size(),
		"mandatory_total": mandatory_total(),
		"optional_completed": completed_optional_ids.size(),
		"optional_skipped": skipped_optional_ids.size(),
		"optional_total": optional_total(),
		"support_points": support_points,
		"completed_event_ids": completed_event_ids.duplicate(),
		"completed_mandatory_ids": completed_mandatory_ids.duplicate(),
		"completed_optional_ids": completed_optional_ids.duplicate(),
		"skipped_optional_ids": skipped_optional_ids.duplicate(),
		"route_choices": (world_state.get("route_choices", {}) as Dictionary).duplicate(true),
		"world_state": world_state.duplicate(true),
		"finished": is_finished(),
		"can_finish": can_finish(),
	}
