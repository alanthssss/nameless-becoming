extends SceneTree
const Scene = preload("res://main.tscn")
const Driver = preload("res://route_driver.gd")
const Save = preload("res://save_data.gd")
var game
var checks := 0
var failures: Array[String] = []
var pressed: Dictionary = {}
var regional_saves: Array[Dictionary] = []
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
	var home_arrival := false
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
				if collect and game.model.stage in [3,7,11]:
					var earned: Dictionary = game.model.save_payload()
					earned["played_seconds"] = game.played_seconds
					regional_saves.append(earned)
				expect(game.handoff_panel.visible and not game.panel.visible,"short chapter handoff")
				print("CHAPTER_UI_STAGE: "+JSON.stringify({"stage":game.model.stage,"seconds":game.model.time,"recoveries":game.model.recoveries,"optional":collect}))
				expect(game.model.save_payload().arrived,"goal progress is saved before the handoff finishes")
				if not collect:
					await shot("handoff-%d" % game.model.stage)
					var finish_clock: float = game.played_seconds
					var finish_energy: float = game.model.stamina
					ticks(78)
					expect(game.played_seconds == finish_clock and game.model.stamina == finish_energy,"landing animation does not advance journey time or spend stamina")
					await shot("arrival-landed-%d" % game.model.stage)
			if collect: tap(KEY_ENTER)
			ticks(1)
			continue
		if game.mode == "arrival":
			release_all()
			if not home_arrival:
				home_arrival = true
				expect(not game.panel.visible and game.handoff_panel.visible,"final landing is visible before the ending card")
				var arrival_time: float = game.world._arrival_elapsed
				var countdown: float = game.transition_left
				tap(KEY_ESCAPE)
				ticks(60)
				expect(game.mode == "pause" and game.transition_left == countdown and game.world._arrival_elapsed == arrival_time,"pause freezes the final landing and its countdown")
				tap(KEY_ESCAPE)
				if not collect:
					ticks(78)
					await shot("home-arrival-before-card")
			if collect: tap(KEY_ENTER)
			ticks(1)
			continue
		if old_stage != game.model.stage:
			old_stage = game.model.stage
			old_section = -1
			expect(not game.model.started,"new level waits for fresh input")
		if old_section != game.model.encounter_index():
			old_section = game.model.encounter_index()
			visited["%d:%d" % [old_stage,old_section]] = true
			expect(not game.hud_objective.text.is_empty(),"every section has a visible objective")
			if not collect and old_section == (3 if old_stage < 4 else 1): await shot("level-%d-middle" % old_stage)
			if not collect and old_stage == 3 and old_section == 2: await shot("distant-home-arrival")
		if not collect and not relay_captured and game.model.stage == 1 and game.model.wind_chain >= 2:
			relay_captured = true
			expect(game.toast.text.contains("连续借风"),"uninterrupted relay has visible feedback")
			await shot("continuous-wind")
		if not collect and not shelter_captured and game.model.stage == 2 and game.model.checkpoint_index >= 0 and game.model.shelter_index_at(game.model.p) >= 0:
			shelter_captured = true
			expect(game.hud_weather.text.contains("叶下安全"),"earned rain shelter confirms safety")
			await shot("rain-shelter")
		if not collect and old_section == 3 and not active_captures.has(old_stage) and game.model.p.x > game.model.chapter.encounters[old_section].start_x+1100:
			active_captures[old_stage] = true
			await shot("level-%d-active" % old_stage)
		if collect and old_stage == 1 and old_section == 3 and game.model.p.x > 5890 and not poses.has("wind-entry-supply"):
			poses["wind-entry-supply"] = true
			await shot("wind-entry-supply")
		if not collect and old_stage == 2 and old_section == 3 and game.model.p.x > 5160 and not poses.has("rain-wind-supply"):
			poses["rain-wind-supply"] = true
			await shot("rain-wind-supply")
		if not collect:
			var shield_pose := "shield-route-%d" % old_stage
			if game.model.shield_left > 0 and game.model.shield_left < 3.5 and not poses.has(shield_pose):
				poses[shield_pose] = true
				await shot(shield_pose)
			var pose := ""
			if game.model.charging and game.model.charge >= game.model.CHARGE_READY: pose = "charge"
			elif game.model.burst_left > 0.25: pose = "dash"
			elif game.model.bees > 1 and not poses.has("rescue"): pose = "rescue"
			if not pose.is_empty() and not poses.has(pose):
				poses[pose] = true
				await shot("motion-"+pose)
		if not collect and old_stage >= 4 and game.model.shelter_index_at(game.model.p) == 0 and not poses.has("neighbor-%d" % old_stage):
			poses["neighbor-%d" % old_stage] = true
			expect(not game.world.neighbor_words().is_empty(),"new regions greet at the earned safe leaf")
			await shot("neighbor-%d" % old_stage)
		# These captures come from the continuous ordinary-input playthrough.
		for feature in ["summer-branch","autumn-crates","winter-flow"]:
			var stage_for_feature: int = {"summer-branch":4,"autumn-crates":9,"winter-flow":12}[feature]
			if old_stage == stage_for_feature and old_section == 0 and game.model.p.x > 650 and not poses.has(feature):
				poses[feature] = true
				await shot(feature+("-alternate" if collect else "-direct"))
		var action: Dictionary = driver.next_input()
		if not str(action.get("error","")).is_empty():
			failures.append("UI route: "+str(action.error))
			break
		apply_action(action)
		ticks(1)
	release_all()
	expect(game.mode == "ending","complete sixteen-level route reaches ending")
	expect(handoffs.size() == game.model.STAGE_COUNT-1,"all fifteen level handoffs")
	expect(home_arrival,"finale uses the same earned arrival before showing results")
	var expected_encounters := 0
	for definition in game.Data.definitions(): expected_encounters += definition.encounters.size()
	expect(visited.size() == expected_encounters,"every authored encounter is visited")
	expect(game.description.text.contains("全篇完") and game.description.text.contains("伙伴 8 只"),"ending counts rescued friends separately from player")
	expect(not game.hud_weather.visible,"ending clears the chase indicator")
	print("CHAPTER_UI_END: "+JSON.stringify({"seconds":game.played_seconds,"recoveries":game.model.recoveries,"dew":game.model.garden_total(),"optional":collect}))
	if collect: expect(game.model.garden_total() == game.model.journey_dew_total(),"optional route collects the chapter's authored dew")
	if not collect:
		expect(relay_captured and shelter_captured,"complete route exercises relay and safe-leaf feedback")
		ticks(180)
		await shot("chapter-ending")

