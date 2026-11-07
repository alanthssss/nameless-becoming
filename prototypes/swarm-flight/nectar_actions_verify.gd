extends SceneTree
## SD-15 rule fixtures. Automated developer checks, never player acceptance.
const Model = preload("res://nectar_harvest_model.gd")
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+label)

func field():
	var m = Model.new()
	m.transition_to("pond")
	m.events.clear()
	return m

func flowers_fixture(twin := false):
	var m = field()
	m.p = Vector2(900,600)
	for flower in m.flowers: flower.pos = Vector2(1600,200)
	m.flowers[0].pos = Vector2(930,600)
	m.flowers[1].pos = Vector2(960,600)
	m.flowers[2].pos = Vector2(980,600)
	if twin: m.owned.assign(["gather1","gather2","reach","twin"])
	return m

func pulse_fixture(guard := false):
	var m = field()
	if guard:
		m.owned.assign(["gather1","bag1","wings1","meadow"])
		m.area = "meadow"
		m.visited_meadow = true
	var index := 1 if guard else 0
	m.creatures[index].pos += Vector2(100,0) # Clear-space action fixture.
	m.p = m.creatures[index].pos-Vector2(70,0)
	return m

func event_count(m,kind: String) -> int:
	var count := 0
	for event in m.events:
		if event.kind == kind: count += 1
	return count

func test_harvest_lock() -> void:
	var m = flowers_fixture()
	m.step(.1,Vector2.ZERO,true,false)
	check(m.harvesting_ids == ["blue_0"],"nearest flower begins collection")
	m.p = Vector2(965,600)
	m.step(.1,Vector2.ZERO,true,false)
	check(m.harvesting_ids == ["blue_0"] and m.flowers[1].progress == 0,"closer flower cannot steal an active target")
	var saved: float = m.flowers[0].progress
	m.step(.1,Vector2.ZERO,false,false)
	check(m.harvesting_ids.is_empty() and m.flowers[0].progress == saved,"release stops action and preserves partial nectar")
	m.step(.1,Vector2.ZERO,true,false)
	check(m.harvesting_ids == ["blue_1"],"press after release acquires the currently nearest flower")
	m.p = Vector2(1110,600)
	m.flowers[2].pos = Vector2(1100,600)
	m.step(.1,Vector2.ZERO,true,false)
	check(m.harvesting_ids == ["blue_2"],"out of range target releases and a vacant slot can acquire")
	m.flowers[2].progress = .99
	m.step(.1,Vector2.ZERO,true,false)
	check(m.cargo_total() == 1 and m.flowers[2].stock == 0,"a stable target completes exactly one nectar")
	m.step(.1,Vector2.ZERO,true,false)
	check(m.harvesting_ids.is_empty(),"empty target cannot remain active")

	var twin = flowers_fixture(true)
	twin.step(.1,Vector2.ZERO,true,false)
	check(twin.harvesting_ids == ["blue_0","blue_1"],"twin begins two targets in nearest order")
	twin.p = Vector2(981,600)
	twin.step(.1,Vector2.ZERO,true,false)
	check(twin.harvesting_ids == ["blue_0","blue_1"] and twin.flowers[2].progress == 0,"twin retains both begun flowers despite a closer third flower")
	twin.cargo.blue = 5
	twin.flowers[0].progress = .99
	twin.flowers[1].progress = .6
	twin.step(.1,Vector2.ZERO,true,false)
	check(twin.cargo_total() == 6 and twin.flowers[0].stock == 0,"last bag slot uses stable target order")
	check(twin.flowers[1].stock == 1 and twin.flowers[1].progress == .6,"last bag slot preserves the other flower's partial progress")
	var energy: float = twin.energy
	twin.step(.1,Vector2.ZERO,true,false)
	check(is_equal_approx(twin.energy,energy-.06) and twin.harvesting_ids.is_empty(),"full bag incurs only idle cost and cannot continue harvesting")
	var empty = field()
	empty.step(.1,Vector2.ZERO,true,false)
	check(is_equal_approx(empty.energy,35.94),"no flower incurs no harvesting cost")

