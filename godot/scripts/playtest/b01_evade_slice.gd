class_name B01EvadeSlice
extends Node2D

const BeePlayerScript := preload("res://scripts/player/bee_player.gd")
const EncounterScript := preload("res://scripts/playtest/b01_evade_encounter.gd")
const InputControllerScript := preload("res://scripts/player/evade_input_controller.gd")
const Rules := preload("res://scripts/mechanics/evade_rules.gd")
const FIELD_TEXTURE := preload("res://assets/art/launch/spring_field_v2.png")
const FLOWER_TEXTURE := preload("res://assets/art/launch/flower_common_v1.png")
const MENTOR_TEXTURE := preload("res://assets/art/launch/player_bee_v1.png")
const MOSQUITO_TEXTURE := preload("res://assets/art/launch/mosquito_v1.png")
const FONT := preload("res://fonts/NotoSansCJKsc-ProjectSubset.otf")
const EXPLORE_MUSIC := preload("res://assets/music/spring_explore.wav")

const WORLD := Rect2(34.0, 146.0, 1178.0, 538.0)
const BEE_CENTER_BOUNDS := Rect2(52.0, 164.0, 1142.0, 502.0)
const DEMONSTRATION_SECONDS := 2.8
const GUIDED_MAX_SECONDS := 90.0
const GUIDED_MAX_ATTEMPTS := 4
const PRACTICE_MAX_SECONDS := 90.0
const PRACTICE_MAX_ATTEMPTS := 3
const DELAY_ACTIVE_SECONDS := 180.0
const HARD_LIMIT_SECONDS := 600.0
const ENCOUNTER_RECOVERY_SECONDS := 0.72

const PHASE_UNCONFIGURED := "unconfigured"
const PHASE_DEMONSTRATION := "demonstration"
const PHASE_GUIDED := "guided_imitation"
const PHASE_PRACTICE := "unprompted_practice"
const PHASE_DELAY := "active_delay_route"
const PHASE_RETEST := "unprompted_retest"
const PHASE_COMPLETE := "complete"

const RESULT_COMPLETED := "completed_independent"
const RESULT_INCOMPLETE := "attempted_incomplete"
const RESULT_NOT_ATTEMPTED := "not_attempted"

const POLLEN_POINTS: Array[Vector2] = [
	Vector2(250.0, 280.0),
	Vector2(455.0, 535.0),
	Vector2(695.0, 270.0),
	Vector2(930.0, 515.0),
	Vector2(1110.0, 335.0),
]

var playtest_session_context: Dictionary = {}
var phase := PHASE_UNCONFIGURED
var result_code := ""
var input_enabled := false
var hard_elapsed_seconds := 0.0
var phase_active_seconds := 0.0
var delay_active_seconds := 0.0
var guided_attempts := 0
var practice_attempts := 0
var retest_opportunities := 0
var teaching_display_count := 0
var current_instruction := ""

var bee: BeePlayer
var encounter := EncounterScript.new()
var input_controller := InputControllerScript.new()
var _configured := false
var _settled := false
var _focus_active := true
var _any_player_attempt := false
var _encounter_recovery_seconds := 0.0
var _route_target_index := 0
var _last_encounter_signature: Dictionary = {}

var _instruction_panel: ColorRect
var _instruction_label: Label
var _status_label: Label
var _timer_label: Label
var _pause_panel: ColorRect
var _end_panel: ColorRect
var _music: AudioStreamPlayer

