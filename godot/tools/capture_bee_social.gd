extends SceneTree
const Scene := preload("res://playtest/spring/spring_route.tscn")
var scene
var output := ""
func _initialize() -> void:
	call_deferred("run")
func capture(name: String) -> void:
	scene.camera_center = scene.model.HIVE if scene.model.social.dance_age >= 0 else scene.model.position
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
	var m = scene.model
	m.day = 15
	m.completed_days.assign(range(1, 15))
	m.start_day()
	m.position = Vector2(1000, 1490)
	for i in range(5):
		m.companions[i].position = m.position + Vector2(-50 - i * 45, 0)
	for i in range(180):
		m.step(1.0 / 60, Vector2.RIGHT, true)
	await capture("01-flight")
	for i in range(90):
		m.step(1.0 / 60, Vector2.UP, true)
	for i in range(150):
		m.step(1.0 / 60, Vector2.ZERO, true)
	await capture("02-turn-and-rest")
	m.position = m.HIVE
	for i in range(5):
		m.companions[i].position = m.HIVE + Vector2.from_angle(i * TAU / 5) * 84
	for kind in ["round", "waggle"]:
		m.social.remember_forage(m.HIVE + Vector2(500 if kind == "round" else 2400, -200))
		assert(m.social.begin_dance(m))
		for i in range(140):
			m.step(1.0 / 60, Vector2.ZERO, true)
		await capture("03-" + kind)
	# Short native rendered clip, including alternating waggle return loops.
	assert(m.social.begin_dance(m))
	assert(DirAccess.make_dir_recursive_absolute(output.path_join("frames")) == OK)
	for frame in range(144):
		m.step(1.0 / 24, Vector2.ZERO, true)
		await capture("frames/%04d" % frame)
	m.configure(0)
	m.day = 4
	m.completed_days.assign([1, 2, 3])
	m.start_day()
	m.position = m.sources()[0]
	assert(m.act() == "load")
	m.position = m.NECTAR_DESK
	assert(m.act() == "deliver")
	var age: float = m.social.dance_age
	scene.paused = true
	scene._physics_process(0.5)
	assert(m.social.dance_age == age, "Pause freezes dance")
	scene.paused = false
	for i in range(90):
		m.step(1.0 / 60, Vector2.ZERO, true)
	await capture("04-nectar-return")
	m.step(1.0 / 60, Vector2.RIGHT, false)
	assert(m.social.dance_age < 0)
	await capture("05-leave-freely")
	scene.landscape.route = null
	scene.queue_free()
	await process_frame
	print("BEE SOCIAL SCENE TEST PASSED: moving formation, round/waggle, automatic nectar return, pause and interruption")
	quit()
