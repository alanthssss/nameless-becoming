extends Node2D
## A single painter for the authored landscape; never changes simulation state.
var model
var particles: Array[Dictionary] = []
var ripples: Array[Dictionary] = []
var trail: Array[Dictionary] = []
var clock := 0.0
var trail_clock := 0.0
var trauma := 0.0
var _rng := RandomNumberGenerator.new()
var _path: Array[Vector2] = []
var _last_stage := -1
var _ending_elapsed := 0.0

const INK := Color("163d3b")
const GOLD := Color("ffd978")
const CREAM := Color("fff4ca")
const SKY := [Color("e5e8c3"), Color("a6d2cb"), Color("617f96")]
const LOW_SKY := [Color("91b999"), Color("4f918b"), Color("304e67")]

func _ready() -> void:
	_rng.seed = 14631

func _process(delta: float) -> void:
	clock += delta
	trauma = maxf(0.0, trauma - delta * 2.0)
	for i in range(particles.size() - 1, -1, -1):
		var bit: Dictionary = particles[i]
		bit.life -= delta
		bit.pos += bit.vel * delta
		bit.vel *= exp(-delta * 1.4)
		bit.vel.y += delta * 45.0
		if bit.life <= 0.0:
			particles.remove_at(i)
	for i in range(ripples.size() - 1, -1, -1):
		ripples[i].life -= delta
		if ripples[i].life <= 0.0:
			ripples.remove_at(i)
	for i in range(trail.size() - 1, -1, -1):
		trail[i].life -= delta
		if trail[i].life <= 0.0:
			trail.remove_at(i)
	if model != null:
		if model.stage != _last_stage or (not _path.is_empty() and _path.back().distance_to(model.p) > 180.0):
			_path.clear()
			particles.clear()
			ripples.clear()
			trail.clear()
			_last_stage = model.stage
		if _path.is_empty():
			_path.append(model.p)
		while _path.back().distance_to(model.p) >= 8.0:
			_path.append(_path.back().move_toward(model.p, 8.0))
			if _path.size() > 48:
				_path.pop_front()
		_ending_elapsed = _ending_elapsed + delta if model.phase == "ending" else 0.0
		trail_clock += delta
		if model.burst_left > 0.0 and trail_clock > 0.022:
			trail_clock = 0.0
			trail.append({"pos": model.p, "life": 0.28, "face": model.face})
	queue_redraw()

func emit_event(kind: String, pos: Vector2) -> void:
	var tint := GOLD
	var count := 14
	var force := 180.0
	match kind:
		"rescue":
			tint = Color("fff3a4")
			count = 36
			force = 200.0
		"ring":
			tint = Color("b6ffe4")
			count = 30
			force = 270.0
		"gate":
			tint = Color("dcad60")
			count = 32
			force = 250.0
			trauma = 0.25
		"hit":
			tint = Color("ffb5a2")
			count = 19
			trauma = 0.36
		"recover":
			tint = Color("b6ffe4")
			count = 28
		"finish":
			count = 60
			force = 300.0
		"burst":
			count = 18
			force = 170.0
	for i in count:
		var angle := _rng.randf_range(0.0, TAU)
		var life := _rng.randf_range(0.35, 0.95)
		particles.append({"pos": pos, "vel": Vector2.from_angle(angle) * _rng.randf_range(force * 0.2, force), "life": life, "max_life": life, "size": _rng.randf_range(2.0, 5.5), "color": tint, "angle": angle})
	ripples.append({"pos": pos, "life": 0.5, "color": tint})

func _draw() -> void:
	if model == null:
		draw_rect(Rect2(0, 0, 1280, 800), SKY[0])
		return
	var act: int = clampi(model.stage, 0, 2)
	var cam: float = model.camera_x
	_background(act, cam)
	var shake := Vector2(sin(clock * 53.0), sin(clock * 39.0)) * trauma * trauma * 9.0
	draw_set_transform(Vector2(-cam, 0) + shake)
	_world_decor(act, cam)
	for wall in model.walls:
		_wall(wall)
	for shelter in model.shelters:
		_shelter(shelter)
	for ring in model.rings:
		_ring(ring)
	for pod in model.pods:
		_pod(pod)
	_exit(act)
	_storm(cam)
	if model.phase == "ending":
		_ending_weather(cam)
	for drop in model.drops:
		_drop(drop.pos, drop.vel)
	for ghost in trail:
		var alpha: float = ghost.life / 0.28 * 0.18
		_ellipse(ghost.pos, Vector2(22, 10), Color(1.0, 0.91, 0.56, alpha), ghost.face.angle())
	_swarm()
	_effects()
	draw_set_transform(Vector2.ZERO)
	_foreground(act, cam)

