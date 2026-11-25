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

static func steelyard(v: Node2D, t: float, entering: bool) -> void:
	var angle := inclination(t)
	var pan_hook := PIVOT + Vector2(PAN_ARM,0).rotated(angle)
	var pan := pan_hook + Vector2(0, 41)
	var weight := weight_hook(t)
	var stone := weight + Vector2(0, 29)
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
	for hook: Vector2 in [pan_hook, PIVOT, weight]:
		v.draw_arc(hook, 2.8, 0, TAU, 12, Color("d8bc81"), 1.3, true)
	for side in [-1,1]:
		var rim := pan + Vector2(side*21,-4)
		v.draw_line(pan_hook+Vector2(0,2),rim,Color("7d603e"),2.4,true)
		v.draw_line(pan_hook+Vector2(0,2),rim,Color("ead7ac"),1.2,true)
	goods(v, PAN, pan)
	v.draw_line(pan_hook+Vector2(0,3),pan+Vector2(0,4),Color("dbc297"),1.15,true)
	v.draw_line(weight+Vector2(0,2),stone-Vector2(0,11),Color("bb9466"),2.1,true)
	goods(v, STONE, stone)
	# Three bound cords cradle the stone. The outside loops meet beneath it.
	for width in [10.0, 3.0, -8.0]:
		var sling := PackedVector2Array([stone+Vector2(0,-13),stone+Vector2(width,-5),
			stone+Vector2(width*.97,5),stone+Vector2(width*.55,10),stone+Vector2(0,13)])
		v.draw_polyline(sling,Color("6b5539"),2.3,true)
		v.draw_polyline(sling,Color("c7a879"),1.25,true)
	v.draw_arc(stone+Vector2(0,-13), 2.4, 0, TAU, 10, Color("d4b583"), 1.3, true)
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
