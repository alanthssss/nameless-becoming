extends "res://region_greybox/model.gd"
## Potential sites are spread through the meadow; undiscovered fertility is
## absent from the scene, not represented by empty collectible markers.
const RegionalLayout = preload("res://region_game/layout.gd")
const INITIAL_SITES := [0,3,6,8,10,12,15,18,20,22,24,26,28,30,32,34]
const MIDDLE_EXTRA := [1,4,7,13,16,21,27,33]
var supply_rank := 0

func configure(area: String,level: int,seed_value: int = 1) -> void:
	super.configure(area,level,seed_value)
	layout = RegionalLayout.build(region)
	var rng := RandomNumberGenerator.new()
	rng.seed = trip_seed*713+41
	var placed: Array[Vector2] = []
	for i in flowers.size():
		var cluster: int = i/3
		var x: float = Layout.CLUSTER_X[cluster]
		var edge_index := 0 if x <= layout.nodes[1].p.x else 1 if x <= layout.nodes[2].p.x else 2
		var a: Vector2 = layout.nodes[edge_index].p
		var b: Vector2 = layout.nodes[edge_index+1].p
		var center := a.lerp(b,(x-a.x)/(b.x-a.x))
		var best := center
		var best_gap := -1.0
		for attempt in 80:
			var candidate := center+Vector2(rng.randf_range(-76,76),rng.randf_range(-175,175))
			if not Layout.walkable(layout,candidate,62): continue
			var gap := INF
			for other in placed: gap = minf(gap,candidate.distance_to(other))
			if gap > best_gap:
				best = candidate
				best_gap = gap
			if gap >= 112: break
		flowers[i].p = best
		flowers[i].enabled = true
		placed.append(best)
	for item in materials: item.enabled = true
	supply_rank = 0
	set_supply_rank(0)

static func active_flower(id: int,rank: int) -> bool:
	return rank == 2 or id in INITIAL_SITES or (rank == 1 and id in MIDDLE_EXTRA)

static func active_material(id: int,rank: int) -> bool:
	return rank == 2 or id in [0,2,4] or (rank == 1 and id == 1)

func set_supply_rank(rank: int) -> void:
	supply_rank = clampi(rank,0,2)
	for f in flowers:
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
		_advance_life(f,dt*rate if f.phase in ["empty","bud"] else dt,false)
	for i in materials.size():
		var item: Dictionary = materials[i]
		if not item.enabled: continue
		_advance_life(item,dt*rate if item.phase in ["empty","bud"] else dt,true)
		if item.dropped or not available(item): continue
		item.stun = maxf(0,float(item.stun)-dt)
		if float(item.stun) > 0: continue
		var t := fmod(elapsed+float(i)*1.1,6.0)
		item.p = item.anchor+(Vector2.ZERO if t < 3 else Vector2(18*sin((t-3)/3*TAU),0))

func snapshot() -> Dictionary:
	var result := super.snapshot()
	result.population_version = 1
	result.supply_rank = supply_rank
	return result

func restore(data: Variant) -> bool:
	if not data is Dictionary or data.get("population_version") != 1 or data.get("supply_rank") not in [0,1,2]: return false
	if not data.get("flowers") is Array or not data.get("materials") is Array: return false
	for i in data.flowers.size():
		var f = data.flowers[i]
		if not f is Dictionary or not f.get("enabled") is bool or f.enabled != active_flower(i,int(data.supply_rank)): return false
		if not f.enabled and (f.get("phase") != "empty" or f.get("phase_time") != 0 or f.get("stock") != 0): return false
	for i in data.materials.size():
		var item = data.materials[i]
		if not item is Dictionary or not item.get("enabled") is bool or item.enabled != active_material(i,int(data.supply_rank)): return false
		if not item.enabled and (item.get("phase") != "empty" or item.get("phase_time") != 0 or item.get("taken") != false): return false
	if not super.restore(data): return false
	supply_rank = int(data.supply_rank)
	return true
