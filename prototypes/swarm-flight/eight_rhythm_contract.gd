extends RefCounted
## Independent ordinary-input fixtures derived from Alan's four feedback items.
## They establish reachability/ordering, not a judgement of fun or first-play ease.
const Model = preload("res://long_journey_model.gd")
const Driver = preload("res://route_driver.gd")

static func run(check: Callable) -> void:
	attack_before_pass(check)
	dash_exits(check)
	resource_routes(check)
	suspend_action(check)

static func attack_before_pass(check: Callable) -> void:
	var model := Model.new()
	model.load_stage(1)
	var flower: Vector2 = model.sprayers[0].pos
	model.p = flower-Vector2(700,0) # Independent start-position boundary fixture.
	var spray_at := -1.0
	var crossed_at := -1.0
	var warned := 0.0
	var hits := 0
	for frame in 600:
		if spray_at < 0 and model.sprayer_phase(0) == "warning": warned += 1.0/60
		model.events.clear()
		model.step(Vector2.RIGHT,false,1.0/60)
		for event in model.events:
			if event.kind == "spray" and spray_at < 0: spray_at = model.time
			if event.kind == "hit": hits += 1
		if crossed_at < 0 and model.p.x >= flower.x: crossed_at = model.time
		if model.p.x > flower.x+280: break
	check.call(spray_at > 0 and spray_at < crossed_at-0.5,"08 flower attacks during ordinary approach, before the player passes")
	check.call(warned >= 0.7,"08 first attack retains a visible warning rather than instant damage")
	check.call(hits > 0,"Ignoring an active flower is observably different from responding")
	print("EIGHT_ATTACK: "+JSON.stringify({"spray":spray_at,"cross":crossed_at,"warning":warned,"ignored_hits":hits}))

static func dash_exits(check: Callable) -> void:
	# Scene, launch x/y, the first of three exit drops. Fixtures deliberately
	# keep Right held after release: no reference-route braking or backtracking.
	var launches := [[0,1650,340,2360,340],[1,850,540,1560,540],[1,2800,340,3340,340],[2,300,280,1010,280],[2,2630,540,4230,280],[3,850,320,1560,320],[3,2800,550,3510,550],[5,330,420,1050,420],[5,2100,420,2810,420],[6,260,540,1850,260],[6,3560,550,4270,550],[8,330,420,1050,420],[8,1550,420,3140,290],[8,4940,550,5650,550],[8,6490,380,7030,380]]
	for launch in launches:
		for offset in [-45,0,45]:
			var model := Model.new()
			model.load_stage(1)
			var origin: float = model.chapter.encounters[launch[0]].start_x
			model.p = Vector2(origin+launch[1]+offset,launch[2])
			model.stamina = 60.0
			var expected: Array = []
			for j in 3: expected.append(Vector2(origin+launch[3]+100*j,launch[4]))
			var picked: Array = []
			var contacts := 0
			var calms := 0
			var gates := 0
			var furthest: float = model.p.x
			var retreat := 0.0
			var launch_seen := false
			var after_dash := 0.0
			for frame in 600:
				model.events.clear()
				# Aim, hold Space for 0.45 s, release, then fly forward continuously.
				model.step(Vector2.ZERO if frame in range(1,28) else Vector2.RIGHT,frame in range(1,28),1.0/60)
				launch_seen = launch_seen or model.bursts > 0
				if launch_seen and model.burst_left <= 0: after_dash += 1.0/60
				furthest = maxf(furthest,model.p.x)
				retreat = maxf(retreat,furthest-model.p.x)
				for event in model.events:
					if event.kind in ["blocked","hit"]: contacts += 1
					if event.kind == "flower_calm": calms += 1
					if event.kind == "gate": gates += 1
					if event.kind == "dew" and event.pos in expected: picked.append(event.pos)
				if (picked.size() == 3 and after_dash >= 0.5) or model.p.x > expected.back().x+100 or model.recoveries > 0: break
			var label := "scene=%d launch=%d offset=%d" % [launch[0],launch[1],offset]
			check.call(launch_seen and contacts == 0 and model.recoveries == 0,"A committed dash has a clear exit: "+label)
			check.call(picked.size() == 3 and retreat < 1,"Dash collects the whole forward ribbon without turning back: "+label)
			if [launch[0],launch[1]] in [[1,850],[3,2800],[8,4940]]: check.call(calms == 1,"One meaningful flower precedes the next distinct approach: "+label)
			if [launch[0],launch[1]] in [[1,2800],[8,6490]]: check.call(gates == 1,"Parkour dash opens its curtain before the collection line: "+label)
			if contacts > 0 or picked.size() != 3: print("EIGHT_EXIT_FAILURE: "+JSON.stringify({"case":label,"contacts":contacts,"picked":picked.size(),"pos":str(model.p),"after_dash":after_dash}))
	print("EIGHT_DASH_EXITS: 15 launches x 3 release positions")

