class_name JourneySeasonalFieldBase
extends Node2D

## Shared camera, input and world-memory foundation for the three later seasons
## and the final hand-off. Each chapter remains its own PackedScene and owns its
## actual rules; this base only keeps large-map navigation and settlement signals
## consistent with the spring journey.

signal status_changed(snapshot: Dictionary)
signal journey_completed(payload: Dictionary)

const BeePlayerScript := preload("res://scripts/player/bee_player.gd")
const SoundFeedbackScript := preload("res://scripts/sound_feedback.gd")
const VIEWPORT_SIZE := Vector2(1280.0, 720.0)
const HUD_SAFE_RECT := Rect2(0.0, 90.0, 1018.0, 630.0)
const BEE_VISUAL_SAFE_EXTENTS := Vector2(51.0, 51.0)

var journey_token := 0
var starting_reserve := 0
var sortie_count := 0
var world_results: Dictionary = {}
var segment_id := ""
var chapter_name := "花田"
var world_bounds := Rect2(0.0, 0.0, 2140.0, 1180.0)
var playable_bounds := Rect2(33.0, 123.0, 1812.0, 1024.0)
var home_position := Vector2(235.0, 455.0)
var home_area := Rect2(135.0, 355.0, 190.0, 150.0)
var ground_color := Color("a9c985")
var path_color := Color("e5d3a0")
var accent_color := Color("dfb84d")
var background_texture_path := ""
var background_texture: Texture2D
var main_hive_texture: Texture2D
var worker_bee_texture: Texture2D
var seasonal_work_props_texture: Texture2D
var bee: BeePlayer
var sound: SoundFeedback
var camera: Camera2D
var input_enabled := true
var _action_release_gate := false
var completion_emitted := false
var elapsed := 0.0
var message := ""
var _status_clock := 0.0


func configure(context: Dictionary) -> Error:
	journey_token = int(context.get("journey_token", 0))
	starting_reserve = maxi(0, int(context.get("reserve", 0)))
	sortie_count = maxi(0, int(context.get("sortie_count", 0)))
	world_results = Dictionary(context.get("world_results", {})).duplicate(true)
	sound = context.get("sound_feedback") as SoundFeedback
	if journey_token <= 0:
		return ERR_INVALID_DATA
	return OK


func _ready() -> void:
	_configure_chapter()
	if not background_texture_path.is_empty() and ResourceLoader.exists(background_texture_path):
		background_texture = ResourceLoader.load(background_texture_path, "Texture2D") as Texture2D
	var main_hive_path := "res://assets/art/commercial/main_hive_exterior_v1.png"
	if ResourceLoader.exists(main_hive_path):
		main_hive_texture = ResourceLoader.load(main_hive_path, "Texture2D") as Texture2D
	var worker_bee_path := "res://assets/art/commercial/worker_bee_topdown_v1.png"
	if ResourceLoader.exists(worker_bee_path):
		worker_bee_texture = ResourceLoader.load(worker_bee_path, "Texture2D") as Texture2D
	var work_props_path := "res://assets/art/commercial/seasonal_work_props_v1.png"
	if ResourceLoader.exists(work_props_path):
		seasonal_work_props_texture = ResourceLoader.load(work_props_path, "Texture2D") as Texture2D
	if sound == null:
		sound = SoundFeedbackScript.new()
		add_child(sound)
	bee = BeePlayerScript.new()
	bee.max_energy = 120.0
	bee.configure(0.82)
	bee.set_movement_bounds(playable_bounds)
	bee.reset_for_expedition(home_position + Vector2(92.0, 0.0))
	add_child(bee)
	bee.sense_started.connect(_on_bee_sense_started)
	bee.set_spring_launch_art(true)

	camera = Camera2D.new()
	camera.name = "SeasonCamera"
	camera.position_smoothing_enabled = false
	camera.limit_left = int(world_bounds.position.x)
	camera.limit_top = int(world_bounds.position.y)
	camera.limit_right = int(world_bounds.end.x)
	camera.limit_bottom = int(world_bounds.end.y)
	add_child(camera)
	camera.make_current()
	_build_chapter()
	_update_camera()
	_emit_status()
	queue_redraw()


func _configure_chapter() -> void:
	pass


func _build_chapter() -> void:
	pass


func _process_chapter(_delta: float) -> void:
	pass


func _handle_primary_action() -> void:
	pass


func _handle_secondary_action() -> void:
	bee.set_move_target(home_position)
	message = "回家的方向记住了。"


func _draw_chapter() -> void:
	pass


