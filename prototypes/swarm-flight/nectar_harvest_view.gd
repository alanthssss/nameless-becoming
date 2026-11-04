extends "res://world_view.gd"
## Reuses the painted garden family. Every harvest centre comes from the model.
@export var area_key := "hub"
const CREATURE_ATLAS: Texture2D = preload("res://art/sign-keeper.png")
const UIArt = preload("res://nectar_ui_art.gd")
const Dance = preload("res://nectar_dance.gd")
const Landscape = preload("res://nectar_landscape.gd")
const STAGE: Texture2D = preload("res://art/nectar-dance-stage.png")
const BOOK_ART: Texture2D = preload("res://art/nectar-field-book.png")
const SHOP_ART: Texture2D = preload("res://art/nectar-honey-shop.png")
const JAR_ART: Texture2D = preload("res://art/nectar-honey-jar.png")
const JAR_SOURCE := Rect2(216,238,824,786)
var reduced_motion := false
var dance_elapsed := -1.0
var dance_style := "waggle"
var collecting := false
var nectar_motes: Array[Dictionary] = []
var harvest_texts: Array[Dictionary] = []
var celebration := 0.0
var pulse_rings: Array[Dictionary] = []
var harvest_recoil := 0.0
var departing_creatures: Array[Dictionary] = []

func _ready() -> void:
	_rng.seed = 2601102

func _process(delta: float) -> void:
	if not presentation_active:
		queue_redraw()
		return
	clock += delta
	harvest_recoil = maxf(0.0,harvest_recoil-delta)
	for ring in pulse_rings: ring.age += delta
	pulse_rings = pulse_rings.filter(func(r): return r.age < 0.4)
	for creature in departing_creatures:
		creature.age += delta
		creature.pos += creature.face*delta*240+Vector2(0,-100)*delta
	departing_creatures = departing_creatures.filter(func(c): return c.age < 0.65)
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
	if kind == "repel":
		for creature in model.creatures:
			if creature.id == event.get("id", ""):
				var flying: Dictionary = creature.duplicate(true)
				flying.state = "flee"
				flying.age = 0.0
				flying.face = Vector2.RIGHT if creature.pos.x >= model.p.x else Vector2.LEFT
				departing_creatures.append(flying)
				break
	if kind == "pulse": pulse_rings.append({"p":at,"age":0.0})
	if kind == "material":
		nectar_motes.append({"from":at,"age":0.0,"duration":0.36,"gold":true,"material":event.type})
		harvest_texts.append({"p":at,"text":"+%d %s" % [event.amount,"纤维" if event.type == "fiber" else "树脂"],"age":0.0})
	if kind == "harvest":
		harvest_recoil = 0.24
		for i in 1:
			nectar_motes.append({"from":at+Vector2(_rng.randf_range(-12,12),_rng.randf_range(-12,12)),"age":-i*0.035,"duration":0.42,"gold":event.get("type", "blue") == "rose"})
		harvest_texts.append({"p":at,"text":"+"+str(event.get("amount",1)),"age":0.0})
	if kind in ["complete", "unlock", "buy"]:
		celebration = 2.3
		for i in 20:
			nectar_motes.append({"from":model.p+Vector2(_rng.randf_range(-100,100),_rng.randf_range(-100,50)),"age":-_rng.randf_range(0,0.3),"duration":0.8,"gold":true})

