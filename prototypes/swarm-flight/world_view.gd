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

const INK := Color("204d43")
const GOLD := Color("edc16c")
const CREAM := Color("fff0c9")
const SKY := [Color("e9e5cd"), Color("c8dcd2"), Color("809eab")]
const LOW_SKY := [Color("a8c3ad"), Color("8db6ae"), Color("527a88")]

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
	# Three restrained print palettes share the same visual grammar. No raster art.
	for row in 32:
		var t := float(row) / 31.0
		draw_rect(Rect2(0,row*25,1280,26),SKY[act].lerp(LOW_SKY[act],t*0.54))
	var sun := Vector2(1010-fmod(cam*0.025,100.0),181)
	draw_circle(sun,62,Color("f9ecc7") if act < 2 else Color("a6bdbe"))
	if act > 0:
		_paper_shape([sun+Vector2(-100,-42),sun+Vector2(-55,-76),sun+Vector2(0,-33),sun+Vector2(21,-39),sun+Vector2(61,-51),sun+Vector2(84,-12),sun+Vector2(122,-24),sun+Vector2(150,5),sun+Vector2(163,9),sun+Vector2(170,28),sun+Vector2(70,42),sun+Vector2(-36,19),sun+Vector2(-100,-42)],LOW_SKY[act].lightened(0.16))
	# Long quiet cloud shapes and a few thin contour marks make open air intentional.
	for i in 3:
		var x := fposmod(float(i)*530-cam*0.05,1700)-240
		var y := 135.0+i*54
		_curve(Vector2(x,y),Vector2(x+75,y-18),Vector2(x+153,y+5),Vector2(x+235,y-12),Color(0.98,0.97,0.84,0.26),1.2)
	for layer in 3:
		var col: Color = LOW_SKY[act].lerp(INK,0.06+layer*0.08)
		col.a = 0.34+layer*0.12
		var base := 650.0 + layer*52.0
		var points := PackedVector2Array([Vector2(-50,820)])
		for x in range(-50,1351,25):
			var wx := x+cam*(0.05+layer*0.06)
			points.append(Vector2(x,base+sin(wx*0.0035+layer*1.7)*47+sin(wx*0.007+layer)*13))
		points.append(Vector2(1350,820))
		draw_colored_polygon(points,col)
	# Large pale botanical silhouettes read as a distant layer, not solid obstacles.
	for i in 6:
		var x := fposmod(i*287.0-cam*0.17,1700)-180
		var h := 160.0 + (i%3)*52.0
		var root := Vector2(x,800)
		var tip := Vector2(x+sin(i*2.4)*53,800-h)
		var col: Color = LOW_SKY[act].lerp(INK,0.11)
		col.a = 0.36
		_curve(root,root+Vector2(20,-h*0.42),tip+Vector2(-12,40),tip,col,2.4)
		for j in 3:
			var joint := root.lerp(tip,0.22+j*0.22)
			var side := -1.0 if j%2 else 1.0
			_leaf(joint,joint+Vector2(side*(50-j*8),-36),15-j*2,col)
	for i in 12:
		var x := fposmod(i*137.0+clock*(7.0+act*8)-cam*0.09,1400)-60
		var y := fposmod(i*173.0,570)+130
		draw_circle(Vector2(x,y+sin(clock*0.4+i)*8),1.15,Color(0.99,0.95,0.75,0.23))

func _world_decor(act: int, cam: float) -> void:
	# Decorative foreground stays beneath the collision-safe flight floor.
	var start := int(floor((cam-160)/210.0))
	for i in range(start,start+9):
		var x := i*210.0+sin(i*2.7)*27
		var tint: Color = [Color("648875"),Color("497a72"),Color("365d67")][act]
		var root := Vector2(x,817)
		_leaf(root,root+Vector2(-67,-69),20,tint)
		_leaf(root+Vector2(4,0),root+Vector2(39,-83),16,tint.lightened(0.08))
		if i%3 == 0:
			_curve(root,root+Vector2(37,-24),root+Vector2(64,-65),root+Vector2(84,-68),tint,2.0)
			for j in 4:
				_leaf(root+Vector2(27+j*13,-24-j*11),root+Vector2(24+j*15,-53-j*7),6,tint.lightened(0.12))

