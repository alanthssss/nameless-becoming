extends RefCounted
## Presentation-only atlas adapters. World anchors and all rules stay in the model.
const ATLAS: Texture2D = preload("res://art/revision-atlas.png")
# Regions exclude the atlas's near-transparent outer specks, without changing it.
const BEE := Rect2(67,158,510,456)
const FLOWER := Rect2(638,100,571,596)
const LEAF := Rect2(19,822,592,251)
const HEDGE := Rect2(634,790,605,322)
const BEE_PIVOT := Vector2(316,468)
const FLOWER_PIVOT := Vector2(918,420)

static func bee_body(v: Node2D, alpha: float, eyes_closed: bool, charge: float) -> void:
	var scale := 60.0/BEE.size.x
	v.draw_texture_rect_region(ATLAS,Rect2((BEE.position-BEE_PIVOT)*scale,BEE.size*scale),BEE,Color(1,1,1,alpha))
	# Small lids remain inside the painted sclera; retain its outer eye contour.
	if eyes_closed:
		var lid := Color(1.0,0.77,0.20,alpha)
		var ink := Color(0.22,0.12,0.035,alpha)
		for eye in [Vector3(402,411,1.0),Vector3(494,389,0.32)]:
			var p := (Vector2(eye.x,eye.y)-BEE_PIVOT)*scale
			var radius := Vector2(5.1*eye.z,5.3 if eye.z > 0.5 else 3.0)
			v._ellipse(p,radius,lid)
			v._curve(p+Vector2(-radius.x,0),p+Vector2(-radius.x*0.4,2),p+Vector2(radius.x*0.5,2),p+Vector2(radius.x,0),ink,1.0)
	elif charge > 0.1:
		var p := (Vector2(398,358)-BEE_PIVOT)*scale
		v.draw_line(p+Vector2(-4,-1),p+Vector2(4,charge*1.5),Color(0.22,0.12,0.035,alpha),1.1,true)

static func flower(v: Node2D, p: Vector2, direction: Vector2, close: float, recoil: float, used: bool) -> void:
	var scale := 154.0/FLOWER.size.x
	var fold := Vector2(1.0-close*0.62,1.0-close*0.30)
	var origin := p+direction*recoil+Vector2(0,close*10)
	var tint := Color.WHITE.lerp(Color(0.64,0.80,0.68),close)
	v.draw_texture_rect_region(ATLAS,Rect2(origin+(FLOWER.position-FLOWER_PIVOT)*scale*fold,FLOWER.size*scale*fold),FLOWER,tint)
	if used: return
	# The mark is independent of the painted petals and follows the real launch.
	var side := direction.orthogonal()
	var arrow := PackedVector2Array([p-direction*10-side*12,p+direction*7,p-direction*10+side*12])
	v.draw_polyline(arrow,Color("fff4ce"),7,true)
	v.draw_polyline(arrow,Color("285d57"),4,true)
	for i in 3:
		var along := 82.0+i*22.0
		v.draw_line(p+direction*along,p+direction*(along+10),Color(0.25,0.62,0.62,0.42-i*0.09),3,true)

static func canopy(v: Node2D, p: Vector2, half: float) -> void:
	var width := half*2+20.0
	var size := Vector2(width,95.0)
	# Every visible leaf pixel is above the model's safe pocket (p.y - 64).
	var rect := Rect2(Vector2(p.x-width/2,p.y-66-size.y),size)
	v.draw_texture_rect_region(ATLAS,rect,LEAF)

static func hedge(v: Node2D, r: Rect2) -> void:
	# Each collider partition sits inside the opaque leafy core. A soft fringe
	# extends beyond it, so transparent corner notches never hide solid space.
	var fringe := 35.0
	# Use whole overlapping clusters on long, shallow hedges instead of flattening
	# leaves and blossoms or cutting a partial tile at the far edge.
	var clusters := maxi(1,roundi(r.size.x/(r.size.y*2.2)))
	var width := r.size.x/clusters+fringe*2.0
	for i in clusters:
		var pos := r.position+Vector2(-fringe+i*r.size.x/clusters,-fringe)
		v.draw_texture_rect_region(ATLAS,Rect2(pos,Vector2(width,r.size.y+fringe*2.0)),HEDGE)

static func small_leaf(v: Node2D, root: Vector2, tip: Vector2, height: float) -> void:
	var length := root.distance_to(tip)
	v.draw_set_transform(v._world_offset+root,root.angle_to_point(tip)-PI)
	v.draw_texture_rect_region(ATLAS,Rect2(-length,-height, length,height),LEAF)
	v.draw_set_transform(v._world_offset)
