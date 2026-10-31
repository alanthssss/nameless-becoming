extends SceneTree
## Bounded source fixtures, not a continuous route or independent exploration.
class NativeFixture extends "res://spring_journey_main.gd":
	func _notification(what: int):
		if what!=NOTIFICATION_APPLICATION_FOCUS_OUT: super._notification(what)
const Model=preload("res://spring_journey_model.gd")
const Canopy=preload("res://leaf_canopy_geometry.gd")
var game
var folder=OS.get_environment("SWARM_POND_STATES_DIR")
var native=false
var section="setup"
var frames=[]
var events=[]
var assertions=[]
var failures=0
var held: Array[Key]=[]
var seeds=[]
func _initialize(): call_deferred("run")
func check(ok: bool,label: String):
	assertions.append({"section":section,"frame":frames.size(),"pass":ok,"label":label})
	if not ok:
		failures+=1
		print("FAIL: "+section+": "+label)
func key(code: Key,down: bool):
	var e=InputEventKey.new()
	e.keycode=code
	e.physical_keycode=code
	e.pressed=down
	root.push_input(e)
	if down and code not in held: held.append(code)
	if not down: held.erase(code)
func tap(code: Key):
	key(code,true)
	key(code,false)
func release_keys():
	for code in held.duplicate(): key(code,false)
func caption_bounds() -> Array:
	# Independently reconstruct the actual drawn caption box, including text width.
	var boxes=[]
	for f in game.world._feedback:
		if f.kind!="caption" or game.world.feedback_font==null: continue
		var w: float=game.world.feedback_font.get_string_size(f.text,HORIZONTAL_ALIGNMENT_LEFT,-1,19).x
		var point:=Vector2(clampf(f.pos.x,game.model.camera_x+w/2+24,game.model.camera_x+1256-w/2)-game.model.camera_x,clampf(f.pos.y-45-(0.9-f.life)*24,160,670))
		boxes.append(Rect2(point-Vector2(w/2+9,23),Vector2(w+18,31)))
	return boxes
func state() -> Dictionary:
	var m=game.model
	var visual: Vector2=m.p+(m.dance_pose() if m.perched else Vector2.ZERO)-Vector2(m.camera_x,0)
	var body:=Rect2(visual-Vector2(62,52),Vector2(124,104))
	var cue_rect: Rect2=game.cue_panel.get_rect()
	return {"caption_rects":caption_bounds().map(func(b): return [b.position.x,b.position.y,b.size.x,b.size.y]),"cue_caption_clear":game.mode!="play" or not game.cue_panel.visible or caption_bounds().all(func(b): return not cue_rect.intersects(b)),"cue_rect":[cue_rect.position.x,cue_rect.position.y,cue_rect.size.x,cue_rect.size.y],"body_rect":[body.position.x,body.position.y,body.size.x,body.size.y],"cue_clear":game.mode!="play" or not game.cue_panel.visible or not cue_rect.intersects(body),"frame":frames.size(),"section":section,"stage":m.stage,"mode":game.mode,"p":[m.p.x,m.p.y],"v":[m.velocity.x,m.velocity.y],"stamina":m.stamina,"charge":m.charge,"charging":m.charging,"burst":m.burst_left,"bursts":m.bursts,"keys":held.duplicate(),"invulnerable":m.invulnerable,"recoveries":m.recoveries,"sheltered":m.shelter_index_at(m.p)>=0,"shield":m.shield_left,"weather":m.weather_phase,"small":m.small.state,"small_pos":[m.small.pos.x,m.small.pos.y],"small_target":[m.small.target.x,m.small.target.y],"source_open":m.source_open,"observed":m.observation_valid(),"feeding":m.feeding_elapsed,"perched":m.perched,"share":m.share_state,"dance":m.dance_elapsed,"message_revision":m.message_revision,"suppress_space":m.suppress_space,"listeners":m.listeners.map(func(b): return b.state),"toast_kind":game.toast_kind,"toast":game.toast.text,"hint":game.hud_hint.text}
func on_sound(kind: String):
	var event={"frame":frames.size(),"section":section,"kind":kind,"stage":game.model.stage,"stamina":game.model.stamina}
	for e in game.model.events:
		if e.kind==kind:
			for field in ["reason","cost","reward"]:
				if e.has(field): event[field]=e[field]
	events.append(event)
func count(kind: String,after:=0) -> int:
	return events.slice(after).filter(func(e): return e.kind==kind).size()
