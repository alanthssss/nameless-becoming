extends RefCounted

static func fly(model, target: Vector2, brake := true) -> void:
	for frame in range(3600):
		var offset: Vector2 = target - model.position
		if offset.length() < 9:
			break
		model.step(1.0 / 60, offset.normalized() * minf(1, offset.length() / 50), brake)
	assert(model.position.distance_to(target) < 15, "Calendar waypoint unreachable: %s" % target)
	for frame in range(120):
		model.step(1.0 / 60, Vector2.ZERO, true)

static func safe_route(model) -> Array:
	var path: Array = []
	for i in range(model.SAFE_ROUTE.size()):
		path.append(model.SAFE_ROUTE[i])
		if model.day == 5 and i in [3, 4]:
			var gap: Vector2 = model.drip_gaps()[i - 3]
			path.append(gap + Vector2(-85, 150))
			path.append(gap + Vector2(85, 150))
	return path

static func flowers(model, count: int) -> void:
	for point in safe_route(model):
		fly(model, point)
	for i in range(count):
		model.act()
	assert(model.cargo == count, "Flower pickup must use actual action")

static func home(model, close_day := true) -> void:
	var path := safe_route(model)
	var nearest := 0
	var distance := INF
	for i in range(path.size()):
		var current: float = model.position.distance_to(path[i])
		if current < distance:
			distance = current
			nearest = i
	for i in range(nearest, -1, -1):
		fly(model, path[i])
	if close_day:
		model.act()
		if model.day == 15 and model.homecoming_time >= 0 and not model.day_finished:
			model.act()

static func work(model, site := 0) -> void:
	match model.today().mode:
		"scout":
			for point in model.today().points:
				fly(model, point)
		"wind":
			fly(model, model.roof_position())
			assert(model.waiting_companion_points().is_empty(), "Meet the sheltered companions before the shared forage trip")
			home(model, false)
			flowers(model, int(model.today().quota))
		"leaf_delivery", "delivery", "mastery", "final":
			flowers(model, int(model.today().quota))
		"build":
			assert(model.act() == "roof")
			fly(model, model.BUILD_SITES[site])
			assert(model.act() == "build")
		"pollinate":
			flowers(model, 2)
			for point in model.today().points:
				fly(model, point)
				assert(model.act() == "pollinate")
		"drips":
			flowers(model, 1)
		"gutter":
			for point in model.today().points:
				fly(model, point)
				assert(model.act() == "seed")
				fly(model, model.today().target)
				assert(model.act() == "clear")
		"rack", "moving":
			flowers(model, int(model.today().quota))
			if model.today().mode == "moving":
				fly(model, model.SHELTERS[6])
				for frame in range(3600):
					var offset: Vector2 = model.moving_roof_position() - model.position
					model.step(1.0 / 60, offset.normalized() * minf(1, offset.length() / 50), true)
					if model.moving_hold >= 1.2:
						break
				assert(model.moving_hold >= 1.2 and model.cargo > 0)
			else:
				for i in range(model.SAFE_ROUTE.size() - 1, 4, -1):
					fly(model, model.SAFE_ROUTE[i])
			fly(model, model.roof_position())
			assert(model.act() == "rest")
			assert(model.cargo > 0 and model.day_delivered == 0, "Rest keeps pollen aboard; only hive delivery counts")
		"beetle":
			fly(model, model.beetle_position)
			assert(model.act() == "roof")
			fly(model, model.today().target)
			assert(model.beetle_home)
		"rescue":
			for i in range(2, 7):
				fly(model, model.SHELTERS[i])
			assert(model.companions.size() == 5)