func rescue_departure_contract() -> void:
	release_all()
	game.model.reset_journey()
	game.begin_stage(0)
	var driver = Driver.new(game.model)
	for frame in 2400:
		if game.model.bees > 1: break
		var action: Dictionary = driver.next_input()
		if not str(action.get("error","")).is_empty(): break
		apply_action(action)
		ticks(1)
	release_all()
	expect(game.model.bees == 3 and game.world.departures.size() == 2,"real rescue spawns exactly the freed companions as temporary departures")
	expect(game.hud_bees.text == "已救  2 / 8" and game.toast.text.contains("先回家"),"HUD excludes player and explains companions leave for home")
	await shot("rescue-departure-start")
	if game.mode == "pause": tap(KEY_ESCAPE)
	tap(KEY_ESCAPE)
	var frozen := JSON.stringify(game.world.departures)
	var paused_at: Vector2 = game.model.p
	ticks(180)
	expect(JSON.stringify(game.world.departures) == frozen and game.model.p == paused_at,"pause freezes departure and player together")
	tap(KEY_ESCAPE)
	key(KEY_RIGHT,true)
	ticks(24)
	key(KEY_RIGHT,false)
	expect(game.model.p.distance_to(paused_at) > 20,"rescue farewell never blocks player control")
	await shot("rescue-departure-arc")
	ticks(36)
	await shot("rescue-departure-flight")
	ticks(144)
	expect(game.world.departures.is_empty() and game.model.bees == 3,"departures finish while rescued progress remains")
	await shot("rescue-solo-after")
	tap(KEY_R)
	ticks(1)
	expect(game.world.departures.is_empty() and game.model.bees == 3,"recovery preserves rescued progress without respawning companions")
	# Explicit event fixtures isolate clearing on same-stage restart and title.
	game.world.emit_event("rescue",game.model.p,{"count":2})
	game.begin_stage(0)
	expect(game.world.departures.is_empty(),"same-stage restart clears active departure effects")
	game.world.emit_event("rescue",game.model.p,{"count":1})
	game.show_title()
	expect(game.world.departures.is_empty() and not game.world.presentation_active,"title clears old departures")
	game.model.reset_journey()
	game.played_seconds = 0
	game.begin_stage(0)