func _process(delta: float) -> void:
	elapsed += maxf(0.0, delta)
	_status_clock -= delta
	if bee == null:
		return
	if completion_emitted or not input_enabled:
		bee.active = false
		_update_camera()
		queue_redraw()
		return
	bee.active = true
	# Space / gamepad A is both the field action and GUI accept. If a visible
	# button owns focus, Godot will emit that button once; polling the same frame
	# used to dispatch a second world action (or even a different action when the
	# secondary button was focused).
	var focused_control := get_viewport().gui_get_focus_owner()
	var gui_button_handles_accept := focused_control is BaseButton and (focused_control as BaseButton).is_visible_in_tree()
	if _action_release_gate:
		if not Input.is_action_pressed("action"):
			_action_release_gate = false
	elif Input.is_action_just_pressed("action") and not gui_button_handles_accept:
		_handle_primary_action()
	if Input.is_action_just_pressed("return_hive"):
		_handle_secondary_action()
	_process_chapter(delta)
	_update_camera()
	if _status_clock <= 0.0:
		_status_clock = 0.08
		_emit_status()
	queue_redraw()


func set_input_enabled(enabled: bool) -> void:
	input_enabled = enabled
	if enabled and Input.is_action_pressed("action"):
		_action_release_gate = true
	if bee == null:
		return
	bee.active = enabled and not completion_emitted
	if not enabled:
		bee.velocity = Vector2.ZERO
		bee.has_target = false


func request_primary_action() -> void:
	if input_enabled and not completion_emitted:
		_handle_primary_action()


func request_secondary_action() -> void:
	if input_enabled and not completion_emitted:
		_handle_secondary_action()


func _complete_journey(payload: Dictionary) -> void:
	if completion_emitted:
		return
	completion_emitted = true
	bee.active = false
	payload["journey_kind"] = segment_id
	payload["journey_token"] = journey_token
	journey_completed.emit(payload.duplicate(true))


func _on_bee_sense_started() -> void:
	if sound != null:
		sound.play_cue("sense")


func resume_after_failed_transition() -> void:
	completion_emitted = false
	message = "巢门刚才正忙，再停稳一次就好。"
	set_input_enabled(true)
	_emit_status()


func _update_camera() -> void:
	if camera == null or bee == null:
		return
	camera.position = camera_target_for(bee.position)


func camera_target_for(world_position: Vector2) -> Vector2:
	var half := VIEWPORT_SIZE * 0.5
	return Vector2(
		clampf(world_position.x, world_bounds.position.x + half.x, world_bounds.end.x - half.x),
		clampf(world_position.y, world_bounds.position.y + half.y, world_bounds.end.y - half.y)
	)


func projected_screen_position(world_position: Vector2) -> Vector2:
	return world_position - camera_target_for(world_position) + VIEWPORT_SIZE * 0.5


func clamp_to_playable_center(world_position: Vector2) -> Vector2:
	return Vector2(
		clampf(world_position.x, playable_bounds.position.x + 18.0, playable_bounds.end.x - 18.0),
		clampf(world_position.y, playable_bounds.position.y + 18.0, playable_bounds.end.y - 18.0)
	)


func _unhandled_input(event: InputEvent) -> void:
	if completion_emitted or not input_enabled or bee == null:
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
	if world_bounds.has_point(world_position):
		bee.set_move_target(clamp_to_playable_center(world_position))
		get_viewport().set_input_as_handled()


func _nearest_point(points: Array, radius: float, resolved_key := "resolved") -> int:
	var nearest := -1
	var nearest_distance := radius
	for index in points.size():
		var point: Dictionary = points[index]
		if bool(point.get(resolved_key, false)):
			continue
		var distance := bee.position.distance_to(Vector2(point.get("position", Vector2.ZERO)))
		if distance < nearest_distance:
			nearest = index
			nearest_distance = distance
	return nearest


func _base_snapshot() -> Dictionary:
	return {
		"journey_kind": segment_id,
		"area": chapter_name,
		"energy": bee.energy if bee != null else 0.0,
		"energy_cap": bee.max_energy if bee != null else 120.0,
		"reserve": starting_reserve,
		"message": message,
	}


func status_snapshot() -> Dictionary:
	return _base_snapshot()


func _emit_status() -> void:
	status_changed.emit(status_snapshot())


func _draw() -> void:
	_draw_background()
	_draw_home()
	_draw_world_memory()
	_draw_chapter()


