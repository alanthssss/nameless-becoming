extends Node2D
## A single painter for the authored landscape; never changes simulation state.
var model
var particles: Array[Dictionary] = []
var ripples: Array[Dictionary] = []
var trail: Array[Dictionary] = []
var clock := 0.0
var trail_clock := 0.0
var trauma := 0.0
var _rng := RandomNumberGenerator.new()
var _path: Array[Vector2] = []
var _last_stage := -1
var _ending_elapsed := 0.0
var _feedback: Array[Dictionary] = []

const INK := Color("253d26")
const GOLD := Color("ffc94f")
const CREAM := Color("fff8d8")
const SKY := [Color("91dbe3"), Color("8bcbdc"), Color("657ea1")]
const LOW_SKY := [Color("edf3ba"), Color("daeebc"), Color("9bb7b0")]

func _ready() -> void:
	_rng.seed = 14631

func _process(delta: float) -> void:
	clock += delta
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
		if model.stage != _last_stage or (not _path.is_empty() and _path.back().distance_to(model.p) > 180.0):
			_path.clear()
			particles.clear()
			ripples.clear()
			trail.clear()
			_feedback.clear()
			_last_stage = model.stage
		if _path.is_empty():
			_path.append(model.p)
		while _path.back().distance_to(model.p) >= 8.0:
			_path.append(_path.back().move_toward(model.p, 8.0))
			if _path.size() > 48:
				_path.pop_front()
		_ending_elapsed = _ending_elapsed + delta if model.phase == "ending" else 0.0
		trail_clock += delta
		if model.burst_left > 0.0 and trail_clock > 0.022:
			trail_clock = 0.0
			trail.append({"pos": model.p, "life": 0.28, "face": model.face})
	queue_redraw()

func emit_event(kind: String, pos: Vector2) -> void:
	var tint := GOLD
	var count := 12
	var force := 150.0
	match kind:
		"rescue":
			tint = Color("fff3a4")
			count = 30
			force = 180.0
		"dew":
			tint = Color("8ef6f1")
			count = 16
			force = 130.0
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
	var act: int = clampi(model.stage, 0, 2)
	var cam: float = model.camera_x
	_background(act, cam)
	var shake := Vector2(sin(clock * 53.0), sin(clock * 39.0)) * trauma * trauma * 9.0
	draw_set_transform(Vector2(-cam, 0) + shake)
	_world_decor(act, cam)
	for wall in model.walls:
		_wall(wall)
	for shelter in model.shelters:
		_shelter(shelter)
	for i in range(model.rings.size()):
		_ring(model.rings[i], i)
	for pod in model.pods:
		_pod(pod)
	for item in model.dew:
		_dew(item)
	for i in model.sprayers.size():
		_sprayer(model.sprayers[i], i)
	for puff in model.puffs:
		_puff(puff.pos)
	_exit(act)
	_storm(cam)
	if model.phase == "ending":
		_ending_weather(cam)
	for drop in model.drops:
		_drop(drop.pos, drop.vel)
	for ghost in trail:
		var alpha: float = ghost.life / 0.28 * 0.18
		_ellipse(ghost.pos, Vector2(22, 10), Color(1.0, 0.91, 0.56, alpha), ghost.face.angle())
	_swarm()
	_effects()
	draw_set_transform(Vector2.ZERO)
	_foreground(act, cam)

func _background(act: int, cam: float) -> void:
	for row in 40:
		var t := float(row)/39.0
		draw_rect(Rect2(0,row*20,1280,21),SKY[act].lerp(LOW_SKY[act],t))
	var sun := Vector2(1070-cam*0.015,165)
	if act < 2:
		draw_circle(sun,58,Color("f9e884"))
		draw_circle(sun-Vector2(8,8),47,Color("fff3b5"))
	for i in 5:
		var c := Vector2(fposmod(i*370.0-cam*0.035,1700)-170,155+(i%3)*56)
		var cloud: Color = Color("eaf6d6") if act < 2 else Color("8095ad")
		_ellipse(c,Vector2(100,22),cloud)
		_ellipse(c+Vector2(-34,-17),Vector2(42,30),cloud)
		_ellipse(c+Vector2(14,-23),Vector2(55,37),cloud)
	for layer in 2:
		var hedge: Color = [Color("77b965"),Color("70b3a0"),Color("618b80")][act].darkened(layer*0.10)
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
	var lawn: Color = [Color("76ba44"),Color("61aa64"),Color("426e61")][act]
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

