extends RefCounted
## Engine-independent rules. All movement uses bounded substeps, including bursts.
const Data = preload("res://chapter_data.gd")
const STAGE_COUNT := Data.STAGE_COUNT
const CHARGE_SECONDS := 0.50
const CHARGE_READY := 0.80
const MAX_STAMINA := 100.0
const BURST_COST := 20.0
const FLIGHT_DRAIN := 2.0
const REST_RECOVERY := 24.0
const STORM_SECONDS := 55.0
const CRUISE_SPEED := 250.0
const CHARGE_SPEED := 90.0
const BURST_SPEED := 880.0
const BURST_SECONDS := 0.54
const FLIGHT_ACCELERATION := 1800.0
const RELEASE_BRAKING := 4000.0
const BURST_BRAKING := 30000.0
const SHIELD_SECONDS := 5.0
var stage := 0
var phase := "playing"
var p := Vector2(180, 420)
var velocity := Vector2.ZERO
var face := Vector2.RIGHT
var charge := 0.0
var charging := false
var burst_left := 0.0
var burst_braking := false
# Legacy saved total includes the player; rescued friends = bees - 1.
# Friends leave after rescue and never participate in flight collision/damage.
var bees := 1
var stamina := MAX_STAMINA
var energy_spent := 0.0
var energy_gained := 0.0
var rain_remaining := STORM_SECONDS
var invulnerable := 0.0
var shield_left := 0.0
var shield_feedback_left := 0.0
var shields: Array[Dictionary] = []
var rain_fields: Array[Dictionary] = []
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
var garden_awards: Array[int] = [0,0,0,0]
var sections: Array[Dictionary] = []
var chapter: Dictionary = {}
var completed := false
var exit_pos := Vector2.ZERO
var exit_ready := false
var events: Array[Dictionary] = []
var bursts := 0
var recoveries := 0
var rings_hit := 0
# Presentation only: consecutive wind flowers during one uninterrupted dash.
var wind_chain := 0
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
	stage = clampi(index, 0, STAGE_COUNT-1)
	chapter = Data.build(stage)
	completed = false
	phase = "playing"
	p = Vector2(180,420)
	velocity = Vector2.ZERO
	face = Vector2.RIGHT
	charge = 0.0
	charging = false
	burst_left = 0.0
	burst_braking = false
	wind_chain = 0
	stamina = MAX_STAMINA
	energy_spent = 0.0
	energy_gained = 0.0
	rain_remaining = STORM_SECONDS
	invulnerable = 1.0
	shield_left = 0.0
	shield_feedback_left = 0.0
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
	world_width = chapter.world_width
	bees = chapter.base_bees
	storm_active = chapter.storm
	storm_x = -260 if storm_active else -1000
	sections.assign(chapter.sections)
	pods.assign(chapter.pods)
	walls.assign(chapter.walls)
	rings.assign(chapter.rings)
	shelters.assign(chapter.shelters)
	dew.assign(chapter.dew)
	sprayers.assign(chapter.sprayers)
	shields.assign(chapter.shields)
	rain_fields.assign(chapter.rain_fields)
	exit_pos = chapter.exit_pos
	rain_remaining = sections[0].budget

	exit_ready = false
	save_checkpoint()

func add_garden(dew_positions: Array, flower_positions: Array) -> void:
	for pos in dew_positions:
		dew.append({"pos":pos,"collected":false})
	for pos in flower_positions:
		sprayers.append({"pos":pos,"timer":2.4+sprayers.size()*0.6,"stun_left":0.0,"flash":0.0,"rewarded":false})

func garden_total() -> int:
	var total := 0
	for value in garden_awards: total += value
	return total

