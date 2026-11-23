extends "res://nectar_harvest_view.gd"
## The terrain plates are registered to the same world coordinates as the
## field coast. Only the raised tips of separate painted plants shift with
## the camera; their contact shadows, roots and interaction points stay fixed.
const FieldLife = preload("res://region_greybox/model.gd")
const FieldLayout = preload("res://region_greybox/layout.gd")
const POND_PLATE: Texture2D = preload("res://art/collection-pond.webp")
const MEADOW_PLATE: Texture2D = preload("res://art/collection-meadow.webp")
const PLATE_RECT := Rect2(0,-100,2680,1550)
const POND_BLOOM: Texture2D = preload("res://art/collection-blue-bloom.webp")
const MEADOW_BLOOM: Texture2D = preload("res://art/collection-violet-bloom.webp")
const CROWN_SHADER = preload("res://region_game/painted_crown.gdshader")
# Crown bounds on a 700 × 405 registration proof of each complete illustration.
# These are the visible fronds, willow, bulrush and arch leaves already in
# the picture; the lower edge of each local projection stays attached.
const PROOF_SIZE := Vector2(700,405)
const POND_CROWNS := [
	Rect2(0,93,61,67), Rect2(273,111,59,51), Rect2(344,225,46,98),
	Rect2(552,0,131,92), Rect2(0,274,109,109), Rect2(580,244,120,129),
]
const MEADOW_CROWNS := [
	Rect2(0,135,46,76), Rect2(65,73,76,45), Rect2(328,25,84,40),
	Rect2(465,112,74,55), Rect2(74,247,100,72), Rect2(228,283,140,91),
	Rect2(575,289,116,75),
]
var _paint_root: Node2D
var _painted_area := ""
var _crowns: Array[Dictionary] = []
var _life_motes: Array[Dictionary] = []
var _material_recoil := {}
var _full_glow := 0.0

func _ready() -> void:
	super._ready()
	if feedback_font == null:
		var face_font := SystemFont.new()
		face_font.font_names = PackedStringArray(["PingFang SC", "Noto Sans CJK SC", "sans-serif"])
		feedback_font = face_font

func _process(delta: float) -> void:
	super._process(delta)
	if not presentation_active: return
	_full_glow = maxf(0.0,_full_glow-delta)
	for mote in _life_motes: mote.age += delta
	_life_motes = _life_motes.filter(func(m: Dictionary) -> bool: return float(m.age) < float(m.duration))
	for id in _material_recoil:
		_material_recoil[id] = maxf(0.0, float(_material_recoil[id]) - delta)

func nectar_event(event: Dictionary) -> void:
	var kind := str(event.get("kind", ""))
	if area_key == "hub":
		super.nectar_event(event)
		return
	if kind == "full": _full_glow = .85
	var item: Dictionary = {}
	var id := int(event.get("id", event.get("amount", -1)))
	var material := kind.begins_with("material_")
	if model != null and model.field != null and id >= 0:
		var list: Array = model.field.materials if material else model.field.flowers
		if id < list.size(): item = list[id]
	if (kind.begins_with("flower_") or kind.begins_with("material_")) and not item.is_empty() and not bool(item.get("enabled",true)): return
	if kind == "material_hit": _material_recoil[id] = 0.24
	if kind == "pulse" and model != null and model.field != null:
		var target: Vector2 = event.get("to", model.p)
		for candidate in model.field.materials:
			if not bool(candidate.get("enabled",true)): continue
			if candidate.p.distance_to(target)<8: _material_recoil[int(candidate.id)] = 0.24
	if not item.is_empty() and (kind.ends_with("_bud") or kind.ends_with("_ripe") or kind.ends_with("_fading") or kind.ends_with("_empty")):
		_life_motes.append({"p":item.p,"age":0.0,"duration":0.9,
			"fall":kind.ends_with("_fading") or kind.ends_with("_empty"),
			"color":Color("c39a67") if kind.ends_with("_empty") else Color("e3c87c") if kind.ends_with("_fading") else Color("dcebb5")})
	# The controller converts collection/pulse events to the existing feedback contract.
	if kind in ["harvest", "material", "pulse", "pulse_empty", "buy", "unlock", "complete"]:
		super.nectar_event(event)

