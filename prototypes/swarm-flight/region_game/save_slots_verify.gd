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

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		errors += 1
		printerr("FAIL ",label)

func boot() -> void:
	if is_instance_valid(game):
		game.free()
	game = IsolatedGame.new()
	game.test_path = directory.path_join("legacy.json")
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

func run() -> void:
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
