class_name ConscriptionMechanic
extends RefCounted
## 夏 · 实体袭扰。
## 第一批花蜜真正卸入蜂巢后，袭扰者从花田外缘进入并扑向仍有蜜的花。
## 它们逐滴取走真实花蜜；玩家必须中断下一条采集路线，飞去惊退它们。

var mechanic_id := "conscription"
var main
var state := "waiting_for_deposit" # waiting_for_deposit / active / cleared
var kind := "field"
var first_deposit_seen := false
var raid_ants: Array = []
var raider_count := 3
var raider_speed := 92.0
var steal_interval := 0.75
var steal_range := 23.0
var raid_capacity := 2
var goal_margin := 3
var repel_range_bonus := 18.0
var original_goal := -1
var goal_extended := false
var configured_stage_index := -1
var event_latch_time := 0.0
var event_kind := ""
var transfer_effects: Array = []
const EVENT_LATCH_SECONDS := 1.5
const TRANSFER_SECONDS := 0.72


func start(game, data: Dictionary, balance: Dictionary) -> void:
	main = game
	var mechanics: Dictionary = balance.get("mechanics", {})
	var params: Dictionary = mechanics.get("conscription", {})
	raider_count = int(params.get("raider_count", 3))
	raider_speed = float(params.get("raider_speed", 92.0))
	steal_interval = float(params.get("steal_interval", 0.75))
	steal_range = float(params.get("steal_range", 23.0))
	raid_capacity = int(params.get("raid_capacity", 2))
	goal_margin = int(params.get("goal_margin", 3))
	repel_range_bonus = float(params.get("repel_range_bonus", 18.0))
	state = "waiting_for_deposit"
	kind = "field"
	first_deposit_seen = false
	raid_ants.clear()
	original_goal = int(data.get("goal", -1))
	goal_extended = false
	configured_stage_index = int(main.stage_index)
	event_latch_time = 0.0
	event_kind = ""
	transfer_effects.clear()


func process(delta: float) -> void:
	event_latch_time = maxf(0.0, event_latch_time - delta)
	if event_latch_time <= 0.0:
		event_kind = ""
	for effect_index in range(transfer_effects.size() - 1, -1, -1):
		var effect: Dictionary = transfer_effects[effect_index]
		effect["life"] = float(effect.get("life", TRANSFER_SECONDS)) - delta
		if float(effect.life) <= 0.0:
			transfer_effects.remove_at(effect_index)
		else:
			transfer_effects[effect_index] = effect
	if state != "active":
		return
	for i in range(raid_ants.size() - 1, -1, -1):
		var raider: Dictionary = raid_ants[i]
		var raider_state := String(raider.get("state", "approach"))
		if raider_state == "escape":
			var escape_direction: Vector2 = Vector2(raider.get("escape_direction", Vector2.RIGHT))
			raider["position"] = Vector2(raider.position) + escape_direction * raider_speed * 1.35 * delta
			raid_ants[i] = raider
			var escape_position := Vector2(raider.position)
			if (
				escape_position.x >= main.WORLD.end.x - 8.0
				or escape_position.x <= main.WORLD.position.x + 8.0
				or escape_position.y <= main.WORLD.position.y + 8.0
				or escape_position.y >= main.WORLD.end.y - 8.0
			):
				raid_ants.remove_at(i)
			continue
		if raider_state == "holding":
			# A full raider keeps the stolen nectar visible until the player
			# intervenes. Waiting is no longer an automatic solution.
			raid_ants[i] = raider
			continue

		var target_index := int(raider.get("target", -1))
		if not is_viable_target(target_index):
			var next_target := richest_target()
			if next_target >= 0:
				target_index = next_target
				raider["target"] = target_index
		if target_index < 0:
			raider["state"] = "holding"
			raid_ants[i] = raider
			continue
		if not is_viable_target(target_index):
			# Keep the last real flower index while holding stolen nectar. If every
			# flower is currently empty, repel can still return the exact resource.
			raider["state"] = "holding"
			raid_ants[i] = raider
			continue

		var target: Dictionary = main.flowers[target_index]
		var to_target := Vector2(target.position) - Vector2(raider.position)
		if to_target.length() > steal_range:
			raider["position"] = Vector2(raider.position) + to_target.normalized() * raider_speed * delta
		else:
			raider["steal_clock"] = float(raider.get("steal_clock", steal_interval)) - delta
			if float(raider.steal_clock) <= 0.0 and int(target.get("nectar", 0)) > 0:
				target["nectar"] = int(target.nectar) - 1
				main.flowers[target_index] = target
				raider["stolen"] = int(raider.get("stolen", 0)) + 1
				transfer_effects.append({
					"from": Vector2(target.position),
					"to": Vector2(raider.position),
					"life": TRANSFER_SECONDS,
					"duration": TRANSFER_SECONDS,
					"kind": "stolen"
				})
				raider["steal_clock"] = steal_interval
				main.spawn_pollen(Vector2(target.position))
				main.message = "花蜜正在被带走。"
				if int(raider.stolen) >= raid_capacity:
					raider["state"] = "holding"
		raid_ants[i] = raider

	if raid_ants.is_empty():
		state = "cleared"
		main.message = "袭扰退去。"