func _prepare_paint() -> void:
	if _painted_area == area_key: return
	_painted_area = area_key
	if is_instance_valid(_paint_root):
		remove_child(_paint_root)
		_paint_root.queue_free()
	_crowns.clear()
	_paint_root = Node2D.new()
	add_child(_paint_root)
	var texture := POND_PLATE if area_key == "pond" else MEADOW_PLATE
	var picture := Sprite2D.new()
	picture.texture = texture
	picture.centered = false
	picture.position = PLATE_RECT.position
	picture.scale = PLATE_RECT.size/texture.get_size()
	picture.z_index = -2
	_paint_root.add_child(picture)
	var placements := POND_CROWNS if area_key == "pond" else MEADOW_CROWNS
	for proof: Rect2 in placements:
		var uv := Rect2(proof.position/PROOF_SIZE,proof.size/PROOF_SIZE)
		var rect := Rect2(PLATE_RECT.position+uv.position*PLATE_RECT.size,uv.size*PLATE_RECT.size)
		var back := _crown_patch(texture,uv,rect,false)
		var front := _crown_patch(texture,uv,rect,true)
		_crowns.append({"rect":rect,"back":back,"front":front})

func _crown_patch(texture: Texture2D, uv: Rect2, rect: Rect2, foreground: bool) -> Sprite2D:
	var patch := Sprite2D.new()
	patch.texture = texture
	patch.centered = false
	patch.region_enabled = true
	patch.region_rect = Rect2(uv.position*texture.get_size(),uv.size*texture.get_size())
	patch.scale = PLATE_RECT.size/texture.get_size()
	patch.position = rect.position
	patch.z_index = 1 if foreground else -1
	var paint := ShaderMaterial.new()
	paint.shader = CROWN_SHADER
	paint.set_shader_parameter("center_uv",uv.get_center())
	paint.set_shader_parameter("radii_uv",uv.size*.5)
	paint.set_shader_parameter("foreground",foreground)
	patch.material = paint
	_paint_root.add_child(patch)
	return patch

func _canopy_offset(rect: Rect2) -> Vector2:
	if reduced_motion: return Vector2.ZERO
	var eye: Vector2 = model.camera_offset+Vector2(640,400)
	var relative := ((rect.get_center()-eye)/Vector2(640,400)).clamp(-Vector2.ONE,Vector2.ONE)
	return relative*Vector2(minf(29.0,rect.size.x*.12),minf(13.0,rect.size.y*.06))

func _update_crowns() -> void:
	var player_uv: Vector2 = (model.p-PLATE_RECT.position)/PLATE_RECT.size
	var visible_world := Rect2(model.camera_offset,get_viewport_rect().size)
	for crown in _crowns:
		var rect: Rect2 = crown.rect
		var back: Sprite2D = crown.back
		var front: Sprite2D = crown.front
		back.visible = visible_world.intersects(rect)
		front.visible = back.visible and model.p.y+33.0<rect.end.y and rect.grow(55).has_point(model.p)
		if not back.visible: continue
		var shift := _canopy_offset(rect)/PLATE_RECT.size
		back.material.set_shader_parameter("shift_uv",shift)
		if front.visible:
			front.material.set_shader_parameter("shift_uv",shift)
			front.material.set_shader_parameter("player_uv",player_uv)

func _visible(at: Vector2, padding := 130.0) -> bool:
	return Rect2(model.camera_offset-Vector2.ONE*padding,get_viewport_rect().size+Vector2.ONE*padding*2).has_point(at)

func _draw() -> void:
	if model == null: return
	if area_key == "hub":
		if is_instance_valid(_paint_root): _paint_root.hide()
		super._draw()
		return
	if model.field == null: return
	_prepare_paint()
	_world_offset = -model.camera_offset
	_paint_root.show()
	_paint_root.position = _world_offset
	_update_crowns()
	draw_set_transform(_world_offset)
	var actors: Array[Dictionary] = []
	for flower in model.field.flowers:
		if not bool(flower.get("enabled",true)): continue
		if _visible(flower.p):
			var foot := _resource_root(flower)
			_ground_shadow(foot+Vector2(4,1),Vector2(20,5),.23)
			actors.append({"kind":"flower","y":foot.y,"data":flower})
	for item in model.field.materials:
		if not bool(item.get("enabled",true)): continue
		if _visible(item.p):
			_ground_shadow(item.anchor+Vector2(0,47),Vector2(23,7),.17)
			actors.append({"kind":"material","y":item.anchor.y+47,"data":item})
	var entry: Vector2 = model.field.layout.nodes[0].p
	actors.append({"kind":"entry","y":entry.y+54,"p":entry})
	_ground_shadow(model.p+Vector2(0,33),Vector2(22,7),.16)
	actors.append({"kind":"player","y":model.p.y+33})
	actors.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return float(a.y) < float(b.y))
	for actor in actors:
		match actor.kind:
			"flower": _draw_living_flower(actor.data)
			"material": _draw_living_material(actor.data)
			"entry": _draw_entry(actor.p)
			"player":
				_draw_working_bee()
				_draw_bag()
	_draw_resource_feedback()
	_draw_region_effects()
	draw_set_transform(Vector2.ZERO)
	_draw_home_bearing()

