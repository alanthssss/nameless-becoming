extends RefCounted
## Isolated route experiment: does not read/write the Nectar save or change its economy.
const Layout = preload("res://region_greybox/layout.gd")
const Harvest = preload("res://nectar_harvest_model.gd")
const SPEED := 230.0
const BODY := 16.0
var layout: Dictionary
var stats: RefCounted
var region := "pond"
const REGROW_SECONDS := 18.0
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
			var offset := Vector2.from_angle(float(i) / float(cluster.count) * TAU) * 26.0
			flowers.append({"id":flowers.size(), "p":anchor + offset, "stock":1, "progress":0.0,
				"regrow":0.0, "node":cluster.node, "band":cluster.band, "cluster":cluster_id})
	for spawn in layout.material_spawns:
		materials.append({"p":spawn.p, "anchor":spawn.p, "node":spawn.node, "band":spawn.band,
			"hits":0, "dropped":false, "taken":false, "stun":0.0})
	phase = "active"
	last_action = "沿花丛深入，采花蜜或取材料，再返回入口"

func _event(kind: String, id: int) -> void:
	events.append({"t":snappedf(elapsed,0.01), "kind":kind, "id":id, "x":snappedf(p.x,0.1), "y":snappedf(p.y,0.1)})

func _supply(dt: float) -> void:
	for flower in flowers:
		if int(flower.stock) > 0: continue
		flower.regrow = minf(REGROW_SECONDS, float(flower.regrow) + dt)
		if float(flower.regrow) >= REGROW_SECONDS - 0.00001:
			flower.stock = 1
			flower.regrow = 0.0
			flower.progress = 0.0
			_event("nectar_refilled", int(flower.id))
	for i in materials.size():
		var item := materials[i]
		if item.dropped or item.taken: continue
		item.stun = maxf(0.0, float(item.stun) - dt)
		if float(item.stun) > 0: continue
		# Brief rest followed by a short out-and-back move, inside its habitat.
		var t := fmod(elapsed + float(i) * 1.1, 6.0)
		var offset := Vector2.ZERO if t < 3.0 else Vector2(18.0 * sin((t - 3.0) / 3.0 * TAU), 0)
		item.p = item.anchor + offset

func target_nearby(radius: float = 250.0) -> bool:
	for flower in flowers:
		if int(flower.stock) > 0 and p.distance_to(flower.p) <= radius and clear_line(p, flower.p): return true
	for item in materials:
		if not item.taken and p.distance_to(item.p) <= radius and clear_line(p, item.p): return true
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
			item.taken = true
			material_count += 1
			_event("material_picked", materials.find(item))
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
	if _locked.is_empty(): return
	harvest_seconds += dt
	energy -= 1.3 * dt
	last_action = "采蜜中"
	for index in _locked:
		var f := flowers[index]
		f.progress = minf(1.0, float(f.progress) + stats.harvest_rate() * dt)
		if float(f.progress) >= 0.99999:
			f.stock = 0
			f.progress = 0.0
			f.regrow = 0.0
			cargo += 1
			_event("nectar_picked", index)
			last_action = "花蜜 +1"

func _pulse(aim: Vector2) -> void:
	if pulse_left > 0 or energy <= 2: return
	var direction := face if aim.is_zero_approx() or not aim.is_finite() else aim.normalized()
	var selected := -1
	var nearest := INF
	for i in materials.size():
		var item := materials[i]
		var offset: Vector2 = item.p - p
		if item.dropped or item.taken or offset.length() > stats.pulse_radius(): continue
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
	return {"schema":2, "region":region, "seed":trip_seed, "growth":growth,
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
	var data := {"version":2}
	for key in SNAPSHOT_KEYS: data[key] = get(key)
	return data.duplicate(true)

func restore(data: Variant) -> bool:
	if not data is Dictionary or data.get("version") != 2: return false
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
	if not data.material_count is int or data.material_count < 0 or data.material_count > 2: return false
	if not data.flowers is Array or data.flowers.size() != 16 or not data.materials is Array or data.materials.size() != 2: return false
	for i in data.flowers.size():
		var f: Variant = data.flowers[i]
		if not f is Dictionary: return false
		for key in candidate.flowers[i]:
			if not f.has(key): return false
		if f.p != candidate.flowers[i].p or f.id != i or f.band != candidate.flowers[i].band or f.node != candidate.flowers[i].node or f.cluster != candidate.flowers[i].cluster: return false
		if f.stock not in [0,1] or not is_finite(float(f.progress)) or not is_finite(float(f.regrow)): return false
		if f.progress < 0 or f.progress >= 1 or f.regrow < 0 or f.regrow >= REGROW_SECONDS: return false
		if (f.stock == 0 and f.progress != 0) or (f.stock == 1 and f.regrow != 0): return false
	var taken := 0
	for i in data.materials.size():
		var item: Variant = data.materials[i]
		if not item is Dictionary: return false
		for key in candidate.materials[i]:
			if not item.has(key): return false
		if item.anchor != candidate.materials[i].anchor or not item.p is Vector2 or not item.p.is_finite(): return false
		if item.p.distance_to(item.anchor) > 30 or not item.hits is int or item.hits < 0 or item.hits > 4: return false
		if not item.dropped is bool or not item.taken is bool or not is_finite(float(item.stun)) or item.stun < 0: return false
		if item.taken and not item.dropped: return false
		if item.taken: taken += 1
	if taken != data.material_count: return false
	for key in ["v","face"]:
		if not data[key] is Vector2 or not data[key].is_finite(): return false
	for key in ["trace","events","visits","_locked"]:
		if not data[key] is Array: return false
	for id in data.visits:
		if id not in [0,1,2,3,4]: return false
	for id in data._locked:
		if not id is int or id < 0 or id >= 16: return false
	if not data.charging is bool or not data.departed is bool or not data.last_action is String: return false
	configure(data.region, data.growth, data.trip_seed)
	for key in SNAPSHOT_KEYS:
		if get(key) is Array: get(key).assign(data[key].duplicate(true))
		else: set(key, data[key])
	return true
