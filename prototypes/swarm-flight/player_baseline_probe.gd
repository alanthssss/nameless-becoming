extends SceneTree
## #236: native developer baseline, not a playtest or whole-character gate.
class NativeFixture extends "res://spring_journey_main.gd":
	func pause_game() -> void: pass # Only suppress OS focus pauses in this fixture.

var game
var folder := OS.get_environment("SWARM_PLAYER_QA_DIR")
var pressed: Array[Key] = []
var frames: Array = []
var segments: Array = []
var checks: Array = []
var failures := 0
const Model=preload("res://spring_journey_model.gd")

func dimensions() -> Dictionary:
	var source:=Image.load_from_file("res://art/revision-atlas.png")
	var low:=Vector2i(577,614)
	var high:=Vector2i(67,158)
	for y in range(158,614):
		for x in range(67,577):
			if source.get_pixel(x,y).a>=0.6:
				low=low.min(Vector2i(x,y))
				high=high.max(Vector2i(x+1,y+1))
	var contacts: Array=[]
	for compact in [false,true]:
		var m=Model.new()
		m.load_stage(0)
		m.walls.clear()
		m.walls.append({"rect":Rect2(1000,100,40,550),"kind":"solid","broken":false})
		var radius:=9.0 if compact else 14.0
		for margin in [0.1,-0.1]:
			m.p=Vector2(1000-radius-margin,230)
			m.velocity=Vector2.ZERO
			m.charging=compact
			var before: float=m.p.x
			m.advance(Vector2.ZERO,1.0/120)
			check(absf(m.p.x-before)<0.001 if margin>0 else m.p.x<=1000-radius,"Wall envelope %dpx: %s point"%[int(radius),"outside unchanged" if margin>0 else "inside expelled"])
			contacts.append({"charging":compact,"wall_x":1000,"initial_gap":radius+margin,"final_gap":1000-m.p.x})
	return {"method":"original source alpha>=0.6; full artwork includes noncolliding decorative anatomy, not a body mask",
		"source_rect":[67,158,510,456],"pivot":[316,468],"base_bitmap_width_px":60,
		"alpha_bounds_source":[low.x,low.y,high.x,high.y],
		"alpha_bounds_base_px":[(low.x-316)*60.0/510,(low.y-468)*60.0/510,(high.x-316)*60.0/510,(high.y-468)*60.0/510],
		"view_scale_charge_ready":[0.83,1.15],"view_scale_burst_without_wind":[1.25,0.81],
		"contacts":contacts,"contact_boundary":"isolated numerical wall fixture using production model; not native terrain/edge-expansion acceptance"}

func _initialize() -> void: call_deferred("run")

