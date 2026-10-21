extends SceneTree
const Model = preload("res://game_model.gd")
const Save = preload("res://save_data.gd")
const Data = preload("res://chapter_data.gd")
const Driver = preload("res://route_driver.gd")
var checks := 0
var failures: Array[String] = []
var m

func _initialize() -> void:
	call_deferred("run")

func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func has_event(kind: String) -> bool:
	for event in m.events:
		if event.kind == kind: return true
	return false

func control_fixture() -> RefCounted:
	# An empty exposed lane isolates input response from authored collisions,
	# pickups and rain. Full routes below exercise the untouched level layouts.
	var sample = Model.new()
	sample.load_stage(1)
	sample.walls.clear()
	sample.pods.clear()
	sample.rings.clear()
	sample.sprayers.clear()
	sample.dew.clear()
	sample.rain_timer = 999.0
	sample.world_width = 10000.0
	sample.exit_pos = Vector2(9900,420)
	return sample

func launch_measure(hold_seconds: float) -> Dictionary:
	var sample = control_fixture()
	for i in int(round(hold_seconds*100)):
		sample.step(Vector2.ZERO,true,0.01)
	var origin: Vector2 = sample.p
	sample.step(Vector2.ZERO,false,1.0/120.0)
	var launch_direction: Vector2 = sample.face
	var burst_frames := 1
	while sample.burst_left > 0 and burst_frames < 120:
		sample.step(Vector2.ZERO,false,1.0/120.0)
		burst_frames += 1
	var burst_end: Vector2 = sample.p
	var brake_frames := 0
	while not sample.velocity.is_zero_approx() and brake_frames < 120:
		sample.step(Vector2.ZERO,false,1.0/120.0)
		brake_frames += 1
	return {"distance":origin.distance_to(burst_end),"tail":burst_end.distance_to(sample.p),"brake_seconds":brake_frames/120.0,"burst_seconds":burst_frames/120.0,"direction":launch_direction,"bursts":sample.bursts,"stopped":sample.velocity.is_zero_approx()}