func tick(n:=1):
	for i in n:
		game.tick(1.0/30)
		game.world._process(1.0/30)
		game.sound._process(1.0/30)
		frames.append(state())
		await process_frame
func until(predicate: Callable,limit:=240) -> bool:
	for i in limit:
		if predicate.call(): return true
		await tick()
	return bool(predicate.call())
func shot(label: String):
	var visual: Vector2=game.model.p+(game.model.dance_pose() if game.model.perched else Vector2.ZERO)-Vector2(game.model.camera_x,0)
	var body:=Rect2(visual-Vector2(62,52),Vector2(124,104))
	if game.mode=="play" and game.cue_panel.visible:
		check(not game.cue_panel.get_rect().intersects(body),"context cue clears full bee/shield: "+label)
		check(caption_bounds().all(func(b): return not game.cue_panel.get_rect().intersects(b)),"context cue clears actual feedback caption: "+label)
	if not native: return
	game.queue_redraw()
	game.world.queue_redraw()
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(folder.path_join(label+".png"))==OK,"native PNG "+label)
func new_scene():
	game=NativeFixture.new()
	game.progress_file=folder.path_join("save.json")
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.world.set_process(false)
	game.sound.set_process(false)
	game.muted=not native
	game.sound.set_muted(not native)
	game.sound.event_played.connect(on_sound)
func fixture(index: int,point: Vector2):
	release_keys()
	game.begin_stage(index)
	game.model.p=point
	game.model.velocity=Vector2.ZERO
	game.model.clear_input()
	game.model.started=true
	game.model.invulnerable=0
	game.model.rng.seed=7271
	game.held.clear()
	game.model.events.clear()
	check(game.model.walls.all(func(w): return w.broken or not w.rect.grow(14).has_point(point)),"fixture starts outside actual solid walls")
	check(game.model.shelters.all(func(leaf): return Canopy.clear_disk(point,14,Canopy.polygon(leaf))),"fixture starts outside actual leaf bodies")
	seeds.append({"section":section,"frame":frames.size(),"stage":index,"p":[point.x,point.y],"note":"Controlled initial position,zero velocity,full default energy and no initial invulnerability;production scene geometry unchanged"})
func open_gates_fixture():
	var m=game.model
	m.front_open=true
	m.passage_open=true
	m.wall_at(2350).broken=true
	m.wall_at(Model.BACK_WALL_X).broken=true
	m.keeper=Model.actor(Model.RESULT_HOME)
	m.keeper.state="settled"
	m.keeper.elapsed=Model.RESULT_SECONDS
	m.result_elapsed=Model.RESULT_SECONDS
	m.save_checkpoint(m.p)
	seeds.append({"section":section,"frame":frames.size(),"note":"Previously earned open gates and settled keeper seeded to isolate share source,not counted as observed gate events"})
func cold_resume(label: String):
	release_keys()
	tap(KEY_ESCAPE)
	var saved: Dictionary=game.model.save_payload()
	await tick(5)
	check(game.model.save_payload()==saved,"pause frozen "+label)
	game.queue_free()
	await process_frame
	await new_scene()
	game.on_secondary()
	check(game.mode=="pause" and game.model.save_payload()==saved,"disk cold exact "+label)
	tap(KEY_ESCAPE)
	await tick()
