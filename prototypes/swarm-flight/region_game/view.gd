extends "res://nectar_harvest_view.gd"
## The terrain plates are registered to the same world coordinates as the
## field coast. Leaf tips, reflections and dappled light move within their
## original paint. Roots, shores, interaction points and buildings stay fixed.
const CourtyardStations = preload("res://region_game/courtyard_stations.gd")
const COURTYARD_PLATE: Texture2D = preload("res://art/honey-inner-courtyard.webp")
const BasinVisitor = preload("res://region_game/basin_visitor.gd")
const EnergyDial = preload("res://nectar_energy_dial.gd")
const FieldLife = preload("res://region_greybox/model.gd")
const FieldLayout = preload("res://region_greybox/layout.gd")
const POND_PLATE: Texture2D = preload("res://art/collection-pond.webp")
const MEADOW_PLATE: Texture2D = preload("res://art/collection-meadow.webp")
const MeadowLayout = preload("res://region_game/layout.gd")
const PLATE_RECT := MeadowLayout.PLATE
const Keycaps = preload("res://region_game/wax_keycaps.gd")
const FieldNotesStyle = preload("res://region_game/field_notes_style.gd")
const FIELD_PAPER := Color("39483ef5")
const FIELD_INK := Color("fff2d5")
const FIELD_MUTED_INK := Color("e0e2cb")
const FIELD_TEXT_SIZE := 20
const FIELD_NOTE_SIZE := 18
const PICKUP_FONT_SIZE := 21
const FIELD_SIGN = preload("res://art/collection-home-sign.webp")
const BEE_FOOT := Vector2(0,25)
const SIGN_FOOT := Vector2(-67,24)
const POND_BLOOM: Texture2D = preload("res://art/collection-blue-bloom.webp")
const MEADOW_BLOOM: Texture2D = preload("res://art/collection-violet-bloom.webp")
const PLATE_SHADER = preload("res://region_game/painted_plate.gdshader")
const DEPTH_MAPS := {
	"hub": preload("res://region_game/hub_depth.svg"),
	"pond": preload("res://region_game/pond_depth.svg"),
	"meadow": preload("res://region_game/meadow_depth.svg"),
}
const SURFACE_SHADER = preload("res://region_game/painted_surface.gdshader")
const CROWN_SHADER = preload("res://region_game/painted_crown.gdshader")
# Crown bounds on a 700 × 405 registration proof of each complete illustration.
# These are the visible fronds, willow, bulrush and arch leaves already in
# the picture. Standing stems and hanging branches have opposite attachments.
const PROOF_SIZE := Vector2(700,405)
const POND_CROWNS := [
	Rect2(104,113,49,36), Rect2(302,121,50,38), Rect2(344,225,46,98),
	Rect2(549,0,77,76), Rect2(0,274,109,109), Rect2(580,244,120,129),
]
const MEADOW_CROWNS := [
	Rect2(11,205,45,33), Rect2(193,152,46,28), Rect2(231,0,84,40),
	Rect2(499,130,53,40), Rect2(75,276,72,36), Rect2(228,283,140,91),
	Rect2(575,289,116,75),
]
# Regions are measured on the full illustrations. Surface masks stay inside
# painted water or sunlit ground, clear of the shore, buildings and stations.
const HUB_PROOF := Vector2(700,438)
const HUB_CROWNS := [
	Rect2(0,100,43,67), Rect2(19,269,41,56), Rect2(532,247,120,68),
	Rect2(622,386,78,52), Rect2(5,390,86,48),
]
const POND_REFLECTIONS := [
	Rect2(45,41,169,56), Rect2(204,45,186,46), Rect2(399,44,136,54),
	Rect2(77,272,154,69), Rect2(440,299,124,59),
]
const HUB_LIGHT := [Rect2(116,352,133,53), Rect2(596,147,86,52)]
const MEADOW_LIGHT := [
	Rect2(39,171,104,43), Rect2(172,173,126,52), Rect2(546,172,74,50),
]
var station_entry := ""
var station_progress := 0.0
var shop_cat_elapsed := CourtyardStations.CAT_SETTLED
var _sale_at_counter := false
var basin_visitor: Sprite2D
var _paint_root: Node2D
var _painted_area := ""
var _crowns: Array[Dictionary] = []
var _surfaces: Array[Sprite2D] = []
var _life_motes: Array[Dictionary] = []
var _material_recoil := {}
var _full_glow := 0.0
var prompt_surface := StyleBoxFlat.new()
var prompt_screen := Rect2()
var _field_note_bounds: Array[Rect2] = []

