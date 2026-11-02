extends SceneTree
## Known-route developer input recording. No teleport, granted currency or upgrades.
const Scene = preload("res://nectar_harvest.tscn")
const Model = preload("res://nectar_harvest_model.gd")
var game
var output := ""
var pressed := {}
var trace: Array[Dictionary] = []
var failures: Array[String] = []
var checks := 0
var frame_count := 0
var resume_check := false
var planned: Array[String] = ["gather1","bag1","wings1","gather2","bag2","meadow","reach","shortcut","market","twin","wings2","reserve"]

func _initialize() -> void: call_deferred("run")
func check(ok: bool,words: String) -> void:
	checks += 1
	if not ok:
		failures.append(words)
		push_error(words)

func frames(count: int) -> void:
	for i in count:
		await process_frame
		frame_count += 1

func key(code: int,value: bool) -> void:
	if bool(pressed.get(code,false)) == value: return
	pressed[code] = value
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = value
	root.push_input(event,true)
	trace.append({"frame":frame_count,"event":"key","key":code,"pressed":value,"pos":[game.model.p.x,game.model.p.y],"cargo":game.model.cargo_total(),"coins":game.model.coins})

func release() -> void:
	for code in pressed.keys(): key(code,false)

func tap(code: int) -> void:
	key(code,true)
	await frames(2)
	key(code,false)
	await frames(2)

func click(b: Button) -> void:
	var at := b.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	root.push_input(motion,true)
	await frames(2)
	for value in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = at
		event.global_position = at
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = value
		root.push_input(event,true)
		await frames(3)
	trace.append({"frame":frame_count,"event":"button","text":b.text,"at":[at.x,at.y],"coins":game.model.coins,"owned":game.model.owned.duplicate()})

func fly_to(target: Vector2) -> bool:
	for i in 1600:
		var delta: Vector2 = target-game.model.p
		if delta.length() < 16:
			release()
			await frames(6)
			return true
		key(KEY_D,delta.x > 8)
		key(KEY_A,delta.x < -8)
		key(KEY_S,delta.y > 8)
		key(KEY_W,delta.y < -8)
		await frames(1)
		if game.mode != "play": break
	release()
	return false

func capture(name: String) -> void:
	if output.is_empty(): return
	await frames(3)
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png(output.path_join(name+".png"))

