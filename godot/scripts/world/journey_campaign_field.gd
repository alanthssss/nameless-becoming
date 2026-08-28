class_name JourneyCampaignField
extends JourneySeasonalFieldBase

## Shared large-map runtime for the twenty-four authored levels. The catalog
## supplies goals and prose; this scene turns each work type into a concrete,
## multi-step interaction and gives every intra-season map a different route.

signal attempt_failed(reason: String, snapshot: Dictionary)
signal event_checkpoint_reached(checkpoint: Dictionary)

const EvadeInputControllerScript := preload("res://scripts/player/evade_input_controller.gd")
const EventMatrixRuntimeScript := preload("res://scripts/world/journey_event_matrix_runtime.gd")
const UI_FONT := preload("res://fonts/NotoSansCJKsc-ProjectSubset.otf")
const CARGO_CAPACITY := 4
const INTERACTION_RADIUS := 92.0
const OBSERVE_SECONDS := 1.15
const CLIMAX_INTERMISSION := 1.8
const CAMPAIGN_ENERGY_CAP := 100.0
const CAMPAIGN_ENERGY_TUTORIAL_VERSION := 1
const CAMPAIGN_ENERGY_TUTORIAL_TEXT := (
	"普通飞行不耗体力；急转、逆风和重载会耗，形状放错最多扣 2。"
	+ "低于 30 时停稳可回到 30，叶子休息点可回满。"
)
## Campaign stamina is a local exertion budget, not permission to move.  Normal
## travel—including the automatic cruise-speed transition—is free because the
## player never explicitly asked to sprint.  Only visible wind, heavy cargo,
## urgent turns and mistakes spend the meter.
const CAMPAIGN_DASH_DRAIN_PER_SECOND := 0.0
const CAMPAIGN_DASH_DELAY := 1.0
const CAMPAIGN_EVADE_COST := 6.0
const CAMPAIGN_REST_RECOVERY_PER_SECOND := 18.0
const CAMPAIGN_BREATHER_DELAY := 0.75
const CAMPAIGN_BREATHER_RECOVERY_PER_SECOND := 6.0
const CAMPAIGN_BREATHER_CAP := 30.0
const CAMPAIGN_WIND_DRAIN_PER_SECOND := 0.8
const CAMPAIGN_CLIMAX_WIND_DRAIN_PER_SECOND := 1.2
const CAMPAIGN_HEAVY_DRAIN_PER_SECOND := 0.35
const CAMPAIGN_FATIGUED_SPEED_SCALE := 0.82
const TASK_MARKER_SAFE_EXTENT := 64.0
# This rectangle remains a world-layout budget and a startup fallback. Once the
# host has built the HUD, visibility is decided from its live Control rectangles.
const CAMPAIGN_HUD_SAFE_RECT := Rect2(0.0, 90.0, 1008.0, 630.0)
const CAMPAIGN_OBJECTIVE_OCCLUSION_RECT := Rect2(18.0, 104.0, 620.0, 118.0)
const EVENT_EDGE_GUIDE_EXTENT := 34.0
const EVENT_EDGE_GUIDE_HIT_RADIUS := 48.0
const EVENT_INTERACTION_RADIUS := 112.0
const EVENT_ANCHOR_HITS := 2
const EVENT_HEAVY_SPEED_SCALE := 0.78
const EVENT_HEAVY_ACCELERATION_SCALE := 0.65
const EVENT_HEAVY_DASH_COST_SCALE := 1.25
const EVENT_HEAVY_WIND_COST_SCALE := 1.25
const EVENT_RHYTHM_PERIOD := 1.55
const EVENT_RHYTHM_OPEN_SECONDS := 0.58
const EVENT_WRONG_MATCH_ENERGY_COST := 2.0
const OPTIONAL_SUPPORT_LABELS := {
	"route_fixture": "沿路固定件",
	"bloom_help": "花路补位",
	"handoff_rhythm": "交接节拍",
	"leaf_shelter": "叶棚歇脚点",
	"route_mastery": "熟练路线记录",
	"weather_read": "天气复读提示",
	"inventory_order": "牌架整理顺序",
	"spare_sign": "备用花牌",
	"storm_support": "风雨近桩支援",
	"neighbour_help": "邻居现场帮手",
}
const SEASON_BACKGROUNDS := {
	"spring": "res://assets/art/commercial/spring_world_ground_v1.png",
	"summer": "res://assets/art/commercial/summer_world_ground_v1.png",
	"autumn": "res://assets/art/commercial/autumn_world_ground_v1.png",
	"winter": "res://assets/art/commercial/winter_world_ground_v1.png",
}
const FLOWER_STATES_PATH := "res://assets/art/commercial/flower_states_topdown_v1.png"
const SEED_SHELL_STATES_PATH := "res://assets/art/commercial/listening_seed_shell_states_v1.png"
const CLIMAX_NEIGHBOUR_PATHS := {
	"spring": "res://assets/art/commercial/mosquito_keeper_states_v1.png",
	"summer": "res://assets/art/commercial/oil_cricket_repairer_states_v2.png",
	"autumn": "res://assets/art/commercial/thrush_neighbor_states_v3.png",
	"winter": "res://assets/art/commercial/bear_helper_states_v1.png",
}
const CLIMAX_DISPLAY_NAMES := {
	"spring": "蚊庄主的花牌大乱",
	"summer": "油葫芦的横雨抢修",
	"autumn": "画眉邻居的听风三回",
	"winter": "大熊的最后一墙",
}
const SEASON_COLORS := {
	"spring": [Color("a8cf91"), Color("ead9a5"), Color("e9b35f")],
	"summer": [Color("83bd75"), Color("d8c782"), Color("f0c84e")],
	"autumn": [Color("bf9b62"), Color("e2c18a"), Color("d38c4a")],
	"winter": [Color("a9c5c8"), Color("d9d8c8"), Color("e2ad58")],
}
const TWO_STEP_TYPES := ["pollinate", "carry", "seed", "warmth"]
const TYPE_COLORS := {
	"pollinate": Color("ef91ae"),
	"collect": Color("efc85c"),
	"observe": Color("82b9c8"),
	"frighten": Color("d98266"),
	"carry": Color("bb8c56"),
	"repair": Color("a67551"),
	"seed": Color("9f8751"),
	"shell": Color("c29b63"),
	"warmth": Color("edaa48"),
	"anchor": Color("718c78"),
}

var level: Dictionary = {}
var run_mode := "progression"
var level_id := ""
var season_id := "spring"
var map_variant := 0
var is_climax := false
var time_limit_seconds := 600.0
var tasks: Array[Dictionary] = []
var objective_counts: Array[int] = []
var objective_goals: Array[int] = []
var current_phase := 0
var phases_completed := 0
var phase_intermission := 0.0
var carried_task_index := -1
var collected_cargo := 0
var delivered_cargo := 0
var focus_task_index := -1
var focus_time := 0.0
var action_count := 0
var weather_window_elapsed := 0.0
var failed := false
var hazard_active := false
var hazard_bands: Array[Rect2] = []
var shelter_areas: Array[Rect2] = []
var rest_points: Array[Vector2] = []
var task_positions: Array[Vector2] = []
var _phase_transition_announced := false
var flower_states_texture: Texture2D
var seed_shell_states_texture: Texture2D
var climax_neighbour_texture: Texture2D
var evade_input_controller = EvadeInputControllerScript.new()
var resting := false
var breather_elapsed := 0.0
var was_fatigued := false
var energy_state := ""
var energy_rule_taught := false
var recovery_rule_taught := false
var energy_feedback_hold := 0.0
var tutorial_overlay_message := ""
var tutorial_overlay_hold := 0.0
var energy_rule_commit_pending := false
var recovery_rule_commit_pending := false
var touch_input_mode := false
var event_matrix_mode := false
var event_runtime: JourneyEventMatrixRuntime
var event_points: Array[Vector2] = []
var event_source_position := Vector2.ZERO
var event_dynamic_position := Vector2.ZERO
var event_carrying := false
var event_observing := false
var event_observe_time := 0.0
var event_anchor_hits := 0
var event_world_marks: Array[Dictionary] = []
var event_match_sources: Array[Vector2] = []
var event_carried_shape := -1
var event_last_pentad := 1
var joy_direction_down := {"left": false, "right": false, "up": false, "down": false}
var event_checkpoint_data: Dictionary = {}
var hud_occlusion_rects: Array[Rect2] = [
	Rect2(18.0, 14.0, 1244.0, 76.0),
	CAMPAIGN_OBJECTIVE_OCCLUSION_RECT,
	Rect2(616.0, 108.0, 44.0, 44.0),
	Rect2(1018.0, 514.0, 244.0, 188.0),
	Rect2(18.0, 672.0, 850.0, 30.0),
]


func configure(context: Dictionary) -> Error:
	var configured_level = context.get("level", {})
	if not configured_level is Dictionary or String(configured_level.get("id", "")).is_empty():
		return ERR_INVALID_DATA
	level = (configured_level as Dictionary).duplicate(true)
	run_mode = String(context.get("run_mode", "progression"))
	var raw_checkpoint = context.get("event_checkpoint", {})
	if not raw_checkpoint is Dictionary:
		return ERR_INVALID_DATA
	event_checkpoint_data = (raw_checkpoint as Dictionary).duplicate(true)
	var tutorial_version := maxi(
		0,
		int(context.get("campaign_energy_tutorial_version", 0))
	)
	energy_rule_taught = tutorial_version >= CAMPAIGN_ENERGY_TUTORIAL_VERSION
	recovery_rule_taught = tutorial_version >= CAMPAIGN_ENERGY_TUTORIAL_VERSION
	return super.configure(context)


func _ready() -> void:
	super._ready()
	_load_campaign_art()
	evade_input_controller.clear(bee)
	if bee != null:
		# Campaign energy is a readable 0–100 exertion loop: reading and ordinary
		# travel are free, explicit urgent turns and visible pressure spend energy,
		# stopping restores a small action reserve, and marked rest points refill it.
		bee.max_energy = CAMPAIGN_ENERGY_CAP
		bee.energy = bee.max_energy
		# The catalog's legacy energy_drain values belong to the retired prototype
		# cruise model.  Do not multiply them by a magic zero: configure the campaign
		# contract explicitly so a later balance edit cannot silently revive passive
		# travel drain across all twenty-four chapters.
		bee.configure(0.0)
		bee.configure_energy_usage(
			false,
			CAMPAIGN_DASH_DRAIN_PER_SECOND,
			CAMPAIGN_DASH_DELAY,
			false
		)
		bee.evade_energy_cost = CAMPAIGN_EVADE_COST
		bee.dash_cost_multiplier = 1.0
		if not event_checkpoint_data.is_empty():
			# Old v3 checkpoints could legally store zero before the recovery rule
			# existed.  Preserve all normal values exactly, but give an exhausted old
			# checkpoint the same bounded action reserve as stopping to catch breath.
			var restored_energy := clampf(
				float(event_checkpoint_data.get("energy", bee.max_energy)),
				0.0,
				bee.max_energy
			)
			bee.energy = (
				CAMPAIGN_BREATHER_CAP
				if restored_energy == 0.0
				else restored_energy
			)
			elapsed = maxf(0.0, float(event_checkpoint_data.get("elapsed_seconds", 0.0)))
			action_count = maxi(0, int(event_checkpoint_data.get("actions", 0)))
			message = "从第%d候继续。前面的花标还亮着，下一件就在眼前。" % (
				int(event_checkpoint_data.get("pentads_completed", 0)) + 1
			)
	_emit_status()
	queue_redraw()


func _hud_safe_world_right(visual_extent: float) -> float:
	# At the right camera limit, the hidden screen strip maps directly to an
	# equally wide world strip. Reserve it before placing either movement centers
	# or task art, and include the caller's visible radius.
	var hud_strip_width := VIEWPORT_SIZE.x - CAMPAIGN_HUD_SAFE_RECT.end.x
	return world_bounds.end.x - hud_strip_width - maxf(0.0, visual_extent)


func set_hud_occlusion_rects(next_rects: Array[Rect2]) -> void:
	# Layout belongs to the host. The field consumes only controls that are really
	# visible, clipped to the fixed game viewport.
	var sanitized: Array[Rect2] = []
	for raw_rect in next_rects:
		var rect := raw_rect.abs()
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			continue
		var clipped := rect.intersection(Rect2(Vector2.ZERO, VIEWPORT_SIZE))
		if clipped.size.x > 0.0 and clipped.size.y > 0.0:
			sanitized.append(clipped)
	hud_occlusion_rects = sanitized
	queue_redraw()


func _screen_bounds_fully_visible(screen_bounds: Rect2) -> bool:
	var normalized_bounds := screen_bounds.abs()
	if not Rect2(Vector2.ZERO, VIEWPORT_SIZE).encloses(normalized_bounds):
		return false
	for occlusion in hud_occlusion_rects:
		if normalized_bounds.intersects(occlusion):
			return false
	return true


func _world_visual_fully_visible(world_position: Vector2, local_bounds: Rect2) -> bool:
	var screen_position := _event_marker_screen_position(world_position)
	return _screen_bounds_fully_visible(
		Rect2(screen_position + local_bounds.position, local_bounds.size)
	)


func _guide_point_is_clear(point: Vector2, visual_extent: float) -> bool:
	for occlusion in hud_occlusion_rects:
		if occlusion.grow(visual_extent).has_point(point):
			return false
	return true


func event_marker_draw_position(world_position: Vector2, visual_extent := EVENT_EDGE_GUIDE_EXTENT) -> Vector2:
	# Full art remains at its real world coordinate. Only the small edge guide may
	# move, choosing the nearest viewport point clear of every live HUD rectangle.
	var camera_position := (
		camera.position
		if camera != null
		else camera_target_for(bee.position if bee != null else world_position)
	)
	var desired := world_position - camera_position + VIEWPORT_SIZE * 0.5
	var extent := maxf(0.0, visual_extent)
	var inner := Rect2(
		Vector2(extent, extent),
		Vector2(
			maxf(1.0, VIEWPORT_SIZE.x - extent * 2.0),
			maxf(1.0, VIEWPORT_SIZE.y - extent * 2.0)
		)
	)
	var clamped := Vector2(
		clampf(desired.x, inner.position.x, inner.end.x),
		clampf(desired.y, inner.position.y, inner.end.y)
	)
	var candidate_xs: Array[float] = [clamped.x, inner.position.x, inner.end.x]
	var candidate_ys: Array[float] = [clamped.y, inner.position.y, inner.end.y]
	for occlusion in hud_occlusion_rects:
		var guard := occlusion.grow(extent + 1.0)
		candidate_xs.append(clampf(guard.position.x - 1.0, inner.position.x, inner.end.x))
		candidate_xs.append(clampf(guard.end.x + 1.0, inner.position.x, inner.end.x))
		candidate_ys.append(clampf(guard.position.y - 1.0, inner.position.y, inner.end.y))
		candidate_ys.append(clampf(guard.end.y + 1.0, inner.position.y, inner.end.y))
	var best := clamped
	var best_distance := INF
	for candidate_x in candidate_xs:
		for candidate_y in candidate_ys:
			var candidate := Vector2(candidate_x, candidate_y)
			if not _guide_point_is_clear(candidate, extent):
				continue
			var distance := candidate.distance_squared_to(desired)
			if distance < best_distance:
				best = candidate
				best_distance = distance
	return camera_position - VIEWPORT_SIZE * 0.5 + best


func _event_marker_screen_position(world_position: Vector2) -> Vector2:
	var camera_position := (
		camera.position
		if camera != null
		else camera_target_for(bee.position if bee != null else world_position)
	)
	return world_position - camera_position + VIEWPORT_SIZE * 0.5


func _event_marker_full_visible(world_position: Vector2, local_bounds: Rect2) -> bool:
	# Compatibility name used by the existing event helpers and focused tests.
	return _world_visual_fully_visible(world_position, local_bounds)


func _current_event_visual_bounds() -> Rect2:
	if event_runtime == null or event_runtime.is_finished():
		return Rect2(-72.0, -72.0, 144.0, 144.0)
	var bounds := Rect2(-72.0, -72.0, 144.0, 144.0)
	match event_runtime.current_kind():
		JourneyEventMatrixRuntime.KIND_ROUTE:
			if event_runtime.requires_rhythm():
				bounds = Rect2(-80.0, -96.0, 160.0, 176.0)
			elif event_runtime.requires_evade():
				bounds = Rect2(-78.0, -78.0, 156.0, 156.0)
		JourneyEventMatrixRuntime.KIND_COOP_ANCHOR:
			bounds = (
				Rect2(-80.0, -72.0, 160.0, 144.0)
				if event_runtime.current_mechanic() == "spatial_match"
				else Rect2(-72.0, -72.0, 162.0, 144.0)
			)
		JourneyEventMatrixRuntime.KIND_ROUTE_CHOICE:
			bounds = Rect2(-160.0, -84.0, 232.0, 168.0)
		JourneyEventMatrixRuntime.KIND_CONVOY:
			bounds = Rect2(-78.0, -78.0, 156.0, 156.0)
	if event_runtime.requires_rhythm() or _convoy_stage_requires_rhythm():
		bounds = bounds.merge(Rect2(-80.0, -96.0, 160.0, 176.0))
	if event_runtime.optional_pending():
		bounds = bounds.merge(Rect2(-72.0, -72.0, 144.0, 144.0))
	return bounds


