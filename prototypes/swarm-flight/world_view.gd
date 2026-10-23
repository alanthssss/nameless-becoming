extends Node2D
const SampleLandscape = preload("res://sample_landscape.gd")
const ArtSprites = preload("res://art_sprites.gd")
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

const INK := Color("253d26")
const GOLD := Color("ffc94f")
const CREAM := Color("fff8d8")
const WATER := Color("8cd6dc")
const WATER_INK := Color("346579")
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
	if kind in ["rescue", "ring", "flower_calm", "checkpoint"]:
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
			tint = LEAF_LIGHT
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
	_world_decor(act, cam)
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
	if model.phase == "ending":
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
	if model.stage in [0,4]:
		SampleLandscape.background(self,model.stage == 4,cam,clock)
		return
	for row in 40:
		var t := float(row)/39.0
		draw_rect(Rect2(0,row*20,1280,21),SKY[act].lerp(LOW_SKY[act],t))
	var sun := Vector2(1070-cam*0.015,165)
	if act < 2 or act == 3:
		draw_circle(sun,58,Color("f9e884"))
		draw_circle(sun-Vector2(8,8),47,Color("fff3b5"))
	for i in 5:
		var c := Vector2(fposmod(i*370.0-cam*0.035,1700)-170,155+(i%3)*56)
		var cloud: Color = Color("eaf6d6") if act < 2 else Color("8095ad")
		_ellipse(c,Vector2(100,22),cloud)
		_ellipse(c+Vector2(-34,-17),Vector2(42,30),cloud)
		_ellipse(c+Vector2(14,-23),Vector2(55,37),cloud)
	if model.stage == 3:
		_distant_home(cam)
	for layer in 2:
		var hedge: Color = [Color("77b965"),Color("70b3a0"),Color("618b80"),Color("7f9580")][act].darkened(layer*0.10)
		for i in 9:
			var x := fposmod(i*204.0-cam*(0.06+layer*0.05),1700)-180
			_ellipse(Vector2(x,609+layer*37),Vector2(148,108+sin(i*2.3)*25),hedge)
	# A distant picket fence identifies a garden, kept light and below the flight focus.
	var fence: Color = Color("d3d8a0") if act < 2 else Color("839e91")
	for i in 24:
		var x := fposmod(i*67.0-cam*0.18,1540)-120
		var pts := PackedVector2Array([Vector2(x,685),Vector2(x,578),Vector2(x+17,557),Vector2(x+34,578),Vector2(x+34,685)])
		draw_colored_polygon(pts,fence)
		draw_polyline(pts,fence.darkened(0.13),2,true)
		draw_line(Vector2(x+5,583),Vector2(x+5,671),fence.lightened(0.14),2,true)
	draw_rect(Rect2(0,608,1280,13),fence.darkened(0.11))
	draw_rect(Rect2(0,653,1280,12),fence.darkened(0.11))
	# Different lower sets: vegetable rows, a fountain pond, then a rainy tool garden.
	var lawn: Color = [Color("76ba44"),Color("61aa64"),Color("426e61"),Color("688454")][act]
	draw_rect(Rect2(0,683,1280,117),lawn)
	for i in 11:
		var x := fposmod(i*157.0-cam*0.23,1650)-130
		_ellipse(Vector2(x,749+(i%2)*22),Vector2(128,22),lawn.lightened(0.055))
	if act == 0:
		for i in 5:
			var x := fposmod(i*327.0-cam*0.22,1750)-180
			_oval(Vector2(x,738),Vector2(71,17),Color("8d6544"),Color("7e5a3b"),2)
			for j in 3:
				var c := Vector2(x-40+j*37,723)
				_oval(c,Vector2(18,13),Color("a7c852"),Color("6a943a"),2)
				_leaf(c+Vector2(-9,1),c+Vector2(11,-12),9,Color("d1df6b"))
	elif act == 1:
		_ellipse(Vector2(660-fmod(cam*0.12,150),740),Vector2(590,58),Color("498b93"))
		_ellipse(Vector2(660-fmod(cam*0.12,150),731),Vector2(570,42),Color("8bd3d0"))
		for i in 7:
			var x := fposmod(i*231.0-cam*0.17,1500)-80
			draw_arc(Vector2(x,728+i%2*15),39,0.15,2.7,18,Color("d6f0cf"),2,true)
		var f := Vector2(970-fmod(cam*0.12,1000),668)
		_oval(f+Vector2(0,19),Vector2(86,22),Color("a4bc9d"),Color("76968a"),3)
		_oval(f,Vector2(72,14),Color("c5d5b5"),Color("76968a"),3)
		draw_line(f,f-Vector2(0,72),Color("9ab7ac"),24,true)
		_oval(f-Vector2(0,69),Vector2(46,12),Color("ceddc0"),Color("76968a"),3)
		for side in [-1.0,1.0]:
			_curve(f-Vector2(0,77),f+Vector2(side*18,-139),f+Vector2(side*55,-77),f+Vector2(side*61,-6),Color("bcece0"),3.5)
	else:
		for i in 6:
			var x := fposmod(i*265.0-cam*0.19,1700)-180
			_ellipse(Vector2(x,735+i%2*18),Vector2(91,13),Color("799ba0"))
			_ellipse(Vector2(x-6,731+i%2*18),Vector2(65,5),Color("9dbdb9"))
		var shed := Vector2(970-fmod(cam*0.11,950),607)
		draw_style_box(_box_style(Color("728678"),Color("577267"),3,5),Rect2(shed-Vector2(70,40),Vector2(140,118)))
		_outline_polygon(PackedVector2Array([shed+Vector2(-86,-40),shed+Vector2(0,-100),shed+Vector2(86,-40)]),Color("8a8574"),Color("577267"),3)
		draw_rect(Rect2(shed+Vector2(-21,1),Vector2(43,77)),Color("58776a"))
	_region_background(cam)
	# Atmospheric wash keeps the garden set subordinate to outlined playable objects.
	var haze: Color = LOW_SKY[act]
	haze.a = 0.15 if act < 2 else 0.12
	draw_rect(Rect2(0,0,1280,800),haze)


func _region_background(cam: float) -> void:
	var region: int = model.chapter.region
	if region == 1:
		# Warm flower-border arches remain visibly behind the playable plants.
		for i in 6:
			var x := fposmod(i*300.0-cam*0.12,1800)-200
			_curve(Vector2(x,700),Vector2(x-50,270),Vector2(x+155,270),Vector2(x+135,700),Color("8cb28b"),12)
			for j in 3: _flower(Vector2(x+16+j*45,360-sin(j*1.5)*30),19,Color("d6a09e"),float(j))
	elif region == 2:
		for i in 5:
			var x := fposmod(i*350.0-cam*0.11,1750)-170
			_curve(Vector2(x,715),Vector2(x+20,550),Vector2(x-10,430),Vector2(x+15,300),Color("998267"),27)
			for j in 3:
				_ellipse(Vector2(x-60+j*65,332-sin(j*1.5)*45),Vector2(85,75),Color("c0ad65") if j%2 else Color("c78b64"))
			for j in 4: draw_circle(Vector2(x-44+j*32,345+sin(j*1.8)*30),9,Color("ae6f54"))
	elif region == 3:
		# Frost is outside the warm glass passage; it has no damage contract.
		for i in 6:
			var x := fposmod(i*270.0-cam*0.10,1620)-180
			draw_rect(Rect2(x,180,246,475),Color(0.82,0.92,0.87,0.17))
			draw_rect(Rect2(x,180,246,475),Color("93a59c"),false,8)
			draw_line(Vector2(x,330),Vector2(x+246,330),Color("93a59c"),6)
			for j in 4: draw_circle(Vector2(x+30+j*53,230+(j%2)*40),3,CREAM)
			draw_line(Vector2(x+123,180),Vector2(x+123,215),Color("a58e60"),2)
			_outline_polygon(PackedVector2Array([Vector2(x+111,221),Vector2(x+135,221),Vector2(x+144,240),Vector2(x+102,240)]),Color("c9b78a"),Color("83958b"),2)
			draw_line(Vector2(x+111,242),Vector2(x+135,242),Color("e8d89b"),3)

