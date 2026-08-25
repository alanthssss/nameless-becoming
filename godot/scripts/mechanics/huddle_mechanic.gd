class_name HuddleMechanic
extends RefCounted
## 冬 · 热源接力。
## 冷区持续消耗体温并明确降低环境速度；玩家可把一滴携蜜留在沿路暖点，
## 激活新的恢复区。远花因此需要“短途采集 → 点亮中继 → 再向外”的路线。

var mechanic_id := "huddle"
var main
var warmth_drain := 5.0
var warm_zone_restore := 14.0
var hive_restore := 20.0
var warm_radius := 92.0
var activation_range := 54.0
var activation_honey_cost := 1
var cold_speed_multiplier := 0.72
var scout_reserve_threshold := 5
var sense_cooldown_scout := 4.0
var cold_warmth_threshold := 35.0
var scouting_unlocked := false
var warm_points: Array = []
var activated_points := 0
var flower_route: Array[int] = []
var _low_warned := false
var frost_level := 0.0


func start(game, _data: Dictionary, balance: Dictionary) -> void:
	main = game
	var mechanics: Dictionary = balance.get("mechanics", {})
	var params: Dictionary = mechanics.get("huddle", {})
	warmth_drain = float(params.get("warmth_drain", 5.0))
	warm_zone_restore = float(params.get("warm_zone_restore", 14.0))
	hive_restore = float(params.get("hive_restore", 20.0))
	warm_radius = float(params.get("warm_radius", 92.0))
	activation_range = float(params.get("activation_range", 54.0))
	activation_honey_cost = int(params.get("activation_honey_cost", 1))
	cold_speed_multiplier = float(params.get("cold_speed_multiplier", 0.72))
	scout_reserve_threshold = int(params.get("scout_reserve_threshold", 5))
	sense_cooldown_scout = float(params.get("sense_cooldown_scout", 4.0))
	cold_warmth_threshold = float(params.get("cold_warmth_threshold", 35.0))
	main.cold_warmth_threshold = cold_warmth_threshold
	if not main.preserve_warmth:
		main.warmth = 100.0
	main.bee.environment_speed_multiplier = 1.0
	_low_warned = false
	frost_level = 0.0
	activated_points = 0
	flower_route.clear()
	scouting_unlocked = main.hive_reserve >= scout_reserve_threshold
	build_warm_points()
	for flower_index in main.flowers.size():
		flower_route.append(flower_index)
	flower_route.sort_custom(func(a: int, b: int) -> bool:
		return Vector2(main.flowers[a].position).x < Vector2(main.flowers[b].position).x
	)

	# 秋季的幼虫投资仍兑现为冬季体力上限，但不替代热源路线。
	var reserve_params: Dictionary = mechanics.get("reserve", {})
	var larvae_per_boost := int(reserve_params.get("larvae_per_boost", 10))
	var boost_per_round := int(reserve_params.get("boost_energy_cap", 5))
	var bonus := int(main.larval_boost / maxi(larvae_per_boost, 1)) * boost_per_round
	main.energy_cap_override = main.bee.max_energy + float(bonus)
	if bonus > 0:
		main.bee.energy = main.energy_cap_override


func build_warm_points() -> void:
	warm_points.clear()
	var world: Rect2 = main.WORLD
	var x_span := world.size.x - 260.0
	for i in 3:
		var ratio := float(i + 1) / 4.0
		warm_points.append({
			"position": Vector2(world.position.x + 160.0 + x_span * ratio, world.position.y + 155.0 + float(i % 2) * 235.0),
			"active": false,
			"fuel": 0
		})


func process(delta: float) -> void:
	var in_hive: bool = main.is_in_hive_entry(main.bee.position)
	var point_index := active_warm_point_at(main.bee.position)
	if in_hive:
		main.warmth = minf(100.0, main.warmth + hive_restore * delta)
		main.bee.environment_speed_multiplier = 1.0
	elif point_index >= 0:
		main.warmth = minf(100.0, main.warmth + warm_zone_restore * delta)
		main.bee.environment_speed_multiplier = 1.0
	else:
		main.warmth = maxf(0.0, main.warmth - warmth_drain * delta)
		main.bee.environment_speed_multiplier = speed_for_warmth(main.warmth)
	frost_level = clampf((100.0 - main.warmth) / 100.0, 0.0, 1.0)

	if main.warmth <= cold_warmth_threshold and not _low_warned:
		_low_warned = true
		main.message = "霜纹压住翅缘。"
	elif main.warmth > cold_warmth_threshold + 12.0:
		_low_warned = false