func _background(act: int, cam: float) -> void:
	for band in 40:
		var t := float(band) / 39.0
		draw_rect(Rect2(0, band * 20, 1280, 21), SKY[act].lerp(LOW_SKY[act], t))
	var sun := Vector2(1030 - fmod(cam * 0.04, 180.0), 140)
	if act == 0:
		draw_circle(sun, 100, Color(1.0, 0.95, 0.69, 0.07))
		draw_circle(sun, 68, Color(1.0, 0.96, 0.72, 0.13))
		draw_circle(sun, 40, Color("fff3c4"))
	else:
		draw_circle(sun, 85, Color(0.89, 0.98, 0.94, 0.035))
		draw_circle(sun, 42, Color(0.91, 0.99, 0.94, 0.11))
	for layer in 3:
		var factor := 0.08 + layer * 0.10
		var tint: Color = LOW_SKY[act].darkened(0.03 + layer * 0.11)
		tint.a = 0.24 + layer * 0.13
		var points := PackedVector2Array([Vector2(-40, 820)])
		for x in range(-40, 1341, 30):
			var wx := x + cam * factor
			var yy := 630.0 - layer * 24.0 + sin(wx * 0.004 + layer * 1.7) * 85.0 + cos(wx * 0.008) * 34.0
			points.append(Vector2(x, yy))
		points.append(Vector2(1340, 820))
		draw_colored_polygon(points, tint)
	for i in 15:
		var x := fposmod(i * 183.0 - cam * 0.25, 1550.0) - 130.0
		var tall := 170.0 + float(i % 5) * 55.0
		var sway := sin(clock * 0.7 + i) * (4.0 + act * 2.5)
		var stem := Vector2(x, 810)
		var tip := Vector2(x + sin(float(i) * 4.1) * 48.0 + sway, 800 - tall)
		var tint: Color = LOW_SKY[act].darkened(0.14)
		tint.a = 0.22
		_curve(stem, stem + Vector2(40, -tall * 0.45), tip + Vector2(-25, 35), tip, tint, 3.0)
		_leaf(stem.lerp(tip, 0.4), stem.lerp(tip, 0.5) + Vector2(-70, -25), 18, tint)
		for petal in 5:
			var angle := float(petal) * TAU / 5.0
			_ellipse(tip + Vector2.from_angle(angle) * 13.0, Vector2(19, 10), tint, angle)
	# Thin atmospheric wind is deliberately much fainter than dangerous drops.
	for i in 24:
		var x := fposmod(i * 83.0 + clock * (18.0 + act * 14.0) - cam * 0.4, 1400.0) - 60.0
		var y := fposmod(i * 137.0, 670.0) + 50.0
		var length := 12.0 + float(i % 4) * 8.0
		draw_line(Vector2(x, y), Vector2(x + length, y - 2), Color(0.94, 1.0, 0.88, 0.13), 1.0, true)