func _navigation_marker_visual_bounds() -> Rect2:
	if event_runtime == null or event_runtime.is_finished():
		return Rect2(-72.0, -72.0, 144.0, 144.0)
	var kind := event_runtime.current_kind()
	if kind == JourneyEventMatrixRuntime.KIND_CARGO and not event_carrying:
		if event_runtime.current_mechanic() == "moving_match":
			return Rect2(-42.0, -42.0, 84.0, 84.0)
		var half := Vector2(37.0, 28.0) if event_runtime.uses_heavy_load() else Vector2(27.0, 20.0)
		return Rect2(-half, half * 2.0)
	if kind == JourneyEventMatrixRuntime.KIND_CONVOY and _convoy_stage_uses_cargo() and not event_carrying:
		return Rect2(-27.0, -20.0, 54.0, 40.0)
	return _current_event_visual_bounds()


func _navigation_uses_edge_guide() -> bool:
	if event_runtime == null or event_runtime.is_finished():
		return false
	return not _event_marker_full_visible(
		_event_navigation_target(),
		_navigation_marker_visual_bounds()
	)


func event_edge_guide_screen_position(world_position: Vector2) -> Vector2:
	return _event_marker_screen_position(
		event_marker_draw_position(world_position, EVENT_EDGE_GUIDE_EXTENT)
	)


func _handle_event_edge_guide_press(screen_position: Vector2) -> bool:
	if not _navigation_uses_edge_guide():
		return false
	var navigation_target := _event_navigation_target()
	var guide_position := event_edge_guide_screen_position(navigation_target)
	if screen_position.distance_to(guide_position) > EVENT_EDGE_GUIDE_HIT_RADIUS:
		return false
	bee.set_move_target(navigation_target)
	bee.trigger_sense()
	message = "沿边缘指引飞过去；到达附近后，按空格或右下动作继续。"
	return true


func _load_campaign_art() -> void:
	if ResourceLoader.exists(FLOWER_STATES_PATH):
		flower_states_texture = ResourceLoader.load(FLOWER_STATES_PATH, "Texture2D") as Texture2D
	if ResourceLoader.exists(SEED_SHELL_STATES_PATH):
		seed_shell_states_texture = ResourceLoader.load(SEED_SHELL_STATES_PATH, "Texture2D") as Texture2D
	var neighbour_path := String(CLIMAX_NEIGHBOUR_PATHS.get(season_id, ""))
	if is_climax and not neighbour_path.is_empty() and ResourceLoader.exists(neighbour_path):
		climax_neighbour_texture = ResourceLoader.load(neighbour_path, "Texture2D") as Texture2D


func _configure_chapter() -> void:
	level_id = String(level.get("id", ""))
	segment_id = level_id
	season_id = String(level.get("season_id", "spring"))
	map_variant = clampi(int(level.get("map_variant", 0)), 0, 5)
	is_climax = String(level.get("kind", "standard")) == "climax"
	time_limit_seconds = maxf(60.0, float(level.get("time_limit_seconds", 600)))
	chapter_name = "%02d · %s · %s" % [
		int(level.get("number", int(level.get("order", 0)) + 1)),
		String(level.get("term_name", "节气")),
		String(CLIMAX_DISPLAY_NAMES.get(season_id, "季节大忙")) if is_climax else String(level.get("chronicle_title", "花田小事")),
	]
	# The source paintings are 2140×1180. A 3600×2000 world remains nearly three
	# screens wide and tall while avoiding the visibly soft 2.2× enlargement used
	# by the first implementation.
	world_bounds = Rect2(0.0, 0.0, 3600.0, 2000.0)
	# The right rail belongs to the persistent HUD. The bee's full silhouette, not
	# merely its center, must remain inside the unobscured viewport strip when the
	# camera reaches the world's right edge.
	var bee_safe_right := _hud_safe_world_right(BEE_VISUAL_SAFE_EXTENTS.x) + 18.0
	playable_bounds = Rect2(35.0, 125.0, bee_safe_right - 35.0, 1815.0)
	home_position = Vector2(270.0, 980.0)
	home_area = Rect2(95.0, 820.0, 350.0, 320.0)
	var colors: Array = SEASON_COLORS.get(season_id, SEASON_COLORS.spring)
	ground_color = colors[0]
	path_color = colors[1]
	accent_color = colors[2]
	background_texture_path = String(SEASON_BACKGROUNDS.get(season_id, SEASON_BACKGROUNDS.spring))
	message = String(level.get("dialogue" if is_climax else "intro", "先看清手边的活，再稳稳带回巢门。"))


func _build_chapter() -> void:
	_build_route_variant()
	objective_counts.clear()
	objective_goals.clear()
	var objectives: Array = level.get("objectives", [])
	for objective in objectives:
		objective_counts.append(0)
		objective_goals.append(maxi(1, int((objective as Dictionary).get("goal", 1))))
	var matrix: Array = level.get("event_matrix", [])
	if not matrix.is_empty():
		_build_event_matrix(matrix)
	elif is_climax:
		_build_climax_tasks()
	else:
		_build_standard_tasks()


func _build_event_matrix(matrix: Array) -> void:
	event_runtime = EventMatrixRuntimeScript.new()
	event_matrix_mode = event_runtime.configure(matrix) == OK
	if not event_matrix_mode:
		push_error("%s 的三候内容矩阵无法建立运行时" % level_id)
		return
	tasks.clear()
	event_world_marks.clear()
	if not event_checkpoint_data.is_empty():
		var runtime_checkpoint := _runtime_checkpoint_payload(event_checkpoint_data)
		if event_runtime.restore_checkpoint(runtime_checkpoint) != OK:
			push_error("%s 的候级检查点无法恢复；本次从第一候安全开始" % level_id)
			event_checkpoint_data.clear()
		else:
			_rebuild_event_world_marks()
			phases_completed = event_runtime.pentads_completed() if is_climax else 0
	event_last_pentad = event_runtime.current_pentad()
	_prepare_current_event()


func _runtime_checkpoint_payload(source: Dictionary) -> Dictionary:
	var payload := {}
	for key in [
		"next_event_number", "pentads_completed", "completed_mandatory_ids",
		"completed_optional_ids", "skipped_optional_ids", "route_choices",
		"support_points", "world_state",
	]:
		if source.has(key):
			payload[key] = source[key]
	return payload.duplicate(true)


func _rebuild_event_world_marks() -> void:
	if event_runtime == null:
		return
	var completed_lookup := {}
	for event_id in event_runtime.completed_event_ids:
		completed_lookup[String(event_id)] = true
	var route_choices: Dictionary = event_runtime.world_state.get("route_choices", {})
	var outcomes: Dictionary = event_runtime.world_state.get("event_outcomes", {})
	for index in event_runtime.current_index:
		var event := event_runtime.events[index] as Dictionary
		var event_id := String(event.get("id", ""))
		if not completed_lookup.has(event_id):
			continue
		var restored_position := _restored_event_mark_position(event, String(route_choices.get(event_id, "")))
		event_world_marks.append({
			"position": restored_position,
			"kind": String(event.get("runtime_kind", "observation")),
			"mechanic": String(event.get("mechanic", "")),
			"optional": bool(event.get("optional", false)),
			"pentad": int(event.get("pentad", 1)),
			"choice": String(route_choices.get(event_id, "")),
			"choice_effect": String((outcomes.get(event_id, {}) as Dictionary).get("choice_effect", "")),
		})
		if String(event.get("mechanic", "")) == "escort_shelter":
			_append_event_rest_point(restored_position)


func _restored_event_mark_position(event: Dictionary, choice: String) -> Vector2:
	if task_positions.is_empty():
		return home_position
	var required := maxi(1, int(event.get("steps_required", 1)))
	var mechanic := String(event.get("mechanic", ""))
	var choice_options := event.get("choice_options", {}) as Dictionary
	if choice in ["swift", "steady"] and choice_options.has(choice):
		required = maxi(
			1,
			int((choice_options.get(choice, {}) as Dictionary).get("steps", required))
		)
	if (
		String(event.get("id", "")) == "guyu_12_air_chase"
		and event_runtime != null
		and int(
			(event_runtime.world_state.get("support_effects", {}) as Dictionary).get(
				"spare_sign",
				0
			)
		) > 0
	):
		required = maxi(1, required - 1)
	var base_index := (int(event.get("order", 1)) * 3 + map_variant * 5) % task_positions.size()
	var final_step := required - 1
	if (
		choice == "steady"
		and (
			mechanic in ["sequence_carry", "spatial_match", "convoy_anchor"]
			or String(event.get("id", "")) == "guyu_12_air_chase"
		)
	):
		# These routes are genuinely traversed in reverse. Their persistent mark
		# belongs at the point the player actually finished, not at the un-reversed
		# array's last element.
		final_step = 0
	var position_index := (
		base_index + final_step * 5 + int(event.get("pentad", 1)) * 2
	) % task_positions.size()
	return task_positions[position_index]


func _append_rest_point_unique(position: Vector2) -> bool:
	for existing in rest_points:
		if existing.distance_to(position) <= 1.0:
			return false
	rest_points.append(position)
	return true


func _append_event_rest_point(position: Vector2) -> bool:
	# Event rewards must add a real new recovery option. Some authored event
	# landmarks deliberately share a task coordinate with an existing leaf rest;
	# in that case place the new grass-stem rest beside the landmark instead of
	# silently turning the promised world change into a no-op.
	if _append_rest_point_unique(position):
		return true
	for offset in [
		Vector2(142.0, -88.0), Vector2(-142.0, -88.0),
		Vector2(142.0, 88.0), Vector2(-142.0, 88.0),
	]:
		var candidate := Vector2(
			clampf(
				position.x + offset.x,
				playable_bounds.position.x + TASK_MARKER_SAFE_EXTENT,
				_hud_safe_world_right(TASK_MARKER_SAFE_EXTENT)
			),
			clampf(
				position.y + offset.y,
				playable_bounds.position.y + TASK_MARKER_SAFE_EXTENT,
				playable_bounds.end.y - TASK_MARKER_SAFE_EXTENT
			)
		)
		if _append_rest_point_unique(candidate):
			return true
	return false


func _prepare_current_event() -> void:
	event_points.clear()
	event_match_sources.clear()
	event_carrying = false
	event_carried_shape = -1
	event_observing = false
	event_observe_time = 0.0
	event_anchor_hits = 0
	if bee != null:
		bee.has_target = false
		bee.velocity = Vector2.ZERO
		bee.set_load_movement_profile()
	if event_runtime == null or event_runtime.is_finished():
		phases_completed = 3 if is_climax else 0
		bee.set_visual_load_ratio(0.0)
		message = "三候的活儿都收好了。沿亮起来的花路回主巢交接。"
		return
	var event := event_runtime.current_event()
	var order := int(event.get("order", 1))
	var required := event_runtime.current_required_steps()
	var base_index := (order * 3 + map_variant * 5) % task_positions.size()
	for step in required:
		var position_index := (base_index + step * 5 + int(event.get("pentad", 1)) * 2) % task_positions.size()
		event_points.append(task_positions[position_index])
	event_source_position = task_positions[(base_index + 11) % task_positions.size()]
	if event_runtime.current_mechanic() == "moving_match":
		var source_offsets: Array[Vector2] = [
			Vector2(-142.0, 54.0), Vector2(0.0, -86.0), Vector2(142.0, 54.0),
		]
		for offset in source_offsets:
			var source: Vector2 = event_source_position + offset
			source.x = clampf(
				source.x,
				playable_bounds.position.x + TASK_MARKER_SAFE_EXTENT,
				_hud_safe_world_right(TASK_MARKER_SAFE_EXTENT)
			)
			source.y = clampf(
				source.y,
				playable_bounds.position.y + TASK_MARKER_SAFE_EXTENT,
				playable_bounds.end.y - TASK_MARKER_SAFE_EXTENT
			)
			event_match_sources.append(source)
	event_dynamic_position = _current_event_point()
	var pentad := event_runtime.current_pentad()
	if pentad != event_last_pentad:
		event_last_pentad = pentad
		message = "第%d候开始啦。%s · %s" % [pentad, String(event.get("title", "花田小事")), String(event.get("ui_hint", "看看现场"))]
	else:
		message = "%s · %s" % [String(event.get("title", "花田小事")), String(event.get("ui_hint", "看看现场"))]
	bee.set_visual_load_ratio(0.0)


func _current_event_point() -> Vector2:
	if event_points.is_empty() or event_runtime == null:
		return home_position
	return event_points[mini(event_points.size() - 1, event_runtime.current_progress)]


func _current_event_id() -> String:
	if event_runtime == null or event_runtime.is_finished():
		return ""
	return String(event_runtime.current_event().get("id", ""))


func _moving_match_sequence() -> Array[int]:
	var sequence: Array[int] = [2, 0, 1]
	if event_runtime == null:
		return sequence
	var effects := event_runtime.world_state.get("support_effects", {}) as Dictionary
	if int(effects.get("inventory_order", 0)) <= 0:
		return sequence
	var outcomes := event_runtime.world_state.get("event_outcomes", {}) as Dictionary
	var inventory_outcome := outcomes.get("guyu_03_keeper_inventory", {}) as Dictionary
	match String(inventory_outcome.get("choice_effect", "")):
		"shape_first": sequence = [0, 1, 2]
		"route_first": sequence = [2, 1, 0]
	return sequence


func _moving_match_required_shape() -> int:
	var sequence := _moving_match_sequence()
	if sequence.is_empty() or event_runtime == null:
		return 0
	return sequence[event_runtime.current_progress % sequence.size()]


func _moving_match_source_position(shape_index: int) -> Vector2:
	if event_match_sources.is_empty():
		return event_source_position
	return event_match_sources[clampi(shape_index, 0, event_match_sources.size() - 1)]


func _nearest_event_match_source() -> int:
	var nearest := -1
	var nearest_distance := EVENT_INTERACTION_RADIUS
	for shape_index in event_match_sources.size():
		var distance := bee.position.distance_to(event_match_sources[shape_index])
		if distance < nearest_distance:
			nearest = shape_index
			nearest_distance = distance
	return nearest


func _event_shape_name(shape_index: int) -> String:
	match shape_index % 3:
		0: return "三角牌"
		1: return "方牌"
		_: return "圆牌"


func _build_route_variant() -> void:
	task_positions.clear()
	# Six stable topologies per season. Reordering the same readable landmarks
	# preserves the art language while changing actual travel and weather lanes.
	var grid: Array[Vector2] = []
	for row in 4:
		for column in 6:
			grid.append(Vector2(650.0 + column * 525.0, 330.0 + row * 455.0))
	for index in grid.size():
		var source_index := (index * (5 if map_variant % 2 == 0 else 7) + map_variant * 3) % grid.size()
		var point := grid[source_index]
		point.x += sin(float(index + map_variant) * 1.7) * 95.0
		point.y += cos(float(index * 2 + map_variant)) * 80.0
		point.x = clampf(
			point.x,
			playable_bounds.position.x + TASK_MARKER_SAFE_EXTENT,
			_hud_safe_world_right(TASK_MARKER_SAFE_EXTENT)
		)
		point.y = clampf(
			point.y,
			playable_bounds.position.y + TASK_MARKER_SAFE_EXTENT,
			playable_bounds.end.y - TASK_MARKER_SAFE_EXTENT
		)
		task_positions.append(point)
	hazard_bands.clear()
	shelter_areas.clear()
	rest_points.clear()
	if map_variant % 3 == 0:
		hazard_bands = [Rect2(950, 125, 320, 1540), Rect2(2320, 390, 360, 1480)]
	elif map_variant % 3 == 1:
		hazard_bands = [Rect2(650, 650, 2300, 280), Rect2(1120, 1390, 2150, 300)]
	else:
		hazard_bands = [Rect2(760, 250, 300, 1500), Rect2(1760, 320, 330, 1390), Rect2(2820, 220, 300, 1530)]
	for shelter_index in 4:
		var source := task_positions[(shelter_index * 5 + map_variant * 2) % task_positions.size()]
		var shelter := Rect2(source - Vector2(175, 115), Vector2(350, 230))
		shelter_areas.append(shelter)
		rest_points.append(shelter.get_center())


func _build_standard_tasks() -> void:
	tasks.clear()
	var cursor := 0
	var objectives: Array = level.get("objectives", [])
	for objective_index in objectives.size():
		var objective := objectives[objective_index] as Dictionary
		var work_type := String(objective.get("type", "observe"))
		var goal := int(objective_goals[objective_index])
		for unit_index in goal:
			var destination := task_positions[cursor % task_positions.size()]
			var source := task_positions[(cursor + 9 + map_variant) % task_positions.size()]
			tasks.append(_task(objective_index, unit_index, work_type, source, destination, -1))
			cursor += 1


func _build_climax_tasks() -> void:
	tasks.clear()
	var phase_types := _climax_phase_types()
	var cursor := 0
	for phase_index in 3:
		var types: Array = phase_types[phase_index]
		for unit_index in types.size():
			var destination := task_positions[(cursor * 2 + phase_index * 3) % task_positions.size()]
			var source := task_positions[(cursor * 2 + 11 + map_variant) % task_positions.size()]
			tasks.append(_task(0, unit_index, String(types[unit_index]), source, destination, phase_index))
			cursor += 1


