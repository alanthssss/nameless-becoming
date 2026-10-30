extends "res://world_view.gd"
const ColorMemory = preload("res://color_memory.gd")

func _rain_field(field: Dictionary) -> void:
	if model.weather_phase == "dry" or model.weather_phase == "after": return
	var area: Rect2 = field.rect
	# Clouds belong to this authored span, not a screen tint. Rain streaks use
	# the same roof/leaf coordinates as physical drops and stop on their tops.
	for i in 12:
		var x := area.position.x+float(i)*200.0
		if x < model.camera_x-160 or x > model.camera_x+1440: continue
		ArtProps.cloud(self,Rect2(x-110,145+sin(float(i)*1.7)*7,240,70),Color("8aa0a5"))
	var count := 54 if model.weather_phase == "rain" else 12
	for i in count:
		var x := area.position.x+fposmod(float(i)*47.31,area.size.x)
		if x < model.camera_x-20 or x > model.camera_x+1300: continue
		var bottom: float = model.rain_floor_at(x)
		var span := maxf(1.0,bottom-195.0)
		var y := 195.0+fposmod(float(i)*81.7+clock*220.0,span)
		var end_y := minf(y+13.0,bottom)
		draw_line(Vector2(x,y),Vector2(x-1.0,end_y),Color(0.54,0.75,0.80,0.58 if model.weather_phase == "rain" else 0.3),2.0,true)
	# A few droplets gather on the roof during the warning; they do not hurt.
	for roof in model.walls:
		var rect: Rect2 = roof.rect
		for i in 6:
			var x: float = rect.position.x+70.0+float(i)*(rect.size.x-100.0)/6.0
			_ellipse(Vector2(x,rect.position.y-3),Vector2(4.5,1.8),Color("d4edf0"))

func _terrain(item: Dictionary) -> void:
	super._terrain(item)
	var rect: Rect2 = item.rect
	for x in [rect.position.x+25.0,rect.end.x-25.0]:
		ArtProps.stalk(self,Vector2(x,rect.end.y),Vector2(x+12,530),Vector2(x-7,680),Vector2(x+18,828),9.0)

func _shelter(shelter: Dictionary) -> void:
	var p: Vector2 = shelter.pos
	var half: float = shelter.half_width
	if p.x+half < model.camera_x-180 or p.x-half > model.camera_x+1460: return
	ArtProps.shelter_plant(self,p,half)
	if int(shelter.section) in [0,2]:
		var center := p+Vector2(105,82)
		_curve(p+Vector2(108,-90),p+Vector2(106,-28),center+Vector2(38,-80),center+Vector2(32,-65),Color("8c7441"),2.3)
		ColorMemory.draw_window(self,center,float(model.color_step),0.68)
	else:
		draw_line(p+Vector2(-7,-91),p+Vector2(-7,-55),INK,2,true)
		ArtProps.decor(self,p+Vector2(-7,-40),"shelter_lamp_lit" if shelter.reached else "shelter_lamp")
	# No decorative horizontal guide masquerading as a platform.
	if shelter.reached:
		draw_polyline(PackedVector2Array([p+Vector2(-7,44),p+Vector2(-1,50),p+Vector2(10,37)]),CREAM,3,true)

func _landmarks(_act: int) -> void:
	# A local reflected trace echoes the committed window color, not the sky.
	var tint := ColorMemory.color_at(9+model.color_step)
	tint.a = 0.25
	for x in [690.0,3590.0]:
		for i in 4:
			_curve(Vector2(x-55+i*6,744+i*5),Vector2(x-18,741+i*5),Vector2(x+20,747+i*5),Vector2(x+60-i*4,743+i*5),tint,2.0)

func _neighbors() -> void:
	pass

func neighbor_words() -> String:
	return ""