func _wall(wall: Dictionary) -> void:
	var r: Rect2 = wall.rect
	if r.end.x < model.camera_x-80 or r.position.x > model.camera_x+1360: return
	if wall.kind == "curtain":
		if wall.broken:
			_curve(r.position,r.position+Vector2(14,8),r.position+Vector2(29,-3),r.position+Vector2(r.size.x,2),Color("aa8f5b"),2.2)
			for i in 3:
				var p := r.position+Vector2(7+i*12,0)
				_leaf(p,p+Vector2(9,22-i*3),6,Color("c2ab75"))
			return
		# A folded paper-thin leaf curtain: continuous face, tear seam, no stem pattern.
		draw_rect(r,Color("ad8e56"))
		for i in range(int(r.size.y/58.0)+1):
			var y := r.position.y+i*58.0
			var h := minf(66,r.end.y-y)
			if h <= 0: continue
			_leaf(Vector2(r.position.x+1,y),Vector2(r.end.x-1,y+h),14,Color("d2b777"))
			_leaf(Vector2(r.end.x-1,y),Vector2(r.position.x+1,y+h),11,Color("bda16b"))
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
	draw_colored_polygon(outline,Color("285044"))
	# The curled bud closes into a pointed, curved end instead of a flat crosscut.
	_paper_shape([Vector2(x+3,root_y),Vector2(x+w*0.85,root_y+(gap_y-root_y)*0.25),Vector2(x+4,root_y+(gap_y-root_y)*0.67),tip+Vector2(0,direction*3),Vector2(x+w-6,gap_y+direction*30),Vector2(x+w-3,root_y+(gap_y-root_y)*0.46),Vector2(x+w-3,root_y)],Color("52745a"))
	_curve(Vector2(center,root_y),Vector2(x+8,root_y+(gap_y-root_y)*0.35),Vector2(x+w-7,root_y+(gap_y-root_y)*0.7),tip+Vector2(0,direction*2),Color("9bad7a"),1.5)
	for i in 3:
		var base := Vector2(center+(i-1)*w*0.24,gap_y+direction*(62+i*8))
		_leaf(base,tip+Vector2((i-1)*3,direction*6),w*0.12,Color("6e8d65") if i%2 else Color("8da474"))
	for i in range(1,4):
		var y := lerpf(root_y,gap_y,float(i)/4.0)
		var flip := -1.0 if i%2 else 1.0
		_curve(Vector2(center,y),Vector2(center+flip*7,y+direction*12),Vector2(center+flip*(w*0.35),y+direction*23),Vector2(center+flip*(w*0.43),y+direction*31),Color("73916b"),1.0)
	if not upper and r.end.y >= 725:
		_leaf(Vector2(center,817),Vector2(x-65,739),24,Color("345e4c"))
		_leaf(Vector2(center+2,820),Vector2(x+w+55,745),22,Color("5d7e5b"))