func _climax_phase_types() -> Array:
	match season_id:
		"spring": return [["observe", "carry", "carry"], ["observe", "frighten", "observe"], ["repair", "carry", "anchor"]]
		"summer": return [["observe", "observe", "observe"], ["carry", "carry", "carry"], ["anchor", "anchor", "anchor"]]
		"autumn": return [["observe", "observe", "observe"], ["collect", "seed", "seed"], ["carry", "carry", "carry"]]
		_: return [["warmth", "observe", "anchor"], ["anchor", "anchor", "anchor"], ["repair", "repair", "repair"]]


func _task(
	objective_index: int,
	unit_index: int,
	work_type: String,
	source: Vector2,
	destination: Vector2,
	phase_index: int
) -> Dictionary:
	return {
		"objective_index": objective_index,
		"unit_index": unit_index,
		"type": work_type,
		"source_position": source,
		"position": destination,
		"origin": destination,
		"phase_index": phase_index,
		"state": 0,
		"hits": 0,
		"resolved": false,
		"credited": work_type != "collect",
	}


func _process_chapter(delta: float) -> void:
	if failed:
		return
	tutorial_overlay_hold = maxf(0.0, tutorial_overlay_hold - maxf(0.0, delta))
	if tutorial_overlay_hold <= 0.0:
		tutorial_overlay_message = ""
	energy_feedback_hold = maxf(0.0, energy_feedback_hold - maxf(0.0, delta))
	weather_window_elapsed += maxf(0.0, delta)
	if weather_window_elapsed >= time_limit_seconds:
		_fail_attempt("这趟的天气窗口合上了。回巢理一理路线，再飞一次就好。")
		return
	hazard_active = fmod(elapsed + float(map_variant) * 0.73, 8.5) < (2.2 if not is_climax else 3.1)
	var sheltered := _is_sheltered(bee.position)
	var moving := bee.velocity.length() > 28.0
	var discrete_energy_feedback_held := (
		energy_feedback_hold > 0.0 and not energy_state.is_empty()
	)
	if not discrete_energy_feedback_held:
		energy_state = ""
	var event_hazard_scale := event_runtime.hazard_scale() if event_matrix_mode and event_runtime != null else 1.0
	var heavy_load_ratio := _campaign_heavy_load_ratio()
	var heavy_wind_scale := lerpf(1.0, EVENT_HEAVY_WIND_COST_SCALE, heavy_load_ratio)
	if hazard_active and _in_hazard_band(bee.position) and not sheltered:
		var raw_speed_multiplier := 0.70 if not is_climax else 0.61
		bee.environment_speed_multiplier = lerpf(1.0, raw_speed_multiplier, event_hazard_scale)
		if moving:
			bee.energy = maxf(
				0.0,
				bee.energy - delta * (
					CAMPAIGN_WIND_DRAIN_PER_SECOND
					if not is_climax
					else CAMPAIGN_CLIMAX_WIND_DRAIN_PER_SECOND
				) * event_hazard_scale * heavy_wind_scale
			)
			if not discrete_energy_feedback_held:
				energy_state = "逆风"
	else:
		bee.environment_speed_multiplier = 1.0
	if heavy_load_ratio > 0.0 and moving:
		bee.energy = maxf(
			0.0,
			bee.energy - CAMPAIGN_HEAVY_DRAIN_PER_SECOND * heavy_load_ratio * delta
		)
		if not discrete_energy_feedback_held:
			energy_state = "逆风＋重载" if energy_state == "逆风" else "重载"
	_teach_energy_cost_if_needed()
	_update_campaign_recovery(delta)
	var fatigued := bee.energy <= 0.01
	if fatigued:
		bee.environment_speed_multiplier = minf(
			bee.environment_speed_multiplier,
			CAMPAIGN_FATIGUED_SPEED_SCALE
		)
		if not was_fatigued and energy_feedback_hold <= 0.0:
			message = "翅膀累了，但基础飞行和主线动作仍可用；停稳片刻会回到 30。"
	was_fatigued = fatigued
	if event_matrix_mode:
		_process_event_matrix(delta)
		return
	_update_moving_tasks()
	_update_observation(delta)
	if phase_intermission > 0.0:
		phase_intermission = maxf(0.0, phase_intermission - delta)
		if phase_intermission <= 0.0:
			_phase_transition_announced = false
			message = _current_phase_instruction()
	if home_area.has_point(bee.position):
		_deposit_collected_cargo()
		if _all_work_complete() and carried_task_index < 0 and phase_intermission <= 0.0:
			_finish_level()
	elif _all_work_complete() and carried_task_index < 0:
		message = "活儿收好了。沿花标回主巢，接货蜂正在门边等你。"


func _campaign_heavy_load_ratio() -> float:
	if (
		event_matrix_mode
		and event_runtime != null
		and event_carrying
		and event_runtime.uses_heavy_load()
	):
		return 1.0
	if String(level.get("scenario_id", "")) == "heavy_pouch":
		return clampf(float(collected_cargo) / float(CARGO_CAPACITY), 0.0, 1.0)
	return 0.0


func _apply_standard_load_profile() -> void:
	if bee == null:
		return
	var ratio := (
		clampf(float(collected_cargo) / float(CARGO_CAPACITY), 0.0, 1.0)
		if String(level.get("scenario_id", "")) == "heavy_pouch"
		else 0.0
	)
	bee.set_visual_load_ratio(float(collected_cargo) / float(CARGO_CAPACITY))
	bee.set_load_movement_profile(
		lerpf(1.0, EVENT_HEAVY_SPEED_SCALE, ratio),
		lerpf(1.0, EVENT_HEAVY_ACCELERATION_SCALE, ratio),
		lerpf(1.0, EVENT_HEAVY_DASH_COST_SCALE, ratio)
	)


func _teach_energy_cost_if_needed() -> void:
	if (
		energy_rule_taught
		or energy_rule_commit_pending
		or energy_state.is_empty()
	):
		return
	_queue_energy_tutorial()


func _queue_energy_tutorial() -> void:
	if (
		(energy_rule_taught and recovery_rule_taught)
		or (energy_rule_commit_pending and recovery_rule_commit_pending)
	):
		return
	tutorial_overlay_message = CAMPAIGN_ENERGY_TUTORIAL_TEXT
	tutorial_overlay_hold = 4.8
	energy_rule_commit_pending = true
	recovery_rule_commit_pending = true


func _clear_tutorial_overlay() -> void:
	tutorial_overlay_message = ""
	tutorial_overlay_hold = 0.0
	energy_rule_commit_pending = false
	recovery_rule_commit_pending = false


func _base_snapshot() -> Dictionary:
	var snapshot := super._base_snapshot()
	var tutorial_delivering := (
		tutorial_overlay_hold > 0.0
		and not tutorial_overlay_message.is_empty()
		and not failed
		and not completion_emitted
	)
	if tutorial_delivering:
		snapshot["message"] = tutorial_overlay_message
	snapshot["energy_rule_taught"] = energy_rule_taught
	snapshot["recovery_rule_taught"] = recovery_rule_taught
	snapshot["energy_tutorial_delivery_version"] = (
		CAMPAIGN_ENERGY_TUTORIAL_VERSION
		if tutorial_delivering and energy_rule_taught and recovery_rule_taught
		else 0
	)
	snapshot["energy_tutorial_delivery_text"] = (
		tutorial_overlay_message if tutorial_delivering else ""
	)
	return snapshot


func _emit_status() -> void:
	# Product help memory advances only on the exact status emission that carries
	# the rule. Event progress may rewrite `message` in the same frame, but the
	# overlay keeps the actually delivered snapshot authoritative.
	if energy_rule_commit_pending:
		energy_rule_taught = true
	if recovery_rule_commit_pending:
		recovery_rule_taught = true
	super._emit_status()
	energy_rule_commit_pending = false
	recovery_rule_commit_pending = false


func _update_campaign_recovery(delta: float) -> void:
	resting = false
	var stopped_for_rest := bee.velocity.length() <= 28.0 and bee.evade_time <= 0.0
	for rest_point in rest_points:
		if bee.position.distance_to(rest_point) <= 105.0 and stopped_for_rest:
			resting = true
			bee.energy = minf(bee.max_energy, bee.energy + CAMPAIGN_REST_RECOVERY_PER_SECOND * delta)
			if energy_feedback_hold <= 0.0:
				energy_state = "休息点 · 快速回满"
			break
	if resting:
		breather_elapsed = 0.0
		if (
			not recovery_rule_taught
			and not recovery_rule_commit_pending
			and energy_feedback_hold <= 0.0
		):
			_queue_energy_tutorial()
		return
	var can_catch_breath := (
		bee.velocity.length() <= 28.0
		and bee.evade_time <= 0.0
	)
	if not can_catch_breath:
		breather_elapsed = 0.0
		return
	var previous_elapsed := breather_elapsed
	breather_elapsed += maxf(0.0, delta)
	var recovery_seconds := (
		maxf(0.0, breather_elapsed - CAMPAIGN_BREATHER_DELAY)
		- maxf(0.0, previous_elapsed - CAMPAIGN_BREATHER_DELAY)
	)
	if recovery_seconds > 0.0 and bee.energy < CAMPAIGN_BREATHER_CAP:
		bee.energy = minf(
			CAMPAIGN_BREATHER_CAP,
			bee.energy + CAMPAIGN_BREATHER_RECOVERY_PER_SECOND * recovery_seconds
		)
		if energy_feedback_hold <= 0.0:
			energy_state = "停稳回气"
		if (
			not recovery_rule_taught
			and not recovery_rule_commit_pending
			and energy_feedback_hold <= 0.0
		):
			_queue_energy_tutorial()


func _process_event_matrix(delta: float) -> void:
	if event_runtime == null:
		return
	if event_runtime.is_finished():
		if home_area.has_point(bee.position):
			_finish_level()
		elif not completion_emitted:
			message = "三候都收好啦。沿已经亮起的路线回主巢交接。"
		return
	var current_point := _current_event_point()
	if event_runtime.has_moving_target() and (
		not event_carrying
		or event_runtime.current_mechanic() in ["moving_match", "moving_shelter"]
	):
		var movement_seed := float(event_runtime.current_index) * 0.73
		event_dynamic_position = current_point + Vector2(
			sin(elapsed * 1.65 + movement_seed) * 125.0,
			cos(elapsed * 1.23 + movement_seed) * 78.0
		)
		event_dynamic_position.x = clampf(
			event_dynamic_position.x,
			playable_bounds.position.x + TASK_MARKER_SAFE_EXTENT,
			_hud_safe_world_right(TASK_MARKER_SAFE_EXTENT)
		)
		event_dynamic_position.y = clampf(
			event_dynamic_position.y,
			playable_bounds.position.y + TASK_MARKER_SAFE_EXTENT,
			playable_bounds.end.y - TASK_MARKER_SAFE_EXTENT
		)
	else:
		event_dynamic_position = current_point
	if not event_observing:
		return
	if event_runtime.requires_weather_window() and hazard_active:
		event_observe_time = maxf(0.0, event_observe_time - delta * 0.8)
		message = "雨线还压在叶面上。看它收窄，再把这次观察接完整。"
		return
	if (
		bee.position.distance_to(current_point) > EVENT_INTERACTION_RADIUS
		or bee.velocity.length() > 55.0
	):
		event_observe_time = maxf(0.0, event_observe_time - delta * 1.7)
		message = "风把线索拨乱了一点；回到光圈里停稳就能接着看。"
		return
	event_observe_time += delta
	message = "把雨影和叶响对起来…… %d%%" % roundi(clampf(event_observe_time / OBSERVE_SECONDS, 0.0, 1.0) * 100.0)
	if event_observe_time >= OBSERVE_SECONDS:
		event_observing = false
		event_observe_time = 0.0
		_advance_event_step(JourneyEventMatrixRuntime.KIND_OBSERVATION)


func _update_moving_tasks() -> void:
	for index in tasks.size():
		var task := tasks[index]
		if bool(task.resolved) or not _task_is_active(task) or String(task.type) != "frighten":
			continue
		var origin := Vector2(task.origin)
		var moving_position := origin + Vector2(sin(elapsed * 1.45 + index) * 135.0, cos(elapsed * 1.1 + index) * 88.0)
		moving_position.x = clampf(
			moving_position.x,
			playable_bounds.position.x + TASK_MARKER_SAFE_EXTENT,
			_hud_safe_world_right(TASK_MARKER_SAFE_EXTENT)
		)
		moving_position.y = clampf(
			moving_position.y,
			playable_bounds.position.y + TASK_MARKER_SAFE_EXTENT,
			playable_bounds.end.y - TASK_MARKER_SAFE_EXTENT
		)
		task.position = moving_position
		tasks[index] = task


func _update_observation(delta: float) -> void:
	if focus_task_index < 0 or focus_task_index >= tasks.size():
		return
	var task := tasks[focus_task_index]
	if bool(task.resolved) or not _task_is_active(task):
		focus_task_index = -1
		focus_time = 0.0
		return
	if bee.position.distance_to(Vector2(task.position)) > INTERACTION_RADIUS or bee.velocity.length() > 55.0:
		focus_time = maxf(0.0, focus_time - delta * 2.0)
		return
	focus_time += delta
	message = "停翅看清楚…… %d%%" % roundi(clampf(focus_time / OBSERVE_SECONDS, 0.0, 1.0) * 100.0)
	if focus_time >= OBSERVE_SECONDS:
		_resolve_task(focus_task_index, "看清了，下一处提示和这条路对得上。", "sense")
		focus_task_index = -1
		focus_time = 0.0


func _handle_primary_action() -> void:
	if phase_intermission > 0.0 or failed:
		return
	action_count += 1
	if event_matrix_mode:
		_handle_event_primary_action()
		return
	if focus_task_index >= 0:
		# The HUD disables the action while a timed observation is in progress.
		# Keyboard/gamepad input must obey the same modal contract as the button;
		# otherwise Space can advance a different nearby job behind the observation.
		bee.has_target = false
		message = "正在观察。继续停稳，不用重复按键。"
		return
	if carried_task_index >= 0:
		var carried_task := tasks[carried_task_index]
		if bee.position.distance_to(Vector2(carried_task.position)) <= INTERACTION_RADIUS:
			_resolve_task(carried_task_index, _delivery_message(String(carried_task.type)), _cue_for_type(String(carried_task.type)))
			carried_task_index = -1
			_apply_standard_load_profile()
			if is_climax and _active_phase_tasks_complete() and collected_cargo == 0:
				_complete_current_phase()
		else:
			bee.set_move_target(Vector2(carried_task.position))
			bee.trigger_sense()
			message = "这件还在身上。已经标出对应工位，沿亮路送过去。"
		return
	if collected_cargo >= CARGO_CAPACITY:
		bee.set_move_target(home_position)
		bee.trigger_sense()
		message = "蜜囊已经装满。沿亮路回主巢卸货，再继续这一项。"
		return
	var source_index := _nearest_source_task()
	if source_index >= 0:
		_pick_up_task(source_index)
		return
	var target_index := _nearest_target_task()
	if target_index < 0:
		if collected_cargo > 0:
			bee.set_move_target(home_position)
			bee.trigger_sense()
			message = "这一批已经收齐。把蜜囊送回主巢，接货蜂会逐份接走。"
			return
		bee.trigger_sense()
		message = "附近没有正等着处理的活。波纹会指出当前路线。"
		return
	var task := tasks[target_index]
	match String(task.type):
		"observe":
			if focus_task_index == target_index:
				message = "正在观察。继续停稳，不用重复按键。"
				return
			focus_task_index = target_index
			focus_time = 0.0
			bee.has_target = false
			message = "在提示旁停翅一会儿，等风和声音自己排清楚。"
		"collect":
			if collected_cargo >= CARGO_CAPACITY:
				message = "蜜囊装了 %d 份。先送回主巢，空出位置再来。" % collected_cargo
			else:
				collected_cargo += 1
				_resolve_task(target_index, "收好一份，蜜囊 %d / %d。" % [collected_cargo, CARGO_CAPACITY], "harvest")
				_apply_standard_load_profile()
		"repair", "shell", "anchor":
			_step_task(target_index)
		"frighten":
			_resolve_task(target_index, "震翼声一到，它松开手里的东西，去旁边草茎歇着了。", "evade")
		_:
			_resolve_task(target_index, "这一处收好了。", _cue_for_type(String(task.type)))


func _handle_event_primary_action() -> void:
	if event_runtime == null or event_runtime.is_finished():
		bee.set_move_target(home_position)
		message = "花路已经收齐，回主巢完成最后交接。"
		return
	if event_runtime.optional_pending():
		if not event_runtime.accept_optional():
			return
		message = _event_acceptance_message()
		if sound != null:
			sound.play_cue("relay")
		return
	if event_runtime.choice_pending():
		_select_event_route("swift")
		return
	var kind := event_runtime.current_kind()
	var target := _event_interaction_target()
	match kind:
		JourneyEventMatrixRuntime.KIND_OBSERVATION:
			if event_observing:
				message = "正在观察。继续停稳，不用重复按键。"
				return
			if bee.position.distance_to(target) > EVENT_INTERACTION_RADIUS:
				_point_to_event_target("先飞进黄色圆圈，再停下来观察。")
				return
			if event_runtime.requires_weather_window() and hazard_active:
				message = "横雨还在经过。等它停一下，再在圆圈里停稳观察。"
				bee.trigger_sense()
				return
			event_observing = true
			event_observe_time = 0.0
			bee.has_target = false
			message = "停稳一会儿，看看雨影、叶响和地面反光。"
		JourneyEventMatrixRuntime.KIND_ROUTE:
			if bee.position.distance_to(target) > EVENT_INTERACTION_RADIUS:
				_point_to_event_target("先飞进下一个黄色圆圈。")
				return
			if event_runtime.requires_rhythm() and not _event_rhythm_window_open():
				message = "等黄色圆圈亮起来，再按空格穿过去。"
				return
			if event_runtime.requires_evade():
				_attempt_event_evade()
				return
			var route_result := event_runtime.record_step(kind)
			_handle_event_step_result(route_result, target)
		JourneyEventMatrixRuntime.KIND_CARGO:
			_handle_event_cargo(target)
		JourneyEventMatrixRuntime.KIND_AIR_CATCH:
			_handle_event_air_catch(target)
		JourneyEventMatrixRuntime.KIND_COOP_ANCHOR:
			_handle_event_anchor(target)
		JourneyEventMatrixRuntime.KIND_ROUTE_CHOICE:
			if bee.position.distance_to(target) > EVENT_INTERACTION_RADIUS:
				_point_to_event_target("沿刚选的路线飞到下一处落脚。")
				return
			_handle_event_step_result(event_runtime.record_step(kind), target)
		JourneyEventMatrixRuntime.KIND_CONVOY:
			_handle_event_convoy(target)