func _bloom_texture() -> Texture2D:
	return MEADOW_BLOOM if area_key == "meadow" else POND_BLOOM

func _resource_root(flower: Dictionary) -> Vector2:
	var id := int(flower.id)
	return flower.p+Vector2(float(id%3-1)*5,39+float(id%4)*6)

func _flower_visual_point(flower: Dictionary) -> Vector2:
	var at: Vector2 = flower.p
	if not reduced_motion and flower.phase != "empty":
		at += Vector2(sin(clock*1.5+float(flower.id)*.7)*1.5,0)
		if int(flower.id) in model.field._locked:
			var pull := smoothstep(0.0,.85,float(flower.progress))
			at += at.direction_to(model.p) * (pull*5.0)
	return at

func _draw_living_flower(flower: Dictionary) -> void:
	if not bool(flower.get("enabled",true)): return
	var phase := str(flower.phase)
	var root := _resource_root(flower)
	var ratio := FieldLife.phase_ratio(flower)
	var purple := area_key == "meadow"
	if phase == "empty":
		_ellipse(root,Vector2(13,4),Color("67724c"))
		ArtSprites.small_leaf(self,root,root+Vector2(-13,-6),5)
		ArtSprites.small_leaf(self,root,root+Vector2(12,-5-ratio*6),5+ratio*3)
		return
	var at := _flower_visual_point(flower)
	var opening := .35+.65*ratio if phase == "bud" else 1.0-ratio*.28 if phase == "fading" else 1.0
	var bloom := _bloom_texture()
	var head_size := .88+float(int(flower.id)%5)*.055
	var width := (58.0 if purple else 54.0)*head_size
	var span := Vector2.ZERO
	var join := at+Vector2(0,14)
	if bloom != null:
		span = bloom.get_size()*(width/bloom.get_width())
		join = at+Vector2(0,span.y*.48)
	elif purple:
		join = at+Vector2(30,15)
	if phase == "bud": join = root.lerp(join,.48+ratio*.52)
	if phase == "fading": join += Vector2(3,ratio*8)
	var habit := sin(float(flower.id)*2.39996)
	var bend := Vector2(8.0*habit,0)
	var neck := join.lerp(root,.33)+bend
	var lower := join.lerp(root,.70)+bend*.65
	# Monotonic controls keep a short bud stem from folding through itself.
	ArtProps.stalk(self,join,neck,lower,root,3.2)
	for t in [.50,.78]:
		var petiole: Vector2 = join.bezier_interpolate(neck,lower,root,t)
		var reach := Vector2((-22.0 if t<.6 else 20.0)+habit*4.0,-12.0+habit*3.0)
		ArtSprites.small_leaf(self,petiole,petiole+reach,8)
	ArtSprites.small_leaf(self,root,root+Vector2(-23.0+habit*5.0,-7),10)
	ArtSprites.small_leaf(self,root,root+Vector2(17,-12.0-habit*6.0),9)
	var tint := Color("b8c58c") if phase == "bud" else Color.WHITE.lerp(Color("b6a483"),ratio*.72) if phase == "fading" else Color.WHITE
	if model.p.y+33 < root.y and model.p.distance_to(at) < 65: tint.a = .58
	var working: bool = int(flower.id) in model.field._locked
	var tug := sin(clock*13)*.052 if working and not reduced_motion else 0.0
	var fold := Vector2(opening,.70+opening*.30)
	if bloom != null:
		draw_set_transform(_world_offset+join,tug+habit*.08,fold)
		draw_texture_rect(bloom,Rect2(-span*Vector2(.5,.97),span),false,tint)
	else:
		draw_set_transform(_world_offset+join,tug+habit*.075,fold*head_size)
	if bloom == null and purple:
		var source := ArtProps.SNEEZE
		var pivot := Vector2(771,431)
		draw_texture_rect_region(ArtProps.FLORA,Rect2(Vector2(-30,-15)+(source.position-pivot)*.135,source.size*.135),source,tint)
	elif bloom == null:
		draw_texture_rect_region(ArtSprites.ATLAS,Rect2(Vector2(0,-14)+(ArtSprites.FLOWER.position-ArtSprites.FLOWER_PIVOT)*.115,ArtSprites.FLOWER.size*.115),ArtSprites.FLOWER,tint)
	draw_set_transform(_world_offset)
	if phase in ["ripe","fading"]:
		var nectar := at+Vector2(0,ratio*6 if phase == "fading" else 0)
		draw_circle(nectar,6,Color(1,.88,.50,.20))
		draw_circle(nectar,3.1,Color("ffe9a0"))
		draw_circle(nectar+Vector2(-1,-1),1,Color("fff8db"))
	if phase == "fading" and not reduced_motion:
		var fall := fposmod(clock*.65+float(flower.id)*.21,1.0)
		_ellipse(at+Vector2(18+sin(fall*PI)*9,fall*43),Vector2(3,1.5),Color(.74,.59,.37,(1-fall)*.65))