func reset_journey() -> void:
	bursts = 0
	recoveries = 0
	rings_hit = 0
	garden_awards = [0,0,0,0]
	completed = false

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
	burst_braking = false
	wind_chain = 0
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
		if is_equal_approx(charge,CHARGE_READY):
			charge = CHARGE_READY
	elif not held and charging:
		charging = false
		if charge >= CHARGE_READY and can_burst():
			spend_energy(BURST_COST)
			started = true
			burst_left = BURST_SECONDS
			burst_braking = false
			wind_chain = 0
			bursts += 1
			emit("burst",p)
		elif charge >= CHARGE_READY:
			emit("tired",p)
		else:
			emit("charge_cancel",p)
		charge = 0.0
	var remaining := dt
	var recoveries_before := recoveries
	while remaining > 0.00001 and phase == "playing":
		var sub := minf(remaining,1.0 / 120.0)
		advance(direction,sub)
		# A recovery is the end of this input frame. Do not let its remaining
		# substeps move the restored bee with the old direction.
		if recoveries != recoveries_before:
			break
		remaining -= sub
	camera_x = clampf(p.x - 480,0,world_width - 1280)

func advance(direction: Vector2, dt: float) -> void:
	time += dt
	if started:
		if shelter_index_at(p) >= 0:
			gain_energy(REST_RECOVERY*dt)
		else:
			spend_energy(FLIGHT_DRAIN*dt)
			if storm_active: rain_remaining = maxf(0.0,rain_remaining-dt)
		if stamina <= 0.0 and burst_left <= 0.0:
			restore_checkpoint("exhaustion")
			return
		if storm_active and rain_remaining <= 0.0:
			restore_checkpoint("timeout")
			return
	var was_shielded := shield_left > 0
	shield_left = maxf(0.0,shield_left-dt)
	shield_feedback_left = maxf(0.0,shield_feedback_left-dt)
	if was_shielded and shield_left <= 0: emit("shield_end",p)
	blocked_cooldown = maxf(0.0, blocked_cooldown-dt)
	invulnerable = maxf(0,invulnerable-dt)
	if burst_left > 0:
		burst_left = maxf(0,burst_left-dt)
		velocity = face * BURST_SPEED
		if burst_left <= 0.0:
			wind_chain = 0
			burst_braking = true
	else:
		var target := direction * (CHARGE_SPEED if charging else CRUISE_SPEED)
		# Wind colors active flight; it never moves an idle or aiming bee.
		if not charging and direction.length() > 0.01 and shelter_index_at(p) < 0:
			target += Vector2(12 if stage == 0 else 34,sin(time * 1.5 + p.x * 0.002) * 24)
		var acceleration := FLIGHT_ACCELERATION
		if burst_braking:
			acceleration = BURST_BRAKING
		elif direction.is_zero_approx() or charging:
			acceleration = RELEASE_BRAKING
		velocity = velocity.move_toward(target,dt * acceleration)
		if velocity.is_equal_approx(target):
			burst_braking = false
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
			if obstacle.kind == "curtain" and burst_left > 0 and gate_ready(obstacle):
				obstacle.broken = true
				emit("gate",r.get_center())
			else:
				if blocked_cooldown <= 0.0 and velocity.length() > 40.0:
					emit("blocked",p)
					events.back()["material"] = "waiting" if not gate_ready(obstacle) else obstacle.kind
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
				wind_chain = 0
	# Pickups resolve before all weather damage and rescue snapshots this substep.
	collect_shields()
	for trapped in pods:
		if not trapped.open and burst_left > 0 and p.distance_to(trapped.pos) < 48:
			trapped.open = true
			bees += int(trapped.count)
			var before_rescue_gain := stamina
			gain_energy(40.0)
			emit("rescue",trapped.pos)
			events.back()["count"] = int(trapped.count)
			events.back()["reward"] = stamina-before_rescue_gain
			save_checkpoint(checkpoint.get("p",p))
	for i in range(rings.size()):
		var flower := rings[i]
		if burst_left > 0 and not flower.active and p.distance_to(flower.pos) < 60:
			flower.active = true
			rings_hit += 1
			wind_chain += 1
			var before_ring_gain := stamina
			gain_energy(8.0)
			burst_left = 0.60
			# Preview and launch use the same fixed direction from the flower center.
			face = ring_direction(i)
			emit("ring",flower.pos)
			events.back()["chain"] = wind_chain
			events.back()["reward"] = stamina-before_ring_gain
	var old_recoveries := recoveries
	advance_garden(dt)
	if old_recoveries != recoveries: return
	advance_shelters()
	exit_ready = rescued_count() == rescue_total() and completed_sections() == sections.size()
	if storm_active:
		advance_storm(dt)
		if old_recoveries != recoveries: return
	# Weather belongs to authored encounters; existing drops still move and collide.
	if started:
		advance_rain(dt)
		if old_recoveries != recoveries: return
	if p.distance_to(exit_pos) < 85 and exit_ready:
		phase = "ending" if stage == STAGE_COUNT-1 else "transition"
		completed = phase == "ending"
		drops.clear()
		puffs.clear()
		shield_left = 0.0
		clear_input()
		emit("finish",p)

