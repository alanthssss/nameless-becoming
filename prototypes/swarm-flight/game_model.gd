extends RefCounted
## Engine-independent rules. All movement uses bounded substeps, including bursts.
const CHARGE_SECONDS := 0.65
const CRUISE_SPEED := 250.0
const BURST_SPEED := 880.0
var stage := 0
var phase := "playing"
var p := Vector2(180, 420)
var velocity := Vector2.ZERO
var face := Vector2.RIGHT
var charge := 0.0
var charging := false
var burst_left := 0.0
var bees := 1
var hp := 3
var invulnerable := 0.0
var time := 0.0
var camera_x := 0.0
var world_width := 3000.0
var storm_x := -1000.0
var storm_active := false
var pods: Array[Dictionary] = []
var walls: Array[Dictionary] = []
var rings: Array[Dictionary] = []
var shelters: Array[Dictionary] = []
var drops: Array[Dictionary] = []
var exit_pos := Vector2.ZERO
var exit_ready := false
var events: Array[Dictionary] = []
var bursts := 0
var recoveries := 0
var rings_hit := 0
var checkpoint: Dictionary = {}
var rain_timer := 1.6
var checkpoint_index := -1
var started := false
var rng := RandomNumberGenerator.new()

func _init() -> void:
	load_stage(0)

func pod(x: float, y: float, count: int) -> Dictionary:
	return {"pos": Vector2(x,y), "open": false, "count": count}

func wall(x: float, y: float, w: float, h: float, kind := "stem") -> Dictionary:
	return {"rect": Rect2(x,y,w,h), "kind": kind, "broken": false}

func load_stage(index: int) -> void:
	stage = clampi(index, 0, 2)
	phase = "playing"
	p = Vector2(180,420)
	velocity = Vector2.ZERO
	face = Vector2.RIGHT
	charge = 0.0
	charging = false
	burst_left = 0.0
	hp = 3
	invulnerable = 1.0
	time = 0.0
	camera_x = 0.0
	storm_x = -1000.0
	storm_active = false
	pods.clear()
	walls.clear()
	rings.clear()
	shelters.clear()
	drops.clear()
	events.clear()
	checkpoint_index = -1
	rain_timer = 1.8
	started = false
	rng.seed = 91027 + stage
	match stage:
		0:
			world_width = 3100
			bees = 1
			pods = [pod(760,400,2), pod(1500,235,2), pod(2350,525,2)]
			walls = [wall(1120,80,50,230), wall(1120,450,50,280), wall(1870,80,50,350), wall(1870,610,50,120), wall(2700,170,42,480,"curtain")]
			exit_pos = Vector2(2920,420)
		1:
			world_width = 4200
			bees = 7
			pods = [pod(1750,370,1), pod(3290,380,1)]
			for pos in [Vector2(760,460), Vector2(1430,250), Vector2(2180,510), Vector2(2900,340)]:
				rings.append({"pos":pos,"active":false})
			walls = [wall(1110,80,45,100), wall(1110,430,45,300), wall(1800,80,45,190), wall(1800,600,45,130), wall(2530,80,45,175), wall(2530,565,45,165), wall(3660,150,42,500,"curtain")]
			exit_pos = Vector2(3990,420)
		2:
			world_width = 5100
			bees = 9
			storm_x = -260
			storm_active = true
			walls = [wall(800,80,48,190), wall(800,490,48,240), wall(1200,190,42,450,"curtain"), wall(2110,80,48,230), wall(2110,545,48,185), wall(2540,160,42,480,"curtain"), wall(3330,80,48,280), wall(3330,590,48,140), wall(3970,150,42,520,"curtain")]
			for pos in [Vector2(1640,400),Vector2(2970,430)]:
				shelters.append({"pos":pos,"reached":false})
			for pos in [Vector2(530,400),Vector2(1810,420),Vector2(3510,460),Vector2(4260,430)]:
				rings.append({"pos":pos,"active":false})
			exit_pos = Vector2(4790,430)
	exit_ready = pods.is_empty()
	save_checkpoint()

