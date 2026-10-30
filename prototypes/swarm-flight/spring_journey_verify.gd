extends SceneTree
const Model=preload("res://spring_journey_model.gd")
const Old=preload("res://long_journey_model.gd")
var checks=0
var failures=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		print("FAIL: "+label)
func fresh(index:=0):
	var m=Model.new()
	m.load_stage(index)
	return m
func frames(m,n: int,d:=Vector2.ZERO,held:=false) -> void:
	for i in n: m.step(d,held,1.0/60)
func fly(m,target: Vector2,held:=false) -> void:
	for i in 1500:
		var delta: Vector2=target-m.p
		if delta.length()<9: break
		var d:=Vector2(signf(delta.x) if absf(delta.x)>5 else 0.0,signf(delta.y) if absf(delta.y)>5 else 0.0).normalized()
		m.step(d,held,1.0/60)
		if m.phase!="playing": break
	frames(m,24,Vector2.ZERO,held)
	check(m.p.distance_to(target)<34 or m.phase!="playing","ordinary flight reaches "+str(target)+" actual "+str(m.p))
func roundtrip(m,label: String) -> void:
	var data: Dictionary=m.save_payload()
	var other=fresh()
	check(other.restore_payload(JSON.parse_string(JSON.stringify(data,"",true,true))),"JSON accepts "+label)
	check(other.save_payload()==data,"exact state "+label)
	var clone=fresh()
	clone.restore_payload(data)
	clone.step(Vector2.RIGHT,false,1.0/60)
	other.step(Vector2.RIGHT,false,1.0/60)
	check(other.save_payload()==clone.save_payload(),"next input "+label)
func chapter03(m,observe: bool,upper: bool) -> void:
	fly(m,Vector2(400,230 if upper else 610))
	fly(m,Vector2(1080,230 if upper else 610))
	if upper: fly(m,Vector2(1270,500))
	fly(m,Vector2(1060,500))
	fly(m,Vector2(1270,500))
	fly(m,Vector2(1450,630 if not upper else 190))
	fly(m,Vector2(1820,630 if not upper else 190))
	fly(m,Vector2(2050,190))
	fly(m,Vector2(2280,190))
	fly(m,Vector2(2280,530))
	fly(m,Vector2(2520,500))
	if observe:
		fly(m,Vector2(2770,500))
		fly(m,Model.SOURCE)
		frames(m,60)
		check(m.observation_valid(),"03 feeding observes real flower")
		roundtrip(m,"03 source observed")
		m.restore_checkpoint()
		check(m.observation_valid(),"observed flower committed on retry")
	fly(m,Vector2(3470,600))
	fly(m,Vector2(3710,600))
	fly(m,Vector2(3970,600))
	fly(m,Vector2(4170,500))
	fly(m,Vector2(4410 if m.stage!=1 else 4360,500))
	fly(m,m.exit_pos+Vector2(45,0))
	check(m.phase=="transition" and m.stage==0,"03 ends at real exit")
	roundtrip(m,"03 transition")
func chapter04(m,upper: bool) -> void:
	m.load_stage(1)
	var fact: Dictionary=m.observation.duplicate(true)
	fly(m,Vector2(620,520))
	fly(m,Vector2(1250,520))
	roundtrip(m,"04 rain below solid canopy")
	fly(m,Vector2(1350,400))
	fly(m,Vector2(1540,400))
	fly(m,Vector2(1760,520))
	fly(m,Vector2(2170,520))
	if upper:
		fly(m,Vector2(2370,520))
		fly(m,Vector2(2370,450))
		check(m.shield_left>0,"04 optional shield obtained by contact")
		fly(m,Vector2(3560,420))
	else:
		fly(m,Vector2(2310,630))
		fly(m,Vector2(3180,630))
		fly(m,Vector2(3200,420))
		fly(m,Vector2(3560,420))
	fly(m,Vector2(3670,520))
	fly(m,Vector2(4120,500))
	fly(m,Vector2(4410 if m.stage!=1 else 4360,500))
	fly(m,m.exit_pos+Vector2(45,0))
	check(m.phase=="transition" and m.observation==fact,"04 route keeps observed flower identity")
	roundtrip(m,"04 transition")
func open_front(m) -> void:
	fly(m,Vector2(620,620))
	fly(m,Vector2(1000,620))
	fly(m,Vector2(1260,500))
	fly(m,Vector2(1850,590))
	fly(m,Vector2(2190,465))
	for i in 900:
		if m.keeper.state=="counting" and m.keeper.elapsed<1.2: break
		frames(m,1)
	check(m.keeper.state=="counting","ordinary approach exposes counting window")
	roundtrip(m,"counting")
	frames(m,30,Vector2.RIGHT,true)
	frames(m,1,Vector2.RIGHT,false)
	for i in 90:
		frames(m,1,Vector2.RIGHT)
		if m.front_open: break
	check(m.front_open and not m.passage_open,"first rope opens but back remains")
	roundtrip(m,"first passage")
	m.restore_checkpoint()
	check(m.front_open and not m.passage_open and m.keeper.state=="watch","retry retains only earned first passage")