func collect_shields() -> void:
	for leaf in shields:
		if not leaf.collected and p.distance_to(leaf.pos) < 38:
			leaf.collected = true
			shield_left = SHIELD_SECONDS
			emit("shield",leaf.pos)

func advance_shelters() -> void:
	for i in shelters.size():
		var shelter: Dictionary = shelters[i]
		if shelter_contains(p,shelter) and shelter.reached and i == checkpoint_index:
			# A side-path pickup can happen after first crossing the wide leaf.
			# Returning to the current safe area must retain that earned collection.
			if _flags(dew,"collected") != _flags(checkpoint.dew,"collected") or _flags(shields,"collected") != _flags(checkpoint.shields,"collected") or _flags(rings,"active") != _flags(checkpoint.rings,"active"):
				save_checkpoint(shelter.pos)
				emit("checkpoint_update",shelter.pos)
		if shelter_contains(p,shelter) and not shelter.reached:
			# Checkpoints advance in order and never move backwards on a revisit.
			if i != checkpoint_index+1 or not section_cleared(i): continue
			shelter.reached = true
			checkpoint_index = i
			storm_x = p.x-440
			rain_remaining = sections[mini(i+1,sections.size()-1)].budget
			save_checkpoint(shelter.pos)
			emit("checkpoint",shelter.pos)


func storm_speed() -> float:
	return float(chapter.encounters[encounter_index()].storm_speed) if storm_active else 0.0

func storm_gap() -> float:
	return p.x-(storm_x+45.0)

func advance_storm(dt: float) -> void:
	var under_shelter := shelter_index_at(p) >= 0
	if started and not under_shelter:
		storm_x += storm_speed() * dt
	else:
		storm_x = minf(storm_x,p.x-300)
	if p.x < storm_x + 45:
		hurt("storm")

func advance_rain(dt: float) -> void:
	for field in rain_fields:
		var area: Rect2 = field.rect
		if not started or p.x < area.position.x-900 or p.x > area.end.x+600: continue
		field.timer -= dt
		if field.timer <= 0:
			field.timer = 0.65
			for column in 4:
				var x := area.position.x+(column+0.3+rng.randf()*0.4)*area.size.x/4.0
				drops.append({"pos":Vector2(x,area.position.y+130.0),"vel":Vector2(-25,350)})
	if chapter.encounters[encounter_index()].ambient_rain: rain_timer -= dt
	else: rain_timer = 1.8
	if rain_timer <= 0:
		rain_timer = 1.25 if storm_active else 2.0
		drops.append({"pos":Vector2(p.x + rng.randf_range(80,400),70),"vel":Vector2(-45,320 if storm_active else 245)})
	for i in range(drops.size()-1,-1,-1):
		var drop := drops[i]
		drop.pos += drop.vel * dt
		var sheltered := false
		for shelter in shelters:
			if absf(drop.pos.x-shelter.pos.x) < float(shelter.get("half_width",118.0))+7 and drop.pos.y > shelter.pos.y-95:
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
	if shield_left > 0 and reason in ["rain","sneeze","storm"]:
		if shield_feedback_left <= 0:
			emit("shield_block",p)
			events.back()["reason"] = reason
			shield_feedback_left = 0.35
		return
	if invulnerable > 0:
		return
	spend_energy(cost)
	invulnerable = 1.8
	emit("hit",p)
	events.back()["reason"] = reason
	events.back()["cost"] = cost
	if stamina <= 0.0:
		restore_checkpoint("rain")

