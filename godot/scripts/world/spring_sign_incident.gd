class_name SpringSignIncident
extends Node2D

## N01 second outing: the mosquito landowner's sign ropes have blown across the
## flower path. This is an avoidance and tidying encounter, never a combat room.
## Honey lost on contact stays lost, while an empty honey stomach can still finish
## every sign window and return home.

signal status_changed(snapshot: Dictionary)
signal journey_completed(payload: Dictionary)

const BeePlayerScript := preload("res://scripts/player/bee_player.gd")
const EvadeInputControllerScript := preload("res://scripts/player/evade_input_controller.gd")
const SoundFeedbackScript := preload("res://scripts/sound_feedback.gd")

const FIELD_TEXTURE_PATH := "res://assets/art/commercial/spring_world_ground_v1.png"
const HIVE_TEXTURE_PATH := "res://assets/art/commercial/main_hive_exterior_v1.png"
const WORKER_TEXTURE_PATH := "res://assets/art/commercial/worker_bee_topdown_v1.png"
const MENTOR_TEXTURE_PATH := "res://assets/art/commercial/mentor_bee_topdown_v1.png"
const MOSQUITO_STATES_PATH := "res://assets/art/commercial/mosquito_keeper_states_v1.png"
const MOSQUITO_FRAME_SIZE := Vector2(256.0, 192.0)

const WORLD_BOUNDS := Rect2(0.0, 0.0, 2140.0, 1180.0)
const VIEWPORT_SIZE := Vector2(1280.0, 720.0)
const PLAYABLE_BOUNDS := Rect2(33.0, 123.0, 1734.0, 1024.0)
const HIVE_POSITION := Vector2(235.0, 455.0)
const HIVE_ENTRY_AREA := Rect2(135.0, 355.0, 190.0, 150.0)
const START_POSITION := Vector2(327.0, 455.0)
const MOSQUITO_START := Vector2(1080.0, 520.0)
const SIGN_GOAL := 3
const INTERACTION_RANGE := 74.0
const CONTACT_RANGE := 55.0
const CONTACT_COOLDOWN := 1.65
const WIND_CYCLE := 4.5
const WIND_WINDOW_DURATION := 2.0
const INCIDENT_HONEY_GOAL := 6

var journey_token := 0
var starting_reserve := 0
var sortie_count := 0
var starting_honey := INCIDENT_HONEY_GOAL
var carried := INCIDENT_HONEY_GOAL
var honey_lost := 0
var bee: BeePlayer
var camera: Camera2D
var sound: SoundFeedback
var evade_input_controller = EvadeInputControllerScript.new()
var signs: Array[Dictionary] = []
var signs_resolved := 0
var last_resolved_index := -1
var wind_elapsed := 0.12
var mosquito_position := MOSQUITO_START
var mosquito_velocity := Vector2.ZERO
var mosquito_patrol_index := 0
var mosquito_contact_cooldown := 0.0
var mosquito_pause := 0.0
var mentor_position := Vector2(250.0, 610.0)
var mentor_return_active := false
var final_sign_on_back := false
var returned_with_mentor := false
var completion_emitted := false
var input_enabled := true
var message := "三处花标都能看见。等风带飞起来，贴近按空格把线结送回原处。"
var elapsed := 0.0
var flash := 0.0
var _status_clock := 0.0
var field_texture: Texture2D
var hive_texture: Texture2D
var worker_texture: Texture2D
var mentor_texture: Texture2D
var mosquito_states_texture: Texture2D
var mosquito_frames: Array[Texture2D] = []


func configure(context: Dictionary) -> Error:
	journey_token = int(context.get("journey_token", 0))
	starting_reserve = maxi(0, int(context.get("reserve", 0)))
	sortie_count = maxi(0, int(context.get("sortie_count", 0)))
	starting_honey = clampi(int(context.get("starting_honey", INCIDENT_HONEY_GOAL)), 0, INCIDENT_HONEY_GOAL)
	carried = starting_honey
	sound = context.get("sound_feedback") as SoundFeedback
	if journey_token <= 0:
		return ERR_INVALID_DATA
	return OK


