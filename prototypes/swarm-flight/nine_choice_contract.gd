extends RefCounted
## 09 behavior contracts use ordinary direction/Space after explicit fixtures.
## These checks prove reachability and state rules, never player preference.
const Model = preload("res://long_journey_model.gd")
const Driver = preload("res://route_driver.gd")
const Data = preload("res://chapter_data.gd")

static func run(check: Callable) -> void:
	complete_routes(check)
	runouts(check)
	miss_and_reenter(check)
	low_supply(check)

static func nine():
	var model := Model.new()
	model.load_stage(2)
	return model

static func drive(model, commands: Array, limit := 12000) -> Dictionary:
	var driver := Driver.new(model)
	driver.stage = 2
	driver.commands = commands
	driver.wait_for_full = false
	var metrics := {"contacts":0,"minimum":model.stamina,"rings":0,"dew":0,"refund":0.0,"error":"","done":false,"high_y":-1.0,"window_y":-1.0}
	for frame in limit:
		if model.phase != "playing" or model.recoveries > 0 or driver.cursor >= commands.size(): break
		var input: Dictionary = driver.next_input()
		if not driver.error.is_empty(): break
		model.events.clear()
		model.step(input.direction,input.held,1.0/60.0)
		metrics.minimum = minf(metrics.minimum,model.stamina)
		if metrics.high_y < 0 and model.p.x >= 1400: metrics.high_y = model.p.y
		if metrics.window_y < 0 and model.p.x >= 1950: metrics.window_y = model.p.y
		for event in model.events:
			if event.kind in ["hit","blocked"]: metrics.contacts += 1
			if event.kind == "ring": metrics.rings += 1
			if event.kind == "dew":
				metrics.dew += 1
				metrics.refund += float(event.get("reward",0))
	metrics.error = driver.error
	metrics.done = model.phase != "playing" or driver.cursor >= commands.size()
	return metrics

static func complete_routes(check: Callable) -> void:
	for mode in ["wind","bypass","ordinary"]:
		var m = nine()
		var commands: Array = (m.chapter.route if mode == "wind" else m.chapter.optional_route).duplicate(true)
		if mode == "ordinary": commands = commands.filter(func(c): return c.kind != "burst")
		var metrics := drive(m,commands)
		check.call(m.phase == "ending" and metrics.error.is_empty(),"09 chosen route reaches the visible exit: "+mode)
		check.call(m.recoveries == 0 and metrics.contacts == 0,"09 chosen route needs no damage, collision or recovery: "+mode)
		check.call(metrics.dew == m.chapter.dew.size() and metrics.refund > 0,"09 both routes collect the same useful supply: "+mode)
		check.call(m.rings_hit == (9 if mode == "wind" else 0),"09 only chosen wind route consumes its nine flowers: "+mode)
		check.call(m.bursts == (3 if mode == "wind" else 0),"09 two opposed arcs require their own intentional launches: "+mode)
		if mode == "wind":
			check.call(metrics.window_y-metrics.high_y > 120,"09 high landing leads to an actual downward turn")
		else:
			check.call(metrics.high_y-metrics.window_y > 100,"09 ordinary low route leads to an actual upward turn")
		print("NINE_ROUTE: "+JSON.stringify({"mode":mode,"seconds":m.time,"metrics":metrics,"recoveries":m.recoveries,"rings":m.rings_hit,"bursts":m.bursts}))

static func runouts(check: Callable) -> void:
	# Explicit entrance boundaries; no route-driver forced brake after launch.
	for fixture in [[210,340,2530,440],[3930,540,5800,430],[6760,250,8630,420]]:
		for offset in [-35,0,35]:
			var m = nine()
			m.p = Vector2(fixture[0]+offset,fixture[1])
			m.stamina = 60.0
			var target := Vector2(fixture[2],fixture[3])
			var post := 0.0
			var contacts := 0
			var picked := false
			for frame in 1800:
				var held := frame in range(1,28)
				var direction := Vector2.RIGHT
				if held: direction = Vector2.ZERO
				elif post >= 0.6:
					var delta: Vector2 = target-m.p
					direction = Vector2(signf(delta.x) if absf(delta.x)>8 else 0,signf(delta.y) if absf(delta.y)>8 else 0).normalized()
				m.events.clear()
				m.step(direction,held,1.0/60)
				if m.bursts > 0 and m.burst_left <= 0: post += 1.0/60
				for event in m.events:
					if event.kind in ["hit","blocked"]: contacts += 1
					if event.kind == "dew" and event.pos == target: picked = true
				if picked or m.recoveries > 0: break
			var label := "launch=%d offset=%d" % [fixture[0],offset]
			check.call(picked and contacts == 0 and m.recoveries == 0,"09 forward runout leaves time for a safe manual turn: "+label)
			check.call(m.rings_hit == 3 and m.bursts == 1,"09 reasonable release positions preserve one three-flower action: "+label)
			if not picked or contacts > 0: print("NINE_RUNOUT_FAILURE: "+JSON.stringify({"case":label,"position":str(m.p),"rings":m.rings_hit,"contacts":contacts}))

