extends RefCounted
## Shared authoring vocabulary, never runtime physics.
static func gap(x: float,y: float,width := 190.0) -> Dictionary:
	return {"kind":"gap","x":x,"y":y,"width":width}
static func rescue(x: float,y: float,count := 1) -> Dictionary:
	return {"kind":"pod","x":x,"y":y,"count":count}
static func wind(x: float,y: float,dy := 0.0) -> Dictionary:
	return {"kind":"ring","x":x,"y":y,"direction":Vector2(1,dy).normalized()}
static func chain(points: Array,openings: Array,landing: Vector2,slow: Array = [],flowers: Array = []) -> Dictionary:
	return {"kind":"chain","x":points[0].x,"y":points[0].y,"points":points,"openings":openings,"landing":landing,"slow":slow,"flowers":flowers}
static func curtain(x: float,y: float) -> Dictionary:
	return {"kind":"curtain","x":x,"y":y}
static func flower(x: float,y: float) -> Dictionary:
	return {"kind":"flower","x":x,"y":y}
static func turn(x: float,y: float) -> Dictionary:
	return {"kind":"turn","x":x,"y":y}
static func weather(x: float,width: float) -> Dictionary:
	return {"kind":"rain","x":x,"y":80.0,"width":width}
static func shield(x: float,y: float) -> Dictionary:
	return {"kind":"shield","x":x,"y":y}
static func dew(x: float,y: float,purpose: String,route_mode := "through") -> Dictionary:
	# Route mode only guides developer inputs; every pickup remains optional in play.
	return {"kind":"dew","x":x,"y":y,"purpose":purpose,"route_mode":route_mode}
static func encounter(name: String,width: float,beats: Array,rest_y := -1.0,cue := "继续向前",speed := 100.0,ambient_rain := false) -> Dictionary:
	return {"name":name,"width":width,"beats":beats,"rest_y":rest_y,"cue":cue,"budget":55.0,"storm_speed":speed,"ambient_rain":ambient_rain}

static func fork(top: Array,top_landing: Vector2,bottom: Array,bottom_landing: Vector2,merge: Vector2) -> Dictionary:
	return {"kind":"fork","x":minf(top[0].x,bottom[0].x),"y":420.0,"top":top,"top_landing":top_landing,"bottom":bottom,"bottom_landing":bottom_landing,"merge":merge}
static func deco(x: float,y: float,style: String) -> Dictionary:
	return {"kind":"deco","x":x,"y":y,"style":style}

static func terrain(x: float,y: float,w: float,h: float,style := "hedge") -> Dictionary:
	return {"kind":"terrain","x":x,"y":y,"width":w,"height":h,"style":style}
static func jet(x: float,y: float,w: float,h: float,period := 6.0,active_seconds := 2.2,offset := 0.0) -> Dictionary:
	return {"kind":"jet","x":x,"y":y,"width":w,"height":h,"period":period,"active_seconds":active_seconds,"offset":offset}
static func airflow(x: float,y: float,w: float,h: float,direction: Vector2,strength := 180.0) -> Dictionary:
	return {"kind":"airflow","x":x,"y":y,"width":w,"height":h,"direction":direction.normalized(),"strength":strength}
