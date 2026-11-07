extends SceneTree
## Authored route and preservation checks; developer fixtures, not player experience.
const Model = preload("res://nectar_harvest_model.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+message)
func field(area := "pond"):
	var m = Model.new()
	m.owned.assign(["gather1","bag1","wings1","meadow"])
	m.energy = m.max_energy()
	m.transition_to(area)
	return m
func fly(m,at: Vector2) -> void:
	for i in 600:
		if m.p.distance_to(at)<8: break
		m.step(1.0/60.0,(at-m.p).normalized(),false,false)
	check(m.p.distance_to(at)<8 and not m.at_home(),"ordinary flight reaches "+str(at))
	m.v = Vector2.ZERO
func run() -> void:
	var m = field()
	m.p = Vector2(740,405)
	for i in 120: m.step(1.0/60.0,Vector2.RIGHT,false,false)
	check(m.p.x<790,"dense pond bush blocks direct flight")
	m.p = Vector2(760,405)
	m.face = Vector2.RIGHT
	m.burst_left = 0.32
	for i in 4: m.step(0.1,Vector2.RIGHT,false,false)
	check(m.p.x<790,"largest-step charged dash cannot tunnel through bush")
	# Two independently authored circuits around the same obstacle converge at the bay.
	for upper in [false,true]:
		m = field()
		for point in ([Vector2(710,235),Vector2(1230,235),Vector2(1400,480)] if upper else [Vector2(730,585),Vector2(1230,585),Vector2(1400,480)]): fly(m,point)
		for point in [Vector2(1230,585),Vector2(730,585),Vector2(470,575)]: fly(m,point)
		check(m.energy>20.0,"both circuits preserve beginner return energy")
		check(m.transition_to("hub"),"both circuits reconnect to the real home exit")
	m = field()
	m.p = Vector2(970,285)
	var flower: Dictionary = m.flowers[0]
	flower.pos = Vector2(970,345)
	for i in 130: m.step(1.0/60.0,Vector2.ZERO,true,false)
	check(m.cargo_total()==0,"cannot collect through dense shrub silhouette")
	var c: Dictionary = m.creatures[0]
	c.pos = Vector2(970,360)
	m.face = Vector2.DOWN
	check(not m.pulse() and c.hits==0,"wing action cannot hit through shrub")
	# Fixed identity stock/progress survives the layout update. A historical embedded
	# position is safely moved; purchasing, cargo and dropped amounts are preserved.
	m = field()
	m.p = Vector2(980,405)
	m.coins = 17
	m.cargo.blue = 3
	m.materials.fiber = 5
	m.flowers[0].progress = 0.4
	var original: Dictionary = m.to_payload()
	var cold = Model.new()
	check(cold.restore_payload(original),"valid v5 save loads after new geometry")
	check(cold.p.distance_to(Vector2(980,405))>100 and cold.v==Vector2.ZERO,"embedded historical position moves to a free edge")
	check(cold.coins==17 and cold.cargo.blue==3 and cold.materials.fiber==5 and cold.owned==m.owned and is_equal_approx(cold.flowers[0].progress,.4),"layout update preserves currency, cargo, upgrades and partial flower progress")
	var again = Model.new()
	check(again.restore_payload(cold.to_payload()) and again.to_payload()==cold.to_payload(),"safe-position correction is idempotent on cold restore")
	# Rain traversal compares ordinary movement at two visible heights.
	var costs: Array[float] = []
	for height in [320.0,645.0]:
		m = field("meadow")
		m.p = Vector2(2590,height)
		var start: float = m.energy
		fly(m,Vector2(2930,height))
		costs.append(start-m.energy)
	check(costs[0]>costs[1]*1.8,"visible low shelter route reduces actual rain exposure")
	# Each clear pond dash lane permits early, centred and late starts, followed
	# by continued forward travel and a turn; no exact-braking assumption.
	for start_x in [760.0,820.0,880.0]:
		m = field()
		m.p = Vector2(start_x,590)
		m.face = Vector2.RIGHT
		m.burst_left = .32
		for frame in 40: m.step(1.0/60.0,Vector2.RIGHT,false,false)
		for frame in 6: m.step(1.0/60.0,Vector2.UP,false,false)
		check(m.p.x>start_x+200 and not Model.Map.blocked("pond",m.p),"clear dash exit tolerates early/normal/late start and continued steering")
	for trip in range(1,25):
		for f in Model.flower_layout(trip):
			check(not Model.Map.blocked("pond" if f.region==0 else "meadow",f.pos,35),"authored flower jitter stays in open flight space "+f.id)
	m = field()
	var still := 0
	var moving := 0
	for i in 500:
		var before: Vector2 = m.creatures[0].pos
		m.step(1.0/60.0,Vector2.ZERO,false,false)
		if before.distance_to(m.creatures[0].pos)<.05: still += 1
		else: moving += 1
	check(still>50 and moving>100,"material carrier alternates readable resting and movement")
	check(Model.new().restore_payload(m.to_payload()),"patrol phase and pauses remain persistable")
	print("NECTAR MAP: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
