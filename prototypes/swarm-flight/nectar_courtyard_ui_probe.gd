extends SceneTree
## Positioned developer UI fixtures, not player or first-discovery evidence.
const Scene = preload("res://region_game/main.tscn")
var game
var output := ""
var checks := 0
var failures: Array[String] = []
var input_trace: Array[Dictionary] = []

func _initialize() -> void: call_deferred("run")
func check(ok: bool, words: String) -> void:
	checks += 1
	if not ok:
		failures.append(words)
		push_error(words)
func frames(n: int) -> void:
	for i in n: await process_frame
func _push_key(code: Key, pressed: bool) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = pressed
	root.push_input(e,true)
func tap(code: Key) -> void:
	for pressed in [true,false]:
		_push_key(code,pressed)
		await frames(2)
func _push_mouse(at: Vector2, pressed: bool) -> void:
	# Re-establish viewport-local hover immediately before the event. Native OS
	# pointer updates are independent from Viewport.push_input's synthetic motion.
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	motion.button_mask = 0 if pressed else MOUSE_BUTTON_MASK_LEFT
	root.push_input(motion,true)
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.position = at
	e.global_position = at
	e.pressed = pressed
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	root.push_input(e,true)
	var button: Button = game.ui.hub_action
	input_trace.append({"pressed":pressed,"at":[at.x,at.y],"mode":game.mode,
		"action":game.model.interaction(),"button_rect":str(button.get_global_rect()),
		"button_hovered":button.is_hovered(),"button_pressed":button.is_pressed(),
		"button_focus":button.has_focus(),"window_focus":root.has_focus(),
		"window_size":str(root.size),"viewport_rect":str(root.get_visible_rect()),
		"stretch_transform":str(root.get_stretch_transform()),"final_transform":str(root.get_final_transform())})
func mouse(at: Vector2, pressed: bool) -> void:
	_push_mouse(at,pressed)
	await frames(2)
func hover(at: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = at
	e.global_position = at
	root.push_input(e,true)
	await frames(2)
func capture(name: String) -> void:
	if output.is_empty() or DisplayServer.get_name() == "headless": return
	await frames(3)
	RenderingServer.force_draw()
	check(root.get_texture().get_image().save_png(output.path_join(name+".png")) == OK,"capture "+name)

func run() -> void:
	var isolated := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): output = arg.trim_prefix("--capture-dir=")
		if arg.begins_with("--progress-file="): isolated = true
	if not isolated: quit(2); return
	if not output.is_empty(): DirAccess.make_dir_recursive_absolute(output)
	game = Scene.instantiate()
	root.add_child(game)
	await frames(8)
	game.start_game()
	for pixels in [Vector2i(1280,800),Vector2i(960,600)]:
		root.size = pixels
		await frames(12) # Allow native window resize / canvas scaling to settle.
		for station in [{"p":game.model.HUB_TREE,"kind":"tree","mode":"tree"},{"p":game.model.HUB_SHOP,"kind":"shop","mode":"shop"},{"p":game.model.HUB_DEPART,"kind":"depart","mode":"regions"}]:
			if game.mode != "play": game.start_game() # Explicit recovery; an earlier failed check stays failed.
			game.model.p = station.p
			game.model.v = Vector2.ZERO
			game.ui.refresh()
			await frames(4)
			var b: Button = game.ui.hub_action
			check(b.is_visible_in_tree(),"near "+station.kind+" shows interaction at "+str(pixels))
			check(Rect2(0,0,1280,800).encloses(b.get_global_rect()),"station control stays inside canvas")
			await hover(Vector2(1250,750))
			await capture(station.kind+"-normal-"+str(pixels.x))
			await hover(b.get_global_rect().get_center())
			await capture(station.kind+"-hover-"+str(pixels.x))
			b.grab_focus()
			await capture(station.kind+"-focus-"+str(pixels.x))
			# Deliver the actual click atomically, without OS focus/mouse events
			# entering between press and release during multi-frame PNG capture.
			# Pressed state is asserted directly; held-mouse visuals require a
			# separate ordinary-native-input observation, not a synthetic still.
			var click_at := b.get_global_rect().get_center()
			_push_mouse(click_at,true)
			check(game.mode == "play" and not game.mouse_collect,"press is consumed without collecting or premature activation")
			check(b.is_pressed(),"mouse down reaches actual station Button")
			_push_mouse(click_at,false)
			await frames(2)
			check(game.mode == station.mode,"release opens "+station.mode)
			check(not game.ui.hud.visible and not game.mouse_collect,"station hides flight HUD and releases controls")
			# E is a separate assertion, not a consequence of a successful click.
			if game.mode != "play": await tap(KEY_ESCAPE)
			await tap(KEY_E)
			check(game.mode == station.mode,"E remains equivalent for "+station.kind)
			if game.mode != "play": await tap(KEY_ESCAPE)
		game.model.p = game.model.HUB_TREE
		game.ui.refresh()
		await frames(3)
		var stale_at: Vector2 = game.ui.hub_action.get_global_rect().get_center()
		game.model.p = Vector2(1200,700)
		await hover(stale_at)
		await mouse(stale_at,true)
		await mouse(stale_at,false)
		check(game.mode == "play","stale prompt cannot interact outside station radius")
		game.ui.refresh()
		check(not game.ui.hub_action.visible,"away from stations hides affordance")
		game.model.p = game.model.HUB_TREE+Vector2(-99,0)
		game.model.v = Vector2.ZERO
		game.ui.refresh()
		# Render frames can be shorter than a physics tick without --fixed-fps.
		# Hold ordinary input until observed movement crosses the station radius,
		# with a real monotonic deadline rather than assuming two frames move it.
		var movement_start := Time.get_ticks_msec()
		_push_key(KEY_A,true)
		while game.model.interaction() == "tree" and Time.get_ticks_msec()-movement_start < 1000:
			await physics_frame
		_push_key(KEY_A,false)
		var movement_held_ms := Time.get_ticks_msec()-movement_start
		await frames(3)
		input_trace.append({"event":"leave_station","held_wall_ms":movement_held_ms,
			"distance":game.model.p.distance_to(game.model.HUB_TREE),"mode":game.mode,
			"action":game.model.interaction(),"prompt_visible":game.ui.hub_action.visible,
			"window_size":str(root.size)})
		check(game.model.interaction().is_empty() and not game.ui.hub_action.visible,"ordinary movement crossing radius clears prompt")
	game.model.p = game.model.HUB_TREE
	game.model.v = Vector2.ZERO
	game.ui.refresh()
	game.ui.hub_action.grab_focus()
	await tap(KEY_ENTER)
	check(game.mode == "tree","focused station opens with Enter")
	game.close_tree()
	game.set_process(false) # Freeze this labelled low-stamina UI fixture in the restoring courtyard.
	game.model.energy = 7
	game.ui.refresh()
	await capture("hud-low")
	check(game.ui.energy_text.text == "7 / 36","low stamina retains explicit numerical reading")
	if not output.is_empty():
		var file := FileAccess.open(output.path_join("courtyard-ui-result.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify({"checks":checks,"failures":failures,"classification":"positioned developer UI fixtures; viewport-injected atomic clicks, not OS/player validation", "input_trace":input_trace,"timing":"--fixed-fps changes simulated frame delta, not OS focus/event delivery or wall-clock screenshot timing; no timing/product latency claims","pressed_visuals":"not captured by this probe; direct Button pressed-state assertions plus separate native observation required"},"\t"))
	print("COURTYARD UI VERIFIED ",checks," / ",failures.size())
	game.queue_free()
	await frames(3)
	quit(0 if failures.is_empty() else 1)
