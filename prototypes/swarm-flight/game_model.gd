extends RefCounted
## Engine-independent rules. All movement uses bounded substeps, including bursts.
const CHARGE_SECONDS := 0.65
const CHARGE_READY := 0.75
const MAX_STAMINA := 100.0
const BURST_COST := 20.0
const FLIGHT_DRAIN := 2.0
const REST_RECOVERY := 24.0
const STORM_SECONDS := 55.0
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
var stamina := MAX_STAMINA
var energy_spent := 0.0
var energy_gained := 0.0
var rain_remaining := STORM_SECONDS
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
var dew: Array[Dictionary] = []
var sprayers: Array[Dictionary] = []
var puffs: Array[Dictionary] = []
var garden_awards: Array[int] = [0,0,0]
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
var blocked_cooldown := 0.0
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
	stamina = MAX_STAMINA
	energy_spent = 0.0
	energy_gained = 0.0
	rain_remaining = STORM_SECONDS
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
	dew.clear()
	sprayers.clear()
	puffs.clear()
	garden_awards[stage] = 0
	events.clear()
	checkpoint_index = -1
	rain_timer = 1.8
	started = false
	blocked_cooldown = 0.0
	rng.seed = 91027 + stage
	match stage:
		0:
			world_width = 3100
			bees = 1
			pods = [pod(760,400,2), pod(1500,235,2), pod(2350,525,2)]
			walls = [wall(1120,80,50,230), wall(1120,450,50,280), wall(1870,80,50,350), wall(1870,610,50,120), wall(2700,170,42,480,"curtain")]
			exit_pos = Vector2(2920,420)
			add_garden([Vector2(510,365),Vector2(1560,165),Vector2(2200,610)],[Vector2(2080,540)])
		1:
			world_width = 4200
			bees = 7
			pods = [pod(1750,370,1), pod(3290,380,1)]
			for pos in [Vector2(760,460), Vector2(1430,250), Vector2(2180,510), Vector2(2900,340)]:
				rings.append({"pos":pos,"active":false})
			walls = [wall(1110,80,45,100), wall(1110,430,45,300), wall(1800,80,45,190), wall(1800,600,45,130), wall(2530,80,45,175), wall(2530,565,45,165), wall(3660,150,42,500,"curtain")]
			exit_pos = Vector2(3990,420)
			add_garden([Vector2(950,210),Vector2(2260,635),Vector2(3140,285)],[Vector2(1330,390),Vector2(2730,495)])
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
			add_garden([Vector2(1060,290),Vector2(3020,370),Vector2(4420,570)],[Vector2(2330,510),Vector2(3750,280)])
	exit_ready = pods.is_empty()
	save_checkpoint()

func add_garden(dew_positions: Array, flower_positions: Array) -> void:
	for pos in dew_positions:
		dew.append({"pos":pos,"collected":false})
	for pos in flower_positions:
		sprayers.append({"pos":pos,"timer":2.4+sprayers.size()*0.6,"stun_left":0.0,"flash":0.0,"rewarded":false})

func garden_total() -> int:
	return garden_awards[0]+garden_awards[1]+garden_awards[2]

func reset_journey() -> void:
	bursts = 0
	recoveries = 0
	rings_hit = 0
	garden_awards = [0,0,0]

func sprayer_phase(index: int) -> String:
	var flower := sprayers[index]
	if flower.stun_left > 0: return "calm"
	if flower.flash > 0: return "sneeze"
	return "warning" if flower.timer <= 0.8 else "idle"

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
		started = true
		charging = true
		charge = minf(1.0,charge + dt / CHARGE_SECONDS)
	elif not held and charging:
		charging = false
		if charge >= CHARGE_READY and can_burst():
			spend_energy(BURST_COST)
			started = true
			burst_left = 0.48 + charge * 0.06
			bursts += 1
			emit("burst",p)
		elif charge >= CHARGE_READY:
			emit("tired",p)
		else:
			emit("charge_cancel",p)
		charge = 0.0
	var remaining := dt
	while remaining > 0.00001 and phase == "playing":
		var sub := minf(remaining,1.0 / 120.0)
		advance(direction,sub)
		remaining -= sub
	camera_x = clampf(p.x - 480,0,world_width - 1280)

