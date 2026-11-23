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
	# Clustered plants are independent objects, with their feet inside the shore.
	var targets := [Vector2(350,290),Vector2(670,270),Vector2(1200,285),Vector2(1640,350),Vector2(1660,570),Vector2(1180,670),Vector2(1040,1000),Vector2(780,710),Vector2(400,650)]
	for index in targets.size():
		var nearest := coast[0]
		for point in coast:
			if point.distance_squared_to(targets[index])<nearest.distance_squared_to(targets[index]): nearest=point
		var center: Vector2 = model.field.layout.nodes[2].p if index<6 else model.field.layout.nodes[4].p
		var foot := nearest.move_toward(center,42)
		if not FieldLayout.walkable(model.field.layout,foot,18): continue
		_shore_plants.append({"p":foot-Vector2(0,9),"normal":Vector2.UP,"size":1.15 if index%3==0 else .85,"kind":0 if index%2==0 else 2})
