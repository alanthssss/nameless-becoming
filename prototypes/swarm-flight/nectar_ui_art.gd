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
const JOURNAL_ACTIONS: Texture2D = preload("res://art/nectar-journal-actions.png")
const CELL := Vector2(160,160)
const JOURNAL_CELLS := {
	"gather": Vector2(0,0), "reach": Vector2(1,0), "beat": Vector2(2,0), "wings": Vector2(3,0),
	"bag": Vector2(0,1), "twin": Vector2(1,1), "meadow": Vector2(2,1), "supply": Vector2(3,1),
	"shortcut": Vector2(0,2), "market": Vector2(1,2), "reserve": Vector2(2,2)
}

static func journal_icon(c: CanvasItem, kind: String, p: Vector2, r: float, tint := Color.WHITE) -> void:
	var tile: Vector2 = JOURNAL_CELLS.get(kind,JOURNAL_CELLS.gather)
	painted_sprite(c,JOURNAL_ACTIONS,Rect2(tile*CELL,CELL),p,r,tint)

static func painted_sprite(c: CanvasItem, texture: Texture2D, source: Rect2, p: Vector2, extent: float, tint := Color.WHITE) -> void:
	var span := source.size * (extent * 2.0 / maxf(source.size.x,source.size.y))
	c.draw_texture_rect_region(texture,Rect2(p-span*.5,span),source,tint)

static func painted_icon(c: CanvasItem, kind: String, p: Vector2, r: float, tint := Color.WHITE) -> void:
	match kind:
		"resin":
			painted_sprite(c,RESIN,Rect2(190,165,810,890),p,r,tint)
		"coin":
			painted_sprite(c,RESOURCES,Rect2(100,120,455,465),p,r,tint)
		"fiber":
			painted_sprite(c,RESOURCES,Rect2(669,108,510,480),p,r,tint)
		"gather", "meadow":
			painted_sprite(c,PAINTED,FLOWER,p,r,tint if kind == "gather" else tint*Color(2.2,.75,1.2))
		"bag", "reserve":
			painted_sprite(c,JAR,Rect2(225,240,800,790),p,r,tint)
			if kind == "reserve":
				painted_sprite(c,JAR,Rect2(225,240,800,790),p+Vector2(r*.65,r*.28),r*.55,tint)
		_:
			if JOURNAL_CELLS.has(kind):
				journal_icon(c,kind,p,r,tint)
				return
			# Compose the whole character for the HUD portrait.
			painted_sprite(c,RESOURCES,Rect2(641,777,538,290),p+Vector2(-r*.12,-r*.34),r*.98,tint)
			painted_sprite(c,PAINTED,BEE,p+Vector2(0,r*.10),r*.88,tint)

static func icon(c: CanvasItem, kind: String, p: Vector2, r: float, _ink := Color("f5e9b7")) -> void:
	if kind == "home":
		painted_sprite(c,HOME_SIGN,Rect2(210,215,1060,610),p,r)
	else:
		painted_icon(c,kind,p,r)
