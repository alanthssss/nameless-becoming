class_name PollinationMechanic
extends RefCounted
## 春 · 开放花传粉。
##
## `pollen_charges` is the only gameplay truth. Both visible flower variants may
## be carried at once, and each is capped at two exact charges. Every charge stays
## visible across the bee body and active world feedback; the shared motif language
## connects anther -> bee -> compatible stigma -> seed. Pollination never creates,
## stores or restores nectar.

const PollenVisualLanguageScript := preload("res://scripts/mechanics/pollen_visual_language.gd")
const POLLEN_VARIANT_COUNT := 2
const MAX_CHARGES_PER_VARIANT := 2
const TRANSFER_DURATION := 0.46
const REJECTION_DURATION := 0.42
## The launch bee is 82 x 60. Rejection feedback is drawn by Main behind the bee
## child, so its grain center must stay beyond the body plus one grain's clearance.
const BEE_VISUAL_HALF_EXTENTS := Vector2(41.0, 30.0)
const REJECTION_CLEARANCE := 9.0
const REJECTION_ROUTE_RADIUS := 68.0
const REJECTION_DEPART_FRACTION := 0.20
const REJECTION_RETURN_ARC_FRACTION := 0.85

var mechanic_id := "pollination"
var main
var deposit_range := 58.0
var pollinated_flowers := 0
var donor_indices: Array[int] = []
var receptive_indices: Array[int] = []
var pollen_charges: Array[int] = [0, 0]
var registered_flower_count := 0
## Active world feedback. A successful transfer owns the single in-flight slot
## until landing so another action cannot overwrite it or pollinate twice.
var feedback_event: Dictionary = {}
## Persistent diagnostic evidence for headless tests; never drives gameplay.
var last_feedback: Dictionary = {}


func start(game, _data: Dictionary, balance: Dictionary) -> void:
	main = game
	var mechanics: Dictionary = balance.get("mechanics", {})
	var params: Dictionary = mechanics.get("pollination", {})
	deposit_range = float(params.get("deposit_range", 58.0))
	pollinated_flowers = 0
	pollen_charges = [0, 0]
	feedback_event.clear()
	last_feedback.clear()
	donor_indices.clear()
	receptive_indices.clear()
	registered_flower_count = 0
	_sync_body_loads()
	if main.flowers.size() < 2:
		return

	# Give every visible variant a donor before filling the rest of the donor half.
	# The arrays are traversal caches only: flower fields drive both drawing and play.
	var donor_flags := {}
	for variant in POLLEN_VARIANT_COUNT:
		for i in main.flowers.size():
			if _visible_variant(main.flowers[i]) == variant:
				donor_flags[i] = true
				break
	var donor_count := maxi(donor_flags.size(), int(ceil(float(main.flowers.size()) * 0.5)))
	for i in main.flowers.size():
		if donor_flags.size() >= donor_count:
			break
		if not donor_flags.has(i):
			donor_flags[i] = true

	for i in main.flowers.size():
		_register_flower(i, donor_flags.has(i))
	# Completion targets must not remain generic closed buds while the HUD already
	# requires them. Mentor permissions still control when deposition is attempted.
	if String(_data.get("tutorial_profile", "")) == "first_trip_pollination" and not bool(main.tutorial_complete):
		for index in receptive_indices:
			var receptive: Dictionary = main.flowers[index]
			receptive["tutorial_locked"] = false
			main.flowers[index] = receptive
	registered_flower_count = main.flowers.size()


func process(delta: float) -> void:
	# Pollen has no hidden expiry. A player who is distracted can always read the
	# body load again or stop and sense the matching stigma.
	_register_new_flowers()
	_update_feedback(delta)


func on_harvest(flower_index: int) -> void:
	_register_new_flowers()
	if flower_index < 0 or flower_index >= main.flowers.size():
		return
	var flower: Dictionary = main.flowers[flower_index]
	if not bool(flower.get("has_anthers", false)):
		return
	var variant := int(flower.get("pollen_variant", -1))
	if not PollenVisualLanguageScript.valid_variant(variant):
		return
	pollen_charges[variant] = mini(MAX_CHARGES_PER_VARIANT, pollen_charges[variant] + 1)
	_sync_body_loads()
	main.message = "散粉附在蜂身上。"