func advance(direction: Vector2, dt: float) -> void:
	time += dt
	if started:
		if shelter_index_at(p) >= 0:
			gain_energy(REST_RECOVERY*dt)
		else:
			spend_energy(FLIGHT_DRAIN*dt)
			if stage == 2: rain_remaining = maxf(0.0,rain_remaining-dt)
		if stamina <= 0.0 and burst_left <= 0.0:
			restore_checkpoint("exhaustion")
			return
		if stage == 2 and rain_remaining <= 0.0:
			restore_checkpoint("timeout")
			return
	blocked_cooldown = maxf(0.0, blocked_cooldown-dt)
	invulnerable = maxf(0,invulnerable-dt)
	if burst_left > 0:
		burst_left = maxf(0,burst_left-dt)
		velocity = face * BURST_SPEED
	else:
		var target := direction * (145.0 if charging else CRUISE_SPEED)
		# The environment moves the bee only after the player starts flying.
		if started and shelter_index_at(p) < 0:
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
				if blocked_cooldown <= 0.0 and velocity.length() > 40.0:
					emit("blocked",p)
					events.back()["material"] = obstacle.kind
					blocked_cooldown = 1.8
				# Resolve each axis independently: holding against a wall still slides.
				var proposed := p
				p = before
				var expanded := r.grow(radius)
				# Unfolding from radius 9 to 14 can begin inside the expanded wall.
				# Depenetrate to its nearest edge before sliding; otherwise every
				# bounded substep is rejected and the bee can never fly away.
				if expanded.has_point(before):
					var edges := [absf(before.x-expanded.position.x),absf(before.x-expanded.end.x),absf(before.y-expanded.position.y),absf(before.y-expanded.end.y)]
					var nearest := edges.find(edges.min())
					match nearest:
						0: p.x = expanded.position.x-0.01
						1: p.x = expanded.end.x+0.01
						2: p.y = expanded.position.y-0.01
						3: p.y = expanded.end.y+0.01
				if not expanded.has_point(Vector2(proposed.x,p.y)):
					p.x = proposed.x
				if not expanded.has_point(Vector2(p.x,proposed.y)):
					p.y = proposed.y
				if not is_equal_approx(p.x,proposed.x): velocity.x = 0
				if not is_equal_approx(p.y,proposed.y): velocity.y = 0
				burst_left = 0
	for trapped in pods:
		if not trapped.open and burst_left > 0 and p.distance_to(trapped.pos) < 48:
			trapped.open = true
			bees += int(trapped.count)
			gain_energy(40.0)
			emit("rescue",trapped.pos)
			save_checkpoint()
	for i in range(rings.size()):
		var flower := rings[i]
		if burst_left > 0 and not flower.active and p.distance_to(flower.pos) < 60:
			flower.active = true
			rings_hit += 1
			gain_energy(8.0)
			burst_left = 0.60
			# Preview and launch use the same fixed direction from the flower center.
			face = ring_direction(i)
			emit("ring",flower.pos)
	var old_recoveries := recoveries
	advance_garden(dt)
	if old_recoveries != recoveries: return
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
		if shelter_contains(p,shelter):
			under_shelter = true
			if not shelter.reached:
				shelter.reached = true
				checkpoint_index = i
				storm_x = minf(storm_x,p.x - 440)
				save_checkpoint()
				checkpoint["p"] = shelter.pos
				emit("checkpoint",shelter.pos)
	if started and not under_shelter:
		storm_x += 145 * dt
	else:
		storm_x = minf(storm_x,p.x-300)
	if p.x < storm_x + 45:
		hurt("storm")

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
		elif p.distance_to(drop.pos) < 25 and shelter_index_at(p) < 0:
			if burst_left > 0:
				emit("rain_break",drop.pos)
			else:
				var old_recoveries := recoveries
				hurt()
				if recoveries != old_recoveries:
					return
			# A lethal hit may restore the checkpoint and clear the array.
			if i < drops.size():
				drops.remove_at(i)