static func resource_routes(check: Callable) -> void:
	for alternate in [false,true]:
		var model := Model.new()
		model.load_stage(1)
		var driver := Driver.new(model,alternate)
		driver.wait_for_full = false
		var first_leaf := -1.0
		var first_leaf_stamina := 100.0
		var minimum := 100.0
		var waste := 0.0
		var contacts := 0
		var retreat := 0.0
		var furthest := model.p.x
		var scene_entries := {0:0.0}
		var previous_scene := 0
		var final_leaf := -1.0
		var previewed := {4:false,7:false}
		for frame in 60000:
			if model.phase != "playing" or model.recoveries > 0: break
			var input: Dictionary = driver.next_input()
			if not driver.error.is_empty(): break
			model.events.clear()
			model.step(input.direction,input.held,1.0/60)
			minimum = minf(minimum,model.stamina)
			var current_scene: int = model.encounter_index()
			if current_scene != previous_scene:
				scene_entries[current_scene] = model.time
				previous_scene = current_scene
			if current_scene in previewed:
				var garden: Dictionary = model.chapter.encounters[current_scene]
				if model.p.x > lerpf(garden.start_x,garden.end_x,0.75):
					for jet in model.jets:
						if jet.rect.position.x > model.p.x and jet.rect.end.x < model.camera_x+1240:
							previewed[current_scene] = true
			furthest = maxf(furthest,model.p.x)
			retreat = maxf(retreat,furthest-model.p.x)
			for event in model.events:
				if event.kind == "checkpoint": final_leaf = model.time
				if event.kind == "checkpoint" and first_leaf < 0:
					first_leaf = model.time
					first_leaf_stamina = model.stamina
				if event.kind == "dew": waste += 4.0-float(event.reward)
				if event.kind in ["blocked","hit","tired"]: contacts += 1
		check.call(model.phase == "transition" and model.stage == 1 and contacts == 0 and model.recoveries == 0 and driver.error.is_empty(),"08 action and bypass routes complete without enforced damage, exhaustion or full-rest waiting")
		check.call(first_leaf > 20 and first_leaf_stamina < 75,"The first leaf follows meaningful action and spending, not the opening")
		# The bypass spends no dash energy. Removing empty flight must not be
		# compensated by forced travel merely to match its old 35-point minimum.
		check.call(minimum >= 12 and minimum < (60 if alternate else 45),"08 routes spend stamina and retain one sneeze of reserve; bypass preserves its cheaper choice")
		for scene_index in [4,7]:
			var duration: float = scene_entries.get(scene_index+1,INF)-scene_entries.get(scene_index,0.0)
			check.call(duration > 0 and duration < 4.5,"A short breather reconnects to the next action within 4.5 seconds: scene=%d" % scene_index)
			check.call(previewed[scene_index],"The next water challenge is in the actual camera before leaving its approach: scene=%d" % scene_index)
		check.call(final_leaf > 0 and model.time-final_leaf < 8,"The final recovery leads directly to the farewell and exit")
		check.call(model.garden_awards[1] == model.dew.size() and retreat < 32,"Every collection line lies on both complete forward routes")
		check.call(waste < 0.01,"08 drops replenish actual spent stamina instead of overflowing a full meter")
		print("EIGHT_RESOURCES: "+JSON.stringify({"alternate":alternate,"minimum":minimum,"first_leaf":first_leaf,"first_leaf_stamina":first_leaf_stamina,"collected":model.garden_awards[1],"total":model.dew.size(),"wasted":waste,"seconds":model.time,"retreat":retreat,"scene_entries":scene_entries,"farewell_seconds":model.time-final_leaf}))

static func suspend_action(check: Callable) -> void:
	for mode in ["spray","calm"]:
		var model := Model.new()
		model.load_stage(1)
		model.p = model.sprayers[0].pos-Vector2(700 if mode == "spray" else 350,0)
		var seen := false
		for frame in 360:
			model.events.clear()
			var held: bool = mode == "calm" and frame in range(1,28)
			model.step(Vector2.ZERO if held else Vector2.RIGHT,held,1.0/60)
			if model.events.any(func(event): return event.kind == ("spray" if mode == "spray" else "flower_calm")):
				seen = true
				break
		check.call(seen,"Create a live attack/extended-dash state through inputs: "+mode)
		var saved := model.save_payload()
		var restored := Model.new()
		check.call(restored.restore_payload(JSON.parse_string(JSON.stringify(saved,"",true,true))),"08 active attack and extended dash can suspend: "+mode)
		for frame in 20:
			model.step(Vector2.RIGHT,false,1.0/60)
			restored.step(Vector2.RIGHT,false,1.0/60)
		check.call(JSON.stringify(restored.save_payload(),"",true,true) == JSON.stringify(model.save_payload(),"",true,true),"08 resume preserves attack timing, projectiles, dash continuation and rewards: "+mode)
