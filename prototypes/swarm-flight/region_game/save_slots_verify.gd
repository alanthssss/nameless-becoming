extends SceneTree

# Use the normal driver and interface with a private save directory.
class IsolatedGame extends "res://region_game/main.gd":
	var test_path: String
	var quit_requested := false

	func default_progress_path() -> String:
		return test_path

	func finish_quit() -> void:
		quit_requested = true

var game: IsolatedGame
var directory := OS.get_temp_dir().path_join("honey-slots-%s-%s" % [OS.get_process_id(),Time.get_ticks_usec()])
var errors := 0
var checks := 0
var capture_dir := ""

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		errors += 1
		printerr("FAIL ",label," mode=",game.mode," device=",game.input_device,
				" focus=",root.gui_get_focus_owner()," pointer=",root.get_mouse_position())

func boot() -> void:
	if is_instance_valid(game):
		game.free()
	game = IsolatedGame.new()
	game.test_path = directory.path_join("legacy.json")
	game.bindings.path = directory.path_join("controls.cfg")
	root.add_child(game)
	game.set_process(false)

func tap(code: Key) -> void:
	for down in [true,false]:
		var input := InputEventKey.new()
		input.keycode = code
		input.physical_keycode = code
		input.pressed = down
		root.push_input(input,true)
		await process_frame

func pad(button: JoyButton) -> void:
	for down in [true,false]:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = down
		root.push_input(event,true)
		await process_frame

func click(button: Button) -> void:
	var at := button.get_global_rect().get_center()
	var movement := InputEventMouseMotion.new()
	movement.position = at
	movement.global_position = at
	root.push_input(movement,true)
	for down in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = at
		event.global_position = at
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		root.push_input(event,true)
		await process_frame

func visible_text(node: Node) -> String:
	if node is CanvasItem and not node.is_visible_in_tree(): return ""
	var words: String = node.text if node is Label or node is Button else ""
	for child in node.get_children():
		words += " " + visible_text(child)
	return words

func check_folio_sizes() -> void:
	var folio = game.ui.pause_folio
	for size_px in [Vector2i(1280,800),Vector2i(960,600)]:
		root.size = size_px
		for i in 5: await process_frame
		var focused := root.gui_get_focus_owner()
		check(folio.is_visible_in_tree() and focused == folio.buttons[0],"opening focus survives resize to "+str(size_px))
		# On the 1583×993 approved folio the page's right edge is at 41%.
		var page_side: Rect2 = game.ui.get_global_rect()
		page_side.size.x *= 0.43
		var targets: Array[Rect2] = []
		var accessible := true
		var separate := true
		for button: Button in folio.buttons:
			var bounds := button.get_global_rect()
			accessible = accessible and button.is_visible_in_tree() and not button.disabled and bounds.has_area() and page_side.encloses(bounds)
			for other in targets:
				separate = separate and not bounds.intersects(other)
			targets.append(bounds)
		check(targets.size() == 6 and accessible and separate,"all six independent actions fit the left page at "+str(size_px))
		if not capture_dir.is_empty():
			await RenderingServer.frame_post_draw
			var frame := root.get_texture().get_image()
			var name := "%s-%dx%d.png" % [game.model.area,size_px.x,size_px.y]
			check(frame.get_size() == size_px and frame.save_png(capture_dir.path_join(name)) == OK,"capture "+name)