func shield_ui_contract() -> void:
	# Start-position fixture for the authored introduction; pickup and pause use
	# ordinary Viewport keys. Complete routes separately earn the whole chapter.
	release_all()
	game.begin_stage(2)
	game.model.p = game.model.shields[0].pos-Vector2(60,0)
	game.model.camera_x = game.model.p.x-480
	game.model.storm_x = game.model.p.x-800
	key(KEY_RIGHT,true)
	ticks(12)
	release_all()
	ticks(1)
	expect(game.model.shield_left > 4.8 and game.toast.text.contains("护雨"),"Contact pickup shows five-second weather protection")
	await shot("shield-turn-introduction")
	if game.mode == "pause": tap(KEY_ESCAPE)
	tap(KEY_ESCAPE)
	var frozen: float = game.model.shield_left
	ticks(120)
	expect(game.model.shield_left == frozen,"Pause freezes shield countdown")
	tap(KEY_ESCAPE)
	key(KEY_DOWN,true)
	ticks(12)
	release_all()
	expect(game.model.shield_left < frozen and game.model.burst_left == 0,"Protected bee can steer normally without dashing")
	game.model.shield_left = 0.7
	game.model.invulnerable = 0
	game.refresh_hud()
	await shot("shield-final-second-fixture")
	tap(KEY_R)
	ticks(1)
	expect(game.model.shield_left == 0,"Recovery clears shield HUD and presentation state")

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
	ticks(150)
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
	expect(game.mode == "ending" and game.model.stage == game.model.STAGE_COUNT-1,"title continue opens saved ending")
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
	expect(game.world.departures.is_empty(),"continuing earned progress never replays earlier departures")
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
	# Continue the earned run through the goal, then leave during its landing.
	# This covers the actual menu path, not just a model snapshot round-trip.
	if game.mode == "pause": tap(KEY_ESCAPE)
	driver = Driver.new(game.model)
	for frame in 7200:
		if game.mode == "transition": break
		var action: Dictionary = driver.next_input()
		if not action.error.is_empty(): failures.append("Arrival save route: "+action.error); break
		apply_action(action)
		ticks(1)
	release_all()
	var arrived_save := Save.read_payload(path)
	expect(game.mode == "transition" and arrived_save.get("arrived",false) and not arrived_save.get("completed",true),"crossing the first goal immediately writes its completion to disk")
	var arrived_seconds: float = game.played_seconds
	var arrived_dew: int = game.model.garden_total()
	# A file cannot contain a child file: isolate the write-failure path without
	# changing filesystem permissions or touching the player's save directory.
	game.progress_file = path.path_join("unwritable.json")
	tap(KEY_ESCAPE)
	expect(not game.has_saved and game.description.text.contains("保存失败") and not game.description.text.contains("进度已保存"),"failed arrival save stays visible in pause instead of claiming success")
	game.progress_file = path
	tap(KEY_ESCAPE)
	tap(KEY_ESCAPE)
	expect(game.has_saved and game.description.text.contains("进度已保存"),"successful arrival save retry reports its actual result")
	tap(KEY_DOWN)
	tap(KEY_ENTER)
	expect(game.mode == "title" and game.secondary_button.text.contains("继续第 2 关"),"leaving the landing offers the next level from title")
	game.saved_payload = Save.read_payload(path)
	tap(KEY_DOWN)
	tap(KEY_ENTER)
	expect(game.mode == "play" and game.model.stage == 1 and not game.model.started and game.held.is_empty(),"continue after arrival starts next level safely without replaying the tail")
	expect(is_equal_approx(game.played_seconds,arrived_seconds),"arrival continuation preserves journey time through JSON round-trip")
	expect(game.model.garden_total() == arrived_dew and game.model.bees == 5,"arrival continuation preserves collected dew and rescued friends")
	await shot("saved-arrival-continued")
	# These three snapshots come from the full input run, not fabricated flags.
	for payload in regional_saves:
		expect(Save.write_payload(payload,path),"earned regional snapshot writes successfully")
		game.saved_payload = Save.read_payload(path)
		game.saved_stage = int(payload.stage)
		game.show_title()
		tap(KEY_DOWN)
		tap(KEY_ENTER)
		expect(game.mode == "play" and game.model.stage == int(payload.stage)+1 and not game.model.started,"earned regional arrival continues at the next season")
		expect(is_equal_approx(game.played_seconds,float(payload.played_seconds)),"season continuation preserves earned journey time")
		expect(game.model.garden_total() == int(payload.garden_awards.reduce(func(a,b): return a+b,0)),"season continuation keeps collected dew")
	game.test_mode = true
	game.progress_file = ""
	DirAccess.remove_absolute(path)

