extends SceneTree

const Game = preload("res://region_game/main.tscn")
var game
var page
var checks := 0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", what)

func frames(count := 2) -> void:
	for i in count: await process_frame

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	root.push_input(event, true)

func tap(code: Key) -> void:
	key(code, true)
	key(code, false)
	await frames()

func pad(code: JoyButton, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 3
	event.button_index = code
	event.pressed = pressed
	root.push_input(event, true)

func press_pad(code: JoyButton) -> void:
	pad(code, true)
	pad(code, false)
	await frames()

func mouse(code: MouseButton, pressed: bool, position: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.position = position
	event.global_position = position
	event.button_index = code
	event.pressed = pressed
	root.push_input(event, true)

func click(button: Control) -> void:
	var at := button.get_global_rect().get_center()
	mouse(MOUSE_BUTTON_LEFT, true, at)
	mouse(MOUSE_BUTTON_LEFT, false, at)
	await frames()

func axis(code: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = 3
	event.axis = code
	event.axis_value = value
	root.push_input(event, true)

func new_game() -> void:
	game = Game.instantiate()
	root.add_child(game)
	page = game.ui.controls_page
	await frames(4)

func close_game() -> void:
	game.queue_free()
	await frames(3)
	# The audio driver drains on wall time even when test frames are accelerated.
	var until := Time.get_ticks_msec() + 350
	while Time.get_ticks_msec() < until:
		OS.delay_msec(10)
		await process_frame

func run() -> void:
	# Game saves and bindings must both be isolated when this script is run by hand.
	if not Array(OS.get_cmdline_user_args()).any(func(s): return s.begins_with("--progress-file=")):
		printerr("Pass --progress-file pointing to an empty test profile")
		quit(2)
		return
	await new_game()
	await press_pad(JOY_BUTTON_DPAD_DOWN)
	check(root.gui_get_focus_owner() == game.ui.menu_settings, "D-pad reaches settings from title")
	await press_pad(JOY_BUTTON_A)
	check(game.mode == "settings", "A opens focused settings")
	for i in 8:
		if root.gui_get_focus_owner() == game.ui.controls_button: break
		await press_pad(JOY_BUTTON_DPAD_DOWN)
	check(root.gui_get_focus_owner() == game.ui.controls_button, "D-pad reaches controls button")
	await press_pad(JOY_BUTTON_A)
	check(game.mode == "controls" and page.device == "pad", "controller opens its own binding table")
	if game.mode != "controls":
		quit(1)
		return
	for pixels in [Vector2i(1280,800), Vector2i(960,600)]:
		root.size = pixels
		await frames(3)
		check(page.scroll.size.y > 170 and page.scroll.get_h_scroll_bar().max_value <= page.scroll.size.x + 1, "rows fit width at " + str(pixels))
	for i in 10:
		if root.gui_get_focus_owner() == page.rows.interact.pad: break
		await press_pad(JOY_BUTTON_DPAD_DOWN)
	check(root.gui_get_focus_owner() == page.rows.interact.pad, "pure controller navigation reaches interact")
	await press_pad(JOY_BUTTON_A)
	check(page.pending_action == "interact", "confirm starts capture without rebinding to itself")
	await press_pad(JOY_BUTTON_X)
	check("已用于" in page.status.text and page.pending_action == "interact", "duplicate controller binding is rejected")
	await press_pad(JOY_BUTTON_B)
	check(page.pending_action.is_empty() and game.mode == "controls", "cancel leaves original assignment and keeps settings open")
	await press_pad(JOY_BUTTON_A)
	await press_pad(JOY_BUTTON_Y)
	check(game.bindings.action_for("pad",JOY_BUTTON_Y) == "interact", "saves replacement pad button")
	await click(page.tabs.kbm)
	await frames()
	page.scroll.ensure_control_visible(page.rows.interact.key)
	await frames()
	await click(page.rows.interact.key)
	await tap(KEY_M)
	check(page.pending_action == "interact" and not game.ui.muted, "capture consumes conflicting mute key")
	await tap(KEY_F)
	check(game.bindings.action_for("key",KEY_E).is_empty() and game.bindings.action_for("key",KEY_F) == "interact", "replaces original keyboard shortcut")
	await click(page.rows.pulse.mouse)
	mouse(MOUSE_BUTTON_MIDDLE,true,Vector2(640,380))
	mouse(MOUSE_BUTTON_MIDDLE,false,Vector2(640,380))
	await frames()
	check(game.bindings.action_for("mouse",MOUSE_BUTTON_MIDDLE) == "pulse" and game.bindings.action_for("mouse",MOUSE_BUTTON_RIGHT).is_empty(), "replaces mouse binding independently")
	await tap(KEY_ESCAPE)
	check(game.mode == "settings" and root.gui_get_focus_owner() == game.ui.controls_button, "back restores opening control focus")
	await press_pad(JOY_BUTTON_DPAD_DOWN)
	await press_pad(JOY_BUTTON_A)
	check(game.ui.settings_credits.is_visible_in_tree(), "controller opens the credits")
	for i in 8:
		await press_pad(JOY_BUTTON_DPAD_DOWN)
	var credits_bottom: float = game.ui.settings_credits.get_global_rect().end.y
	check(credits_bottom <= game.ui.settings_scroll.get_global_rect().end.y + 1, "controller can read the last credit line")
	await tap(KEY_ESCAPE)
	await tap(KEY_ENTER)
	check(game.mode == "play" and game.model.at_home(), "start through title")
	await tap(KEY_E)
	check(game.mode == "play" and game.ui.hub_action_key.text == "F", "old keyboard input is inactive, nearby sign shows new key")
	await tap(KEY_F)
	check(game.mode == "regions", "new keyboard shortcut opens station")
	await press_pad(JOY_BUTTON_B)
	await press_pad(JOY_BUTTON_Y)
	check(game.mode == "regions", "rebound controller operates courtyard gate")
	await press_pad(JOY_BUTTON_A)
	await press_pad(JOY_BUTTON_RIGHT_SHOULDER)
	await frames(4)
	check(game.mode == "play" and game.model.area == "pond", "fixed menu A chooses destination, dash skips dance")
	if game.model.field == null:
		quit(1)
		return
	var field = game.model.field
	var at: Vector2 = game.model.p
	axis(JOY_AXIS_LEFT_X, .08)
	await frames(4)
	check(at.distance_to(game.model.p) < 1, "stick drift stays within dead zone")
	axis(JOY_AXIS_LEFT_X,.85)
	await frames(22)
	axis(JOY_AXIS_LEFT_X,0)
	check(game.model.p.distance_to(at) > 12, "analog stick flies in the field")
	# Start by a stocked flower beyond the return sign. Drive the hold through the viewport.
	var flower: Dictionary = {}
	for candidate in field.flowers:
		if candidate.stock > 0 and candidate.p.distance_to(field.layout.nodes[0].p) > 240:
			flower = candidate
			break
	check(not flower.is_empty(), "harvest fixture supplies a reachable flower")
	if not flower.is_empty():
		field.p = flower.p
		field.v = Vector2.ZERO
		game.model._sync_field()
		pad(JOY_BUTTON_Y,true)
		await frames(145)
		pad(JOY_BUTTON_Y,false)
		check(game.model.cargo_total() > 0, "holding remapped controller button collects honey")
	pad(JOY_BUTTON_X,true)
	pad(JOY_BUTTON_X,false)
	await frames(2)
	check(game.event_log.any(func(e): return e.kind in ["pulse","pulse_empty"]), "quick controller wingbeat reaches model")
	pad(JOY_BUTTON_RIGHT_SHOULDER,true)
	await frames(30)
	pad(JOY_BUTTON_RIGHT_SHOULDER,false)
	await frames(3)
	check(game.event_log.any(func(e): return e.kind == "dash"), "hold then release shoulder button dashes")
	await press_pad(JOY_BUTTON_START)
	check(game.mode == "pause" and root.gui_get_focus_owner() == game.ui.pause_folio.buttons[0], "Start opens the folio on Continue")
	await press_pad(JOY_BUTTON_DPAD_DOWN)
	await press_pad(JOY_BUTTON_A)
	check(game.mode == "journal" and "Y" in game.ui.journal_controls.text, "guide shows the rebound controller action")
	await press_pad(JOY_BUTTON_B)
	await click(game.ui.pause_folio.buttons[3])
	await click(game.ui.controls_button)
	check(game.mode == "controls", "pause settings reaches the same binding table")
	await close_game()
	await new_game()
	check(game.bindings.action_for("pad",JOY_BUTTON_Y) == "interact" and game.bindings.action_for("key",KEY_F) == "interact" and game.bindings.action_for("mouse",MOUSE_BUTTON_MIDDLE) == "pulse", "fresh game loads all three slots")
	await click(game.ui.menu_settings)
	await click(game.ui.controls_button)
	await click(page.reset_button)
	check(game.bindings.action_for("key",KEY_E) == "interact" and game.bindings.action_for("pad",JOY_BUTTON_A) == "interact" and game.bindings.action_for("mouse",MOUSE_BUTTON_RIGHT) == "pulse", "restore defaults resets every device")
	await close_game()
	print("Honey controls: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