func movement_edges():
	section="A-stem"
	fixture(0,Vector2(2155,480))
	key(KEY_SPACE,true)
	key(KEY_RIGHT,true)
	await tick(8)
	check(game.model.p.x>2156 and game.model.p.x<=2161.01,"compact bee reaches real stem9px boundary")
	check(game.model.charging and game.model.charge<game.model.CHARGE_READY,"moving charge remains early")
	await shot("01-stem-compact")
	key(KEY_SPACE,false)
	await tick()
	check(game.model.p.x<=2156 and not game.model.charging and game.model.bursts==0,"early release unfolds to14px outside stem without burst")
	await shot("02-stem-expanded")
	var y: float=game.model.p.y
	key(KEY_UP,true)
	await tick(18)
	check(game.model.p.y<y-45 and game.model.p.x<=2156,"ordinary input slides along real stem")
	release_keys()
	key(KEY_LEFT,true)
	await tick(14)
	check(game.model.p.x<2100,"expanded bee can leave stem")
	await shot("03-stem-leave")
	section="A-leaf"
	fixture(1,Vector2(620,520))
	var leaf: Dictionary=game.model.shelters[0]
	game.model.p=Vector2(leaf.pos.x,Canopy.bottom_at(leaf.pos.x,leaf)+17)
	seeds.append({"section":section,"frame":frames.size(),"note":"Start17px beneath actual leaf underside","p":[game.model.p.x,game.model.p.y]})
	key(KEY_UP,true)
	key(KEY_SPACE,true)
	await tick(8)
	check(Canopy.clear_disk(game.model.p,9,Canopy.polygon(leaf)),"charged body clear of actual painted leaf")
	await shot("04-leaf-compact")
	key(KEY_SPACE,false)
	await tick()
	check(Canopy.clear_disk(game.model.p,14,Canopy.polygon(leaf)),"unfolded body clear of actual painted leaf")
	await shot("05-leaf-expanded")
	release_keys()
	var before: Vector2=game.model.p
	key(KEY_DOWN,true)
	await tick(15)
	check(game.model.p.y>before.y+45,"expanded body can leave leaf underside")
	section="A-low-energy"
	fixture(0,Vector2(1700,210))
	game.model.stamina=19
	seeds.append({"section":section,"frame":frames.size(),"note":"19 energy boundary fixture"})
	var start=events.size()
	key(KEY_SPACE,true)
	key(KEY_LEFT,true)
	await tick(12)
	check(game.model.charging and game.model.charge>=game.model.CHARGE_READY and game.model.face.x<0,"moving low-energy charge can turn and reaches timing threshold")
	var energy: float=game.model.stamina
	key(KEY_SPACE,false)
	await tick()
	check(count("tired",start)==1 and game.model.bursts==0 and game.model.burst_left==0,"below20 release rejects burst once")
	check(absf(energy-game.model.stamina-2.0/30)<0.001,"rejection costs flight drain only")
	await shot("06-too-tired")
func mosquito_cycle():
	section="B-miss-cycle"
	fixture(0,Vector2(2520,280))
	var begin=frames.size()
	var start=events.size()
	check(game.model.small.state=="idle","ordinary mosquito begins idle")
	check(await until(func(): return game.model.small.state=="aim"),"actual visible approach triggers aim")
	await shot("07-mosquito-aim")
	check(await until(func(): return game.model.small.state=="chase"),"aim enters real chase")
	key(KEY_UP,true)
	await tick(20)
	key(KEY_UP,false)
	key(KEY_RIGHT,true)
	await tick(32)
	release_keys()
	check(await until(func(): return game.model.small.state=="idle",180),"missed chase returns,rests and becomes idle")
	var states=frames.slice(begin).map(func(f): return f.small)
	check(["aim","chase","return","rest","idle"].all(func(s): return s in states),"all ordinary mosquito states sampled")
	check(count("hit",start)==0,"moving away actually avoids contact")
	check(game.model.small.pos.distance_to(Model.SMALL_HOME)<0.1,"ordinary mosquito returns to its real perch")
	await shot("08-mosquito-missed")
	section="B-contact-recovery"
	fixture(0,Vector2(2480,280))
	start=events.size()
	check(await until(func(): return count("hit",start)>0,100),"stationary target receives actual mosquito collision")
	var hits=events.slice(start).filter(func(e): return e.kind=="hit")
	check(hits.size()==1 and hits[0].get("reason")=="mosquito" and hits[0].get("cost")==8,"contact event records8 energy mosquito damage")
	check(game.model.invulnerable>1.7,"contact starts1.8second protection")
	await shot("09-mosquito-hit")
	await tick(20)
	check(count("hit",start)==1,"continued nearby contact does not repeat within protection")
	var contacts=frames.filter(func(f): return f.section==section and f.small=="chase" and Vector2(f.p[0],f.p[1]).distance_to(Vector2(f.small_pos[0],f.small_pos[1]))<30 and f.invulnerable>0)
	check(contacts.size()>=2,"protection assertion includes multiple actual contact frames")
	var target: Vector2=game.model.checkpoint.p
	key(KEY_LEFT,true)
	key(KEY_SPACE,true)
	await tick(5)
	tap(KEY_R)
	check(game.model.p.distance_to(target)<0.1 and game.model.stamina==100,"R restores registered safe point and energy100")
	check(game.held.is_empty() and not game.model.charging and game.model.burst_left==0 and game.model.velocity.is_zero_approx(),"R clears held movement,charge,burst and velocity")
	check(game.model.invulnerable>=2.49,"R provides2.5seconds protection")
	await tick(10)
	check(game.model.p.distance_to(target)<0.1,"old keys do not continue motion after R")
	release_keys()
	await shot("10-safe-recovery")