func _world_decor(act: int, cam: float) -> void:
	# Foreground objects are silhouettes; only walls in model.walls are solid.
	var start := int(floor((cam - 160.0) / 170.0))
	for i in range(start, start + 11):
		var x := float(i) * 170.0 + sin(i * 3.7) * 37.0
		var high := 65.0 + fposmod(float(i) * 51.0, 140.0)
		var base := Vector2(x, 800)
		var tip := Vector2(x + 35.0 + sin(clock * 0.8 + i) * (5.0 + act * 5.0), 800 - high)
		var stem_color: Color = [Color("407563"), Color("326c66"), Color("294b55")][act]
		_curve(base, base + Vector2(12, -high * 0.45), tip + Vector2(-30, 16), tip, stem_color, 5.0)
		_leaf(base.lerp(tip, 0.35), base.lerp(tip, 0.55) + Vector2(-60, -15), 16, stem_color)
		_leaf(base.lerp(tip, 0.52), base.lerp(tip, 0.68) + Vector2(50, -10), 12, stem_color.lightened(0.04))
		if i % 3 == 0:
			_flower(tip, 17.0, Color("decd98") if act == 0 else Color("91bfbe"), float(i))
	for i in range(start - 2, start + 7):
		if i % 3 != 1:
			continue
		var x := float(i) * 260.0
		var tint: Color = [Color("6c9b75"), Color("548d86"), Color("3e626e")][act]
		tint.a = 0.30
		var root := Vector2(x, 850)
		var crown := Vector2(x + 60, 290 + sin(i * 2.1) * 90.0)
		_curve(root, root + Vector2(120, -190), crown + Vector2(130, 80), crown, tint, 12.0)
		_leaf(root + Vector2(36, -120), root + Vector2(-120, -290), 52, tint)
		_flower(crown, 60.0, tint, float(i))

func _wall(wall: Dictionary) -> void:
	var r: Rect2 = wall.rect
	if r.end.x < model.camera_x - 80 or r.position.x > model.camera_x + 1360:
		return
	if wall.kind == "curtain":
		if wall.broken:
			draw_line(r.position, r.position + Vector2(r.size.x, 0), Color(0.76, 0.73, 0.45, 0.38), 3.0, true)
			for i in 4:
				var x := r.position.x + (i + 0.5) * r.size.x / 4.0
				_leaf(Vector2(x, r.position.y), Vector2(x + 8, r.position.y + 23), 7, Color("9a9d68"))
			return
		draw_rect(r.grow(2), Color("604e38"))
		draw_rect(r, Color("bea367"))
		for i in range(int(r.size.y / 25.0) + 1):
			var y := r.position.y + i * 25.0
			draw_line(Vector2(r.position.x + 3, y), Vector2(r.end.x - 3, minf(y + 13.0, r.end.y)), Color("e7c583"), 2.0, true)
		var fracture := PackedVector2Array()
		for i in 9:
			fracture.append(Vector2(r.get_center().x + (7.0 if i % 2 else -6.0), r.position.y + r.size.y * i / 8.0))
		draw_polyline(fracture, Color("fff0b1"), 3.0, true)
		var mid := r.get_center()
		for dy in [-22.0, 0.0, 22.0]:
			draw_polyline(PackedVector2Array([mid + Vector2(-12, dy - 7), mid + Vector2(-3, dy), mid + Vector2(-12, dy + 7)]), Color("fff4cb"), 3.0, true)
		return
	draw_rect(r.grow(2), Color("133c39"))
	draw_rect(r, Color("2b6653"))
	draw_rect(Rect2(r.position + Vector2(3, 0), Vector2(minf(6.0, r.size.x * 0.2), r.size.y)), Color("52886a"))
	for y in range(int(r.position.y + 24), int(r.end.y), 58):
		draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y - 4), Color("1e5145"), 3.0)

func _pod(pod: Dictionary) -> void:
	var p: Vector2 = pod.pos
	if p.x < model.camera_x - 100 or p.x > model.camera_x + 1380:
		return
	_curve(p + Vector2(4, 36), p + Vector2(15, 74), p + Vector2(-20, 112), p + Vector2(-9, 170), Color("6a8560"), 3)
	if pod.open:
		_leaf(p + Vector2(-27, 14), p + Vector2(-44, 43), 17, Color("a78f56"))
		_leaf(p + Vector2(27, 14), p + Vector2(47, 44), 17, Color("bfa36a"))
		_ellipse(p + Vector2(0, 21), Vector2(25, 7), Color("776f4b"))
		return
	var breathe := 1.0 + sin(clock * 3.0 + p.x) * 0.04
	draw_circle(p, 48 + sin(clock * 2.0) * 3.0, Color(1.0, 0.86, 0.44, 0.07))
	_ellipse(p, Vector2(36, 41) * breathe, Color("6d6842"), -0.16)
	_ellipse(p + Vector2(-2, -3), Vector2(31, 37) * breathe, Color("c9ae67"), -0.16)
	_leaf(p + Vector2(-25, 20), p + Vector2(14, -35), 16, Color("e1c482"))
	draw_polyline(PackedVector2Array([p + Vector2(5, -26), p + Vector2(-3, -13), p + Vector2(5, 0), p + Vector2(-2, 13), p + Vector2(6, 26)]), Color("fff0ad"), 3.0, true)
	_bee(p + Vector2(-8, 1), 0.65, Vector2.RIGHT, 0.6, true, 0.0)
	# A little moving wing peeks out: this is a friend, not a collectible coin.
	_ellipse(p + Vector2(14, -5), Vector2(6, 11 + sin(clock * 17.0) * 2.0), Color(0.97, 1.0, 0.93, 0.9), 0.4)

