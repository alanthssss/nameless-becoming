extends SceneTree
## Deterministic rule fixtures and ordinary stepped routes, never player evidence.
const Model = preload("res://nectar_harvest_model.gd")
const V3 = preload("res://nectar_legacy_model_v3.gd")
const V4 = preload("res://nectar_legacy_model_v4.gd")
const MATERIAL_COSTS := {"gather2":{"fiber":2},"reach":{"fiber":3},"twin":{"resin":3},"wings1":{"fiber":2},"bag2":{"fiber":3},"wings2":{"fiber":4,"resin":2},"beat":{"fiber":2}}
var step_dt := 1.0/60.0
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+label)
func tick(m, seconds: float, collect := false) -> void:
	for i in roundi(seconds/step_dt): m.step(step_dt,Vector2.ZERO,collect,false)
func clone_ok(m,label: String) -> void:
	var clone = Model.new()
	check(clone.restore_payload(JSON.parse_string(JSON.stringify(m.to_payload(),"",true,true))),label)
func fly(m,target: Vector2) -> bool:
	var area: String = m.area
	for frame in 1800:
		if m.area != area: return false
		var d: Vector2 = target-m.p
		if d.length() < 12:
			tick(m,.1)
			return true
		m.step(step_dt,Vector2(float(d.x>5)-float(d.x< -5),float(d.y>5)-float(d.y< -5)).limit_length(),false,false)
	return false

