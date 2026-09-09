extends Node2D

const Model := preload("res://playtest/rain_route/route_model.gd")
const INK := Color("364940")
const PAPER := Color("eee9d7")
const GREEN := Color("a6b798")
const GOLD := Color("e6bb62")
var route: Node2D
var last_draw_us := 0
var static_pass := false
var layer_opacity := 1.0
var rain_origins := PackedVector2Array()

func _ready() -> void:
	if static_pass:
		return
	var background := Node2D.new()
	background.set_script(get_script())
	background.static_pass = true
	background.route = route
	# Render immutable ground once; keep the live canopy/bee/rain layers vector-based.
	var cache := SubViewport.new()
	cache.size = Vector2i(3600, 2100)
	cache.disable_3d = true
	cache.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(cache)
	cache.add_child(background)
	var ground := Sprite2D.new()
	ground.texture = cache.get_texture()
	ground.centered = false
	ground.show_behind_parent = true
	add_child(ground)
	for i in range(3400):
		rain_origins.append(Vector2(fposmod(sin(i * 127.1 + 31.7) * 43758.5453, 1.0) * 3600, fposmod(sin(i * 269.5 + 73.1) * 18341.137, 1.0) * 2100))


func line(points: Array, color := INK, width := 2.0) -> void:
	color.a *= layer_opacity
	draw_polyline(PackedVector2Array(points), color, width, true)

func shape(points: Array, color: Color, width := 2.0) -> void:
	# Overlapping roof leaves must not accumulate into an opaque cover.
	color.a *= layer_opacity if layer_opacity >= 1.0 else layer_opacity * 0.25
	var polygon := PackedVector2Array(points)
	draw_colored_polygon(polygon, color)
	polygon.append(polygon[0])
	draw_polyline(polygon, Color(INK, layer_opacity), width, true)

func oval(center: Vector2, radius: Vector2, color: Color, outline := true) -> void:
	var points: Array = []
	for i in range(40):
		points.append(center + Vector2(cos(i * TAU / 40), sin(i * TAU / 40)) * radius)
	if outline:
		shape(points, color)
	else:
		draw_colored_polygon(PackedVector2Array(points), Color(color, color.a * layer_opacity))

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

func occupied(center: Vector2, radius := 215.0) -> bool:
	if route.model.position.distance_to(center) < radius:
		return true
	for companion in route.model.companions:
		if (companion.position as Vector2).distance_to(center) < radius:
			return true
	return false

