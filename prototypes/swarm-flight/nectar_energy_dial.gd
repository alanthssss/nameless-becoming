extends Control
## Painted bee portrait with a small, resolution-independent stamina ring.
const Art = preload("res://nectar_ui_art.gd")
var source: Range

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if source: source.value_changed.connect(_value_changed)

func _value_changed(_value: float) -> void:
	queue_redraw()

func _draw() -> void:
	var at := Vector2(64,62)
	draw_circle(at+Vector2(0,2),40,Color("263d35b0"))
	draw_circle(at,38,Color("f1dfb5"))
	draw_circle(at,31,Color("e5cf94"))
	draw_arc(at,35,0,TAU,96,Color("587153"),5,true)
	var ratio := clampf(source.value/maxf(source.max_value,1.0),0,1) if source else 1.0
	if ratio>0:
		draw_arc(at,35,-PI*.5,-PI*.5+TAU*ratio,96,Color("85bc65") if ratio>.25 else Color("d7954e"),5,true)
	# Use the whole bee assembly, including both wings, rather than its body atlas.
	Art.painted_icon(self,"bee",at+Vector2(0,-2),27)