func key(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode=code
	event.keycode=code
	event.pressed=down
	root.push_input(event)
	if down and code not in pressed: pressed.append(code)
	if not down: pressed.erase(code)

func check(ok: bool, message: String) -> void:
	checks.append({"pass":ok,"assertion":message})
	if not ok:
		failures+=1
		push_error(message)

func sample(label: String) -> Dictionary:
	var m=game.model
	return {"frame":frames.size(),"segment":label,"mode":game.mode,"phase":m.phase,
		"keys":pressed.duplicate(),"p":[m.p.x,m.p.y],"velocity":[m.velocity.x,m.velocity.y],
		"face":[m.face.x,m.face.y],"charge":m.charge,"charging":m.charging,
		"ready":m.charging and m.charge>=m.CHARGE_READY and m.can_burst(),
		"burst_left":m.burst_left,"bursts":m.bursts,"stamina":m.stamina,
		"settle":game.world._settle,"recoveries":m.recoveries,"camera_x":m.camera_x,"invulnerable":m.invulnerable,
		"sheltered":m.shelter_index_at(m.p)>=0}

func segment(label: String, count: int) -> void:
	var before:=sample(label)
	var start:=frames.size()
	for i in count:
		game.tick(1.0/30.0)
		game.world._process(1.0/30.0)
		game.queue_redraw()
		game.world.queue_redraw()
		frames.append(sample(label))
		await process_frame
	await process_frame
	check(root.get_texture().get_image().save_png(folder.path_join(label+".png"))==OK,"Saved native PNG: "+label)
	segments.append({"name":label,"first_frame":start,"frames":count,"before":before,"after":sample(label),"screenshot":label+".png"})

func run() -> void:
	if folder.is_empty() or DisplayServer.get_name()=="headless":
		push_error("Set SWARM_PLAYER_QA_DIR and use the native renderer")
		quit(1)
		return
	if DirAccess.make_dir_recursive_absolute(folder)!=OK:
		push_error("Cannot create evidence directory")
		quit(1)
		return
	var measured:=dimensions()
	game=NativeFixture.new()
	game.test_mode=true
	game.progress_file=folder.path_join("unused-isolated-save.json")
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.world.set_process(false)
	game.sound.set_muted(true)
	game.begin_stage(0)
	# Explicit safe-air fixture. Authored stage remains intact; no other teleports.
	game.model.p=Vector2(850,230)
	game.model.velocity=Vector2.ZERO
	game.model.face=Vector2.RIGHT
	game.model.clear_input()
	game.model.started=false
	game.model.camera_x=370
	# Natural expiry of initial 1s invulnerability, not a production rule override.
	await segment("default",36)
	check(game.model.invulnerable==0,"Default keyframe is outside the initial blinking interval")
	key(KEY_RIGHT,true)
	await segment("flight-right",18)
	key(KEY_RIGHT,false)
	key(KEY_LEFT,true)
	await segment("turn-left",18)
	check(game.model.face.x<0 and game.model.velocity.x<0,"Left keyboard input reverses face and actual motion")
	key(KEY_LEFT,false)
	key(KEY_RIGHT,true)
	await segment("turn-right",18)
	check(game.model.face.x>0 and game.model.velocity.x>0,"Right keyboard input restores face and actual motion")
	key(KEY_RIGHT,false)
	await segment("flight-stop",18)
	check(game.model.velocity.length()<1,"Ordinary release stops in safe air")
	key(KEY_SPACE,true)
	await segment("early-charge",6)
	check(game.model.charging and not frames[-1].ready,"0.20 seconds held is charging but not ready")
	var before_cancel: float=game.model.stamina
	key(KEY_SPACE,false)
	await segment("cancel",1)
	check(game.model.bursts==0 and game.model.burst_left==0 and not game.model.charging,"Early release cancels without launch")
	check(absf(before_cancel-game.model.stamina-2.0/30.0)<0.001,"Early release pays only ordinary flight drain, no burst cost")
	key(KEY_SPACE,true)
	await segment("charge-before-ready",11)
	check(not frames[-1].ready,"At 11/30 seconds charge is not ready")
	await segment("ready",1)
	check(frames[-1].ready,"At 12/30 seconds charge is ready")
	var before_burst: float=game.model.stamina
	key(KEY_SPACE,false)
	await segment("burst",1)
	check(game.model.bursts==1 and game.model.burst_left>0,"Ready release launches exactly once")
	check(absf(before_burst-game.model.stamina-20.0-2.0/30.0)<0.001,"Ready release costs 20 plus one frame of flight drain")
	key(KEY_LEFT,true)
	await segment("burst-direction-locked",8)
	check(game.model.face.x>0 and game.model.velocity.x>800,"Opposite input does not steer an active burst")
	key(KEY_LEFT,false)
	await segment("settle",9)
	check(game.model.burst_left==0 and game.world._settle>0,"Burst ends and production view enters settle")
	await segment("free-again",18)
	check(game.model.burst_left==0 and not game.model.charging and game.model.velocity.length()<1 and game.world._settle==0,"Settled bee returns to stationary free flight")
	check(frames.all(func(f):return f.mode=="play" and f.phase=="playing" and f.recoveries==0),"Every frame stays playing without recovery")
	check(frames.all(func(f):return not f.sheltered),"Safe-air cost assertions never enter a recovery shelter")
	check(not FileAccess.file_exists(game.progress_file),"Fixture writes no progress file")
	var report: Dictionary={"issue":236,"base_revision":"801823675f5dfc0de653d3d3737a428c9991e6f1",
		"kind":"native_developer_fixture","fps":30,"fixture":"production Spring main/model/view, stage0 safe-air initial placement; keyboard root.push_input; fixed ticks; OS pause suppressed; saves disabled before ready; sound muted",
		"frame_numbering":"model sample indices; movie also includes initial setup and unticked render waits",
		"dimensions":measured,"checks":checks,"failures":failures,"segments":segments,"frames":frames}
	var file:=FileAccess.open(folder.path_join("trace.json"),FileAccess.WRITE)
	if file==null:
		push_error("Cannot write trace")
		quit(1)
		return
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	var readback=JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("trace.json")))
	if not readback is Dictionary or readback.get("frames",[]).size()!=frames.size():
		push_error("Trace readback failed")
		quit(1)
		return
	game.queue_free()
	await process_frame
	print("PLAYER BASELINE: %d assertions, %d failures, %d simulated frames"%[checks.size(),failures,frames.size()])
	quit(1 if failures else 0)
