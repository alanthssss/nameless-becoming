extends Node2D
const Winter = preload("res://winter_art.gd")
const SampleLandscape = preload("res://sample_landscape.gd")
const ArtSprites = preload("res://art_sprites.gd")
const ArtProps = preload("res://art_props.gd")
## A single painter for the authored landscape; never changes simulation state.
var model
var feedback_font: Font
var particles: Array[Dictionary] = []
var ripples: Array[Dictionary] = []
var trail: Array[Dictionary] = []
# Rescue departures are transient presentation actors, never model companions.
var departures: Array[Dictionary] = []
var presentation_active := true
var clock := 0.0
var trail_clock := 0.0
var trauma := 0.0
var _rng := RandomNumberGenerator.new()
var _last_stage := -1
var _ending_elapsed := 0.0
var _feedback: Array[Dictionary] = []
var _reactions: Array[Dictionary] = []
var _world_offset := Vector2.ZERO
var _last_speed := 0.0
var _was_burst := false
var _settle := 0.0
var _rest_blend := 0.0
var _greeting := 0.0
var _wind_kick := 0.0
var _shield_flash := 0.0
var _shield_birth := 0.0
var _arrival_elapsed := -1.0
var _arrival_from := Vector2.ZERO
var _arrival_dash := false

const INK := Color("58452c")
const GOLD := Color("ffc94f")
const CREAM := Color("fff8d8")
const WATER := Color("8cd6dc")
const WATER_INK := Color("436c70")
const LEAF_LIGHT := Color("cee58c")
const SKY := [Color("91dbe3"), Color("8bcbdc"), Color("657ea1"), Color("a78b99")]
const LOW_SKY := [Color("edf3ba"), Color("daeebc"), Color("9bb7b0"), Color("efd7aa")]

func _ready() -> void:
	_rng.seed = 14631
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

func reset_presentation() -> void:
	departures.clear()
	particles.clear()
	ripples.clear()
	trail.clear()
	_feedback.clear()
	_reactions.clear()
	_settle = 0.0
	_rest_blend = 0.0
	_last_speed = 0.0
	_was_burst = false
	_greeting = 0.0
	_wind_kick = 0.0
	_shield_flash = 0.0
	_shield_birth = 0.0
	_ending_elapsed = 0.0
	_arrival_elapsed = -1.0
	_arrival_dash = false
	trail_clock = 0.0
	trauma = 0.0
	_last_stage = model.stage if model != null else -1
	queue_redraw()

func _process(delta: float) -> void:
	if not presentation_active: return
	if model != null and model.stage != _last_stage:
		reset_presentation()
	clock += delta
	if _arrival_elapsed >= 0.0: _arrival_elapsed += delta
	_advance_departures(delta)
	_settle = maxf(0.0, _settle - delta)
	_greeting = maxf(0.0, _greeting - delta)
	_wind_kick = maxf(0.0, _wind_kick - delta * 3.0)
	_shield_flash = maxf(0.0, _shield_flash - delta)
	_shield_birth = maxf(0.0, _shield_birth - delta)
	for i in range(_reactions.size() - 1, -1, -1):
		_reactions[i].age += delta
		if _reactions[i].age > 1.25:
			_reactions.remove_at(i)
	for i in range(_feedback.size() - 1, -1, -1):
		_feedback[i].life -= delta
		if _feedback[i].life <= 0.0:
			_feedback.remove_at(i)
	trauma = maxf(0.0, trauma - delta * 2.0)
	for i in range(particles.size() - 1, -1, -1):
		var bit: Dictionary = particles[i]
		bit.life -= delta
		bit.pos += bit.vel * delta
		bit.vel *= exp(-delta * 1.4)
		bit.vel.y += delta * 45.0
		if bit.life <= 0.0:
			particles.remove_at(i)
	for i in range(ripples.size() - 1, -1, -1):
		ripples[i].life -= delta
		if ripples[i].life <= 0.0:
			ripples.remove_at(i)
	for i in range(trail.size() - 1, -1, -1):
		trail[i].life -= delta
		if trail[i].life <= 0.0:
			trail.remove_at(i)
	if model != null:
		var speed: float = model.velocity.length()
		var bursting: bool = model.burst_left > 0.0
		if (_was_burst and not bursting) or (_last_speed > 100.0 and speed < 35.0):
			_settle = 0.36
		_last_speed = speed
		_was_burst = bursting
		var resting: bool = model.shelter_index_at(model.p) >= 0 and speed < 12.0 and not model.charging and not bursting
		_rest_blend = move_toward(_rest_blend, 1.0 if resting else 0.0, delta * (2.4 if resting else 9.0))
		_ending_elapsed = _ending_elapsed + delta if model.phase == "ending" else 0.0
		trail_clock += delta
		if model.burst_left > 0.0 and trail_clock > 0.022:
			trail_clock = 0.0
			trail.append({"pos": model.p, "life": 0.28, "face": model.face, "relay":model.wind_chain > 1})
	queue_redraw()