func save_checkpoint(safe_position: Vector2 = Vector2.INF) -> void:
	if safe_position == Vector2.INF: safe_position = p
	checkpoint = {"p":safe_position,"bees":bees,"pods":pods.duplicate(true),"walls":walls.duplicate(true),"rings":rings.duplicate(true),"shelters":shelters.duplicate(true),"dew":dew.duplicate(true),"sprayers":sprayers.duplicate(true),"shields":shields.duplicate(true),"storm_x":storm_x,"checkpoint_index":checkpoint_index,"rain_remaining":rain_remaining}

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
	shields.assign(checkpoint.shields.duplicate(true))
	shield_left = 0.0
	shield_feedback_left = 0.0
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
	if rings[index].has("direction"): return rings[index].direction
	var destination: Vector2 = rings[index+1].pos if index+1 < rings.size() else exit_pos
	return (destination-Vector2(rings[index].pos)).normalized()

func shelter_contains(point: Vector2, shelter: Dictionary) -> bool:
	var half := float(shelter.get("half_width",118.0))
	return Rect2(shelter.pos-Vector2(half,64),Vector2(half*2,140)).has_point(point)

func shelter_index_at(point: Vector2) -> int:
	for i in shelters.size():
		if shelter_contains(point,shelters[i]): return i
	return -1

func chapter_title() -> String:
	return chapter.title

func theme_index() -> int:
	return chapter.theme

func music_index() -> int:
	return chapter.music

func encounter_index() -> int:
	for i in chapter.encounters.size():
		if p.x < chapter.encounters[i].end_x: return i
	return chapter.encounters.size()-1

func encounter_name() -> String:
	return chapter.encounters[encounter_index()].name

func section_index() -> int:
	return clampi(checkpoint_index+1,0,sections.size()-1)

func section_count() -> int:
	return sections.size()

func section_name() -> String:
	return sections[section_index()].name

func completed_sections() -> int:
	return checkpoint_index+1

func section_cleared(index: int) -> bool:
	for trapped in pods:
		if trapped.get("section",0) <= index and not trapped.open: return false
	return true

func gate_ready(obstacle: Dictionary) -> bool:
	if not obstacle.has("needs_section"): return true
	var index: int = obstacle.needs_section
	return section_cleared(index) and checkpoint_index >= index-1

func section_rescued() -> int:
	var total := 0
	for trapped in pods:
		if trapped.section == section_index() and trapped.open: total += int(trapped.count)
	return total

func section_rescue_total() -> int:
	var total := 0
	for trapped in pods:
		if trapped.section == section_index(): total += int(trapped.count)
	return total

func rescued_count() -> int:
	return bees-int(chapter.base_bees)

func rescue_total() -> int:
	var total := 0
	for trapped in pods: total += int(trapped.count)
	return total

func stage_dew_total() -> int:
	return dew.size()

func journey_dew_total() -> int:
	var total := 0
	for index in STAGE_COUNT: total += Data.dew_count(index)
	return total

func journey_bees_total() -> int:
	return 9

func section_progress_text() -> String:
	return "%d / %d 处叶下已抵达" % [completed_sections(),section_count()]

func target_position() -> Vector2:
	for trapped in pods:
		if not trapped.open and trapped.section <= section_index(): return trapped.pos
	if checkpoint_index < shelters.size()-1: return shelters[checkpoint_index+1].pos
	return exit_pos

func objective() -> String:
	if exit_ready: return "本关已走完 · 飞向出口" if stage < STAGE_COUNT-1 else "伙伴在家等你 · 飞进树洞"
	if section_rescue_total() > section_rescued():
		return "%s · 冲开卷叶救伙伴" % encounter_name() if target_position().x < p.x-240 else str(chapter.encounters[encounter_index()].cue)
	return str(chapter.encounters[encounter_index()].cue)

