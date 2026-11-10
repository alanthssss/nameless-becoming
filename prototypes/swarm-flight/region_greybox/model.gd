extends RefCounted
## Isolated route experiment: does not read/write the Nectar save or change its economy.
const Layout = preload("res://region_greybox/layout.gd")
const Harvest = preload("res://nectar_harvest_model.gd")
const SPEED := 230.0
const BODY := 16.0
var layout: Dictionary
var stats: RefCounted
var region := "pond"
const FLOWER_DURATIONS := {"empty":6.0,"bud":4.0,"ripe":18.0,"fading":6.0}
const MATERIAL_DURATIONS := {"empty":18.0,"bud":4.0,"ripe":22.0,"fading":6.0}
const DROP_SECONDS := 12.0
const PHASE_ORDER := ["ripe","fading","empty","bud"]
var trip_seed := 1
var growth := 0
var p := Vector2.ZERO
var v := Vector2.ZERO
var face := Vector2.RIGHT
var energy := 36.0
var cargo := 0
var material_count := 0
var flowers: Array[Dictionary] = []
var materials: Array[Dictionary] = []
var phase := "ready"
var elapsed := 0.0
var distance := 0.0
var longest_empty_flight := 0.0
var _empty_flight := 0.0
var longest_actionless_flight := 0.0
var _actionless_flight := 0.0
var events: Array[Dictionary] = []
var harvest_seconds := 0.0
var collision_seconds := 0.0
var pulse_left := 0.0
var pulse_flash := 0.0
var charge := 0.0
var charging := false
var burst_left := 0.0
var departed := false
var visits: Array[int] = []
var trace: Array[Dictionary] = []
var _next_sample := 0.0
var _locked: Array[int] = []
var last_action := ""

func configure(area: String, level: int, seed_value: int = 1) -> void:
	region = area if area in ["pond", "violet"] else "pond"
	trip_seed = maxi(1, seed_value)
	growth = clampi(level, 0, 1)
	stats = Harvest.new()
	if growth == 1:
		stats.owned.assign(["bag1", "bag2", "wings1", "wings2", "gather1", "gather2", "reach", "beat", "twin"])
	layout = Layout.build(region)
	p = layout.nodes[0].p
	v = Vector2.ZERO
	face = Vector2.RIGHT
	energy = stats.max_energy()
	cargo = 0
	material_count = 0
	elapsed = 0.0
	distance = 0.0
	longest_empty_flight = 0.0
	_empty_flight = 0.0
	longest_actionless_flight = 0.0
	_actionless_flight = 0.0
	harvest_seconds = 0.0
	collision_seconds = 0.0
	pulse_left = 0.0
	pulse_flash = 0.0
	charge = 0.0
	charging = false
	burst_left = 0.0
	departed = false
	visits = [0]
	trace.clear()
	events.clear()
	_next_sample = 0.0
	_locked.clear()
	flowers.clear()
	materials.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = trip_seed
	for cluster_id in layout.clusters.size():
		var cluster: Dictionary = layout.clusters[cluster_id]
		var anchor: Vector2 = cluster.anchors[rng.randi_range(0, cluster.anchors.size() - 1)]
		for i in int(cluster.count):
			var offset := Vector2.from_angle(float(i) / float(cluster.count) * TAU) * 45.0
			var flower := {"id":flowers.size(), "p":anchor + offset, "stock":1, "progress":0.0,
				"node":cluster.node, "band":cluster.band, "cluster":cluster_id,
				"phase":"ripe", "phase_time":0.0, "phase_duration":18.0}
			_initial_phase(flower,float([0,11,23][i])+float(cluster_id%4)*3.0,false)
			flowers.append(flower)
	for i in layout.material_spawns.size():
		var spawn: Dictionary = layout.material_spawns[i]
		var item := {"id":i,"p":spawn.p, "anchor":spawn.p, "node":spawn.node, "band":spawn.band,
			"hits":0, "dropped":false, "taken":false, "stun":0.0,
			"phase":"ripe", "phase_time":0.0, "phase_duration":22.0}
		_initial_phase(item,6.0 if i == 1 else 25.0 if i in [3,5] else 0.0,true)
		materials.append(item)
	phase = "active"
	last_action = "沿花丛深入，采花蜜或取材料，再返回入口"

