class_name BeePlayer
extends Node2D

signal sense_started

const WORLD_BOUNDS := Rect2(34, 146, 970, 538)

var energy := 100.0
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
var invulnerable_time := 0.0

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
	energy = 100.0
	sense_time = 0.0
	sense_cooldown = 0.0
	evade_time = 0.0
	evade_cooldown = 0.0
	invulnerable_time = 0.0
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
	invulnerable_time = 0.34
	has_target = false
	return true

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

	var dashing := Input.is_action_pressed("dash") and energy > 8.0 and evade_time <= 0.0
	var desired_speed := (dash_speed if dashing else base_speed) * speed_multiplier
	if evade_time > 0.0:
		velocity = velocity.move_toward(velocity.normalized() * 520.0, 180.0 * delta)
	elif input_direction.length_squared() > 0.01:
		velocity = velocity.move_toward(input_direction.normalized() * desired_speed, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, braking * delta)

	if velocity.length_squared() > 1.0:
		facing = velocity.angle()
	position += velocity * delta
	position.x = clampf(position.x, WORLD_BOUNDS.position.x + 18, WORLD_BOUNDS.end.x - 18)
	position.y = clampf(position.y, WORLD_BOUNDS.position.y + 18, WORLD_BOUNDS.end.y - 18)
	energy = maxf(0.0, energy - drain_rate * delta - (9.5 * dash_cost_multiplier * delta if dashing else 0.0))
	if Input.is_action_just_pressed("sense") and sense_cooldown <= 0.0:
		sense_time = 3.0
		sense_cooldown = 7.0
		sense_started.emit()

	queue_redraw()

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, facing)
	var wing_alpha := 0.5 + sin(Time.get_ticks_msec() * 0.03) * 0.12
	draw_circle(Vector2(-5, -10), 8, Color(0.97, 0.98, 0.9, wing_alpha))
	draw_circle(Vector2(-5, 10), 8, Color(0.97, 0.98, 0.9, wing_alpha))
	draw_circle(Vector2.ZERO, 13, Color("292921"))
	draw_rect(Rect2(Vector2(-7, -12), Vector2(5, 24)), Color("e1aa2c"))
	draw_rect(Rect2(Vector2(3, -11), Vector2(5, 22)), Color("e1aa2c"))
	draw_circle(Vector2(13, 0), 7, Color("efcf69"))
	draw_line(Vector2(18, 0), Vector2(24, 0), Color("2b2921"), 2)
	if sense_time > 0.0:
		draw_arc(Vector2.ZERO, 27 + sin(Time.get_ticks_msec() * 0.012) * 4, 0, TAU, 28, Color("f1d46d", 0.72), 2)
	draw_set_transform(Vector2.ZERO)