func _event_acceptance_message() -> String:
	if event_runtime == null or event_runtime.is_finished():
		return "这件自选小事已经不在当前路线里。"
	var mechanic := event_runtime.current_mechanic()
	var reward := float(
		JourneyEventMatrixRuntime.OPTIONAL_ENERGY_REWARDS.get(mechanic, 4.0)
	)
	var support_effect := String(
		JourneyEventMatrixRuntime.OPTIONAL_SUPPORT_EFFECTS.get(mechanic, "neighbour_help")
	)
	var support_label := String(
		OPTIONAL_SUPPORT_LABELS.get(support_effect, OPTIONAL_SUPPORT_LABELS["neighbour_help"])
	)
	var exit_instruction := (
		"先用空格／Q 选路线；选好后仍可按 Q 放下。"
		if event_runtime.choice_pending()
		else "途中可按 Q 放下。"
	)
	return (
		"接下这件自选小事。现场支援：%s；完成后体力恢复 %s 点。%s"
		% [support_label, _format_energy_amount(reward), exit_instruction]
	)


func _format_energy_amount(value: float) -> String:
	return str(roundi(value)) if is_equal_approx(value, float(roundi(value))) else "%.1f" % value


func _handle_event_cargo(target: Vector2) -> void:
	if event_runtime.current_mechanic() == "moving_match":
		_handle_event_moving_match(target)
		return
	if not event_carrying:
		if bee.position.distance_to(event_source_position) > EVENT_INTERACTION_RADIUS:
			bee.set_move_target(event_source_position)
			message = "先到发亮的接货点，把这一件真正托起来。"
			return
		event_carrying = true
		var heavy := event_runtime.uses_heavy_load()
		bee.set_visual_load_ratio(0.88 if heavy else 0.60)
		if heavy:
			bee.set_load_movement_profile(
				EVENT_HEAVY_SPEED_SCALE,
				EVENT_HEAVY_ACCELERATION_SCALE,
				EVENT_HEAVY_DASH_COST_SCALE
			)
			message = "宽牌真的压住了转向。提早收弯，不要急切横风，把它送稳。"
		else:
			bee.set_load_movement_profile()
			message = "接稳了。负载会拖住一点视线，把它送到对应工位。"
		if sound != null:
			sound.play_cue("relay")
		return
	if bee.position.distance_to(target) > EVENT_INTERACTION_RADIUS:
		bee.set_move_target(target)
		message = "还在身上呢；沿同色边光送到接货蜂那边。"
		return
	if event_runtime.requires_rhythm() and not _event_rhythm_window_open():
		message = "接货蜂还没空出手。等它举起前足的拍点，再把载荷递过去。"
		return
	event_carrying = false
	bee.set_visual_load_ratio(0.0)
	bee.set_load_movement_profile()
	_handle_event_step_result(event_runtime.record_step(JourneyEventMatrixRuntime.KIND_CARGO), target)


func _handle_event_moving_match(target: Vector2) -> void:
	var required_shape := _moving_match_required_shape()
	if not event_carrying:
		var source_index := _nearest_event_match_source()
		if source_index < 0:
			bee.set_move_target(_moving_match_source_position(required_shape))
			bee.trigger_sense()
			message = "移动工位亮着%s。先从三块牌里认出同形的一块。" % _event_shape_name(required_shape)
			return
		if source_index != required_shape:
			var energy_before := bee.energy
			bee.energy = maxf(0.0, bee.energy - EVENT_WRONG_MATCH_ENERGY_COST)
			var actual_cost := energy_before - bee.energy
			if actual_cost > 0.0:
				energy_state = "误配 -%s" % _format_energy_amount(actual_cost)
				message = "这块是%s，工位要的是%s。放回去再看一眼；体力 -%s。" % [
					_event_shape_name(source_index),
					_event_shape_name(required_shape),
					_format_energy_amount(actual_cost),
				]
			else:
				energy_state = "误配 · 未再扣体力"
				message = "这块是%s，工位要的是%s。体力已经见底，这次不再扣；放回去再看一眼。" % [
					_event_shape_name(source_index),
					_event_shape_name(required_shape),
				]
			energy_feedback_hold = 1.4
			_teach_energy_cost_if_needed()
			bee.trigger_sense()
			if sound != null:
				sound.play_cue("sense")
			return
		event_carrying = true
		event_carried_shape = source_index
		bee.set_visual_load_ratio(0.52)
		message = "%s接对了。工位还在移动，跟上它再交接。" % _event_shape_name(source_index)
		if sound != null:
			sound.play_cue("relay")
		return
	if bee.position.distance_to(target) > EVENT_INTERACTION_RADIUS:
		bee.set_move_target(target)
		message = "牌还托着呢；看亮边追上移动工位。"
		return
	event_carrying = false
	event_carried_shape = -1
	bee.set_visual_load_ratio(0.0)
	_handle_event_step_result(event_runtime.record_step(JourneyEventMatrixRuntime.KIND_CARGO), target)


func _handle_event_convoy(target: Vector2) -> void:
	if _convoy_stage_uses_cargo() and not event_carrying:
		if bee.position.distance_to(event_source_position) > EVENT_INTERACTION_RADIUS:
			bee.set_move_target(event_source_position)
			bee.trigger_sense()
			message = "蜂流先慢下来啦。到发亮的叶托接住这份花粉，再带回队首。"
			return
		event_carrying = true
		bee.set_visual_load_ratio(0.62)
		message = "花粉托稳了。带回前方亮牌，后面的蜂会照着你的弯跟上。"
		if sound != null:
			sound.play_cue("relay")
		return
	if bee.position.distance_to(target) > EVENT_INTERACTION_RADIUS:
		_point_to_event_target(
			"带着花粉回到队首。" if event_carrying else "蜂流正在身后等着；飞到下一枚亮起的花牌。"
		)
		return
	if _convoy_stage_requires_rhythm() and not _event_rhythm_window_open():
		message = "先听三滴，再从那一小段空拍带队穿过去。"
		return
	if _convoy_stage_requires_evade() and not event_runtime.evade_registered:
		# The visible action button and Space/A promise an urgent turn here. Execute
		# that same paid action instead of merely asking for a hidden second input;
		# _play_evade_result registers and advances the convoy stage on success.
		_attempt_event_evade()
		return
	if event_carrying:
		event_carrying = false
		bee.set_visual_load_ratio(0.0)
	if _convoy_stage_requires_evade():
		event_runtime.clear_evade()
	_handle_event_step_result(event_runtime.record_step(JourneyEventMatrixRuntime.KIND_CONVOY), target)


func _convoy_stage_uses_cargo() -> bool:
	return (
		_current_event_id() == "yushui_15_full_rain_route"
		and event_runtime.current_progress == 2
	)


func _convoy_stage_requires_rhythm() -> bool:
	return (
		_current_event_id() == "yushui_15_full_rain_route"
		and event_runtime.current_progress == 0
	)


func _convoy_stage_requires_evade() -> bool:
	if _current_event_id() == "yushui_15_full_rain_route":
		return event_runtime.current_progress == 1
	if _current_event_id() == "guyu_15_full_route":
		return event_runtime.current_progress == event_runtime.current_required_steps() - 1
	return false


func _handle_event_air_catch(target: Vector2) -> void:
	var partner_rescue := event_runtime.current_mechanic() == "partner_rescue"
	if not event_carrying:
		if bee.position.distance_to(target) > EVENT_INTERACTION_RADIUS:
			bee.set_move_target(target)
			message = (
				"从侧下追上同期新蜂，保持一点速度并飞到新蜂身边。"
				if partner_rescue
				else "看它的落势，不追图标；在移动中贴近再接。"
			)
			return
		if bee.velocity.length() < 24.0:
			message = (
				"先带一点飞行速度靠近；同期新蜂需要你陪着并飞，不是原地托起。"
				if partner_rescue
				else "它还在半空，要带一点飞行速度从侧下方接住。"
			)
			return
		event_carrying = true
		bee.set_visual_load_ratio(0.55)
		message = (
			"并飞接上啦！陪同期新蜂一起飞到前方黄色安全点。"
			if partner_rescue
			else "空中接住了！现在送到旁边亮起的临时桩。"
		)
		if sound != null:
			sound.play_cue("evade")
		return
	var delivery := _current_event_point()
	if bee.position.distance_to(delivery) > EVENT_INTERACTION_RADIUS:
		bee.set_move_target(delivery)
		message = (
			"同期新蜂正和你并飞；一起到黄色安全点的叶棚。"
			if partner_rescue
			else "接住的东西还在身上，把它送到临时桩。"
		)
		return
	event_carrying = false
	bee.set_visual_load_ratio(0.0)
	bee.set_load_movement_profile()
	_handle_event_step_result(event_runtime.record_step(JourneyEventMatrixRuntime.KIND_AIR_CATCH), delivery)


func _event_rhythm_window_open() -> bool:
	var support_effects := event_runtime.world_state.get("support_effects", {}) as Dictionary
	var assisted_window := EVENT_RHYTHM_OPEN_SECONDS + (
		0.16 if int(support_effects.get("handoff_rhythm", 0)) > 0 else 0.0
	)
	return fmod(elapsed + float(event_runtime.current_index) * 0.17, EVENT_RHYTHM_PERIOD) >= (
		EVENT_RHYTHM_PERIOD - assisted_window
	)


func _event_interaction_target() -> Vector2:
	if event_runtime == null:
		return home_position
	if event_runtime.current_mechanic() in ["moving_match", "moving_shelter"]:
		return event_dynamic_position
	if event_runtime.has_moving_target() and not event_carrying:
		return event_dynamic_position
	return _current_event_point()


func _handle_event_anchor(target: Vector2) -> void:
	if bee.position.distance_to(target) > EVENT_INTERACTION_RADIUS:
		_point_to_event_target("同伴已在桩的另一边等着，过去一起扣紧。")
		return
	event_anchor_hits += 1
	if event_anchor_hits < EVENT_ANCHOR_HITS:
		message = "这一侧压住了；同伴正扣另一边，再一起用力一次。"
		if sound != null:
			sound.play_cue("relay")
		return
	event_anchor_hits = 0
	_handle_event_step_result(event_runtime.record_step(JourneyEventMatrixRuntime.KIND_COOP_ANCHOR), target)


func _point_to_event_target(text_value: String) -> void:
	bee.set_move_target(_event_navigation_target())
	bee.trigger_sense()
	message = text_value


func _select_event_route(choice: String) -> void:
	if not event_runtime.choose_route(choice):
		return
	if choice == "steady" and event_points.size() < event_runtime.current_required_steps():
		var extra_index := (event_runtime.current_index * 7 + map_variant * 3 + 17) % task_positions.size()
		event_points.append(task_positions[extra_index])
	if (
		choice == "steady"
		and (
			event_runtime.current_mechanic() in ["sequence_carry", "spatial_match", "convoy_anchor"]
			or _current_event_id() == "guyu_12_air_chase"
		)
	):
		event_points.reverse()
	var selected_label := event_runtime.choice_label(choice)
	match event_runtime.current_mechanic():
		"load_choice":
			event_carrying = true
			if choice == "swift":
				bee.set_visual_load_ratio(0.88)
				bee.set_load_movement_profile(
					EVENT_HEAVY_SPEED_SCALE,
					EVENT_HEAVY_ACCELERATION_SCALE,
					EVENT_HEAVY_DASH_COST_SCALE
				)
				message = "选了一趟重载：只走一段，但宽弯和横风都会真的压住转向。"
			else:
				bee.set_visual_load_ratio(0.45)
				bee.set_load_movement_profile()
				message = "选了两趟轻载：多走一段，转向和停靠会更从容。"
		"support_choice":
			message = (
				"选了蜡封近路：路短、容错也短，高潮时会给近桩一次支援。"
				if choice == "swift"
				else "选了长绳宽路：多一个落脚点，之后横风压力会更轻。"
			)
		_:
			message = (
				"选了%s：步骤更紧，现场会记住这次做法。" % selected_label
				if choice == "swift"
				else "选了%s：多留一点余地，结果不会被评成对错。" % selected_label
			)
	if sound != null:
		sound.play_cue("sense")


func _advance_event_step(kind: String) -> void:
	_handle_event_step_result(event_runtime.record_step(kind), _current_event_point())


func _handle_event_step_result(result: Dictionary, completed_at: Vector2) -> void:
	if not bool(result.get("accepted", false)):
		return
	event_observing = false
	event_observe_time = 0.0
	event_anchor_hits = 0
	if not bool(result.get("event_complete", false)):
		message = "%s · %d / %d；下一处已经亮起来。" % [
			String(event_runtime.current_event().get("title", "这一段")),
			int(result.get("progress", 0)),
			int(result.get("required", 1)),
		]
		if sound != null:
			sound.play_cue("relay")
		return
	var completed_event: Dictionary = result.get("event", {})
	var event_id := String(completed_event.get("id", ""))
	var route_choices := event_runtime.world_state.get("route_choices", {}) as Dictionary
	var outcomes := event_runtime.world_state.get("event_outcomes", {}) as Dictionary
	var outcome := outcomes.get(event_id, {}) as Dictionary
	var chosen_route := String(route_choices.get(event_id, ""))
	var chosen_label := ""
	if not chosen_route.is_empty():
		var choice_options := completed_event.get("choice_options", {}) as Dictionary
		chosen_label = String((choice_options.get(chosen_route, {}) as Dictionary).get("label", ""))
	# Persist a stable event landmark rather than the instantaneous position of a
	# moving target. The same authored route endpoint is reconstructed after a
	# whole-pentad reload, so completed marks and rest rewards never jump on load.
	var mark_position := _restored_event_mark_position(completed_event, chosen_route)
	if String(completed_event.get("mechanic", "")) == "escort_shelter":
		_append_event_rest_point(mark_position)
	event_world_marks.append({
		"position": mark_position,
		"kind": String(completed_event.get("runtime_kind", "observation")),
		"mechanic": String(completed_event.get("mechanic", "")),
		"optional": bool(completed_event.get("optional", false)),
		"pentad": int(completed_event.get("pentad", 1)),
		"choice": String(route_choices.get(event_id, "")),
		"choice_effect": String(outcome.get("choice_effect", "")),
	})
	var reward := float(result.get("energy_reward", 0.0))
	var completion_summary := ""
	if reward > 0.0:
		var energy_before_reward := bee.energy
		bee.energy = minf(bee.max_energy, bee.energy + reward)
		var actual_reward := bee.energy - energy_before_reward
		energy_state = "自选奖励 +%s" % _format_energy_amount(actual_reward)
		energy_feedback_hold = 1.4
		completion_summary = "小事也收好了：体力实际恢复 %s 点。%s" % [
			_format_energy_amount(actual_reward),
			_short_event_consequence(String(completed_event.get("consequence", "")))
		]
	else:
		completion_summary = "%s：%s" % [
			String(completed_event.get("title", "这一段")),
			_short_event_consequence(String(completed_event.get("consequence", "现场留下了变化。"))),
		]
	if not chosen_label.is_empty():
		completion_summary = "采用「%s」· %s" % [chosen_label, completion_summary]
	if sound != null:
		sound.play_cue("complete")
	phases_completed = event_runtime.pentads_completed() if is_climax else 0
	_prepare_current_event()
	_emit_event_checkpoint_if_ready()
	message = "%s %s" % [completion_summary, message]


func _short_event_consequence(consequence: String) -> String:
	var clean := consequence.strip_edges()
	if clean.is_empty():
		return "现场留下了看得见的变化。"
	var sentence_end := clean.find("。")
	if sentence_end >= 0:
		clean = clean.left(sentence_end + 1)
	return clean.left(38)


func _emit_event_checkpoint_if_ready() -> void:
	if event_runtime == null or bee == null:
		return
	var checkpoint := event_runtime.checkpoint_snapshot()
	if checkpoint.is_empty():
		return
	# Five activities represent one working shift.  The colony changes shifts
	# before the next pentad, so the next block always begins with a known budget
	# instead of inheriting a nearly empty meter from an old checkpoint.
	bee.energy = bee.max_energy
	energy_state = "换班 · 体力回满"
	energy_feedback_hold = maxf(energy_feedback_hold, 1.4)
	if run_mode == "progression":
		checkpoint["level_id"] = level_id
		checkpoint["energy"] = bee.max_energy
		checkpoint["elapsed_seconds"] = maxf(0.0, elapsed)
		checkpoint["actions"] = maxi(0, action_count)
		event_checkpoint_reached.emit(checkpoint.duplicate(true))
	# A whole-pentad checkpoint is also a fresh weather sortie. Keep cumulative
	# elapsed time for result records, but never restore the player one frame away
	# from an unavoidable timeout.
	weather_window_elapsed = 0.0
	message = "%s 大家换班歇了一会儿，体力也回满了。" % message