func _region_landmarks(cam: float) -> void:
	for item in model.chapter.decor:
		var p: Vector2 = item.pos
		if p.x < cam-120 or p.x > cam+1400: continue
		if item.style == "withered" or item.style == "dead_flower":
			_curve(p+Vector2(0,170),p+Vector2(-20,60),p+Vector2(18,-10),p+Vector2(35,10),Color("8e8460"),5)
			for i in 4: _leaf(p+Vector2(35,10),p+Vector2(15+i*13,45+i%2*15),8,Color("a5966b"))
		elif item.style == "lamp":
			draw_line(p+Vector2(0,150),p-Vector2(0,20),Color("738377"),4)
			_outline_polygon(PackedVector2Array([p+Vector2(-12,-13),p+Vector2(12,-13),p+Vector2(22,9),p+Vector2(-22,9)]),Color("b4b28a"),Color("738377"),2)
			draw_line(p+Vector2(-12,12),p+Vector2(12,12),Color("e8d89b"),3)
		else:
			# Unoutlined, small garden signs are decorative, never false walls.
			draw_line(p+Vector2(0,10),p+Vector2(0,65),Color("8b7956"),6)
			_oval(p,Vector2(31,15),Color("b9ad7c"),Color("8b7956"),2)
			draw_line(p-Vector2(16,0),p+Vector2(16,0),CREAM,2)

func _bird(p: Vector2) -> void:
	_oval(p+Vector2(0,-8),Vector2(23,18),Color("aa8564"),INK,2.5)
	_oval(p+Vector2(16,-23),Vector2(14,14),Color("c7a67b"),INK,2)
	draw_colored_polygon(PackedVector2Array([p+Vector2(28,-25),p+Vector2(40,-19),p+Vector2(28,-16)]),GOLD)
	draw_circle(p+Vector2(20,-26),3,INK)
	_leaf(p+Vector2(-5,0),p+Vector2(-36,-22),11,Color("7e6651"))
	draw_line(p+Vector2(-7,8),p+Vector2(-7,17),INK,2)
	draw_line(p+Vector2(6,8),p+Vector2(6,17),INK,2)

func _neighbors() -> void:
	if model.chapter.npc.is_empty() or model.shelters.is_empty(): return
	var indices := [0]
	if model.shelters.size() > 1 and model.stage != model.STAGE_COUNT-1: indices.append(model.shelters.size()-1)
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
	# The third homeward encounter reveals the destination across the garden.
	# This sits behind the hedges, has no cue/collider and fades before the real tree.
	if model.chapter.encounters.size() < 3: return
	var reveal_x: float = model.chapter.encounters[2].start_x
	var reveal: float = clampf((model.p.x-reveal_x+180.0)/240.0,0.0,1.0)
	var approach: float = clampf((model.exit_pos.x-model.p.x-1100.0)/1200.0,0.0,1.0)
	var opacity := reveal*approach
	if opacity <= 0.001: return
	var p := Vector2(1090.0-(cam-reveal_x+480.0)*0.055,660)
	var trunk := Color("887b64").lerp(LOW_SKY[3],0.25)
	trunk.a = opacity*0.78
	var edge := Color("697569")
	edge.a = opacity*0.40
	_silhouette([p+Vector2(40,0),p+Vector2(28,-110),p+Vector2(56,-210),p+Vector2(34,-318),p+Vector2(2,-330),p+Vector2(-27,-326),p+Vector2(-27,-307),p+Vector2(-17,-190),p+Vector2(-35,-110),p+Vector2(-49,0),p+Vector2(-17,-11),p+Vector2(18,-9),p+Vector2(40,0)],trunk,edge,2)
	_curve(p+Vector2(-4,-230),p+Vector2(-45,-255),p+Vector2(-88,-275),p+Vector2(-110,-319),trunk,17)
	_curve(p+Vector2(23,-258),p+Vector2(57,-274),p+Vector2(88,-301),p+Vector2(100,-338),trunk,15)
	var foliage := Color("859b76").lerp(LOW_SKY[3],0.18)
	foliage.a = opacity*0.76
	_ellipse(p+Vector2(-73,-344),Vector2(85,61),foliage)
	_ellipse(p+Vector2(17,-383),Vector2(97,67),foliage)
	_ellipse(p+Vector2(92,-349),Vector2(82,62),foliage)
	var upper := foliage.lightened(0.12)
	upper.a = opacity*0.55
	_ellipse(p+Vector2(-16,-396),Vector2(72,47),upper)
	var window := p+Vector2(0,-200)
	_oval(window,Vector2(14,22),Color(1.0,0.88,0.54,opacity*0.9),edge,2)
	_ellipse(window-Vector2(2,3),Vector2(8,15),Color(1.0,0.96,0.71,opacity*0.8))
	_curve(window+Vector2(-21,23),window+Vector2(-8,28),window+Vector2(8,28),window+Vector2(22,21),trunk,4)

func _world_decor(act: int, cam: float) -> void:
	if model.stage == 4: return
	var start := int(floor((cam-180)/235.0))
	for i in range(start,start+8):
		var x := i*235.0+sin(i*2.7)*24
		var root := Vector2(x,816)
		_cartoon_leaf(root,root+Vector2(-67,-64),23,Color("448d35"))
		_cartoon_leaf(root,root+Vector2(43,-83),19,Color("85bb42"))
		if i%3 == 0:
			var c := root+Vector2(76,-50)
			_flower(c,17,Color("f4b977") if act==0 else Color("b79be0"),float(i))