func on_context_action() -> bool:
	if main == null or main.bee == null:
		return false
	return _deposit_at(main.bee.position)


func try_context_action(position: Vector2) -> bool:
	return _deposit_at(position)


func _deposit_at(position: Vector2) -> bool:
	# One visible grain is already travelling. Consume the repeated press without
	# starting another transfer or allowing a second action to overwrite its target.
	if _deposit_in_flight():
		return true
	var flower_index := nearest_receptive_flower_at(position)
	if flower_index < 0:
		return false
	var flower: Dictionary = main.flowers[flower_index]
	var required_variant := int(flower.get("stigma_variant", -1))
	if not PollenVisualLanguageScript.valid_variant(required_variant):
		return false
	if active_pollen_variants().is_empty():
		_start_empty_load(flower_index, required_variant)
		return true
	if pollen_charges[required_variant] <= 0:
		_start_rejection(flower_index, required_variant)
		return true
	_start_transfer(flower_index, required_variant)
	return true


func _start_transfer(flower_index: int, variant: int) -> void:
	var flower: Dictionary = main.flowers[flower_index]
	pollen_charges[variant] -= 1
	flower["pollination_pending"] = true
	main.flowers[flower_index] = flower
	feedback_event = {
		"kind": "deposit",
		"variant": variant,
		"target_variant": variant,
		"flower_index": flower_index,
		"source_position": _body_slot_world(variant),
		"target_position": Vector2(flower.position),
		"duration": TRANSFER_DURATION,
		"remaining": TRANSFER_DURATION
	}
	# A previous rejection may be replaced by this valid transfer. Synchronize only
	# after the event changes so its temporarily withheld body grain is restored,
	# while the authoritative transfer decrement remains visible.
	_sync_body_loads()
	last_feedback = feedback_event.duplicate(true)
	last_feedback["kind"] = "deposit_started"
	main.message = "一粒散粉正从蜂身落向同型花心。"


func _start_empty_load(flower_index: int, required_variant: int) -> void:
	var flower: Dictionary = main.flowers[flower_index]
	feedback_event = {
		"kind": "empty_load",
		"variant": -1,
		"target_variant": required_variant,
		"flower_index": flower_index,
		"target_position": Vector2(flower.position),
		"duration": REJECTION_DURATION,
		"remaining": REJECTION_DURATION
	}
	_sync_body_loads()
	last_feedback = feedback_event.duplicate(true)
	main.message = "蜂身没有散粉。先贴近带散粉的花心采蜜。"


func _start_rejection(flower_index: int, required_variant: int) -> void:
	var attempted_variant := _first_wrong_carried_variant(required_variant)
	var flower: Dictionary = main.flowers[flower_index]
	var bee_origin := Vector2(main.bee.position)
	var bee_facing := float(main.bee.facing)
	feedback_event = {
		"kind": "rejection",
		"variant": attempted_variant,
		"target_variant": required_variant,
		"flower_index": flower_index,
		"source_position": _body_exterior_slot_world(attempted_variant) if attempted_variant >= 0 else bee_origin,
		"target_position": Vector2(flower.position),
		"bee_origin": bee_origin,
		"bee_facing": bee_facing,
		"duration": REJECTION_DURATION,
		"remaining": REJECTION_DURATION
	}
	# Rules keep the rejected grain. Presentation temporarily removes exactly that
	# one body grain while the same grain is visibly outside the silhouette.
	_sync_body_loads()
	last_feedback = feedback_event.duplicate(true)
	main.sound.play_cue("mismatch")
	main.message = "散粉形态没有与这个花心相合。"