func advance_garden(dt: float) -> void:
	for drop in dew:
		if not drop.collected and p.distance_to(drop.pos) < 30:
			drop.collected = true
			garden_awards[stage] += 1
			var before_gain := stamina
			gain_energy(12.0)
			emit("dew",drop.pos)
			events.back()["reward"] = stamina-before_gain
	for i in sprayers.size():
		var flower := sprayers[i]
		flower.flash = maxf(0,flower.flash-dt)
		flower.stun_left = maxf(0,flower.stun_left-dt)
		if burst_left > 0 and flower.stun_left <= 0 and p.distance_to(flower.pos) < 58:
			flower.stun_left = 6.0
			flower.timer = 4.5
			flower.flash = 0.0
			var before_gain := stamina
			if not flower.rewarded:
				gain_energy(10.0)
				flower.rewarded = true
			emit("flower_calm",flower.pos)
			events.back()["reward"] = stamina-before_gain
			for j in range(puffs.size()-1,-1,-1):
				if puffs[j].source == i: puffs.remove_at(j)
		if not started or flower.stun_left > 0 or absf(p.x-flower.pos.x) > 650: continue
		flower.timer -= dt
		if flower.timer <= 0:
			flower.timer = 4.5
			flower.flash = 0.25
			for angle in [-0.2,0.0,0.2]:
				puffs.append({"pos":flower.pos-Vector2(38,0),"vel":Vector2.LEFT.rotated(angle)*200,"life":4.0,"source":i})
			emit("spray",flower.pos)
	for i in range(puffs.size()-1,-1,-1):
		var puff := puffs[i]
		puff.pos += puff.vel*dt
		puff.life -= dt
		var blocked: bool = puff.life <= 0 or shelter_index_at(puff.pos) >= 0
		for obstacle in walls:
			if not obstacle.broken and obstacle.rect.grow(8).has_point(puff.pos):
				blocked = true
				break
		if blocked:
			puffs.remove_at(i)
		elif p.distance_to(puff.pos) < 25 and shelter_index_at(p) < 0:
			if burst_left > 0:
				emit("rain_break",puff.pos)
			else:
				var old_recoveries := recoveries
				hurt("sneeze",12.0)
				if recoveries != old_recoveries: return
			puffs.remove_at(i)

func hurt(reason := "rain", cost := 30.0) -> void:
	if invulnerable > 0:
		return
	spend_energy(cost)
	invulnerable = 1.8
	emit("hit",p)
	events.back()["reason"] = reason
	events.back()["cost"] = cost
	if stamina <= 0.0:
		restore_checkpoint("rain")

func save_checkpoint() -> void:
	checkpoint = {"p":p,"bees":bees,"pods":pods.duplicate(true),"walls":walls.duplicate(true),"rings":rings.duplicate(true),"shelters":shelters.duplicate(true),"dew":dew.duplicate(true),"sprayers":sprayers.duplicate(true),"storm_x":storm_x,"checkpoint_index":checkpoint_index,"rain_remaining":rain_remaining}

func restore_checkpoint(reason := "manual") -> void:
	if checkpoint.is_empty():
		return
	recoveries += 1
	p = checkpoint.p
	bees = checkpoint.bees
	pods.assign(checkpoint.pods.duplicate(true))
	walls.assign(checkpoint.walls.duplicate(true))
	rings.assign(checkpoint.rings.duplicate(true))
	shelters.assign(checkpoint.shelters.duplicate(true))
	dew.assign(checkpoint.dew.duplicate(true))
	sprayers.assign(checkpoint.sprayers.duplicate(true))
	garden_awards[stage] = 0
	for drop in dew:
		if drop.collected: garden_awards[stage] += 1
	storm_x = checkpoint.storm_x
	checkpoint_index = checkpoint.checkpoint_index
	drops.clear()
	puffs.clear()
	phase = "playing"
	gain_energy(MAX_STAMINA)
	rain_remaining = maxf(20.0,checkpoint.get("rain_remaining",STORM_SECONDS))
	invulnerable = 2.5
	rain_timer = 2
	clear_input()
	started = false
	camera_x = clampf(p.x-480,0,world_width-1280)
	emit("recover_"+reason,p)

func can_burst() -> bool:
	return stamina >= BURST_COST

func spend_energy(amount: float) -> void:
	var used := minf(stamina,maxf(0.0,amount))
	stamina -= used
	energy_spent += used

func gain_energy(amount: float) -> void:
	var gained := minf(MAX_STAMINA-stamina,maxf(0.0,amount))
	stamina += gained
	energy_gained += gained

func ring_direction(index: int) -> Vector2:
	var destination: Vector2 = rings[index+1].pos if index+1 < rings.size() else exit_pos
	return (destination-Vector2(rings[index].pos)).normalized()