func _draw_background() -> void:
	if background_texture != null:
		draw_texture_rect(background_texture, world_bounds, false)
	else:
		draw_rect(world_bounds, ground_color)
		# Broad, low-noise value patches make the fallback map readable at camera
		# scale without pretending the procedural pass is final art.
		for patch_index in 18:
			var px := 180.0 + float((patch_index * 347) % int(world_bounds.size.x - 260.0))
			var py := 170.0 + float((patch_index * 193) % int(world_bounds.size.y - 240.0))
			var radius := 75.0 + float((patch_index * 29) % 85)
			draw_circle(Vector2(px, py), radius, ground_color.lightened(0.035 + float(patch_index % 3) * 0.018))
	# A long sheltered route and a shorter exposed route exist in every later
	# season; the chapter rules decide why each matters.
	var safe_route := PackedVector2Array([
		home_position + Vector2(70, 85),
		Vector2(world_bounds.size.x * 0.32, world_bounds.size.y * 0.72),
		Vector2(world_bounds.size.x * 0.60, world_bounds.size.y * 0.80),
		Vector2(world_bounds.size.x * 0.82, world_bounds.size.y * 0.60),
	])
	var safe_edge := path_color.darkened(0.08)
	var safe_center := path_color
	var route_width := 78.0
	var center_width := 62.0
	if background_texture != null:
		safe_edge.a = 0.16
		safe_center.a = 0.12
		route_width = 34.0
		center_width = 22.0
	draw_polyline(safe_route, safe_edge, route_width, true)
	draw_polyline(safe_route, safe_center, center_width, true)
	var exposed_color := accent_color.lightened(0.25)
	if background_texture != null:
		exposed_color.a = 0.42
	draw_dashed_line(
		home_position + Vector2(100, -60),
		Vector2(world_bounds.size.x * 0.83, world_bounds.size.y * 0.35),
		exposed_color,
		4.0,
		28.0
	)


func _draw_home() -> void:
	# A low, eaved communal workhouse. Its porch and workers, rather than a magic
	# aura, communicate the dependable bonfire-like feeling of coming home.
	var p := home_position
	if main_hive_texture != null:
		draw_texture_rect(main_hive_texture, Rect2(p + Vector2(-195, -340), Vector2(330, 412)), false)
		draw_rect(Rect2(p + Vector2(-165, 66), Vector2(330, 24)), Color("d0ae70", 0.72))
		for worker_index in 3:
			var textured_worker_pos := p + Vector2(88.0 + float(worker_index) * 32.0, 52.0 + sin(elapsed * 2.0 + worker_index) * 7.0)
			_draw_worker_bee(textured_worker_pos, 0.58)
		return
	draw_colored_polygon(PackedVector2Array([
		p + Vector2(-150, -80), p + Vector2(-105, -135),
		p + Vector2(105, -135), p + Vector2(155, -80),
	]), Color("806342"))
	draw_rect(Rect2(p + Vector2(-130, -78), Vector2(260, 150)), Color("b58b55"))
	draw_rect(Rect2(p + Vector2(-40, -20), Vector2(80, 92)), Color("554335"))
	draw_rect(Rect2(p + Vector2(-165, 66), Vector2(330, 24)), Color("d0ae70"))
	for worker_index in 3:
		var worker_pos := p + Vector2(88.0 + float(worker_index) * 32.0, 52.0 + sin(elapsed * 2.0 + worker_index) * 7.0)
		_draw_worker_bee(worker_pos, 0.58)


