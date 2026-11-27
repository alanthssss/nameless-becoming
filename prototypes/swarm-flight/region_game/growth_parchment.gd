extends Control
## One continuous piece of paper cut from the painted journal's clean left leaf.
const PAPER := preload("res://art/nectar-growth-journal.png")
const PAPER_SAMPLE := Rect2(145,160,535,680)

var small_note := false
var grain := FastNoiseLite.new()

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	grain.seed = 53
	grain.frequency = .12

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED: queue_redraw()

func _edge(outline: PackedVector2Array, a: Vector2, b: Vector2) -> void:
	var inward := (b-a).normalized().orthogonal()
	var steps := maxi(1,ceili(a.distance_to(b)/9.0))
	for i in steps:
		var point := a.lerp(b,float(i)/steps)
		if i > 0:
			var fray := 1.6*grain.get_noise_2dv(point) + 2.6*grain.get_noise_2dv(point*.19)
			point += inward*fray
		outline.append(point)

func _draw() -> void:
	if size.x < 32 or size.y < 24: return
	var w := size.x
	var h := size.y
	var corners := PackedVector2Array([
		Vector2(7,5),Vector2(w-9,2),Vector2(w-4,6),Vector2(w-2,h-10),
		Vector2(w-7,h-6),Vector2(6,h-3),Vector2(2,h-9),Vector2(3,9)])
	var outline := PackedVector2Array()
	for side in corners.size():
		_edge(outline,corners[side],corners[(side+1)%corners.size()])
	# Sample the leaf sideways as one continuous image, clear of its printed trim.
	var uv := PackedVector2Array()
	var tex_size := Vector2(PAPER.get_size())
	for point in outline:
		var at := Vector2(1.0-point.y/h,point.x/w)
		uv.append((PAPER_SAMPLE.position + at*PAPER_SAMPLE.size)/tex_size)
	draw_set_transform(Vector2(1.25,3.0) if small_note else Vector2(1.0,2.25))
	draw_colored_polygon(outline,Color("342d233b"))
	draw_set_transform(Vector2.ZERO)
	draw_colored_polygon(outline,Color("faf9faff"),uv,PAPER)
	if small_note: draw_colored_polygon(outline,Color("fff5ddbf"))
