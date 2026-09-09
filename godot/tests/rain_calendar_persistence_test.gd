extends SceneTree
const Scene := preload("res://playtest/rain_route/rain_route.tscn")
const Driver := preload("res://tools/rain_calendar_driver.gd")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var path := "user://rain_calendar_test_%d.json" % OS.get_process_id()
	assert(not FileAccess.file_exists(path))
	var scene = Scene.instantiate()
	scene.save_path = path
	root.add_child(scene)
	scene.set_physics_process(false)
	Driver.work(scene.model)
	Driver.home(scene.model, false)
	scene._act()
	scene._save_dawn()
	assert(FileAccess.file_exists(path))
	var saved = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(int(saved.day) == 2 and saved.completed_days.size() == 1 and int(saved.completed_days[0]) == 1)
	var resumed = Scene.instantiate()
	resumed.save_path = path
	root.add_child(resumed)
	resumed.set_physics_process(false)
	assert(resumed.model.day == 2 and resumed.model.completed_days == [1])
	resumed.model.cargo = 2
	resumed._restart()
	assert(resumed.model.day == 2 and resumed.model.cargo == 0, "Restart resets today, not earlier days")
	var before: String = FileAccess.get_file_as_string(path)
	resumed.paused = true
	resumed._next_day()
	assert(FileAccess.get_file_as_string(path) == before, "Pause cannot advance/write the calendar")
	DirAccess.remove_absolute(path)
	if FileAccess.file_exists(path + ".tmp"):
		DirAccess.remove_absolute(path + ".tmp")
	scene.landscape.route = null
	resumed.landscape.route = null
	scene.queue_free()
	resumed.queue_free()
	await process_frame
	print("RAIN CALENDAR PERSISTENCE TEST PASSED: actual dawn file, resume, current-day restart, pause isolation")
	quit()
