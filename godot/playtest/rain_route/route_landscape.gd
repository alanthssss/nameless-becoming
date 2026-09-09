extends Node2D

const Model := preload("res://playtest/rain_route/route_model.gd")
const INK := Color("364940")
const PAPER := Color("eee9d7")
const GREEN := Color("a6b798")
const GOLD := Color("e6bb62")
var route: Node2D

func line(points: Array, color := INK, width := 2.0) -> void:
	draw_polyline(PackedVector2Array(points), color, width, true)

func shape(points: Array, color: Color, width := 2.0) -> void:
	var polygon := PackedVector2Array(points)
	draw_colored_polygon(polygon, color)
	polygon.append(polygon[0])
	draw_polyline(polygon, INK, width, true)

func oval(center: Vector2, radius: Vector2, color: Color, outline := true) -> void:
	var points: Array = []
	for i in range(40):
		points.append(center + Vector2(cos(i * TAU / 40), sin(i * TAU / 40)) * radius)
	if outline:
		shape(points, color)
	else:
		draw_colored_polygon(PackedVector2Array(points), color)

func label(point: Vector2, value: String, size := 24) -> void:
	draw_string(route.font, point, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, INK)

func leaf(center: Vector2, size: float, angle: float, tint: Color) -> void:
	var points: Array = []
	for i in range(33):
		var t := i / 32.0 * TAU
		var local := Vector2(cos(t) * size, sin(t) * size * 0.45 * (0.8 + 0.2 * sin(t)))
		points.append(center + local.rotated(angle))
	shape(points, tint)
	var stem := Vector2(size, 0).rotated(angle)
	line([center - stem, center + stem], INK, 1.6)
	for i in range(1, 6):
		var x := -size + i * size / 3.0
		var h := sin(i * PI / 6) * size * 0.32
		for sign_value in [-1, 1]:
			line([center + Vector2(x - size * 0.20, 0).rotated(angle), center + Vector2(x, h * sign_value).rotated(angle)], Color("647c65"), 1.1)

func canopy(center: Vector2, index: int, built := false) -> void:
	oval(center + Vector2(12, 35), Vector2(218, 195), Color("738765", 0.12), false)
	var near: bool = route.model.position.distance_to(center) < 245
	var colors := [Color("b2c3a0"), Color("9fb598"), Color("c1cbaa")]
	for i in range(5):
		var angle := i * TAU / 5 + index * 0.53
		var c: Color = colors[(index + i) % 3]
		if near:
			c = c.lightened(0.24)
		var p := center + Vector2.from_angle(angle) * 89
		leaf(p, 139 + (i % 2) * 9, angle + sin(route.visual_time * 1.1 + index) * 0.025, c)
	if built:
		line([center + Vector2(-90, 105), center + Vector2(-80, -50), center + Vector2(80, -50), center + Vector2(90, 105)], INK, 5)
		label(center + Vector2(-42, 90), "新叶台", 20)

func bee(point: Vector2, heading: float, scale_value := 1.0, waiting := false) -> void:
	var bob: float = sin(route.visual_time * 8 + point.x) * 2.0
	oval(point + Vector2(0, 18), Vector2(22, 8) * scale_value, Color("909b85", 0.25), false)
	draw_set_transform(point + Vector2(0, bob), heading, Vector2.ONE * scale_value)
	var flutter: float = 0.85 + sin(route.visual_time * 42) * 0.15
	oval(Vector2(-3, -15), Vector2(17, 10 * flutter), Color("faf8e9"))
	oval(Vector2(-3, 15), Vector2(17, 10 * flutter), Color("faf8e9"))
	oval(Vector2(-5, 0), Vector2(22, 13), GOLD if not waiting else Color("b8b5a1"))
	for x in [-16, -6, 4]:
		line([Vector2(x, -10), Vector2(x - 2, 0), Vector2(x, 10)], INK, 4)
	oval(Vector2(16, 0), Vector2(12, 11), GOLD)
	draw_circle(Vector2(20, -5), 2.5, INK)
	draw_circle(Vector2(20, 5), 2.5, INK)
	line([Vector2(22, -7), Vector2(30, -14), Vector2(34, -12)], INK, 1.6)
	line([Vector2(22, 7), Vector2(30, 14), Vector2(34, 12)], INK, 1.6)
	draw_set_transform(Vector2.ZERO)