func configure_playtest_session(context: Dictionary) -> Error:
	if is_inside_tree() or _configured:
		return ERR_ALREADY_IN_USE
	if not _has_exact_keys(context, ["artifact", "catalog_sha256", "product", "schema_version", "session_id", "slice", "task", "ticket_sha256"]):
		return ERR_INVALID_DATA
	if context.get("schema_version") != 1 or not context.get("session_id") is String or not _matches(String(context.session_id), "^[A-Z0-9-]{8,40}$"):
		return ERR_INVALID_DATA
	if not context.get("task") is Dictionary or not _has_exact_keys(context.task, ["code", "slice_code"]):
		return ERR_INVALID_DATA
	var task: Dictionary = context.task
	if task.get("code") != "B" or task.get("slice_code") != "B01":
		return ERR_INVALID_DATA
	if not context.get("slice") is Dictionary or not _has_exact_keys(context.slice, ["assignment", "code", "maximum_minutes", "status"]):
		return ERR_INVALID_DATA
	var slice: Dictionary = context.slice
	if slice.get("code") != "B01" or slice.get("assignment") != "固定切片 B01" or slice.get("status") != "ready":
		return ERR_INVALID_DATA
	if not _is_json_integer(slice.get("maximum_minutes")) or int(slice.maximum_minutes) != 10:
		return ERR_INVALID_DATA
	if not context.get("product") is Dictionary or not _has_exact_keys(context.product, ["commit", "dirty", "display_name", "id", "version"]):
		return ERR_INVALID_DATA
	var product: Dictionary = context.product
	if product.get("id") != "nameless-becoming" or product.get("display_name") != "无名：成蜂" or not product.get("version") is String:
		return ERR_INVALID_DATA
	if String(product.version) != String(ProjectSettings.get_setting("application/config/version", "")):
		return ERR_INVALID_DATA
	if not product.get("commit") is String or not _matches(String(product.commit), "^[0-9a-f]{40}$") or typeof(product.get("dirty")) != TYPE_BOOL or product.dirty != false:
		return ERR_INVALID_DATA
	if not context.get("artifact") is Dictionary or not _has_exact_keys(context.artifact, ["filename", "manifest_sha256", "platform", "sha256", "size"]):
		return ERR_INVALID_DATA
	var artifact: Dictionary = context.artifact
	var artifact_names := {
		"macos-universal": "NamelessBecoming-macOS.zip",
		"windows-x86_64": "NamelessBecoming-Windows.exe",
	}
	if not artifact.get("platform") is String or not artifact_names.has(artifact.platform) or artifact.get("filename") != artifact_names[artifact.platform]:
		return ERR_INVALID_DATA
	if not _is_json_integer(artifact.get("size")) or int(artifact.size) <= 0:
		return ERR_INVALID_DATA
	for hash_key in ["sha256", "manifest_sha256"]:
		if not artifact.get(hash_key) is String or not _matches(String(artifact.get(hash_key)), "^[0-9a-f]{64}$"):
			return ERR_INVALID_DATA
	for hash_key in ["catalog_sha256", "ticket_sha256"]:
		if not context.get(hash_key) is String or not _matches(String(context.get(hash_key)), "^[0-9a-f]{64}$"):
			return ERR_INVALID_DATA
	playtest_session_context = context.duplicate(true)
	_configured = true
	return OK

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not _configured:
		push_error("B01 typed scene requires a validated playtest session context before entering the tree.")
		set_physics_process(false)
		set_process_unhandled_input(false)
		return
	_build_world()
	_build_interface()
	_begin_demonstration()
	set_physics_process(true)
	set_process_unhandled_input(true)

func _build_world() -> void:
	bee = BeePlayerScript.new()
	bee.name = "Bee"
	# The root must keep the hard wall clock alive while paused. The player is
	# explicitly pausable so inheriting from that root cannot advance movement.
	bee.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(bee)
	var bounds_error := bee.set_movement_bounds(WORLD)
	assert(bounds_error == OK, "B01 movement bounds must remain valid")
	bee.reset_for_expedition(Vector2(620.0, 410.0))
	bee.configure(0.0)
	bee.set_spring_launch_art(true)
	bee.active = false

	_music = AudioStreamPlayer.new()
	_music.name = "ExploreMusic"
	_music.process_mode = Node.PROCESS_MODE_PAUSABLE
	_music.stream = EXPLORE_MUSIC
	_music.volume_db = -20.0
	_music.finished.connect(_on_music_finished)
	add_child(_music)
	if DisplayServer.get_name() != "headless":
		_music.play()

