extends "res://nectar_growth_node.gd"
## Screen-sized lettering over native clickable, focusable map cells.
const CENTER := Vector2(18,16)
const EDGES := [Color("69804e"), Color("a77544"), Color("a56d42"), Color("4e7b7b"), Color("7c844c"), Color("87647f"), Color("9d773c")]
var sector := 0
var icon_name := "gather"
var planned := false
var zoom_lod := 1.0
var layout_radius := 10.6
var label_rect := Rect2()

func set_rank(value: int) -> void:
	var grew := rank_initialized and value > rank
	rank = value
	rank_initialized = true
	if not grew or reduced_motion: return
	if growth_tween: growth_tween.kill()
	growth_tween = create_tween()
	growth_tween.tween_method(_bloom,1.0,0.0,.42)

func _has_point(p: Vector2) -> bool:
	var on_screen := (p-CENTER)*zoom_lod
	var hit_radius := maxf(12.0,_radius()+1.0)
	return on_screen.length() <= hit_radius or (_show_label() and label_rect.has_point(on_screen))

func _show_label() -> bool:
	return label_rect.has_area()

func _radius() -> float:
	return clampf(layout_radius*zoom_lod,8.0,31.0)

func state_caption() -> String:
	var caption: String
	match state:
		"max": caption = "已学满"
		"ready": caption = "可升级" if rank>0 else "可学习"
		"poor": caption = "金币或材料不足"
		"locked": caption = "条件未满足"
		_: return "后续开放"
	return "已学 %d/%d · %s" % [rank,max_rank,caption] if rank>0 and rank<max_rank else caption

func icon_opacity() -> float:
	if rank>0 or state=="ready": return 1.0
	match state:
		"poor": return .72
		"locked": return .46
		_: return .25

func _hex(radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 6: points.append(Vector2.from_angle(-PI/2+i*TAU/6)*radius)
	points.append(points[0])
	return points

func _draw() -> void:
	if not ui_font: return
	var radius := _radius()
	draw_set_transform(CENTER,0,Vector2.ONE/zoom_lod)
	var hex := _hex(radius)
	var edge := Color(EDGES[sector],1.0 if rank>0 or state=="ready" else .67)
	var fill := Color("fff1cc")
	if state == "ready": fill = Color("e3edc8")
	elif state == "planned": fill = Color("eee7d6")
	elif rank == 0 and state != "ready": fill = Color("eee4c9")
	draw_colored_polygon(hex.slice(0,6),fill)
	draw_polyline(hex,edge,2.0 if rank>0 or state=="ready" else 1.35,true)
	Art.journal_icon(self,icon_name,Vector2.ZERO,radius*.82,Color(Color.WHITE,icon_opacity()))
	_draw_status(radius)
	if selected:
		_draw_focus_corners(radius)
	if ink_bloom>0:
		draw_arc(Vector2.ZERO,radius+(1.0-ink_bloom)*10,0,TAU,32,Color("bf842c",ink_bloom),2,true)
	if zoom_lod>1.65 and max_rank>1 and not planned:
		for i in max_rank:
			var pip := Vector2((i-(max_rank-1)*.5)*7,radius-2)
			draw_circle(pip,2.5,Color("9a682a"),i<rank,-1.0 if i<rank else 1.0,true)
	if _show_label():
		var background := Color("49391f") if selected else Color("f8eedcf2")
		var ink := Color("fff4cf") if selected else Color("433820")
		draw_rect(label_rect,background)
		draw_string(ui_font,label_rect.position+Vector2(3,14),title,HORIZONTAL_ALIGNMENT_LEFT,-1,14,ink)

func _draw_focus_corners(radius: float) -> void:
	var ext := radius*.9+2
	var arm := clampf(radius*.32,4,9)
	for sign_x in [-1,1]:
		for sign_y in [-1,1]:
			var at := Vector2(sign_x,sign_y)*ext
			var corner := PackedVector2Array([at-Vector2(sign_x*arm,0),at,at-Vector2(0,sign_y*arm)])
			draw_polyline(corner,Color("5b4425"),4.8,true)
			draw_polyline(corner,Color("fff6d6"),2.3,true)

func _draw_status(radius: float) -> void:
	# At overview scale avoid forty competing marks. Filled cells and the
	# available frontier keep their marks; the quieter ones return at reading scale.
	if zoom_lod < 1.65 and state in ["planned","locked","poor"] and rank==0 and not selected:
		return
	var tint := Color("46653b")
	match state:
		"poor": tint = Color("866129")
		"locked": tint = Color("775644")
		"planned": tint = Color("817664")
	var at := Vector2(radius*.62,-radius*.62)
	var r := clampf(radius*.30,4.8,7.7)
	draw_circle(at,r+.9,Color("fff4d9"),true,-1,true)
	draw_circle(at,r,tint,true,-1,true)
	var white := Color("fff8dd")
	match state:
		"ready":
			draw_line(at+Vector2.LEFT*r*.48,at+Vector2.RIGHT*r*.48,white,1.6,true)
			draw_line(at+Vector2.UP*r*.48,at+Vector2.DOWN*r*.48,white,1.6,true)
		"max":
			draw_polyline(PackedVector2Array([at+Vector2(-.55,-.02)*r,at+Vector2(-.12,.40)*r,at+Vector2(.54,-.46)*r]),white,1.6,true)
		"poor":
			draw_circle(at,r*.54,white,false,1.4,true)
			draw_line(at+Vector2.UP*r*.26,at+Vector2.DOWN*r*.26,white,1.4,true)
		"locked":
			draw_arc(at+Vector2.UP*r*.13,r*.32,PI,TAU,8,white,1.4,true)
			draw_rect(Rect2(at+Vector2(-.43,-.06)*r,Vector2(.86,.56)*r),white)
		_:
			for i in range(-1,2):
				draw_circle(at+Vector2(i*r*.41,0),r*.13,white,true,-1,true)
