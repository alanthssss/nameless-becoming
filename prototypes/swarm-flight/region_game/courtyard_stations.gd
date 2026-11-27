extends RefCounted
## Registered to the 1280 × 800 #427 inner-courtyard painting.
const GOODS: Texture2D = preload("res://art/honey-steelyard-goods.webp")
const POND_SHEET: Texture2D = preload("res://art/honey-flight-sheet-pond.webp")
const MEADOW_SHEET: Texture2D = preload("res://art/honey-flight-sheet-meadow.webp")
const PIVOT := Vector2(280, 434)
const PAN_ARM := -33.0
const SHEET_FRAME := Rect2(640, 347, 280, 127)
const PAN := Rect2(0, 0, 58, 30)
const STONE := Rect2(65, 0, 30, 30)
const STONE_DROP := Vector2(0, 29)
const FIBER := Rect2(104, 0, 30, 29)
const JAR := Rect2(145, 0, 41, 35)

static func weight_arm(t: float) -> float:
	return lerpf(72.0, 100.0, smoothstep(.44, .82, t))

static func inclination(t: float) -> float:
	# The added load lowers the pan on the left. Sliding the counterweight
	# away from the pivot restores the horizontal beam before the shop opens.
	return lerpf(.016, -.145, smoothstep(.22, .43, t)) * (1.0 - smoothstep(.50, .90, t))

static func weight_hook(t: float) -> Vector2:
	return PIVOT + Vector2(weight_arm(t), 0).rotated(inclination(t))

static func goods(v: Node2D, source: Rect2, center: Vector2, size := 1.0) -> void:
	var span := source.size * size
	v.draw_texture_rect_region(GOODS, Rect2(center-span*.5, span), source)

static func _draw_counterweight(v: Node2D, hook: Vector2) -> void:
	const HEMP_SHADE := Color("#705636")
	const HEMP := Color("#c09b68")
	const HEMP_LIGHT := Color("#e2c593")
	v.draw_set_transform(hook)
	# The hitch wraps over the beam. Its two ends come together below it.
	var hitch := PackedVector2Array([Vector2(-1,9), Vector2(-3,4), Vector2(-3,-2),
		Vector2(-1,-3.5), Vector2(2,-3.3), Vector2(3,1), Vector2(2,5), Vector2(-1,9)])
	v.draw_polyline(hitch, HEMP_SHADE, 3.0, true)
	v.draw_polyline(hitch, HEMP, 1.6, true)
	v.draw_line(Vector2(-2.6,2), Vector2(-2.6,-2), HEMP_LIGHT, 1.1, true)
	# The same cord disappears into a bore just below the top of the stone.
	# Draw its return behind the stone, leaving both flanks and the heel bare.
	v.draw_line(Vector2(-1,8), STONE_DROP + Vector2(1,-10), HEMP_SHADE, 2.8, true)
	v.draw_line(Vector2(-1.4,8), STONE_DROP + Vector2(.5,-10), HEMP, 1.5, true)
	v.draw_set_transform(hook + STONE_DROP)
	goods(v, STONE, Vector2.ZERO)
	var eye := Vector2(0,-8)
	v.draw_arc(eye, 2.4, .05 * PI, .95 * PI, 8, Color("#b6a46d"), 1.1, true)
	v.draw_circle(eye, 2.0, Color("#493e2b"), true, -1, true)
	var end := PackedVector2Array([Vector2(-.7,-17), Vector2(-1.6,-13),
		Vector2(-1.3,-10), eye])
	v.draw_polyline(end, HEMP_SHADE, 2.7, true)
	v.draw_polyline(end, HEMP, 1.5, true)
	v.draw_set_transform(Vector2.ZERO)