func _ready() -> void:
	super._ready()
	prompt_surface.set_corner_radius_all(14)
	prompt_surface.set_border_width_all(2)
	prompt_surface.border_color = Color("d9bf8d")
	prompt_surface.shadow_color = Color("433a2bd0")
	prompt_surface.shadow_size = 2
	prompt_surface.shadow_offset = Vector2(0,2)
	if area_key == "hub":
		basin_visitor = BasinVisitor.new()
		add_child(basin_visitor)
		basin_visitor.pose(0.0, reduced_motion)
	if feedback_font == null:
		var face_font := SystemFont.new()
		face_font.font_names = PackedStringArray(["PingFang SC", "Noto Sans CJK SC", "sans-serif"])
		feedback_font = face_font

func _process(delta: float) -> void:
	super._process(delta)
	if basin_visitor != null:
		basin_visitor.pose(clock, reduced_motion)
	if not presentation_active: return
	if shop_cat_elapsed < CourtyardStations.CAT_SETTLED:
		if station_entry.is_empty():
			shop_cat_elapsed = minf(shop_cat_elapsed + delta, CourtyardStations.CAT_SETTLED)
		else:
			shop_cat_elapsed = CourtyardStations.CAT_SETTLED
	_full_glow = maxf(0.0,_full_glow-delta)
	for mote in _life_motes: mote.age += delta
	_life_motes = _life_motes.filter(func(m: Dictionary) -> bool: return float(m.age) < float(m.duration))
	for id in _material_recoil:
		_material_recoil[id] = maxf(0.0, float(_material_recoil[id]) - delta)

func leave_shop_counter() -> void:
	shop_cat_elapsed = 0.0 if _sale_at_counter else CourtyardStations.CAT_SETTLED
	_sale_at_counter = false

func nectar_event(event: Dictionary) -> void:
	var kind := str(event.get("kind", ""))
	if area_key == "hub":
		if kind == "sell": _sale_at_counter = true
		super.nectar_event(event)
		return
	if kind in ["harvest", "material"]:
		_show_pickup(event)
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
	if kind in ["pulse", "pulse_empty", "buy", "unlock", "complete"]:
		super.nectar_event(event)

func _show_pickup(event: Dictionary) -> void:
	super.nectar_event(event)
	var label := harvest_texts[-1]
	label.text = "%s +%d" % [FieldNotesStyle.PICKUP_NAMES[event.type], event.amount]
	label.color = FieldNotesStyle.PICKUP_COLORS[event.type]
	if event.kind == "harvest":
		var mote := nectar_motes[-1]
		mote.from = event.pos
		mote.color = label.color

func _prepare_paint() -> void:
	if _painted_area == area_key: return
	_painted_area = area_key
	if is_instance_valid(_paint_root):
		remove_child(_paint_root)
		_paint_root.queue_free()
	_crowns.clear()
	_paint_root = Node2D.new()
	add_child(_paint_root)
	var home := area_key == "hub"
	var texture := COURTYARD_PLATE if home else (POND_PLATE if area_key == "pond" else MEADOW_PLATE)
	var frame := Rect2(Vector2.ZERO, MeadowLayout.VIEWPORT) if home else PLATE_RECT
	var proof_size := HUB_PROOF if home else PROOF_SIZE
	var picture := Sprite2D.new()
	picture.texture = texture
	picture.centered = false
	picture.position = frame.position
	picture.scale = frame.size/texture.get_size()
	picture.z_index = -2
	picture.material = _paint_material(PLATE_SHADER, texture)
	_paint_root.add_child(picture)
	var placements := HUB_CROWNS if home else (POND_CROWNS if area_key == "pond" else MEADOW_CROWNS)
	for proof: Rect2 in placements:
		var uv := Rect2(proof.position/proof_size, proof.size/proof_size)
		var back := _paint_patch(texture, uv, frame, CROWN_SHADER)
		var hangs := (home and proof == HUB_CROWNS[0]) or (area_key == "pond" and proof == POND_CROWNS[3]) or (area_key == "meadow" and proof == MEADOW_CROWNS[2])
		back.material.set_shader_parameter("hanging", hangs)
		var front: Sprite2D
		if not home:
			front = _paint_patch(texture, uv, frame, CROWN_SHADER)
			front.z_index = 1
			front.material.set_shader_parameter("foreground", true)
			front.material.set_shader_parameter("hanging", hangs)
		_crowns.append({"rect":Rect2(back.position, uv.size*frame.size), "back":back, "front":front})
	_surfaces.clear()
	var water := area_key == "pond"
	var surfaces := POND_REFLECTIONS if water else (HUB_LIGHT if home else MEADOW_LIGHT)
	for proof: Rect2 in surfaces:
		var uv := Rect2(proof.position/proof_size, proof.size/proof_size)
		var patch := _paint_patch(texture, uv, frame, SURFACE_SHADER)
		patch.material.set_shader_parameter("water", water)
		_surfaces.append(patch)

