extends "res://nectar_harvest_view.gd"
## The terrain plates are registered to the same world coordinates as the
## field coast. Only the raised tips of separate painted plants shift with
## the camera; their contact shadows, roots and interaction points stay fixed.
const EnergyDial = preload("res://nectar_energy_dial.gd")
const FieldLife = preload("res://region_greybox/model.gd")
const FieldLayout = preload("res://region_greybox/layout.gd")
const POND_PLATE: Texture2D = preload("res://art/collection-pond.webp")
const MEADOW_PLATE: Texture2D = preload("res://art/collection-meadow.webp")
const MeadowLayout = preload("res://region_game/layout.gd")
const PLATE_RECT := MeadowLayout.PLATE
const FIELD_SIGN = preload("res://art/collection-home-sign.webp")
const BEE_FOOT := Vector2(0,25)
const SIGN_FOOT := Vector2(-67,24)
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
			if int(event.get("source_id",-1)) == candidate.id or candidate.p.distance_to(target)<8: _material_recoil[int(candidate.id)] = 0.24
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
	paint.set_shader_parameter("world_size",PLATE_RECT.size)
	patch.material = paint
	_paint_root.add_child(patch)
	return patch

func _canopy_offset(rect: Rect2) -> Vector2:
	if reduced_motion: return Vector2.ZERO
	var half_view := MeadowLayout.VIEWPORT/(2.0*MeadowLayout.FIELD_ZOOM)
	var eye: Vector2 = model.camera_offset+half_view
	var relative := ((rect.get_center()-eye)/half_view).clamp(-Vector2.ONE,Vector2.ONE)
	return relative*Vector2(minf(29.0,rect.size.x*.12),minf(13.0,rect.size.y*.06))

func _update_crowns() -> void:
	var player_uv: Vector2 = (model.p-PLATE_RECT.position)/PLATE_RECT.size
	var visible_world := Rect2(model.camera_offset,get_viewport_rect().size/MeadowLayout.FIELD_ZOOM)
	for crown in _crowns:
		var rect: Rect2 = crown.rect
		var back: Sprite2D = crown.back
		var front: Sprite2D = crown.front
		back.visible = visible_world.intersects(rect)
		front.visible = back.visible and model.p.y+BEE_FOOT.y<rect.end.y and rect.grow(55).has_point(model.p)
		if not back.visible: continue
		var shift := _canopy_offset(rect)/PLATE_RECT.size
		back.material.set_shader_parameter("shift_uv",shift)
		if front.visible:
			front.material.set_shader_parameter("shift_uv",shift)
			front.material.set_shader_parameter("player_uv",player_uv)

func _visible(at: Vector2, padding := 130.0) -> bool:
	return Rect2(model.camera_offset-Vector2.ONE*padding,get_viewport_rect().size/scale+Vector2.ONE*padding*2).has_point(at)

func _draw() -> void:
	if model == null: return
	if area_key == "hub":
		scale = Vector2.ONE
		if is_instance_valid(_paint_root): _paint_root.hide()
		super._draw()
		return
	if model.field == null: return
	scale = Vector2.ONE*MeadowLayout.FIELD_ZOOM
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
			actors.append({"kind":"flower","y":_flower_depth(flower),"data":flower})
	for item in model.field.materials:
		if not bool(item.get("enabled",true)): continue
		if _visible(item.p):
			_ground_shadow(_material_root(item),Vector2(22,6),.17)
			actors.append({"kind":"material","y":_material_depth(item),"data":item})
			if item.dropped: actors.append({"kind":"material_drop","y":item.p.y+6,"data":item})
	var entry: Vector2 = model.field.layout.nodes[0].p
	actors.append({"kind":"entry","y":entry.y+SIGN_FOOT.y,"p":entry})
	_ground_shadow(model.p+BEE_FOOT,Vector2(16,5),.16)
	actors.append({"kind":"player","y":model.p.y+BEE_FOOT.y})
	actors.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return float(a.y) < float(b.y))
	for actor in actors:
		match actor.kind:
			"flower": _draw_living_flower(actor.data)
			"material": _draw_living_material(actor.data)
			"material_drop": _draw_material_drop(actor.data)
			"entry": _draw_entry(actor.p)
			"player":
				_draw_working_bee()
				_draw_bag()
	_draw_resource_feedback()
	_draw_region_effects()
	if model.p.distance_to(entry) < 240.0:
		var label_at: Vector2 = entry + SIGN_FOOT + Vector2(0,-89)
		if model.field.at_entry():
			_return_badge(label_at,"E / 左键  回庭院")
		else:
			_region_label(label_at,"庭院入口",false)
	draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE/MeadowLayout.FIELD_ZOOM)
	_draw_home_bearing()

