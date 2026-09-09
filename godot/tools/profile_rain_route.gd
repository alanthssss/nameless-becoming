extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene = load("res://playtest/rain_route/rain_route.tscn").instantiate()
	root.add_child(scene)
	scene.set_physics_process(false)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var frames: Array[float] = []
	var draws: Array[float] = []
	for frame in range(240):
		var start := Time.get_ticks_usec()
		scene.model.position = Vector2(600 + frame * 8, 1250)
		scene._physics_process(1.0 / 60)
		await process_frame
		await RenderingServer.frame_post_draw
		if frame >= 40:
			frames.append((Time.get_ticks_usec() - start) / 1000.0)
			draws.append(scene.landscape.last_draw_us / 1000.0)
	frames.sort()
	draws.sort()
	print("RAIN PROFILE frames=%d frame_ms median=%.2f p95=%.2f draw_cpu_ms median=%.2f p95=%.2f" % [frames.size(), frames[100], frames[190], draws[100], draws[190]])
	scene.landscape.route = null
	scene.queue_free()
	await process_frame
	quit()