func on_context_action() -> bool:
	var point_index := nearest_inactive_point_at(main.bee.position)
	if point_index < 0:
		return false
	if int(main.carried) < activation_honey_cost:
		main.message = "暖点需要一滴蜜。"
		# The relay owns this press so the generic router cannot reinterpret it as
		# sense. Held harvesting still runs independently when a real flower overlaps.
		return true
	main.carried -= activation_honey_cost
	var point: Dictionary = warm_points[point_index]
	point["active"] = true
	point["fuel"] = activation_honey_cost
	warm_points[point_index] = point
	activated_points += 1
	main.warmth = minf(100.0, main.warmth + warm_zone_restore * 0.5)
	main.flash = maxf(float(main.flash), 0.32)
	main.spawn_pollen(Vector2(point.position))
	main.message = "暖点亮起。"
	return true


func try_context_action(_position: Vector2) -> bool:
	return on_context_action()


func context_action_id(position: Vector2) -> String:
	if nearest_inactive_point_at(position) < 0:
		return ""
	if int(main.carried) < activation_honey_cost:
		return "warm_relay_needs_honey"
	return "light_warm_relay"


func can_complete() -> bool:
	return activated_points >= warm_points.size()


func hud_status() -> String:
	return "暖点 %d / %d" % [activated_points, warm_points.size()]


func is_flower_available(index: int) -> bool:
	# Honey committed to a decoy returns as a recovery bloom. It is already
	# player-owned resource, so the cold route must never strand it merely
	# because the bloom was created after this mechanic took its route snapshot.
	if index >= 0 and index < main.flowers.size() and bool(main.flowers[index].get("recovery", false)):
		return true
	if not flower_route.has(index):
		return false
	# Each lit relay opens the next quarter of the route. With the configured
	# goals and one-honey fuel cost, the player must build the whole chain, but
	# the rule is expressed by reachable flowers rather than an abstract gate.
	var segments := warm_points.size() + 1
	var unlocked_count := ceili(float(flower_route.size()) * float(activated_points + 1) / float(segments))
	return flower_route.find(index) < unlocked_count


func nearest_inactive_point() -> int:
	return nearest_inactive_point_at(main.bee.position)


func nearest_inactive_point_at(position: Vector2) -> int:
	var nearest := -1
	var nearest_distance := activation_range
	for i in warm_points.size():
		var point: Dictionary = warm_points[i]
		if bool(point.get("active", false)):
			continue
		if i > 0 and not bool(warm_points[i - 1].get("active", false)):
			continue
		var distance: float = position.distance_to(Vector2(point.position))
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = i
	return nearest


func active_warm_point_at(position: Vector2) -> int:
	for i in warm_points.size():
		var point: Dictionary = warm_points[i]
		if bool(point.get("active", false)) and position.distance_to(Vector2(point.position)) <= warm_radius:
			return i
	return -1


func is_scouting_ready() -> bool:
	return scouting_unlocked


func scout_cooldown_value() -> float:
	return sense_cooldown_scout


func current_speed_factor() -> float:
	return float(main.bee.environment_speed_multiplier)


func speed_for_warmth(value: float) -> float:
	# A full bee leaves the hive at normal speed. Cold becomes legible as a
	# gradual bodily change instead of an unexplained 28% movement penalty on the
	# very first frame outside the safe zone.
	var full_speed_warmth := maxf(cold_warmth_threshold + 35.0, 70.0)
	var ratio := inverse_lerp(cold_warmth_threshold, full_speed_warmth, clampf(value, cold_warmth_threshold, full_speed_warmth))
	# The exposed field retains a barely perceptible 2% headwind even while warm,
	# keeping the existing cold-zone contract without the old immediate 28% drag.
	return lerpf(cold_speed_multiplier, 0.98, ratio)


