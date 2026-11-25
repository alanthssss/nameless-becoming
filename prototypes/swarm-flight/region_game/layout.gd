extends RefCounted
## Authored natural shores around the accepted five-node collecting skeleton.
## `coast` is shared by presentation and movement; dressing never defines walls.
const Skeleton = preload("res://region_greybox/layout.gd")
const SPACING := 22.0

const GROUND_SCALE := 1.10
const FIELD_ZOOM := 0.91
# The painted 176×300 husk is registered at its seed socket. Both field
# placement and drawing use this span, including the different host sizes.
const FIBER_SOCKET := Vector2(.77,.16)
const FIBER_SPAN := Vector2(176,300)*(118.0/300.0)
const WEST_SHORE := 32.0
const WEST_JOIN := 190.0
const VIEWPORT := Vector2(1280,800)
const PLATE := Rect2(Vector2(0,-100)*GROUND_SCALE,Vector2(2680,1550)*GROUND_SCALE)

static func material_scale(band: String) -> float:
	return .84 if band == "near" else 1.10 if band == "far" else 1.0

static func build(region: String, expanded := true) -> Dictionary:
	var layout: Dictionary = Skeleton.build(region)
	var pieces: Array[PackedVector2Array] = []
	for i in layout.paths.size():
		var path: PackedVector2Array = layout.paths[i]
		pieces.append(_capsule(path[0],path[-1],float(layout.path_radii[i])))
	for node in layout.nodes: pieces.append(_circle(node.p,float(node.radius)))
	var outline: PackedVector2Array = pieces[0]
	for i in range(1,pieces.size()):
		var merged := Geometry2D.merge_polygons(outline,pieces[i])
		assert(merged.size() == 1,"The collecting skeleton must remain one surface")
		outline = merged[0]
	# Equal-distance samples remove the original cap/straight-segment partition.
	outline = _resample(outline,SPACING)
	for _pass_index in 5: outline = _smooth(outline)
	var natural := PackedVector2Array()
	var phase := .35 if region == "pond" else 2.1
	var middle: Vector2 = layout.nodes[2].p
	var pocket: Vector2 = layout.nodes[4].p
	var direction := signf(pocket.y-middle.y)
	for i in outline.size():
		var point: Vector2 = outline[i]
		var tangent := (outline[(i+1)%outline.size()]-outline[(i-1+outline.size())%outline.size()]).normalized()
		var outward := tangent.orthogonal()
		if Geometry2D.is_point_in_polygon(point+outward*3,outline): outward = -outward
		# Broad bends change the width; smaller, non-periodic bends form shallow
		# bays. This is fixed authored geometry, independent of visit/resource seed.
		var reach := 45.0*sin(point.x*.0061+phase)
		reach += 25.0*sin(point.x*.0113+point.y*.0047+phase*1.7)
		reach += 10.0*sin(point.y*.0201-point.x*.0028)
		# The short pocket keeps comfortable clearance around its two targets.
		if (point.y-middle.y)*direction > 120 and absf(point.x-pocket.x)<240:
			reach = clampf(reach,-15,30)
		# Authored small bay / soft projecting shoulder, not an extra route.
		var bay := Vector2(1120,380) if region == "pond" else Vector2(1070,980)
		var shoulder := Vector2(1860,880) if region == "pond" else Vector2(1940,450)
		reach -= 32.0*exp(-point.distance_squared_to(bay)/42000.0)
		reach += 27.0*exp(-point.distance_squared_to(shoulder)/52000.0)
		natural.append(point+outward*reach)
	for _pass_index in 4: natural = _smooth(natural)
	# The final samples themselves, not an independently smoothed display, are
	# authoritative for collision, endpoint access, and the visible grass edge.
	layout.coast = _resample(natural,SPACING)
	layout.geometry_version = 2
	var low := Vector2(INF,INF)
	var high := Vector2(-INF,-INF)
	for point in layout.coast:
		low = low.min(point)
		high = high.max(point)
	layout.bounds = Rect2(low-Vector2.ONE*70,high-low+Vector2.ONE*140)
	return expand(layout) if expanded else layout

static func expand(layout: Dictionary, frame_west := true) -> Dictionary:
	for node in layout.nodes:
		node.p *= GROUND_SCALE
		node.radius *= GROUND_SCALE
	for i in layout.paths.size():
		var path: PackedVector2Array = layout.paths[i]
		for j in path.size(): path[j] *= GROUND_SCALE
		layout.paths[i] = path
		layout.path_radii[i] *= GROUND_SCALE
	for cluster in layout.clusters:
		for i in cluster.anchors.size(): cluster.anchors[i] *= GROUND_SCALE
	for item in layout.material_spawns: item.p *= GROUND_SCALE
	for i in layout.coast.size(): layout.coast[i] *= GROUND_SCALE
	layout.corridor_radius *= GROUND_SCALE
	layout.bounds = Rect2(layout.bounds.position*GROUND_SCALE,layout.bounds.size*GROUND_SCALE)
	if frame_west:
		# Fit just the western curve beside the entrance into the painted frame.
		# Keep its shape and its join to the original path, including the curved ends.
		var original_left := INF
		for point: Vector2 in layout.coast:
			original_left = minf(original_left,point.x)
		for i in layout.coast.size():
			var point: Vector2 = layout.coast[i]
			if point.x < WEST_JOIN:
				point.x = remap(point.x,original_left,WEST_JOIN,WEST_SHORE,WEST_JOIN)
				layout.coast[i] = point
		var previous_end: Vector2 = layout.bounds.end
		layout.bounds.position.x = WEST_SHORE-70.0*GROUND_SCALE
		layout.bounds.end = previous_end
		layout.geometry_version = 3
	return layout

static func _circle(at: Vector2,radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 64: points.append(at+Vector2.from_angle(TAU*float(i)/64.0)*radius)
	return points

static func _capsule(a: Vector2,b: Vector2,radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var angle := (b-a).angle()
	for i in 33: points.append(b+Vector2.from_angle(angle-PI*.5+PI*float(i)/32)*radius)
	for i in 33: points.append(a+Vector2.from_angle(angle+PI*.5+PI*float(i)/32)*radius)
	return points

static func _smooth(points: PackedVector2Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for i in points.size():
		result.append(points[i]*.5+(points[(i-1+points.size())%points.size()]+points[(i+1)%points.size()])*.25)
	return result

static func _resample(points: PackedVector2Array,spacing: float) -> PackedVector2Array:
	var lengths: Array[float] = []
	var perimeter := 0.0
	for i in points.size():
		var length := points[i].distance_to(points[(i+1)%points.size()])
		lengths.append(length)
		perimeter += length
	var count := maxi(3,ceili(perimeter/spacing))
	var output := PackedVector2Array()
	var edge := 0
	var passed := 0.0
	for i in count:
		var distance := perimeter*float(i)/float(count)
		while edge<lengths.size()-1 and passed+lengths[edge]<distance:
			passed += lengths[edge]
			edge += 1
		var ratio := (distance-passed)/maxf(lengths[edge],.0001)
		output.append(points[edge].lerp(points[(edge+1)%points.size()],ratio))
	return output
