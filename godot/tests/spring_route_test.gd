extends SceneTree
const Spring := preload("res://playtest/spring/spring_model.gd")
const Rain := preload("res://playtest/rain_route/route_model.gd")
const Driver := preload("res://tools/spring_driver.gd")
const RainDriver := preload("res://tools/rain_calendar_driver.gd")
func _init() -> void:
	var world: Dictionary = {}
	var total := 0
	for term in range(6):
		var model
		if term == 1:
			model = Rain.new()
		else:
			model = Spring.new()
			model.configure(term, world)
		for day in range(1, 16):
			assert(model.day == day and not model.complete)
			if term == 1:
				RainDriver.work(model)
				RainDriver.home(model)
			else:
				Driver.work(model)
				Driver.home(model)
			assert(model.completed_days.size() == day)
			model.act()
			assert(model.completed_days.size() == day, "Closing is idempotent")
			total += 1
			if day < 15:
				assert(model.next_day())
				var saved: Dictionary = JSON.parse_string(JSON.stringify(model.snapshot()))
				var resumed = Rain.new() if term == 1 else Spring.new()
				assert(resumed.restore(saved), "Every dawn checkpoint must resume")
				model = resumed
		assert(model.complete and not model.next_day())
		if term == 1:
			world["built_site"] = model.built_site
			world["beetle_home"] = model.beetle_home
			world["cleared_gutter"] = model.cleared.size() == 3
		else:
			world = model.world.duplicate(true)
		print("SPRING CHAPTER PASSED: ", term, " fifteen actual days")
	assert(total == 90 and world.beetle_home and world.cleared_gutter)
	check_food()
	check_recovery()
	check_shelter_history()
	print("SPRING ROUTE TEST PASSED: ninety actual days, distinct food handoffs, all dawn resumes, persistent world")
	quit()

func check_food() -> void:
	var model := Spring.new()
	model.configure(3)
	model.day = 2
	model.start_day()
	Driver.fly(model, model.sources()[0])
	assert(model.act() == "load" and model.food_kind == "nectar")
	model.position = model.POLLEN_DESK + Vector2(45, 0)
	assert(model.act() == "" and model.cargo == 1, "Nectar cannot unload into pollen storage")
	model.position = model.NECTAR_DESK
	model.velocity = Vector2.ZERO
	assert(model.act() == "deliver" and model.world.nectar == 1)

func check_recovery() -> void:
	var model := Spring.new()
	model.configure(5)
	model.completed_days.assign([1, 2, 3])
	model.day = 4
	model.start_day()
	model.position = model.objects[0].point
	assert(model.act() == "load")
	model.position = model.objects[1].target
	assert(model.act() == "" and model.carried == 0, "Wrong support retains the carried object")
	model.position = model.objects[0].target
	model.velocity = Vector2.ZERO
	assert(model.act() == "help" and model.carried == -1)
	var expanded: Vector2 = model.objects[0].target + Vector2(225, 0)
	assert(model.sheltered(expanded), "Repair extends actual shelter coverage")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(model.snapshot()))
	var copy := Spring.new()
	assert(copy.restore(saved) and copy.sheltered(expanded), "Repaired cover survives a checkpoint")
	model.configure(3)
	model.day = 4
	model.start_day()
	model.position = model.sources()[0]
	assert(model.act() == "load")
	model.position = model.NECTAR_DESK
	model.velocity = Vector2.ZERO
	assert(model.act() == "deliver")
	assert(model.objective_points() == [model.sources()[1]], "A harvested wind-task flower cannot remain the next target")
	model.configure(0)
	model.day = 7
	model.start_day()
	model.position = model.sources()[0] + Vector2(-90, -70)
	assert(model.act() == "load" and model.body_pollen and model.cargo == 0)
	model.position = model.sources()[0]
	assert(model.act() == "help" and model.cargo == 0, "Pollination does not turn body pollen into edible cargo")

# Exercise a dense carried world, exact shelter edges, same-day repair and reload.
func check_shelter_history() -> void:
	var history := {}
	for i in range(200):
		history["wake:%d" % i] = {"kind": "wake", "x": i * 10.0, "y": 1900.0}
	history["repair:3300:1800"] = {"kind": "repair", "x": 3300.0, "y": 1800.0}
	var m := Spring.new()
	m.configure(2, history)
	for x in range(0, 3600, 37):
		for y in range(0, 2100, 43):
			var point := Vector2(x, y)
			var expected := point.distance_to(m.HIVE) < 230 or point.distance_to(Vector2(3300, 1800)) < 240
			for place in m.EXTRA_ROOF_PLACES:
				expected = expected or point.distance_to(m.PLACES[place]) < 155
			for roof in m.SHELTERS:
				expected = expected or point.distance_to(roof) < 215
			assert(m.sheltered(point) == expected, "History caching changed shelter coverage")
	assert(m.sheltered(Vector2(3300, 2039.9)))
	assert(not m.sheltered(Vector2(3300, 2040)))
	m.remember("repair", Vector2(3300, 1800), 1)
	assert(m.repaired_roofs.size() == 1, "Revisiting a repair must not multiply roofs")
	var copy := Spring.new()
	assert(copy.restore(JSON.parse_string(JSON.stringify(m.snapshot()))))
	assert(copy.sheltered(Vector2(3300, 2039.9)))
	copy.configure(2)
	assert(not copy.sheltered(Vector2(3300, 2039.9)), "A new world must clear old shelter geometry")