func _bloom_texture() -> Texture2D:
	return MEADOW_BLOOM if area_key == "meadow" else POND_BLOOM

func _resource_root(flower: Dictionary) -> Vector2:
	var id := int(flower.id)
	return flower.p+Vector2(float(id%3-1)*4,29+float((id*7)%6)*3.8+(5.0 if area_key=="meadow" else 0.0))

func _flower_contact(flower: Dictionary) -> bool:
	return collecting and int(flower.stock)>0 and int(flower.id) in model.field._locked

func _flower_depth(flower: Dictionary) -> float:
	var ground := _resource_root(flower).y
	return minf(ground,model.p.y+BEE_FOOT.y-1) if _flower_contact(flower) else ground

func _flower_visual_point(flower: Dictionary) -> Vector2:
	var at: Vector2 = flower.p
	if not reduced_motion and flower.phase != "empty":
		at += Vector2(sin(clock*1.5+float(flower.id)*.7)*1.5,0)
		if _flower_contact(flower):
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
		var calyx := root+Vector2(5,-24.0+ratio*4)
		ArtProps.stalk(self,calyx,calyx+Vector2(-6,4),root+Vector2(-3,-11),root,2.4)
		_ellipse(calyx,Vector2(4.7,3.3),Color("ac9765"))
		_ellipse(root,Vector2(13,4),Color("67724c"))
		ArtSprites.small_leaf(self,root,root+Vector2(-13,-6),5)
		ArtSprites.small_leaf(self,root,root+Vector2(12,-5-ratio*6),5+ratio*3)
		return
	var at := _flower_visual_point(flower)
	var opening := .35+.65*ratio if phase == "bud" else 1.0-ratio*.28 if phase == "fading" else 1.0
	var bloom := _bloom_texture()
	var head_size := .82+float((int(flower.id)*7)%6)*.064
	var width := (51.0 if purple else 46.0)*head_size
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
	if not _flower_contact(flower) and model.p.y+BEE_FOOT.y < root.y and model.p.distance_to(at) < 46: tint.a = .75
	var working := _flower_contact(flower)
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
	if int(flower.stock)>0:
		var nectar := at+Vector2(0,ratio*6 if phase == "fading" else 0)
		draw_circle(nectar,6,Color(1,.88,.50,.20))
		draw_circle(nectar,3.1,Color("ffe9a0"))
		draw_circle(nectar+Vector2(-1,-1),1,Color("fff8db"))
	if phase == "fading" and not reduced_motion:
		var fall := fposmod(clock*.65+float(flower.id)*.21,1.0)
		_ellipse(at+Vector2(18+sin(fall*PI)*9,fall*43),Vector2(3,1.5),Color(.74,.59,.37,(1-fall)*.65))

const FIBER_HOST: Texture2D = preload("res://art/collection-fiber-source.webp")
const RESIN_HOST: Texture2D = preload("res://art/collection-resin-source.webp")
const AMBER_DROP := Rect2(148,691,372,469)

const FIBER_SOCKET := Vector2(.77,.16)
const FIBER_FOOT := Vector2(.65,.99)
const RESIN_SOCKET := Vector2(.50,.44)
const RESIN_FOOT := Vector2(.51,.98)

func _material_span(item: Dictionary) -> Vector2:
	var fiber := area_key == "pond"
	var texture := FIBER_HOST if fiber else RESIN_HOST
	var size := texture.get_size() * (118.0/texture.get_height() if fiber else 126.0/texture.get_width())
	var maturity := .84 if item.band == "near" else 1.10 if item.band == "far" else 1.0
	return size*maturity

func _material_root(item: Dictionary) -> Vector2:
	var foot_offset := FIBER_FOOT-FIBER_SOCKET if area_key == "pond" else RESIN_FOOT-RESIN_SOCKET
	return item.anchor + _material_span(item)*foot_offset