func physical_drop():
	game.model.drops.append({"pos":game.model.p+Vector2(0,-70),"vel":Vector2(0,350)})
	seeds.append({"section":section,"frame":frames.size(),"note":"One controlled physical rain particle70px above bee,350px/s;no direct hurt invocation"})
func shield_cycle():
	section="C-shield-cycle"
	fixture(1,Vector2(2425,450))
	var pickup: Vector2=game.model.shields[0].pos
	check(game.model.p==pickup+Vector2(55,0),"safe fixture starts55px right of shield")
	game.model.weather_phase="rain"
	game.model.warning_elapsed=Model.WARNING_SECONDS
	var start=events.size()
	key(KEY_LEFT,true)
	check(await until(func(): return game.model.shield_left>0,50),"actual movement contacts shield pickup")
	release_keys()
	check(count("shield",start)==1 and game.model.shields[0].collected and game.model.shield_left>4.8,"pickup commits one five-second shield")
	await shot("11-shield-picked")
	key(KEY_UP,true)
	key(KEY_RIGHT,true)
	await tick(12)
	release_keys()
	await tick(10)
	check(game.model.shelter_index_at(game.model.p)<0 and game.model.p.y<game.model.rain_floor_at(game.model.p.x),"shielded test body really exposed above geometry")
	var energy: float=game.model.stamina
	var before: float=game.model.time
	physical_drop()
	check(await until(func(): return count("shield_block",start)>0,20),"physical falling drop is blocked by active shield")
	check(count("hit",start)==0,"shield block produces no damage event")
	check(absf(energy-game.model.stamina-2.0*(game.model.time-before))<0.01,"shield block pays only ordinary exposure drain")
	physical_drop()
	physical_drop()
	await tick(5)
	check(count("shield_block",start)==1 and count("hit",start)==0,"two more physical drops within0.35s do not spam block feedback")
	await shot("12-shield-block")
	check(await until(func(): return game.model.shield_left<0.5,180),"shield naturally approaches expiration")
	check(game.model.shield_left>0,"near-end snapshot still protected")
	await shot("13-shield-near-end")
	if native:
		root.size=Vector2i(960,600)
		await process_frame
		await process_frame
		await shot("13b-shield-small-window")
		root.size=Vector2i(1280,800)
		await process_frame
	check(await until(func(): return game.model.shield_left==0,30),"shield expires through ordinary time")
	check(count("shield_end",start)==1,"expiry emits exactly one end event")
	await shot("14-shield-ended")
	physical_drop()
	check(await until(func(): return count("hit",start)>0,25),"unshielded physical drop actually hurts")
	var hit=events.slice(start).filter(func(e): return e.kind=="hit")
	check(hit.size()==1 and hit[0].get("reason")=="rain" and hit[0].get("cost")==30,"unprotected rain damage30 matches feedback")
	await shot("15-rain-hit")
	check(await until(func(): return game.model.invulnerable==0,80),"rain protection interval naturally ends")
	game.model.stamina=20
	seeds.append({"section":section,"frame":frames.size(),"note":"20 energy lethal-boundary fixture,actual incoming particle causes recovery"})
	var recovered: int=game.model.recoveries
	physical_drop()
	check(await until(func(): return game.model.recoveries>recovered,25),"physical rain hit below30 restores checkpoint")
	check(game.model.stamina==100 and game.model.drops.is_empty() and game.model.shield_left==0,"rain recovery clears particles/shield and restores energy")
	check(game.held.is_empty() and game.model.velocity.is_zero_approx(),"rain recovery resets input and velocity")
	await shot("16-rain-recovered")
