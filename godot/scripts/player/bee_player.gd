class_name BeePlayer
extends Node2D

signal sense_started

const WORLD_BOUNDS := Rect2(34, 146, 970, 538)
const AUTO_DASH_THRESHOLD := 0.35
const PLAYER_BEE_TEXTURE := preload("res://assets/art/player_bee_textile.svg")
const SPRING_PLAYER_BEE_PATH := "res://assets/art/launch/player_bee_v1.png"

# 出巢体力上限：由 main 从 balance.json player.max_energy 注入，避免调参时改代码
var max_energy := 100.0
var energy := max_energy
var drain_rate := 1.45
var base_speed := 215.0
var dash_speed := 360.0
var acceleration := 1050.0
var braking := 1280.0
var velocity := Vector2.ZERO
var target := Vector2.ZERO
var has_target := false
var active := false
var sense_time := 0.0
var sense_cooldown := 0.0
var facing := 0.0
var speed_multiplier := 1.0
var dash_cost_multiplier := 1.0
var evade_time := 0.0
var evade_cooldown := 0.0
# 闪避无敌时长：由 main 从 balance.json player.evade_invuln_seconds 注入
var evade_invuln := 0.18
var invulnerable_time := 0.0
var move_duration := 0.0
var spring_player_bee_texture: Texture2D
var use_spring_launch_art := false

func _ready() -> void:
	if ResourceLoader.exists(SPRING_PLAYER_BEE_PATH):
		spring_player_bee_texture = ResourceLoader.load(SPRING_PLAYER_BEE_PATH, "Texture2D") as Texture2D

func has_spring_launch_art() -> bool:
	return spring_player_bee_texture != null

func set_spring_launch_art(enabled: bool) -> void:
	use_spring_launch_art = enabled and has_spring_launch_art()
	queue_redraw()

func configure(stage_drain: float) -> void:
	drain_rate = stage_drain

func reset_upgrades() -> void:
	speed_multiplier = 1.0
	dash_cost_multiplier = 1.0

func apply_upgrade(upgrade_id: String) -> void:
	if upgrade_id == "long_wing":
		speed_multiplier *= 1.10
		dash_cost_multiplier *= 0.85

func reset_for_expedition(at: Vector2) -> void:
	position = at
	velocity = Vector2.ZERO
	target = Vector2.ZERO
	has_target = false
	energy = max_energy
	sense_time = 0.0
	sense_cooldown = 0.0
	evade_time = 0.0
	evade_cooldown = 0.0
	invulnerable_time = 0.0
	move_duration = 0.0
	active = true
	queue_redraw()

func set_move_target(world_position: Vector2) -> void:
	target = world_position
	has_target = true

func spend_energy(amount: float) -> bool:
	if energy < amount:
		return false
	energy -= amount
	return true

func try_evade() -> bool:
	if evade_cooldown > 0.0 or not spend_energy(12.0):
		return false
	var direction := velocity.normalized() if velocity.length_squared() > 4.0 else Vector2.from_angle(facing)
	velocity = direction * 520.0
	evade_time = 0.18
	evade_cooldown = 1.6
	invulnerable_time = evade_invuln
	has_target = false
	return true

func trigger_sense() -> void:
	if sense_cooldown <= 0.0:
		sense_time = 3.0
		sense_cooldown = 7.0
		sense_started.emit()

func _physics_process(delta: float) -> void:
	sense_time = maxf(0.0, sense_time - delta)
	sense_cooldown = maxf(0.0, sense_cooldown - delta)
	evade_time = maxf(0.0, evade_time - delta)
	evade_cooldown = maxf(0.0, evade_cooldown - delta)
	invulnerable_time = maxf(0.0, invulnerable_time - delta)
	if not active:
		velocity = velocity.move_toward(Vector2.ZERO, braking * delta)
		return

	var input_direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_direction.length_squared() < 0.01 and has_target:
		var to_target := target - position
		if to_target.length() > 10.0:
			input_direction = to_target.normalized()
		else:
			has_target = false

	# Auto-dash: sustained movement for >threshold automatically accelerates to dash speed
	var is_moving := input_direction.length_squared() > 0.01
	if is_moving:
		move_duration += delta
	else:
		move_duration = 0.0

	var auto_dashing := move_duration > AUTO_DASH_THRESHOLD and energy > 8.0 and evade_time <= 0.0
	var desired_speed := (dash_speed if auto_dashing else base_speed) * speed_multiplier
	if evade_time > 0.0:
		velocity = velocity.move_toward(velocity.normalized() * 520.0, 180.0 * delta)
	elif is_moving:
		velocity = velocity.move_toward(input_direction.normalized() * desired_speed, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, braking * delta)

	if velocity.length_squared() > 1.0:
		facing = velocity.angle()
	position += velocity * delta
	position.x = clampf(position.x, WORLD_BOUNDS.position.x + 18, WORLD_BOUNDS.end.x - 18)
	position.y = clampf(position.y, WORLD_BOUNDS.position.y + 18, WORLD_BOUNDS.end.y - 18)
	energy = maxf(0.0, energy - drain_rate * delta - (9.5 * dash_cost_multiplier * delta if auto_dashing else 0.0))

	queue_redraw()

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, facing)
	# A slight vertical pulse keeps the wings alive before a full frame sheet exists.
	var wing_pulse := 0.96 + sin(Time.get_ticks_msec() * 0.03) * 0.04
	draw_set_transform(Vector2.ZERO, facing, Vector2(1.0, wing_pulse))
	var player_texture: Texture2D = spring_player_bee_texture if use_spring_launch_art else PLAYER_BEE_TEXTURE
	var player_size := Vector2(82, 60) if use_spring_launch_art else Vector2(58, 42)
	draw_texture_rect(player_texture, Rect2(player_size * -0.5, player_size), false)
	if sense_time > 0.0:
		draw_arc(Vector2.ZERO, 27 + sin(Time.get_ticks_msec() * 0.012) * 4, 0, TAU, 28, Color("f1d46d", 0.72), 2)
	draw_set_transform(Vector2.ZERO)
