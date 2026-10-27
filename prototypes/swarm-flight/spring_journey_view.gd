extends "res://bee_dance_view.gd"
## Presentation adapter for the three-stage pond/rain/return integration.
## All timings and facts belong to SpringModel; this painter never commits them.
const KEEPER_ATLAS: Texture2D = preload("res://art/sign-keeper.png")
const ColorMemory = preload("res://color_memory.gd")
const FRAME := Vector2(256,192)

func _landmarks(_act: int) -> void:
	if model.stage in [0,2]:
		_source_cluster(model.SOURCE)
		_pond_landmarks()
		_wax_window_landmark()
		if model.stage == 0: _small_flower()
		if model.stage == 2:
			_wax_comb(model.COMB)
			if model.front_open:
				_sign_support(Vector2(model.KNOT.x+84,660))
			if model.passage_open:
				_sign_support(model.RESULT_HOME+Vector2(-70,35))
	elif model.stage == 1:
		var window_center: Vector2=model.shelters[0].pos+Vector2(105,82)
		_curve(model.shelters[0].pos+Vector2(108,-90),window_center+Vector2(20,-75),window_center+Vector2(4,-55),window_center+Vector2(0,-45),INK,1.7)
		ColorMemory.draw_window(self,window_center,float(model.color_step),0.44,3)
		# The weather changes the route; only a small reflected trace takes color.
		var tint := ColorMemory.color_at(3+model.color_step)
		tint.a = 0.25
		for shelter in model.shelters:
			var x: float = shelter.pos.x
			for i in 3:
				_curve(Vector2(x-38,768+i*5),Vector2(x-12,762+i*5),Vector2(x+20,775+i*5),Vector2(x+50,769+i*5),tint,1.8)

func _pond_landmarks() -> void:
	# These coordinates and silhouettes are identical on the first and return visit.
	var s: Vector2 = model.SOURCE
	_ellipse(Vector2(s.x+30,787),Vector2(196,15),Color("6dabb488"))
	for i in 4:
		_curve(Vector2(s.x-130+i*8,781+i*6),Vector2(s.x-52,775+i*6),Vector2(s.x+73,790+i*6),Vector2(s.x+170-i*10,780+i*6),Color("dbeed18e"),1.8)
	for i in 3:
		var root := Vector2(s.x-185+i*13,831)
		_curve(root,root+Vector2(-6,-37),root+Vector2(4,-63),root+Vector2(-14,-100+i*9),Color("527945"),3.2)
		ArtSprites.small_leaf(self,root+Vector2(-2,-28),root+Vector2(33,-66),8)
	var perch := s+Vector2(195,-121)
	ArtProps.stalk(self,perch+Vector2(-47,22),perch+Vector2(30,16),Vector2(perch.x+57,622),Vector2(perch.x+27,833),7.0)
	ArtProps.stalk(self,perch+Vector2(-47,22),perch+Vector2(-23,5),perch+Vector2(10,12),perch+Vector2(43,25),6.0)
	ArtSprites.small_leaf(self,perch+Vector2(27,20),perch+Vector2(84,3),16)
	if model.stage == 0: _bird(perch)
	if model.stage == 2:
		for i in 3: _ellipse(perch+Vector2(-27+i*24,20),Vector2(3,1.4),Color("d2e5ce"))

func _small_flower() -> void:
	var home: Vector2 = model.SMALL_HOME
	var flower := home+Vector2(-14,62)
	ArtProps.stalk(self,flower,flower+Vector2(15,110),Vector2(home.x-39,720),Vector2(home.x+10,835),9.0)
	ArtSprites.small_leaf(self,home+Vector2(3,145),home+Vector2(-112,121),29)
	draw_set_transform(_world_offset+flower,0.0,Vector2(1.8,1.8))
	ArtProps.decor(self,Vector2.ZERO,"flower")
	draw_set_transform(_world_offset)
	_ellipse(Vector2(home.x+20,791),Vector2(70,9),Color("5d979b7a"))

func _wax_window_landmark() -> void:
	# Kept beside the landing leaf, with a real branch attachment and local light.
	var center: Vector2 = model.COMB+Vector2(110,-157)
	ArtProps.stalk(self,center+Vector2(4,-70),center+Vector2(80,-105),center+Vector2(78,52),Vector2(center.x+82,833),7.0)
	_curve(center+Vector2(4,-70),center+Vector2(2,-57),center+Vector2(1,-51),center+Vector2(0,-45),INK,1.8)
	ColorMemory.draw_window(self,center,float(model.color_step),0.44,3)

func _neighbors() -> void:
	if model.stage == 0:
		_mosquito(model.small,false)
	elif model.stage == 2:
		_mosquito(model.keeper,true)
		super._neighbors()