func _terrain(item: Dictionary) -> void:
	var r: Rect2 = item.rect
	var material: String = item.get("material","hedge")
	if model.stage == 4 and material == "hedge":
		ArtSprites.hedge(self,r)
		return
	var fill := Color("7aab48") if material == "hedge" else Color("bd935e") if material == "crate" else Color("779a96")
	draw_rect(r,fill)
	draw_rect(r,INK,false,4)
	var inner := r.grow(-8)
	if material != "hedge" and inner.size.x > 0 and inner.size.y > 0: draw_rect(inner,fill.lightened(0.24),false,3)
	if material == "crate":
		draw_line(r.position+Vector2(12,12),r.end-Vector2(12,12),Color("84613f"),7,true)
		draw_line(Vector2(r.position.x+12,r.end.y-12),Vector2(r.end.x-12,r.position.y+12),Color("84613f"),7,true)
		for x in range(1,int(r.size.x/85.0)):
			draw_line(r.position+Vector2(x*85,8),Vector2(r.position.x+x*85,r.end.y-8),Color("9e764d"),2)
	elif material == "hedge":
		# Dense clipped foliage reads as a solid hedge, not another HUD panel.
		for row in maxi(1,int(r.size.y/45.0)):
			var y := r.position.y+25+row*43.0
			for column in maxi(1,int(r.size.x/55.0)):
				var x := r.position.x+29+column*55.0
				var radius := Vector2(minf(29,r.end.x-x-3),minf(23,r.end.y-y-3))
				_ellipse(Vector2(x,y),radius,Color("60943f") if (row+column)%3 == 0 else Color("8ab750"))
				_leaf(Vector2(x-8,y+7),Vector2(x+10,y-9),7,Color("b0cf67"))
		for x in range(1,int(r.size.x/120.0)):
			_flower(Vector2(r.position.x+x*120,r.position.y+20),10,Color("d8b995"),float(x))
	else:
		draw_rect(Rect2(r.position,Vector2(r.size.x,minf(16,r.size.y))),Color("b6c7ac"))
		draw_line(r.position+Vector2(0,16),Vector2(r.end.x,r.position.y+16),INK,3)

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
	draw_style_box(_box_style(Color("729b97"),INK,3,5),base)
	var words := "喷发" if active else "将喷" if state == "warning" else "停喷"
	if feedback_font != null: draw_string(feedback_font,Vector2(r.get_center().x-30,r.end.y+36),words,HORIZONTAL_ALIGNMENT_CENTER,60,16,INK)

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
	var vertical := absf(dir.y) > 0.5
	var source := Vector2(r.get_center().x,r.end.y+9) if dir.y < -0.5 else Vector2(r.get_center().x,r.position.y-9) if dir.y > 0.5 else Vector2(r.end.x+10,r.get_center().y) if dir.x < 0 else Vector2(r.position.x-10,r.get_center().y)
	_oval(source,Vector2(27,10) if vertical else Vector2(10,27),Color("647f7d"),INK,2)
	for j in range(-2,3):
		if vertical: draw_line(source+Vector2(j*9,-6),source+Vector2(j*9,6),Color("c8ded2"),2)
		else: draw_line(source+Vector2(-6,j*9),source+Vector2(6,j*9),Color("c8ded2"),2)

func _wall(wall: Dictionary) -> void:
	var r: Rect2 = wall.rect
	if r.end.x < model.camera_x-80 or r.position.x > model.camera_x+1360: return
	if wall.kind == "terrain":
		_terrain(wall)
		return
	if wall.kind == "curtain":
		if wall.broken:
			_curve(r.position,r.position+Vector2(14,8),r.position+Vector2(29,-3),r.position+Vector2(r.size.x,2),Color("94713e"),2.2)
			for i in 3:
				var p := r.position+Vector2(7+i*12,0)
				_leaf(p,p+Vector2(9,22-i*3),6,Color("c2ab75"))
			return
		# A folded paper-thin leaf curtain: continuous face, tear seam, no stem pattern.
		draw_rect(r,Color("b99848"))
		draw_rect(r,INK,false,3.5)
		for i in range(int(r.size.y/58.0)+1):
			var y := r.position.y+i*58.0
			var h := minf(66,r.end.y-y)
			if h <= 0: continue
			_leaf(Vector2(r.position.x+1,y),Vector2(r.end.x-1,y+h),14,Color("e5ca63"))
			_leaf(Vector2(r.end.x-1,y),Vector2(r.position.x+1,y+h),11,Color("c4a646"))
		var seam := PackedVector2Array()
		for i in 19:
			seam.append(Vector2(r.get_center().x+(-3 if i%2 else 4),r.position.y+r.size.y*i/18.0))
		draw_polyline(seam,CREAM,2.2,true)
		if wall.has("needs_section"):
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
	# The full solid face and all four collision edges remain visible and still.
	# Broad overlapping leaf folds carry the material; only their inner veins sway.
	var upper := r.position.y < 100
	var body := Rect2(r.position,r.size)
	if upper:
		body.size.y += body.position.y+20
		body.position.y = -20
	elif r.end.y >= 725:
		body.size.y = 840-body.position.y
	var x := body.position.x
	var w := body.size.x
	var gap_y := r.end.y if upper else r.position.y
	var root_y := body.position.y if upper else body.end.y
	var direction := -1.0 if upper else 1.0
	var center := x+w*0.5
	var length := absf(root_y-gap_y)
	draw_rect(body,Color("497c35"))
	var fold := [Vector2(x+3,root_y),Vector2(x+w*0.88,root_y-direction*length*0.22),Vector2(x+4,gap_y+direction*length*0.31),Vector2(x+w-4,gap_y+direction*4),Vector2(x+w-1,gap_y+direction*length*0.33),Vector2(x+w-8,root_y-direction*length*0.45),Vector2(x+w-3,root_y)]
	_paper_shape(fold,Color("83b747"))
	_paper_shape([Vector2(x+4,root_y),Vector2(x+5,root_y-direction*length*0.38),Vector2(x+w*0.4,gap_y+direction*length*0.25),Vector2(x+8,gap_y+direction*4),Vector2(x+w*0.4+6,gap_y+direction*length*0.25),Vector2(x+11,root_y-direction*length*0.38),Vector2(x+12,root_y)],Color("b3d467"))
	var sway := sin(clock*1.1+x*0.021)*1.5
	_curve(Vector2(center+7,root_y),Vector2(x+6+sway,root_y-direction*length*0.35),Vector2(x+w-4,gap_y+direction*length*0.3),Vector2(x+7,gap_y+direction*8),Color("d3e779"),2.0)
	for i in range(1,5):
		var y := lerpf(root_y,gap_y,float(i)/5.0)
		var flip := -1.0 if i%2 else 1.0
		_curve(Vector2(center,y),Vector2(center+flip*5,y+direction*12),Vector2(center+flip*w*0.30,y+direction*24),Vector2(center+flip*w*0.43,y+direction*28),Color("c3dd77"),1.4)
	# A curled lip is painted inside the boundary, never used to disguise a collider.
	_curve(Vector2(x+3,gap_y+direction*7),Vector2(x+11,gap_y+direction*20),Vector2(x+w-6,gap_y+direction*20),Vector2(x+w-4,gap_y+direction*5),Color("33582b"),4)
	_curve(Vector2(x+5,gap_y+direction*5),Vector2(x+14,gap_y+direction*12),Vector2(x+w-10,gap_y+direction*13),Vector2(x+w-6,gap_y+direction*4),Color("d3e779"),2)
	draw_rect(body,INK,false,3.5)
	if not upper and r.end.y >= 725:
		_cartoon_leaf(Vector2(center,817),Vector2(x-65,739)+Vector2(sway*2,0),24,Color("345e4c"))
		_cartoon_leaf(Vector2(center+2,820),Vector2(x+w+55,745)+Vector2(sway*2,0),22,Color("5d7e5b"))

