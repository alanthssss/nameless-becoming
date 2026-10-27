extends RefCounted
## Local, wordless flower-wax window. Fictional garden craft, not bee biology.
## Source: docs/COLOR_SYSTEM.md; order: world-elements.md table, first row = 0.
## Only the transmitted light moves with committed story progress. No wall clock,
## unlock counters, gameplay state, or whole-scene tint belongs in this painter.
const COLORS := [
	"3D5560", "597A82", "739BA0", "008080", "20927C", "4AA56E",
	"80995C", "BB7F48", "D8593C", "DC3C3C", "E05857", "E37970",
	"E0A188", "DDC2A6", "E5DFCE", "F5F5F5", "DEDCD9", "BABABC",
	"8C8E94", "5C6069", "3A3C45", "101420", "1B2632", "2A3C48",
]
static var _panes: Array[PackedVector2Array] = []
static var _centers: Array[Vector2] = []
static var _rim := PackedVector2Array()

static func color_at(index: int) -> Color:
	return Color(COLORS[((index % COLORS.size()) + COLORS.size()) % COLORS.size()])

static func draw_window(canvas: Node2D, center: Vector2, progress: float, scale: float = 1.0) -> void:
	if scale <= 0.0 or not is_finite(scale): return
	_prepare()
	var step := clampf(progress, 0.0, 2.0) if is_finite(progress) else 0.0
	var focus := 9.0 + step
	var left := int(floor(focus))
	var light_at := _centers[left].lerp(_centers[mini(left + 1, 11)], focus - left)
	# A narrow, uneven twig frame belongs to the garden, rather than to the HUD.
	_fill(canvas, _rim, center + Vector2(4, 7) * scale, scale, Color("243c2948"))
	_fill(canvas, _rim, center, scale, Color("f3d89bb4"))
	_line(canvas, _rim, center, scale, Color("34472c"), 15.0)
	_line(canvas, _rim, center, scale, Color("786329"), 11.0)
	_line(canvas, _rim, center + Vector2(-1, -2) * scale, scale, Color("b5a24a"), 5.0)
	# Shared curved boundaries keep the pieces joined without a regular grid.
	for i in _panes.size():
		var distance := _centers[i].distance_to(light_at)
		var lit := exp(-distance * distance / 2800.0)
		var pigment := color_at(i)
		var glass := pigment.lerp(Color("ffe4a8"), 0.12 + lit * 0.18)
		glass.a = 0.84
		_fill(canvas, _panes[i], center, scale, glass)
		_line(canvas, _panes[i], center, scale, Color("7b703ac9"), 2.4)
		# A small reflected crescent and irregular brush hatching retain material
		# cues in grayscale. Light advances by position as well as by hue.
		var pane_center: Vector2 = _centers[i]
		var sheen := Color("fff2c6")
		sheen.a = 0.12 + lit * 0.46
		var top := pane_center + Vector2(-10, -10)
		_curve(canvas, top, top + Vector2(8, -5), top + Vector2(20, -3), center, scale, sheen, 2.4 + lit)
		var vein := Color("e5d6a0")
		vein.a = 0.15 + lit * 0.22
		var direction := Vector2(10.0 + float(i % 3) * 2.0, -15.0)
		_curve(canvas, pane_center - direction * 0.65, pane_center + Vector2(-4, -1), pane_center + direction * 0.65, center, scale, vein, 1.1)
		_curve(canvas, pane_center, pane_center + Vector2(6, 2), pane_center + Vector2(12, 0), center, scale, vein, 0.8)
		for stroke in 2:
			var offset := Vector2(-12 + stroke * 12, 5 + (i % 3) * 2)
			var tint := pigment.lightened(0.3)
			tint.a = 0.12
			_curve(canvas, pane_center + offset, pane_center + offset + Vector2(3, -2), pane_center + offset + Vector2(8, -1), center, scale, tint, 1.8)
	# The three adjacent illuminated pieces share this travelling, tapered glint.
	var light_color := Color("fff4ce")
	light_color.a = 0.72
	_curve(canvas, light_at + Vector2(-16, -12), light_at + Vector2(-3, -21), light_at + Vector2(14, -15), center, scale, light_color, 3.0)
	# A few attached leaves soften the arch without concealing the glass shapes.
	_leaf(canvas, Vector2(-81, -83), Vector2(-122, -99), 12, center, scale, Color("658d38"))
	_leaf(canvas, Vector2(-80, -84), Vector2(-92, -124), 11, center, scale, Color("8baf4b"))
	_leaf(canvas, Vector2(83, 78), Vector2(122, 61), 13, center, scale, Color("587d32"))
	_leaf(canvas, Vector2(82, 78), Vector2(98, 111), 10, center, scale, Color("91ae4e"))
	_curve(canvas, Vector2(-85, -79), Vector2(-108, -53), Vector2(-111, -12), center, scale, Color("d8cb70a8"), 2.0)
	_curve(canvas, Vector2(99, 27), Vector2(95, 68), Vector2(64, 91), center, scale, Color("d8cb7078"), 1.8)

