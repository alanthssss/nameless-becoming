class_name BeePlayer
extends Node2D

signal sense_started

const WORLD_BOUNDS := Rect2(34, 146, 970, 538)
const AUTO_DASH_THRESHOLD := 0.35
const EVADE_SPEED := 520.0
const EVADE_DURATION := 0.18
const EVADE_COST := 12.0
const EVADE_COOLDOWN := 1.6
const PLAYER_BEE_TEXTURE := preload("res://assets/art/commercial/player_bee_topdown_states_v1.png")
const SPRING_PLAYER_FRAME_SIZE := Vector2(256.0, 256.0)
const PollenVisualLanguage := preload("res://scripts/mechanics/pollen_visual_language.gd")

# 出巢体力上限：由 main 从 balance.json player.max_energy 注入，避免调参时改代码
var max_energy := 100.0
var energy := max_energy
var drain_rate := 1.45
## Most legacy sorties treat the configured drain as an always-on expedition
## clock. Larger campaign maps opt into movement-only drain so pausing to read
## the field never spends energy behind the player's back.
var drain_while_idle := true
var auto_dash_delay := AUTO_DASH_THRESHOLD
var auto_dash_drain_per_second := 9.5
var auto_dash_requires_energy := true
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
## Environment-owned movement modifier. Seasonal mechanics may slow or restore the
## bee without overwriting permanent Long Wing upgrades.
var environment_speed_multiplier := 1.0
var dash_cost_multiplier := 1.0
## Cargo is a handling profile, not a second stamina bar. Heavy loads visibly
## widen turns, lower top speed and make sustained acceleration costlier; fields
## must reset the profile as soon as the parcel leaves the bee.
var load_speed_multiplier := 1.0
var load_acceleration_multiplier := 1.0
var load_dash_cost_multiplier := 1.0
var evade_time := 0.0
var evade_cooldown := 0.0
# Campaign story gates may explicitly allow one assisted urgent turn when the
# meter is empty.  Ordinary/optional evades still require the full cost; the
# field enables this flag only while the bee is beside a mandatory evade gate.
var allow_exhausted_evade := false
var last_evade_was_assisted := false
var evade_energy_cost := EVADE_COST
var assisted_evade_speed_scale := 0.75
var assisted_evade_cooldown := 2.4
# 闪避无敌时长：由 main 从 balance.json player.evade_invuln_seconds 注入
var evade_invuln := 0.18
var invulnerable_time := 0.0
var evade_sequence := 0
var last_evade_origin := Vector2.ZERO
var last_evade_direction := Vector2.RIGHT
var evade_tap_time := 0.0
var evade_tap_direction := Vector2.RIGHT
var move_duration := 0.0
var spring_player_bee_texture: Texture2D
var spring_player_bee_frames: Array[Texture2D] = []
var use_spring_launch_art := false
var visual_load_ratio := 0.0
var _movement_bounds := WORLD_BOUNDS
## N01 opening prop. It is a short-lived posture cue, not equipment or a new
## character identity: the mentor removes the petal before the first real job.
var story_petal_visible := false
## Presentation mirror only. PollinationMechanic owns the authoritative charges;
## this copy exists so the load can be drawn after the bee texture instead of
## disappearing underneath it in Main's parent canvas.
var pollen_loads: Array[int] = [0, 0]

func _ready() -> void:
	spring_player_bee_texture = PLAYER_BEE_TEXTURE
	for frame_index in 4:
		var frame := AtlasTexture.new()
		frame.atlas = spring_player_bee_texture
		frame.region = Rect2(
			Vector2(float(frame_index) * SPRING_PLAYER_FRAME_SIZE.x, 0.0),
			SPRING_PLAYER_FRAME_SIZE
		)
		spring_player_bee_frames.append(frame)

func has_spring_launch_art() -> bool:
	return spring_player_bee_frames.size() == 4

func set_spring_launch_art(enabled: bool) -> void:
	use_spring_launch_art = enabled and has_spring_launch_art()
	queue_redraw()


func set_story_petal(visible: bool) -> void:
	story_petal_visible = visible
	queue_redraw()


func set_visual_load_ratio(ratio: float) -> void:
	visual_load_ratio = clampf(ratio, 0.0, 1.0)
	queue_redraw()


func set_pollen_loads(charges: Array[int]) -> void:
	var next_loads: Array[int] = [0, 0]
	for variant in mini(next_loads.size(), charges.size()):
		next_loads[variant] = clampi(int(charges[variant]), 0, 2)
	pollen_loads = next_loads
	queue_redraw()

func configure(stage_drain: float) -> void:
	drain_rate = stage_drain