func _world_decor(act: int, cam: float) -> void:
	var start := int(floor((cam-180)/235.0))
	for i in range(start,start+8):
		var x := i*235.0+sin(i*2.7)*24
		var root := Vector2(x,816)
		_cartoon_leaf(root,root+Vector2(-67,-64),23,Color("448d35"))
		_cartoon_leaf(root,root+Vector2(43,-83),19,Color("85bb42"))
		if i%3 == 0:
			var c := root+Vector2(76,-50)
			_flower(c,17,Color("f4b977") if act==0 else Color("b79be0"),float(i))

func _wall(wall: Dictionary) -> void:
	var r: Rect2 = wall.rect
	if r.end.x < model.camera_x-80 or r.position.x > model.camera_x+1360: return
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
		return
	# Solid sides match the model rectangle. A 20px inward bud cap replaces
	# the former flat cut; the tip remains at the exact authored gap boundary.
	var upper := r.position.y < 100
	var body := Rect2(r.position,r.size)
	if upper:
		body.size.y += body.position.y+20
		body.position.y = -20
	elif r.end.y >= 725:
		body.size.y = 840-body.position.y
	var x := body.position.x
	var w := body.size.x
	var top := body.position.y
	var bottom := body.end.y
	var center := x+w*0.50
	var gap_y := r.end.y if upper else r.position.y
	var root_y := body.position.y if upper else body.end.y
	var direction := -1.0 if upper else 1.0
	var cap := minf(20.0,w*0.42)
	var tip := Vector2(center+2.0,gap_y)
	var right := Vector2(x+w,gap_y+direction*cap)
	var left := Vector2(x,gap_y+direction*cap)
	var outline := PackedVector2Array([Vector2(x,root_y),Vector2(x+w,root_y),right])
	for i in range(1,13):
		outline.append(right.bezier_interpolate(Vector2(x+w-2,gap_y+direction*7),tip+Vector2(8,direction*6),tip,float(i)/12.0))
	for i in range(1,13):
		outline.append(tip.bezier_interpolate(tip+Vector2(-7,direction*7),Vector2(x+2,gap_y+direction*9),left,float(i)/12.0))
	draw_colored_polygon(outline,Color("497c35"))
	var closed := outline.duplicate()
	closed.append(outline[0])
	draw_polyline(closed,INK,4.5,true)
	# Three broad values give the stem a rounded cross-section without moving collision edges.
	_curve(Vector2(x+w-8,root_y),Vector2(x+w-8,root_y+(gap_y-root_y)*0.4),Vector2(x+w-9,gap_y+direction*65),tip+Vector2(3,direction*12),Color("33582b"),9)
	_curve(Vector2(x+11,root_y),Vector2(x+11,root_y+(gap_y-root_y)*0.4),Vector2(x+11,gap_y+direction*55),tip+Vector2(-3,direction*12),Color("a9cf5a"),5)
	# The curled bud closes into a pointed, curved end instead of a flat crosscut.
	_paper_shape([Vector2(x+3,root_y),Vector2(x+w*0.85,root_y+(gap_y-root_y)*0.25),Vector2(x+4,root_y+(gap_y-root_y)*0.67),tip+Vector2(0,direction*3),Vector2(x+w-6,gap_y+direction*30),Vector2(x+w-3,root_y+(gap_y-root_y)*0.46),Vector2(x+w-3,root_y)],Color("73a940"))
	_curve(Vector2(center,root_y),Vector2(x+8,root_y+(gap_y-root_y)*0.35),Vector2(x+w-7,root_y+(gap_y-root_y)*0.7),tip+Vector2(0,direction*2),Color("d3e779"),1.5)
	for i in 3:
		var base := Vector2(center+(i-1)*w*0.24,gap_y+direction*(62+i*8))
		_leaf(base,tip+Vector2((i-1)*3,direction*6),w*0.12,Color("86bd42") if i%2 else Color("b1d45d"))
	for i in range(1,4):
		var y := lerpf(root_y,gap_y,float(i)/4.0)
		var flip := -1.0 if i%2 else 1.0
		_curve(Vector2(center,y),Vector2(center+flip*7,y+direction*12),Vector2(center+flip*(w*0.35),y+direction*23),Vector2(center+flip*(w*0.43),y+direction*31),Color("bdcf67"),1.0)
	if not upper and r.end.y >= 725:
		_leaf(Vector2(center,817),Vector2(x-65,739),24,Color("345e4c"))
		_leaf(Vector2(center+2,820),Vector2(x+w+55,745),22,Color("5d7e5b"))

