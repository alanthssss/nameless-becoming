extends RefCounted
## Nectar-only scenery. All attachments use world coordinates, never parallax.
## Ground stays below the flying centre limit (650); supports are behind actors.
const Props = preload("res://art_props.gd")
const Sprites = preload("res://art_sprites.gd")
const GARDEN: Texture2D = preload("res://art/garden-spring.png")
const STUMP: Texture2D = preload("res://art/nectar-rooted-stump.png")
const BRANCH: Texture2D = preload("res://art/nectar-branch-support.png")
const GRASS := Rect2(380,965,760,26)

static func ground_y(area: String, x: float) -> float:
	if area == "hub": return 755.0+sin(x*.005)*7.0
	if area == "pond": return 746.0+sin(x*.008)*9.0+sin(x*.022)*3.0
	return 724.0+sin((x-1800.0)*.004)*16.0+sin(x*.012)*5.0

static func background(v: Node2D, area: String) -> void:
	if area == "hub":
		v.draw_texture_rect(GARDEN,Rect2(0,-30,1280,830),false)
	else:
		# Retain the painted distant trees. The left/centre crop excludes the shed.
		v.draw_texture_rect_region(GARDEN,Rect2(0,-30,1280,830),Rect2(0,0,1170,992),Color("edf1e9") if area == "meadow" else Color.WHITE)
	v.draw_rect(Rect2(0,0,1280,800),Color(.96,.98,.85,.08))

static func terrain(v: Node2D, area: String, cam: float, clock: float) -> void:
	var left: float = floorf((cam-180.0)/16.0)*16.0
	var right: float = cam+1480.0
	if area == "pond":
		# One softly shaded water surface behind the near bank; no stepped colour bands.
		var water := PackedVector2Array()
		var shades := PackedColorArray()
		for i in range(int((right-left)/16.0)+1):
			var x: float = left+i*16.0
			water.append(Vector2(x,675.0+sin(x*.005)*8.0+sin(x*.016)*1.8))
			shades.append(Color("9cd2b9"))
		water.append(Vector2(right,810))
		water.append(Vector2(left,810))
		shades.append(Color("5aafac"))
		shades.append(Color("5aafac"))
		v.draw_polygon(water,shades)
		for i in range(int(left/95.0)-1,int(right/95.0)+1):
			var x: float = i*95.0+sin(float(i)*3.7)*22.0
			var y: float = 693.0+fposmod(float(i)*17.0,39.0)
			v._curve(Vector2(x,y),Vector2(x+13,y-1.7),Vector2(x+35,y+2),Vector2(x+49,y),Color(.85,.97,.79,.24),1.3)
			if i%4 == 0:
				var float_at := Vector2(x+32,724.0+sin(clock*.55+i)*1.0)
				Sprites.small_leaf(v,float_at+Vector2(26,0),float_at-Vector2(26,0),7)
	# A quiet soil gradient carries the depth; the painted grass is only a 22px rim.
	# Both the rim and its UVs use fixed world tiles, independent of camera motion.
	var soil := PackedVector2Array()
	var soil_colors := PackedColorArray()
	var soil_top := Color("b4bd84") if area == "pond" else Color("aab873")
	var soil_bottom := Color("879b69") if area == "pond" else Color("7e965f")
	for i in range(int((right-left)/16.0)+1):
		var x: float = left+i*16.0
		soil.append(Vector2(x,ground_y(area,x)))
		soil_colors.append(soil_top)
	soil.append(Vector2(right,835))
	soil.append(Vector2(left,835))
	soil_colors.append(soil_bottom)
	soil_colors.append(soil_bottom)
	v.draw_polygon(soil,soil_colors)
	for tile in range(int(floorf(left/600.0)),int(ceilf(right/600.0))):
		var start: float = tile*600.0
		var rim := PackedVector2Array()
		var uv := PackedVector2Array()
		var rim_colors := PackedColorArray()
		var tint := Color("d8d1b4") if area == "pond" else Color("dee3c4")
		for i in 39:
			var x: float = start+float(i)/38.0*600.0
			rim.append(Vector2(x,ground_y(area,x)))
			uv.append((GRASS.position+Vector2(float(i)/38.0*GRASS.size.x,0))/Vector2(GARDEN.get_size()))
			rim_colors.append(tint)
		for i in range(38,-1,-1):
			var x: float = start+float(i)/38.0*600.0
			rim.append(Vector2(x,ground_y(area,x)+22.0))
			uv.append((GRASS.position+Vector2(float(i)/38.0*GRASS.size.x,GRASS.size.y))/Vector2(GARDEN.get_size()))
			rim_colors.append(Color(tint,0.0))
		v.draw_polygon(rim,rim_colors,uv,GARDEN)
	# Root crowns and tiny leaves soften the near edge without adding opaque obstacles.
	for i in range(int(left/170.0),int(right/170.0)+1):
		var x: float = i*170.0+23.0
		var y: float = ground_y(area,x)+5.0
		Sprites.small_leaf(v,Vector2(x,y),Vector2(x-26,y-10),8)
		Sprites.small_leaf(v,Vector2(x+3,y),Vector2(x+25,y-16),8)

static func rooted_stump(v: Node2D, area: String, p: Vector2, foot_y: float, width: float) -> void:
	# Fixed source anchors: upper ellipse contact y=300, root baseline y=865.
	# The existing feet occlude the rear ellipse; both contacts remain on one plane.
	var height: float = ground_y(area,p.x)-foot_y
	var scale_y: float = height/565.0
	var scale_x: float = width/1536.0
	v.draw_texture_rect(STUMP,Rect2(Vector2(p.x-768.0*scale_x,foot_y-300.0*scale_y),Vector2(1536.0*scale_x,1024.0*scale_y)),false)

static func platform(v: Node2D, area: String, p: Vector2, size: float) -> void:
	var foot_y: float = p.y+size*.205
	if size < 200.0:
		# Source saddle spans x=170..690 at y=345; root baseline is y=1465.
		# One coherent painted branch joins both stage feet to a visible rear trunk.
		var scale_x: float = size*.78/520.0
		var trunk_x: float = p.x+(715.0-430.0)*scale_x
		var scale_y: float = (ground_y(area,trunk_x)-foot_y)/1120.0
		v.draw_texture_rect(BRANCH,Rect2(Vector2(p.x-430.0*scale_x,foot_y-345.0*scale_y),Vector2(1024.0*scale_x,1536.0*scale_y)),false,Color("e5e4c9"))
	else:
		rooted_stump(v,area,p,foot_y,size*1.18)

static func shop_base(v: Node2D, p: Vector2) -> void:
	rooted_stump(v,"hub",p,p.y+96.0,350.0)

static func book_bracket(v: Node2D, p: Vector2) -> void:
	# A small painted beam fixed into the existing trunk. The book's own feet
	# remain visible on it; the old freestanding green support is gone.
	v.draw_texture_rect_region(Props.TERRAIN,Rect2(p+Vector2(-80,29),Vector2(160,14)),Rect2(75,914,490,35))

static func root_crown(v: Node2D, at: Vector2, size := 1.0) -> void:
	v._ellipse(at+Vector2(0,3),Vector2(23,5)*size,Color("74845499"))
	Sprites.small_leaf(v,at,at+Vector2(-35,-12)*size,9*size)
	Sprites.small_leaf(v,at+Vector2(2,0),at+Vector2(32,-17)*size,9*size)