func _wall(wall: Dictionary) -> void:
	var r: Rect2 = wall.rect
	if model.stage == 2 and wall.kind == "curtain" and absf(r.position.x-2350.0)<0.1:
		_sign_rope(r,model.KNOT,model.front_open,false)
	elif model.stage == 2 and wall.kind == "curtain" and absf(r.position.x-3000.0)<0.1:
		_sign_rope(r,model.BACK_KNOT,model.passage_open,true)
	else:
		super._wall(wall)

func _sign_support(point: Vector2) -> void:
	ArtProps.stalk(self,point+Vector2(0,-43),point+Vector2(-4,4),point+Vector2(7,99),Vector2(point.x-3,833),8.0)
	ArtSprites.small_leaf(self,point+Vector2(10,68),point+Vector2(-73,61),19)

func _sign_rope(rect: Rect2,knot: Vector2,opened: bool,back: bool) -> void:
	if knot.x < model.camera_x-250 or knot.x > model.camera_x+1530: return
	var top := Vector2(knot.x,rect.position.y)
	var bottom := Vector2(knot.x,rect.end.y)
	var slack: bool = model.front_open if back else model.keeper.state == "counting"
	var rope := Color("816338")
	var lit := Color("d7bd77")
	if not opened:
		var bow := 20.0 if slack else 1.0
		_curve(top,top+Vector2(bow,27),knot+Vector2(bow,-18),knot,rope,4.8)
		_curve(knot,knot+Vector2(-bow,18),bottom+Vector2(-bow,-27),bottom,rope,4.8)
		_curve(top,top+Vector2(bow-1,27),knot+Vector2(bow-1,-18),knot,lit,1.7)
		_curve(knot,knot+Vector2(-bow-1,18),bottom+Vector2(-bow-1,-27),bottom,lit,1.7)
		_flower_sign(knot+Vector2(0,-45),-0.05 if slack else 0.02,0)
		_flower_sign(knot+Vector2(0,45),0.08 if slack else -0.02,1)
		_dry_leaf_knot(knot,slack)
	else:
		_curve(top,top+Vector2(13,6),top+Vector2(-6,21),top+Vector2(9,27),rope,3.5)
		_curve(bottom,bottom+Vector2(-15,-7),bottom+Vector2(7,-20),bottom+Vector2(-7,-25),rope,3.5)
		var point: Vector2
		var sway := 0.0
		if back:
			var progress: float = model.result_progress()
			var eased := 1.0-pow(1.0-progress,3.0)
			var side: Vector2 = model.RESULT_HOME+Vector2(-70,35)
			var corner := Vector2(side.x,knot.y)
			point = knot.lerp(corner,minf(1.0,eased*2.0)) if eased<0.5 else corner.lerp(side,(eased-0.5)*2.0)
			sway = sin(progress*PI)*0.16
		else:
			# No final-result timer belongs to this earlier, independently committed gate.
			# Its short signs stay on the first post instead of flying through the second wall.
			point = Vector2(knot.x+84,660)
		_flower_sign(point+Vector2(0,-33),-0.04+sway,0)
		_flower_sign(point+Vector2(0,13),0.05-sway,1)

func _terrain(item: Dictionary) -> void:
	var rect: Rect2 = item.rect
	if item.get("material", "hedge") == "stem":
		ArtProps.stem(self,rect,rect.position.y<100)
		if rect.end.y>700:
			ArtProps.stalk(self,Vector2(rect.get_center().x,rect.end.y),Vector2(rect.get_center().x+4,780),Vector2(rect.get_center().x-5,810),Vector2(rect.get_center().x+10,834),rect.size.x*0.7)
		elif rect.position.y>100:
			ArtProps.stalk(self,Vector2(rect.get_center().x,rect.end.y),Vector2(rect.get_center().x+15,660),Vector2(rect.get_center().x-12,770),Vector2(rect.get_center().x+10,834),rect.size.x*0.4)
	else:
		super._terrain(item)
		if model.stage == 1:
			for x in [rect.position.x+25.0,rect.end.x-25.0]:
				ArtProps.stalk(self,Vector2(x,rect.end.y),Vector2(x+12,530),Vector2(x-7,680),Vector2(x+18,828),9.0)

func neighbor_words() -> String: return ""
func _waiting_friends() -> void: pass

