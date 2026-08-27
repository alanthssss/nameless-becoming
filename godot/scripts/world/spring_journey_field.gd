class_name SpringJourneyField
extends Node2D

signal status_changed(snapshot: Dictionary)
signal journey_completed(payload: Dictionary)

const BeePlayerScript := preload("res://scripts/player/bee_player.gd")
const PollinationMechanicScript := preload("res://scripts/mechanics/pollination_mechanic.gd")
const RelayHiveMechanicScript := preload("res://scripts/mechanics/relay_hive_mechanic.gd")
const SoundFeedbackScript := preload("res://scripts/sound_feedback.gd")

const FIELD_TEXTURE_PATH := "res://assets/art/commercial/spring_world_ground_v1.png"
const FLOWER_STATES_PATH := "res://assets/art/commercial/flower_states_topdown_v1.png"
const FLOWER_FRAME_SIZE := Vector2(256.0, 256.0)
const HIVE_TEXTURE_PATH := "res://assets/art/commercial/main_hive_exterior_v1.png"
const REST_HIVE_TEXTURE_PATH := "res://assets/art/commercial/rest_hive_exterior_v1.png"
const COLONY_BEE_PATH := "res://assets/art/commercial/worker_bee_topdown_v1.png"
const MENTOR_BEE_PATH := "res://assets/art/commercial/mentor_bee_topdown_v1.png"
const WORLD_BOUNDS := Rect2(0.0, 0.0, 2140.0, 1180.0)
const VIEWPORT_SIZE := Vector2(1280.0, 720.0)
# The persistent HUD covers y=0..90 and x=1018..1280. The rotated 82×60 bee has
# a 50.8px circumscribed radius, so the playable range reserves 51px around its
# center even while turning. This keeps the full silhouette out of the HUD.
const PLAYABLE_BOUNDS := Rect2(33.0, 123.0, 1734.0, 1024.0)
const HUD_SAFE_RECT := Rect2(0.0, 90.0, 1018.0, 630.0)
const BEE_VISUAL_SAFE_EXTENTS := Vector2(51.0, 51.0)
const HIVE_RETURN_POS := Vector2(235.0, 455.0)
const HIVE_ENTRY_AREA := Rect2(135.0, 355.0, 190.0, 150.0)
const RELAY_POSITION := Vector2(1115.0, 575.0)
const RETURN_BREEZE := Rect2(650.0, 880.0, 1300.0, 170.0)
const CARRY_CAPACITY := 8
const DELIVERY_GOAL := 6
const HARVEST_INTERVAL := 0.42
const DEPOSIT_DWELL := 0.78
const STORY_BUMP_END := 1.05
const STORY_PETAL_END := 2.15
const STORY_DEMO_END := 4.45

var journey_token := 0
var starting_reserve := 0
var sortie_count := 0
var first_sortie := false
var bee: BeePlayer
var camera: Camera2D
var sound: SoundFeedback
var pollination
var relay_hive = RelayHiveMechanicScript.new()
var flowers: Array = []
var carried := 0
var delivered := 0
var message := "先去近处花心取散粉。"
var elapsed := 0.0
var flash := 0.0
var harvest_clock := 0.0
var hive_dwell := 0.0
var relay_was_resting := false
var shortcut_used := false
var completion_emitted := false
var exhaustion_notice_shown := false
var input_enabled := true
var field_texture: Texture2D
var flower_state_texture: Texture2D
var flower_state_frames: Array[Texture2D] = []
var hive_texture: Texture2D
var rest_hive_texture: Texture2D
var colony_bee_texture: Texture2D
var mentor_bee_texture: Texture2D
var _status_clock := 0.0
var story_intro_active := false
var story_intro_elapsed := 0.0
var story_intro_phase := ""
var mentor_demonstration_completed := false
var mentor_story_position := Vector2.ZERO


func configure(context: Dictionary) -> Error:
	journey_token = int(context.get("journey_token", 0))
	starting_reserve = maxi(0, int(context.get("reserve", 0)))
	sortie_count = maxi(0, int(context.get("sortie_count", 0)))
	first_sortie = bool(context.get("first_sortie", sortie_count <= 1))
	sound = context.get("sound_feedback") as SoundFeedback
	if journey_token <= 0:
		return ERR_INVALID_DATA
	return OK