func on_home(amount: int, _delta: float) -> void:
	# amount 只有在 main 判定“站稳并实际卸蜜”的那一帧大于 0；擦过巢口不触发。
	if amount <= 0 or first_deposit_seen:
		return
	first_deposit_seen = true
	trigger_raid(amount)


func trigger_raid(deposit_amount: int = 0) -> void:
	if state == "active":
		return
	state = "active"
	kind = "field"
	raid_ants.clear()
	transfer_effects.clear()
	_latch_event("raid_enter")
	# 第一趟若足以碰到旧目标，当前关会在同一帧结算，玩家永远看不到袭扰。
	# 只为本关临时延长一个小回合，进入下一关前由 end() 恢复原数据。
	if original_goal > 0 and configured_stage_index >= 0 and configured_stage_index < main.stages.size():
		var stage: Dictionary = main.stages[configured_stage_index]
		stage["goal"] = maxi(original_goal, int(main.delivered) + deposit_amount + goal_margin)
		main.stages[configured_stage_index] = stage
		goal_extended = int(stage.goal) != original_goal
	var right_edge: float = main.WORLD.end.x - 18.0
	for i in raider_count:
		raid_ants.append({
			"position": Vector2(right_edge, 220.0 + float(i % 4) * 105.0),
			"target": richest_target(i),
			"state": "approach",
			"stolen": 0,
			"steal_clock": steal_interval,
			"escape_direction": Vector2.RIGHT
		})
	main.message = "袭扰从花田边缘出现。"


func richest_target(offset: int = 0) -> int:
	var candidates: Array[int] = []
	for i in main.flowers.size():
		if is_viable_target(i):
			candidates.append(i)
	if candidates.is_empty():
		return -1
	candidates.sort_custom(func(a: int, b: int) -> bool:
		return int(main.flowers[a].nectar) > int(main.flowers[b].nectar)
	)
	return candidates[offset % candidates.size()]


func is_viable_target(index: int) -> bool:
	if index < 0 or index >= main.flowers.size():
		return false
	var flower: Dictionary = main.flowers[index]
	return (
		int(flower.get("nectar", 0)) > 0
		and not bool(flower.get("sleeping", false))
		and float(flower.get("flatten_time", 0.0)) <= 0.0
	)


func on_context_action() -> bool:
	return repel_nearest_raider()


func try_context_action(_position: Vector2) -> bool:
	return on_context_action()


func context_action_id(position: Vector2) -> String:
	if state == "active" and nearest_raider_at(position) >= 0:
		return "repel_raider"
	return ""


func latched_event() -> Dictionary:
	return {"id": event_kind, "remaining": event_latch_time}


func visual_profile() -> String:
	return "winged_raider"


func can_complete() -> bool:
	return first_deposit_seen and state != "active"


func hud_status() -> String:
	match state:
		"waiting_for_deposit":
			return "袭扰 · 待首批归巢"
		"active":
			return "惊退袭扰者 %d" % raid_ants.size()
		_:
			return "袭扰已清"


func is_flower_available(_index: int) -> bool:
	return true


func on_repel_success() -> void:
	repel_nearest_raider()


func repel_nearest_raider() -> bool:
	return repel_raider_at(main.bee.position)


func nearest_raider_at(position: Vector2) -> int:
	if state != "active":
		return -1
	var nearest := -1
	var nearest_distance := float(main.sting_range) + repel_range_bonus
	for i in raid_ants.size():
		var raider: Dictionary = raid_ants[i]
		if String(raider.get("state", "approach")) == "escape":
			continue
		var distance: float = position.distance_to(Vector2(raider.position))
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = i
	return nearest


