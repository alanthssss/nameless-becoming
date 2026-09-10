extends "res://playtest/rain_route/route_landscape.gd"
const SpringModel := preload("res://playtest/spring/spring_model.gd")

func is_rain() -> bool:
	return is_instance_valid(route) and route.term_index == 1

func _draw_static() -> void:
	super._draw_static()
	if is_rain():
		return
	var tints := [Color("e7dcc6"), PAPER, Color("ced8ba"), Color("e3ddb5"), Color("d5dfd2"), Color("c6d6c3")]
	oval(Vector2(2050, 1630), Vector2(530, 240), Color(tints[route.term_index], 0.55), false)
	oval(Vector2(2430, 480), Vector2(730, 210), Color(tints[route.term_index], 0.5), false)
	# The stump, winding northern lane and meadow remain at the same coordinates.
	var stump: Vector2 = SpringModel.PLACES["树桩"]
	oval(stump, Vector2(64, 39), Color("c5ab81"))
	for radius in [22, 38, 53]:
		draw_arc(stump, radius, 0, TAU, 30, Color("8a7958"), 1.5, true)
	for place: String in SpringModel.PLACES:
		var p: Vector2 = SpringModel.PLACES[place]
		if place in ["近花", "池花", "北花", "草地"]:
			var count := 5 if route.term_index == 0 else 8
			for i in range(count):
				flower(p + Vector2.from_angle(i * 2.39) * (35 + i * 7), 11 + i % 3, Color("e1c495") if route.term_index < 3 else Color("d8b5ac"))
		label(p + Vector2(-26, 125), place, 18)

func extra_roofs() -> Array:
	if is_rain():
		return super.extra_roofs()
	var result: Array = []
	for place: String in SpringModel.EXTRA_ROOF_PLACES:
		result.append({"point": SpringModel.PLACES[place], "radius": 155.0})
	for point: Vector2 in route.model.repaired_roofs:
		result.append({"point": point, "radius": 240.0})
	return result

func _daily_world(visible_world: Rect2) -> void:
	if is_rain():
		super._daily_world(visible_world)
	var m = route.model
	var history: Dictionary = route.world if is_rain() else m.world
	for value in history.values():
		if value is Dictionary and value.has("kind"):
			var p := Vector2(float(value.x), float(value.y))
			if visible_world.has_point(p):
				if value.kind in ["sign", "catch", "repair"]:
					post(p + Vector2(60, -30), int(value.get("shape", 0)), true)
				elif value.kind == "haul":
					for n in range(3):
						leaf(p + Vector2(35 + n * 13, 40), 22, -0.4 + n * 0.4, Color("c9b989"))
				elif value.kind == "wake":
					line([p + Vector2(50, 10), p + Vector2(55, -70)], GREEN, 3)
					oval(p + Vector2(52, -48), Vector2(14, 9), Color("b4a67e"))
				elif value.kind == "pollinate":
					var age: int = route.term_index * 15 + m.day - int(value.get("born_day", route.term_index * 15 + m.day))
					if age < 7:
						flower(p + Vector2(50, 20), 14, Color("ecd097"))
					else:
						for i in range(3):
							var tip := p + Vector2(25 + i * 22, 10 - i % 2 * 12)
							line([tip + Vector2(0, 30), tip], GREEN, 2)
							oval(tip, Vector2(5, 15), Color("d4ad68") if age >= 45 else GREEN)
						label(p + Vector2(-15, 65), "种子成熟了" if age >= 45 else "青果慢慢长大", 16)
	if is_rain():
		return
	if m.world.get("cleared_gutter", false):
		oval(Vector2(2500, 1110), Vector2(70, 30), Color("e6d5ac"), false)
	if visible_world.has_point(Model.HIVE):
		# Two distinct receiving places: honey cells and compact pollen cells.
		var nectar: Vector2 = SpringModel.NECTAR_DESK + Vector2(-17, 18)
		var pollen: Vector2 = SpringModel.POLLEN_DESK + Vector2(-17, 18)
		for i in range(3):
			oval(nectar + Vector2(i * 17, 0), Vector2(8, 12), Color("d9b567"))
			oval(pollen + Vector2(i * 17, 0), Vector2(8, 7), Color("b7a172"))
		label(nectar + Vector2(-18, 25), "接蜜处", 16)
		label(pollen + Vector2(-12, 25), "储粉处", 16)
		# The same five workers, not additional bees, show receiving work on solo days.
		if m.companions.is_empty() and m.social.dance_age < 0:
			for i in range(5):
				var p: Vector2 = Model.HIVE + Vector2(-80 + i * 40, 58 + (i % 2) * 12)
				var receiving: bool = m.pulse > 0 and m.pulse_point.distance_to(Model.HIVE) < 180
				if receiving:
					p.y += sin(route.visual_time * 5 + i) * 3
				bee(p, -PI / 2 + sin(route.visual_time * 0.7 + i) * 0.08, 0.62)
	var mode: String = m.today().mode
	for i in range(m.objects.size()):
		var item: Dictionary = m.objects[i]
		var p: Vector2 = item.target if mode in ["wake", "pollinate"] else item.point
		if mode in ["pollen", "nectar", "wind", "dual"]:
			p = m.sources()[i]
			if visible_world.has_point(p):
				flower(p, 21, Color("edd19e") if mode == "pollen" else Color("dfb8b0"))
				if m.today().get("variation") == "sway":
					label(p + Vector2(-30, -38), ("轻晃" if i == 0 else "稳花") + " · %d" % m.source_stock[i], 16)
			continue
		if visible_world.has_point(item.target) and mode in ["haul", "repair", "sign", "catch"]:
			post(item.target, int(item.shape), item.done)
		if i == m.carried:
			continue
		if visible_world.has_point(p):
			if mode == "wake":
				var offset := Vector2(52, -48) if item.done else Vector2.ZERO
				var progress: float = 1.0 - m.pulse / 1.8 if m.pulse > 0 and m.pulse_point == p else 1.0
				offset *= smoothstep(0, 0.6, progress)
				line([p + Vector2(50, 10), p + Vector2(55, -70)], GREEN, 3)
				oval(p + offset, Vector2(14, 9), Color("b4a67e"))
				for n in range(3):
					line([p + offset + Vector2(-9 + n * 8, 7), p + offset + Vector2(-12 + n * 8, 14)], INK, 1.5)
			elif mode == "pollinate":
				flower(p, 19 + (sin(m.pulse * 3) * 2 if item.done else 0), Color("edcd97") if item.done else Color("d5a99b"))
			elif mode in ["sign", "catch", "repair", "haul"] and not item.done:
				for n in range(4):
					var trace: Vector2 = (item.target as Vector2).lerp(item.origin, (n + 1) / 5.0)
					line([trace, trace + Vector2(13, -4)], Color("91a795"), 2)
				board(p, int(item.shape), mode == "haul")
	if mode == "pollinate" and not m.body_pollen:
		flower(m.sources()[0] + Vector2(-90, -70), 23, Color("f1d778"))

