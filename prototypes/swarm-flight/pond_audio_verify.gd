extends SceneTree
## #219/#226: controlled production-state and audio-routing checks.
## Seeded positions/open gates isolate events. No fabricated emit(), native
## listening acceptance, or claim that these fixtures are player exploration.
const Scene = preload("res://spring_journey.tscn")
const Model = preload("res://spring_journey_model.gd")
const DT := 1.0 / 60.0
const POND_EVENTS := ["source_observed", "bird_greeting", "weather_warning", "dance_commit", "keeper_hang", "keeper_count", "keeper_lift", "keeper_place", "listener_depart"]
var game
var checks := 0
var failures := 0
var section := "setup"
var routed: Array = []
var results: Array = []
var pcm_metrics: Array = []
var folder := OS.get_environment("SWARM_POND_AUDIO_QA_DIR")

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	results.append({"section":section, "label":label, "passed":ok})
	if not ok:
		failures += 1
		print("FAIL: ", section, ": ", label)

func on_event(kind: String) -> void:
	var m = game.model
	var listener_positions: Array = []
	for bee in m.listeners: listener_positions.append([bee.pos.x, bee.pos.y])
	routed.append({"section":section, "kind":kind, "time":m.time,
		"mode":game.mode, "keeper_state":m.keeper.state,
		"keeper_pos":[m.keeper.pos.x,m.keeper.pos.y],
		"keeper_work":m.keeper.elapsed, "result_elapsed":m.result_elapsed,
		"share_state":m.share_state, "message_revision":m.message_revision,
		"listeners":listener_positions, "weather":m.weather_phase})

func count(kind: String, start := 0) -> int:
	var total := 0
	for i in range(start,routed.size()):
		if routed[i].kind == kind: total += 1
	return total

func tick(n := 1) -> void:
	for i in n:
		game.tick(DT)
		game.sound._process(DT)