func observation_and_share():
	section="D-no-observation"
	fixture(0,Model.SOURCE)
	await tick(9)
	check(not game.model.observation_valid() and game.model.feeding_elapsed>0,"short flower visit is not a remembered source")
	key(KEY_RIGHT,true)
	await tick(15)
	release_keys()
	check(game.model.feeding_elapsed==0 and not game.model.observation_valid(),"leaving flower clears incomplete feeding")
	fixture(2,Model.COMB)
	open_gates_fixture()
	await tick(2)
	var start=events.size()
	key(KEY_SPACE,true)
	await tick(6)
	key(KEY_SPACE,false)
	await tick(40)
	check(game.model.perched and game.model.share_state=="idle" and game.model.message_revision==0 and count("dance_commit",start)==0,"without observation comb cannot invent a report")
	await shot("17-no-observation")
	section="D-late-observation"
	fixture(2,Model.SOURCE)
	open_gates_fixture()
	await tick(22)
	check(game.model.observation_valid(),"same true source can be observed on return")
	await shot("18-return-feed")
	game.model.p=Model.COMB
	game.model.velocity=Vector2.ZERO
	seeds.append({"section":section,"frame":frames.size(),"note":"Move fixture to comb after actual late observation;source fact preserved"})
	await tick(2)
	section="D-held-cancel"
	start=events.size()
	key(KEY_SPACE,true)
	await tick(3)
	check(game.model.share_state=="armed","fresh press arms a valid report")
	key(KEY_LEFT,true)
	await tick(18)
	check(game.model.share_state=="idle" and game.model.message_revision==0 and game.model.listeners.all(func(b): return b.state=="waiting"),"direction cancels before commit and listeners wait")
	check(game.model.suppress_space and not game.model.charging and game.model.bursts==0,"space held while leaving cannot turn into flight charge")
	key(KEY_SPACE,false)
	await tick()
	check(game.model.bursts==0 and count("dance_commit",start)==0,"releasing old held space launches neither dash nor share")
	release_keys()
	await shot("19-held-cancel")
	game.model.p=Model.COMB
	game.model.velocity=Vector2.ZERO
	seeds.append({"section":section,"frame":frames.size(),"note":"Return to comb for fresh-input path"})
	await tick(2)
	section="D-dancing-cancel"
	key(KEY_SPACE,true)
	await tick()
	key(KEY_SPACE,false)
	await tick(12)
	check(game.model.share_state=="dancing" and game.model.message_revision==0,"fresh release starts uncommitted dance")
	key(KEY_RIGHT,true)
	await tick(4)
	release_keys()
	check(game.model.share_state=="idle" and game.model.message_revision==0 and count("dance_commit",start)==0,"direction during uncommitted dance cancels without report")
	await shot("20-dance-cancel")
	game.model.p=Model.COMB
	game.model.velocity=Vector2.ZERO
	await tick(2)
	key(KEY_SPACE,true)
	await tick()
	key(KEY_SPACE,false)
	check(await until(func(): return game.model.message_revision==1,60),"fresh input can complete real report after cancellation")
	check(count("dance_commit",start)==1,"successful report committed once")
	await tick(50)
	for i in 2:
		key(KEY_SPACE,true)
		await tick(3)
		key(KEY_SPACE,false)
		await tick(3)
	check(count("dance_commit",start)==1 and game.model.share_state=="idle","repeat input cannot duplicate committed report")
	await shot("21-shared-once")
	await cold_resume("committed report")
	check(count("dance_commit",start)==1,"cold restore does not recommit")
	section="D-invalidated-source"
	game.model.invalidate_source()
	seeds.append({"section":section,"frame":frames.size(),"note":"Explicit supported content invalidation event;not an automatic timing rule"})
	await tick(10)
	check(not game.model.observation_valid() and not game.model.can_share() and game.model.listeners.all(func(b): return b.state in ["returning","waiting"]),"closed source invalidates sharing and returns listeners")
	await cold_resume("invalidated source")
	check(not game.model.source_open and game.model.source_revision==2,"invalidated source remains closed after cold restore")
	await shot("22-source-invalidated")
func run():
	if folder.is_empty():
		print("Set SWARM_POND_STATES_DIR to an isolated evidence directory")
		quit(1)
		return
	native=DisplayServer.get_name()!="headless"
	DirAccess.make_dir_recursive_absolute(folder)
	await new_scene()
	var only=OS.get_environment("SWARM_POND_STATES_ONLY")
	if only in ["","A"]: await movement_edges()
	if only in ["","B"]: await mosquito_cycle()
	if only in ["","C"]: await shield_cycle()
	if only in ["","D"]: await observation_and_share()
	release_keys()
	check(frames.all(func(f): return f.cue_clear),"context cue clears actual bee and shield on every sampled frame")
	check(frames.all(func(f): return f.cue_caption_clear),"context cue clears actual feedback captions on every sampled frame")
	var file=FileAccess.open(folder.path_join("trace.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"kind":"bounded source audit with controlled initial states and actual production keyboard/physics;not continuous exploration","only":only,"native":native,"checks":assertions.size(),"failures":failures,"seeds":seeds,"assertions":assertions,"events":events,"frames":frames},"\t"))
	file.close()
	game.queue_free()
	await process_frame
	print("POND SOURCE STATES VERIFIED: %d checks, %d failures" % [assertions.size(),failures])
	quit(1 if failures else 0)
