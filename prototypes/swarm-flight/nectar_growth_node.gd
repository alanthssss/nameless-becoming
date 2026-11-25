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
var hive_cell := false
var rank_initialized := false
var growth_tween: Tween
var ink_bloom := 0.0
var gesture := 1.0
# Positions in the 160 px painted cells, following the scent ribbon and the sunlit trail.
const SCENT_PATH := [Vector2(34,98),Vector2(48,74),Vector2(65,70),Vector2(91,82),Vector2(119,75),Vector2(138,55),Vector2(134,36),Vector2(113,30)]
const TRAIL_PATH := [Vector2(43,125),Vector2(69,114),Vector2(92,103),Vector2(83,97),Vector2(63,91),Vector2(58,87),Vector2(67,81),Vector2(95,75),Vector2(106,71),Vector2(101,67),Vector2(79,59)]

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	focus_mode = Control.FOCUS_ALL
	for name in ["normal","hover","pressed","focus","disabled"]:
		add_theme_stylebox_override(name,StyleBoxEmpty.new())
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	focus_entered.connect(_show_gesture)
	set_process(false)
	focus_exited.connect(queue_redraw)

func _show_gesture() -> void:
	queue_redraw()
	if reduced_motion or kind not in ["reach","beat","wings"]: return
	gesture = 0.0
	set_process(true)

func _process(delta: float) -> void:
	if reduced_motion or not has_focus() or not is_visible_in_tree():
		gesture = 1.0
	else:
		gesture = minf(1.0,gesture + delta / (.38 if kind == "beat" else .85))
	set_process(gesture < 1.0)
	queue_redraw()

func _draw_journal_icon(center: Vector2, tint: Color) -> void:
	var radius := 23.0 if hive_cell else 31.0
	var at := center
	if kind == "beat":
		at += Vector2(4,-2) * sin(gesture*PI) * (1.0-gesture)
	Art.journal_icon(self,kind,at,radius,tint)
	if gesture >= 1.0 or kind not in ["reach","wings"]: return
	var path: Array = SCENT_PATH if kind == "reach" else TRAIL_PATH
	var progress := gesture*(path.size()-1)
	var segment := mini(floori(progress),path.size()-2)
	var sample: Vector2 = path[segment].lerp(path[segment+1],progress-segment)
	var spark := center+(sample/80.0-Vector2.ONE)*radius
	var opacity := sin(gesture*PI)
	draw_circle(spark,2.8,Color("bb772d",opacity),true,-1,true)
	draw_circle(spark,1.8,Color("fff1a9",opacity),true,-1,true)

func set_rank(value: int) -> void:
	var grew := rank_initialized and value > rank
	rank = value
	rank_initialized = true
	if not grew or reduced_motion: return
	if growth_tween: growth_tween.kill()
	pivot_offset = Vector2(size.x/2,30 if hive_cell else 48)
	scale = Vector2(1.12,1.12)
	growth_tween = create_tween()
	growth_tween.tween_property(self,"scale",Vector2.ONE,.30).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	growth_tween.parallel().tween_method(_bloom,1.0,0.0,.48)

func _bloom(value: float) -> void:
	ink_bloom = value
	queue_redraw()

func _has_point(p: Vector2) -> bool:
	if hive_cell:
		return p.distance_to(Vector2(size.x/2,30)) <= 33 or Rect2(3,60,size.x-6,23).has_point(p)
	return Rect2(3,3,size.x-6,size.y-6).has_point(p)

func _draw() -> void:
	var center := Vector2(size.x/2,30 if hive_cell else 43)
	var muted := state == "locked"
	if ink_bloom > 0 and not reduced_motion:
		var radius := lerpf(49,29,ink_bloom)
		for i in 6:
			var ray := Vector2.from_angle(TAU*i/6-.2)
			draw_line(center+ray*radius,center+ray*(radius+6*ink_bloom),Color("bf842c",ink_bloom),2.5,true)
	if hive_cell:
		var hex := PackedVector2Array()
		for corner in 6:
			hex.append(center+Vector2.from_angle(corner*TAU/6.0-PI/2)*31)
		var ink := Color("98723e") if selected else Color("6d813f") if state == "ready" else Color("b6a77b")
		draw_colored_polygon(hex,Color(ink,.17 if selected or is_hovered() else .055))
		hex.append(hex[0])
		draw_polyline(hex,ink,2.6 if selected else 1.2,true)
	elif selected or has_focus() or is_hovered():
		# A loose double pencil oval, not a separate metallic/hexagonal widget.
		var stroke := Color("a46c2f") if selected or has_focus() else Color("bcb07e")
		var points := PackedVector2Array()
		for i in 49:
			var angle := TAU*i/48.0
			points.append(center+Vector2(cos(angle)*47,sin(angle)*42)+Vector2(sin(angle*3)*1.5,cos(angle*5)))
		draw_polyline(points,Color(stroke,.18),7,true)
		draw_polyline(points,stroke,1.7,true)
	_draw_journal_icon(center,Color("a9ad94") if muted else Color.WHITE)
	for i in max_rank:
		var at := center+Vector2((i-(max_rank-1)*.5)*15,31 if hive_cell else 42)
		draw_circle(at,4.5,Color("a77a32") if i < rank else Color("d9cbae"))
		draw_circle(at+Vector2(-1,-1),1.3,Color("fff0bd") if i < rank else Color("b9aa88"))
	if ui_font:
		draw_string(ui_font,Vector2(0,81 if hive_cell else 112),title,HORIZONTAL_ALIGNMENT_CENTER,size.x,16 if hive_cell else 19,Color("445e37") if not muted else Color("667253") if hive_cell else Color("7c8063"))
		if state == "locked":
			draw_rect(Rect2(center+(Vector2(20,-24) if hive_cell else Vector2(29,-31)),Vector2(10,9)),Color("8e8056"))
			draw_arc(center+(Vector2(25,-24) if hive_cell else Vector2(34,-31)),4,PI,TAU,12,Color("8e8056"),2,true)
		elif state == "max":
			draw_string(ui_font,Vector2(size.x/2+30,18),"✓",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("617b3d"))

func _exit_tree() -> void:
	if growth_tween: growth_tween.kill()
	growth_tween = null