func _pod(pod: Dictionary) -> void:
	var p: Vector2 = pod.pos
	if p.x < model.camera_x-100 or p.x > model.camera_x+1380: return
	_curve(p+Vector2(2,40),p+Vector2(18,92),p+Vector2(-11,118),p+Vector2(-8,175),INK,6)
	_curve(p+Vector2(2,40),p+Vector2(18,92),p+Vector2(-11,118),p+Vector2(-8,175),Color("76a841"),3)
	_cartoon_leaf(p+Vector2(1,90),p+Vector2(-52,65),15,Color("91be4c"))
	if pod.open:
		_cartoon_leaf(p+Vector2(0,36),p+Vector2(-56,-5),22,Color("c1d967"))
		_cartoon_leaf(p+Vector2(0,36),p+Vector2(52,-13),23,Color("99bc45"))
		return
	_oval(p+Vector2(3,5),Vector2(45,50),Color("739e38"),INK,4)
	_oval(p+Vector2(-8,-6),Vector2(32,36),Color("a9cf54"),Color.TRANSPARENT,0)
	_cartoon_leaf(p+Vector2(8,-42),p+Vector2(-32,32),24,Color("c5dd6d"))
	_cartoon_leaf(p+Vector2(15,-42),p+Vector2(25,41),18,Color("84b63d"))
	# The occupied fold is warm and animated; opening leaves an unmistakably empty cup.
	_oval(p+Vector2(0,5),Vector2(25,29),Color("465d29"),INK,2)
	_bee(p+Vector2(0,5),0.76,Vector2.RIGHT,1.0,true,0.0)
	_curve(p+Vector2(-26,30),p+Vector2(-7,38),p+Vector2(10,38),p+Vector2(31,28),Color("d7e789"),4)

func _ring(ring: Dictionary, index: int) -> void:
	var p: Vector2 = ring.pos
	if p.x < model.camera_x-200 or p.x > model.camera_x+1400: return
	var used: bool = ring.active
	var direction: Vector2 = model.ring_direction(index)
	var side := direction.orthogonal()
	_curve(p+Vector2(0,42),p+Vector2(-28,165),p+Vector2(38,228),Vector2(p.x-26,831),INK,10)
	_curve(p+Vector2(0,42),p+Vector2(-28,165),p+Vector2(38,228),Vector2(p.x-26,831),Color("73b141"),6)
	_cartoon_leaf(p+Vector2(0,105),p+Vector2(-72,61),23,Color("9acb53"))
	if used:
		for i in 5:
			var a := float(i)*TAU/5-PI/2
			_cartoon_leaf(p+Vector2.from_angle(a)*36,p+Vector2(0,18),13,Color("8fad76"))
		_curve(p+Vector2(-14,2),p+Vector2(-7,10),p+Vector2(7,10),p+Vector2(14,2),INK,3)
		return
	for i in 7:
		var a := float(i)*TAU/7-PI/2+sin(clock*0.8)*0.02
		var axis := Vector2.from_angle(a)
		_oval(p+axis*45,Vector2(28,17),Color("63bdc6") if i%2 else Color("8ed9d2"),INK,3,a)
		_ellipse(p+axis*47+Vector2(-3,-4),Vector2(17,7),Color("b7eee0"),a)
	_oval(p,Vector2(35,35),Color("317f87"),INK,3)
	draw_arc(p,29,-2.6,0.2,32,Color("9de5db"),4,true)
	var arrow := p+direction*sin(clock*2)*2
	draw_polyline(PackedVector2Array([arrow-direction*10-side*12,arrow+direction*7,arrow-direction*10+side*12]),CREAM,5,true)
	for i in 3:
		var along := 76.0+fposmod(clock*26+i*22,66)
		draw_line(p+direction*along,p+direction*(along+10),Color(0.25,0.62,0.62,(1-(along-76)/85)*0.65),3,true)

