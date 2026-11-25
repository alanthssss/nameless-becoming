extends "res://region_greybox/model.gd"
## Potential sites are spread through the meadow; undiscovered fertility is
## absent from the scene, not represented by empty collectible markers.
const RegionalLayout = preload("res://region_game/layout.gd")
const INITIAL_SITES := [0,3,6,8,10,12,15,18,20,22,24,26,28,30,32,34]
const MIDDLE_EXTRA := [1,4,7,13,16,21,27,33]
const NECTAR_SECONDS := [20.0,14.0,10.0]
const OPEN_FLOWER_AGE_RATE := 0.45
const RESIN_REACH := 64.0
const RESIN_SECONDS := 0.8
const TUFT_DRIFT := 24.0
# Pixel registration in a 970×561 proof of the entire pond painting, including the handle.
const JAR_RECT := Rect2(RegionalLayout.PLATE.position + Vector2(93,161)/Vector2(970,561)*RegionalLayout.PLATE.size,
		Vector2(64,79)/Vector2(970,561)*RegionalLayout.PLATE.size)
# Largest flower in bloom, including rocking petals above and roots and leaves below.
const FLOWER_FOOTPRINT := Rect2(-38,-42,76,99)
const POND_SPACE_VERSION := 5
const PLANT_CLEARANCE := 24.0
# The ripe or shaken tuft spreads past the husk only above its socket.
const FIBER_TUFT := Rect2(-32,-26,64,22)

var supply_rank := 0
var drawing_resin_id := -1
var _beat_shown := false

func configure(area: String,level: int,seed_value: int = 1) -> void:
	super.configure(area,level,seed_value)
	drawing_resin_id = -1
	_beat_shown = false
	layout = RegionalLayout.build(region,false)
	var original := _seeded_flower_sites(layout,trip_seed)
	for i in flowers.size():
		flowers[i].p = original[i]*RegionalLayout.GROUND_SCALE
		flowers[i].enabled = true
	p *= RegionalLayout.GROUND_SCALE
	for item in materials:
		item.enabled = true
		item.anchor *= RegionalLayout.GROUND_SCALE
		item.p = item.anchor
	layout = RegionalLayout.expand(layout)
	if region == "pond":
		# Reproduce the 0.32.1 sites first. Only move flowers that still crowd a host.
		_clear_pond_flowers(flowers,layout,[JAR_RECT])
		_clear_pond_flowers(flowers,layout,_pond_obstacles(layout),32)
	supply_rank = 0
	set_supply_rank(0)

# Reproduce the original seeded layout before moving only sites that cover the painted pot.
static func _seeded_flower_sites(coast: Dictionary,seed_value: int) -> Array[Vector2]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value*713+41
	var placed: Array[Vector2] = []
	for i in Layout.CLUSTER_X.size()*3:
		var cluster: int = i/3
		var x: float = Layout.CLUSTER_X[cluster]
		var edge_index := 0 if x <= coast.nodes[1].p.x else 1 if x <= coast.nodes[2].p.x else 2
		var a: Vector2 = coast.nodes[edge_index].p
		var b: Vector2 = coast.nodes[edge_index+1].p
		var center := a.lerp(b,(x-a.x)/(b.x-a.x))
		var best := center
		var best_gap := -1.0
		for attempt in 80:
			var candidate := center+Vector2(rng.randf_range(-76,76),rng.randf_range(-175,175))
			if not Layout.walkable(coast,candidate,62): continue
			var gap := INF
			for other in placed: gap = minf(gap,candidate.distance_to(other))
			if gap > best_gap:
				best = candidate
				best_gap = gap
			if gap >= 112: break
		placed.append(best)
	return placed

static func _pond_obstacles(coast: Dictionary) -> Array[Rect2]:
	var obstacles: Array[Rect2] = [JAR_RECT]
	for spawn in coast.material_spawns:
		var maturity := RegionalLayout.material_scale(spawn.band)
		var span := RegionalLayout.FIBER_SPAN*maturity
		obstacles.append(Rect2(spawn.p-span*RegionalLayout.FIBER_SOCKET,span).grow(PLANT_CLEARANCE))
		obstacles.append(Rect2(spawn.p+FIBER_TUFT.position*maturity,FIBER_TUFT.size*maturity).grow(PLANT_CLEARANCE))
	return obstacles

static func _overlaps_obstacle(at: Vector2,obstacles: Array[Rect2]) -> bool:
	var plant := Rect2(at+FLOWER_FOOTPRINT.position,FLOWER_FOOTPRINT.size)
	for obstacle in obstacles:
		if plant.intersects(obstacle,true): return true
	return false