func _material_depth(item: Dictionary) -> float:
	var depth := _material_root(item).y
	if model.field.drawing_resin_id == item.id:
		return minf(depth,model.p.y+BEE_FOOT.y-1)
	return depth

func _draw_living_material(item: Dictionary) -> void:
	if not bool(item.get("enabled",true)): return
	var fiber := area_key == "pond"
	var span := _material_span(item)
	var body := Rect2(item.anchor-span*(FIBER_SOCKET if fiber else RESIN_SOCKET),span)
	var covered: bool = _material_depth(item)>model.p.y+BEE_FOOT.y and body.grow(8).has_point(model.p)
	var tint := Color(1,1,1,.58) if covered else Color.WHITE
	draw_texture_rect(FIBER_HOST if fiber else RESIN_HOST,body,false,tint)
	if item.dropped or item.phase == "empty": return
	var ratio := FieldLife.phase_ratio(item)
	var growth := .30+ratio*.70 if item.phase == "bud" else 1.0
	var at: Vector2 = item.anchor
	var recoil: float = float(_material_recoil.get(int(item.id),0.0))
	if recoil>0 and not reduced_motion: at.x += sin(recoil*72.0)*recoil*11.0
	if fiber:
		var spread := 1.16 if int(item.hits)>0 else .82
		_seed_down(at,growth*span.y/108.0,spread,item.phase=="fading")
	else:
		var open: bool = model.field.resin_open(item)
		var extent := (14.0 if open else 6.5 if int(item.hits)>0 else 4.5)*growth*span.y/104.0
		extent *= 1.0-.56*float(item.get("resin_draw",0.0))/model.field.RESIN_SECONDS
		var resin_tint := Color("d7a774") if item.phase=="fading" else Color.WHITE
		# A narrow bark lip lifts away from the bead at the exposed seam.
		var gap := 9.0 if open else 3.0 if int(item.hits)>0 else 0.0
		var bark_foot := at+Vector2(-3,9)
		var tip := at+Vector2(-4-gap,-9)
		_curve(bark_foot,bark_foot+Vector2(-4,-5),tip+Vector2(2,4),tip,Color("795337"),3.2)
		_curve(bark_foot,bark_foot+Vector2(-4,-4),tip+Vector2(2,4),tip,Color("bc975d"),1.1)
		UIArt.painted_sprite(self,UIArt.RESOURCES,AMBER_DROP,at,extent,resin_tint)

func _seed_down(at: Vector2, size: float, spread: float, weathered: bool) -> void:
	var fiber_color := Color("d6c79f") if weathered else Color("f4e7bb")
	var highlight := Color("e1d2ac") if weathered else Color("fff4d6")
	for i in 7:
		var t := float(i-3)/3.0
		var root := at + Vector2(t*3.0,3.0+absf(t))*size
		var tip := root + Vector2(t*16.0*spread,-(12.0-absf(t)*5.0)+sin(float(i)*2.2)*2.0)*size
		_curve(root,root.lerp(tip,.25)+Vector2(t*2.0,0),root.lerp(tip,.72),tip,Color("bc9a62"),maxf(1.0,1.8*size))
		var tuft := 3.5+float(i%3)
		for j in 3:
			var end := tip + Vector2((float(j)-1.0)*3.8+t*3.0,-tuft+absf(float(j)-1)*1.6)*size
			draw_line(tip,end,highlight if j==1 else fiber_color,maxf(1.0,1.5*size),true)

func _draw_material_drop(item: Dictionary) -> void:
	var at: Vector2 = item.p
	var travel := clampf(float(item.phase_time)/.35,0.0,1.0)
	if not reduced_motion:
		at = item.anchor.lerp(at,smoothstep(0,1,travel))
		at.y -= sin(travel*PI)*13.0
	_ground_shadow(item.p+Vector2(0,7),Vector2(13,4),.18)
	if area_key == "pond":
		_seed_down(at+Vector2(0,3),.95,1.22,FieldLife.phase_ratio(item)>.72)
	else:
		# Drops already loose in a 0.31 meadow save remain individually pickable.
		UIArt.painted_icon(self,"resin",at,11)
	if FieldLife.phase_ratio(item)>.68:
		draw_arc(at,17,-PI*.5,-PI*.5+TAU*(1.0-FieldLife.phase_ratio(item)),28,Color("e3c383"),2,true)

