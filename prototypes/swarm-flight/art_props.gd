extends RefCounted
## Shared painted prop families; coordinates and state belong to the model.
const Winter = preload("res://winter_art.gd")
const Sprites = preload("res://art_sprites.gd")
const TERRAIN: Texture2D = preload("res://art/garden-terrain.png")
const FLORA: Texture2D = preload("res://art/garden-flora.png")
const LANDMARKS: Texture2D = preload("res://art/garden-landmarks.png")
const HOME: Texture2D = preload("res://art/garden-home.png")
const WEATHER: Texture2D = preload("res://art/garden-weather.png")
const STEM := Rect2(276,110,133,618)
const CURTAIN := Rect2(649,131,554,607)
const CRATE := Rect2(30,847,601,297)
const LEDGE := Rect2(650,933,586,167)
const POD := Rect2(37,207,639,416)
const SNEEZE := Rect2(715,122,518,505)
const BIRD := Rect2(60,694,607,466)
const FOUNTAIN := Rect2(700,692,502,466)
const ARCH := Rect2(751,116,464,520)
const BELL := Rect2(128,794,364,367)
const SIGN := Rect2(671,908,537,214)
const CLOUD := Rect2(23,231,847,347)
const DEW := Rect2(917,188,242,363)
const SHIELD := Rect2(36,734,722,390)
const LANTERN := Rect2(810,681,407,476)
const INK := Color("34532c")

static func sprite(v: Node2D, texture: Texture2D, source: Rect2, rect: Rect2, tint := Color.WHITE) -> void:
	v.draw_texture_rect_region(texture,rect,source,tint)

static func stem(v: Node2D, r: Rect2, upper: bool) -> void:
	if r.size.y <= 0.0: return
	var winter := Winter.active(v)
	var atlas: Texture2D = Winter.ATLAS if winter else TERRAIN
	var cap: Rect2 = Winter.STEM_CAP if winter else Rect2(276,110,133,47)
	# Adjacent atlas slices share their horizontal bounds. The shaft starts
	# behind the rim, never behind its transparent rounded corners.
	var core := Rect2(cap.position.x,cap.end.y,cap.size.x,650.0-cap.end.y if winter else 704.0-cap.end.y)
	var cap_height := minf(16.0,r.size.y)
	var origin := Vector2(r.get_center().x,r.end.y if upper else r.position.y)
	v.draw_set_transform(v._world_offset+origin,PI if upper else 0.0)
	sprite(v,atlas,cap,Rect2(-r.size.x/2,0,r.size.x,cap_height))
	if r.size.y > cap_height:
		sprite(v,atlas,core,Rect2(-r.size.x/2,cap_height,r.size.x,r.size.y-cap_height))
	v.draw_set_transform(v._world_offset)

static func stalk(v: Node2D, a: Vector2, b: Vector2, c: Vector2, d: Vector2, width: float) -> void:
	var winter := Winter.active(v)
	var atlas: Texture2D = Winter.ATLAS if winter else TERRAIN
	var core: Rect2 = Winter.STEM_CORE if winter else Rect2(285,150,113,550)
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var uv_left := PackedVector2Array()
	var uv_right := PackedVector2Array()
	for i in 19:
		var t := float(i)/18.0
		var q := a.bezier_interpolate(b,c,d,t)
		var tangent := a.bezier_derivative(b,c,d,t).normalized()
		var normal := tangent.orthogonal()*width*0.5
		left.append(q-normal)
		right.append(q+normal)
		uv_left.append(Vector2(core.position.x,core.position.y+t*core.size.y)/Vector2(atlas.get_size()))
		uv_right.append(Vector2(core.end.x,core.position.y+t*core.size.y)/Vector2(atlas.get_size()))
	for i in range(18,-1,-1):
		left.append(right[i])
		uv_left.append(uv_right[i])
	v._curve(a,b,c,d,Winter.INK if winter else INK,width+2.0)
	v.draw_polygon(left,PackedColorArray([Color.WHITE]),uv_left,atlas)