func _paint_material(shader: Shader, texture: Texture2D) -> ShaderMaterial:
	var paint := ShaderMaterial.new()
	paint.shader = shader
	paint.set_shader_parameter("plate_art", texture)
	paint.set_shader_parameter("depth_map", DEPTH_MAPS[area_key])
	return paint

func _paint_patch(texture: Texture2D, uv: Rect2, frame: Rect2, shader: Shader) -> Sprite2D:
	var patch := Sprite2D.new()
	patch.texture = texture
	patch.centered = false
	patch.region_enabled = true
	patch.region_rect = Rect2(uv.position*texture.get_size(), uv.size*texture.get_size())
	patch.scale = frame.size/texture.get_size()
	patch.position = frame.position+uv.position*frame.size
	patch.z_index = -1
	var paint := _paint_material(shader, texture)
	paint.set_shader_parameter("center_uv", uv.get_center())
	paint.set_shader_parameter("radii_uv", uv.size*.5)
	paint.set_shader_parameter("world_size", frame.size)
	patch.material = paint
	_paint_root.add_child(patch)
	return patch

func _canopy_offset(rect: Rect2) -> Vector2:
	if reduced_motion: return Vector2.ZERO
	var at := rect.get_center()
	# A travelling gust leads into a smaller, quicker rustle at exposed tips.
	var phase := at.x*.003 + at.y*.0017
	var gust := sin(clock*1.34-phase) * (.71 + .29*sin(clock*.68-phase*.48))
	var rustle := sin(clock*2.43-phase*1.7)
	var reach := clampf(rect.size.y*.041, 2.1, 11.5)
	var breeze := Vector2(gust+.28*rustle, .19*rustle) * reach
	if area_key == "hub": return breeze
	var half_view := MeadowLayout.VIEWPORT/(2.0*MeadowLayout.FIELD_ZOOM)
	var eye: Vector2 = model.camera_offset+half_view
	var relative := ((at-eye)/half_view).clamp(-Vector2.ONE,Vector2.ONE)
	return breeze + relative*Vector2(minf(29.0,rect.size.x*.12),minf(13.0,rect.size.y*.06))

func _update_crowns() -> void:
	var home := area_key == "hub"
	var frame := Rect2(Vector2.ZERO, MeadowLayout.VIEWPORT) if home else PLATE_RECT
	var visible_world := frame if home else Rect2(model.camera_offset,get_viewport_rect().size/MeadowLayout.FIELD_ZOOM)
	for crown in _crowns:
		var rect: Rect2 = crown.rect
		var back: Sprite2D = crown.back
		var front: Sprite2D = crown.front
		back.visible = visible_world.intersects(rect)
		if front:
			front.visible = back.visible and model.p.y+BEE_FOOT.y<rect.end.y and rect.grow(55).has_point(model.p)
		if not back.visible: continue
		var shift := _canopy_offset(rect)/frame.size
		back.material.set_shader_parameter("shift_uv",shift)
		if front and front.visible:
			front.material.set_shader_parameter("shift_uv",shift)
			front.material.set_shader_parameter("player_uv",(model.p-frame.position)/frame.size)
	for surface in _surfaces:
		surface.visible = not reduced_motion and visible_world.intersects(Rect2(surface.position, surface.region_rect.size*surface.scale))
		if surface.visible:
			surface.material.set_shader_parameter("seconds", clock)

func _draw_background() -> void:
	_prepare_paint()
	_update_crowns()

func _visible(at: Vector2, padding := 130.0) -> bool:
	return Rect2(model.camera_offset-Vector2.ONE*padding,get_viewport_rect().size/scale+Vector2.ONE*padding*2).has_point(at)

