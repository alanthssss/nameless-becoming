extends RefCounted
## Editable contour traced from revision-atlas.png LEAF alpha >= .6, epsilon 2 source px.
## Standard static green leaf only. Rendering keeps the original hand-painted atlas.
const SOURCE_RECT := Rect2(19,822,592,251)
const HEIGHT := 95.0
const TOP_OFFSET := -161.0
const OUTLINE := [
	Vector2(0.44932432,0.00796813),
	Vector2(0.39864865,0.01992032),
	Vector2(0.38513514,0.01992032),
	Vector2(0.33277027,0.04780876),
	Vector2(0.32432432,0.04780876),
	Vector2(0.22297297,0.12350598),
	Vector2(0.21790541,0.12350598),
	Vector2(0.18750000,0.15936255),
	Vector2(0.18412162,0.15936255),
	Vector2(0.14864865,0.21912351),
	Vector2(0.14527027,0.21912351),
	Vector2(0.12331081,0.27490040),
	Vector2(0.12162162,0.27490040),
	Vector2(0.10641892,0.33067729),
	Vector2(0.10472973,0.33067729),
	Vector2(0.07432432,0.49003984),
	Vector2(0.07432432,0.49800797),
	Vector2(0.06587838,0.49800797),
	Vector2(0.06081081,0.48207171),
	Vector2(0.05912162,0.48207171),
	Vector2(0.06587838,0.44223108),
	Vector2(0.06756757,0.44223108),
	Vector2(0.06756757,0.41035857),
	Vector2(0.06250000,0.39840637),
	Vector2(0.06250000,0.39043825),
	Vector2(0.05574324,0.38247012),
	Vector2(0.04054054,0.38247012),
	Vector2(0.03209459,0.39442231),
	Vector2(0.02871622,0.39442231),
	Vector2(0.01182432,0.44223108),
	Vector2(0.01013514,0.44223108),
	Vector2(0.00168919,0.50199203),
	Vector2(0.00168919,0.56972112),
	Vector2(0.01013514,0.62151394),
	Vector2(0.01013514,0.62948207),
	Vector2(0.03040541,0.68525896),
	Vector2(0.03040541,0.68924303),
	Vector2(0.05912162,0.70916335),
	Vector2(0.05912162,0.71314741),
	Vector2(0.07939189,0.70119522),
	Vector2(0.08445946,0.70119522),
	Vector2(0.09797297,0.67729084),
	Vector2(0.10135135,0.67729084),
	Vector2(0.13513514,0.59362550),
	Vector2(0.13513514,0.58964143),
	Vector2(0.14864865,0.57370518),
	Vector2(0.14864865,0.56972112),
	Vector2(0.18918919,0.53784861),
	Vector2(0.18918919,0.53386454),
	Vector2(0.26182432,0.50199203),
	Vector2(0.30067568,0.50199203),
	Vector2(0.33614865,0.51792829),
	Vector2(0.34290541,0.51792829),
	Vector2(0.38344595,0.55776892),
	Vector2(0.38851351,0.55776892),
	Vector2(0.45101351,0.64940239),
	Vector2(0.45439189,0.64940239),
	Vector2(0.53547297,0.79282869),
	Vector2(0.53547297,0.79681275),
	Vector2(0.60135135,0.84860558),
	Vector2(0.60135135,0.85258964),
	Vector2(0.74493243,0.88844622),
	Vector2(0.76689189,0.88844622),
	Vector2(0.90371622,0.93625498),
	Vector2(0.91891892,0.93625498),
	Vector2(0.93918919,0.95219124),
	Vector2(0.94425676,0.95219124),
	Vector2(0.96790541,0.98804781),
	Vector2(0.96790541,0.99203187),
	Vector2(0.97972973,0.99203187),
	Vector2(0.98648649,0.97609562),
	Vector2(0.98817568,0.97609562),
	Vector2(0.99493243,0.94422311),
	Vector2(0.99662162,0.94422311),
	Vector2(0.99831081,0.90438247),
	Vector2(1.00000000,0.90438247),
	Vector2(0.99324324,0.79282869),
	Vector2(0.99324324,0.77689243),
	Vector2(0.97804054,0.68127490),
	Vector2(0.97804054,0.66932271),
	Vector2(0.95945946,0.58565737),
	Vector2(0.95945946,0.57768924),
	Vector2(0.93074324,0.48605578),
	Vector2(0.93074324,0.47808765),
	Vector2(0.91047297,0.43027888),
	Vector2(0.91047297,0.42231076),
	Vector2(0.83952703,0.28286853),
	Vector2(0.83952703,0.27888446),
	Vector2(0.76858108,0.18725100),
	Vector2(0.76858108,0.18326693),
	Vector2(0.70945946,0.13147410),
	Vector2(0.70945946,0.12749004),
	Vector2(0.63006757,0.08366534),
	Vector2(0.62331081,0.08366534),
	Vector2(0.54898649,0.02788845),
	Vector2(0.54898649,0.02390438),
	Vector2(0.51013514,0.01195219),
	Vector2(0.51013514,0.00796813),
	Vector2(0.44932432,0.00398406),
]

