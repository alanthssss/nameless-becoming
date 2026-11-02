extends "res://world_view.gd"
## Reuses the painted garden family. Every harvest centre comes from the model.
var collecting := false
var nectar_motes: Array[Dictionary] = []
var harvest_texts: Array[Dictionary] = []
var celebration := 0.0

func _ready() -> void:
	_rng.seed = 2601102

func _process(delta: float) -> void:
	if not presentation_active:
		queue_redraw()
		return
	clock += delta
	celebration = maxf(0.0, celebration-delta)
	for mote in nectar_motes:
		mote.age += delta
	for item in harvest_texts:
		item.age += delta
	nectar_motes = nectar_motes.filter(func(m): return m.age < m.duration)
	harvest_texts = harvest_texts.filter(func(t): return t.age < 1.0)
	_rest_blend = move_toward(_rest_blend, 0.55 if model != null and model.phase == "home" else 0.0, delta*2.5)
	queue_redraw()

func nectar_event(event: Dictionary) -> void:
	var kind: String = event.get("kind", "")
	var at: Vector2 = event.get("pos", model.p)
	if kind == "harvest":
		for i in 3:
			nectar_motes.append({"from":at+Vector2(_rng.randf_range(-12,12),_rng.randf_range(-12,12)),"age":-i*0.035,"duration":0.42,"gold":event.get("type", "blue") == "rose"})
		harvest_texts.append({"p":at,"text":"+"+str(event.get("amount",1)),"age":0.0})
	if kind in ["complete", "unlock", "buy"]:
		celebration = 2.3
		for i in 20:
			nectar_motes.append({"from":model.p+Vector2(_rng.randf_range(-100,100),_rng.randf_range(-100,50)),"age":-_rng.randf_range(0,0.3),"duration":0.8,"gold":true})

func _draw() -> void:
	if model == null: return
	draw_set_transform(Vector2.ZERO)
	SampleLandscape.background(self,0,model.camera_x,clock,0,0)
	# A broad atmosphere shift accompanies the second flower meadow.
	var far_mix: float = clampf((model.camera_x-700.0)/1500.0,0.0,1.0)
	draw_rect(Rect2(0,0,1280,800),Color(0.69,0.60,0.87,far_mix*0.07))
	_world_offset = Vector2(-model.camera_x,0)
	draw_set_transform(_world_offset)
	_draw_home()
	_draw_boundary()
	_draw_leaf_stop(Vector2(1420,565),93)
	if "meadow" in model.owned:
		_draw_leaf_stop(model.RAIN_SHELTER.pos,model.RAIN_SHELTER.half_width)
	for flower in model.flowers:
		if flower.pos.x > model.camera_x-150 and flower.pos.x < model.camera_x+1430:
			_draw_source(flower)
	_draw_shortcut(Vector2(1040,400),false)
	_draw_shortcut(Vector2(3000,400),true)
	_draw_rain()
	if collecting and model.phase == "field" and model.cargo_total() < model.capacity():
		draw_arc(model.p,model.harvest_radius(),0,TAU,64,Color(1.0,0.87,0.40,0.22),1.5,true)
	for mote in nectar_motes:
		if mote.age < 0.0: continue
		var t: float = clampf(mote.age/mote.duration,0,1)
		var q: Vector2 = mote.from.lerp(model.p+Vector2(-7,7),t*t)
		draw_circle(q,3.3*(1.0-t*0.35),Color("ffed87") if mote.gold else Color("d4f4ff"))
		draw_circle(q+Vector2(-1,-1),1.1,Color.WHITE)
	_bee(model.p,1.02,model.face,1.0,false,0.0)
	_draw_bag()
	for item in harvest_texts:
		if feedback_font:
			draw_string(feedback_font,item.p+Vector2(14,-30-item.age*26),item.text,HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color(1,0.96,0.72,1-item.age))
	draw_set_transform(Vector2.ZERO)
	SampleLandscape.foreground(self,model.camera_x,clock)

func _draw_home() -> void:
	if model.camera_x > 850: return
	ArtProps.home(self,model.HOME+Vector2(-25,-22),0,1,0.70)
	# The leaf counter and waiting bee are rooted in the tree's entrance.
	var stand: Vector2 = model.HOME+Vector2(118,52)
	ArtProps.stalk(self,stand,stand+Vector2(7,80),Vector2(370,760),Vector2(348,830),12)
	ArtSprites.small_leaf(self,stand,stand+Vector2(-155,2),36)
	_bee(stand+Vector2(-41,-18),0.75,Vector2.LEFT,1,false,1.7,"waiting")
	ArtProps.decor(self,model.HOME+Vector2(10,96),"sign")
	if feedback_font:
		draw_string(feedback_font,model.HOME+Vector2(-27,103),"蜂巢小店",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("382d16"))
	for i in mini(5,int(model.sold_total/30)):
		var jar: Vector2 = stand+Vector2(-104+i*17,-7)
		_oval(jar,Vector2(7,10),Color("e4ad42"),Color("78512a"),1.5)
		draw_line(jar+Vector2(-5,-8),jar+Vector2(5,-8),Color("ffe8a1"),3,true)
	if model.completed:
		for i in 3:
			_bee(model.HOME+Vector2(50+i*42,-128+sin(clock*1.7+i)*8),0.58,Vector2.LEFT,1,false,float(i+3),"waiting")

