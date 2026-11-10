extends SceneTree
const Layout = preload("res://region_greybox/layout.gd")
var checks := 0
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func _init() -> void:
	for region in ["pond","violet"]: verify(region)
	print("GREYBOX_LAYOUT checks=%d failures=%d" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)

func verify(region: String) -> void:
	var layout: Dictionary = Layout.build(region)
	check(layout == Layout.build(region),region+" repeated visits have fixed geometry/anchors")
	check(not layout.has("state") and not layout.has("shelters"),region+" no weather/layout variants")
	check(layout.nodes.size() == 5 and layout.edges.size() == 4,region+" one main direction plus one pocket")
	check(layout.paths.size() == layout.edges.size() and layout.path_radii.size() == layout.paths.size(),region+" visible paths have collision radii")
	var adjacency := {}
	for node in layout.nodes: adjacency[int(node.id)] = []
	for edge in layout.edges:
		adjacency[edge.x].append(edge.y)
		adjacency[edge.y].append(edge.x)
	var visited: Array[int] = [0]
	var todo: Array[int] = [0]
	while not todo.is_empty():
		var current: int = todo.pop_back()
		for neighbor in adjacency[current]:
			if neighbor not in visited:
				visited.append(neighbor)
				todo.append(neighbor)
	check(visited.size() == 5 and layout.edges.size() == visited.size()-1,region+" connected tree without loops")
	check(adjacency[0] == [1] and adjacency[1] == [0,2] and adjacency[2] == [1,3,4],region+" clear inward direction and one middle branch")
	check(adjacency[3] == [2] and adjacency[4] == [2],region+" far target and pocket are returnable dead ends")
	var main_length := 0.0
	for i in 3:
		main_length += layout.nodes[i].p.distance_to(layout.nodes[i+1].p)
	check(main_length >= 1600.0 and main_length <= 2200.0,region+" proposed 1600–2200px inward distance")
	var pocket_length: float = layout.nodes[2].p.distance_to(layout.nodes[4].p)
	check(pocket_length/230.0 >= 1.0 and pocket_length/230.0 <= 2.0,region+" pocket only 1–2 seconds aside")
	check(layout.bounds.size.x > 2000,region+" main extent requires camera travel")
	for node in layout.nodes:
		check(Layout.walkable(layout,node.p),region+" node centre passable")
		check(Layout.node_at(layout,node.p) == node.id,region+" stable location identity")
		check(layout.bounds.encloses(Rect2(node.p-Vector2.ONE*node.radius,Vector2.ONE*node.radius*2)),region+" bounds include rendered room")
	for i in layout.paths.size():
		var path: PackedVector2Array = layout.paths[i]
		var edge: Vector2i = layout.edges[i]
		var radius: float = layout.path_radii[i]
		check(path[0] == layout.nodes[edge.x].p and path[-1] == layout.nodes[edge.y].p,region+" endpoints meet visible nodes")
		var reverse := Layout.path_between(layout,edge.y,edge.x)
		check(reverse[0] == path[-1] and reverse[-1] == path[0],region+" return follows same path")
		if i < 3: check(radius*2 >= 450 and radius*2 <= 700,region+" broad collecting ground")
		var normal := (path[1]-path[0]).normalized().orthogonal()
		for offset in [-radius*0.65,0.0,radius*0.65]:
			var start: Vector2 = path[0]+normal*float(offset)
			var end: Vector2 = path[1]+normal*float(offset)
			var count := ceili(start.distance_to(end)/25.0)
			for sample in count+1:
				check(Layout.walkable(layout,start.lerp(end,float(sample)/count)),region+" broad ordinary-flight lane")
			var reached := Layout.move(layout,start,end-start)
			check(reached.distance_to(end) < 0.1,region+" swept movement traverses broad lane")
		# At the middle of each main segment the visible outer edge is solid,
		# not a hidden bypass outside the same capsule used for rendering.
		if i < 3:
			for direction in [-1.0,1.0]:
				var outside: Vector2 = path[0].lerp(path[1],0.5)+normal*(radius+65.0)*direction
				check(not Layout.walkable(layout,outside),region+" vegetation blocks space outside drawn main surface")
	verify_disjoint_corridors(layout,region)
	verify_supply_anchors(layout,region)
	var entry: Vector2 = layout.nodes[0].p
	var stopped := Layout.move(layout,entry,Vector2(-2000,0))
	check(Layout.walkable(layout,stopped),region+" oversized dash remains inside geometry")
	check(stopped.x >= entry.x-Layout.ROOM_RADIUS,region+" vegetation stops outward dash")

