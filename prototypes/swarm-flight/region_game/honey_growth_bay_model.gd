extends RefCounted
## Disposable field exercise. All nectar, blooms and marks belong to this instance.
const POSITIONS := [
	Vector2(136,263), Vector2(237,265), Vector2(333,247), Vector2(429,262),
	Vector2(526,246), Vector2(624,235), Vector2(717,215), Vector2(455,302),
]
const LEVELS := [Vector3i(0,0,0), Vector3i(1,1,0), Vector3i(1,1,1), Vector3i(2,2,2)]
const CAPACITY := 10
const MANUAL := 0
const GARLAND := 1
const CASCADE := 2
var stage := 0
var starting_load := 0
var target := 0
var bee := Vector2.ZERO
var facing := Vector2.RIGHT
var clock := 0.0
var holding := false
var streak: Array[Dictionary] = []
var session := 0
var ready_at := 0.0
var mark := -1
var mark_until := 0.0
var ripe: Array[bool] = []
var marked_once: Array[bool] = []
var progress: Array[float] = []
var received := Vector3i.ZERO
var last_harvest: Array[Dictionary] = []
var harvest_count := 0

func reset(selected_stage: int, preloaded: int) -> void:
	stage = clampi(selected_stage,0,LEVELS.size()-1)
	starting_load = clampi(preloaded,0,CAPACITY)
	target = 0
	bee = Vector2(111,270)
	facing = Vector2.RIGHT
	clock = 0.0
	holding = false
	session = 0
	ready_at = 0.0
	mark = -1
	mark_until = 0.0
	ripe.resize(POSITIONS.size())
	ripe.fill(true)
	marked_once.resize(POSITIONS.size())
	marked_once.fill(false)
	progress.resize(POSITIONS.size())
	progress.fill(0.0)
	streak.clear()
	received = Vector3i.ZERO
	last_harvest.clear()
	harvest_count = 0

func total() -> int:
	return starting_load + received.x + received.y + received.z

func set_holding(active: bool) -> void:
	if active and not holding:
		session += 1
	holding = active

func step(delta: float) -> void:
	clock += delta
	var ability: Vector3i = LEVELS[stage]
	var interval := 5.0 if ability.y == 2 else 4.0
	if not streak.is_empty() and clock - float(streak.back().at) > interval:
		streak.clear()
	if clock >= mark_until:
		mark = -1
	var origin: Vector2 = POSITIONS[target]
	if bee.distance_to(origin) > 0.5:
		facing = bee.direction_to(origin)
		bee = bee.move_toward(origin,242.0*delta)
	if not holding or not ripe[target] or total() >= CAPACITY or bee.distance_to(origin) > 100.0:
		return
	if mark == target and not marked_once[target]:
		progress[target] = maxf(progress[target],0.4 if ability.x == 2 else 0.25)
		marked_once[target] = true
		mark = -1
	progress[target] += delta/0.8
	if progress[target] >= 1.0:
		_harvest(ability)

func _collect(index: int, kind: int, source: Vector2) -> bool:
	if index < 0 or not ripe[index] or total() >= CAPACITY:
		return false
	ripe[index] = false
	progress[index] = 0.0
	received[kind] += 1
	last_harvest.append({"flower":index,"kind":kind,"from":source,"at":clock})
	return true

func _nearest(origin: Vector2, radius: float, forward_only := false, unmarked_only := false) -> int:
	var best := -1
	var closest := radius
	for i in POSITIONS.size():
		if not ripe[i] or (unmarked_only and marked_once[i]):
			continue
		var point: Vector2 = POSITIONS[i]
		var distance := origin.distance_to(point)
		if distance > closest or (best >= 0 and is_equal_approx(distance,closest)):
			continue
		if forward_only and origin.direction_to(point).dot(facing) < cos(deg_to_rad(55.0)):
			continue
		best = i
		closest = distance
	return best

func _harvest(ability: Vector3i) -> void:
	last_harvest.clear()
	if not _collect(target,MANUAL,bee):
		return
	harvest_count += 1
	streak.append({"at":clock,"session":session})
	if streak.size() == 3:
		var origin: Vector2 = POSITIONS[target]
		var tail := target
		for i in ability.y:
			var next := _nearest(origin,145.0 if ability.y == 2 else 115.0)
			if not _collect(next,GARLAND,origin):
				break
			tail = next
		if tail != target and ability.z > 0 and streak.front().session == session and clock >= ready_at:
			var jumped := false
			for i in ability.z + 1:
				var next := _nearest(POSITIONS[tail],150.0 if ability.z == 2 else 120.0,true)
				if not _collect(next,CASCADE,POSITIONS[tail]):
					break
				tail = next
				jumped = true
			if jumped:
				ready_at = clock + (8.0 if ability.z == 2 else 10.0)
		streak.clear()
	if ability.x > 0:
		mark = _nearest(POSITIONS[target],150.0 if ability.x == 2 else 110.0,false,true)
		mark_until = clock + 4.0
