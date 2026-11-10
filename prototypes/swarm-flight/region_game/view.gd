extends "res://nectar_harvest_view.gd"
## Painted presentation for the fixed collecting grounds. No simulation writes.
## The turf edge is the same union of capsules/discs used by field collision.
const FieldLayout = preload("res://region_greybox/layout.gd")
const FieldLife = preload("res://region_greybox/model.gd")
const GROUND_TILE: Texture2D = preload("res://art/region-ground.png")
const WATER_TILE: Texture2D = preload("res://art/region-water.png")
const TURF_SHADER := """shader_type canvas_item;
render_mode unshaded;
uniform vec4 ground_tint : source_color = vec4(1.0);
uniform float opacity = 1.0;
uniform float flow = 0.0;
varying vec2 ground_point;
void vertex() { ground_point = VERTEX; }
void fragment() {
    // Purpose-made object-free material tiles; one normal repeat every 512px.
    vec2 uv = ground_point / 512.0 + vec2(flow,flow*0.21);
    vec3 paint = texture(TEXTURE,uv).rgb;
    COLOR = vec4(paint * ground_tint.rgb, opacity);
}
"""
var _field_key := ""
var _coast: PackedVector2Array = []
var _turf: Polygon2D
var _outside: Polygon2D
var _soft_banks: Array[Polygon2D] = []
var _shore_plants: Array[Dictionary] = []
var _grass_marks: Array[Dictionary] = []
var _life_motes: Array[Dictionary] = []
var _material_recoil := {}

func _ready() -> void:
	super._ready()
	if feedback_font == null:
		var face_font := SystemFont.new()
		face_font.font_names = PackedStringArray(["PingFang SC", "Noto Sans CJK SC", "sans-serif"])
		feedback_font = face_font

func _process(delta: float) -> void:
	super._process(delta)
	if not presentation_active: return
	for mote in _life_motes: mote.age += delta
	_life_motes = _life_motes.filter(func(m: Dictionary) -> bool: return float(m.age) < float(m.duration))
	for id in _material_recoil:
		_material_recoil[id] = maxf(0.0, float(_material_recoil[id]) - delta)

func nectar_event(event: Dictionary) -> void:
	var kind := str(event.get("kind", ""))
	if area_key == "hub":
		super.nectar_event(event)
		return
	var item: Dictionary = {}
	var id := int(event.get("id", event.get("amount", -1)))
	var material := kind.begins_with("material_")
	if model != null and model.field != null and id >= 0:
		var list: Array = model.field.materials if material else model.field.flowers
		if id < list.size(): item = list[id]
	if kind == "material_hit": _material_recoil[id] = 0.24
	if kind == "pulse" and model != null and model.field != null:
		var target: Vector2 = event.get("to", model.p)
		for candidate in model.field.materials:
			if candidate.p.distance_to(target)<8: _material_recoil[int(candidate.id)] = 0.24
	if not item.is_empty() and (kind.ends_with("_bud") or kind.ends_with("_ripe") or kind.ends_with("_fading") or kind.ends_with("_empty")):
		_life_motes.append({"p":item.p,"age":0.0,"duration":0.9,
			"fall":kind.ends_with("_fading") or kind.ends_with("_empty"),
			"color":Color("c39a67") if kind.ends_with("_empty") else Color("e3c87c") if kind.ends_with("_fading") else Color("dcebb5")})
	# The controller converts collection/pulse events to the existing feedback contract.
	if kind in ["harvest", "material", "pulse", "pulse_empty", "buy", "unlock", "complete"]:
		super.nectar_event(event)

func _circle_polygon(at: Vector2, radius: float, count := 64) -> PackedVector2Array:
	var result := PackedVector2Array()
	for i in count: result.append(at + Vector2.from_angle(TAU * float(i) / float(count)) * radius)
	return result

