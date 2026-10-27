extends SceneTree
const Scene = preload("res://sign_keeper.tscn")
const Model = preload("res://sign_keeper_model.gd")
const Driver = preload("res://route_driver.gd")
const Save = preload("res://save_data.gd")
var game
var checks := 0
var failures := 0
var pressed := {}
var folder := OS.get_environment("SWARM_KEEPER_QA_DIR")

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
		print("Set SWARM_KEEPER_QA_DIR")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(folder)
	await new_scene()
	check(game.model.journey_id()=="sign-keeper-sample-v1","independent scene model")
	await shot("00-title")
	tap(KEY_ENTER)
	fly(Vector2(530,440))
	await shot("01-small-aim")
	fly(Vector2(620,620))
	fly(Vector2(1000,620))
	fly(Vector2(1260,500))
	check(game.model.checkpoint_index==0,"real keyboard route to safe leaf")
	await shot("02-after-small")
	fly(Vector2(1850,590))
	for i in 900:
		if game.model.keeper.state=="chase": break
		tick()
	await shot("03-keeper-checks")
	await cold_resume("chase")
	fly(Vector2(2190,465))
	for i in 900:
		if game.model.keeper.state=="counting" and game.model.keeper.elapsed<2.0: break
		tick()
	await shot("04-counting-slack")
	key(KEY_RIGHT,true)
	key(KEY_SPACE,true)
	tick(30)
	key(KEY_SPACE,false)
	for i in 90:
		if game.model.passage_open: break
		tick()
	release_all()
	check(game.model.passage_open,"actual keyboard dash opens knot")
	await shot("05-opening")
	await cold_resume("tidying")
	tap(KEY_R)
	tick()
	check(game.model.passage_open and game.model.keeper.state=="settled","real retry keeps passage and skips prior animation")
	await shot("06-retained-result")
	fly(Vector2(2260,465))
	check(game.model.p.x<2350,"can fly back through open passage")
	fly(Vector2(2530,465))
	check(game.model.p.x>2392,"can fly forward through open passage")
	for child in game.get_children():
		if child is CanvasLayer: child.visible=false
	await shot("07-result-no-text")
	for child in game.get_children():
		if child is CanvasLayer: child.visible=true
	root.size=Vector2i(960,600)
	await process_frame
	await shot("08-small-window")
	root.size=Vector2i(1280,800)
	fly(Vector2(2910,500))
	fly(game.model.exit_pos+Vector2(45,0))
	check(game.model.phase=="ending","complete keyboard route")
	game.show_ending()
	await shot("09-ending")
	var ending: Dictionary = game.model.save_payload()
	game.queue_free()
	await process_frame
	await new_scene()
	game.on_secondary()
	check(game.mode=="ending" and game.model.save_payload()==ending,"completed cold launch")
	game.queue_free()
	await process_frame
	print("SIGN KEEPER UI VERIFIED: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