func configure_energy_usage(
	should_drain_while_idle: bool,
	dash_drain_per_second: float,
	dash_delay_seconds: float,
	dash_needs_energy := true
) -> Error:
	if (
		not is_finite(dash_drain_per_second)
		or not is_finite(dash_delay_seconds)
		or dash_drain_per_second < 0.0
		or dash_delay_seconds < 0.0
	):
		return ERR_INVALID_PARAMETER
	drain_while_idle = should_drain_while_idle
	auto_dash_drain_per_second = dash_drain_per_second
	auto_dash_delay = dash_delay_seconds
	auto_dash_requires_energy = dash_needs_energy
	return OK


func set_load_movement_profile(
	speed_scale: float = 1.0,
	acceleration_scale: float = 1.0,
	dash_cost_scale: float = 1.0
) -> Error:
	if (
		not is_finite(speed_scale)
		or not is_finite(acceleration_scale)
		or not is_finite(dash_cost_scale)
		or speed_scale <= 0.0
		or acceleration_scale <= 0.0
		or dash_cost_scale <= 0.0
	):
		return ERR_INVALID_PARAMETER
	load_speed_multiplier = clampf(speed_scale, 0.35, 1.25)
	load_acceleration_multiplier = clampf(acceleration_scale, 0.25, 1.25)
	load_dash_cost_multiplier = clampf(dash_cost_scale, 0.5, 2.5)
	return OK

func set_movement_bounds(bounds: Rect2) -> Error:
	if (
		not is_finite(bounds.position.x)
		or not is_finite(bounds.position.y)
		or not is_finite(bounds.size.x)
		or not is_finite(bounds.size.y)
		or bounds.size.x < 36.0
		or bounds.size.y < 36.0
	):
		return ERR_INVALID_PARAMETER
	_movement_bounds = bounds
	_clamp_to_movement_bounds()
	return OK

func get_movement_bounds() -> Rect2:
	return _movement_bounds

func reset_upgrades() -> void:
	speed_multiplier = 1.0
	environment_speed_multiplier = 1.0
	dash_cost_multiplier = 1.0
	set_load_movement_profile()

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
	allow_exhausted_evade = false
	last_evade_was_assisted = false
	invulnerable_time = 0.0
	evade_sequence = 0
	last_evade_origin = at
	last_evade_direction = Vector2.RIGHT
	evade_tap_time = 0.0
	evade_tap_direction = Vector2.RIGHT
	move_duration = 0.0
	environment_speed_multiplier = 1.0
	set_load_movement_profile()
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

func show_evade_first_tap(direction: Vector2, duration: float) -> void:
	if direction.length_squared() < 0.01:
		return
	evade_tap_direction = direction.normalized()
	evade_tap_time = duration
	queue_redraw()

func clear_evade_first_tap() -> void:
	evade_tap_time = 0.0
	queue_redraw()

func try_evade(input_direction := Vector2.ZERO, input_origin = null) -> bool:
	last_evade_was_assisted = false
	if evade_cooldown > 0.0:
		return false
	if energy < evade_energy_cost:
		if not allow_exhausted_evade:
			return false
		# Mandatory campaign gates must never become a permanent story lock.  The
		# assisted turn spends whatever remains and still enters the normal
		# cooldown; it is not available for free roaming or optional shortcuts.
		energy = 0.0
		last_evade_was_assisted = true
	else:
		energy -= evade_energy_cost
	var direction: Vector2 = input_direction.normalized()
	if direction.length_squared() < 0.01:
		direction = velocity.normalized() if velocity.length_squared() > 4.0 else Vector2.from_angle(facing)
	# For a double tap, the causal attempt begins on the first tap. Recording that
	# point prevents normal movement between taps from invalidating a legal evade,
	# while still rejecting an unrelated evade begun after leaving the locked path.
	last_evade_origin = position if input_origin == null else Vector2(input_origin)
	last_evade_direction = direction
	evade_tap_time = 0.0
	evade_sequence += 1
	velocity = direction * EVADE_SPEED * (assisted_evade_speed_scale if last_evade_was_assisted else 1.0)
	evade_time = EVADE_DURATION
	evade_cooldown = assisted_evade_cooldown if last_evade_was_assisted else EVADE_COOLDOWN
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
	evade_tap_time = maxf(0.0, evade_tap_time - delta)
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

	var auto_dashing := (
		move_duration > auto_dash_delay
		and (not auto_dash_requires_energy or energy > 8.0)
		and evade_time <= 0.0
	)
	var desired_speed := (
		(dash_speed if auto_dashing else base_speed)
		* speed_multiplier
		* environment_speed_multiplier
		* load_speed_multiplier
	)
	if evade_time > 0.0:
		velocity = velocity.move_toward(velocity.normalized() * 520.0, 180.0 * delta)
	elif is_moving:
		velocity = velocity.move_toward(
			input_direction.normalized() * desired_speed,
			acceleration * load_acceleration_multiplier * delta
		)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, braking * delta)

	if velocity.length_squared() > 1.0:
		facing = velocity.angle()
	position += velocity * delta
	_clamp_to_movement_bounds()
	var cruise_cost := drain_rate * delta if (drain_while_idle or is_moving) else 0.0
	var dash_cost := (
		auto_dash_drain_per_second * dash_cost_multiplier * load_dash_cost_multiplier * delta
		if auto_dashing
		else 0.0
	)
	energy = maxf(0.0, energy - cruise_cost - dash_cost)

	queue_redraw()