func _ready() -> void:
	if ResourceLoader.exists(FIELD_TEXTURE_PATH):
		field_texture = ResourceLoader.load(FIELD_TEXTURE_PATH, "Texture2D") as Texture2D
	if ResourceLoader.exists(HIVE_TEXTURE_PATH):
		hive_texture = ResourceLoader.load(HIVE_TEXTURE_PATH, "Texture2D") as Texture2D
	if ResourceLoader.exists(WORKER_TEXTURE_PATH):
		worker_texture = ResourceLoader.load(WORKER_TEXTURE_PATH, "Texture2D") as Texture2D
	if ResourceLoader.exists(MENTOR_TEXTURE_PATH):
		mentor_texture = ResourceLoader.load(MENTOR_TEXTURE_PATH, "Texture2D") as Texture2D
	if ResourceLoader.exists(MOSQUITO_STATES_PATH):
		mosquito_states_texture = ResourceLoader.load(MOSQUITO_STATES_PATH, "Texture2D") as Texture2D
		for frame_index in 3:
			var frame := AtlasTexture.new()
			frame.atlas = mosquito_states_texture
			frame.region = Rect2(
				Vector2(float(frame_index) * MOSQUITO_FRAME_SIZE.x, 0.0),
				MOSQUITO_FRAME_SIZE
			)
			mosquito_frames.append(frame)
	if sound == null:
		sound = SoundFeedbackScript.new()
		add_child(sound)
	bee = BeePlayerScript.new()
	bee.max_energy = 120.0
	bee.configure(0.72)
	bee.set_movement_bounds(PLAYABLE_BOUNDS)
	bee.reset_for_expedition(START_POSITION)
	add_child(bee)
	bee.sense_started.connect(_on_bee_sense_started)
	bee.set_spring_launch_art(true)
	bee.set_visual_load_ratio(float(carried) / float(INCIDENT_HONEY_GOAL))

	camera = Camera2D.new()
	camera.name = "SignIncidentCamera"
	camera.position = VIEWPORT_SIZE * 0.5
	camera.limit_left = int(WORLD_BOUNDS.position.x)
	camera.limit_top = int(WORLD_BOUNDS.position.y)
	camera.limit_right = int(WORLD_BOUNDS.end.x)
	camera.limit_bottom = int(WORLD_BOUNDS.end.y)
	camera.position_smoothing_enabled = false
	add_child(camera)
	camera.make_current()

	signs = [
		_sign(0, Vector2(590.0, 286.0), 0.0),
		_sign(1, Vector2(970.0, 746.0), 1.5),
		_sign(2, Vector2(1435.0, 326.0), 3.0),
	]
	_emit_status()
	queue_redraw()


func _sign(id: int, position: Vector2, phase_offset: float) -> Dictionary:
	return {
		"id": id,
		"position": position,
		"phase_offset": phase_offset,
		"resolved": false,
	}


func _process(delta: float) -> void:
	elapsed += delta
	wind_elapsed += delta
	flash = maxf(0.0, flash - delta * 2.6)
	mosquito_contact_cooldown = maxf(0.0, mosquito_contact_cooldown - delta)
	mosquito_pause = maxf(0.0, mosquito_pause - delta)
	_status_clock -= delta
	if completion_emitted or not input_enabled:
		bee.active = false
		_update_camera()
		queue_redraw()
		return
	bee.active = true
	bee.set_visual_load_ratio(float(carried) / float(INCIDENT_HONEY_GOAL))
	_handle_actions()
	_update_mosquito(delta)
	_update_mentor(delta)
	_update_home()
	_update_camera()
	if _status_clock <= 0.0:
		_status_clock = 0.08
		_emit_status()
	queue_redraw()


func set_input_enabled(enabled: bool) -> void:
	input_enabled = enabled
	if bee == null:
		return
	bee.active = enabled and not completion_emitted
	if not enabled:
		bee.velocity = Vector2.ZERO
		bee.has_target = false
		evade_input_controller.clear(bee)


func _handle_actions() -> void:
	if Input.is_action_just_pressed("return_hive"):
		bee.set_move_target(HIVE_POSITION)
		message = (
			"老师傅已经跟上，往巢门飞就好。"
			if signs_resolved >= SIGN_GOAL
			else "巢门在左边。三处花标理完，老师傅会和你一起回去。"
		)
	if not Input.is_action_just_pressed("action"):
		return
	var sign_index := nearest_unresolved_sign(INTERACTION_RANGE)
	if sign_index < 0:
		bee.trigger_sense()
		message = "风里能分清三处线结、蚊庄主绕行的方向和左边巢门。"
		return
	if not is_wind_window_open(sign_index):
		message = "这块花标还压在草里。等它外圈的风线展开再理。"
		return
	_resolve_sign(sign_index)