func controls_contract() -> void:
	var sample = control_fixture()
	for i in 60: sample.step(Vector2.RIGHT,false,1.0/120.0)
	var release_pos: Vector2 = sample.p
	var stop_frames := 0
	while not sample.velocity.is_zero_approx() and stop_frames < 120:
		sample.step(Vector2.ZERO,false,1.0/120.0)
		stop_frames += 1
	var drift := release_pos.distance_to(sample.p)
	expect(sample.velocity.is_zero_approx() and stop_frames/120.0 <= 0.10,"Releasing cruise controls stops within one tenth of a second")
	expect(drift <= 20.0,"Cruise release travels at most twenty pixels before stopping")
	var rest: Vector2 = sample.p
	for i in 120: sample.step(Vector2.ZERO,false,1.0/120.0)
	expect(sample.p == rest,"Exposed idle flight has no hidden wind drift after releasing controls")
	for i in 120: sample.step(Vector2.ZERO,true,1.0/120.0)
	expect(sample.p == rest and sample.face == Vector2.RIGHT,"Stationary charging keeps both aim and position until directional input")
	sample.step(Vector2.DOWN,true,0.1)
	expect(sample.face == Vector2.DOWN and absf(sample.velocity.length()-90.0)<0.001 and absf(sample.velocity.x)<0.001,"Charging allows deliberate ninety-pixel-per-second aiming without wind")
	sample.step(Vector2.ZERO,false,1.0/120.0)
	sample.step(Vector2.LEFT,false,1.0/120.0)
	expect(sample.face == Vector2.DOWN and sample.velocity.x == 0 and sample.velocity.y > 0,"Released burst keeps the last displayed aim instead of following later steering")
	var ready := launch_measure(0.40)
	var full := launch_measure(1.00)
	sample = control_fixture()
	for i in 48: sample.step(Vector2.ZERO,true,1.0/120.0)
	expect(sample.charge >= Model.CHARGE_READY,"A four-tenths-second charge is ready at the actual 120Hz simulation step")
	expect(ready.bursts == 1 and full.bursts == 1,"Both a ready charge and a long-held charge launch exactly once")
	expect(absf(ready.distance-full.distance)<0.001 and absf(ready.burst_seconds-full.burst_seconds)<0.001,"Holding past ready never secretly changes burst reach or duration")
	expect(ready.stopped and ready.tail < 20.0 and ready.brake_seconds <= 0.10,"Burst ends with less than twenty pixels of tail travel and immediate control recovery")
	sample = control_fixture()
	for i in 39: sample.step(Vector2.ZERO,true,0.01)
	sample.step(Vector2.ZERO,false,1.0/120.0)
	expect(sample.bursts == 0 and not sample.charging,"Release just before the four-tenths ready threshold does not launch")
	var cancelled := false
	for event in sample.events:
		if event.kind == "charge_cancel": cancelled = true
	expect(cancelled,"An early release still explains why no burst occurred")
	print("CONTROL RESPONSE: %s" % JSON.stringify({"cruise_stop_seconds":stop_frames/120.0,"cruise_tail_px":snappedf(drift,0.01),"ready_at_seconds":0.40,"burst_distance_px":snappedf(ready.distance,0.01),"burst_tail_px":snappedf(ready.tail,0.01),"burst_stop_seconds":ready.brake_seconds}))
	# A deliberately large input frame must end exactly at the restored state,
	# even when directions and Space were held as exhaustion/timeout occurred.
	for reason in ["exhaustion","timeout","rain","sneeze"]:
		m = Model.new()
		m.load_stage(2 if reason == "timeout" else 1 if reason == "rain" else 0)
		if reason == "rain": m.bees = 3
		m.p = Vector2(500,420)
		m.save_checkpoint()
		m.p = Vector2(600,420)
		m.invulnerable = 0
		if reason == "timeout": m.rain_remaining = 0.001
		else: m.spend_energy(m.stamina-0.01)
		if reason == "rain": m.drops.assign([{"pos":m.p,"vel":Vector2.ZERO}])
		if reason == "sneeze": m.puffs.assign([{"pos":m.p,"vel":Vector2.ZERO,"life":1.0,"source":0}])
		# Hits need enough energy to reach their damage check before exhaustion.
		if reason in ["rain","sneeze"]: m.gain_energy(0.99)
		m.step(Vector2.RIGHT,true,0.1)
		expect(m.recoveries == 1 and m.p == m.checkpoint.p and m.velocity == Vector2.ZERO,"Recovery ends all remaining movement substeps: " + reason)
		expect(not m.started and not m.charging and m.charge == 0 and m.stamina == 100,"Recovery remains safe and fully refilled until a new input frame: " + reason)
		m.step(Vector2.ZERO,false,0.1)
		expect(not m.started and m.p == m.checkpoint.p and m.stamina == 100,"Cleared UI input can hold the recovery position safely: " + reason)

func authored_content() -> void:
	var names: Array[String] = []
	for stage in Model.STAGE_COUNT:
		m = Model.new()
		m.load_stage(stage)
		expect(m.sections.size() == 7 and m.world_width >= 15000,"Each chapter has seven authored encounters and a complete world")
		expect(m.theme_index() == stage and m.music_index() in [0,1,2],"Chapter presentation is data driven")
		expect(m.dew.size() == 7 and m.shelters.size() == 7,"Each encounter has an optional dew and safe checkpoint")
		for section in m.sections:
			expect(not names.has(section.name),"Encounter names are distinct: "+section.name)
			names.append(section.name)
		for wall in m.walls:
			expect(wall.rect.size.x > 0 and wall.rect.size.y > 0,"Authored obstacle has positive extents")
		for i in m.rings.size():
			var point: Vector2 = m.rings[i].pos-Vector2(60,0)
			var direction: Vector2 = m.ring_direction(i)
			var clear := true
			for sample in 66:
				var at: Vector2 = point+direction*sample*8.0
				for wall in m.walls:
					if wall.kind == "stem" and wall.rect.grow(14).has_point(at): clear = false
			expect(clear,"Advertised wind landing clears solid stems")
		expect(not m.exit_ready,"A whole chapter cannot finish before its required checkpoints")

