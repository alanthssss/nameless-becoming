extends SceneTree
const Model = preload("res://region_greybox/model.gd")
const Layout = preload("res://region_greybox/layout.gd")
const Probe = preload("res://region_greybox/route_probe.gd")
const DT := 1.0/60.0
var checks := 0
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func fresh(region := "pond", state := "sunny", growth := 0) -> RefCounted:
	var m := Model.new()
	m.configure(region,state,growth)
	return m

func _init() -> void:
	configuration()
	return_and_stop()
	collection()
	pulse_and_dash()
	rain_choices()
	for region in ["pond","violet"]:
		for state in ["sunny","rain","variant"]:
			for growth in [0,1]: frozen_state(region,state,growth)
	check(checks > 1000,"model corpus actually executed")
	print("GREYBOX_MODEL checks=%d failures=%d" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)

func configuration() -> void:
	var low := fresh()
	var high := fresh("violet","variant",1)
	check(low.max_energy() == 36.0 and low.capacity() == 6,"initial existing stats")
	check(high.max_energy() == 70.0 and high.capacity() == 16,"grown existing stats")
	check(is_equal_approx(low.stats.harvest_rate(),1.0/1.8),"initial harvesting cadence")
	check(is_equal_approx(high.stats.harvest_rate(),1.25),"grown harvesting cadence")
	check(low.stats.owned.is_empty(),"growth profile not shared")
	check(low.region == "pond" and low.condition == "sunny", "config instances independent")
	Probe.drive_edge(high,0,1)
	high.configure("pond","rain",0)
	check(high.elapsed == 0 and high.distance == 0 and high.rain_seconds == 0,"fresh run clears measurements")
	check(high.energy == 36 and high.cargo == 0 and high.material_count == 0,"fresh run clears run inventory")
	check(high.visits == [0] and high.trace.is_empty(),"fresh run clears route history")
	check(not high.departed and high.phase == "active" and high.v == Vector2.ZERO,"fresh run resets movement/phase")
	check(high.stats.owned.is_empty(),"switching to early growth clears grown ownership")
	var original: Vector2 = low.p
	var original_energy: float = low.energy
	low.step(NAN,Vector2.RIGHT,false)
	low.step(-1,Vector2.RIGHT,false)
	low.step(DT,Vector2(INF,0),false)
	check(low.p == original and low.energy == original_energy and low.elapsed == 0,"invalid input is rejected")

func return_and_stop() -> void:
	var m := fresh()
	m.step(DT,Vector2.ZERO,true)
	check(m.phase == "active","E at untouched entrance does not finish an empty run")
	check(Probe.drive_edge(m,0,1),"leave entry through actual movement")
	check(m.departed,"departure recorded after leaving entry")
	check(Probe.drive_edge(m,1,0),"ordinary input returns to entry")
	m.step(DT,Vector2.ZERO,true)
	check(m.phase == "returned" and m.energy > 0,"E completes return only after departure")
	var snapshot: Dictionary = m.summary()
	for frame in 180: m.step(DT,Vector2.RIGHT,true,true,true)
	check(m.summary() == snapshot,"returned measurement and inventory remain frozen")
	var exhausted := fresh()
	for frame in 6000:
		if exhausted.phase != "active": break
		exhausted.step(DT,Vector2.ZERO,false)
	check(exhausted.phase == "exhausted" and exhausted.energy == 0,"ordinary time consumption can exhaust")
	check(absf(exhausted.elapsed-60.0) < 0.1,"idle budget uses existing 0.6-per-second drain")
	var stopped: Dictionary = exhausted.summary()
	for frame in 180: exhausted.step(DT,Vector2.RIGHT,true)
	check(exhausted.summary() == stopped,"exhaustion stops clock and movement")