func _pod(pod: Dictionary) -> void:
	var p: Vector2 = pod.pos
	if p.x < model.camera_x-100 or p.x > model.camera_x+1380: return
	var age := _reaction_age("rescue",p)
	var opened := 0.0
	if pod.open:
		opened = 1.0 if age < 0.0 else 1.0-pow(1.0-clampf(age/0.65,0.0,1.0),3.0)
	var flex := 0.0 if age < 0.0 else sin(age*12.0)*exp(-age*4.0)*8.0
	var sway := sin(clock*1.4+p.x*0.01)*2.0
	_curve(p+Vector2(2,38),p+Vector2(18+sway,92),p+Vector2(-11,118),p+Vector2(-8,175),INK,6)
	_curve(p+Vector2(2,38),p+Vector2(18+sway,92),p+Vector2(-11,118),p+Vector2(-8,175),Color("76a841"),3)
	_cartoon_leaf(p+Vector2(1,90),p+Vector2(-52+sway*2,65),15,Color("91be4c"))
	# One asymmetrical folded cup opens at its real rescue event, then stays empty.
	var depth := lerpf(-45.0,21.0,opened)
	_silhouette([p+Vector2(0,39),p+Vector2(-51,27),p+Vector2(-51,depth-5),p+Vector2(-9,depth),p+Vector2(31,depth-15),p+Vector2(53,21),p+Vector2(0,39)],Color("739e38"),INK,3.2)
	var left_tip := p+Vector2(-16,-43).lerp(Vector2(-62,3-flex),opened)+Vector2(sway,0)
	var right_tip := p+Vector2(24,-41).lerp(Vector2(60,-11-flex),opened)+Vector2(sway,0)
	_cartoon_leaf(p+Vector2(1,37),left_tip,lerpf(25,21,opened),Color("c5dd6d"))
	_cartoon_leaf(p+Vector2(5,37),right_tip,lerpf(23,20,opened),Color("96bf49"))
	if opened < 0.8:
		var mouth := p+Vector2(0,7)
		_silhouette([mouth+Vector2(-22,17),mouth+Vector2(-31,-11),mouth+Vector2(-8,-29),mouth+Vector2(10,-23),mouth+Vector2(31,-18),mouth+Vector2(31,23),mouth+Vector2(-22,17)],Color("465d29"),INK,2)
		if not pod.open: _bee(mouth,0.76,Vector2.RIGHT,1.0,true,0.0)
	_curve(p+Vector2(-24,30),p+Vector2(-7,40),p+Vector2(10,40),p+Vector2(30,27),Color("d7e789"),3)

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
	var side := direction.orthogonal()
	var age := _reaction_age("ring",p)
	var close := 1.0 if used else 0.0
	if used and age >= 0.0: close = 1.0-pow(1.0-clampf(age/0.55,0.0,1.0),3.0)
	var recoil := 0.0 if age < 0.0 else sin(age*13.0)*exp(-age*3.8)*12.0
	var sway := sin(clock*1.1+index*1.7)*3.0
	_curve(p+Vector2(0,42),p+Vector2(-28+sway+recoil,165),p+Vector2(38,228),Vector2(p.x-26,831),INK,10)
	_curve(p+Vector2(0,42),p+Vector2(-28+sway+recoil,165),p+Vector2(38,228),Vector2(p.x-26,831),Color("73b141"),6)
	if model.stage == 4:
		_curve(p+Vector2(-1,42),p+Vector2(-29+sway+recoil,165),p+Vector2(37,228),Vector2(p.x-27,831),Color("b6d76a"),2)
		ArtSprites.small_leaf(self,p+Vector2(0,105),p+Vector2(-72+sway*1.5+recoil,61),30)
		ArtSprites.flower(self,p,direction,close,recoil,used)
		return
	_cartoon_leaf(p+Vector2(0,105),p+Vector2(-72+sway*1.5+recoil,61),23,Color("9acb53"))
	for i in 7:
		var a := float(i)*TAU/7-PI/2
		var axis := Vector2.from_angle(a)
		var breath := sin(clock*1.6+i*0.8+index)*2.0*(1.0-close)
		var tip := p+axis*(72.0+sin(i*2.4)*5+breath)
		tip = tip.lerp(p+axis*30+Vector2(0,16),close)+direction*recoil
		var base := p+axis*22
		var width := lerpf(25.0,11.0,close)
		var tint := (Color("63bdc6") if i%2 else Color("8ed9d2")).lerp(Color("8fad76"),close)
		# Fold along the actual base-to-tip axis. A fixed open-flower axis
		# would make closed upper petals cross themselves during recoil.
		var petal_vector := tip-base
		var petal_normal := petal_vector.normalized().orthogonal()
		_silhouette([base,base+petal_vector*0.35-petal_normal*width,tip-petal_vector*0.12-petal_normal*width*0.65,tip,tip-petal_vector*0.12+petal_normal*width*0.72,base+petal_vector*0.35+petal_normal*width*0.65,base],tint,INK,2.6)
		_curve(base,base+petal_vector*0.35+petal_normal*2,tip-petal_vector*0.25+petal_normal*3,tip-petal_vector*0.1,tint.lightened(0.27),1.7)
	# The center and the directional mark always use the model's exact anchor/direction.
	if used:
		_oval(p,Vector2(25,23),Color("78a08a"),INK,2.6)
		_curve(p+Vector2(-12,-2),p+Vector2(-7,7),p+Vector2(7,7),p+Vector2(12,-2),INK,2.6)
		return
	_silhouette([p+Vector2(0,-35),p+Vector2(25,-35),p+Vector2(39,-12),p+Vector2(34,6),p+Vector2(30,34),p+Vector2(-10,40),p+Vector2(-27,23),p+Vector2(-48,-1),p+Vector2(-27,-36),p+Vector2(0,-35)],Color("317f87"),INK,3)
	draw_arc(p,29,-2.6,0.2,32,Color("9de5db"),3,true)
	draw_polyline(PackedVector2Array([p-direction*10-side*12,p+direction*7,p-direction*10+side*12]),CREAM,5,true)
	for i in 3:
		var along := 76.0+fposmod(clock*26+i*22,66)
		draw_line(p+direction*along,p+direction*(along+10),Color(0.25,0.62,0.62,(1-(along-76)/85)*0.65),3,true)

