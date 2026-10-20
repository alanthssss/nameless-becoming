extends SceneTree
const Scene = preload("res://main.tscn")
var game
var checks := 0
var failures: Array[String] = []
var pressed: Dictionary = {}
var use_wasd := false

func _initialize() -> void:
	call_deferred("run")

func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func key(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = down
	game._unhandled_input(event)
	if down: pressed[code] = true
	else: pressed.erase(code)

func release_all() -> void:
	for code in pressed.keys(): key(code,false)

func point(direction: Vector2) -> void:
	var codes := [KEY_A,KEY_D,KEY_W,KEY_S] if use_wasd else [KEY_LEFT,KEY_RIGHT,KEY_UP,KEY_DOWN]
	var values := [direction.x < -0.1,direction.x > 0.1,direction.y < -0.1,direction.y > 0.1]
	for i in range(4):
		if values[i] != pressed.has(codes[i]): key(codes[i],values[i])

func ticks(count: int) -> void:
	for i in range(count): game.tick(1.0/60.0)

func fly(target: Vector2, label: String) -> bool:
	for i in range(1500):
		if game.model.p.distance_to(target) < 18 or game.mode != "play":
			point(Vector2.ZERO)
			return true
		var delta: Vector2 = target-game.model.p
		point(Vector2(signf(delta.x) if absf(delta.x)>10 else 0,signf(delta.y) if absf(delta.y)>10 else 0))
		ticks(1)
	failures.append("Keyboard route stuck: " + label + " at " + str(game.model.p))
	release_all()
	return false

func launch(direction: Vector2, settle := 0.63) -> void:
	point(direction)
	ticks(1)
	point(Vector2.ZERO)
	key(KEY_SPACE,true)
	ticks(43)
	key(KEY_SPACE,false)
	ticks(int(settle*60))

func chapter_zero() -> void:
	if not fly(Vector2(590,400),"first pod"): return
	launch(Vector2.RIGHT)
	expect(game.model.bees == 3,"Arrows + Space release rescue first pair")
	if not fly(Vector2(1040,380),"first gap approach"): return
	if not fly(Vector2(1240,380),"first gap"): return
	if not fly(Vector2(1330,235),"second pod"): return
	launch(Vector2.RIGHT)
	expect(game.model.bees == 5,"Keyboard second rescue")
	if not fly(Vector2(1770,520),"lower gap approach"): return
	if not fly(Vector2(1990,520),"lower gap"): return
	if not fly(Vector2(2180,525),"third pod"): return
	launch(Vector2.RIGHT)
	if not fly(Vector2(2560,420),"leaf curtain"): return
	launch(Vector2.RIGHT)
	fly(game.model.exit_pos,"first exit")
	expect(game.mode == "transition" and game.panel.visible,"Chapter exit opens actual continuation panel")

func chapter_one() -> void:
	# Test a forgiving keyboard route that does not require perfect diagonal aiming.
	if not fly(Vector2(590,460),"first wind flower"): return
	launch(Vector2.RIGHT,0.8)
	for i in range(1,4):
		var target: Vector2 = game.model.rings[i].pos
		# Approach on the same horizontal line and launch with a single arrow.
		if not fly(target-Vector2(170,0),"flower %d" % i): return
		launch(Vector2.RIGHT,0.8)
	# Rescue targets are visible and can be opened independently of wind flowers.
	if not game.model.pods[0].open:
		failures.append("Expected wind arc to catch the first companion without backtracking")
	if not game.model.pods[1].open:
		fly(Vector2(3130,380),"last companion")
		launch(Vector2.RIGHT)
	if not fly(Vector2(3470,405),"last bridge curtain"): return
	launch(Vector2.RIGHT)
	fly(game.model.exit_pos,"bridge exit")
	expect(game.mode == "transition" and game.model.bees == 9,"All nine bees finish the real keyboard bridge route")

func chapter_two() -> void:
	for item in [Vector2(670,390),Vector2(940,390),Vector2(1050,400)]:
		if not fly(item,"first rain gap"): return
	launch(Vector2.RIGHT)
	if not fly(Vector2(1640,400),"shelter one"): return
	expect(game.model.shelters[0].reached,"Actual movement reaches shelter one")
	for item in [Vector2(2000,440),Vector2(2270,440),Vector2(2380,430)]:
		if not fly(item,"middle rain gap"): return
	launch(Vector2.RIGHT)
	if not fly(Vector2(2970,430),"shelter two"): return
	expect(game.model.shelters[1].reached,"Actual movement reaches shelter two")
	for item in [Vector2(3210,480),Vector2(3410,480),Vector2(3810,430)]:
		if not fly(item,"last rain gap"): return
	launch(Vector2.RIGHT)
	fly(game.model.exit_pos,"tree hollow")
	expect(game.mode == "ending" and game.heading.text == "九只，都到家了。","Keyboard route reaches the visible ending")

func controls() -> void:
	var start: Vector2 = game.model.p
	key(KEY_RIGHT,true)
	ticks(10)
	key(KEY_RIGHT,false)
	expect(game.model.p.x > start.x+10,"Arrow key moves continuously")
	key(KEY_SPACE,true)
	ticks(40)
	var bursts: int = game.model.bursts
	key(KEY_ESCAPE,true)
	key(KEY_ESCAPE,false)
	var paused_pos: Vector2 = game.model.p
	var paused_stamina: float = game.model.stamina
	var paused_clock: float = game.model.rain_remaining
	var paused_trip: float = game.played_seconds
	ticks(120)
	expect(game.mode == "pause" and game.model.p == paused_pos,"Pause freezes physical progress")
	expect(game.model.stamina == paused_stamina and game.model.rain_remaining == paused_clock and game.played_seconds == paused_trip,"Pause freezes stamina, countdown and journey timer together")
	expect(game.description.position.y+game.description.get_minimum_size().y < game.main_button.position.y-8,"Pause instructions fit above the first menu button")
	key(KEY_SPACE,false)
	key(KEY_ENTER,true)
	key(KEY_ENTER,false)
	ticks(1)
	expect(game.mode == "play" and game.model.bursts == bursts and not game.model.charging,"Resuming a held charge never causes an accidental burst")
	key(KEY_RIGHT,true)
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	expect(game.mode == "pause" and game.held.is_empty(),"Losing application focus pauses and clears held movement")
	release_all()
	game.main_button.pressed.emit()
	key(KEY_R,true)
	key(KEY_R,false)
	expect(game.model.p.distance_to(start)<1,"R returns to the chapter's current checkpoint")
	key(KEY_M,true)
	key(KEY_M,false)
	expect(game.muted and AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")),"Mute applies to sound buses")
	key(KEY_M,true)
	key(KEY_M,false)
	expect(not game.muted,"Mute toggles back")
	use_wasd = true
	point(Vector2.UP)
	ticks(12)
	point(Vector2.ZERO)
	expect(game.model.p.y < start.y-15,"WASD uses the same continuous flight")
	use_wasd = false
	key(KEY_R,true)
	key(KEY_R,false)

func interface_feedback() -> void:
	game.saved_stage = 1
	game.show_title()
	key(KEY_DOWN,true)
	key(KEY_DOWN,false)
	key(KEY_ENTER,true)
	key(KEY_ENTER,false)
	expect(game.mode == "play" and game.model.stage == 1,"Keyboard menu navigation selects the visible continue action")
	game.show_title()
	game.main_button.pressed.emit()
	key(KEY_SPACE,true)
	ticks(5)
	key(KEY_SPACE,false)
	ticks(1)
	expect(game.toast.visible and game.toast.text.contains("还没蓄好力"),"An early Space release visibly explains why no burst occurred")
	key(KEY_SPACE,true)
	ticks(40)
	expect(game.cue_panel.visible and game.cue_label.text.contains("松开空格"),"Ready-to-release feedback appears beside the bee")
	expect(game.hud_energy.text.contains("体力") and game.hud_clock.text.begins_with("旅程"),"Stamina value and journey timer are visible in the HUD")
	key(KEY_ESCAPE,true)
	key(KEY_ESCAPE,false)
	key(KEY_SPACE,false)
	expect(not game.cue_panel.visible and not game.toast.visible,"Pause hides stale gameplay feedback")
	game.main_button.pressed.emit()
	key(KEY_R,true)
	key(KEY_R,false)
	ticks(1)
	expect(game.toast.text.contains("已回到") and game.toast.text.contains("伙伴都在"),"Manual recovery has an explicit visible cause and preserved-progress message")
	game.begin_stage(2)
	game.model.p = Vector2(1640,400)
	game.model.started = true
	game.model.spend_energy(60)
	ticks(60)
	expect(game.hud_clock.text.contains("停") and game.cue_label.text.contains("恢复"),"Shelter HUD explains paused countdown and actual stamina recovery")
	game.model.p += Vector2(250,0)
	game.model.rain_remaining = 0.01
	ticks(1)
	expect(game.toast.text.contains("暴雨抵达") and game.toast.text.contains("重置"),"Timeout recovery explains why and what reset")
	game.begin_stage(0)
	release_all()

func run() -> void:
	game = Scene.instantiate()
	game.test_mode = true
	root.add_child(game)
	game.set_process(false)
	await process_frame
	expect(game.mode == "title" and game.main_button.visible,"Native scene starts at the title")
	expect(game.description.position.y+game.description.get_minimum_size().y < game.main_button.position.y-8,"Title instructions fit above the first menu button")
	expect(game.world.show_behind_parent,"World does not cover HUD contrast bands or target marker")
	interface_feedback()
	controls()
	chapter_zero()
	if game.mode == "transition":
		key(KEY_ENTER,true)
		key(KEY_ENTER,false)
		chapter_one()
	if game.mode == "transition":
		game.main_button.pressed.emit()
		chapter_two()
	expect(game.mode == "ending","Whole scene flow completed without debug teleport or stage skip")
	if game.mode == "ending":
		expect(game.description.position.y+game.description.get_minimum_size().y < game.main_button.position.y-8,"Ending copy fits above the replay button")
		expect(game.description.text.contains("旅程") and game.description.text.contains("恢复点"),"Whole-chapter ending reports total time and retries")
		game.main_button.pressed.emit()
		expect(game.mode == "title","Ending offers a working replay")
		game.main_button.pressed.emit()
		expect(game.model.stage == 0 and game.model.bees == 1 and game.mode == "play","Replay starts a fresh whole experience")
	game.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("SWARM FLIGHT UI VERIFIED: %d checks, complete arrow-key route" % checks)
	quit(0 if failures.is_empty() else 1)