func _exit_tree() -> void:
	if _music != null:
		_music.stop()
		_music.stream = null

func _build_interface() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Interface"
	add_child(layer)

	var header := ColorRect.new()
	header.color = Color("17191fe8")
	header.position = Vector2(34.0, 28.0)
	header.size = Vector2(1178.0, 92.0)
	layer.add_child(header)

	var title := _label("固定切片 B01", 28)
	title.position = Vector2(26.0, 16.0)
	title.size = Vector2(580.0, 54.0)
	header.add_child(title)

	_status_label = _label("", 20)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_status_label.position = Vector2(610.0, 20.0)
	_status_label.size = Vector2(360.0, 42.0)
	header.add_child(_status_label)

	_timer_label = _label("10:00", 22)
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_timer_label.position = Vector2(982.0, 18.0)
	_timer_label.size = Vector2(166.0, 46.0)
	header.add_child(_timer_label)

	_instruction_panel = ColorRect.new()
	_instruction_panel.color = Color("22252fe8")
	_instruction_panel.position = Vector2(82.0, 568.0)
	_instruction_panel.size = Vector2(1082.0, 104.0)
	_instruction_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_instruction_panel)
	_instruction_label = _label("", 21)
	_instruction_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_instruction_label.position = Vector2(24.0, 16.0)
	_instruction_label.size = Vector2(1034.0, 76.0)
	_instruction_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_instruction_panel.add_child(_instruction_label)

	_pause_panel = ColorRect.new()
	_pause_panel.color = Color("111319d9")
	_pause_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_panel.visible = false
	layer.add_child(_pause_panel)
	var pause_label := _label("已暂停", 34)
	pause_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pause_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_panel.add_child(pause_label)

	_end_panel = ColorRect.new()
	_end_panel.color = Color("17191ff2")
	_end_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_end_panel.visible = false
	layer.add_child(_end_panel)
	var end_label := _label("本次试玩已结束。\n可以关闭游戏并回到短表。", 32)
	end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	end_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_end_panel.add_child(end_label)

func _label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color("f3ecd8"))
	return label

func _physics_process(delta: float) -> void:
	if not _configured or _settled:
		return
	var gameplay_active := _gameplay_is_active()
	_set_bee_gameplay_enabled(gameplay_active and input_enabled)
	if gameplay_active and input_enabled and phase in [PHASE_GUIDED, PHASE_PRACTICE, PHASE_RETEST]:
		_poll_direction_input()
	_advance_session(delta, gameplay_active)
	_update_interface()
	queue_redraw()

func _advance_session(delta: float, gameplay_active: bool) -> void:
	if _settled or delta <= 0.0:
		return
	hard_elapsed_seconds += delta
	if hard_elapsed_seconds >= HARD_LIMIT_SECONDS:
		_finish(_incomplete_result())
		return
	if not gameplay_active:
		return
	phase_active_seconds += delta
	match phase:
		PHASE_DEMONSTRATION:
			if phase_active_seconds >= DEMONSTRATION_SECONDS:
				_begin_guided_imitation()
		PHASE_GUIDED:
			if phase_active_seconds >= GUIDED_MAX_SECONDS:
				_begin_unprompted_practice()
			else:
				_advance_encounter(delta)
		PHASE_PRACTICE:
			if phase_active_seconds >= PRACTICE_MAX_SECONDS:
				_finish(_incomplete_result())
			else:
				_advance_encounter(delta)
		PHASE_DELAY:
			delay_active_seconds += delta
			_advance_pollen_route(delta)
			if delay_active_seconds >= DELAY_ACTIVE_SECONDS:
				_begin_unprompted_retest()
		PHASE_RETEST:
			_advance_encounter(delta)