func flower(point: Vector2, size: float, color: Color) -> void:
	line([point + Vector2(-6, 44), point + Vector2(3, 18), point], Color("6d876d"), 2)
	for i in range(5):
		oval(point + Vector2.from_angle(i * TAU / 5) * size * 0.65, Vector2.ONE * size * 0.58, color)
	oval(point, Vector2.ONE * size * 0.35, GOLD)

func hive() -> void:
	var h := Model.HIVE
	oval(h + Vector2(10, 78), Vector2(145, 52), Color("c6c6ad"), false)
	line([h + Vector2(-91, 92), h + Vector2(-85, -28), h + Vector2(86, -28), h + Vector2(96, 92)], INK, 6)
	shape([h + Vector2(-111, 46), h + Vector2(-88, -87), h + Vector2(-44, -137), h + Vector2(43, -137), h + Vector2(86, -87), h + Vector2(110, 46)], Color("dfc88a"), 3)
	for i in range(6):
		var y := -100 + i * 26
		line([h + Vector2(-69 - i * 5, y), h + Vector2(0, y + 9), h + Vector2(69 + i * 5, y)], Color("86774e"), 2)
	oval(h + Vector2(0, 19), Vector2(23, 32), INK)
	shape([h + Vector2(-44, 45), h + Vector2(45, 45), h + Vector2(61, 65), h + Vector2(-60, 65)], Color("ebdfb9"))
	label(h + Vector2(-63, 132), "巢边 · 出发", 22)

