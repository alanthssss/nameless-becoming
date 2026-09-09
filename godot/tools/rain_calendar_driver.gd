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

static func flowers(model, count: int) -> void:
	for point in model.SAFE_ROUTE:
		fly(model, point)
	for i in range(count):
		model.act()
	assert(model.cargo == count, "Flower pickup must use actual action")

static func home(model, close_day := true) -> void:
	var nearest := 0
	var distance := INF
	for i in range(model.SAFE_ROUTE.size()):
		var current: float = model.position.distance_to(model.SAFE_ROUTE[i])
		if current < distance:
			distance = current
			nearest = i
	for i in range(nearest, -1, -1):
		fly(model, model.SAFE_ROUTE[i])
	if close_day:
		model.act()

static func work(model, site := 0) -> void:
	match model.today().mode:
		"scout":
			for point in model.today().points:
				fly(model, point)
		"leaf_delivery", "delivery", "mastery", "wind", "final":
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
			for i in range(model.today().points.size()):
				var target: Vector2 = model.today().points[i]
				for attempt in range(8):
					fly(model, target - Vector2(85, 0))
					while fposmod(model.day_clock, 4.5) < 2.72:
						model.step(1.0 / 60, Vector2.ZERO, true)
					fly(model, target)
					if model.visited.has(str(i)):
						break
				assert(model.visited.has(str(i)), "Drip gap must be crossed by flight")
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
			assert(model.act() == "handoff")
		"beetle":
			fly(model, model.beetle_position)
			assert(model.act() == "roof")
			fly(model, model.today().target)
			assert(model.beetle_home)
		"rescue":
			for i in range(2, 7):
				fly(model, model.SHELTERS[i])
			assert(model.companions.size() == 5)