func _draw() -> void:
	if model == null: return
	if area_key == "hub":
		_frame_station()
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
	_bee_shadow(model.p+BEE_FOOT,Vector2(16,5))
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
	prompt_screen = Rect2()
	_field_note_bounds.clear()
	_draw_resource_feedback()
	_draw_region_effects()
	if model.p.distance_to(entry) < 240.0:
		var label_at: Vector2 = entry + SIGN_FOOT + Vector2(0,-132)
		if model.field.at_entry():
			_field_note(label_at, "%s  回庭院" % _action_hint("interact"), true,0,false,"interact")
		else:
			_field_note(label_at,"庭院入口",false)
	draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE/MeadowLayout.FIELD_ZOOM)
	_draw_home_bearing()
	_draw_pickup_labels()

func _frame_station() -> void:
	var zoom := 1.0
	var focus := Vector2.ZERO
	var framing := Vector2.ZERO
	if not reduced_motion:
		if station_entry == "tree":
			var travel := smoothstep(.41,1.0,station_progress)
			zoom += travel*1.47
			focus = Vector2(786,407)
			framing = (Vector2(640,400)-focus)*travel
		elif station_entry == "shop":
			var approach := smoothstep(.02,.38,station_progress)
			zoom += .22*approach
			focus = Vector2(288,449)
	scale = Vector2.ONE*zoom
	position = focus*(1.0-zoom)+framing

func _draw_hub() -> void:
	var shop_entry := station_entry == "shop"
	var shop_t := station_progress if shop_entry else 0.0
	var sheet_t := station_progress if station_entry == "tree" else 0.0
	var swing := CourtyardStations.cat_swing(shop_cat_elapsed, reduced_motion)
	CourtyardStations.steelyard(self, shop_t, shop_entry, swing)
	CourtyardStations.shop_cat(self, shop_cat_elapsed, shop_t, reduced_motion)
	CourtyardStations.sheet(self,model.last_region == "meadow",sheet_t)
	# The counter's front shelf fills with sealed jars as the player sells.
	var jars := mini(6,floori(float(model.sold_total)/6))
	for i in jars:
		CourtyardStations.goods(self,CourtyardStations.JAR,Vector2(212+i*29,354),.62)
	if model.completed:
		var reserve := Vector2(503,500)
		_ground_shadow(reserve,Vector2(39,8),.20)
		for i in 3:
			var foot := reserve+Vector2((i-1)*24,abs(i-1)*3)
			CourtyardStations.goods(self,CourtyardStations.JAR,foot-Vector2(0,15),.89)
			UIArt.icon(self,"reserve",foot+Vector2(0,-13),5)
		if model.p.distance_to(reserve)<240: _label(reserve+Vector2(0,-61),"蜂巢储备已封好",false,190)
	var sees_cat := shop_cat_elapsed >= 1.06 and shop_cat_elapsed < CourtyardStations.CAT_SETTLED
	_bee(Vector2(452,437),.53,Vector2.LEFT if sees_cat else Vector2.RIGHT,1,false,1.7,"waiting")
	_bee(Vector2(913,473),.49,Vector2.LEFT,1,false,2.9,"waiting")
	if station_entry.is_empty():
		_bee_shadow(model.p+Vector2(0,35),Vector2(22,7))
	if not reduced_motion:
		var lamp := Vector2(1011,356)
		var glint := lamp+Vector2(sin(clock*.71)*26,cos(clock*.72)*26)
		draw_line(glint-Vector2(4,0),glint+Vector2(4,0),Color(1,.97,.78,.65),1.3,true)
		draw_line(glint-Vector2(0,4),glint+Vector2(0,4),Color(1,.97,.78,.65),1.3,true)
	if model.completed:
		for i in 3:
			var pose: Dictionary = Dance.pose(fposmod(clock+i*.12,1.4),"waggle",i)
			var base: Vector2 = model.HUB_DEPART+Vector2(-65+i*55,12)
			_bee(base+(Vector2.ZERO if reduced_motion else pose.offset),.62,Vector2.RIGHT,1,false,float(i),"greet")

func _draw_player() -> void:
	if station_entry.is_empty() or reduced_motion:
		super._draw_player()
		return
	var at := CourtyardStations.bee_position(station_entry,station_progress,model.p)
	var next := CourtyardStations.bee_position(station_entry,minf(1.0,station_progress+.015),model.p)
	var face := at.direction_to(next)
	if station_entry == "shop" and station_progress > .45: face = Vector2.RIGHT
	if face.is_zero_approx(): face = Vector2.LEFT
	var size := lerpf(1.0,.65,smoothstep(.05,.33,station_progress))
	if station_entry == "tree": size *= 1.0-.55*smoothstep(.65,.98,station_progress)
	_bee(at,size,face,1.0,false,0.0,"depart",0.0,model.energy_stage())
	_draw_bag_at(at,face,size)

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