static func _clear_pond_flowers(sites: Array,coast: Dictionary,obstacles: Array[Rect2],directions := 16) -> void:
	for flower in sites:
		if _overlaps_obstacle(flower.p,obstacles):
			flower.p = _nearby_open_ground(flower,sites,coast,obstacles,directions)

static func _nearby_open_ground(flower: Dictionary,sites: Array,coast: Dictionary,obstacles: Array[Rect2],directions: int) -> Vector2:
	var best: Vector2 = coast.nodes[1].p
	var best_gap := -1.0
	# Expand beyond the local search only if every nearby candidate was obstructed.
	var rings := ceili(coast.bounds.size.length()/32.0)
	for ring in range(1,rings+1):
		if ring > 10 and best_gap >= 0: break
		for spoke in directions:
			var offset := Vector2.DOWN.rotated(spoke*TAU/directions)*(ring*32.0)
			var at: Vector2 = flower.p + offset
			if _overlaps_obstacle(at,obstacles) or at.distance_to(coast.nodes[0].p)<150.0: continue
			var gap := INF
			for other in sites:
				if other != flower: gap = minf(gap,at.distance_squared_to(other.p))
			if gap <= best_gap or not Layout.walkable(coast,at,62): continue
			best = at
			best_gap = gap
			if gap >= 112.0*112.0: return at
	return best

static func active_flower(id: int,rank: int) -> bool:
	return rank == 2 or id in INITIAL_SITES or (rank == 1 and id in MIDDLE_EXTRA)

static func active_material(id: int,rank: int) -> bool:
	return rank == 2 or id in [0,2,4] or (rank == 1 and id == 1)

func set_supply_rank(rank: int) -> void:
	supply_rank = clampi(rank,0,2)
	for f in flowers:
		f.erase("nectar_wait")
		f.enabled = active_flower(int(f.id),supply_rank)
		if f.enabled:
			_initial_phase(f,float([0,5,12,18][int(f.id)%4]),false)
		else:
			f.phase = "empty"
			f.phase_time = 0.0
			f.phase_duration = FLOWER_DURATIONS.empty
			f.stock = 0
			f.progress = 0.0
	for item in materials:
		item.erase("resin_draw")
		item.enabled = active_material(int(item.id),supply_rank)
		if item.enabled:
			_initial_phase(item,6.0 if int(item.id) == 1 else 25.0 if int(item.id) in [3,5] else 0.0,true)
		else:
			item.phase = "empty"
			item.phase_time = 0.0
			item.phase_duration = MATERIAL_DURATIONS.empty
			item.hits = 0
			item.dropped = false
			item.taken = false
			item.stun = 0.0

func _supply(dt: float) -> void:
	var rate: float = [0.5,1.0/1.4,1.0][supply_rank]
	for f in flowers:
		if not f.enabled: continue
		_advance_life(f,dt*rate if f.phase in ["empty","bud"] else dt*OPEN_FLOWER_AGE_RATE,false)
		if f.has("nectar_wait"):
			f.nectar_wait -= dt
			if f.nectar_wait <= 0.00001:
				f.erase("nectar_wait")
				f.stock = 1
	for i in materials.size():
		var item: Dictionary = materials[i]
		if not item.enabled: continue
		_advance_life(item,dt*rate if item.phase in ["empty","bud"] else dt,true)
		if item.dropped or not available(item): continue
		item.stun = maxf(0,float(item.stun)-dt)
		if float(item.stun) > 0: continue
		# Attached seed heads and bark seams stay on their host.
		item.p = item.anchor

static func shell_strength(item: Dictionary) -> int:
	return 1 if item.band == "near" else 2

func resin_open(item: Dictionary) -> bool:
	return region == "violet" and available(item) and not item.dropped and item.hits >= shell_strength(item)

func nearby_material(radius: float, opened_only := false) -> Dictionary:
	var best := {}
	var best_rank := -1
	var shortest := INF
	for item in materials:
		if not item.enabled or (opened_only and not resin_open(item)): continue
		var distance_sq := p.distance_squared_to(item.p)
		if distance_sq > radius*radius: continue
		var rank := 2 if resin_open(item) and distance_sq<=RESIN_REACH*RESIN_REACH else 1 if available(item) else 0
		if rank < best_rank or (rank == best_rank and distance_sq >= shortest): continue
		if clear_line(p,item.p):
			shortest = distance_sq
			best_rank = rank
			best = item
	return best