func _ring(ring: Dictionary) -> void:
	var p: Vector2 = ring.pos
	var active: bool = ring.active
	var mint := Color("aaf1cf") if active else Color("c9e8bd")
	_curve(p + Vector2(0, 51), p + Vector2(-10, 140), p + Vector2(45, 220), Vector2(p.x - 30, 830), Color("386c58"), 7.0)
	_leaf(p + Vector2(0, 100), p + Vector2(-87, 61), 24, Color("4b8667"))
	for i in 7:
		var angle := float(i) * TAU / 7.0 - PI / 2.0
		_ellipse(p + Vector2.from_angle(angle) * 51, Vector2(24, 14), Color("4d897c") if active else Color("6e9a80"), angle)
		_ellipse(p + Vector2.from_angle(angle) * 47, Vector2(19, 10), mint.darkened(0.17), angle)
	draw_circle(p, 45, Color(0.23, 0.55, 0.48, 0.10))
	draw_arc(p, 46.0, 0.0, TAU, 64, mint, 3.5, true)
	for i in 3:
		var x := -19.0 + float(i) * 20.0 + sin(clock * 3.0) * 3.0
		var col := mint
		col.a = 0.4 + 0.6 * (0.5 + sin(clock * 4.0 - i) * 0.5)
		draw_polyline(PackedVector2Array([p + Vector2(x - 8, -10), p + Vector2(x + 4, 0), p + Vector2(x - 8, 10)]), col, 3.0, true)
	if active:
		for i in 10:
			var x := fposmod(clock * 190.0 + i * 35.0, 360.0)
			var y := sin(i * 2.7 + clock * 1.8) * 30.0
			var col := Color(0.79, 1.0, 0.88, 0.30 * (1.0 - x / 360.0))
			draw_line(p + Vector2(x + 44, y), p + Vector2(x + 68, y - 1), col, 2.0, true)

func _shelter(shelter: Dictionary) -> void:
	var p: Vector2 = shelter.pos
	var reached: bool = shelter.reached
	_curve(p + Vector2(117, -82), p + Vector2(135, 10), p + Vector2(96, 95), Vector2(p.x + 87, 820), Color("3f7360"), 7.0)
	_leaf(p + Vector2(126, -77), p + Vector2(-122, -85), 42, Color("264d47"))
	_leaf(p + Vector2(123, -85), p + Vector2(-122, -93), 30, Color("5c9373"))
	draw_line(p + Vector2(-108, -90), p + Vector2(112, -83), Color("a8c78c"), 2, true)
	draw_circle(p + Vector2(0, 5), 58, Color(1.0, 0.88, 0.53, 0.07 if reached else 0.035))
	_ellipse(p + Vector2(0, 38), Vector2(51, 12), Color("4d7360"))
	_ellipse(p + Vector2(0, 35), Vector2(39, 7), Color("b6c488") if reached else Color("829f72"))
	if reached:
		draw_circle(p + Vector2(0, 32), 4, GOLD)
		for side in [-1, 1]:
			draw_line(p + Vector2(side * 12, 34), p + Vector2(side * 23, 29), GOLD, 2.0, true)