func hint() -> String:
	if shield_left > 0:
		return "护雨 %.1f 秒 · 雨滴、喷嚏和雨幕暂时不伤体力；飞行仍耗体力" % shield_left
	if charging and not can_burst():
		return "冲刺需要 20 体力 · 按 R 返回恢复点补充；大叶下可以休息"
	if charging:
		return "准备好了 · 松开空格冲刺，方向键可以调整朝向" if charge >= CHARGE_READY else "继续按住空格 · 等光环亮起，再松开"
	if not started:
		return "方向键 / WASD 飞行   ·   按住空格蓄力，亮起后松开冲刺"
	if stage == 0 and bees == 1:
		return "飞向呼救的卷叶 · 面朝伙伴，按住空格，亮起后松开"
	if shelter_index_at(p) >= 0:
		return "叶下休息 · " + ("体力充足" if stamina >= MAX_STAMINA else "体力正在恢复") + ("，暴雨倒计时暂停" if storm_active else "")
	return "飞行缓慢耗体力 · 空格蓄力冲刺消耗 20 · 叶下恢复 · Esc 暂停"

func context_cue() -> Dictionary:
	# Local prompts appear only within an actionable distance, never over the whole map.
	if charging:
		var words := "体力不足 20 · R 返回恢复点" if not can_burst() else ("松开空格 · 冲刺消耗 20" if charge >= CHARGE_READY else "按住空格 · 蓄力中")
		return {"pos":p,"text":words,"kind":"charge"}
	for leaf in shields:
		if not leaf.collected and p.distance_to(leaf.pos) < 270:
			return {"pos":leaf.pos,"text":"护雨叶 · 轻触获得五秒防雨","kind":"shield"}
	var rest_index := shelter_index_at(p)
	if rest_index >= 0:
		return {"pos":shelters[rest_index].pos,"text":"叶下安全 · " + ("体力充足" if stamina >= MAX_STAMINA else "体力恢复中"),"kind":"shelter"}
	for trapped in pods:
		if not trapped.open and p.distance_to(trapped.pos) < 300:
			return {"pos":trapped.pos,"text":"冲开卷叶 · 救出伙伴","kind":"pod"}
	for obstacle in walls:
		if obstacle.kind == "curtain" and not obstacle.broken and absf(p.x-obstacle.rect.get_center().x) < 270 and p.y > obstacle.rect.position.y-40 and p.y < obstacle.rect.end.y+40:
			return {"pos":Vector2(obstacle.rect.get_center().x,p.y),"text":"干叶帘 · 蓄力冲开" if gate_ready(obstacle) else "先救出本段伙伴，并抵达前方叶下","kind":"curtain"}
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
			return {"pos":drop.pos,"text":"晨露 · 轻触收集" + ("，体力已满" if stamina >= MAX_STAMINA else "，最多恢复 12 体力"),"kind":"dew"}
	for flower in rings:
		if p.distance_to(flower.pos) < (115 if flower.active else 270):
			return {"pos":flower.pos,"text":"花瓣已收拢 · 继续向前" if flower.active else "冲进风花 · 沿箭头借力一次","kind":"spent" if flower.active else "ring"}
	for shelter in shelters:
		if p.distance_to(shelter.pos) < 230:
			return {"pos":shelter.pos,"text":"大叶下休息 · 恢复体力","kind":"shelter"}
	if exit_ready and p.distance_to(exit_pos) < 330:
		return {"pos":exit_pos,"text":"到家了 · 飞进树洞" if stage == STAGE_COUNT-1 else "一起向前 · 飞过叶拱","kind":"exit"}
	return {}

func _flags(items: Array, property: String) -> Array:
	var flags: Array = []
	for item in items: flags.append(bool(item[property]))
	return flags

func save_payload() -> Dictionary:
	# Persist the latest safe snapshot, not an airborne position or live hazards.
	var saved_awards: Array = garden_awards.duplicate()
	var saved_dew := _flags(checkpoint.dew,"collected")
	saved_awards[stage] = saved_dew.count(true)
	var saved_sprayers: Array = []
	for item in checkpoint.sprayers:
		saved_sprayers.append({"rewarded":item.rewarded,"stun_left":item.stun_left,"timer":item.timer})
	return {"version":4,"content_revision":6,"stage":stage,"checkpoint_index":checkpoint.checkpoint_index,"pods":_flags(checkpoint.pods,"open"),"walls":_flags(checkpoint.walls,"broken"),"rings":_flags(checkpoint.rings,"active"),"dew":saved_dew,"shields":_flags(checkpoint.shields,"collected"),"sprayers":saved_sprayers,"garden_awards":saved_awards,"bees":checkpoint.bees,"rain_remaining":checkpoint.rain_remaining,"bursts":bursts,"recoveries":recoveries,"rings_hit":rings_hit,"completed":completed}