func check_courtyard_folio() -> void:
	await tap(KEY_ESCAPE)
	var folio = game.ui.pause_folio
	var buttons: Array = folio.buttons
	var words := visible_text(folio)
	check(game.mode == "pause" and not game.ui.menu.visible and root.gui_get_focus_owner() == buttons[0],"Escape opens the folio on Continue")
	for label in ["歇一会儿","继续这趟出行","花路手册","选择存档","设置","新的一轮","保存并退出","Esc"]:
		check(label in words,"folio shows "+label)
	check("存档2" in words.replace(" ","").replace("　",""),"the folio identifies the active second slot")
	check(folio.status.text == game.model.goal_text(), "header shows the objective for the loaded profile")
	check(folio.version.text == ("Demo 0.32.7" if OS.has_feature("pond_feedback") else "Demo 0.29.0"), "folio shows this build's version")
	await check_folio_sizes()
	await pad(JOY_BUTTON_DPAD_DOWN)
	check(root.gui_get_focus_owner() == buttons[1] and "B" in visible_text(folio) and "Esc" not in visible_text(folio),"D-pad reaches the guide and switches the return hint")
	await pad(JOY_BUTTON_A)
	check(game.mode == "journal" and not folio.is_visible_in_tree(),"A opens the field guide")
	await pad(JOY_BUTTON_B)
	check(game.mode == "pause" and root.gui_get_focus_owner() == buttons[1],"B returns from the guide to its opener")
	await tap(KEY_DOWN)
	check(root.gui_get_focus_owner() == buttons[2],"down selects the slot browser")
	await tap(KEY_ENTER)
	check(game.mode == "slots" and root.gui_get_focus_owner() == game.ui.slot_buttons[2],"Enter opens the active slot")
	await tap(KEY_ESCAPE)
	check(game.mode == "pause" and root.gui_get_focus_owner() == buttons[2],"Escape returns to the slot opener")
	await click(buttons[3])
	check(game.mode == "settings","click opens settings")
	await tap(KEY_ESCAPE)
	check(game.mode == "pause" and root.gui_get_focus_owner() == buttons[3],"settings returns to its opener")
	var prior: Dictionary = game.model.to_payload()
	await pad(JOY_BUTTON_DPAD_DOWN)
	await pad(JOY_BUTTON_A)
	check(game.ui.restart_dialog.visible and root.gui_get_focus_owner() == game.ui.restart_cancel,"New Round opens on Cancel")
	await pad(JOY_BUTTON_B)
	check(not game.ui.restart_dialog.visible and root.gui_get_focus_owner() == buttons[4] and game.model.to_payload() == prior,"cancel preserves the outing and restores the restart focus")
	await pad(JOY_BUTTON_DPAD_RIGHT)
	check(root.gui_get_focus_owner() == buttons[5],"the right arrow reaches Save and Quit")
	await click(buttons[0])
	check(game.mode == "play" and not folio.is_visible_in_tree(),"click on Continue resumes the garden")