func _event(kind: String, id: int) -> void:
	events.append({"t":snappedf(elapsed,0.01), "kind":kind, "id":id, "x":snappedf(p.x,0.1), "y":snappedf(p.y,0.1)})

static func phase_ratio(item: Dictionary) -> float:
	return clampf(float(item.phase_time)/maxf(0.0001,float(item.phase_duration)),0.0,1.0)

static func available(item: Dictionary) -> bool:
	return item.phase in ["ripe","fading"]

func _initial_phase(item: Dictionary, offset: float, material: bool) -> void:
	var durations: Dictionary = MATERIAL_DURATIONS if material else FLOWER_DURATIONS
	var cycle := 50.0 if material else 34.0
	var remaining := fmod(offset,cycle)
	for state in PHASE_ORDER:
		var duration: float = durations[state]
		if remaining < duration:
			item.phase = state
			item.phase_time = remaining
			item.phase_duration = duration
			if not material: item.stock = 1 if available(item) else 0
			return
		remaining -= duration

func _enter_phase(item: Dictionary, state: String, material: bool) -> void:
	item.phase = state
	item.phase_time = 0.0
	item.phase_duration = (MATERIAL_DURATIONS if material else FLOWER_DURATIONS)[state]
	if material:
		if state != "fading":
			item.dropped = false
			item.taken = false
			item.hits = 0
			item.stun = 0.0
			item.p = item.anchor
	else:
		item.stock = 1 if state in ["ripe","fading"] else 0
		if state in ["empty","bud","ripe"]: item.progress = 0.0
	_event(("material_" if material else "flower_")+state,int(item.id))

func _advance_life(item: Dictionary, dt: float, material: bool) -> void:
	item.phase_time = minf(float(item.phase_duration),float(item.phase_time)+dt)
	if float(item.phase_time) < float(item.phase_duration)-0.00001: return
	# A dropped item has its own visible 12-second decay, then vacates this
	# habitat. Normal maturation and expiry use the same phase contract.
	if material and item.dropped:
		if last_action == "材料已松落，靠近拾取": last_action = "落地材料已消散，可寻找其他成熟材料"
		_enter_phase(item,"empty",true)
		return
	var next := str(PHASE_ORDER[(PHASE_ORDER.find(item.phase)+1)%PHASE_ORDER.size()])
	_enter_phase(item,next,material)

func _supply(dt: float) -> void:
	for flower in flowers: _advance_life(flower,dt,false)
	for i in materials.size():
		var item := materials[i]
		_advance_life(item,dt,true)
		if item.dropped or not available(item): continue
		item.stun = maxf(0.0,float(item.stun)-dt)
		if float(item.stun) > 0: continue
		var t := fmod(elapsed+float(i)*1.1,6.0)
		item.p = item.anchor+(Vector2.ZERO if t < 3.0 else Vector2(18.0*sin((t-3.0)/3.0*TAU),0))

func target_nearby(radius: float = 250.0) -> bool:
	for flower in flowers:
		if int(flower.stock) > 0 and p.distance_to(flower.p) <= radius and clear_line(p, flower.p): return true
	for item in materials:
		if available(item) and p.distance_to(item.p) <= radius and clear_line(p, item.p): return true
	return at_entry()

func capacity() -> int: return stats.capacity()
func max_energy() -> float: return stats.max_energy()
func at_entry() -> bool: return p.distance_to(layout.nodes[0].p) <= 125.0
func clear_line(a: Vector2, b: Vector2) -> bool:
	var steps := maxi(1, ceili(a.distance_to(b) / 8.0))
	for i in steps + 1:
		if not Layout.walkable(layout, a.lerp(b, float(i) / steps), 0.0): return false
	return true

