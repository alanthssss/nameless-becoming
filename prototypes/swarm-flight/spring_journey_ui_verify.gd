extends SceneTree
const Scene = preload("res://spring_journey.tscn")
const Model = preload("res://spring_journey_model.gd")
const Driver = preload("res://route_driver.gd")
const Save = preload("res://save_data.gd")
var game
var checks := 0
var failures := 0
var pressed := {}
var folder := OS.get_environment("SWARM_SPRING_QA_DIR")

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
	game.progress_file=folder.path_join("save.json")
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
		print("Set SWARM_SPRING_QA_DIR")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(folder)
	await new_scene()
	check(game.model.journey_id()=="spring-03-05-v2","independent integrated journey")
	await shot("00-title")
	tap(KEY_ENTER)
	fly(Vector2(400,230))
	await shot("01-03-two-levels")
	fly(Vector2(1080,230))
	fly(Vector2(1270,500))
	fly(Vector2(1060,500))
	fly(Vector2(1270,500))
	fly(Vector2(1450,190))
	fly(Vector2(2050,190))
	fly(Vector2(2280,190))
	await shot("02-03-small-mosquito")
	fly(Vector2(2280,530))
	fly(Vector2(2520,500))
	fly(Vector2(2770,500))
	fly(Model.SOURCE)
	tick(60)
	check(game.model.observation_valid() and game.model.bird_greeted,"keyboard feeding observes source and bird responds")
	check(game.toast.text.contains("记住") or game.toast.text.contains("画眉"),"actual source response reaches visible UI")
	await shot("03-source-first-visit")
	await cold_resume("03 observed source")
	fly(Vector2(3470,600))
	fly(Vector2(3710,600))
	fly(Vector2(3970,600))
	fly(Vector2(4170,500))
	await shot("04-window-before")
	fly(Vector2(4410 if game.model.stage!=1 else 4360,500))
	fly(game.model.exit_pos+Vector2(45,0))
	check(game.mode=="transition" and game.model.stage==0,"03 physical exit enters transition")
	check(game.handoff_detail.text.contains("Enter 提前") and game.handoff_detail.text.contains("Esc 暂停"),"chapter ending keys describe actual roles")
	await cold_resume_transition("03 to04")
	tick(150)
	check(game.mode=="play" and game.model.stage==1 and game.model.observation_valid(),"automatic03→04 preserves source")
	fly(Vector2(620,520))
	await shot("05-weather-forecast")
	fly(Vector2(1250,520))
	await shot("06-rain-canopy")
	await cold_resume("04 rain")
	fly(Vector2(1350,400))
	fly(Vector2(1540,400))
	await shot("06b-raised-opening")
	fly(Vector2(1760,520))
	fly(Vector2(2170,520))
	fly(Vector2(2370,520))
	fly(Vector2(2370,450))
	check(game.model.shield_left>0,"keyboard contacts rain shield")
	await shot("07-shelter-and-shield")
	fly(Vector2(3560,420))
	fly(Vector2(3670,520))
	fly(Vector2(4120,500))
	fly(Vector2(4410 if game.model.stage!=1 else 4360,500))
	fly(game.model.exit_pos+Vector2(45,0))
	tick(150)
	check(game.model.stage==2 and game.model.observation_valid(),"automatic04→05 preserves source")
	fly(Vector2(620,620))
	fly(Vector2(1000,620))
	fly(Vector2(1260,500))
	fly(Vector2(1850,590))
	fly(Vector2(2190,465))
	for i in 900:
		if game.model.keeper.state=="counting" and game.model.keeper.elapsed<1.2: break
		tick()
	await shot("08-keeper-counting")
	key(KEY_RIGHT,true)
	key(KEY_SPACE,true)
	tick(30)
	key(KEY_SPACE,false)
	for i in 90:
		if game.model.front_open: break
		tick()
	release_all()
	check(game.model.front_open and not game.model.passage_open,"first physical knot opens")
	await cold_resume("first gate")
	tap(KEY_R)
	check(game.model.front_open and not game.model.passage_open,"R keeps first gate without completing second")
	fly(Vector2(2485,465))
	await shot("09-wind-to-back-side")
	key(KEY_RIGHT,true)
	key(KEY_SPACE,true)
	tick(30)
	key(KEY_SPACE,false)
	for i in 180:
		if game.model.passage_open: break
		tick()
	release_all()
	check(game.model.passage_open and game.model.rings_hit>=2,"keyboard wind changes height into back knot")
	await shot("10-back-passage")
	await cold_resume("tidying")
	fly(Vector2(3460,300))
	fly(Vector2(3460,620))
	fly(Vector2(3260,620))
	for i in 600:
		if game.model.keeper.state=="settled": break
		tick()
	check(game.model.keeper.state=="settled","keeper actually reaches result position")
	await shot("11-returned-source-and-result")
	fly(Model.COMB)
	tick(60)
	key(KEY_SPACE,true)
	check(game.model.perched,"wax is physical perch")
	tick(1)
	check(game.model.share_state=="armed","fresh keyboard share")
	await cold_resume("armed share")
	check(game.resume_charge_guard,"restore waits for actual held key")
	tick(60)
	check(game.model.share_state=="armed","no invented release after restore")
	key(KEY_SPACE,true)
	tick(1)
	key(KEY_SPACE,false)
	tick(40)
	await shot("12-sharing-seen-flower")
	tick(55)
	check(game.model.message_revision==1,"real information committed")
	await cold_resume("listeners departing")
	tick(360)
	check(game.model.listeners.all(func(bee): return bee.state=="foraging"),"listeners physically arrive at03source")
	await shot("13-listeners-reached-source")
	root.size=Vector2i(960,600)
	await process_frame
	await shot("14-small-window")
	root.size=Vector2i(1280,800)
	fly(Vector2(3970,600))
	fly(Vector2(4170,500))
	fly(Vector2(4410 if game.model.stage!=1 else 4360,500))
	fly(game.model.exit_pos+Vector2(45,0))
	tick(180)
	check(game.mode=="ending" and game.model.stage==2,"whole journey ending")
	await shot("15-ending")
	var ending: Dictionary=game.model.save_payload()
	game.queue_free()
	await process_frame
	await new_scene()
	game.on_secondary()
	check(game.mode=="ending" and game.model.save_payload()==ending,"completed cold launch")
	# Controlled boundary fixture: an earned result still animates after arrival.
	game.model.keeper.state="tidy"
	game.model.keeper.pos=Vector2(3090,300)
	game.model.keeper.target=Model.RESULT_HOME
	game.model.result_elapsed=Model.RESULT_SECONDS
	tick(180)
	check(game.model.keeper.state=="settled" and game.model.keeper.pos==Model.RESULT_HOME,"ending advances earned keeper result without blocking player")
	game.queue_free()
	await process_frame
	# Actual disk/cold-scene path for the old geometry's embedded v2 position.
	var legacy:=Model.new()
	legacy.load_stage(1)
	legacy.p=legacy.shelters[0].pos
	legacy.save_checkpoint(legacy.p)
	legacy.p=Vector2(619.65,409.71)
	FileAccess.open(folder.path_join("save.json"),FileAccess.WRITE).store_string(JSON.stringify(legacy.save_payload()))
	await new_scene()
	game.on_secondary()
	check(game.mode=="pause" and game.model.p==legacy.checkpoint.p,"legacy disk load uses safe checkpoint before drawing")
	check(game.heading.text=="已回到安全的落脚点" and game.description.text.contains("旅程保留"),"geometry recovery is explained on resume page")
	await shot("16-legacy-safe-resume")
	game.queue_free()
	await process_frame
	print("SPRING JOURNEY UI VERIFIED: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
func cold_resume_transition(label: String) -> void:
	tap(KEY_ESCAPE)
	var before: Dictionary=game.model.save_payload()
	check(game.mode=="pause","pause at chapter boundary "+label)
	game.queue_free()
	await process_frame
	await new_scene()
	game.on_secondary()
	check(game.model.save_payload()==before and game.mode=="pause" and game.paused_from=="transition","cold chapter boundary is paused at same chapter fact")
	tap(KEY_ESCAPE)
	check(game.mode=="transition","explicit resume restores pending handoff")