func _exit(act: int) -> void:
	var p: Vector2 = model.exit_pos
	if act < 2:
		var col := Color("d9edb2") if model.exit_ready else Color("88a98b")
		_curve(p + Vector2(-90, 170), p + Vector2(-88, -50), p + Vector2(-10, -115), p + Vector2(44, -85), Color("3f7459"), 13.0)
		_leaf(p + Vector2(-54, -57), p + Vector2(42, -99), 25, Color("7da273"))
		if model.exit_ready:
			for i in 3:
				var x := p.x - 28 + i * 26.0 + sin(clock * 3.0) * 4.0
				draw_polyline(PackedVector2Array([Vector2(x, p.y - 13), Vector2(x + 13, p.y), Vector2(x, p.y + 13)]), col, 4.0, true)
		return
	# The bright hollow remains visible as the destination throughout the finale.
	var trunk := Rect2(p.x - 105, -60, 300, 920)
	draw_rect(trunk, Color("293f42"))
	for i in 9:
		var x := p.x - 95 + i * 34.0
		_curve(Vector2(x, -20), Vector2(x - 25, 230), Vector2(x + 24, 520), Vector2(x - 15, 840), Color("3b5150"), 7.0)
	_ellipse(p, Vector2(95, 125), Color("192f33"), 0.03)
	_ellipse(p + Vector2(6, 5), Vector2(77, 106), Color("6f6544"), 0.03)
	_ellipse(p + Vector2(15, 13), Vector2(63, 90), Color("bea365"), 0.03)
	_ellipse(p + Vector2(19, 20), Vector2(49, 72), Color("eac681"), 0.03)
	for i in 3:
		draw_circle(p + Vector2(-18, 24), 128.0 + i * 28.0, Color(1.0, 0.81, 0.40, 0.025))
	_leaf(p + Vector2(-90, 103), p + Vector2(100, 87), 28, Color("779367"))
	_leaf(p + Vector2(-90, 103), p + Vector2(82, 102), 13, Color("a5b47a"))

func _storm(cam: float) -> void:
	if not model.storm_active:
		return
	var front: float = model.storm_x
	if front < cam - 100:
		return
	var start := maxf(cam - 10.0, front - 1500.0)
	draw_rect(Rect2(start, 0, maxf(0.0, front - start), 800), Color(0.13, 0.26, 0.36, 0.44))
	for band in 8:
		var x := front - 12.0 + band * 10.0
		draw_rect(Rect2(x, 0, 11, 800), Color(0.19, 0.36, 0.46, (8 - band) * 0.025))
	for i in 70:
		var x := front - fposmod(i * 37.7 + clock * 140.0, 1400.0)
		var y := fposmod(i * 63.0 + clock * 530.0, 900.0) - 50.0
		draw_line(Vector2(x, y), Vector2(x - 9, y + 29), Color(0.65, 0.86, 0.94, 0.34), 1.3, true)
	for i in 8:
		var y := i * 115.0 + sin(clock * 2 + i) * 16.0
		draw_arc(Vector2(front - 10, y), 40, -PI / 2.0, PI / 2.0, 15, Color(0.70, 0.90, 0.99, 0.20), 2.0, true)

func _drop(p: Vector2, velocity: Vector2) -> void:
	var direction := velocity.normalized()
	if direction.is_zero_approx():
		direction = Vector2.DOWN
	draw_line(p - direction * 28.0, p, Color(0.69, 0.94, 1.0, 0.4), 5.0, true)
	var points := PackedVector2Array([p - direction * 17, p + direction.orthogonal() * 8, p + direction * 8, p - direction.orthogonal() * 8])
	draw_colored_polygon(points, Color("c0ecff"))
	draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[3], points[0]]), Color("3d789b"), 2.0, true)
	draw_circle(p + Vector2(-2, -1), 2.5, Color("f3ffff"))

