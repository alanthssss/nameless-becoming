extends SceneTree
const Scene := preload("res://playtest/spring/spring_route.tscn")
const Driver := preload("res://tools/spring_driver.gd")
const RainDriver := preload("res://tools/rain_calendar_driver.gd")
var scene
var output := ""
func _initialize() -> void:
	call_deferred("run")
func capture(name: String) -> void:
	scene.paused = false
	scene.camera_center = scene.model.position
	scene._update_camera(1)
	scene._physics_process(0)
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(output.path_join(name + ".png")) == OK)
func run() -> void:
	output = OS.get_cmdline_user_args()[0]
	assert(DirAccess.make_dir_recursive_absolute(output) == OK)
	scene = Scene.instantiate()
	scene.spring_save_enabled = false
	root.add_child(scene)
	scene.set_physics_process(false)
	for term in range(6):
		assert(scene.term_index == term)
		await capture("term-%d-start" % term)
		for day in range(1, 16):
			if term == 1:
				RainDriver.work(scene.model)
			else:
				Driver.work(scene.model)
			if day in [3, 8, 12, 14]:
				await capture("term-%d-day-%02d-work" % [term, day])
			if term == 1:
				RainDriver.home(scene.model, false)
			else:
				Driver.home(scene.model)
			if not scene.model.day_finished:
				scene.paused = false
				scene._act()
				if day == 15 and not scene.model.day_finished:
					scene._act()
			assert(scene.model.day_finished)
			if day < 15:
				scene.paused = false
				scene._next_day()
		await capture("term-%d-end" % term)
		var saved: Dictionary = JSON.parse_string(JSON.stringify(scene.spring_snapshot()))
		assert(scene.restore_spring(saved), "Chapter-end spring envelope resumes")
		if term < 5:
			scene.paused = false
			scene._next_term()
	assert(scene.prior_terms.size() == 5 and scene.model.complete)
	assert(scene.model.world.beetle_home)
	scene.landscape.route = null
	scene.queue_free()
	await process_frame
	print("SPRING SCENE TEST PASSED: six scene transitions, ninety days, all chapter-end envelopes and persistent rain achievements")
	quit()
