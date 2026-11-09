extends RefCounted
## Isolated route experiment: does not read/write the Nectar save or change its economy.
const Layout = preload("res://region_greybox/layout.gd")
const Harvest = preload("res://nectar_harvest_model.gd")
const SPEED := 230.0
const BODY := 16.0
var layout: Dictionary
var stats: RefCounted
var region := "pond"
var condition := "sunny"
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
var rain_seconds := 0.0
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
var _locked := -1
var last_action := ""

func configure(area: String, state: String, level: int) -> void:
	region = area if area in ["pond", "violet"] else "pond"
	condition = state if state in ["sunny", "rain", "variant"] else "sunny"
	growth = clampi(level, 0, 1)
	stats = Harvest.new()
	if growth == 1:
		stats.owned.assign(["bag1", "bag2", "wings1", "wings2", "gather1", "gather2", "reach", "beat"])
	layout = Layout.build(region, condition)
	p = layout.nodes[0].p
	v = Vector2.ZERO
	face = Vector2.RIGHT
	energy = stats.max_energy()
	cargo = 0
	material_count = 0
	elapsed = 0.0
	distance = 0.0
	rain_seconds = 0.0
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
	_next_sample = 0.0
	_locked = -1
	flowers.clear()
	materials.clear()
	var far := 4 if region == "pond" else 5
	for id in [2, 3, far]:
		var count := 10 if id == far else 4 if id == 2 else 2
		for i in count:
			var offset := Vector2.from_angle(float(i) / float(count) * TAU) * (96.0 if id == far else 55.0)
			flowers.append({"p": layout.nodes[id].p + offset, "stock": 1, "progress": 0.0, "node": id})
	var material_node := 7 if region == "pond" else 6
	for i in 2:
		materials.append({"p": layout.nodes[material_node].p + Vector2(-45 + i * 90, 0), "hits": 0, "dropped": false, "taken": false})
	phase = "active"
	last_action = "离开入口，选择一条采集路线"

func capacity() -> int: return stats.capacity()
func max_energy() -> float: return stats.max_energy()
func at_entry() -> bool: return p.distance_to(layout.nodes[0].p) <= 125.0
func exposed() -> bool: return condition == "rain" and not Layout.sheltered(layout, p)
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
	var rain := exposed()
	if rain: rain_seconds += dt
	energy -= dt * ((1.0 if v.length() > 20 else 0.6) + (1.8 if rain else 0.0))
	if energy <= 0:
		finish("exhausted")
		return
	if collect and departed and at_entry():
		finish("returned")
		return
	if pulse and not charging and not dashing: _pulse(aim)
	if collect and not charging and not dashing and pulse_flash <= 0:
		_harvest(dt)
	else:
		_locked = -1
	for item in materials:
		if item.dropped and not item.taken and p.distance_to(item.p) < 42:
			item.taken = true
			material_count += 1
			last_action = "拾取材料 +1"
	if energy <= 0: finish("exhausted")
	if elapsed >= _next_sample:
		trace.append({"t": snappedf(elapsed, 0.01), "x": snappedf(p.x, 0.1), "y": snappedf(p.y, 0.1), "energy": snappedf(energy, 0.01), "cargo": cargo})
		_next_sample += 0.5

func _flower_in_reach(index: int) -> bool:
	if index < 0 or index >= flowers.size(): return false
	var f := flowers[index]
	return int(f.stock) > 0 and p.distance_to(f.p) <= stats.harvest_radius() and clear_line(p, f.p)

func _harvest(dt: float) -> void:
	if cargo >= capacity():
		last_action = "蜜囊已满，仍可探索或回入口交付"
		return
	if not _flower_in_reach(_locked):
		_locked = -1
		var nearest := INF
		for i in flowers.size():
			if _flower_in_reach(i) and p.distance_squared_to(flowers[i].p) < nearest:
				_locked = i
				nearest = p.distance_squared_to(flowers[i].p)
	if _locked < 0: return
	var f := flowers[_locked]
	f.progress = minf(1.0, f.progress + stats.harvest_rate() * dt)
	harvest_seconds += dt
	energy -= 1.3 * dt
	last_action = "采蜜中"
	if f.progress >= 0.99999:
		f.stock = 0
		cargo += 1
		_locked = -1
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
	materials[selected].hits += 2 if growth == 1 else 1
	if materials[selected].hits >= 2:
		materials[selected].dropped = true
		last_action = "材料已松落，靠近拾取"
	else: last_action = "再次振翅可取下材料"

func finish(outcome: String) -> void:
	phase = outcome
	energy = maxf(0.0, energy)
	v = Vector2.ZERO

func summary() -> Dictionary:
	return {"schema": 1, "region": region, "condition": condition, "growth": growth,
		"result": phase, "elapsed_seconds": snappedf(elapsed, 0.01), "distance_px": snappedf(distance, 0.1),
		"energy_left": snappedf(energy, 0.01), "energy_start": max_energy(), "cargo": cargo, "capacity": capacity(),
		"materials": material_count, "rain_seconds": snappedf(rain_seconds, 0.01), "harvest_seconds": snappedf(harvest_seconds, 0.01),
		"collision_seconds": snappedf(collision_seconds, 0.01), "visits": visits.duplicate(), "trace": trace.duplicate(true)}