func _nearest_source_task() -> int:
	var nearest := -1
	var nearest_distance := INTERACTION_RADIUS
	for index in tasks.size():
		var task := tasks[index]
		if not _task_is_active(task) or bool(task.resolved) or int(task.state) != 0 or String(task.type) not in TWO_STEP_TYPES:
			continue
		var distance := bee.position.distance_to(Vector2(task.source_position))
		if distance < nearest_distance:
			nearest = index
			nearest_distance = distance
	return nearest


func _nearest_target_task() -> int:
	var nearest := -1
	var nearest_distance := INTERACTION_RADIUS
	for index in tasks.size():
		var task := tasks[index]
		if not _task_is_active(task) or bool(task.resolved) or String(task.type) in TWO_STEP_TYPES:
			continue
		var distance := bee.position.distance_to(Vector2(task.position))
		if distance < nearest_distance:
			nearest = index
			nearest_distance = distance
	return nearest


func _pick_up_task(index: int) -> void:
	var task := tasks[index]
	task.state = 1
	tasks[index] = task
	carried_task_index = index
	bee.set_visual_load_ratio(0.72)
	match String(task.type):
		"pollinate": message = "取到同形散粉。沿同色花路送到发亮的柱头。"
		"warmth": message = "暖蜡接好了。绕开冷风带，送到下一处暖点。"
		"seed": message = "种核托稳了。把它送去背风花地，别切过迎风线。"
		_: message = "东西拿稳了。对应工位正发着同色边光。"
	if sound != null:
		sound.play_cue("relay")


func _step_task(index: int) -> void:
	var task := tasks[index]
	task.hits = int(task.hits) + 1
	var required := 3 if String(task.type) == "shell" else 2
	if int(task.hits) >= required:
		tasks[index] = task
		_resolve_task(index, _delivery_message(String(task.type)), _cue_for_type(String(task.type)))
		return
	tasks[index] = task
	if String(task.type) == "shell":
		message = "种壳转过一格，还要对准下一条声路（%d / %d）。" % [int(task.hits), required]
	else:
		message = "先固定一侧，再去扣紧另一侧（%d / %d）。" % [int(task.hits), required]
	if sound != null:
		sound.play_cue("relay")


func _resolve_task(index: int, resolved_message: String, cue: String) -> void:
	var task := tasks[index]
	if bool(task.resolved):
		return
	task.resolved = true
	task.state = 2
	tasks[index] = task
	# Collection only becomes campaign work after the bee physically reaches the
	# hive receiving line. This keeps “picked up” and “delivered” honest in the HUD.
	if not is_climax and String(task.type) != "collect":
		var objective_index := int(task.objective_index)
		objective_counts[objective_index] = mini(objective_goals[objective_index], objective_counts[objective_index] + 1)
	message = resolved_message
	if sound != null:
		sound.play_cue(cue)
	if is_climax and _active_phase_tasks_complete() and carried_task_index < 0 and collected_cargo == 0:
		_complete_current_phase()


func _complete_current_phase() -> void:
	if phases_completed >= 3:
		return
	phases_completed += 1
	objective_counts[0] = phases_completed
	current_phase = mini(2, phases_completed)
	phase_intermission = CLIMAX_INTERMISSION if phases_completed < 3 else 0.0
	_phase_transition_announced = true
	if phases_completed < 3:
		var phase: Dictionary = (level.get("phases", []) as Array)[phases_completed - 1]
		message = "“%s”收好啦。大家换个位置，接下一段。" % String(phase.get("label", "这一段"))
	else:
		message = "三段都接住了。沿全年花标回主巢，最后一趟也要真实交接。"
	if sound != null:
		sound.play_cue("complete")


func _task_is_active(task: Dictionary) -> bool:
	if is_climax:
		return int(task.phase_index) == phases_completed
	# Standard chapters are deliberately non-linear: every visible unfinished job
	# is a real job.  The HUD follows the player's nearest/current job instead of
	# silently disabling other markers until an arbitrary list order is complete.
	return true


func _active_objective_index() -> int:
	if is_climax or event_matrix_mode:
		return -1
	if carried_task_index >= 0 and carried_task_index < tasks.size():
		return int((tasks[carried_task_index] as Dictionary).get("objective_index", -1))
	if focus_task_index >= 0 and focus_task_index < tasks.size():
		return int((tasks[focus_task_index] as Dictionary).get("objective_index", -1))
	if collected_cargo >= CARGO_CAPACITY:
		for task in tasks:
			if String(task.get("type", "")) == "collect" and not bool(task.get("credited", false)):
				return int(task.get("objective_index", -1))
	var active_task_index := _active_standard_task_index()
	if active_task_index >= 0:
		return int((tasks[active_task_index] as Dictionary).get("objective_index", -1))
	for index in objective_goals.size():
		if objective_counts[index] < objective_goals[index]:
			return index
	return -1


func _active_standard_task_index() -> int:
	if event_matrix_mode or is_climax or bee == null:
		return -1
	if carried_task_index >= 0 and carried_task_index < tasks.size():
		return carried_task_index
	if focus_task_index >= 0 and focus_task_index < tasks.size():
		return focus_task_index
	if collected_cargo >= CARGO_CAPACITY:
		return -1
	var nearest := -1
	var nearest_distance := INF
	for index in tasks.size():
		var task := tasks[index]
		if bool(task.resolved) or not _task_is_active(task):
			continue
		var target_position := Vector2(task.position)
		if String(task.type) in TWO_STEP_TYPES and int(task.state) == 0:
			target_position = Vector2(task.source_position)
		var distance := bee.position.distance_to(target_position)
		if distance < nearest_distance:
			nearest = index
			nearest_distance = distance
	return nearest


func _active_phase_tasks_complete() -> bool:
	if not is_climax or phases_completed >= 3:
		return false
	var found := false
	for task in tasks:
		if int(task.phase_index) != phases_completed:
			continue
		found = true
		if not bool(task.resolved):
			return false
	return found


func _all_work_complete() -> bool:
	if event_matrix_mode:
		return event_runtime != null and event_runtime.can_finish()
	if is_climax:
		return phases_completed == 3 and collected_cargo == 0
	for index in objective_counts.size():
		if objective_counts[index] < objective_goals[index]:
			return false
	return collected_cargo == 0


func _deposit_collected_cargo() -> void:
	if collected_cargo <= 0:
		return
	var deposited_now := collected_cargo
	for index in tasks.size():
		var task := tasks[index]
		if String(task.type) != "collect" or not bool(task.resolved) or bool(task.get("credited", false)):
			continue
		task.credited = true
		tasks[index] = task
		if not is_climax:
			var objective_index := int(task.objective_index)
			objective_counts[objective_index] = mini(
				objective_goals[objective_index],
				objective_counts[objective_index] + 1
			)
	delivered_cargo += deposited_now
	message = "接货蜂把 %d 份逐个接进巢里。蜜囊空出来了，可以再走一趟。" % deposited_now
	collected_cargo = 0
	_apply_standard_load_profile()
	if carried_task_index >= 0:
		bee.set_visual_load_ratio(0.72)
	if sound != null:
		sound.play_cue("handoff")
	if is_climax and _active_phase_tasks_complete() and carried_task_index < 0:
		_complete_current_phase()


func _finish_level() -> void:
	if completion_emitted:
		return
	_clear_tutorial_overlay()
	message = String(level.get("dialogue", "接货蜂：回来啦，这一趟收得很稳。"))
	var completion_payload := {
		"level_id": level_id,
		"objectives_complete": true,
		"returned_home": true,
		"objective_counts": objective_counts.duplicate(),
		"phases_completed": phases_completed,
		"elapsed_seconds": elapsed,
		"energy_remaining": bee.energy,
		"actions": action_count,
		"failed": false,
	}
	if event_matrix_mode and event_runtime != null:
		var event_snapshot := event_runtime.snapshot()
		completion_payload["event_result"] = {
			"completed_mandatory_ids": (event_snapshot.get("completed_mandatory_ids", []) as Array).duplicate(),
			"completed_optional_ids": (event_snapshot.get("completed_optional_ids", []) as Array).duplicate(),
			"skipped_optional_ids": (event_snapshot.get("skipped_optional_ids", []) as Array).duplicate(),
			"route_choices": (event_snapshot.get("route_choices", {}) as Dictionary).duplicate(true),
			"support_points": int(event_snapshot.get("support_points", 0)),
			"world_state": (event_snapshot.get("world_state", {}) as Dictionary).duplicate(true),
		}
	_complete_journey(completion_payload)


func _fail_attempt(reason: String) -> void:
	if failed or completion_emitted:
		return
	_clear_tutorial_overlay()
	failed = true
	completion_emitted = true
	bee.active = false
	message = reason
	attempt_failed.emit(reason, status_snapshot())


func _handle_secondary_action() -> void:
	if event_matrix_mode and event_runtime != null and not event_runtime.is_finished():
		if event_runtime.optional_pending():
			var skipped := event_runtime.skip_optional()
			if bool(skipped.get("accepted", false)):
				_prepare_current_event()
				_emit_event_checkpoint_if_ready()
				message = "这件小事先略过，不影响本候主线。%s" % message
			return
		if event_runtime.choice_pending():
			_select_event_route("steady")
			return
		if event_runtime.optional_accepted():
			var abandoned := event_runtime.skip_optional()
			if bool(abandoned.get("accepted", false)):
				_prepare_current_event()
				_emit_event_checkpoint_if_ready()
				message = "已经放下这件自选小事，不影响本候主线。%s" % message
			return
	bee.set_move_target(home_position)
	message = "沿亮着的巢门回去。身上的东西和蜜囊都会跟你一起走。"


func _unhandled_input(event: InputEvent) -> void:
	if completion_emitted or not input_enabled or bee == null:
		return
	# The same double-direction gesture works on keyboard and analogue gamepad.
	# Keeping it in the shared evade controller also preserves the first-tap pose
	# cue and prevents a diagonal chord from spending energy twice.
	if event is InputEventJoypadMotion:
		_handle_joy_direction_edge(event as InputEventJoypadMotion)
		return
	for direction_key in ["left", "right", "up", "down"]:
		if event.is_action_pressed("move_%s" % direction_key) and not event.is_echo():
			_register_evade_direction_tap(direction_key)
			return
	var screen_position := Vector2.ZERO
	var pressed := false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		touch_input_mode = false
		screen_position = event.position
		pressed = event.pressed
	elif event is InputEventScreenTouch:
		touch_input_mode = true
		screen_position = event.position
		pressed = event.pressed
	if not pressed:
		return
	if _handle_event_edge_guide_press(screen_position):
		get_viewport().set_input_as_handled()
		return
	var world_position := get_canvas_transform().affine_inverse() * screen_position
	var world_attempt_origin := bee.position
	if evade_input_controller.world_tap_time > 0.0:
		world_attempt_origin = evade_input_controller.world_tap_origin
	bee.allow_exhausted_evade = _mandatory_evade_assist_available(world_attempt_origin)
	var tap_result: Dictionary = evade_input_controller.handle_world_tap(
		world_position,
		Time.get_ticks_msec() * 0.001,
		bee,
		playable_bounds,
		true
	)
	bee.allow_exhausted_evade = false
	# This child owns pointer input for the urgent-turn detector, so it must also
	# preserve the base field's ordinary one-tap movement contract.  The controller
	# already does this on a first tap; setting the clamped target explicitly keeps
	# that guarantee local even if the controller implementation changes later.
	if bool(tap_result.get("consumed", false)) and not bool(tap_result.get("evade_attempted", false)):
		bee.set_move_target(clamp_to_playable_center(world_position))
	_play_evade_result(tap_result)
	if bool(tap_result.get("consumed", false)):
		get_viewport().set_input_as_handled()


func _handle_joy_direction_edge(event: InputEventJoypadMotion) -> void:
	var negative_key := ""
	var positive_key := ""
	if event.axis == JOY_AXIS_LEFT_X:
		negative_key = "left"
		positive_key = "right"
	elif event.axis == JOY_AXIS_LEFT_Y:
		negative_key = "up"
		positive_key = "down"
	else:
		return
	if absf(event.axis_value) <= 0.35:
		joy_direction_down[negative_key] = false
		joy_direction_down[positive_key] = false
		return
	var pressed_key := negative_key if event.axis_value <= -0.65 else (
		positive_key if event.axis_value >= 0.65 else ""
	)
	if pressed_key.is_empty() or bool(joy_direction_down.get(pressed_key, false)):
		return
	joy_direction_down[negative_key] = pressed_key == negative_key
	joy_direction_down[positive_key] = pressed_key == positive_key
	_register_evade_direction_tap(pressed_key)


func _register_evade_direction_tap(direction_key: String) -> void:
	var direction_attempt_origin := bee.position
	if float(evade_input_controller.direction_tap_times.get(direction_key, 0.0)) > 0.0:
		direction_attempt_origin = Vector2(
			evade_input_controller.direction_tap_origins.get(direction_key, bee.position)
		)
	bee.allow_exhausted_evade = _mandatory_evade_assist_available(direction_attempt_origin)
	var result: Dictionary = evade_input_controller.register_direction_tap(
		direction_key,
		Vector2(EvadeInputControllerScript.DIRECTION_VECTORS[direction_key]),
		Time.get_ticks_msec() * 0.001,
		bee
	)
	bee.allow_exhausted_evade = false
	_play_evade_result(result)


func _attempt_event_evade() -> void:
	# The on-screen action and Space/A must perform the action named on the button,
	# not merely tell the player to discover a second hidden input.  Double-tapping
	# a direction remains the expressive movement shortcut.
	var direction := bee.velocity.normalized()
	if direction.length_squared() < 0.01:
		direction = Vector2.from_angle(bee.facing)
	bee.allow_exhausted_evade = _mandatory_evade_assist_available()
	var started := bee.try_evade(direction, bee.position)
	bee.allow_exhausted_evade = false
	_play_evade_result({
		"consumed": true,
		"evade_attempted": true,
		"evade_started": started,
		"direction": direction,
		"origin": bee.position,
	})


func _effective_evade_energy_cost() -> float:
	return bee.current_evade_energy_cost() if bee != null else CAMPAIGN_EVADE_COST


func _mandatory_evade_assist_available(at_position = null) -> bool:
	var attempt_position := bee.position if bee != null else Vector2.ZERO
	if at_position != null:
		attempt_position = Vector2(at_position)
	if (
		event_runtime == null
		or event_runtime.is_finished()
		or bee == null
		or bool(event_runtime.current_event().get("optional", false))
		or attempt_position.distance_to(_event_interaction_target()) > EVENT_INTERACTION_RADIUS * 1.25
	):
		return false
	return (
		(
			event_runtime.current_kind() == JourneyEventMatrixRuntime.KIND_ROUTE
			and event_runtime.requires_evade()
		)
		or (
			event_runtime.current_kind() == JourneyEventMatrixRuntime.KIND_CONVOY
			and _convoy_stage_requires_evade()
		)
	)


func _play_evade_result(result: Dictionary) -> void:
	if bool(result.get("evade_started", false)):
		var actual_cost := bee.last_evade_energy_spent
		var attempt_origin := Vector2(result.get("origin", bee.position))
		var needs_energy_tutorial := not energy_rule_taught and not energy_rule_commit_pending
		energy_state = "急转 -%s" % _format_energy_amount(actual_cost)
		energy_feedback_hold = 1.4
		var evade_feedback := (
			"体力见底也穿过去了；本次实际消耗 %s 点，停稳就能回到 30。" % _format_energy_amount(actual_cost)
			if bee.last_evade_was_assisted
			else "穿过去了！急转消耗 %s 点体力。" % _format_energy_amount(actual_cost)
		)
		message = evade_feedback
		if sound != null:
			sound.play_cue("evade")
		if (
			event_matrix_mode
			and event_runtime != null
			and not event_runtime.is_finished()
		):
			if (
				event_runtime.current_kind() == JourneyEventMatrixRuntime.KIND_ROUTE
				and event_runtime.requires_evade()
			):
				if attempt_origin.distance_to(_event_interaction_target()) <= EVENT_INTERACTION_RADIUS * 1.25:
					event_runtime.note_evade()
					_advance_event_step(JourneyEventMatrixRuntime.KIND_ROUTE)
			elif (
				event_runtime.current_kind() == JourneyEventMatrixRuntime.KIND_CONVOY
				and _convoy_stage_requires_evade()
			):
				if attempt_origin.distance_to(_event_interaction_target()) <= EVENT_INTERACTION_RADIUS * 1.25:
					event_runtime.note_evade()
					_handle_event_convoy(_event_interaction_target())
		# Event progress writes its own useful "1/3" feedback. Keep the stamina
		# explanation on the same toast instead of letting that write erase the new
		# rule at the exact moment the player first pays for it.
		if message != evade_feedback:
			message = "%s %s" % [message, evade_feedback]
		if needs_energy_tutorial:
			_queue_energy_tutorial()
	elif bool(result.get("evade_attempted", false)):
		if bee.energy < _effective_evade_energy_cost():
			message = "体力不够做急转。普通飞行仍可用；见底时会变慢。停稳片刻可回到 30，休息点可回满。"
		else:
			message = "急转还在恢复。等身后的亮痕消失，再试一次。"


