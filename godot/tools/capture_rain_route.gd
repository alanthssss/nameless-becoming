extends SceneTree
const Scene := preload("res://playtest/rain_route/rain_route.tscn")
const Driver := preload("res://tools/rain_calendar_driver.gd")
var scene
var output := ""

func _initialize() -> void:
	call_deferred("run")

func capture(name: String) -> void:
	scene.camera_center = scene.model.position
	scene._update_camera(1)
	scene._physics_process(0)
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(output.path_join(name + ".png")) == OK)

func run() -> void:
	assert(OS.get_cmdline_user_args().size() == 1)
	output = OS.get_cmdline_user_args()[0]
	assert(output.is_absolute_path())
	scene = Scene.instantiate()
	assert(scene.has_method("_act"))
	scene.save_enabled = false
	root.add_child(scene)
	scene.set_physics_process(false)
	await capture("day-01-start")
	scene._toggle_pause()
	await capture("pause")
	scene._toggle_pause()
	for day in range(1, 16):
		if day in [4, 5, 7, 9, 10, 12]:
			Driver.fly(scene.model, scene.model.objective_points()[0])
			await capture("day-%02d-start-work" % day)
		Driver.work(scene.model)
		await capture("day-%02d-work" % day)
		Driver.home(scene.model, false)
		scene._act()
		assert(scene.model.day_finished)
		await capture("day-%02d-end" % day)
		if day < 15:
			scene._next_day()
			assert(scene.model.day == day + 1)
	assert(scene.model.complete and scene.model.completed_days.size() == 15)
	scene._restart()
	assert(scene.model.day == 1 and scene.model.completed_days.is_empty())
	await capture("restart-calendar")
	scene.landscape.route = null
	scene.queue_free()
	await process_frame
	print("RAIN ROUTE SCENE TEST PASSED: fifteen distinct days, daily closing and advancing, full calendar result, pause and restart")
	quit()