func visual_profile() -> String:
	return "wax_lamp_huddle"


func draw() -> void:
	for i in warm_points.size():
		var point: Dictionary = warm_points[i]
		var pos := Vector2(point.position)
		if bool(point.get("active", false)):
			var pulse := warm_radius + sin(main.elapsed * 2.6 + float(i)) * 5.0
			# A low, filled pool of amber is environmental warmth, not another
			# interactable ring. The wax lamp remains the readable object at its core.
			main.draw_circle(pos + Vector2(0, 10), pulse, Color("f4d893", 0.055))
			_draw_wax_lamp(pos, true)
		else:
			_draw_wax_lamp(pos, false)
	for flower_index in flower_route:
		if is_flower_available(flower_index):
			continue
		var frozen_position := Vector2(main.flowers[flower_index].position)
		# Frost clings to petals as shards; it no longer reads as a generic target arc.
		for shard_index in 5:
			var shard_angle := -PI * 0.88 + float(shard_index) * PI * 0.38
			var shard_root := frozen_position + Vector2.from_angle(shard_angle) * 22.0
			var shard_tip := frozen_position + Vector2.from_angle(shard_angle) * (28.0 + float(shard_index % 2) * 5.0)
			main.draw_line(shard_root, shard_tip, Color("b8d8e8", 0.72), 3.0)
			main.draw_line(shard_tip, shard_tip + Vector2.from_angle(shard_angle + 0.65) * 5.0, Color("d9eef7", 0.62), 1.5)
	if frost_level > 0.04:
		var bee_pos: Vector2 = Vector2(main.bee.position)
		var frost_color := Color("b8d8e8", 0.2 + frost_level * 0.65)
		for shard in 6:
			var angle: float = float(shard) * TAU / 6.0 + float(main.elapsed) * 0.08
			var inner: Vector2 = bee_pos + Vector2.from_angle(angle) * (20.0 + frost_level * 5.0)
			var outer: Vector2 = bee_pos + Vector2.from_angle(angle) * (25.0 + frost_level * 10.0)
			main.draw_line(inner, outer, frost_color, 2.0 + frost_level)


func _draw_wax_lamp(pos: Vector2, active: bool) -> void:
	var wax := Color("f0d889") if active else Color("d3c39a")
	var wax_shadow := Color("be9c52") if active else Color("927d5c")
	# Chunky wax body and wick replace the previous abstract empty circle.
	main.draw_colored_polygon(PackedVector2Array([
		pos + Vector2(-11, 14), pos + Vector2(-13, -8),
		pos + Vector2(-6, -13), pos + Vector2(0, -9),
		pos + Vector2(7, -14), pos + Vector2(12, -8),
		pos + Vector2(10, 14)
	]), wax)
	main.draw_line(pos + Vector2(-9, 12), pos + Vector2(9, 12), wax_shadow, 3.0)
	main.draw_line(pos + Vector2(0, -10), pos + Vector2(0, -19), Color("4b3a2d"), 3.0)
	if active:
		var flame_height: float = 11.0 + sin(float(main.elapsed) * 7.0 + pos.x) * 2.0
		main.draw_colored_polygon(PackedVector2Array([
			pos + Vector2(0, -31 - flame_height * 0.25),
			pos + Vector2(-7, -20), pos + Vector2(0, -15),
			pos + Vector2(7, -20)
		]), Color("f6a43d"))
		main.draw_circle(pos + Vector2(0, -21), 3.5, Color("fff0a0"))
	# Three tiny bees physically huddle around the lamp base. When cold they face
	# inward; after ignition their gold stripes become visible.
	for bee_index in 3:
		var angle: float = PI * 0.15 + float(bee_index) * PI * 0.35
		var bee_pos: Vector2 = pos + Vector2.from_angle(angle) * 23.0 + Vector2(0, 11)
		main.draw_circle(bee_pos, 5.5, Color("4a4036"))
		main.draw_line(bee_pos + Vector2(-3, 0), bee_pos + Vector2(3, 0), Color("e1b94f") if active else Color("aa8742"), 2.5)


func end() -> void:
	if main != null and main.bee != null:
		main.bee.environment_speed_multiplier = 1.0