func verify_supply_anchors(layout: Dictionary, label: String) -> void:
	check(layout.clusters.size() == 12,label+" twelve closely spaced flower clusters")
	var counts := {"near":0,"middle":0,"far":0}
	for i in layout.clusters.size():
		var cluster: Dictionary = layout.clusters[i]
		counts[cluster.band] += int(cluster.count)
		check(not cluster.anchors.is_empty(),label+" each cluster has an approved anchor")
		if i == 0:
			check(cluster.anchors.size() == 1,label+" first flowers stay predictable")
			var entry: Vector2 = layout.nodes[0].p
			check(entry.distance_to(cluster.anchors[0]) < 400.0 and entry.distance_to(cluster.anchors[0]) > 125.0,label+" first flower visible beside entry")
		else:
			check(cluster.anchors.size() > 1,label+" later clusters permit small position changes")
		for anchor in cluster.anchors:
			# All proposed 45px flower offsets plus collection/body clearance
			# remain in the same visible geometry, including anchor extremes.
			for angle in 12:
				var at: Vector2 = anchor+Vector2.from_angle(float(angle)/12.0*TAU)*45.0
				check(Layout.walkable(layout,at,Layout.BODY_RADIUS+45.0),label+" flower offset has approach clearance")
			if i > 0:
				for previous in layout.clusters[i-1].anchors:
					var seconds: float = previous.distance_to(anchor)/230.0
					check(seconds >= 0.70 and seconds <= 1.05,label+" successive clusters stay roughly 170–190px apart")
	check(counts == {"near":12,"middle":12,"far":12},label+" 36 flower sites span all three bands")
	check(layout.material_spawns.size() == 6,label+" six distributed material habitats")
	check(layout.material_spawns[0].node == 1 and layout.material_spawns[1].node == 2 and layout.material_spawns[2].node == 4 and layout.material_spawns[3].node == 4 and layout.material_spawns[4].node == 3 and layout.material_spawns[5].node == 3,label+" near/middle materials plus two branch and two far sites")
	for item in layout.material_spawns:
		for angle in 16:
			var approach: Vector2 = item.p+Vector2.from_angle(float(angle)/16.0*TAU)*70.0
			check(Layout.walkable(layout,approach),label+" material can be approached for wing action")
		check(Layout.move(layout,layout.nodes[item.node].p,item.p-layout.nodes[item.node].p).distance_to(item.p)<0.1,label+" material pickup reachable")

func verify_disjoint_corridors(layout: Dictionary, label: String) -> void:
	for i in layout.edges.size():
		var first: Vector2i = layout.edges[i]
		for j in range(i+1,layout.edges.size()):
			var second: Vector2i = layout.edges[j]
			if first.x in [second.x,second.y] or first.y in [second.x,second.y]: continue
			var a: PackedVector2Array = layout.paths[i]
			var b: PackedVector2Array = layout.paths[j]
			var nearest := INF
			var samples := ceili(a[0].distance_to(a[1])/15.0)
			for sample in samples+1:
				nearest = minf(nearest,Layout.segment_distance(a[0].lerp(a[1],float(sample)/samples),b[0],b[1]))
			check(nearest > float(layout.path_radii[i])+float(layout.path_radii[j])+12.0,label+" unrelated path capsules do not create a hidden bypass")