func material_for_hint() -> Dictionary:
	var item := nearby_material(stats.pulse_radius())
	if item.is_empty() or cargo >= capacity(): return item
	for index in _locked:
		if _flower_in_reach(index): return {}
	var distance_sq := p.distance_squared_to(item.p)
	if resin_open(item) and distance_sq<=RESIN_REACH*RESIN_REACH: return item
	for flower in flowers:
		if flower.stock>0 and (not available(item) or p.distance_squared_to(flower.p)<distance_sq) and _flower_in_reach(int(flower.id)):
			return {}
	return item

func _after_nectar_picked(flower: Dictionary) -> void:
	flower.stock = 0
	flower.progress = 0.0
	flower.nectar_wait = NECTAR_SECONDS[supply_rank]

func nectar_fill(flower: Dictionary) -> float:
	if int(flower.stock)>0: return 1.0
	if not flower.has("nectar_wait"): return 0.0
	return clampf(1.0-float(flower.nectar_wait)/float(NECTAR_SECONDS[supply_rank]),0.0,1.0)

func _valid_flower_stock(flower: Dictionary) -> bool:
	if flower.has("nectar_wait"):
		return available(flower) and flower.stock == 0 and flower.progress == 0 and _number(flower.nectar_wait) and flower.nectar_wait > 0 and flower.nectar_wait <= 20
	return super._valid_flower_stock(flower)

func _enter_phase(item: Dictionary, state: String, material: bool) -> void:
	super._enter_phase(item,state,material)
	if not material and item.has("nectar_wait"):
		if state == "fading": item.stock = 0
		else: item.erase("nectar_wait")
	if material and state != "fading":
		item.erase("resin_draw")

func _event(kind: String, id: int) -> void:
	super._event(kind,id)
	if kind in ["material_hit","material_picked","material_dropped"]:
		events[-1].world_target = materials[id].p

func _pulse(aim: Vector2) -> void:
	if pulse_left > 0.0 or energy <= 2.0: return
	var direction := face if aim.is_zero_approx() or not aim.is_finite() else aim.normalized()
	var selected := {}
	var shortest: float = stats.pulse_radius() * stats.pulse_radius()
	for item in materials:
		if not item.enabled or item.dropped or not available(item) or resin_open(item): continue
		var offset: Vector2 = item.p - p
		var distance_sq := offset.length_squared()
		if distance_sq > shortest or (distance_sq > 0.001 and direction.dot(offset.normalized()) < 0.5): continue
		if not clear_line(p,item.p): continue
		selected = item
		shortest = distance_sq
	if selected.is_empty():
		if not _beat_shown:
			_event("pulse_empty",-1)
			events[-1].direction = direction
			_beat_shown = true
		return
	_beat_shown = true
	face = direction
	energy -= 2.0
	pulse_left = 0.55
	pulse_flash = 0.18
	selected.stun = 0.42
	if selected.phase == "fading":
		# Disturbed bark and an almost-ripe head give enough time to finish the action.
		selected.phase_time = minf(selected.phase_time,selected.phase_duration-3.0)
	var required := shell_strength(selected)
	selected.hits = mini(required, int(selected.hits) + (2 if "beat" in stats.owned else 1))
	_event("material_hit",selected.id)
	if selected.hits < required:
		last_action = "种穗已经裂开" if region == "pond" else "树皮已经松动"
		return
	if region == "violet":
		_event("material_opened",selected.id)
		last_action = "树脂已露出，贴近按住 E 收取"
		return
	selected.dropped = true
	selected.phase = "fading"
	selected.phase_time = 0.0
	selected.phase_duration = DROP_SECONDS
	# The tuft can be caught near the lee side of the ear, never over an impassable shore.
	selected.p = Layout.move(layout,selected.anchor,direction * TUFT_DRIFT,5)
	_event("material_dropped",selected.id)
	last_action = "材料已松落，靠近拾取"

func step(delta: float, motion: Vector2, collect: bool, space_held: bool = false, pulse: bool = false, aim := Vector2.ZERO, entry_pressed := false) -> void:
	drawing_resin_id = -1
	if not pulse: _beat_shown = false
	super.step(delta,motion,collect,space_held,pulse,aim,entry_pressed)

func _harvest(dt: float) -> void:
	var source := nearby_material(RESIN_REACH,true)
	if not source.is_empty() and cargo < capacity():
		for index in _locked:
			if _flower_in_reach(index):
				super._harvest(dt)
				return
	if source.is_empty():
		super._harvest(dt)
		return
	_locked.clear()
	drawing_resin_id = source.id
	last_action = "正在收树脂"
	var drawn := float(source.get("resin_draw",0.0)) + dt
	if drawn < RESIN_SECONDS - 0.00001:
		source.resin_draw = drawn
		return
	material_count += 1
	_event("material_picked",source.id)
	_enter_phase(source,"empty",true)
	source.taken = true
	drawing_resin_id = -1
	last_action = "树脂 +1"