func _draw_living_material(item: Dictionary) -> void:
	if not bool(item.get("enabled",true)): return
	var root: Vector2 = item.anchor+Vector2(0,47)
	var at: Vector2 = item.p
	var phase := str(item.phase)
	var ratio := FieldLife.phase_ratio(item)
	var kind := "fiber" if area_key == "pond" else "resin"
	if bool(item.dropped):
		var fall := clampf(float(item.phase_time)/.35,0,1)
		var lift := 0.0 if reduced_motion else sin(fall*PI)*17
		var joint: Vector2 = item.anchor+Vector2(0,15)
		ArtProps.stalk(self,joint,joint.lerp(root,.32)+Vector2(-2,0),joint.lerp(root,.7),root,3.4)
		for side in [-1,1]:
			ArtSprites.small_leaf(self,joint,joint+Vector2(side*20,-10),7)
		_ground_shadow(at+Vector2(0,12),Vector2(18,5),.16)
		var tint := Color.WHITE.lerp(Color("a9a082"),smoothstep(.65,1,ratio))
		UIArt.painted_icon(self,kind,at+Vector2(0,-lift),18,tint)
		draw_arc(at+Vector2(0,1),25,-PI*.5,-PI*.5+TAU*(1-ratio),40,Color("e9ca79"),2,true)
		return
	# Fibers emerge from a seed head; resin gathers on a rooted woody twig.
	# Both retain a physical source while their collectible portion regenerates.
	if kind == "fiber":
		var join := at+Vector2(0,12)
		ArtProps.stalk(self,join,join.lerp(root,.33)+Vector2(3,0),join.lerp(root,.70)+Vector2(-2,0),root,4.5)
	else:
		_curve(root,root+Vector2(-6,-15),at+Vector2(7,23),at+Vector2(0,-14),Color("735638"),8)
		_curve(root+Vector2(-2,-3),root+Vector2(-8,-15),at+Vector2(4,23),at+Vector2(-2,-13),Color("b79a5d"),2)
		_curve(root+Vector2(0,-18),root+Vector2(8,-24),root+Vector2(18,-31),root+Vector2(22,-34),Color("735638"),4)
	for direction in [-1,1]:
		ArtSprites.small_leaf(self,root+Vector2(0,-10),root+Vector2(29*direction,-24),13 if kind == "fiber" else 9)
	if phase == "empty":
		ArtSprites.small_leaf(self,root,root+Vector2(9,-12-ratio*7),7)
		return
	var scale := .3+ratio*.7 if phase == "bud" else 1-ratio*.18 if phase == "fading" else 1.0
	var recoil: float = float(_material_recoil.get(int(item.id),0.0))
	if recoil > 0 and not reduced_motion: at += Vector2(sin(recoil*70)*5,0)
	var color := Color.WHITE if phase == "ripe" else Color("beac88") if phase == "fading" else Color("b4c786")
	var split := float(item.hits)*4
	if kind == "fiber":
		ArtSprites.small_leaf(self,at+Vector2(-split,13),at+Vector2(-28-split,-10)*scale,19*scale)
		ArtSprites.small_leaf(self,at+Vector2(split,13),at+Vector2(28+split,-10)*scale,19*scale)
	else:
		_ellipse(at+Vector2(0,5),Vector2(14,19)*scale,Color("76583e"))
		if int(item.hits)>0:
			_curve(at+Vector2(-12,10),at+Vector2(-5,1),at+Vector2(4,13),at+Vector2(13,-2),Color("c5a467"),1.5)
	UIArt.painted_icon(self,kind,at,17*scale,color)
	if phase == "ripe": draw_circle(at+Vector2(-6,-8),2,Color("ffefae"))