const FIBER_SOCKET := MeadowLayout.FIBER_SOCKET
const FIBER_FOOT := Vector2(.65,.99)
const RESIN_SOCKET := Vector2(.50,.44)
const RESIN_FOOT := Vector2(.51,.98)

func _material_span(item: Dictionary) -> Vector2:
	var size := MeadowLayout.FIBER_SPAN if area_key == "pond" else RESIN_HOST.get_size()*(126.0/RESIN_HOST.get_width())
	return size*MeadowLayout.material_scale(item.band)

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
	_bee(pose.p,pose.size,pose.face,1.0,false,0.0,"leader",pose.push,model.energy_stage())

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

func _action_hint(action: String) -> String:
	var driver := get_parent()
	if driver != null and driver.has_method("control_hint"): return driver.control_hint(action)
	return "E / 左键" if action == "interact" else "Q / 右键"

func _nectar_caption(flower: Dictionary) -> String:
	if _flower_contact(flower): return "采蜜中"
	if flower.phase == "empty": return "花期已过"
	if flower.phase == "bud": return "花苞渐开"
	if flower.has("nectar_wait"): return "补蜜中" if flower.phase=="ripe" else "将谢 · 补蜜中"
	if model.field.cargo >= model.field.capacity(): return "蜜囊已满"
	return ("按住 %s  采蜜" if flower.phase == "ripe" else "花将谢 · 按住 %s  采蜜") % _action_hint("interact")

func _draw_nectar_status(flower: Dictionary, show_caption: bool) -> void:
	var cap: String = _nectar_caption(flower) if show_caption else ""
	var anchor: Vector2 = _flower_visual_point(flower) + Vector2(0,-94)
	if flower.phase in ["empty","bud"]:
		if show_caption: _field_note(anchor,cap,false)
		return
	var glass := Color("3d493b")
	var gold := Color("ffd175")
	var cream := Color("fff0bf")
	var radius := 16.0
	var icon := anchor
	if not cap.is_empty():
		var can_work: bool = int(flower.stock) > 0 and model.field.cargo < model.field.capacity()
		var tag := _field_note(anchor, cap, can_work, 42, false, "interact" if cap.contains("按住") else "")
		icon = Vector2(tag.position.x + 21, tag.get_center().y)
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

func _draw_material_hint(item: Dictionary) -> void:
	var field = model.field
	var fiber := area_key=="pond"
	var at: Vector2 = item.p
	if item.dropped:
		var title := "飞近收取 1 份纤维" if fiber else "飞近拾取树脂"
		_field_note(at+Vector2(0,-32),title+" · 将散" if FieldLife.phase_ratio(item)>.70 else title,true)
		return
	if not FieldLife.available(item):
		var words := "种绒正在蓬松" if fiber else "裂口正在凝脂"
		if item.phase=="empty": words="空种壳 · 待长新绒" if fiber else "空树皮 · 待凝脂"
		_field_note(at+Vector2(0,-43),words,false)
		return
	if field.resin_open(item):
		var close_enough: bool = model.p.distance_to(at)<=field.RESIN_REACH
		var message := "贴近裂口收树脂"
		if close_enough: message = "按住 %s  收树脂" % _action_hint("interact")
		if item.phase=="fading" and FieldLife.phase_ratio(item)>.60: message += " · 将干"
		_field_note(at+Vector2(0,-99),message,true,0,false,"interact" if close_enough else "")
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
	var action := "朝种穗振翅取绒" if fiber else "朝裂口振翅掀皮"
	if hits > 0: action = "再振一次落绒" if fiber else "再振一次开皮"
	_field_note(at + Vector2(0,-99), "%s  %s" % [_action_hint("pulse"), action], true,0,false,"pulse")

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
			draw_circle(q,radius,mote.get("color", Color("f7c655")),true,-1,true)
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