func _update_feedback(delta: float) -> void:
	if feedback_event.is_empty():
		return
	feedback_event["remaining"] = maxf(0.0, float(feedback_event.get("remaining", 0.0)) - delta)
	if float(feedback_event.remaining) > 0.0:
		return
	var completed_event := feedback_event.duplicate(true)
	_clear_feedback_event()
	if String(completed_event.get("kind", "")) == "deposit":
		_land_transfer(completed_event)


func _land_transfer(event: Dictionary) -> void:
	var flower_index := int(event.get("flower_index", -1))
	var variant := int(event.get("variant", -1))
	if flower_index < 0 or flower_index >= main.flowers.size():
		_refund_cancelled_transfer(variant)
		return
	var flower: Dictionary = main.flowers[flower_index]
	if not bool(flower.get("pollination_pending", false)):
		_refund_cancelled_transfer(variant)
		return
	flower["pollination_pending"] = false
	flower["pollinated"] = true
	flower["seed_setting"] = true
	main.flowers[flower_index] = flower
	pollinated_flowers += 1
	last_feedback = event.duplicate(true)
	last_feedback["kind"] = "deposit_landed"
	main.flash = maxf(float(main.flash), 0.24)
	main.sound.play_cue("pollinate")
	main.message = "同形散粉落在花心，开始结籽。"


func _refund_cancelled_transfer(variant: int) -> void:
	if PollenVisualLanguageScript.valid_variant(variant):
		pollen_charges[variant] = mini(MAX_CHARGES_PER_VARIANT, pollen_charges[variant] + 1)
		_sync_body_loads()
	last_feedback = {"kind": "deposit_cancelled", "variant": variant}


func _deposit_in_flight() -> bool:
	return String(feedback_event.get("kind", "")) == "deposit"


func _clear_feedback_event() -> void:
	feedback_event.clear()
	_sync_body_loads()


func context_action_id(position: Vector2) -> String:
	if nearest_receptive_flower_at(position) < 0:
		return ""
	if active_pollen_variants().is_empty():
		return "needs_pollen"
	return "deposit_pollen"


func required_pollination_count() -> int:
	return mini(2, receptive_indices.size())


func can_complete() -> bool:
	return pollinated_flowers >= required_pollination_count()


func hud_status() -> String:
	var required := required_pollination_count()
	return "传粉 %d / %d" % [mini(pollinated_flowers, required), required]


func is_flower_available(index: int) -> bool:
	# Donors and receptive flowers remain ordinary nectar sources before and after
	# reproduction. Pending only protects the reproduction action itself.
	return index >= 0 and index < main.flowers.size()


func active_pollen_variants() -> Array[int]:
	var active: Array[int] = []
	for variant in pollen_charges.size():
		if pollen_charges[variant] > 0:
			active.append(variant)
	return active


func has_pollen_variant(variant: int) -> bool:
	return variant >= 0 and variant < pollen_charges.size() and pollen_charges[variant] > 0


func motif_id_for_variant(variant: int) -> String:
	return PollenVisualLanguageScript.motif_id(variant)


func matching_sense_targets() -> Dictionary:
	var targets := {}
	if main == null or main.bee == null:
		return targets
	for variant in active_pollen_variants():
		var target := nearest_matching_receptive(variant, Vector2(main.bee.position))
		if target >= 0:
			targets[variant] = target
	return targets


func sense_focus_active() -> bool:
	# Do not suppress ordinary flower sensing if a stale load has no legal target.
	# That state should not occur in authored spring stages, but failing open avoids a
	# blank sense screen in malformed/debug data.
	return not matching_sense_targets().is_empty()


func nearest_receptive_flower_at(position: Vector2) -> int:
	_register_new_flowers()
	var nearest := -1
	var nearest_distance := deposit_range
	for index in receptive_indices:
		if index < 0 or index >= main.flowers.size():
			continue
		var flower: Dictionary = main.flowers[index]
		if (
			not bool(flower.get("receptive_stigma", false))
			or bool(flower.get("pollinated", false))
			or bool(flower.get("pollination_pending", false))
		):
			continue
		if bool(flower.get("tutorial_hidden", false)) and not bool(flower.get("discovered", false)):
			continue
		if bool(flower.get("tutorial_locked", false)):
			continue
		var distance: float = position.distance_to(Vector2(flower.position))
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = index
	return nearest