func chapter_routes(collect_optional: bool) -> void:
	m = Model.new()
	m.reset_journey()
	var driver = Driver.new(m,collect_optional)
	var route_time := 0.0
	var frames := 0
	var prior_checkpoint := -1
	var rings_this_launch := 0
	var chain_max := 0
	while m.phase != "ending" and frames < 108000:
		if m.phase == "transition":
			if m.stage == 1:
				expect(chain_max >= 3,"Flower bridge contains a real three-flower chain from one launch")
				var branch_rings: Array = m.rings.filter(func(item): return item.get("section",-1) == 3)
				expect(branch_rings.all(func(item): return not item.active) if collect_optional else branch_rings.all(func(item): return item.active),"The same bridge admits a wind shortcut and a no-wind steady route")
			report_stage(collect_optional)
			route_time += m.time
			m.load_stage(m.stage+1)
			prior_checkpoint = -1
			rings_this_launch = 0
			chain_max = 0
		var action: Dictionary = driver.next_input()
		if not action.error.is_empty():
			failures.append("Full route: "+action.error)
			break
		m.step(action.direction,action.held,1.0/60.0)
		frames += 1
		if m.checkpoint_index != prior_checkpoint:
			prior_checkpoint = m.checkpoint_index
			var payload: Dictionary = m.save_payload()
			var clone = Model.new()
			var decoded = JSON.parse_string(JSON.stringify(payload))
			expect(clone.restore_payload(decoded),"Reached checkpoint serializes and restores on the actual route")
			expect(clone.p == m.checkpoint.p and clone.bees == m.checkpoint.bees and not clone.started,"Checkpoint resume is safe and preserves the real rescued group")
		for event in m.events:
			if event.kind == "burst": rings_this_launch = 0
			elif event.kind == "ring":
				rings_this_launch += 1
				chain_max = maxi(chain_max,rings_this_launch)
		m.events.clear()
	if m.phase == "ending":
		expect(chain_max >= 3,"Final chapter combines a real continuous flower chain with the homeward route")
		report_stage(collect_optional)
		route_time += m.time
	expect(m.phase == "ending" and m.stage == 3 and m.bees == 9,"Known-answer input route completes all four chapters with the whole group")
	if collect_optional: expect(m.garden_total() == m.journey_dew_total(),"Optional input route collects all twenty-eight dew without teleportation")
	var restored = Model.new()
	expect(restored.restore_payload(m.save_payload()) and restored.phase == "ending","Completed save resumes at the ending rather than replaying the long final chapter")
	print("CHAPTER ROUTE: %s" % JSON.stringify({"scenario":"all-dew" if collect_optional else "direct","seconds":snappedf(route_time,0.01),"frames":frames,"recoveries":m.recoveries,"dew":m.garden_total(),"completed":m.phase=="ending"}))

func report_stage(optional: bool) -> void:
	expect(m.completed_sections() == 7,"Completed chapter visited every required safe leaf")
	expect(absf(m.stamina-(100+m.energy_gained-m.energy_spent))<0.001,"Whole chapter conserves the capped stamina ledger")
	if optional: expect(m.garden_awards[m.stage] == 7,"Optional route reaches all dew in this chapter")
	print("BALANCE: %s" % JSON.stringify({"stage":m.stage,"route":m.chapter_title(),"scenario":"all-dew" if optional else "direct","seconds":snappedf(m.time,0.01),"stamina":snappedf(m.stamina,0.01),"spent":snappedf(m.energy_spent,0.01),"gained":snappedf(m.energy_gained,0.01),"storm_remaining":snappedf(m.rain_remaining,0.01),"recoveries":m.recoveries,"dew":m.garden_awards[m.stage]}))

