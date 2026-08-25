class_name EvadeInputController
extends RefCounted

const Rules := preload("res://scripts/mechanics/evade_rules.gd")
const DIRECTION_VECTORS := {
	"left": Vector2.LEFT,
	"right": Vector2.RIGHT,
	"up": Vector2.UP,
	"down": Vector2.DOWN,
}

var direction_tap_times := {"left": 0.0, "right": 0.0, "up": 0.0, "down": 0.0}
var direction_tap_origins := {"left": Vector2.ZERO, "right": Vector2.ZERO, "up": Vector2.ZERO, "down": Vector2.ZERO}
var world_tap_time := 0.0
var world_tap_direction := Vector2.ZERO
var world_tap_position := Vector2.ZERO
var world_tap_origin := Vector2.ZERO

func clear(bee = null) -> void:
	direction_tap_times = {"left": 0.0, "right": 0.0, "up": 0.0, "down": 0.0}
	direction_tap_origins = {"left": Vector2.ZERO, "right": Vector2.ZERO, "up": Vector2.ZERO, "down": Vector2.ZERO}
	world_tap_time = 0.0
	world_tap_direction = Vector2.ZERO
	world_tap_position = Vector2.ZERO
	world_tap_origin = Vector2.ZERO
	if bee != null:
		bee.clear_evade_first_tap()

func register_direction_tap(direction_key: String, direction: Vector2, now: float, bee) -> Dictionary:
	var result := _result(true)
	if bee == null or not DIRECTION_VECTORS.has(direction_key) or direction.length_squared() < 0.01:
		return result
	var previous_tap := float(direction_tap_times.get(direction_key, 0.0))
	if previous_tap > 0.0 and now - previous_tap <= Rules.DOUBLE_TAP_WINDOW:
		direction_tap_times[direction_key] = 0.0
		var attempt_origin := Vector2(direction_tap_origins.get(direction_key, bee.position))
		result.evade_attempted = true
		result.direction = direction.normalized()
		result.origin = attempt_origin
		result.evade_started = bool(bee.try_evade(result.direction, attempt_origin))
		if not result.evade_started:
			# A failed second tap is a complete attempt, not the first half of a
			# hidden third-tap shortcut after cooldown or recovery.
			bee.clear_evade_first_tap()
		return result
	direction_tap_times[direction_key] = now
	direction_tap_origins[direction_key] = bee.position
	bee.show_evade_first_tap(direction, Rules.DOUBLE_TAP_WINDOW)
	return result

func process_pressed_directions(
	pressed_directions: Array[String],
	now: float,
	bee,
	attack_direction := Vector2.ZERO
) -> Dictionary:
	var combined := _result(not pressed_directions.is_empty())
	var directions_to_process: Array[String] = pressed_directions.duplicate()
	var normalized_attack := attack_direction.normalized()
	if directions_to_process.size() > 1 and normalized_attack.length_squared() > 0.01:
		var best_key := ""
		var best_score := INF
		for candidate_key in directions_to_process:
			if not DIRECTION_VECTORS.has(candidate_key):
				continue
			var candidate := Vector2(DIRECTION_VECTORS[candidate_key])
			var score := absf(candidate.dot(normalized_attack))
			if score < best_score:
				best_score = score
				best_key = candidate_key
		if not best_key.is_empty():
			directions_to_process.assign([best_key])
	for direction_key in directions_to_process:
		if not DIRECTION_VECTORS.has(direction_key):
			continue
		var result := register_direction_tap(direction_key, Vector2(DIRECTION_VECTORS[direction_key]), now, bee)
		if bool(result.evade_attempted):
			combined = result
		if bool(result.evade_started):
			# A diagonal chord can report two directions in one frame. Once one
			# evade starts, no second direction may overwrite it or remain cached.
			clear(bee)
			return result
	return combined

func handle_world_tap(
	world_position: Vector2,
	now: float,
	bee,
	world_bounds: Rect2,
	evade_allowed := true
) -> Dictionary:
	if bee == null or not world_bounds.has_point(world_position):
		return _result(false)
	if not evade_allowed:
		bee.set_move_target(world_position)
		return _result(true)
	if world_tap_time > 0.0 and now - world_tap_time > Rules.DOUBLE_TAP_WINDOW:
		clear(bee)
	var direction := (world_position - Vector2(bee.position)).normalized()
	var repeats_position := world_tap_position.distance_to(world_position) <= Rules.WORLD_TAP_REPEAT_RADIUS
	var repeats_direction := (
		direction.length_squared() > 0.01
		and world_tap_direction.length_squared() > 0.01
		and world_tap_direction.dot(direction) >= 0.86
	)
	if world_tap_time > 0.0 and (repeats_position or repeats_direction):
		var result := _result(true)
		# The first click starts ordinary movement. Preserve its direction and
		# origin even if the bee reaches that point before the second click.
		var committed_direction := world_tap_direction
		if committed_direction.length_squared() > 0.01:
			result.evade_attempted = true
			result.direction = committed_direction
			result.origin = world_tap_origin
			result.evade_started = bool(bee.try_evade(committed_direction, world_tap_origin))
		clear(bee)
		return result
	if direction.length_squared() < 0.01:
		return _result(false)
	world_tap_time = now
	world_tap_direction = direction
	world_tap_position = world_position
	world_tap_origin = bee.position
	bee.show_evade_first_tap(direction, Rules.DOUBLE_TAP_WINDOW)
	bee.set_move_target(world_position)
	return _result(true)

func _result(consumed: bool) -> Dictionary:
	return {
		"consumed": consumed,
		"evade_started": false,
		"evade_attempted": false,
		"direction": Vector2.ZERO,
		"origin": Vector2.ZERO,
	}