func _shelter(shelter: Dictionary) -> void:
	var p: Vector2 = shelter.pos
	var half := float(shelter.get("half_width",118.0))
	if p.x+half < model.camera_x-80 or p.x-half > model.camera_x+1360: return
	var reached: bool = shelter.reached
	var stem_x := half+4.0
	_curve(p+Vector2(stem_x,-80),p+Vector2(stem_x+17,8),p+Vector2(stem_x-23,130),Vector2(p.x+stem_x-34,828),INK,12)
	_curve(p+Vector2(stem_x,-80),p+Vector2(stem_x+17,8),p+Vector2(stem_x-23,130),Vector2(p.x+stem_x-34,828),Color("77a945"),7)
	# Canopy underside stays above y=-65, the exact safe pocket starts at y=-64.
	# Its overhang follows the model's width, rather than hiding a wider safe zone.
	if model.stage == 4:
		_curve(p+Vector2(stem_x-2,-80),p+Vector2(stem_x+15,8),p+Vector2(stem_x-25,130),Vector2(p.x+stem_x-36,828),Color("b8d472"),2)
		ArtSprites.canopy(self,p,half)
	else:
		var canopy := [p+Vector2(-half-12,-80),p+Vector2(-half*0.50,-151),p+Vector2(half*0.58,-146),p+Vector2(half+9,-78),p+Vector2(half*0.54,-65),p+Vector2(-half*0.38,-66),p+Vector2(-half-12,-80)]
		_paper_shape(canopy,INK)
		_paper_shape([p+Vector2(-half-6,-82),p+Vector2(-half*0.43,-143),p+Vector2(half*0.54,-140),p+Vector2(half+2,-82),p+Vector2(half*0.51,-73),p+Vector2(-half*0.34,-73),p+Vector2(-half-6,-82)],Color("90be49"))
		_curve(p+Vector2(-half-3,-83),p+Vector2(-half*0.38,-110),p+Vector2(half*0.46,-110),p+Vector2(half+1,-81),LEAF_LIGHT,4)
		for i in 7:
			var x := lerpf(-half*0.72,half*0.70,float(i)/6.0)
			var lift := sin(float(i+1)*PI/8)*24
			_curve(p+Vector2(x,-100),p+Vector2(x+1,-103),p+Vector2(x+8,-109-lift),p+Vector2(x+17,-112-lift),Color("bedb6e"),2)
	# A tiny hanging lamp and a low cushion mark a usable resting place.
	draw_line(p+Vector2(-7,-91),p+Vector2(-7,-48),INK,2,true)
	_oval(p+Vector2(-7,-40),Vector2(11,15),GOLD if reached else Color("d8c778"),INK,2)
	_ellipse(p+Vector2(-10,-44),Vector2(3,7),CREAM)
	# The same little leaf tray spans the safe entry/exit; no rail blocks flight.
	_curve(p+Vector2(-half,72),p+Vector2(-half*0.35,76),p+Vector2(half*0.35,76),p+Vector2(half,72),Color(0.83,0.92,0.60,0.65),2)
	if model.stage == 4:
		ArtSprites.small_leaf(self,p+Vector2(60,57),p+Vector2(-60,57),29)
	else:
		_oval(p+Vector2(0,49),Vector2(58,12),Color("5c913d"),INK,3)
		_ellipse(p+Vector2(-5,46),Vector2(48,6),Color("b9d36b"))
	if reached:
		draw_polyline(PackedVector2Array([p+Vector2(-7,44),p+Vector2(-1,50),p+Vector2(10,37)]),CREAM,3,true)

func _exit(_act: int) -> void:
	var p: Vector2 = model.exit_pos
	if model.chapter.exit_kind != "home":
		# An open, leaf-framed threshold: the player crosses the bell's vertical
		# line within the same wide aperture used by the model (no hidden radius).
		var ready: bool = model.exit_ready
		var bloom := clampf(_arrival_elapsed/0.35,0.0,1.0)
		if ready:
			_ellipse(p+Vector2(22,0),Vector2(66,model.EXIT_HALF_HEIGHT),Color(1.0,0.91,0.55,0.10))
		_curve(p+Vector2(80,318),p+Vector2(113,116),p+Vector2(114,-149),p+Vector2(-42,-139),INK,13)
		_curve(p+Vector2(80,318),p+Vector2(113,116),p+Vector2(114,-149),p+Vector2(-42,-139),Color("77a945"),7)
		_leaf(p+Vector2(13,-129),p+Vector2(-97,-123-bloom*18),24,LEAF_LIGHT if ready else Color("8fa77a"))
		_leaf(p+Vector2(78,-66),p+Vector2(123,-108-bloom*10),18,Color("8bb95b"))
		_leaf(p+Vector2(-64,108),p+Vector2(111,107),20,Color("5c913d"))
		_leaf(p+Vector2(-57,106),p+Vector2(100,104),10,LEAF_LIGHT)
		_goal_bell(p+Vector2(0,-143))
		if ready and _arrival_elapsed < 0.0:
			for i in 2:
				var x := p.x-46+i*25+sin(clock*2.3)*3
				draw_polyline(PackedVector2Array([Vector2(x,p.y-10),Vector2(x+11,p.y),Vector2(x,p.y+10)]),CREAM,3,true)
		elif _arrival_elapsed >= 0.0:
			draw_polyline(PackedVector2Array([p+Vector2(-21,-41),p+Vector2(-9,-29),p+Vector2(15,-54)]),GOLD,4,true)
		return
	# Authored cut-paper trunk: three broad curved layers and one warm, clear hollow.
	_paper_shape([p+Vector2(-126,-510),p+Vector2(-61,-270),p+Vector2(-136,-33),p+Vector2(-110,171),p+Vector2(-103,278),p+Vector2(-170,351),p+Vector2(-225,397),p+Vector2(-32,356),p+Vector2(119,386),p+Vector2(226,398),p+Vector2(149,245),p+Vector2(167,41),p+Vector2(145,-141),p+Vector2(135,-270),p+Vector2(189,-406),p+Vector2(182,-510)],Color("4d3d2d"))
	_paper_shape([p+Vector2(-77,-510),p+Vector2(-22,-237),p+Vector2(-99,-41),p+Vector2(-72,186),p+Vector2(-54,273),p+Vector2(-95,348),p+Vector2(-119,379),p+Vector2(17,351),p+Vector2(90,370),p+Vector2(139,385),p+Vector2(100,211),p+Vector2(119,19),p+Vector2(104,-133),p+Vector2(93,-300),p+Vector2(142,-443),p+Vector2(131,-510)],Color("80673d"))
	for i in 3:
		var x := p.x-75+i*76.0
		_curve(Vector2(x,-50),Vector2(x+27,170),Vector2(x-24,460),Vector2(x+8,799),Color("ad9255"),4.5)
	var hollow := [p+Vector2(0,-130),p+Vector2(-95,-83),p+Vector2(-109,45),p+Vector2(-68,115),p+Vector2(-35,145),p+Vector2(48,143),p+Vector2(78,108),p+Vector2(107,24),p+Vector2(79,-86),p+Vector2(0,-130)]
	_paper_shape(hollow,Color("3a3224"))
	_paper_shape([p+Vector2(0,-111),p+Vector2(-76,-69),p+Vector2(-86,43),p+Vector2(-56,101),p+Vector2(-24,126),p+Vector2(42,124),p+Vector2(62,95),p+Vector2(86,28),p+Vector2(64,-72),p+Vector2(0,-111)],Color("d9b968"))
	_paper_shape([p+Vector2(10,-82),p+Vector2(-41,-33),p+Vector2(-48,53),p+Vector2(-28,103),p+Vector2(-4,118),p+Vector2(40,111),p+Vector2(55,89),p+Vector2(72,39),p+Vector2(58,-39),p+Vector2(10,-82)],Color("ffe3a0"))
	for i in 5:
		_leaf(p+Vector2(-58+i*24,117),p+Vector2(-35+i*20,87),12,Color("b0bd88") if i%2 else Color("829b71"))
	_leaf(p+Vector2(-84,120),p+Vector2(88,115),17,Color("668f3b"))
	_leaf(p+Vector2(-76,119),p+Vector2(81,117),8,Color("b3d66b"))
	_leaf(p+Vector2(-115,-161),p+Vector2(-199,-228),25,Color("497e38"))
	_leaf(p+Vector2(150,-177),p+Vector2(237,-235),27,Color("8db648"))
	_goal_bell(p+Vector2(0,-163))

	_waiting_friends()
	if model.phase == "ending":
		var bloom_count: int = mini(model.garden_total(),16)
		for i in bloom_count:
			var flower_pos := p+Vector2(-158+(i%8)*38,246+(i/8)*35-sin(i*1.9)*24)
			_curve(flower_pos+Vector2(0,60),flower_pos+Vector2(8,36),flower_pos+Vector2(-4,20),flower_pos,Color("8dbb53"),5)
			_flower(flower_pos,21,[Color("e9a5c9"),Color("f4cb62"),Color("bca0df")][i%3],float(i))