func repel_raider_at(position: Vector2) -> bool:
	var nearest := nearest_raider_at(position)
	if nearest < 0:
		return false

	var raider: Dictionary = raid_ants[nearest]
	var stolen := int(raider.get("stolen", 0))
	var target_index := int(raider.get("target", -1))
	if (target_index < 0 or target_index >= main.flowers.size()) and not main.flowers.is_empty():
		var nearest_distance := INF
		for flower_index in main.flowers.size():
			var distance := Vector2(raider.position).distance_to(Vector2(main.flowers[flower_index].position))
			if distance < nearest_distance:
				nearest_distance = distance
				target_index = flower_index
	if stolen > 0 and target_index >= 0 and target_index < main.flowers.size():
		var flower: Dictionary = main.flowers[target_index]
		flower["nectar"] = int(flower.get("nectar", 0)) + stolen
		main.flowers[target_index] = flower
		for drop_index in stolen:
			transfer_effects.append({
				"from": Vector2(raider.position) + Vector2(float(drop_index - stolen / 2) * 6.0, -15.0),
				"to": Vector2(flower.position),
				"life": TRANSFER_SECONDS,
				"duration": TRANSFER_SECONDS,
				"kind": "returned"
			})
	elif stolen > 0:
		# Defensive fallback for dynamically removed flower lists. Recovery blooms
		# are part of the established honey-conservation path.
		main.return_honey_to_field(stolen, Vector2(raider.position))
	raider["stolen"] = 0
	raider["state"] = "escape"
	var away: Vector2 = Vector2(raider.position) - position
	raider["escape_direction"] = Vector2.RIGHT if away.length_squared() < 0.01 else away.normalized()
	raid_ants[nearest] = raider
	main.flash = maxf(float(main.flash), 0.22)
	main.message = "被夺的蜜落回花田。" if stolen > 0 else "袭扰者退出航线。"
	# Teaching and world feedback must distinguish a real recovered drop from an
	# early scare-off. Otherwise "repel immediately" would falsely teach return.
	_latch_event("honey_return" if stolen > 0 else "raider_repelled")
	return true


func _latch_event(id: String) -> void:
	event_kind = id
	event_latch_time = EVENT_LATCH_SECONDS


func draw() -> void:
	for effect in transfer_effects:
		var duration := maxf(0.01, float(effect.get("duration", TRANSFER_SECONDS)))
		var progress := 1.0 - clampf(float(effect.get("life", 0.0)) / duration, 0.0, 1.0)
		var from := Vector2(effect.get("from", Vector2.ZERO))
		var to := Vector2(effect.get("to", from))
		var pos := from.lerp(to, progress)
		pos.y -= sin(progress * PI) * 22.0
		var drop_color := Color("fff0a0") if String(effect.get("kind", "")) == "returned" else Color("e6b849")
		main.draw_circle(pos, 5.0, drop_color)
		main.draw_line(pos + Vector2(0, -5), pos + Vector2(2, -9), Color(drop_color, 0.62), 2.0)
	if state == "active":
		for raider in raid_ants:
			_draw_raider(raider)


func _draw_raider(raider: Dictionary) -> void:
	var pos := Vector2(raider.position)
	var escaping := String(raider.get("state", "approach")) == "escape"
	var alpha := 0.5 if escaping else 1.0
	var body := Color("773a2e", alpha)
	var armor := Color("c55f42", alpha)
	# Large winged silhouette: three armored body plates, transparent wings,
	# hooked legs and a pale face mask keep it distinct from ordinary field ants.
	main.draw_colored_polygon(PackedVector2Array([
		pos + Vector2(-8, -4), pos + Vector2(-30, -22),
		pos + Vector2(-34, 2), pos + Vector2(-10, 7)
	]), Color("f0d7b2", 0.34 * alpha))
	main.draw_colored_polygon(PackedVector2Array([
		pos + Vector2(1, -5), pos + Vector2(22, -25),
		pos + Vector2(29, -1), pos + Vector2(7, 8)
	]), Color("f0d7b2", 0.34 * alpha))
	main.draw_circle(pos + Vector2(-13, 0), 10.0, body)
	main.draw_circle(pos, 12.5, armor)
	main.draw_circle(pos + Vector2(15, -1), 8.5, Color("3d2524", alpha))
	main.draw_line(pos + Vector2(18, -7), pos + Vector2(29, -17), body, 2.5)
	main.draw_line(pos + Vector2(18, 4), pos + Vector2(31, 11), body, 2.5)
	for side in [-1.0, 1.0]:
		main.draw_line(pos + Vector2(-5, 5 * side), pos + Vector2(-17, 16 * side), body, 3.0)
		main.draw_line(pos + Vector2(5, 5 * side), pos + Vector2(17, 17 * side), body, 3.0)
	var target_index := int(raider.get("target", -1))
	if not escaping and target_index >= 0 and target_index < main.flowers.size():
		main.draw_dashed_line(pos, Vector2(main.flowers[target_index].position), Color("c94c3f", 0.78), 3.0, 8.0)
	for drop in int(raider.get("stolen", 0)):
		var drop_pos := pos + Vector2(-6.0 + float(drop) * 12.0, -22.0)
		main.draw_circle(drop_pos, 5.0, Color("f2cf5b"))
		main.draw_line(drop_pos + Vector2(0, -4), drop_pos + Vector2(2, -8), Color("fff0a0"), 2.0)


func end() -> void:
	if goal_extended and original_goal > 0 and configured_stage_index >= 0 and configured_stage_index < main.stages.size():
		var stage: Dictionary = main.stages[configured_stage_index]
		stage["goal"] = original_goal
		main.stages[configured_stage_index] = stage
	raid_ants.clear()
	transfer_effects.clear()
	event_latch_time = 0.0
	event_kind = ""
