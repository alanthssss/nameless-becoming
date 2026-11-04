extends SceneTree
const Scene = preload("res://nectar_harvest.tscn")
const Model = preload("res://nectar_harvest_model.gd")
const Save = preload("res://save_data.gd")
var game
var checks := 0
var failures: Array[String] = []
var trace: Array[Dictionary] = []
var output := ""
var input_keys: Array[int] = []
var serialization_differences := {}

func _initialize() -> void: call_deferred("run")
func check(ok: bool, words: String) -> void:
	checks += 1
	if not ok:
		failures.append(words)
		push_error(words)

func frames(count: int) -> void:
	for i in count: await process_frame

func key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	root.push_input(event,true)
	trace.append({"event":"key","code":code,"pressed":pressed,"p":[game.model.p.x,game.model.p.y],"mode":game.mode})

func tap(code: int) -> void:
	key(code,true)
	await frames(2)
	key(code,false)
	await frames(2)

func click(button: Button, double_click := false) -> void:
	var at := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	root.push_input(motion,true)
	await frames(2)
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = at
		event.global_position = at
		event.button_index = MOUSE_BUTTON_LEFT
		event.double_click = double_click
		event.pressed = pressed
		root.push_input(event,true)
		await frames(2)
	trace.append({"event":"click","control":button.text,"at":[at.x,at.y],"coins":game.model.coins})

func capture(name: String) -> void:
	if output.is_empty() or DisplayServer.get_name() == "headless": return
	await frames(3)
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png(output.path_join(name+".png"))