func checkpoints_and_resources() -> void:
	m = Model.new()
	expect(not m.gate_ready(m.walls.filter(func(item): return item.has("needs_section"))[0]),"The first exit curtain waits for the local companions")
	m.p = m.shelters[1].pos
	m.advance_shelters()
	expect(m.checkpoint_index == -1,"Skipping ahead cannot bypass the ordered checkpoints")
	m.p = m.shelters[0].pos
	m.advance_shelters()
	expect(m.checkpoint_index == -1,"A leaf cannot certify a missed local rescue")
	for pod in m.pods:
		if pod.section == 0: pod.open = true; m.bees += int(pod.count)
	m.advance_shelters()
	expect(m.checkpoint_index == 0 and m.checkpoint.p == m.shelters[0].pos,"Cleared encounter records its safe leaf")
	var first: Vector2 = m.checkpoint.p
	m.p = m.pods[1].pos
	m.burst_left = 0.3
	m.step(Vector2.ZERO,false,1.0/120.0)
	expect(m.checkpoint.p == first and m.checkpoint.bees == m.bees,"Rescue saves new companions without moving recovery into danger")
	m.load_stage(2)
	m.rain_remaining = 0.5
	m.p = m.shelters[0].pos
	m.advance_shelters()
	expect(m.rain_remaining == m.sections[1].budget,"A fresh leaf resets the next exposed section's rain budget")
	m.p = m.shelters[1].pos
	m.advance_shelters()
	var latest: Vector2 = m.checkpoint.p
	m.p = m.shelters[0].pos
	m.advance_shelters()
	expect(m.checkpoint_index == 1 and m.checkpoint.p == latest,"Revisiting old shelter never rolls checkpoint progress backwards")
	m.spend_energy(70)
	m.started = true
	var clock: float = m.rain_remaining
	for i in 120: m.step(Vector2.ZERO,false,1.0/60.0)
	expect(absf(m.stamina-78)<0.01 and m.rain_remaining == clock,"Two seconds of leaf rest restore 48 energy and freeze rain")
	m = control_fixture()
	m.step(Vector2.RIGHT,false,1.0/60.0)
	for i in 299: m.step(Vector2.ZERO,false,1.0/60.0)
	expect(absf(m.stamina-90)<0.01,"Five exposed seconds retain the original ten-energy drain")
	m = control_fixture()
	m.spend_energy(81)
	for i in 30: m.step(Vector2.ZERO,true,1.0/60.0)
	m.step(Vector2.ZERO,false,1.0/60.0)
	expect(m.bursts == 0 and has_event("tired"),"Less than twenty energy refuses an unaffordable burst")

func collision_and_garden() -> void:
	m = control_fixture()
	m.walls.assign([m.wall(500,80,45,650)])
	m.p = Vector2(475,420)
	m.face = Vector2.RIGHT
	m.burst_left = 0.54
	m.step(Vector2.RIGHT,false,0.1)
	expect(m.p.x < 500 and has_event("blocked"),"Substeps stop a full-speed burst at a solid stem")
	m.walls[0].kind = "curtain"
	m.burst_left = 0.54
	m.step(Vector2.RIGHT,false,0.1)
	expect(m.walls[0].broken and has_event("gate"),"The same burst opens a breakable curtain")
	m = Model.new()
	m.spend_energy(60)
	m.p = m.dew[0].pos
	m.advance_garden(0)
	expect(m.stamina == 52 and m.garden_total() == 1,"Optional dew restores twelve once")
	m.advance_garden(0)
	expect(m.stamina == 52 and m.garden_total() == 1,"Collected dew cannot be farmed")
	m.save_checkpoint()
	m.p = m.dew[1].pos
	m.advance_garden(0)
	m.restore_checkpoint()
	expect(m.garden_total() == 1 and not m.dew[1].collected,"Unsaved dew follows checkpoint rollback")
	m.p = m.sprayers[0].pos-Vector2(100,0)
	m.started = true
	m.sprayers[0].timer = 0.79
	expect(m.sprayer_phase(0) == "warning","Sneeze flower still warns before its water fan")
	m.advance_garden(0.8)
	expect(m.puffs.size() == 3,"One sneeze creates three water particles")
	m.p = m.sprayers[0].pos
	m.burst_left = 0.3
	m.advance_garden(0)
	expect(m.sprayer_phase(0) == "calm" and m.puffs.is_empty(),"Burst calms the flower and clears its own water")
	var reward_energy: float = m.stamina
	m.sprayers[0].stun_left = 0
	m.advance_garden(0)
	expect(m.stamina == reward_energy,"Repeated calming does not farm stamina")
	m.burst_left = 0
	m.invulnerable = 0
	m.hurt("sneeze",12)
	var after_hit: float = m.stamina
	m.hurt("sneeze",12)
	expect(m.stamina == after_hit,"Hit protection prevents a fan from dealing three simultaneous hits")