func _advance_encounter(delta: float) -> void:
	if _encounter_recovery_seconds > 0.0:
		_encounter_recovery_seconds = maxf(0.0, _encounter_recovery_seconds - delta)
		if _encounter_recovery_seconds <= 0.0:
			_start_encounter()
		return
	var event: Dictionary = encounter.advance(delta, bee.position, bee.evade_sequence)
	match String(event.kind):
		"locked":
			input_controller.clear(bee)
		"crossed":
			var success := Rules.cleared_locked_path(
				bee,
				Vector2(event.aim_direction),
				Vector2(event.locked_target),
				int(event.evade_sequence_at_lock)
			)
			var attempted := bool(event.evade_attempted) or bee.evade_sequence > int(event.evade_sequence_at_lock)
			_resolve_current_encounter(success, attempted)
		"expired":
			_resolve_current_encounter(false, bool(event.evade_attempted))

func _start_encounter() -> void:
	_encounter_recovery_seconds = 0.0
	input_controller.clear(bee)
	encounter.begin(bee.position, bee.evade_sequence)
	_last_encounter_signature = encounter.config_signature()

func _schedule_encounter() -> void:
	input_controller.clear(bee)
	encounter.state = B01EvadeEncounter.STATE_IDLE
	_encounter_recovery_seconds = ENCOUNTER_RECOVERY_SECONDS

func _resolve_current_encounter(success: bool, attempted: bool) -> void:
	if _settled or phase not in [PHASE_GUIDED, PHASE_PRACTICE, PHASE_RETEST]:
		return
	_any_player_attempt = _any_player_attempt or attempted
	match phase:
		PHASE_GUIDED:
			guided_attempts += 1
			if success or guided_attempts >= GUIDED_MAX_ATTEMPTS:
				_begin_unprompted_practice()
			else:
				_schedule_encounter()
		PHASE_PRACTICE:
			practice_attempts += 1
			if success:
				_begin_active_delay_route()
			elif practice_attempts >= PRACTICE_MAX_ATTEMPTS:
				_finish(_incomplete_result())
			else:
				_schedule_encounter()
		PHASE_RETEST:
			if success:
				_finish(RESULT_COMPLETED)
			elif attempted:
				_finish(RESULT_INCOMPLETE)
			else:
				_finish(RESULT_NOT_ATTEMPTED)

func _begin_demonstration() -> void:
	phase = PHASE_DEMONSTRATION
	phase_active_seconds = 0.0
	input_enabled = false
	if bee != null:
		bee.visible = false
	_show_instruction("老师傅示范：红线先跟随；变成实线后路线不再改变。此时同一方向连按两次，离开冲刺锁定的旧位置。")
	_status_label.text = "示范"

func _begin_guided_imitation() -> void:
	phase = PHASE_GUIDED
	phase_active_seconds = 0.0
	guided_attempts = 0
	input_enabled = true
	bee.visible = true
	_show_instruction("等红线变亮并停住，再沿亮色侧标同向连按两次。")
	_status_label.text = "跟随示范"
	_start_encounter()

func _begin_unprompted_practice() -> void:
	phase = PHASE_PRACTICE
	phase_active_seconds = 0.0
	practice_attempts = 0
	input_enabled = true
	_hide_instruction()
	_status_label.text = ""
	_schedule_encounter()

func _begin_active_delay_route() -> void:
	phase = PHASE_DELAY
	phase_active_seconds = 0.0
	delay_active_seconds = 0.0
	_route_target_index = 0
	input_enabled = true
	encounter.state = B01EvadeEncounter.STATE_IDLE
	_encounter_recovery_seconds = 0.0
	input_controller.clear(bee)
	_hide_instruction()
	_status_label.text = "花间飞行"

func _begin_unprompted_retest() -> void:
	if _settled or retest_opportunities > 0:
		return
	phase = PHASE_RETEST
	phase_active_seconds = 0.0
	retest_opportunities = 1
	input_enabled = true
	_hide_instruction()
	_status_label.text = ""
	# The 180-second interference route is allowed to exhaust ordinary flight
	# resources, but it must not silently invalidate the one measured evade.
	# Restore only the action resources; attack timing and input grammar stay exact.
	bee.energy = bee.max_energy
	bee.evade_time = 0.0
	bee.evade_cooldown = 0.0
	bee.invulnerable_time = 0.0
	bee.clear_evade_first_tap()
	_start_encounter()