func _draw_entry(at: Vector2) -> void:
	var foot := at+Vector2(-57,50)
	ArtProps.stalk(self,foot+Vector2(0,-98),foot+Vector2(-2,-64),foot+Vector2(3,-22),foot,8)
	_ground_shadow(foot,Vector2(30,8),.16)
	UIArt.painted_sprite(self,HOME_SIGN,Rect2(210,215,1060,610),foot+Vector2(0,-74),66)
	ArtSprites.small_leaf(self,foot+Vector2(0,-34),foot+Vector2(29,-55),12)
	if model.p.distance_to(at)<240:
		_region_label(foot+Vector2(0,-121),"E  回庭院" if model.field.at_entry() else "庭院入口",true)

func _draw_working_bee() -> void:
	if area_key == "hub":
		super._draw_working_bee()
		return
	var field = model.field
	var facing: Vector2 = field.face
	var at: Vector2 = field.p
	var scale := 1.02
	var locked_flower: Dictionary = {}
	for id in field._locked:
		if bool(field.flowers[int(id)].get("enabled",true)):
			locked_flower = field.flowers[int(id)]
			break
	if collecting and not locked_flower.is_empty():
		var flower: Dictionary = locked_flower
		facing = (flower.p-at).normalized()
		at += facing*9
		if not reduced_motion:
			at += Vector2(sin(clock*24)*1.4,sin(clock*13)*1.7)
			scale += sin(clock*19)*.015
	if not reduced_motion and harvest_recoil > 0: at.y -= sin(harvest_recoil/.24*PI)*6
	var push := 0.0
	if float(field.pulse_flash) > 0:
		facing = wing_direction
		push = sin(clampf(float(field.pulse_flash)/.18,0,1)*PI)
		if not reduced_motion:
			at -= facing*push*4
			scale += push*.05
	_bee(at,scale,facing,1.0,false,0.0,"leader",push)

func _draw_resource_feedback() -> void:
	var nearest_flower: Dictionary = {}
	var flower_distance := 105.0
	for flower in model.field.flowers:
		if not bool(flower.get("enabled",true)): continue
		var at: Vector2 = flower.p
		if not _visible(at): continue
		var distance: float = model.p.distance_to(at)
		if distance<flower_distance:
			flower_distance = distance
			nearest_flower = flower
		var working: bool = int(flower.id) in model.field._locked
		if working:
			var fill := clampf(float(flower.progress),0,1)
			draw_arc(at,22,-PI*.5,-PI*.5+TAU*maxf(.01,fill),36,Color("f5d383"),3,true)
			if not reduced_motion:
				for i in 3:
					var t := fposmod(clock*1.5+float(i)/3,1)
					var q := at.lerp(model.p,t)+Vector2(0,-sin(t*PI)*7)
					draw_circle(q,2,Color(1,.91,.59,.3+t*.5))
	var closest: Dictionary = {}
	var shortest := 155.0
	for item in model.field.materials:
		if not bool(item.get("enabled",true)): continue
		var distance: float = model.p.distance_to(item.p)
		if distance < shortest:
			closest = item
			shortest = distance
	if closest.is_empty():
		if not nearest_flower.is_empty():
			var phase := str(nearest_flower.phase)
			var words: String = {"bud":"花苞正在舒展","empty":"新芽正在生长","ripe":"E  采蜜","fading":"E  采蜜 · 花将谢"}[phase]
			_region_label(nearest_flower.p+Vector2(0,-66),words,phase in ["ripe","fading"])
		return
	var at: Vector2 = closest.p
	if closest.dropped:
		_region_label(at+Vector2(0,-39),"靠近拾取 · 即将消散" if FieldLife.phase_ratio(closest)>.70 else "靠近拾取",true)
	elif closest.phase in ["ripe","fading"]:
		var total := 2 if area_key == "pond" else 3
		for i in total:
			draw_circle(at+Vector2(float(i)*12-float(total-1)*6,-31),3.5,Color("edcf89") if i >= int(closest.hits) else Color("677653"))
		_region_label(at+Vector2(0,-54),"Q  振翅 · 将谢" if closest.phase == "fading" else "Q  振翅取材",true)
	else:
		_region_label(at+Vector2(0,-34),"正在生长" if closest.phase == "bud" else "等待新生",false)
		var ratio := FieldLife.phase_ratio(closest)
		draw_arc(at,24,-PI*.5,-PI*.5+TAU*maxf(.01,ratio),36,Color(.84,.89,.65,.6),1.5,true)

