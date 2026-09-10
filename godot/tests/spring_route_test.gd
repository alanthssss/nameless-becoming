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