func nearest_matching_receptive(variant: int, origin: Vector2) -> int:
	_register_new_flowers()
	var nearest := -1
	var nearest_distance := INF
	for index in receptive_indices:
		if index < 0 or index >= main.flowers.size():
			continue
		var flower: Dictionary = main.flowers[index]
		if (
			not bool(flower.get("receptive_stigma", false))
			or bool(flower.get("pollinated", false))
			or bool(flower.get("pollination_pending", false))
			or int(flower.get("stigma_variant", -1)) != variant
		):
			continue
		if not _flower_is_visible(flower):
			continue
		var distance := origin.distance_to(Vector2(flower.position))
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = index
	return nearest


func visual_state_for_flower(index: int) -> String:
	if index < 0 or index >= main.flowers.size():
		return "ordinary"
	var flower: Dictionary = main.flowers[index]
	if bool(flower.get("seed_setting", false)):
		return "seed_setting"
	if bool(flower.get("pollination_pending", false)):
		return "pollination_pending"
	if bool(flower.get("has_anthers", false)):
		return "donor_anthers" if int(flower.get("nectar", 0)) > 0 else "spent_donor"
	if bool(flower.get("receptive_stigma", false)):
		return "receptive_stigma"
	return "ordinary"


func _visible_variant(flower: Dictionary) -> int:
	return clampi(int(flower.get("visual_variant", 0)), 0, POLLEN_VARIANT_COUNT - 1)


func _register_flower(index: int, is_donor: bool) -> void:
	if index < 0 or index >= main.flowers.size():
		return
	var flower: Dictionary = main.flowers[index]
	var variant := _visible_variant(flower)
	flower["sleeping"] = false
	flower["has_anthers"] = is_donor
	flower["receptive_stigma"] = not is_donor
	flower["pollen_variant"] = variant if is_donor else -1
	flower["stigma_variant"] = variant if not is_donor else -1
	flower["pollinated"] = false
	flower["pollination_pending"] = false
	flower["seed_setting"] = false
	if is_donor:
		donor_indices.append(index)
	else:
		receptive_indices.append(index)
	main.flowers[index] = flower


func _register_new_flowers() -> void:
	if main == null:
		return
	while registered_flower_count < main.flowers.size():
		var index := registered_flower_count
		var variant := _visible_variant(main.flowers[index])
		var donors_of_variant := 0
		var receptive_of_variant := 0
		for donor_index in donor_indices:
			if donor_index < main.flowers.size() and int(main.flowers[donor_index].get("pollen_variant", -1)) == variant:
				donors_of_variant += 1
		for receptive_index in receptive_indices:
			if receptive_index < main.flowers.size() and int(main.flowers[receptive_index].get("stigma_variant", -1)) == variant:
				receptive_of_variant += 1
		# Alternate each visible variant between roles. Tutorial/recovery flowers join
		# the same visible rule instead of becoming unmarked exceptions.
		_register_flower(index, donors_of_variant <= receptive_of_variant)
		registered_flower_count += 1


func _flower_is_visible(flower: Dictionary) -> bool:
	if bool(flower.get("tutorial_hidden", false)) and not bool(flower.get("discovered", false)):
		return false
	return not bool(flower.get("tutorial_locked", false))


func _first_wrong_carried_variant(required_variant: int) -> int:
	for variant in active_pollen_variants():
		if variant != required_variant:
			return variant
	return -1


func _body_slot_world(variant: int) -> Vector2:
	if main == null or main.bee == null or not PollenVisualLanguageScript.valid_variant(variant):
		return Vector2.ZERO
	return Vector2(main.bee.position) + PollenVisualLanguageScript.load_slot(variant).rotated(float(main.bee.facing))


