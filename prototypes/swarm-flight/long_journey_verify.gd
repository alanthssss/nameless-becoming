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
	Supply.run(check)
	if "--long-supply-only" in OS.get_cmdline_user_args():
		print("LONG SUPPLY CHECKS: %d, failures %d" % [checks,failures])
		quit(0 if failures == 0 else 1)
		return
	for alternate in [false,true]:
		var model := Model.new()
		var driver := Driver.new(model,alternate)
		driver.wait_for_full = false
		var sampled := {}
		for frame in 180000:
			if model.phase == "transition":
				print("LONG_ROUTE: 07 alternate=%s seconds=%.2f recoveries=%d checkpoints=%d" % [alternate,model.time,model.recoveries,model.completed_sections()])
				roundtrip(model,"07 arrival")
				model.load_stage(1)
			if model.phase == "ending": break
			var command: Dictionary = driver.next_input()
			if not driver.error.is_empty():
				check(false,driver.error)
				break
			model.step(command.direction,command.held,1.0/60.0)
			var label := "%s:%s" % [model.stage,model.encounter_index()]
			if not sampled.has(label) and model.started and model.time > 1:
				sampled[label] = true
				roundtrip(model,label)
			if frame%6000 == 0: print("ROUTE_PROGRESS: %s stage=%d x=%.0f command=%d" % [alternate,model.stage+7,model.p.x,driver.cursor])
		check(model.phase == "ending","both long chapters finish via ordinary inputs, alternate=%s" % alternate)
		print("LONG_ROUTE: 08 alternate=%s seconds=%.2f recoveries=%d checkpoints=%d" % [alternate,model.time,model.recoveries,model.completed_sections()])
		roundtrip(model,"08 ending")
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