func pickup_label_layout() -> Array[Rect2]:
	var result: Array[Rect2] = []
	var occupied: Array[Rect2] = _field_note_bounds.duplicate()
	var bee_center: Vector2 = (model.p - model.camera_offset) * MeadowLayout.FIELD_ZOOM
	occupied.append(Rect2(bee_center - Vector2(24, 22), Vector2(48, 44)))
	var interface = get_parent().get("ui")
	if is_instance_valid(interface) and is_instance_valid(interface.get("field_hud")):
		occupied.append_array(interface.field_hud.pickup_obstacles())
	var safe := get_viewport_rect().grow(-6)
	for item in harvest_texts:
		var extent := feedback_font.get_string_size(item.text, HORIZONTAL_ALIGNMENT_LEFT, -1, PICKUP_FONT_SIZE).ceil() + Vector2(10, 12)
		var origin: Vector2 = (item.p - model.camera_offset) * MeadowLayout.FIELD_ZOOM
		var preferred := origin - Vector2(extent.x * .5, extent.y + 12)
		var box := _place_pickup_label(preferred, extent, safe, occupied)
		result.append(box)
		occupied.append(box.grow(3))
	return result

func _place_pickup_label(preferred: Vector2, extent: Vector2, safe: Rect2, occupied: Array[Rect2]) -> Rect2:
	var origin := preferred.round().clamp(safe.position, safe.end - extent)
	# A label can sit against either edge of a prompt or a previous pickup.
	var xs: Array[float] = [origin.x]
	var ys: Array[float] = [origin.y]
	for block in occupied:
		xs.append(block.position.x - extent.x)
		xs.append(block.end.x)
		ys.append(block.position.y - extent.y)
		ys.append(block.end.y)
	var best := Rect2(origin, extent)
	var best_score := INF
	for x in xs:
		for y in ys:
			var candidate := Rect2(Vector2(x, y).clamp(safe.position, safe.end - extent), extent)
			var delta := (candidate.position - origin) * Vector2(1.0, 2.7)
			var score := delta.length_squared()
			if score >= best_score: continue
			if occupied.any(func(block: Rect2) -> bool: return candidate.intersects(block)): continue
			if score == 0: return candidate
			best = candidate
			best_score = score
	return best

func _draw_pickup_labels() -> void:
	if harvest_texts.is_empty(): return
	var boxes := pickup_label_layout()
	for i in harvest_texts.size():
		var item := harvest_texts[i]
		var box := boxes[i]
		var ink: Color = item.color
		var baseline := box.position + Vector2(0, 5 + feedback_font.get_ascent(PICKUP_FONT_SIZE))
		if not reduced_motion:
			baseline.y += 4 * (1.0 - smoothstep(0.0, .22, item.age))
			ink.a = 1.0 - smoothstep(.72, 1.0, item.age)
		draw_string_outline(feedback_font, baseline, item.text, HORIZONTAL_ALIGNMENT_CENTER, box.size.x, PICKUP_FONT_SIZE, 4, Color("423643", ink.a))
		draw_string(feedback_font, baseline, item.text, HORIZONTAL_ALIGNMENT_CENTER, box.size.x, PICKUP_FONT_SIZE, ink)

