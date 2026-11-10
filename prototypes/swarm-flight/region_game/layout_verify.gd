extends SceneTree
const Natural = preload("res://region_game/layout.gd")
const Collision = preload("res://region_greybox/layout.gd")
var checks := 0
var failures: Array[String] = []

func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("FAIL "+label)

func _initialize() -> void:
	for region in ["pond","violet"]: verify(region)
	print("REGIONAL_LAYOUT checks=%d failures=%d" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)

func verify(region: String) -> void:
	var layout: Dictionary = Natural.build(region)
	var legacy: Dictionary = Collision.build(region)
	var coast: PackedVector2Array = layout.coast
	check(layout == Natural.build(region),region+" fixed authored shore, independent of visit seed")
	check(layout.nodes == legacy.nodes and layout.edges == legacy.edges,region+" all five targets and four tree edges unchanged")
	check(layout.edges == [Vector2i(0,1),Vector2i(1,2),Vector2i(2,3),Vector2i(2,4)],region+" one inward route and one short pocket, no loop")
	check(not layout.has("weather") and not layout.has("shelters"),region+" no weather or alternate route states")
	check(coast.size()>150 and not Geometry2D.triangulate_polygon(coast).is_empty(),region+" natural outline is renderable")
	check(_simple(coast),region+" no self intersections or folded coastal collision")
	check(layout.bounds.size.x>2200,region+" overall map still needs sustained camera travel")
	var boundary_ok := true
	var max_segment := 0.0
	for i in coast.size():
		var a: Vector2 = coast[i]
		var b: Vector2 = coast[(i+1)%coast.size()]
		max_segment = maxf(max_segment,a.distance_to(b))
		var middle := (a+b)*.5
		var inward := (b-a).normalized().orthogonal()
		if not Geometry2D.is_point_in_polygon(middle+inward*2,coast): inward = -inward
		boundary_ok = boundary_ok and Collision.walkable(layout,middle+inward*2,0)
		boundary_ok = boundary_ok and not Collision.walkable(layout,middle-inward*2,0)
		boundary_ok = boundary_ok and not Collision.walkable(layout,middle+inward*8,16)
		boundary_ok = boundary_ok and Collision.walkable(layout,middle+inward*22,16)
		boundary_ok = boundary_ok and layout.bounds.has_point(a)
	check(boundary_ok,region+" exact displayed coast and 16px body margin agree on both sides")
	check(max_segment<24,region+" boundary contains no long straight mesh spans")
	var lane_ok := true
	var main_length := 0.0
	var widths: Array[float] = []
	for i in layout.paths.size():
		var path: PackedVector2Array = layout.paths[i]
		var edge: Vector2i = layout.edges[i]
		check(path[0] == layout.nodes[edge.x].p and path[-1] == layout.nodes[edge.y].p,region+" graph endpoints still match real targets")
		var backwards := Collision.path_between(layout,edge.y,edge.x)
		check(backwards[0] == path[-1] and backwards[-1] == path[0],region+" return uses the same open route")
		var normal := (path[-1]-path[0]).normalized().orthogonal()
		var offsets: Array = [-100.0,0.0,100.0] if i<3 else [-35.0,0.0,35.0]
		for step_index in 31:
			var at: Vector2 = path[0].lerp(path[-1],float(step_index)/30)
			for offset in offsets:
				lane_ok = lane_ok and Collision.walkable(layout,at+normal*offset,16)
		if i<3:
			main_length += path[0].distance_to(path[-1])
			for t in [.2,.4,.6,.8]:
				var centre: Vector2 = path[0].lerp(path[-1],t)
				widths.append(_ray_width(layout,centre,normal))
		var at: Vector2 = path[0]
		for j in range(1,path.size()): at = Collision.move(layout,at,path[j]-at)
		check(at.distance_to(path[-1])<.1,region+" swept body reaches target along main/pocket path")
	check(lane_ok,region+" broad body-clear main lanes and pocket remain connected")
	check(main_length>1900 and main_length<2200,region+" preserves useful inward travel distance")
	var smallest := INF
	var largest := 0.0
	for width in widths:
		smallest = minf(smallest,width)
		largest = maxf(largest,width)
	check(largest-smallest>70,region+" narrow and broad reaches have materially different widths")
	var sources_ok := true
	for cluster in layout.clusters:
		for anchor in cluster.anchors:
			for i in 12:
				sources_ok = sources_ok and Collision.walkable(layout,anchor+Vector2.from_angle(TAU*float(i)/12)*45,32)
	for item in layout.material_spawns:
		for x in [-18.0,0.0,18.0]: sources_ok = sources_ok and Collision.walkable(layout,item.p+Vector2(x,0),24)
	check(sources_ok,region+" all legacy potential resource positions remain approachable")
	for node in layout.nodes: check(Collision.walkable(layout,node.p,32),region+" stable target centre has flight clearance")
	var entry: Vector2 = layout.nodes[0].p
	var stopped := Collision.move(layout,entry,Vector2(-3000,-2000))
	check(Collision.walkable(layout,stopped,16),region+" large movement cannot tunnel across shore")
	check(not Collision.walkable(layout,Vector2(-5000,-5000),-50),region+" optional polygon always rejects outside points")
	# Old greybox data must continue down its original capsule path unchanged.
	check(not legacy.has("coast") and Collision.walkable(legacy,entry) and not Collision.walkable(legacy,entry+Vector2(-400,0)),region+" old greybox layout keeps original collision contract")
	_verify_grid(layout,region)
	print("REGIONAL_SHORE %s vertices=%d main_length=%.1f sampled_width=%.0f..%.0f" % [region,coast.size(),main_length,smallest,largest])

