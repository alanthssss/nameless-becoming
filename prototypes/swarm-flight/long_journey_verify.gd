extends SceneTree
const Model = preload("res://long_journey_model.gd")
const Driver = preload("res://route_driver.gd")
const Save = preload("res://save_data.gd")
const Supply = preload("res://long_supply_contract.gd")
var checks := 0
var failures := 0

func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+label)

func _initialize() -> void:
	call_deferred("run")

func roundtrip(model,label: String) -> void:
	var raw: Dictionary = JSON.parse_string(JSON.stringify(model.save_payload(),"",true,true))
	var restored := Model.new()
	if not restored.restore_payload(raw):
		check(false,"restore "+label)
		return
	check(JSON.stringify(restored.save_payload(),"",true,true) == JSON.stringify(model.save_payload(),"",true,true),"exact live state "+label)
	# A frozen save consumes no offline time; identical next input is deterministic.
	for i in 8:
		model.step(Vector2.RIGHT,true,1.0/60.0)
		restored.step(Vector2.RIGHT,true,1.0/60.0)
	check(JSON.stringify(restored.save_payload(),"",true,true) == JSON.stringify(model.save_payload(),"",true,true),"deterministic resumed physics "+label)
	model.restore_payload(raw)

func run() -> void:
	if "--seven-flow-only" in OS.get_cmdline_user_args():
		preload("res://seven_flow_contract.gd").run(check)
		print("SEVEN FLOW VERIFIED: %d checks, %d failures" % [checks,failures])
		quit(0 if failures == 0 else 1)
		return
	if "--eight-rhythm-only" in OS.get_cmdline_user_args():
		preload("res://eight_rhythm_contract.gd").run(check)
		print("EIGHT RHYTHM VERIFIED: %d checks, %d failures" % [checks,failures])
		quit(0 if failures == 0 else 1)
		return
	if "--nine-choice-only" in OS.get_cmdline_user_args():
		preload("res://nine_choice_contract.gd").run(check)
		print("NINE CHOICE VERIFIED: %d checks, %d failures" % [checks,failures])
		quit(0 if failures == 0 else 1)
		return
	Supply.run(check)
	if "--long-supply-only" in OS.get_cmdline_user_args():
		print("LONG SUPPLY CHECKS: %d, failures %d" % [checks,failures])
		quit(0 if failures == 0 else 1)
		return
	preload("res://eight_rhythm_contract.gd").run(check)
	preload("res://seven_flow_contract.gd").run(check)
	preload("res://nine_choice_contract.gd").run(check)
	checkpoint_flow()
	ordinary_flight()
	for alternate in [false,true]:
		var model := Model.new()
		var driver := Driver.new(model,alternate)
		driver.wait_for_full = false
		var sampled := {}
		var metrics := {"blocked":0,"hit":0,"min_stamina":100.0,"retreat":0.0,"furthest":180.0}
		var summaries: Array = []
		var last_beat := -1
		for frame in 180000:
			if model.phase == "transition":
				print("PACING_METRICS: "+JSON.stringify({"stage":model.stage+7,"alternate":alternate,"metrics":metrics,"beats":summaries}))
				check(model.recoveries == 0,"Chapter %d has no forced recovery" % (model.stage+7))
				check(metrics.blocked == 0,"Chapter %d authored paths clear visible geometry" % (model.stage+7))
				check(metrics.hit == 0,"Chapter %d authored paths avoid damage" % (model.stage+7))
				print("LONG_ROUTE: %02d alternate=%s seconds=%.2f recoveries=%d checkpoints=%d" % [model.stage+7,alternate,model.time,model.recoveries,model.completed_sections()])
				roundtrip(model,"%02d arrival" % (model.stage+7))
				model.load_stage(model.stage+1)
				metrics = {"blocked":0,"hit":0,"min_stamina":100.0,"retreat":0.0,"furthest":180.0}
				summaries.clear()
				last_beat = -1
			if model.phase == "ending": break
			var command: Dictionary = driver.next_input()
			if not driver.error.is_empty():
				check(false,driver.error)
				break
			model.events.clear()
			model.step(command.direction,command.held,1.0/60.0)
			metrics.min_stamina = minf(metrics.min_stamina,model.stamina)
			metrics.furthest = maxf(metrics.furthest,model.p.x)
			metrics.retreat = maxf(metrics.retreat,metrics.furthest-model.p.x)
			for event in model.events:
				if event.kind in ["blocked","hit"]:
					metrics[event.kind] += 1
					print("PATH_CONTACT: "+JSON.stringify({"stage":model.stage+7,"alternate":alternate,"beat":model.encounter_index(),"command":driver.cursor,"event":event,"pos":str(model.p)}))
			if model.encounter_index() != last_beat:
				last_beat = model.encounter_index()
				summaries.append({"beat":last_beat,"time":model.time,"stamina":model.stamina,"name":model.encounter_name()})
			var label := "%s:%s" % [model.stage,model.encounter_index()]
			if not sampled.has(label) and model.started and model.time > 1:
				sampled[label] = true
				roundtrip(model,label)
			if frame%6000 == 0: print("ROUTE_PROGRESS: %s stage=%d x=%.0f command=%d" % [alternate,model.stage+7,model.p.x,driver.cursor])
		check(model.phase == "ending","all sample chapters finish via ordinary inputs, alternate=%s" % alternate)
		print("PACING_METRICS: "+JSON.stringify({"stage":model.stage+7,"alternate":alternate,"metrics":metrics,"beats":summaries}))
		check(model.recoveries == 0,"Final sample chapter has no forced recovery")
		check(metrics.blocked == 0,"Final sample chapter paths clear visible geometry")
		check(metrics.hit == 0,"Final sample chapter paths avoid damage")
		print("LONG_ROUTE: %02d alternate=%s seconds=%.2f recoveries=%d checkpoints=%d" % [model.stage+7,alternate,model.time,model.recoveries,model.completed_sections()])
		roundtrip(model,"09 ending")
	var probe := Model.new()
	for i in 30: probe.step(Vector2.RIGHT,true,1.0/60.0)
	roundtrip(probe,"held charge")
	probe.step(Vector2.RIGHT,false,1.0/60.0)
	roundtrip(probe,"mid burst")
	var valid := probe.save_payload()
	var before := JSON.stringify(valid)
	for key in ["journey_id","stage","rng_state","completed","state"]:
		var bad := valid.duplicate(true)
		bad[key] = "invalid"
		check(not probe.restore_payload(bad),"reject malformed "+key)
		check(JSON.stringify(probe.save_payload()) == before,"invalid file cannot mutate "+key)
	var geometry := valid.duplicate(true)
	geometry.state.walls[0].rect.r[0] += 1
	check(not probe.restore_payload(geometry),"reject edited geometry")
	check(not Save.write_payload(valid,"/nonexistent/swarm-save.json",Model.new()),"write failure reported")
	probe.restore_checkpoint()
	check(probe.p == probe.checkpoint.p and probe.stamina == Model.MAX_STAMINA,"failure rollback distinct from suspend")
	print("LONG JOURNEY VERIFIED: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)

func checkpoint_flow() -> void:
	for stage in Model.new().last_stage_index()+1:
		var model := Model.new()
		model.load_stage(stage)
		var safe: Vector2 = model.shelters[0].pos
		# Explicit boundary fixture, followed only by ordinary inputs. Passing
		# above a leaf must record progress without a mandatory detour or refill.
		model.p = Vector2(safe.x-40,150)
		model.stamina = 60.0
		var before: float = model.stamina
		for frame in 30: model.step(Vector2.RIGHT,false,1.0/60)
		check(model.checkpoint_index == 0,"Passing the checkpoint station preserves continuous flight")
		check(model.p.y < safe.y-100 and model.stamina < before,"Checkpoint crossing does not teleport or remotely refill")
		check(model.checkpoint.p == safe,"Failure returns to the safe leaf, not a midair crossing")
		roundtrip(model,"passing checkpoint")
		model.restore_checkpoint()
		check(model.p == safe and model.stamina == 100,"Passing checkpoint still gives safe failure recovery")
		for leaf in model.shelters:
			check(not model.walls.any(func(obstacle): return obstacle.rect.grow(16).has_point(leaf.pos)),"Every recovery point is clear of solid geometry")
		check(model.sections.size() == model.shelters.size(),"Quiet ending does not create an unreachable recovery section")
		check(not model.chapter.sprayers.is_empty() if stage == 1 else model.chapter.sprayers.is_empty(),"Spatial flight and 08 breathing hazards have distinct roles")

func ordinary_flight() -> void:
	for stage in Model.new().last_stage_index()+1:
		var model := Model.new()
		model.load_stage(stage)
		var driver := Driver.new(model,true)
		driver.wait_for_full = false
		driver.stage = stage
		# Keep the authored alternate geometry, omit only Space inputs. This
		# checks that low-energy players can still choose ordinary flight.
		driver.commands = model.chapter.optional_route.filter(func(c): return c.kind != "burst")
		var minimum := 100.0
		var contacts := 0
		for frame in 60000:
			if model.phase != "playing" or model.recoveries > 0: break
			var input: Dictionary = driver.next_input()
			if not driver.error.is_empty(): break
			model.events.clear()
			model.step(input.direction,input.held,1.0/60)
			minimum = minf(minimum,model.stamina)
			for event in model.events:
				if event.kind in ["blocked","hit"]: contacts += 1
		check(model.phase != "playing" and driver.error.is_empty(),"Both gardens allow ordinary flight without mandatory bursts")
		check(model.bursts == 0 and model.recoveries == 0 and contacts == 0,"Ordinary flight needs no collision, damage or recovery")
		print("ORDINARY_ROUTE: "+JSON.stringify({"stage":stage+7,"seconds":model.time,"minimum_stamina":minimum,"contacts":contacts,"recoveries":model.recoveries,"error":driver.error}))
