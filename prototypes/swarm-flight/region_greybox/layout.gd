extends RefCounted
## Fixed collecting grounds for the 2026-11-10 no-weather design.
## The visible pale surface and collision share this union of discs/capsules.
## Main-path width is 520px; only the short material pocket narrows to 240px.
const BODY_RADIUS := 16.0
const ROOM_RADIUS := 260.0
const CORRIDOR_RADIUS := 260.0
const POCKET_RADIUS := 120.0
const NODE_DATA := {
	"pond": [
		[200,700,"入口湾"], [825,600,"近岸蓝花"], [1515,760,"沿岸混合带"],
		[2205,560,"远岸纤维点"], [1515,1140,"侧湾纤维点"]
	],
	"violet": [
		[200,600,"坡脚入口"], [825,730,"近处紫花"], [1515,580,"连续紫花带"],
		[2205,790,"深处树脂点"], [1515,200,"侧坡树脂点"]
	]
}
const EDGES := [Vector2i(0,1),Vector2i(1,2),Vector2i(2,3),Vector2i(2,4)]
const CLUSTER_X := [480.0,825.0,1170.0,1515.0,1860.0,2205.0]

static func build(region: String) -> Dictionary:
	assert(region in NODE_DATA, "Unknown greybox region")
	var nodes: Array[Dictionary] = []
	for i in NODE_DATA[region].size():
		var data: Array = NODE_DATA[region][i]
		nodes.append({"id":i,"name":str(data[2]),"p":Vector2(float(data[0]),float(data[1])),
			"radius":150.0 if i == 4 else ROOM_RADIUS})
	var edges: Array[Vector2i] = []
	var paths: Array[PackedVector2Array] = []
	var path_radii: Array[float] = []
	for edge in EDGES:
		edges.append(edge)
		paths.append(PackedVector2Array([nodes[edge.x].p,nodes[edge.y].p]))
		path_radii.append(POCKET_RADIUS if edge.y == 4 else CORRIDOR_RADIUS)
	var clusters: Array[Dictionary] = []
	for i in CLUSTER_X.size():
		var x: float = CLUSTER_X[i]
		var edge_index := 0 if i < 2 else 1 if i < 4 else 2
		var a: Vector2 = paths[edge_index][0]
		var b: Vector2 = paths[edge_index][1]
		var centre := a.lerp(b,clampf((x-a.x)/(b.x-a.x),0.0,1.0))
		var anchors: Array[Vector2] = [centre]
		if i > 0:
			anchors.append(centre+Vector2(0,-35))
			anchors.append(centre+Vector2(0,35))
		clusters.append({"band":"near" if i < 2 else "middle" if i < 4 else "far",
			"node":1 if i < 2 else 2 if i < 4 else 3,"count":2 if i < 2 else 3,"anchors":anchors})
	var material_spawns: Array[Dictionary] = [
		{"p":nodes[4].p,"node":4,"band":"middle"},
		{"p":nodes[3].p+Vector2(70,55 if region == "pond" else -55),"node":3,"band":"far"}
	]
	# Bounds include every rendered cap, including the smaller side pocket.
	var low := Vector2(INF,INF)
	var high := Vector2(-INF,-INF)
	for node in nodes:
		low = low.min(node.p-Vector2.ONE*float(node.radius))
		high = high.max(node.p+Vector2.ONE*float(node.radius))
	var padding := Vector2.ONE*70.0
	return {"region":region,"nodes":nodes,"edges":edges,"paths":paths,"path_radii":path_radii,
		"corridor_radius":CORRIDOR_RADIUS,"clusters":clusters,"material_spawns":material_spawns,
		"bounds":Rect2(low-padding,high-low+padding*2.0)}

static func segment_distance(at: Vector2, a: Vector2, b: Vector2) -> float:
	var axis := b-a
	if axis.length_squared() <= 0.0001: return at.distance_to(a)
	var t := clampf((at-a).dot(axis)/axis.length_squared(),0.0,1.0)
	return at.distance_to(a+axis*t)

static func walkable(layout: Dictionary, at: Vector2, margin: float = BODY_RADIUS) -> bool:
	for node in layout.nodes:
		var radius: float = maxf(0.0,float(node.radius)-margin)
		if at.distance_squared_to(node.p) <= radius*radius: return true
	for index in layout.paths.size():
		var path: PackedVector2Array = layout.paths[index]
		var radius: float = maxf(0.0,float(layout.path_radii[index])-margin)
		for i in path.size()-1:
			if segment_distance(at,path[i],path[i+1]) <= radius: return true
	return false

static func move(layout: Dictionary, origin: Vector2, displacement: Vector2, margin: float = BODY_RADIUS) -> Vector2:
	if not walkable(layout,origin,margin): return origin
	var at := origin
	var steps := maxi(1,ceili(displacement.length()/6.0))
	var offset := displacement/float(steps)
	for i in steps:
		if walkable(layout,at+offset,margin):
			at += offset
			continue
		# Axis sliding keeps a held key useful against a boundary. A six-pixel
		# substep cannot jump the 16-pixel player clearance or a blocked gate.
		if walkable(layout,at+Vector2(offset.x,0),margin): at.x += offset.x
		if walkable(layout,at+Vector2(0,offset.y),margin): at.y += offset.y
	return at

static func node_at(layout: Dictionary, at: Vector2) -> int:
	var nearest := -1
	var distance := INF
	for node in layout.nodes:
		var d := at.distance_to(node.p)
		if d <= float(node.radius) and d < distance:
			nearest = int(node.id)
			distance = d
	return nearest

static func path_between(layout: Dictionary, a: int, b: int) -> PackedVector2Array:
	for i in layout.edges.size():
		var edge: Vector2i = layout.edges[i]
		if edge == Vector2i(a,b): return layout.paths[i].duplicate()
		if edge == Vector2i(b,a):
			var reverse: PackedVector2Array = layout.paths[i].duplicate()
			reverse.reverse()
			return reverse
	return PackedVector2Array()
