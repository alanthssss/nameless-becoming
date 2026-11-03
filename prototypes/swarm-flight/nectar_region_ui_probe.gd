extends SceneTree
## Explicit developer fixtures for transition boundaries and visible combat feedback.
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
	await frames(14)
	check(game.mode == "play" and game.model.area == "pond" and game.world.area_key == "pond","midpoint swaps actual PackedScene")
	check(game.model.trip_index == 1 and game.held.is_empty() and game.model.p == Model.POND_ENTRY,"held inputs during fade neither move nor bounce back")
	key(KEY_D,false); key(KEY_E,false)
	await capture("02-pond-entry")
	# Force a real write failure at a directory, with a valid candidate transition.
	var path: String = game.saved_path
	game.saved_path = output.path_join("cannot-write-directory")
	DirAccess.make_dir_recursive_absolute(game.saved_path)
	var before: Dictionary = game.model.to_payload()
	await tap(KEY_E); await frames(18)
	check(game.mode == "play" and game.model.area == "pond" and game.world.area_key == "pond","failed save keeps original scene")
	check(game.model.cargo == before.cargo and game.model.trip_index == before.trip_index,"failed transition retains cargo and trip")
	check(game.ui.toast_panel.visible and "未能保存" in game.ui.toast.text,"failed transition leaves a visible recovery message")
	game.saved_path = path
	# Position fixture, then real held-space/release input produces the full repel.
	var mosquito: Dictionary = game.model.creatures[0]
	game.model.p = mosquito.pos-Vector2(100,0)
	game.model.v = Vector2.ZERO
	game.model.face = Vector2.RIGHT
	game.presentation_changed.emit()
	await frames(3)
	check(mosquito.state == "warn","ordinary proximity visibly warns before attack")
	await capture("03-warning")
	var energy: float = game.model.energy
	key(KEY_SPACE,true); key(KEY_D,true)
	await frames(11)
	key(KEY_SPACE,false)
	await frames(6)
	key(KEY_D,false)
	check(mosquito.state == "gone","charged release drives away the mosquito")
	check(game.model.energy > energy-6.0,"dash wins without concurrent contact damage")
	check(not game.world.departing_creatures.is_empty(),"repel produces a visible departing creature")
	await capture("04-repel-flight")
	await frames(25)
	check(game.world.departing_creatures.is_empty(),"repel animation ends without leaving a duplicate creature")
	# A separate explicit encounter fixture verifies damage, safety recovery and pause.
	mosquito.state = "patrol"; mosquito.pos = mosquito.anchor; mosquito.timer = 0.0
	game.model.p = mosquito.anchor-Vector2(75,0); game.model.v = Vector2.ZERO
	for i in 60:
		await frames(1)
		if game.model.hurt_left > 0: break
	check(game.model.hurt_left > 0,"waiting through warning allows one guarded contact hit")
	await capture("05-contact-hit")
	await tap(KEY_ESCAPE)
	var paused: Dictionary = game.model.to_payload()
	await frames(12)
	check(game.model.to_payload() == paused,"pause freezes creature state and invulnerability timer")
	await tap(KEY_ESCAPE)
	game.model.p = Model.POND_ENTRY; game.model.v = Vector2.ZERO
	await tap(KEY_E); await frames(18)
	check(game.model.area == "hub" and game.model.energy == game.model.max_energy(),"ordinary return replenishes only at the safe life scene")
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
	await frames(20)
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