func step(delta: float, motion: Vector2, collect: bool, space_held: bool = false, pulse: bool = false, aim := Vector2.ZERO) -> void:
	if phase != "active" or not is_finite(delta) or delta <= 0 or not motion.is_finite(): return
	var dt := minf(delta, 0.05)
	motion = motion.limit_length(1.0)
	elapsed += dt
	_supply(dt)
	pulse_left = maxf(0.0, pulse_left - dt)
	pulse_flash = maxf(0.0, pulse_flash - dt)
	if not motion.is_zero_approx() and burst_left <= 0: face = motion.normalized()
	if burst_left <= 0:
		if space_held:
			charging = true
			charge = minf(0.32, charge + dt)
		elif charging:
			if charge >= 0.32 and energy >= 4:
				burst_left = 0.32
				energy -= 4.0
			charging = false
			charge = 0.0
	var dashing := burst_left > 0
	if dashing:
		v = face * 500.0
		burst_left = maxf(0.0, burst_left - dt)
	else:
		v = v.move_toward(motion * (135.0 if charging else SPEED), (1800.0 if motion.is_zero_approx() else 1300.0) * dt)
	var old := p
	var requested := v * dt
	p = Layout.move(layout, p, requested, BODY)
	if p.distance_to(old + requested) > 0.1: collision_seconds += dt
	distance += old.distance_to(p)
	if p.distance_to(layout.nodes[0].p) > 220: departed = true
	var node: int = Layout.node_at(layout, p)
	if node >= 0 and (visits.is_empty() or visits[-1] != node): visits.append(node)
	energy -= dt * (1.0 if v.length() > 20 else 0.6)
	if old.distance_to(p) > 0.1 and not target_nearby():
		_empty_flight += dt
		longest_empty_flight = maxf(longest_empty_flight, _empty_flight)
	else: _empty_flight = 0.0
	if energy <= 0:
		finish("exhausted")
		return
	if collect and departed and at_entry():
		finish("returned")
		return
	var harvest_before := harvest_seconds
	var material_before := material_count
	if pulse and not charging and not dashing: _pulse(aim)
	if collect and not charging and not dashing and pulse_flash <= 0:
		_harvest(dt)
	else:
		_locked.clear()
		if last_action == "采蜜中": last_action = "选择下一处目标，或沿来路返回"
	for item in materials:
		if item.dropped and not item.taken and p.distance_to(item.p) < 42:
			material_count += 1
			_event("material_picked", int(item.id))
			_enter_phase(item,"empty",true)
			item.taken = true
			last_action = "拾取材料 +1"
	if old.distance_to(p) > 0.1 and harvest_seconds == harvest_before and material_count == material_before and pulse_flash <= 0:
		_actionless_flight += dt
		longest_actionless_flight = maxf(longest_actionless_flight, _actionless_flight)
	elif harvest_seconds > harvest_before or material_count > material_before or pulse_flash > 0:
		_actionless_flight = 0.0
	if energy <= 0: finish("exhausted")
	if elapsed >= _next_sample:
		trace.append({"t": snappedf(elapsed, 0.01), "x": snappedf(p.x, 0.1), "y": snappedf(p.y, 0.1), "energy": snappedf(energy, 0.01), "cargo": cargo, "materials": material_count, "target_nearby":target_nearby()})
		_next_sample += 0.25

func _flower_in_reach(index: int) -> bool:
	if index < 0 or index >= flowers.size(): return false
	var f := flowers[index]
	return int(f.stock) > 0 and p.distance_to(f.p) <= stats.harvest_radius() and clear_line(p, f.p)

