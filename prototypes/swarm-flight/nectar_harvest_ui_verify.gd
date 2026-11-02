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

func click(button: Button) -> void:
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
		event.pressed = pressed
		root.push_input(event,true)
		await frames(2)
	trace.append({"event":"click","control":button.text,"at":[at.x,at.y],"coins":game.model.coins})

func capture(name: String) -> void:
	if output.is_empty() or DisplayServer.get_name() == "headless": return
	await frames(3)
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png(output.path_join(name+".png"))

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): output=arg.trim_prefix("--capture-dir=")
	if not output.is_empty(): DirAccess.make_dir_recursive_absolute(output)
	game = Scene.instantiate()
	root.add_child(game)
	await frames(8)
	check(game.mode == "title","fresh scene opens at title")
	await capture("01-title")
	await tap(KEY_ENTER)
	check(game.mode == "play","focused title button starts with actual Enter input")
	await capture("02-first-garden")
	key(KEY_D,true)
	await create_timer(2.0).timeout
	key(KEY_D,false)
	await frames(4)
	check(game.model.p.x > 500 and game.model.phase == "field","real movement leaves hive and starts a trip")
	# Targeted fixture positions are explicit; full journey coverage is separate.
	game.model.p = Vector2(620,520)
	game.model.v = Vector2.ZERO
	await frames(2)
	key(KEY_E,true)
	await create_timer(1.25).timeout
	key(KEY_E,false)
	await frames(3)
	check(game.model.cargo_total() >= 4,"actual hold-E collects visible source")
	check(game.model.flowers[0].stock < 12,"source stock decreases with cargo")
	await capture("03-harvesting")
	var old_cargo: int = game.model.cargo_total()
	await tap(KEY_ESCAPE)
	check(game.mode == "pause" and game.held.is_empty(),"escape saves pauses and releases input")
	var state: Dictionary = game.model.to_payload()
	await create_timer(0.25).timeout
	check(game.model.to_payload() == state,"paused state is frozen")
	var loaded := Save.read_payload(game.saved_path,Model.new())
	check(not loaded.is_empty() and loaded.cargo.blue == old_cargo,"pause writes actual cargo to isolated disk")
	await tap(KEY_ESCAPE)
	check(game.mode == "play" and not game.model.charging,"resume does not trigger a held charge")
	game.model.p = Model.HOME
	game.model.v = Vector2.ZERO
	await frames(3)
	await tap(KEY_E)
	check(game.mode == "shop","home E opens shop instead of harvesting")
	await capture("04-first-shop")
	check(game.ui.shop_story.size.x <= 208.1,"story wraps within its sidebar")
	check(game.ui.shop_cargo.size.x <= 208.1,"cargo stays inside its sidebar")
	await click(game.ui.sell_button)
	check(game.model.cargo_total() == 0 and game.model.coins == old_cargo,"actual sell click commits cargo and coins")
	await click(game.ui.leave_button)
	check(game.mode == "play","actual leave click returns to world")
	# Known-state fixture proves purchase rollback separately from native route.
	game.model.coins = 30
	game.open_shop()
	await frames(2)
	await click(game.ui.upgrade_buttons.gather1)
	check("gather1" in game.model.owned and game.model.coins == 18,"tree button buys one upgrade at displayed price")
	var after_buy := Save.read_payload(game.saved_path,Model.new())
	check("gather1" in after_buy.owned and int(after_buy.coins)==18,"purchase cold snapshot has matching debit and upgrade")
	check(game.ui.upgrade_buttons.gather1.disabled,"owned node cannot be purchased twice")
	await capture("05-growth-tree")
	game.ui.shop_story.text = "紫花蜜也收到了。\n把这片花地的收获，慢慢变成蜂巢的储粮吧。"
	await frames(3)
	check(game.ui.shop_story.size.x <= 208.1,"changing story text retains sidebar width")
	root.size = Vector2i(960,600)
	await frames(5)
	await capture("06-small-window")
	for b in game.ui.upgrade_buttons.values():
		check(b.get_global_rect().end.x <= 1280 and b.get_global_rect().end.y <= 800,"growth card stays inside canvas")
	root.size = Vector2i(1280,800)
	game.close_shop()
	game.model.coins = 300
	game.open_shop()
	await frames(2)
	await click(game.ui.upgrade_buttons.meadow)
	check("meadow" in game.model.owned,"meadow purchase opens persistent region")
	game.close_shop()
	game.model.p = Vector2(2140,410)
	game.model.phase = "field"
	game.model.visited_meadow = true
	await frames(3)
	await capture("07-purple-meadow")
	check(game.ui.help_text.get_visible_line_count() >= 2,"both dynamic help lines are visible")
	game.model.p = Vector2(2750,650)
	await frames(3)
	await capture("08-sheltered-low-route")
	check(not game.model.rain_exposed(),"visible low route avoids rain cost")
	game.pause_game()
	var before: Dictionary = game.model.to_payload()
	var again = Model.new()
	check(again.restore_payload(Save.read_payload(game.saved_path,Model.new())) and again.to_payload() == before,"full persistent state survives actual disk serialization")
	if not output.is_empty():
		var file := FileAccess.open(output.path_join("ui-result.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify({"checks":checks,"failures":failures,"classification":"developer targeted UI/native fixtures; not independent play","trace":trace},"\t"))
	print("NECTAR UI VERIFIED: %d checks, %d failures" % [checks,failures.size()])
	game.queue_free()
	await frames(3)
	quit(0 if failures.is_empty() else 1)