func canopy(center: Vector2, index: int, built := false, custom_radius := 0.0) -> void:
	var near: bool = route.model.position.distance_to(center) < (route.model.roof_radius() + 30 if built else 245)
	var roof_scale: float = custom_radius / 215.0 if custom_radius > 0 else (route.model.roof_radius() / 215.0 if built else 1.0)
	draw_set_transform(center, 0, Vector2.ONE * roof_scale)
	center = Vector2.ZERO
	oval(center + Vector2(12, 35), Vector2(218, 195), Color("738765", 0.12), false)
	var colors := [Color("b2c3a0"), Color("9fb598"), Color("c1cbaa")]
	for i in range(5):
		var angle := i * TAU / 5 + index * 0.53
		var c: Color = colors[(index + i) % 3]
		if near:
			c = c.lightened(0.24)
		var p := center + Vector2.from_angle(angle) * 89
		leaf(p, 139 + (i % 2) * 9, angle + sin(route.visual_time * 1.1 + index) * 0.025, c)
	# Rain lands on the roof; runoff leaves the lower edge while the bee stays dry.
	for i in range(3):
		var phase: float = fposmod(route.visual_time * 1.1 + i * 0.33 + index * 0.17, 1.0)
		var p := center + Vector2(-95 + i * 90, -45 + (i % 2) * 70)
		draw_arc(p, 3 + phase * 9, 0, TAU, 16, Color("f5f5e1", (1 - phase) * 0.8), 1.5, true)
	var drip: float = fposmod(route.visual_time * 1.5 + index * 0.2, 1.0)
	line([center + Vector2(10, 203 + drip * 24), center + Vector2(10, 207 + drip * 24)], Color("789c9c", 1 - drip), 1.5)
	if built:
		line([center + Vector2(-90, 105), center + Vector2(-80, -50), center + Vector2(80, -50), center + Vector2(90, 105)], INK, 5)
		label(center + Vector2(-42, 90), "新叶台", 20)
	draw_set_transform(Vector2.ZERO)

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
	var started := Time.get_ticks_usec()
	if not is_instance_valid(route):
		return
	if static_pass:
		_draw_static()
		return
	var visible_world := Rect2(route.camera_origin - Vector2(280, 280), Vector2(1840, 1280))
	for i in range(Model.SHELTERS.size()):
		if visible_world.has_point(Model.SHELTERS[i]) and not occupied(Model.SHELTERS[i]):
			canopy(Model.SHELTERS[i], i)
	if route.model.built_site >= 0:
		if not occupied(route.model.roof_position(), route.model.roof_radius()):
			canopy(route.model.roof_position(), 3, true)
	else:
		for index in range(Model.BUILD_SITES.size()):
			var site: Vector2 = Model.BUILD_SITES[index]
			for i in range(2):
				line([site + Vector2(-35 + i * 70, -10), site + Vector2(-35 + i * 70, 35)], INK, 3)
			label(site + Vector2(-65, 75), "中路 · 支点" if index == 0 else "上路 · 支点", 20)
	if visible_world.has_point(Model.FLOWERS):
		if not occupied(Model.FLOWERS):
			canopy(Model.FLOWERS + Vector2(0, -15), 4)
		for i in range(13):
			var p := Model.FLOWERS + Vector2(sin(i * 2.39) * (45 + i * 5), cos(i * 2.39) * (40 + i * 5))
			flower(p, 19 + i % 4, Color("d5a99b") if i % 3 else Color("f1e6ba"))
	_daily_world(visible_world)
	for extra in extra_roofs():
		if visible_world.has_point(extra.point) and not occupied(extra.point, extra.radius):
			canopy(extra.point, 2, false, extra.radius)
	# Regional rain falls downward everywhere exposed; only wind's horizontal component changes.
	var rain_lines := PackedVector2Array()
	var viewport := Rect2(route.camera_origin, Vector2(1280, 720))
	var streak := Vector2(-4 if route.model.day >= 14 else 4, 16)
	for i in range(rain_origins.size()):
		var origin := rain_origins[i]
		var p := Vector2(fposmod(origin.x + route.model.wind_travel, 3600), fposmod(origin.y + route.visual_time * (350 + i % 90), 2100))
		if viewport.has_point(p) and not route.model.sheltered(p):
			rain_lines.append(p)
			rain_lines.append(p + streak)
	if not rain_lines.is_empty():
		draw_multiline(rain_lines, Color("799b9b", route.model.rain_strength() * 0.6), 1.2, true)
	for p: Vector2 in route.model.drops:
		oval(p, Vector2(12, 9), GOLD)
	for companion in route.model.companions:
		bee(companion.position, float(companion.get("heading", PI)), 0.75, companion.waiting)
		if companion.waiting:
			label(companion.position + Vector2(-4, -32), "!", 20)
	bee(route.model.position, route.model.heading)
	for i in range(route.model.cargo):
		oval(route.model.position + Vector2(-10 + i * 9, 21), Vector2(5, 5), GOLD)
	# Roofs draw ABOVE bees inside them; translucent surfaces keep movement readable.
	layer_opacity = 0.22
	for i in range(Model.SHELTERS.size()):
		if occupied(Model.SHELTERS[i]) and visible_world.has_point(Model.SHELTERS[i]):
			canopy(Model.SHELTERS[i], i)
	if route.model.built_site >= 0 and occupied(route.model.roof_position(), route.model.roof_radius()):
		canopy(route.model.roof_position(), 3, true)
	if occupied(Model.FLOWERS):
		canopy(Model.FLOWERS + Vector2(0, -15), 4)
	for extra in extra_roofs():
		if visible_world.has_point(extra.point) and occupied(extra.point, extra.radius):
			canopy(extra.point, 2, false, extra.radius)
	layer_opacity = 1.0
	_draw_drip_gaps(visible_world)
	_draw_seed_landing(visible_world)
	_draw_beetle_guest(visible_world)
	_draw_beetle_hint()
	if route.model.sheltered(route.model.position) and route.model.position.distance_to(Model.HIVE) > 205:
		label(route.model.position + Vector2(-38, 55), "叶下 · 避雨", 16)
	if route.model.roof_carried:
		leaf(route.model.position + Vector2(-18, -35), 33, -0.25, GREEN)
	if route.model.carried_seed >= 0:
		oval(route.model.position + Vector2(-10, -22), Vector2(10, 7), GOLD)
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

	last_draw_us = Time.get_ticks_usec() - started