func _goal_bell(anchor: Vector2) -> void:
	var swing := sin(clock*1.8)*0.035
	if _arrival_elapsed >= 0.0:
		swing = sin(_arrival_elapsed*15.0)*exp(-_arrival_elapsed*2.4)*(0.55 if _arrival_dash else 0.4)
	var bell := anchor+Vector2(0,35).rotated(swing)
	draw_line(anchor,bell,INK,2.5,true)
	var tint := GOLD if model.exit_ready else Color("b0b382")
	_silhouette([bell+Vector2(-14,-8),bell+Vector2(-9,-19),bell+Vector2(8,-20),bell+Vector2(14,-7),bell+Vector2(19,8),bell+Vector2(7,12),bell+Vector2(-5,10),bell+Vector2(-19,7),bell+Vector2(-14,-8)],tint,INK,2.5)
	_curve(bell+Vector2(-10,-3),bell+Vector2(-5,-12),bell+Vector2(4,-13),bell+Vector2(8,-5),CREAM,2)
	draw_circle(bell+Vector2(0,13),4,INK)
	if _arrival_elapsed >= 0.0 and _arrival_elapsed < 0.8:
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
		_ellipse(c,Vector2(78,32),Color(0.19,0.32,0.43,0.66))
		_ellipse(c+Vector2(-15,-22),Vector2(42,34),Color(0.25,0.39,0.50,0.74))
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
		_ellipse(c,Vector2(spacing*0.54,16),cloud)
		_ellipse(c+Vector2(-spacing*0.16,-10),Vector2(spacing*0.23,20),cloud)
		_ellipse(c+Vector2(spacing*0.16,-15),Vector2(spacing*0.26,24),cloud)
		_curve(c+Vector2(-spacing*0.4,5),c+Vector2(-spacing*0.12,14),c+Vector2(spacing*0.20,13),c+Vector2(spacing*0.42,4),Color("9ab9bd"),1.5)
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
		draw_line(begin, end, Color(0.12, 0.25, 0.24, 0.6), 8.0, true)
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
	var ink := Color(0.15,0.20,0.12,alpha)
	var yellow := Color(1.0,0.79,0.28,alpha)
	var pale := Color(1.0,0.9,0.49,alpha)
	var wing_color := Color(0.9,0.99,0.91,alpha*0.94)
	var flutter := 0.5+0.5*sin(clock*(39.0 if charge>0.0 else 31.0)+seed_value*1.7)
	var wing_height := lerpf(17.0+flutter*11.0,3.0,rest)
	wing_height = lerpf(wing_height,8.0,dash)
	# Unequal, rooted wings fold along the back at rest and sweep aft on a launch.
	_silhouette([Vector2(0,-6),Vector2(-1,-wing_height-11),Vector2(-15,-wing_height-17),Vector2(-18,-wing_height-7),Vector2(-22,-wing_height+3),Vector2(-11,-5),Vector2(0,-6)],Color(0.77,0.92,0.84,alpha),ink,1.5)
	_silhouette([Vector2(-4,-5),Vector2(-12,-wing_height-12),Vector2(-32,-wing_height-8),Vector2(-28,-wing_height+1),Vector2(-24,-3),Vector2(-13,-1),Vector2(-4,-5)],wing_color,ink,1.8)
	_curve(Vector2(-7,-6),Vector2(-15,-9),Vector2(-23,-wing_height+1),Vector2(-25,-wing_height-3),Color(1.0,1.0,0.96,alpha),1.5)
	if model.stage in [0,4]:
		_curve(Vector2(-8,-7),Vector2(-11,-12),Vector2(-12,-wing_height-3),Vector2(-15,-wing_height-8),Color(0.48,0.69,0.59,alpha*0.5),0.8)
	var feet := lerpf(15.0,19.0,rest)-dash*5.0
	for x in [-10.0,3.0]:
		_curve(Vector2(x,8),Vector2(x-3,13),Vector2(x-5,feet),Vector2(x+1,feet),ink,1.8)
	if model.stage == 4:
		var blink := fposmod(clock+seed_value*0.61,4.6)<0.13
		ArtSprites.bee_body(self,alpha,blink or rest>0.72,charge)
	else:
		if size >= 0.95:
			var flutter_tail := sin(clock*8.0)*2.0*(1.0-rest)
			_silhouette([Vector2(-3,7),Vector2(-12,8),Vector2(-23,13+flutter_tail),Vector2(-30-dash*6,10+flutter_tail),Vector2(-23,23),Vector2(-12,17),Vector2(-3,7)],Color("e66e4e"),ink,1.6)
		# A single pear-shaped contour joins head and abdomen, with a soft cheek and tapered tail.
		_silhouette([Vector2(-23,2),Vector2(-23,-10),Vector2(-10,-16),Vector2(1,-12),Vector2(11,-19),Vector2(24,-12),Vector2(25,0),Vector2(27,11),Vector2(12,18),Vector2(1,14),Vector2(-11,14),Vector2(-20,10),Vector2(-23,2)],yellow,ink,2.5)
		_paper_shape([Vector2(-21,3),Vector2(-12,9),Vector2(8,15),Vector2(23,5),Vector2(20,16),Vector2(-7,19),Vector2(-21,3)],Color(0.87,0.57,0.14,alpha))
		_paper_shape([Vector2(-18,-5),Vector2(-10,-12),Vector2(-2,-10),Vector2(2,-7),Vector2(10,-14),Vector2(18,-12),Vector2(20,-8),Vector2(4,-4),Vector2(-9,-7),Vector2(-18,-5)],pale)
		for stripe in [-13.0,-4.0]:
			_curve(Vector2(stripe,-10),Vector2(stripe-4,-3),Vector2(stripe-3,6),Vector2(stripe+2,12),ink,3.5)
		# The far eye is smaller; the larger near eye and cheek keep a readable three-quarter face.
		var blink := fposmod(clock+seed_value*0.61,4.6)<0.13
		var eyes_closed := blink or rest>0.72
		if eyes_closed:
			_curve(Vector2(11,-3),Vector2(13,0),Vector2(17,0),Vector2(19,-3),ink,1.8)
			_curve(Vector2(20,-6),Vector2(22,-4),Vector2(24,-4),Vector2(25,-6),ink,1.4)
		else:
			_oval(Vector2(21,-5),Vector2(4.1,5.1),Color(1,0.99,0.91,alpha),ink,1.2)
			draw_circle(Vector2(22,-4.5),2.1,ink)
			_oval(Vector2(14,-3),Vector2(5.5,6.5),Color(1,0.99,0.91,alpha),ink,1.4)
			draw_circle(Vector2(16,-2.5),2.8,ink)
			draw_circle(Vector2(16.5,-3.7),0.9,Color(1,1,1,alpha))
		_ellipse(Vector2(15,6),Vector2(4,2.4),Color(0.97,0.61,0.26,alpha))
		if trapped:
			_curve(Vector2(19,9),Vector2(21,6),Vector2(23,6),Vector2(24,8),ink,1.4)
		else:
			_curve(Vector2(17,8),Vector2(20,11),Vector2(23,9),Vector2(24,6),ink,1.4)
		var feeler_sweep := dash*9.0-charge*4.0+settle*5.0
		for i in 2:
			var base := Vector2(6+i*9,-12)
			var tip := Vector2(3+i*17-feeler_sweep,-24+rest*5+sin(clock*3.2+seed_value+i)*1.4)
			_curve(base,base+Vector2(-1,-6),tip+Vector2(-3,1),tip,ink,1.6)
			draw_circle(tip,2.2,ink)
		if charge>0.1 and not eyes_closed:
			draw_line(Vector2(10,-11),Vector2(19,-8-charge*2.0),ink,1.7,true)
	if not trapped and (pose == "greet" or (pose == "leader" and _greeting > 0.0 and dash<0.5)):
		var wave := sin((clock+seed_value*0.07)*17)*3.0
		_curve(Vector2(6,10),Vector2(14,18),Vector2(24,17),Vector2(23,9+wave),ink,2)
	if size >= 0.95 and model.stage != 4:
		_silhouette([Vector2(0,9),Vector2(3,8),Vector2(8,10),Vector2(8,13),Vector2(4,17),Vector2(-2,14),Vector2(0,9)],Color("f28c5c"),ink,1.4)
	draw_set_transform(_world_offset)