static func _prepare() -> void:
	if not _panes.is_empty(): return
	var rows := [-111.0, -82.0, -42.0, 1.0, 42.0, 79.0, 105.0]
	var widths := [40.0, 84.0, 108.0, 114.0, 105.0, 81.0, 32.0]
	var grid: Array[PackedVector2Array] = []
	for row in 7:
		var points := PackedVector2Array()
		for column in 5:
			var fraction: float = [0.0, 0.20, 0.48, 0.76, 1.0][column]
			var wobble := sin(row * 2.7 + column * 1.4) * 5.0 if column > 0 and column < 4 else 0.0
			var y: float = rows[row] + (sin(column * 2.3 + row) * 5.0 if row > 0 and row < 6 else 0.0)
			points.append(Vector2(lerpf(-widths[row], widths[row], fraction) + wobble, y))
		grid.append(points)
	for row in 6:
		for column in 4:
			var a: Vector2 = grid[row][column]
			var b: Vector2 = grid[row][column + 1]
			var c: Vector2 = grid[row + 1][column + 1]
			var d: Vector2 = grid[row + 1][column]
			var pane := PackedVector2Array()
			_join(pane, _edge(a, b, sin(row + column * 1.7) * 4.0))
			_join(pane, _edge(b, c, cos(row * 1.6 + column + 1) * 4.0))
			_join(pane, _reversed(_edge(d, c, sin(row + 1 + column * 1.7) * 4.0)))
			_join(pane, _reversed(_edge(a, d, cos(row * 1.6 + column) * 4.0)))
			pane.append(pane[0])
			_panes.append(pane)
			_centers.append((a + b + c + d) / 4.0)
	for column in 4: _join(_rim, _edge(grid[0][column], grid[0][column + 1], sin(column * 1.7) * 4.0))
	for row in 6: _join(_rim, _edge(grid[row][4], grid[row + 1][4], cos(row * 1.6 + 4) * 4.0))
	for column in range(3, -1, -1): _join(_rim, _reversed(_edge(grid[6][column], grid[6][column + 1], sin(6 + column * 1.7) * 4.0)))
	for row in range(5, -1, -1): _join(_rim, _reversed(_edge(grid[row][0], grid[row + 1][0], cos(row * 1.6) * 4.0)))
	_rim.append(_rim[0])

static func _edge(a: Vector2, b: Vector2, bend: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var control := (a + b) * 0.5 + (b - a).orthogonal().normalized() * bend
	for i in 9:
		var t := i / 8.0
		points.append(a.lerp(control, t).lerp(control.lerp(b, t), t))
	return points

static func _reversed(points: PackedVector2Array) -> PackedVector2Array:
	points.reverse()
	return points

static func _join(target: PackedVector2Array, edge: PackedVector2Array) -> void:
	for i in range(1 if not target.is_empty() else 0, edge.size()): target.append(edge[i])

static func _placed(points: PackedVector2Array, center: Vector2, scale: float) -> PackedVector2Array:
	var placed := PackedVector2Array()
	for point in points: placed.append(center + point * scale)
	return placed

static func _fill(canvas: Node2D, points: PackedVector2Array, center: Vector2, scale: float, color: Color) -> void:
	canvas.draw_colored_polygon(_placed(points, center, scale), color)

static func _line(canvas: Node2D, points: PackedVector2Array, center: Vector2, scale: float, color: Color, width: float) -> void:
	canvas.draw_polyline(_placed(points, center, scale), color, width * scale, true)

static func _curve(canvas: Node2D, a: Vector2, control: Vector2, b: Vector2, center: Vector2, scale: float, color: Color, width: float) -> void:
	var points := PackedVector2Array()
	for i in 13:
		var t := i / 12.0
		points.append(a.lerp(control, t).lerp(control.lerp(b, t), t))
	_line(canvas, points, center, scale, color, width)

static func _leaf(canvas: Node2D, a: Vector2, b: Vector2, width: float, center: Vector2, scale: float, color: Color) -> void:
	var axis := b - a
	var side := axis.orthogonal().normalized()
	var points := PackedVector2Array()
	for i in 15:
		var t := i / 14.0
		points.append(a + axis * t + side * sin(t * PI) * width)
	for i in range(14, -1, -1):
		var t := i / 14.0
		points.append(a + axis * t - side * sin(t * PI) * width * 0.64)
	_fill(canvas, points, center, scale, color.darkened(0.12))
	_curve(canvas, a, a.lerp(b, 0.55) + side * 3.0, b, center, scale, color.lightened(0.35), 1.4)
