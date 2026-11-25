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
func check_seed_pickup() -> void:
	var field = game.model.field
	var head: Dictionary = field.materials[0]
	field.p = head.anchor - Vector2(85,0)
	game.model.step(.05, Vector2.ZERO, false, false, true, Vector2.RIGHT)
	await frames(2)
	check(head.dropped and game.model.materials.fiber == 0, "loosening a tuft does not credit fiber")
	field.p = head.p
	await frames(3)
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
	game.sell_cargo()
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
	check(game.model.trip_index == 1,"exactly one departure")
	check(game.world.area_key == "pond","world follows region")
	await check_seed_pickup()
	check(game.persist(),"active field persisted")
	var before: Dictionary = game.model.to_payload()
	game.pause_game()
	await frames(30)
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
	gate_inputs()
	game.queue_free()
	await frames(3)
	print("Regional UI: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func press_key(code: Key, pressed: bool) -> void:
	var key := InputEventKey.new()
	key.physical_keycode = code
	key.keycode = code
	key.pressed = pressed
	root.push_input(key,true)

func gate_input(mouse: bool, pressed: bool) -> void:
	if not mouse:
		press_key(KEY_E,pressed)
		return
	var click := InputEventMouseButton.new()
	click.position = Vector2(480,340)
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = pressed
	root.push_input(click,true)

func commit_gate() -> void:
	press_key(KEY_SPACE,true)
	press_key(KEY_SPACE,false)
	game._process(.001)

func gate_inputs() -> void:
	# Advance the ordinary scene deterministically around input edges.
	game.set_process(false)
	game.restart_game()
	var writable: String = game.saved_path
	for mouse in [false,true]:
		for route in ["at gate","tap across","hold across"]:
			check(game.model.transition_to("pond"),"set up native gate input")
			game._load_world()
			var field = game.model.field
			field.departed = route != "at gate"
			# A full bag isolates flight cost if the route seed puts a flower beside the gate.
			var carried: int = game.model.capacity()
			game.model.cargo.blue = carried
			field.cargo = carried
			if field.departed:
				field.p = field.layout.nodes[0].p + Vector2.RIGHT * (149 if route == "hold across" else 130)
				field.v = Vector2.LEFT * field.SPEED
				field.energy = .11 if route == "hold across" else .01
			game.model._sync_field()
			game.model.update_camera()
			var previous: int = game.event_log.filter(func(e):return e.kind=="return").size()
			gate_input(mouse,true)
			if route == "hold across":
				press_key(KEY_A,true)
				game._process(.1)
				check(game.mode=="play" and not field.at_entry(),"holding outside gate cannot start return")
				game._process(.05)
				press_key(KEY_A,false)
			gate_input(mouse,false)
			game._process(.1)
			check(game.mode=="transition" and game.transition_target=="hub","native keyboard/mouse return: "+route)
			if mouse and route == "tap across":
				game.saved_path = OS.get_temp_dir()
				commit_gate()
				game._process(.1)
				check(game.mode=="play" and game.model.interaction()=="home" and game.model.energy==0 and game.model.cargo.blue==carried,"zero-energy arrival can retry a failed write")
				game.saved_path = writable
				gate_input(mouse,true)
				gate_input(mouse,false)
			gate_input(mouse,true)
			gate_input(mouse,false)
			commit_gate()
			check(game.mode=="play" and game.model.at_home() and game.model.cargo.blue==carried and game.model.energy==game.model.max_energy(),"saved and restored full arrival by ordinary input")
			check(game.event_log.filter(func(e):return e.kind=="return").size()==previous+1,"repeated native presses pay out once")
			var restored = game.new_model()
			check(restored.restore_payload(game.read_progress(writable).payload) and restored.at_home() and restored.cargo.blue==carried,"ordinary return persisted with cargo")
	# A live bee can still fly after a failed return transaction.
	game.model.transition_to("pond")
	game._load_world()
	var field = game.model.field
	field.departed = true
	field.p = field.layout.nodes[0].p + Vector2.RIGHT * 130
	field.v = Vector2.LEFT * field.SPEED
	game.model._sync_field()
	gate_input(true,true)
	game._process(.1)
	gate_input(true,false)
	game.saved_path = OS.get_temp_dir()
	commit_gate()
	var before: Vector2 = game.model.p
	press_key(KEY_D,true)
	game._process(.1)
	press_key(KEY_D,false)
	check(game.mode=="play" and game.model.field.phase=="active" and game.model.p.x>before.x,"failed return with stamina preserves flight controls")
	game.saved_path = writable