func _draw_entry(at: Vector2) -> void:
	var foot := at+SIGN_FOOT
	var span := FIELD_SIGN.get_size()*(81.0/FIELD_SIGN.get_height())
	_ground_shadow(foot,Vector2(16,4),.16)
	draw_texture_rect(FIELD_SIGN,Rect2(foot-span*Vector2(.53,.98),span),false)

func _field_bee_pose() -> Dictionary:
	var field = model.field
	var facing: Vector2 = field.face
	var at: Vector2 = field.p
	var body_scale := .82
	if field.drawing_resin_id >= 0:
		var scar: Vector2 = field.materials[field.drawing_resin_id].anchor
		var toward := at.direction_to(scar)
		if not toward.is_zero_approx():
			facing = toward
			at += toward*minf(6.0,at.distance_to(scar))
	for id in field._locked:
		var flower: Dictionary = field.flowers[int(id)]
		if not _flower_contact(flower): continue
		var towards: Vector2 = at.direction_to(flower.p)
		if not towards.is_zero_approx(): facing = towards
		at += facing*minf(8.0,at.distance_to(flower.p))
		if not reduced_motion: at.y += sin(clock*13)*1.1
		break
	if not reduced_motion and harvest_recoil > 0: at.y -= sin(harvest_recoil/.24*PI)*4
	var push := 0.0
	if float(field.pulse_flash) > 0:
		facing = wing_direction
		push = sin(clampf(float(field.pulse_flash)/.18,0,1)*PI)
		if not reduced_motion:
			at -= facing*push*3
			body_scale += push*.035
	return {"p":at,"face":facing,"size":body_scale,"push":push}

func _draw_working_bee() -> void:
	if area_key == "hub":
		super._draw_working_bee()
		return
	var pose := _field_bee_pose()
	_bee(pose.p,pose.size,pose.face,1.0,false,0.0,"leader",pose.push)

func _draw_bag() -> void:
	if area_key == "hub":
		super._draw_bag()
		return
	var pose := _field_bee_pose()
	_draw_bag_at(pose.p,pose.face,pose.size)

func _draw_resource_feedback() -> void:
	var field = model.field
	if field.departed and field.at_entry(): return
	var focus := {}
	var best := INF
	var active_count := 0
	for flower in field.flowers:
		if not bool(flower.get("enabled",true)): continue
		var at: Vector2 = flower.p
		var distance: float = field.p.distance_to(at)
		if distance>field.stats.harvest_radius() or not field.clear_line(field.p,at): continue
		if _flower_contact(flower):
			_draw_nectar_status(flower,active_count==0)
			active_count+=1
			if not reduced_motion:
				for i in 3:
					var t := fposmod(clock*1.5+float(i)/3,1)
					var q := at.lerp(model.p,t)+Vector2(0,-sin(t*PI)*7)
					draw_circle(q,2,Color(1,.91,.59,.3+t*.5))
		# On release the closest flower shows its own stock. While harvesting,
		# the active locks above already identify the exact targets.
		if distance<best:
			best = distance
			focus = flower
	if active_count>0: return
	var material: Dictionary = field.material_for_hint()
	if not material.is_empty():
		_draw_material_hint(material)
	elif not focus.is_empty():
		_draw_nectar_status(focus,true)

func _nectar_caption(flower: Dictionary) -> String:
	if _flower_contact(flower): return "采蜜中"
	if flower.phase == "empty": return "花期已过"
	if flower.phase == "bud": return "花苞渐开"
	if flower.has("nectar_wait"): return "补蜜中" if flower.phase=="ripe" else "将谢 · 补蜜中"
	if model.field.cargo >= model.field.capacity(): return "蜜囊已满"
	return "按住 E / 左键" if flower.phase=="ripe" else "花将谢 · 按住 E"

