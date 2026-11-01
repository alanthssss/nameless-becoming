extends SceneTree
## Known-solution continuous developer route; not independent player exploration.
class NativeFixture extends "res://spring_journey_main.gd":
	func _notification(what: int):
		if what!=NOTIFICATION_APPLICATION_FOCUS_OUT: super._notification(what)
const Scene = preload("res://spring_journey.tscn")
const Model = preload("res://spring_journey_model.gd")
const Driver = preload("res://route_driver.gd")
const Save = preload("res://save_data.gd")
var game
var checks := 0
var failures := 0
var pressed := {}
var folder := OS.get_environment("SWARM_SPRING_QA_DIR")
var movie_ticks:=0
var dry_fast=DisplayServer.get_name()=="headless" and OS.get_environment("SWARM_DRY_FAST")=="1"
var waits=[]
const MAX_TICKS=24000
var PRODUCTION_REVISION=OS.get_environment("SWARM_PRODUCTION_REVISION") if not OS.get_environment("SWARM_PRODUCTION_REVISION").is_empty() else "uncommitted-wind-layout-after-17f84019ad64302e4c972d5b339c7c637b36d820"
var samples=[]
var event_trace=[]
var verdicts=[]
var marks=[]
func snapshot() -> Dictionary:
	var m=game.model
	var visual: Vector2=m.p+(m.dance_pose() if m.perched else Vector2.ZERO)-Vector2(m.camera_x,0)
	var body:=Rect2(visual-Vector2(62,52),Vector2(124,104))
	var captions=[]
	for f in game.world._feedback:
		if f.kind!="caption" or game.world.feedback_font==null: continue
		var w: float=game.world.feedback_font.get_string_size(f.text,HORIZONTAL_ALIGNMENT_LEFT,-1,19).x
		var point:=Vector2(clampf(f.pos.x,m.camera_x+w/2+24,m.camera_x+1256-w/2)-m.camera_x,clampf(f.pos.y-45-(0.9-f.life)*24,160,670))
		captions.append(Rect2(point-Vector2(w/2+9,23),Vector2(w+18,31)))
	var cue: Rect2=game.cue_panel.get_rect()
	return {"tick":movie_ticks,"engine_frame":Engine.get_process_frames(),"stage":m.stage,"mode":game.mode,"phase":m.phase,"p":[m.p.x,m.p.y],"stamina":m.stamina,"recoveries":m.recoveries,"dew":m.garden_total(),"weather":m.weather_phase,"warning":m.warning_elapsed,"shield":m.shield_left,"shelter":m.shelter_index_at(m.p),"observed":m.observation_valid(),"small_state":m.small.state,"small_pos":[m.small.pos.x,m.small.pos.y],"keeper_state":m.keeper.state,"keeper_pos":[m.keeper.pos.x,m.keeper.pos.y],"keeper_target":[m.keeper.target.x,m.keeper.target.y],"front":m.front_open,"passage":m.passage_open,"result":m.result_elapsed,"rings":m.rings_hit,"share":m.share_state,"message_revision":m.message_revision,"listeners":m.listeners.map(func(b): return {"state":b.state,"p":[b.pos.x,b.pos.y]}),"color":m.color_step,"camera_x":m.camera_x,"exposed":m.weather_phase=="rain" and m.p.y<m.rain_floor_at(m.p.x) and m.shelter_index_at(m.p)<0,"cue_clear":game.mode!="play" or not game.cue_panel.visible or not cue.intersects(body),"cue_caption_clear":game.mode!="play" or not game.cue_panel.visible or captions.all(func(b):return not cue.intersects(b))}
func voiced(kind: String):
	event_trace.append({"tick":movie_ticks,"stage":game.model.stage,"mode":game.mode,"kind":kind})