func emit_event(kind: String, pos: Vector2, details: Dictionary = {}) -> void:
	if model != null and model.stage != _last_stage:
		reset_presentation()
	if kind.begins_with("recover"):
		reset_presentation()
	if kind in ["rescue", "ring", "flower_calm", "checkpoint", "gate"]:
		_reactions.append({"kind":kind, "pos":pos, "age":0.0})
	if kind == "rescue":
		_greeting = 0.85
		_spawn_departures(pos,clampi(int(details.get("count",1)),0,15))
	elif kind == "ring":
		_wind_kick = 1.0
	elif kind == "shield":
		_shield_birth = 0.4
	elif kind == "shield_block":
		_shield_flash = 0.24
	elif kind == "finish":
		_arrival_elapsed = 0.0
		_arrival_from = pos
		_arrival_dash = bool(details.get("dashing",false))
	var caption := ""
	match kind:
		"burst": caption = "−20"
		"rescue": caption = "+%d 伙伴" % int(details.get("count",1))
		"ring": caption = "借风 ×%d" % int(details.get("chain",1)) if int(details.get("chain",1)) > 1 else "借到风！"
		"gate": caption = "冲开了！"
		"dew":
			var reward := int(round(details.get("reward",0)))
			caption = "+%d 体力" % reward if reward > 0 else "晨露 +1"
		"hit": caption = "−%d 体力" % int(details.get("cost",30))
		"shield": caption = "护雨 · 5 秒"
	if not caption.is_empty():
		_feedback.append({"kind":"caption","pos":pos,"life":0.9,"text":caption,"bad":kind=="hit"})
	var tint := GOLD
	var count := 12
	var force := 150.0
	match kind:
		"rescue":
			tint = Color("fff3a4")
			count = 30
			force = 180.0
		"dew":
			tint = Color("c7f3db")
			count = 9
			force = 105.0
		"shield":
			tint = Winter.FROST if Winter.active(self) else LEAF_LIGHT
			count = 14
			force = 90.0
		"shield_block":
			# Protection has its own soft, local response. Never reuse hit shake,
			# damage captions or the red hit particles for an absorbed raindrop.
			for i in 6:
				var angle := -PI+float(i)*PI/5.0
				var direction := Vector2.from_angle(angle)
				particles.append({"pos":pos+direction*43.0,"vel":direction*70.0,"life":0.28,"max_life":0.28,"size":2.3,"color":WATER.lightened(0.3),"angle":angle})
			return
		"shield_end":
			_feedback.append({"kind":"shield_end", "pos":pos, "life":0.4})
			return
		"flower_calm":
			tint = Color("ffc9f0")
			count = 25
			force = 150.0
		"spray":
			tint = Color("d3f8ff")
			count = 8
			force = 100.0
		"ring":
			tint = Color("bcf4dc")
			count = 22
			force = 240.0
		"gate":
			tint = Color("e0b575")
			count = 25
			force = 230.0
			trauma = 0.18
		"hit":
			tint = Color("edb2a3")
			count = 15
			trauma = 0.28
		"recover", "recover_manual", "recover_rain", "recover_exhaustion", "recover_timeout":
			tint = Color("c4dec0")
			count = 20
			force = 100.0
		"checkpoint", "restored_energy":
			tint = Color("f5dea2")
			count = 16
			force = 100.0
		"finish":
			_feedback.clear()
			count = 42
			force = 250.0
		"burst", "rain_break":
			count = 13
			force = 160.0
		"charge_cancel", "tired":
			_feedback.append({"kind":kind, "pos":pos, "life":0.55})
			return
		"breath":
			tint = Color("bcd6a9")
			count = 7
			force = 55.0
		"blocked":
			_feedback.append({"kind":kind, "pos":pos, "life":0.42})
			trauma = 0.1
			return
		_:
			return
	for i in count:
		var angle := _rng.randf_range(0.0, TAU)
		var life := _rng.randf_range(0.35, 0.85)
		particles.append({"pos": pos, "vel": Vector2.from_angle(angle) * _rng.randf_range(force * 0.2, force), "life": life, "max_life": life, "size": _rng.randf_range(1.4, 4.5), "color": tint, "angle": angle})
	ripples.append({"pos": pos, "life": 0.5, "color": tint})

func _draw() -> void:
	if model == null:
		draw_rect(Rect2(0, 0, 1280, 800), SKY[0])
		return
	var act: int = clampi(model.theme_index(), 0, 3)
	var cam: float = model.camera_x
	_background(act, cam)
	var shake := Vector2(sin(clock * 53.0), sin(clock * 39.0)) * trauma * trauma * 9.0
	_world_offset = Vector2(-cam, 0) + shake
	draw_set_transform(_world_offset)
	_region_landmarks(cam)
	_landmarks(act)
	for field in model.rain_fields:
		_rain_field(field)
	for wall in model.walls:
		_wall(wall)
	for field in model.airflows: _airflow(field)
	for i in model.jets.size(): _jet(i)
	for shelter in model.shelters:
		_shelter(shelter)
	_wind_paths()
	for i in range(model.rings.size()):
		_ring(model.rings[i], i)
	for pod in model.pods:
		_pod(pod)
	for item in model.dew:
		_dew(item)
	for item in model.shields:
		_shield_pickup(item)
	for i in model.sprayers.size():
		_sprayer(model.sprayers[i], i)
	for puff in model.puffs:
		_puff(puff.pos)
	_exit(act)
	_neighbors()
	_storm(cam)
	if model.phase == "ending" and model.chapter.exit_kind == "home":
		_ending_weather(cam)
	for drop in model.drops:
		_drop(drop.pos, drop.vel)
	for ghost in trail:
		var alpha: float = ghost.life / 0.28 * 0.18
		_ellipse(ghost.pos, Vector2(22, 10), Color(1.0, 0.91, 0.56, alpha), ghost.face.angle())
		if ghost.relay:
			draw_line(ghost.pos-ghost.face*24,ghost.pos+ghost.face*8,Color(0.61,1.0,0.88,alpha*2.0),4,true)
	_leader()
	_airflow_contact()
	_draw_departures()
	_effects()
	draw_set_transform(Vector2.ZERO)
	_foreground(act, cam)

func _background(act: int, cam: float) -> void:
	SampleLandscape.background(self,model.chapter.region,cam,clock,act,model.stage)
	if model.stage == 3:
		_distant_home(cam)

func _region_landmarks(cam: float) -> void:
	for item in model.chapter.decor:
		var p: Vector2 = item.pos
		if p.x < cam-120 or p.x > cam+1400: continue
		ArtProps.decor(self,p,item.style)

func _bird(p: Vector2) -> void:
	ArtProps.bird(self,p,clock)

func _neighbors() -> void:
	if model.chapter.npc.is_empty() or model.shelters.is_empty(): return
	var indices := [0]
	if model.shelters.size() > 1 and model.stage != model.STAGE_COUNT-1: indices.append(model.shelters.size()-1)
	if model.chapter.has("neighbor_stops"):
		indices.clear()
		for stop in model.chapter.neighbor_stops: indices.append(int(stop.index))
	for index in indices:
		var p: Vector2 = model.shelters[index].pos+Vector2(94,22)
		if p.x < model.camera_x-140 or p.x > model.camera_x+1380: continue
		if model.chapter.npc == "bird": _bird(p)
		else:
			var greeting: bool = model.stage == 4 and model.shelter_index_at(model.p) == index and fposmod(clock,4.2) < 0.7
			_bee(p,0.85,Vector2.LEFT,1.0,false,0.0,"greet" if greeting else "waiting")
			_flower(p+Vector2(6,-19),7,Color("e6a6b7"),0.0)

func neighbor_words() -> String:
	# Share the existing shelter cue so dialogue cannot obscure a second cue.
	if model.chapter.npc.is_empty(): return ""
	var index: int = model.shelter_index_at(model.p)
	if model.chapter.has("neighbor_stops"):
		for stop in model.chapter.neighbor_stops:
			if index != int(stop.index): continue
			if model.stage == 0 and index == 0:
				if model.sample_approach == "top": return "小满：你从花篱上面飞来的呀！"
				if model.sample_approach == "bottom": return "小满：你走了下面那条路呀！"
			if model.stage == 1 and index == 0:
				for flower in model.sprayers:
					if flower.rewarded: return "画眉：花朵安静下来，我也能歇一会儿了。"
			return stop.line
		return ""
	if index < 0 or (index != 0 and index != model.shelters.size()-1): return ""
	if index == model.shelters.size()-1 and model.stage == model.STAGE_COUNT-1: return ""
	if model.stage == 4:
		if model.sample_approach == "top": return "小满：你从花篱上面飞来的呀！"
		if model.sample_approach == "bottom": return "小满：你走了下面那条路呀！"
		return "小满：到了呀，一起歇歇脚。"
	if index != model.shelters.size()-1: return model.chapter.npc_line
	if model.chapter.npc == "bird": return "画眉：这条新路，我也记住了。"
	return "小满：你也到了，歇一会儿吧。"