func _draw() -> void:
	if not is_instance_valid(route):
		return
	draw_rect(Rect2(0, 0, 3600, 2100), PAPER)
	# Authored broad ground masses, distinct from interactable roof shapes.
	oval(Vector2(850, 1760), Vector2(1160, 430), Color("d6ddc4"), false)
	oval(Vector2(2990, 1440), Vector2(610, 630), Color("dce1c6"), false)
	oval(Vector2(1530, 220), Vector2(1540, 310), Color("d2dcc6"), false)
	var road := PackedVector2Array(Model.SAFE_ROUTE)
	draw_polyline(road, Color("d8cfb1"), 150, true)
	draw_polyline(road, Color("e5ddc4"), 142, true)
	var direct := PackedVector2Array([Model.HIVE, Vector2(850, 740), Model.BUILD_SITE, Vector2(2740, 950), Model.FLOWERS])
	draw_polyline(direct, Color("d4cdb5"), 92, true)
	draw_polyline(direct, Color("e7dfc9"), 86, true)
	# Quiet botanical marks are deterministic; no raster collage or tiled backdrops.
	for i in range(390):
		var p := Vector2(60 + fposmod(i * 127.731, 3480), 70 + fposmod(i * 217.193, 1940))
		if not Rect2(route.camera_origin - Vector2(100, 100), Vector2(1480, 920)).has_point(p):
			continue
		if route.model.sheltered(p) or route.model.blocked(p):
			continue
		if i % 7 == 0:
			flower(p, 8 + i % 5, Color("eee8cc") if i % 2 else Color("cfaba0"))
		else:
			line([p + Vector2(-7, -10), p, p + Vector2(4, -18)], Color("a0b094"), 1.3)
			line([p, p + Vector2(12, -8)], Color("a0b094"), 1.3)
	for pond: Vector3 in Model.PONDS:
		var center := Vector2(pond.x, pond.y)
		oval(center, Vector2.ONE * (pond.z + 13), Color("c0c7b2"))
		oval(center, Vector2.ONE * pond.z, Color("a9c2be"))
		for i in range(12):
			var p := center + Vector2(sin(i * 8.0) * pond.z * 0.65, -pond.z * 0.8 + i * pond.z * 0.14)
			line([p, p + Vector2(24, 0)], Color("e3e9db"), 2)
		for i in range(26):
			var edge := center + Vector2.from_angle(i * TAU / 26) * (pond.z + 10)
			line([edge + Vector2(-8, -23), edge, edge + Vector2(5, -35)], Color("70856c"), 2.0)
			line([edge, edge + Vector2(13, -21)], Color("70856c"), 1.5)
		for i in range(4):
			leaf(center + Vector2(sin(i * 4) * 90, cos(i * 6) * 100), 33, i * 1.5, GREEN)
	for i in range(Model.SHELTERS.size()):
		canopy(Model.SHELTERS[i], i)
	if route.model.stage >= 1:
		canopy(Model.BUILD_SITE, 3, true)
	else:
		for i in range(4):
			line([Model.BUILD_SITE + Vector2(-43 + i * 20, -20), Model.BUILD_SITE + Vector2(-37 + i * 20, 30)], INK, 4)
		label(Model.BUILD_SITE + Vector2(-70, 75), "待建 · 叶台", 20)
	hive()
	canopy(Model.FLOWERS + Vector2(0, -15), 4)
	for i in range(13):
		var p := Model.FLOWERS + Vector2(sin(i * 2.39) * (45 + i * 5), cos(i * 2.39) * (40 + i * 5))
		flower(p, 19 + i % 4, Color("d5a99b") if i % 3 else Color("f1e6ba"))
	label(Model.FLOWERS + Vector2(-57, 166), "花田 · 取粉", 22)
	label(Vector2(1000, 1770), "叶下小径", 30)
	label(Vector2(1850, 480), "雨中的洼地", 30)
	# Regional rain falls downward everywhere exposed; only wind's horizontal component changes.
	for i in range(3400):
		var px := fposmod(sin(i * 127.1 + 31.7) * 43758.5453, 1.0) * 3600
		var py := fposmod(sin(i * 269.5 + 73.1) * 18341.137, 1.0) * 2100
		var p := Vector2(fposmod(px + route.visual_time * (-65 if route.model.stage >= 2 else 65), 3600), fposmod(py + route.visual_time * (350 + i % 90), 2100))
		if not Rect2(route.camera_origin, Vector2(1280, 720)).has_point(p) or route.model.sheltered(p):
			continue
		line([p, p + Vector2(-4 if route.model.stage >= 2 else 4, 16)], Color("799b9b", route.model.rain_strength() * 0.6), 1.2)
	for p: Vector2 in route.model.drops:
		oval(p, Vector2(12, 9), GOLD)
	for companion in route.model.companions:
		bee(companion.position, float(companion.get("heading", PI)), 0.75, companion.waiting)
		if companion.waiting:
			label(companion.position + Vector2(-4, -32), "!", 20)
	bee(route.model.position, route.model.heading)
	for i in range(route.model.cargo):
		oval(route.model.position + Vector2(-10 + i * 9, 21), Vector2(5, 5), GOLD)
	if route.model.rain_exposure > 0.1:
		var p: Vector2 = route.model.position + Vector2(-24, 37)
		line([p, p + Vector2(48, 0)], Color("d3cdb8"), 4)
		line([p, p + Vector2(48 * clampf(route.model.rain_exposure / 6, 0, 1), 0)], Color("a67863"), 4)
	for effect in route.effects:
		var c: Color = effect.color
		c.a = 1 - float(effect.age) / float(effect.life)
		draw_circle(effect.point, effect.size, c)
	if route.pointer_active:
		draw_arc(route.pointer_target, 8, 0, TAU, 20, INK, 1.5, true)