func _is_sheltered(position: Vector2) -> bool:
	for shelter in shelter_areas:
		if shelter.has_point(position):
			return true
	return false


func _in_hazard_band(position: Vector2) -> bool:
	for band in hazard_bands:
		if band.has_point(position):
			return true
	return false


func _delivery_message(work_type: String) -> String:
	match work_type:
		"pollinate": return "同形散粉送到了，花心轻轻收拢。"
		"carry": return "物件放进对应工位，接应蜂把它往里推稳。"
		"seed": return "种核在背风花地坐稳，细梗也跟着直起来。"
		"warmth": return "暖蜡接上了，下一段换班路亮得很踏实。"
		"repair": return "两侧都扣紧，风来时只剩叶棚轻轻响。"
		"shell": return "种壳朝准声路，三边都稳稳落地。"
		"anchor": return "路线标和绳扣互相照应，这一段稳住了。"
		_: return "这一处收好了。"


func _cue_for_type(work_type: String) -> String:
	match work_type:
		"pollinate": return "pollinate"
		"collect": return "harvest"
		"carry": return "carry_log"
		"seed": return "seed"
		"warmth": return "warmth_link"
		"shell": return "seed_shell_rustle"
		"repair", "anchor": return "repair"
		"frighten": return "evade"
		_: return "relay"


func _current_phase_instruction() -> String:
	if not is_climax or phases_completed >= 3:
		return "沿花标回主巢，把这一趟真实交给接货蜂。"
	var phases: Array = level.get("phases", [])
	var phase: Dictionary = phases[phases_completed]
	return "第 %d 段 · %s\n%s" % [
		phases_completed + 1,
		String(phase.get("label", "一起收好")),
		String(phase.get("instruction", "看清这一段的节奏，再动翅膀。")),
	]


func _action_label() -> String:
	if failed:
		return "先理一理路线"
	if event_matrix_mode:
		return _event_action_label()
	if phase_intermission > 0.0:
		return "大家正在换位"
	if carried_task_index >= 0 and carried_task_index < tasks.size():
		var carried_task := tasks[carried_task_index]
		if bee.position.distance_to(Vector2(carried_task.position)) <= INTERACTION_RADIUS:
			return "放进对应工位"
		return "前往送达花标"
	if collected_cargo >= CARGO_CAPACITY:
		return "蜜囊已满，回巢卸货"
	if focus_task_index >= 0:
		return "正在观察…"
	var source_index := _nearest_source_task()
	if source_index >= 0:
		match String(tasks[source_index].type):
			"pollinate": return "取同形散粉"
			"warmth": return "接一小段暖蜡"
			"seed": return "托稳一枚种核"
			_: return "拿稳这件东西"
	var target_index := _nearest_target_task()
	if target_index >= 0:
		match String(tasks[target_index].type):
			"observe": return "停翅看清"
			"collect": return "收进蜜囊"
			"repair": return "扣紧支架"
			"shell": return "转一格种壳"
			"anchor": return "压稳绳扣"
			"frighten": return "轻轻震翼"
	if collected_cargo > 0:
		return "把这批送回主巢"
	return "看看最近花标"


func _event_action_label() -> String:
	if event_runtime == null:
		return "看看花路"
	if event_runtime.is_finished():
		return "沿亮路回巢"
	if event_runtime.optional_pending():
		return "做这件小事"
	if event_runtime.choice_pending():
		return event_runtime.choice_label("swift")
	if event_observing:
		return "正在观察…"
	match event_runtime.current_kind():
		JourneyEventMatrixRuntime.KIND_OBSERVATION:
			return "停翅观察"
		JourneyEventMatrixRuntime.KIND_ROUTE:
			if event_runtime.requires_evade():
				return "急转穿过（%s 体力）" % _format_energy_amount(_effective_evade_energy_cost())
			if event_runtime.requires_rhythm():
				return "亮起时穿过"
			return "穿过标记"
		JourneyEventMatrixRuntime.KIND_CARGO:
			if event_runtime.current_mechanic() == "moving_match":
				return "追上同形工位" if event_carrying else "拿同形牌"
			return "送到工位" if event_carrying else "托起载荷"
		JourneyEventMatrixRuntime.KIND_AIR_CATCH:
			if event_runtime.current_mechanic() == "partner_rescue":
				return "陪新蜂到安全点" if event_carrying else "并飞接住新蜂"
			return "送到临时桩" if event_carrying else "空中接住"
		JourneyEventMatrixRuntime.KIND_COOP_ANCHOR:
			return "和同伴扣紧"
		JourneyEventMatrixRuntime.KIND_ROUTE_CHOICE:
			return "通过所选路线"
		JourneyEventMatrixRuntime.KIND_CONVOY:
			if _convoy_stage_requires_rhythm():
				return "踩准空拍"
			if _convoy_stage_requires_evade():
				return "急转带队（%s 体力）" % _format_energy_amount(_effective_evade_energy_cost())
			if _convoy_stage_uses_cargo():
				return "送回队首" if event_carrying else "托起花粉"
			return "带蜂流过牌"
	return "处理眼前这件事"


func _return_label() -> String:
	if event_matrix_mode and event_runtime != null and not event_runtime.is_finished():
		if event_runtime.optional_pending():
			return "这次略过"
		if event_runtime.choice_pending():
			return event_runtime.choice_label("steady")
		if event_runtime.optional_accepted():
			return "放下这件自选小事"
	return "回巢交接" if _all_work_complete() else "指路回巢"


func _event_player_instruction() -> String:
	if event_runtime == null or event_runtime.is_finished():
		return "沿亮起的路线回主蜂巢"
	if event_runtime.optional_pending():
		return "按空格接下这件小事，按 Q 略过"
	if event_runtime.choice_pending():
		return "空格：%s　Q：%s" % [
			event_runtime.choice_label("swift"),
			event_runtime.choice_label("steady"),
		]
	match event_runtime.current_kind():
		JourneyEventMatrixRuntime.KIND_OBSERVATION:
			if event_runtime.requires_weather_window():
				return "等横雨停一下，飞进黄色圆圈，停稳后按空格"
			return "飞进黄色圆圈，停稳后按空格"
		JourneyEventMatrixRuntime.KIND_ROUTE:
			if event_runtime.requires_evade():
				return (
					"飞进黄色圆圈，朝同一边连点两下（或点右下动作）"
					if touch_input_mode
					else "飞进黄色圆圈，连续按两次同一个方向（或按空格）"
				)
			if event_runtime.requires_rhythm():
				return "飞进黄色圆圈，圆圈亮起时按空格"
			return "飞进黄色圆圈，按空格穿过"
		JourneyEventMatrixRuntime.KIND_CARGO:
			if event_runtime.current_mechanic() == "moving_match":
				return "拿起与目标同形的牌，再送到黄色圆圈" if not event_carrying else "把手里的牌送到同形的黄色圆圈"
			if event_runtime.current_mechanic() == "handoff_timing":
				return (
					"飞到发亮载荷旁按空格接起"
					if not event_carrying
					else "到黄色圆圈，等接货蜂举起前足时按空格交接"
				)
			return "飞到发亮物件旁按空格，再送到黄色圆圈" if not event_carrying else "把手里的东西送到黄色圆圈"
		JourneyEventMatrixRuntime.KIND_AIR_CATCH:
			if event_runtime.current_mechanic() == "partner_rescue":
				return (
					"陪同期新蜂飞到黄色安全点的叶棚，再按空格一起落稳"
					if event_carrying
					else "带一点速度靠近同期新蜂，按空格并飞接应"
				)
			return "追上移动目标按空格，再送到黄色圆圈" if not event_carrying else "把接到的东西送到黄色圆圈"
		JourneyEventMatrixRuntime.KIND_COOP_ANCHOR:
			return "飞进黄色圆圈，按空格与同伴一起扣紧"
		JourneyEventMatrixRuntime.KIND_ROUTE_CHOICE:
			return "沿选好的路线飞进黄色圆圈，按空格"
		JourneyEventMatrixRuntime.KIND_CONVOY:
			if _convoy_stage_requires_evade():
				return (
					"跟队飞进黄色圆圈，朝同一边连点两下（或点右下动作）"
					if touch_input_mode
					else "跟队飞进黄色圆圈，连按两次同一方向（或按空格）"
				)
			if _convoy_stage_requires_rhythm():
				return "跟队飞进黄色圆圈，圆圈亮起时按空格"
			return "跟着蜂队飞进黄色圆圈，按空格"
	return "飞到黄色圆圈，按空格"


func _event_progress_label(runtime_snapshot: Dictionary) -> String:
	if bool(runtime_snapshot.get("can_finish", false)):
		return ""
	if event_runtime == null or event_runtime.optional_pending() or event_runtime.choice_pending():
		return ""
	var progress := int(runtime_snapshot.get("progress", 0))
	var required := int(runtime_snapshot.get("required", 1))
	var verb := "已完成"
	match event_runtime.current_kind():
		JourneyEventMatrixRuntime.KIND_ROUTE, JourneyEventMatrixRuntime.KIND_ROUTE_CHOICE, JourneyEventMatrixRuntime.KIND_CONVOY:
			verb = "已通过"
		JourneyEventMatrixRuntime.KIND_OBSERVATION:
			verb = "已观察"
		JourneyEventMatrixRuntime.KIND_CARGO:
			verb = "已送达"
		JourneyEventMatrixRuntime.KIND_AIR_CATCH:
			verb = "已接回"
		JourneyEventMatrixRuntime.KIND_COOP_ANCHOR:
			verb = "已扣紧"
	return "%s %d/%d" % [verb, progress, required]


func status_snapshot() -> Dictionary:
	var snapshot := _base_snapshot()
	if event_matrix_mode:
		return _event_status_snapshot(snapshot)
	var objective_lines: Array[String] = []
	var objectives: Array = level.get("objectives", [])
	var has_collection := false
	for task in tasks:
		if String(task.type) == "collect":
			has_collection = true
			break
	if is_climax:
		var phases: Array = level.get("phases", [])
		for index in phases.size():
			var marker := "✓" if index < phases_completed else ("→" if index == phases_completed else "·")
			objective_lines.append("%s %s" % [marker, String((phases[index] as Dictionary).get("label", "阶段"))])
	else:
		for index in objectives.size():
			objective_lines.append("%s  %d / %d" % [
				String((objectives[index] as Dictionary).get("label", "花田工作")),
				objective_counts[index] if index < objective_counts.size() else 0,
				objective_goals[index] if index < objective_goals.size() else 0,
			])
	snapshot.merge({
		"level_id": level_id,
		"level_number": int(level.get("number", 1)),
		"term_name": String(level.get("term_name", "节气")),
		"display_name": String(CLIMAX_DISPLAY_NAMES.get(season_id, "季节大忙")) if is_climax else "",
		"is_climax": is_climax,
		"phase": phases_completed + 1 if phases_completed < 3 else 3,
		"phases_completed": phases_completed,
		"objective_lines": objective_lines,
		"objective_counts": objective_counts.duplicate(),
		"objective_goals": objective_goals.duplicate(),
		"active_objective_index": _active_objective_index(),
		"carried": collected_cargo + (1 if carried_task_index >= 0 else 0),
		"honey_cargo": collected_cargo,
		"capacity": CARGO_CAPACITY,
		"delivered_cargo": delivered_cargo,
		"has_collection": has_collection,
		"time_remaining": maxf(0.0, time_limit_seconds - weather_window_elapsed),
		"hazard_active": hazard_active,
		"sheltered": _is_sheltered(bee.position) if bee != null else false,
		"resting": resting,
		"energy_state": energy_state,
		"fatigued": bee.energy <= 0.01 if bee != null else false,
		"sprinting": (
			bee.move_duration > bee.auto_dash_delay and bee.evade_time <= 0.0
		) if bee != null else false,
		"evade_cost": _effective_evade_energy_cost(),
		"evade_ready": (
			bee.evade_cooldown <= 0.0
			and (bee.energy >= _effective_evade_energy_cost() or _mandatory_evade_assist_available())
		) if bee != null else false,
		"ready_to_return": _all_work_complete(),
		"phase_instruction": _current_phase_instruction() if is_climax else "",
		"action_label": _action_label(),
		"action_enabled": not failed and phase_intermission <= 0.0 and focus_task_index < 0,
		"return_label": _return_label(),
		"failed": failed,
	})
	return snapshot


func _event_status_snapshot(snapshot: Dictionary) -> Dictionary:
	var runtime_snapshot := event_runtime.snapshot() if event_runtime != null else {}
	var ready := bool(runtime_snapshot.get("can_finish", false))
	var current_number := int(runtime_snapshot.get("current_event_number", 1))
	var title := String(runtime_snapshot.get("current_event_title", ""))
	var hint := String(runtime_snapshot.get("ui_hint", ""))
	var optional_word := "自选" if bool(runtime_snapshot.get("optional", false)) else "主线"
	var current_line := "三候已经收齐" if ready else "第%d候 · %02d/15 · %s · %s" % [
		int(runtime_snapshot.get("pentad", 1)), current_number, optional_word, title,
	]
	if not ready and not hint.is_empty():
		current_line += " · %s" % hint
	var visible_world_state: Dictionary = runtime_snapshot.get("world_state", {})
	visible_world_state = visible_world_state.duplicate(true)
	visible_world_state["persistent_mark_count"] = event_world_marks.size()
	visible_world_state["current_target"] = _event_navigation_target()
	snapshot.merge({
		"level_id": level_id,
		"level_number": int(level.get("number", 1)),
		"term_name": String(level.get("term_name", "节气")),
		"display_name": String(CLIMAX_DISPLAY_NAMES.get(season_id, "季节大忙")) if is_climax else "",
		"is_climax": is_climax,
		"phase": int(runtime_snapshot.get("pentad", 3)),
		"phases_completed": int(runtime_snapshot.get("pentads_completed", 0)),
		# Exactly one actionable line is exposed.  Completed and future events live
		# in the runtime snapshot for save/debug evidence, not in the HUD list.
		"objective_lines": [current_line],
		"objective_counts": [int(runtime_snapshot.get("progress", 0))],
		"objective_goals": [int(runtime_snapshot.get("required", 1))],
		"player_instruction": _event_player_instruction(),
		"progress_label": _event_progress_label(runtime_snapshot),
		"carried": 1 if event_carrying else 0,
		"honey_cargo": 0,
		"capacity": CARGO_CAPACITY,
		"delivered_cargo": int(visible_world_state.get("delivered_loads", 0)),
		"has_collection": false,
		"time_remaining": maxf(0.0, time_limit_seconds - weather_window_elapsed),
		"hazard_active": hazard_active,
		"sheltered": _is_sheltered(bee.position) if bee != null else false,
		"resting": resting,
		"energy_state": energy_state,
		"fatigued": bee.energy <= 0.01 if bee != null else false,
		"sprinting": (
			bee.move_duration > bee.auto_dash_delay and bee.evade_time <= 0.0
		) if bee != null else false,
		"evade_cost": _effective_evade_energy_cost(),
		"evade_ready": (
			bee.evade_cooldown <= 0.0
			and (bee.energy >= _effective_evade_energy_cost() or _mandatory_evade_assist_available())
		) if bee != null else false,
		"ready_to_return": ready,
		"phase_instruction": current_line if is_climax else "",
		"action_label": _event_action_label(),
		"action_enabled": not failed and not event_observing,
		"return_label": _return_label(),
		"failed": failed,
		"event_runtime": runtime_snapshot,
		"visible_world_state": visible_world_state,
	})
	return snapshot


func _draw_background() -> void:
	super._draw_background()
	# The weather topology remains the actual slowdown geometry, but its visual
	# language is made of moving lanes and leaf shelter shapes—not debug rectangles.
	for band_index in hazard_bands.size():
		var band := hazard_bands[band_index]
		var tint := Color("d7edf2", 0.11 if not hazard_active else 0.24)
		if season_id == "summer": tint = Color("f5d36b", 0.10 if not hazard_active else 0.20)
		elif season_id == "autumn": tint = Color("d9b777", 0.10 if not hazard_active else 0.21)
		_draw_weather_lane(band, tint)
	for shelter in shelter_areas:
		_draw_leaf_shelter(shelter)


func _draw_weather_lane(band: Rect2, tint: Color) -> void:
	var vertical := band.size.y > band.size.x
	var cross_size := band.size.x if vertical else band.size.y
	for lane_index in 5:
		var ratio := float(lane_index) / 4.0
		var offset := lerpf(-cross_size * 0.34, cross_size * 0.34, ratio)
		var start := Vector2(
			band.get_center().x + offset if vertical else band.position.x + 32.0,
			band.position.y + 32.0 if vertical else band.get_center().y + offset
		)
		var finish := Vector2(
			start.x if vertical else band.end.x - 32.0,
			band.end.y - 32.0 if vertical else start.y
		)
		var line_color := tint
		line_color.a *= 0.70 + float(lane_index % 2) * 0.30
		draw_dashed_line(start, finish, line_color, 4.0 if hazard_active else 3.0, 30.0)
	for mote_index in 7:
		var progress := fmod(float(mote_index) * 0.151 + elapsed * 0.035, 1.0)
		var mote := Vector2(
			band.get_center().x + sin(float(mote_index) * 1.9) * cross_size * 0.31 if vertical else lerpf(band.position.x, band.end.x, progress),
			lerpf(band.position.y, band.end.y, progress) if vertical else band.get_center().y + sin(float(mote_index) * 1.9) * cross_size * 0.31
		)
		draw_circle(mote, 5.0 if hazard_active else 3.5, tint)