func _valid_integer(value, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and value >= low and value <= high

func _valid_flags(value, count: int) -> bool:
	if not value is Array or value.size() != count: return false
	for flag in value:
		if not flag is bool: return false
	return true

func restore_payload(data: Dictionary) -> bool:
	# Validate every field before changing the current run. Extra UI metadata is
	# intentionally ignored; maps and positions always come from authored data.
	if data.get("version") != 4 or data.get("content_revision") != 6: return false
	if not _valid_integer(data.get("stage"),0,STAGE_COUNT-1): return false
	var saved_stage := int(data.stage)
	var layout := Data.build(saved_stage)
	if not _valid_integer(data.get("checkpoint_index"),-1,layout.sections.size()-1): return false
	var saved_checkpoint := int(data.checkpoint_index)
	for field in ["pods","walls","rings","dew","shields"]:
		if not _valid_flags(data.get(field),layout[field].size()): return false
	if not data.get("sprayers") is Array or data.sprayers.size() != layout.sprayers.size(): return false
	for item in data.sprayers:
		if not item is Dictionary or not item.get("rewarded") is bool: return false
		for field in ["stun_left","timer"]:
			var value = item.get(field)
			if not (value is int or value is float) or not is_finite(float(value)) or value < 0 or value > (6.0 if field == "stun_left" else 4.5): return false
	if not data.get("garden_awards") is Array or data.garden_awards.size() != STAGE_COUNT: return false
	for i in STAGE_COUNT:
		if not _valid_integer(data.garden_awards[i],0,Data.dew_count(i)): return false
		if i > saved_stage and data.garden_awards[i] != 0: return false
	if data.garden_awards[saved_stage] != data.dew.count(true): return false
	var expected_bees: int = layout.base_bees
	for i in layout.pods.size():
		if data.pods[i]: expected_bees += int(layout.pods[i].count)
		elif int(layout.pods[i].section) <= saved_checkpoint: return false
	if not _valid_integer(data.get("bees"),expected_bees,expected_bees): return false
	for i in layout.walls.size():
		if data.walls[i] and layout.walls[i].kind != "curtain": return false
	for field in ["bursts","recoveries","rings_hit"]:
		if not _valid_integer(data.get(field),0,10000000): return false
	var remaining = data.get("rain_remaining")
	if not (remaining is int or remaining is float) or not is_finite(float(remaining)) or remaining < 0 or remaining > STORM_SECONDS: return false
	if not data.get("completed") is bool: return false
	if data.completed and (saved_stage != STAGE_COUNT-1 or saved_checkpoint != layout.sections.size()-1): return false
	load_stage(saved_stage)
	checkpoint_index = saved_checkpoint
	for i in pods.size(): pods[i].open = data.pods[i]
	for i in walls.size(): walls[i].broken = data.walls[i]
	for i in rings.size(): rings[i].active = data.rings[i]
	for i in dew.size(): dew[i].collected = data.dew[i]
	for i in shields.size(): shields[i].collected = data.shields[i]
	for i in shelters.size(): shelters[i].reached = i <= checkpoint_index
	for i in sprayers.size():
		sprayers[i].rewarded = data.sprayers[i].rewarded
		sprayers[i].stun_left = float(data.sprayers[i].stun_left)
		sprayers[i].timer = float(data.sprayers[i].timer)
	for i in STAGE_COUNT: garden_awards[i] = int(data.garden_awards[i])
	bees = expected_bees
	bursts = int(data.bursts)
	recoveries = int(data.recoveries)
	rings_hit = int(data.rings_hit)
	p = shelters[checkpoint_index].pos if checkpoint_index >= 0 else Vector2(180,420)
	storm_x = p.x-440 if storm_active else -1000.0
	rain_remaining = maxf(20.0,float(remaining))
	invulnerable = 2.5
	exit_ready = completed_sections() == section_count() and rescued_count() == rescue_total()
	completed = data.completed
	save_checkpoint()
	if completed:
		p = exit_pos
		phase = "ending"
	camera_x = clampf(p.x-480,0,world_width-1280)
	return true
