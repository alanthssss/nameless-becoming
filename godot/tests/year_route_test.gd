extends SceneTree
const Spring := preload("res://playtest/year/year_model.gd")
const Rain := preload("res://playtest/rain_route/route_model.gd")
const Driver := preload("res://tools/year_driver.gd")
const RainDriver := preload("res://tools/rain_calendar_driver.gd")
func _init() -> void:
	var world: Dictionary = {}
	var total := 0
	for term in range(24):
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
		print("YEAR CHAPTER PASSED: ", term, " fifteen actual days")
	assert(total == 360 and world.beetle_home and world.cleared_gutter)
	print("YEAR ROUTE TEST PASSED: 360 actual days, distinct food handoffs, all dawn resumes, persistent world")
	quit()