# The anchor and its tail stay in world coordinates as the camera moves.
func _field_note(at: Vector2, words: String, active: bool, mark_width := 0, screen_space := false, action := "") -> Rect2:
	var pixels := 22 if active else 19
	var keys := PackedStringArray()
	var prefix := ""
	var driver := get_parent()
	if not action.is_empty() and driver and driver.has_method("control_hint"):
		var hint := _action_hint(action)
		var split := words.find(hint)
		if split >= 0:
			prefix = words.left(split)
			words = words.substr(split+hint.length()).strip_edges()
			for slot in (["pad"] if driver.input_device=="pad" else ["key","mouse"]):
				keys.append_array(driver.bindings.labels(action,slot))
			if keys.is_empty(): keys.append("未绑定")
	var key_widths := PackedFloat32Array()
	var key_space := 0.0
	for key in keys:
		var width := maxf(36,feedback_font.get_string_size(key,HORIZONTAL_ALIGNMENT_LEFT,-1,19).x+15)
		key_widths.append(width)
		key_space += width+5
	key_space += maxi(0,keys.size()-1)*25
	var prefix_width := feedback_font.get_string_size(prefix,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels).x
	var text_width := feedback_font.get_string_size(words,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels).x
	var extent := Vector2(ceilf(text_width+mark_width+prefix_width+key_space+31),48 if active else 39)
	var bounds := get_viewport_rect() if screen_space else Rect2(model.camera_offset,get_viewport_rect().size/scale)
	var center := at.clamp(bounds.position+extent/2+Vector2(5,5),bounds.end-extent/2-Vector2(5,13))
	var box := Rect2((center-extent/2).round(),extent)
	if not screen_space and box.grow(10).intersects(Rect2(model.p-Vector2(24,20),Vector2(48,40))):
		box.position.y = maxf(bounds.position.y+5,model.p.y-32-extent.y)
	if screen_space and box.intersects(prompt_screen.grow(7)):
		box.position.y = clampf(prompt_screen.end.y+12,5,bounds.end.y-extent.y-5)
	prompt_surface.bg_color = Color("793e2b") if screen_space and model.energy_is_low() else (Color("35594e") if active else Color("3f5147"))
	draw_style_box(prompt_surface,box)
	if not screen_space:
		var x := clampf(at.x,box.position.x+15,box.end.x-15)
		var tip := PackedVector2Array([Vector2(x-9,box.end.y-2),Vector2(x,box.end.y+9),Vector2(x+9,box.end.y-2)])
		draw_colored_polygon(tip,prompt_surface.bg_color)
		draw_polyline(tip,prompt_surface.border_color,1.8,true)
		prompt_screen = Rect2((box.position-model.camera_offset)*scale,box.size*scale)
	_field_note_bounds.append((box if screen_space else prompt_screen).grow(9))
	var cursor := box.position.x+15+mark_width
	var baseline := box.get_center().y+(feedback_font.get_ascent(pixels)-feedback_font.get_descent(pixels))/2
	if not prefix.is_empty():
		draw_string(feedback_font,Vector2(cursor,baseline),prefix,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels,FIELD_INK)
		cursor += prefix_width
	for i in keys.size():
		if i:
			draw_string(feedback_font,Vector2(cursor,baseline),"或",HORIZONTAL_ALIGNMENT_LEFT,-1,17,FIELD_MUTED_INK)
			cursor+=25
		var cap := Rect2(cursor,box.get_center().y-18,key_widths[i],37)
		draw_style_box(Keycaps.q_face if keys[i]=="Q" else Keycaps.blank_face,cap)
		if keys[i]!="Q":
			draw_string(feedback_font,Vector2(cursor,baseline-2),keys[i],HORIZONTAL_ALIGNMENT_CENTER,cap.size.x,19,Keycaps.INK)
		cursor+=cap.size.x+5
	draw_string(feedback_font,Vector2(cursor,baseline),words,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels,FIELD_INK)
	return box

func _draw_home_bearing() -> void:
	var entry: Vector2 = model.field.layout.nodes[0].p
	var direction: Vector2 = (entry-model.p).normalized()
	if model.energy_is_low():
		if model.field.at_entry(): return
		var bee: Vector2 = (model.p - model.camera_offset) * MeadowLayout.FIELD_ZOOM
		var badge_at := (bee + Vector2(0,-118)).clamp(Vector2(110,26),get_viewport_rect().size-Vector2(110,26))
		var badge := _field_note(badge_at, "体力低 · 回庭院", true, 27, true)
		var centre := Vector2(badge.position.x + 18, badge.get_center().y)
		var strength := 1.0 if reduced_motion else (1.0 + cos(model.field.elapsed * TAU / EnergyDial.PULSE_SECONDS)) * .5
		var gold := Color("ebc58c").lerp(Color("ffe8a4"), strength)
		var side := direction.orthogonal()
		draw_line(centre-direction*10,centre+direction*9,gold,4,true)
		draw_colored_polygon(PackedVector2Array([centre+direction*13,centre+direction*2+side*8,centre+direction*2-side*8]),gold)
		return
	if model.p.distance_to(entry)<330 and _full_glow <= 0: return
	var at := get_viewport_rect().size - Vector2(141, 52)
	var badge := _field_note(at, "回庭院", false, 21, true)
	var side := direction.orthogonal()
	var centre := Vector2(badge.position.x + 16, badge.get_center().y)
	if _full_glow > 0:
		var alpha := minf(_full_glow*3,1)
		draw_circle(centre,13,Color("5b512e",alpha*.9),true,-1,true)
		draw_arc(centre,13,0,TAU,28,Color("f9d979",alpha),2,true)
	draw_polyline(PackedVector2Array([centre-direction*5-side*5,centre+direction*6,centre-direction*5+side*5]),Color("f5df9f"),2.5,true)