func _simple(points: PackedVector2Array) -> bool:
	for i in points.size():
		for j in range(i+2,points.size()):
			if i == 0 and j == points.size()-1: continue
			var intersection: Variant = Geometry2D.segment_intersects_segment(points[i],points[(i+1)%points.size()],points[j],points[(j+1)%points.size()])
			if intersection != null: return false
	return true

func _ray_width(layout: Dictionary,centre: Vector2,normal: Vector2) -> float:
	var width := 0.0
	for direction in [-1.0,1.0]:
		var distance := 0.0
		while distance<650 and Collision.walkable(layout,centre+normal*direction*(distance+4),0): distance += 4
		width += distance
	return width

func _verify_grid(layout: Dictionary,label: String) -> void:
	# Independent spatial flood, rather than accepting graph connectivity alone.
	var step := 36.0
	var origin: Vector2 = layout.bounds.position+Vector2.ONE*step*.5
	var cells := {}
	for y in ceili(layout.bounds.size.y/step):
		for x in ceili(layout.bounds.size.x/step):
			var key := Vector2i(x,y)
			if Collision.walkable(layout,origin+Vector2(key)*step,16): cells[key] = true
	var entry: Vector2 = layout.nodes[0].p
	var start := Vector2i(roundi((entry.x-origin.x)/step),roundi((entry.y-origin.y)/step))
	var seen := {start:true}
	var todo: Array[Vector2i] = [start]
	var cursor := 0
	while cursor<todo.size():
		var key: Vector2i = todo[cursor]
		cursor += 1
		for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN,Vector2i(-1,-1),Vector2i(-1,1),Vector2i(1,-1),Vector2i(1,1)]:
			var neighbor: Vector2i = key+offset
			if cells.has(neighbor) and not seen.has(neighbor):
				var middle := origin+(Vector2(key)+Vector2(neighbor))*step*.5
				if Collision.walkable(layout,middle,16):
					seen[neighbor] = true
					todo.append(neighbor)
	var targets_ok := true
	for node in layout.nodes:
		var key := Vector2i(roundi((node.p.x-origin.x)/step),roundi((node.p.y-origin.y)/step))
		targets_ok = targets_ok and seen.has(key)
	check(targets_ok and seen.size()>=cells.size()*.99,label+" spatial flood connects all targets and traversable reaches")
