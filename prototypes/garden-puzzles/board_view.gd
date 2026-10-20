extends Control
signal cell_clicked(index: int)
signal cell_dragged(first: int, last: int)
const INK := Color("#304735")
const PETALS := [Color("#e9b94e"),Color("#d97d91"),Color("#79b9c9"),Color("#a68abb"),Color("#8eb46a")]
var font: Font
var kind := "merge"
var values: Array = []
var cursor := 0
var selected := -1
var interactive := false
var frame: Dictionary = {}
var progress := 1.0
var down_cell := -1
var hover := -1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_exited.connect(func(): hover = -1; queue_redraw())
	resized.connect(queue_redraw)

func count_side() -> int:
	return 4 if kind == "merge" else 6

func grid_rect() -> Rect2:
	var side := minf(size.x,size.y)
	return Rect2((size-Vector2.ONE*side)*0.5+Vector2.ONE*12,Vector2.ONE*(side-24))

func cell_rect(index: int) -> Rect2:
	var grid := grid_rect()
	var cell := grid.size.x/count_side()
	return Rect2(grid.position+Vector2(index%count_side(),index/count_side())*cell+Vector2.ONE*5,Vector2.ONE*(cell-10))

func cell_at(point: Vector2) -> int:
	var grid := grid_rect()
	if not grid.has_point(point): return -1
	var coord := (point-grid.position)/(grid.size.x/count_side())
	return int(coord.y)*count_side()+int(coord.x)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		hover = cell_at(event.position)
		queue_redraw()
	if not interactive or kind != "match": return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var at := cell_at(event.position)
		if event.pressed: down_cell = at
		else:
			if down_cell >= 0 and at >= 0:
				if at == down_cell: cell_clicked.emit(at)
				else: cell_dragged.emit(down_cell,at)
			down_cell = -1
		accept_event()

func style(fill: Color, border := Color.TRANSPARENT, width := 0, radius := 14) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(radius)
	return box

func _draw() -> void:
	if not is_instance_valid(font): return
	var grid := grid_rect()
	draw_style_box(style(Color("#d7dfc8"),Color("#a7b59a"),2,22),grid.grow(12))
	for i in count_side()*count_side():
		draw_style_box(style(Color("#c2cfb5"),Color("#b3c2a5"),1,13),cell_rect(i))
	var t := 1.0-pow(1.0-clampf(progress,0,1),3)
	var animation: String = frame.get("kind","")
	if animation == "slide":
		for item in frame.slides:
			var rect := cell_rect(item.from)
			rect.position = rect.position.lerp(cell_rect(item.to).position,t)
			tile(rect,item.value,1.0)
	elif animation == "fall":
		for item in frame.falls:
			var rect := cell_rect(item.to)
			var start := rect.position+Vector2(0,(item.from_row-float(item.to/count_side()))*(grid.size.x/count_side()))
			rect.position = start.lerp(rect.position,t)
			if rect.get_center().y >= grid.position.y-2:
				tile(rect,item.value,1.0)
	else:
		for i in values.size():
			var rect := cell_rect(i)
			var alpha := 1.0
			if animation == "swap":
				if i == frame.a: rect.position = rect.position.lerp(cell_rect(frame.b).position,t)
				elif i == frame.b: rect.position = rect.position.lerp(cell_rect(frame.a).position,t)
			if animation == "clear" and i in frame.cleared:
				alpha = 1.0-progress
				rect = rect.grow(-rect.size.x*progress*0.28)
				draw_arc(cell_rect(i).get_center(),12+progress*28,0,TAU,32,Color(1,0.98,0.80,1-progress),3,true)
			if animation == "pop" and (i in frame.get("merged",[]) or i == frame.get("spawned",-1)):
				rect = rect.grow(sin(progress*PI)*3)
			tile(rect,values[i],alpha)
	if kind == "match" and interactive:
		if hover >= 0: draw_style_box(style(Color(1,1,1,0.10),Color("#78946a"),2),cell_rect(hover))
		if cursor >= 0: draw_style_box(style(Color.TRANSPARENT,INK,2),cell_rect(cursor).grow(-1))
		if selected >= 0:
			draw_style_box(style(Color(1,0.89,0.45,0.14),Color("#bd7e23"),4),cell_rect(selected).grow(1))

func tile(rect: Rect2, value: int, alpha: float) -> void:
	if kind == "merge":
		if value <= 0: return
		var palette := {2:"#fbf5dc",4:"#d6e4b5",8:"#b5d9d7",16:"#efc79e",32:"#e8a2a4",64:"#bba6cf",128:"#efca55"}
		var fill := Color(palette.get(value,"#efca55"))
		fill.a = alpha
		var border := INK; border.a = alpha*0.16
		draw_style_box(style(fill,border,2,15),rect)
		var words := str(value)
		var fs := int(rect.size.x*(0.42 if value<100 else 0.34))
		var width := font.get_string_size(words,HORIZONTAL_ALIGNMENT_LEFT,-1,fs).x
		var color := INK; color.a = alpha
		draw_string(font,rect.get_center()+Vector2(-width*0.5,fs*0.34),words,HORIZONTAL_ALIGNMENT_LEFT,-1,fs,color)
	else:
		if value < 0: return
		draw_style_box(style(Color(0.99,0.98,0.93,alpha)),rect)
		flower(rect.get_center(),value,rect.size.x*0.32,alpha)

func flower(center: Vector2, type: int, radius: float, alpha := 1.0) -> void:
	var color: Color = PETALS[posmod(type,5)]; color.a = alpha
	var edge := color.darkened(0.25); edge.a = alpha
	var petals: int = [5,4,3,6,4][posmod(type,5)]
	for i in petals:
		var angle := TAU*i/petals-PI*0.5
		var point := center+Vector2.from_angle(angle)*radius*0.52
		if type == 1:
			var shape := PackedVector2Array([point+Vector2(0,-radius*0.55),point+Vector2(radius*0.42,0),point+Vector2(0,radius*0.55),point+Vector2(-radius*0.42,0)])
			draw_colored_polygon(shape,color)
			shape.append(shape[0]); draw_polyline(shape,edge,1.6,true)
		else:
			draw_circle(point,radius*0.48,edge)
			draw_circle(point,radius*0.41,color)
	draw_circle(center,radius*0.28,Color(0.98,0.92,0.66,alpha))
	draw_circle(center,radius*0.12,Color(0.28,0.34,0.22,alpha))
