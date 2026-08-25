class_name B01EvadeEncounter
extends RefCounted

const Rules := preload("res://scripts/mechanics/evade_rules.gd")

const STATE_IDLE := "idle"
const STATE_AIM := "aim"
const STATE_LOCKED := "locked"
const STATE_DASH := "dash"
const STATE_RESOLVED := "resolved"

const AIM_SECONDS := 0.72
const LOCK_SECONDS := 0.48
const DASH_SECONDS := 0.85
const DASH_SPEED := 520.0
const SPAWN_OFFSET := Vector2(190.0, -36.0)
const ATTACKER_BOUNDS := Rect2(70.0, 182.0, 898.0, 466.0)

var state := STATE_IDLE
var state_seconds := 0.0
var attacker_position := Vector2.ZERO
var locked_origin := Vector2.ZERO
var aim_direction := Vector2.LEFT
var locked_target := Vector2.ZERO
var evade_sequence_at_lock := 0
var evade_attempted := false

func begin(bee_position: Vector2, evade_sequence: int) -> void:
	var horizontal_offset := SPAWN_OFFSET.x if bee_position.x <= ATTACKER_BOUNDS.get_center().x else -SPAWN_OFFSET.x
	var requested_position := bee_position + Vector2(horizontal_offset, SPAWN_OFFSET.y)
	attacker_position = Vector2(
		clampf(requested_position.x, ATTACKER_BOUNDS.position.x, ATTACKER_BOUNDS.end.x - 1.0),
		clampf(requested_position.y, ATTACKER_BOUNDS.position.y, ATTACKER_BOUNDS.end.y - 1.0)
	)
	aim_direction = (bee_position - attacker_position).normalized()
	locked_origin = attacker_position
	locked_target = bee_position
	evade_sequence_at_lock = evade_sequence
	evade_attempted = false
	state = STATE_AIM
	state_seconds = AIM_SECONDS

func restart_aim(bee_position: Vector2, evade_sequence: int) -> void:
	begin(bee_position, evade_sequence)

func mark_evade_attempted() -> bool:
	if state not in [STATE_LOCKED, STATE_DASH]:
		return false
	evade_attempted = true
	return true

func config_signature() -> Dictionary:
	return {
		"aim_seconds": AIM_SECONDS,
		"attack_cross_radius": Rules.ATTACK_CROSS_RADIUS,
		"dash_seconds": DASH_SECONDS,
		"dash_speed": DASH_SPEED,
		"lock_seconds": LOCK_SECONDS,
		"path_clearance": Rules.PATH_CLEARANCE,
		"spawn_offset": SPAWN_OFFSET,
	}

func advance(delta: float, bee_position: Vector2, current_evade_sequence: int) -> Dictionary:
	if delta <= 0.0 or state in [STATE_IDLE, STATE_RESOLVED]:
		return _event("")
	state_seconds = maxf(0.0, state_seconds - delta)
	match state:
		STATE_AIM:
			aim_direction = (bee_position - attacker_position).normalized()
			if state_seconds <= 0.0:
				locked_origin = attacker_position
				locked_target = bee_position
				# Capture causality atomically with the aim -> locked transition. A
				# host cannot accidentally credit an evade performed before lock.
				evade_sequence_at_lock = current_evade_sequence
				state = STATE_LOCKED
				state_seconds = LOCK_SECONDS
				return _event("locked")
		STATE_LOCKED:
			if state_seconds <= 0.0:
				state = STATE_DASH
				state_seconds = DASH_SECONDS
				return _event("dash_started")
		STATE_DASH:
			var previous := attacker_position
			attacker_position += aim_direction * DASH_SPEED * delta
			if Rules.attack_crossed_locked_target(previous, attacker_position, locked_target):
				state = STATE_RESOLVED
				return _event("crossed")
			if state_seconds <= 0.0:
				state = STATE_RESOLVED
				return _event("expired")
	return _event("")

func _event(kind: String) -> Dictionary:
	return {
		"kind": kind,
		"aim_direction": aim_direction,
		"attacker_position": attacker_position,
		"evade_attempted": evade_attempted,
		"evade_sequence_at_lock": evade_sequence_at_lock,
		"locked_origin": locked_origin,
		"locked_target": locked_target,
	}