func _draw_leaf_shelter(shelter: Rect2) -> void:
	var center := shelter.get_center()
	var canopy_color := Color("dce6a7", 0.15)
	var edge_color := Color("f5e6aa", 0.50)
	for leaf_index in 3:
		var leaf_center := center + Vector2(-58.0 + leaf_index * 58.0, -15.0 + absf(float(leaf_index - 1)) * 12.0)
		draw_set_transform(leaf_center, -0.35 + leaf_index * 0.35, Vector2(1.65, 0.72))
		draw_circle(Vector2.ZERO, 46.0, canopy_color)
		draw_arc(Vector2.ZERO, 46.0, PI, TAU, 16, edge_color, 3.0)
		draw_set_transform(Vector2.ZERO)


func _draw_world_memory() -> void:
	var traces: Array = world_results.get("traces", [])
	for index in mini(24, traces.size()):
		var row := index / 8
		var column := index % 8
		var point := home_position + Vector2(-125.0 + column * 38.0, 132.0 + row * 34.0)
		var trace := traces[index] as Dictionary
		var trace_season := String(trace.get("season_id", "spring"))
		var colors: Array = SEASON_COLORS.get(trace_season, SEASON_COLORS.spring)
		if not _world_visual_fully_visible(point, Rect2(-14.0, -14.0, 28.0, 28.0)):
			continue
		draw_circle(point, 10.0, colors[2], true)
		draw_arc(point, 13.0, 0.0, TAU, 16, Color("fff0c1", 0.86), 2.0)
		# One notch per completed level keeps every durable trace countable in the
		# world without turning the field into a text ledger.
		draw_line(point, point + Vector2.from_angle(float(index % 6) / 6.0 * TAU) * 9.0, Color("6c5136"), 2.0)


func _draw_chapter() -> void:
	_draw_rest_points()
	if event_matrix_mode:
		_draw_event_world_state()
		_draw_current_event()
		_draw_route_pointer()
		_draw_climax_neighbour()
		if hazard_active:
			_draw_weather_motion()
		return
	_draw_tasks()
	_draw_route_pointer()
	_draw_climax_neighbour()
	if hazard_active:
		_draw_weather_motion()


func _draw_rest_points() -> void:
	for point in rest_points:
		if not _world_visual_fully_visible(point, Rect2(-58.0, -56.0, 116.0, 125.0)):
			continue
		draw_circle(point, 56.0, Color("f3e7ad", 0.13))
		draw_arc(point, 35.0, -PI, 0.0, 14, Color("f5e8ac", 0.78), 7.0)
		draw_line(point + Vector2(-34, 3), point + Vector2(34, 3), Color("7b6545", 0.76), 6.0)
		draw_circle(point + Vector2(-26, -13), 6.0, Color("91a85f", 0.82))
		draw_circle(point + Vector2(25, -17), 7.0, Color("91a85f", 0.82))
		# Recovery is not a secret collectible. A short world-space label makes the
		# function readable before the player needs it, without adding HUD prose.
		draw_rect(Rect2(point + Vector2(-41, 39), Vector2(82, 28)), Color("f4edda", 0.86))
		draw_string(
			UI_FONT,
			point + Vector2(-34, 60),
			"休息点",
			HORIZONTAL_ALIGNMENT_CENTER,
			68.0,
			15,
			Color("405044", 0.94)
		)


func _draw_event_world_state() -> void:
	if event_runtime == null:
		return
	var visible_marks: Array[bool] = []
	for index in event_world_marks.size():
		var mark := event_world_marks[index]
		var position := Vector2(mark.get("position", home_position))
		var visible := _world_visual_fully_visible(
			position,
			Rect2(-34.0, -34.0, 68.0, 68.0)
		)
		visible_marks.append(visible)
		if not visible:
			continue
		var optional := bool(mark.get("optional", false))
		var choice := String(mark.get("choice", ""))
		var color := Color("f4ce70") if optional else Color("8fc28a")
		if choice == "swift":
			color = Color("efbc52")
		elif choice == "steady":
			color = Color("80bda0")
		draw_circle(position, 19.0, Color(color, 0.28))
		draw_arc(position, 25.0, 0.0, TAU, 18, Color(color, 0.84), 3.0)
		if optional:
			draw_line(position + Vector2(-8, 4), position + Vector2(0, -8), color, 4.0)
			draw_line(position + Vector2(0, -8), position + Vector2(9, 5), color, 4.0)
		else:
			_draw_event_memory_glyph(position, String(mark.get("mechanic", "")), color)
		if choice == "swift":
			draw_arc(position, 31.0, -1.15, 0.35, 8, Color(color, 0.92), 4.0)
		elif choice == "steady":
			draw_arc(position, 31.0, 0.55, 2.25, 8, Color(color, 0.92), 4.0)
		if index > 0 and visible_marks[index - 1]:
			var previous := Vector2(event_world_marks[index - 1].get("position", position))
			draw_dashed_line(previous, position, Color("f8df8c", 0.36), 3.0, 23.0)
	var world: Dictionary = event_runtime.world_state
	var bloom_stage := int(world.get("bloom_stage", 0))
	for bloom_index in bloom_stage * 3:
		var bloom_position := home_position + Vector2(430.0 + bloom_index * 62.0, 185.0 + sin(float(bloom_index) * 1.3) * 38.0)
		if not _world_visual_fully_visible(bloom_position, Rect2(-16.0, -16.0, 32.0, 32.0)):
			continue
		for petal in 5:
			draw_circle(bloom_position + Vector2.from_angle(float(petal) / 5.0 * TAU) * 9.0, 5.5, Color("f2a9bd", 0.72))
		draw_circle(bloom_position, 4.5, Color("efd06b"))
	if bool(world.get("setpiece_complete", false)):
		for index in range(1, event_world_marks.size()):
			if not visible_marks[index - 1] or not visible_marks[index]:
				continue
			draw_line(
				Vector2(event_world_marks[index - 1].get("position", home_position)),
				Vector2(event_world_marks[index].get("position", home_position)),
				Color("ffe590", 0.72),
				8.0,
				true
			)


func _draw_current_event() -> void:
	if event_runtime == null or event_runtime.is_finished():
		return
	var kind := event_runtime.current_kind()
	var raw_target := _event_interaction_target()
	var target_visible := _event_marker_full_visible(raw_target, _current_event_visual_bounds())
	var navigation_target := _event_navigation_target()
	if not target_visible and navigation_target.is_equal_approx(raw_target):
		_draw_event_edge_guide(navigation_target)
		return
	var target := raw_target
	var pulse := 1.0 + sin(elapsed * 3.4) * 0.08
	var pending_alpha := 0.40 if event_runtime.optional_pending() else 0.82
	if target_visible:
		draw_circle(target, 55.0 * pulse, Color("fff0a5", 0.12))
		draw_arc(target, 62.0 * pulse, 0.0, TAU, 28, Color("fff0a5", pending_alpha), 4.0)
	match kind:
		JourneyEventMatrixRuntime.KIND_OBSERVATION:
			if not target_visible:
				return
			for ring in 3:
				draw_arc(target, 18.0 + ring * 11.0, -2.7 + ring * 0.25, 0.3 + ring * 0.25, 18, Color("96d0d5", 0.78 - ring * 0.12), 3.0)
		JourneyEventMatrixRuntime.KIND_ROUTE:
			if not target_visible:
				return
			draw_line(target + Vector2(-34, -28), target + Vector2(-34, 28), Color("8aa46d"), 7.0)
			draw_line(target + Vector2(34, -28), target + Vector2(34, 28), Color("8aa46d"), 7.0)
			draw_dashed_line(target + Vector2(-25, 0), target + Vector2(25, 0), Color("fff0a5"), 4.0, 12.0)
		JourneyEventMatrixRuntime.KIND_CARGO:
			if event_runtime.current_mechanic() == "moving_match":
				_draw_moving_match_sources()
				if target_visible:
					_draw_event_shape(_moving_match_required_shape(), target, Color("e8b65e"))
				if event_carrying and target_visible:
					draw_dashed_line(bee.position, target, Color("ffe594", 0.68), 4.0, 18.0)
			elif not event_carrying:
				_draw_event_parcel_marker(event_source_position, event_runtime.uses_heavy_load(), true)
			if target_visible:
				_draw_event_receiving_station(target)
		JourneyEventMatrixRuntime.KIND_AIR_CATCH:
			if not target_visible:
				return
			if not event_carrying:
				match event_runtime.current_mechanic():
					"escort_shelter": _draw_beetle_leaf_shelter(target)
					"partner_rescue": _draw_worker_bee(target, 0.72)
					_: _draw_event_shape(event_runtime.current_progress, target, Color("e8b65e"))
			_draw_event_receiving_station_if_visible(_current_event_point())
		JourneyEventMatrixRuntime.KIND_COOP_ANCHOR:
			if not target_visible:
				return
			if event_runtime.current_mechanic() == "spatial_match":
				_draw_spatial_match(target)
			else:
				draw_line(target + Vector2(0, -39), target + Vector2(0, 34), Color("74513c"), 9.0)
				draw_arc(target + Vector2(0, 25), 27.0, -PI, 0.0, 14, Color("e1bc68"), 5.0)
				_draw_worker_bee(target + Vector2(64, 13), 0.68)
			if event_runtime.current_mechanic() == "convoy_anchor":
				_draw_event_convoy()
		JourneyEventMatrixRuntime.KIND_ROUTE_CHOICE:
			if not target_visible:
				return
			var choice := event_runtime.current_choice
			var swift_color := Color("f3ca61", 0.84 if choice in ["", "swift"] else 0.24)
			var steady_color := Color("9dc58b", 0.84 if choice in ["", "steady"] else 0.24)
			draw_dashed_line(target + Vector2(-120, -60), target, swift_color, 6.0, 19.0)
			draw_dashed_line(target + Vector2(-150, 85), target, steady_color, 6.0, 26.0)
		JourneyEventMatrixRuntime.KIND_CONVOY:
			if target_visible:
				draw_line(target + Vector2(0, -45), target + Vector2(0, 36), Color("75543d"), 8.0)
				draw_colored_polygon(PackedVector2Array([target + Vector2(0, -41), target + Vector2(42, -27), target + Vector2(0, -10)]), Color("e2b85d"))
			if _convoy_stage_uses_cargo() and not event_carrying:
				_draw_event_parcel_marker(event_source_position, false, true)
			if _convoy_stage_requires_evade() and target_visible:
				draw_arc(target, 78.0, -2.65, -0.55, 18, Color("b8e4e5", 0.78), 6.0)
			_draw_event_convoy()
	if target_visible and (event_runtime.requires_rhythm() or _convoy_stage_requires_rhythm()):
		_draw_event_rhythm_signal(target)
	if target_visible and event_runtime.choice_pending():
		_draw_event_choice_fork(target)
	if target_visible and event_runtime.optional_pending():
		draw_arc(target, 72.0, -PI * 0.25, PI * 1.25, 22, Color("f5d16b", 0.82), 3.0)


func _draw_event_edge_guide(world_target: Vector2) -> void:
	var guide_position := event_marker_draw_position(world_target, EVENT_EDGE_GUIDE_EXTENT)
	var direction := (_event_marker_screen_position(world_target) - _event_marker_screen_position(guide_position)).normalized()
	if direction.length_squared() < 0.01:
		direction = Vector2.RIGHT
	draw_circle(guide_position, 29.0, Color("283d34", 0.88))
	draw_arc(guide_position, 31.0, -PI * 0.78, PI * 0.78, 18, Color("ffe38b", 0.94), 4.0)
	var tip := guide_position + direction * 22.0
	var side := direction.orthogonal() * 9.0
	draw_colored_polygon(PackedVector2Array([
		tip + direction * 7.0,
		tip - direction * 9.0 + side,
		tip - direction * 9.0 - side,
	]), Color("ffe38b", 0.98))
	draw_circle(guide_position - direction * 9.0, 5.0, Color("f4edda", 0.90))


func _draw_event_memory_glyph(position: Vector2, mechanic: String, color: Color) -> void:
	if mechanic in ["pollen_delivery", "moving_shelter"]:
		for petal in 5:
			draw_circle(position + Vector2.from_angle(float(petal) / 5.0 * TAU) * 8.0, 4.0, color)
		draw_circle(position, 3.0, Color("efd06b"))
	elif mechanic in ["air_catch", "moving_match", "spatial_match"]:
		_draw_event_shape(1, position, color)
	elif mechanic in ["coop_anchor", "convoy_anchor"]:
		draw_line(position + Vector2(-8, 8), position + Vector2(0, -9), color, 4.0)
		draw_line(position + Vector2(0, -9), position + Vector2(8, 8), color, 4.0)
	else:
		draw_line(position + Vector2(-9, 0), position + Vector2(-2, 8), color, 4.0)
		draw_line(position + Vector2(-2, 8), position + Vector2(11, -9), color, 4.0)


func _draw_event_shape(shape_index: int, position: Vector2, color: Color) -> void:
	match shape_index % 3:
		0:
			draw_colored_polygon(PackedVector2Array([
				position + Vector2(0, -20), position + Vector2(19, 15), position + Vector2(-19, 15),
			]), color)
		1:
			draw_rect(Rect2(position - Vector2(17, 17), Vector2(34, 34)), color, true)
		_:
			draw_circle(position, 19.0, color)


func _draw_spatial_match(position: Vector2) -> void:
	for slot in 3:
		var offset := Vector2((slot - 1) * 53.0, 0.0)
		var slot_color := Color("8fc28a") if slot < event_runtime.current_progress else Color("e8b65e")
		_draw_event_shape(slot, position + offset, Color(slot_color, 0.88))
		draw_arc(position + offset, 27.0, 0.0, TAU, 16, Color("fff0a5", 0.62), 3.0)


func _draw_moving_match_sources() -> void:
	var required_shape := _moving_match_required_shape()
	for marker in _moving_match_marker_layout():
		var shape_index := int(marker.get("shape_index", -1))
		var source := Vector2(marker.get("position", Vector2.ZERO))
		if bool(marker.get("edge_guide", false)):
			_draw_event_edge_guide(Vector2(marker.get("world_target", source)))
			continue
		var source_color := Color("f0cf72") if shape_index == required_shape else Color("b5b790")
		_draw_event_shape(shape_index, source, Color(source_color, 0.92))
		draw_arc(source, 31.0, 0.0, TAU, 16, Color("fff2b0", 0.72), 3.0)
		if shape_index == required_shape:
			draw_arc(source, 40.0, -1.1, 0.1, 10, Color("f4d76e", 0.92), 5.0)


func _moving_match_marker_layout() -> Array[Dictionary]:
	var layout: Array[Dictionary] = []
	var required_shape := _moving_match_required_shape()
	var source_bounds := Rect2(-42.0, -42.0, 84.0, 84.0)
	for shape_index in event_match_sources.size():
		var source := event_match_sources[shape_index]
		if _event_marker_full_visible(source, source_bounds):
			layout.append({
				"shape_index": shape_index,
				"position": source,
				"world_target": source,
				"edge_guide": false,
			})
		elif shape_index == required_shape:
			# Off-screen alternatives are intentionally not clamped independently:
			# doing so can collapse different shapes onto one pixel. One arrow leads to
			# the currently required source; the full group appears in its real layout
			# once the camera is close enough.
			layout.append({
				"shape_index": shape_index,
				"position": event_marker_draw_position(source, EVENT_EDGE_GUIDE_EXTENT),
				"world_target": source,
				"edge_guide": true,
			})
	return layout


func _draw_beetle_leaf_shelter(position: Vector2) -> void:
	draw_circle(position, 14.0, Color("654934"))
	draw_circle(position + Vector2(18, 0), 9.0, Color("493326"))
	for leg in 3:
		var y := -9.0 + leg * 9.0
		draw_line(position + Vector2(-3, y), position + Vector2(-19, y - 5), Color("493326"), 3.0)
		draw_line(position + Vector2(5, y), position + Vector2(21, y + 5), Color("493326"), 3.0)
	draw_set_transform(position + Vector2(0, -31), -0.22, Vector2(1.7, 0.68))
	draw_circle(Vector2.ZERO, 29.0, Color("a7c77d", 0.86))
	draw_set_transform(Vector2.ZERO)


func _draw_event_rhythm_signal(position: Vector2) -> void:
	var phase := fmod(elapsed + float(event_runtime.current_index) * 0.17, EVENT_RHYTHM_PERIOD)
	var open := _event_rhythm_window_open()
	for beat in 3:
		var beat_position := position + Vector2(-30.0 + beat * 30.0, -82.0)
		var passed := phase >= float(beat + 1) * (EVENT_RHYTHM_PERIOD - EVENT_RHYTHM_OPEN_SECONDS) / 3.0
		draw_circle(beat_position, 7.0, Color("8fc8d2", 0.94 if passed else 0.30))
	var gap_color := Color("ffe58d", 0.96 if open else 0.28)
	draw_arc(position, 73.0, -0.92, -0.22, 12, gap_color, 7.0)


