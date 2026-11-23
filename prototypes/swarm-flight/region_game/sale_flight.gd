extends Control
## Paint a single committed delivery above the courtyard and its open shop.
const Art = preload("res://nectar_ui_art.gd")
const DURATION := 0.88
const JAR_FOOT := Vector2(304,396)
var elapsed := DURATION
var source := Vector2.ZERO
var balance: Label
var paid := 0
var delivery: Array[Color] = []
var reduced := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()
	set_process(false)

func begin(event: Dictionary, bag_position: Vector2, target: Label, reduce_motion: bool) -> void:
	source = bag_position
	balance = target
	paid = int(event.amount)
	reduced = reduce_motion
	delivery.clear()
	for kind in ["blue", "rose"]:
		for i in mini(3,int(event.cargo[kind])):
			delivery.append(Color("f4b941") if kind == "blue" else Color("de91a5"))
	elapsed = 0.0
	show()
	set_process(true)
	queue_redraw()

func stop() -> void:
	hide()
	set_process(false)
	elapsed = DURATION

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= DURATION or not is_visible_in_tree():
		stop()
	else:
		queue_redraw()

func _draw() -> void:
	if not is_instance_valid(balance) or elapsed >= DURATION: return
	var jar := JAR_FOOT - Vector2(0,23)
	var mouth := jar - Vector2(0,15)
	var ink := Color("715633")
	var target := balance.get_global_rect().position + Vector2(balance.get_theme_font("font").get_string_size(balance.text,HORIZONTAL_ALIGNMENT_LEFT,-1,balance.get_theme_font_size("font_size")).x+18,balance.size.y * .5)
	var fill := smoothstep(.14,.48,elapsed)
	var bounce := 0.0 if reduced else sin(fill*PI)*.09
	if not reduced and elapsed < .49:
		var shine := sin(PI*clampf(elapsed/.49,0,1))
		draw_circle(jar,32,Color("ffce63",shine*.24),true,-1,true)
	draw_set_transform(JAR_FOOT,bounce,Vector2(1.0+bounce,1.0-bounce))
	Art.painted_icon(self,"bag",Vector2(0,-22),25)
	if fill > 0:
		draw_arc(Vector2(0,-18),10,0.22,PI-.22,14,Color("ffdd84",fill*.85),2.4,true)
	draw_set_transform(Vector2.ZERO)
	if not reduced:
		for i in delivery.size():
			var t := clampf((elapsed-float(i)*.024)/.36,0,1)
			if t <= 0 or t >= 1: continue
			var drop := source.lerp(mouth,t) + Vector2(0,-sin(PI*t)*(44+i*3))
			draw_circle(drop,5.8,ink,true,-1,true)
			draw_circle(drop,4.9,delivery[i],true,-1,true)
			draw_circle(drop-Vector2(1.4,1.5),1.5,Color("fff5c7"))
		for i in mini(paid,3):
			var t := clampf((elapsed-.34-float(i)*.047)/.35,0,1)
			if t <= 0 or t >= 1: continue
			var trail := PackedVector2Array()
			for sample in 7:
				var part := maxf(0,t-.017*float(6-sample))
				trail.append(mouth.lerp(target,smoothstep(0,1,part)) + Vector2(0,-sin(PI*part)*66))
			draw_polyline(trail,Color("fff0a0",sin(t*PI)*.60),3,true)
			Art.painted_icon(self,"coin",trail[-1],14)
	if reduced or elapsed >= .63:
		var font := balance.get_theme_font("font")
		var at := target+Vector2(8,7)
		draw_string(font,at,"+%d" % paid,HORIZONTAL_ALIGNMENT_LEFT,-1,22,ink)