func post(p: Vector2, kind: int, finished: bool) -> void:
	line([p + Vector2(-20, 35), p + Vector2(-18, -5), p + Vector2(22, -5), p + Vector2(25, 35)], INK, 3)
	if finished:
		board(p + Vector2(0, -13), kind)
	else:
		draw_arc(p + Vector2(0, -13), 16, 0, TAU, 24, Color("79956d", 0.55), 2, true)
		mark(p + Vector2(0, -13), kind)

func mark(p: Vector2, kind: int) -> void:
	if kind == 0:
		draw_arc(p, 7, 0, TAU, 20, INK, 2, true)
	elif kind == 1:
		line([p + Vector2(-7, 6), p + Vector2(0, -7), p + Vector2(7, 6), p + Vector2(-7, 6)], INK, 2)
	else:
		draw_rect(Rect2(p - Vector2(6, 6), Vector2(12, 12)), INK, false, 2)

func board(p: Vector2, kind: int, twig := false) -> void:
	if twig:
		leaf(p, 32, -0.3, Color("c9b989"))
	else:
		shape([p + Vector2(-24, -17), p + Vector2(25, -17), p + Vector2(28, 16), p + Vector2(-21, 18)], Color("dac494"))
		mark(p, kind)

func _draw_food() -> void:
	if is_rain():
		super._draw_food()
		return
	var m = route.model
	if m.food_kind != "nectar":
		super._draw_food()
	if m.body_pollen:
		for i in range(4):
			draw_circle(m.position + Vector2(-12 + i * 7, -3), 2, GOLD)
	if m.carried >= 0:
		board(m.position + Vector2(-20, 28), int(m.objects[m.carried].shape), m.today().mode == "haul")

func _draw() -> void:
	if not is_instance_valid(route):
		return
	super._draw()
	if static_pass or is_rain():
		return
	var m = route.model
	if m.social.dance_age >= 0:
		return
	if m.pulse > 0:
		var p: Vector2 = m.pulse_point
		draw_arc(p, 25 + (1.8 - m.pulse) * 16, 0, TAU, 26, Color("e2c275", m.pulse / 3), 1.5, true)
		if p.distance_to(m.position) < 230:
			label(p + Vector2(-70, -65), m.reaction_text, 16)
	var targets: Array = m.objective_points()
	if not targets.is_empty():
		var target: Vector2 = targets[0]
		var best: float = target.distance_to(m.position)
		for p: Vector2 in targets:
			if p.distance_to(m.position) < best:
				target = p
				best = p.distance_to(m.position)
		if best > 125:
			var direction: Vector2 = (target - m.position).normalized()
			leaf(m.position + direction * 65, 12, direction.angle(), Color("d6ba77"))
		else:
			draw_arc(target, 35, 0, TAU, 28, Color("9f8053", 0.55), 1.5, true)

func _draw_beetle_hint() -> void:
	if is_rain():
		super._draw_beetle_hint()

func _draw_beetle_guest(visible_world: Rect2) -> void:
	if is_rain():
		super._draw_beetle_guest(visible_world)
	elif route.model.beetle_home and visible_world.has_point(SpringModel.PLACES["甲虫家"]):
		var p: Vector2 = SpringModel.PLACES["甲虫家"] + Vector2(sin(route.visual_time * 0.5) * 12, 0)
		leaf(p + Vector2(30, -15), 30, -0.2, GREEN)
		oval(p, Vector2(13, 19), Color("ae9278"))
		line([p + Vector2(0, -14), p + Vector2(0, 15)], INK, 2)

func _draw_seed_landing(visible_world: Rect2) -> void:
	if is_rain():
		super._draw_seed_landing(visible_world)

func flower_landmark_title() -> String:
	return super.flower_landmark_title() if is_rain() else "花田"