func _draw_static() -> void:
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
	var upper := PackedVector2Array([Model.HIVE, Vector2(750, 500), Vector2(1250, 420), Model.BUILD_SITES[1], Vector2(2570, 500), Model.FLOWERS])
	draw_polyline(upper, Color("d4cdb5"), 65, true)
	draw_polyline(upper, Color("e7dfc9"), 60, true)
	# Quiet botanical marks are deterministic; no raster collage or tiled backdrops.
	for i in range(390):
		var p := Vector2(60 + fposmod(i * 127.731, 3480), 70 + fposmod(i * 217.193, 1940))
		if route.model.sheltered(p) or route.model.over_water(p):
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
	hive()
	label(Model.FLOWERS + Vector2(-57, 166), "花田 · 取粉", 22)
	label(Vector2(1000, 1770), "叶下小径", 30)
	label(Vector2(1850, 480), "雨中的洼地", 30)


func extra_roofs() -> Array:
	var roofs: Array = []
	if route.model.day == 10:
		roofs.append({"point": route.model.moving_roof_position(), "radius": 135.0})
	if route.model.cleared.size() == 3:
		roofs.append({"point": Vector2(2470, 1080), "radius": 215.0})
	if route.model.escort_roof:
		roofs.append({"point": route.model.position, "radius": 135.0})
	for gap: Vector2 in route.model.drip_gaps():
		roofs.append({"point": gap + Vector2(0, 150), "radius": 145.0})
	return roofs

func _daily_world(visible_world: Rect2) -> void:
	var model = route.model
	if model.roof_available() and visible_world.has_point(Model.ROOF_PICKUP):
		var p := Model.ROOF_PICKUP
		oval(p + Vector2(0, 20), Vector2(58, 18), Color("c6c6ad"), false)
		line([p + Vector2(-40, 25), p + Vector2(-34, -2), p + Vector2(39, -2), p + Vector2(45, 25)], INK, 3)
		leaf(p + Vector2(-27, 0), 85, -0.25, GREEN)
		label(p + Vector2(-48, 62), "遮雨叶", 20)
		if model.can_take_roof():
			label(p + Vector2(-48, 86), "空格 · 带上", 16)
	# The two flower beds retain pollen, then show fruit only on later days.
	for i in range(Model.Calendar.DAYS[3].points.size()):
		var p: Vector2 = Model.Calendar.DAYS[3].points[i]
		if not visible_world.has_point(p):
			continue
		for j in range(3):
			var spot := p + Vector2((j - 1) * 31, (j % 2) * 19)
			if model.pollinated.has(str(i)) and model.day >= 11:
				oval(spot, Vector2(12, 16), Color("d4ad68"))
				line([spot, spot + Vector2(0, -23)], INK, 2)
			else:
				flower(spot, 15, Color("e2c2ab"))
				if model.pollinated.has(str(i)):
					draw_circle(spot, 4, GOLD)
		label(p + Vector2(-35, 65), "花粉已到" if model.pollinated.has(str(i)) else "待传粉", 16)
	if model.day >= 7:
		var landing: Vector2 = Model.Calendar.DAYS[6].target
		if visible_world.has_point(landing):
			oval(landing, Vector2(96, 68), Color("dfca9b"))
			oval(landing + Vector2(0, 5), Vector2(78, 48), Color("efe1bc"))
			for i in range(model.cleared.size()):
				var seed := landing + Vector2(-26 + i * 26, 4 + (i % 2) * 9)
				oval(seed, Vector2(16, 11), Color("c8ab79"))
		var points: Array = Model.Calendar.DAYS[6].points
		for i in range(points.size()):
			if not model.cleared.has(str(i)) and model.carried_seed != i and visible_world.has_point(points[i]):
				oval(points[i], Vector2(16, 11), Color("c8ab79"))
		if visible_world.has_point(Vector2(2470, 1080)) and model.cleared.size() < 3:
			line([Vector2(2410, 930), Vector2(2450, 1000), Vector2(2470, 1080), Vector2(2580, 1150)], Color("86a8aa"), 8)
			label(Vector2(2410, 1155), "堵住的叶沟", 17)
	if model.built_site >= 0:
		var p: Vector2 = model.roof_position() + Vector2(85, 72)
		if visible_world.has_point(p):
			line([p + Vector2(-30, 30), p + Vector2(-24, -12), p + Vector2(36, -12), p + Vector2(42, 30)], INK, 3)
			for i in range(mini(model.rack_stock, 6)):
				oval(p + Vector2(-20 + i * 10, -7), Vector2(5, 6), GOLD)
	if model.day >= 9 and visible_world.has_point(Model.Calendar.DAYS[8].target):
		var home: Vector2 = model.beetle_rest_position()
		leaf(home + Vector2(0, 14), 42, 0.15, Color("c1cbaa"))
		if model.beetle_home:
			leaf(home + Vector2(24, 24), 16, -0.6, GREEN)
	if model.today().mode in ["scout", "drips"]:
		for i in range(model.today().points.size()):
			var p: Vector2 = model.today().points[i]
			if not visible_world.has_point(p):
				continue
			if model.today().mode == "scout":
				line([p + Vector2(0, 26), p + Vector2(0, -25)], INK, 3)
				shape([p + Vector2(0, -25), p + Vector2(27, -18), p + Vector2(0, -10)], GREEN if model.visited.has(str(i)) else GOLD)
	if not model.day_finished:
		for target: Vector2 in model.objective_points():
			if visible_world.has_point(target):
				# Small ground chevrons identify today's work without blocking flight.
				line([target + Vector2(-9, 47), target + Vector2(0, 53), target + Vector2(9, 47)], Color("ae7d55"), 2)


