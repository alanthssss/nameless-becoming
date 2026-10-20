extends SceneTree

const Main = preload("res://main.tscn")
const MERGE_ROUTE := [1,0,1,1,0,0,1,1,0,0,1,1,1,1,0,0,1,1,1,0,1,2,2,1,1,1,0,0,1,1,0,1,0,1,0,1,0,2,0,1,0,1,1,0,0,1,1,0,1,1,2,1,0,1,2,0,1,1,1,2,1,2,1,3,1,2,1,1,0,1,2,2,1,0,1,0,0]
const MATCH_ROUTE := [[13,19],[7,8],[10,11],[13,14],[9,15],[9,10],[2,3],[3,4],[10,11],[3,9],[8,9],[8,14],[1,7],[7,8]]
const KEYS := [KEY_LEFT,KEY_UP,KEY_RIGHT,KEY_DOWN]
var game
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, description: String) -> void:
	checks += 1
	if not value: failures.append(description)

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	root.push_input(event)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event)

func mouse_at(index: int, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = game.board.get_global_transform()*game.board.cell_rect(index).get_center()
	event.global_position = event.position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	root.push_input(event)

func click_cell(index: int) -> void:
	mouse_at(index,true)
	mouse_at(index,false)

func aim_at(index: int) -> void:
	# Navigate with real keyboard events; never write the cursor for a route.
	for i in 6:
		if game.cursor%6 < index%6: key(KEY_RIGHT)
		elif game.cursor%6 > index%6: key(KEY_LEFT)
	for i in 6:
		if game.cursor/6 < index/6: key(KEY_DOWN)
		elif game.cursor/6 > index/6: key(KEY_UP)

func settle() -> void:
	for i in 1000:
		if not game.busy: break
		game.tick(0.1)
	check(not game.busy,"animation resolves within a bounded time")

func shot(name: String) -> void:
	var directory := OS.get_environment("PUZZLE_UI_CAPTURE_DIR")
	if directory.is_empty() or DisplayServer.get_name() == "headless": return
	await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png(directory.path_join(name+".png"))
	check(result == OK,"native capture "+name)

func run() -> void:
	root.size = Vector2i(1280,800)
	game = Main.instantiate()
	root.add_child(game)
	game.set_process(false)
	game.qa_seed = 1
	game.toggle_sound()
	await process_frame
	await process_frame
	check(game.mode == "title" and game.menu_buttons.size() == 2,"title offers exactly two samples")
	await shot("01-title")
	key(KEY_ENTER)
	await process_frame
	await process_frame
	check(game.mode == "play" and game.kind == "merge","title keyboard starts merge")
	check(game.board.get_global_rect().end.y <= 800 and game.arrows.get_global_rect().end.y <= 800,"merge controls fit reference viewport")
	await shot("02-merge")
	var before: Array = game.model.board.duplicate()
	key(KEY_UP)
	var after: Array = game.model.board.duplicate()
	key(KEY_LEFT)
	check(game.busy and game.model.moves == 1 and game.model.board == after,"merge ignores extra input while sliding")
	key(KEY_ESCAPE)
	var paused_time: float = game.frame_time
	game.tick(1)
	check(game.mode == "pause" and game.frame_time == paused_time,"pause freezes in-flight animation")
	key(KEY_ESCAPE)
	settle()
	key(KEY_Z)
	check(game.model.moves == 0 and game.model.board == before and not game.model.can_undo(),"UI undo restores opening")
	for direction in MERGE_ROUTE:
		key(KEYS[direction])
		settle()
	check(game.mode == "result" and game.model.phase == "won" and game.model.board.has(128),"entire 77-move merge game reaches visible success")
	check(game.model.moves == 77 and game.modal.visible,"merge result has final move count")
	await shot("03-merge-won")
	key(KEY_ENTER)
	check(game.mode == "play" and game.model.moves == 0,"merge replay starts fresh")
	key(KEY_ESCAPE)
	key(KEY_DOWN)
	key(KEY_DOWN)
	key(KEY_ENTER)
	check(game.mode == "title","pause menu returns to chooser")
	key(KEY_RIGHT)
	key(KEY_ENTER)
	await process_frame
	await process_frame
	check(game.kind == "match" and game.model.moves_left == 18,"chooser starts match")
	check(game.board.get_global_rect().end.y <= 800 and not game.undo_button.visible,"match fits with mode-specific controls")
	await shot("04-match")
	before = game.model.board.duplicate()
	click_cell(13)
	mouse_at(0,true)
	mouse_at(19,false)
	check(not game.busy and game.model.board == before and game.model.moves_left == 18,"non-adjacent drag cannot exchange a stale selection")
	key(KEY_ESCAPE)
	click_cell(0)
	check(game.selected == 0,"viewport mouse click selects a flower")
	key(KEY_ESCAPE)
	check(game.selected == -1 and game.mode == "play","escape cancels selection before pausing")
	# Seed 1 pair 0/1 makes no match; verify continuous forward/reverse snapshots.
	click_cell(0)
	click_cell(1)
	check(game.busy and game.model.moves_left == 18 and game.model.board == before,"invalid adjacent click exchange is free")
	check(game.frames.size() == 2 and game.frames[1].values[0] == before[1] and game.frames[1].values[1] == before[0],"invalid swap animation reverses the attempted board")
	settle()
	for i in MATCH_ROUTE.size():
		var pair: Array = MATCH_ROUTE[i]
		if i%3 == 0:
			click_cell(pair[0])
			click_cell(pair[1])
		elif i%3 == 1:
			mouse_at(pair[0],true)
			mouse_at(pair[1],false)
		else:
			aim_at(pair[0])
			key(KEY_ENTER)
			aim_at(pair[1])
			key(KEY_ENTER)
		check(game.busy,"match route accepts mouse, drag, or keyboard move %d" % i)
		var remaining: int = game.model.moves_left
		click_cell(0)
		check(game.model.moves_left == remaining,"match animation blocks further exchanges")
		settle()
	check(game.mode == "result" and game.model.phase == "won" and game.shown_collected >= 60,"entire 14-swap match game reaches visible success")
	check(game.model.moves_left == 4,"match win consumes exactly 14 valid moves")
	await shot("05-match-won")
	key(KEY_ENTER)
	check(game.mode == "play" and game.model.collected == 0 and game.model.moves_left == 18,"match replay resets counters")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(game.mode == "pause","leaving application automatically pauses")
	key(KEY_ESCAPE)
	# Explicit boundary fixtures below are separate from the two complete input routes.
	game.model.moves_left = 1
	var pair: Vector2i = game.model.legal_moves()[0]
	click_cell(pair.x)
	click_cell(pair.y)
	settle()
	check(game.mode == "result" and game.model.phase == "lost","last-step failure fixture reaches visible result")
	await shot("06-match-lost")
	key(KEY_DOWN)
	key(KEY_ENTER)
	key(KEY_ENTER)
	check(game.kind == "merge" and game.mode == "play","result chooser can switch back to merge")
	game.model.board.assign([0,2,4,8,4,8,16,32,8,16,32,64,16,32,64,2])
	key(KEY_LEFT)
	settle()
	check(game.mode == "result" and game.model.phase == "lost","merge blocked-board fixture reaches result")
	key(KEY_ENTER)
	check(game.mode == "play" and game.model.phase == "playing" and not game.model.can_undo(),"loss result offers a functional one-step undo")
	key(KEY_ESCAPE)
	key(KEY_DOWN)
	key(KEY_ENTER)
	check(game.model.moves == 0 and game.model.board.count(0) == 14,"pause restart resets the same seed")
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("GARDEN PUZZLES UI VERIFIED: %d checks; complete merge and match input routes, boundary fixtures separate" % checks)
		quit(0)
	else:
		for failure in failures: printerr("FAIL: "+failure)
		quit(1)
