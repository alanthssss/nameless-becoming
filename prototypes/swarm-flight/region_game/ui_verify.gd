extends SceneTree
const Scene = preload("res://region_game/main.tscn")
var game
var checks := 0
var failures := 0
var cues: Array[String] = []
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
func click_buy_button() -> void:
	var centre: Vector2 = game.ui.buy_button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = centre
	root.push_input(motion, true)
	for pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.position = centre
		click.pressed = pressed
		root.push_input(click, true)
		await frames(2)

func all_text(node: Node) -> String:
	var result: String = node.text if node is Label or node is Button else ""
	for child in node.get_children(): result += all_text(child)
	return result
func check_seed_pickup() -> void:
	var field = game.model.field
	var head: Dictionary = field.materials[0]
	cues.clear()
	field.p = head.anchor - Vector2(85,0)
	game.model.step(.05, Vector2.ZERO, false, false, true, Vector2.LEFT)
	await frames(2)
	check(cues == ["pulse"], "missing the head plays only the wingbeat")
	field.p = head.anchor - Vector2(85,0)
	game.model.step(.05, Vector2.ZERO, false, false, true, Vector2.RIGHT)
	await frames(2)
	check(cues == ["pulse", "pulse", "fiber_release"], "real release plays wing then rustle, before collection")
	check(head.dropped and game.model.materials.fiber == 0, "loosening a tuft does not credit fiber")
	field.p = head.p
	await frames(3)
	check(cues.count("fiber") == 1, "catching the released fiber plays its pickup once")
	check(game.model.materials.fiber == 1 and game.ui.fiber_text.text == "1", "caught tuft increments HUD inventory")
	check(game.ui.toast_panel.visible and "纤维 +1（现有 1）" in game.ui.toast.text and "升级双翼" in game.ui.toast.text, "confirmed pickup explains quantity, stock and use")
	field.p = field.layout.nodes[0].p
	field.v = Vector2.ZERO
	await frames(2)

func check_shop_shelves() -> void:
	# Start just outside the left post. Ordinary D input must reveal the action on the upper shelf.
	game.model.p = Vector2(165,330)
	game.ui.refresh()
	var right := InputEventKey.new()
	right.physical_keycode = KEY_D
	right.pressed = true
	root.push_input(right,true)
	await frames(15)
	right.pressed = false
	root.push_input(right,true)
	check(game.ui.hub_action.visible and game.ui.hub_action_kind == "shop", "flying to upper shelf reveals delivery")
	game.model.v = Vector2.ZERO
	for y in [330,372,440,490]:
		for x in [195,310,438]:
			game.model.p = Vector2(x,y)
			game.ui.refresh()
			check(game.ui.hub_action.visible and game.ui.hub_action.text == "交付花蜜", "prompt across shop shelf "+str(game.model.p))
	game.model.p = Vector2(260,330)
	await tap(KEY_E)
	check(game.mode == "shop" and game.ui.sell_button.disabled, "top shelf opens empty shop with E")
	game.close_shop()
	game.model.cargo.blue = 2
	game.model.p = Vector2(438,372)
	game.ui.refresh()
	game.ui.hub_action.pressed.emit()
	check(game.mode == "shop" and not game.ui.sell_button.disabled, "second shelf opens delivery from visible button")
	cues.clear()
	game.save_blocked = true
	game.sell_cargo()
	check(cues.is_empty(), "uncommitted delivery stays silent")
	game.save_blocked = false
	game.sell_cargo()
	game.sell_cargo()
	check(cues == ["sell"], "one committed delivery rings once; empty sale stays quiet")
	check(game.model.coins == 2 and game.model.cargo_total() == 0, "delivery credits carried honey once")
	game.close_shop()
	for point in [Vector2(310,240),Vector2(540,390),Vector2(150,480)]:
		game.model.p = point
		game.ui.refresh()
		check(not game.ui.hub_action.visible, "shop prompt ends outside counter and shelves "+str(point))

func check_pond_backup() -> void:
	var previous = game.new_model()
	previous.trip_index = 13
	previous.transition_to("pond")
	var data: Dictionary = previous.to_payload()
	var state: Dictionary = bytes_to_var(Marshalls.base64_to_raw(data.field))
	state.space_version = 3
	var coast = previous.MeadowLayout.build("pond",false)
	var sites = previous.Field._seeded_flower_sites(coast,14)
	for i in sites.size(): state.flowers[i].p = sites[i]*previous.MeadowLayout.GROUND_SCALE
	data.field = Marshalls.raw_to_base64(var_to_bytes(state))
	var original := JSON.stringify(data,"  ",true,true)
	var path := OS.get_temp_dir().path_join("regional-old-pond-%d.json" % OS.get_process_id())
	var backup := path+".pond-"+original.sha256_text()+".bak"
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(original)
	file.close()
	check(game.read_progress(path).ok and FileAccess.get_file_as_bytes(backup)==original.to_utf8_buffer(),"opening an older pond trip keeps a byte-exact rollback copy")
	check(game.read_progress(path).ok and FileAccess.get_file_as_bytes(path)==original.to_utf8_buffer(),"reopening before the first save reuses the backup and retains the original")
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(backup)