func _draw() -> void:
	if model == null: return
	draw_set_transform(Vector2.ZERO)
	Landscape.background(self,area_key)
	_world_offset = Vector2(-model.camera_x,0)
	draw_set_transform(_world_offset)
	Landscape.terrain(self,area_key,model.camera_x,clock)
	if area_key == "hub":
		_draw_hub()
	else:
		if area_key == "pond":
			_draw_leaf_stop(Vector2(1420,565),93)
			_draw_shortcut(Vector2(1040,400),false)
		else:
			_draw_leaf_stop(model.RAIN_SHELTER.pos,model.RAIN_SHELTER.half_width)
			_draw_shortcut(Vector2(3000,400),true)
			_draw_rain()
		for flower in model.flowers:
			if int(flower.region) == (0 if area_key == "pond" else 1) and flower.pos.x > model.camera_x-150 and flower.pos.x < model.camera_x+1430:
				_draw_source(flower)
		for creature in model.creatures:
			if int(creature.region) == (0 if area_key == "pond" else 1): _draw_creature(creature)
		if area_key == "pond":
			_draw_gate(Vector2(470,575),"回庭院",true)
			_draw_gate(Vector2(1660,575),"前往紫花地", "meadow" in model.owned)
		else: _draw_gate(Vector2(1900,575),"返程路牌",true)
	for creature in departing_creatures: _draw_creature(creature)
	_draw_materials()
	for ring in pulse_rings:
		var t: float = ring.age/0.4
		draw_arc(ring.p,lerpf(22,model.pulse_radius(),1-pow(1-t,3)),0,TAU,64,Color(1,.94,.67,(1-t)*.7),3.0*(1-t)+1,true)
	if collecting and model.phase == "field" and model.cargo_total() < model.capacity():
		draw_arc(model.p,model.harvest_radius(),0,TAU,64,Color(1.0,0.87,0.40,0.22),1.5,true)
	for mote in nectar_motes:
		if mote.age < 0.0: continue
		var t: float = clampf(mote.age/mote.duration,0,1)
		var q: Vector2 = mote.from.lerp(model.p+Vector2(-7,7),t*t)
		if mote.has("material"): UIArt.icon(self,mote.material,q,9*(1-t*.5))
		else:
			draw_circle(q,3.3*(1.0-t*0.35),Color("ffed87") if mote.gold else Color("d4f4ff"))
			draw_circle(q+Vector2(-1,-1),1.1,Color.WHITE)
	if dance_elapsed >= 0.0 and not reduced_motion:
		_draw_dance()
	else:
		_draw_working_bee()
		_draw_bag()
	for item in harvest_texts:
		if feedback_font:
			draw_string(feedback_font,item.p+Vector2(14,-30-item.age*26),item.text,HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color(1,0.96,0.72,1-item.age))
	draw_set_transform(Vector2.ZERO)
	# Ground and roots share the world transform; parallax leaves cannot hide their joins.

func _label(p: Vector2, words: String, active := false, width := 180.0) -> void:
	if p.x < model.camera_x+8 or p.x > model.camera_x+1272: return
	p.x = clampf(p.x,model.camera_x+width*0.5+16,model.camera_x+1280-width*0.5-16)
	var r := Rect2(p-Vector2(width*0.5,22),Vector2(width,42))
	draw_style_box(_box_style(Color("294c3eea"),Color("edce83") if active else Color("98ab7d"),2,12),r)
	if feedback_font: draw_string(feedback_font,p+Vector2(-width*0.5+13,7),words,HORIZONTAL_ALIGNMENT_LEFT,width-24,18,Color("fff1cc"))

func _draw_hub() -> void:
	# Three addresses in one view; shelf inventory uses the same painted jar family.
	var shop_origin: Vector2 = model.HUB_SHOP+Vector2(-175,-230)
	Landscape.shop_base(self,model.HUB_SHOP)
	draw_texture_rect(SHOP_ART,Rect2(shop_origin,Vector2(350,350)),false)
	_bee(model.HUB_SHOP+Vector2(10,5),0.70,Vector2.RIGHT,1,false,1.7,"waiting")
	var jars: int = mini(6,int(model.sold_total/6))
	for i in jars:
		# Feet touch the two existing shelf surfaces, no flat procedural oval jars.
		var foot: Vector2 = shop_origin+Vector2(87+(i%3)*39,176-(i/3)*39)
		draw_texture_rect_region(JAR_ART,Rect2(foot+Vector2(0,-34),Vector2(35,34)),JAR_SOURCE)
	ArtProps.home(self,model.HUB_TREE+Vector2(25,60),0,1,0.64)
	Landscape.book_bracket(self,model.HUB_TREE+Vector2(0,75))
	_bee(model.HUB_TREE+Vector2(48,0),0.62,Vector2.LEFT,1,false,2.9,"waiting")
	_book(model.HUB_TREE+Vector2(0,75),true)
	# The old nonfunctional wind flowers and standalone information desk are removed.
	_draw_gate(model.HUB_DEPART,"E  出发",true)
	if model.interaction()=="shop": _label(model.HUB_SHOP+Vector2(0,-250),"E  交付花蜜",true,160)
	elif model.interaction()=="tree": _label(model.HUB_TREE+Vector2(0,-220),"E  成长",true,130)
	if model.completed:
		for i in 3:
			var pose: Dictionary = Dance.pose(fposmod(clock+i*.12,1.4),"waggle",i)
			_bee(model.HUB_DEPART+Vector2(-80+i*65,0)+(Vector2.ZERO if reduced_motion else pose.offset),0.62,Vector2.RIGHT,1,false,float(i),"greet")

func _book(p: Vector2, _growth: bool) -> void:
	draw_texture_rect(BOOK_ART,Rect2(p+Vector2(-70,-58),Vector2(140,98)),false)

func _draw_gate(p: Vector2, title: String, available: bool) -> void:
	if p.x < model.camera_x-160 or p.x > model.camera_x+1440: return
	var size := 300.0 if area_key == "hub" else 230.0
	_stage(p,size,available)
	if model.p.distance_to(p)<=(100 if area_key=="hub" else 70):
		_label(p+Vector2(0,-size*.66),title,true,150 if area_key=="hub" else 176)
	if not available and feedback_font:
		draw_string(feedback_font,Vector2(clampf(p.x,model.camera_x+106,model.camera_x+1174)-79,p.y-23),"尚未开放",HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("4f623f"))