static func steelyard(v: Node2D, t: float, entering: bool) -> void:
	var angle := inclination(t)
	var pan_hook := PIVOT + Vector2(PAN_ARM,0).rotated(angle)
	var pan := pan_hook + Vector2(0, 41)
	var weight := weight_hook(t)
	var stone := weight + STONE_DROP
	v._ground_shadow(pan+Vector2(3,17), Vector2(30,4), .22)
	v._ground_shadow(stone+Vector2(2,16), Vector2(16,3), .18)

	# The single support goes to the rooted branch tip. Both hangers remain
	# vertical under gravity even while the graduated wooden beam pivots.
	v.draw_line(Vector2(279,419), PIVOT, Color("624126"), 3.4, true)
	for y in [421,425,429]:
		v.draw_line(Vector2(278,y+2), Vector2(281,y), Color("d5b27c"), 1.7, true)
	v.draw_set_transform(PIVOT, angle)
	v.draw_line(Vector2(-40,1.3),Vector2(131,1.3),Color("61391e"),6.2,true)
	v.draw_line(Vector2(-40,-.4),Vector2(131,-.4),Color("b87432"),4.7,true)
	v.draw_line(Vector2(-38,-1.5),Vector2(129,-1.5),Color("e2a460"),1.5,true)
	for tick in range(12,125,7):
		v.draw_line(Vector2(tick,-.8),Vector2(tick,2.4 if tick%3 == 0 else 1.1),Color("f0d598"),1.0,true)
	v.draw_set_transform(Vector2.ZERO)
	for hook: Vector2 in [pan_hook, PIVOT]:
		v.draw_arc(hook, 2.8, 0, TAU, 12, Color("d8bc81"), 1.3, true)
	for side in [-1,1]:
		var rim := pan + Vector2(side*21,-4)
		v.draw_line(pan_hook+Vector2(0,2),rim,Color("7d603e"),2.4,true)
		v.draw_line(pan_hook+Vector2(0,2),rim,Color("ead7ac"),1.2,true)
	goods(v, PAN, pan)
	v.draw_line(pan_hook+Vector2(0,3),pan+Vector2(0,4),Color("dbc297"),1.15,true)
	_draw_counterweight(v, weight)
	if entering:
		var drop := smoothstep(.09, .36, t)
		var at := Vector2(234,390).lerp(pan+Vector2(2,-7),drop)
		at.y -= 22.0*sin(PI*drop)
		goods(v, FIBER, at, .66)

static func sheet(v: Node2D, meadow: bool, t: float) -> void:
	var texture := MEADOW_SHEET if meadow else POND_SHEET
	if t <= 0:
		v.draw_texture_rect(texture,SHEET_FRAME,false)
		return
	# The top stays pinned by its pebble. A travelling bend rolls just the
	# exposed lower corner back, revealing the dark support under the paper.
	var lift := smoothstep(.15,.44,t)*(1.0-.40*smoothstep(.60,.90,t))
	const COLS := 8
	const ROWS := 5
	for row in ROWS:
		for col in COLS:
			var points := PackedVector2Array()
			var uvs := PackedVector2Array()
			for step: Vector2 in [Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN]:
				var uv := (Vector2(col,row)+step)/Vector2(COLS,ROWS)
				var fold := smoothstep(.45,.86,uv.x)*smoothstep(.49,.95,uv.y)
				points.append(SHEET_FRAME.position + uv*SHEET_FRAME.size + Vector2(-15,-23)*lift*fold)
				uvs.append(uv)
			v.draw_polygon(points,PackedColorArray([Color.WHITE]),uvs,texture)

static func bee_position(entry: String, t: float, start: Vector2) -> Vector2:
	if entry == "shop":
		# Hover over the load, then push the sliding loop across the beam.
		var hand := weight_hook(t)+Vector2(-16,-12)
		var at := start.lerp(Vector2(251,431), smoothstep(0,.22,t))
		return at.lerp(hand,smoothstep(.24,.47,t))
	var tip := Vector2(876,450)
	if t < .40:
		return start.lerp(tip+Vector2(7,-8),smoothstep(0,.40,t))
	var follow := smoothstep(.40,.96,t)
	return (tip+Vector2(7,-8)).bezier_interpolate(Vector2(908,361),Vector2(810,359),Vector2(742,412),follow)