func _ready() -> void:
	field_texture = _load_texture(FIELD_TEXTURE_PATH)
	flower_state_texture = _load_texture(FLOWER_STATES_PATH)
	if flower_state_texture != null:
		for row in 2:
			for column in 3:
				var frame := AtlasTexture.new()
				frame.atlas = flower_state_texture
				frame.region = Rect2(
					Vector2(float(column) * FLOWER_FRAME_SIZE.x, float(row) * FLOWER_FRAME_SIZE.y),
					FLOWER_FRAME_SIZE
				)
				flower_state_frames.append(frame)
	hive_texture = _load_texture(HIVE_TEXTURE_PATH)
	rest_hive_texture = _load_texture(REST_HIVE_TEXTURE_PATH)
	colony_bee_texture = _load_texture(COLONY_BEE_PATH)
	mentor_bee_texture = _load_texture(MENTOR_BEE_PATH)

	if sound == null:
		sound = SoundFeedbackScript.new()
		add_child(sound)
	bee = BeePlayerScript.new()
	bee.max_energy = 120.0
	bee.configure(0.9)
	bee.set_movement_bounds(PLAYABLE_BOUNDS)
	bee.reset_for_expedition(HIVE_RETURN_POS + Vector2(92.0, 0.0))
	add_child(bee)
	bee.sense_started.connect(_on_bee_sense_started)
	bee.set_spring_launch_art(true)
	bee.set_visual_load_ratio(0.0)

	camera = Camera2D.new()
	camera.name = "FieldCamera"
	camera.position = Vector2(VIEWPORT_SIZE.x * 0.5, VIEWPORT_SIZE.y * 0.5)
	camera.limit_left = int(WORLD_BOUNDS.position.x)
	camera.limit_top = int(WORLD_BOUNDS.position.y)
	camera.limit_right = int(WORLD_BOUNDS.end.x)
	camera.limit_bottom = int(WORLD_BOUNDS.end.y)
	# Exact following makes the HUD safety calculation deterministic at map edges.
	# Smoothing can return later with a look-ahead budget that preserves this margin.
	camera.position_smoothing_enabled = false
	add_child(camera)
	camera.make_current()

	_build_authored_route()
	pollination = PollinationMechanicScript.new()
	pollination.start(self, {}, {})
	relay_hive.configure({
		"position": RELAY_POSITION,
		"activation_cost": 1,
		"energy_restore_per_second": 12.0,
		"energy_cap_ratio": 0.65,
	})
	if first_sortie:
		_start_story_intro()
	_emit_status()
	queue_redraw()