func _draw_nectar_status(flower: Dictionary, show_caption: bool) -> void:
	var cap: String = _nectar_caption(flower) if show_caption else ""
	var anchor: Vector2 = flower.p + Vector2(0,-45)
	if flower.phase in ["empty","bud"]:
		if show_caption: _region_label(anchor,cap,false)
		return
	var glass := Color("3d493b")
	var gold := Color("ffd175")
	var cream := Color("fff0bf")
	var radius := 16.0
	var width := feedback_font.get_string_size(cap,HORIZONTAL_ALIGNMENT_LEFT,-1,18).x if not cap.is_empty() else 0.0
	var icon := anchor - Vector2(width*.5,0)
	# Clamp the entire flower-side mark to the visible field, including a long caption.
	var bounds := get_viewport_rect().size/scale
	icon.x = clampf(icon.x,model.camera_offset.x+radius+3,model.camera_offset.x+bounds.x-width-radius*2-4)
	icon.y = clampf(icon.y,model.camera_offset.y+radius+5,model.camera_offset.y+bounds.y-radius-5)
	draw_circle(icon,radius,glass,true,-1,true)
	draw_arc(icon,radius-1,0,TAU,40,Color("bda777"),1.4,true)
	var drop := PackedVector2Array()
	for xy: Vector2 in [Vector2(0,-9),Vector2(2,-5),Vector2(5,-1),Vector2(6,2),Vector2(5.7,5),Vector2(4.5,7),Vector2(2,8.5),Vector2(0,9),Vector2(-2,8.5),Vector2(-4.5,7),Vector2(-5.7,5),Vector2(-6,2),Vector2(-5,-1),Vector2(-2,-5)]:
		drop.append(icon+xy)
	var fill: float = model.field.nectar_fill(flower)
	if fill >= 1.0:
		draw_colored_polygon(drop,gold)
	elif fill > .025:
		var top := icon.y+9.0-fill*18.0
		var fluid := PackedVector2Array([Vector2(icon.x-8,top),Vector2(icon.x+8,top),icon+Vector2(8,10),icon+Vector2(-8,10)])
		for liquid in Geometry2D.intersect_polygons(drop,fluid):
			if not Geometry2D.triangulate_polygon(liquid).is_empty(): draw_colored_polygon(liquid,gold)
	drop.append(drop[0])
	draw_polyline(drop,cream,1.5,true)
	if _flower_contact(flower):
		draw_arc(icon,radius+2.5,-PI/2,-PI/2+TAU*maxf(.01,float(flower.progress)),40,cream,3,true)
	if not cap.is_empty():
		var baseline := icon + Vector2(radius+5,6)
		draw_string_outline(feedback_font,baseline,cap,HORIZONTAL_ALIGNMENT_LEFT,-1,18,4,glass)
		draw_string(feedback_font,baseline,cap,HORIZONTAL_ALIGNMENT_LEFT,-1,18,cream)

func _draw_material_hint(item: Dictionary) -> void:
	var field = model.field
	var fiber := area_key=="pond"
	var at: Vector2 = item.p
	if item.dropped:
		var title := "飞近种绒 · 收 1 份纤维" if fiber else "树脂 · 飞近拾取"
		_region_label(at+Vector2(0,-32),title+" · 将散" if FieldLife.phase_ratio(item)>.70 else title,true)
		return
	if not FieldLife.available(item):
		var words := "种绒正在蓬松" if fiber else "裂口正在凝脂"
		if item.phase=="empty": words="空种壳 · 待长新绒" if fiber else "空树皮 · 待凝脂"
		_region_label(at+Vector2(0,-43),words,false)
		return
	if field.resin_open(item):
		var close_enough: bool = model.p.distance_to(at)<=field.RESIN_REACH
		var message := "贴近裂口收树脂"
		if close_enough: message = "按住 E / 左键 · 收树脂"
		if item.phase=="fading" and FieldLife.phase_ratio(item)>.60: message += " · 将干"
		_region_label(at+Vector2(0,-48),message,true)
		var fill: float = float(item.get("resin_draw",0.0))/field.RESIN_SECONDS
		if field.drawing_resin_id==item.id:
			var contact: Vector2 = model.p+Vector2(0,6)
			var strand_start := at+Vector2(0,6)
			_curve(strand_start,strand_start.lerp(contact,.35)+Vector2(0,5),strand_start.lerp(contact,.72)+Vector2(0,3),contact,Color("d7a34b"),1.5)
		if fill>0:
			draw_arc(at,20,-PI*.5,-PI*.5+TAU*fill,36,Color("f5bc62"),3,true)
		return
	var total: int = field.shell_strength(item)
	var hits: int = item.hits
	if total>1:
		for i in total:
			draw_circle(at+Vector2(float(i)*11.0-5.5,-24),3.0,Color("b6a580") if i<hits else Color("ffdd90"))
	var action := "振松种绒取纤维" if fiber else "掀松树皮"
	if hits>0: action="再振落绒" if fiber else "再振开皮"
	_region_label(at+Vector2(0,-48),"朝向种穗 Q · "+action if fiber else "朝向裂口 Q · "+action,true)

