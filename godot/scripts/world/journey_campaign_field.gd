class_name JourneyCampaignField
extends JourneySeasonalFieldBase

## Shared large-map runtime for the twenty-four authored levels. The catalog
## supplies goals and prose; this scene turns each work type into a concrete,
## multi-step interaction and gives every intra-season map a different route.

signal attempt_failed(reason: String, snapshot: Dictionary)

const CARGO_CAPACITY := 4
const INTERACTION_RADIUS := 92.0
const OBSERVE_SECONDS := 1.15
const CLIMAX_INTERMISSION := 1.8
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


func configure(context: Dictionary) -> Error:
	var configured_level = context.get("level", {})
	if not configured_level is Dictionary or String(configured_level.get("id", "")).is_empty():
		return ERR_INVALID_DATA
	level = (configured_level as Dictionary).duplicate(true)
	run_mode = String(context.get("run_mode", "progression"))
	return super.configure(context)


func _ready() -> void:
	super._ready()
	_load_campaign_art()
	if bee != null:
		# The formal maps are several times larger than the vertical slice. Energy
		# remains a route-planning pressure, not a twenty-second hidden timer.
		bee.max_energy = 360.0
		bee.energy = bee.max_energy
		bee.configure(float(level.get("energy_drain", 0.82)) * 0.20)
		bee.dash_cost_multiplier = 0.04
	_emit_status()
	queue_redraw()


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
	playable_bounds = Rect2(35.0, 125.0, 3505.0, 1815.0)
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
	if is_climax:
		_build_climax_tasks()
	else:
		_build_standard_tasks()


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
	if elapsed >= time_limit_seconds:
		_fail_attempt("这趟的天气窗口合上了。回巢理一理路线，再飞一次就好。")
		return
	hazard_active = fmod(elapsed + float(map_variant) * 0.73, 8.5) < (2.2 if not is_climax else 3.1)
	var sheltered := _is_sheltered(bee.position)
	if hazard_active and _in_hazard_band(bee.position) and not sheltered:
		bee.environment_speed_multiplier = 0.70 if not is_climax else 0.61
		bee.energy = maxf(0.0, bee.energy - delta * (0.45 if not is_climax else 0.75))
	else:
		bee.environment_speed_multiplier = 1.0
	for rest_point in rest_points:
		if bee.position.distance_to(rest_point) <= 105.0:
			bee.energy = minf(bee.max_energy, bee.energy + 26.0 * delta)
	if bee.energy <= 0.01:
		bee.environment_speed_multiplier = minf(bee.environment_speed_multiplier, 0.46)
		message = "翅膀累了。沿叶棚慢慢飞，歇脚点会把力气接回来。"
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


func _update_moving_tasks() -> void:
	for index in tasks.size():
		var task := tasks[index]
		if bool(task.resolved) or not _task_is_active(task) or String(task.type) != "frighten":
			continue
		var origin := Vector2(task.origin)
		task.position = origin + Vector2(sin(elapsed * 1.45 + index) * 135.0, cos(elapsed * 1.1 + index) * 88.0)
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
	if carried_task_index >= 0:
		var carried_task := tasks[carried_task_index]
		if bee.position.distance_to(Vector2(carried_task.position)) <= INTERACTION_RADIUS:
			_resolve_task(carried_task_index, _delivery_message(String(carried_task.type)), _cue_for_type(String(carried_task.type)))
			carried_task_index = -1
			bee.set_visual_load_ratio(float(collected_cargo) / float(CARGO_CAPACITY))
			if is_climax and _active_phase_tasks_complete() and collected_cargo == 0:
				_complete_current_phase()
		else:
			message = "这件还在身上。发亮的对应工位在另一头，先送稳再接下一件。"
		return
	var source_index := _nearest_source_task()
	if source_index >= 0:
		_pick_up_task(source_index)
		return
	var target_index := _nearest_target_task()
	if target_index < 0:
		bee.trigger_sense()
		message = "附近没有正等着处理的活。波纹会指出当前路线。"
		return
	var task := tasks[target_index]
	match String(task.type):
		"observe":
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
				bee.set_visual_load_ratio(float(collected_cargo) / float(CARGO_CAPACITY))
		"repair", "shell", "anchor":
			_step_task(target_index)
		"frighten":
			_resolve_task(target_index, "震翼声一到，它松开手里的东西，去旁边草茎歇着了。", "evade")
		_:
			_resolve_task(target_index, "这一处收好了。", _cue_for_type(String(task.type)))


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
	return not is_climax or int(task.phase_index) == phases_completed


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
	bee.set_visual_load_ratio(0.0 if carried_task_index < 0 else 0.72)
	if sound != null:
		sound.play_cue("handoff")
	if is_climax and _active_phase_tasks_complete() and carried_task_index < 0:
		_complete_current_phase()


func _finish_level() -> void:
	if completion_emitted:
		return
	message = String(level.get("dialogue", "接货蜂：回来啦，这一趟收得很稳。"))
	_complete_journey({
		"level_id": level_id,
		"objectives_complete": true,
		"returned_home": true,
		"objective_counts": objective_counts.duplicate(),
		"phases_completed": phases_completed,
		"elapsed_seconds": elapsed,
		"energy_remaining": bee.energy,
		"actions": action_count,
		"failed": false,
	})


