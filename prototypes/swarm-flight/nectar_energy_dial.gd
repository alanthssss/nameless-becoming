extends Control
## Painted bee portrait; a narrow honey-coloured ink arc carries live stamina.
const Art = preload("res://nectar_ui_art.gd")
var source: Range

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if source: source.value_changed.connect(_value_changed)

func _value_changed(_value: float) -> void:
	queue_redraw()

func _draw() -> void:
	var at := Vector2(64,62)
	# Let the shared parchment remain the backdrop, without a flat green medallion.
	draw_arc(at,40,0,TAU,128,Color("be9e64a0"),1.1,true)
	draw_arc(at,36,0,TAU,128,Color("d9c698"),2.8,true)
	var ratio := clampf(source.value/maxf(source.max_value,1.0),0,1) if source else 1.0
	if ratio>0:
		var ink := Color("ae7d37") if ratio>.25 else Color("b65a35")
		draw_arc(at,36,-PI*.5,-PI*.5+TAU*ratio,128,ink,3.1,true)
		draw_arc(at,35,-PI*.5,-PI*.5+TAU*ratio,128,Color("f3d898b0"),.8,true)
	# Use the whole bee assembly, including both wings, rather than its body atlas.
	Art.painted_icon(self,"bee",at+Vector2(0,-2),29)