func solo_rescue_contract() -> void:
	# A saved rescue total is progress, never a second set of bodies or targets.
	m = control_fixture()
	m.bees = 9
	m.invulnerable = 0
	m.drops.assign([{"pos":m.p-Vector2(60,0),"vel":Vector2.ZERO}])
	m.advance_rain(0.0)
	expect(m.stamina == 100 and m.bees == 9,"Rain behind the solo player cannot hit departed companions")
	m.drops.assign([{"pos":m.p,"vel":Vector2.ZERO}])
	m.advance_rain(0.0)
	expect(m.stamina == 70 and m.bees == 9,"Rain hits only player stamina; rescued total cannot be lost")
	m = control_fixture()
	m.bees = 9
	m.walls.assign([m.wall(500,80,45,650)])
	m.p = Vector2(475,420)
	m.burst_left = 0.54
	m.face = Vector2.RIGHT
	m.step(Vector2.RIGHT,false,0.1)
	var rescued_stop: Vector2 = m.p
	m = control_fixture()
	m.walls.assign([m.wall(500,80,45,650)])
	m.p = Vector2(475,420)
	m.burst_left = 0.54
	m.face = Vector2.RIGHT
	m.step(Vector2.RIGHT,false,0.1)
	expect(m.p == rescued_stop,"Saved rescue total does not enlarge player collision")

func save_contract() -> void:
	m = Model.new()
	var payload: Dictionary = m.save_payload()
	payload["ui"] = {"played_seconds":42.5}
	var path := "user://swarm_chapter_verify_v2.json"
	expect(Save.PATH.ends_with("chapter_v2.json") and not Save.PATH.ends_with("v1.json"),"Chapter saves use a separate v2 path")
	expect(Save.write_payload(payload,path),"A new-run safe snapshot writes atomically")
	var loaded := Save.read_payload(path)
	expect(loaded.get("ui",{}).get("played_seconds") == 42.5 and m.restore_payload(loaded),"V2 preserves extra UI metadata and validates model fields")
	var bad_cases: Array = []
	for field in ["version","content_revision","stage","checkpoint_index","bees","bursts","recoveries","rings_hit"]:
		var bad := payload.duplicate(true)
		bad[field] = -3
		bad_cases.append(bad)
	for field in ["pods","walls","rings","dew","sprayers","garden_awards"]:
		var bad := payload.duplicate(true)
		bad[field] = ["invalid"]
		bad_cases.append(bad)
	for value in [-1,999,"soon",null]:
		var bad := payload.duplicate(true)
		bad["rain_remaining"] = value
		bad_cases.append(bad)
	var future := payload.duplicate(true)
	future.garden_awards[3] = 1
	bad_cases.append(future)
	var impossible := payload.duplicate(true)
	impossible.checkpoint_index = 0
	bad_cases.append(impossible)
	var false_ending := payload.duplicate(true)
	false_ending.completed = true
	bad_cases.append(false_ending)
	var stem_broken := payload.duplicate(true)
	stem_broken.walls[0] = true
	bad_cases.append(stem_broken)
	for bad in bad_cases:
		var before: Dictionary = m.save_payload()
		expect(not m.restore_payload(bad) and m.save_payload() == before,"Malformed save is rejected transactionally")
	expect(not Save.write_payload(false_ending,path) and Save.read_payload(path).stage == 0,"Invalid write cannot replace a valid save")
	for content in ["broken","[]",'{"version":1,"stage":2}']:
		var file := FileAccess.open(path,FileAccess.WRITE)
		file.store_string(content)
		file.close()
		expect(Save.read_payload(path).is_empty(),"Malformed and old-format saves are rejected")
	DirAccess.remove_absolute(path)