func _capsule_polygon(a: Vector2, b: Vector2, radius: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	var angle := (b - a).angle()
	for i in 33: result.append(b + Vector2.from_angle(angle - PI * .5 + PI * float(i) / 32.0) * radius)
	for i in 33: result.append(a + Vector2.from_angle(angle + PI * .5 + PI * float(i) / 32.0) * radius)
	return result

func _prepare_field() -> void:
	var field = model.field
	if _field_key == str(field.region): return
	_field_key = str(field.region)
	var shapes: Array[PackedVector2Array] = []
	# Merge the connected tree in edge order; visual triangulation never changes collision.
	for i in field.layout.paths.size():
		var path: PackedVector2Array = field.layout.paths[i]
		shapes.append(_capsule_polygon(path[0], path[1], float(field.layout.path_radii[i])))
	for node in field.layout.nodes: shapes.append(_circle_polygon(node.p, float(node.radius)))
	_coast = shapes[0]
	for i in range(1, shapes.size()):
		var merged: Array[PackedVector2Array] = Geometry2D.merge_polygons(_coast, shapes[i])
		if not merged.is_empty(): _coast = merged[0]
	if not is_instance_valid(_outside):
		_outside = Polygon2D.new()
		_outside.z_index = -3
		_outside.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		_outside.polygon = PackedVector2Array([Vector2(-6000,-6000),Vector2(8000,-6000),Vector2(8000,8000),Vector2(-6000,8000)])
		add_child(_outside)
	if not is_instance_valid(_turf):
		_turf = Polygon2D.new()
		_turf.z_index = -1
		_turf.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		_turf.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		add_child(_turf)
	var pond := _field_key == "pond"
	_outside.color = Color.WHITE
	_turf.polygon = _coast
	_turf.texture = GROUND_TILE
	var shader := Shader.new()
	shader.code = TURF_SHADER
	var paint := ShaderMaterial.new()
	paint.shader = shader
	paint.set_shader_parameter("ground_tint", Color.WHITE if pond else Color("e2ebef"))
	_turf.material = paint
	for bank in _soft_banks: bank.queue_free()
	_soft_banks.clear()
	for width in [18.0,11.0,5.0]:
		var outlines := Geometry2D.offset_polygon(_coast,width,Geometry2D.JOIN_ROUND)
		if outlines.is_empty(): continue
		var bank := Polygon2D.new()
		bank.z_index = -2
		bank.polygon = outlines[0]
		bank.texture = _turf.texture
		bank.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		var bank_paint: ShaderMaterial = paint.duplicate()
		bank_paint.set_shader_parameter("opacity",.20 if width>15 else .35 if width>8 else .60)
		bank_paint.set_shader_parameter("ground_tint",Color("a99e68") if pond else Color("6b8353"))
		bank.material = bank_paint
		add_child(bank)
		_soft_banks.append(bank)
	_outside.texture = WATER_TILE if pond else GROUND_TILE
	var outside_paint := ShaderMaterial.new()
	outside_paint.shader = shader
	outside_paint.set_shader_parameter("ground_tint",Color.WHITE if pond else Color("597757"))
	_outside.material = outside_paint
	_shore_plants.clear()
	_grass_marks.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 349001 if pond else 349002
	# Roots sit in actual bank soil; leaves may overhang the water, roots may not.
	for i in _coast.size():
		var a: Vector2 = _coast[i]
		var b: Vector2 = _coast[(i+1)%_coast.size()]
		var normal := (b-a).normalized().orthogonal()
		if FieldLayout.walkable(field.layout, (a+b)*.5+normal*10, 0): normal = -normal
		var count := maxi(1, int(a.distance_to(b)/62))
		for j in count:
			var at := a.lerp(b,(float(j)+.5)/float(count))
			if rng.randf() < .62:
				_shore_plants.append({"p":at-normal*25-Vector2(0,9),"normal":normal,"size":rng.randf_range(.75,1.3),"kind":rng.randi_range(0,4)})
	for i in 240:
		var bounds: Rect2 = field.layout.bounds
		var at := bounds.position + Vector2(rng.randf()*bounds.size.x,rng.randf()*bounds.size.y)
		if FieldLayout.walkable(field.layout,at,42):
			_grass_marks.append({"p":at,"turn":rng.randf_range(-.6,.6),"size":rng.randf_range(.6,1.25)})

func _visible(at: Vector2, padding := 130.0) -> bool:
	return Rect2(model.camera_offset-Vector2.ONE*padding,get_viewport_rect().size+Vector2.ONE*padding*2).has_point(at)

func _draw() -> void:
	if model == null: return
	if area_key == "hub":
		if is_instance_valid(_turf): _turf.visible = false
		if is_instance_valid(_outside): _outside.visible = false
		for bank in _soft_banks: bank.visible = false
		super._draw()
		return
	if model.field == null: return
	_prepare_field()
	_world_offset = -model.camera_offset
	_turf.visible = true
	_outside.visible = true
	_turf.position = _world_offset
	_outside.position = _world_offset
	for bank in _soft_banks:
		bank.visible = true
		bank.position = _world_offset
	if area_key == "pond": _outside.material.set_shader_parameter("flow",0.0 if reduced_motion else clock*.0015)
	draw_set_transform(_world_offset)
	_draw_region_floor()
	var actors: Array[Dictionary] = []
	for plant in _shore_plants:
		if _visible(plant.p): actors.append({"kind":"shore","y":plant.p.y,"data":plant})
	for flower in model.field.flowers:
		if _visible(flower.p):
			_ground_shadow(_resource_root(flower),Vector2(18,5),.13)
			actors.append({"kind":"flower","y":_resource_root(flower).y,"data":flower})
	for item in model.field.materials:
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
			"shore": _draw_shore_plant(actor.data)
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

func _draw_region_floor() -> void:
	var pond := area_key == "pond"
	for mark in _grass_marks:
		var at: Vector2 = mark.p
		if not _visible(at,20): continue
		var tone := Color(.87,.87,.52,.24) if pond else Color(.73,.80,.57,.24)
		for blade in 3:
			var root := at+Vector2(float(blade-1)*4,0)
			_curve(root,root+Vector2(-2,-4),root+Vector2(-6+blade*4,-8),root+Vector2(-7+blade*5,-11)*float(mark.size),tone,1.5)
	# Quiet water and floor marks lie outside the collecting surface only.
	for i in 34:
		var at := Vector2(-50+float(i%9)*310,180+float(i/9)*330)
		if not _visible(at,120) or FieldLayout.walkable(model.field.layout,at,-45): continue
		if pond:
			var drift := 0.0 if reduced_motion else sin(clock*.55+float(i)) * 9
			_curve(at+Vector2(-65,drift),at+Vector2(-25,-5+drift),at+Vector2(24,5+drift),at+Vector2(68,drift),Color(.79,.91,.77,.21),2)
			if i%3 == 0:
				ArtSprites.small_leaf(self,at+Vector2(20,20),at+Vector2(-38,19),23)
		else:
			_ellipse(at,Vector2(100,42),Color(.16,.27,.20,.22))
	_draw_distant_landmarks()

func _draw_distant_landmarks() -> void:
	# Rooted silhouettes make near/middle/far readable without inventing a route.
	var nodes: Array = model.field.layout.nodes
	for index in [1,2,3]:
		# The meadow's short pocket goes north of its middle node; keep its
		# landmark on the opposite bank so it cannot look like a blocked branch.
		var bank := 340.0 if area_key == "meadow" and index == 2 else -315.0
		var at: Vector2 = nodes[index].p+Vector2(10,bank)
		if not _visible(at,210): continue
		if area_key == "pond":
			if index == 3:
				var source := ArtProps.FOUNTAIN
				draw_texture_rect_region(ArtProps.FLORA,Rect2(at-Vector2(60,85),Vector2(120,112)),source,Color(.70,.79,.68))
			else:
				for j in 5+index*2:
					var foot := at+Vector2(float(j)*16-50,30+sin(float(j))*7)
					var tip := foot+Vector2(sin(float(j))*14,-70-float(j%3)*22)
					_curve(foot,foot+Vector2(0,-30),tip+Vector2(-6,15),tip,Color("6f8950"),3)
					ArtSprites.small_leaf(self,foot+Vector2(0,-25),foot+Vector2(28,-48),9)
		else:
			var span := Vector2(180+index*35,100+index*15)
			draw_texture_rect_region(THICKET,Rect2(at-Vector2(span.x*.5,span.y-25),span),Rect2(45,45,1680,755),Color(.76,.82,.84))
			# Violet edge leaves form a distinct cool canopy, with roots outside the path.
			for j in 3:
				var foot := at+Vector2(float(j-1)*39,20)
				ArtSprites.small_leaf(self,foot,foot+Vector2(-32,-42-float(j)*10),24)

func _draw_shore_plant(plant: Dictionary) -> void:
	var at: Vector2 = plant.p
	var scale: float = plant.size
	var alpha := .32 if model.p.distance_to(at) < 85 else .82
	if int(plant.kind) == 4:
		# Small bank stones sit partly in the soil and mark the soft shoreline.
		var stone := PackedVector2Array([at+Vector2(-19,5),at+Vector2(-16,-6),at+Vector2(-5,-12),at+Vector2(12,-9),at+Vector2(21,2),at+Vector2(12,8)])
		_ground_shadow(at+Vector2(0,7),Vector2(23,6),.13)
		draw_colored_polygon(stone,Color("a3a17a") if area_key == "pond" else Color("969a83"))
		draw_polyline(PackedVector2Array([at+Vector2(-15,-5),at+Vector2(-5,-10),at+Vector2(11,-7)]),Color("dad0a1"),2,true)
	elif int(plant.kind) == 0:
		var span := Vector2(116,62)*scale
		draw_texture_rect_region(THICKET,Rect2(at-Vector2(span.x*.5,span.y-8),span),Rect2(45,45,1680,755),Color(.86,.90,.76,alpha))
	else:
		var root := at+Vector2(0,9)
		_ground_shadow(root,Vector2(21,5),.13)
		for leaf in 3:
			var tip := root+Vector2(float(leaf-1)*29,-22-float(leaf%2)*19)*scale
			ArtSprites.small_leaf(self,root,tip,13*scale)

func _resource_root(flower: Dictionary) -> Vector2:
	var id := int(flower.id)
	return flower.p+Vector2((30 if area_key == "meadow" else 0)+float(id%3-1)*5,37+float(id%4)*6)

func _flower_visual_point(flower: Dictionary) -> Vector2:
	var at: Vector2 = flower.p
	if not reduced_motion and flower.phase != "empty":
		at += Vector2(sin(clock*1.5+float(flower.id)*.7)*1.5,0)
	return at

func _draw_living_flower(flower: Dictionary) -> void:
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
	var join := at+Vector2(30,15) if purple else at+Vector2(0,14)
	if phase == "bud": join = root.lerp(join,.48+ratio*.52)
	if phase == "fading": join += Vector2(3,ratio*8)
	var bend := Vector2((4.0+float(int(flower.id)%3)*2.0)*(-1 if int(flower.id)%2 == 0 else 1),0)
	var neck := join.lerp(root,.33)+bend
	var lower := join.lerp(root,.70)+bend*.65
	# Monotonic controls keep a short bud stem from folding through itself.
	ArtProps.stalk(self,join,neck,lower,root,3.2)
	for t in [.50,.78]:
		var petiole: Vector2 = join.bezier_interpolate(neck,lower,root,t)
		ArtSprites.small_leaf(self,petiole,petiole+Vector2(-21 if t<.6 else 20,-10),8)
	ArtSprites.small_leaf(self,root,root+Vector2(-23,-7),10)
	ArtSprites.small_leaf(self,root,root+Vector2(17,-12),9)
	var tint := Color("b8c58c") if phase == "bud" else Color.WHITE.lerp(Color("b6a483"),ratio*.72) if phase == "fading" else Color.WHITE
	if model.p.y+33 < root.y and model.p.distance_to(at) < 65: tint.a = .58
	var working: bool = int(flower.id) in model.field._locked
	var tug := sin(clock*23)*.022 if working and not reduced_motion else 0.0
	var head_size := .84+float(int(flower.id)%5)*.065
	draw_set_transform(_world_offset+join,tug,Vector2(opening,.70+opening*.30)*head_size)
	if purple:
		var source := ArtProps.SNEEZE
		var pivot := Vector2(771,431)
		draw_texture_rect_region(ArtProps.FLORA,Rect2(Vector2(-30,-15)+(source.position-pivot)*.135,source.size*.135),source,tint)
	else:
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
	var root: Vector2 = item.anchor+Vector2(0,47)
	var at: Vector2 = item.p
	var phase := str(item.phase)
	var ratio := FieldLife.phase_ratio(item)
	var kind := "fiber" if area_key == "pond" else "resin"
	if bool(item.dropped):
		var fall := clampf(float(item.phase_time)/.35,0,1)
		var lift := sin(fall*PI)*17
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
	if collecting and not field._locked.is_empty():
		var flower: Dictionary = field.flowers[int(field._locked[0])]
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
		var q: Vector2 = mote.from.lerp(model.p+Vector2(-7,7),t*t)
		if mote.has("material"): UIArt.icon(self,mote.material,q,9*(1-t*.5))
		else: draw_circle(q,3.1*(1-t*.35),Color("ffe9a1") if mote.gold else Color("d8f2df"))
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
	if model.p.distance_to(entry)<330: return
	var at := get_viewport_rect().size-Vector2(112,50)
	var direction: Vector2 = (entry-model.p).normalized()
	var side := direction.orthogonal()
	var centre := at-Vector2(48,0)
	draw_polyline(PackedVector2Array([centre-direction*5-side*5,centre+direction*6,centre-direction*5+side*5]),Color("f5df9f"),2.5,true)
	_region_label(at+Vector2(5,0),"回庭院",false)