func _fail_attempt(reason: String) -> void:
	if failed or completion_emitted:
		return
	failed = true
	completion_emitted = true
	bee.active = false
	message = reason
	attempt_failed.emit(reason, status_snapshot())


func _handle_secondary_action() -> void:
	bee.set_move_target(home_position)
	message = "沿亮着的巢门回去。身上的东西和蜜囊都会跟你一起走。"


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
		"repair", "shell", "anchor": return "repair"
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
	if phase_intermission > 0.0:
		return "大家正在换位"
	if carried_task_index >= 0 and carried_task_index < tasks.size():
		var carried_task := tasks[carried_task_index]
		if bee.position.distance_to(Vector2(carried_task.position)) <= INTERACTION_RADIUS:
			return "放进对应工位"
		return "查看送达花标"
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
	return "看看最近花标"


func _return_label() -> String:
	return "回巢交接" if _all_work_complete() else "指路回巢"


func status_snapshot() -> Dictionary:
	var snapshot := _base_snapshot()
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
		"carried": collected_cargo + (1 if carried_task_index >= 0 else 0),
		"honey_cargo": collected_cargo,
		"capacity": CARGO_CAPACITY,
		"delivered_cargo": delivered_cargo,
		"has_collection": has_collection,
		"time_remaining": maxf(0.0, time_limit_seconds - elapsed),
		"hazard_active": hazard_active,
		"sheltered": _is_sheltered(bee.position) if bee != null else false,
		"ready_to_return": _all_work_complete(),
		"phase_instruction": _current_phase_instruction() if is_climax else "",
		"action_label": _action_label(),
		"action_enabled": not failed and phase_intermission <= 0.0,
		"return_label": _return_label(),
		"failed": failed,
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
		draw_circle(point, 10.0, colors[2], true)
		draw_arc(point, 13.0, 0.0, TAU, 16, Color("fff0c1", 0.86), 2.0)
		# One notch per completed level keeps every durable trace countable in the
		# world without turning the field into a text ledger.
		draw_line(point, point + Vector2.from_angle(float(index % 6) / 6.0 * TAU) * 9.0, Color("6c5136"), 2.0)


func _draw_chapter() -> void:
	_draw_rest_points()
	_draw_tasks()
	_draw_route_pointer()
	_draw_climax_neighbour()
	if hazard_active:
		_draw_weather_motion()


func _draw_rest_points() -> void:
	for point in rest_points:
		draw_circle(point, 56.0, Color("f3e7ad", 0.13))
		draw_arc(point, 35.0, -PI, 0.0, 14, Color("f5e8ac", 0.78), 7.0)
		draw_line(point + Vector2(-34, 3), point + Vector2(34, 3), Color("7b6545", 0.76), 6.0)
		draw_circle(point + Vector2(-26, -13), 6.0, Color("91a85f", 0.82))
		draw_circle(point + Vector2(25, -17), 7.0, Color("91a85f", 0.82))


func _draw_tasks() -> void:
	for index in tasks.size():
		var task := tasks[index]
		if not _task_is_active(task):
			continue
		var work_type := String(task.type)
		var color: Color = TYPE_COLORS.get(work_type, accent_color)
		if bool(task.resolved):
			_draw_task_marker(Vector2(task.position), work_type, color.darkened(0.18), false, int(task.hits), true)
			continue
		if work_type in TWO_STEP_TYPES and int(task.state) == 0:
			_draw_task_marker(Vector2(task.source_position), work_type, color.lightened(0.14), true, int(task.hits), false)
		_draw_task_marker(Vector2(task.position), work_type, color, false, int(task.hits), false)
	if carried_task_index >= 0 and carried_task_index < tasks.size():
		var destination := Vector2(tasks[carried_task_index].position)
		draw_dashed_line(bee.position, destination, Color("fff1aa", 0.66), 4.0, 24.0)


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
	if carried_task_index >= 0 and carried_task_index < tasks.size():
		return Vector2(tasks[carried_task_index].position)
	if _all_work_complete():
		return home_position
	var nearest := bee.position
	var nearest_distance := INF
	for task in tasks:
		if bool(task.resolved) or not _task_is_active(task):
			continue
		var target_position := Vector2(task.position)
		if String(task.type) in TWO_STEP_TYPES and int(task.state) == 0:
			target_position = Vector2(task.source_position)
		var distance := bee.position.distance_to(target_position)
		if distance < nearest_distance:
			nearest = target_position
			nearest_distance = distance
	return nearest


func _draw_route_pointer() -> void:
	if bee == null:
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
	if climax_neighbour_texture != null:
		var texture_size := climax_neighbour_texture.get_size()
		var frame_width := texture_size.x / 3.0
		var frame_index := mini(2, phases_completed)
		var destination_size := Vector2(210.0, 150.0)
		if season_id == "summer": destination_size = Vector2(245.0, 176.0)
		elif season_id == "autumn": destination_size = Vector2(225.0, 158.0)
		elif season_id == "winter": destination_size = Vector2(240.0, 170.0)
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
