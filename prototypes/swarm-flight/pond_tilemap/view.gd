extends "res://region_game/view.gd"
## Reuse the existing hand-painted actors; TileMapLayer owns the floor.

func _draw() -> void:
	if model == null or model.field == null: return
	_world_offset = -model.camera_offset
	draw_set_transform(_world_offset)
	var actors: Array[Dictionary] = []
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
