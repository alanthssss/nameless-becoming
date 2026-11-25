extends "res://nectar_growth_node.gd"
## Screen-sized lettering over native clickable, focusable map cells.
const CENTER := Vector2(18,16)
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

func _draw() -> void:
	if not ui_font: return
	var radius := _radius()
	draw_set_transform(CENTER,0,Vector2.ONE/zoom_lod)
	Art.journal_icon(self,icon_name,Vector2.ZERO,radius*.82,Color(Color.WHITE,icon_opacity()))
	_draw_status(radius)
	if selected or ink_bloom>0:
		var strength := 1.0 if selected else ink_bloom
		var span := radius*(1.28+.22*ink_bloom)
		_draw_underline(Vector2(-span*.54,radius+2.2),span,2.15+.7*ink_bloom,Color("885b2f",strength))
	if zoom_lod>1.65 and max_rank>1 and not planned:
		for i in max_rank:
			var pip := Vector2((i-(max_rank-1)*.5)*7,radius-2)
			draw_circle(pip,2.3,Color("815c34"),i<rank,-1.0 if i<rank else 1.0,true)
	if _show_label():
		var baseline := label_rect.position+Vector2(3,14)
		var ink := Color("4d301c") if selected else Color("433820")
		if selected:
			var span := minf(label_rect.size.x-6.0,43.0)
			_draw_underline(baseline+Vector2(1,3),span,1.8,Color("794e2e"))
		draw_string_outline(ui_font,baseline,title,HORIZONTAL_ALIGNMENT_LEFT,-1,14,1,Color("f5e4ba",.65))
		draw_string(ui_font,baseline,title,HORIZONTAL_ALIGNMENT_LEFT,-1,14,ink)

func _draw_underline(at: Vector2, span: float, weight: float, ink: Color) -> void:
	# A pen touches down, widens, then lifts off the page.
	var shoulder := at+Vector2(span*.22,.1)
	var turn := at+Vector2(span*.66,-.2)
	var tip := at+Vector2(span,-1.1)
	draw_line(at,shoulder,Color(ink,ink.a*.67),weight*.54,true)
	draw_line(shoulder,turn,ink,weight,true)
	draw_line(turn,tip,Color(ink,ink.a*.80),weight*.51,true)

func _draw_status(radius: float) -> void:
	# At overview scale avoid forty competing marks. Filled cells and the
	# available frontier keep their marks; the quieter ones return at reading scale.
	if zoom_lod < 1.65 and state in ["planned","locked","poor"] and rank==0 and not selected:
		return
	var tint := Color("435b34")
	match state:
		"poor": tint = Color("765021")
		"locked": tint = Color("694833")
		"planned": tint = Color("776448")
	var at := Vector2(radius*.81,-radius*.58)
	var r := clampf(radius*.30,4.8,7.7)
	match state:
		"ready":
			draw_line(at+Vector2(-.67,.05)*r,at+Vector2(.70,-.04)*r,tint,1.8,true)
			draw_line(at+Vector2(.03,-.69)*r,at+Vector2(-.04,.69)*r,tint,1.8,true)
		"max":
			draw_polyline(PackedVector2Array([at+Vector2(-.76,-.03)*r,at+Vector2(-.24,.56)*r,at+Vector2(.76,-.69)*r]),tint,2.0,true)
		"poor":
			draw_circle(at,r*.65,tint,false,1.45,true)
			draw_line(at+Vector2(-.03,-.33)*r,at+Vector2(.03,.32)*r,tint,1.35,true)
		"locked":
			draw_arc(at+Vector2.UP*r*.12,r*.39,PI,TAU,10,tint,1.55,true)
			draw_rect(Rect2(at+Vector2(-.55,-.14)*r,Vector2(1.10,.74)*r),tint,false,1.55,true)
		_:
			for i in range(-1,2):
				draw_circle(at+Vector2(i*r*.50,0),maxf(.9,r*.16),tint,true,-1,true)
