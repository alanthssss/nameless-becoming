extends RefCounted
## Shared HUD symbols and field-journal illustrations; no progression state.
const HOME_SIGN: Texture2D = preload("res://art/nectar-home-sign.png")
const JOURNAL: Texture2D = preload("res://art/nectar-growth-journal.png")
const PAINTED: Texture2D = preload("res://art/revision-atlas.png")
const RESOURCES: Texture2D = preload("res://art/nectar-resource-icons.png")
const RESIN: Texture2D = preload("res://art/nectar-resin-chunks.png")
const JAR: Texture2D = preload("res://art/nectar-honey-jar.png")
const FLOWER := Rect2(638,100,571,596)
const BEE := Rect2(67,158,510,456)
const LEAF := Rect2(19,822,592,251)

static func painted_sprite(c: CanvasItem, texture: Texture2D, source: Rect2, p: Vector2, extent: float, tint := Color.WHITE) -> void:
	var span := source.size * (extent * 2.0 / maxf(source.size.x,source.size.y))
	c.draw_texture_rect_region(texture,Rect2(p-span*.5,span),source,tint)

static func painted_icon(c: CanvasItem, kind: String, p: Vector2, r: float, tint := Color.WHITE) -> void:
	match kind:
		"resin":
			painted_sprite(c,RESIN,Rect2(190,165,810,890),p,r,tint)
		"coin", "fiber", "wings", "beat":
			var source: Rect2 = {"coin":Rect2(100,120,455,465),"fiber":Rect2(669,108,510,480),"resin":Rect2(151,690,365,460),"wings":Rect2(641,777,538,290),"beat":Rect2(641,777,538,290)}[kind]
			painted_sprite(c,RESOURCES,source,p,r,tint)
			if kind == "beat":
				for side in [-1,1]:
					c.draw_arc(p,r*1.06,-.6 if side>0 else PI-.6,.6 if side>0 else PI+.6,14,Color("b08a45"),1.8,true)
		"gather", "meadow":
			painted_sprite(c,PAINTED,FLOWER,p,r,tint if kind == "gather" else tint*Color(2.2,.75,1.2))
		"twin":
			painted_sprite(c,PAINTED,FLOWER,p+Vector2(-r*.43,r*.15),r*.69,tint)
			painted_sprite(c,PAINTED,FLOWER,p+Vector2(r*.43,-r*.15),r*.69,tint*Color(2.2,.75,1.2))
		"bag", "reserve", "market":
			painted_sprite(c,JAR,Rect2(225,240,800,790),p,r,tint)
			if kind == "reserve":
				painted_sprite(c,JAR,Rect2(225,240,800,790),p+Vector2(r*.65,r*.28),r*.55,tint)
			elif kind == "market": icon(c,"coin",p+Vector2(r*.66,r*.36),r*.36)
		"shortcut":
			painted_sprite(c,PAINTED,LEAF,p+Vector2(0,r*.27),r,tint)
			c.draw_arc(p+Vector2(0,-r*.14),r*.62,PI*1.04,TAU*.98,20,Color("a67539"),2,true)
			c.draw_line(p+Vector2(r*.62,-r*.15),p+Vector2(r*.32,-r*.31),Color("a67539"),2,true)
		"reach":
			# The same painted bee's antennae provide the field-book illustration.
			painted_sprite(c,PAINTED,BEE,p,r,tint)
			c.draw_arc(p+Vector2(0,-r*.12),r*.98,PI*1.12,PI*1.88,20,Color("91a574"),1.6,true)
		_:
			# Use the same painted material family for the wings and body. The old
			# opaque procedural ovals flattened the portrait against the painted UI.
			painted_sprite(c,RESOURCES,Rect2(641,777,538,290),p+Vector2(-r*.12,-r*.34),r*.98,tint)
			painted_sprite(c,PAINTED,BEE,p+Vector2(0,r*.10),r*.88,tint)
			if kind == "beat":
				for side in [-1,1]:
					c.draw_arc(p+Vector2(0,r*.1),r*1.06,-.6 if side>0 else PI-.6,.6 if side>0 else PI+.6,14,Color("b08a45"),1.8,true)

static func icon(c: CanvasItem, kind: String, p: Vector2, r: float, _ink := Color("f5e9b7")) -> void:
	if kind == "home":
		painted_sprite(c,HOME_SIGN,Rect2(210,215,1060,610),p,r)
	else:
		painted_icon(c,kind,p,r)