func _distant_home(cam: float) -> void:
	# Reuse the real home in the background plane, retaining the authored reveal.
	if model.chapter.encounters.size() < 3: return
	var reveal_x: float = model.chapter.encounters[2].start_x
	var reveal: float = clampf((model.p.x-reveal_x+180.0)/240.0,0.0,1.0)
	var approach: float = clampf((model.exit_pos.x-model.p.x-1100.0)/1200.0,0.0,1.0)
	var opacity := reveal*approach
	if opacity <= 0.001: return
	var p := Vector2(1090.0-(cam-reveal_x+480.0)*0.055,600)
	ArtProps.home(self,p,-1.0,opacity*0.78,0.5)
	draw_set_transform(Vector2.ZERO)

func _terrain(item: Dictionary) -> void:
	var r: Rect2 = item.rect
	var material: String = item.get("material","hedge")
	if material == "hedge":
		ArtSprites.hedge(self,r)
	else:
		ArtProps.terrain(self,r,"crate" if material == "crate" else "platform")

func _jet(index: int) -> void:
	var item: Dictionary = model.jets[index]
	var r: Rect2 = item.rect
	if r.end.x < model.camera_x-120 or r.position.x > model.camera_x+1400: return
	var state: String = model.jet_phase(index)
	var active := state == "spray"
	var tint := Color("80d8e2") if active else Color("f1bf69") if state == "warning" else Color("679d9f")
	draw_rect(r,Color(tint,0.24 if active else 0.07))
	for x in [r.position.x,r.end.x]:
		for y in range(int(r.position.y),int(r.end.y),30): draw_line(Vector2(x,y),Vector2(x,minf(y+12,r.end.y)),Color(tint,0.7),2,true)
	if active:
		for j in 5:
			var x: float = r.position.x+8+(r.size.x-16)*j/4.0
			for k in 5:
				var y: float = r.end.y-fposmod(model.hazard_clock*360+k*r.size.y/5.0+j*13,r.size.y)
				draw_line(Vector2(x,y),Vector2(x,clampf(y+35,r.position.y,r.end.y)),CREAM,3,true)
	else:
		var head := Vector2(r.get_center().x,r.end.y-15)
		for j in 3: draw_circle(head+Vector2((j-1)*19,-absf(sin(clock*4+j))*12),3.5,tint)
	var base := Rect2(r.position.x-10,r.end.y-4,r.size.x+20,18)
	ArtProps.fountain(self,base,state)
	# The nearby model-driven cue carries the phase; keep the painted nozzle clear.

func _airflow_contact() -> void:
	# This contact feedback uses the same effective force as movement, not proximity.
	var flow: Vector2 = model.effective_airflow()
	if flow.is_zero_approx(): return
	var dir := flow.normalized()
	var side := dir.orthogonal()
	for i in 3:
		var along := fposmod(clock*140+i*29,84.0)-42.0
		var tip: Vector2 = model.p+dir*along+side*(30 if i%2 == 0 else -30)
		var arrow := PackedVector2Array([tip-dir*6-side*4,tip,tip-dir*6+side*4])
		var contained := false
		for field in model.airflows:
			var inside: Rect2 = field.rect.grow(-2)
			if inside.has_point(tip-dir*17) and inside.has_point(arrow[0]) and inside.has_point(arrow[1]) and inside.has_point(arrow[2]):
				contained = true
				break
		if not contained: continue
		draw_line(tip-dir*17,tip,Color("edf5d7"),3,true)
		draw_polyline(arrow,Color("edf5d7"),2,true)

func _airflow(item: Dictionary) -> void:
	var r: Rect2 = item.rect
	if r.end.x < model.camera_x-100 or r.position.x > model.camera_x+1400: return
	draw_rect(r,Color(0.50,0.85,0.91,0.18))
	draw_rect(r,Color(0.35,0.65,0.70,0.65),false,2)
	var dir: Vector2 = item.direction
	var side := dir.orthogonal()
	for i in 15:
		var p := r.position+Vector2(fposmod(i*73.0+clock*dir.x*75,r.size.x),fposmod(i*97.0+clock*dir.y*75,r.size.y))
		p.x = clampf(p.x,r.position.x+12,r.end.x-12)
		p.y = clampf(p.y,r.position.y+12,r.end.y-12)
		draw_polyline(PackedVector2Array([p-dir*9-side*5,p,p-dir*9+side*5]),Color("edf5d7"),2.5,true)
	var source := Vector2(r.get_center().x,r.end.y+9) if dir.y < -0.5 else Vector2(r.get_center().x,r.position.y-9) if dir.y > 0.5 else Vector2(r.end.x+10,r.get_center().y) if dir.x < 0 else Vector2(r.position.x-10,r.get_center().y)
	ArtProps.air_source(self,source,dir)

func _wall(wall: Dictionary) -> void:
	var r: Rect2 = wall.rect
	if r.end.x < model.camera_x-80 or r.position.x > model.camera_x+1360: return
	if wall.kind == "terrain":
		_terrain(wall)
		return
	if wall.kind == "curtain":
		var age := _reaction_age("gate",r.get_center())
		var flex := 0.0 if age < 0.0 else sin(age*12.0)*exp(-age*4.0)
		ArtProps.curtain(self,r,wall.broken,flex)
		if not wall.broken and wall.has("needs_section"):
			var waiting := false
			for pod in model.pods:
				if int(pod.get("section",-1)) == int(wall.needs_section) and not pod.open: waiting = true
			var badge := r.get_center()
			draw_circle(badge,23,INK)
			if waiting:
				_bee(badge,0.65,Vector2.RIGHT,1.0,true,0)
			else:
				draw_polyline(PackedVector2Array([badge+Vector2(-9,-9),badge+Vector2(5,0),badge+Vector2(-9,9)]),CREAM,4,true)
		return
	# The helper receives the unchanged solid rectangle; any roots extend away
	# from the opening, never into the route between the two collision edges.
	ArtProps.stem(self,r,r.position.y < 100)

func _pod(pod: Dictionary) -> void:
	var p: Vector2 = pod.pos
	if p.x < model.camera_x-100 or p.x > model.camera_x+1380: return
	var age := _reaction_age("rescue",p)
	var opened := 0.0
	if pod.open:
		opened = 1.0 if age < 0.0 else 1.0-pow(1.0-clampf(age/0.65,0.0,1.0),3.0)
	var sway := sin(clock*1.4+p.x*0.01)*2.0
	ArtProps.stalk(self,p+Vector2(2,38),p+Vector2(18+sway,92),p+Vector2(-11,118),Vector2(p.x-8,831),6.0)
	ArtSprites.small_leaf(self,p+Vector2(1,90),p+Vector2(-52+sway*2,65),22)
	ArtProps.pod(self,p,opened,false)
	if not pod.open:
		_bee(p+Vector2(0,7),0.76,Vector2.RIGHT,1.0,true,0.0)
	ArtProps.pod(self,p,opened,true)