func season_ui_contract() -> void:
	# Explicit UI state fixtures for warning readability and pause, separate from
	# the continuous input-route screenshots above.
	release_all()
	game.model.reset_journey()
	game.begin_stage(4)
	expect(not game.model.jets.is_empty(),"summer introduces a real fountain")
	if game.model.jets.is_empty(): return
	var area: Rect2 = game.model.jets[0].rect
	game.model.p = Vector2(area.position.x-100,area.get_center().y)
	game.model.camera_x = maxf(0,game.model.p.x-480)
	game.model.started = true
	for state in ["quiet","warning","spray"]:
		game.model.hazard_clock = {"quiet":0.1,"warning":3.1,"spray":4.1}[state]
		ticks(1)
		expect(game.model.context_cue().get("kind","") == "jet","fountain has a nearby actionable cue in "+state)
		await shot("fountain-"+state+"-fixture")
	var phase_time: float = game.model.hazard_clock
	tap(KEY_ESCAPE)
	ticks(60)
	expect(game.mode == "pause" and game.model.hazard_clock == phase_time,"real Escape pauses fountain timing")
	tap(KEY_ESCAPE)
	ticks(1)
	expect(game.mode == "play" and game.model.hazard_clock > phase_time,"real resume continues the same fountain cycle")
	game.model.reset_journey()
	game.begin_stage(12)
	expect(not game.model.airflows.is_empty(),"winter introduces a real wind field")
	if not game.model.airflows.is_empty():
		game.model.p = game.model.airflows[0].rect.get_center()
		game.model.camera_x = maxf(0,game.model.p.x-480)
		ticks(1)
		expect(game.model.context_cue().get("kind","") == "airflow","wind field explains its actual effect")
		await shot("winter-flow-fixture")

func fly_without_burst(target: Vector2) -> bool:
	# Independent of the authored route driver: only ordinary Viewport keys.
	# This deliberately passes the wind flower without ever pressing Space.
	for frame in 1800:
		if game.mode == "pause":
			release_all()
			tap(KEY_ESCAPE)
		var offset: Vector2 = target-game.model.p
		if offset.length() < 16:
			release_all()
			return true
		apply_action({"direction":Vector2(signf(offset.x) if absf(offset.x)>8 else 0,signf(offset.y) if absf(offset.y)>8 else 0)})
		ticks(1)
	release_all()
	expect(false,"ordinary input reaches %s without teleporting; stopped at %s" % [str(target),str(game.model.p)])
	return false