func _draw_source(flower: Dictionary) -> void:
	var p: Vector2 = flower.pos
	var purple: bool = flower.type == "rose"
	var stocked: bool = flower.stock > 0
	var join := p+Vector2(54,23) if purple else p+Vector2(0,22)
	var root := Vector2(p.x+26,832)
	var stem := PackedVector2Array([join,join+Vector2(12,110),root+Vector2(-25,-125),root])
	ArtProps.stalk(self,stem[0],stem[1],stem[2],stem[3],5.5)
	for t in [0.42,0.70]:
		var leaf_root: Vector2 = stem[0].bezier_interpolate(stem[1],stem[2],stem[3],t)
		var direction := -1.0 if t < 0.5 else 1.0
		ArtSprites.small_leaf(self,leaf_root,leaf_root+Vector2(64*direction,-28),17)
	var tint := Color.WHITE if stocked else Color("899880")
	if purple:
		var factor := 0.19
		var pivot := Vector2(771,431)
		draw_texture_rect_region(ArtProps.FLORA,Rect2(p+(ArtProps.SNEEZE.position-pivot)*factor,ArtProps.SNEEZE.size*factor),ArtProps.SNEEZE,tint)
	else:
		var factor := 0.15
		draw_texture_rect_region(ArtSprites.ATLAS,Rect2(p+(ArtSprites.FLOWER.position-ArtSprites.FLOWER_PIVOT)*factor,ArtSprites.FLOWER.size*factor),ArtSprites.FLOWER,tint)
	if stocked:
		var radius := 5.0+sin(clock*2+p.x*0.013)*0.8
		draw_circle(p,radius+3,Color(1.0,0.84,0.34,0.18))
		draw_circle(p,radius,Color("ffe99c") if purple else Color("fff2bd"))
		draw_circle(p+Vector2(-1.8,-1.7),1.8,Color.WHITE)
	if p.distance_to(model.p) < model.harvest_radius()+65:
		var rect := Rect2(p+Vector2(-27,58),Vector2(54,5))
		draw_style_box(_box_style(Color("315b4c"),Color("e8ead0"),1,3),rect)
		if stocked:
			draw_style_box(_box_style(Color("edc85b"),Color.TRANSPARENT,0,2),Rect2(rect.position,Vector2(rect.size.x*float(flower.stock)/float(flower.max),5)))
		if feedback_font:
			var words := str(flower.stock)+" / "+str(flower.max) if stocked else "已采完"
			draw_string(feedback_font,p+Vector2(-27,82),words,HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("254c3d"))

func _draw_boundary() -> void:
	var x: float = model.GATE_X
	if x < model.camera_x-250 or x > model.camera_x+1500: return
	if "meadow" not in model.owned:
		# A dense, rooted flower hedge marks the actual locked boundary.
		ArtProps.stalk(self,Vector2(x,180),Vector2(x+8,350),Vector2(x-8,650),Vector2(x,833),18)
		for i in 5:
			ArtSprites.hedge(self,Rect2(x-28,190+i*116,66,92))
		ArtProps.stalk(self,Vector2(x-88,480),Vector2(x-84,580),Vector2(x-90,710),Vector2(x-83,830),7)
		ArtProps.decor(self,Vector2(x-87,465),"sign")
		if feedback_font:
			draw_string(feedback_font,Vector2(x-121,470),"紫花地",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("382d16"))
	else:
		for i in 2:
			ArtSprites.hedge(self,Rect2(x-60+i*105,760,78,66))

func _draw_leaf_stop(p: Vector2, half: float) -> void:
	ArtProps.shelter_plant(self,p,half)

func _draw_shortcut(p: Vector2, far: bool) -> void:
	if p.x < model.camera_x-100 or p.x > model.camera_x+1400: return
	if far and "meadow" not in model.owned: return
	ArtProps.stalk(self,p+Vector2(0,32),p+Vector2(12,130),Vector2(p.x-28,710),Vector2(p.x,830),6)
	ArtSprites.small_leaf(self,p+Vector2(8,107),p+Vector2(-62,77),20)
	var active: bool = "shortcut" in model.owned
	ArtSprites.flower(self,p,Vector2.LEFT if far else Vector2.RIGHT,0 if active else 0.55,0,not active)
	if active and feedback_font:
		draw_string(feedback_font,p+Vector2(-48,-70),"F · 借风穿行",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("2c5544"))

func _draw_rain() -> void:
	if "meadow" not in model.owned: return
	var left: float = 2600
	var right: float = 2920
	# A broad light shower in the far flower meadow, never a narrow invisible wall.
	for i in 48:
		var x: float = left+fposmod(float(i)*53.7+clock*15,right-left)
		var y: float = 130+fposmod(float(i)*79.3+clock*230,650)
		if x < model.camera_x-20 or x > model.camera_x+1300: continue
		if y >= model.rain_floor_at(x): continue
		var end_y: float = minf(y+18,model.rain_floor_at(x-5))
		if end_y <= y: continue
		draw_line(Vector2(x,y),Vector2(x-5,end_y),Color(0.72,0.89,1,0.24),1.4,true)

func _draw_bag() -> void:
	if model.cargo_total() <= 0: return
	var p: Vector2 = model.p+Vector2(-20 if model.face.x >= 0 else 21,17)
	_oval(p,Vector2(7,9),Color("dba344"),Color("6e4e29"),1.3)
	var ratio: float = float(model.cargo_total())/float(model.capacity())
	_ellipse(p+Vector2(0,4-ratio*5),Vector2(4,2+ratio*4),Color("ffdb67"))
