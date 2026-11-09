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
	for region in ["pond","violet"]:
		for state in ["sunny","rain","variant"]:
			verify(region,state)
	check(checks > 1000,"geometry corpus actually executed")
	print("GREYBOX_LAYOUT checks=%d failures=%d" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)

func verify(region: String, state: String) -> void:
	var layout: Dictionary = Layout.build(region,state)
	var label: String = region+"/"+state
	if not layout.has("nodes"):
		check(false,label+" build returned a valid layout")
		return
	check(layout.nodes.size() == 8,label+" eight spaces")
	check(layout.bounds.size.x > 2500 and layout.bounds.size.y > 1800,label+" exceeds a single viewport")
	check(layout.paths.size() == layout.edges.size(),label+" path-edge correspondence")
	var adjacency := {}
	for i in 8: adjacency[i] = []
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
	check(visited.size() == 8,label+" all nodes connected to entrance")
	for node in layout.nodes:
		check(Layout.walkable(layout,node.p),label+" node centre passable")
		check(Layout.node_at(layout,node.p) == node.id,label+" stable node identity")
	for i in layout.paths.size():
		var path: PackedVector2Array = layout.paths[i]
		var edge: Vector2i = layout.edges[i]
		check(path[0] == layout.nodes[edge.x].p and path[-1] == layout.nodes[edge.y].p,label+" endpoints match")
		var reverse := Layout.path_between(layout,edge.y,edge.x)
		check(reverse[0] == path[-1] and reverse[-1] == path[0],label+" reverse traversal")
		var at: Vector2 = path[0]
		for j in path.size()-1:
			var distance := path[j].distance_to(path[j+1])
			var count := maxi(1,ceili(distance/20.0))
			for sample in count+1:
				check(Layout.walkable(layout,path[j].lerp(path[j+1],float(sample)/float(count))),label+" corridor centreline")
			at = Layout.move(layout,at,path[j+1]-at)
			check(at.distance_to(path[j+1]) < 0.1,label+" swept movement reaches next waypoint")
	verify_disjoint_corridors(layout,label)
	# Closed variant bridge genuinely contains blocked space; it isn't merely
	# hidden from graph data while remaining traversable in the union geometry.
	var removed: Vector2i = Layout.REMOVED[region]
	var a: Vector2 = layout.nodes[removed.x].p
	var b: Vector2 = layout.nodes[removed.y].p
	if state == "variant":
		check(Layout.path_between(layout,removed.x,removed.y).is_empty(),label+" removed connection absent")
		check(not Layout.walkable(layout,a.lerp(b,0.5)),label+" removed bridge physically blocked")
		var reached := Layout.move(layout,a,b-a)
		check(reached.distance_to(b) > 160.0,label+" long displacement cannot tunnel through removed bridge")
		check(not Layout.path_between(layout,2,4).is_empty(),label+" alternate connection present")
	else:
		check(Layout.walkable(layout,a.lerp(b,0.5)),label+" base bridge open")
	# Any attempted escape into the vegetation must remain inside the same
	# geometry used for visible walkable paths, including oversized dash steps.
	var entry: Vector2 = layout.nodes[0].p
	var escaped := Layout.move(layout,entry,Vector2(-2000,1000))
	check(Layout.walkable(layout,escaped),label+" huge dash stays within footprint")
	check(escaped.distance_to(entry) < 500.0,label+" vegetation stops outbound dash")
	var protected := 0
	var exposed := 0
	for edge in Layout.SHELTER_EDGES[region]:
		var start: Vector2 = layout.nodes[edge.x].p
		var end: Vector2 = layout.nodes[edge.y].p
		for i in 101:
			if Layout.sheltered(layout,start.lerp(end,float(i)/100.0)): protected += 1
			else: exposed += 1
	check(protected > 0 and exposed > 0,label+" shelter segments include real exposed gaps")

func verify_disjoint_corridors(layout: Dictionary, label: String) -> void:
	# Two branches that have no common graph node must not become connected
	# through overlapping path capsules. This checks geometry, not graph BFS.
	for i in layout.edges.size():
		var first: Vector2i = layout.edges[i]
		for j in range(i+1,layout.edges.size()):
			var second: Vector2i = layout.edges[j]
			if first.x in [second.x,second.y] or first.y in [second.x,second.y]: continue
			var a: PackedVector2Array = layout.paths[i]
			var b: PackedVector2Array = layout.paths[j]
			var nearest := INF
			for k in a.size()-1:
				var samples := maxi(1,ceili(a[k].distance_to(a[k+1])/12.0))
				for sample in samples+1:
					var at := a[k].lerp(a[k+1],float(sample)/float(samples))
					for n in b.size()-1:
						nearest = minf(nearest,Layout.segment_distance(at,b[n],b[n+1]))
			check(nearest > 2.0*float(layout.corridor_radius)+12.0,label+" unrelated corridors stay separate")
