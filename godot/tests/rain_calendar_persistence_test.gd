extends SceneTree
const Scene := preload("res://playtest/rain_route/rain_route.tscn")
const Driver := preload("res://tools/rain_calendar_driver.gd")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var path := "user://rain_calendar_test_%d.json" % OS.get_process_id()
	var cover_path := path + ".opening"
	assert(not FileAccess.file_exists(path))
	assert(not FileAccess.file_exists(cover_path))
	var opening = Scene.instantiate()
	opening.chapter_presentation = true
	opening.save_path = cover_path
	root.add_child(opening)
	opening.set_physics_process(false)
	assert(opening.chapter_cover and opening.chapter_start_button.visible)
	assert(opening.save_path == cover_path and not FileAccess.file_exists(cover_path))
	var opening_state: Dictionary = opening.model.snapshot().duplicate(true)
	var opening_clock: float = opening.model.day_clock
	var opening_position: Vector2 = opening.model.position
	opening._physics_process(1.0)
	opening._act()
	opening._next_day()
	assert(opening.model.snapshot() == opening_state and opening.model.day_clock == opening_clock)
	assert(opening.model.position == opening_position and not FileAccess.file_exists(cover_path), "The opening freezes work and does not save an unstarted run")
	var start_event := InputEventJoypadButton.new()
	start_event.button_index = JOY_BUTTON_A
	start_event.pressed = true
	assert(start_event.is_action_pressed("action"), "The test uses the project's existing controller action binding")
	opening._unhandled_input(start_event)
	assert(not opening.chapter_cover and not opening.chapter_start_button.visible)
	assert(opening.save_path == cover_path and FileAccess.file_exists(cover_path))
	var opening_save = JSON.parse_string(FileAccess.get_file_as_string(cover_path))
	assert(opening_save.day == 1 and opening_save.completed_days.is_empty())
	opening._physics_process(0.25)
	assert(opening.model.day_clock > opening_clock, "The controller start must release the gameplay freeze")
	var scene = Scene.instantiate()
	scene.chapter_presentation = false
	scene.save_path = path
	root.add_child(scene)
	scene.set_physics_process(false)
	assert(scene.save_path == path, "A custom test save path must not be replaced by the chapter review save")
	Driver.work(scene.model)
	Driver.home(scene.model, false)
	scene._act()
	scene._save_dawn()
	assert(FileAccess.file_exists(path))
	var saved = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(int(saved.day) == 2 and saved.completed_days.size() == 1 and int(saved.completed_days[0]) == 1)
	var resumed = Scene.instantiate()
	resumed.chapter_presentation = false
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
	resumed.paused = false
	# Continue through actual daily work to exercise a late checkpoint, including the other roof site.
	while resumed.model.day < 15:
		Driver.work(resumed.model, 1)
		Driver.home(resumed.model, false)
		resumed._act()
		assert(resumed.model.day_finished)
		resumed._next_day()
	assert(resumed.model.day == 15 and resumed.model.built_site == 1)
	var final_dawn = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(final_dawn.day == 15 and final_dawn.completed_days.size() == 14)
	assert(final_dawn.built_site == 1 and final_dawn.cleared.size() == 3 and final_dawn.beetle_home)
	Driver.work(resumed.model, 1)
	assert(resumed.model.final_party_ready())
	resumed._restart()
	assert(resumed.model.day == 15 and resumed.model.final_visitors.is_empty())
	assert(resumed.model.cargo == 0 and resumed.model.day_delivered == 0 and resumed.model.built_site == 1)
	Driver.work(resumed.model, 1)
	Driver.home(resumed.model, false)
	resumed._act()
	assert(resumed.model.homecoming_time == 0 and not resumed.model.day_finished)
	resumed._save_dawn()
	var during_ending = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(during_ending == final_dawn, "The controllable ending must not silently become a mid-day checkpoint")
	var late = Scene.instantiate()
	late.chapter_presentation = false
	late.save_path = path
	root.add_child(late)
	late.set_physics_process(false)
	assert(late.model.day == 15 and late.model.final_visitors.is_empty())
	assert(late.model.homecoming_time < 0 and not late.model.complete)
	assert(late.model.built_site == 1 and late.model.cleared.size() == 3 and late.model.beetle_home)
	resumed._act()
	assert(resumed.model.complete and resumed.model.day_finished)
	resumed._save_dawn()
	var finished_bytes: String = FileAccess.get_file_as_string(path)
	var finished = Scene.instantiate()
	finished.chapter_presentation = false
	finished.save_path = path
	root.add_child(finished)
	finished.set_physics_process(false)
	assert(finished.model.complete and finished.model.day_finished and finished.model.completed_days.size() == 15)
	assert(finished.model.built_site == 1 and finished.model.beetle_home)
	finished._next_day()
	finished._act()
	assert(FileAccess.get_file_as_string(path) == finished_bytes, "Restoring a finished chapter cannot issue another completion")
	for test_path in [path, cover_path]:
		DirAccess.remove_absolute(test_path)
		if FileAccess.file_exists(test_path + ".tmp"):
			DirAccess.remove_absolute(test_path + ".tmp")
	# All scenes are test-owned and idle here. Free them before exiting the async runner.
	for instance in [opening, scene, resumed, late, finished]:
		instance.landscape.route = null
		instance.free()
	opening = null
	scene = null
	resumed = null
	late = null
	finished = null
	start_event = null
	await process_frame
	print("RAIN CALENDAR PERSISTENCE TEST PASSED: controller opening, custom save isolation, early/final dawns, restart participation reset, ending rollback and finished resume")
	call_deferred("quit")
