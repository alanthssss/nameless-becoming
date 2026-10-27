extends SceneTree
const Scene = preload("res://bee_dance.tscn")
const Model = preload("res://bee_dance_model.gd")
const Driver = preload("res://route_driver.gd")
const Save = preload("res://save_data.gd")
var game
var checks := 0
var failures := 0
var pressed := {}
var folder := OS.get_environment("SWARM_DANCE_QA_DIR")

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

func fly(target: Vector2) -> void:
	for frame in 1500:
		var d: Vector2 = target-game.model.p
		if d.length() < 10 or game.model.phase != "playing": break
		action({"direction":Vector2(signf(d.x) if absf(d.x)>6 else 0.0,signf(d.y) if absf(d.y)>6 else 0.0),"held":false})
		tick()
	release_all()
	tick(24)

func cold_resume(label: String) -> void:
	tap(KEY_ESCAPE)
	var before: Dictionary = game.model.save_payload()
	check(game.mode=="pause" and game.has_saved,"actual disk pause "+label)
	tick(90)
	check(game.model.save_payload()==before,"pause freezes transaction and listeners "+label)
	release_all()
	game.queue_free()
	await process_frame
	await new_scene()
	check(not game.saved_payload.is_empty(),"cold launch reads save "+label)
	game.on_secondary()
	check(game.mode=="pause" and game.model.save_payload()==before,"exact cold resume "+label)
	tap(KEY_ESCAPE)

func run() -> void:
	if folder.is_empty():
		print("Set SWARM_DANCE_QA_DIR")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(folder)
	await new_scene()
	check(game.model.journey_id()=="bee-dance-sample-v1","independent scene model")
	await shot("00-title")
	tap(KEY_ENTER)
	fly(Model.SOURCE)
	tick(60)
	check(game.model.observation_valid(),"real keyboard route observes source")
	await shot("01-source-observed")
	fly(Model.COMB)
	check(game.model.perched,"real keyboard landing on wax")
	await shot("02-on-wax")
	key(KEY_SPACE,true)
	tick(8)
	check(game.model.share_state=="armed","Space arms instead of dash")
	await cold_resume("armed")
	var armed: Dictionary = game.model.save_payload()
	tick(80)
	check(game.resume_charge_guard and game.model.save_payload()==armed,"cold restored armed selection cannot infer a release")
	# Actual direction event cancels the restored selection without submitting.
	var physical := InputEventKey.new()
	physical.physical_keycode = KEY_UP
	physical.pressed = true
	root.push_input(physical)
	tick(1)
	key(KEY_UP,false)
	check(game.model.share_state=="idle" and game.model.message_revision==0,"movement cancels restored selection")
	fly(Model.COMB)
	key(KEY_SPACE,true)
	tick(5)
	key(KEY_SPACE,false)
	tick(28)
	await shot("03-first-waggle")
	await cold_resume("before-commit")
	tick(47)
	check(game.model.message_revision==1,"one full segment commits")
	await shot("04-listeners-turn")
	tick(100)
	await shot("05-listeners-depart")
	await cold_resume("in-flight")
	tick(220)
	fly(Model.SOURCE)
	check(game.model.listeners[0].state=="foraging" and game.model.listeners[1].state=="foraging","listeners reach the observed flower")
	await shot("06-real-destination")
	# No-label frame is the same actual route, not a fabricated message history.
	for child in game.get_children():
		if child is CanvasLayer: child.visible = false
	await shot("07-no-text-destination")
	for child in game.get_children():
		if child is CanvasLayer: child.visible = true
	fly(game.model.exit_pos+Vector2(45,0))
	check(game.model.phase=="ending","ordinary exit after optional follow-up")
	game.show_ending()
	await shot("08-ending")
	var ending: Dictionary = game.model.save_payload()
	game.queue_free()
	await process_frame
	await new_scene()
	game.on_secondary()
	check(game.mode=="ending" and game.model.save_payload()==ending,"completed cold launch")
	# Explicit content-event visual fixture: not an observed player event.
	game.begin_stage(0)
	fly(Model.SOURCE)
	tick(60)
	fly(Model.COMB)
	key(KEY_SPACE,true)
	tick(5)
	key(KEY_SPACE,false)
	tick(390)
	game.model.invalidate_source()
	tick(60)
	await shot("fixture-source-closed-returning")
	root.size = Vector2i(960,600)
	await process_frame
	await shot("fixture-small-window")
	game.queue_free()
	await process_frame
	print("BEE DANCE UI VERIFIED: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