func _body_exterior_slot_local(variant: int) -> Vector2:
	if not PollenVisualLanguageScript.valid_variant(variant):
		return Vector2.ZERO
	var slot := PollenVisualLanguageScript.load_slot(variant)
	var exterior_half := BEE_VISUAL_HALF_EXTENTS + Vector2.ONE * REJECTION_CLEARANCE
	var x_scale := INF if absf(slot.x) < 0.001 else exterior_half.x / absf(slot.x)
	var y_scale := INF if absf(slot.y) < 0.001 else exterior_half.y / absf(slot.y)
	return slot * minf(x_scale, y_scale)


func _body_exterior_slot_world(variant: int) -> Vector2:
	if main == null or main.bee == null:
		return Vector2.ZERO
	return Vector2(main.bee.position) + _body_exterior_slot_local(variant).rotated(float(main.bee.facing))


func presentation_pollen_loads() -> Array[int]:
	var visible_loads: Array[int] = pollen_charges.duplicate()
	if String(feedback_event.get("kind", "")) == "rejection":
		var rejected_variant := int(feedback_event.get("variant", -1))
		if PollenVisualLanguageScript.valid_variant(rejected_variant):
			visible_loads[rejected_variant] = maxi(0, visible_loads[rejected_variant] - 1)
	return visible_loads


func _sync_body_loads() -> void:
	if main != null and main.bee != null and main.bee.has_method("set_pollen_loads"):
		main.bee.set_pollen_loads(presentation_pollen_loads())


func _draw_anthers(flower: Dictionary) -> void:
	var variant := int(flower.get("pollen_variant", 0))
	if not PollenVisualLanguageScript.valid_variant(variant):
		return
	var pos := Vector2(flower.position)
	for stamen in 5:
		var angle: float = TAU * float(stamen) / 5.0 + float(main.elapsed) * 0.12
		var head := pos + Vector2.from_angle(angle) * 11.0
		main.draw_line(pos, head, Color("66512f", 0.82), 2.2)
		PollenVisualLanguageScript.draw_grain(main, head, variant, 0.78, 0.98)
	main.draw_circle(pos, 3.8, Color("66512f", 0.92))


func _draw_receptive_stigma(flower: Dictionary) -> void:
	var variant := int(flower.get("stigma_variant", 0))
	if not PollenVisualLanguageScript.valid_variant(variant):
		return
	var pos := Vector2(flower.position)
	var matching_load := has_pollen_variant(variant)
	var pulse := 1.0 + (0.12 + 0.08 * sin(float(main.elapsed) * 6.0) if matching_load else 0.0)
	# One raised, three-lobed stigma remains unlike the donor's five anthers. The
	# inner grains reuse the exact compatibility motif carried by the bee.
	main.draw_line(pos + Vector2(0, 9), pos + Vector2(0, -7), Color("f6eed2", 0.95), 4.0)
	for lobe_position in [Vector2(0, -10), Vector2(-6, -7), Vector2(6, -7)]:
		main.draw_circle(pos + lobe_position, 5.4 * pulse, Color("405840", 0.90))
		PollenVisualLanguageScript.draw_grain(main, pos + lobe_position, variant, 0.58 * pulse, 0.98)
	if matching_load:
		for cue_index in 2:
			var cue_angle := float(main.elapsed) * 1.4 + float(cue_index) * PI
			var cue_position := pos + Vector2.from_angle(cue_angle) * 18.0 + Vector2(0, -4)
			PollenVisualLanguageScript.draw_grain(main, cue_position, variant, 0.48, 0.52)


func _draw_seed_setting(flower: Dictionary) -> void:
	var pos := Vector2(flower.position)
	main.draw_colored_polygon(PackedVector2Array([
		pos + Vector2(0, -11), pos + Vector2(-8, -3),
		pos + Vector2(-6, 9), pos + Vector2(0, 14),
		pos + Vector2(6, 9), pos + Vector2(8, -3)
	]), Color("86a85f", 0.94))
	for seed in 3:
		main.draw_circle(pos + Vector2(0, -3 + seed * 5), 2.2, Color("f3d474"))
	var variant := int(flower.get("stigma_variant", -1))
	if PollenVisualLanguageScript.valid_variant(variant):
		PollenVisualLanguageScript.draw_grain(main, pos + Vector2(0, -13), variant, 0.48, 0.72)


