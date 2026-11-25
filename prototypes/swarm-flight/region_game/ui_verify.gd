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
func wait_for_entrance() -> void:
	var deadline := Time.get_ticks_msec()+4000
	while game.mode == "station_entry" and Time.get_ticks_msec() < deadline:
		await process_frame

func tap(code: int) -> void:
	for pressed in [true,false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event,true)
		await frames(2)
	await wait_for_entrance()

func pad(button: JoyButton) -> void:
	for pressed in [true,false]:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = pressed
		root.push_input(event,true)
		await frames(2)

func map_pointer(view: Control, local: Vector2, button: MouseButton, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = view.get_global_transform_with_canvas()*local
	event.button_index = button
	event.pressed = down
	root.push_input(event,true)
	await frames(1)

func map_drag(view: Control, local: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = view.get_global_transform_with_canvas()*local
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(event,true)
	await frames(1)

func axis(code: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = code
	event.axis_value = value
	root.push_input(event,true)
	await frames(2)

func check_map_camera() -> void:
	var view = game.ui.growth_map
	var board = game.ui.board
	var starting_wallet: Dictionary = game.model.to_payload()
	for pixels in [Vector2i(960,600),Vector2i(1280,800)]:
		root.size = pixels
		await frames(3)
		await tap(KEY_HOME)
		check(view.clip_contents and is_equal_approx(view.magnification,1.0),"full tree is always available at "+str(pixels))
		var centers_match := true
		for id in board.visible_ids():
			if view._node_at(board.point(id)) != id: centers_match = false
		check(centers_match,"every illustrated cell center selects its own cell at "+str(pixels))
		var detail: Vector2 = game.ui.detail_card.global_position
		var at: Vector2 = view.size*Vector2(.64,.46)
		await map_pointer(view,at,MOUSE_BUTTON_WHEEL_UP,true)
		await map_pointer(view,at,MOUSE_BUTTON_WHEEL_UP,false)
		check(view.magnification>1.0 and (board.position+at*view.magnification).distance_to(at)<1,"wheel preserves map location under pointer")
		await map_pointer(view,at,MOUSE_BUTTON_WHEEL_UP,true)
		await map_pointer(view,at,MOUSE_BUTTON_WHEEL_UP,false)
		var before: Vector2 = board.position
		var empty: Vector2 = view.size*Vector2(.17,.94)
		await map_pointer(view,empty,MOUSE_BUTTON_LEFT,true)
		await map_drag(view,empty+Vector2(48,-38))
		await map_pointer(view,empty+Vector2(48,-38),MOUSE_BUTTON_LEFT,false)
		check(before.distance_to(board.position)>25 and game.ui.detail_card.global_position==detail,"drag pans paper; facing detail stays fixed")
		await tap(KEY_HOME)
		var gather: Vector2 = board.point("gather")
		await map_pointer(view,gather,MOUSE_BUTTON_LEFT,true)
		await map_pointer(view,gather,MOUSE_BUTTON_LEFT,false)
		check(board.selected=="gather","map release selects a cell without paying")
		await tap(KEY_EQUAL)
		await tap(KEY_EQUAL)
		await tap(KEY_EQUAL)
		await tap(KEY_EQUAL)
		for j in 8: await tap(KEY_DOWN)
		await frames(18)
		var focused: Vector2 = board.position+board.point(board.selected)*view.magnification
		check(board.selected!="gather" and Rect2(Vector2.ZERO,view.size).grow(-46).has_point(focused),"zoomed camera follows keyboard selection into readable margin")
		var prior: String = board.selected
		await map_pointer(view,focused,MOUSE_BUTTON_LEFT,true)
		await map_drag(view,focused+Vector2(45,-33))
		await map_pointer(view,focused+Vector2(45,-33),MOUSE_BUTTON_LEFT,false)
		check(board.selected==prior,"dragging an illustration preserves the selection")
		await tap(KEY_0)
		await axis(JOY_AXIS_TRIGGER_RIGHT,.85)
		var triggered: float = view.magnification
		await axis(JOY_AXIS_TRIGGER_RIGHT,.95)
		await axis(JOY_AXIS_TRIGGER_RIGHT,0.0)
		check(triggered>1.0 and is_equal_approx(view.magnification,triggered),"held trigger zooms once")
		before = board.position
		await axis(JOY_AXIS_RIGHT_X,1.0)
		await frames(7)
		await axis(JOY_AXIS_RIGHT_X,0.0)
		check(board.position.x<before.x,"right stick pans the viewport")
		await axis(JOY_AXIS_LEFT_Y,-1.0)
		await axis(JOY_AXIS_LEFT_Y,0.0)
		check(board.selected!=prior,"left stick navigates the nodes")
		await pad(JOY_BUTTON_RIGHT_STICK)
		check(is_equal_approx(view.magnification,1.0) and board.position==Vector2.ZERO,"controller resets full view")
		var pinch := InputEventMagnifyGesture.new()
		pinch.position = view.get_global_transform_with_canvas()*at
		pinch.factor = 1.7
		root.push_input(pinch,true)
		await frames(1)
		before=board.position
		var pan := InputEventPanGesture.new()
		pan.position=pinch.position
		pan.delta=Vector2(-1,1)
		root.push_input(pan,true)
		await frames(1)
		check(is_equal_approx(view.magnification,1.7) and board.position.distance_to(before)>1,"magnify and pan gesture events move the map")
		var remembered: Vector2 = board.position
		var remembered_rank: String = board.inspect_data().id
		await pad(JOY_BUTTON_B)
		await tap(KEY_E)
		check(game.mode=="tree" and board.inspect_data().id==remembered_rank and board.position.is_equal_approx(remembered) and is_equal_approx(view.magnification,1.7),"reopen journal on remembered rank, zoom and pan")
	check(game.model.to_payload()==starting_wallet,"browsing, zoom, drag, back and reopen cannot change the saved purchase state")
	board.select_node("gather")

func check_bookmark_rules() -> void:
	var view = game.ui.growth_map
	var board = game.ui.board
	var original: String = game.saved_path
	var base := original + ".book-test"
	game.close_tree()
	game.saved_path = base
	var file := FileAccess.open(base+".growth-view.json",FileAccess.WRITE)
	file.store_string("{truncated")
	file.close()
	game.open_tree()
	check(view.magnification>=2.75 and board.buttons[board.selected].state=="ready","malformed view opens on an affordable live rank")
	board.select_rank("cascade2")
	view.center_selection(false)
	var position: Vector2 = board.position
	var neighbour := "cascade"
	for id in board.visible_ids():
		var pixel: Vector2 = position+board.point(id)*view.magnification
		if id != "cascade" and Rect2(Vector2.ZERO,view.size).grow(-32).has_point(pixel):
			neighbour = id
			break
	var hit: Vector2 = position+board.point(neighbour)*view.magnification
	await map_pointer(view,hit,MOUSE_BUTTON_LEFT,true)
	await map_pointer(view,hit,MOUSE_BUTTON_LEFT,false)
	check(board.selected==neighbour and board.position.is_equal_approx(position),"pointer selects the visible neighbour without shifting the paper")
	var old_motion: bool = board.reduced_motion
	board.reduced_motion = true
	await tap(KEY_DOWN)
	var centered: Vector2 = view._bounded(view.size*.5-board.point(board.selected)*view.magnification)
	check(board.position.is_equal_approx(centered),"direction navigation places the selected skill at the reading point immediately with reduced motion")
	board.reduced_motion = old_motion
	board.select_rank("cascade2")
	view.zoom_at(1.18,view.size*.5)
	view.center_selection(false)
	view._pan(Vector2(14,12))
	var snapshot: Dictionary = view.capture_view()
	game.close_tree()
	file = FileAccess.open(base+".growth-view.json",FileAccess.READ)
	var saved: Dictionary = JSON.parse_string(file.get_as_text())
	file.close()
	check(saved.cell=="cascade" and saved.rank=="cascade2","separate slot preference records stable cell and rank IDs")
	game.open_tree()
	check(board.inspect_data().id==snapshot.rank and is_equal_approx(view.magnification,snapshot.zoom),"readback restores the selected future rank and chosen zoom")
	var other: Dictionary = saved.duplicate()
	other.zoom = 2.0
	file = FileAccess.open(base+".growth-view.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(other,"",true,true))
	file.close()
	game.close_tree()
	game.open_tree()
	check(view.magnification==2.0,"closing an unchanged book preserves another instance's newer view")
	await tap(KEY_HOME)
	game.close_tree()
	game.open_tree()
	check(view.magnification==1.0 and board.inspect_data().id=="cascade2","explicit full overview remains the next opening view")
	game.close_tree()
	saved.cell="removed-from-catalog"
	file = FileAccess.open(base+".growth-view.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(saved))
	file.close()
	game.open_tree()
	check(view.magnification>=2.75 and board.entries.has(board.selected),"removed bookmarked skill uses a readable valid starting skill")
	game.close_tree()
	saved.cell="cascade"
	saved.rank="removed-rank"
	file = FileAccess.open(base+".growth-view.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(saved))
	file.close()
	game.open_tree()
	check(board.selected=="cascade" and board.viewed_index()==0,"removed rank falls back to the bookmarked skill's current rank")
	game.close_tree()
	view.forget_book(base)
	check(not FileAccess.file_exists(base+".growth-view.json"),"clearing a slot removes only its view preference")
	game.saved_path = original
	game.open_tree()
	board.select_node("gather")

func check_catalog_preview() -> void:
	var board = game.ui.board
	var view = game.ui.growth_map
	var saved: Dictionary = game.model.to_payload()
	board.select_node("cascade")
	await tap(KEY_PAGEDOWN)
	var rank: Dictionary = board.inspect_data()
	check(rank.id=="cascade2" and rank.planned and game.ui.buy_button.disabled and game.ui.bay_button.visible,"late second rank describes its price and opens a demo")
	cues.clear()
	await pad(JOY_BUTTON_A)
	await tap(KEY_ENTER)
	check(cues.is_empty(),"confirming a future entry produces no purchase or refusal cue")
	check(saved==game.model.to_payload(),"confirm never buys an unavailable rank")
	await pad(JOY_BUTTON_X)
	check(board.inspect_data().id=="cascade1","pad switches the fixed detail page to the first rank")
	await tap(KEY_EQUAL)
	await frames(15)
	var at: Vector2 = board.position
	var zoom: float = view.magnification
	await pad(JOY_BUTTON_Y)
	check(game.mode=="growth_preview" and is_instance_valid(game.ui.bay_preview),"the selected cascade opens a native flower bay")
	await tap(KEY_4)
	await tap(KEY_EQUAL)
	await tap(KEY_ESCAPE)
	check(game.mode=="tree" and not is_instance_valid(game.ui.bay_preview),"Escape dismisses only the flower bay")
	check(board.selected=="cascade" and board.inspect_data().id=="cascade1" and at.is_equal_approx(board.position) and is_equal_approx(view.magnification,zoom),"return restores the exact selected rank and camera transform")
	check(saved==game.model.to_payload(),"playing the flower bay leaves the regional progress unchanged")
	check(not cues.has("book_close") and not cues.has("buy"),"browsing the flower bay preserves the open journal sound state")
	await tap(KEY_P)
	await pad(JOY_BUTTON_B)
	check(game.mode=="tree" and not is_instance_valid(game.ui.bay_preview),"keyboard shortcut opens and pad B returns to the same journal")
	await tap(KEY_HOME)
	board.select_node("gather")


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

func check_station_entrances() -> void:
	for target in ["shop","tree"]:
		game.model.p = Vector2(250,476) if target == "shop" else Vector2(875,410)
		game.ui.refresh()
		var wallet: Dictionary = game.model.to_payload()
		game.ui.hub_action.pressed.emit()
		check(game.mode == "station_entry" and game.world.station_entry == target, "painted landmark starts its own entrance")
		await frames(6)
		check(game.world.station_progress > 0.0 and not game.ui.shop.visible and not game.ui.tree.visible, "entrance moves before the menu is shown")
		await tap(KEY_ESCAPE)
		check(game.mode == "play" and game.world.station_entry.is_empty() and game.model.to_payload() == wallet, "cancel restores courtyard without a transaction")
		game.reduced_motion = true
		await tap(KEY_E)
		check(game.mode == target, "reduced motion opens the same station immediately")
		await tap(KEY_ESCAPE)
		game.reduced_motion = false

func check_shop_shelves() -> void:
	# Start just outside the left post. Ordinary D input must reveal the action on the upper shelf.
	game.model.p = Vector2(130,330)
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
	check(cues.back() == "shop_open" and game.sound._music[2].playing and game.sound.SHOP_MUSIC.loop, "opening the counter starts its own loop with a wood tap")
	game.close_shop()
	game.model.cargo.blue = 2
	game.model.p = Vector2(438,372)
	game.ui.refresh()
	game.ui.hub_action.pressed.emit()
	await wait_for_entrance()
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
	check(cues.back() == "shop_close","leaving the shop closes the drawer")
	for point in [Vector2(310,240),Vector2(540,390),Vector2(130,480)]:
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
	check(game.sound._music[0].stream == game.sound.SPRING and game.sound.SPRING.loop and game.sound._music[0].playing,"courtyard starts the looping spring recording")
	await tap(KEY_E)
	check(game.mode == "regions","entry opens destination")
	check(game.ui.meadow_button.disabled,"new profile cannot select purple")
	cues.clear()
	game.request_transition("pond")
	check(is_zero_approx(game.transition_elapsed),"courtyard departure keeps its dance")
	await tap(KEY_SPACE)
	await frames(4)
	check(game.model.area == "pond" and game.mode == "play","skip commits destination once")
	check(game.sound._area == "pond" and not game.sound._overlay, "pond music follows the committed area")
	check(game.sound._music[1].stream == game.sound.AUTUMN and game.sound.AUTUMN.loop and game.sound._music[1].playing and not game.sound._flute.playing,"pond starts the looping autumn recording without a flute cue")
	check(cues.count("depart_wind") == 1 and game.model.trip_index == 1,"one committed departure gives one rush of air")
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
	check(game.model.at_home() and cues.count("arrival_bell") == 1,"one bell on the saved return")
	await check_station_entrances()
	await check_shop_shelves()
	game.model.p = game.model.HUB_TREE
	cues.clear()
	await tap(KEY_E)
	check(game.ui.growth_map.magnification>=2.75 and game.ui.board.selected=="gather","first book opens on a readable introductory skill")
	check(not game.ui.buy_button.visible and game.ui.conditions.shown_rows.any(func(r): return r.kind=="cost"),"unaffordable rank shows how to earn the missing resource")
	check(cues == ["book_open"], "opening an unaffordable page only sounds the book")
	game.ui.last_denied_msec = -1000
	cues.clear()
	await tap(KEY_ENTER)
	check(game.ui.skill_note.visible and cues.is_empty(),"first confirm opens the selected note safely")
	await tap(KEY_ENTER)
	check(game.ui.buy_button.disabled and cues == ["denied"], "confirming an inspected unaffordable rank gives a quiet refusal")
	await tap(KEY_ESCAPE)
	check(cues.back() == "book_close", "closing the book turns the page once")
	game.model.coins = 1000
	game.model.materials = {"fiber":100,"resin":100}
	game.model.p = game.model.HUB_TREE
	await tap(KEY_E)
	await frames(48)
	var flute: AudioStreamOggVorbis = game.sound._flute.stream
	check(game.mode == "tree" and game.sound._flute.playing and flute.loop and flute.get_length() >= 90.0,"the book plays the full-length flute score on loop")
	check(is_zero_approx(game.sound._music[0].volume_linear),"the courtyard stays silent while reading")
	var phrase = game.sound._flute.get_stream_playback()
	game.ui.board.select_node("gather")
	await frames(5)
	check(game.sound._flute.get_stream_playback() == phrase,"browsing the growth map keeps the same solo")
	phrase = null
	game.sound._flute.seek(22.0)
	await frames(3)
	await tap(KEY_ESCAPE)
	await frames(16)
	await tap(KEY_E)
	await frames(48)
	check(game.sound._flute.playing and game.sound._flute.get_playback_position() >= 21.0,"reopening after a full fade returns to the current passage")
	await check_map_camera()
	await check_bookmark_rules()
	await check_catalog_preview()
	var paid: int = game.model.coins
	var board = game.ui.board
	check(board.visible_ids().size() == 41 and not board.buttons.shortcut.visible,"all 41 regional cells can be inspected from a fresh profile")
	await pad(JOY_BUTTON_DPAD_RIGHT)
	check(board.selected != "gather" and game.model.coins == paid,"direction selects a different cell without buying")
	var visited := {}
	for i in board.visible_ids().size():
		visited[board.selected] = true
		await tap(KEY_TAB)
	check(visited.size() == 41,"Tab visits every cell, including distant locked goals")
	board.select_node("twin")
	check(game.ui.buy_button.disabled and game.ui.detail_costs.coin.text == "29","locked double harvest shows its current regional price")
	await pad(JOY_BUTTON_A)
	check(game.model.coins == paid and not "twin" in game.model.owned,"confirming a locked cell cannot charge")
	await pad(JOY_BUTTON_B)
	check(game.mode == "play","controller back returns from journal to garden")
	await tap(KEY_E)
	board.select_node("gather")
	cues.clear()
	await pad(JOY_BUTTON_A)
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
	var working_save: String = game.saved_path
	cues.clear()
	game.saved_path = OS.get_temp_dir()
	game.request_transition("meadow")
	await tap(KEY_SPACE)
	check(game.model.area == "hub" and not cues.has("depart_wind"),"failed meadow travel leaves the courtyard score alone")
	game.saved_path = working_save
	game.open_regions()
	game.request_transition("meadow")
	await tap(KEY_SPACE)
	await frames(4)
	check(game.model.area == "meadow" and game.model.field.max_energy() == 50 and game.model.field.capacity() == 10,"incremental growth reaches actual field")
	await frames(12) # Let a rapid book-to-map transition finish its closing fade.
	check(game.sound._area == "meadow" and not game.sound._flute.playing and game.sound._music[1].playing, "meadow plays the autumn score with its leaf bed")
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
	game.start_game()
	game.model.field.p = game.model.field.layout.nodes[0].p
	game.model._sync_field()
	game.request_transition("hub")
	game._advance_transition(10.0)
	check(game.model.at_home() and game.model.last_region == "meadow","return from violet changes courtyard ink")
	var reload = game.new_model()
	check(reload.restore_payload(game.read_progress(game.saved_path).payload),"existing v2 economy file loads after a colour change")
	game.model = reload
	game._load_world()
	check(game.model.last_region == "meadow","cold load restores this slot's violet ink")
	await check_station_entrances()
	check(game.model.last_region == "meadow","browsing stations keeps the same ink")
	game.model.p = game.model.HUB_DEPART
	game.request_transition("pond")
	game._advance_transition(10.0)
	game.request_transition("hub")
	game._advance_transition(10.0)
	check(game.model.at_home() and game.model.last_region == "pond","next pond return restores teal ink")
	gate_inputs()
	game.queue_free()
	await frames(3)
	# The audio driver drains on wall time even with --fixed-fps.
	var drain_until := Time.get_ticks_msec() + 350
	while Time.get_ticks_msec() < drain_until:
		OS.delay_msec(10)
		await process_frame
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