func emit(kind: String, pos: Vector2) -> void:
	events.append({"kind":kind,"pos":pos})

func clear_input() -> void:
	charging = false
	charge = 0.0
	burst_left = 0.0
	velocity = Vector2.ZERO

func step(direction: Vector2, held: bool, delta: float) -> void:
	if phase != "playing":
		return
	var dt := clampf(delta,0.0,0.1)
	if dt <= 0:
		return
	direction = direction.limit_length(1.0)
	if direction.length() > 0.01:
		started = true
		# Each short launch keeps its chosen direction; a ring can redirect it.
		if burst_left <= 0:
			face = direction
	if held and burst_left <= 0:
		charging = true
		charge = minf(1.0,charge + dt / CHARGE_SECONDS)
	elif not held and charging:
		charging = false
		if charge >= 0.75:
			burst_left = 0.48 + charge * 0.06
			bursts += 1
			emit("burst",p)
		charge = 0.0
	var remaining := dt
	while remaining > 0.00001 and phase == "playing":
		var sub := minf(remaining,1.0 / 120.0)
		advance(direction,sub)
		remaining -= sub
	camera_x = clampf(p.x - 480,0,world_width - 1280)

func advance(direction: Vector2, dt: float) -> void:
	time += dt
	invulnerable = maxf(0,invulnerable-dt)
	if burst_left > 0:
		burst_left = maxf(0,burst_left-dt)
		velocity = face * BURST_SPEED
	else:
		var target := direction * (145.0 if charging else CRUISE_SPEED)
		# The environment moves the bee only after the player starts flying.
		if started:
			target += Vector2(12 if stage == 0 else 34,sin(time * 1.5 + p.x * 0.002) * (10 if charging else 24))
		velocity = velocity.move_toward(target,dt * 1800)
	var before := p
	p += velocity * dt
	p.x = clampf(p.x,35,world_width-50)
	p.y = clampf(p.y,100,710)
	for obstacle in walls:
		if obstacle.broken:
			continue
		var r: Rect2 = obstacle.rect
		var radius := 9.0 if charging else 14.0
		if r.grow(radius).has_point(p):
			if obstacle.kind == "curtain" and burst_left > 0:
				obstacle.broken = true
				emit("gate",r.get_center())
			else:
				# Resolve each axis independently: holding against a wall still slides.
				var proposed := p
				p = before
				if not r.grow(radius).has_point(Vector2(proposed.x,before.y)):
					p.x = proposed.x
				if not r.grow(radius).has_point(Vector2(p.x,proposed.y)):
					p.y = proposed.y
				burst_left = 0
	for trapped in pods:
		if not trapped.open and burst_left > 0 and p.distance_to(trapped.pos) < 48:
			trapped.open = true
			bees += int(trapped.count)
			hp = 3
			emit("rescue",trapped.pos)
			save_checkpoint()
	for i in range(rings.size()):
		var flower := rings[i]
		if burst_left > 0 and not flower.active and p.distance_to(flower.pos) < 60:
			flower.active = true
			rings_hit += 1
			burst_left = 0.60
			var next_pos: Vector2 = rings[i+1].pos if i+1 < rings.size() else exit_pos
			# Only chain toward nearby flowers; the final launch stays nearly level.
			face = (next_pos-p).normalized()
			emit("ring",flower.pos)
	exit_ready = true
	for trapped in pods:
		if not trapped.open:
			exit_ready = false
	if stage == 2:
		advance_storm(dt)
	# Rain is introduced after the safe first rescue, never during the controls lesson.
	if started and (stage > 0 or bees > 1):
		advance_rain(dt)
	if p.distance_to(exit_pos) < 85 and exit_ready:
		phase = "ending" if stage == 2 else "transition"
		clear_input()
		emit("finish",p)