func chase_contract() -> void:
	for stage_index in [2,3]:
		m = Model.new()
		m.load_stage(stage_index)
		for section_index in m.sections.size():
			m.checkpoint_index = section_index-1
			expect(m.storm_speed() > 0 and m.storm_speed() < Model.CRUISE_SPEED,"Every chase beat remains slower than ordinary horizontal cruise")
		m.checkpoint_index = 2
		var pressure: float = m.storm_speed()
		m.checkpoint_index = 3
		expect(m.storm_speed() < pressure,"Wind pressure is followed by a slower breathing beat")
		m.started = true
		var old_front: float = m.storm_x
		var pace: float = m.storm_speed()
		m.advance_storm(1.0)
		expect(is_equal_approx(m.storm_x-old_front,pace),"Authored pace advances the actual storm front")
	m.load_stage(2)
	var idle_front: float = m.storm_x
	m.advance_storm(5.0)
	expect(m.storm_x == idle_front,"Rain waits for first input")
	m.p = m.shelters[0].pos
	m.advance_shelters()
	m.started = true
	m.spend_energy(50)
	var safe_front: float = m.storm_x
	var safe_budget: float = m.rain_remaining
	for i in 120: m.step(Vector2.ZERO,false,1.0/60.0)
	expect(m.storm_x == safe_front and m.rain_remaining == safe_budget and m.stamina > 97,"Earned leaf freezes chase and exposure while restoring stamina")
	m.p += Vector2(200,0)
	m.storm_x = m.p.x-40
	m.invulnerable = 0
	var energy: float = m.stamina
	m.advance_storm(0.0)
	expect(m.storm_gap() < 0 and is_equal_approx(energy-m.stamina,30.0) and has_event("hit"),"Crossing the visible front causes the original thirty-energy hit")
	m.spend_energy(m.stamina-1)
	m.invulnerable = 0
	m.advance_storm(0.0)
	expect(m.p == m.checkpoint.p and m.stamina == 100 and not m.started,"Lethal chase hit recovers at the earned leaf and waits for fresh input")
	m = control_fixture()
	for x in [400,850,1300]:
		m.rings.append({"pos":Vector2(x,420),"active":false,"direction":Vector2.RIGHT})
	for i in 48: m.step(Vector2.ZERO,true,1.0/120.0)
	for i in 360: m.step(Vector2.ZERO,false,1.0/120.0)
	var chain_events: Array[int] = []
	for event in m.events:
		if event.kind == "ring": chain_events.append(int(event.chain))
	expect(chain_events == [1,2,3] and m.bursts == 1,"One launch reports first, second and third wind in sequence")
	expect(m.wind_chain == 0,"Relay ends when the continuous dash ends")
	m.wind_chain = 3
	m.clear_input()
	expect(m.wind_chain == 0,"Pause or cleared input cannot retain a relay")
	m.wind_chain = 3
	m.restore_checkpoint()
	expect(m.wind_chain == 0,"Checkpoint recovery clears transient relay feedback")
	m.wind_chain = 3
	m.load_stage(0)
	expect(m.wind_chain == 0,"Loading a stage clears transient relay feedback")

func run() -> void:
	if "--chase-only" in OS.get_cmdline_user_args():
		chase_contract()
		for failure in failures: push_error(failure)
		if failures.is_empty(): print("CHASE VERIFIED: %d checks" % checks)
		quit(0 if failures.is_empty() else 1)
		return
	controls_contract()
	if "--controls-only" not in OS.get_cmdline_user_args():
		chase_contract()
		authored_content()
		checkpoints_and_resources()
		collision_and_garden()
		solo_rescue_contract()
		save_contract()
		chapter_routes(false)
		chapter_routes(true)
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("SWARM FLIGHT VERIFIED: %d checks, four authored chapters" % checks)
	quit(0 if failures.is_empty() else 1)
