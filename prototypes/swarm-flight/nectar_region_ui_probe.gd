extends SceneTree
## Explicit developer fixtures for transition boundaries and peaceful wildlife.
const Scene = preload("res://nectar_harvest.tscn")
const Model = preload("res://nectar_harvest_model.gd")
var game
var output := ""
var checks := 0
var failures: Array[String] = []
var trace: Array = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)
func frames(count: int) -> void:
	for i in count:
		await process_frame
		trace.append({"mode":game.mode,"area":game.model.area,"p":[game.model.p.x,game.model.p.y],"energy":game.model.energy,"creatures":game.model.to_payload().creatures})
func until_mode(expected: String,limit := 360) -> bool:
	for i in limit:
		if game.mode == expected: return true
		await frames(1)
	return game.mode == expected

func key(code: int,value: bool) -> void:
	var e := InputEventKey.new(); e.keycode = code; e.physical_keycode = code; e.pressed = value
	root.push_input(e,true)
func tap(code: int) -> void:
	key(code,true); await frames(1); key(code,false); await frames(1)
func capture(name: String) -> void:
	if output.is_empty() or DisplayServer.get_name() == "headless": return
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png(output.path_join(name+".png"))
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): output = arg.trim_prefix("--capture-dir=")
	if output.is_empty(): quit(2); return
	DirAccess.make_dir_recursive_absolute(output)
	game = Scene.instantiate(); root.add_child(game)
	await frames(5); await tap(KEY_ENTER)
	game.model.p = Model.HUB_DEPART
	game.model.v = Vector2.ZERO
	await tap(KEY_E)
	check(game.mode == "regions","sign exposes dedicated destination screen")
	await tap(KEY_ESCAPE)
	check(game.mode == "play" and game.model.area == "hub" and game.model.trip_index == 0,"cancel does not create a trip")
	await tap(KEY_E); await tap(KEY_ENTER)
	key(KEY_D,true); key(KEY_E,true)
	await frames(3)
	check(game.mode == "transition" and game.model.area == "hub","fade-out freezes the original scene until commit")
	await capture("01-fade-out")
	check(await until_mode("play"),"departure transition finishes within bounded frames")
	check(game.mode == "play" and game.model.area == "pond" and game.world.area_key == "pond","midpoint swaps actual PackedScene")
	check(game.model.trip_index == 1 and game.held.is_empty() and game.model.p == Model.POND_ENTRY,"held inputs during fade neither move nor bounce back")
	key(KEY_D,false); key(KEY_E,false)
	await capture("02-pond-entry")
	# Force a real write failure at a directory, with a valid candidate transition.
	var path: String = game.saved_path
	game.saved_path = output.path_join("cannot-write-directory")
	DirAccess.make_dir_recursive_absolute(game.saved_path)
	var before: Dictionary = game.model.to_payload()
	await tap(KEY_E); check(await until_mode("play"),"failed transition returns control within bounded frames")
	check(game.mode == "play" and game.model.area == "pond" and game.world.area_key == "pond","failed save keeps original scene")
	check(game.model.cargo == before.cargo and game.model.trip_index == before.trip_index,"failed transition retains cargo and trip")
	check(game.ui.toast_panel.visible and "未能保存" in game.ui.toast.text,"failed transition leaves a visible recovery message")
	game.saved_path = path
	# Position fixture + real held-space/release input crosses peaceful wildlife.
	var mosquito: Dictionary = game.model.creatures[0]
	game.model.p = mosquito.pos-Vector2(80,0)
	game.model.v = Vector2.ZERO
	game.model.face = Vector2.RIGHT
	game.presentation_changed.emit()
	await frames(3)
	check(mosquito.state == "patrol","ordinary proximity leaves wildlife in peaceful patrol")
	await capture("03-peaceful-neighbor")
	var energy: float = game.model.energy
	var played: float = game.played_seconds
	var dash_count: int = game.event_log.filter(func(e): return e.kind == "dash").size()
	key(KEY_SPACE,true)
	for i in 120:
		await frames(1)
		if game.model.charge >= Model.CHARGE_READY: break
	check(game.model.charging and game.model.charge == Model.CHARGE_READY,"real held Space charges to readiness")
	game.model.p = mosquito.pos-Vector2(25,0)
	game.model.v = Vector2.ZERO
	key(KEY_SPACE,false); key(KEY_D,true)
	await frames(6)
	key(KEY_D,false)
	check(game.event_log.filter(func(e): return e.kind == "dash").size() == dash_count+1,"real released Space produces one dash")
	check(mosquito.state == "patrol" and game.world.departing_creatures.is_empty(),"dash through wildlife neither removes it nor produces a repel animation")
	check(absf(game.model.energy-(energy-4.0-0.7*(game.played_seconds-played))) < 0.01,"dash pays exactly dash cost and ordinary drain without contact damage")
	await capture("04-dash-past-neighbor")
	await frames(25)
	# Waiting in direct contact remains harmless; resource/time pressure is separate.
	mosquito.pos = mosquito.anchor; mosquito.timer = 0.0
	game.model.p = mosquito.anchor; game.model.v = Vector2.ZERO
	game.model.burst_left = 0.0
	energy = game.model.energy; played = game.played_seconds
	await frames(60)
	check(game.model.hurt_left == 0 and mosquito.state == "patrol","waiting next to wildlife never begins warning, chase or invulnerability")
	check(absf(game.model.energy-(energy-0.7*(game.played_seconds-played))) < 0.01,"continuous overlap pays only ordinary endurance drain")
	check(not game.event_log.any(func(e): return e.kind in ["warn","hurt","repel"]),"ordinary input emits no combat feedback")
	await capture("05-peaceful-contact")
	await tap(KEY_ESCAPE)
	var paused: Dictionary = game.model.to_payload()
	await frames(12)
	check(game.model.to_payload() == paused,"pause freezes wildlife, player and endurance")
	await tap(KEY_ESCAPE)
	check(game.persist(),"peaceful encounter state writes to isolated save")
	var resumed = Model.new()
	check(resumed.restore_payload(JSON.parse_string(FileAccess.get_file_as_string(game.saved_path))) and resumed.creatures == game.model.creatures and resumed.hurt_left == 0,"cold model resume preserves peaceful wildlife without spawning combat")
	game.model.p = Model.POND_ENTRY; game.model.v = Vector2.ZERO
	await tap(KEY_E); check(await until_mode("play"),"return transition finishes within bounded frames")
	check(game.model.area == "hub" and game.model.energy == game.model.max_energy() and game.model.p == Model.HUB_DEPART and game.model.camera_x == 0,"ordinary return restores endurance at the visible departure orb")
	await capture("06-back-to-life")
	game.model.p = Model.HUB_DEPART
	await tap(KEY_E)
	root.size = Vector2i(960,600)
	await frames(5)
	await capture("07-small-destinations")
	check(Rect2(0,0,1280,800).encloses(game.ui.region_back.get_global_rect()),"960 window retains cancel control")
	check(Rect2(0,0,1280,800).encloses(game.ui.pond_button.get_global_rect()),"960 window retains destination action")
	await tap(KEY_ESCAPE)
	await tap(KEY_E); await tap(KEY_ENTER)
	game.test_mode = false
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	game.test_mode = true
	check(await until_mode("pause"),"focus-loss transition finishes paused within bounded frames")
	check(game.mode == "pause" and game.model.area == "pond","focus loss during fade finishes safely paused")
	var focus_energy: float = game.model.energy
	await frames(12)
	check(game.model.energy == focus_energy and focus_energy == game.model.max_energy(),"background transition never starts field drain")
	await tap(KEY_ESCAPE)
	check(game.mode == "play","focused explicit continue resumes after transition pause")
	var file := FileAccess.open(output.path_join("region-ui-result.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"classification":"developer positioned fixtures + ordinary keyboard; not independent human play","trace":trace,"events":game.event_log},"\t"));file.close()
	print("NECTAR REGION UI: %d checks, %d failures" % [checks,failures.size()])
	game.queue_free(); await process_frame; await process_frame
	quit(0 if failures.is_empty() else 1)