func _draw_drip_gaps(visible_world: Rect2) -> void:
	var model = route.model
	for p: Vector2 in model.drip_gaps():
		if not visible_world.has_point(p):
			continue
		# Remove overlapping roof silhouettes at the same bounds as the exposed gap.
		oval(p, Vector2(52, 100), Color("eae4cf"), false)
		for side in [-1, 1]:
			var rim: Array = []
			for sample in range(17):
				var angle := -PI / 2 + sample * PI / 16
				rim.append(p + Vector2(side * cos(angle) * 52, sin(angle) * 100))
			line(rim, Color("647c65"), 2)
			var edge := p + Vector2(side * 72, 0)
			line([edge + Vector2(-side * 11, -8), edge, edge + Vector2(-side * 11, 8)], GREEN, 3)
		# A large leaf visibly channels water to its tip above the opening.
		leaf(p + Vector2(-58, -115), 64, 0.4, GREEN)
		if not model.drip_open():
			var drop: Vector2 = model.drip_position(p)
			line([drop + Vector2(0, -16), drop], Color("658f98"), 3)
			oval(drop, Vector2(7, 11), Color("7fa7ae"))
			var phase := fposmod(model.day_clock, 0.9) / 0.9
			draw_arc(p + Vector2(0, 88), 4 + phase * 12, PI, TAU, 14, Color("7fa7ae", 1 - phase), 2, true)
		for pulse in range(3):
			draw_circle(p + Vector2(-14 + pulse * 14, -105), 3, GREEN if model.drip_open() or fposmod(model.day_clock, 4.5) >= (pulse + 1) * 0.9 else Color("b5b4a3"))
		# Keep the player and recoverable pollen above the opened roof area.
		for pollen: Vector2 in model.drops:
			if Rect2(p - Vector2(60, 110), Vector2(120, 220)).has_point(pollen):
				oval(pollen, Vector2(12, 9), GOLD)
		if Rect2(p - Vector2(80, 130), Vector2(160, 260)).has_point(model.position):
			bee(model.position, model.heading)
			for i in range(model.cargo):
				oval(model.position + Vector2(-10 + i * 9, 21), Vector2(5, 5), GOLD)
		if model.drip_hit_flash > 0 and model.position.distance_to(p) < 125:
			draw_arc(model.position, 32 + (1.2 - model.drip_hit_flash) * 15, 0, TAU, 24, Color("7fa7ae", model.drip_hit_flash / 1.2), 3, true)
		draw_rect(Rect2(p + Vector2(-120, -175), Vector2(240, 30)), Color("f8f0d9"))
		label(p + Vector2(-107, -154), "停水 · 可以飞过" if model.drip_open() else "滴水 · 等一等再飞", 19)
		draw_rect(Rect2(p + Vector2(-88, 185), Vector2(176, 28)), Color("f8f0d9"))
		label(p + Vector2(-73, 205), "叶下绕行 · 不用等", 17)