func _shelter(shelter: Dictionary) -> void:
	var p: Vector2 = shelter.pos
	var reached: bool = shelter.reached
	_curve(p+Vector2(120,-80),p+Vector2(137,8),p+Vector2(97,130),Vector2(p.x+86,828),INK,12)
	_curve(p+Vector2(120,-80),p+Vector2(137,8),p+Vector2(97,130),Vector2(p.x+86,828),Color("77a945"),7)
	# Canopy underside stays above y=-65, the exact safe pocket starts at y=-64.
	var canopy := [p+Vector2(-130,-80),p+Vector2(-59,-151),p+Vector2(68,-146),p+Vector2(127,-78),p+Vector2(63,-65),p+Vector2(-45,-66),p+Vector2(-130,-80)]
	_paper_shape(canopy,INK)
	_paper_shape([p+Vector2(-124,-82),p+Vector2(-51,-143),p+Vector2(63,-140),p+Vector2(120,-82),p+Vector2(60,-73),p+Vector2(-40,-73),p+Vector2(-124,-82)],Color("90be49"))
	_curve(p+Vector2(-121,-83),p+Vector2(-45,-110),p+Vector2(54,-110),p+Vector2(119,-81),Color("d5e77f"),4)
	for i in 6:
		var x := -84+i*32.0
		var lift := sin(float(i+1)*PI/7)*24
		_curve(p+Vector2(x,-100),p+Vector2(x+1,-103),p+Vector2(x+8,-109-lift),p+Vector2(x+17,-112-lift),Color("bedb6e"),2)
	# A tiny hanging lamp and a low cushion mark a usable resting place.
	draw_line(p+Vector2(-7,-91),p+Vector2(-7,-48),INK,2,true)
	_oval(p+Vector2(-7,-40),Vector2(11,15),GOLD if reached else Color("d8c778"),INK,2)
	_ellipse(p+Vector2(-10,-44),Vector2(3,7),CREAM)
	_oval(p+Vector2(0,49),Vector2(58,12),Color("5c913d"),INK,3)
	_ellipse(p+Vector2(-5,46),Vector2(48,6),Color("b9d36b"))
	if reached:
		draw_polyline(PackedVector2Array([p+Vector2(-7,44),p+Vector2(-1,50),p+Vector2(10,37)]),CREAM,3,true)

func _exit(act: int) -> void:
	var p: Vector2 = model.exit_pos
	if act < 2:
		_curve(p+Vector2(-95,180),p+Vector2(-104,-38),p+Vector2(-25,-111),p+Vector2(50,-88),Color("49795f"),10)
		_leaf(p+Vector2(-64,-57),p+Vector2(44,-101),28,Color("8fa77a"))
		_leaf(p+Vector2(-77,-13),p+Vector2(-120,-63),17,Color("688d6e"))
		if model.exit_ready:
			for i in 2:
				var x := p.x-16+i*27+sin(clock*2.3)*3
				draw_polyline(PackedVector2Array([Vector2(x,p.y-10),Vector2(x+11,p.y),Vector2(x,p.y+10)]),CREAM,3,true)
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

	if model.phase == "ending":
		var bloom_count: int = model.garden_total()
		for i in bloom_count:
			var flower_pos := p+Vector2(-158+i*38,246-sin(i*1.9)*24)
			_curve(flower_pos+Vector2(0,60),flower_pos+Vector2(8,36),flower_pos+Vector2(-4,20),flower_pos,Color("8dbb53"),5)
			_flower(flower_pos,21,[Color("e9a5c9"),Color("f4cb62"),Color("bca0df")][i%3],float(i))

func _storm(cam: float) -> void:
	if not model.storm_active:
		return
	var front: float = model.storm_x
	if front < cam - 100:
		return
	var start := maxf(cam - 10.0, front - 1500.0)
	draw_rect(Rect2(start, 0, maxf(0.0, front - start), 800), Color(0.13, 0.26, 0.36, 0.44))
	for band in 8:
		var x := front - 12.0 + band * 10.0
		draw_rect(Rect2(x, 0, 11, 800), Color(0.19, 0.36, 0.46, (8 - band) * 0.025))
	for i in 70:
		var x := front - fposmod(i * 37.7 + clock * 140.0, 1400.0)
		var y := fposmod(i * 63.0 + clock * 530.0, 900.0) - 50.0
		draw_line(Vector2(x, y), Vector2(x - 9, y + 29), Color(0.65, 0.86, 0.94, 0.34), 1.3, true)
	for i in 8:
		var y := i * 115.0 + sin(clock * 2 + i) * 16.0
		draw_arc(Vector2(front - 10, y), 40, -PI / 2.0, PI / 2.0, 15, Color(0.70, 0.90, 0.99, 0.20), 2.0, true)