func run() -> void:
	var m = Model.new()
	check(m.energy == 36 and m.harvest_rate() == 1.0/1.8,"new trip has 36 energy and 1.8 second nectar")
	check(m.transition_to("pond"),"ordinary departure")
	m.p = m.flowers[0].pos # Explicit isolated interaction fixture.
	tick(m,.9,true)
	check(m.cargo_total() == 0 and absf(m.flowers[0].progress-.5)<.001,"half effort gives half progress, no premature item")
	clone_ok(m,"partial collection survives transaction serialization")
	var progress: float = m.flowers[0].progress
	tick(m,.3)
	check(m.flowers[0].progress == progress,"release preserves earned progress")
	tick(m,.92,true)
	check(m.cargo_total() == 1 and m.flowers[0].stock == 0 and m.flowers[0].regrow > 17.9,"one complete action grants exactly one nectar and starts regrowth")
	clone_ok(m,"empty flower timer saves")
	var before: float = m.flowers[0].regrow
	var cold = Model.new()
	check(cold.restore_payload(m.to_payload()) and cold.flowers[0].regrow == before,"cold restore cannot refill flower")
	m.energy = 36 # Timer-only fixture excludes energy failure.
	tick(m,17.8)
	check(m.flowers[0].stock == 0,"flower cannot regenerate early")
	tick(m,.25)
	check(m.flowers[0].stock == 1 and m.flowers[0].bloom < .5,"flower regrows through visible bud phase")
	clone_ok(m,"regrowing state saves")
	var other = Model.new(); other.trip_index = 1; other.transition_to("pond")
	check(other.flowers[0].pos != m.flowers[0].pos,"different expeditions generate different bounded flower positions")
	check(Model.flower_layout(2) == Model.flower_layout(2),"generation is reproducible")
	var bug = Model.new(); bug.transition_to("pond")
	bug.p = bug.creatures[0].pos-Vector2(70,0)
	var energy: float = bug.energy
	check(bug.pulse() and bug.energy == energy-2 and bug.creatures[0].hits == 1,"first pulse spends energy and makes partial material progress")
	check(not bug.pulse() and bug.creatures[0].hits == 1,"same-frame pulses cannot duplicate impact")
	clone_ok(bug,"partial mosquito interaction saves")
	tick(bug,.56)
	check(bug.pulse() and bug.creatures[0].state == "gone" and bug.drops.size() == 1 and bug.materials.fiber == 0,"second hit sheds an uncollected physical drop")
	clone_ok(bug,"uncollected drop saves")
	bug.p = bug.drops[0].pos
	tick(bug,.32)
	check(bug.materials.fiber == 2 and bug.drops.is_empty(),"approach collects exactly two fibers")
	tick(bug,.7)
	bug.pulse()
	check(bug.materials.fiber == 2,"gone mosquito cannot duplicate material")
	clone_ok(bug,"collected materials cold restore")
	bug.p = Model.POND_ENTRY; bug.transition_to("hub"); bug.coins = 30
	check(bug.buy("gather1") and bug.buy("wings1") and bug.materials.fiber == 0 and bug.energy == 50,"growth spends material once and raises actual endurance")
	check(not bug.buy("wings1") and bug.materials.fiber == 0,"repeat growth never spends again")
	var old = V4.new(); old.transition_to("pond"); old.energy = 42.5; old.cargo.blue = 3
	var next = Model.new()
	check(next.restore_legacy_payload(old.to_payload(),4),"frozen v4 validates before migration")
	check(next.energy == 18 and next.cargo.blue == 3 and next.materials.fiber == 0,"migration preserves energy ratio and cargo without granting materials")
	var invalid: Dictionary = next.to_payload(); invalid.materials.fiber = -1
	var stable: Dictionary = next.to_payload()
	check(not next.restore_payload(invalid) and next.to_payload() == stable,"invalid material payload is atomic")
	invalid = stable.duplicate(true); invalid.flowers[0].regrow = 12
	check(not next.restore_payload(invalid),"stocked flower cannot carry refill timer")
	var rescue = Model.new(); rescue.transition_to("pond"); rescue.energy = .01; rescue.cargo.blue = 5; rescue.materials.fiber = 2
	tick(rescue,.1)
	check(rescue.at_home() and rescue.p == Model.HOME and rescue.cargo.blue == 2 and rescue.materials.fiber == 2,"exhaustion returns to lamp, halves unsold nectar, retains secured materials")
	var stronger = Model.new(); stronger.owned.assign(["gather1","beat"]); stronger.transition_to("pond")
	stronger.p = stronger.creatures[0].pos
	check(stronger.pulse() and stronger.creatures[0].state == "gone","strength growth reduces scout collection to one pulse")
	var spent_energy: float = stronger.energy
	stronger.step(0.0,Vector2.ZERO,false,false)
	check(stronger.energy == spent_energy and stronger.pulse_left == .55,"paused frame cannot advance pulse or drops")
	clone_ok(stronger,"strength drop state saves")
	legacy_edge_pulses()
	endurance_curve()
	for branch in ["shortcut","twin","all"]: run_route(branch)
	run_route("all",1.0/30.0)
	print("NECTAR LIVING: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func run_route(branch: String, dt := 1.0/60.0) -> void:
	step_dt = dt
	var m = Model.new()
	var plan: Array = ["gather1","bag1","wings1","meadow","shortcut","reserve"]
	if branch == "twin": plan = ["gather1","gather2","reach","meadow","twin","reserve"]
	if branch == "all": plan = ["gather1","bag1","wings1","beat","gather2","bag2","meadow","reach","shortcut","market","twin","wings2","reserve"]
	var safe := true
	var earned := 0
	var spent := 0
	var minima: Array = []
	var material_spent := {"fiber":0,"resin":0}
	for expedition in 80:
		if plan.is_empty(): break
		# Materials determine which expedition is useful; no resources are granted.
		var need_fiber := 0
		var need_resin := 0
		for id in plan:
			need_fiber += int(m.upgrade(id).get("fiber",0))
			need_resin += int(m.upgrade(id).get("resin",0))
		var destination := "meadow" if "meadow" in m.owned and m.materials.fiber >= need_fiber else "pond"
		safe = fly(m,Model.HUB_DEPART) and m.transition_to(destination) and safe
		var home: Vector2 = Model.POND_ENTRY if destination == "pond" else Model.MEADOW_ENTRY
		var region := 0 if destination == "pond" else 1
		for creature in m.creatures:
			if creature.region != region: continue
			if destination == "pond" and m.materials.fiber >= need_fiber: continue
			if destination == "meadow" and m.materials.resin >= need_resin: continue
			var cost: float = m.p.distance_to(creature.pos)/180+creature.pos.distance_to(home)/180+(3 if creature.kind == "guard" else 2)*2.6+4
			if m.energy < cost: break
			safe = fly(m,creature.pos) and safe
			for hit in 3:
				if creature.state == "gone": break
				m.pulse(); tick(m,.56)
			if not m.drops.is_empty():
				safe = fly(m,m.drops[-1].pos) and safe
				tick(m,.35)
		var picked: Array = []
		for attempt in 20:
			if m.cargo_total() >= m.capacity(): break
			var target: Dictionary = {}
			for flower in m.flowers:
				if flower.region != region or flower.stock == 0 or flower.id in picked: continue
				if target.is_empty() or m.p.distance_to(flower.pos) < m.p.distance_to(target.pos): target = flower
			if target.is_empty(): break
			var required: float = m.p.distance_to(target.pos)/180+target.pos.distance_to(home)/180+1.9/m.harvest_rate()+3.0
			if m.energy <= required: break
			safe = fly(m,target.pos) and safe
			for frame in ceili(2.2/step_dt):
				m.step(step_dt,Vector2.ZERO,true,false)
				if target.stock == 0 or m.cargo_total() == m.capacity(): break
			picked.append(target.id)
		minima.append(m.energy)
		safe = fly(m,home) and m.transition_to("hub") and safe
		clone_ok(m,branch+" ordinary return serializes")
		earned += m.sell()
		while not plan.is_empty() and m.can_buy(plan[0]):
			spent += int(m.upgrade(plan[0]).cost)
			for kind in ["fiber","resin"]: material_spent[kind] += int(MATERIAL_COSTS.get(plan[0],{}).get(kind,0))
			m.buy(plan.pop_front())
		clone_ok(m,branch+" purchases serialize")
		if not safe: break
	check(safe and plan.is_empty() and m.completed,branch+" completes through earned nectar and collected materials")
	check(m.coins == earned-spent,branch+" exact coin conservation")
	var produced := {"fiber":0,"resin":0}
	var collected := {"fiber":0,"resin":0}
	for event in m.events:
		if event.kind == "repel": produced["fiber" if event.id == "mosquito_0" else "resin"] += 2 if event.id == "mosquito_0" else 1
		if event.kind == "material": collected[event.type] += int(event.amount)
	for kind in ["fiber","resin"]:
		var pending := 0
		for drop in m.drops:
			if drop.kind == kind: pending += int(drop.amount)
		check(produced[kind] == collected[kind]+pending,branch+" "+kind+" drop/pickup ledger conserves every item")
		check(m.materials[kind] == collected[kind]-material_spent[kind],branch+" "+kind+" pickup/spend/wallet ledger conserves every item")
	print("MATERIAL LEDGER %s %dFPS produced=%s collected=%s spent=%s wallet=%s" % [branch,roundi(1.0/step_dt),str(produced),str(collected),str(material_spent),str(m.materials)])
	step_dt = 1.0/60.0
	print("LIVING ROUTE: %s trips=%d earned=%d spent=%d remaining=%s material=%s energy_before_return=%s" % [branch,m.trip_index,earned,spent,str(plan),str(m.materials),str(minima)])

func endurance_curve() -> void:
	var ending: Array = []
	for rank in [-1,0,1,2]:
		var m = Model.new()
		# Same six-flower itinerary, isolated equipment fixtures; no enjoyment claim.
		if rank >= 0: m.owned.assign(["gather1"])
		if rank >= 1: m.owned.append("wings1")
		if rank == 2: m.owned.append("wings2")
		m.energy = m.max_energy()
		m.transition_to("pond")
		var used: Array = []
		for i in 6:
			var target: Dictionary = {}
			for flower in m.flowers:
				if flower.region != 0 or flower.id in used: continue
				if target.is_empty() or m.p.distance_to(flower.pos)<m.p.distance_to(target.pos): target=flower
			check(fly(m,target.pos),"same-route flower reachable for wing rank %d" % rank)
			for frame in 120:
				m.step(1.0/60,Vector2.ZERO,true,false)
				if target.stock == 0: break
			used.append(target.id)
		check(fly(m,Model.POND_ENTRY) and not m.at_home(),"six-flower return is possible for wing rank %d" % rank)
		ending.append(m.energy)
	check(ending[0] > 0 and ending[0] < 12,"fresh trip leaves a meaningful but nonzero reserve")
	check(ending[2] > ending[1]+13 and ending[3] > ending[2]+19,"wing growth creates measured headroom on the same itinerary")
	print("ENDURANCE SAME ROUTE (fresh/gather1/wing1/wing2): returned energy="+str(ending))

func legacy_edge_pulses() -> void:
	for version in [3,4]:
		var old = V3.new() if version == 3 else V4.new()
		old.p = old.HUB_DEPART
		old.transition_to("pond")
		old.creatures[0].pos = old.creatures[0].anchor+Vector2(180,0)
		old.p = old.creatures[0].pos-Vector2(70,0)
		if version == 3:
			old.creatures[0].state = "chase"
			old.creatures[0].timer = .4
		var verify_old = V3.new() if version == 3 else V4.new()
		check(verify_old.restore_payload(old.to_payload()),"edge fixture is valid under immutable v%d rules" % version)
		var m = Model.new()
		check(m.restore_legacy_payload(old.to_payload(),version),"legal edge v%d migrates" % version)
		check(m.pulse(),"edge first pulse")
		clone_ok(m,"edge partial mosquito remains saveable")
		tick(m,.56)
		check(m.pulse() and m.creatures[0].state == "gone","edge second pulse releases material")
		clone_ok(m,"edge gone mosquito and drop remain saveable")
		if m.drops.is_empty():
			check(false,"edge sequence has a real drop")
			continue
		m.p = m.drops[0].pos
		tick(m,.32)
		check(m.materials.fiber == 2,"edge drop can actually be collected")
		clone_ok(m,"edge material pickup remains saveable")
		check(fly(m,Model.POND_ENTRY) and m.transition_to("hub"),"edge expedition can still return")
		clone_ok(m,"edge returned state remains saveable")