func open_back(m,wind: bool) -> void:
	if wind:
		fly(m,Vector2(2485,465))
		frames(m,30,Vector2.RIGHT,true)
		frames(m,1,Vector2.RIGHT,false)
		for i in 180:
			frames(m,1,Vector2.RIGHT)
			if m.passage_open: break
		check(m.rings_hit>=2,"wind changes height before back knot")
	else:
		fly(m,Vector2(2740,465))
		fly(m,Vector2(2740,300))
		fly(m,Vector2(2910,300))
		frames(m,30,Vector2.RIGHT,true)
		frames(m,1,Vector2.RIGHT,false)
		for i in 90:
			frames(m,1,Vector2.RIGHT)
			if m.passage_open: break
	check(m.passage_open,"ordinary inputs open back passage")
	if not wind: check(m.rings_hit==0,"ordinary back route needs no wind flower")
	roundtrip(m,"second passage tidy")
	m.restore_checkpoint()
	check(m.passage_open and m.keeper.state=="settled","retry keeps both gates and completed tidying")
	fly(m,Vector2(2910,300))
	fly(m,Vector2(3100,300))
func chapter05(m,share: bool,wind: bool) -> void:
	m.load_stage(2)
	if not share: m.stamina=40.0
	check(m.observation_valid()==share,"03 observation crosses both chapter loads")
	open_front(m)
	open_back(m,wind)
	# The full painted canopy is solid: descend beyond its right tip.
	fly(m,Vector2(3460,300))
	fly(m,Vector2(3460,620))
	fly(m,Vector2(3260,620))
	fly(m,Model.COMB)
	frames(m,60)
	check(m.perched,"05 wax is real landing")
	if share:
		frames(m,1,Vector2.ZERO,true)
		check(m.share_state=="armed","fresh key arms sharing")
		roundtrip(m,"armed")
		frames(m,1)
		frames(m,35)
		m.cancel_dance()
		check(m.message_revision==0,"cancel before full segment does not report")
		frames(m,1,Vector2.ZERO,true)
		frames(m,1)
		frames(m,80)
		check(m.message_revision==1,"03 flower reported at05")
		roundtrip(m,"listeners depart")
		frames(m,360)
		check(m.listeners.all(func(bee): return bee.state=="foraging" and bee.pos.distance_to(Model.SOURCE)<90),"both listeners reach original source coordinate")
		var count: int=m.garden_total()
		frames(m,1,Vector2.ZERO,true)
		frames(m,180)
		check(m.message_revision==1 and m.garden_total()==count,"repeat produces no award")
	else:
		frames(m,30,Vector2.ZERO,true)
		frames(m,180)
		check(m.message_revision==0 and m.listeners.all(func(bee): return bee.state=="waiting"),"unseen flower never fabricates a report")
	fly(m,Vector2(3970,600))
	fly(m,Vector2(4170,500))
	fly(m,Vector2(4410 if m.stage!=1 else 4360,500))
	fly(m,m.exit_pos+Vector2(45,0))
	check(m.phase=="ending","05 complete ending with optional share "+str(share))
	roundtrip(m,"journey ending")
func run() -> void:
	for share in [true,false]:
		var m=fresh()
		if not share: m.stamina=40.0
		chapter03(m,share,share)
		chapter04(m,not share)
		chapter05(m,share,share)
		check(m.recoveries==(3 if share else 2),"no forced recovery beyond deliberateR checks; low40 start on alternate")
		print("SPRING_ROUTE: "+JSON.stringify({"shared":share,"recoveries":m.recoveries,"rings":m.rings_hit,"completed":m.completed}))
	# Regression of Alan's constant-height sheltered bypass: ordinary steering
	# must meet the new rooted stem, while authored routes above remain viable.
	var flat=fresh(1)
	flat.p=Vector2(1100,520)
	frames(flat,220,Vector2.RIGHT)
	check(flat.p.x<1410,"04 holding right under first canopy cannot skip raised opening")
	for from_above in [true,false]:
		var roof=fresh()
		var leaf: Dictionary=roof.shelters[-1]
		roof.p=leaf.pos+Vector2(0,-205 if from_above else -55)
		frames(roof,80,Vector2.DOWN if from_above else Vector2.UP)
		check(roof.p.y<leaf.pos.y-145 if from_above else roof.p.y>leaf.pos.y-115,"leaf blocks crossing from "+str(from_above))
		fly(roof,leaf.pos+Vector2(-240,-200 if from_above else -40))
		fly(roof,leaf.pos+Vector2(-240,0))
		fly(roof,leaf.pos)
		check(roof.shelter_index_at(roof.p)==roof.shelters.size()-1,"leaf remains reachable through open side")
	var bird=fresh()
	bird.p=Model.SOURCE
	bird.stamina=60
	frames(bird,60)
	check(bird.bird_greeted and bird.observation_valid() and bird.stamina>70,"stationary source gives bird response, fact and real restoration")
	roundtrip(bird,"bird response")
	var bud=fresh()
	bud.p=Model.SMALL_HOME+Vector2(-14,62)
	bud.stamina=60
	frames(bud,60)
	check(not bud.observation_valid() and bud.stamina<=60,"closed flower is not a second nectar source")
	var m=fresh()
	var old=Old.new()
	old.load_stage(0)
	check(not m.restore_payload(old.save_payload()) and not old.restore_payload(m.save_payload()),"07–09 saves remain separate")
	var before: Dictionary=m.save_payload()
	var bad: Dictionary=before.duplicate(true)
	bad.story.site_id="other-pond"
	check(not m.restore_payload(bad) and m.save_payload()==before,"invalid site rejected atomically")
	m.load_stage(1)
	m.started=true
	m.p=Vector2(1500,520)
	frames(m,160)
	m.save_checkpoint(m.p)
	m.restore_checkpoint()
	check(m.weather_phase=="warning" and m.warning_elapsed==0,"rain retry gives new forecast")
	roundtrip(m,"weather retry")
	print("SPRING JOURNEY VERIFIED: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