func _advance_pollen_route(delta: float) -> void:
	if bee == null:
		return
	bee.energy = minf(bee.max_energy, bee.energy + 4.0 * delta)
	var target := POLLEN_POINTS[_route_target_index]
	if bee.position.distance_to(target) <= 44.0:
		_route_target_index = (_route_target_index + 1) % POLLEN_POINTS.size()

func _show_instruction(text: String) -> void:
	current_instruction = text
	teaching_display_count += 1
	if _instruction_panel != null:
		_instruction_panel.visible = true
		_instruction_label.text = text

func _hide_instruction() -> void:
	current_instruction = ""
	if _instruction_panel != null:
		_instruction_panel.visible = false
		_instruction_label.text = ""

func _finish(outcome: String) -> void:
	if _settled or outcome not in [RESULT_COMPLETED, RESULT_INCOMPLETE, RESULT_NOT_ATTEMPTED]:
		return
	_settled = true
	result_code = outcome
	phase = PHASE_COMPLETE
	input_enabled = false
	input_controller.clear(bee)
	if bee != null:
		_set_bee_gameplay_enabled(false)
	set_process_unhandled_input(false)
	if _music != null:
		_music.stop()
	_hide_instruction()
	_status_label.text = ""
	_pause_panel.visible = false
	_end_panel.visible = true

func _incomplete_result() -> String:
	return RESULT_INCOMPLETE if _any_player_attempt else RESULT_NOT_ATTEMPTED

func _poll_direction_input() -> void:
	var directions := {
		"left": "move_left",
		"right": "move_right",
		"up": "move_up",
		"down": "move_down",
	}
	var pressed: Array[String] = []
	for direction_key in directions:
		if Input.is_action_just_pressed(String(directions[direction_key])):
			pressed.append(String(direction_key))
	if pressed.is_empty():
		return
	var result := input_controller.process_pressed_directions(
		pressed,
		Time.get_ticks_msec() / 1000.0,
		bee,
		encounter.aim_direction
	)
	_consume_evade_input(result)

func _unhandled_input(event: InputEvent) -> void:
	if not _configured or _settled:
		return
	if event.is_action_pressed("ui_cancel"):
		_toggle_pause()
		get_viewport().set_input_as_handled()
		return
	if not input_enabled or not _gameplay_is_active():
		return
	var point := Vector2.ZERO
	var pressed := false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		point = event.position
		pressed = event.pressed
	elif event is InputEventScreenTouch:
		point = event.position
		pressed = event.pressed
	if not pressed:
		return
	var evade_allowed := phase in [PHASE_GUIDED, PHASE_PRACTICE, PHASE_RETEST]
	var result := input_controller.handle_world_tap(
		point,
		Time.get_ticks_msec() / 1000.0,
		bee,
		WORLD,
		evade_allowed
	)
	_consume_evade_input(result)
	if bool(result.consumed):
		get_viewport().set_input_as_handled()

func _consume_evade_input(result: Dictionary) -> void:
	if bool(result.get("evade_attempted", false)):
		# Only an input committed after the attack locks is a measured attempt.
		# Early input remains visible movement but cannot change the outcome label.
		if encounter.mark_evade_attempted():
			_any_player_attempt = true

func _toggle_pause() -> void:
	var tree := get_tree()
	tree.paused = not tree.paused
	_pause_panel.visible = tree.paused
	if tree.paused:
		input_controller.clear(bee)
		_set_bee_gameplay_enabled(false)
	else:
		_set_bee_gameplay_enabled(_focus_active and input_enabled)

func _gameplay_is_active() -> bool:
	return _focus_active and not get_tree().paused and not _settled

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_set_focus_active(false)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_set_focus_active(true)

