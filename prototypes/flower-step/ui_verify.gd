extends SceneTree
## Engine-internal integration test: real scene/buttons/animations, no OS input.
const MainScene = preload("res://main.tscn")
const Model = preload("res://game_model.gd")
const ROUTES := [
	[Vector2i(1,1),Vector2i(4,1),Vector2i(7,1),Vector2i(8,1),"wait"],
	[Vector2i(1,1),Vector2i(3,1),"wait",Vector2i(6,1),Vector2i(8,1)],
	[Vector2i(1,1),Vector2i(2,1),Vector2i(3,2),"wait",Vector2i(5,2),Vector2i(6,1),Vector2i(8,1)],
	[Vector2i(1,1),Vector2i(2,2),Vector2i(3,1),Vector2i(4,2),Vector2i(6,2),Vector2i(6,1),Vector2i(8,1),"wait"],
]
var game
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func expect(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	game._unhandled_input(event)

func settle(label: String) -> bool:
	# Follow the actual animation duration, including the planned 0.85 s timing.
	# Do not force anim=0 or manually call _process to skip the real transition.
	var deadline := Time.get_ticks_msec() + 5000
	while game.anim > 0.0 and Time.get_ticks_msec() < deadline:
		await create_timer(0.03).timeout
	expect(game.anim == 0.0, label + ": animation must settle within five seconds")
	return game.anim == 0.0

func run() -> void:
	game = MainScene.instantiate()
	root.add_child(game)
	await process_frame
	expect(game.mode == "title" and game.next_button.visible, "Scene opens at its playable title menu")
	game.next_button.pressed.emit()
	expect(game.mode == "intro" and game.chapter == 0, "Start button opens the first introduction")
	game.next_button.pressed.emit()
	expect(game.mode == "play" and game.wait_button.visible, "Introduction button enters play")
	await test_controls()
	if not failures.is_empty():
		await finish()
		return
	var expected_scores: Array = []
	for chapter in range(ROUTES.size()):
		expect(game.chapter == chapter and game.mode == "play", "Chapter %d is actually playable" % (chapter+1))
		if chapter == 1:
			await test_loss_recovery()
			if not failures.is_empty():
				await finish()
				return
		for step in ROUTES[chapter]:
			var action: Dictionary = {"kind":"fly","to":step} if step is Vector2i else {"kind":step}
			var old_turn: int = game.state.turn
			game.act(action)
			expect(game.state.turn == old_turn + 1, "Chapter route action is accepted once")
			if not await settle("Chapter %d turn %d" % [chapter+1,old_turn+1]):
				await finish()
				return
		expect(game.mode == "result" and game.state.won and not game.state.lost, "Chapter %d reaches its result overlay" % (chapter+1))
		expect(game.next_button.visible and not game.wait_button.visible, "Result exposes continuation rather than play controls")
		expect(game.state.turn == ROUTES[chapter].size(), "Scene replay retains exactly the verified route's turns")
		expected_scores.append({"turns":game.state.turn,"broken":game.state.broken,"hp":game.state.hp})
		print("UI CHAPTER COMPLETE: %d, turns=%d, hp=%d" % [chapter+1,game.state.turn,game.state.hp])
		game.next_button.pressed.emit()
		expect(game.scores == expected_scores, "Continuation records one accurate score per completed chapter")
		if chapter < ROUTES.size()-1:
			expect(game.mode == "intro" and game.history.is_empty() and game.state.turn == 0, "Next chapter starts with clean history and a fresh encounter")
			key(KEY_ENTER)
			expect(game.mode == "play", "Enter starts the next introduction")
	expect(game.mode == "ending" and game.scores.size() == 4, "All four results lead to the chapter ending")
	expect(game.next_button.visible and game.home_button.visible, "Ending offers replay and return to title")
	game.next_button.pressed.emit()
	expect(game.mode == "intro" and game.chapter == 0 and game.scores.is_empty(), "Replay starts a fresh short chapter without duplicate scores")
	key(KEY_ENTER)
	key(KEY_ESCAPE)
	game.home_button.pressed.emit()
	expect(game.mode == "title", "Pause menu can return to the title after replay")
	await finish()

func test_controls() -> void:
	var initial: Dictionary = game.state.duplicate(true)
	game.act({"kind":"fly","to":Vector2i(-1,3)})
	expect(game.state == initial and game.anim == 0.0 and game.history.is_empty(), "Invalid input neither spends a turn nor starts an animation/history entry")
	key(KEY_ESCAPE)
	expect(game.mode == "paused" and game.next_button.visible and not game.wait_button.visible, "Escape pauses and exposes resume")
	game.act({"kind":"wait"})
	expect(game.state == initial, "Paused scene rejects game actions")
	game.next_button.pressed.emit()
	expect(game.mode == "play" and game.state == initial, "Resume button restores the same decision")
	key(KEY_ESCAPE)
	key(KEY_ESCAPE)
	expect(game.mode == "play" and game.state == initial, "Escape can also resume without spending a turn")
	key(KEY_SPACE)
	expect(game.state.turn == 1 and game.state.landed and game.anim > 0.0, "Space invokes perch and begins its animation")
	var during_animation: Dictionary = game.state.duplicate(true)
	key(KEY_W)
	key(KEY_Z)
	key(KEY_R)
	expect(game.state == during_animation and game.history.size() == 1, "Input during an animation cannot queue extra turns, undo or restart")
	if not await settle("Perch keyboard action"):
		return
	key(KEY_Z)
	expect(game.mode == "play" and game.state == initial and game.history.is_empty(), "Keyboard undo restores complete state and unlocks play")
	key(KEY_W)
	if not await settle("Wait keyboard action"):
		return
	expect(game.state.turn == 1 and not game.restart_button.disabled, "Wait settles with restart available")
	game.restart_button.pressed.emit()
	expect(game.mode == "play" and game.state == initial and game.history.is_empty(), "Restart button resets encounter and history")
	game.act({"kind":"fly","to":Vector2i(1,1)})
	if not await settle("Fly before button undo"):
		return
	game.undo_button.pressed.emit()
	expect(game.state == initial and game.mode == "play", "Undo button restores a completed flight")

func test_loss_recovery() -> void:
	# Real chapter-two play: attract the cricket, then deliberately remain in
	# successive locked attacks. No HP, enemy or scene state is injected.
	game.act({"kind":"fly","to":Vector2i(1,2)})
	if not await settle("Attract cricket"):
		return
	for i in range(3):
		game.wait_button.pressed.emit()
		if not await settle("Cricket hit %d" % (i+1)):
			return
	expect(game.mode == "lost" and game.state.lost and game.next_button.visible, "Lethal real play opens the recovery overlay")
	game.next_button.pressed.emit()
	expect(game.mode == "play" and not game.state.lost and game.state.hp > 0, "Loss recovery button undoes the lethal turn")
	key(KEY_R)
	expect(game.mode == "play" and game.state == Model.start(1) and game.history.is_empty(), "Keyboard restart after loss recovery permits a fresh full solution")

func finish() -> void:
	game.queue_free()
	await process_frame
	game = null
	if failures.is_empty():
		print("FLOWER STEP UI VERIFIED: %d assertions; title, controls, loss recovery, four results and ending." % checks)
		quit(0)
	else:
		for failure in failures:
			printerr("FAIL: " + failure)
		quit(1)
