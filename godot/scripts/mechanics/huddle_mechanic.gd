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
	var in_hive: bool = main.bee.position.x < main.HIVE_SAFE_X
	var point_index := active_warm_point_at(main.bee.position)
	if in_hive:
		main.warmth = minf(100.0, main.warmth + hive_restore * delta)
		main.bee.environment_speed_multiplier = 1.0
	elif point_index >= 0:
		main.warmth = minf(100.0, main.warmth + warm_zone_restore * delta)
		main.bee.environment_speed_multiplier = 1.0
	else:
		main.warmth = maxf(0.0, main.warmth - warmth_drain * delta)
		main.bee.environment_speed_multiplier = cold_speed_multiplier

	if main.warmth <= cold_warmth_threshold and not _low_warned:
		_low_warned = true
		main.message = "霜纹压住翅缘。"
	elif main.warmth > cold_warmth_threshold + 12.0:
		_low_warned = false


func on_context_action() -> bool:
	var point_index := nearest_inactive_point()
	if point_index < 0:
		return false
	if int(main.carried) < activation_honey_cost:
		main.message = "暖点需要一滴蜜。"
		# 不占用附近花朵的采集动作；有蜜时才由暖点取得情境动作优先级。
		return false
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
	var nearest := -1
	var nearest_distance := activation_range
	for i in warm_points.size():
		var point: Dictionary = warm_points[i]
		if bool(point.get("active", false)):
			continue
		if i > 0 and not bool(warm_points[i - 1].get("active", false)):
			continue
		var distance: float = main.bee.position.distance_to(Vector2(point.position))
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


func draw() -> void:
	var hive_position := Vector2(86, 410)
	var glow := 27.0 + sin(main.elapsed * 3.0) * 3.0
	main.draw_arc(hive_position, glow, 0, TAU, 28, Color("f4d893", 0.6), 3.0)
	for i in warm_points.size():
		var point: Dictionary = warm_points[i]
		var pos := Vector2(point.position)
		if bool(point.get("active", false)):
			var pulse := warm_radius + sin(main.elapsed * 2.6 + float(i)) * 5.0
			main.draw_circle(pos, 10.0, Color("f4d893"))
			main.draw_arc(pos, pulse, 0, TAU, 40, Color("f4d893", 0.34), 3.0)
		else:
			main.draw_circle(pos, 9.0, Color("53636b"))
			main.draw_arc(pos, 17.0, -PI * 0.8, PI * 0.8, 20, Color("9eb5bf", 0.72), 2.0)
	for flower_index in flower_route:
		if is_flower_available(flower_index):
			continue
		var frozen_position := Vector2(main.flowers[flower_index].position)
		main.draw_arc(frozen_position, 29.0, -PI * 0.9, PI * 0.15, 20, Color("b8d8e8", 0.62), 3.0)
	if main.bee.environment_speed_multiplier < 1.0:
		main.draw_arc(main.bee.position, 27.0, -PI * 0.8, PI * 0.8, 22, Color("b8d8e8", 0.75), 3.0)


func end() -> void:
	if main != null and main.bee != null:
		main.bee.environment_speed_multiplier = 1.0