func _wind_paths() -> void:
	# A light breeze links authored relays; it is a route hint, not a new collider.
	for i in range(model.rings.size()-1):
		var ring: Dictionary = model.rings[i]
		var next: Dictionary = model.rings[i+1]
		if ring.active or not ring.get("chain",false) or not next.get("chain",false) or ring.section != next.section or ring.get("encounter",-1) != next.get("encounter",-1) or ring.get("branch","") != next.get("branch",""):
			continue
		var p: Vector2 = ring.pos
		var end: Vector2 = next.pos
		if end.x < model.camera_x-80 or p.x > model.camera_x+1360: continue
		var direction := p.direction_to(end)
		var side := direction.orthogonal()
		var distance := p.distance_to(end)
		for j in range(5):
			var along := 76.0+fposmod(clock*42+j*66,distance-150)
			var center := p+direction*along
			draw_polyline(PackedVector2Array([center-direction*6-side*5,center,center-direction*6+side*5]),Color(0.80,0.96,0.76,0.56),2,true)

func _ring(ring: Dictionary, index: int) -> void:
	var p: Vector2 = ring.pos
	if p.x < model.camera_x-200 or p.x > model.camera_x+1400: return
	var used: bool = ring.active
	var direction: Vector2 = model.ring_direction(index)
	var age := _reaction_age("ring",p)
	var close := 1.0 if used else 0.0
	if used and age >= 0.0: close = 1.0-pow(1.0-clampf(age/0.55,0.0,1.0),3.0)
	var recoil := 0.0 if age < 0.0 else sin(age*13.0)*exp(-age*3.8)*12.0
	var sway := sin(clock*1.1+index*1.7)*3.0
	var stem := PackedVector2Array([p+direction*recoil+Vector2(0,42+close*10),p+Vector2(-28+sway+recoil,165),p+Vector2(38,228),Vector2(p.x-26,831)])
	ArtProps.stalk(self,stem[0],stem[1],stem[2],stem[3],10.0)
	var leaf_root := stem[0].bezier_interpolate(stem[1],stem[2],stem[3],0.18)
	ArtSprites.small_leaf(self,leaf_root,leaf_root+Vector2(-72+sway*1.5, -44),30)
	ArtSprites.flower(self,p,direction,close,recoil,used)

func _shelter(shelter: Dictionary) -> void:
	var p: Vector2 = shelter.pos
	var half := float(shelter.get("half_width",118.0))
	if p.x+half < model.camera_x-80 or p.x-half > model.camera_x+1360: return
	var reached: bool = shelter.reached
	ArtProps.shelter_plant(self,p,half)
	draw_line(p+Vector2(-7,-91),p+Vector2(-7,-55),INK,2,true)
	ArtProps.decor(self,p+Vector2(-7,-40),"shelter_lamp_lit" if reached else "shelter_lamp")
	if reached:
		draw_polyline(PackedVector2Array([p+Vector2(-7,44),p+Vector2(-1,50),p+Vector2(10,37)]),CREAM,3,true)

func _exit(_act: int) -> void:
	var p: Vector2 = model.exit_pos
	if model.chapter.exit_kind != "home":
		var ready: bool = model.exit_ready
		if ready:
			_ellipse(p+Vector2(22,0),Vector2(66,model.EXIT_HALF_HEIGHT),Color(1.0,0.91,0.55,0.10))
		ArtProps.goal_arch(self,p,ready,_arrival_elapsed)
		_goal_bell(p+Vector2(0,-143))
		if ready and _arrival_elapsed < 0.0:
			for i in 2:
				var x := p.x-46+i*25+sin(clock*2.3)*3
				draw_polyline(PackedVector2Array([Vector2(x,p.y-10),Vector2(x+11,p.y),Vector2(x,p.y+10)]),CREAM,3,true)
		elif _arrival_elapsed >= 0.0:
			draw_polyline(PackedVector2Array([p+Vector2(-21,-41),p+Vector2(-9,-29),p+Vector2(15,-54)]),GOLD,4,true)
		return
	ArtProps.home(self,p,_arrival_elapsed)
	_goal_bell(p+Vector2(0,-163))
	_waiting_friends()
	if model.phase == "ending":
		var bloom_count: int = mini(model.garden_total(),16)
		for i in bloom_count:
			var flower_pos := p+Vector2(-158+(i%8)*38,246+(i/8)*35-sin(i*1.9)*24)
			ArtProps.stalk(self,flower_pos+Vector2(0,60),flower_pos+Vector2(8,36),flower_pos+Vector2(-4,20),flower_pos,5.0)
			_flower(flower_pos,21,[Color("e9a5c9"),Color("f4cb62"),Color("bca0df")][i%3],float(i))

func _goal_bell(anchor: Vector2) -> void:
	var swing := sin(clock*1.8)*0.035
	if _arrival_elapsed >= 0.0:
		swing = sin(_arrival_elapsed*15.0)*exp(-_arrival_elapsed*2.4)*(0.55 if _arrival_dash else 0.4)
	ArtProps.bell(self,anchor,swing,model.exit_ready)
	if _arrival_elapsed >= 0.0 and _arrival_elapsed < 0.8:
		var bell := anchor+Vector2(1,10).rotated(swing)
		var radius := 28+_arrival_elapsed*34
		var tint_wave := Color(1.0,0.93,0.64,(1.0-_arrival_elapsed/0.8)*0.7)
		draw_arc(bell,radius,-0.7,0.7,16,tint_wave,2,true)
		draw_arc(bell,radius,PI-0.7,PI+0.7,16,tint_wave,2,true)

func _storm(cam: float) -> void:
	if not model.storm_active:
		return
	# The visible leading edge agrees with the model's contact threshold.
	# Once home, the rain leaves the frame instead of lingering over the ending.
	var front: float = model.storm_x + 45 - maxf(_ending_elapsed,_arrival_elapsed)*190
	if front < cam - 100:
		return
	var start := maxf(cam - 10.0, front - 1500.0)
	var edge := PackedVector2Array()
	for i in 41:
		var y := i*20.0
		var x := front-4-absf(sin(y*0.019+clock*2))*14
		edge.append(Vector2(x,y))
	var body := PackedVector2Array([Vector2(start,0)])
	body.append_array(edge)
	body.append(Vector2(start,800))
	if front > start+18: draw_colored_polygon(body,Color(0.13,0.26,0.36,0.44))
	draw_polyline(edge,Color(0.70,0.90,0.99,0.42),3,true)
	# Rounded storm-cloud masses and rightward gusts make this read as weather.
	for i in 4:
		var c := Vector2(front-62-i*91,195+sin(clock*0.8+i)*9)
		ArtProps.cloud(self,Rect2(c-Vector2(78,56),Vector2(156,88)),Color(0.48,0.60,0.66,0.74))
	for i in 70:
		var x := front - fposmod(i * 37.7 + clock * 140.0, 1400.0)
		var y := fposmod(i * 63.0 + clock * 530.0, 900.0) - 50.0
		draw_line(Vector2(x, y), Vector2(x - 9, y + 29), Color(0.65, 0.86, 0.94, 0.34), 1.3, true)
	for i in 5:
		var y := 270+i*87.0+sin(clock*1.8+i)*12
		var x := front-65+sin(clock*2+i)*12
		draw_line(Vector2(x-50,y),Vector2(x,y),Color(0.70,0.90,0.99,0.38),2,true)
		draw_polyline(PackedVector2Array([Vector2(x-9,y-6),Vector2(x,y),Vector2(x-9,y+6)]),Color(0.70,0.90,0.99,0.38),2,true)