func _draw_region_effects() -> void:
	for ring in pulse_rings:
		var t: float = ring.age/.4
		var axis: Vector2 = (ring.to-ring.p).normalized()
		var front: Vector2 = ring.p.lerp(ring.to,minf(t/.45,1))
		for lane in [-1,0,1]:
			var side: Vector2 = axis.orthogonal()*float(lane)*10
			draw_line(front-axis*24+side,front+side*.65,Color(1,.95,.74,(1-t)*(.25 if ring.empty else .75)),2,true)
	for mote in nectar_motes:
		if mote.age < 0: continue
		var t: float = clampf(mote.age/mote.duration,0,1)
		var side := -1 if model.face.x >= 0 else 1
		var pocket: Vector2 = model.p+Vector2(side*20,18)
		var q: Vector2 = mote.from.lerp(pocket,smoothstep(0,1,t))
		if not reduced_motion: q.y -= sin(t*PI)*26
		if reduced_motion: continue
		if mote.has("material"):
			UIArt.icon(self,mote.material,q,14*(1-t*.30))
		else:
			var radius := 6.8*(1-t*.34)
			draw_circle(q,radius+1,Color("94682c"),true,-1,true)
			draw_circle(q,radius,Color("eca3ae") if mote.gold else Color("f7c655"),true,-1,true)
			draw_circle(q-Vector2(1.4,1.6),radius*.32,Color("fff6cd"))
			if t < .55:
				for i in 4:
					var tip: Vector2 = mote.from + Vector2.from_angle(TAU*i/4+.4)*(8+t*27)
					draw_circle(tip,2.4*(1-t),Color("ffe4a0",1-t))
	for mote in _life_motes:
		var t: float = float(mote.age)/float(mote.duration)
		for i in 4:
			var at: Vector2 = mote.p+Vector2(float(i-2)*7+sin(t*PI+float(i))*5,(t*28 if mote.fall else -t*22))
			var tone: Color = mote.color
			tone.a = (1-t)*.65
			_ellipse(at,Vector2(2.7,1.4),tone)
	for item in harvest_texts:
		var tone := Color(1,.96,.76,1-float(item.age))
		var at: Vector2 = item.p+Vector2(13,-33-float(item.age)*25)
		draw_string_outline(feedback_font,at,item.text,HORIZONTAL_ALIGNMENT_LEFT,-1,17,3,Color(.18,.27,.19,tone.a*.8))
		draw_string(feedback_font,at,item.text,HORIZONTAL_ALIGNMENT_LEFT,-1,17,tone)

func _region_label(at: Vector2, words: String, active: bool) -> void:
	if feedback_font == null: return
	var width := feedback_font.get_string_size(words,HORIZONTAL_ALIGNMENT_LEFT,-1,17).x
	var baseline := at+Vector2(-width*.5,5)
	draw_string_outline(feedback_font,baseline,words,HORIZONTAL_ALIGNMENT_LEFT,-1,17,4,Color("304a37e8"))
	draw_string(feedback_font,baseline,words,HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("ffedbd") if active else Color("dce5c0"))

func _draw_home_bearing() -> void:
	var entry: Vector2 = model.field.layout.nodes[0].p
	if model.p.distance_to(entry)<330 and _full_glow <= 0: return
	var at := get_viewport_rect().size-Vector2(112,50)
	var direction: Vector2 = (entry-model.p).normalized()
	var side := direction.orthogonal()
	var centre := at-Vector2(48,0)
	if _full_glow > 0:
		var alpha := minf(_full_glow*3,1)
		draw_circle(centre,13,Color("5b512e",alpha*.9),true,-1,true)
		draw_arc(centre,13,0,TAU,28,Color("f9d979",alpha),2,true)
	draw_polyline(PackedVector2Array([centre-direction*5-side*5,centre+direction*6,centre-direction*5+side*5]),Color("f5df9f"),2.5,true)
	_region_label(at+Vector2(5,0),"回庭院",false)
