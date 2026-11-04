extends Control
const Art = preload("res://nectar_ui_art.gd")
var kind := "bag"
var preview := false
var reduced_motion := false
var current_value := 1.0
var next_value := 1.0
var phase := 0.0

func _process(delta: float) -> void:
	if not preview or not is_visible_in_tree() or reduced_motion: return
	phase += delta
	queue_redraw()

func _draw() -> void:
	if not preview:
		Art.icon(self,kind,size*.5,14)
		return
	var start := 34.0
	var width := maxf(20,size.x-start-12)
	var limit := maxf(current_value,next_value)
	for i in 2:
		var y := 10.0+i*25.0
		var value := current_value if i == 0 else next_value
		var tint := Color("a0b39b") if i == 0 else Color("d5ab4e")
		Art.icon(self,kind,Vector2(13,y),10,tint)
		draw_line(Vector2(start,y),Vector2(start+width,y),Color("d4d9bf"),5,true)
		var fill: float = value/maxf(limit,.01)
		if kind == "gather": fill = .58 if reduced_motion else fposmod(phase,maxf(.1,value))/maxf(.1,value)
		draw_line(Vector2(start,y),Vector2(start+width*fill,y),tint,5,true)
		draw_circle(Vector2(start+width*fill,y),4,tint)
