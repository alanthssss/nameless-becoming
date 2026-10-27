extends SceneTree
const Scene = preload("res://weather_window.tscn")
const Model = preload("res://weather_window_model.gd")
const Driver = preload("res://route_driver.gd")
const Save = preload("res://save_data.gd")
var game
var checks := 0
var failures := 0
var pressed := {}
var folder := OS.get_environment("SWARM_WEATHER_QA_DIR")

func _initialize() -> void: call_deferred("run")

func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+label)

func key(code: Key,down: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = down
	root.push_input(event)
	if down: pressed[code] = true
	else: pressed.erase(code)

func tap(code: Key) -> void:
	key(code,true)
	key(code,false)

func release_all() -> void:
	for code in pressed.keys(): key(code,false)

func action(command: Dictionary) -> void:
	var d: Vector2 = command.direction
	var codes := [KEY_LEFT,KEY_RIGHT,KEY_UP,KEY_DOWN,KEY_SPACE]
	var values := [d.x < -0.1,d.x > 0.1,d.y < -0.1,d.y > 0.1,command.held]
	for i in codes.size():
		if values[i] != pressed.has(codes[i]): key(codes[i],values[i])

func tick(count := 1) -> void:
	for i in count:
		game.tick(1.0/60)
		game.world._process(1.0/60)

func shot(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	game.queue_redraw()
	game.world.queue_redraw()
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(folder.path_join(name+".png")) == OK,"capture "+name)

func new_scene() -> void:
	game = Scene.instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.world.set_process(false)
	game.sound.set_muted(true)

func run() -> void:
	if folder.is_empty():
		print("Set SWARM_WEATHER_QA_DIR")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(folder)
	await new_scene()
	check(game.model.journey_id() == "weather-window-sample-v1","independent scene model")
	await shot("00-title")
	tap(KEY_ENTER)
	check(game.mode == "play","title enters play")
	var driver := Driver.new(game.model)
	driver.wait_for_full = false
	var captures := {}
	var did_resume := false
	for frame in 9000:
		if game.model.phase != "playing": break
		action(driver.next_input())
		tick()
		if game.model.p.x > 400 and not captures.has("start"):
			captures.start = true
			await shot("01-window-dry")
		if game.model.weather_phase == "warning" and not captures.has("warning"):
			captures.warning = true
			await shot("02-warning")
		if game.model.weather_phase == "rain" and game.model.p.x > 1250 and not did_resume:
			did_resume = true
			release_all()
			tap(KEY_ESCAPE)
			var before: Dictionary = game.model.save_payload()
			check(game.mode == "pause" and game.has_saved,"rain pause saved to real disk")
			tick(120)
			check(before == game.model.save_payload(),"pause freezes weather, window, hazards and flight")
			game.queue_free()
			await process_frame
			await new_scene()
			check(not game.saved_payload.is_empty(),"cold launch reads actual saved file")
			game.on_secondary()
			check(game.mode == "pause" and game.model.save_payload() == before,"cold resume freezes the exact rain frame")
			await shot("03-cold-resume")
			tap(KEY_ESCAPE)
			# Keep the known-answer route cursor, only reconnect the reloaded model.
			driver.model = game.model
			await shot("04-rain-under-roof")
		if game.model.color_step == 1 and not captures.has("middle"):
			captures.middle = true
			await shot("05-trace-middle")
		if game.model.p.x > 3350 and not captures.has("after"):
			captures.after = true
			await shot("06-window-after")
		if not driver.error.is_empty(): break
	check(game.model.phase == "ending" and driver.error.is_empty(),"native route finishes "+driver.error)
	check(did_resume and captures.has("after"),"native route includes cold rain resume and after-rain window")
	release_all()
	game.show_ending()
	await shot("07-ending")
	var ending: Dictionary = game.model.save_payload()
	game.queue_free()
	await process_frame
	await new_scene()
	game.on_secondary()
	check(game.mode == "ending" and game.model.save_payload() == ending,"completed sample cold launch returns to ending")
	# Controlled visual comparison, not a recorded player history: one camera,
	# one scene/geometry, only committed window phase and matching weather differ.
	game.begin_stage(0)
	game.model.p = Vector2(620,520)
	game.model.camera_x = 0
	game.world.presentation_active = false
	for state in [0,1,2]:
		game.model.color_step = state
		game.model.weather_phase = ["dry","rain","after"][state]
		await shot("comparison-window-"+str(state))
	for child in game.get_children():
		if child is CanvasLayer: child.visible = false
	await shot("comparison-no-text")
	var gray_layer := CanvasLayer.new()
	gray_layer.layer = 100
	var gray_rect := ColorRect.new()
	gray_rect.size = Vector2(1280,800)
	var gray_material := ShaderMaterial.new()
	gray_material.shader = Shader.new()
	gray_material.shader.code = "shader_type canvas_item; uniform sampler2D screen_texture : hint_screen_texture, filter_linear; void fragment(){ vec4 c=texture(screen_texture,SCREEN_UV); float g=dot(c.rgb,vec3(0.299,0.587,0.114)); COLOR=vec4(vec3(g),1.0); }"
	gray_rect.material = gray_material
	gray_layer.add_child(gray_rect)
	root.add_child(gray_layer)
	await shot("comparison-grayscale")
	gray_layer.queue_free()
	await process_frame
	root.size = Vector2i(960,600)
	await process_frame
	await shot("small-window")
	game.queue_free()
	await process_frame
	print("WEATHER UI VERIFIED: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