func collection() -> void:
	for level in [0,1]:
		var m := fresh("pond","sunny",level)
		check(Probe.drive_edge(m,0,1) and Probe.drive_edge(m,1,2),"reach near flowers by flight")
		var before: float = m.harvest_seconds
		check(Probe.gather(m,1),"one nectar collected")
		var expected := 1.8 if level == 0 else 0.8
		check(absf(m.harvest_seconds-before-expected) < DT*1.1,"growth changes actual collect duration")
		check(m.cargo == 1,"one stock yields one cargo")
	# Capacity has more stock available at the far patch; a full bag must not
	# keep draining the extra harvest cost while the input remains held.
	var full := fresh()
	check(Probe.drive_edge(full,0,1) and Probe.drive_edge(full,1,3) and Probe.drive_edge(full,3,4),"early profile can physically reach far patch")
	check(Probe.gather(full,8) and full.cargo == 6,"capacity caps a request for eight")
	var stock := 0
	for flower in full.flowers:
		if int(flower.node) == 4: stock += int(flower.stock)
	check(stock == 4,"full bag leaves unharvested far stock")
	var seconds: float = full.harvest_seconds
	for frame in 12: full.step(DT,Vector2.ZERO,true)
	check(full.cargo == 6 and full.harvest_seconds == seconds,"holding collect while full adds neither cargo nor harvest cost")
	# Partial progress is preserved when the player releases E.
	var partial := fresh()
	Probe.drive_edge(partial,0,1)
	Probe.drive_edge(partial,1,2)
	for frame in 54: partial.step(DT,Vector2.ZERO,true)
	check(partial.cargo == 0,"partial harvesting does not pay early")
	partial.step(DT,Vector2.ZERO,false)
	for frame in 54: partial.step(DT,Vector2.ZERO,true)
	check(partial.cargo == 1,"partial progress survives releasing collect")

func pulse_and_dash() -> void:
	var empty := fresh()
	var baseline := fresh()
	for frame in 60:
		empty.step(DT,Vector2.ZERO,false,false,true,Vector2.LEFT)
		baseline.step(DT,Vector2.ZERO,false)
	check(is_equal_approx(empty.energy,baseline.energy),"empty wing pulses cost no extra energy")
	var material := fresh("violet","sunny",1)
	for edge in [[0,1],[1,3],[3,4],[4,6]]:
		check(Probe.drive_edge(material,edge[0],edge[1]),"material target reached via corridor")
	check(Probe.gather_materials(material),"grown directional pulses and close pickup collect both materials")
	check(material.material_count == 2,"materials accounted separately from nectar")
	for item in material.materials:
		check(item.taken and item.dropped and int(item.hits) == 2,"one grown pulse per material")
	var dash := fresh()
	for frame in 25: dash.step(DT,Vector2.LEFT,false,true)
	dash.step(DT,Vector2.LEFT,false,false)
	check(dash.burst_left > 0,"release after charge starts dash")
	for frame in 60:
		dash.step(DT,Vector2.LEFT,false)
		check(Layout.walkable(dash.layout,dash.p),"dash cannot cross visible vegetation boundary")
	check(dash.collision_seconds > 0,"dash records blocked movement")
	var blocked := fresh("pond","variant",1)
	check(not blocked.clear_line(blocked.layout.nodes[3].p,blocked.layout.nodes[4].p),"closed variant bridge blocks action line of sight")

func frozen_state(region: String, state: String, level: int) -> void:
	var m := fresh(region,state,level)
	var original_edges: Array = m.layout.edges.duplicate(true)
	var original_shelters: Array = m.layout.shelters.duplicate(true)
	var original_capacity: int = m.capacity()
	for frame in 90:
		m.step(DT,(m.layout.nodes[1].p-m.p).normalized(),false)
		check(m.cargo <= m.capacity() and m.energy >= 0,"inventory and energy bounds")
	check(m.region == region and m.condition == state and m.growth == level,"run configuration stays fixed")
	check(m.layout.edges == original_edges and m.layout.shelters == original_shelters,"state never reshuffles midflight")
	check(m.capacity() == original_capacity,"growth does not change midflight")

func rain_choices() -> void:
	for region in ["pond","violet"]:
		var early: Dictionary = Probe.sample(region,"rain",0,"initial_one",[0,1,2,1,0],2,1)
		check(early.result == "returned" and early.cargo == 1,"initial rain has a short productive return")
		check(float(early.energy_left) > 5.0,"initial rain short route leaves turning/reading margin")
		var direct: Array = [0,1,3,4,3,1,0] if region == "pond" else [0,1,2,5,2,1,0]
		var covered: Array = [0,1,6,5,4,5,6,1,0] if region == "pond" else [0,1,3,4,5,4,3,1,0]
		var target := 4 if region == "pond" else 5
		var a: Dictionary = Probe.sample(region,"rain",1,"direct",direct,target,1)
		var b: Dictionary = Probe.sample(region,"rain",1,"covered",covered,target,1)
		check(a.result == "returned" and b.result == "returned","grown rain route comparison both returns")
		check(a.cargo == b.cargo and a.energy_start == b.energy_start,"rain comparison holds target and profile constant")
		check(float(b.elapsed_seconds) > float(a.elapsed_seconds),"sheltered rain choice takes longer")
		check(float(b.rain_seconds) < float(a.rain_seconds) and float(b.energy_left) > float(a.energy_left)+3.0,"sheltered rain choice saves measured stamina")