func save_json(name: String,data) -> void:
	var file := FileAccess.open(output.path_join(name),FileAccess.WRITE)
	file.store_string(JSON.stringify(data,"\t",true,true))

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): output=arg.trim_prefix("--capture-dir=")
		if arg == "--resume-check": resume_check=true
	if output.is_empty(): quit(2); return
	DirAccess.make_dir_recursive_absolute(output)
	game=Scene.instantiate()
	root.add_child(game)
	await frames(12)
	if resume_check:
		var expected = JSON.parse_string(FileAccess.get_file_as_string(output.path_join("save-before.json")))
		var expected_model = Model.new()
		var expected_valid: bool = expected_model.restore_payload(expected)
		check(game.has_save and expected_valid and game.model.to_payload() == expected_model.to_payload(),"cold process restores exact persisted state before continuation")
		save_json("cold-loaded.json",game.model.to_payload())
		await capture("11-cold-title")
		await tap(KEY_ENTER)
		check(game.mode == "play","actual continue input resumes exported-independent scene")
		var before: Vector2=game.model.p
		key(KEY_D,true)
		await frames(15)
		key(KEY_D,false)
		await tap(KEY_ESCAPE)
		check(game.model.p.x>before.x,"ordinary movement works after cold resume")
		save_json("save-after.json",game.model.to_payload())
		await capture("12-cold-continued")
		await finish("cold-result.json")
		return
	check(not game.has_save and game.model.coins == 0 and game.model.owned.is_empty(),"whole route begins from real new progress")
	await capture("01-new-title")
	await tap(KEY_ENTER)
	await capture("02-hive-departure")
	for expedition in 30:
		if planned.is_empty(): break
		check(await fly_to(Vector2(470,575)),"ordinary departure %d" % expedition)
		if "shortcut" in game.model.owned:
			check(await fly_to(Model.SHORTCUTS[0]),"reach near shortcut")
			await tap(KEY_F)
			check(game.model.p.distance_to(Model.SHORTCUTS[1]) < 5,"F uses actual outward shortcut")
		while game.model.cargo_total() < game.model.capacity():
			var target: Dictionary={}
			for flower in game.model.flowers:
				if flower.stock<=0: continue
				if flower.region==1 and "meadow" not in game.model.owned: continue
				if flower.region==0 and "meadow" in game.model.owned: continue
				if target.is_empty() or game.model.p.distance_to(flower.pos)<game.model.p.distance_to(target.pos): target=flower
			if target.is_empty(): check(false,"a source remains available for filling this cargo"); break
			if not await fly_to(target.pos): check(false,"source reachable through ordinary controls"); break
			key(KEY_E,true)
			for tick in 600:
				await frames(1)
				if game.model.cargo_total()>=game.model.capacity() or target.stock<=0: break
			key(KEY_E,false)
			await frames(3)
			if expedition==0 and game.model.cargo_total()<game.model.capacity(): await capture("03-first-harvest")
			if game.model.phase != "field": check(false,"no forced rescue on the planned route"); break
		check(game.model.cargo_total()==game.model.capacity(),"trip %d fills real cargo" % expedition)
		if expedition==0: await capture("04-first-full-cargo")
		if "shortcut" in game.model.owned:
			check(await fly_to(Model.SHORTCUTS[1]),"reach far shortcut")
			await tap(KEY_F)
			check(game.model.p.distance_to(Model.SHORTCUTS[0])<5,"F uses actual return shortcut")
		check(await fly_to(Model.HOME),"normal return to hive")
		await tap(KEY_E)
		check(game.mode == "shop","E opens hive transaction screen")
		if expedition==0: await capture("05-first-sale-offer")
		var gain: int=game.model.cargo_value()
		var coins_before: int=game.model.coins
		await click(game.ui.sell_button)
		check(game.model.cargo_total()==0 and game.model.coins==coins_before+gain,"sale commits real collected cargo")
		while not planned.is_empty() and game.model.can_buy(planned[0]):
			var id: String=planned.pop_front()
			await click(game.ui.upgrade_buttons[id])
			check(id in game.model.owned,"actual growth click purchases "+id)
			if id == "gather1": await capture("06-first-upgrade")
			if id == "meadow": await capture("07-meadow-unlocked")
			if id == "shortcut": await capture("08-shortcut-unlocked")
		if game.mode == "complete": break
		await click(game.ui.leave_button)
		if not failures.is_empty(): break
	check(game.model.completed and game.model.owned.size()==12,"all growth branches and reserve completed through ordinary input")
	await capture("09-reserve-complete")
	await tap(KEY_ENTER)
	check(game.mode == "play","completion allows continued free play")
	await fly_to(Vector2(640,480))
	key(KEY_E,true)
	await frames(20)
	key(KEY_E,false)
	await tap(KEY_ESCAPE)
	save_json("save-before.json",game.model.to_payload())
	await capture("10-saved-in-field")
	await finish("route-result.json")

func finish(name: String) -> void:
	release()
	save_json(name,{"checks":checks,"failures":failures,"frames":frame_count,"game_seconds":game.played_seconds,"classification":"known-route developer native input; not uncoached or human play","trace":trace,"events":game.event_log,"final":game.model.to_payload()})
	print("NECTAR NATIVE ROUTE: %d checks, %d failures, %.1f game seconds" % [checks,failures.size(),game.played_seconds])
	game.queue_free()
	await frames(4)
	quit(0 if failures.is_empty() else 1)
