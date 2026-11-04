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

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): output=arg.trim_prefix("--capture-dir=")
		if arg.begins_with("--progress-file="): DirAccess.make_dir_recursive_absolute(arg.trim_prefix("--progress-file=").get_base_dir())
	if not output.is_empty(): DirAccess.make_dir_recursive_absolute(output)
	game = Scene.instantiate()
	root.add_child(game)
	await frames(8)
	check(game.mode == "title","fresh scene opens at title")
	await capture("01-title")
	await tap(KEY_ENTER)
	check(game.mode == "play","focused title button starts with actual Enter input")
	check(not game.ui.goal_text.visible and not game.ui.trip_text.visible,"permanent objective and area text removed from flight HUD")
	for item in [game.ui.bag_text,game.ui.energy_text,game.ui.coins_text]:
		check(game.ui.hud_status.get_global_rect().encloses(item.get_global_rect()),"all resource indicators live inside a single status block")
	await capture("02-first-garden")
	key(KEY_D,true)
	await create_timer(2.0).timeout
	key(KEY_D,false)
	await frames(4)
	check(game.model.p.x > 1000 and game.model.area == "hub" and game.model.trip_index == 0,"walking past stations never auto-departs or refreshes resources")
	game.model.p = Model.HUB_DEPART
	game.model.v = Vector2.ZERO
	await tap(KEY_E)
	check(game.mode == "regions" and game.ui.meadow_button.disabled,"departure sign opens destinations with locked meadow")
	await capture("02b-destination-board")
	await click(game.ui.pond_button)
	check(game.mode == "transition","destination confirmation starts a distinct transition")
	await create_timer(2.4).timeout
	check(game.model.area == "pond" and game.world.area_key == "pond" and game.model.trip_index == 1,"confirmed departure loads pond scene once")
	# Targeted fixture positions are explicit; full journey coverage is separate.
	game.model.p = game.model.flower_point(game.model.flowers[0])+Vector2(0,-101)
	game.model.v = Vector2(0,230)
	game.model.energy = 35.75
	game.ui.refresh()
	check(not game.ui.help_text.visible,"outside harvest radius has no collection prompt")
	key(KEY_S,true)
	await frames(4)
	key(KEY_S,false)
	check(int(ceil(game.model.energy)) == 36 and game.ui.help_text.visible,"entering harvest radius updates prompt before rounded energy changes")
	game.model.p = game.model.flower_point(game.model.flowers[0])+Vector2(0,-99)
	game.model.v = Vector2(0,-230)
	game.ui.refresh()
	key(KEY_W,true)
	await frames(4)
	key(KEY_W,false)
	check(int(ceil(game.model.energy)) == 36 and not game.ui.help_text.visible,"leaving harvest radius clears prompt before rounded energy changes")
	game.model.p = game.model.flowers[0].pos
	game.model.v = Vector2.ZERO
	await frames(2)
	key(KEY_E,true)
	await create_timer(1.95).timeout
	key(KEY_E,false)
	await frames(3)
	check(game.model.cargo_total() == 1,"actual hold-E collects visible source")
	check(game.model.flowers[0].stock == 0,"source stock decreases with cargo")
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
	game.model.p = Model.POND_ENTRY
	game.model.v = Vector2.ZERO
	await tap(KEY_E)
	await create_timer(2.4).timeout
	check(game.model.area == "hub" and game.world.area_key == "hub" and game.model.p.distance_to(Model.HUB_DEPART)<1,"return arrives at the courtyard lamp rather than growth tree")
	game.model.p = Model.HUB_SHOP
	await frames(3)
	await tap(KEY_E)
	check(game.mode == "shop","home E opens shop instead of harvesting")
	await capture("04-first-shop")
	check(game.ui.shop_story.size.x <= 464.1,"shop story fits the sale panel")
	await click(game.ui.sell_button)
	check(game.model.cargo_total() == 0 and game.model.coins == old_cargo,"sell commits exact visible cargo value")
	await click(game.ui.tree_button)
	check(game.mode == "play","sale action returns to courtyard rather than opening growth")
	game.model.p = Model.HUB_TREE
	await frames(2)
	await tap(KEY_E)
	check(game.mode == "tree" and not game.ui.shop.visible and not game.ui.hud.visible,"growth is a dedicated screen")
	check(game.ui.board.visible_ids() == ["gather","bag","meadow","reserve"],"fresh tree reveals two choices and two landmarks")
	await capture("05-initial-tree")
	var initial_coins: int = game.model.coins
	await click(game.ui.board.buttons.bag)
	check(game.ui.board.selected == "bag" and game.model.coins == initial_coins,"node click selects without charging")
	await click(game.ui.board.buttons.meadow)
	check(game.ui.buy_button.disabled and "0 / 3" in game.ui.detail_requirements.text,"locked node remains inspectable with measurable condition")
	# Explicit funded UI fixture, distinct from the ordinary-input full journey.
	game.model.coins = 1000
	game.model.materials = {"fiber":100,"resin":100} # Explicit UI predicate fixture.
	game.ui.refresh()
	await click(game.ui.board.buttons.gather)
	key(KEY_ENTER,true)
	await create_timer(0.45).timeout
	var repeat := InputEventKey.new()
	repeat.keycode = KEY_ENTER
	repeat.pressed = true
	repeat.echo = true
	root.push_input(repeat,true)
	await frames(3)
	check(game.model.owned == ["gather1"] and game.model.coins == 996,"held Enter and key repeat buy exactly one rank")
	# Explicit focus-loss notification fixture: key-up happened in another app.
	game.test_mode = false
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	game.test_mode = true
	check(not game.ui.enter_held and game.held.is_empty(),"focus loss clears tree confirmation and movement state")
	await frames(2)
	check(game.ui.board.buttons.reach.visible and game.ui.board.buttons.wings.visible,"first purchase reveals relevant next choices")
	check(not game.ui.board.buttons.twin.visible,"double gather stays concealed until reach is found")
	check("1.2 → 0.8" in game.ui.detail_effect.text,"detail advances to the next rank")
	await tap(KEY_ENTER)
	check("gather2" in game.model.owned and game.model.coins == 985,"a separate confirmation buys second rank at its own cost")
	check(game.ui.buy_button.disabled and not game.ui.board.buttons.gather.disabled,"max node is inspectable but purchase is disabled")
	var after_buy := Save.read_payload(game.saved_path,Model.new())
	check("gather2" in after_buy.get("owned",[]) and int(after_buy.get("coins",-1))==985,"purchase snapshot retains matching debit and ranks")
	await create_timer(.4).timeout
	await click(game.ui.board.buttons.bag)
	await click(game.ui.buy_button)
	check(game.model.growth_count() == 3,"two ranks plus another ability count as three growths")
	await create_timer(.4).timeout
	await click(game.ui.board.buttons.meadow)
	check(not game.ui.buy_button.disabled,"third base growth makes meadow purchasable")
	await click(game.ui.buy_button)
	check("meadow" in game.model.owned and game.ui.board.buttons.market.visible,"meadow opens the later choices")
	await click(game.ui.board.buttons.market)
	check(game.ui.buy_button.disabled and "紫" in game.ui.detail_requirements.text,"market needs exploration and a sale, not merely meadow purchase")
	await click(game.ui.board.buttons.wings)
	await create_timer(.4).timeout
	var before_wings: int = game.model.coins
	await click(game.ui.buy_button)
	await click(game.ui.buy_button)
	check("wings1" in game.model.owned and "wings2" not in game.model.owned and game.model.coins == before_wings-9,"rapid double click cannot consume both ranks")
	await create_timer(.42).timeout
	await click(game.ui.buy_button,true)
	check("wings2" not in game.model.owned and game.model.coins == before_wings-9,"OS slower double-click second activation cannot buy another rank")
	await create_timer(.4).timeout
	await click(game.ui.board.buttons.reach)
	var valid_path: String = game.saved_path
	var blocked := valid_path+"-directory"
	DirAccess.make_dir_recursive_absolute(blocked)
	game.saved_path = blocked
	var before_failed: Dictionary = game.model.to_payload()
	await click(game.ui.buy_button)
	check(game.model.to_payload() == before_failed,"failed persistence does not debit or unlock")
	game.saved_path = valid_path
	await create_timer(.4).timeout
	await click(game.ui.buy_button)
	check("reach" in game.model.owned and game.ui.board.buttons.twin.visible,"retry commits and reveals double gather")
	await click(game.ui.board.buttons.twin)
	await tap(KEY_RIGHT)
	check(game.ui.board.selected == "wings","group navigation restores prior node")
	await tap(KEY_LEFT)
	check(game.ui.board.selected == "twin","returning to group restores remembered selection")
	var visited: Array[String] = []
	for i in game.ui.board.visible_ids().size():
		visited.append(game.ui.board.selected)
		await tap(KEY_TAB)
	check(visited.size() == 10 and _unique(visited).size() == game.ui.board.visible_ids().size(),"Tab traverses every revealed node")
	await capture("06-progressed-tree")
	game.model.visited_meadow = true
	game.model.rose_sold = 18
	game.model.sold_total = maxi(game.model.sold_total,18)
	game.ui.refresh()
	await click(game.ui.board.buttons.reserve)
	check(game.ui.buy_button.disabled and "任选其一" in game.ui.detail_requirements.text or "任选其一" in game.ui.detail_hint.text,"stage clearly shows the OR condition")
	await click(game.ui.board.buttons.shortcut)
	await create_timer(.4).timeout
	await click(game.ui.buy_button)
	await click(game.ui.board.buttons.reserve)
	check(not game.ui.buy_button.disabled and "market" not in game.model.owned and "twin" not in game.model.owned,"shortcut permits stage completion without market or double gather")
	await capture("07-stage-ready")
	root.size = Vector2i(960,600)
	await frames(5)
	await capture("08-small-tree")
	for b in game.ui.board.buttons.values():
		check(Rect2(0,0,1280,800).encloses(b.get_global_rect()),"visible growth node remains inside logical canvas")
	check(Rect2(0,0,1280,800).encloses(game.ui.buy_button.get_global_rect()),"small window retains purchase action")
	await tap(KEY_ESCAPE)
	check(game.mode == "play","Esc tree returns to its physical courtyard station")
	game.model.p = Model.HUB_SHOP
	await frames(2)
	await tap(KEY_E)
	await capture("09-small-shop")
	check(Rect2(0,0,1280,800).encloses(game.ui.leave_button.get_global_rect()),"small sale panel retains leave action")
	await tap(KEY_ESCAPE)
	check(game.mode == "play" and game.held.is_empty(),"second Esc returns to flight with no stuck input")
	root.size = Vector2i(1280,800)
	game.model.p = Model.HUB_DEPART
	await tap(KEY_E)
	await click(game.ui.meadow_button)
	await create_timer(2.4).timeout
	check(game.model.area == "meadow" and game.world.area_key == "meadow","unlocked direct departure loads meadow scene")
	game.model.p = Vector2(2140,410)
	await frames(3)
	await capture("10-purple-meadow")
	check(game.ui.help_text.get_visible_line_count() <= 1,"field context is one readable action line")
	game.model.p = Vector2(2750,650)
	await frames(3)
	await capture("11-sheltered-low-route")
	check(not game.model.rain_exposed(),"visible low route avoids rain cost")
	game.pause_game()
	var before: Dictionary = game.model.to_payload()
	var again = Model.new()
	var restored: bool = again.restore_payload(Save.read_payload(game.saved_path,Model.new()))
	var after: Dictionary = again.to_payload()
	for field in before:
		if JSON.stringify(before[field],"",true,true) != JSON.stringify(after[field],"",true,true):
			serialization_differences[field] = {"before":before[field],"after":after[field]}
	check(restored and same_state(before,after),"persistent discrete state is exact; float round-trip error stays below 1e-7")
	if not serialization_differences.is_empty(): print("UI SERIALIZATION DIFFERENCES: ",JSON.stringify(serialization_differences,"",true,true))
	if not output.is_empty():
		var file := FileAccess.open(output.path_join("ui-result.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify({"checks":checks,"failures":failures,"classification":"developer targeted UI/native fixtures; not independent play","serialization_differences":serialization_differences,"trace":trace},"\t"))
	print("NECTAR UI VERIFIED: %d checks, %d failures" % [checks,failures.size()])
	game.queue_free()
	await frames(3)
	quit(0 if failures.is_empty() else 1)

func _unique(values: Array[String]) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		if value not in result: result.append(value)
	return result

# JSON decimal parsing can differ at the final bit of a double. Integer economy,
# IDs, booleans, shape and collection sizes remain exact; no gameplay tolerance.
func same_state(a,b) -> bool:
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size(): return false
		for field in a:
			if not b.has(field) or not same_state(a[field],b[field]): return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size(): return false
		for i in a.size():
			if not same_state(a[i],b[i]): return false
		return true
	if a is int: return b is int and a == b
	if a is float: return b is float and absf(a-b) <= 0.0000001
	return typeof(a) == typeof(b) and a == b
