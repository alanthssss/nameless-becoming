class_name ConscriptionMechanic
extends RefCounted
## 夏至 · 征召：被需要的方式在变化。
## 巢口告急（蚊群冲巢 → 回巢稳住阵脚）/ 花区告急（掠蜜蚁扑田 → 惊退驱赶）
## 交替出现；响应哪边都是贡献，不响应也有代价，但不会致死——
## 被需要的方式在变化，而不是「个体 vs 集体」的对立。

var mechanic_id := "conscription"
var main
var state := "idle"  # idle / active
var kind := ""  # hive / field
var timer := 0.0
var remaining := 0.0
var response_progress := 0.0
var field_repels_needed := 2
var field_repels_done := 0
var interval_min := 14.0
var interval_max := 20.0
var duration := 12.0
var hive_response_seconds := 1.0
var horde_count := 2
var reward_reserve := 2
var horde: Array = []
var raid_ants: Array = []
var successful_events := 0
var rng := RandomNumberGenerator.new()


func start(game, data: Dictionary, balance: Dictionary) -> void:
	main = game
	rng.randomize()
	var mechanics: Dictionary = balance.get("mechanics", {})
	var params: Dictionary = mechanics.get("conscription", {})
	interval_min = float(params.get("interval_min", 14.0))
	interval_max = float(params.get("interval_max", 20.0))
	duration = float(params.get("duration", 12.0))
	hive_response_seconds = float(params.get("hive_response_seconds", 1.0))
	field_repels_needed = int(params.get("field_repels", 2))
	horde_count = int(params.get("horde_count", 2))
	reward_reserve = int(params.get("reward_reserve", 2))
	state = "idle"
	kind = ""
	response_progress = 0.0
	field_repels_done = 0
	horde.clear()
	raid_ants.clear()
	successful_events = 0
	timer = rng.randf_range(interval_min, interval_max)


func process(delta: float) -> void:
	if state == "idle":
		timer -= delta
		if timer <= 0.0:
			trigger_event()
	elif state == "active":
		remaining -= delta
		if kind == "hive":
			update_horde(delta)
		if response_complete():
			resolve(true)
		elif remaining <= 0.0:
			resolve(false)


func trigger_event() -> void:
	state = "active"
	kind = "hive" if rng.randf() < 0.5 else "field"
	remaining = duration
	response_progress = 0.0
	field_repels_done = 0
	if kind == "hive":
		main.message = "巢口告急！蚊群正向蜂巢扑来——回到巢口稳住阵脚。"
		horde.clear()
		for i in horde_count:
			horde.append({
				"position": Vector2(rng.randf_range(560, 900), rng.randf_range(220, 600)),
				"velocity": Vector2(-1, 0),
				"repel_time": 0.0
			})
	else:
		main.message = "花区告急！掠蜜蚁正扑向花田——用惊退（J）把它们赶走。"
		raid_ants.clear()
		for i in 2:
			raid_ants.append({
				"position": Vector2(rng.randf_range(500, 800), rng.randf_range(240, 580)),
				"velocity": Vector2.ZERO,
				"flee_time": 0.0
			})


func update_horde(delta: float) -> void:
	for i in horde.size():
		var mosquito: Dictionary = horde[i]
		mosquito["repel_time"] = maxf(0.0, float(mosquito.get("repel_time", 0.0)) - delta)
		var direction := Vector2.LEFT if Vector2(mosquito.position).x > main.HIVE_SAFE_X + 12.0 else Vector2.RIGHT
		mosquito["position"] = Vector2(mosquito.position) + direction * 130.0 * delta
		horde[i] = mosquito
		# 蚊群冲过巢口 = 巢口失守
		if Vector2(mosquito.position).x <= main.HIVE_SAFE_X + 10.0 and state == "active" and not response_complete():
			resolve(false)
			return


func on_home(amount: int, delta: float) -> void:
	if state == "active" and kind == "hive":
		response_progress += delta
		if response_progress >= hive_response_seconds:
			resolve(true)


func on_repel_success() -> void:
	if state != "active" or kind != "field":
		return
	for i in raid_ants.size():
		var ant: Dictionary = raid_ants[i]
		if main.bee.position.distance_to(Vector2(ant.position)) < main.sting_range + 10.0:
			ant["flee_time"] = 1.5
			ant["velocity"] = (Vector2(ant.position) - main.bee.position).normalized() * 3.0
			raid_ants[i] = ant
			field_repels_done += 1
			if field_repels_done >= field_repels_needed:
				resolve(true)
			return


func response_complete() -> bool:
	if kind == "hive":
		return response_progress >= hive_response_seconds
	return field_repels_done >= field_repels_needed


func resolve(success: bool) -> void:
	if state != "active":
		return
	var resolved_kind := kind
	if success:
		successful_events += 1
	state = "idle"
	kind = ""
	response_progress = 0.0
	field_repels_done = 0
	horde.clear()
	raid_ants.clear()
	timer = rng.randf_range(interval_min, interval_max)
	if success:
		main.flash = 0.32
		if resolved_kind == "hive":
			main.hive_reserve += reward_reserve
			main.message = "你及时回防，蜂群安然无恙。公共储备 +%d。" % reward_reserve
		else:
			for i in main.flowers.size():
				var flower: Dictionary = main.flowers[i]
				if int(flower.nectar) > 0:
					flower["nectar"] = int(flower.nectar) + 1
					main.flowers[i] = flower
			main.message = "掠蜜蚁被赶退，花田恢复了活力。"
	else:
		if resolved_kind == "hive":
			main.message = "蜂群等了一场空——蚊群扰过巢口，本轮蜂群呼吸弱了一分。"
		else:
			main.message = "花区被掠走一滴蜜。蜂群需要你时，你在远方。"
			for i in main.flowers.size():
				var flower: Dictionary = main.flowers[i]
				if int(flower.nectar) > 1:
					flower["nectar"] = int(flower.nectar) - 1
					main.flowers[i] = flower
					break

func completion_ready() -> bool:
	return successful_events >= 1


func draw() -> void:
	if state != "active":
		return
	if kind == "hive":
		var hive_position := Vector2(86, 410)
		var pulse := 30.0 + sin(main.elapsed * 4.0) * 4.0
		main.draw_arc(hive_position, pulse, 0, TAU, 32, Color("b84a3f", 0.7), 3)
		main.draw_arc(hive_position, pulse + 14, 0, TAU, 32, Color("b84a3f", 0.35), 2)
		for mosquito in horde:
			var pos: Vector2 = mosquito.position
			main.draw_circle(pos, 8, Color("8e3740"))
			main.draw_line(pos, pos + Vector2(-22, 0), Color("c96a5a", 0.8), 2)
		var progress := clampf(response_progress / maxf(hive_response_seconds, 0.01), 0.0, 1.0)
		main.draw_arc(hive_position, 48, -PI / 2.0, -PI / 2.0 + TAU * progress, 40, Color("fff1a8", 0.9), 4)
	else:
		var field_center := Vector2(620, 410)
		var pulse := 60.0 + sin(main.elapsed * 3.0) * 6.0
		main.draw_arc(field_center, pulse, 0, TAU, 48, Color("d9a93f", 0.5), 3)
		main.draw_arc(field_center, pulse + 16, 0, TAU, 48, Color("d9a93f", 0.22), 2)
		for ant in raid_ants:
			var pos: Vector2 = ant.position
			main.draw_circle(pos + Vector2(-5, 0), 6, Color("a66d38"))
			main.draw_circle(pos + Vector2(6, 0), 6, Color("a66d38"))
