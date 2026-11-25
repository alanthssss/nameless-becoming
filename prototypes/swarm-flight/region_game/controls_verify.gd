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

func has_only_single_lines() -> bool:
	for label in page.find_children("*", "Label", true, false):
		if label.is_visible_in_tree() and label.get_line_count() > 1:
			return false
	return true

func check_sections() -> void:
	# Start from the device tab. The fixed tables must work with just the D-pad.
	await press_pad(JOY_BUTTON_DPAD_DOWN)
	for title in ["菜单","成长树","花湾"]:
		await press_pad(JOY_BUTTON_DPAD_RIGHT)
		check(root.gui_get_focus_owner() == page.sections[title], "D-pad reaches " + title)
		await press_pad(JOY_BUTTON_A)
		check(page.section == title and page.reference.is_visible_in_tree() and not page.flight.visible, "only selected reference is visible: " + title)
		check(has_only_single_lines() and not page.reset_button.visible, "fixed shortcuts are single lines and read-only: " + title)
		var last: Control = page.reference.get_child(-1)
		check(page.scroll.get_global_rect().encloses(last.get_global_rect()), "last shortcut visible from section tab: " + title)
	await click(page.tabs.kbm)
	var harvest: Control = page.reference.get_child(2)
	var captions: Array = harvest.find_children("*", "Label", true, false).map(func(label): return label.text)
	check(captions == ["采蜜", "按住", "E", "或", "空格"], "switching device shows the two fixed harvest inputs with their hold instruction")
	await click(page.sections["飞行"])
	check(page.scroll.get_global_rect().encloses(page.rows.mute.mouse.get_global_rect()) and has_only_single_lines(), "all keyboard and mouse bindings fit on entry")
	await click(page.tabs.pad)
	check(page.flight.is_visible_in_tree() and not page.reference.visible and has_only_single_lines(), "flight table has no guide paragraphs")

func check_reference_bounds() -> void:
	for device in ["kbm", "pad"]:
		await click(page.tabs[device])
		for title in ["菜单", "成长树", "花湾"]:
			await click(page.sections[title])
			var viewport_rect: Rect2 = page.scroll.get_global_rect()
			var all_visible := true
			for caption: Label in page.reference.find_children("*", "Label", true, false):
				all_visible = all_visible and viewport_rect.grow(1).encloses(caption.get_global_rect())
			check(all_visible, "%s %s %s fits every fixed keycap" % [root.size, device, title])
	await click(page.sections["飞行"])
	await click(page.tabs.pad)

func check_live_keycaps() -> void:
	await click(page.tabs.kbm)
	var up = page._keycaps(page.rows.up.key)
	check(up.get_child_count() == 3 and up.get_child(0).text == "W" and up.get_child(2).text == "↑", "movement alternatives have separate caps")
	var pulse = page._keycaps(page.rows.pulse.key)
	var original_q = pulse.get_child(0).get_theme_stylebox("normal").texture
	check(original_q == pulse.PAINTED_Q and page.rows.up.mouse.text == "未绑定", "default Q uses approved artwork and empty slots remain editable")
	await click(page.rows.pulse.key)
	check(not pulse.visible and page.rows.pulse.key.text == "等待输入…", "capture replaces only the active keycap")
	await tap(KEY_M)
	check(not pulse.visible and page.rows.pulse.key.text == "请换一个键", "conflict keeps the active cell distinct")
	await tap(KEY_ESCAPE)
	check(pulse.visible and pulse.get_child(0).text == "Q", "cancel restores the painted Q")
	await click(page.rows.pulse.key)
	await tap(KEY_PAGEDOWN)
	var long_cap: Label = pulse.get_child(0)
	check(long_cap.text == game.bindings.label("pulse","key") and long_cap.get_theme_stylebox("normal").texture == pulse.WAX, "remapping Q to PageDown uses the live key name on blank wax")
	check(page.rows.pulse.key.get_global_rect().encloses(long_cap.get_global_rect()), "long keycap fits the editable slot")
	await click(page.rows.mute.key)
	await tap(KEY_Q)
	var moved_q = page._keycaps(page.rows.mute.key).get_child(0)
	check(moved_q.text == "Q" and moved_q.get_theme_stylebox("normal").texture == original_q, "painted Q follows its new action")
	await click(page.rows.mute.key)
	await tap(KEY_SLASH)
	check(page._keycaps(page.rows.mute.key).get_child_count() == 1, "slash remains a single input")
	await click(page.reset_button)
	await click(page.tabs.pad)

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
		check(page.scroll.get_global_rect().encloses(page.rows.mute.pad.get_global_rect()) and has_only_single_lines(), "all pad bindings fit on entry at " + str(pixels))
		await check_reference_bounds()
	await check_sections()
	await check_live_keycaps()
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
