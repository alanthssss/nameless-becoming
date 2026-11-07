extends RefCounted
## Known-route navigation for developer probes only; all motion remains ordinary input.
const Map = preload("res://nectar_map.gd")
static func points(area: String,origin: Vector2,target: Vector2) -> Array[Vector2]:
	# Known pilot uses visible clear corners of the thicket, never teleports.
	var departure := Map.safe_point(area,origin,40.0)
	target = Map.safe_point(area,target,40.0)
	var prelude: Array[Vector2] = []
	if not departure.is_equal_approx(origin): prelude.append(departure)
	origin = departure
	var legs: Array[Vector2] = []
	if area == "meadow" and minf(target.x,origin.x)<2920 and maxf(target.x,origin.x)>2600 and minf(target.y,origin.y)<640:
		legs.append(Vector2(origin.x,645))
		legs.append(Vector2(target.x,645))
	legs.append(target)
	var result: Array[Vector2] = prelude
	var at := origin
	for leg in legs:
		if not clear_flight(area,at,leg):
			var corners: Array = [Vector2(735,235),Vector2(1225,235),Vector2(735,575),Vector2(1225,575)] if area == "pond" else [Vector2(2125,300),Vector2(2515,300),Vector2(2125,585),Vector2(2515,585)]
			var nodes: Array[Vector2] = [at,leg]
			nodes.append_array(corners)
			var costs := [0.0,INF,INF,INF,INF,INF]
			var previous := [-1,-1,-1,-1,-1,-1]
			var done: Array[int] = []
			for step in nodes.size():
				var best := -1
				for i in nodes.size():
					if i not in done and (best<0 or costs[i]<costs[best]): best = i
				if best<0 or is_inf(costs[best]): break
				done.append(best)
				for j in nodes.size():
					if j in done or not clear_flight(area,nodes[best],nodes[j]): continue
					var cost: float = costs[best]+nodes[best].distance_to(nodes[j])
					if cost<costs[j]:
						costs[j] = cost
						previous[j] = best
			var backwards: Array[Vector2] = []
			var cursor: int = previous[1]
			while cursor>0:
				backwards.push_front(nodes[cursor])
				cursor = previous[cursor]
			result.append_array(backwards)
		result.append(leg)
		at = leg
	return result


static func clear_flight(area: String,a: Vector2,b: Vector2) -> bool:
	# Keyboard pilot moves at 45 degrees then along one axis; that is NOT a
	# straight chord. Check both actual legs before choosing a known route.
	var delta := b-a
	var diagonal := minf(absf(delta.x),absf(delta.y))
	var bend := a+Vector2(signf(delta.x),signf(delta.y))*diagonal
	return Map.clear_segment(area,a,bend,36.0) and Map.clear_segment(area,bend,b,36.0)
