extends SceneTree
const Scene = preload("res://main.tscn")
const Model = preload("res://long_journey_model.gd")
const Driver = preload("res://route_driver.gd")
const Save = preload("res://save_data.gd")
var game
var checks := 0
var failures := 0
var pressed := {}
var folder := OS.get_environment("SWARM_LONG_QA_DIR")

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
		print("Set SWARM_LONG_QA_DIR to an isolated writable directory")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(folder)
	await new_scene()
	check(game.long_journey,"sample launch selected")
	await shot("00-title")
	tap(KEY_ENTER)
	key(KEY_RIGHT,true)
	tick(45)
	key(KEY_RIGHT,false)
	key(KEY_SPACE,true)
	tick(27)
	var charged: Dictionary = game.model.save_payload()
	tap(KEY_ESCAPE)
	release_all()
	tick(180)
	check(game.mode == "pause" and game.model.save_payload() == charged,"pause freezes live charge, energy and clocks")
	await shot("01-pause-save")
	# A new scene reads the actual atomic save from disk, with no injected payload.
	game.queue_free()
	await process_frame
	await new_scene()
	check(game.secondary_button.visible,"cold launch offers saved position")
	tap(KEY_DOWN)
	tap(KEY_ENTER)
	check(game.mode == "pause","cold resume requires explicit continue")
	check(game.model.save_payload() == charged,"cold load preserves full suspended state")
	await shot("02-cold-resume")
	tap(KEY_ENTER)
	tick(120)
	check(game.resume_charge_guard and game.model.save_payload() == charged,"charge resume waits for player to take Space")
	key(KEY_SPACE,true)
	tick()
	key(KEY_SPACE,false)
	tick(4)
	check(game.model.burst_left > 0,"restored charge can launch normally")
	var bursting: Dictionary = game.model.save_payload()
	tap(KEY_ESCAPE)
	game.on_third()
	check(game.mode == "title","pause can save and return to title")
	game.on_secondary()
	check(game.mode == "pause" and game.model.save_payload() == bursting,"resume preserves active burst")
	# Failed writes never close the window or discard the in-memory state.
	var good_path: String = game.progress_file
	game.progress_file = folder.path_join("missing/subfolder/save.json")
	game.quit_game()
	check(game.mode == "pause" and game.heading.text == "存档还没有写入","failed quit remains visible and retryable")
	check(game.model.save_payload() == bursting,"write failure does not mutate suspended play")
	game.progress_file = good_path
	check(game.persist_progress(),"saving can be retried")
	game.on_third()
	tap(KEY_ENTER)
	var driver := Driver.new(game.model)
	driver.wait_for_full = false
	var captured := {}
	for frame in 90000:
		if game.mode == "ending": break
		if game.mode == "pause":
			release_all()
			tap(KEY_ESCAPE)
		if game.mode in ["transition","arrival"]:
			release_all()
			await shot("07-to-08" if game.mode == "transition" else "08-arrival")
			tap(KEY_ENTER)
			continue
		var command: Dictionary = driver.next_input()
		if not driver.error.is_empty():
			check(false,driver.error)
			break
		action(command)
		tick()
		var encounter: int = game.model.encounter_index()
		var id := "%d-%d" % [game.model.stage,encounter]
		if not captured.has(id) and game.model.p.x > game.model.chapter.encounters[encounter].start_x+900:
			captured[id] = true
			await shot("play-"+id)
		if frame%6000 == 0: print("UI_PROGRESS: stage=%d x=%.0f" % [game.model.stage+7,game.model.p.x])
	check(game.mode == "ending" and game.model.stage == 1,"ordinary viewport inputs finish both chapters")
	check(game.heading.text == "两座庭院，走完了。","sample ending is distinct from full-game ending")
	check(game.model.recoveries == 0,"both routes do not require failure recovery")
	check(game.has_saved,"ending saved to isolated sample file")
	await shot("09-ending")
	var payload := Save.read_payload(game.progress_file,Model.new())
	check(payload.get("completed",false),"completed save can be reloaded")
	release_all()
	game.queue_free()
	await process_frame
	print("LONG JOURNEY UI VERIFIED: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