static func curtain(v: Node2D, r: Rect2, broken: bool, flex: float) -> void:
	if broken:
		var tip := Rect2(r.position+Vector2(flex*2,0),Vector2(r.size.x,23))
		sprite(v,TERRAIN,Rect2(804,148,124,80),tip,Color("d2ad78"))
		return
	# The narrow strip is a hanging leaf membrane, not four squeezed ornaments.
	sprite(v,TERRAIN,Rect2(817,237,108,330),r)
	v.draw_line(r.position,r.position+Vector2(r.size.x,0),Color("7c4b24"),4,true)

static func solid_frame(v: Node2D, source: Rect2, core: Rect2, r: Rect2, fringe: float) -> void:
	# Nine slices keep the fully opaque face exactly on the collider. Painted
	# bevels occupy a small forgiving fringe without a rectangular backing.
	var sx := [source.position.x,core.position.x,core.end.x,source.end.x]
	var sy := [source.position.y,core.position.y,core.end.y,source.end.y]
	var dx := [r.position.x-fringe,r.position.x,r.end.x,r.end.x+fringe]
	var dy := [r.position.y-fringe,r.position.y,r.end.y,r.end.y+fringe]
	for row in 3:
		for col in 3:
			sprite(v,TERRAIN,Rect2(sx[col],sy[row],sx[col+1]-sx[col],sy[row+1]-sy[row]),Rect2(dx[col],dy[row],dx[col+1]-dx[col],dy[row+1]-dy[row]))

static func terrain(v: Node2D, r: Rect2, material: String) -> void:
	if material == "crate":
		solid_frame(v,Rect2(30,898,601,246),Rect2(42,914,579,221),r,6.0)
	else:
		solid_frame(v,LEDGE,Rect2(681,990,518,101),r,7.0)

static func pod(v: Node2D, p: Vector2, opened: float, front: bool) -> void:
	var size := Vector2(136,88)
	var dest := Rect2(p+Vector2(-68,-32),size)
	if not front:
		sprite(v,FLORA,POD,dest)
		return
	# Front lip covers the bee's feet; the lid opens away from its visible face.
	sprite(v,FLORA,Rect2(POD.position+Vector2(0,285),Vector2(POD.size.x,131)),Rect2(dest.position+Vector2(0,60.3),Vector2(size.x,27.7)))
	if opened < 0.99:
		var root := p+Vector2(50,33)
		var tip := p+Vector2(-47,-30).lerp(Vector2(74,37),opened)
		Sprites.small_leaf(v,root,tip,lerpf(32,14,opened))

static func sprayer(v: Node2D, p: Vector2, calm: bool, warning: float, sneeze: float, blink: bool) -> void:
	var size := Vector2(148+sneeze*14,144-sneeze*12)
	var tint := Color.WHITE.lerp(Color("ffd18e"),warning*0.35)
	if calm: tint = Color("c4e6da")
	sprite(v,FLORA,SNEEZE,Rect2(p+Vector2(-80,-76)-Vector2(sneeze*8,0),size),tint)
	var face := p+Vector2(18,-11)
	for side in [0.0,1.0]:
		var eye := face+Vector2(side*12,-side*4)
		if calm or blink or sneeze > 0.0:
			v._curve(eye-Vector2(4,1),eye-Vector2(2,-3),eye+Vector2(2,-3),eye+Vector2(4,1),Color("4b345b"),1.7)
		else:
			v._oval(eye,Vector2(4.0,5.0),Color("fff6dd"),Color("4b345b"),1.2)
			v.draw_circle(eye-Vector2(1,0),2,Color("4b345b"))
	if warning > 0.0:
		v.draw_line(face+Vector2(-5,-9),face+Vector2(5,-7-warning*3),Color("4b345b"),1.8,true)
	if calm:
		v._curve(face+Vector2(-2,9),face+Vector2(3,13),face+Vector2(8,12),face+Vector2(12,7),Color("4b345b"),1.5)

static func fountain(v: Node2D, base: Rect2, state: String) -> void:
	var width := clampf(base.size.x,64,110)
	var height := width*FOUNTAIN.size.y/FOUNTAIN.size.x
	var tint := Color.WHITE if state != "warning" else Color("ffe2a6")
	sprite(v,FLORA,FOUNTAIN,Rect2(base.get_center().x-width/2,base.position.y-6,width,height),tint)

static func air_source(v: Node2D, p: Vector2, direction: Vector2) -> void:
	v.draw_set_transform(v._world_offset+p,direction.angle()+PI/2)
	sprite(v,FLORA,FOUNTAIN,Rect2(-24,0,48,45),Color("d6ebdf"))
	v.draw_set_transform(v._world_offset)

