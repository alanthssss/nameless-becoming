extends SceneTree
const Scene = preload("res://main.tscn")
const Driver = preload("res://route_driver.gd")
const Save = preload("res://save_data.gd")
var game
var checks := 0
var failures: Array[String] = []
var pressed: Dictionary = {}
var capture_dir := OS.get_environment("SWARM_FLOW_CAPTURE_DIR")

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
	root.push_input(event)
	if down: pressed[code] = true
	else: pressed.erase(code)

func tap(code: Key) -> void:
	key(code,true)
	key(code,false)

func release_all() -> void:
	for code in pressed.keys(): key(code,false)

func apply_action(action: Dictionary) -> void:
	var direction: Vector2 = action.get("direction",Vector2.ZERO)
	var codes := [KEY_LEFT,KEY_RIGHT,KEY_UP,KEY_DOWN,KEY_SPACE]
	var values := [direction.x < -0.1,direction.x > 0.1,direction.y < -0.1,direction.y > 0.1,bool(action.get("held",false))]
	for i in codes.size():
		if values[i] != pressed.has(codes[i]): key(codes[i],values[i])

func ticks(count: int) -> void:
	for i in count:
		game.tick(1.0/60.0)
		game.world._process(1.0/60.0)

func shot(name: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless": return
	# Explicit scene fixtures can change stage without advancing a gameplay frame.
	game.queue_redraw()
	game.world._process(0.0)
	await RenderingServer.frame_post_draw
	var ok := get_root().get_texture().get_image().save_png(capture_dir.path_join(name+".png"))
	expect(ok == OK,"native capture "+name)

func run_complete_route(collect: bool) -> void:
	var driver = Driver.new(game.model,collect)
	var visited := {}
	var old_stage := -1
	var old_section := -1
	var handoffs := {}
	var active_captures := {}
	var relay_captured := false
	var shelter_captured := false
	var poses := {}
	for frame in 180000:
		if game.mode == "ending": break
		# Native capture may yield focus to another running app; use the real
		# resume key, keeping production focus-loss behavior intact.
		if game.mode == "pause":
			release_all()
			tap(KEY_ESCAPE)
			continue
		if game.mode == "transition":
			release_all()
			if not handoffs.has(game.model.stage):
				handoffs[game.model.stage] = true
				expect(game.handoff_panel.visible and not game.panel.visible,"short chapter handoff")
				print("CHAPTER_UI_STAGE: "+JSON.stringify({"stage":game.model.stage,"seconds":game.model.time,"recoveries":game.model.recoveries,"optional":collect}))
				if not collect: await shot("handoff-%d" % game.model.stage)
			if collect: tap(KEY_ENTER)
			ticks(1)
			continue
		if old_stage != game.model.stage:
			old_stage = game.model.stage
			old_section = -1
			expect(not game.model.started,"new level waits for fresh input")
		if old_section != game.model.section_index():
			old_section = game.model.section_index()
			visited["%d:%d" % [old_stage,old_section]] = true
			expect(not game.hud_objective.text.is_empty(),"every section has a visible objective")
			if not collect and old_section == 3: await shot("level-%d-middle" % old_stage)
		if not collect and not relay_captured and game.model.stage == 1 and game.model.wind_chain >= 2:
			relay_captured = true
			expect(game.toast.text.contains("连续借风"),"uninterrupted relay has visible feedback")
			await shot("continuous-wind")
		if not collect and not shelter_captured and game.model.stage == 2 and game.model.checkpoint_index >= 0 and game.model.shelter_index_at(game.model.p) >= 0:
			shelter_captured = true
			expect(game.hud_weather.text.contains("叶下安全"),"earned rain shelter confirms safety")
			await shot("rain-shelter")
		if not collect and old_section == 3 and not active_captures.has(old_stage) and game.model.p.x > game.model.sections[old_section].start_x+1100:
			active_captures[old_stage] = true
			await shot("level-%d-active" % old_stage)
		if not collect:
			var pose := ""
			if game.model.charging and game.model.charge >= game.model.CHARGE_READY: pose = "charge"
			elif game.model.burst_left > 0.25: pose = "dash"
			elif game.model.bees > 1 and not poses.has("rescue"): pose = "rescue"
			if not pose.is_empty() and not poses.has(pose):
				poses[pose] = true
				await shot("motion-"+pose)
		var action: Dictionary = driver.next_input()
		if not str(action.get("error","")).is_empty():
			failures.append("UI route: "+str(action.error))
			break
		apply_action(action)
		ticks(1)
	release_all()
	expect(game.mode == "ending","complete four-level route reaches ending")
	expect(handoffs.size() == 3,"all three level handoffs")
	expect(visited.size() >= 28,"all twenty-eight authored sections visited")
	expect(game.description.text.contains("第一章"),"ending identifies complete chapter")
	expect(not game.hud_weather.visible,"ending clears the chase indicator")
	print("CHAPTER_UI_END: "+JSON.stringify({"seconds":game.played_seconds,"recoveries":game.model.recoveries,"dew":game.model.garden_total(),"optional":collect}))
	if collect: expect(game.model.garden_total() == game.model.journey_dew_total(),"optional route collects the chapter's authored dew")
	if not collect:
		expect(relay_captured and shelter_captured,"complete route exercises relay and safe-leaf feedback")
		ticks(180)
		await shot("chapter-ending")

func weather_contract() -> void:
	# UI state fixtures only; complete input routes above earn all their own progress.
	game.begin_stage(2)
	game.model.p = Vector2(520,420)
	game.model.storm_x = game.model.p.x-200
	game.refresh_hud()
	expect(game.hud_weather.visible and game.hud_weather.text.contains("逼近"),"nearby rain names the threat and response")
	expect(game.hud_clock.text.begins_with("露天"),"exposure clock is distinct from the chasing rain front")
	await shot("rain-near-fixture")
	game.model.storm_x = game.model.p.x-900
	game.refresh_hud()
	expect(game.hud_weather.text.contains("甩开"),"gaining distance visibly releases pressure")
	tap(KEY_ESCAPE)
	expect(not game.hud_weather.visible,"pause clears chase UI")
	tap(KEY_ESCAPE)
	game.begin_stage(0)
	expect(not game.hud_weather.visible,"sunny stages have no false chase warning")

func boundaries() -> void:
	tap(KEY_ENTER)
	expect(game.mode == "play" and game.model.stage == 0,"ending Enter restarts whole chapter")
	key(KEY_RIGHT,true)
	ticks(25)
	key(KEY_SPACE,true)
	ticks(25)
	key(KEY_RIGHT,false)
	key(KEY_DOWN,true)
	ticks(1)
	expect(game.model.face.y > 0.9 and game.model.charge >= game.model.CHARGE_READY,"charged direction can change")
	release_all()
	ticks(1)
	expect(game.model.burst_left > 0,"release launches charged dash")
	tap(KEY_ESCAPE)
	var p: Vector2 = game.model.p
	var t: float = game.played_seconds
	ticks(120)
	expect(game.mode == "pause" and game.model.p == p and game.played_seconds == t,"pause freezes world and journey clock")
	tap(KEY_ENTER)
	expect(game.mode == "play" and game.held.is_empty(),"resume starts with clear input")
	tap(KEY_R)
	expect(not game.model.started and game.held.is_empty(),"manual recovery waits for new input")
	var before_wasd: float = game.model.p.x
	key(KEY_D,true)
	ticks(20)
	expect(game.model.p.x > before_wasd+20,"WASD enters flight path")
	release_all()
	game._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	expect(game.mode == "pause","focus loss pauses play")
	tap(KEY_ESCAPE)
	game.event_message("recover_timeout","重要恢复",3.0)
	game.event_message("dew","普通晨露",2.0)
	expect(game.toast.text == "重要恢复","recovery feedback cannot be overwritten by routine reward")
	tap(KEY_M)
	expect(game.muted,"mute key toggles")
	tap(KEY_M)
	# Explicit boundary fixture: separate from the untouched complete input routes above.
	game.model.phase = "transition"
	game.show_transition()
	game._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	var left: float = game.transition_left
	ticks(180)
	expect(game.mode == "pause" and game.transition_left == left,"focus loss freezes handoff")
	tap(KEY_ENTER)
	ticks(100)
	expect(game.model.stage == 1 and not game.model.started,"handoff resumes and next level waits")

func saved_menu_contract() -> void:
	# Completed and in-progress snapshots were earned by the complete input routes.
	# Only the save path is a fixture; real user progress remains untouched.
	var path := OS.get_cache_dir().path_join("before-rain-ui-chapter-save.json")
	game.progress_file = path
	game.test_mode = false
	game.persist_progress()
	var completed := Save.read_payload(path)
	expect(completed.get("completed",false),"actual ending persists as completed")
	game.saved_payload = completed
	game.saved_stage = int(completed.get("stage",-1))
	game.show_title()
	expect(game.secondary_button.visible and game.secondary_button.text.contains("结尾"),"completed save offers ending from title")
	tap(KEY_DOWN)
	tap(KEY_ENTER)
	expect(game.mode == "ending" and game.model.stage == 3,"title continue opens saved ending")
	game.model.reset_journey()
	game.begin_stage(0)
	var driver = Driver.new(game.model)
	for frame in 7200:
		if game.model.checkpoint_index >= 0: break
		var action: Dictionary = driver.next_input()
		if not action.error.is_empty(): failures.append("Save route: "+action.error); break
		apply_action(action)
		ticks(1)
	release_all()
	expect(game.model.checkpoint_index == 0,"save test earns its first leaf through ordinary inputs")
	var safe: Vector2 = game.model.checkpoint.p
	var companions: int = game.model.bees
	tap(KEY_ESCAPE)
	tap(KEY_DOWN)
	tap(KEY_DOWN)
	tap(KEY_ENTER)
	expect(game.mode == "title","pause menu returns to title with saved progress")
	game.saved_payload = Save.read_payload(path)
	game.saved_stage = int(game.saved_payload.get("stage",-1))
	tap(KEY_DOWN)
	tap(KEY_ENTER)
	expect(game.mode == "play" and game.model.p == safe and game.model.bees == companions,"title continue restores earned safe leaf and rescued companions")
	expect(not game.model.started and game.held.is_empty() and game.model.stamina == 100,"continue is stationary, refilled and requires fresh input")
	ticks(45)
	await shot("saved-leaf-continued")
	# Rendering/animation may advance while gameplay is paused; it cannot spend,
	# move, rescue, or otherwise alter simulation or persisted progress.
	var model_before := JSON.stringify(game.model.save_payload())
	var p_before: Vector2 = game.model.p
	var velocity_before: Vector2 = game.model.velocity
	var time_before: float = game.model.time
	for i in 90: game.world._process(1.0/60.0)
	await shot("motion-leaf-rest")
	expect(JSON.stringify(game.model.save_payload()) == model_before and game.model.p == p_before and game.model.velocity == velocity_before and game.model.time == time_before,"presentation animation cannot mutate gameplay or saved progress")
	game.test_mode = true
	game.progress_file = ""
	DirAccess.remove_absolute(path)

func run() -> void:
	game = Scene.instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.world.set_process(false)
	game.sound.set_muted(true)
	expect(game.test_mode,"QA never reads or writes user progress")
	expect(game.mode == "title","normal launch starts at title")
	await shot("chapter-title")
	tap(KEY_ENTER)
	await run_complete_route(false)
	boundaries()
	release_all()
	game.model.reset_journey()
	game.begin_stage(0)
	game.sound.set_muted(true)
	await run_complete_route(true)
	await saved_menu_contract()
	await weather_contract()
	if failures.is_empty(): print("SWARM FLIGHT UI VERIFIED: %d checks, complete four-level input routes" % checks)
	else:
		for failure in failures: push_error(failure)
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
