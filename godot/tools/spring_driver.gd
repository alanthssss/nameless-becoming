extends RefCounted
const RainDriver := preload("res://tools/rain_calendar_driver.gd")

static func fly(model, target: Vector2) -> void:
	RainDriver.fly(model, target)

static func work(model) -> void:
	var mode: String = model.today().mode
	match mode:
		"visit", "convoy":
			for point in model.sources():
				fly(model, point)
				if mode == "convoy":
					for attempt in range(3):
						if model.all_near(point, 195):
							break
						for bee in model.companions:
							if bee.waiting:
								fly(model, bee.position)
						fly(model, point)
		"escort":
			for bee in model.companions:
				fly(model, bee.position)
		"pollen", "nectar", "wind", "dual":
			var trips := 2 if mode == "dual" else 1
			for trip in range(trips):
				for p in model.sources():
					fly(model, p)
					assert(model.act() == "load")
					if mode == "dual":
						break
				var desk: Vector2 = model.NECTAR_DESK if model.food_kind == "nectar" else model.POLLEN_DESK
				fly(model, desk)
				assert(model.act() == "deliver")
		"pollinate":
			fly(model, model.sources()[0] + Vector2(-90, -70))
			assert(model.act() == "load")
			for item in model.objects:
				fly(model, item.target)
				assert(model.act() == "help")
		"wake":
			for item in model.objects:
				fly(model, item.target)
				assert(model.act() == "help")
		_:
			for i in range(model.objects.size()):
				if mode == "catch":
					for frame in range(2400):
						var offset: Vector2 = model.objects[i].point - model.position
						model.step(1.0 / 60, offset.normalized(), true)
						if offset.length() < 50:
							break
				else:
					fly(model, model.objects[i].point)
				assert(model.act() == "load")
				fly(model, model.objects[i].target)
				assert(model.act() == "help")

static func home(model) -> void:
	# Pick up anyone actually left behind before returning, rather than teleporting a convoy.
	for sweep in range(3):
		for bee in model.companions:
			if bee.waiting or not bee.joined:
				fly(model, bee.position)
		fly(model, model.HIVE)
		if model.companions.is_empty() or model.home_companions() == 5:
			break
	assert(model.work_ready(), "Chapter %d day %d incomplete: visits=%s companions=%s" % [model.term_index, model.day, model.visits, model.home_companions()])
	model.act()
	if not model.day_finished:
		assert(model.homecoming_time >= 0)
		model.act()
	assert(model.day_finished)