func test_direction_and_growth() -> void:
	var m = pulse_fixture()
	var target: Dictionary = m.creatures[0]
	var energy: float = m.energy
	check(m.pulse_target(Vector2.LEFT).is_empty() and not m.pulse(Vector2.LEFT),"a target behind the aim cannot be hit")
	check(m.energy == energy and m.pulse_left == 0 and m.pulse_action_left == 0,"empty wing action has no resource or action cost")
	check(event_count(m,"pulse_empty") == 1,"empty wing action supplies one brief feedback event")
	target.pos = m.p+Vector2.RIGHT.rotated(deg_to_rad(60))*150
	check(m.pulse_target(Vector2.RIGHT) == target,"inclusive forward sector reaches 60 degrees and 150 pixels")
	target.pos = m.p+Vector2.RIGHT.rotated(deg_to_rad(60.1))*100
	check(m.pulse_target(Vector2.RIGHT).is_empty(),"outside the 120 degree sector is excluded")
	target.pos = m.p+Vector2(150.1,0)
	check(m.pulse_target(Vector2.RIGHT).is_empty(),"base range excludes targets beyond 150 pixels")
	m.owned.assign(["gather1","reach"])
	target.pos = m.p+Vector2(205,0)
	check(m.pulse_target(Vector2.RIGHT) == target and m.harvest_radius() == 155,"reach improves both actual action ranges")
	target.pos = m.p+Vector2(205.1,0)
	check(m.pulse_target(Vector2.RIGHT).is_empty(),"upgraded range excludes targets beyond 205 pixels")

	# Two eligible same-region creatures: one action must choose only the nearest.
	m.creatures[1].region = 0
	m.creatures[1].pos = m.p+Vector2(60,20)
	target.pos = m.p+Vector2(90,0)
	check(m.pulse(Vector2.RIGHT) and m.creatures[1].hits == 1 and target.hits == 0,"one wing action hits only the nearest forward target")
	check(m.energy == energy-2 and event_count(m,"pulse") == 1,"one valid action costs exactly two energy")
	var event: Dictionary = {}
	for item in m.events:
		if item.kind == "pulse": event = item
	check(event.to == m.p+Vector2(60,20) and event.direction == Vector2.RIGHT and event.strength == 1 and event.id == "mosquito_1","wing effect carries the actual pre-knockback target and strength")
	check(not m.pulse(Vector2.RIGHT) and event_count(m,"pulse") == 1,"same-frame call cannot duplicate hit or charge")

	for guard in [false,true]:
		for upgraded in [false,true]:
			var sample = pulse_fixture(guard)
			if upgraded:
				if "gather1" not in sample.owned: sample.owned.append("gather1")
				sample.owned.append("beat")
			var creature: Dictionary = sample.creatures[1 if guard else 0]
			var expected := (2 if guard else 1) if upgraded else (3 if guard else 2)
			for hit in expected:
				sample.pulse_left = 0 # Isolate integer hit thresholds from repeat timing.
				var previous_pos: Vector2 = creature.pos
				check(sample.pulse(creature.pos-sample.p),"threshold hit is valid")
				check(is_equal_approx(previous_pos.distance_to(creature.pos),24.0),"strength growth preserves the same 24 pixel knockback")
				if hit < expected-1: check(creature.state != "gone" and sample.drops.is_empty(),"partial hit loosens material without granting it")
			check(creature.state == "gone" and sample.drops.size() == 1,"base/upgraded target uses the specified 2→1 or 3→2 hits")
			check(sample.materials.fiber == 0 and sample.materials.resin == 0,"completion does not pre-credit materials")
			var drop: Dictionary = sample.drops[0]
			sample.p = drop.pos
			sample._pickup_drops(.299)
			check(sample.drops.size() == 1,"drop cannot be collected before 0.3 seconds")
			sample.p = drop.pos+Vector2(85.1,0)
			sample._pickup_drops(.01)
			check(sample.drops.size() == 1,"mature drop outside 85 pixels remains in the world")
			sample.p = drop.pos+Vector2(85,0)
			sample._pickup_drops(.01)
			check(sample.drops.is_empty() and sample.materials["resin" if guard else "fiber"] == (1 if guard else 2),"mature drop credits exact quantity at the inclusive pickup boundary")
			sample.pulse_left = 0
			check(not sample.pulse() and sample.drops.is_empty(),"departed creature cannot release materials again")