func _draw_world_memory() -> void:
	var base := home_position + Vector2(-145, 120)
	var spring_count := int(world_results.get("spring_signs_resolved", 0))
	var seed_count := int(world_results.get("autumn_seeded", 0))
	var wall_count := int(world_results.get("winter_windbreak_segments", 0))
	if seasonal_work_props_texture != null:
		if spring_count > 0 or seed_count > 0:
			_draw_work_prop(3, Rect2(base + Vector2(-38, -72), Vector2(132, 124)))
		if bool(world_results.get("summer_rest_hive_repaired", false)):
			_draw_work_prop(0, Rect2(base + Vector2(100, -68), Vector2(142, 120)))
		if wall_count > 0:
			_draw_work_prop(2, Rect2(base + Vector2(257, -63), Vector2(146, 116)))
		return
	for sign_index in mini(3, spring_count):
		var sign_pos := base + Vector2(float(sign_index) * 38.0, 0)
		draw_line(sign_pos, sign_pos + Vector2(0, 42), Color("68513b"), 5.0)
		draw_colored_polygon(PackedVector2Array([
			sign_pos + Vector2(-15, -9), sign_pos + Vector2(0, -16),
			sign_pos + Vector2(15, -8), sign_pos + Vector2(12, 10),
			sign_pos + Vector2(-12, 10),
		]), Color("d9ad58"))
		draw_circle(sign_pos + Vector2(0, -2), 5.0, Color("7e9a5e"))
		draw_line(sign_pos + Vector2(-8, -4), sign_pos + Vector2(8, 3), Color("f4df9b", 0.72), 1.5)
	if bool(world_results.get("summer_rest_hive_repaired", false)):
		var rest_pos := base + Vector2(140, 18)
		draw_colored_polygon(PackedVector2Array([
			rest_pos + Vector2(-32, -10), rest_pos + Vector2(-18, -27),
			rest_pos + Vector2(19, -27), rest_pos + Vector2(33, -9),
		]), Color("6d5138"))
		draw_colored_polygon(PackedVector2Array([
			rest_pos + Vector2(-27, -8), rest_pos + Vector2(27, -8),
			rest_pos + Vector2(23, 18), rest_pos + Vector2(-24, 18),
		]), Color("b58a50"))
		draw_circle(rest_pos + Vector2(0, 5), 7.0, Color("4b3c31"))
		for patch_index in 3:
			draw_line(
				rest_pos + Vector2(-20.0 + float(patch_index) * 19.0, -21),
				rest_pos + Vector2(-15.0 + float(patch_index) * 19.0, -10),
				Color("e0bd6f"),
				2.0
			)
	for seed_index in mini(5, seed_count):
		var seed_pos := base + Vector2(205.0 + float(seed_index) * 24.0, 24.0)
		draw_line(seed_pos, seed_pos + Vector2(0, -28), Color("657347"), 3.0)
		for burr_index in 5:
			var burr_angle := float(burr_index) / 5.0 * TAU
			draw_line(
				seed_pos + Vector2(0, -32),
				seed_pos + Vector2(0, -32) + Vector2.from_angle(burr_angle) * 10.0,
				Color("9a7745"),
				2.0
			)
		draw_circle(seed_pos + Vector2(0, -32), 6.0, Color("c29a58"))
	for wall_index in wall_count:
		var wall_pos := base + Vector2(350.0 + float(wall_index) * 34.0, 8.0)
		draw_line(wall_pos + Vector2(-17, 10), wall_pos + Vector2(17, -10), Color("65452f"), 12.0)
		draw_line(wall_pos + Vector2(-15, 6), wall_pos + Vector2(15, -12), Color("a77b4d"), 3.0)
		draw_arc(wall_pos, 9.0, -0.4, 1.2, 8, Color("d5b36c"), 2.5)


func _draw_work_prop(frame: int, destination: Rect2, modulate := Color.WHITE) -> void:
	if seasonal_work_props_texture == null:
		return
	# The generated atlas leaves generous transparent breathing room and its
	# silhouettes cross nominal quarter guides. Explicit source windows keep the
	# shelter and wall intact instead of slicing them at 25% boundaries.
	var source_rect := Rect2(0.0, 0.0, 325.0, 362.0)
	match frame:
		1:
			source_rect = Rect2(335.0, 0.0, 185.0, 362.0)
		2:
			source_rect = Rect2(500.0, 0.0, 330.0, 362.0)
		3:
			source_rect = Rect2(820.0, 0.0, 266.0, 362.0)
	draw_texture_rect_region(
		seasonal_work_props_texture,
		destination,
		source_rect,
		modulate
	)


func _draw_worker_bee(position: Vector2, scale := 1.0) -> void:
	draw_set_transform(position, sin(elapsed * 2.4 + position.x) * 0.12, Vector2(scale, scale))
	if worker_bee_texture != null:
		draw_texture_rect(worker_bee_texture, Rect2(-38.0, -38.0, 76.0, 76.0), false)
		draw_set_transform(Vector2.ZERO)
		return
	draw_colored_polygon(PackedVector2Array([
		Vector2(-5, -5), Vector2(-18, -16), Vector2(-3, -19), Vector2(5, -8),
	]), Color("e7eee4", 0.82))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-5, 5), Vector2(-18, 16), Vector2(-3, 19), Vector2(5, 8),
	]), Color("e7eee4", 0.82))
	draw_circle(Vector2(0, 0), 10.0, Color("e1b748"))
	draw_circle(Vector2(12, 0), 7.0, Color("6f5632"))
	draw_line(Vector2(-5, -8), Vector2(-5, 8), Color("44382d"), 4.0)
	draw_set_transform(Vector2.ZERO)