func _draw_region_effects() -> void:
	for ring in pulse_rings:
		var t: float = ring.age/.4
		var axis: Vector2 = (ring.to-ring.p).normalized()
		var front: Vector2 = ring.p.lerp(ring.to,minf(t/.45,1))
		for lane in [-1,0,1]:
			var side: Vector2 = axis.orthogonal()*float(lane)*10
			draw_line(front-axis*24+side,front+side*.65,Color(1,.95,.74,(1-t)*(.25 if ring.empty else .75)),2,true)
	var pose := _field_bee_pose()
	var pocket := _bag_position(pose.p,pose.face,pose.size)
	for mote in nectar_motes:
		if mote.age < 0: continue
		var t: float = clampf(mote.age/mote.duration,0,1)
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

# A dark backing keeps the return action legible against both water and sunlit grass.
func _return_badge(at: Vector2, words: String, direction := Vector2.ZERO) -> void:
	if feedback_font == null: return
	var has_arrow := not direction.is_zero_approx()
	var width := feedback_font.get_string_size(words,HORIZONTAL_ALIGNMENT_LEFT,-1,19).x
	var arrow_space := 27.0 if has_arrow else 0.0
	var half_span := (width + arrow_space) * 0.5
	var paper := Color("493924")
	draw_rect(Rect2(at-Vector2(half_span,16),Vector2(half_span*2,32)),paper)
	for x in [-half_span,half_span]:
		draw_circle(at+Vector2(x,0),16,paper,true,-1,true)
	var left := at - Vector2(half_span,0)
	if has_arrow:
		var centre := left + Vector2(6,0)
		var strength := 1.0 if reduced_motion else (1.0+cos(model.field.elapsed*TAU/EnergyDial.PULSE_SECONDS))*.5
		draw_circle(centre,11,Color("cc783d").lerp(Color("ffe29a"),strength),true,-1,true)
		var side := direction.orthogonal()
		draw_polyline(PackedVector2Array([centre-direction*4-side*5,centre+direction*5,centre-direction*4+side*5]),paper,2.8,true)
	draw_string(feedback_font,left+Vector2(arrow_space,6),words,HORIZONTAL_ALIGNMENT_LEFT,-1,19,Color("fff0c7"))

func _draw_home_bearing() -> void:
	var entry: Vector2 = model.field.layout.nodes[0].p
	var direction: Vector2 = (entry-model.p).normalized()
	if model.energy_is_low():
		if model.field.at_entry(): return
		var bee: Vector2 = (model.p - model.camera_offset) * MeadowLayout.FIELD_ZOOM
		var badge_at := (bee + Vector2(0,-64)).clamp(Vector2(110,26),get_viewport_rect().size-Vector2(110,26))
		_return_badge(badge_at,"体力低 · 回庭院",direction)
		return
	if model.p.distance_to(entry)<330 and _full_glow <= 0: return
	var at := get_viewport_rect().size-Vector2(112,50)
	var side := direction.orthogonal()
	var centre := at-Vector2(48,0)
	if _full_glow > 0:
		var alpha := minf(_full_glow*3,1)
		draw_circle(centre,13,Color("5b512e",alpha*.9),true,-1,true)
		draw_arc(centre,13,0,TAU,28,Color("f9d979",alpha),2,true)
	draw_polyline(PackedVector2Array([centre-direction*5-side*5,centre+direction*6,centre-direction*5+side*5]),Color("f5df9f"),2.5,true)
	_region_label(at+Vector2(5,0),"回庭院",false)