func _drop(p: Vector2, velocity: Vector2) -> void:
	var direction := velocity.normalized()
	if direction.is_zero_approx():
		direction = Vector2.DOWN
	var side := direction.orthogonal()
	draw_line(p-direction*31.0,p-direction*9.0,Color(0.72,0.89,0.96,0.48),3.0,true)
	# A moving, round-bottomed tear differs in shape and motion from faceted dew.
	_silhouette([p-direction*17,p-direction*3-side*12,p+direction*11-side*10,p+direction*10,p+direction*11+side*10,p-direction*3+side*12,p-direction*17],Color("bde5ed"),WATER_INK,2.4)
	draw_line(p-side*3-direction*3,p-side*4+direction*3,Color("f1ffff"),2.2,true)

func _rain_field(field: Dictionary) -> void:
	var area: Rect2 = field.rect
	if area.end.x < model.camera_x-80 or area.position.x > model.camera_x+1360: return
	var imminent := float(field.timer) < 0.18
	var cloud_y := area.position.y+114.0
	var clusters := maxi(1,ceili(area.size.x/150.0))
	var spacing := area.size.x/float(clusters)
	# A fixed overhead cloud marks the authored rain lane before moving drops arrive.
	for i in clusters:
		var c := Vector2(area.position.x+(float(i)+0.5)*spacing,cloud_y)
		var cloud := Color("526f82") if imminent else Color("617e8a")
		ArtProps.cloud(self,Rect2(c-Vector2(spacing*0.54,39),Vector2(spacing*1.08,55)),cloud)
	# Fine streaks are a spatial forecast, never substitute for the outlined hazards.
	var columns := maxi(4,ceili(area.size.x/43.0))
	var rain_height := maxf(1.0,area.end.y-cloud_y-32.0)
	for i in columns:
		var x := area.position.x+(float(i)+0.5)*area.size.x/float(columns)
		for j in 3:
			var y := cloud_y+28.0+fposmod(float(i)*73.0+float(j)*rain_height/3.0+clock*155.0,rain_height)
			var drift := (y-cloud_y)/350.0*25.0
			draw_line(Vector2(x-drift,y),Vector2(x-drift-1.3,minf(y+18.0,area.end.y)),Color(0.75,0.90,0.94,0.20),1.0,true)

func _leader() -> void:
	var p: Vector2 = model.p
	var face: Vector2 = model.face
	if face.length_squared() < 0.01:
		face = Vector2.RIGHT
	var compact: bool = model.charging
	var burst: bool = model.burst_left > 0.0
	if _arrival_elapsed >= 0.0 and model.phase in ["transition","ending"]:
		var t := clampf(_arrival_elapsed/1.2,0.0,1.0)
		var eased := 1.0-pow(1.0-t,3.0)
		var landing: Vector2 = model.exit_pos+Vector2(-5,22) if model.chapter.exit_kind == "home" else model.exit_pos+Vector2(35,82)
		var lead := _arrival_from.bezier_interpolate(_arrival_from+Vector2(45,-12),landing-Vector2(0,38),landing,eased)
		_bee(lead,1.0,Vector2.RIGHT,1.0,false,0.0)
		return
	if model.phase == "ending":
		_ending_arrival()
		return
	if model.shield_left > 0.0:
		_shield_shell(p,false)
	if model.invulnerable <= 0.0 or sin(clock * 28.0) > -0.35:
		if burst:
			_ellipse(p - face * 16.0, Vector2(38, 17), Color(1.0, 0.89, 0.48, 0.18), face.angle())
		_bee(p, 1.0, face, 1.0, false, 0.0)
	if model.shield_left > 0.0:
		_shield_shell(p,true)
	if compact:
		var fill: float = clampf(model.charge / model.CHARGE_READY, 0.0, 1.0)
		var ready: bool = model.charge >= model.CHARGE_READY and model.can_burst()
		var col := Color("fff4b3") if ready else Color("c5a96c")
		draw_arc(p, 27, -PI / 2, -PI / 2 + TAU * maxf(0.005, fill), 48, col, 4.0, true)
		var begin := p + face * 37
		var end := p + face * (67.0 + fill * 58.0)
		draw_line(begin, end, Color(INK,0.6), 8.0, true)
		draw_line(begin, end, col, 4.0, true)
		draw_polyline(PackedVector2Array([end - face * 14 + face.orthogonal() * 10, end, end - face * 14 - face.orthogonal() * 10]), col, 4.0, true)
		if ready:
			draw_arc(p, 33 + sin(clock * 8.0) * 2.0, 0, TAU, 48, Color(1.0, 0.95, 0.65, 0.3), 1.5, true)

func _spawn_departures(pos: Vector2, count: int) -> void:
	if model == null: return
	for i in count:
		var offset := Vector2((float(i)-float(count-1)*0.5)*22.0,-8.0-float(i%2)*10.0)
		var start: Vector2 = pos+offset-Vector2(model.camera_x,0)
		start.y = clampf(start.y,196.0,690.0)
		departures.append({"origin":pos+offset,"screen_pos":start,"age":0.0,"delay":0.22+minf(i,2)*0.04,"duration":1.72+minf(i,2)*0.06,"launched":false,"at_edge":false,"start":start,"control_a":start,"control_b":start,"end":start,"face":Vector2.RIGHT,"size":0.68,"seed":float(i)})

func _advance_departures(delta: float) -> void:
	if model == null: return
	for i in range(departures.size()-1,-1,-1):
		var bee: Dictionary = departures[i]
		bee.age += delta
		if not bee.launched:
			var pop: float = clampf(bee.age/bee.delay,0.0,1.0)
			var screen: Vector2 = bee.origin-Vector2(model.camera_x,0)+Vector2(0,-18.0*sin(pop*PI*0.5))
			screen.y = clampf(screen.y,196.0,690.0)
			bee.screen_pos = screen
			if bee.age >= bee.delay:
				# From takeoff onward this arc belongs to the screen plane: turning,
				# dashing or moving the camera cannot make a rescued bee follow.
				bee.launched = true
				bee.start = screen
				bee.end = Vector2(1335.0+bee.seed*3.0,clampf(screen.y-190.0-bee.seed*12.0,188.0,500.0))
				bee.control_a = screen+Vector2(85.0,maxf(-130.0,188.0-screen.y))
				bee.control_b = bee.end+Vector2(-230.0,50.0)
		if bee.launched:
			var progress: float = clampf((bee.age-bee.delay)/(bee.duration-bee.delay),0.0,1.0)
			var t := pow(progress,1.15)
			var start: Vector2 = bee.start
			var point := start.bezier_interpolate(bee.control_a,bee.control_b,bee.end,t)
			var next := start.bezier_interpolate(bee.control_a,bee.control_b,bee.end,minf(t+0.01,1.0))
			if point.distance_squared_to(next)>0.001: bee.face = point.direction_to(next)
			bee.screen_pos = point
			bee.size = lerpf(0.68,0.22,pow(progress,0.65))
			bee.at_edge = point.x >= 1310.0
		# Leave the complete arc at the edge for a few frames before disposal.
		if bee.at_edge and bee.age >= bee.duration+0.06:
			departures.remove_at(i)