func _pod(pod: Dictionary) -> void:
	var p: Vector2 = pod.pos
	if p.x < model.camera_x-100 or p.x > model.camera_x+1380: return
	_curve(p+Vector2(2,39),p+Vector2(21,79),p+Vector2(-21,115),p+Vector2(-9,170),Color("6d8c6c"),2.4)
	if pod.open:
		_leaf(p+Vector2(0,33),p+Vector2(-47,-1),17,Color("bc9c60"))
		_leaf(p+Vector2(1,34),p+Vector2(48,-10),18,Color("dbc17d"))
		_curve(p+Vector2(-36,4),p+Vector2(-24,25),p+Vector2(25,37),p+Vector2(40,0),Color("92764d"),1.5)
		return
	# Asymmetric folded leaf; the curved slit exposes a moving friend.
	_paper_shape([p+Vector2(1,-49),p+Vector2(-45,-29),p+Vector2(-43,21),p+Vector2(-19,38),p+Vector2(0,52),p+Vector2(33,28),p+Vector2(33,8),p+Vector2(43,-19),p+Vector2(17,-39),p+Vector2(1,-49)],Color("9e7d48"))
	_paper_shape([p+Vector2(1,-46),p+Vector2(-36,-23),p+Vector2(-36,21),p+Vector2(-8,41),p+Vector2(-14,6),p+Vector2(10,-14),p+Vector2(1,-46)],Color("e4c47b"))
	_paper_shape([p+Vector2(4,-44),p+Vector2(31,-24),p+Vector2(35,13),p+Vector2(9,40),p+Vector2(14,6),p+Vector2(1,-18),p+Vector2(4,-44)],Color("bd9759"))
	_curve(p+Vector2(0,-39),p+Vector2(-19,-3),p+Vector2(11,10),p+Vector2(-2,36),CREAM,1.7)
	for i in 3:
		var y := -18+i*15.0
		_curve(p+Vector2(-11,y),p+Vector2(-16,y-1),p+Vector2(-23,y-7),p+Vector2(-25,y-10),Color("f4dda4"),1.0)
	_bee(p+Vector2(0,5),0.68,Vector2.RIGHT,1.0,true,0.0)

func _ring(ring: Dictionary, index: int) -> void:
	var p: Vector2 = ring.pos
	if p.x < model.camera_x-200 or p.x > model.camera_x+1400: return
	var used: bool = ring.active
	var direction: Vector2 = model.ring_direction(index)
	var side := direction.orthogonal()
	_curve(p+Vector2(0,45),p+Vector2(-20,165),p+Vector2(38,228),Vector2(p.x-26,831),Color("4f7d6b"),4.2)
	_leaf(p+Vector2(0,101),p+Vector2(-72,63),20,Color("86a58a"))
	if used:
		for i in 5:
			var a := float(i)*TAU/5.0-PI/2
			_leaf(p+Vector2.from_angle(a)*34,p+Vector2(0,18),10,Color("6f9685") if i%2 else Color("91af96"))
		_leaf(p+Vector2(0,24),p+Vector2(-4,-15),11,Color("527e6b"))
		return
	for i in 7:
		var a := float(i)*TAU/7.0-PI/2+sin(clock*0.8)*0.018
		var axis := Vector2.from_angle(a)
		_leaf(p+axis*32,p+axis*(64+sin(clock*1.1+i)*1.2),13,Color("5c9b8e"))
		_leaf(p+axis*35,p+axis*61,8,Color("c4d8b5"))
	draw_arc(p,36,0,TAU,64,Color("326e61"),4.2,true)
	draw_arc(p,35,0,TAU,64,Color("dce6be"),1.4,true)
	var arrow := p+direction*sin(clock*2.0)*2
	draw_polyline(PackedVector2Array([arrow-direction*9-side*10,arrow+direction*5,arrow-direction*9+side*10]),CREAM,2.7,true)
	for i in 3:
		var along := 59.0+fposmod(clock*26.0+i*22,66)
		draw_line(p+direction*along,p+direction*(along+10),Color(0.83,0.94,0.83,(1-(along-59)/85)*0.48),1.4,true)