func _swarm() -> void:
	var p: Vector2 = model.p
	var face: Vector2 = model.face
	if face.length_squared() < 0.01:
		face = Vector2.RIGHT
	var compact: bool = model.charging
	var burst: bool = model.burst_left > 0.0
	if model.phase == "ending":
		_ending_swarm()
		return
	for i in range(model.bees - 1, 0, -1):
		var side := 1.0 if i % 2 else -1.0
		var along := float(i) * (8.0 if compact or burst else 10.0)
		var center := _path_position(along)
		var tangent := (_path_position(maxf(0.0, along - 6.0)) - center).normalized()
		if tangent.is_zero_approx():
			tangent = face
		var across := side * (2.5 if compact or burst else 9.0 + float(i) * 0.7)
		var companion := center + tangent.orthogonal() * across
		if not _free_visual_position(companion):
			companion = center
		_bee(companion, 0.68, tangent, 0.85, false, i)
	if model.invulnerable <= 0.0 or sin(clock * 28.0) > -0.35:
		if burst:
			_ellipse(p - face * 16.0, Vector2(38, 17), Color(1.0, 0.89, 0.48, 0.18), face.angle())
		_bee(p, 1.0, face, 1.0, false, 0.0)
	if compact:
		var fill: float = clampf(model.charge, 0.0, 1.0)
		var ready: bool = fill >= 0.75
		var col := Color("fff4b3") if ready else GOLD
		draw_arc(p, 27, -PI / 2, -PI / 2 + TAU * maxf(0.005, fill), 48, col, 4.0, true)
		var begin := p + face * 37
		var end := p + face * (67.0 + fill * 58.0)
		draw_line(begin, end, Color(0.12, 0.25, 0.24, 0.6), 8.0, true)
		draw_line(begin, end, col, 4.0, true)
		draw_polyline(PackedVector2Array([end - face * 14 + face.orthogonal() * 10, end, end - face * 14 - face.orthogonal() * 10]), col, 4.0, true)
		if ready:
			draw_arc(p, 33 + sin(clock * 8.0) * 2.0, 0, TAU, 48, Color(1.0, 0.95, 0.65, 0.3), 1.5, true)

func _path_position(distance: float) -> Vector2:
	var cursor: Vector2 = model.p
	for i in range(_path.size() - 1, -1, -1):
		var length := cursor.distance_to(_path[i])
		if length >= distance and length > 0.001:
			return cursor.lerp(_path[i], distance / length)
		distance -= length
		cursor = _path[i]
	return cursor

func _free_visual_position(point: Vector2) -> bool:
	for wall in model.walls:
		if not wall.broken and wall.rect.grow(8.0).has_point(point):
			return false
	return true

func _ending_swarm() -> void:
	var progress := clampf(_ending_elapsed / 1.8, 0.0, 1.0)
	var eased := 1.0 - pow(1.0 - progress, 3.0)
	for i in range(model.bees - 1, 0, -1):
		var home: Vector2 = model.exit_pos + Vector2(-43 + (i % 5) * 18, 65 + (i / 5) * 18)
		var start := _path_position(float(i) * 10.0)
		var p := start.lerp(home, eased)
		_bee(p, 0.68, Vector2.RIGHT, 1.0, false, float(i))
	var lead: Vector2 = model.p.lerp(model.exit_pos + Vector2(-5, 42), eased)
	_bee(lead, 1.0, Vector2.RIGHT, 1.0, false, 0.0)

func _ending_weather(cam: float) -> void:
	var edge: float = model.exit_pos.x - 106.0
	var width := maxf(1.0, edge - cam)
	for i in 60:
		var x := cam + fposmod(float(i) * 63.3 - clock * 42.0, width)
		var y := fposmod(float(i) * 67.3 + clock * 390.0, 880.0) - 40.0
		draw_line(Vector2(x, y), Vector2(x - 8, y + 25), Color(0.77, 0.91, 0.98, 0.29), 1.0, true)