func _draw_departures() -> void:
	for bee in departures:
		var point: Vector2 = bee.screen_pos+Vector2(model.camera_x,0)
		_bee(point,bee.size,bee.face,1.0,false,bee.seed,"depart" if bee.launched else "greet")

func _waiting_friends() -> void:
	var p: Vector2 = model.exit_pos
	if p.x < model.camera_x-200 or p.x > model.camera_x+1480: return
	for i in maxi(0,mini(model.bees,16)-1):
		var home := p+Vector2(-55.0+float(i%4)*37.0,63.0+float(i/4)*25.0)
		_bee(home,0.57,Vector2.RIGHT,1.0,false,float(i),"waiting")
		if model.stage == model.STAGE_COUNT-1 and i == 0: _flower(home+Vector2(4,-13),5,Color("e6a6b7"),0.0)
	if model.stage == model.STAGE_COUNT-1: _bird(p+Vector2(110,66))

func _ending_arrival() -> void:
	var progress := clampf(_ending_elapsed/1.8,0.0,1.0)
	var eased := 1.0-pow(1.0-progress,3.0)
	var lead: Vector2 = model.p.lerp(model.exit_pos+Vector2(-5,22),eased)
	_bee(lead,1.0,Vector2.RIGHT,1.0,false,0.0)

func _ending_weather(cam: float) -> void:
	var edge: float = model.exit_pos.x - 106.0
	var width := maxf(1.0, edge - cam)
	for i in 60:
		var x := cam + fposmod(float(i) * 63.3 - clock * 42.0, width)
		var y := fposmod(float(i) * 67.3 + clock * 390.0, 880.0) - 40.0
		draw_line(Vector2(x, y), Vector2(x - 8, y + 25), Color(0.77, 0.91, 0.98, 0.29), 1.0, true)

func _bee(p: Vector2, size: float, face: Vector2, alpha: float, trapped: bool, seed_value: float, pose := "leader") -> void:
	var axis := face.normalized() if not face.is_zero_approx() else Vector2.RIGHT
	var charge := 0.0
	var dash := 0.0
	var rest := 0.0
	var settle := 0.0
	if not trapped and model != null and pose == "leader":
		charge = clampf(model.charge/model.CHARGE_READY,0.0,1.0) if model.charging else 0.0
		dash = 1.0 if model.burst_left > 0.0 else 0.0
		rest = _rest_blend
		if model.phase == "ending": rest = clampf(_ending_elapsed/1.8,0.0,1.0)
		if _arrival_elapsed >= 0.0: rest = clampf((_arrival_elapsed-0.35)/0.85,0.0,1.0)
		if _settle > 0.0: settle = sin((0.36-_settle)/0.36*PI)*_settle/0.36
	elif pose == "depart":
		dash = 0.35
	elif pose == "waiting":
		rest = 1.0
	var wind_kick := _wind_kick if pose == "leader" and not trapped else 0.0
	var stretch := Vector2(1.0-charge*0.17+dash*(0.25+wind_kick*0.07)-settle*0.12,1.0+charge*0.15-dash*0.19+settle*0.13)
	# Turn the side-view bee by mirroring, never by rolling its back underneath.
	# Pitch still follows flight direction; folded resting poses settle level.
	var mirror := -1.0 if axis.x < 0.0 else 1.0
	var pitch := atan2(axis.y,absf(axis.x))*mirror
	pitch = lerpf(pitch,0.0,rest)
	draw_set_transform(_world_offset+p,pitch,stretch*Vector2(mirror,1.0)*size)
	var ink := Color(INK,alpha)
	var wing_color := Color(0.9,0.99,0.91,alpha*0.94)
	var flutter := 0.5+0.5*sin(clock*(39.0 if charge>0.0 else 31.0)+seed_value*1.7)
	var wing_height := lerpf(17.0+flutter*11.0,3.0,rest)
	wing_height = lerpf(wing_height,8.0,dash)
	# Unequal, rooted wings fold along the back at rest and sweep aft on a launch.
	_silhouette([Vector2(0,-6),Vector2(-1,-wing_height-11),Vector2(-15,-wing_height-17),Vector2(-18,-wing_height-7),Vector2(-22,-wing_height+3),Vector2(-11,-5),Vector2(0,-6)],Color(0.77,0.92,0.84,alpha),ink,1.5)
	_silhouette([Vector2(-4,-5),Vector2(-12,-wing_height-12),Vector2(-32,-wing_height-8),Vector2(-28,-wing_height+1),Vector2(-24,-3),Vector2(-13,-1),Vector2(-4,-5)],wing_color,ink,1.8)
	_curve(Vector2(-7,-6),Vector2(-15,-9),Vector2(-23,-wing_height+1),Vector2(-25,-wing_height-3),Color(1.0,1.0,0.96,alpha),1.5)
	_curve(Vector2(-8,-7),Vector2(-11,-12),Vector2(-12,-wing_height-3),Vector2(-15,-wing_height-8),Color(0.48,0.69,0.59,alpha*0.5),0.8)
	var feet := lerpf(15.0,19.0,rest)-dash*5.0
	for x in [-10.0,3.0]:
		_curve(Vector2(x,8),Vector2(x-3,13),Vector2(x-5,feet),Vector2(x+1,feet),ink,1.8)
	var blink := fposmod(clock+seed_value*0.61,4.6)<0.13
	ArtSprites.bee_body(self,alpha,blink or rest>0.72,charge,trapped)
	if not trapped and (pose == "greet" or (pose == "leader" and _greeting > 0.0 and dash<0.5)):
		var wave := sin((clock+seed_value*0.07)*17)*3.0
		_curve(Vector2(6,10),Vector2(14,18),Vector2(24,17),Vector2(23,9+wave),ink,2)
	draw_set_transform(_world_offset)