func _load_texture(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	return ResourceLoader.load(path, "Texture2D") as Texture2D


func _build_authored_route() -> void:
	flowers = [
		_flower(0, Vector2(390, 455), 1, 0, false),
		_flower(1, Vector2(455, 700), 1, 1, false),
		_flower(2, Vector2(650, 320), 1, 0, false),
		_flower(3, Vector2(760, 690), 1, 1, false),
		_flower(4, Vector2(830, 490), 0, 0, false),
		_flower(5, Vector2(1015, 805), 0, 1, false),
		_flower(6, Vector2(1660, 310), 4, 0, true),
		_flower(7, Vector2(1770, 775), 4, 1, true),
	]


func _flower(id: int, position: Vector2, nectar: int, variant: int, large: bool) -> Dictionary:
	return {
		"id": id,
		"position": position,
		"nectar": nectar,
		"max_nectar": nectar,
		"kind": variant,
		"visual_variant": variant,
		"large_bloom": large,
		"phase": float(id) * 0.73,
		"recovery": false,
		"type": "peak_bloom" if large else "nectar_bloom",
	}


func _process(delta: float) -> void:
	elapsed += delta
	flash = maxf(0.0, flash - delta * 2.8)
	_status_clock -= delta
	if completion_emitted or not input_enabled:
		bee.active = false
		_update_camera()
		queue_redraw()
		return
	if story_intro_active:
		bee.active = false
		_update_story_intro(delta)
		_update_camera()
		if _status_clock <= 0.0:
			_status_clock = 0.08
			_emit_status()
		queue_redraw()
		return
	bee.active = true
	bee.set_visual_load_ratio(float(carried) / float(CARRY_CAPACITY))
	pollination.process(delta)
	_handle_actions(delta)
	_update_relay(delta)
	_update_main_hive(delta)
	_update_return_breeze(delta)
	_update_camera()
	if bee.energy <= 0.0 and not exhaustion_notice_shown:
		exhaustion_notice_shown = true
		message = "翅膀累得发沉，只能慢慢飞；小蜂房能歇脚。"
	elif bee.energy > 0.0:
		exhaustion_notice_shown = false
	if _status_clock <= 0.0:
		_status_clock = 0.08
		_emit_status()
	queue_redraw()


func set_input_enabled(enabled: bool) -> void:
	input_enabled = enabled
	if bee == null:
		return
	bee.active = enabled and not completion_emitted and not story_intro_active
	if not enabled:
		bee.velocity = Vector2.ZERO
		bee.has_target = false
		harvest_clock = 0.0


func _start_story_intro() -> void:
	story_intro_active = true
	story_intro_elapsed = 0.0
	story_intro_phase = "bumped_flower"
	mentor_demonstration_completed = false
	mentor_story_position = bee.position + Vector2(170.0, -55.0)
	bee.set_story_petal(true)
	message = "新蜂一头飞进花里。再飞出来时，头上多了一片粉色花片。"


func _update_story_intro(delta: float) -> void:
	if not story_intro_active:
		return
	story_intro_elapsed += maxf(0.0, delta)
	if story_intro_elapsed < STORY_BUMP_END:
		story_intro_phase = "bumped_flower"
		mentor_story_position = bee.position + Vector2(175.0, -55.0)
		message = "新蜂一头飞进花里。再飞出来时，头上多了一片粉色花片。"
	elif story_intro_elapsed < STORY_PETAL_END:
		story_intro_phase = "petal_removed"
		mentor_story_position = bee.position + Vector2(58.0, -24.0)
		bee.set_story_petal(false)
		message = "老师傅停在身边，把花片取下来：先看一次。"
	elif story_intro_elapsed < STORY_DEMO_END:
		story_intro_phase = "mentor_demonstration"
		# The mentor traces donor -> matching stigma in presentation space only.
		# No flower dictionary or PollinationMechanic state is touched here.
		var ratio := clampf(
			(story_intro_elapsed - STORY_PETAL_END) / (STORY_DEMO_END - STORY_PETAL_END),
			0.0,
			1.0
		)
		var donor_position := Vector2(flowers[0].position)
		var receptive_position := Vector2(flowers[4].position)
		mentor_story_position = donor_position.lerp(receptive_position, ratio)
		message = "老师傅贴过带散粉的花心，再把同形散粉送到第二朵花。花蜜一点没动。"
	else:
		story_intro_active = false
		story_intro_phase = "first_job"
		mentor_demonstration_completed = true
		bee.set_story_petal(false)
		bee.active = input_enabled and not completion_emitted
		message = "老师傅往后让了让：这回你来。两朵花心和 6 滴花蜜都在等。"
	_emit_status()


func _handle_actions(delta: float) -> void:
	if Input.is_action_just_pressed("return_hive"):
		bee.set_move_target(HIVE_RETURN_POS)
		message = "回家的方向记住了。"

	var flower_index := nearest_flower(58.0)
	if Input.is_action_just_pressed("action"):
		var relay_result: Dictionary = relay_hive.try_activate(bee.position, carried)
		var relay_event := String(relay_result.get("event", ""))
		if relay_event == "activated":
			carried -= int(relay_result.get("consumed", 0))
			sound.play_cue("relay")
			message = "小蜂房亮起一格，停稳就能歇一会儿。"
		elif relay_event == "needs_honey":
			message = "小蜂房要一滴随身蜜才能开门。"
		elif pollination.try_context_action(bee.position):
			pass
		elif flower_index < 0:
			bee.trigger_sense()
			message = "风里有散粉、花心和回家的方向。"

	if Input.is_action_pressed("action") and flower_index >= 0 and bee.energy > 0.0:
		var flower: Dictionary = flowers[flower_index]
		if int(flower.get("nectar", 0)) <= 0:
			harvest_clock = 0.0
			return
		harvest_clock += delta
		bee.energy = maxf(0.0, bee.energy - 2.8 * delta)
		if harvest_clock >= HARVEST_INTERVAL:
			harvest_clock = 0.0
			if carried >= CARRY_CAPACITY:
				message = "蜜囊满了。该往家飞啦。"
				sound.play_cue("full")
				return
			flower["nectar"] = int(flower.nectar) - 1
			flowers[flower_index] = flower
			carried += 1
			pollination.on_harvest(flower_index)
			sound.play_cue("harvest")
			if not bool(flower.get("has_anthers", false)):
				message = "一滴蜜进了蜜囊。"
	else:
		harvest_clock = 0.0


func _on_bee_sense_started() -> void:
	if sound != null:
		sound.play_cue("sense")


func nearest_flower(radius: float) -> int:
	var nearest := -1
	var nearest_distance := radius
	for index in flowers.size():
		var flower: Dictionary = flowers[index]
		var distance := bee.position.distance_to(Vector2(flower.position))
		if distance < nearest_distance:
			nearest = index
			nearest_distance = distance
	return nearest


func _update_relay(delta: float) -> void:
	var still := bee.velocity.length_squared() < 4.0 and not bee.has_target
	var result: Dictionary = relay_hive.process(
		delta,
		bee.position,
		still,
		bee.energy,
		bee.max_energy
	)
	bee.energy = float(result.get("energy", bee.energy))
	var resting := bool(result.get("resting", false))
	if resting and not relay_was_resting:
		message = "有人扶住落脚板。这里能歇一会儿，货还是要带回家。"
	relay_was_resting = resting


func _update_main_hive(delta: float) -> void:
	var inside := HIVE_ENTRY_AREA.has_point(bee.position)
	if not inside:
		hive_dwell = 0.0
		return
	bee.energy = minf(bee.max_energy, bee.energy + 22.0 * delta)
	var still := bee.velocity.length_squared() < 9.0 and not bee.has_target
	if not still:
		hive_dwell = 0.0
		return
	hive_dwell += delta
	if hive_dwell < DEPOSIT_DWELL:
		return
	var amount := carried
	hive_dwell = 0.0
	if amount > 0:
		carried = 0
		delivered += amount
		flash = 0.42
		sound.play_cue("home")
		message = "接货蜂把 %d 滴蜜往里传。" % amount
	if delivered >= DELIVERY_GOAL and pollination.can_complete():
		_complete_journey()
	elif amount > 0 and delivered >= DELIVERY_GOAL:
		message += " 还有花心在等散粉。"
	elif amount > 0:
		message += " 还差 %d 滴。" % (DELIVERY_GOAL - delivered)
	elif delivered >= DELIVERY_GOAL:
		message = "蜜已经送够了，还有花心在等散粉。"


func _update_return_breeze(delta: float) -> void:
	if not RETURN_BREEZE.has_point(bee.position):
		return
	if bee.velocity.x < -5.0 or (bee.has_target and bee.target.x < bee.position.x):
		bee.position.x = maxf(PLAYABLE_BOUNDS.position.x + 18.0, bee.position.x - 115.0 * delta)
		if not shortcut_used:
			shortcut_used = true
			message = (
				"花田的活办妥了，正好从下面的回风路轻快返程。"
				if pollination.can_complete()
				else "下面这股回风一直朝巢门去。"
			)


func _complete_journey() -> void:
	if completion_emitted:
		return
	completion_emitted = true
	bee.active = false
	message = "都送到了。巢门里面有人接着。"
	journey_completed.emit({
		"journey_kind": JourneyState.SPRING_ROUTE,
		"journey_token": journey_token,
		"deposit": delivered,
		"pollinations": int(pollination.pollinated_flowers),
		"relay_activated": bool(relay_hive.active),
		"shortcut_used": shortcut_used,
	})


func resume_after_failed_transition() -> void:
	completion_emitted = false
	message = "巢门刚才有点忙，再靠近停稳一次就好。"
	set_input_enabled(true)
	_emit_status()


func _update_camera() -> void:
	if camera == null or bee == null:
		return
	var desired := bee.position
	var half := VIEWPORT_SIZE * 0.5
	desired.x = clampf(desired.x, WORLD_BOUNDS.position.x + half.x, WORLD_BOUNDS.end.x - half.x)
	desired.y = clampf(desired.y, WORLD_BOUNDS.position.y + half.y, WORLD_BOUNDS.end.y - half.y)
	camera.position = desired


func camera_target_for(world_position: Vector2) -> Vector2:
	var half := VIEWPORT_SIZE * 0.5
	return Vector2(
		clampf(world_position.x, WORLD_BOUNDS.position.x + half.x, WORLD_BOUNDS.end.x - half.x),
		clampf(world_position.y, WORLD_BOUNDS.position.y + half.y, WORLD_BOUNDS.end.y - half.y)
	)


func projected_screen_position(world_position: Vector2) -> Vector2:
	return world_position - camera_target_for(world_position) + VIEWPORT_SIZE * 0.5


func _unhandled_input(event: InputEvent) -> void:
	if completion_emitted or not input_enabled:
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
	if WORLD_BOUNDS.has_point(world_position):
		bee.set_move_target(clamp_to_playable_center(world_position))
		get_viewport().set_input_as_handled()


func screen_to_world(screen_position: Vector2) -> Vector2:
	return get_canvas_transform().affine_inverse() * screen_position


func clamp_to_playable_center(world_position: Vector2) -> Vector2:
	return Vector2(
		clampf(world_position.x, PLAYABLE_BOUNDS.position.x + 18.0, PLAYABLE_BOUNDS.end.x - 18.0),
		clampf(world_position.y, PLAYABLE_BOUNDS.position.y + 18.0, PLAYABLE_BOUNDS.end.y - 18.0)
	)


func status_snapshot() -> Dictionary:
	var pollinated := int(pollination.pollinated_flowers) if pollination != null else 0
	var relay_state := relay_hive.status_id()
	return {
		"journey_kind": JourneyState.SPRING_ROUTE,
		"area": area_name_for(bee.position) if bee != null else "春野",
		"carried": carried,
		"capacity": CARRY_CAPACITY,
		"energy": bee.energy if bee != null else 0.0,
		"energy_cap": bee.max_energy if bee != null else 120.0,
		"reserve": starting_reserve + delivered,
		"delivered": mini(delivered, DELIVERY_GOAL),
		"delivery_goal": DELIVERY_GOAL,
		"pollinated": mini(pollinated, 2),
		"pollination_goal": 2,
		"relay_state": relay_state,
		"story_phase": story_intro_phase,
		"story_intro_active": story_intro_active,
		"mentor_demonstration_complete": mentor_demonstration_completed,
		"message": message,
	}


func area_name_for(world_position: Vector2) -> String:
	if RETURN_BREEZE.has_point(world_position):
		return "春野 · 回风路"
	if world_position.x < 760.0:
		return "春野 · 近花坡"
	if world_position.x < 1450.0:
		return "春野 · 小蜂房"
	return "春野 · 远花坡"


func _emit_status() -> void:
	status_changed.emit(status_snapshot())


func _draw() -> void:
	_draw_ground()
	_draw_routes()
	_draw_hive()
	_draw_relay_hive()
	for flower in flowers:
		_draw_flower(flower)
	if pollination != null:
		pollination.draw()
	_draw_story_intro()
	_draw_navigation()
	if flash > 0.0:
		draw_rect(WORLD_BOUNDS, Color("fff0a0", flash * 0.18))


func _draw_ground() -> void:
	if field_texture != null:
		# The commercial ground master already carries the route hierarchy and the
		# single light/value system. Keep it unfiltered by prototype color bands.
		draw_texture_rect(field_texture, WORLD_BOUNDS, false)
	else:
		draw_rect(WORLD_BOUNDS, Color("b6d391"))


func _draw_routes() -> void:
	# The authored ground already contains the outbound and return paths. Only the
	# earned tailwind remains animated; permanent debug-like route paint would
	# compete with flowers and make the commercial background look double-drawn.
	if pollination != null and pollination.can_complete():
		for stitch in 18:
			var ratio := float(stitch) / 17.0
			var start := Vector2(660.0, 960.0).lerp(Vector2(1920.0, 960.0), ratio)
			draw_line(start, start + Vector2(-28.0, 0), Color("f5dfa1", 0.30 + 0.15 * sin(elapsed * 3.0 + stitch)), 3.0)


func _draw_hive() -> void:
	var activity := 0.28 + 0.16 * sin(elapsed * 2.2)
	draw_colored_polygon(PackedVector2Array([
		Vector2(118, 355), Vector2(328, 355), Vector2(385, 520), Vector2(82, 520)
	]), Color("f3d47a", 0.18 + activity * 0.16))
	if hive_texture != null:
		draw_texture_rect(hive_texture, Rect2(40, 130, 330, 412), false)
	else:
		draw_rect(Rect2(62, 180, 285, 340), Color("b99058"))
	for worker in 3:
		var worker_pos := Vector2(308.0 + sin(elapsed * 1.8 + worker) * 32.0, 430.0 + float(worker) * 31.0)
		_draw_worker(worker_pos, false)


func _draw_relay_hive() -> void:
	var active := bool(relay_hive.active)
	var pos := RELAY_POSITION
	if rest_hive_texture != null:
		var tint := Color.WHITE if active else Color(0.72, 0.73, 0.68, 0.94)
		draw_texture_rect(
			rest_hive_texture,
			Rect2(pos + Vector2(-112.0, -88.0), Vector2(224.0, 168.0)),
			false,
			tint
		)
		# A waiting worker and the open landing board communicate rest availability;
		# the shelter never gains a literal fire or universal checkpoint aura.
		_draw_worker(pos + Vector2(70.0, 35.0 + sin(elapsed * 1.7) * 4.0), false)
		if active:
			for frame in 3:
				draw_circle(pos + Vector2(-22.0 + float(frame) * 22.0, 3.0), 4.0, Color("f3cf68", 0.86))
		return
	draw_colored_polygon(PackedVector2Array([
		pos + Vector2(-70, 42), pos + Vector2(68, 42),
		pos + Vector2(92, 88), pos + Vector2(-94, 88)
	]), Color("e9cf83", 0.18 if active else 0.08))
	# The field post is a low horizontal shelter with exposed frames, not a scaled
	# copy of the tall home hive. The silhouette makes its limited role readable.
	var shell := Color("c5a873") if active else Color("9d9278")
	draw_colored_polygon(PackedVector2Array([
		pos + Vector2(-82, -44), pos + Vector2(-55, -70),
		pos + Vector2(63, -70), pos + Vector2(84, -44)
	]), shell.lightened(0.12))
	draw_rect(Rect2(pos + Vector2(-72, -44), Vector2(144, 92)), shell)
	draw_rect(Rect2(pos + Vector2(-72, -44), Vector2(144, 92)), Color("514638", 0.72), false, 4.0)
	for frame in 3:
		var frame_rect := Rect2(pos + Vector2(-52.0 + float(frame) * 38.0, -30.0), Vector2(28, 52))
		draw_rect(frame_rect, Color("5b503e", 0.52), false, 3.0)
		if active:
			draw_circle(frame_rect.get_center(), 5.0, Color("f2cf5b", 0.72))
	draw_rect(Rect2(pos + Vector2(-25, 20), Vector2(50, 31)), Color("58483a", 0.88))
	# A worker opening the landing board gives the rest state its warmth. There is
	# deliberately no literal flame or universal glowing circle.
	if active:
		_draw_worker(pos + Vector2(48.0 + sin(elapsed * 2.0) * 9.0, 20.0), false)
	else:
		draw_line(pos + Vector2(-28, 44), pos + Vector2(28, 44), Color("4d493e", 0.78), 6.0)
		_draw_worker(pos + Vector2(48.0, 31.0 + sin(elapsed * 1.2) * 3.0), false)


func _draw_worker(position: Vector2, mentor: bool) -> void:
	var texture := mentor_bee_texture if mentor else colony_bee_texture
	if texture == null:
		draw_circle(position, 8.0, Color("e2bc49"))
		return
	draw_set_transform(position, sin(elapsed * 2.3 + position.x) * 0.12, Vector2(0.42, 0.42))
	draw_texture_rect(texture, Rect2(-50, -42, 100, 84), false)
	draw_set_transform(Vector2.ZERO)


func _draw_flower(flower: Dictionary) -> void:
	var pos := Vector2(flower.position)
	var large := bool(flower.get("large_bloom", false))
	var texture: Texture2D = null
	if flower_state_frames.size() == 6:
		var row := clampi(int(flower.get("visual_variant", 0)), 0, 1)
		var column := 0
		if bool(flower.get("seed_setting", false)) or bool(flower.get("pollinated", false)):
			column = 2
		elif bool(flower.get("receptive_stigma", false)):
			column = 1
		texture = flower_state_frames[row * 3 + column]
	var alive := int(flower.get("nectar", 0)) > 0 or bool(flower.get("receptive_stigma", false))
	var alpha := 1.0 if alive else 0.42
	draw_set_transform(pos, 0.0, Vector2(1.0, 0.34))
	draw_circle(Vector2.ZERO, 23.0 if large else 17.0, Color("26352a", 0.20 * alpha))
	draw_set_transform(Vector2.ZERO)
	if texture != null:
		var height := 104.0 if large else 82.0
		var ratio := float(texture.get_width()) / maxf(1.0, float(texture.get_height()))
		var size := Vector2(height * ratio, height)
		draw_texture_rect(texture, Rect2(pos - Vector2(size.x * 0.5, size.y * 0.42), size), false, Color(1, 1, 1, alpha))
	else:
		draw_circle(pos, 18.0 if large else 13.0, Color("eaa5b6", alpha))
	if int(flower.get("nectar", 0)) > 0:
		for drop_index in mini(3, int(flower.nectar)):
			var drop := pos + Vector2(float(drop_index - 1) * 11.0, -50.0)
			draw_circle(drop, 3.2, Color("f5d46c", 0.84))


func _draw_navigation() -> void:
	if bee == null:
		return
	if bee.sense_time > 0.0:
		draw_dashed_line(bee.position, HIVE_RETURN_POS, Color("f8dfa1", 0.46), 3.0, 18.0)
		if not relay_hive.active:
			draw_dashed_line(bee.position, RELAY_POSITION, Color("d8c58d", 0.34), 2.0, 16.0)


func _draw_story_intro() -> void:
	if not story_intro_active:
		return
	if story_intro_phase == "mentor_demonstration":
		var donor_position := Vector2(flowers[0].position)
		var receptive_position := Vector2(flowers[4].position)
		draw_dashed_line(donor_position, receptive_position, Color("f7e2a6", 0.62), 3.0, 18.0)
		var route_ratio := clampf(
			(story_intro_elapsed - STORY_PETAL_END) / (STORY_DEMO_END - STORY_PETAL_END),
			0.0,
			1.0
		)
		var pollen_position := donor_position.lerp(receptive_position, clampf(route_ratio + 0.08, 0.0, 1.0))
		draw_circle(pollen_position + Vector2(0, -22), 5.0, Color("f5cf54"))
	_draw_story_mentor(mentor_story_position)


func _draw_story_mentor(position: Vector2) -> void:
	if mentor_bee_texture != null:
		draw_set_transform(position, -0.12)
		draw_texture_rect(mentor_bee_texture, Rect2(-58, -48, 116, 96), false)
		draw_set_transform(Vector2.ZERO)
		return
	draw_set_transform(position, -0.12)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-10, -6), Vector2(-31, -27), Vector2(2, -23)
	]), Color("d4e0db", 0.78))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-10, 6), Vector2(-31, 27), Vector2(2, 23)
	]), Color("d4e0db", 0.78))
	draw_circle(Vector2(-8, 0), 17.0, Color("c99f3f"))
	draw_circle(Vector2(14, 0), 12.0, Color("806a3d"))
	draw_line(Vector2(-19, -9), Vector2(-19, 9), Color("51442f"), 4.0)
	draw_set_transform(Vector2.ZERO)