func advance_storm(dt: float) -> void:
	var under_shelter := false
	for i in range(shelters.size()):
		var shelter := shelters[i]
		if p.distance_to(shelter.pos) < 140:
			under_shelter = true
			if not shelter.reached:
				shelter.reached = true
				checkpoint_index = i
				hp = 3
				storm_x = minf(storm_x,p.x - 440)
				save_checkpoint()
				emit("recover",p)
	if started and not under_shelter:
		storm_x += 145 * dt
	else:
		storm_x = minf(storm_x,p.x-300)
	if p.x < storm_x + 45:
		hurt()

func advance_rain(dt: float) -> void:
	rain_timer -= dt
	if rain_timer <= 0:
		rain_timer = 1.25 if stage == 2 else 2.0
		drops.append({"pos":Vector2(p.x + rng.randf_range(80,400),70),"vel":Vector2(-45,320 if stage == 2 else 245)})
	for i in range(drops.size()-1,-1,-1):
		var drop := drops[i]
		drop.pos += drop.vel * dt
		var sheltered := false
		for shelter in shelters:
			if absf(drop.pos.x-shelter.pos.x) < 125 and drop.pos.y > shelter.pos.y-95:
				sheltered = true
		if drop.pos.y > 760 or sheltered:
			drops.remove_at(i)
		elif p.distance_to(drop.pos) < 25:
			if burst_left > 0:
				emit("gate",drop.pos)
			else:
				var old_recoveries := recoveries
				hurt()
				if recoveries != old_recoveries:
					return
			# A lethal hit may restore the checkpoint and clear the array.
			if i < drops.size():
				drops.remove_at(i)

func hurt() -> void:
	if invulnerable > 0:
		return
	hp -= 1
	invulnerable = 1.8
	emit("hit",p)
	if hp <= 0:
		restore_checkpoint()

func save_checkpoint() -> void:
	checkpoint = {"p":p,"bees":bees,"pods":pods.duplicate(true),"walls":walls.duplicate(true),"rings":rings.duplicate(true),"shelters":shelters.duplicate(true),"storm_x":storm_x,"checkpoint_index":checkpoint_index}

func restore_checkpoint() -> void:
	if checkpoint.is_empty():
		return
	recoveries += 1
	p = checkpoint.p
	bees = checkpoint.bees
	pods.assign(checkpoint.pods.duplicate(true))
	walls.assign(checkpoint.walls.duplicate(true))
	rings.assign(checkpoint.rings.duplicate(true))
	shelters.assign(checkpoint.shelters.duplicate(true))
	storm_x = checkpoint.storm_x
	checkpoint_index = checkpoint.checkpoint_index
	drops.clear()
	phase = "playing"
	hp = 3
	invulnerable = 2.5
	rain_timer = 2
	clear_input()
	started = false
	camera_x = clampf(p.x-480,0,world_width-1280)
	emit("recover",p)

func target_position() -> Vector2:
	for trapped in pods:
		if not trapped.open:
			return trapped.pos
	return exit_pos

func objective() -> String:
	if stage == 0:
		return "把卷叶里的伙伴带出来" if not exit_ready else "伙伴都跟上了，穿过右边的叶帘"
	if stage == 1:
		return "借风花连飞，接上最后两只伙伴" if not exit_ready else "九只都在，朝树洞出发"
	return "越过雨线，带大家进入发光的树洞"

func hint() -> String:
	if charging:
		return "松开空格，冲！" if charge >= 0.75 else "收拢蜂群……按住空格蓄力"
	if stage == 0 and bees == 1:
		return "靠近卷叶 → 按住空格 → 朝卷叶松开，救出伙伴"
	if stage == 1 and rings_hit == 0:
		return "冲进蓝色风花，它会把蜂群接力送往下一朵"
	if stage == 2:
		for shelter in shelters:
			if p.distance_to(shelter.pos) < 140:
				return "叶下可以歇一口气。往右飞，继续最后一程。"
	return "方向键 / WASD 飞行    按住空格收拢，松开冲刺"