static func miss_and_reenter(check: Callable) -> void:
	var m = nine()
	# Missing the first entry is an ordinary-flight boundary, not teleport recovery.
	m.p = Vector2(620,600)
	m.stamina = 40.0
	var commands := [Data.move_to(Vector2(1500,600)),Data.move_to(Vector2(1910,440)),Data.move_to(Vector2(2530,440))]
	var metrics := drive(m,commands)
	check.call(metrics.done and metrics.contacts == 0 and m.recoveries == 0 and metrics.dew == 1,"09 missed wind entry retains a safe supplied ordinary route")
	check.call(m.rings_hit == 0 and m.bursts == 0,"09 missing wind does not silently grant or require a relay")
	# Consume a real chain, fly back with ordinary controls, launch into used flowers.
	m = nine()
	m.p = Vector2(210,340)
	m.stamina = 70.0
	commands = [{"kind":"burst","direction":Vector2.RIGHT},Data.move_to(Vector2(1270,230)),Data.move_to(Vector2(1300,230)),Data.move_to(Vector2(1000,230)),Data.move_to(Vector2(500,230)),Data.move_to(Vector2(210,340))]
	metrics = drive(m,commands)
	if m.rings_hit != 3 or metrics.contacts > 0 or m.recoveries > 0: print("NINE_RETURN_FAILURE: "+JSON.stringify({"position":str(m.p),"rings":m.rings_hit,"metrics":metrics}))
	check.call(m.rings_hit == 3 and metrics.contacts == 0 and m.recoveries == 0,"09 return to used wind is reachable by ordinary controls")
	var before: int = m.rings_hit
	var rewards: float = m.energy_gained
	metrics = drive(m,[{"kind":"burst","direction":Vector2.RIGHT},Data.move_to(Vector2(550,340))])
	check.call(m.rings_hit == before and m.energy_gained == rewards,"09 reentering used flowers cannot repeat wind or reward")
	check.call(m.phase == "playing" and m.checkpoint_index == -1,"09 local backtrack neither skips the exit nor invents checkpoint progress")

static func low_supply(check: Callable) -> void:
	for fixture in [[180,420,0],[3780,420,1]]:
		var m = nine()
		m.p = Vector2(fixture[0],fixture[1])
		m.stamina = 40.0 # Explicit low-energy fixture, then ordinary input only.
		var commands: Array
		if fixture[2] == 0:
			commands = [Data.move_to(Vector2(350,600)),Data.move_to(Vector2(1500,600)),Data.move_to(Vector2(1910,440)),Data.move_to(Vector2(2530,440))]
		else:
			commands = [Data.move_to(Vector2(3950,540)),Data.move_to(Vector2(5060,540)),Data.move_to(Vector2(5800,430)),Data.move_to(Vector2(6020,430)),Data.move_to(Vector2(6070,350)),Data.move_to(Vector2(6800,350)),Data.move_to(Vector2(6860,600)),Data.move_to(Vector2(8220,600)),Data.move_to(Vector2(8630,420))]
		var metrics := drive(m,commands)
		check.call(metrics.done and metrics.contacts == 0 and m.recoveries == 0 and metrics.minimum > 0,"09 low-energy ordinary route reaches shared supply: "+str(fixture[2]))
		check.call(metrics.refund >= (12.0 if fixture[2] == 0 else 24.0),"09 shared supply restores useful energy on ordinary route: "+str(fixture[2]))