func _draw_sense_routes() -> void:
	if main == null or main.bee == null or float(main.bee.sense_time) <= 0.0:
		return
	var targets := matching_sense_targets()
	for variant in targets:
		var target_index := int(targets[variant])
		if target_index < 0 or target_index >= main.flowers.size():
			continue
		var start := _body_slot_world(int(variant))
		var finish := Vector2(main.flowers[target_index].position)
		var direction := finish - start
		var distance := direction.length()
		if distance < 1.0:
			continue
		var normal := direction.normalized().orthogonal()
		var steps := clampi(int(distance / 42.0), 4, 18)
		for step in range(1, steps):
			var ratio := float(step) / float(steps)
			var route_position := start.lerp(finish, ratio) + normal * sin(ratio * PI) * 16.0
			var route_alpha := 0.46 + 0.18 * sin(float(main.elapsed) * 5.0 - ratio * 5.0)
			PollenVisualLanguageScript.draw_grain(main, route_position, int(variant), 0.56, route_alpha)
		for target_cue in 3:
			var angle := float(target_cue) * TAU / 3.0 + float(main.elapsed) * 0.7
			var cue_position := finish + Vector2.from_angle(angle) * 24.0
			PollenVisualLanguageScript.draw_grain(main, cue_position, int(variant), 0.55, 0.72)


func _draw_feedback() -> void:
	if feedback_event.is_empty():
		return
	var kind := String(feedback_event.get("kind", ""))
	var variant := int(feedback_event.get("variant", -1))
	var target_variant := int(feedback_event.get("target_variant", -1))
	var source := Vector2(feedback_event.get("source_position", Vector2.ZERO))
	var target := Vector2(feedback_event.get("target_position", Vector2.ZERO))
	var duration := maxf(0.01, float(feedback_event.get("duration", 0.01)))
	var progress := 1.0 - clampf(float(feedback_event.get("remaining", 0.0)) / duration, 0.0, 1.0)
	if kind == "deposit" and PollenVisualLanguageScript.valid_variant(variant):
		var position := source.lerp(target, progress)
		position.y -= sin(progress * PI) * 18.0
		PollenVisualLanguageScript.draw_grain(main, position, variant, 1.0, 0.98)
		for trail_index in 2:
			var trail_ratio := clampf(progress - 0.08 * float(trail_index + 1), 0.0, 1.0)
			var trail_position := source.lerp(target, trail_ratio)
			trail_position.y -= sin(trail_ratio * PI) * 18.0
			PollenVisualLanguageScript.draw_grain(main, trail_position, variant, 0.48, 0.34)
	elif kind in ["rejection", "empty_load"]:
		if PollenVisualLanguageScript.valid_variant(target_variant):
			var target_pulse := 0.72 + 0.28 * sin(progress * PI)
			for pulse_index in 3:
				var pulse_angle := float(pulse_index) * TAU / 3.0
				PollenVisualLanguageScript.draw_grain(
					main,
					target + Vector2.from_angle(pulse_angle) * (14.0 + 8.0 * sin(progress * PI)),
					target_variant,
					0.52,
					target_pulse
				)
		if kind == "rejection" and PollenVisualLanguageScript.valid_variant(variant):
			var grain_position := _rejection_grain_position(feedback_event, progress)
			var previous_position := _rejection_grain_position(feedback_event, maxf(0.0, progress - 0.035))
			main.draw_line(
				previous_position,
				grain_position,
				Color(PollenVisualLanguageScript.color_for(variant), 0.54),
				3.2
			)
			PollenVisualLanguageScript.draw_grain(
				main,
				grain_position,
				variant,
				0.95,
				0.94
			)


