extends SceneTree
## Drive the exported pack with an isolated slot, then check it in a fresh process.

func _initialize() -> void:
	call_deferred("run")

func frames(count: int) -> void:
	for frame in count:
		await process_frame

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func tap(code: Key) -> void:
	key(code, true)
	await frames(2)
	key(code, false)
	await frames(2)

func fail(reason: String) -> void:
	printerr("Honey package smoke failed: ", reason)
	quit(1)

func run() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.has("--cold") and not args.has("--fresh"):
		fail("specify --fresh or --cold")
		return
	var isolated := ""
	for arg in args:
		if arg.begins_with("--slot-dir="):
			isolated = arg.trim_prefix("--slot-dir=")
	if not isolated.is_absolute_path() or not DirAccess.dir_exists_absolute(isolated):
		fail("an existing isolated slot directory is required")
		return
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
	await frames(15)
	var game = current_scene
	if game == null or game.scene_file_path != "res://region_game/main.tscn":
		fail("unexpected default entry")
		return
	var cold := args.has("--cold")
	if game.saved_path.get_base_dir() != isolated or game.has_save != cold or game.save_blocked:
		fail("unexpected slot or title state")
		return
	if cold:
		var payload: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(game.saved_path))
		var saved: Array = payload.profile.p
		if not game.model.p.is_equal_approx(Vector2(saved[0], saved[1])):
			fail("position did not survive restart")
			return
	await tap(KEY_ENTER)
	if game.mode != "play" or game.model.area != "hub":
		fail("did not enter courtyard")
		return
	var start: Vector2 = game.model.p
	key(KEY_D, true)
	await frames(15)
	key(KEY_D, false)
	await tap(KEY_ESCAPE)
	if game.mode != "pause" or game.model.p.distance_to(start) < 4 or not FileAccess.file_exists(game.saved_path):
		fail("movement or pause-save failed")
		return
	print("HONEY_STEAM_SMOKE_OK ", "cold" if cold else "fresh")
	game.quit_game()