func nearest_unresolved_sign(radius: float) -> int:
	if bee == null:
		return -1
	var nearest := -1
	var nearest_distance := radius
	for index in signs.size():
		var sign: Dictionary = signs[index]
		if bool(sign.get("resolved", false)):
			continue
		var distance := bee.position.distance_to(Vector2(sign.position))
		if distance < nearest_distance:
			nearest = index
			nearest_distance = distance
	return nearest


func is_wind_window_open(sign_index: int) -> bool:
	if sign_index < 0 or sign_index >= signs.size() or bool(signs[sign_index].get("resolved", false)):
		return false
	var phase := fposmod(wind_elapsed + float(signs[sign_index].phase_offset), WIND_CYCLE)
	return phase < WIND_WINDOW_DURATION


func _resolve_sign(sign_index: int) -> bool:
	if sign_index < 0 or sign_index >= signs.size():
		return false
	var sign: Dictionary = signs[sign_index]
	if bool(sign.get("resolved", false)):
		return false
	sign["resolved"] = true
	signs[sign_index] = sign
	signs_resolved += 1
	last_resolved_index = sign_index
	flash = 0.22
	sound.play_cue("repair")
	if signs_resolved >= SIGN_GOAL:
		final_sign_on_back = true
		mentor_return_active = true
		mosquito_pause = 999.0
		message = "最后一块花标稳稳落在蚊庄主背上。它停住了；老师傅飞到你身边，一起回巢。"
	else:
		message = "线结跟着风回到原处。还剩 %d 处。" % (SIGN_GOAL - signs_resolved)
	_emit_status()
	return true


func _update_mosquito(delta: float) -> void:
	if final_sign_on_back:
		mosquito_velocity = mosquito_velocity.move_toward(Vector2.ZERO, 320.0 * delta)
		return
	if mosquito_pause > 0.0:
		mosquito_velocity = mosquito_velocity.move_toward(Vector2.ZERO, 560.0 * delta)
		return
	var patrol := PackedVector2Array([
		Vector2(680.0, 500.0), Vector2(1110.0, 260.0),
		Vector2(1500.0, 650.0), Vector2(1030.0, 820.0),
	])
	var target := patrol[mosquito_patrol_index]
	var distance_to_bee := mosquito_position.distance_to(bee.position)
	if distance_to_bee < 480.0:
		target = bee.position
	elif mosquito_position.distance_to(target) < 36.0:
		mosquito_patrol_index = (mosquito_patrol_index + 1) % patrol.size()
		target = patrol[mosquito_patrol_index]
	var desired := (target - mosquito_position).normalized() * (215.0 if distance_to_bee < 480.0 else 150.0)
	mosquito_velocity = mosquito_velocity.move_toward(desired, 410.0 * delta)
	mosquito_position += mosquito_velocity * delta
	mosquito_position.x = clampf(mosquito_position.x, 280.0, PLAYABLE_BOUNDS.end.x - 30.0)
	mosquito_position.y = clampf(mosquito_position.y, PLAYABLE_BOUNDS.position.y + 30.0, PLAYABLE_BOUNDS.end.y - 30.0)
	if mosquito_position.distance_to(bee.position) <= CONTACT_RANGE:
		apply_mosquito_contact()


func apply_mosquito_contact() -> bool:
	if mosquito_contact_cooldown > 0.0 or completion_emitted or final_sign_on_back:
		return false
	if bee != null and bee.invulnerable_time > 0.0:
		message = "你从花标线旁一闪，蚊庄主只好绕半圈。"
		sound.play_cue("evade_clear")
		mosquito_contact_cooldown = 0.34
		return false
	mosquito_contact_cooldown = CONTACT_COOLDOWN
	mosquito_pause = 0.28
	if carried > 0:
		carried -= 1
		honey_lost += 1
		message = "擦身时蜜囊少了一滴。掉了就是掉了，花标的活也能做完。"
		sound.play_cue("honey_loss")
	else:
		message = "蜜囊已经空了，但蚊庄主没法把花标这件事也撞没。"
	bee.position += (bee.position - mosquito_position).normalized() * 38.0
	flash = 0.35
	_emit_status()
	return true


