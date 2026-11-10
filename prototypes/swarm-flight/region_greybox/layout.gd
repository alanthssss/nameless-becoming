extends RefCounted
## Greybox geometry for the approved 2026-11-09 interior diagrams.
## Traversable space is the union of visible room discs and path capsules.
## Everything outside that union is a visible flight-height vegetation block,
## not water or an invisible wall. Units are game pixels, not source-map metres.
const BODY_RADIUS := 16.0
const DEFAULT_SCALE := 3.2
const ROOM_RADIUS := 180.0
const CORRIDOR_RADIUS := 90.0
const RAW_NODES := {
	"pond": [
		[130,690,"入口湾"], [330,600,"芦苇岔口"], [180,400,"内湾花丛"],
		[450,365,"荷叶棚"], [690,205,"远岸花源"], [790,405,"岸边根拱"],
		[620,670,"回岸岔口"], [870,590,"材料侧湾"]
	],
	"violet": [
		[130,690,"坡脚入口"], [335,620,"花带岔口"], [320,405,"露天长花带"],
		[640,640,"叶棚小径"], [760,425,"背坡转折"], [680,195,"深处花圃"],
		[875,290,"根边材料窝"], [185,205,"回坡缺口"]
	]
}
const RAW_EDGES := {
	"pond": [[0,1],[1,2],[2,3],[3,1],[3,4],[4,5],[5,6],[6,1],[5,7],[7,6]],
	"violet": [[0,1],[1,2],[2,3],[3,1],[2,5],[3,4],[4,5],[5,7],[7,2],[4,6],[6,5]]
}
const REMOVED := {"pond": Vector2i(3,4), "violet": Vector2i(2,5)}
const SHELTER_EDGES := {
	"pond": [Vector2i(1,6),Vector2i(6,5),Vector2i(5,4)],
	"violet": [Vector2i(1,3),Vector2i(3,4),Vector2i(4,5)]
}

static func build(region: String, state: String, scale: float = DEFAULT_SCALE) -> Dictionary:
	assert(region in RAW_NODES, "Unknown greybox region")
	assert(state in ["sunny","rain","variant"], "Unknown greybox state")
	assert(scale >= 2.5, "Room and corridor clearances require scale >= 2.5")
	var nodes: Array[Dictionary] = []
	for i in RAW_NODES[region].size():
		var raw: Array = RAW_NODES[region][i]
		nodes.append({"id":i,"name":str(raw[2]),"p":_position(Vector2(float(raw[0]),float(raw[1])),scale),"radius":ROOM_RADIUS})
	var edges: Array[Vector2i] = []
	var paths: Array[PackedVector2Array] = []
	for pair in RAW_EDGES[region]:
		var edge := Vector2i(int(pair[0]),int(pair[1]))
		if state == "variant" and edge == REMOVED[region]: continue
		edges.append(edge)
		paths.append(PackedVector2Array([nodes[edge.x].p,nodes[edge.y].p]))
	if state == "variant":
		edges.append(Vector2i(2,4))
		if region == "pond":
			# An outer reed passage: a straight 2–4 chord would cut through
			# the near loop and silently create junctions absent from the diagram.
			var outer := PackedVector2Array([nodes[2].p])
			for raw in [Vector2(145,250),Vector2(260,150),Vector2(455,130)]:
				outer.append(_position(raw,scale))
			outer.append(nodes[4].p)
			paths.append(outer)
		else:
			paths.append(PackedVector2Array([nodes[2].p,nodes[4].p]))
	var shelters: Array[Dictionary] = []
	# Leaf patches are present in all weather. Rain only changes their utility.
	# Each chain cell covers 88% of its centreline; visible gaps stay exposed.
	# This is measured greybox geometry, not an energy/velocity adjustment.
	var covered_edges: Array = SHELTER_EDGES[region].duplicate()
	covered_edges.append(Vector2i(0,1))
	for edge in covered_edges:
		var a: Vector2 = nodes[edge.x].p
		var b: Vector2 = nodes[edge.y].p
		var length := a.distance_to(b)
		var count := maxi(1,ceili(length/330.0))
		var patch_radius := minf(150.0,length/float(count)*0.44)
		for i in count:
			var t := (float(i)+0.5)/float(count)
			shelters.append({"p":a.lerp(b,t),"radius":patch_radius})
	# Sheltered decision/collection nodes make a short first rainy outing
	# possible. No patch restores stamina and exposed direct links stay open.
	var covered_nodes: Array = [0,1,2,3,4,5,6] if region == "pond" else [0,1,2,3,4,5]
	for id in covered_nodes:
		shelters.append({"p":nodes[id].p,"radius":150.0})
	var low := Vector2(INF,INF)
	var high := Vector2(-INF,-INF)
	for path in paths:
		for at in path:
			low = low.min(at)
			high = high.max(at)
	var padding := Vector2.ONE*(ROOM_RADIUS+80.0)
	return {"region":region,"state":state,"scale":scale,"nodes":nodes,"edges":edges,
		"paths":paths,"corridor_radius":CORRIDOR_RADIUS,"shelters":shelters,
		"bounds":Rect2(low-padding,high-low+padding*2.0)}

static func _position(raw: Vector2, scale: float) -> Vector2:
	return (raw-Vector2(100,110))*scale+Vector2(260,260)

static func segment_distance(at: Vector2, a: Vector2, b: Vector2) -> float:
	var axis := b-a
	if axis.length_squared() <= 0.0001: return at.distance_to(a)
	var t := clampf((at-a).dot(axis)/axis.length_squared(),0.0,1.0)
	return at.distance_to(a+axis*t)

static func walkable(layout: Dictionary, at: Vector2, margin: float = BODY_RADIUS) -> bool:
	for node in layout.nodes:
		var radius: float = maxf(0.0,float(node.radius)-margin)
		if at.distance_squared_to(node.p) <= radius*radius: return true
	var radius: float = maxf(0.0,float(layout.corridor_radius)-margin)
	for path in layout.paths:
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

static func sheltered(layout: Dictionary, at: Vector2) -> bool:
	for shelter in layout.shelters:
		if at.distance_squared_to(shelter.p) <= float(shelter.radius)*float(shelter.radius): return true
	return false

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