func _set_focus_active(active: bool) -> void:
	if _focus_active == active:
		return
	_focus_active = active
	if bee == null:
		return
	input_controller.clear(bee)
	_set_bee_gameplay_enabled(active and input_enabled and not get_tree().paused and not _settled)
	if _music != null:
		_music.stream_paused = not active
	# Losing focus before a retest route commits cannot consume the only measured
	# opportunity. Restart the same configuration from aim with clean input.
	if not active and phase == PHASE_RETEST and encounter.state in [B01EvadeEncounter.STATE_AIM, B01EvadeEncounter.STATE_LOCKED]:
		encounter.restart_aim(bee.position, bee.evade_sequence)

func _set_bee_gameplay_enabled(enabled: bool) -> void:
	if bee == null:
		return
	bee.active = enabled
	# Focus loss does not pause the SceneTree, so active=false alone would still
	# tick cooldowns and braking. Disable the player's physics callback as the
	# explicit freeze gate; the ALWAYS root alone keeps the hard clock alive.
	bee.set_physics_process(enabled)

func _on_music_finished() -> void:
	if not _settled and _music != null:
		_music.play()

func _update_interface() -> void:
	if _timer_label == null:
		return
	var remaining := maxi(0, int(ceil(HARD_LIMIT_SECONDS - hard_elapsed_seconds)))
	_timer_label.text = "%02d:%02d" % [remaining / 60, remaining % 60]

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(1280.0, 720.0)), Color("0f1117"))
	draw_texture_rect_region(
		FIELD_TEXTURE,
		WORLD,
		cover_source_region(FIELD_TEXTURE.get_size(), WORLD.size),
		Color(0.82, 0.88, 0.72, 0.92)
	)
	draw_rect(WORLD, Color("f1d46d66"), false, 3.0)
	for point in POLLEN_POINTS:
		draw_texture_rect(FLOWER_TEXTURE, Rect2(point - Vector2(34.0, 34.0), Vector2(68.0, 68.0)), false, Color(1.0, 1.0, 1.0, 0.82))
	if phase == PHASE_DELAY:
		_draw_pollen_route()
	elif phase == PHASE_DEMONSTRATION:
		_draw_demonstration()
	elif phase in [PHASE_GUIDED, PHASE_PRACTICE, PHASE_RETEST]:
		_draw_encounter()

func _draw_pollen_route() -> void:
	var target := POLLEN_POINTS[_route_target_index]
	var pulse := 30.0 + sin(Time.get_ticks_msec() * 0.008) * 5.0
	draw_arc(target, pulse, 0.0, TAU, 32, Color("f4d36fb8"), 4.0)
	for point in POLLEN_POINTS:
		for mote_index in 4:
			var angle := float(mote_index) * TAU / 4.0 + delay_active_seconds * 0.35
			draw_circle(point + Vector2.from_angle(angle) * 46.0, 3.0, Color("f6df88a8"))

func _draw_demonstration() -> void:
	var progress := clampf(phase_active_seconds / DEMONSTRATION_SECONDS, 0.0, 1.0)
	var old_position := Vector2(560.0, 405.0)
	var attacker_start := Vector2(790.0, 365.0)
	var attack_direction := (old_position - attacker_start).normalized()
	var mentor_position := old_position
	if progress >= 0.50:
		mentor_position += attack_direction.orthogonal() * lerpf(0.0, 88.0, clampf((progress - 0.50) / 0.20, 0.0, 1.0))
	var attacker_position := attacker_start
	if progress >= 0.68:
		attacker_position = attacker_start.lerp(old_position + attack_direction * 150.0, clampf((progress - 0.68) / 0.25, 0.0, 1.0))
	if progress < 0.30:
		draw_dashed_line(attacker_start, old_position, Color("d95d5488"), 3.0, 12.0)
	else:
		var geometry := Rules.committed_corridor_geometry(attacker_start, attack_direction, WORLD, Rules.PATH_CLEARANCE)
		_draw_corridor(geometry, 0.28)
	_draw_mosquito(attacker_position, attack_direction, progress >= 0.68)
	_draw_mentor_bee(mentor_position, Vector2.UP if progress >= 0.50 else attack_direction)
	_draw_demo_double_tap_cues(mentor_position, attack_direction.orthogonal(), progress)
	if progress >= 0.82:
		draw_arc(old_position, 44.0, 0.0, TAU, 28, Color("f4d36f"), 4.0)