func feedback_caption_rect(feedback: Dictionary) -> Rect2:
	var text_width := feedback_font.get_string_size(feedback.text,HORIZONTAL_ALIGNMENT_LEFT,-1,19).x
	var pos: Vector2=feedback.pos
	pos.y=clampf(pos.y-45-(0.9-feedback.life)*24,160,670)
	pos.x=clampf(pos.x,model.camera_x+text_width*0.5+24,model.camera_x+1256-text_width*0.5)
	return Rect2(pos-Vector2(text_width*0.5+9,23),Vector2(text_width+18,31))

func active_caption_rects() -> Array[Rect2]:
	var boxes: Array[Rect2]=[]
	if feedback_font==null: return boxes
	for feedback in _feedback:
		if feedback.kind=="caption": boxes.append(feedback_caption_rect(feedback))
	return boxes

func _effects() -> void:
	for feedback in _feedback:
		var alpha: float = minf(1.0, feedback.life * 2.5)
		var pos: Vector2 = feedback.pos
		if feedback.kind == "caption" and feedback_font != null:
			var words: String = feedback.text
			var box:=feedback_caption_rect(feedback)
			var text_width:=box.size.x-18.0
			pos=box.position+Vector2(box.size.x/2.0,23)
			var ink := Color(INK,alpha)
			var tint := Color("ffd3b6") if feedback.bad else CREAM; tint.a = alpha
			draw_style_box(_box_style(ink,Color.TRANSPARENT,0,9),box)
			draw_string(feedback_font,pos-Vector2(text_width*0.5,0),words,HORIZONTAL_ALIGNMENT_LEFT,-1,19,tint)
		elif feedback.kind == "blocked":
			for side in [-1.0, 0.0, 1.0]:
				draw_line(pos + Vector2(-9 + side * 9, -20), pos + Vector2(-12 + side * 12, -27), Color(0.95,0.89,0.68,alpha), 2.0, true)
		elif feedback.kind == "shield_end":
			var radius: float = 46.0+(0.4-feedback.life)*20.0
			for side in 2:
				draw_arc(pos-Vector2(0,9),radius,float(side)*PI+0.3,float(side)*PI+2.3,20,Color(0.80,0.92,0.74,alpha*0.6),1.6,true)
		else:
			draw_arc(pos, 24.0 + (0.55 - feedback.life) * 12.0, -PI * 0.85, PI * 0.3, 32, Color(0.96,0.81,0.50,alpha), 1.7, true)
	for ring in ripples:
		var progress: float = 1.0 - ring.life / 0.5
		var tint: Color = ring.color
		tint.a = ring.life * 0.85
		draw_arc(ring.pos, 14 + progress * 48, 0, TAU, 48, tint, 3.0 * (1.0 - progress) + 0.5, true)
	for bit in particles:
		var tint: Color = bit.color
		tint.a = minf(1.0, bit.life / bit.max_life * 1.5)
		_ellipse(bit.pos, Vector2(bit.size * 1.5, bit.size * 0.6), tint, bit.angle + clock * 1.5)

func _foreground(_act: int, cam: float) -> void:
	SampleLandscape.foreground(self,cam,clock)

func _flower(p: Vector2, radius: float, _tint: Color, seed_value: float) -> void:
	var sway := sin(clock*0.6+seed_value)*0.04
	draw_set_transform(_world_offset+p,sway,Vector2.ONE*(radius/15.0))
	ArtProps.decor(self,Vector2.ZERO,"flower")
	draw_set_transform(_world_offset)

func _ellipse(center: Vector2, radius: Vector2, tint: Color, angle := 0.0) -> void:
	var points := PackedVector2Array()
	for i in 40:
		var theta := i * TAU / 40.0
		points.append(center + Vector2(cos(theta) * radius.x, sin(theta) * radius.y).rotated(angle))
	draw_colored_polygon(points, tint)
	if model != null:
		var outline := points.duplicate()
		outline.append(outline[0])
		draw_polyline(outline,tint,1.0,true)

func _leaf(a: Vector2, b: Vector2, width: float, tint: Color) -> void:
	var axis := (b-a).normalized()
	var normal := axis.orthogonal()
	var points := PackedVector2Array()
	for i in 15:
		var t := float(i)/14.0
		var center := a.lerp(b,t)+normal*sin(t*PI)*width*0.14
		points.append(center+normal*pow(sin(t*PI),0.78)*width)
	for i in range(14,-1,-1):
		var t := float(i)/14.0
		var center := a.lerp(b,t)+normal*sin(t*PI)*width*0.14
		points.append(center-normal*pow(sin(t*PI),0.94)*width*0.57)
	draw_colored_polygon(points,tint)
	if width >= 9:
		_curve(a,a.lerp(b,0.33)+normal*width*0.11,a.lerp(b,0.66)+normal*width*0.11,b,tint.lightened(0.18),0.9)

func _curve(a: Vector2, b: Vector2, c: Vector2, d: Vector2, tint: Color, width: float) -> void:
	var points := PackedVector2Array()
	for i in 21:
		points.append(a.bezier_interpolate(b, c, d, float(i) / 20.0))
	draw_polyline(points, tint, width, true)

func _reaction_age(kind: String, point: Vector2) -> float:
	for i in range(_reactions.size()-1,-1,-1):
		if _reactions[i].kind == kind and _reactions[i].pos.distance_squared_to(point)<4.0:
			return _reactions[i].age
	return -1.0

func _silhouette(control: Array, fill: Color, edge: Color, width: float) -> void:
	if control.size() < 4: return
	var points := PackedVector2Array([control[0]])
	var at: Vector2 = control[0]
	var i := 1
	while i+2 < control.size():
		var b: Vector2 = control[i]
		var c: Vector2 = control[i+1]
		var d: Vector2 = control[i+2]
		for j in range(1,11): points.append(at.bezier_interpolate(b,c,d,float(j)/10.0))
		at = d
		i += 3
	if points.size() < 3: return
	draw_colored_polygon(points,fill)
	if edge.a>0.0 and width>0.0:
		points.append(points[0])
		draw_polyline(points,edge,width,true)

func _paper_shape(control: Array, tint: Color) -> void:
	if control.size() < 4: return
	var points := PackedVector2Array([control[0]])
	var at: Vector2 = control[0]
	var i := 1
	while i + 2 < control.size():
		var b: Vector2 = control[i]
		var c: Vector2 = control[i+1]
		var d: Vector2 = control[i+2]
		for j in range(1,13): points.append(at.bezier_interpolate(b,c,d,float(j)/12.0))
		at = d
		i += 3
	if points.size() >= 3:
		draw_colored_polygon(points,tint)
		if model != null:
			points.append(points[0])
			draw_polyline(points,tint,1.0,true)

func _oval(center: Vector2, radius: Vector2, fill: Color, edge: Color, width: float, angle := 0.0) -> void:
	var points := PackedVector2Array()
	for i in 40:
		var theta := i*TAU/40.0
		points.append(center+Vector2(cos(theta)*radius.x,sin(theta)*radius.y).rotated(angle))
	draw_colored_polygon(points,fill)
	if width > 0 and edge.a > 0:
		points.append(points[0])
		draw_polyline(points,edge,width,true)