func _draw_event_choice_fork(position: Vector2) -> void:
	draw_dashed_line(position + Vector2(-145, -76), position + Vector2(-40, -20), Color("f2c65c", 0.86), 5.0, 17.0)
	draw_dashed_line(position + Vector2(-155, 82), position + Vector2(-40, 20), Color("8fbc82", 0.86), 5.0, 24.0)


func _draw_event_parcel(position: Vector2, heavy: bool) -> void:
	var half := Vector2(37, 28) if heavy else Vector2(27, 20)
	draw_colored_polygon(PackedVector2Array([
		position + Vector2(-half.x, 0), position + Vector2(0, -half.y),
		position + Vector2(half.x, 0), position + Vector2(0, half.y),
	]), Color("bd8c54"))
	draw_line(position + Vector2(-half.x * 0.7, -4), position + Vector2(half.x * 0.7, 5), Color("efd692"), 4.0)


func _draw_event_parcel_marker(world_position: Vector2, heavy: bool, current_navigation: bool) -> void:
	var half := Vector2(37.0, 28.0) if heavy else Vector2(27.0, 20.0)
	if _event_marker_full_visible(world_position, Rect2(-half, half * 2.0)):
		_draw_event_parcel(world_position, heavy)
	elif current_navigation:
		_draw_event_edge_guide(world_position)


func _draw_event_receiving_station(position: Vector2) -> void:
	draw_arc(position, 31.0, -PI, 0.0, 15, Color("edcf78"), 7.0)
	draw_line(position + Vector2(-32, 3), position + Vector2(32, 3), Color("795b3d"), 5.0)
	_draw_worker_bee(position + Vector2(48, 11), 0.58)


func _draw_event_receiving_station_if_visible(world_position: Vector2) -> void:
	if _event_marker_full_visible(world_position, Rect2(-32.0, -31.0, 102.0, 67.0)):
		_draw_event_receiving_station(world_position)


func _draw_event_convoy() -> void:
	if bee == null or event_runtime == null:
		return
	var outcomes := event_runtime.world_state.get("event_outcomes", {}) as Dictionary
	var partner_joined := 1 if outcomes.has("yushui_12_partner_rescue") else 0
	var follower_count := 3 + event_runtime.support_points + partner_joined
	var direction := bee.velocity.normalized() if bee.velocity.length() > 4.0 else Vector2.LEFT
	var side := direction.orthogonal()
	for follower in follower_count:
		var row := follower / 3
		var lane := follower % 3 - 1
		var follower_position := bee.position - direction * (72.0 + row * 58.0) + side * lane * 38.0
		_draw_worker_bee(follower_position, 0.48)


func _draw_tasks() -> void:
	for index in tasks.size():
		var task := tasks[index]
		if not _task_is_active(task):
			continue
		var work_type := String(task.type)
		var color: Color = TYPE_COLORS.get(work_type, accent_color)
		if bool(task.resolved):
			if _world_visual_fully_visible(
				Vector2(task.position),
				_task_marker_visual_bounds(work_type)
			):
				_draw_task_marker(Vector2(task.position), work_type, color.darkened(0.18), false, int(task.hits), true)
			continue
		if work_type in TWO_STEP_TYPES and int(task.state) == 0:
			if _world_visual_fully_visible(
				Vector2(task.source_position),
				_task_marker_visual_bounds(work_type)
			):
				_draw_task_marker(Vector2(task.source_position), work_type, color.lightened(0.14), true, int(task.hits), false)
		if _world_visual_fully_visible(
			Vector2(task.position),
			_task_marker_visual_bounds(work_type)
		):
			_draw_task_marker(Vector2(task.position), work_type, color, false, int(task.hits), false)
	if carried_task_index >= 0 and carried_task_index < tasks.size():
		var destination := Vector2(tasks[carried_task_index].position)
		if _world_visual_fully_visible(
			destination,
			_task_marker_visual_bounds(String(tasks[carried_task_index].type))
		):
			draw_dashed_line(bee.position, destination, Color("fff1aa", 0.66), 4.0, 24.0)


func _task_marker_visual_bounds(_work_type: String) -> Rect2:
	# Covers the largest current prop, its pulse ring, progress arc and completion tick.
	return Rect2(-64.0, -64.0, 128.0, 128.0)


func _draw_task_marker(position: Vector2, work_type: String, color: Color, source: bool, hits: int, resolved: bool) -> void:
	var pulse := 1.0 + sin(elapsed * 3.2 + position.x * 0.01) * 0.08
	draw_circle(position, 48.0 * pulse, Color(color, 0.12 if resolved else 0.22))
	draw_arc(position, 55.0 * pulse, 0.0, TAU, 24, Color("fff2b5", 0.30 if resolved else 0.72), 3.0)
	if _draw_commercial_task_art(position, work_type, source, resolved, color, hits):
		if source:
			draw_arc(position, 62.0, 0.0, TAU, 24, Color("fff5c7", 0.78), 3.0)
		elif resolved:
			draw_line(position + Vector2(-15, 3), position + Vector2(-3, 15), Color("fff5c7"), 5.0)
			draw_line(position + Vector2(-3, 15), position + Vector2(20, -15), Color("fff5c7"), 5.0)
		return
	match work_type:
		"pollinate":
			for petal in 5:
				draw_circle(position + Vector2.from_angle(float(petal) / 5.0 * TAU) * 17.0, 10.0, color)
			draw_circle(position, 8.0, Color("f4d069"))
		"collect", "warmth":
			draw_circle(position, 15.0, color)
			draw_circle(position + Vector2(-5, -5), 5.0, color.lightened(0.32))
		"observe":
			draw_arc(position, 22.0, 0.3, TAU - 0.3, 20, color, 5.0)
			draw_circle(position, 5.0, color.lightened(0.3))
		"carry", "repair", "anchor":
			draw_rect(Rect2(position - Vector2(17, 13), Vector2(34, 26)), color, true)
			draw_line(position + Vector2(-13, 0), position + Vector2(13, 0), color.lightened(0.3), 3.0)
		"seed", "shell":
			draw_circle(position, 14.0, color)
			for ray in 6:
				draw_line(position, position + Vector2.from_angle(float(ray) / 6.0 * TAU) * 23.0, color.lightened(0.15), 3.0)
		"frighten":
			draw_colored_polygon(PackedVector2Array([position + Vector2(-18, 0), position + Vector2(0, -13), position + Vector2(18, 0), position + Vector2(0, 13)]), color)
		_:
			draw_circle(position, 16.0, color)
	if source:
		draw_arc(position, 62.0, 0.0, TAU, 24, Color("fff5c7", 0.75), 3.0)
	elif hits > 0:
		draw_arc(position, 62.0, -PI * 0.5, -PI * 0.5 + PI * float(hits), 24, Color("fff5c7"), 4.0)


func _draw_commercial_task_art(position: Vector2, work_type: String, source: bool, resolved: bool, color: Color, hits: int) -> bool:
	var modulate := Color(1.0, 1.0, 1.0, 0.48 if resolved else 1.0)
	if work_type in ["pollinate", "collect", "seed"] and flower_states_texture != null:
		var column := 0
		if work_type == "collect": column = 1
		elif work_type == "seed" or resolved: column = 2
		elif not source: column = 1
		var source_rect := Rect2(float(column * 256), 0.0, 256.0, 256.0)
		draw_texture_rect_region(flower_states_texture, Rect2(position - Vector2(43, 43), Vector2(86, 86)), source_rect, modulate)
		return true
	if work_type == "shell" and seed_shell_states_texture != null:
		var frame_width := float(seed_shell_states_texture.get_width()) / 3.0
		var frame := mini(2, hits)
		draw_texture_rect_region(
			seed_shell_states_texture,
			Rect2(position - Vector2(49, 39), Vector2(98, 78)),
			Rect2(float(frame) * frame_width, 0.0, frame_width, float(seed_shell_states_texture.get_height())),
			modulate
		)
		return true
	if seasonal_work_props_texture != null:
		match work_type:
			"warmth":
				_draw_work_prop(1, Rect2(position - Vector2(36, 50), Vector2(72, 96)), modulate)
				return true
			"repair":
				_draw_work_prop(0, Rect2(position - Vector2(55, 45), Vector2(110, 90)), modulate)
				return true
			"anchor":
				_draw_work_prop(2, Rect2(position - Vector2(58, 42), Vector2(116, 84)), modulate)
				return true
	if work_type == "carry":
		var parcel_color := color.darkened(0.12)
		parcel_color.a = modulate.a
		draw_colored_polygon(PackedVector2Array([
			position + Vector2(-31, 0), position + Vector2(0, -24),
			position + Vector2(31, 0), position + Vector2(0, 24),
		]), parcel_color)
		draw_line(position + Vector2(-24, -5), position + Vector2(24, 7), Color("f0d696", modulate.a), 4.0)
		draw_line(position + Vector2(-4, -20), position + Vector2(5, 20), Color("6b4d32", modulate.a), 4.0)
		return true
	if work_type == "frighten":
		draw_circle(position, 15.0, Color(color, modulate.a))
		draw_circle(position + Vector2(19, 0), 10.0, Color("534132", modulate.a))
		draw_set_transform(position + Vector2(-5, -13), -0.35, Vector2(1.5, 0.7))
		draw_circle(Vector2.ZERO, 15.0, Color("e8f0df", 0.68 * modulate.a))
		draw_set_transform(position + Vector2(-5, 13), 0.35, Vector2(1.5, 0.7))
		draw_circle(Vector2.ZERO, 15.0, Color("e8f0df", 0.68 * modulate.a))
		draw_set_transform(Vector2.ZERO)
		return true
	return false


func _navigation_target() -> Vector2:
	if event_matrix_mode:
		return _event_navigation_target()
	if carried_task_index >= 0 and carried_task_index < tasks.size():
		return Vector2(tasks[carried_task_index].position)
	if collected_cargo >= CARGO_CAPACITY:
		return home_position
	if _all_work_complete():
		return home_position
	var active_task_index := _active_standard_task_index()
	if active_task_index < 0:
		return home_position if collected_cargo > 0 else bee.position
	var active_task := tasks[active_task_index]
	if String(active_task.type) in TWO_STEP_TYPES and int(active_task.state) == 0:
		return Vector2(active_task.source_position)
	return Vector2(active_task.position)


func _event_navigation_target() -> Vector2:
	if event_runtime == null or event_runtime.is_finished():
		return home_position
	var kind := event_runtime.current_kind()
	if kind == JourneyEventMatrixRuntime.KIND_CARGO and not event_carrying:
		if event_runtime.current_mechanic() == "moving_match":
			return _moving_match_source_position(_moving_match_required_shape())
		return event_source_position
	if kind == JourneyEventMatrixRuntime.KIND_CONVOY and _convoy_stage_uses_cargo() and not event_carrying:
		return event_source_position
	if event_runtime.current_mechanic() in ["moving_match", "moving_shelter"]:
		return event_dynamic_position
	if event_runtime.has_moving_target() and not event_carrying:
		return event_dynamic_position
	return _current_event_point()


func _draw_route_pointer() -> void:
	if bee == null:
		return
	if (
		event_matrix_mode
		and event_runtime != null
		and not event_runtime.is_finished()
		and event_runtime.current_mechanic() == "mastery_lane"
		and event_runtime.optional_accepted()
	):
		return
	var destination := _navigation_target()
	var offset := destination - bee.position
	if offset.length() < 118.0:
		return
	var direction := offset.normalized()
	var start := bee.position + direction * 66.0
	var tip := bee.position + direction * 104.0
	var side := direction.orthogonal() * 11.0
	draw_arc(bee.position, 63.0, direction.angle() - 0.42, direction.angle() + 0.42, 10, Color("fff0a6", 0.78), 4.0)
	draw_line(start, tip, Color("fff0a6", 0.78), 5.0)
	draw_colored_polygon(PackedVector2Array([tip + direction * 10.0, tip - direction * 9.0 + side, tip - direction * 9.0 - side]), Color("fff0a6", 0.88))


func _draw_climax_neighbour() -> void:
	if not is_climax:
		return
	var position := _climax_neighbour_position()
	var destination_size := Vector2(210.0, 150.0)
	if season_id == "summer": destination_size = Vector2(245.0, 176.0)
	elif season_id == "autumn": destination_size = Vector2(225.0, 158.0)
	elif season_id == "winter": destination_size = Vector2(240.0, 170.0)
	var neighbour_bounds := Rect2(
		-destination_size * 0.55,
		Vector2(destination_size.x * 1.1, destination_size.y * 1.28)
	)
	if not _world_visual_fully_visible(position, neighbour_bounds):
		return
	if climax_neighbour_texture != null:
		var texture_size := climax_neighbour_texture.get_size()
		var frame_width := texture_size.x / 3.0
		var frame_index := mini(2, phases_completed)
		draw_set_transform(position + Vector2(0, destination_size.y * 0.34), 0.0, Vector2(1.7, 0.42))
		draw_circle(Vector2.ZERO, 45.0, Color("4a3d2f", 0.22))
		draw_set_transform(Vector2.ZERO)
		draw_texture_rect_region(
			climax_neighbour_texture,
			Rect2(position - destination_size * 0.5, destination_size),
			Rect2(float(frame_index) * frame_width, 0.0, frame_width, texture_size.y)
		)
		draw_arc(position, destination_size.x * 0.49, 0.0, TAU, 28, Color(accent_color, 0.72), 5.0)
		for phase_index in 3:
			var dot_color := accent_color if phase_index < phases_completed else Color("6f6b5d", 0.62)
			if phase_index == phases_completed and phases_completed < 3:
				dot_color = Color("fff0a2")
			draw_circle(position + Vector2(-30 + phase_index * 30, destination_size.y * 0.60), 9.0, dot_color)
		return
	var body_color := Color("725d43")
	match season_id:
		"spring":
			body_color = Color("81745a")
			draw_circle(position, 42.0, body_color)
			draw_line(position + Vector2(-35, 22), position + Vector2(-58, 54), body_color, 8.0)
		"summer":
			body_color = Color("694a32")
			draw_colored_polygon(PackedVector2Array([position + Vector2(-48, 28), position + Vector2(-28, -42), position + Vector2(34, -35), position + Vector2(52, 25)]), body_color)
		"autumn":
			body_color = Color("8a6b48")
			draw_colored_polygon(PackedVector2Array([position + Vector2(-50, 22), position + Vector2(-8, -36), position + Vector2(52, 4), position + Vector2(8, 34)]), body_color)
			draw_circle(position + Vector2(18, -11), 4.0, Color("2f2b25"))
		"winter":
			body_color = Color("735b46")
			draw_circle(position, 62.0, body_color)
			draw_circle(position + Vector2(-38, -42), 19.0, body_color)
			draw_circle(position + Vector2(38, -42), 19.0, body_color)
	draw_arc(position, 76.0, 0.0, TAU, 24, accent_color, 5.0)
	for phase_index in 3:
		var dot_color := accent_color if phase_index < phases_completed else Color("6f6b5d", 0.52)
		draw_circle(position + Vector2(-28 + phase_index * 28, 92), 8.0, dot_color)


func _climax_neighbour_position() -> Vector2:
	if tasks.is_empty():
		return Vector2(world_bounds.end.x - 320.0, world_bounds.get_center().y)
	var task_index := mini(tasks.size() - 1, phases_completed * 3)
	var anchor := Vector2(tasks[task_index].position)
	var horizontal_offset := 230.0 if anchor.x < world_bounds.get_center().x else -230.0
	var vertical_offset := -145.0 if anchor.y > 420.0 else 155.0
	return Vector2(
		clampf(anchor.x + horizontal_offset, 180.0, world_bounds.end.x - 180.0),
		clampf(anchor.y + vertical_offset, 210.0, world_bounds.end.y - 190.0)
	)


func _draw_weather_motion() -> void:
	var weather_color := Color("dceef2", 0.46)
	if season_id == "summer": weather_color = Color("f3d26b", 0.36)
	elif season_id == "autumn": weather_color = Color("e7c58d", 0.42)
	for streak in 18:
		var x := fmod(float(streak * 337) + elapsed * 180.0, world_bounds.size.x)
		var y := 180.0 + fmod(float(streak * 193), world_bounds.size.y - 300.0)
		draw_line(Vector2(x, y), Vector2(x + 75.0, y + 24.0), weather_color, 4.0)


func force_complete_for_test() -> void:
	if event_matrix_mode and event_runtime != null:
		while not event_runtime.is_finished():
			if event_runtime.optional_pending():
				event_runtime.accept_optional()
			if event_runtime.choice_pending():
				event_runtime.choose_route("swift")
			if event_runtime.requires_evade():
				event_runtime.note_evade()
			var result := event_runtime.record_step(event_runtime.current_kind())
			if not bool(result.get("accepted", false)):
				push_error("三候测试补全停在 %s" % String(event_runtime.current_event().get("id", "unknown")))
				return
		phases_completed = 3 if is_climax else 0
		event_carrying = false
		bee.set_visual_load_ratio(0.0)
		bee.set_load_movement_profile()
		bee.position = home_position
		_finish_level()
		return
	for index in objective_counts.size():
		objective_counts[index] = objective_goals[index]
	for index in tasks.size():
		var task := tasks[index]
		task.resolved = true
		task.state = 2
		tasks[index] = task
	phases_completed = 3 if is_climax else 0
	collected_cargo = 0
	carried_task_index = -1
	bee.position = home_position
	_finish_level()