func _clamp_to_movement_bounds() -> void:
	position.x = clampf(position.x, _movement_bounds.position.x + 18.0, _movement_bounds.end.x - 18.0)
	position.y = clampf(position.y, _movement_bounds.position.y + 18.0, _movement_bounds.end.y - 18.0)

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, facing)
	# A slight vertical pulse keeps the wings alive before a full frame sheet exists.
	var wing_pulse := 0.96 + sin(Time.get_ticks_msec() * 0.03) * 0.04
	draw_set_transform(Vector2.ZERO, facing, Vector2(1.0, wing_pulse))
	var player_texture: Texture2D = spring_player_bee_frames[0] if has_spring_launch_art() else PLAYER_BEE_TEXTURE
	var player_size := Vector2(104, 82)
	var player_anchor_offset := Vector2.ZERO
	if has_spring_launch_art():
		var frame_index := 0
		if use_spring_launch_art:
			if evade_time > 0.0 or move_duration > auto_dash_delay:
				frame_index = 1
			elif visual_load_ratio >= 0.5:
				frame_index = 2
			elif energy <= max_energy * 0.28:
				frame_index = 3
		player_texture = spring_player_bee_frames[frame_index]
		# The 256px cells deliberately include breathing room. At this draw size the
		# actual silhouette lands near 72x52 and stays inside the existing HUD-safe
		# movement radius while retaining clean antialiasing.
		# Generated poses had different transparent margins. Register all four on the
		# same thorax pivot so changing load/speed never makes the bee jump sideways.
		var source_anchor_shift: float = float([-26.0, -4.0, -6.0, 12.0][frame_index])
		player_anchor_offset.x = source_anchor_shift * player_size.x / SPRING_PLAYER_FRAME_SIZE.x
	if evade_time > 0.0:
		var evade_ratio := clampf(evade_time / EVADE_DURATION, 0.0, 1.0)
		for trail_index in [2, 1]:
			var trail_offset := Vector2(-16.0 * float(trail_index), 0.0)
			var trail_alpha := evade_ratio * (0.10 + float(2 - trail_index) * 0.08)
			draw_texture_rect(player_texture, Rect2(player_size * -0.5 + player_anchor_offset + trail_offset, player_size), false, Color(0.82, 0.90, 1.0, trail_alpha))
	draw_texture_rect(player_texture, Rect2(player_size * -0.5 + player_anchor_offset, player_size), false)
	# Two stable body-surface pollen anchors summarize loose grains distributed on
	# contact hairs. They are not hind-leg pollen baskets. Shape and color match
	# the corresponding anther, stigma and scent route; 0/1/2 charges are drawn
	# exactly rather than collapsed into one icon.
	for variant in pollen_loads.size():
		PollenVisualLanguage.draw_cluster(
			self,
			PollenVisualLanguage.load_slot(variant),
			variant,
			pollen_loads[variant],
			1.15
		)
	if story_petal_visible:
		# A deliberately simple loose petal sits above the head for a few seconds.
		# It is drawn after the bee so the action reads at runtime even before the
		# final animation sheet replaces this procedural story prop.
		var petal_center := Vector2(17.0, -18.0)
		draw_colored_polygon(PackedVector2Array([
			petal_center + Vector2(-7, 0),
			petal_center + Vector2(0, -9),
			petal_center + Vector2(8, -1),
			petal_center + Vector2(1, 6),
		]), Color("f5a6bd"))
		draw_circle(petal_center + Vector2(1, -1), 2.3, Color("f4d56e"))
	if sense_time > 0.0:
		draw_arc(Vector2.ZERO, 27 + sin(Time.get_ticks_msec() * 0.012) * 4, 0, TAU, 28, Color("f1d46d", 0.72), 2)
	draw_set_transform(Vector2.ZERO)
	if evade_tap_time > 0.0 and evade_time <= 0.0:
		for tap_index in 2:
			var tip: Vector2 = evade_tap_direction * (34.0 + float(tap_index) * 14.0)
			var wing: Vector2 = evade_tap_direction.orthogonal() * 5.0
			var tap_alpha := 0.92 if tap_index == 0 else 0.24
			draw_line(tip - evade_tap_direction * 9.0 + wing, tip, Color("f4d36f", tap_alpha), 3.0)
			draw_line(tip - evade_tap_direction * 9.0 - wing, tip, Color("f4d36f", tap_alpha), 3.0)