func _bee(p: Vector2, size: float, face: Vector2, alpha: float, trapped: bool, seed_value: float) -> void:
	var angle := face.angle()
	var wing := 0.7 + absf(sin(clock * 35.0 + seed_value)) * 0.45
	if model != null and model.phase == "ending":
		wing *= 0.28 + 0.72 * exp(-_ending_elapsed * 2.0)
	var axis := face
	var cross := axis.orthogonal()
	var wing_color := Color(0.96, 1.0, 0.90, alpha * 0.82)
	_ellipse(p - cross * 8 * size - axis * 2 * size, Vector2(10, 6 * wing) * size, wing_color, angle - 0.7)
	_ellipse(p + cross * 8 * size - axis * 2 * size, Vector2(10, 6 * wing) * size, wing_color, angle + 0.7)
	_ellipse(p, Vector2(15, 10) * size, Color(0.09, 0.19, 0.18, alpha), angle)
	_ellipse(p, Vector2(12.8, 8.2) * size, Color(1.0, 0.77, 0.29, alpha), angle)
	for stripe in [-5.0, 1.0]:
		draw_line(p + axis * stripe * size - cross * 6.8 * size, p + axis * stripe * size + cross * 6.8 * size, Color(0.16, 0.25, 0.21, alpha), 3.5 * size, true)
	var eye := p + axis * 8 * size - cross * 3 * size
	draw_circle(eye, 2.4 * size, Color(0.09, 0.15, 0.15, alpha))
	draw_circle(eye - axis * 0.3 * size - cross * 0.7 * size, 0.9 * size, Color(1, 1, 0.9, alpha))
	if not trapped:
		draw_line(p + axis * 7 * size - cross * 7 * size, p + axis * 10 * size - cross * 13 * size, Color(0.13, 0.23, 0.20, alpha), 1.5 * size, true)
		draw_circle(p + axis * 10 * size - cross * 13 * size, 1.5 * size, Color(0.13, 0.23, 0.20, alpha))
	if size >= 0.95:
		# The player wears one pale scarf; followers are always visibly smaller.
		var scarf := PackedVector2Array([p - axis * 3 + cross * 7, p - axis * 17 + cross * (12 + sin(clock * 8) * 2), p - axis * 13 + cross * 5])
		draw_colored_polygon(scarf, Color("fff0bb"))

func _effects() -> void:
	for ring in ripples:
		var progress: float = 1.0 - ring.life / 0.5
		var tint: Color = ring.color
		tint.a = ring.life * 1.2
		draw_arc(ring.pos, 14 + progress * 76, 0, TAU, 48, tint, 3.0 * (1.0 - progress) + 0.5, true)
	for bit in particles:
		var tint: Color = bit.color
		tint.a = minf(1.0, bit.life / bit.max_life * 1.5)
		_ellipse(bit.pos, Vector2(bit.size * 1.5, bit.size * 0.6), tint, bit.angle + clock * 1.5)

func _foreground(act: int, cam: float) -> void:
	var tint: Color = [Color("254f42"), Color("204f4a"), Color("1e3546")][act]
	for i in 40:
		var x := fposmod(i * 43.7 - cam * 1.15, 1400.0) - 60.0
		var high := 14.0 + float(i % 7) * 6.0
		var tip := Vector2(x + 8 + sin(clock * 1.4 + i) * 7, 800 - high)
		_leaf(Vector2(x, 805), tip, 3.5 + i % 3, tint)
	draw_rect(Rect2(0, 792, 1280, 8), tint)

func _flower(p: Vector2, radius: float, tint: Color, seed_value: float) -> void:
	for i in 5:
		var a := i * TAU / 5.0 + seed_value + sin(clock * 0.6 + seed_value) * 0.04
		_ellipse(p + Vector2.from_angle(a) * radius * 0.52, Vector2(radius * 0.67, radius * 0.38), tint, a)
	draw_circle(p, radius * 0.23, tint.darkened(0.18))

func _ellipse(center: Vector2, radius: Vector2, tint: Color, angle := 0.0) -> void:
	var points := PackedVector2Array()
	for i in 24:
		var theta := i * TAU / 24.0
		points.append(center + Vector2(cos(theta) * radius.x, sin(theta) * radius.y).rotated(angle))
	draw_colored_polygon(points, tint)

func _leaf(a: Vector2, b: Vector2, width: float, tint: Color) -> void:
	var normal := (b - a).normalized().orthogonal()
	var points := PackedVector2Array()
	for i in 13:
		var t := float(i) / 12.0
		points.append(a.lerp(b, t) + normal * sin(t * PI) * width)
	for i in range(12, -1, -1):
		var t := float(i) / 12.0
		points.append(a.lerp(b, t) - normal * sin(t * PI) * width * 0.55)
	draw_colored_polygon(points, tint)

func _curve(a: Vector2, b: Vector2, c: Vector2, d: Vector2, tint: Color, width: float) -> void:
	var points := PackedVector2Array()
	for i in 21:
		points.append(a.bezier_interpolate(b, c, d, float(i) / 20.0))
	draw_polyline(points, tint, width, true)