func _stage(p: Vector2, size: float, active: bool) -> void:
	# Feet rest on a wooden saddle joined to a visible trunk and ground roots.
	var base := p+Vector2(0,size*.14)
	Landscape.platform(self,area_key,p,size)
	draw_texture_rect(STAGE,Rect2(p+Vector2(-size*.5,-size*.68),Vector2.ONE*size),false,Color.WHITE if active else Color("829481"))
	if not active: return
	var lamp := p+Vector2(0,-size*.24)
	if not reduced_motion:
		for i in 3:
			var foot := base+Vector2(sin(clock*.85+i*TAU/3)*size*.27,-size*.09)
			draw_colored_polygon(PackedVector2Array([lamp,foot+Vector2(-17,0),foot+Vector2(17,0)]),Color(.98,.89,.54,.07))
			_ellipse(foot,Vector2(20,5),Color(.98,.90,.58,.18))
	_ellipse(lamp,Vector2(size*.095,size*.09),Color(1,.89,.56,.10))

func _draw_dance() -> void:
	var group: int = mini(3,model.growth_count())
	var pose: Dictionary = Dance.pose(dance_elapsed,dance_style)
	_bee(model.p+pose.offset,1.02,pose.face,1,false,0,"dance")
	for i in group:
		var follower: Dictionary = Dance.pose(dance_elapsed,dance_style,i+1)
		var at: Vector2 = model.p+Vector2(-58-(i%2)*44,22+(i/2)*25)+follower.offset
		_bee(at,0.65,follower.face,smoothstep(0,.22,dance_elapsed),false,float(i+1),"dance")

func _draw_creature(creature: Dictionary) -> void:
	if creature.state == "gone": return
	var p: Vector2 = creature.pos
	if p.x < model.camera_x-90 or p.x > model.camera_x+1370: return
	var guard: bool = creature.kind == "guard"
	var scale := 0.37 if guard else 0.30
	var facing: Vector2 = creature.get("face",Vector2.RIGHT)
	var mirror := -1.0 if facing.x < 0 else 1.0
	var reaction: float = sin(float(creature.get("stun",0))/.42*PI)
	var flutter := 1.0+sin(clock*32+p.x)*0.018
	if not reduced_motion: flutter += reaction*.12
	draw_set_transform(_world_offset+p,0.0,Vector2(mirror,flutter))
	draw_texture_rect_region(CREATURE_ATLAS,Rect2(-Vector2(256,192)*scale*0.5,Vector2(256,192)*scale),Rect2(256,0,256,192),Color(1+reaction*.25,1+reaction*.18,1,1.0-float(creature.get("age",0))/0.65))
	draw_set_transform(_world_offset)
	UIArt.icon(self,"resin" if guard else "fiber",p+Vector2(0,22),10)
	if model.p.distance_to(p) <= model.pulse_radius()+25 and creature.state != "flee":
		var total := 3 if guard else 2
		for i in total:
			draw_circle(p+Vector2((i-(total-1)*.5)*12,-39),4,Color("f3cf75") if i >= int(creature.hits) else Color("546f57"))
		if feedback_font: draw_string(feedback_font,p+Vector2(-7,-51),"Q",HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("294d40"))