func _rejection_grain_position(event: Dictionary, progress: float) -> Vector2:
	var variant := int(event.get("variant", -1))
	var source := Vector2(event.get("source_position", Vector2.ZERO))
	var target := Vector2(event.get("target_position", Vector2.ZERO))
	var center := Vector2(event.get("bee_origin", source))
	var facing := float(event.get("bee_facing", 0.0))
	if main != null and main.bee != null:
		center = Vector2(main.bee.position)
		facing = float(main.bee.facing)
	var source_vector := _body_exterior_slot_local(variant).rotated(facing)
	if source_vector.length_squared() < 0.01:
		source_vector = source - center
	var source_angle := source_vector.angle()
	var target_vector := target - center
	var target_direction := target_vector.normalized() if target_vector.length_squared() > 0.01 else Vector2.from_angle(facing)
	var turn_angle := target_direction.angle()
	var bounded_progress := clampf(progress, 0.0, 1.0)
	if bounded_progress <= 0.5:
		var outward := bounded_progress / 0.5
		# First emerge radially from the live body-surface anchor, then orbit outside the entire
		# 82×60 silhouette toward a clear turnaround beside the stigma.
		if outward < REJECTION_DEPART_FRACTION:
			var depart_ratio := smoothstep(0.0, 1.0, outward / REJECTION_DEPART_FRACTION)
			var depart_radius := lerpf(source_vector.length(), REJECTION_ROUTE_RADIUS, depart_ratio)
			return center + Vector2.from_angle(source_angle) * depart_radius
		var arc_ratio := smoothstep(
			0.0,
			1.0,
			(outward - REJECTION_DEPART_FRACTION) / (1.0 - REJECTION_DEPART_FRACTION)
		)
		return center + Vector2.from_angle(lerp_angle(source_angle, turn_angle, arc_ratio)) * REJECTION_ROUTE_RADIUS

	# Return around the live bee's outer ring. Re-evaluating both center and facing on
	# every draw keeps the one real grain visible if the player moves or turns. The
	# last short radial segment reaches the exterior anchor, where the body copy is
	# restored only after this feedback event ends.
	var return_progress := (bounded_progress - 0.5) / 0.5
	if return_progress < REJECTION_RETURN_ARC_FRACTION:
		var return_arc_ratio := smoothstep(
			0.0,
			1.0,
			return_progress / REJECTION_RETURN_ARC_FRACTION
		)
		return center + Vector2.from_angle(lerp_angle(turn_angle, source_angle, return_arc_ratio)) * REJECTION_ROUTE_RADIUS
	var settle_ratio := smoothstep(
		0.0,
		1.0,
		(return_progress - REJECTION_RETURN_ARC_FRACTION)
		/ (1.0 - REJECTION_RETURN_ARC_FRACTION)
	)
	var settle_radius := lerpf(REJECTION_ROUTE_RADIUS, source_vector.length(), settle_ratio)
	return center + source_vector.normalized() * settle_radius


func draw() -> void:
	_register_new_flowers()
	for index in donor_indices:
		if index < 0 or index >= main.flowers.size():
			continue
		var flower: Dictionary = main.flowers[index]
		if _flower_is_visible(flower) and bool(flower.get("has_anthers", false)) and int(flower.get("nectar", 0)) > 0:
			_draw_anthers(flower)
	for index in receptive_indices:
		if index < 0 or index >= main.flowers.size():
			continue
		var flower: Dictionary = main.flowers[index]
		if not _flower_is_visible(flower):
			continue
		if bool(flower.get("seed_setting", false)):
			_draw_seed_setting(flower)
		elif bool(flower.get("receptive_stigma", false)):
			_draw_receptive_stigma(flower)
	_draw_sense_routes()
	_draw_feedback()


func end() -> void:
	for index in receptive_indices:
		if index >= 0 and main != null and index < main.flowers.size():
			var flower: Dictionary = main.flowers[index]
			flower["pollination_pending"] = false
			main.flowers[index] = flower
	pollen_charges = [0, 0]
	_clear_feedback_event()
