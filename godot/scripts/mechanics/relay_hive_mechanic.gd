class_name RelayHiveMechanic
extends RefCounted

## A relay hive is deliberately not a second home or deposit point. The player
## explicitly spends one carried drop to wake this field post, then may rest
## inside its visible landing patch for partial recovery. Honey is safe only at
## the primary hive: relay use never changes delivered, reserve or home events.

const ENTRY_SIZE := Vector2(116.0, 88.0)

var enabled := false
var position := Vector2.ZERO
var activation_cost := 1
var energy_restore_per_second := 12.0
var energy_cap_ratio := 0.65
var warmth_restore_per_second := 8.0
var warmth_cap := 70.0
var active := false
var activity_time := 0.0

func configure(spec: Dictionary) -> void:
	enabled = not spec.is_empty()
	position = _vector_from_value(spec.get("position", [640.0, 548.0]))
	activation_cost = maxi(1, int(spec.get("activation_cost", 1)))
	energy_restore_per_second = maxf(0.0, float(spec.get("energy_restore_per_second", 12.0)))
	energy_cap_ratio = clampf(float(spec.get("energy_cap_ratio", 0.65)), 0.1, 0.95)
	warmth_restore_per_second = maxf(0.0, float(spec.get("warmth_restore_per_second", 8.0)))
	warmth_cap = clampf(float(spec.get("warmth_cap", 70.0)), 1.0, 99.0)
	active = false
	activity_time = 0.0

func clear() -> void:
	enabled = false
	active = false
	activity_time = 0.0

func try_activate(bee_position: Vector2, carried: int) -> Dictionary:
	if not enabled or active or not is_inside(bee_position):
		return {"consumed": 0, "event": ""}
	if carried < activation_cost:
		return {"consumed": 0, "event": "needs_honey"}
	active = true
	activity_time = 1.0
	return {"consumed": activation_cost, "event": "activated"}

func process(
	delta: float,
	bee_position: Vector2,
	is_still: bool,
	energy: float,
	energy_cap: float,
	warmth: float = 100.0,
	winter_active: bool = false
) -> Dictionary:
	activity_time = maxf(0.0, activity_time - delta)
	if not enabled or not active or not is_still or not is_inside(bee_position):
		return {"energy": energy, "warmth": warmth, "resting": false}
	var energy_limit := energy_cap * energy_cap_ratio
	# The cap limits how far this post can heal; it must never pull a healthier
	# bee back down to 65% merely because the player crossed the landing patch.
	var restored_energy := energy
	if energy < energy_limit:
		restored_energy = minf(energy_limit, energy + energy_restore_per_second * delta)
	var restored_warmth := warmth
	if winter_active and warmth < warmth_cap:
		restored_warmth = minf(warmth_cap, warmth + warmth_restore_per_second * delta)
	activity_time = 1.0
	return {"energy": restored_energy, "warmth": restored_warmth, "resting": true}

func context_action_id(bee_position: Vector2, carried: int) -> String:
	if not enabled or active or not is_inside(bee_position):
		return ""
	return "activate_relay_hive" if carried >= activation_cost else "relay_hive_needs_honey"

func is_inside(world_position: Vector2) -> bool:
	return enabled and entry_area().has_point(world_position)

func entry_area() -> Rect2:
	return Rect2(position - ENTRY_SIZE * 0.5, ENTRY_SIZE)

func status_id() -> String:
	if not enabled:
		return "disabled"
	return "active" if active else "dormant"

func _vector_from_value(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2(640.0, 548.0)