func _drop(p: Vector2, velocity: Vector2) -> void:
	var direction := velocity.normalized()
	if direction.is_zero_approx():
		direction = Vector2.DOWN
	draw_line(p - direction * 28.0, p, Color(0.69, 0.94, 1.0, 0.4), 5.0, true)
	var points := PackedVector2Array([p - direction * 17, p + direction.orthogonal() * 8, p + direction * 8, p - direction.orthogonal() * 8])
	draw_colored_polygon(points, Color("c0ecff"))
	draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[3], points[0]]), Color("3d789b"), 2.0, true)
	draw_circle(p + Vector2(-2, -1), 2.5, Color("f3ffff"))

func _swarm() -> void:
	var p: Vector2 = model.p
	var face: Vector2 = model.face
	if face.length_squared() < 0.01:
		face = Vector2.RIGHT
	var compact: bool = model.charging
	var burst: bool = model.burst_left > 0.0
	if model.phase == "ending":
		_ending_swarm()
		return
	for i in range(model.bees - 1, 0, -1):
		var side := 1.0 if i % 2 else -1.0
		var along := float(i) * (8.0 if compact or burst else 10.0)
		var center := _path_position(along)
		var tangent := (_path_position(maxf(0.0, along - 6.0)) - center).normalized()
		if tangent.is_zero_approx():
			tangent = face
		var across := side * (2.5 if compact or burst else 9.0 + float(i) * 0.7)
		var companion := center + tangent.orthogonal() * across
		if not _free_visual_position(companion):
			companion = center
		_bee(companion, 0.68, tangent, 0.85, false, i)
	if model.invulnerable <= 0.0 or sin(clock * 28.0) > -0.35:
		if burst:
			_ellipse(p - face * 16.0, Vector2(38, 17), Color(1.0, 0.89, 0.48, 0.18), face.angle())
		_bee(p, 1.0, face, 1.0, false, 0.0)
	if compact:
		var fill: float = clampf(model.charge, 0.0, 1.0)
		var ready: bool = fill >= model.CHARGE_READY and model.can_burst()
		var col := Color("fff4b3") if ready else Color("c5a96c")
		draw_arc(p, 27, -PI / 2, -PI / 2 + TAU * maxf(0.005, fill), 48, col, 4.0, true)
		var begin := p + face * 37
		var end := p + face * (67.0 + fill * 58.0)
		draw_line(begin, end, Color(0.12, 0.25, 0.24, 0.6), 8.0, true)
		draw_line(begin, end, col, 4.0, true)
		draw_polyline(PackedVector2Array([end - face * 14 + face.orthogonal() * 10, end, end - face * 14 - face.orthogonal() * 10]), col, 4.0, true)
		if ready:
			draw_arc(p, 33 + sin(clock * 8.0) * 2.0, 0, TAU, 48, Color(1.0, 0.95, 0.65, 0.3), 1.5, true)

func _path_position(distance: float) -> Vector2:
	var cursor: Vector2 = model.p
	for i in range(_path.size() - 1, -1, -1):
		var length := cursor.distance_to(_path[i])
		if length >= distance and length > 0.001:
			return cursor.lerp(_path[i], distance / length)
		distance -= length
		cursor = _path[i]
	return cursor

func _free_visual_position(point: Vector2) -> bool:
	for wall in model.walls:
		if not wall.broken and wall.rect.grow(8.0).has_point(point):
			return false
	return true

func _ending_swarm() -> void:
	var progress := clampf(_ending_elapsed / 1.8, 0.0, 1.0)
	var eased := 1.0 - pow(1.0 - progress, 3.0)
	for i in range(model.bees - 1, 0, -1):
		var home: Vector2 = model.exit_pos + Vector2(-43 + (i % 5) * 18, 65 + (i / 5) * 18)
		var start := _path_position(float(i) * 10.0)
		var p := start.lerp(home, eased)
		_bee(p, 0.68, Vector2.RIGHT, 1.0, false, float(i))
	var lead: Vector2 = model.p.lerp(model.exit_pos + Vector2(-5, 42), eased)
	_bee(lead, 1.0, Vector2.RIGHT, 1.0, false, 0.0)