func _draw_encounter() -> void:
	if encounter.state == B01EvadeEncounter.STATE_IDLE:
		return
	if encounter.state == B01EvadeEncounter.STATE_AIM:
		draw_dashed_line(encounter.attacker_position, bee.position, Color("d95d5499"), 3.0, 12.0)
	else:
		var geometry := Rules.committed_corridor_geometry(encounter.locked_origin, encounter.aim_direction, WORLD, Rules.PATH_CLEARANCE)
		_draw_corridor(geometry, 0.34)
	if phase == PHASE_GUIDED and encounter.state in [B01EvadeEncounter.STATE_LOCKED, B01EvadeEncounter.STATE_DASH]:
		for direction in escape_directions_for(encounter.locked_target, encounter.aim_direction):
			_draw_escape_arrow(encounter.locked_target, direction)
	_draw_mosquito(encounter.attacker_position, encounter.aim_direction, encounter.state == B01EvadeEncounter.STATE_DASH)
	draw_circle(encounter.attacker_position, 34.0, Color("d95d5448"), false, 3.0)

func _draw_corridor(geometry: Dictionary, alpha: float) -> void:
	if not bool(geometry.get("valid", false)):
		return
	var polygon: PackedVector2Array = geometry.polygon
	draw_colored_polygon(polygon, Color(0.85, 0.25, 0.24, alpha * 0.32))
	draw_line(Vector2(geometry.start), Vector2(geometry.finish), Color(0.91, 0.34, 0.31, alpha + 0.34), 4.0)

func _draw_escape_arrow(origin: Vector2, direction: Vector2) -> void:
	var geometry := escape_arrow_geometry(origin, direction)
	if not bool(geometry.get("valid", false)):
		return
	draw_line(Vector2(geometry.start), Vector2(geometry.finish), Color("f4d36f"), 5.0)
	draw_line(Vector2(geometry.finish), Vector2(geometry.head_a), Color("f4d36f"), 5.0)
	draw_line(Vector2(geometry.finish), Vector2(geometry.head_b), Color("f4d36f"), 5.0)

static func cover_source_region(source_size: Vector2, destination_size: Vector2) -> Rect2:
	if source_size.x <= 0.0 or source_size.y <= 0.0 or destination_size.x <= 0.0 or destination_size.y <= 0.0:
		return Rect2()
	var cover_scale := maxf(destination_size.x / source_size.x, destination_size.y / source_size.y)
	var visible_size := destination_size / cover_scale
	return Rect2((source_size - visible_size) * 0.5, visible_size)

static func escape_arrow_geometry(origin: Vector2, direction: Vector2) -> Dictionary:
	var normalized := direction.normalized()
	if normalized.length_squared() < 0.01:
		return {"valid": false}
	var available := INF
	if normalized.x > 0.001:
		available = minf(available, (BEE_CENTER_BOUNDS.end.x - origin.x) / normalized.x)
	elif normalized.x < -0.001:
		available = minf(available, (BEE_CENTER_BOUNDS.position.x - origin.x) / normalized.x)
	if normalized.y > 0.001:
		available = minf(available, (BEE_CENTER_BOUNDS.end.y - origin.y) / normalized.y)
	elif normalized.y < -0.001:
		available = minf(available, (BEE_CENTER_BOUNDS.position.y - origin.y) / normalized.y)
	var finish_distance := minf(86.0, available)
	if finish_distance < Rules.PATH_CLEARANCE + 1.0:
		return {"valid": false}
	var start_distance := minf(34.0, finish_distance * 0.46)
	var head_length := minf(18.0, maxf(9.0, (finish_distance - start_distance) * 0.44))
	var start := origin + normalized * start_distance
	var finish := origin + normalized * finish_distance
	var side := normalized.orthogonal() * minf(9.0, head_length * 0.5)
	return {
		"valid": true,
		"start": start,
		"finish": finish,
		"head_a": finish - normalized * head_length + side,
		"head_b": finish - normalized * head_length - side,
	}