func _harvest(dt: float) -> void:
	if cargo >= capacity():
		last_action = "蜜囊已满，仍可取材料或回入口"
		return
	var slots := mini(2 if "twin" in stats.owned else 1, capacity() - cargo)
	var selected: Array[int] = []
	for index in _locked:
		if _flower_in_reach(index) and selected.size() < slots: selected.append(index)
	while selected.size() < slots:
		var nearest := -1
		var distance_sq := INF
		for i in flowers.size():
			if i not in selected and _flower_in_reach(i) and p.distance_squared_to(flowers[i].p) < distance_sq:
				nearest = i
				distance_sq = p.distance_squared_to(flowers[i].p)
		if nearest < 0: break
		selected.append(nearest)
	_locked = selected
	if _locked.is_empty():
		for flower in flowers:
			if not available(flower) and p.distance_to(flower.p) <= stats.harvest_radius() and clear_line(p,flower.p):
				last_action = "花正在生长，沿路还有花源"
				break
		return
	harvest_seconds += dt
	energy -= 1.3 * dt
	last_action = "采蜜中"
	for index in _locked:
		var f := flowers[index]
		f.progress = minf(1.0, float(f.progress) + stats.harvest_rate() * dt)
		if float(f.progress) >= 0.99999:
			cargo += 1
			_event("nectar_picked", index)
			_enter_phase(f,"empty",false)
			last_action = "花蜜 +1"

func _pulse(aim: Vector2) -> void:
	if pulse_left > 0 or energy <= 2: return
	var direction := face if aim.is_zero_approx() or not aim.is_finite() else aim.normalized()
	var selected := -1
	var nearest := INF
	for i in materials.size():
		var item := materials[i]
		var offset: Vector2 = item.p - p
		if item.dropped or not available(item) or offset.length() > stats.pulse_radius(): continue
		if not offset.is_zero_approx() and direction.dot(offset.normalized()) < 0.5: continue
		if not clear_line(p, item.p): continue
		if offset.length_squared() < nearest:
			selected = i
			nearest = offset.length_squared()
	if selected < 0: return # Empty wing actions remain free, as in the current demo.
	face = direction
	energy -= 2.0
	pulse_left = 0.55
	pulse_flash = 0.18
	materials[selected].hits += 2 if "beat" in stats.owned else 1
	materials[selected].stun = 0.42
	_event("material_hit", selected)
	if materials[selected].hits >= (2 if region == "pond" else 3):
		materials[selected].dropped = true
		materials[selected].phase = "fading"
		materials[selected].phase_time = 0.0
		materials[selected].phase_duration = DROP_SECONDS
		_event("material_dropped", selected)
		last_action = "材料已松落，靠近拾取"
	else: last_action = "再次振翅可取下材料"

func finish(outcome: String) -> void:
	if phase != "active": return
	phase = outcome
	_event(outcome, -1)
	energy = maxf(0.0, energy)
	v = Vector2.ZERO

func summary() -> Dictionary:
	return {"schema":3, "region":region, "seed":trip_seed, "growth":growth,
		"result":phase, "elapsed_seconds":snappedf(elapsed,0.01), "distance_px":snappedf(distance,0.1),
		"energy_left":snappedf(energy,0.01), "energy_start":max_energy(), "cargo":cargo, "capacity":capacity(),
		"materials":material_count, "harvest_seconds":snappedf(harvest_seconds,0.01),
		"longest_empty_flight_seconds":snappedf(longest_empty_flight,0.01),
		"longest_actionless_flight_seconds":snappedf(longest_actionless_flight,0.01),
		"actionless_flight_definition":"moving time between harvesting/pulse/pickup actions; stationary pauses do not reset it",
		"empty_flight_definition":"moving with no stocked flower/untaken material within 250px and clear line; excludes entry",
		"collision_seconds":snappedf(collision_seconds,0.01), "visits":visits.duplicate(),
		"events":events.duplicate(true), "trace":trace.duplicate(true)}

const SNAPSHOT_KEYS := ["region","trip_seed","growth","p","v","face","energy","cargo","material_count",
	"flowers","materials","phase","elapsed","distance","longest_empty_flight","_empty_flight",
	"longest_actionless_flight","_actionless_flight","harvest_seconds","collision_seconds","pulse_left","pulse_flash","charge","charging","burst_left",
	"departed","visits","trace","events","_next_sample","_locked","last_action"]

