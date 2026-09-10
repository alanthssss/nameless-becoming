extends SceneTree
const Scene := preload("res://playtest/rain_route/rain_route.tscn")
const Driver := preload("res://tools/rain_calendar_driver.gd")
var scene
var output := ""

func _initialize() -> void:
	call_deferred("run")

func capture(name: String) -> void:
	if name != "pause":
		scene.paused = false
	scene.camera_center = scene.model.position
	scene._update_camera(1)
	scene._physics_process(0)
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(output.path_join(name + ".png")) == OK)

func capture_response(kind: String, point: Vector2) -> void:
	assert(scene.reaction_age(kind, point) == 0)
	for frame in range(24):
		scene._physics_process(1.0 / 60)
	await capture("response-" + kind)
	var age: float = scene.reaction_age(kind, point)
	scene.paused = true
	scene._physics_process(0.5)
	assert(scene.reaction_age(kind, point) == age, "Pause freezes local responses")
	scene.paused = false
	for frame in range(108):
		scene._physics_process(1.0 / 60)
	assert(scene.reaction_age(kind, point) == -1, "Responses end without blocking the player")
	assert(scene.model.restore(scene.model.dawn_state))
	scene._reset_feedback()

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
		if day == 9:
			await capture("day-09-far-hint")
		if day == 3:
			await capture("day-03-leaf-rack")
		if day in [4, 7, 9, 10, 12]:
			Driver.fly(scene.model, scene.model.objective_points()[0])
			await capture("day-%02d-start-work" % day)
		if day == 3:
			scene._act()
			Driver.fly(scene.model, scene.model.BUILD_SITES[0])
			scene._act()
			await capture_response("build", scene.model.roof_position())
		if day == 4:
			Driver.flowers(scene.model, 1)
			Driver.fly(scene.model, scene.model.today().points[0])
			scene._act()
			await capture_response("pollinate", scene.model.today().points[0])
		if day == 5:
			Driver.fly(scene.model, scene.model.drip_gaps()[0] - Vector2(85, 0))
			while fposmod(scene.model.day_clock, 4.5) > 0.8:
				scene.model.step(1.0 / 60, Vector2.ZERO, true)
			await capture("day-05-dripping")
			while not scene.model.drip_open():
				scene.model.step(1.0 / 60, Vector2.ZERO, true)
			await capture("day-05-dry-gap")
		if day == 7:
			assert(scene.model.act() == "seed")
			await capture("day-07-carry-to-landing")
			Driver.fly(scene.model, scene.model.today().target)
			await capture("day-07-landing")
			scene._act()
			await capture_response("clear", scene.model.today().target)
		if day == 9:
			assert(scene.model.act() == "roof")
			await capture("day-09-escort-hint")
			assert(scene.model.restore(scene.model.dawn_state))
		Driver.work(scene.model)
		await capture("day-%02d-work" % day)
		if day == 9:
			assert(scene.beetle_greeting_time > 0)
			scene.paused = false
			for frame in range(108):
				scene._physics_process(1.0 / 60)
			await capture("day-09-thank-you")
			var before: float = scene.beetle_greeting_time
			scene.paused = true
			scene._physics_process(0.5)
			assert(scene.beetle_greeting_time == before)
			scene.paused = false
			for frame in range(180):
				scene._physics_process(1.0 / 60)
			assert(scene.beetle_greeting_time == 0, "Greeting must not replay each frame")
		Driver.home(scene.model, false)
		scene.paused = false
		scene._act()
		if day == 15:
			assert(not scene.model.day_finished and scene.model.homecoming_time == 0)
			for frame in range(360):
				scene._physics_process(1.0 / 60)
			assert(scene.model.home_companions() == 5 and scene.model.rain_strength() < 0.1)
			var home_time: float = scene.model.homecoming_time
			scene.paused = true
			scene._physics_process(0.5)
			assert(scene.model.homecoming_time == home_time)
			scene.paused = false
			await capture("day-15-homecoming")
			scene._act()
		assert(scene.model.day_finished)
		await capture("day-%02d-end" % day)
		if day < 15:
			scene.paused = false
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