func airflow_input_contract() -> void:
	# Reproduce the reported approach from the real chapter menu. No position,
	# velocity, checkpoint, wind or stamina fixture is used in this contract.
	release_all()
	game.show_title()
	for i in 3: tap(KEY_TAB)
	tap(KEY_ENTER)
	expect(game.mode == "play" and game.model.stage == 12 and not game.model.started,"real chapter selector starts the winter airflow reproduction")
	if game.model.stage != 12: return
	for point in [Vector2(400,560),Vector2(580,360),Vector2(1370,360),Vector2(1590,420),Vector2(2030,250)]:
		if not fly_without_burst(point): return
	expect(game.model.checkpoint_index == 0,"ordinary input earns the leaf before the reported counterwind")
	var field: Rect2 = game.model.airflows[1].rect
	if not fly_without_burst(Vector2(field.position.x-50,field.get_center().y)): return
	ticks(1)
	expect(game.model.airflow_at(game.model.p).is_zero_approx(),"approach sample is physically outside the wind field")
	expect(game.model.context_cue().get("kind","") == "airflow_approach" and game.cue_panel.visible and not game.cue_label.text.contains("推动中"),"actual HUD distinguishes approaching wind from being pushed")
	await shot("airflow-ordinary-approach")
	var sample := Vector2(field.position.x+field.size.x*0.72,field.get_center().y)
	if not fly_without_burst(sample): return
	ticks(15)
	expect(field.has_point(game.model.p) and game.model.airflow_at(game.model.p).x < -100,"ordinary keys enter the real counterwind without triggering the wind flower")
	expect(game.model.context_cue().get("kind","") == "airflow" and game.cue_panel.visible and game.cue_label.text.contains("推动中"),"actual HUD reports pushing inside the wind field")
	await shot("airflow-ordinary-entered")
	if game.mode == "pause": tap(KEY_ESCAPE)
	var idle_start: Vector2 = game.model.p
	ticks(60)
	var idle_delta: Vector2 = game.model.p-idle_start
	expect(idle_delta.x < -100 and field.has_point(game.model.p),"releasing ordinary flight drifts left visibly for one second inside counterwind")
	expect(game.cue_panel.visible and game.cue_label.text.contains("推动中"),"idle drift keeps the actual wind-state HUD visible")
	await shot("airflow-ordinary-release-one-second")
	if not fly_without_burst(sample): return
	ticks(15)
	key(KEY_SPACE,true)
	var charge_start: Vector2 = game.model.p
	ticks(30)
	var charge_delta: Vector2 = game.model.p-charge_start
	expect(charge_delta.x < -35 and field.has_point(game.model.p) and game.model.charging,"holding charge also drifts left visibly for half a second")
	expect(game.model.context_cue().get("kind","") == "airflow" and game.cue_panel.visible and game.cue_label.text.contains("蓄力"),"actual HUD explains airflow during charging rather than hiding it with a generic charge prompt")
	expect(game.model.bursts == 0 and game.model.rings_hit == 0 and game.model.recoveries == 0,"ordinary airflow reproduction never dashes, borrows a flower or recovers")
	await shot("airflow-ordinary-charge-half-second")
	print("AIRFLOW_UI_INPUT: "+JSON.stringify({"stage":game.model.stage,"idle_one_second":str(idle_delta),"charge_half_second":str(charge_delta),"bursts":game.model.bursts,"recoveries":game.model.recoveries}))
	# Cancel charge through the real pause input before releasing Space, so the
	# test itself cannot silently finish by launching a dash.
	if game.mode != "pause": tap(KEY_ESCAPE)
	release_all()
	tap(KEY_ESCAPE)
	expect(game.model.bursts == 0 and not game.model.charging,"pause cancels the sampled charge without launching")
	if not fly_without_burst(Vector2(field.end.x+55,field.get_center().y)): return
	ticks(15)
	expect(game.model.airflow_at(game.model.p).is_zero_approx() and not game.cue_label.text.contains("推动中"),"leaving the real wind field removes the pushing HUD state")
	await shot("airflow-ordinary-exited")

