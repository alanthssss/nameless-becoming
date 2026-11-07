extends SceneTree
## Native developer fixture: authored starting states, then ordinary keyboard motion.
## Does not stand in for an uncoached player or the complete economy input recording.
const Scene = preload("res://nectar_harvest.tscn")
const Model = preload("res://nectar_harvest_model.gd")
var game
var output := ""
var checks := 0
var failures: Array[String] = []
var held := {}
var trace: Array = []
var samples: Array = []
var frame := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)
func frames(n: int) -> void:
	for i in n:
		await process_frame
		frame += 1
		samples.append([frame,game.model.area,game.model.p.x,game.model.p.y,game.model.energy])
func key(code: int,down: bool) -> void:
	if held.get(code,false)==down: return
	held[code] = down
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = down
	root.push_input(e,true)
	trace.append({"frame":frame,"key":code,"down":down})
func release() -> void:
	for code in held.keys(): key(code,false)
func fly(at: Vector2) -> void:
	for i in 420:
		var d: Vector2 = at-game.model.p
		if d.length()<14: break
		key(KEY_A,d.x< -7)
		key(KEY_D,d.x>7)
		key(KEY_W,d.y< -7)
		key(KEY_S,d.y>7)
		await frames(1)
	release()
	await frames(5)
	check(game.model.p.distance_to(at)<22,"ordinary input reaches "+str(at))
func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(name+".png"))==OK,"capture "+name)
func fixture(area: String, at: Vector2) -> void:
	release()
	game.release_controls()
	game.model = Model.new()
	game.model.owned.assign(["gather1","bag1","wings1","meadow","shortcut"])
	game.model.energy = game.model.max_energy()
	game.model.transition_to(area)
	game.model.p = at
	game.model.update_camera()
	game.mode = "play"
	game._load_world()
	game.ui.show_mode("play")
	game.ui.refresh()
	trace.append({"frame":frame,"fixture":area,"p":[at.x,at.y],"classification":"explicit positioned fixture"})
func run() -> void:
	var isolated := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): output = arg.trim_prefix("--capture-dir=")
		if arg.begins_with("--progress-file="): isolated = true
	if output.is_empty() or not isolated or DisplayServer.get_name()=="headless": quit(2); return
	DirAccess.make_dir_recursive_absolute(output)
	game = Scene.instantiate()
	root.add_child(game)
	await frames(5)
	fixture("pond",Model.POND_ENTRY)
	await frames(5)
	await capture("01-fork-and-home")
	for at in [Vector2(730,585),Vector2(1005,585),Vector2(1230,585),Vector2(1400,480)]: await fly(at)
	await capture("02-lower-nectar-bay")
	for at in [Vector2(1295,255),Vector2(1030,225),Vector2(730,235),Model.POND_ENTRY]: await fly(at)
	check(game.model.energy>25,"full pond loop retains return reserve")
	await capture("03-loop-return")
	# From a clear launch lane, early/normal/late dash release remains steerable.
	for x in [760.0,820.0,880.0]:
		fixture("pond",Vector2(x,590))
		key(KEY_D,true)
		key(KEY_SPACE,true)
		await frames(12)
		key(KEY_SPACE,false)
		await frames(18)
		release()
		key(KEY_W,true)
		await frames(5)
		release()
		check(not Model.Map.blocked("pond",game.model.p) and game.model.p.x>x+160,"dash from clear lane leaves room to turn")
	await capture("04-dash-clear-lane")
	fixture("pond",Vector2(750,405))
	key(KEY_D,true)
	key(KEY_SPACE,true)
	await frames(12)
	key(KEY_SPACE,false)
	await frames(15)
	release()
	check(game.model.p.x<790,"native charged input stops at visible bush")
	await capture("05-solid-edge")
	fixture("pond",Vector2(1310,370))
	# Observe a complete lap in motion: stops remain usable opportunities, not immunity.
	await frames(210)
	await capture("06-material-rest-route")
	fixture("meadow",Model.MEADOW_ENTRY)
	for at in [Vector2(2100,585),Vector2(2515,585),Vector2(2590,645)]: await fly(at)
	var start: float = game.model.energy
	await fly(Vector2(2930,645))
	var low_cost: float = start-game.model.energy
	await capture("07-sheltered-return")
	fixture("meadow",Vector2(2590,320))
	start = game.model.energy
	await fly(Vector2(2930,320))
	check(start-game.model.energy>low_cost*1.8,"native upper crossing costs more than sheltered lower crossing")
	await capture("08-rain-direct-route")
	var f := FileAccess.open(output.path_join("map-result.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify({"classification":"positioned developer native fixtures plus ordinary inputs; not human playtest","checks":checks,"failures":failures,"input_trace":trace,"frame_samples":samples},"\t"))
	print("NECTAR NATIVE MAP: %d checks, %d failures" % [checks,failures.size()])
	game.queue_free()
	await process_frame
	quit(1 if not failures.is_empty() else 0)