func shelter_contains(point: Vector2, shelter: Dictionary) -> bool:
	return Rect2(shelter.pos-Vector2(118,64),Vector2(236,140)).has_point(point)

func shelter_index_at(point: Vector2) -> int:
	for i in shelters.size():
		if shelter_contains(point,shelters[i]): return i
	return -1

func target_position() -> Vector2:
	for trapped in pods:
		if not trapped.open:
			return trapped.pos
	return exit_pos

func objective() -> String:
	if stage == 0:
		return "救出卷叶里的六只伙伴" if not exit_ready else "伙伴到齐 · 冲开干叶帘，去花桥"
	if stage == 1:
		return "接上最后两只伙伴 · 风花可以借力" if not exit_ready else "九只到齐 · 穿过干叶帘，去老树"
	return "赶在暴雨前回家 · 大叶下可以休息"

func hint() -> String:
	if charging and not can_burst():
		return "冲刺需要 20 体力 · 按 R 返回恢复点补充；大叶下可以休息"
	if charging:
		return "准备好了 · 松开空格冲刺，方向键可以调整朝向" if charge >= CHARGE_READY else "继续按住空格 · 等光环亮起，再松开"
	if not started:
		return "方向键 / WASD 飞行   ·   按住空格蓄力，亮起后松开冲刺"
	if stage == 0 and bees == 1:
		return "飞向呼救的卷叶 · 面朝伙伴，按住空格，亮起后松开"
	if shelter_index_at(p) >= 0:
		return "叶下休息 · " + ("体力充足" if stamina >= MAX_STAMINA else "体力正在恢复") + "，暴雨倒计时暂停"
	return "飞行缓慢耗体力 · 空格蓄力冲刺消耗 20 · 叶下恢复 · Esc 暂停"

func context_cue() -> Dictionary:
	# Local prompts appear only within an actionable distance, never over the whole map.
	if charging:
		var words := "体力不足 20 · R 返回恢复点" if not can_burst() else ("松开空格 · 冲刺消耗 20" if charge >= CHARGE_READY else "按住空格 · 蓄力中")
		return {"pos":p,"text":words,"kind":"charge"}
	var rest_index := shelter_index_at(p)
	if rest_index >= 0:
		return {"pos":shelters[rest_index].pos,"text":"叶下安全 · " + ("体力充足" if stamina >= MAX_STAMINA else "体力恢复中"),"kind":"shelter"}
	for trapped in pods:
		if not trapped.open and p.distance_to(trapped.pos) < 300:
			return {"pos":trapped.pos,"text":"冲开卷叶 · 救出伙伴","kind":"pod"}
	for obstacle in walls:
		if obstacle.kind == "curtain" and not obstacle.broken and absf(p.x-obstacle.rect.get_center().x) < 270 and p.y > obstacle.rect.position.y-40 and p.y < obstacle.rect.end.y+40:
			return {"pos":Vector2(obstacle.rect.get_center().x,p.y),"text":"干叶帘 · 蓄力冲开","kind":"curtain"}
	for i in sprayers.size():
		var flower := sprayers[i]
		if p.distance_to(flower.pos) < 260:
			var state := sprayer_phase(i)
			var words := "喷嚏花 · 冲刺让它安静六秒"
			if state == "warning" or state == "sneeze": words = "要打喷嚏啦 · 绕开或冲刺安抚"
			elif state == "calm": words = "安静啦 · 可以放心通过"
			return {"pos":flower.pos,"text":words,"kind":"sprayer"}
	for drop in dew:
		if not drop.collected and p.distance_to(drop.pos) < 170:
			return {"pos":drop.pos,"text":"晨露 · 轻触收集，体力 +12","kind":"dew"}
	for flower in rings:
		if p.distance_to(flower.pos) < (115 if flower.active else 270):
			return {"pos":flower.pos,"text":"花瓣已收拢 · 继续向前" if flower.active else "冲进风花 · 沿箭头借力一次","kind":"spent" if flower.active else "ring"}
	for shelter in shelters:
		if p.distance_to(shelter.pos) < 230:
			return {"pos":shelter.pos,"text":"大叶下休息 · 恢复体力","kind":"shelter"}
	if exit_ready and p.distance_to(exit_pos) < 330:
		return {"pos":exit_pos,"text":"到家了 · 飞进树洞" if stage == 2 else "一起向前 · 飞过叶拱","kind":"exit"}
	return {}