func sample_visual_contract() -> void:
	for stage in [0,4]:
		for alternate in [false,true]:
			if stage == 0 and alternate: continue
			release_all()
			game.model.reset_journey()
			game.begin_stage(stage)
			var driver = Driver.new(game.model,alternate)
			var flight_shot := false
			var charge_shot := false
			var leaf_shot := false
			var exit_hint_seen := false
			var suffix := "%02d-%s" % [stage+1,"lower" if alternate else "upper"]
			for frame in 15000:
				if game.mode in ["transition","arrival"]: break
				if game.mode == "pause":
					release_all()
					tap(KEY_ESCAPE)
				var action: Dictionary = driver.next_input()
				if not str(action.get("error","")).is_empty():
					expect(false,"sample input route: "+str(action.error))
					break
				apply_action(action)
				ticks(1)
				if stage == 4 and not exit_hint_seen and game.model.exit_ready and game.model.shelter_index_at(game.model.p) >= 0:
					exit_hint_seen = true
					expect(game.hud_objective.text.contains("花铃叶拱"),"last summer leaf preserves the earned exit instruction")
					await shot("sample-"+suffix+"-last-leaf")
				if not charge_shot and game.model.charging and game.model.charge >= 0.3:
					charge_shot = true
					if stage == 4 and game.model.encounter_index() == 0:
						var landing: Vector2 = game.model.shelters[0].pos-Vector2(game.model.camera_x,0)
						expect(landing.x > 70 and landing.x < 1230,"shared landing is on screen before the first sample launch")
						var bee: Vector2 = game.model.p-Vector2(game.model.camera_x,0)
						expect(not Rect2(game.cue_panel.position,game.cue_panel.size).grow(12).has_point(bee),"high-flight charge prompt leaves the bee visible")
					await shot("sample-"+suffix+"-charge")
				if not flight_shot and game.model.p.x > 850:
					flight_shot = true
					await shot("sample-"+suffix+"-flight")
				if not leaf_shot and game.model.checkpoint_index == 0 and game.model.shelter_index_at(game.model.p) == 0:
					leaf_shot = true
					if stage == 4:
						var side := "bottom" if alternate else "top"
						expect(game.model.sample_approach == side,"real scene input takes "+side+" branch")
						expect(game.cue_label.text.contains("下面" if alternate else "上面"),"Xiaoman responds to actual "+side+" approach at first shared leaf")
					await shot("sample-"+suffix+"-shared-leaf")
					if stage == 4 and alternate and DisplayServer.get_name() != "headless":
						var old_size := root.size
						root.size = Vector2i(960,600)
						await process_frame
						await shot("sample-05-lower-small-window")
						root.size = old_size
						await process_frame
					if stage == 4:
						release_all()
						ticks(90)
						await shot("sample-"+suffix+"-rest")
			expect(flight_shot and leaf_shot and game.mode == "transition","sample level reaches its shared leaves and goal through ordinary input")
			if stage == 4: expect(exit_hint_seen,"summer route reaches its final leaf and exit instruction")
			await shot("sample-"+suffix+"-arrival")
	# UI text measured at the shipped logical resolution, including every cue.
	for definition in game.Data.definitions():
		for encounter in definition.encounters:
			expect(game.font.get_string_size(str(encounter.cue),HORIZONTAL_ALIGNMENT_LEFT,-1,20).x <= game.hud_objective.size.x,"objective fits: "+str(encounter.name))
	release_all()

