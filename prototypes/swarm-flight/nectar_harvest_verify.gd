extends SceneTree
## Rules and persistence assertions; not evidence of player enjoyment.
const Model = preload("res://nectar_harvest_model.gd")
const Save = preload("res://save_data.gd")
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")

func check(value: bool,label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: "+label)

func tick(m,seconds: float,move := Vector2.ZERO,collect := false,held := false) -> void:
	for i in int(round(seconds*60.0)): m.step(1.0/60.0,move,collect,held)

func field(m,where: Vector2) -> void:
	# Isolated rule fixture; journey flow below uses normal movement separately.
	m.p = where
	m.v = Vector2.ZERO
	m.phase = "field"
	m.area = "meadow" if where.x > Model.GATE_X else "pond"
	m.trip_index = maxi(1,m.trip_index)
	m.energy = m.max_energy()
	m.creatures = Model.Encounters.layout(m.trip_index)
	for creature in m.creatures: creature.state = "gone"
	if where.x > Model.GATE_X: m.visited_meadow = true

func home(m) -> void:
	m.p = Model.HOME
	m.v = Vector2.ZERO
	m.phase = "home"
	m.area = "hub"
	m.hurt_left = 0.0
	m.energy = m.max_energy()
	m.clear_controls()
	m.burst_left = 0.0

func travel(m,target: Vector2,dt: float,digital: bool) -> bool:
	# Movement fixtures use the same explicit gate request as the native E input.
	if target == Model.HOME and m.area != "hub":
		var entry: Vector2 = Model.POND_ENTRY if m.area == "pond" else Model.MEADOW_ENTRY
		if not local_fly(m,entry,dt,digital) or not m.transition_to("hub"): return false
	elif target != Model.HOME:
		var destination := "meadow" if target.x > Model.GATE_X else "pond"
		if m.area == "hub":
			if not local_fly(m,Model.HUB_DEPART,dt,digital) or not m.transition_to(destination): return false
		elif m.area != destination:
			var gate: Vector2 = Model.POND_EXIT if m.area == "pond" else Model.MEADOW_ENTRY
			if not local_fly(m,gate,dt,digital) or not m.transition_to(destination): return false
	return local_fly(m,target,dt,digital)

func fly(m,target: Vector2) -> bool:
	return travel(m,target,1.0/60.0,false)

func fly_input_frames(m,target: Vector2,dt: float) -> bool:
	return travel(m,target,dt,true)

func local_fly(m,target: Vector2,dt: float,digital: bool) -> bool:
	for frame in 2400:
		var delta: Vector2 = target-m.p
		if delta.length() < (16.0 if digital else 9.0):
			for released in 6: m.step(dt,Vector2.ZERO,false,false)
			return true
		var move: Vector2 = Vector2(float(delta.x > 8)-float(delta.x < -8),float(delta.y > 8)-float(delta.y < -8)) if digital else delta.normalized()
		m.step(dt,move.limit_length(),false,false)
	return false

func transaction_route_regression(dt: float) -> void:
	# Regression for the native trip-12 +180 sale: real time steps, no granted
	# upgrades/cargo, and the same clone-before-transaction contract as main.
	var route = Model.new()
	var plan := ["gather1","bag1","wings1","gather2","bag2","meadow","reach","shortcut","market","twin","wings2","reserve"]
	var route_ok := true
	var final_sale := false
	for expedition in 30:
		if plan.is_empty(): break
		route_ok = fly_input_frames(route,Vector2(470,575),dt) and route_ok
		if "shortcut" in route.owned:
			route_ok = fly_input_frames(route,Model.SHORTCUTS[0],dt) and route_ok
			route_ok = route.use_shortcut() and route_ok
		while route.cargo_total() < route.capacity():
			var target: Dictionary = {}
			for flower in route.flowers:
				if flower.stock <= 0: continue
				if (flower.region == 1) != ("meadow" in route.owned): continue
				if target.is_empty() or route.p.distance_to(flower.pos) < route.p.distance_to(target.pos): target = flower
			if target.is_empty() or not fly_input_frames(route,target.pos,dt):
				route_ok = false
				break
			for frame in 600:
				route.step(dt,Vector2.ZERO,true,false)
				if route.cargo_total() >= route.capacity() or target.stock <= 0: break
			for released in 3: route.step(dt,Vector2.ZERO,false,false)
			if route.phase != "field":
				route_ok = false
				break
		if not route_ok: break
		if "shortcut" in route.owned:
			route_ok = fly_input_frames(route,Model.SHORTCUTS[1],dt) and route_ok
			route_ok = route.use_shortcut() and route_ok
		route_ok = fly_input_frames(route,Model.HOME,dt) and route_ok
		route.clear_controls()
		route.v = Vector2.ZERO
		var candidate = Model.new()
		var before: Dictionary = route.to_payload()
		var restored: bool = candidate.restore_payload(JSON.parse_string(JSON.stringify(before,"",true,true)))
		check(restored,"digital-input %d FPS trip %d clones before sale" % [roundi(1.0/dt),expedition+1])
		if not restored:
			print("FAILED PRE-SALE STATE: "+JSON.stringify(before,"",true,true))
			route_ok = false
			break
		var gain: int = candidate.sell()
		check(gain > 0 and candidate.cargo_total() == 0 and candidate.coins == route.coins+gain,"digital-input trip %d sale transfers cargo once" % (expedition+1))
		final_sale = final_sale or (route.owned.size() == 11 and route.energy == 145.0 and gain == 180)
		route_ok = route.restore_payload(candidate.to_payload()) and route_ok
		while not plan.is_empty() and route.can_buy(plan[0]):
			candidate = Model.new()
			route_ok = candidate.restore_payload(route.to_payload()) and route_ok
			route_ok = candidate.buy(plan.pop_front()) and route_ok
			route_ok = route.restore_payload(candidate.to_payload()) and route_ok
	check(route_ok and final_sale and route.completed and route.owned.size() == 12,"digital-input %d FPS route sells +180 with final wings and completes reserve" % roundi(1.0/dt))

func reject(m,data: Dictionary,label: String) -> void:
	var before := JSON.stringify(m.to_payload())
	check(not m.restore_payload(data),label+" rejected")
	check(JSON.stringify(m.to_payload()) == before,label+" restore is atomic")

func growth_tree_rules() -> void:
	# Isolated purchase predicates, not a prediction of player pacing.
	var m = Model.new()
	m.coins = 2000
	check(not m.can_buy("wings1") and not m.can_buy("meadow"),"new tree starts with exactly the two initial skill families")
	check(m.buy("gather1") and m.can_buy("wings1") and m.can_buy("reach"),"first gather rank reveals independent endurance and reach")
	check(m.buy("reach") and m.growth_count() == 2 and not m.can_buy("meadow"),"two ability ranks are below region threshold")
	check(not m.can_buy("twin"),"range alone cannot bypass twin's gather-two AND prerequisite")
	check(m.buy("gather2") and m.growth_count() == 3 and m.can_buy("meadow") and m.can_buy("twin"),"three ranks include repeated ranks and satisfy meadow; twin AND is complete")
	check(m.buy("meadow") and m.growth_count() == 3,"region purchase does not add a base growth rank")
	check(not m.can_buy("market") and not m.can_buy("reserve"),"region ownership alone does not fabricate purple deliveries")
	m.visited_meadow = true
	m.sold_total = 1
	m.rose_sold = 1
	check(m.can_buy("market") and not m.can_buy("reserve"),"one purple delivery opens optional income, not completion")
	m.sold_total = 18
	m.rose_sold = 18
	check(not m.can_buy("reserve"),"18 deliveries still need one capability or route change")
	check(m.buy("twin") and m.can_buy("reserve"),"twin alone satisfies completion OR without shortcut")
	check("口碑" not in m.goal_text() and "180" in m.goal_text(),"twin route goal advances directly to reserve without optional market")
	check(m.buy("reserve") and m.completed and "market" not in m.owned and "shortcut" not in m.owned,"twin route finishes without market or full tree")
	var clone = Model.new()
	check(clone.restore_payload(m.to_payload()) and clone.completed,"twin completion survives strict new save validation")
	check(m.buy("bag1") and m.buy("bag2") and "wings1" not in m.owned,"capacity ranks can be bought independently after completion")
	check(clone.restore_payload(m.to_payload()),"capacity-two without wings is a legal cold state")
	var wings = Model.new()
	wings.coins = 2000
	check(wings.buy("gather1") and wings.buy("wings1") and wings.buy("wings2") and "bag1" not in wings.owned,"endurance ranks do not require capacity ranks")
	check(clone.restore_payload(wings.to_payload()),"endurance-two without capacity is a legal cold state")
	var shortcut = Model.new()
	shortcut.coins = 2000
	for id in ["gather1","bag1","wings1","meadow","shortcut"]:
		check(shortcut.buy(id),"shortcut route legal purchase: "+id)
	shortcut.visited_meadow = true
	shortcut.sold_total = 18
	shortcut.rose_sold = 18
	check("口碑" not in shortcut.goal_text() and "180" in shortcut.goal_text(),"shortcut route goal advances directly to reserve without optional market")
	check(shortcut.buy("reserve") and "twin" not in shortcut.owned and "market" not in shortcut.owned,"shortcut route finishes without twin or market")
	check(clone.restore_payload(shortcut.to_payload()),"shortcut completion survives strict save validation")
	var bad := Model.new().to_payload()
	bad.owned = ["gather1","meadow"]
	reject(clone,bad,"new saves cannot use old one-rank region threshold")
	bad = Model.new().to_payload()
	bad.owned = ["bag1","bag2","meadow"]
	reject(clone,bad,"two capacity ranks still cannot open region")
	bad = Model.new().to_payload()
	bad.owned = ["gather1","gather2","reach","meadow","market"]
	reject(clone,bad,"new income upgrade requires actual purple exploration and sale")
	for ids in [["wings1"],["bag1","wings2"],["gather2"],["reach"],["gather1","reach","twin"],["gather1","gather2","twin"]]:
		bad = Model.new().to_payload()
		bad.owned = ids
		bad.energy = 145.0 if "wings2" in ids else 110.0 if "wings1" in ids else 85.0
		reject(clone,bad,"new save missing a required ability: "+str(ids))

func run() -> void:
	growth_tree_rules()
	var m = Model.new()
	check(m.at_home() and m.capacity() == 18 and m.energy == 85.0,"new game starts supplied at home")
	check(m.flowers.size() == 14 and m.upgrade_defs().size() == 12,"two seven-flower regions and twelve growth nodes")
	check(m.sell() == 0 and m.coins == 0,"empty sale creates no money")
	check(not m.buy("unknown") and not m.buy("gather1"),"unknown or unaffordable purchase denied")
	check(fly(m,m.flowers[0].pos),"ordinary movement reaches first source")
	check(m.phase == "field" and m.trip_index == 1,"first departure opens one trip")
	var initial_stock: int = m.flowers[0].stock
	tick(m,1.0,Vector2.ZERO,true)
	check(m.cargo_total() == 5 and m.flowers[0].stock == initial_stock-5,"one second harvesting transfers five units")
	var no_collect := m.cargo_total()
	tick(m,0.5)
	check(m.cargo_total() == no_collect,"releasing collection stops intake")
	check(fly(m,Model.HOME),"ordinary movement returns to home")
	check(m.at_home() and m.energy == m.max_energy(),"return refills expedition energy")
	check(m.sell() == 5 and m.coins == 5 and m.cargo_total() == 0,"sale transfers cargo into coins")
	check(m.sell() == 0 and m.coins == 5,"repeat sale cannot pay twice")
	check(fly(m,m.flowers[0].pos) and m.trip_index == 2,"second departure is available after sale")
	check(m.flowers[0].stock == initial_stock,"new trip replenishes normal flower stock")
	tick(m,3.0,Vector2.ZERO,true)
	check(m.cargo_total() == 12 and m.flowers[0].stock == 0,"source can be exhausted without over-harvesting")
	check(fly(m,m.flowers[1].pos),"next source reachable")
	tick(m,3.0,Vector2.ZERO,true)
	check(m.cargo_total() == 18 and m.flowers[1].stock == 6,"full bag stops exactly at capacity")
	var full_stock: int = m.flowers[1].stock
	tick(m,1.0,Vector2.ZERO,true)
	check(m.flowers[1].stock == full_stock,"full bag does not destroy nectar")
	check(m.events.filter(func(e): return e.kind == "full").size() == 1,"full feedback is emitted once until capacity available")
	var payload: Dictionary = JSON.parse_string(JSON.stringify(m.to_payload(),"",true,true))
	var copy = Model.new()
	check(copy.restore_payload(payload),"current field save survives JSON encoding")
	check(copy.cargo == m.cargo and copy.flowers == m.flowers and copy.energy == m.energy and copy.p == m.p,"cold resume preserves cargo, depletion, energy and position")
	var preserved := JSON.stringify(copy.to_payload())
	copy.step(0.0,Vector2.ZERO,true,false)
	check(JSON.stringify(copy.to_payload()) == preserved,"paused zero-time update neither harvests nor refreshes")
	var before_trip: int = copy.trip_index
	tick(copy,0.1)
	check(copy.trip_index == before_trip and copy.flowers[1].stock == full_stock,"load followed by step does not start a fresh trip")
	var empty = Model.new()
	check(fly(empty,Vector2(500,575)) and fly(empty,Model.HOME),"empty expedition can return")
	empty.flowers[0].stock = 0
	check(fly(empty,Vector2(500,575)) and empty.flowers[0].stock == 12 and empty.trip_index == 2,"empty return does not block next-trip replenishment")
	var edge = Model.new()
	edge.p = Model.HUB_DEPART
	tick(edge,0.3,Vector2.RIGHT)
	check(edge.area == "hub" and edge.trip_index == 0,"walking across the hub never auto-starts an expedition")
	edge.p = Model.HUB_DEPART
	check(edge.transition_to("pond"),"departure requires explicit gate interaction")
	edge.flowers[0].stock = 3
	edge.p = Model.POND_ENTRY
	tick(edge,0.3)
	check(edge.area == "pond" and edge.trip_index == 1 and edge.flowers[0].stock == 3,"standing on entry never refills or auto-returns")
	var rescued = Model.new()
	field(rescued,Vector2(900,400))
	rescued.cargo = {"blue":10,"rose":0}
	rescued.coins = 19
	rescued.owned.append("gather1")
	rescued.energy = 0.001
	rescued.step(0.1,Vector2.ZERO,false,false)
	check(rescued.at_home() and rescued.cargo_total() == 5 and rescued.coins == 19 and "gather1" in rescued.owned,"exhaustion halves unsold cargo and preserves permanent rewards")
	check(rescued.energy == rescued.max_energy() and rescued.events.any(func(e): return e.kind == "rescue"),"rescue supplies home and reports loss")
	check(fly(rescued,Vector2(500,575)) and rescued.trip_index == 2,"rescue permits a new trip")
	var dash = Model.new()
	field(dash,Vector2(800,450))
	tick(dash,0.4,Vector2.RIGHT,false,true)
	check(dash.charging and dash.charge == Model.CHARGE_READY,"held charge reaches readiness")
	dash.step(1.0/60.0,Vector2.RIGHT,false,false)
	check(dash.burst_left > 0.0 and dash.v.x == 500.0 and dash.events.any(func(e): return e.kind == "dash"),"release launches dash")
	tick(dash,1.0,Vector2.RIGHT)
	check(dash.p.x <= 1720.0,"locked region remains physically closed")
	var growth = Model.new()
	growth.coins = 1000
	check(not growth.buy("meadow") and not growth.buy("gather2"),"visible prerequisites cannot be skipped")
	check(growth.buy("bag1") and growth.capacity() == 30 and growth.coins == 982,"capacity upgrade charges correct amount")
	check(not growth.buy("bag1") and growth.coins == 982,"owned node cannot be purchased twice")
	check(growth.buy("wings1") and growth.max_energy() == 110.0 and growth.energy == 110.0,"energy upgrade takes effect and refills at home")
	check(growth.buy("bag2") and growth.capacity() == 48,"larger bag expands carrying limit")
	check(growth.buy("wings2") and growth.max_energy() == 145.0,"final wings expand endurance")
	check(growth.buy("meadow"),"three base ranks permit meadow unlock")
	field(growth,Model.POND_EXIT)
	check(growth.transition_to("meadow"),"unlocked gate explicitly switches region")
	check(growth.p.x > Model.GATE_X and growth.visited_meadow,"unlock opens actual movement into new area")
	check(not growth.buy("shortcut"),"buy is denied outside home")
	field(growth,growth.flowers[7].pos)
	tick(growth,4.0,Vector2.ZERO,true)
	check(growth.cargo.rose == 16 and growth.cargo_value() == 48,"far flower yields more valuable purple nectar")
	home(growth)
	check(growth.sell() == 48 and growth.rose_sold == 16,"purple sale tracks milestone progress")
	check(growth.buy("shortcut"),"shortcut purchase follows meadow")
	field(growth,Model.SHORTCUTS[0])
	check(growth.use_shortcut() and growth.p == Model.SHORTCUTS[1],"shortcut travels outward")
	check(growth.use_shortcut() and growth.p == Model.SHORTCUTS[0],"shortcut travels homeward")
	home(growth)
	check(growth.buy("market"),"market follows actual first purple sale")
	growth.cargo = {"blue":0,"rose":4}
	check(growth.cargo_value() == 15 and growth.sell() == 15,"market applies one visible 25 percent bonus")
	check(growth.buy("reserve") and growth.completed,"real purple deliveries allow final reserve milestone")
	check(growth.phase == "home" and fly(growth,Vector2(600,400)),"milestone does not end free play")
	var rain = Model.new()
	rain.owned.assign(["gather1","gather2","reach","meadow"])
	field(rain,Vector2(2700,400))
	tick(rain,1.0)
	check(absf(rain.energy-82.5) < 0.001,"exposed rain edge consumes extra endurance")
	field(rain,Vector2(2700,650))
	tick(rain,1.0)
	check(absf(rain.energy-84.3) < 0.001,"low rain route avoids extra weather drain")
	rain.p = Vector2(2760,580)
	check(not rain.rain_exposed(),"painted canopy underside at 580 protects against rain")
	rain.p = Vector2(2760,400)
	check(rain.rain_exposed(),"above the same visible canopy remains exposed")
	tick(rain,1.0,Vector2.DOWN)
	check(rain.p.y <= 650,"downward movement keeps the bee above the bottom HUD")
	var twin = Model.new()
	twin.owned.assign(["gather1","gather2","reach","twin","bag1"])
	field(twin,(twin.flowers[1].pos+twin.flowers[2].pos)*0.5)
	tick(twin,1.0,Vector2.ZERO,true)
	check(twin.flowers[1].stock < 12 and twin.flowers[2].stock < 12 and twin.cargo_total() >= 20,"twin affects two real nearby sources")
	var valid: Dictionary = JSON.parse_string(JSON.stringify(m.to_payload(),"",true,true))
	var bad := valid.duplicate(true)
	bad.coins = -1
	reject(copy,bad,"negative coins")
	bad = valid.duplicate(true); bad.p[0] = INF
	reject(copy,bad,"nonfinite position")
	bad = valid.duplicate(true); bad.energy = NAN
	reject(copy,bad,"nonfinite energy")
	bad = valid.duplicate(true); bad.owned = ["bag2"]
	reject(copy,bad,"missing upgrade prerequisite")
	bad = valid.duplicate(true); bad.owned = ["bag1","bag1"]
	reject(copy,bad,"duplicate upgrade")
	bad = valid.duplicate(true); bad.cargo.blue = 19
	reject(copy,bad,"over-capacity cargo")
	bad = valid.duplicate(true); bad.flowers[0].stock = 99
	reject(copy,bad,"invented flower stock")
	bad = valid.duplicate(true); bad.flowers[0].id = "wrong"
	reject(copy,bad,"wrong flower identity")
	bad = valid.duplicate(true); bad.flowers[8].stock = 0
	reject(copy,bad,"unopened far flowers harvested")
	bad = valid.duplicate(true); bad.extra = true
	reject(copy,bad,"unexpected save field")
	bad = valid.duplicate(true); bad.version = 4
	reject(copy,bad,"unsupported schema")
	bad = valid.duplicate(true); bad.completed = true
	reject(copy,bad,"false milestone flag")
	bad = valid.duplicate(true); bad.phase = "home"
	reject(copy,bad,"home flag outside home")
	var path := "user://nectar-harvest-rule-test-%d.json" % OS.get_process_id()
	check(Save.write_payload(valid,path,Model.new()),"atomic file writer accepts new independent validator")
	var disk: Dictionary = Save.read_payload(path,Model.new())
	var disk_model = Model.new()
	check(not disk.is_empty() and disk_model.restore_payload(disk) and disk_model.cargo == m.cargo,"disk round trip preserves actual stock and cargo")
	check(not Save.write_payload(bad,path,Model.new()),"bad candidate cannot overwrite disk snapshot")
	check(Save.read_payload(path,Model.new()) == disk,"failed write leaves previous save untouched")
	DirAccess.remove_absolute(path)
	var transaction = Model.new()
	transaction.coins = 20
	var candidate = Model.new()
	check(candidate.restore_payload(transaction.to_payload()) and candidate.buy("gather1"),"purchase can be staged in an independent candidate")
	var failed_path := "user://missing-nectar-test-%d/save.json" % OS.get_process_id()
	check(not Save.write_payload(candidate.to_payload(),failed_path,Model.new()),"unavailable save destination reports failure")
	check(transaction.coins == 20 and transaction.owned.is_empty(),"failed staged purchase leaves live money and ownership intact")
	check(Save.write_payload(candidate.to_payload(),path,Model.new()) and transaction.restore_payload(candidate.to_payload()),"saved purchase candidate can commit")
	check(transaction.coins == 8 and "gather1" in transaction.owned,"committed purchase has both debit and benefit")
	var restored_purchase = Model.new()
	check(restored_purchase.restore_payload(Save.read_payload(path,Model.new())) and not restored_purchase.buy("gather1"),"cold resume cannot repeat a purchased node")
	DirAccess.remove_absolute(path)
	var economy = Model.new()
	var planned := ["gather1","bag1","wings1","gather2","bag2","meadow","reach","shortcut","market","twin","wings2","reserve"]
	var simulated_seconds := 0.0
	var route_ok := true
	for expedition in 40:
		while not planned.is_empty() and economy.can_buy(planned[0]):
			economy.buy(planned.pop_front())
		if planned.is_empty(): break
		var before_count: int = economy.trip_index
		while economy.cargo_total() < economy.capacity():
			var target: Dictionary = {}
			for flower in economy.flowers:
				if flower.stock <= 0: continue
				if flower.region == 1 and "meadow" not in economy.owned: continue
				if "meadow" in economy.owned and flower.region == 0: continue
				if target.is_empty() or economy.p.distance_to(flower.pos) < economy.p.distance_to(target.pos): target = flower
			if target.is_empty():
				route_ok = false
				break
			var distance: float = economy.p.distance_to(target.pos)
			route_ok = fly(economy,target.pos) and route_ok
			simulated_seconds += distance/230.0
			var needed := mini(economy.capacity()-economy.cargo_total(),int(target.stock))
			var harvesting_seconds: float = float(needed)/economy.harvest_rate()+0.1
			tick(economy,harvesting_seconds,Vector2.ZERO,true)
			simulated_seconds += harvesting_seconds
			if economy.at_home():
				route_ok = false
				break
		if not route_ok: break
		simulated_seconds += economy.p.distance_to(Model.HOME)/230.0
		route_ok = fly(economy,Model.HOME) and route_ok
		var sold := economy.sell()
		check(sold > 0 and economy.trip_index == before_count+1,"normal-input economy trip %d sells one actual cargo" % (expedition+1))
		var after_trip = Model.new()
		check(after_trip.restore_payload(JSON.parse_string(JSON.stringify(economy.to_payload(),"",true,true))),"economy trip %d remains save-valid" % (expedition+1))
	check(route_ok and economy.completed and economy.owned.size() == 12,"ordinary collection/sale route can buy all twelve nodes and finish reserve")
	check(economy.rose_sold >= 18 and economy.coins >= 0 and economy.trip_index < 40,"progression uses delivered nectar without negative balances or test-loop exhaustion")
	print("NECTAR ECONOMY FIXTURE: %d trips; approximate movement/collection %.1f seconds, excludes menus and player decisions" % [economy.trip_index,simulated_seconds])
	transaction_route_regression(1.0/30.0)
	transaction_route_regression(1.0/60.0)
	print("NECTAR RULES: %d checks, %d failures" % [checks,failures])
	quit(1 if failures > 0 else 0)
