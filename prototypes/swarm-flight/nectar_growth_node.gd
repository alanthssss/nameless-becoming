extends Button
const Art = preload("res://nectar_ui_art.gd")
var kind := "gather"
var rank := 0
var max_rank := 1
var state := "locked"
var selected := false
var title := ""
var ui_font: Font
var reduced_motion := false
var rank_initialized := false
var growth_tween: Tween

func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	focus_mode = Control.FOCUS_ALL
	for name in ["normal","hover","pressed","focus","disabled"]:
		add_theme_stylebox_override(name,StyleBoxEmpty.new())
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)

func set_rank(value: int) -> void:
	var grew := rank_initialized and value > rank
	rank = value
	rank_initialized = true
	if not grew or reduced_motion: return
	if growth_tween: growth_tween.kill()
	pivot_offset = Vector2(size.x/2,48)
	scale = Vector2(1.12,1.12)
	growth_tween = create_tween()
	growth_tween.tween_property(self,"scale",Vector2.ONE,.30).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func hexagon(radius: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 6:
		var a: float = TAU*i/6-PI/6
		pts.append(Vector2(size.x/2,48)+Vector2(cos(a),sin(a))*radius)
	return pts

func _has_point(p: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(p,hexagon(48)) or Rect2(0,92,size.x,30).has_point(p)

func _draw() -> void:
	var center := Vector2(size.x/2,48)
	var tint := Color("759583") if state == "locked" else Color("cbd9bd") if state == "poor" else Color("edce83")
	var fill := Color("284b41") if state == "locked" else Color("3c6451") if state != "max" else Color("4b7053")
	if selected or has_focus():
		draw_colored_polygon(hexagon(51),Color("efcd78"))
		draw_colored_polygon(hexagon(48),Color("163b34"))
	draw_colored_polygon(hexagon(44),fill.lightened(.08) if is_hovered() else fill)
	var outline := hexagon(44)
	outline.append(outline[0])
	draw_polyline(outline,tint,2,true)
	Art.icon(self,kind,center+Vector2(0,-5),22,tint)
	for i in max_rank:
		var at := center+Vector2((i-(max_rank-1)*.5)*13,27)
		draw_circle(at,3.5,Color("f3d17d") if i < rank else Color("163b34"))
	if ui_font:
		draw_string(ui_font,Vector2(0,112),title,HORIZONTAL_ALIGNMENT_CENTER,size.x,19,Color("f1e8ce") if state != "locked" else Color("a2b7a8"))
		if state == "locked":
			draw_rect(Rect2(center+Vector2(29,-33),Vector2(10,9)),Color("bac6b0"))
			draw_arc(center+Vector2(34,-33),4,PI,TAU,12,Color("bac6b0"),2,true)
		elif state == "max":
			draw_string(ui_font,Vector2(size.x/2+28,20),"✓",HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("efd080"))

func _exit_tree() -> void:
	if growth_tween: growth_tween.kill()
	growth_tween = null