func supply_input_contract() -> void:
	var contract = load("res://supply_contract.gd")
	for spec in contract.cases():
		for lower in [false,true]:
			release_all()
			game.model.reset_journey()
			game.begin_stage(spec.stage)
			var entrance = Driver.new(game.model)
			for frame in 6000:
				if game.mode == "pause": tap(KEY_ESCAPE)
				if game.model.checkpoint_index >= spec.checkpoint: break
				apply_action(entrance.next_input())
				ticks(1)
			release_all()
			expect(game.model.checkpoint_index == spec.checkpoint,"native supply route earns its preceding checkpoint")
			var driver = Driver.new(game.model)
			driver.stage = game.model.stage
			driver.commands = contract.commands(spec,lower)
			var before_shot := false
			var pickup_shot := false
			var action_shot := false
			var start_bursts: int = game.model.bursts
			var suffix := "%02d-%s" % [spec.stage+1,"lower" if lower else "upper"]
			for frame in 2400:
				if game.mode == "pause": tap(KEY_ESCAPE)
				if driver.cursor >= driver.commands.size(): break
				apply_action(driver.next_input())
				ticks(1)
				if not before_shot and game.model.p.x > spec.supply.x-170:
					before_shot = true
					await shot("supply-"+suffix+"-shared-exit")
				var picked: bool = game.model.dew.any(func(drop): return drop.encounter == spec.encounter and drop.collected)
				if picked and not pickup_shot:
					pickup_shot = true
					expect(driver.cursor == (spec.lower.size() if lower else spec.upper.size()),"native input collects shared exit supply before the next action")
					await shot("supply-"+suffix+"-collected")
				if not lower and not action_shot and game.model.p.x > spec.approach.x+600:
					action_shot = true
					await shot("supply-"+suffix+"-flight")
			release_all()
			expect(pickup_shot and driver.error.is_empty() and driver.cursor == driver.commands.size() and game.model.recoveries == 0,"native input preserves supply and chosen branch without recovery")
			print("SUPPLY_UI_INPUT: "+JSON.stringify({"level":spec.stage+1,"lower":lower,"collected_before_next_action":pickup_shot,"remaining":game.model.stamina,"recoveries":game.model.recoveries}))

func run() -> void:
	game = Scene.instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.world.set_process(false)
	game.sound.set_muted(true)
	if "--supply-only" in OS.get_cmdline_user_args():
		await supply_input_contract()
		for failure in failures: push_error(failure)
		print("SUPPLY UI CHECKS: %d, failures %d" % [checks,failures.size()])
		game.queue_free()
		await process_frame
		quit(0 if failures.is_empty() else 1)
		return
	if "--sample-visuals-only" in OS.get_cmdline_user_args():
		await sample_visual_contract()
		for failure in failures: push_error(failure)
		print("SAMPLE VISUAL CHECKS: %d, failures %d" % [checks,failures.size()])
		game.queue_free()
		await process_frame
		quit(0 if failures.is_empty() else 1)
		return
	if "--season-elements-only" in OS.get_cmdline_user_args():
		await season_ui_contract()
		await airflow_input_contract()
		for failure in failures: push_error(failure)
		print("SEASON UI CHECKS: %d, failures %d" % [checks,failures.size()])
		game.queue_free()
		await process_frame
		quit(0 if failures.is_empty() else 1)
		return
	expect(game.test_mode,"QA never reads or writes user progress")
	expect(game.mode == "title","normal launch starts at title")
	await shot("chapter-title")
	tap(KEY_DOWN)
	expect(game.menu_index > 0,"chapter selector is tested from another menu action")
	tap(KEY_TAB)
	expect(game.menu_index == 0,"selecting a region focuses its start button")
	tap(KEY_ENTER)
	expect(game.model.stage == 4 and game.mode == "play" and not game.model.started,"title chapter selector starts summer with fresh input")
	game.show_title()
	await rescue_departure_contract()
	# Contract returns a fresh active chapter.

	await run_complete_route(false)
	boundaries()
	release_all()
	game.model.reset_journey()
	game.begin_stage(0)
	game.sound.set_muted(true)
	await run_complete_route(true)
	await saved_menu_contract()
	await weather_contract()
	await shield_ui_contract()
	await season_ui_contract()
	await airflow_input_contract()
	await sample_visual_contract()
	await supply_input_contract()
	if failures.is_empty(): print("SWARM FLIGHT UI VERIFIED: %d checks, complete sixteen-level input routes" % checks)
	else:
		for failure in failures: push_error(failure)
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