func _update_mentor(delta: float) -> void:
	if mentor_return_active:
		var side := Vector2(-74.0, 48.0).rotated(bee.facing)
		mentor_position = mentor_position.move_toward(bee.position + side, 330.0 * delta)
	else:
		mentor_position = Vector2(255.0, 618.0 + sin(elapsed * 1.8) * 8.0)


func _update_home() -> void:
	if signs_resolved < SIGN_GOAL or not HIVE_ENTRY_AREA.has_point(bee.position):
		return
	if mentor_position.distance_to(bee.position) > 105.0:
		message = "老师傅正往你这边飞。等半拍，一起进巢门。"
		return
	returned_with_mentor = true
	_complete_incident()


func _complete_incident() -> void:
	if completion_emitted:
		return
	completion_emitted = true
	bee.active = false
	message = "你和老师傅一起落在巢门前。接货蜂数着余下的蜜，一滴一滴往储蜜架传。"
	journey_completed.emit({
		"journey_kind": JourneyState.SIGN_INCIDENT,
		"journey_token": journey_token,
		"deposit": carried,
		"signs_resolved": signs_resolved,
		"honey_lost": honey_lost,
		"final_sign_on_back": final_sign_on_back,
		"returned_with_mentor": returned_with_mentor,
	})


func resume_after_failed_transition() -> void:
	completion_emitted = false
	returned_with_mentor = false
	message = "巢门刚才有点忙。老师傅还在身边，再靠近一次就好。"
	set_input_enabled(true)
	_emit_status()


func status_snapshot() -> Dictionary:
	var open_indices: Array[int] = []
	for index in signs.size():
		if is_wind_window_open(index):
			open_indices.append(index + 1)
	return {
		"journey_kind": JourneyState.SIGN_INCIDENT,
		"area": area_name_for(bee.position) if bee != null else "春野 · 花标路",
		"carried": carried,
		"capacity": starting_honey,
		"energy": bee.energy if bee != null else 0.0,
		"energy_cap": bee.max_energy if bee != null else 120.0,
		"reserve": starting_reserve,
		"starting_honey": starting_honey,
		"honey_lost": honey_lost,
		"signs_resolved": signs_resolved,
		"sign_goal": SIGN_GOAL,
		"open_sign_windows": open_indices,
		"final_sign_on_back": final_sign_on_back,
		"return_with_mentor_required": true,
		"returned_with_mentor": returned_with_mentor,
		"message": message,
	}


func area_name_for(world_position: Vector2) -> String:
	if world_position.x < 430.0:
		return "春野 · 巢门外"
	if world_position.x < 820.0:
		return "春野 · 第一处花标"
	if world_position.x < 1250.0:
		return "春野 · 花田中段花标"
	return "春野 · 远处花标"


func _emit_status() -> void:
	status_changed.emit(status_snapshot())


func _update_camera() -> void:
	if camera == null or bee == null:
		return
	var half := VIEWPORT_SIZE * 0.5
	camera.position = Vector2(
		clampf(bee.position.x, WORLD_BOUNDS.position.x + half.x, WORLD_BOUNDS.end.x - half.x),
		clampf(bee.position.y, WORLD_BOUNDS.position.y + half.y, WORLD_BOUNDS.end.y - half.y)
	)


func _unhandled_input(event: InputEvent) -> void:
	if completion_emitted or not input_enabled or bee == null:
		return
	for direction_key in ["left", "right", "up", "down"]:
		if event.is_action_pressed("move_%s" % direction_key):
			var direction := Vector2(EvadeInputControllerScript.DIRECTION_VECTORS[direction_key])
			var direction_result := evade_input_controller.register_direction_tap(
				direction_key, direction, Time.get_ticks_msec() * 0.001, bee
			)
			_play_evade_result(direction_result)
			return
	var screen_position := Vector2.ZERO
	var pressed := false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		screen_position = event.position
		pressed = event.pressed
	elif event is InputEventScreenTouch:
		screen_position = event.position
		pressed = event.pressed
	if not pressed:
		return
	var world_position := get_canvas_transform().affine_inverse() * screen_position
	var result: Dictionary = evade_input_controller.handle_world_tap(
		world_position,
		Time.get_ticks_msec() * 0.001,
		bee,
		PLAYABLE_BOUNDS,
		true
	)
	_play_evade_result(result)
	if bool(result.get("consumed", false)):
		get_viewport().set_input_as_handled()