func _mosquito(actor: Dictionary, keeper: bool) -> void:
	var p: Vector2 = actor.pos
	if p.x < model.camera_x-180 or p.x > model.camera_x+1460: return
	var frame := 0 if keeper else 1
	var pose := 0.0
	var size := Vector2(144,108) if keeper else Vector2(79,59.25)
	if keeper and actor.state in ["tidy","settled"]:
		var progress: float = model.result_progress()
		frame = 2 if progress > 0.46 or actor.state == "settled" else 0
		# It checks and straightens its own back sign; the body has a single
		# brief lean, rather than a celebration or a mandatory cutscene.
		pose = sin(progress*PI)*0.11 if actor.state == "tidy" else 0.0
	elif actor.state in ["counting","watch"]:
		pose = sin(actor.elapsed*5.0)*0.055
	elif actor.state == "aim":
		pose = -0.075
	var mirror := -1.0 if actor.face.x < 0.0 else 1.0
	var pitch := atan2(actor.face.y,absf(actor.face.x))*mirror*0.2
	var flutter := sin(actor.elapsed*28.0)*0.015 if actor.state in ["chase","return"] else 0.0
	draw_set_transform(_world_offset+p,pitch+pose,Vector2(mirror,1.0+flutter))
	draw_texture_rect_region(KEEPER_ATLAS,Rect2(-size*0.5,size),Rect2(Vector2(frame*FRAME.x,0),FRAME))
	draw_set_transform(_world_offset)
	if keeper and actor.state in ["counting","watch"]:
		for i in 3:
			var point := p+Vector2(-38+i*35,63)
			_curve(p+Vector2(12,20),p+Vector2(4,33),point+Vector2(0,-24),point+Vector2(0,-12),INK,1.7)
			_flower_sign(point,0.04*float(i-1),i%2)
		var chosen := int(actor.elapsed/0.48)%3
		_curve(p+Vector2(27,18),p+Vector2(30,31),p+Vector2(-38+chosen*35,43),p+Vector2(-38+chosen*35,55),INK,2.2)


func _flower_sign(point: Vector2, angle: float, variant: int) -> void:
	draw_set_transform(_world_offset+point,angle,Vector2(0.68,0.85))
	ArtProps.decor(self,Vector2.ZERO,"sign")
	# A painted flower, not text, names the keeper's little plots.
	draw_set_transform(_world_offset+point,angle,Vector2(0.48,0.48))
	ArtProps.decor(self,Vector2(-17 if variant else 0,-1),"flower")
	if variant:
		ArtProps.decor(self,Vector2(18,2),"flower")
	draw_set_transform(_world_offset)


func _dry_leaf_knot(point: Vector2, loose: bool) -> void:
	var spread := 20.0 if loose else 13.0
	var leaf := Color("c69e54")
	var edge := Color("73532c")
	_silhouette([point,point+Vector2(-spread,-20),point+Vector2(-spread-9,-17),point+Vector2(-spread-7,-5),point+Vector2(-spread-4,7),point+Vector2(-5,9),point],leaf,edge,2.0)
	_silhouette([point,point+Vector2(spread,-18),point+Vector2(spread+10,-15),point+Vector2(spread+7,-3),point+Vector2(spread+4,8),point+Vector2(5,8),point],leaf.lightened(0.1),edge,2.0)
	_curve(point+Vector2(-spread,-11),point+Vector2(-11,-5),point+Vector2(-8,3),point+Vector2(0,5),Color("efd69a"),1.1)
	_curve(point+Vector2(spread,-9),point+Vector2(12,-4),point+Vector2(8,2),point+Vector2(0,5),Color("f5dc9d"),1.1)
	_oval(point+Vector2(0,3),Vector2(7,10),Color("c6a55c"),edge,2.0,-0.2)
	_curve(point+Vector2(0,12),point+Vector2(-3,19),point+Vector2(-13,25),point+Vector2(-12,30),edge,2.5)
	_curve(point+Vector2(3,12),point+Vector2(8,20),point+Vector2(12,22),point+Vector2(18,23),edge,2.5)


func _rain_field(field: Dictionary) -> void:
	if model.stage != 1 or model.weather_phase == "dry" or model.weather_phase == "after": return
	var area: Rect2 = field.rect
	# Clouds belong to this authored span, not a screen tint. Rain streaks use
	# the same roof/leaf coordinates as physical drops and stop on their tops.
	for i in 12:
		var x := area.position.x+float(i)*200.0
		if x < model.camera_x-160 or x > model.camera_x+1440: continue
		ArtProps.cloud(self,Rect2(x-110,145+sin(float(i)*1.7)*7,240,70),Color("8aa0a5"))
	var count := 54 if model.weather_phase == "rain" else 12
	for i in count:
		var x := area.position.x+fposmod(float(i)*47.31,area.size.x)
		if x < model.camera_x-20 or x > model.camera_x+1300: continue
		var bottom: float = model.rain_floor_at(x)
		var span := maxf(1.0,bottom-195.0)
		var y := 195.0+fposmod(float(i)*81.7+clock*220.0,span)
		var end_y := minf(y+13.0,bottom)
		draw_line(Vector2(x,y),Vector2(x-1.0,end_y),Color(0.54,0.75,0.80,0.58 if model.weather_phase == "rain" else 0.3),2.0,true)
	# A few droplets gather on the roof during the warning; they do not hurt.
	for roof in model.walls:
		var rect: Rect2 = roof.rect
		if rect.size.x < rect.size.y: continue
		for i in 6:
			var x: float = rect.position.x+70.0+float(i)*(rect.size.x-100.0)/6.0
			_ellipse(Vector2(x,rect.position.y-3),Vector2(4.5,1.8),Color("d4edf0"))