func snapshot() -> Dictionary:
	var data := {"version":3}
	for key in SNAPSHOT_KEYS: data[key] = get(key)
	return data.duplicate(true)

func restore(data: Variant) -> bool:
	if not data is Dictionary or data.get("version") != 3: return false
	for key in SNAPSHOT_KEYS:
		if not data.has(key): return false
	if data.region not in ["pond","violet"] or data.growth not in [0,1] or data.phase != "active": return false
	if not data.trip_seed is int or data.trip_seed < 1: return false
	var candidate: RefCounted = get_script().new()
	candidate.configure(data.region, data.growth, data.trip_seed)
	if not data.p is Vector2 or not data.p.is_finite() or not Layout.walkable(candidate.layout, data.p): return false
	for key in ["energy","elapsed","distance","longest_empty_flight","_empty_flight","longest_actionless_flight","_actionless_flight","harvest_seconds","collision_seconds","pulse_left","pulse_flash","charge","burst_left","_next_sample"]:
		if not (data[key] is float or data[key] is int) or not is_finite(float(data[key])) or float(data[key]) < 0: return false
	if data.energy > candidate.max_energy() or data.energy <= 0: return false
	if not data.cargo is int or data.cargo < 0 or data.cargo > candidate.capacity(): return false
	if not data.material_count is int or data.material_count < 0: return false
	if not data.flowers is Array or data.flowers.size() != 36 or not data.materials is Array or data.materials.size() != 6: return false
	for i in data.flowers.size():
		var f: Variant = data.flowers[i]
		if not f is Dictionary: return false
		for key in candidate.flowers[i]:
			if not f.has(key): return false
		if f.p != candidate.flowers[i].p or f.id != i or f.band != candidate.flowers[i].band or f.node != candidate.flowers[i].node or f.cluster != candidate.flowers[i].cluster: return false
		if not _valid_phase(f,false) or not _number(f.progress): return false
		if f.progress < 0 or f.progress >= 1 or f.stock != (1 if available(f) else 0): return false
		if not available(f) and f.progress != 0: return false
	for i in data.materials.size():
		var item: Variant = data.materials[i]
		if not item is Dictionary: return false
		for key in candidate.materials[i]:
			if not item.has(key): return false
		if item.id != i or item.node != candidate.materials[i].node or item.band != candidate.materials[i].band: return false
		if item.anchor != candidate.materials[i].anchor or not item.p is Vector2 or not item.p.is_finite(): return false
		if item.p.distance_to(item.anchor) > 30 or not item.hits is int or item.hits < 0 or item.hits > 4: return false
		if not item.dropped is bool or not item.taken is bool or not _number(item.stun) or item.stun < 0: return false
		if not _valid_phase(item,true): return false
		if item.dropped and (item.phase != "fading" or item.taken): return false
		if item.taken and item.phase != "empty": return false
		if not available(item) and (item.hits != 0 or item.dropped): return false
	for key in ["v","face"]:
		if not data[key] is Vector2 or not data[key].is_finite(): return false
	for key in ["trace","events","visits","_locked"]:
		if not data[key] is Array: return false
	for id in data.visits:
		if id not in [0,1,2,3,4]: return false
	for id in data._locked:
		if not id is int or id < 0 or id >= 36: return false
	if not data.charging is bool or not data.departed is bool or not data.last_action is String: return false
	configure(data.region, data.growth, data.trip_seed)
	for key in SNAPSHOT_KEYS:
		if get(key) is Array: get(key).assign(data[key].duplicate(true))
		else: set(key, data[key])
	return true

static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func _valid_phase(item: Dictionary, material: bool) -> bool:
	if item.phase not in PHASE_ORDER or not _number(item.phase_time) or not _number(item.phase_duration): return false
	var expected: float = DROP_SECONDS if material and item.dropped else (MATERIAL_DURATIONS if material else FLOWER_DURATIONS)[item.phase]
	return item.phase_duration == expected and item.phase_time >= 0.0 and item.phase_time < expected
