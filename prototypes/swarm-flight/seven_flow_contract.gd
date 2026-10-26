extends RefCounted
## Independent release/runout inputs for LV03–06, not a player enjoyment score.
const Model = preload("res://long_journey_model.gd")
const Driver = preload("res://route_driver.gd")
# Scene, launch x/y, next shared pickup x/y, expected wind flowers.
const EXITS := [[0,290,250,2220,420,3],[1,250,500,2150,530,3],[2,250,270,2230,550,3],[2,3050,560,4930,420,3],[3,1110,550,2990,540,3],[5,350,230,2440,420,3],[5,350,580,2440,420,3],[6,300,550,2220,420,3],[7,270,520,2190,540,3],[7,2850,570,4730,420,3],[8,450,420,1160,420,0],[8,1260,230,3140,420,3],[9,1470,540,3370,550,3],[11,260,500,2180,550,3],[11,2790,550,4670,420,3],[11,5150,420,6990,540,3],[12,260,220,2370,420,3],[12,260,580,2370,420,3],[12,2890,420,4730,420,3]]

static func run(check: Callable) -> void:
	runouts(check)
	resources(check)
	wind_links(check)

static func runouts(check: Callable) -> void:
	for fixture in EXITS:
		for offset in [-45,0,45]:
			var m := Model.new()
			var origin: float = m.chapter.encounters[fixture[0]].start_x
			m.p = Vector2(origin+fixture[1]+offset,fixture[2])
			m.stamina = 60.0 # Explicit independent state boundary, then only inputs.
			var target := Vector2(origin+fixture[3],fixture[4])
			# The two fork exits deliberately follow the visible hedge to its end
			# before converging. Do not mistake cutting into that hedge for a bug.
			var turn_x: float = origin+({5:2330,12:2250}.get(fixture[0],0))
			var post := 0.0
			var picked := false
			var contacts := 0
			var furthest: float = m.p.x
			var retreat := 0.0
			for frame in 1500:
				var held := frame in range(1,28)
				var direction := Vector2.RIGHT
				if held: direction = Vector2.ZERO
				elif post >= 0.6 and m.p.x >= turn_x:
					# The player has time to read the exit before turning, with no
					# route-driver brake inserted at the precise dash endpoint.
					var delta: Vector2 = target-m.p
					direction = Vector2(signf(delta.x) if absf(delta.x)>8 else 0,signf(delta.y) if absf(delta.y)>8 else 0).normalized()
				m.events.clear()
				m.step(direction,held,1.0/60)
				if m.bursts > 0 and m.burst_left <= 0: post += 1.0/60
				furthest = maxf(furthest,m.p.x)
				retreat = maxf(retreat,furthest-m.p.x)
				for event in m.events:
					if event.kind in ["hit","blocked"]: contacts += 1
					if event.kind == "dew" and event.pos == target: picked = true
				if picked or m.recoveries > 0: break
			var label := "scene=%d launch=%d offset=%d" % [fixture[0],fixture[1],offset]
			check.call(contacts == 0 and m.recoveries == 0,"07 dash runout and subsequent turn stay clear: "+label)
			check.call(picked and retreat < 32,"07 exit supply is reachable after reading the landing without turning back: "+label)
			check.call(m.rings_hit == fixture[5],"07 release tolerance keeps the intended wind chain: "+label)
			if contacts > 0 or not picked or retreat >= 32: print("SEVEN_EXIT_FAILURE: "+JSON.stringify({"case":label,"contacts":contacts,"picked":picked,"retreat":retreat,"position":str(m.p-Vector2(origin,0))}))
	print("SEVEN_RUNOUTS: 19 launches x 3 release positions")

static func resources(check: Callable) -> void:
	for alternate in [false,true]:
		var m := Model.new()
		var driver := Driver.new(m,alternate)
		driver.wait_for_full = false
		var minimum := 100.0
		var waste := 0.0
		var first_leaf := {}
		var first_dew := -1.0
		var contacts := 0
		var scenes := {0:0.0}
		var previous := 0
		var previewed := {4:false,10:false}
		for frame in 60000:
			if m.phase != "playing" or m.recoveries > 0: break
			var input: Dictionary = driver.next_input()
			if not driver.error.is_empty(): break
			m.events.clear()
			m.step(input.direction,input.held,1.0/60)
			minimum = minf(minimum,m.stamina)
			if m.encounter_index() != previous:
				previous = m.encounter_index()
				scenes[previous] = m.time
			if previous in previewed and m.p.x > m.chapter.encounters[previous].end_x-260:
				for flower in m.rings:
					if flower.get("encounter",-1) == previous+1 and flower.pos.x > m.p.x and flower.pos.x < m.camera_x+1240:
						previewed[previous] = true
			for e in m.events:
				if e.kind in ["blocked","hit","tired"]: contacts += 1
				if e.kind == "dew":
					waste += float(m.chapter.get("dew_reward",12))-e.reward
					if first_dew < 0: first_dew = e.reward
				if e.kind == "checkpoint" and first_leaf.is_empty(): first_leaf = {"time":m.time,"stamina":m.stamina}
		check.call(m.phase == "transition" and contacts == 0 and m.recoveries == 0 and driver.error.is_empty(),"07 full forward routes need no damage, forced recovery or full-rest wait")
		check.call(first_dew >= 6 and first_leaf.get("time",0) > 15 and first_leaf.get("stamina",100) < 80,"07 opening spends stamina before a useful refill and first leaf")
		check.call(minimum >= 12 and minimum < (70 if alternate else 55) and waste < 12,"07 resources preserve a hit reserve without a route of overflowing refills")
		for scene_index in [4,10]:
			var duration: float = scenes.get(scene_index+1,INF)-scenes.get(scene_index,0.0)
			check.call(duration > 0 and duration < 6,"07 breather reconnects to purpose within six seconds: scene=%d" % scene_index)
			check.call(previewed[scene_index],"07 next wind approach is visible before leaving the breather: scene=%d" % scene_index)
		print("SEVEN_RESOURCES: "+JSON.stringify({"alternate":alternate,"minimum":minimum,"waste":waste,"first_dew":first_dew,"first_leaf":first_leaf,"seconds":m.time,"scenes":scenes,"collected":m.garden_awards[0],"total":m.dew.size()}))

static func wind_links(check: Callable) -> void:
	# Counterfactual fixture: a middle wind flower sustains the flight across a
	# gap one launch cannot cover. This is a functional link, not another target
	# claiming to be a new decision. Does not establish variety or enjoyment.
	for missing in [false,true]:
		var m := Model.new()
		m.p = Vector2(290,250)
		m.stamina = 60.0
		if missing: m.rings.remove_at(1)
		for frame in 240:
			m.step(Vector2.ZERO if frame in range(1,28) else Vector2.RIGHT,frame in range(1,28),1.0/60)
		check.call(m.rings_hit == (1 if missing else 3),"Intermediate wind flower makes a measurable continuation difference: missing=%s" % missing)