func _shelter(shelter: Dictionary) -> void:
	var p: Vector2 = shelter.pos
	var reached: bool = shelter.reached
	_curve(p+Vector2(120,-80),p+Vector2(137,8),p+Vector2(97,130),Vector2(p.x+86,828),Color("446e5b"),5.5)
	# Canopy underside stays above the entire rectangular safe pocket.
	_paper_shape([p+Vector2(-130,-80),p+Vector2(-59,-151),p+Vector2(68,-146),p+Vector2(127,-78),p+Vector2(63,-65),p+Vector2(-45,-66),p+Vector2(-130,-80)],Color("315c4c"))
	_paper_shape([p+Vector2(-126,-82),p+Vector2(-51,-143),p+Vector2(63,-140),p+Vector2(121,-82),p+Vector2(58,-96),p+Vector2(-38,-98),p+Vector2(-126,-82)],Color("82a178"))
	_curve(p+Vector2(-125,-81),p+Vector2(-47,-112),p+Vector2(54,-112),p+Vector2(123,-80),Color("d1d9a0"),1.5)
	for i in 6:
		var x := -84+i*32.0
		var lift := sin(float(i+1)*PI/7)*24
		_curve(p+Vector2(x,-100),p+Vector2(x+1,-103),p+Vector2(x+8,-109-lift),p+Vector2(x+17,-112-lift),Color("b5c58f"),1.0)
	_curve(p+Vector2(-3,-91),p+Vector2(-5,-73),p+Vector2(-3,-62),p+Vector2(-7,-50),Color("b5be8c"),1.3)
	_leaf(p+Vector2(-7,-53),p+Vector2(-7,-28),8,Color("d5b46d"))
	_leaf(p+Vector2(-7,-50),p+Vector2(-7,-31),4,CREAM if reached else Color("e0cf98"))
	_leaf(p+Vector2(-55,48),p+Vector2(55,44),15,Color("64886a"))
	_leaf(p+Vector2(-48,47),p+Vector2(48,44),7,Color("a6bc88"))
	if reached:
		draw_polyline(PackedVector2Array([p+Vector2(-6,40),p+Vector2(-1,45),p+Vector2(8,35)]),GOLD,1.8,true)

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
	_paper_shape([p+Vector2(-126,-510),p+Vector2(-61,-270),p+Vector2(-136,-33),p+Vector2(-110,171),p+Vector2(-103,278),p+Vector2(-170,351),p+Vector2(-225,397),p+Vector2(-32,356),p+Vector2(119,386),p+Vector2(226,398),p+Vector2(149,245),p+Vector2(167,41),p+Vector2(145,-141),p+Vector2(135,-270),p+Vector2(189,-406),p+Vector2(182,-510)],Color("254b43"))
	_paper_shape([p+Vector2(-77,-510),p+Vector2(-22,-237),p+Vector2(-99,-41),p+Vector2(-72,186),p+Vector2(-54,273),p+Vector2(-95,348),p+Vector2(-119,379),p+Vector2(17,351),p+Vector2(90,370),p+Vector2(139,385),p+Vector2(100,211),p+Vector2(119,19),p+Vector2(104,-133),p+Vector2(93,-300),p+Vector2(142,-443),p+Vector2(131,-510)],Color("3e6855"))
	for i in 3:
		var x := p.x-75+i*76.0
		_curve(Vector2(x,-50),Vector2(x+27,170),Vector2(x-24,460),Vector2(x+8,799),Color("68876a"),1.5)
	var hollow := [p+Vector2(0,-130),p+Vector2(-95,-83),p+Vector2(-109,45),p+Vector2(-68,115),p+Vector2(-35,145),p+Vector2(48,143),p+Vector2(78,108),p+Vector2(107,24),p+Vector2(79,-86),p+Vector2(0,-130)]
	_paper_shape(hollow,Color("173e36"))
	_paper_shape([p+Vector2(0,-111),p+Vector2(-76,-69),p+Vector2(-86,43),p+Vector2(-56,101),p+Vector2(-24,126),p+Vector2(42,124),p+Vector2(62,95),p+Vector2(86,28),p+Vector2(64,-72),p+Vector2(0,-111)],Color("cfb877"))
	_paper_shape([p+Vector2(10,-82),p+Vector2(-41,-33),p+Vector2(-48,53),p+Vector2(-28,103),p+Vector2(-4,118),p+Vector2(40,111),p+Vector2(55,89),p+Vector2(72,39),p+Vector2(58,-39),p+Vector2(10,-82)],Color("f0d592"))
	for i in 5:
		_leaf(p+Vector2(-58+i*24,117),p+Vector2(-35+i*20,87),12,Color("b0bd88") if i%2 else Color("829b71"))
	_leaf(p+Vector2(-84,120),p+Vector2(88,115),17,Color("698c69"))
	_leaf(p+Vector2(-76,119),p+Vector2(81,117),8,Color("b9c792"))
	_leaf(p+Vector2(-115,-161),p+Vector2(-199,-228),25,Color("406e58"))
	_leaf(p+Vector2(150,-177),p+Vector2(237,-235),27,Color("628468"))

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
	var angle := face.angle()
	var wing := 0.55 + absf(sin(clock * 35.0 + seed_value)) * 0.60
	if model != null and model.phase == "ending":
		wing *= 0.28 + 0.72 * exp(-_ending_elapsed * 2.0)
	var axis := face
	var cross := axis.orthogonal()
	var ink := Color(0.19, 0.25, 0.20, alpha)
	for side in [-1.0, 1.0]:
		var center: Vector2 = p + cross * side * 8.4 * size - axis * 3.0 * size
		var rot: float = angle + side * 0.65
		_ellipse(center, Vector2(10, 6.6 * wing) * size, Color(0.29, 0.45, 0.37, alpha * 0.7), rot)
		_ellipse(center - cross * side * 0.5 * size, Vector2(9, 5.4 * wing) * size, Color(0.98, 0.99, 0.87, alpha * 0.92), rot)
		draw_line(center - axis * 4 * size, center + axis * 5 * size + cross * side * wing * size, Color(0.69,0.79,0.65,alpha*0.8), 0.8 * size, true)
	_ellipse(p + cross * 1.0 * size, Vector2(14.4, 10.4) * size, ink, angle)
	_ellipse(p, Vector2(12.9, 8.9) * size, Color(0.83, 0.56, 0.20, alpha), angle)
	_ellipse(p - cross * 1.7 * size, Vector2(12.0, 7.0) * size, Color(1.0, 0.80, 0.35, alpha), angle)
	for stripe in [-6.0, 0.0]:
		_curve(p + axis * stripe * size - cross * 7.6 * size, p + axis * (stripe-1.5) * size - cross * 3 * size, p + axis * (stripe-1.5) * size + cross * 3 * size, p + axis * stripe * size + cross * 7.6 * size, Color(0.29,0.30,0.20,alpha), 3.3*size)
	_ellipse(p + axis * 6.8 * size - cross * 1.4 * size, Vector2(5.8, 6.6) * size, Color(1.0,0.84,0.43,alpha), angle)
	var eye := p + axis * 8.4 * size - cross * 3.2 * size
	draw_circle(eye, 2.3 * size, ink)
	draw_circle(eye - axis * 0.4 * size - cross * 0.65 * size, 0.85 * size, Color(1,1,0.9,alpha))
	draw_circle(p + axis * 9.2 * size + cross * 2.4 * size, 1.7*size, Color(0.94,0.56,0.33,alpha*0.65))
	if not trapped:
		for side in [-1.0, 1.0]:
			var tip: Vector2 = p + axis * 12 * size + cross * side * 12 * size
			_curve(p+axis*8*size+cross*side*6*size,p+axis*10*size+cross*side*10*size,tip-axis*2*size,tip,ink,1.2*size)
			draw_circle(tip, 1.3*size, ink)
	if size >= 0.95:
		var scarf := PackedVector2Array([p-axis*3+cross*7,p-axis*18+cross*(12+sin(clock*8)*2),p-axis*14+cross*5])
		draw_colored_polygon(scarf, Color("fff0bc"))
		draw_line(p-axis*5+cross*7,p-axis*15+cross*8,Color("cfac64"),1.0,true)

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
		_ellipse(p + Vector2.from_angle(a) * radius * 0.52, Vector2(radius * 0.67, radius * 0.38), tint, a)
	draw_circle(p, radius * 0.23, tint.darkened(0.18))

func _ellipse(center: Vector2, radius: Vector2, tint: Color, angle := 0.0) -> void:
	var points := PackedVector2Array()
	for i in 24:
		var theta := i * TAU / 24.0
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
