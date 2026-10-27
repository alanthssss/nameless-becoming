extends SceneTree
const Model = preload("res://sign_keeper_model.gd")
const Long = preload("res://long_journey_model.gd")
const Weather = preload("res://weather_window_model.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+label)
func fresh() -> Model:
	var m := Model.new()
	m.load_stage(0)
	return m
func frames(m,count: int,d := Vector2.ZERO,held := false) -> void:
	for i in count: m.step(d,held,1.0/60)
func fly(m,target: Vector2,held := false) -> void:
	for i in 1500:
		var delta: Vector2 = target-m.p
		if delta.length() < 10: break
		var d := Vector2(signf(delta.x) if absf(delta.x)>6 else 0.0,signf(delta.y) if absf(delta.y)>6 else 0.0).normalized()
		m.step(d,held,1.0/60)
	frames(m,24,Vector2.ZERO,held)
func roundtrip(m,label: String) -> void:
	var payload: Dictionary = m.save_payload()
	var other := fresh()
	check(other.restore_payload(JSON.parse_string(JSON.stringify(payload,"",true,true))),"accept snapshot "+label)
	check(other.save_payload()==payload,"exact snapshot "+label)
	var clone := fresh()
	clone.restore_payload(payload)
	clone.step(Vector2.RIGHT,false,1.0/60)
	other.step(Vector2.RIGHT,false,1.0/60)
	check(other.save_payload()==clone.save_payload(),"same next input "+label)
func approach(m,upper := false) -> void:
	fly(m,Vector2(620,200 if upper else 620))
	fly(m,Vector2(1000,200 if upper else 620))
	fly(m,Vector2(1260,500))
	fly(m,Vector2(1850,590))
	fly(m,Vector2(2190,465))
func open_gate(m) -> void:
	for i in 900:
		if m.keeper.state=="counting" and m.keeper.elapsed<1.2: break
		m.step(Vector2.ZERO,false,1.0/60)
	check(m.keeper.state=="counting","can observe a finite counting window")
	frames(m,30,Vector2.RIGHT,true)
	frames(m,1,Vector2.RIGHT,false)
	for i in 90:
		if m.passage_open: break
		m.step(Vector2.RIGHT,false,1.0/60)
	check(m.passage_open,"ordinary dash opens loose knot")
func run() -> void:
	var seen := {}
	for upper in [false,true]:
		var m := fresh()
		approach(m,upper)
		check(m.checkpoint_index==0,"ordinary bypass reaches safe leaf")
		check(m.recoveries==0,"no forced failure before keeper")
		for i in 800:
			if not seen.has(m.keeper.state):
				seen[m.keeper.state]=true
				roundtrip(m,"keeper "+m.keeper.state)
			m.step(Vector2.ZERO,false,1.0/60)
			if seen.has("aim") and seen.has("chase") and seen.has("counting") and seen.has("return"): break
		open_gate(m)
		roundtrip(m,"gate just opened")
		check(m.checkpoint.walls[3].broken and m.checkpoint_keeper.passage_open,"opening commits geometry and fact before next leaf")
		frames(m,20)
		roundtrip(m,"tidying")
		m.restore_checkpoint()
		check(m.passage_open and m.keeper.state=="settled" and m.result_elapsed==Model.RESULT_SECONDS and m.p.x>2392,"retry keeps passage and skips earned actor animation")
		# Real return through the new gap, then forward again.
		fly(m,Vector2(2260,465))
		check(m.p.x<2350,"opened passage is genuinely traversable backwards")
		fly(m,Vector2(2530,465))
		check(m.p.x>2392,"opened passage is genuinely traversable forwards")
		fly(m,Vector2(2910,500))
		fly(m,m.exit_pos+Vector2(45,0))
		check(m.phase=="ending","complete ordinary route "+str(upper))
		roundtrip(m,"ending")
		print("KEEPER_ROUTE: "+JSON.stringify({"upper":upper,"time":m.time,"recoveries":m.recoveries,"stamina":m.stamina,"opened":m.passage_open}))
	# Explicit rule fixtures isolate material/window/contact combinations.
	for counting in [false,true]:
		for dashing in [false,true]:
			var m := fresh()
			m.p=Vector2(2300,465)
			m.keeper.state="counting" if counting else "idle"
			m.keeper.pos=Vector2(1980,250)
			m.keeper.elapsed=0
			m.face=Vector2.RIGHT
			if dashing: m.burst_left=0.4
			frames(m,18,Vector2.RIGHT)
			check(m.passage_open==(counting and dashing),"only dash and loose rope opens "+str(counting)+"/"+str(dashing))
	var ordinary := fresh()
	ordinary.started=true
	ordinary.p=Vector2(700,440)
	frames(ordinary,55)
	check(ordinary.small.state=="chase","ordinary mosquito aims before chasing")
	ordinary.p=Vector2(1200,640)
	frames(ordinary,300)
	check(ordinary.small.pos.distance_to(Model.SMALL_HOME)<1 and ordinary.small.state in ["idle","rest"],"ordinary chase returns home instead of pursuing across map")
	var cover := fresh()
	cover.started=true
	cover.p=Vector2(1000,440)
	frames(cover,300)
	check(cover.small.state=="idle" and cover.small.pos==Model.SMALL_HOME,"solid hedge blocks initial sight")
	check(not cover.sight_clear(Vector2(820,440),Vector2(990,440)),"physical hedge blocks actor sight segment")
	var tidy := fresh()
	tidy.passage_open=true
	tidy.walls[3].broken=true
	tidy.keeper.state="tidy"
	tidy.keeper.pos=Vector2(1820,600)
	tidy.keeper.target=Vector2(2240,465)
	var intersects := false
	for i in 600:
		tidy.step(Vector2.ZERO,false,1.0/60)
		for wall in tidy.walls:
			if not wall.broken and wall.rect.has_point(tidy.keeper.pos): intersects=true
	check(not intersects and tidy.keeper.pos==Model.RESULT_HOME and tidy.keeper.state=="settled","tidy route crosses through actual opening before settling")
	var bad := fresh()
	var before := bad.save_payload()
	var payload := before.duplicate(true)
	payload.keeper.passage_open=true
	check(not bad.restore_payload(payload) and bad.save_payload()==before,"contradictory passage rejected without mutation")
	for other in [Long.new(),Weather.new()]:
		other.load_stage(0)
		check(not other.restore_payload(before) and not bad.restore_payload(other.save_payload()),"independent old-save namespaces")
	print("SIGN KEEPER VERIFIED: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
