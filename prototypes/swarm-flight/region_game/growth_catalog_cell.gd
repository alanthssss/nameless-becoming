extends "res://nectar_growth_node.gd"
## Screen-sized lettering over native clickable, focusable map cells.
const CENTER := Vector2(18,16)
const EDGES := [Color("69804e"), Color("a77544"), Color("a56d42"), Color("4e7b7b"), Color("7c844c"), Color("87647f"), Color("9d773c")]
var sector := 0
var icon_name := "gather"
var planned := false
var zoom_lod := 1.0

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
	var hit_radius := clampf(15.0*zoom_lod,15,32)
	if on_screen.length() <= hit_radius: return true
	if _show_label():
		var width := ui_font.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x+6
		var label_y := _radius()+5
		return Rect2(-width/2,label_y,width,18).has_point(on_screen)
	return false

func _show_label() -> bool:
	return selected or zoom_lod >= 1.78

func _radius() -> float:
	return clampf(10.6*zoom_lod,10.6,31.0)

func _draw() -> void:
	if not ui_font: return
	var radius := _radius()
	draw_set_transform(CENTER,0,Vector2.ONE/zoom_lod)
	var hex := PackedVector2Array()
	for i in 6: hex.append(Vector2.from_angle(-PI/2+i*TAU/6)*radius)
	var edge: Color = EDGES[sector]
	var fill := Color("faf4df") if not planned else Color("e9e8d7")
	if selected: fill = Color("f4da99")
	if state == "ready": fill = Color("e2ebc5")
	draw_colored_polygon(hex,fill)
	hex.append(hex[0])
	draw_polyline(hex,Color("7a5527") if selected else edge,2.8 if selected else 1.35,true)
	Art.journal_icon(self,icon_name,Vector2.ZERO,radius*.84,Color("d1cec1") if planned else Color.WHITE)
	if planned:
		draw_circle(Vector2(radius*.57,-radius*.66),3.0,edge,true,-1,true)
	elif rank>0:
		draw_circle(Vector2(radius*.58,-radius*.64),3.2,Color("bb852c"),true,-1,true)
	if ink_bloom>0:
		draw_arc(Vector2.ZERO,radius+(1.0-ink_bloom)*10,0,TAU,32,Color("bf842c",ink_bloom),2,true)
	if zoom_lod>1.65 and max_rank>1:
		for i in max_rank:
			draw_circle(Vector2((i-(max_rank-1)*.5)*7,radius-2),2.6,Color("a16927") if i<rank else Color("d7caa7"),true,-1,true)
	if _show_label():
		var font_size := 14
		var extent := ui_font.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
		var y := radius+4
		draw_rect(Rect2(-extent/2-2,y,extent+4,18),Color("f6eddbed"))
		draw_string(ui_font,Vector2(-extent/2,y+14),title,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color("443e2d"))