func _draw_source(flower: Dictionary) -> void:
	var p: Vector2 = flower.pos if reduced_motion else model.flower_point(flower)
	var purple: bool = flower.type == "rose"
	var stocked: bool = flower.stock > 0
	var join := p+Vector2(54,23) if purple else p+Vector2(0,22)
	var root := Vector2(flower.pos.x+26,Landscape.ground_y(area_key,flower.pos.x+26)+3)
	var stem := PackedVector2Array([join,join+Vector2(12,110),root+Vector2(-25,-125),root])
	ArtProps.stalk(self,stem[0],stem[1],stem[2],stem[3],5.5)
	Landscape.root_crown(self,root,.8)
	for t in [0.42,0.70]:
		var leaf_root: Vector2 = stem[0].bezier_interpolate(stem[1],stem[2],stem[3],t)
		var direction := -1.0 if t < 0.5 else 1.0
		ArtSprites.small_leaf(self,leaf_root,leaf_root+Vector2(64*direction,-28),17)
	var tint := Color.WHITE if stocked else Color("aaa986")
	var opening: float = float(flower.bloom)
	var head_scale := lerpf(0.42,1.0,smoothstep(0,1,opening))
	var working: bool = flower.id in model.harvesting_ids
	var tug := sin(clock*25)*0.025 if working and not reduced_motion else 0.0
	# Scale the flower around its stalk contact, preserving attachment at all poses.
	draw_set_transform(_world_offset+join,tug,Vector2(head_scale,lerpf(.78,1.0,opening)))
	var local_p := p-join
	if purple:
		var factor := 0.19
		var pivot := Vector2(771,431)
		draw_texture_rect_region(ArtProps.FLORA,Rect2(local_p+(ArtProps.SNEEZE.position-pivot)*factor,ArtProps.SNEEZE.size*factor),ArtProps.SNEEZE,tint)
	else:
		var factor := 0.15
		draw_texture_rect_region(ArtSprites.ATLAS,Rect2(local_p+(ArtSprites.FLOWER.position-ArtSprites.FLOWER_PIVOT)*factor,ArtSprites.FLOWER.size*factor),ArtSprites.FLOWER,tint)
	draw_set_transform(_world_offset)
	if stocked:
		var radius := 5.0+sin(clock*2+p.x*0.013)*0.8
		draw_circle(p,radius+3,Color(1.0,0.84,0.34,0.18))
		draw_circle(p,radius,Color("ffe99c") if purple else Color("fff2bd"))
		draw_circle(p+Vector2(-1.8,-1.7),1.8,Color.WHITE)
	if working or (stocked and float(flower.progress)>0.0 and p.distance_to(model.p)<model.harvest_radius()+40):
		var rect := Rect2(p+Vector2(-38,-70),Vector2(76,11))
		draw_style_box(_box_style(Color("264a3b"),Color("fff3cf"),2,6),rect)
		var fill: float = clampf(float(flower.progress),0,1)
		if fill > 0.0: draw_style_box(_box_style(Color("f6ce61"),Color.TRANSPARENT,0,4),Rect2(rect.position+Vector2(2,2),Vector2(72*fill,7)))
		draw_circle(p+Vector2(48,-65),5,Color("f6ce61"))
		if working:
			var mouth: Vector2 = model.p+Vector2(15 if p.x>=model.p.x else -15,10)
			for i in 5:
				var t: float = fposmod(clock*1.8+i*.2,1.0)
				var q := p.lerp(mouth,t)+Vector2(0,-sin(t*PI)*12)
				draw_circle(q,2.2,Color(1,.91,.54,.4+.5*t))

func _draw_working_bee() -> void:
	var at: Vector2 = model.p
	var facing: Vector2 = model.face
	var size := 1.02
	if collecting and not model.harvesting_ids.is_empty():
		for flower in model.flowers:
			if flower.id == model.harvesting_ids[0]:
				var target: Vector2 = model.flower_point(flower)
				facing = Vector2(1 if target.x >= at.x else -1,.28)
				if not reduced_motion:
					at += Vector2(sin(clock*26)*1.8,sin(clock*13)*2.2)
					size += sin(clock*18)*.018
				break
	if not reduced_motion and harvest_recoil > 0.0: at.y -= sin(harvest_recoil/.24*PI)*7
	_bee(at,size,facing,1.0,false,0.0)

func _draw_materials() -> void:
	for drop in model.drops:
		if int(drop.region) != (1 if area_key == "meadow" else 0) or area_key == "hub": continue
		var bounce: float = sin(minf(float(drop.age)/.3,1)*PI)*22
		var at: Vector2 = drop.pos+Vector2(0,-bounce+sin(clock*3)*3)
		draw_circle(at,17,Color(1,.93,.65,.12))
		UIArt.icon(self,drop.kind,at,13)

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
	# Keep the shared canopy geometry; only the source of its stalk moves into view.
	var root := Vector2(p.x+half-34,Landscape.ground_y(area_key,p.x+half-34)+3)
	var stem := PackedVector2Array([p+Vector2(half+4,-80),p+Vector2(half+17,8),root+Vector2(-10,-50),root])
	ArtProps.stalk(self,stem[0],stem[1],stem[2],stem[3],12.0)
	ArtProps.branch(self,stem,.48,p+Vector2(58,54),4.5)
	ArtSprites.canopy(self,p,half)
	ArtSprites.small_leaf(self,p+Vector2(60,57),p+Vector2(-60,57),29)
	Landscape.root_crown(self,root,1.4)

func _draw_shortcut(p: Vector2, far: bool) -> void:
	if p.x < model.camera_x-100 or p.x > model.camera_x+1400: return
	if far and "meadow" not in model.owned: return
	var active: bool = "shortcut" in model.owned
	_stage(p,170,active)
	if feedback_font and model.p.distance_to(p)<=115:
		draw_string(feedback_font,p+Vector2(-63,-125),"F  近道" if active else "尚未点亮",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("2c5544"))

func _draw_rain() -> void:
	if area_key != "meadow": return
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