func key(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = down
	root.push_input(event)

func tap(code: Key) -> void:
	key(code,true)
	key(code,false)

func seed_stage(index: int, point: Vector2) -> void:
	game.begin_stage(index)
	game.model.p = point
	game.model.velocity = Vector2.ZERO
	game.model.clear_input()
	game.model.started = true
	game.model.invulnerable = 0.0
	game.held.clear()
	game.model.events.clear()

func open_gate_fixture() -> void:
	# Earned gates are fixture setup, never counted as observed gate events.
	var m = game.model
	m.front_open = true
	m.passage_open = true
	m.wall_at(2350).broken = true
	m.wall_at(Model.BACK_WALL_X).broken = true
	m.keeper = Model.actor(Model.RESULT_HOME)
	m.keeper.state = "settled"
	m.keeper.elapsed = Model.RESULT_SECONDS
	m.result_elapsed = Model.RESULT_SECONDS
	m.save_checkpoint(m.p)

func until(predicate: Callable, limit := 900) -> bool:
	for i in limit:
		if predicate.call(): return true
		tick()
	return bool(predicate.call())

func new_scene() -> void:
	game = Scene.instantiate()
	game.progress_file = folder.path_join("save.json")
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.world.set_process(false)
	game.muted = true
	game.sound.set_muted(true)
	if game.sound.has_signal("event_played"):
		game.sound.connect("event_played",on_event)

func cold_resume(label: String) -> void:
	tap(KEY_ESCAPE)
	var before: Dictionary = game.model.save_payload()
	var heard := routed.size()
	check(game.mode == "pause" and game.has_saved,"disk pause: " + label)
	tick(20)
	check(game.model.save_payload() == before,"pause freezes model: " + label)
	check(routed.size() == heard,"pause creates no one-shots: " + label)
	if not game.has_saved: return
	game.queue_free()
	await process_frame
	await new_scene()
	game.on_secondary()
	var restored_mode: String = "ending" if before.completed else "pause"
	check(game.mode == restored_mode and game.model.save_payload() == before,"exact cold restore: " + label)
	tick(2)
	check(routed.size() == heard,"restore does not replay historical events: " + label)
	if game.mode == "pause": tap(KEY_ESCAPE)

func verify_sound_contract() -> void:
	section = "sound pool and mute"
	var sound = game.sound
	for kind in POND_EVENTS:
		var before := count(kind)
		sound.play_event(kind,0.0)
		check(count(kind) == before + 1,"mapped event allocates once while muted: " + kind)
		check(sound._voices.any(func(player): return player.stream != null),"pool owns an actual stream: " + kind)
	var before := routed.size()
	sound.play_event("not_a_pond_event",0.0)
	check(routed.size() == before,"unknown event allocates no voice")
	sound.play_event("finish",0.0)
	sound._process(0.1)
	for bus_name in ["Music","SFX","Ambience"]:
		check(AudioServer.is_bus_mute(AudioServer.get_bus_index(bus_name)),"event/duck/fade preserve mute: " + bus_name)
	section = "background context contract"
	sound.set_pond_context(false,false,false,false,true)
	var dry: float = sound._pond_rain_target
	var still: float = sound._pond_dance_target
	sound.set_pond_context(true,false,false,false,true)
	var exposed: float = sound._pond_rain_target
	check(exposed > dry,"real rain raises rain target above dry")
	sound.set_pond_context(true,true,false,false,true)
	check(sound._pond_rain_target < exposed,"cover attenuates exposed rain")
	sound.set_pond_context(true,false,true,false,true)
	check(sound._pond_dance_target > still,"active dance has a separate audible target")
	sound.set_pond_context(true,false,true,true,true)
	check(sound._pond_rain.stream_paused and sound._pond_dance.stream_paused,"pause suspends both gameplay backgrounds")
	before = routed.size()
	sound.play_event("source_observed",0.0)
	check(routed.size() == before,"paused sound cannot allocate a new one-shot")
	sound.set_pond_context(true,false,true,false,false)
	check(sound._pond_rain_target <= dry and sound._pond_dance_target <= still,"inactive title cannot retain rain or dance")
	check(sound._pond_rain.bus == "Ambience" and sound._pond_dance.bus == "SFX","new loops use existing mute-controlled buses")
	for pair in [["rain",sound._pond_rain.stream],["dance",sound._pond_dance.stream]]:
		var stream: AudioStreamWAV = pair[1]
		var metrics := inspect_pcm(stream)
		metrics["kind"] = pair[0]
		pcm_metrics.append(metrics)
		check(metrics.peak > 0.02 and metrics.peak < 0.9,"new loop is nonzero and has headroom: " + pair[0])
		check(metrics.seam_delta < 0.02,"new loop endpoint discontinuity below0.02: " + pair[0])
		check(stream.loop_mode == AudioStreamWAV.LOOP_FORWARD,"new background actually loops: " + pair[0])
	for kind in POND_EVENTS:
		var metrics := inspect_pcm(sound._samples[kind])
		check(metrics.peak > 0.02 and metrics.peak < 0.9,"new one-shot PCM is nonzero with headroom: " + kind)
	sound.play_event("burst",9000.0)
	var last: int = posmod(sound._voice-1,sound._voices.size())
	check(is_equal_approx(sound._voices[last].volume_db,-1.5),"distance argument does not attenuate legacy burst")
	sound.play_event("keeper_hang",0.0)
	last = posmod(sound._voice-1,sound._voices.size())
	var near_db: float = sound._voices[last].volume_db
	sound.play_event("keeper_hang",1000.0)
	last = posmod(sound._voice-1,sound._voices.size())
	check(sound._voices[last].volume_db < near_db,"new distant keeper action is attenuated")

func inspect_pcm(stream: AudioStreamWAV) -> Dictionary:
	var bytes: PackedByteArray = stream.data
	var peak := 0.0
	var energy := 0.0
	var samples: int = bytes.size()/2
	for i in samples:
		var value := bytes.decode_s16(i*2)/32768.0
		peak = maxf(peak,absf(value))
		energy += value*value
	return {"peak":peak,"rms":sqrt(energy/maxi(1,samples)),"seam_delta":absf(bytes.decode_s16(0)-bytes.decode_s16(bytes.size()-2))/32768.0}

func verify_preparation() -> void:
	section = "three real sign attachments"
	seed_stage(0,Vector2(3370,400))
	var start := routed.size()
	tick(110)
	check(game.model.preparation_count() == 0 and count("keeper_hang",start) == 0,"held sign does not sound attached early")
	await cold_resume("first sign held")
	check(until(func(): return game.model.preparation_count() == 1,60),"first sign actually attaches")
	check(count("keeper_hang",start) == 1,"first attachment routes once")
	check(game.model.keeper.pos != Model.preparation_position(1),"next hanger requires travel")
	var work: float = game.model.keeper.elapsed
	tick(10)
	check(game.model.keeper.elapsed == work and count("keeper_hang",start) == 1,"travel neither works nor plays another attachment")
	await cold_resume("travelling between hangers")
	check(until(func(): return game.model.keeper.state == "watch"),"keeper reaches all three hangers")
	check(count("keeper_hang",start) == 3,"three placements produce exactly three sounds")
	check(count("keeper_count",start) == 0,"stage0 counting pose is not the return encounter window")
	tick(60)
	check(count("keeper_hang",start) == 3,"finished rack does not repeat")

func verify_counting() -> void:
	section = "keeper window transition"
	seed_stage(2,Vector2(2190,465))
	var start := routed.size()
	check(until(func(): return game.model.keeper.state == "counting",240),"real approach/chase reaches counting")
	check(count("keeper_count",start) == 1,"window entry routes one count/rope sound")
	tick(40)
	check(game.model.keeper.state == "counting" and count("keeper_count",start) == 1,"holding a window does not loop its entry sound")
	await cold_resume("inside counting window")
	check(until(func(): return game.model.keeper.state != "counting",240),"window can finish")
	check(until(func(): return game.model.keeper.state == "counting",600),"another real cycle reaches counting")
	check(count("keeper_count",start) == 2,"next actual window is audible once again")

func verify_weather() -> void:
	section = "weather transitions and suspend"
	seed_stage(1,Vector2(660,520))
	var start := routed.size()
	tick()
	check(game.model.weather_phase == "warning" and count("weather_warning",start) == 1,"crossing650 actually enters audible warning")
	tick(25)
	await cold_resume("weather warning")
	check(until(func(): return game.model.weather_phase == "rain",180),"warning advances to actual rain")
	check(count("weather_warning",start) == 1,"warning is not replayed each frame or cold restore")
	game.model.p = Vector2(3700,520)
	game.model.velocity = Vector2.ZERO
	tick()
	check(game.model.weather_phase == "after" and game.model.drops.is_empty(),"actual far-side crossing clears rain")
	check(game.sound._pond_rain_target <= -60.0,"rain-after removes the local rain bed target")

func verify_source_and_dance() -> void:
	section = "observed source and bird"
	seed_stage(0,Model.SOURCE)
	var start := routed.size()
	tick(20)
	check(not game.model.observation_valid() and count("source_observed",start) == 0,"short feeding does not sound committed")
	tick(45)
	check(game.model.observation_valid() and count("source_observed",start) == 1,"real full feeding routes observation once")
	check(game.model.bird_greeted and count("bird_greeting",start) == 1,"actual bird response routes once")
	await cold_resume("observed source")
	tick(50)
	check(count("source_observed",start) == 1 and count("bird_greeting",start) == 1,"remaining by restored flower replays neither fact")
	section = "dance cancellation and commit"
	seed_stage(2,Model.COMB)
	open_gate_fixture()
	tick(2)
	start = routed.size()
	key(KEY_SPACE,true)
	tick()
	key(KEY_SPACE,false)
	tick(20)
	check(game.model.share_state == "dancing" and count("dance_commit",start) == 0,"dance begins without premature success sound")
	check(game.sound._pond_dance_target > -60.0,"live dance enables wing background")
	key(KEY_LEFT,true)
	tick()
	key(KEY_LEFT,false)
	check(game.model.share_state == "idle" and count("dance_commit",start) == 0,"real directional cancellation has no commit")
	check(game.sound._pond_dance_target <= -60.0,"cancelled dance removes its background target")
	game.model.p = Model.COMB
	game.model.velocity = Vector2.ZERO
	tick(2)
	key(KEY_SPACE,true)
	tick()
	key(KEY_SPACE,false)
	tick(20)
	await cold_resume("uncommitted dancing")
	check(until(func(): return game.model.message_revision == 1,120),"full dance commits actual source")
	check(count("dance_commit",start) == 1,"commit routes once")
	check(until(func(): return count("listener_depart",start) == 2,100),"two delayed listeners actually start flying")
	var departures: Array = []
	for i in range(start,routed.size()):
		if routed[i].kind == "listener_depart": departures.append(routed[i])
	if departures.size() == 2:
		check(departures[1].time > departures[0].time,"listener departures are separate physical starts")
		check(departures[0].listeners[0] != [Model.waiting_listener(0).pos.x,Model.waiting_listener(0).pos.y],"first departure is not merely assigning a delayed state")
	await cold_resume("listeners already flying")
	tick(200)
	key(KEY_SPACE,true)
	tick()
	key(KEY_SPACE,false)
	tick(160)
	check(count("dance_commit",start) == 1 and count("listener_depart",start) == 2,"restoring/repeated input does not duplicate committed report or flights")

func verify_ending_consumption() -> void:
	section = "earned result continues after arrival"
	seed_stage(2,Vector2(3600,630))
	open_gate_fixture()
	var m = game.model
	# A reached hook isolates lift timing; the real inspect/carry/place functions
	# then advance unchanged. Ending is deliberately seeded, not an arrival test.
	m.keeper = Model.actor(Model.PICKUP_POSITION)
	m.keeper.state = "tidy"
	m.result_elapsed = 0.0
	m.checkpoint_index = m.shelters.size()-1
	for leaf in m.shelters: leaf.reached = true
	m.save_checkpoint(Vector2(4410,500))
	m.phase = "ending"
	m.completed = true
	game.mode = "arrival"
	game.transition_left = 10000.0
	var start := routed.size()
	var zero_state: Dictionary = m.story_state()
	m.advance_tidy(0.0)
	m.advance_listeners(0.0)
	check(m.story_state() == zero_state and m.events.is_empty(),"zero timestep changes neither actors nor event queue")
	tick(20)
	check(m.result_elapsed < Model.INSPECT_SECONDS and count("keeper_lift",start) == 0,"arrival does not lift before inspection finishes")
	await cold_resume("ending inspection")
	m = game.model
	check(until(func(): return game.model.result_elapsed >= Model.INSPECT_SECONDS,100),"ending inspection really reaches pickup")
	check(count("keeper_lift",start) == 1,"ending consumes lift once outside play mode")
	check(until(func(): return game.model.keeper.state == "settled",900),"ending carry reaches final support")
	check(count("keeper_place",start) == 1,"ending consumes placement once outside play mode")
	check(game.model.events.is_empty(),"ending leaves no unconsumed audio event queue")
	tick(90)
	check(count("keeper_lift",start) == 1 and count("keeper_place",start) == 1,"settled ending cannot repeat lift or placement")

func run() -> void:
	if folder.is_empty():
		folder = OS.get_cache_dir().path_join("pond-audio-qa-" + str(OS.get_process_id()))
	DirAccess.make_dir_recursive_absolute(folder)
	await new_scene()
	var api: bool = game.sound.has_signal("event_played") and game.sound.has_method("set_pond_context")
	check(api,"pond event signal/context API exists (baseline missing API must fail)")
	if api:
		verify_sound_contract()
		await verify_preparation()
		await verify_counting()
		await verify_weather()
		await verify_source_and_dance()
		await verify_ending_consumption()
	var output := FileAccess.open(folder.path_join("audio-routing-report.json"),FileAccess.WRITE)
	if output != null:
		output.store_string(JSON.stringify({"kind":"controlled production state/routing/suspend tests; muted; no native listening or player evidence", "checks":checks, "failures":failures, "results":results, "routed_events":routed,"loop_pcm":pcm_metrics},"\t"))
		output.close()
	else:
		check(false,"report output is writable")
	game.queue_free()
	await process_frame
	print("POND AUDIO VERIFIED: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
