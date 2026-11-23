extends "res://region_game/view.gd"
## Reuse the existing hand-painted actors; TileMapLayer owns the floor.

const PlaceDressing = preload("res://region_game/landscape.gd")
var _landscape := {}
var _shore_plants: Array[Dictionary] = []

func _bloom_texture() -> Texture2D:
	return null

func _draw() -> void:
	if model == null or model.field == null: return
	_world_offset = -model.camera_offset
	draw_set_transform(_world_offset)
	PlaceDressing.draw_floor(self,_landscape)
	var actors: Array[Dictionary] = []
	for decoration in _landscape.get("actors",[]):
		if _visible(decoration.p): actors.append({"kind":"landscape","y":decoration.p.y,"data":decoration})
	for plant in _shore_plants:
		if _visible(plant.p): actors.append({"kind":"shore","y":plant.p.y,"data":plant})
	for flower in model.field.flowers:
		_ground_shadow(_resource_root(flower),Vector2(18,5),.13)
		actors.append({"kind":"flower","y":_resource_root(flower).y,"data":flower})
	for item in model.field.materials:
		_ground_shadow(item.anchor+Vector2(0,47),Vector2(23,7),.17)
		actors.append({"kind":"material","y":item.anchor.y+47,"data":item})
	actors.append({"kind":"entry","y":model.field.layout.nodes[0].p.y+54,"p":model.field.layout.nodes[0].p})
	_ground_shadow(model.p+Vector2(0,33),Vector2(22,7),.16)
	actors.append({"kind":"player","y":model.p.y+33})
	actors.sort_custom(func(a,b): return float(a.y)<float(b.y))
	for actor in actors:
		match actor.kind:
			"landscape": PlaceDressing.draw_actor(self,actor.data)
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

func dress(coast: PackedVector2Array) -> void:
	_landscape = PlaceDressing.build(model.field,true)
	_shore_plants.clear()
	# Small irregular groups and long open banks; roots follow the local inward
	# normal rather than pointing at a remote route node across a concave bay.
	var targets := [Vector2(330,305),Vector2(650,265),Vector2(1300,310),Vector2(1650,420),Vector2(1220,665),Vector2(1050,1000),Vector2(390,650)]
	for index in targets.size():
		var nearest := coast[0]
		var tangent := Vector2.RIGHT
		for i in coast.size():
			var next := coast[(i+1)%coast.size()]
			var point := Geometry2D.get_closest_point_to_segment(targets[index],coast[i],next)
			if point.distance_squared_to(targets[index])<nearest.distance_squared_to(targets[index]):
				nearest=point
				tangent=(next-coast[i]).normalized()
		var inward := tangent.orthogonal()
		if not FieldLayout.walkable(model.field.layout,nearest+inward*38,20): inward=-inward
		for j in 3 if index%2==0 else 2:
			var foot := nearest+inward*(38.0+float(j%2)*13.0)+tangent*(float(j)-.7)*30.0
			if not FieldLayout.walkable(model.field.layout,foot,24): continue
			# Preserve the material/flower interaction silhouettes.
			if foot.distance_to(Vector2(920,937))<68: continue
			_shore_plants.append({"p":foot-Vector2(0,9),"normal":-inward,"size":.72 if j==0 else .48+float(index%2)*.10,"kind":0 if j==0 else 2})

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