func _effects() -> void:
	for feedback in _feedback:
		var alpha: float = minf(1.0, feedback.life * 2.5)
		var pos: Vector2 = feedback.pos
		if feedback.kind == "caption" and feedback_font != null:
			var words: String = feedback.text
			var text_width := feedback_font.get_string_size(words,HORIZONTAL_ALIGNMENT_LEFT,-1,19).x
			pos.y = clampf(pos.y-45-(0.9-feedback.life)*24,160,670)
			pos.x = clampf(pos.x,model.camera_x+text_width*0.5+24,model.camera_x+1256-text_width*0.5)
			var ink := Color("253d26"); ink.a = alpha
			var tint := Color("ffd3b6") if feedback.bad else CREAM; tint.a = alpha
			draw_style_box(_box_style(ink,Color.TRANSPARENT,0,9),Rect2(pos-Vector2(text_width*0.5+9,23),Vector2(text_width+18,31)))
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

func _foreground(act: int, cam: float) -> void:
	if model.stage in [0,4]:
		SampleLandscape.foreground(self,cam,clock)
		return
	var tint: Color = [Color("254f42"), Color("204f4a"), Color("1e3546"),Color("35463d")][act]
	for i in 40:
		var x := fposmod(i * 43.7 - cam * 1.15, 1400.0) - 60.0
		var high := 14.0 + float(i % 7) * 6.0
		var tip := Vector2(x + 8 + sin(clock * 1.4 + i) * 7, 800 - high)
		_leaf(Vector2(x, 805), tip, 3.5 + i % 3, tint)
	draw_rect(Rect2(0, 792, 1280, 8), tint)

func _flower(p: Vector2, radius: float, tint: Color, seed_value: float) -> void:
	for i in 5:
		var a := i * TAU / 5.0 + seed_value + sin(clock * 0.6 + seed_value) * 0.04
		_oval(p + Vector2.from_angle(a) * radius * 0.52, Vector2(radius * 0.67, radius * 0.38), tint, INK, 1.6, a)
	draw_circle(p, radius * 0.26, GOLD)

func _ellipse(center: Vector2, radius: Vector2, tint: Color, angle := 0.0) -> void:
	var points := PackedVector2Array()
	for i in 40:
		var theta := i * TAU / 40.0
		points.append(center + Vector2(cos(theta) * radius.x, sin(theta) * radius.y).rotated(angle))
	draw_colored_polygon(points, tint)
	if model != null and model.stage in [0,4]:
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
		if model != null and model.stage in [0,4]:
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
	# Stable diamond badge distinguishes a reward from moving round spray droplets.
	var gem := PackedVector2Array([p+Vector2(0,-17),p+Vector2(12,-3),p+Vector2(9,10),p+Vector2(0,15),p+Vector2(-10,9),p+Vector2(-12,-3)])
	_outline_polygon(gem,Color("72e0df"),Color("245e63"),3)
	draw_colored_polygon(PackedVector2Array([p+Vector2(0,-12),p+Vector2(0,10),p+Vector2(-8,7),p+Vector2(-9,-2)]),Color("cef8e9"))
	draw_line(p+Vector2(18,-13),p+Vector2(18,-5),CREAM,2,true)
	draw_line(p+Vector2(14,-9),p+Vector2(22,-9),CREAM,2,true)

func _shield_pickup(item: Dictionary) -> void:
	if item.collected: return
	var p: Vector2 = item.pos
	if p.x < model.camera_x-80 or p.x > model.camera_x+1360: return
	p.y += sin(clock*2.0+p.x*0.01)*2.0
	# A broad leaf cup around a clear membrane: unlike a dew gem or wind arrow.
	_silhouette([p+Vector2(0,-24),p+Vector2(-13,-28),p+Vector2(-24,-18),p+Vector2(-25,-7),p+Vector2(-25,10),p+Vector2(-13,24),p+Vector2(0,29),p+Vector2(13,24),p+Vector2(25,10),p+Vector2(25,-7),p+Vector2(24,-18),p+Vector2(13,-28),p+Vector2(0,-24)],Color("d7f1ce"),INK,2.8)
	_silhouette([p+Vector2(0,-17),p+Vector2(-10,-20),p+Vector2(-17,-12),p+Vector2(-17,-5),p+Vector2(-17,5),p+Vector2(-10,17),p+Vector2(0,21),p+Vector2(10,17),p+Vector2(17,5),p+Vector2(17,-5),p+Vector2(17,-12),p+Vector2(10,-20),p+Vector2(0,-17)],Color("7ec7b5"),Color.TRANSPARENT,0)
	_cartoon_leaf(p+Vector2(0,24),p+Vector2(-27,-5),10,Color("9fc76b"))
	_cartoon_leaf(p+Vector2(0,24),p+Vector2(28,-8),11,LEAF_LIGHT)
	_curve(p+Vector2(-11,-2),p+Vector2(-12,-12),p+Vector2(-4,-16),p+Vector2(3,-13),CREAM,2.5)
	# One gently deflected drop previews weather protection without particle clutter.
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
	draw_arc(center,radius,0,TAU,64,Color(0.16,0.36,0.33,0.65),3.5,true)
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
		_leaf(center+Vector2(-4,-radius-6),center+Vector2(-15+close,-radius-16),4.5,LEAF_LIGHT)
		_leaf(center+Vector2(4,-radius-6),center+Vector2(15-close,-radius-16),4.5,LEAF_LIGHT)