func run() -> void:
	game = Scene.instantiate()
	root.add_child(game)
	game.sound.event_played.connect(func(cue: String): cues.append(cue))
	await frames(6)
	game.saved_path = OS.get_temp_dir().path_join("regional-ui-%d.json" % OS.get_process_id())
	game.save_blocked = false
	check_pond_backup()
	game.restart_game()
	check(game.mode == "play" and game.model.at_home(),"new playable courtyard")
	await tap(KEY_E)
	check(game.mode == "regions","entry opens destination")
	check(game.ui.meadow_button.disabled,"new profile cannot select purple")
	game.request_transition("pond")
	check(is_zero_approx(game.transition_elapsed),"courtyard departure keeps its dance")
	await tap(KEY_SPACE)
	await frames(4)
	check(game.model.area == "pond" and game.mode == "play","skip commits destination once")
	check(game.sound._area == "pond" and not game.sound._overlay, "pond music follows the committed area")
	check(game.model.trip_index == 1,"exactly one departure")
	check(game.world.area_key == "pond","world follows region")
	await check_seed_pickup()
	check(game.persist(),"active field persisted")
	var before: Dictionary = game.model.to_payload()
	game.pause_game()
	await frames(30)
	check(game.sound._area == "pond" and game.sound._overlay, "pause softens the score in place")
	check(game.model.to_payload() == before,"pause freezes phases and input")
	game.start_game()
	game.saved_path = OS.get_temp_dir() # Explicit failed-write fixture.
	game.model.field.departed = true
	game.reduced_motion = true
	game.model.return_requested = true
	await frames(2)
	check(game.transition_short,"reduced-motion return uses the short fade")
	await tap(KEY_SPACE)
	await frames(4)
	check(game.model.area == "pond" and game.mode == "play","failed save cannot leave field")
	game.saved_path = OS.get_temp_dir().path_join("regional-ui-%d.json" % OS.get_process_id())
	game.reduced_motion = false
	var gate_key := InputEventKey.new()
	gate_key.physical_keycode = KEY_E
	gate_key.pressed = true
	root.push_input(gate_key,true)
	check(game.mode == "transition" and not game.transition_short,"gate input starts the normal iris")
	var iris: ShaderMaterial = game.ui.transition_layer.shade_material
	var starting_radius: float = iris.get_shader_parameter("radius")
	game._advance_transition(1.0/60.0)
	var moving_radius: float = iris.get_shader_parameter("radius")
	check(moving_radius < starting_radius - 1.0,"return iris visibly closes on the first frame")
	check(game.model.area == "pond" and not game.transition_committed,"first response precedes save and scene change")
	gate_key.pressed = false
	root.push_input(gate_key,true)
	await tap(KEY_SPACE)
	await frames(4)
	check(game.model.at_home(),"return transition")
	await check_shop_shelves()
	game.model.p = game.model.HUB_TREE
	cues.clear()
	await tap(KEY_E)
	await click_buy_button()
	check(cues == ["book_open", "denied"], "clicking an unaffordable rank sounds once")
	game.ui.last_denied_msec = -1000
	cues.clear()
	await tap(KEY_ENTER)
	check(game.ui.buy_button.disabled and cues == ["denied"], "pressing purchase with insufficient funds gives a quiet refusal")
	await tap(KEY_ESCAPE)
	check(cues.back() == "book_close", "closing the book turns the page once")
	game.model.coins = 1000
	game.model.materials = {"fiber":100,"resin":100}
	game.model.p = game.model.HUB_TREE
	await tap(KEY_E)
	check(game.mode == "tree","growth interaction")
	var paid: int = game.model.coins
	cues.clear()
	await tap(KEY_ENTER)
	check(cues == ["buy"], "paid upgrade has its own confirmation")
	check("gather1" in game.model.owned and game.model.coins == paid-4,"real purchase commits")
	game.buy_upgrade("gather1")
	check(game.model.coins == paid-4,"duplicate cannot spend")
	for id in ["bag1","wings1","meadow","supply1"]: game.buy_upgrade(id)
	check(cues.count("buy") == 5 and not cues.has("unlock"), "area unlock never doubles a purchase jingle")
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
	check(game.sound._area == "meadow", "purple field selects its leaf bed")
	cues.clear()
	var bark: Dictionary = game.model.field.materials[0]
	game.model.field.p = bark.anchor - Vector2(45,0)
	game.model.step(.05, Vector2.ZERO, false, false, true, Vector2.RIGHT)
	await frames(2)
	check(cues == ["pulse", "resin_open"], "opening bark has no sticky pickup yet")
	for i in 22: game.model.step(.05, Vector2.ZERO, true, false)
	await frames(2)
	check(cues.count("resin") == 1, "pulling exposed resin to completion plays one pickup")
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