func test_input_priority() -> void:
	var m = flowers_fixture()
	m.creatures[0].pos = m.p+Vector2(70,0)
	m.creatures[0].anchor = m.creatures[0].pos
	m.step(.1,Vector2.ZERO,true,false,true,Vector2.RIGHT)
	check(m.flowers[0].progress == 0 and m.creatures[0].hits == 1,"effective wing action wins same-frame collection")
	check(is_equal_approx(m.energy,33.94),"priority frame charges idle plus wing action, without harvesting cost")
	var start: Vector2 = m.p
	m.step(.1,Vector2.RIGHT,true,false)
	check(m.p.x > start.x and m.flowers[0].progress == 0,"wing action pauses collection without locking ordinary movement")
	m.step(.1,Vector2.ZERO,true,false)
	check(m.pulse_left > 0 and m.flowers[0].progress > 0,"collection resumes after 0.18 seconds while wing cooldown continues")
	var miss = flowers_fixture()
	miss.creatures[0].pos = miss.p+Vector2(-70,0)
	miss.creatures[0].anchor = miss.creatures[0].pos
	miss.step(.1,Vector2.ZERO,true,false,true,Vector2.RIGHT)
	check(miss.flowers[0].progress > 0 and miss.creatures[0].hits == 0 and is_equal_approx(miss.energy,35.81),"invalid wing action does not interrupt or surcharge collection")

	var full = pulse_fixture()
	full.cargo.blue = full.capacity()
	full.step(.1,Vector2.ZERO,true,false,true,Vector2.RIGHT)
	check(full.creatures[0].hits == 1 and full.cargo_total() == full.capacity(),"full nectar bag still permits material actions")

	var charging = pulse_fixture()
	charging.step(.1,Vector2.ZERO,true,true,true,Vector2.RIGHT)
	check(charging.charging and charging.creatures[0].hits == 0,"charge input wins over a simultaneous wing attempt")
	for frame in 3: charging.step(.1,Vector2.ZERO,true,true,true,Vector2.RIGHT)
	charging.step(.1,Vector2.ZERO,true,false,true,Vector2.RIGHT)
	check(charging.burst_left > 0 and charging.creatures[0].hits == 0,"charge-release dash cannot also hit a target")
	charging.burst_left = .01
	charging.p = charging.creatures[0].pos-Vector2(70,0)
	charging.step(.02,Vector2.ZERO,false,false,true,Vector2.RIGHT)
	check(charging.creatures[0].hits == 0,"last dash frame remains exclusive even as timer reaches zero")
	charging.step(.1,Vector2.ZERO,false,false,false,Vector2.RIGHT)
	check(charging.creatures[0].hits == 0,"released wing input cannot leave a delayed attack queue")

	for dt in [1.0/60.0,1.0/30.0,.1]:
		var held = pulse_fixture(true)
		var frames: Array[int] = []
		var previous := 0
		for frame in roundi(1.6/dt):
			held.step(dt,Vector2.ZERO,false,false,true,Vector2.RIGHT)
			var count := event_count(held,"pulse")
			if count != previous: frames.append(frame)
			previous = count
		check(frames.size() == 3 and held.creatures[1].state == "gone","hold repeats complete a three-hit target at tested frame rate")
		if frames.size() == 3:
			check((frames[1]-frames[0])*dt >= .55-.00001 and (frames[2]-frames[1])*dt >= .55-.00001,"held input never bypasses the 0.55 second interval")

func test_save_boundaries() -> void:
	var m = pulse_fixture()
	m.coins = 17
	m.materials.fiber = 3
	m.flowers[0].progress = .4
	m.cargo.blue = 2
	check(m.pulse(),"save fixture includes a valid partial hit")
	var data: Dictionary = m.to_payload()
	check(data.version == 5 and not data.has("pulse_action_left") and not data.has("_harvest_locked_ids"),"new input state leaves the strict v5 schema unchanged")
	var restored = flowers_fixture()
	restored.step(.1,Vector2.ZERO,true,false)
	restored.pulse_action_left = .18
	check(restored.restore_payload(JSON.parse_string(JSON.stringify(data))),"v5 action snapshot restores atomically")
	check(restored.coins == 17 and restored.materials.fiber == 3 and restored.cargo.blue == 2 and restored.flowers[0].progress == .4 and restored.creatures[0].hits == 1,"restore preserves currency, material, nectar and encounter progress")
	check(restored.harvesting_ids.is_empty() and restored._harvest_locked_ids.is_empty() and restored.pulse_action_left == 0,"restore clears transient locks and short action")
	check(restored.pulse_left == .55 and not restored.pulse(),"save/restore cannot bypass the persisted wing cooldown")
	var invalid := data.duplicate(true)
	invalid.pulse_action_left = .18
	var before: Dictionary = restored.to_payload()
	check(not restored.restore_payload(invalid) and restored.to_payload() == before,"unknown fields stay rejected without partial mutation")
	m.clear_controls()
	check(m.pulse_action_left == 0 and m._harvest_locked_ids.is_empty() and m.pulse_left == .55,"menu/control reset clears short actions and retains cooldown")
	var paused := m.to_payload()
	m.step(0,Vector2.RIGHT,true,true,true,Vector2.RIGHT)
	check(m.to_payload() == paused,"paused step cannot advance actions or spend resources")

func run() -> void:
	test_harvest_lock()
	test_direction_and_growth()
	test_input_priority()
	test_save_boundaries()
	print("NECTAR ACTIONS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
