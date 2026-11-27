extends RefCounted
## Shared HUD symbols and field-journal illustrations; no progression state.
const HOME_SIGN: Texture2D = preload("res://art/nectar-home-sign.png")
const JOURNAL: Texture2D = preload("res://art/nectar-growth-journal.png")
const PAINTED: Texture2D = preload("res://art/revision-atlas.png")
const RESOURCES: Texture2D = preload("res://art/nectar-resource-icons.png")
const RESIN: Texture2D = preload("res://art/nectar-resin-chunks.png")
const JAR: Texture2D = preload("res://art/nectar-honey-jar.png")
const FLOWER := Rect2(638,100,571,596)
const BEE: Texture2D = preload("res://art/honey-bee.png")
const BODY := Rect2(0,0,512,512)
const WINGS := Rect2(512,0,512,512)
const WING_ROOT := Vector2(.39,.435)
const ENERGY_POSES: Texture2D = preload("res://art/honey-energy-poses.png")
const POSE_SIZE := Vector2(256,256)
const WING_LIFT := [1.0,.97,.92,.86,.78,.70]
static var bee_texture := CanvasTexture.new()
static var pose_texture := CanvasTexture.new()
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

# The atlas has mipmaps. Select them on this texture alone, including in world
# views that also paint full-resolution scenery on the same CanvasItem.
static func _bee_layers(c: CanvasItem, body: Rect2, wings: Rect2, texture: Texture2D, region: Rect2, offset: Vector2, color: Color) -> void:
	c.draw_texture_rect_region(bee_texture,Rect2(wings.position+offset,wings.size),WINGS,color)
	c.draw_texture_rect_region(texture,Rect2(body.position+offset,body.size),region,color)

# Both layers use the same square canvas. Keep the wing joint fixed when it folds.
static func painted_bee(c: CanvasItem, rect: Rect2, wing_scale := 1.0, tint := Color.WHITE, shaded := true, energy_stage := -1) -> void:
	if bee_texture.diffuse_texture == null:
		bee_texture.diffuse_texture = BEE
		bee_texture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		pose_texture.diffuse_texture = ENERGY_POSES
		pose_texture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var body_texture := bee_texture
	var body_region := BODY
	if energy_stage >= 0:
		var column := energy_stage % 3
		var row := floori(float(energy_stage)/3.0)
		body_texture = pose_texture
		body_region = Rect2(Vector2(column,row)*POSE_SIZE,POSE_SIZE)
		# Adjust only the open end of the stroke: resting and recoil still fold it.
		wing_scale = lerpf(.28,wing_scale,float(WING_LIFT[energy_stage]))
	var wing_rect := rect
	wing_rect.size *= Vector2(lerpf(1.10,1.0,wing_scale),wing_scale)
	wing_rect.position += (rect.size-wing_rect.size)*WING_ROOT
	if shaded:
		# A narrow burnt-umber edge on the shadow side separates the wings and
		# cheek from the scenery. Each impression follows the moving silhouette.
		var edge := rect.size.x/58.0
		_bee_layers(c,rect,wing_rect,body_texture,body_region,Vector2(1.08,1.25)*edge,Color(.105,.078,.063,.88)*tint)
		_bee_layers(c,rect,wing_rect,body_texture,body_region,Vector2(-.80,.45)*edge,Color(.17,.12,.087,.72)*tint)
		_bee_layers(c,rect,wing_rect,body_texture,body_region,Vector2(-.60,-1.18)*edge,Color(.21,.16,.11,.80)*tint)
		_bee_layers(c,rect,wing_rect,body_texture,body_region,Vector2(-.29,-.57)*edge,Color(1.5,1.18,.84,.74)*tint)
	_bee_layers(c,rect,wing_rect,body_texture,body_region,Vector2.ZERO,tint)

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
			painted_bee(c,Rect2(p-Vector2.ONE*r,Vector2.ONE*r*2.0),1.0,tint)

static func icon(c: CanvasItem, kind: String, p: Vector2, r: float, _ink := Color("f5e9b7")) -> void:
	if kind == "home":
		painted_sprite(c,HOME_SIGN,Rect2(210,215,1060,610),p,r)
	else:
		painted_icon(c,kind,p,r)