func _play_evade_result(result: Dictionary) -> void:
	if bool(result.get("evade_started", false)) and sound != null:
		sound.play_cue("evade")


func _on_bee_sense_started() -> void:
	if sound != null:
		sound.play_cue("sense")


func _draw() -> void:
	_draw_ground()
	_draw_hive()
	_draw_sign_routes()
	for index in signs.size():
		_draw_sign(index)
	_draw_mosquito()
	_draw_mentor()
	_draw_sense_routes()
	if flash > 0.0:
		draw_rect(WORLD_BOUNDS, Color("f6d7a4", flash * 0.16))


func _draw_ground() -> void:
	if field_texture != null:
		draw_texture_rect(field_texture, WORLD_BOUNDS, false, Color(0.96, 1.0, 0.96))
		return
	draw_rect(WORLD_BOUNDS, Color("a9ca8e"))
	for strip in 9:
		var y := 145.0 + float(strip) * 105.0
		draw_line(Vector2(180.0, y), Vector2(1800.0, y + sin(float(strip)) * 48.0), Color("708d61", 0.13), 34.0)
	for patch in 32:
		var position := Vector2(
			260.0 + fmod(float(patch * 211), 1480.0),
			145.0 + fmod(float(patch * 139), 820.0)
		)
		draw_circle(position, 18.0 + float(patch % 4) * 8.0, Color("e9d88d", 0.13))


func _draw_hive() -> void:
	if hive_texture != null:
		draw_texture_rect(hive_texture, Rect2(40, 130, 330, 412), false)
		for worker in 3:
			var worker_position := Vector2(
				308.0 + float(worker) * 28.0,
				430.0 + sin(elapsed * 2.0 + worker) * 31.0
			)
			if worker_texture != null:
				draw_set_transform(worker_position, PI + float(worker) * 0.08)
				draw_texture_rect(worker_texture, Rect2(-34, -30, 68, 60), false)
				draw_set_transform(Vector2.ZERO)
			else:
				draw_circle(worker_position, 7.0, Color("e6bd48"))
		return
	draw_colored_polygon(PackedVector2Array([
		Vector2(28, 432), Vector2(190, 394), Vector2(264, 470),
		Vector2(252, 642), Vector2(38, 658),
	]), Color("ae8a55"))
	draw_rect(Rect2(74, 477, 132, 134), Color("604833"))
	draw_rect(Rect2(88, 492, 118, 104), Color("d4bd76", 0.35), false, 5.0)
	for worker in 3:
		var position := Vector2(218.0 + float(worker) * 28.0, 526.0 + sin(elapsed * 2.0 + worker) * 34.0)
		draw_circle(position, 7.0, Color("e6bd48"))


func _draw_sign_routes() -> void:
	var route := PackedVector2Array([HIVE_POSITION, Vector2(signs[0].position), Vector2(signs[1].position), Vector2(signs[2].position)])
	for index in range(route.size() - 1):
		draw_dashed_line(route[index], route[index + 1], Color("f0e0ad", 0.24), 2.0, 22.0)


func _draw_sign(index: int) -> void:
	var sign: Dictionary = signs[index]
	var position := Vector2(sign.position)
	var resolved := bool(sign.get("resolved", false))
	var ready := is_wind_window_open(index)
	draw_line(position + Vector2(-34, 50), position + Vector2(-34, -42), Color("6d5237"), 8.0)
	if resolved:
		draw_rect(Rect2(position + Vector2(-31, -42), Vector2(82, 52)), Color("d9b86b"))
		draw_rect(Rect2(position + Vector2(-31, -42), Vector2(82, 52)), Color("634d36"), false, 4.0)
		for mark in index + 1:
			draw_line(position + Vector2(-12 + mark * 18, -29), position + Vector2(-12 + mark * 18, -4), Color("745d3e"), 4.0)
		return
	var sway := sin(wind_elapsed * 2.3 + float(index)) * (10.0 if ready else 3.0)
	var board_position := position + Vector2(28.0 + sway, 18.0)
	draw_line(position + Vector2(-31, -28), board_position, Color("746043"), 4.0)
	draw_rect(Rect2(board_position + Vector2(-38, -24), Vector2(84, 48)), Color("d9b86b"))
	draw_rect(Rect2(board_position + Vector2(-38, -24), Vector2(84, 48)), Color("634d36"), false, 4.0)
	for mark in index + 1:
		draw_line(board_position + Vector2(-18 + mark * 18, -12), board_position + Vector2(-18 + mark * 18, 12), Color("745d3e"), 4.0)
	var ring_color := Color("fff0a8", 0.90) if ready else Color("6d7665", 0.35)
	draw_arc(position, 66.0, -2.7, 0.35, 26, ring_color, 5.0)
	if ready:
		for gust in 3:
			var gust_y := -38.0 + float(gust) * 23.0
			draw_line(position + Vector2(-74, gust_y), position + Vector2(-46, gust_y - 5), Color("f8e8ad", 0.78), 4.0)