static func rect(leaf: Dictionary) -> Rect2:
	var half: float = leaf.get("half_width",180.0)
	return Rect2(leaf.pos+Vector2(-half-10,TOP_OFFSET),Vector2(half*2+20,HEIGHT))

static func polygon(leaf: Dictionary) -> PackedVector2Array:
	var r := rect(leaf)
	var result := PackedVector2Array()
	for point in OUTLINE: result.append(r.position+point*r.size)
	return result

static func top_at(x: float, leaf: Dictionary) -> float:
	var points := polygon(leaf)
	var top := INF
	for i in points.size():
		var a: Vector2 = points[i]
		var b: Vector2 = points[(i+1)%points.size()]
		if x < minf(a.x,b.x) or x > maxf(a.x,b.x): continue
		if absf(a.x-b.x)<0.0001:
			top=minf(top,minf(a.y,b.y))
		else:
			top=minf(top,lerpf(a.y,b.y,(x-a.x)/(b.x-a.x)))
	return top

static func intercepts(before: Vector2, after: Vector2, leaf: Dictionary) -> bool:
	var points := polygon(leaf)
	if Geometry2D.is_point_in_polygon(after,points): return true
	for i in points.size():
		if Geometry2D.segment_intersects_segment(before,after,points[i],points[(i+1)%points.size()]) != null: return true
	return false

static func clear_disk(point: Vector2, radius: float, points: PackedVector2Array) -> bool:
	if Geometry2D.is_point_in_polygon(point,points): return false
	for i in points.size():
		if point.distance_to(Geometry2D.get_closest_point_to_segment(point,points[i],points[(i+1)%points.size()]))<radius-0.001: return false
	return true

static func contact(point: Vector2, radius: float, leaf: Dictionary) -> Dictionary:
	if not rect(leaf).grow(radius).has_point(point): return {}
	var points := polygon(leaf)
	var inside := Geometry2D.is_point_in_polygon(point,points)
	var nearest := Vector2.ZERO
	var distance := INF
	var edge := Vector2.ZERO
	for i in points.size():
		var a: Vector2 = points[i]
		var b: Vector2 = points[(i+1)%points.size()]
		var candidate := Geometry2D.get_closest_point_to_segment(point,a,b)
		var d := point.distance_to(candidate)
		if d<distance:
			distance=d
			nearest=candidate
			edge=b-a
	if not inside and distance>=radius: return {}
	var normal := (nearest-point if inside else point-nearest).normalized()
	if normal.is_zero_approx():
		normal=edge.orthogonal().normalized()
		if Geometry2D.is_point_in_polygon(nearest+normal*0.1,points): normal=-normal
	var resolved := nearest+normal*(radius+0.05)
	if not clear_disk(resolved,radius,points):
		# The curled tip is concave: a nearest-edge push can enter another edge.
		# Choose a fully clear candidate; bounding-box candidates guarantee escape.
		var box := rect(leaf).grow(radius+0.05)
		var candidates: Array[Vector2] = [Vector2(point.x,box.position.y),Vector2(point.x,box.end.y),Vector2(box.position.x,point.y),Vector2(box.end.x,point.y)]
		for i in points.size():
			var a := points[i]
			var b := points[(i+1)%points.size()]
			var foot := Geometry2D.get_closest_point_to_segment(point,a,b)
			var n := (b-a).orthogonal().normalized()
			candidates.append(foot+n*(radius+0.05))
			candidates.append(foot-n*(radius+0.05))
		var best := INF
		for candidate in candidates:
			var d := point.distance_squared_to(candidate)
			if d<best and clear_disk(candidate,radius,points):
				best=d
				resolved=candidate
		normal=(resolved-point).normalized()
	return {"position":resolved,"normal":normal}