func _ending_weather(cam: float) -> void:
	var edge: float = model.exit_pos.x - 106.0
	var width := maxf(1.0, edge - cam)
	for i in 60:
		var x := cam + fposmod(float(i) * 63.3 - clock * 42.0, width)
		var y := fposmod(float(i) * 67.3 + clock * 390.0, 880.0) - 40.0
		draw_line(Vector2(x, y), Vector2(x - 8, y + 25), Color(0.77, 0.91, 0.98, 0.29), 1.0, true)

func _bee(p: Vector2, size: float, face: Vector2, alpha: float, trapped: bool, seed_value: float) -> void:
	var axis := face.normalized()
	var cross := axis.orthogonal()
	var angle := axis.angle()
	var wing := 0.6+absf(sin(clock*34.0+seed_value))*0.5
	if model != null and model.phase == "ending": wing *= 0.3+0.7*exp(-_ending_elapsed*2)
	var ink := Color(0.15,0.20,0.12,alpha)
	for side in [-1.0,1.0]:
		var center: Vector2 = p-axis*6*size+cross*side*12*size
		_oval(center,Vector2(13,8*wing)*size,Color(0.9,0.99,0.91,alpha*0.95),ink,1.8*size,angle+side*0.6)
		_ellipse(center-cross*side*2*size,Vector2(8,3*wing)*size,Color(1,1,0.96,alpha),angle+side*0.6)
	# Round abdomen, an oversized expressive head and scarf form one original silhouette.
	_oval(p-axis*5*size,Vector2(16,12)*size,Color(0.93,0.66,0.17,alpha),ink,2.5*size,angle)
	_ellipse(p-axis*6*size-cross*3*size,Vector2(12,7)*size,Color(1,0.84,0.30,alpha),angle)
	for stripe in [-12.0,-5.0]:
		_curve(p+axis*stripe*size-cross*10*size,p+axis*(stripe-3)*size-cross*4*size,p+axis*(stripe-3)*size+cross*5*size,p+axis*stripe*size+cross*10*size,ink,3.5*size)
	var head := p+axis*10*size-cross*1*size
	_oval(head,Vector2(12,13)*size,Color(1,0.79,0.28,alpha),ink,2.3*size,angle)
	_ellipse(head-axis*2*size-cross*4*size,Vector2(7,6)*size,Color(1,0.9,0.49,alpha),angle)
	for side in [-1.0,1.0]:
		var eye: Vector2 = head+axis*5*size+cross*side*5.5*size
		_oval(eye,Vector2(5.5,6.6)*size,Color(1,0.99,0.91,alpha),ink,1.4*size,angle)
		draw_circle(eye+axis*1.5*size,2.8*size,ink)
		draw_circle(eye+axis*1.8*size-cross*1.1*size,0.9*size,Color(1,1,1,alpha))
		var tip: Vector2 = head-axis*3*size+cross*side*19*size
		_curve(head-axis*2*size+cross*side*10*size,head-axis*1*size+cross*side*15*size,tip+axis*3*size,tip,ink,1.8*size)
		draw_circle(tip,2.4*size,ink)
	if not trapped:
		_curve(head+axis*10*size+cross*3*size,head+axis*13*size+cross*3*size,head+axis*12*size+cross*7*size,head+axis*8*size+cross*8*size,ink,1.4*size)
	if size >= 0.95:
		var scarf := PackedVector2Array([p-axis*2+cross*10,p-axis*22+cross*(19+sin(clock*8)*2),p-axis*19+cross*10])
		_outline_polygon(scarf,Color("e66e4e"),ink,1.5)
		_oval(p+cross*9,Vector2(6,4),Color("f28c5c"),ink,1.2,angle)

func _effects() -> void:
	for feedback in _feedback:
		var alpha: float = minf(1.0, feedback.life * 2.5)
		var pos: Vector2 = feedback.pos
		if feedback.kind == "blocked":
			for side in [-1.0, 0.0, 1.0]:
				draw_line(pos + Vector2(-9 + side * 9, -20), pos + Vector2(-12 + side * 12, -27), Color(0.95,0.89,0.68,alpha), 2.0, true)
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
	var tint: Color = [Color("254f42"), Color("204f4a"), Color("1e3546")][act]
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
	if points.size() >= 3: draw_colored_polygon(points,tint)

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
