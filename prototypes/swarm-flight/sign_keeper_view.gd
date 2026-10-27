extends "res://world_view.gd"
## D representative encounter: actors, loose rope and the retained open passage
## are painted from model state. No health bar, reward number or extra actors.
const KEEPER_ATLAS: Texture2D = preload("res://art/sign-keeper.png")
const FRAME := Vector2(256,192)

func _landmarks(_act: int) -> void:
	var home: Vector2 = model.SMALL_HOME
	if home.x > model.camera_x-200 and home.x < model.camera_x+1480:
		# The ordinary mosquito has a specific flower place to return to.
		var flower := home+Vector2(-14,62)
		ArtProps.stalk(self,flower,flower+Vector2(15,110),Vector2(home.x-39,720),Vector2(home.x+10,835),9.0)
		ArtSprites.small_leaf(self,home+Vector2(3,145),home+Vector2(-112,121),29)
		ArtSprites.small_leaf(self,home+Vector2(0,217),home+Vector2(115,175),31)
		draw_set_transform(_world_offset+flower,0.0,Vector2(1.8,1.8))
		ArtProps.decor(self,Vector2.ZERO,"flower")
		draw_set_transform(_world_offset)
		_ellipse(Vector2(home.x+20,791),Vector2(70,9),Color("5d979b7a"))
		_curve(Vector2(home.x-33,790),Vector2(home.x-10,786),Vector2(home.x+30,794),Vector2(home.x+69,789),Color("e4ecd6b0"),1.3)
	# The displaced signs settle beside the route, on a planted stand.
	if model.passage_open:
		var side: Vector2 = model.RESULT_HOME+Vector2(-70,35)
		var visible: float = model.result_progress()
		if visible > 0.4:
			ArtProps.stalk(self,side+Vector2(0,-43),side+Vector2(-4,4),side+Vector2(7,99),Vector2(side.x-3,833),8.0)
			ArtSprites.small_leaf(self,side+Vector2(10,68),side+Vector2(-73,61),19)

func _neighbors() -> void:
	_mosquito(model.small,false)
	_mosquito(model.keeper,true)

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
	elif actor.state == "counting":
		pose = sin(actor.elapsed*5.0)*0.055
	elif actor.state == "aim":
		pose = -0.075
	var mirror := -1.0 if actor.face.x < 0.0 else 1.0
	var pitch := atan2(actor.face.y,absf(actor.face.x))*mirror*0.2
	var flutter := sin(actor.elapsed*28.0)*0.015 if actor.state in ["chase","return"] else 0.0
	draw_set_transform(_world_offset+p,pitch+pose,Vector2(mirror,1.0+flutter))
	draw_texture_rect_region(KEEPER_ATLAS,Rect2(-size*0.5,size),Rect2(Vector2(frame*FRAME.x,0),FRAME))
	draw_set_transform(_world_offset)
	if keeper and actor.state=="counting":
		for i in 3:
			var point := p+Vector2(-38+i*35,63)
			_curve(p+Vector2(12,20),p+Vector2(4,33),point+Vector2(0,-24),point+Vector2(0,-12),INK,1.7)
			_flower_sign(point,0.04*float(i-1),i%2)
		var chosen := int(actor.elapsed/0.48)%3
		_curve(p+Vector2(27,18),p+Vector2(30,31),p+Vector2(-38+chosen*35,43),p+Vector2(-38+chosen*35,55),INK,2.2)

func _wall(wall: Dictionary) -> void:
	var rect: Rect2 = wall.rect
	if wall.kind == "curtain" and absf(rect.position.x-2350.0) < 0.1:
		_sign_rope(rect)
	else:
		super._wall(wall)

func _sign_rope(rect: Rect2) -> void:
	var knot: Vector2 = model.KNOT
	if knot.x < model.camera_x-250 or knot.x > model.camera_x+1530: return
	var top := Vector2(knot.x,rect.position.y)
	var bottom := Vector2(knot.x,rect.end.y)
	var open: bool = model.passage_open
	var slack: bool = model.keeper.state == "counting"
	var rope := Color("816338")
	var lit := Color("d7bd77")
	if not open:
		var bow := 20.0 if slack else 1.0
		_curve(top,top+Vector2(bow,27),knot+Vector2(bow,-18),knot,rope,4.8)
		_curve(knot,knot+Vector2(-bow,18),bottom+Vector2(-bow,-27),bottom,rope,4.8)
		_curve(top,top+Vector2(bow-1,27),knot+Vector2(bow-1,-18),knot,lit,1.7)
		_curve(knot,knot+Vector2(-bow-1,18),bottom+Vector2(-bow-1,-27),bottom,lit,1.7)
		_flower_sign(knot+Vector2(0,-45),-0.05 if slack else 0.02,0)
		_flower_sign(knot+Vector2(0,45),0.08 if slack else -0.02,1)
		_dry_leaf_knot(knot,slack)
	else:
		var progress: float = model.result_progress()
		_curve(top,top+Vector2(13,6),top+Vector2(-6,21),top+Vector2(9,27),rope,3.5)
		_curve(bottom,bottom+Vector2(-15,-7),bottom+Vector2(7,-20),bottom+Vector2(-7,-25),rope,3.5)
		var side: Vector2 = model.RESULT_HOME+Vector2(-70,35)
		var eased := 1.0-pow(1.0-progress,3.0)
		var corner := Vector2(2470,knot.y)
		var point := knot.lerp(corner,minf(1.0,eased*2.0)) if eased<0.5 else corner.lerp(side,(eased-0.5)*2.0)
		var sway := sin(progress*PI)*0.16
		_flower_sign(point+Vector2(0,-33),-0.04+sway,0)
		_flower_sign(point+Vector2(0,13),0.05-sway,1)
		# Short broken ends stay at the anchors; nothing still spans the passage.

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

func neighbor_words() -> String:
	return ""

func _waiting_friends() -> void:
	pass

func _shelter(shelter: Dictionary) -> void:
	var point: Vector2 = shelter.pos
	var half: float = shelter.half_width
	ArtProps.stalk(self,point+Vector2(half+4,-80),point+Vector2(half+17,8),point+Vector2(half-23,130),Vector2(point.x+half-34,828),12.0)
	ArtSprites.canopy(self,point,half)
	ArtSprites.small_leaf(self,point+Vector2(60,57),point+Vector2(-60,57),29)
	draw_line(point+Vector2(-7,-91),point+Vector2(-7,-55),INK,2,true)
	ArtProps.decor(self,point+Vector2(-7,-40),"shelter_lamp_lit" if shelter.reached else "shelter_lamp")

func _terrain(item: Dictionary) -> void:
	var rect: Rect2 = item.rect
	# Upright plant supports use the existing painted shaft, never stretch a
	# whole flower hedge into a narrow vertical strip.
	ArtProps.stem(self,rect,rect.position.y<100)
	if rect.end.y>700:
		ArtProps.stalk(self,Vector2(rect.get_center().x,rect.end.y),Vector2(rect.get_center().x+4,780),Vector2(rect.get_center().x-5,810),Vector2(rect.get_center().x+10,834),rect.size.x*0.7)
	elif rect.position.x<1000:
		ArtProps.stalk(self,Vector2(rect.get_center().x,rect.end.y),Vector2(rect.get_center().x+15,660),Vector2(rect.get_center().x-12,770),Vector2(rect.get_center().x+10,834),rect.size.x*0.4)