static func escape_directions_for(target: Vector2, attack_direction: Vector2) -> Array[Vector2]:
	# Rect2.has_point excludes its end edge while BeePlayer's physical clamp is
	# inclusive. A sub-pixel expansion makes both representations agree without
	# moving the bee or changing the shared 36px causal clearance.
	return Rules.cardinal_escape_directions(target, attack_direction, BEE_CENTER_BOUNDS.grow(0.01))

func _draw_mentor_bee(position: Vector2, facing_direction: Vector2) -> void:
	var facing := facing_direction.angle() if facing_direction.length_squared() > 0.01 else 0.0
	draw_set_transform(position, facing, Vector2(0.82, 0.82))
	draw_texture_rect(MENTOR_TEXTURE, Rect2(-41.0, -30.0, 82.0, 60.0), false, Color("d6ddd7"))
	# Match the established mentor silhouette: an indigo wing binding and one
	# silver knot distinguish the elder without inventing another costume style.
	draw_line(Vector2(-10.0, -13.0), Vector2(11.0, 13.0), Color("47517f"), 5.0)
	draw_circle(Vector2(-16.0, -17.0), 4.0, Color("c8d0d2"))
	draw_set_transform(Vector2.ZERO)

func _draw_mosquito(position: Vector2, attack_direction: Vector2, dashing: bool) -> void:
	var direction := attack_direction.normalized()
	if dashing and direction.length_squared() > 0.01:
		draw_line(position - direction * 92.0, position - direction * 18.0, Color("f4d994d0"), 7.0)
	draw_set_transform(position, direction.angle() if direction.length_squared() > 0.01 else 0.0)
	draw_texture_rect(MOSQUITO_TEXTURE, Rect2(-34.0, -24.0, 68.0, 48.0), false, Color.WHITE)
	draw_set_transform(Vector2.ZERO)

func _draw_demo_double_tap_cues(position: Vector2, escape_direction: Vector2, progress: float) -> void:
	if progress < 0.43 or progress > 0.78:
		return
	var direction := escape_direction.normalized()
	if direction.length_squared() < 0.01:
		return
	var side := direction.orthogonal()
	for beat_index in 2:
		var beat_start := 0.43 + float(beat_index) * 0.10
		var beat_progress := clampf((progress - beat_start) / 0.10, 0.0, 1.0)
		if beat_progress <= 0.0:
			continue
		var tip := position + direction * (44.0 + float(beat_index) * 22.0)
		var color := Color("f4d36f", 0.30 + beat_progress * 0.68)
		draw_line(tip - direction * 16.0 + side * 8.0, tip, color, 5.0)
		draw_line(tip - direction * 16.0 - side * 8.0, tip, color, 5.0)
		draw_arc(position, 31.0 + float(beat_index) * 8.0, -0.42, 0.42, 12, color, 3.0)

func _has_exact_keys(value: Dictionary, expected: Array) -> bool:
	var actual: Array[String] = []
	for key in value.keys():
		actual.append(String(key))
	actual.sort()
	var normalized: Array[String] = []
	for key in expected:
		normalized.append(String(key))
	normalized.sort()
	return actual == normalized

func _matches(value: String, expression: String) -> bool:
	var pattern := RegEx.new()
	return pattern.compile(expression) == OK and pattern.search(value) != null

func _is_json_integer(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	if typeof(value) != TYPE_FLOAT:
		return false
	var number := float(value)
	return is_finite(number) and number == floor(number)