func snapshot() -> Dictionary:
	var result := super.snapshot()
	result.population_version = 1
	result.space_version = POND_SPACE_VERSION if region == "pond" else 4
	result.supply_rank = supply_rank
	return result

func restore(data: Variant, allow_gate_arrival := false) -> bool:
	if not data is Dictionary or data.get("population_version") != 1 or data.get("supply_rank") not in [0,1,2]: return false
	if not data.get("flowers") is Array or not data.get("materials") is Array: return false
	for i in data.flowers.size():
		var f = data.flowers[i]
		if not f is Dictionary or not f.get("p") is Vector2: return false
		if not f.get("enabled") is bool or f.enabled != active_flower(i,int(data.supply_rank)): return false
		if f.has("nectar_wait") and (not _number(f.nectar_wait) or f.nectar_wait > NECTAR_SECONDS[int(data.supply_rank)]): return false
		if not f.enabled and (f.get("phase") != "empty" or f.get("phase_time") != 0 or f.get("stock") != 0): return false
	for i in data.materials.size():
		var item = data.materials[i]
		if not item is Dictionary or not item.get("enabled") is bool or item.enabled != active_material(i,int(data.supply_rank)): return false
		if item.has("resin_draw"):
			if not _number(item.resin_draw) or item.resin_draw < 0.0 or item.resin_draw >= RESIN_SECONDS: return false
			if data.get("region") != "violet" or not item.enabled or item.get("dropped") != false or item.get("phase") not in ["ripe","fading"]: return false
			if not item.get("hits") is int or not item.has("band") or item.hits < shell_strength(item): return false
		if not item.enabled and (item.get("phase") != "empty" or item.get("phase_time") != 0 or item.get("taken") != false): return false
	var version = data.get("space_version",1)
	if version not in [1,2,3,4,POND_SPACE_VERSION] or data.get("region") not in ["pond","violet"]: return false
	if not data.get("p") is Vector2 or not data.p.is_finite(): return false
	var previous_position: Vector2 = data.p
	if version == 1:
		data = data.duplicate(true)
		data.p *= RegionalLayout.GROUND_SCALE
		for flower in data.flowers:
			if not flower.get("p") is Vector2: return false
			flower.p *= RegionalLayout.GROUND_SCALE
		for item in data.materials:
			if not item.get("anchor") is Vector2 or not item.get("p") is Vector2: return false
			var offset: Vector2 = item.p - item.anchor
			item.anchor *= RegionalLayout.GROUND_SCALE
			item.p = item.anchor + offset
		if data.get("trace") is Array:
			for point in data.trace:
				if point is Dictionary and _number(point.get("x")) and _number(point.get("y")):
					point.x *= RegionalLayout.GROUND_SCALE
					point.y *= RegionalLayout.GROUND_SCALE
	if version < 3 and data.p.x < RegionalLayout.WEST_JOIN+BODY:
		var old_coast := RegionalLayout.build(data.region,false)
		if version == 2: old_coast = RegionalLayout.expand(old_coast,false)
		if not Layout.walkable(old_coast,previous_position,BODY): return false
		var next_coast := RegionalLayout.build(data.region)
		if not Layout.walkable(next_coast,data.p,BODY):
			# Approach the old position from the safe entrance. Preserve the nearest
			# reachable shore point and all non-spatial trip and inventory state.
			data = data.duplicate()
			var entry: Vector2 = next_coast.nodes[0].p
			data.p = Layout.move(next_coast,entry,data.p-entry,BODY)
	if version < POND_SPACE_VERSION and data.region == "pond":
		if not data.get("trip_seed") is int or data.trip_seed < 1: return false
		var coast := RegionalLayout.build("pond",false)
		var original := _seeded_flower_sites(coast,data.trip_seed)
		if data.flowers.size() != original.size(): return false
		var historical: Array[Dictionary] = []
		for i in original.size():
			historical.append({"id":i,"p":original[i]*RegionalLayout.GROUND_SCALE})
		coast = RegionalLayout.expand(coast)
		if version == 4: _clear_pond_flowers(historical,coast,[JAR_RECT])
		for i in historical.size():
			if data.flowers[i].p != historical[i].p: return false
		data = data.duplicate(true)
		if version < 4: _clear_pond_flowers(data.flowers,coast,[JAR_RECT])
		_clear_pond_flowers(data.flowers,coast,_pond_obstacles(coast),32)
	if not super.restore(data,allow_gate_arrival): return false
	supply_rank = int(data.supply_rank)
	return true
