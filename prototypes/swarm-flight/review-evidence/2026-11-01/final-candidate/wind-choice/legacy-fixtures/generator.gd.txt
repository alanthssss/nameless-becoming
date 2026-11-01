extends SceneTree
## Controlled stage2 component entry with ordinary InputEvents; not a full journey.
## Used before/after the visible first-flower relocation. No cold resume in this probe.
const Main=preload("res://spring_journey_main.gd")
const Model=preload("res://spring_journey_model.gd")
var game
var folder=OS.get_environment("SWARM_WIND_PROBE_DIR")
var generate=OS.get_environment("SWARM_WIND_GENERATE_OLD")=="1"
var ticks=0
var samples=[]
var checks=0
var failures=0
var captured={}
func _initialize(): call_deferred("run")
func key(code: Key,down: bool):
	var e=InputEventKey.new()
	e.physical_keycode=code;e.keycode=code;e.pressed=down
	root.push_input(e)
func tap(code: Key):key(code,true);key(code,false)
func check(ok: bool,label: String):
	checks+=1
	if not ok:failures+=1;print("FAIL: "+label)
func save_state(name: String):
	if not generate or captured.has(name):return
	captured[name]=true
	var raw=JSON.stringify(game.model.save_payload(),"\t",true,true)
	var clone=Model.new()
	check(clone.restore_payload(JSON.parse_string(raw)),"genuine old model accepts "+name)
	var f=FileAccess.open(folder.path_join(name+".json"),FileAccess.WRITE);f.store_string(raw);f.close()
func step(n: int):
	for i in n:
		game.tick(1.0/60);game.world._process(1.0/60);ticks+=1
		var m=game.model
		if m.front_open:save_state("old-front-open-live-burst")
		if m.rings_hit>=1:save_state("old-first-wind-active")
		if m.passage_open:save_state("old-both-open")
		if ticks%2==0:samples.append({"tick":ticks,"p":[m.p.x,m.p.y],"front":m.front_open,"passage":m.passage_open,"rings":m.rings_hit,"burst":m.burst_left,"recoveries":m.recoveries,"stamina":m.stamina})
func fly(p: Vector2):
	for i in 1600:
		var d=p-game.model.p
		if d.length()<10:break
		key(KEY_LEFT,d.x< -6);key(KEY_RIGHT,d.x>6);key(KEY_UP,d.y< -6);key(KEY_DOWN,d.y>6)
		step(1)
	for k in [KEY_LEFT,KEY_RIGHT,KEY_UP,KEY_DOWN]:key(k,false)
	step(6)
	check(game.model.p.distance_to(p)<16,"ordinary waypoint "+str(p))
func run():
	DirAccess.make_dir_recursive_absolute(folder)
	game=Main.new();game.progress_file=folder.path_join("runtime-save.json")
	root.add_child(game);await process_frame
	game.set_process(false);game.world.set_process(false);game.sound.set_muted(true)
	tap(KEY_ENTER)
	check(game.model.stage==2,"actual menu uses declared stage2 component entry")
	save_state("old-stage2-unopened")
	for p in [Vector2(620,620),Vector2(1000,620),Vector2(1260,500),Vector2(1850,590),Vector2(2190,465)]:fly(p)
	for i in 900:
		if game.model.keeper.state=="counting" and game.model.keeper.elapsed<1.2:break
		step(1)
	save_state("old-before-first-charge")
	key(KEY_RIGHT,true);key(KEY_SPACE,true);step(30);key(KEY_SPACE,false)
	# Keep the exact same RIGHT direction; no second press/turn, retry or cold restore.
	step(180);key(KEY_RIGHT,false);step(6)
	check(game.model.front_open,"first ordinary stroke opens first knot")
	check(not game.model.passage_open and game.model.rings_hit==0,"one unchanged RIGHT stroke must not automatically take wind and open second knot")
	if generate:
		for i in 900:
			if game.model.keeper.state=="settled":break
			step(1)
		save_state("old-settled-after-double-open")
		for stage in [0,1]:
			var m=Model.new();m.load_stage(stage)
			var f=FileAccess.open(folder.path_join("old-stage%d.json"%stage),FileAccess.WRITE);f.store_string(JSON.stringify(m.save_payload(),"\t",true,true));f.close()
	var f=FileAccess.open(folder.path_join("probe.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify({"kind":"controlled actual-menu stage2 ordinary-input component, no position/gate seed, no cold resume","checks":checks,"failures":failures,"ticks":ticks,"samples":samples,"end":{"front":game.model.front_open,"passage":game.model.passage_open,"rings":game.model.rings_hit,"p":[game.model.p.x,game.model.p.y]}},"\t"));f.close()
	print("WIND SINGLE STROKE: %d checks, %d failures; front%s back%s rings%d"%[checks,failures,game.model.front_open,game.model.passage_open,game.model.rings_hit])
	game.queue_free();await process_frame;quit(1 if failures else 0)