func fixture_position(p: Vector2) -> void:
	game.model.p = p
	game.model.v = Vector2.ZERO
	game.model.update_camera()
	game.presentation_changed.emit()

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): output = arg.trim_prefix("--capture-dir=")
		if arg.begins_with("--progress-file="): DirAccess.make_dir_recursive_absolute(arg.trim_prefix("--progress-file=").get_base_dir())
	if output.is_empty(): quit(2); return
	DirAccess.make_dir_recursive_absolute(output)
	game = Scene.instantiate(); root.add_child(game)
	await frames(8)
	await click(game.ui.menu_settings)
	check(game.mode == "settings","title exposes settings without starting expedition")
	await capture("01-settings")
	await click(game.ui.settings_motion)
	check(game.reduced_motion and game.world.reduced_motion and game.ui.settings_dance.disabled,"reduced motion controls world and disables dance choice")
	await click(game.ui.settings_motion)
	await click(game.ui.settings_dance)
	check(game.dance_style == "side_step","original anthropomorphic clip selectable")
	var cfg := ConfigFile.new()
	check(cfg.load(game.saved_path+".settings.cfg") == OK and cfg.get_value("presentation","dance_style") == "side_step","preferences persist independently of progression")
	await click(game.ui.settings_dance)
	await tap(KEY_ESCAPE)
	check(game.mode == "title","settings returns to caller")
	await tap(KEY_ENTER)
	fixture_position(Model.HUB_SHOP)
	await capture("02-hub-shop")
	fixture_position(Model.HUB_TREE)
	await capture("03-hub-book")
	await tap(KEY_ESCAPE)
	await capture("04-pause-help-entry")
	var prior: Dictionary = game.model.to_payload()
	await click(game.ui.menu_guide)
	check(game.mode == "journal","pause menu opens field guide without travel to a redundant station")
	await capture("05-field-guide")
	await tap(KEY_ESCAPE)
	check(game.model.to_payload() == prior and game.mode == "pause","reading and leaving guide never changes trip or economy")
	await tap(KEY_ESCAPE)
	fixture_position(Model.HUB_DEPART)
	check(game.model.camera_x == 0,"all three courtyard stations share one screen")
	var restored = Model.new()
	check(restored.restore_payload(game.model.to_payload()) and restored.p == Model.HUB_DEPART,"courtyard lamp position restores from v4 save")
	await capture("06-dance-plaza")
	await tap(KEY_E); await click(game.ui.pond_button)
	key(KEY_D,true); key(KEY_E,true)
	await create_timer(.60).timeout
	check(game.mode == "transition" and game.model.area == "hub" and game.world.dance_elapsed > .4,"visible bee dance precedes atomic scene commit")
	check(game.held.is_empty() and game.model.trip_index == 0,"dance ignores flight and does not start expedition early")
	await capture("07-waggle-departure")
	await tap(KEY_SPACE); await tap(KEY_SPACE)
	check(game.model.area == "pond" and game.mode == "play" and game.model.trip_index == 1,"repeated skip creates exactly one departure")
	key(KEY_D,false); key(KEY_E,false); key(KEY_SPACE,false)
	check(game.model.p.distance_to(Model.POND_ENTRY)<1 and game.model.cargo_total()==0,"skip leaves a stable arrival without held movement or collection")
	await capture("08-pond-stage")
	var real_path: String = game.saved_path
	game.saved_path = output.path_join("write-blocker")
	DirAccess.make_dir_recursive_absolute(game.saved_path)
	prior = game.model.to_payload()
	await tap(KEY_E); await tap(KEY_SPACE)
	check(game.mode == "play" and game.model.area == "pond" and game.model.trip_index == prior.trip_index,"failed save plus skip keeps original area and trip")
	check(game.ui.toast_panel.visible and "未能保存" in game.ui.toast.text,"failed skip communicates recovery")
	game.saved_path = real_path
	await tap(KEY_E)
	await create_timer(.6).timeout
	game.saved_path = output.path_join("write-blocker")
	game._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	check(game.mode == "pause" and game.transition_candidate == null and game.world.dance_elapsed < 0,"failed window close cancels uncommitted dance presentation")
	game.saved_path = real_path
	await tap(KEY_ENTER)
	check(game.mode == "play" and game.model.area == "pond" and game.world.dance_elapsed < 0,"resume after failed exit preserves stable area without frozen dance")
	game.reduced_motion = true; game.save_settings()
	await tap(KEY_E)
	check(game.transition_short,"reduced transition selected at request start")
	await create_timer(.5).timeout
	check(game.mode == "play" and game.model.area == "hub" and game.world.dance_elapsed < 0,"reduced transition returns in a short fade with no dance")
	# Explicit presentation fixture: paid progress is not evidence of earned play.
	game.model.owned.assign(["gather1","bag1","wings1"])
	game.model.sold_total = 120
	game.model.coins = 65
	game.model.energy = game.model.max_energy()
	game.reduced_motion = false; game.dance_style = "side_step"; game.save_settings()
	fixture_position(Model.HUB_SHOP)
	await capture("09-stocked-shop-fixture")
	fixture_position(Model.HUB_DEPART)
	await tap(KEY_E); await click(game.ui.pond_button)
	await create_timer(.6).timeout
	await capture("10-group-side-step-fixture")
	game.test_mode = false
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(game.pause_after_transition,"focus loss requests pause after stable commit")
	await create_timer(1.7).timeout
	check(game.mode == "pause" and game.model.area == "pond" and game.held.is_empty(),"focus loss completes one stable transition then pauses")
	game.test_mode = true
	await click(game.ui.menu_settings)
	root.size = Vector2i(960,600)
	await frames(6)
	await capture("11-small-settings")
	check(Rect2(0,0,1280,800).encloses(game.ui.settings_motion.get_global_rect()),"small window retains motion setting")
	await tap(KEY_ESCAPE)
	await tap(KEY_ESCAPE)
	await tap(KEY_E); await tap(KEY_SPACE)
	await tap(KEY_ESCAPE)
	await click(game.ui.menu_guide); await capture("12-small-guide")
	check(game.mode == "journal" and Rect2(0,0,1280,800).encloses(game.ui.journal_back.get_global_rect()),"small field guide retains return action")
	var result := {"actor":"developer fixture with native key/mouse input", "checks":checks,"failures":failures,"trace":trace,"native":DisplayServer.get_name()!="headless"}
	var f := FileAccess.open(output.path_join("demo-ui-result.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify(result,"  ")); f.close()
	print("NECTAR DEMO UI: %d checks, %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