static func bird(v: Node2D, p: Vector2, clock: float) -> void:
	var size := Vector2(72,55)
	sprite(v,FLORA,BIRD,Rect2(p+Vector2(-36,-37+sin(clock*1.6)*1.2),size))

static func goal_arch(v: Node2D, p: Vector2, ready: bool, arrival: float) -> void:
	var tint := Color.WHITE if ready else Color("d5dfb8")
	var height := 350.0+minf(maxf(arrival,0.0),1.0)*8.0
	sprite(v,Winter.ATLAS if Winter.active(v) else LANDMARKS,Winter.ARCH if Winter.active(v) else ARCH,Rect2(p+Vector2(-80,-184),Vector2(230,height)),tint)
	Sprites.small_leaf(v,p+Vector2(95,107),p+Vector2(-66,107),27)

static func home(v: Node2D, p: Vector2, _arrival: float, opacity := 1.0, scale := 1.0) -> void:
	# A dedicated tall source keeps bark and roots in proportion. The hollow
	# around source (628,587) coincides with the model's unchanged exit center.
	var factor := 0.556*scale
	var origin := p-Vector2(628,587)*factor
	var texture: Texture2D = Winter.HOME if Winter.active(v) else HOME
	# Both variants preserve the same hollow anchor and natural trunk proportions.
	sprite(v,texture,Rect2(Vector2.ZERO,texture.get_size()),Rect2(origin,texture.get_size()*factor),Color(1,1,1,opacity))

static func bell(v: Node2D, p: Vector2, swing: float, ready: bool) -> void:
	v.draw_set_transform(v._world_offset+p,swing)
	if Winter.active(v):
		# Keep the brass bell; omit its fresh leafy handle in winter.
		v.draw_arc(Vector2(0,8),5,PI,TAU,12,Winter.INK,2,true)
		sprite(v,LANDMARKS,Rect2(128,964,303,197),Rect2(-14,7,28,21),Color.WHITE if ready else Color("d5d0bb"))
	else:
		sprite(v,LANDMARKS,BELL,Rect2(-16,-8,34,36),Color.WHITE if ready else Color("d0c49d"))
	v.draw_set_transform(v._world_offset)

static func pickup(v: Node2D, p: Vector2, kind: String) -> void:
	if kind == "dew":
		sprite(v,WEATHER,DEW,Rect2(p-Vector2(13,20),Vector2(26,39)))
	else:
		sprite(v,Winter.ATLAS if Winter.active(v) else WEATHER,Winter.LEAF if Winter.active(v) else SHIELD,Rect2(p-Vector2(28,16),Vector2(56,31)))

static func cloud(v: Node2D, r: Rect2, tint: Color) -> void:
	sprite(v,WEATHER,CLOUD,r,tint)

static func decor(v: Node2D, p: Vector2, style: String) -> void:
	# Do not reset the caller's transform: small flowers also use local scaling.
	if style == "flower":
		sprite(v,Winter.ATLAS if Winter.active(v) else Sprites.ATLAS,Winter.FLOWER if Winter.active(v) else Sprites.FLOWER,Rect2(p-Vector2(15,15),Vector2(30,30)),Color.WHITE if Winter.active(v) else Color("ffb7d9"))
	elif style == "sign":
		sprite(v,LANDMARKS,SIGN,Rect2(p-Vector2(48,16),Vector2(96,32)))
	elif style in ["lamp","shelter_lamp","shelter_lamp_lit"]:
		var tint := Color.WHITE if style == "shelter_lamp_lit" else Color("d5cf9e")
		sprite(v,WEATHER,LANTERN,Rect2(p-Vector2(13,16),Vector2(26,31)),tint)
	elif style in ["withered","dead_flower"]:
		v._curve(p+Vector2(0,100),p+Vector2(-12,15),p+Vector2(21,-9),p+Vector2(28,12),Color("8d6a3e"),4)
		sprite(v,TERRAIN,CURTAIN,Rect2(p+Vector2(5,8),Vector2(43,49)),Color("c3b68d"))
	else:
		sprite(v,LANDMARKS,SIGN,Rect2(p-Vector2(26,12),Vector2(52,24)),Color("c3c7a4"))
