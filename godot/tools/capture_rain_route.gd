extends SceneTree

const Scene := preload("res://playtest/rain_route/rain_route.tscn")
const RouteTest := preload("res://playtest/rain_route/route_model.gd")
var scene
var output := ""

func _initialize() -> void:
	call_deferred("run")

func fly(destination: Vector2) -> void:
	for frame in range(2400):
		var offset: Vector2 = destination - scene.model.position
		if offset.length() < 9:
			break
		scene.model.step(1.0 / 60, offset.normalized() * minf(1, offset.length() / 50), true)
	for frame in range(45):
		scene.model.step(1.0 / 60, Vector2.ZERO, true)

func capture(name: String) -> void:
	scene._physics_process(0.0)
	await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(output.path_join(name + ".png"))
	if error != OK:
		push_error("Could not write capture")
		quit(1)

func run() -> void:
	if OS.get_cmdline_user_args().size() != 1:
		push_error("Pass exactly one absolute output directory after --")
		quit(1)
		return
	output = OS.get_cmdline_user_args()[0]
	if not output.is_absolute_path():
		quit(1)
		return
	scene = Scene.instantiate()
	if not scene.has_method("_act"):
		push_error("Rain route script failed to load")
		quit(1)
		return
	root.add_child(scene)
	scene.set_physics_process(false)
	await capture("01-start")
	scene._toggle_pause()
	await capture("06-pause")
	scene._toggle_pause()
	for trip in range(3):
		fly(Vector2(160, 545))
		if trip == 0:
			fly(Vector2(350, 545))
			await capture("07-under-leaf")
		fly(Vector2(1140, 545))
		fly(RouteTest.FLOWERS)
		for index in range(3):
			scene._act()
		if trip == 2:
			await capture("03-convoy")
		fly(Vector2(1140, 545))
		fly(Vector2(160, 545))
		fly(RouteTest.HIVE)
		scene._act()
		if trip == 0:
			await capture("02-built")
	assert(scene.model.complete, "Capture traversal must really complete")
	await capture("04-complete")
	scene._toggle_pause()
	assert(scene.paused)
	scene._restart()
	assert(not scene.paused and scene.model.delivered == 0 and not scene.model.complete)
	await capture("05-restart")
	scene.queue_free()
	await process_frame
	print("RAIN ROUTE SCENE TEST PASSED: actual scene actions, full traversal, result, pause and restart; captures saved")
	quit(0)