func _sprayer(flower: Dictionary, index: int) -> void:
	var p: Vector2 = flower.pos
	if p.x < model.camera_x-140 or p.x > model.camera_x+1420: return
	var phase: String = model.sprayer_phase(index)
	var bob := sin(clock*2.2+index)*2
	var swell := 1.0+0.09*sin(clock*15) if phase == "warning" else 1.0
	var head := p+Vector2(0,bob)
	_curve(p+Vector2(0,28),p+Vector2(11,105),p+Vector2(-22,120),Vector2(p.x+12,814),INK,9)
	_curve(p+Vector2(0,28),p+Vector2(11,105),p+Vector2(-22,120),Vector2(p.x+12,814),Color("70a343"),5)
	_cartoon_leaf(p+Vector2(4,75),p+Vector2(56,42),18,Color("a7cf56"))
	_cartoon_leaf(p+Vector2(1,102),p+Vector2(-46,73),16,Color("82ba43"))
	for i in 6:
		var a := i*TAU/6.0-0.2
		var petal := head+Vector2.from_angle(a)*31*swell
		_oval(petal,Vector2(26,17)*swell,Color("e8a5c2") if phase=="calm" else Color("bf7ba9"),INK,3,a)
		_ellipse(petal+Vector2(-4,-4),Vector2(14,6)*swell,Color("f2c3cf"),a)
	_oval(head,Vector2(33,28)*swell,Color("edbd78") if phase!="warning" else Color("f4a162"),INK,3)
	_ellipse(head+Vector2(-9,-8),Vector2(18,12),Color("f7d48e"))
	if phase == "calm":
		for x in [-12.0,8.0]:
			_curve(head+Vector2(x-5,-3),head+Vector2(x-2,-9),head+Vector2(x+2,-9),head+Vector2(x+5,-3),INK,2.8)
		_curve(head+Vector2(-10,11),head+Vector2(-3,20),head+Vector2(7,19),head+Vector2(12,9),INK,2.8)
		if sin(clock*2.0)>0:
			var h := head+Vector2(37,-40)
			draw_circle(h+Vector2(-4,0),5,Color("f4a1b8"))
			draw_circle(h+Vector2(4,0),5,Color("f4a1b8"))
			draw_colored_polygon(PackedVector2Array([h+Vector2(-9,1),h+Vector2(9,1),h+Vector2(0,12)]),Color("f4a1b8"))
	else:
		for x in [-13.0,8.0]:
			if phase == "sneeze" or (phase == "idle" and fposmod(clock+index*0.7,3.7)<0.12):
				_curve(head+Vector2(x-6,-3),head+Vector2(x-2,-7),head+Vector2(x+2,-7),head+Vector2(x+6,-3),INK,3)
			else:
				_oval(head+Vector2(x,-6),Vector2(8,10),CREAM,INK,2)
				draw_circle(head+Vector2(x-3,-5),3,INK)
		if phase == "warning":
			_oval(head+Vector2(-5,13),Vector2(10,8),Color("714734"),INK,2)
			draw_line(head+Vector2(-12,-53),head+Vector2(-12,-67),GOLD,5,true)
			draw_circle(head+Vector2(-12,-46),3,GOLD)
		else:
			_oval(head+Vector2(-19,9),Vector2(8,5),Color("84513f"),INK,2)
	if phase == "sneeze":
		for i in 3:
			var y := -13+i*13.0
			draw_line(head+Vector2(-46,y),head+Vector2(-71,y*1.5),Color("e0faff"),4,true)

func _puff(p: Vector2) -> void:
	_oval(p,Vector2(11,10),Color("91c9e9"),Color("305e80"),3)
	_ellipse(p+Vector2(-3,-4),Vector2(4,3),Color("eafaff"))

func _landmarks(act: int) -> void:
	# Decorative objects sit below the playable corridor; leaf shelters remain authoritative.
	for i in model.shelters.size():
		var rest: Vector2 = model.shelters[i].pos
		var x := rest.x-230.0
		if x < model.camera_x-210 or x > model.camera_x+1430: continue
		var p := Vector2(x,694)
		if model.stage not in [0,4]:
			match (i+act)%4:
				0: # Watering can, tilted spout and loop handle.
					draw_arc(p+Vector2(-66,-18),32,0.9,5.1,32,Color("547b72"),12,true)
					draw_style_box(_box_style(Color("77a99b"),INK,3,14),Rect2(p-Vector2(53,50),Vector2(104,76)))
					_outline_polygon(PackedVector2Array([p+Vector2(45,-19),p+Vector2(107,-69),p+Vector2(116,-59),p+Vector2(52,15)]),Color("93c3ad"),INK,3)
					_oval(p+Vector2(112,-65),Vector2(17,10),Color("b9d5b7"),INK,2,-0.5)
				1: # Terracotta pot with broad leaves.
					_outline_polygon(PackedVector2Array([p+Vector2(-49,-18),p+Vector2(48,-18),p+Vector2(34,48),p+Vector2(-32,48)]),Color("c68c63"),INK,3)
					draw_style_box(_box_style(Color("e0ad7b"),INK,3,7),Rect2(p-Vector2(57,29),Vector2(114,24)))
					for j in 3:
						_cartoon_leaf(p-Vector2(0,25),p+Vector2(-65+j*60,-86-24*(j%2)),22,Color("a5c956"))
				2: # Tiny garden bench.
					for side in [-1,1]: draw_line(p+Vector2(side*47,-2),p+Vector2(side*47,52),Color("5d6d48"),10,true)
					draw_style_box(_box_style(Color("c7b879"),INK,3,5),Rect2(p-Vector2(72,10),Vector2(144,22)))
					draw_style_box(_box_style(Color("decd8a"),INK,3,5),Rect2(p-Vector2(70,54),Vector2(140,30)))
				3: # A stack of pebbles and a familiar lantern.
					for j in 3: _oval(p+Vector2((j%2)*16,j*20),Vector2(42-j*7,16),Color("a5b6a0"),INK,2)
					draw_line(p+Vector2(-51,36),p+Vector2(-51,-65),INK,5,true)
					_outline_polygon(PackedVector2Array([p+Vector2(-63,-65),p+Vector2(-39,-65),p+Vector2(-29,-43),p+Vector2(-73,-43)]),Color("a3a17b"),Color("6d8072"),2)
					draw_line(p+Vector2(-63,-40),p+Vector2(-39,-40),Color("e8d89b"),3)
		if feedback_font != null:
			var text := "叶亭 %02d" % (i+1)
			var w := feedback_font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,17).x
			var sign := rest+Vector2(0,83)
			draw_style_box(_box_style(Color("fff0bf"),INK,2,7),Rect2(sign-Vector2(w*0.5+10,19),Vector2(w+20,29)))
			draw_string(feedback_font,sign-Vector2(w*0.5,0),text,HORIZONTAL_ALIGNMENT_LEFT,-1,17,INK)
