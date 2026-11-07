extends RefCounted
## Authored flight-height thickets. Water, low grass and leaf shelters stay passable.
## Ellipses are also the opaque sprite footprint; no invisible corridor walls.
const LAYOUT_ID := "nectar-routes-027"
const BODY_RADIUS := 16.0
const THICKETS := {
	"pond":[{"id":"pond_island","p":Vector2(980,405),"r":Vector2(190,105)}],
	"meadow":[{"id":"meadow_island","p":Vector2(2320,445),"r":Vector2(140,85)}]
}

static func solids(area: String) -> Array:
	return THICKETS.get(area,[])

static func inside(at: Vector2, solid: Dictionary, margin := 0.0) -> bool:
	return ((at-solid.p)/(solid.r+Vector2.ONE*margin)).length_squared()<1.0

static func blocked(area: String, at: Vector2, margin := BODY_RADIUS) -> bool:
	for solid in solids(area):
		if inside(at,solid,margin): return true
	return false

static func clear_segment(area: String, a: Vector2, b: Vector2, margin := 0.0) -> bool:
	for solid in solids(area):
		var radii: Vector2 = solid.r+Vector2.ONE*margin
		var start: Vector2 = (a-solid.p)/radii
		var end: Vector2 = (b-solid.p)/radii
		var axis := end-start
		var t := clampf(-start.dot(axis)/axis.length_squared(),0.0,1.0) if axis.length_squared()>0.000001 else 0.0
		if (start+axis*t).length_squared()<1.0: return false
	return true

static func safe_point(area: String, at: Vector2, margin := BODY_RADIUS) -> Vector2:
	var result := at
	for solid in solids(area):
		if not inside(result,solid,margin): continue
		var radii: Vector2 = solid.r+Vector2.ONE*(margin+1.0)
		var axis: Vector2 = (result-solid.p)/radii
		if axis.is_zero_approx(): axis = Vector2.DOWN
		result = solid.p+axis.normalized()*radii
	return result

static func move(area: String, origin: Vector2, displacement: Vector2, margin := BODY_RADIUS) -> Vector2:
	# <=8 px steps also prevent a 500 px/s dash at the largest allowed dt tunnelling.
	var at := safe_point(area,origin,margin)
	var steps := maxi(1,ceili(displacement.length()/8.0))
	var offset := displacement/float(steps)
	for i in steps:
		if not blocked(area,at+offset,margin):
			at += offset
			continue
		if not blocked(area,at+Vector2(offset.x,0),margin): at.x += offset.x
		if not blocked(area,at+Vector2(0,offset.y),margin): at.y += offset.y
	return at