func _draw_seed_landing(visible_world: Rect2) -> void:
	var model = route.model
	if model.day < 7:
		return
	var target: Vector2 = Model.Calendar.DAYS[6].target
	if visible_world.has_point(target):
		# The destination stays legible above transparent overhead leaves.
		draw_rect(Rect2(target + Vector2(-92, 73), Vector2(184, 30)), Color("f8f0d9"))
		label(target + Vector2(-78, 94), "种壳放这里 · %d / 3" % model.cleared.size(), 17)
		if model.day == 7 and model.carried_seed >= 0:
			draw_arc(target, 75, 0, TAU, 48, Color("ae7d55"), 2, true)
	if model.day == 7 and model.carried_seed >= 0 and model.position.distance_to(target) >= 75:
		var direction: Vector2 = (target - model.position).normalized()
		var tip: Vector2 = model.position + direction * 68
		var base: Vector2 = tip - direction * 18
		var normal := direction.orthogonal() * 9
		shape([tip, base + normal, base - normal], GOLD)


func _draw_beetle_hint() -> void:
	var model = route.model
	if model.day != 9 or model.beetle_home or model.day_finished:
		return
	var target: Vector2 = model.today().target if model.escort_roof else model.beetle_position
	var distance: float = model.position.distance_to(target)
	var opacity := smoothstep(85.0, 220.0, distance)
	if opacity > 0:
		var direction: Vector2 = (target - model.position).normalized()
		var tip: Vector2 = model.position + direction * 90
		var normal := direction.orthogonal()
		# A quiet leaf-shaped compass near the bee, rather than a route drawn across the map.
		layer_opacity = opacity * 0.8
		shape([tip, tip - direction * 14 + normal * 7, tip - direction * 26, tip - direction * 14 - normal * 7], Color("d5bb78"), 1.3)
		line([tip - direction * 23, tip - direction * 4], INK, 1)
		layer_opacity = 1.0
	if not model.escort_roof and distance < 260:
		var p: Vector2 = model.beetle_position
		var glow: float = (0.35 + 0.1 * sin(route.visual_time * 2.0)) * (1.0 - smoothstep(180.0, 260.0, distance))
		draw_arc(p, 30, 0.2, PI - 0.2, 22, Color("ae9278", glow), 1.5, true)
		draw_arc(p, 30, PI + 0.2, TAU - 0.2, 22, Color("ae9278", glow), 1.5, true)
		# Retain a readable name even beneath overlapping translucent leaves.
		label(p + Vector2(-27, 44), "小甲虫", 16)


func _draw_beetle_guest(visible_world: Rect2) -> void:
	var model = route.model
	if model.day < 9 or not visible_world.has_point(model.beetle_position):
		return
	var p: Vector2 = model.beetle_position
	var remaining: float = route.beetle_greeting_time
	var elapsed: float = 4.0 - remaining
	var turn := smoothstep(0.4, 1.2, elapsed) if remaining > 0 else 0.0
	var angle: float = lerp_angle(0, route.beetle_greeting_angle, turn)
	if remaining > 0 and remaining < 0.7:
		angle = lerp_angle(0, angle, remaining / 0.7)
	draw_set_transform(p, angle)
	for side in [-1, 1]:
		for leg in range(3):
			var foot := Vector2(side * 19, -10 + leg * 10)
			if side == 1 and leg == 0 and elapsed > 1.2 and remaining > 0.7:
				foot += Vector2(5 + sin(elapsed * 9) * 4, -9 + cos(elapsed * 9) * 4)
			line([Vector2(side * 8, -10 + leg * 10), foot], INK, 2)
	oval(Vector2.ZERO, Vector2(13, 19), Color("ae9278"))
	line([Vector2(0, -14), Vector2(0, 15)], INK, 1.5)
	oval(Vector2(0, -17), Vector2(8, 7), Color("ae9278"))
	for side in [-1, 1]:
		draw_circle(Vector2(side * 4, -20), 1.6, INK)
		line([Vector2(side * 4, -23), Vector2(side * 9, -28)], INK, 1.3)
	draw_set_transform(Vector2.ZERO)
	if model.beetle_home:
		label(p + Vector2(-30, 48), "到家了", 16)
	elif model.day != 9:
		label(p + Vector2(-30, 43), "小甲虫", 16)
