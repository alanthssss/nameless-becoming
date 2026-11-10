extends SceneTree
const Scene = preload("res://region_game/main.tscn")
var game
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL "+label)
func frames(count: int) -> void:
	for i in count: await process_frame
func tap(code: int) -> void:
	for pressed in [true,false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event,true)
		await frames(2)
func all_text(node: Node) -> String:
	var result: String = node.text if node is Label or node is Button else ""
	for child in node.get_children(): result += all_text(child)
	return result
func run() -> void:
	game = Scene.instantiate()
	root.add_child(game)
	await frames(6)
	game.saved_path = OS.get_temp_dir().path_join("regional-ui-%d.json" % OS.get_process_id())
	game.save_blocked = false
	game.restart_game()
	check(game.mode == "play" and game.model.at_home(),"new playable courtyard")
	await tap(KEY_E)
	check(game.mode == "regions","entry opens destination")
	check(game.ui.meadow_button.disabled,"new profile cannot select purple")
	game.request_transition("pond")
	await tap(KEY_SPACE)
	await frames(4)
	check(game.model.area == "pond" and game.mode == "play","skip commits destination once")
	check(game.model.trip_index == 1,"exactly one departure")
	check(game.world.area_key == "pond","world follows region")
	check(game.persist(),"active field persisted")
	var before: Dictionary = game.model.to_payload()
	game.pause_game()
	await frames(30)
	check(game.model.to_payload() == before,"pause freezes phases and input")
	game.start_game()
	game.saved_path = OS.get_temp_dir() # Explicit failed-write fixture.
	game.model.field.departed = true
	game.model.return_requested = true
	await frames(2)
	await tap(KEY_SPACE)
	await frames(4)
	check(game.model.area == "pond" and game.mode == "play","failed save cannot leave field")
	game.saved_path = OS.get_temp_dir().path_join("regional-ui-%d.json" % OS.get_process_id())
	game.request_transition("hub")
	await tap(KEY_SPACE)
	await frames(4)
	check(game.model.at_home(),"return transition")
	game.model.coins = 1000
	game.model.materials = {"fiber":100,"resin":100}
	game.model.p = game.model.HUB_TREE
	await tap(KEY_E)
	check(game.mode == "tree","growth interaction")
	var paid: int = game.model.coins
	game.buy_upgrade("gather1")
	check("gather1" in game.model.owned and game.model.coins == paid-4,"real purchase commits")
	game.buy_upgrade("gather1")
	check(game.model.coins == paid-4,"duplicate cannot spend")
	for id in ["bag1","wings1","meadow","supply1"]: game.buy_upgrade(id)
	game.ui.refresh()
	check(game.ui.board.buttons.supply.visible and "supply1" in game.model.owned,"resource growth appears and purchases")
	check(not game.ui.board.buttons.shortcut.visible,"obsolete shortcut never exposed")
	check(not game.ui.meadow_button.disabled,"purchase enables destination")
	check(not "细雨" in all_text(game.ui) and not "F 使用近道" in all_text(game.ui),"help follows current rules")
	game.close_tree()
	game.model.p = game.model.HUB_DEPART
	game.open_regions()
	game.request_transition("meadow")
	await tap(KEY_SPACE)
	await frames(4)
	check(game.model.area == "meadow" and game.model.field.max_energy() == 50 and game.model.field.capacity() == 10,"incremental growth reaches actual field")
	check(game.model.field.supply_rank == 1,"purchased abundance reaches the field")
	game.pause_game()
	check(game.persist(),"purple midtrip save")
	var clone = game.new_model()
	check(clone.restore_payload(game.model.to_payload()),"same validator accepts committed save")
	check(clone.field.flowers == game.model.field.flowers,"purple exact phases retained")
	for size in [Vector2i(960,600),Vector2i(1280,800)]:
		root.size = size
		await frames(4)
		check(game.ui.menu.visible,"pause available at "+str(size))
	game.queue_free()
	await frames(3)
	print("Regional UI: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