func _outline_polygon(points: PackedVector2Array, fill: Color, edge: Color, width: float) -> void:
	draw_colored_polygon(points,fill)
	var line := points.duplicate()
	line.append(points[0])
	draw_polyline(line,edge,width,true)

func _box_style(fill: Color, edge: Color, width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	return style

func _cartoon_leaf(a: Vector2, b: Vector2, width: float, tint: Color) -> void:
	_leaf(a,b,width+3,INK)
	_leaf(a+Vector2(0,-1),b-Vector2(1,1),width,tint)
	_curve(a,a.lerp(b,0.33)-Vector2(0,width*0.17),a.lerp(b,0.66)-Vector2(0,width*0.12),b,tint.lightened(0.3),2)

func _dew(item: Dictionary) -> void:
	if item.collected: return
	var p: Vector2 = item.pos+Vector2(0,sin(clock*2.5+item.pos.x)*4)
	if p.x < model.camera_x-80 or p.x > model.camera_x+1360: return
	ArtProps.pickup(self,p,"dew")
	draw_line(p+Vector2(18,-13),p+Vector2(18,-5),CREAM,2,true)
	draw_line(p+Vector2(14,-9),p+Vector2(22,-9),CREAM,2,true)

func _shield_pickup(item: Dictionary) -> void:
	if item.collected: return
	var p: Vector2 = item.pos
	if p.x < model.camera_x-80 or p.x > model.camera_x+1360: return
	p.y += sin(clock*2.0+p.x*0.01)*2.0
	ArtProps.pickup(self,p,"shield")
	var angle := lerpf(-2.7,-0.4,fposmod(clock*0.45,1.0))
	var bead := p+Vector2.from_angle(angle)*36.0
	_ellipse(bead,Vector2(2.5,4.5),WATER_INK,angle+PI/2)

func _shield_shell(p: Vector2, front: bool) -> void:
	var center := p-Vector2(0,9)
	var remaining: float = clampf(model.shield_left/5.0,0.0,1.0)
	var warning: bool = model.shield_left <= 1.0
	var pulse := 0.5+0.5*sin(clock*18.0) if warning else 0.0
	var arrive := sin((1.0-_shield_birth/0.4)*PI)*4.0 if _shield_birth > 0.0 else 0.0
	var radius := 46.0+arrive+pulse*2.5
	if not front:
		draw_circle(center,radius,Color(0.71,0.92,0.80,0.10))
		return
	# The outer silhouette stays present even during the warning pulse. Its arc
	# drains from the model timer; the inner charge ring retains a separate radius.
	draw_arc(center,radius,0,TAU,64,Color(INK,0.65),3.5,true)
	draw_arc(center,radius-0.5,0,TAU,64,Color(0.82,0.95,0.76,0.54+pulse*0.26),1.7,true)
	var time_color := GOLD if warning else LEAF_LIGHT
	draw_arc(center,radius+4.0,-PI/2,-PI/2+TAU*maxf(0.003,remaining),64,time_color,3.4,true)
	for i in 5:
		var direction := Vector2.from_angle(-PI/2+float(i)*TAU/5.0)
		draw_line(center+direction*(radius+2.0),center+direction*(radius+6.0),INK,1.5,true)
	_curve(center+Vector2(-32,-11),center+Vector2(-33,-25),center+Vector2(-23,-34),center+Vector2(-13,-35),Color(0.98,1.0,0.86,0.65),2.4)
	if _shield_flash > 0.0:
		var strength := _shield_flash/0.24
		draw_arc(center,radius+(1.0-strength)*5.0,-PI*0.95,-PI*0.05,32,Color(0.97,1.0,0.85,strength),3.0,true)
	if warning:
		# The two closing leaf tips provide a shape cue as well as an amber tint.
		var close := (1.0-remaining*5.0)*5.0
		_leaf(center+Vector2(-4,-radius-6),center+Vector2(-15+close,-radius-16),4.5,Winter.FROST if Winter.active(self) else LEAF_LIGHT)
		_leaf(center+Vector2(4,-radius-6),center+Vector2(15-close,-radius-16),4.5,Winter.FROST if Winter.active(self) else LEAF_LIGHT)

func _sprayer(flower: Dictionary, index: int) -> void:
	var p: Vector2 = flower.pos
	if p.x < model.camera_x-140 or p.x > model.camera_x+1420: return
	var phase: String = model.sprayer_phase(index)
	var head := p+Vector2(0,sin(clock*2.2+index)*2)
	ArtProps.stalk(self,p+Vector2(0,28),p+Vector2(11,105),p+Vector2(-22,120),Vector2(p.x+12,814),9.0)
	ArtSprites.small_leaf(self,p+Vector2(4,75),p+Vector2(56,42),26)
	ArtSprites.small_leaf(self,p+Vector2(1,102),p+Vector2(-46,73),23)
	var warning := clampf(1.0-float(flower.timer)/0.8,0.001,1.0) if phase == "warning" else 0.0
	var sneeze := clampf(float(flower.flash)/0.25,0.0,1.0) if phase == "sneeze" else 0.0
	var blink := phase == "idle" and fposmod(clock+index*0.7,3.7)<0.12
	ArtProps.sprayer(self,head,phase == "calm",warning,sneeze,blink)
	if phase == "warning":
		# Use the same painted material language as the flower, clear of its petals.
		draw_texture_rect(ArtProps.FLOWER_WARNING,Rect2(head+Vector2(-22,-146),Vector2(44,66)),false)
	elif phase == "sneeze":
		for i in 3:
			var y := -13+i*13.0
			draw_line(head+Vector2(-46,y),head+Vector2(-71,y*1.5),Color("e0faff"),4,true)
	elif phase == "calm" and sin(clock*2.0)>0:
		var h := head+Vector2(37,-40)
		draw_circle(h+Vector2(-4,0),5,Color("f4a1b8"))
		draw_circle(h+Vector2(4,0),5,Color("f4a1b8"))
		draw_colored_polygon(PackedVector2Array([h+Vector2(-9,1),h+Vector2(9,1),h+Vector2(0,12)]),Color("f4a1b8"))

func _puff(p: Vector2) -> void:
	_oval(p,Vector2(11,10),Color("91c9e9"),Color("305e80"),3)
	_ellipse(p+Vector2(-3,-4),Vector2(4,3),Color("eafaff"))

func _landmarks(_act: int) -> void:
	# Signs identify the real safe leaves; scenic props belong to the background.
	if feedback_font == null: return
	for i in model.shelters.size():
		var rest: Vector2 = model.shelters[i].pos
		if rest.x < model.camera_x-210 or rest.x > model.camera_x+1430: continue
		var text := "叶亭 %02d" % (i+1)
		var w := feedback_font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,17).x
		var sign := rest+Vector2(0,83)
		ArtProps.decor(self,sign-Vector2(0,5),"sign")
		draw_string(feedback_font,sign-Vector2(w*0.5,0),text,HORIZONTAL_ALIGNMENT_LEFT,-1,17,INK)