func check_field_quit_and_resume() -> void:
	await pad(JOY_BUTTON_START)
	check(game.mode == "pause" and game.world.area_key == "pond","Start pauses the running field")
	await check_folio_sizes()
	# Change a fixture value after the pause autosave to distinguish the quit write.
	game.model.coins += 4
	var expected: Dictionary = game.model.to_payload()
	await click(game.ui.pause_folio.buttons[5])
	check(game.quit_requested,"Save and Quit finishes only after saving")
	boot()
	check(game.mode == "title" and game.active_slot == 1 and game.has_save,"cold driver opens the saved active slot")
	await tap(KEY_ENTER)
	check(game.mode == "play" and game.world.area_key == "pond" and game.model.to_payload() == expected,"cold Continue restores the field and the quit write")

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): capture_dir = arg.trim_prefix("--capture-dir=")
	if not capture_dir.is_empty():
		if DisplayServer.get_name() == "headless" or DirAccess.make_dir_recursive_absolute(capture_dir) != OK:
			printerr("A screenshot run requires a native window and a writable capture directory")
			quit(2)
			return
	if DirAccess.make_dir_absolute(directory) != OK:
		quit(1)
		return
	boot()
	game.open_slots()
	game.quit_game()
	check(game.quit_requested and not FileAccess.file_exists(game.saved_path),"browsing and closing a fresh title leaves slot 1 empty")
	game.close_slots()

	# Seed the exact pre-slot format and original filename.
	var old = game.new_model()
	old.coins = 19
	old.materials.fiber = 3
	old.p = old.HUB_DEPART
	check(old.transition_to("pond"),"legacy outing created")
	var first := game.slot_path(1)
	check(game.Save.write_payload(old.to_payload(),first,game.new_model()),"legacy fixture saved")
	var original := FileAccess.get_file_as_bytes(first)
	boot()
	check(game.has_save and game.active_slot == 1 and game.model.area == "pond" and game.model.coins == 19,"legacy title restores slot 1")
	game.ui.menu_slots.grab_focus()
	await tap(KEY_ENTER)
	var rows := game.slot_rows()
	check(game.mode == "slots" and rows[0].status == "occupied" and rows[0].area == game.area_name("pond") and rows[0].coins == 19 and rows[1].status == "empty" and rows[2].status == "empty","keyboard opens three accurate summaries")
	await tap(KEY_ESCAPE)
	check(game.mode == "title" and FileAccess.get_file_as_bytes(first) == original,"cancel leaves original bytes untouched")

	game.open_slots()
	game.ui.slot_buttons[2].grab_focus()
	await tap(KEY_ENTER)
	check(game.active_slot == 2 and game.mode == "play" and game.model.at_home() and game.model.coins == 0,"keyboard starts a fresh second slot")
	await check_courtyard_folio()
	game.model.coins = 7
	game.pause_game()
	game.open_slots()
	game.choose_slot(3)
	check(game.active_slot == 3 and game.model.coins == 0,"third slot also starts independently")
	game.pause_game()
	game.open_slots()
	game.choose_slot(2)
	check(game.model.coins == 7 and FileAccess.get_file_as_bytes(first) == original,"returning to slot 2 restores its own coins and preserves the old file")
	boot()
	check(game.active_slot == 2 and game.has_save and game.model.coins == 7,"cold startup remembers and loads the last slot")
	game.start_game()
	game.pause_game()
	var third := game.slot_path(3)
	var broken := FileAccess.open(third,FileAccess.WRITE)
	broken.store_string("broken")
	broken.close()
	game.open_slots()
	check(game.slot_rows()[2].status == "blocked" and game.ui.slot_buttons[3].disabled,"damaged slot is distinct from an empty slot")
	game.choose_slot(3)
	check(game.mode == "slots" and game.active_slot == 2 and FileAccess.get_file_as_string(third) == "broken","failed target preserves both slots")
	game.close_slots()
	var second := game.saved_path
	game.saved_path = directory.path_join("missing/unwritable")
	game.open_slots()
	check(game.mode == "pause" and game.model.coins == 7 and game.active_slot == 2,"failed save blocks switching and retains the running game")
	check("保存失败" in game.ui.pause_folio.status.text, "failed switch leaves a persistent save warning on the folio")
	game.saved_path = second
	game.restart_game()
	check(game.model.coins == 0 and FileAccess.get_file_as_bytes(first) == original and FileAccess.get_file_as_string(third) == "broken","restart only resets the selected slot")
	var found_backup := false
	for filename in DirAccess.get_files_at(directory):
		if filename.begins_with(second.get_file()+".backup-"):
			var recovered = game.new_model()
			found_backup = not game.Save.read_payload(directory.path_join(filename),recovered).is_empty() and recovered.coins == 7
	check(found_backup,"restarting an occupied slot retains a usable backup")
	game.pause_game()
	game.open_slots()
	game.choose_slot(1)
	check(game.model.area == "pond" and game.model.coins == 19 and game.model.materials.fiber == 3 and game.model.trip_index == 1,"switch back restores the old outing and inventory")
	await check_field_quit_and_resume()
	game.free()
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(filename))
	DirAccess.remove_absolute(directory)
	# The audio driver releases stopped streams on wall time even under --fixed-fps.
	var drain_until := Time.get_ticks_msec() + 350
	while Time.get_ticks_msec() < drain_until:
		OS.delay_msec(10)
		await process_frame
	print("Honey save slots: %d checks, %d failures" % [checks,errors])
	quit(1 if errors else 0)