func write_trace():
	var file=FileAccess.open(folder.path_join("trace.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"kind":"known-solution ordinary-input route with real menu cold recovery;not independent exploration or subjective listening","revision":PRODUCTION_REVISION,"headless_fast_dry_run":dry_fast,"fixed_fps":30,"sample_interval_ticks":2,"total_simulation_ticks":movie_ticks,"simulation_seconds":movie_ticks/60.0,"recorded_waits":waits,"photo_wait_semantics":"Rendering-only frame waits do not advance model; all explicit observation waits recorded separately","simulation_step":1.0/60,"checks":checks,"failures":failures,"assertions":verdicts,"marks":marks,"voiced_events":event_trace,"samples":samples},"\t"))
	file.close()

func _initialize() -> void: call_deferred("run")

func check(ok: bool,label: String) -> void:
	checks += 1
	verdicts.append({"tick":movie_ticks,"pass":ok,"label":label})
	if not ok:
		failures += 1
		print("FAIL: "+label)

func key(code: Key,down: bool) -> void:
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

func action(command: Dictionary) -> void:
	var d: Vector2 = command.direction
	var codes := [KEY_LEFT,KEY_RIGHT,KEY_UP,KEY_DOWN,KEY_SPACE]
	var values := [d.x < -0.1,d.x > 0.1,d.y < -0.1,d.y > 0.1,command.held]
	for i in codes.size():
		if values[i] != pressed.has(codes[i]): key(codes[i],values[i])

func tick(count := 1) -> void:
	for i in count:
		if movie_ticks>=MAX_TICKS:
			check(false,"bounded total simulation ticks exceeded")
			write_trace()
			quit(1)
			return
		game.tick(1.0/60)
		game.world._process(1.0/60)
		movie_ticks+=1
		if movie_ticks%2==0:
			samples.append(snapshot())
			if not dry_fast: await process_frame

func shot(name: String) -> void:
	marks.append({"name":name,"state":snapshot()})
	if DisplayServer.get_name() == "headless": return
	game.queue_redraw()
	game.world.queue_redraw()
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(folder.path_join(name+".png")) == OK,"capture "+name)

func new_scene() -> void:
	game = NativeFixture.new()
	game.progress_file=folder.path_join("save.json")
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.world.set_process(false)
	game.muted=false
	game.sound.set_muted(false)
	game.sound.event_played.connect(voiced)

func fly(target: Vector2) -> void:
	for frame in 1500:
		var d: Vector2 = target-game.model.p
		if d.length() < 10 or game.model.phase != "playing": break
		action({"direction":Vector2(signf(d.x) if absf(d.x)>6 else 0.0,signf(d.y) if absf(d.y)>6 else 0.0),"held":false})
		await tick()
	var reached: bool=game.model.p.distance_to(target)<10
	var exited: bool=target.x>=game.model.exit_pos.x and game.model.phase!="playing" and game.mode in ["transition","arrival","ending"]
	if not reached and not exited:
		check(false,"waypoint timeout: "+str(target)+" actual "+str(game.model.p))
		write_trace()
		quit(1)
		return
	check(reached or exited,"waypoint or expected exit: stage%d target%s actual%s mode%s" % [game.model.stage,target,game.model.p,game.mode])
	release_all()
	await observed_wait(6,"ordinary waypoint settling")

func cold_resume(label: String) -> void:
	tap(KEY_ESCAPE)
	var before: Dictionary = game.model.save_payload()
	check(game.mode=="pause" and game.has_saved,"actual disk pause "+label)
	await observed_wait(90,"paused disk roundtrip: "+label)
	check(game.model.save_payload()==before,"pause freezes transaction and listeners "+label)
	release_all()
	game.queue_free()
	await process_frame
	await new_scene()
	check(not game.saved_payload.is_empty(),"cold launch reads save "+label)
	tap(KEY_DOWN)
	tap(KEY_ENTER)
	check(game.mode=="pause" and game.model.save_payload()==before,"exact cold resume "+label)
	tap(KEY_ESCAPE)

func observed_wait(count: int,label: String) -> void:
	var start:=movie_ticks
	await tick(count)
	waits.append({"start_tick":start,"end_tick":movie_ticks,"reason":label})

func run() -> void:
	if folder.is_empty() or FileAccess.file_exists(folder.path_join("save.json")):
		print("Set SWARM_SPRING_QA_DIR to a fresh isolated writable directory")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(folder)
	await new_scene()
	check(game.model.journey_id()=="spring-03-05-v2" and game.saved_payload.is_empty(),"fresh integrated journey via actual menu")
	await shot("00-title")
	tap(KEY_ENTER)
	for point in [Vector2(400,230),Vector2(1080,230),Vector2(1270,500),Vector2(1060,500),Vector2(1270,500),Vector2(1450,190),Vector2(2050,190),Vector2(2280,190)]: await fly(point)
	await shot("01-departure-and-mosquito")
	for point in [Vector2(2280,530),Vector2(2520,500),Vector2(2750,500)]: await fly(point)
	await shot("02-flower-lower-preview")
	await fly(Vector2(2750,230))
	await shot("03-upper-source-preview")
	for point in [Vector2(3100,230),Vector2(3300,230),Vector2(3470,230)]: await fly(point)
	check(not game.model.observation_valid(),"upper source route skips feeding through ordinary flight")
	await shot("04-source-skipped")
	await cold_resume("source skipped")
	await fly(Vector2(3470,600))
	for point in [Vector2(3710,600),Vector2(3970,600),Vector2(4170,500),Vector2(4410,500),game.model.exit_pos+Vector2(45,0)]: await fly(point)
	check(game.mode=="transition" and game.model.stage==0,"first actual threshold reaches handoff")
	await cold_resume_transition("pond to rain")
	await observed_wait(150,"automatic stage handoff")
	check(game.mode=="play" and game.model.stage==1,"automatic pond to rain transition")
	for point in [Vector2(620,520),Vector2(1250,520)]: await fly(point)
	await shot("05-rain-forecast-and-roof")
	await cold_resume("rain before branch")
	for point in [Vector2(1350,400),Vector2(1540,400),Vector2(1760,520),Vector2(2170,520),Vector2(2330,520)]: await fly(point)
	await shot("06-safe-rain-choice")
	for point in [Vector2(2330,630),Vector2(2630,600)]: await fly(point)
	check(game.model.shield_left==0 and game.model.shelter_index_at(game.model.p)==2,"missed shield reaches actual low recovery leaf")
	await shot("07-unshielded-low-rest")
	var low_energy: float=game.model.stamina
	await observed_wait(60,"observe real low leaf recovery")
	check(game.model.stamina>=low_energy,"low leaf genuinely recovers stamina")
	await cold_resume("unshielded low leaf")
	for point in [Vector2(2780,600),Vector2(2860,520),Vector2(3010,520)]: await fly(point)
	await shot("08-low-route-rejoins-high-leaf")
	for point in [Vector2(3158,520),Vector2(3158,435),Vector2(3200,435),Vector2(3400,435),Vector2(3560,420),Vector2(4120,500),Vector2(4360,500),game.model.exit_pos+Vector2(45,0)]: await fly(point)
	check(game.mode=="transition" and game.model.stage==1,"rain path reaches actual exit")
	await observed_wait(150,"automatic rain to return handoff")
	check(game.model.stage==2,"automatic return stage reached")
	for point in [Vector2(620,620),Vector2(1000,620),Vector2(1260,500),Vector2(1850,590),Vector2(2190,465)]: await fly(point)
	var count_start:=movie_ticks
	for i in 900:
		if game.model.keeper.state=="counting" and game.model.keeper.elapsed<1.2: break
		await tick()
	waits.append({"start_tick":count_start,"end_tick":movie_ticks,"reason":"wait for actual counting opportunity"})
	check(game.model.keeper.state=="counting","first opening uses actual counting window")
	await shot("10-first-counting-window")
	key(KEY_RIGHT,true)
	key(KEY_SPACE,true)
	await observed_wait(30,"ordinary first-knot charge")
	key(KEY_SPACE,false)
	for i in 90:
		if game.model.front_open: break
		await tick()
	release_all()
	check(game.model.front_open and not game.model.passage_open,"first physical knot commits alone")
	await cold_resume("first opening")
	for point in [Vector2(2740,465),Vector2(2740,500),Vector2(3040,500),Vector2(3040,300),Vector2(3070,300)]: await fly(point)
	await shot("11-ordinary-back-knot-approach")
	key(KEY_RIGHT,true)
	key(KEY_SPACE,true)
	await observed_wait(30,"ordinary back-knot charge without wind")
	key(KEY_SPACE,false)
	for i in 90:
		if game.model.passage_open: break
		await tick()
	release_all()
	check(game.model.passage_open and game.model.rings_hit==0,"ordinary height change opens back without wind relay")
	await shot("12-second-opening")
	await cold_resume("keeper tidying after second opening")
	for point in [Vector2(3460,300),Vector2(3460,620),Vector2(3260,620)]: await fly(point)
	var tidy_start:=movie_ticks
	for i in 900:
		if game.model.keeper.state=="settled": break
		await tick()
	waits.append({"start_tick":tidy_start,"end_tick":movie_ticks,"reason":"developer observation of actual keeper arrival and placing; player controls remain available"})
	check(game.model.keeper.state=="settled","keeper really reaches supported result")
	await shot("13-keeper-placed-signs")
	check(not game.model.observation_valid() and game.model.message_revision==0,"skip route has no source fact or report")
	check(game.model.listeners.all(func(bee): return bee.state=="waiting"),"no sharing leaves both listeners waiting")
	await shot("14-no-share-direct-home")
	for point in [Vector2(3970,600),Vector2(4170,500),Vector2(4410,500),game.model.exit_pos+Vector2(45,0)]: await fly(point)
	await observed_wait(180,"arrival and ending sequence")
	check(game.mode=="ending" and game.model.stage==2,"whole journey reaches ending")
	await shot("16-ending")
	var ending: Dictionary=game.model.save_payload()
	release_all()
	game.queue_free()
	await process_frame
	await new_scene()
	tap(KEY_DOWN)
	tap(KEY_ENTER)
	check(game.mode=="ending" and game.model.save_payload()==ending,"completed ending exact cold launch")
	marks.append({"name":"completed-cold-ending","state":snapshot()})
	check(samples.all(func(f):return f.cue_clear and f.cue_caption_clear),"sampled context cue avoids player and feedback throughout route")
	write_trace()
	game.queue_free()
	await process_frame
	print("POND MVP ROUTE B VERIFIED: %d checks, %d failures; %d ticks at60Hz" % [checks,failures,movie_ticks])
	quit(1 if failures else 0)
func cold_resume_transition(label: String) -> void:
	tap(KEY_ESCAPE)
	var before: Dictionary=game.model.save_payload()
	check(game.mode=="pause","pause at chapter boundary "+label)
	game.queue_free()
	await process_frame
	await new_scene()
	tap(KEY_DOWN)
	tap(KEY_ENTER)
	check(game.model.save_payload()==before and game.mode=="pause" and game.paused_from=="transition","cold chapter boundary is paused at same chapter fact")
	tap(KEY_ESCAPE)
	check(game.mode=="transition","explicit resume restores pending handoff")
