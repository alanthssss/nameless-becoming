class_name EvadeRules
extends RefCounted

## Shared facts for the production acute-turn input, causal result and attack
## corridor. Main and fixed playtest slices must use this file instead of keeping
## near-identical thresholds that can drift apart.

const DOUBLE_TAP_WINDOW := 0.34
const PATH_CLEARANCE := 36.0
const LOCK_ORIGIN_TOLERANCE := 52.0
const WORLD_TAP_REPEAT_RADIUS := 56.0
const SIDE_ALIGNMENT_LIMIT := 0.76
const ATTACK_CROSS_RADIUS := 29.0
const CORRIDOR_REACH := 1100.0
const CORRIDOR_ORIGIN_LEAD := 24.0

static func attack_crossed_locked_target(
	previous: Vector2,
	current: Vector2,
	locked_target: Vector2,
	radius := ATTACK_CROSS_RADIUS
) -> bool:
	var closest := Geometry2D.get_closest_point_to_segment(locked_target, previous, current)
	return closest.distance_to(locked_target) <= radius

static func cleared_locked_path(
	bee,
	attack_direction: Vector2,
	locked_target: Vector2,
	sequence_at_lock: int,
	clearance := PATH_CLEARANCE
) -> bool:
	if bee == null or int(bee.evade_sequence) <= sequence_at_lock:
		return false
	var normalized_attack := attack_direction.normalized()
	if normalized_attack.length_squared() < 0.01:
		return false
	# A cardinal input must be substantially sideways to the committed route.
	# The threshold still accepts the best cardinal choice against a diagonal.
	if absf(Vector2(bee.last_evade_direction).normalized().dot(normalized_attack)) > SIDE_ALIGNMENT_LIMIT:
		return false
	var evade_origin_offset := Vector2(bee.last_evade_origin) - locked_target
	# The causal attempt starts on the first tap. It must have started at the
	# position/corridor that was actually locked, not after ordinary movement took
	# the bee somewhere unrelated.
	if evade_origin_offset.length() > maxf(LOCK_ORIGIN_TOLERANCE, clearance + 16.0):
		return false
	if absf(evade_origin_offset.cross(normalized_attack)) >= clearance:
		return false
	var sideways_distance := absf((Vector2(bee.position) - locked_target).cross(normalized_attack))
	return sideways_distance >= clearance

static func cardinal_escape_directions(
	target: Vector2,
	attack_direction: Vector2,
	bee_center_bounds: Rect2,
	clearance := PATH_CLEARANCE
) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var normalized_attack := attack_direction.normalized()
	var side := normalized_attack.orthogonal()
	if side.length_squared() < 0.01:
		return result
	var cardinal_directions: Array[Vector2] = [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]
	for side_sign in [-1.0, 1.0]:
		var outward: Vector2 = side * float(side_sign)
		var shown_direction := Vector2.ZERO
		var best_alignment := -INF
		for cardinal in cardinal_directions:
			var alignment := cardinal.dot(outward)
			if alignment <= best_alignment or absf(cardinal.dot(normalized_attack)) > SIDE_ALIGNMENT_LIMIT:
				continue
			if not bee_center_bounds.has_point(target + cardinal * (clearance + 1.0)):
				continue
			shown_direction = cardinal
			best_alignment = alignment
		if shown_direction.length_squared() > 0.01:
			result.append(shown_direction)
	return result

static func committed_corridor_geometry(
	origin: Vector2,
	attack_direction: Vector2,
	world_bounds: Rect2,
	half_width: float
) -> Dictionary:
	var aim := attack_direction.normalized()
	if aim.length_squared() < 0.01:
		return {"valid": false}
	var side := aim.orthogonal()
	var reach := CORRIDOR_REACH
	if absf(aim.x) > 0.001:
		var x_edge := world_bounds.end.x if aim.x > 0.0 else world_bounds.position.x
		reach = minf(reach, (x_edge - origin.x) / aim.x)
	if absf(aim.y) > 0.001:
		var y_edge := world_bounds.end.y if aim.y > 0.0 else world_bounds.position.y
		reach = minf(reach, (y_edge - origin.y) / aim.y)
	reach = maxf(0.0, reach)
	var start := origin - aim * CORRIDOR_ORIGIN_LEAD
	start = Vector2(
		clampf(start.x, world_bounds.position.x, world_bounds.end.x),
		clampf(start.y, world_bounds.position.y, world_bounds.end.y)
	)
	var finish := origin + aim * reach
	return {
		"valid": true,
		"aim": aim,
		"side": side,
		"start": start,
		"finish": finish,
		"polygon": PackedVector2Array([
			start + side * half_width,
			finish + side * half_width,
			finish - side * half_width,
			start - side * half_width,
		]),
	}