func _draw_mosquito() -> void:
	var angle := mosquito_velocity.angle() if mosquito_velocity.length_squared() > 1.0 else 0.0
	if mosquito_frames.size() == 3:
		var frame_index := 2 if final_sign_on_back else (1 if honey_lost > 0 else 0)
		draw_set_transform(mosquito_position, angle)
		draw_texture_rect(mosquito_frames[frame_index], Rect2(-76, -57, 152, 114), false)
		draw_set_transform(Vector2.ZERO)
		return
	draw_set_transform(mosquito_position, angle)
	var abdomen_radius := Vector2(26.0 + float(honey_lost) * 2.2, 18.0 + float(honey_lost) * 1.4)
	draw_set_transform(mosquito_position, angle, Vector2(1.0, abdomen_radius.y / abdomen_radius.x))
	draw_circle(Vector2(-18, 0), abdomen_radius.x, Color("7f765d"))
	draw_set_transform(mosquito_position, angle)
	draw_circle(Vector2(12, 0), 15.0, Color("706955"))
	draw_line(Vector2(22, 0), Vector2(58, -4), Color("4d4b43"), 4.0)
	draw_colored_polygon(PackedVector2Array([Vector2(-4, -5), Vector2(-34, -34), Vector2(10, -22)]), Color("dce3d5", 0.72))
	draw_colored_polygon(PackedVector2Array([Vector2(-4, 5), Vector2(-34, 34), Vector2(10, 22)]), Color("dce3d5", 0.72))
	for leg in [-1.0, 1.0]:
		draw_line(Vector2(2, leg * 9), Vector2(-16, leg * 34), Color("4d4b43"), 3.0)
		draw_line(Vector2(10, leg * 8), Vector2(30, leg * 29), Color("4d4b43"), 3.0)
	if final_sign_on_back:
		draw_set_transform(mosquito_position, angle + 0.12)
		draw_rect(Rect2(-38, -32, 58, 28), Color("d9b86b"))
		draw_rect(Rect2(-38, -32, 58, 28), Color("634d36"), false, 3.0)
	draw_set_transform(Vector2.ZERO)


func _draw_mentor() -> void:
	if mentor_texture != null:
		draw_set_transform(mentor_position, bee.facing if mentor_return_active else -0.15)
		draw_texture_rect(mentor_texture, Rect2(-58, -48, 116, 96), false)
		draw_set_transform(Vector2.ZERO)
		return
	draw_set_transform(mentor_position, bee.facing if mentor_return_active else -0.15)
	draw_colored_polygon(PackedVector2Array([Vector2(-8, -7), Vector2(-29, -29), Vector2(3, -23)]), Color("d6e2dc", 0.76))
	draw_colored_polygon(PackedVector2Array([Vector2(-8, 7), Vector2(-29, 29), Vector2(3, 23)]), Color("d6e2dc", 0.76))
	draw_circle(Vector2(-7, 0), 17.0, Color("c99f3f"))
	draw_circle(Vector2(14, 0), 12.0, Color("8a7141"))
	draw_line(Vector2(-18, -9), Vector2(-18, 9), Color("544632"), 4.0)
	draw_set_transform(Vector2.ZERO)


func _draw_sense_routes() -> void:
	if bee == null or bee.sense_time <= 0.0:
		return
	for index in signs.size():
		if not bool(signs[index].get("resolved", false)):
			draw_dashed_line(bee.position, Vector2(signs[index].position), Color("f8e4a3", 0.55), 3.0, 18.0)
	if signs_resolved >= SIGN_GOAL:
		draw_dashed_line(bee.position, HIVE_POSITION, Color("f8e4a3", 0.72), 4.0, 18.0)
