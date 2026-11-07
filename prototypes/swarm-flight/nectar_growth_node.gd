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

func _has_point(p: Vector2) -> bool:
	return Rect2(3,3,size.x-6,size.y-6).has_point(p)

func _draw() -> void:
	var center := Vector2(size.x/2,43)
	var muted := state == "locked"
	if selected or has_focus() or is_hovered():
		# A loose double pencil oval, not a separate metallic/hexagonal widget.
		var stroke := Color("a46c2f") if selected or has_focus() else Color("bcb07e")
		var points := PackedVector2Array()
		for i in 49:
			var angle := TAU*i/48.0
			points.append(center+Vector2(cos(angle)*47,sin(angle)*42)+Vector2(sin(angle*3)*1.5,cos(angle*5)))
		draw_polyline(points,Color(stroke,.18),7,true)
		draw_polyline(points,stroke,1.7,true)
	Art.painted_icon(self,kind,center,30,Color("a9ad94") if muted else Color.WHITE)
	for i in max_rank:
		var at := center+Vector2((i-(max_rank-1)*.5)*15,42)
		draw_circle(at,4.5,Color("a77a32") if i < rank else Color("d9cbae"))
		draw_circle(at+Vector2(-1,-1),1.3,Color("fff0bd") if i < rank else Color("b9aa88"))
	if ui_font:
		draw_string(ui_font,Vector2(0,112),title,HORIZONTAL_ALIGNMENT_CENTER,size.x,19,Color("445e37") if not muted else Color("7c8063"))
		if state == "locked":
			draw_rect(Rect2(center+Vector2(29,-31),Vector2(10,9)),Color("8e8056"))
			draw_arc(center+Vector2(34,-31),4,PI,TAU,12,Color("8e8056"),2,true)
		elif state == "max":
			draw_string(ui_font,Vector2(size.x/2+30,18),"✓",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("617b3d"))

func _exit_tree() -> void:
	if growth_tween: growth_tween.kill()
	growth_tween = null
