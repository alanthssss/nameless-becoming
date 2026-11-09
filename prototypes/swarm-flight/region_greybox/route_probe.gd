extends SceneTree
## Known-route developer probe. Movement/collection always use the same step()
## inputs as play; it never teleports the bee, fills cargo, or resets energy.
## This is measured model execution, not uncoached human exploration evidence.
const Model = preload("res://region_greybox/model.gd")
const Layout = preload("res://region_greybox/layout.gd")
const DT := 1.0 / 60.0

static func drive_to(model: RefCounted, target: Vector2) -> bool:
	for frame in 3600:
		if model.phase != "active": return false
		var delta: Vector2 = target - model.p
		if delta.length() < 2.0 and model.v.length() < 4.0: return true
		# Brake before each waypoint. This keeps turns reproducible and avoids
		# cutting across the vegetation when a capsule changes direction.
		var motion := delta / 28.0 if delta.length() < 28.0 else delta.normalized()
		model.step(DT,motion,false)
	return false

static func drive_edge(model: RefCounted, a: int, b: int) -> bool:
	var path: PackedVector2Array = Layout.path_between(model.layout,a,b)
	if path.is_empty(): return false
	for i in range(1,path.size()):
		if not drive_to(model,path[i]): return false
	return true

static func gather(model: RefCounted, count: int) -> bool:
	var target: int = mini(model.capacity(),model.cargo + count)
	for frame in 2400:
		if model.phase != "active": return false
		if model.cargo >= target: return true
		model.step(DT,Vector2.ZERO,true)
	return false

static func gather_materials(model: RefCounted, count: int = 2) -> bool:
	for item in model.materials:
		if model.material_count >= count: return true
		if not drive_to(model,item.p): return false
		for frame in 180:
			if model.phase != "active": return false
			if item.taken: break
			model.step(DT,Vector2.ZERO,false,false,true,item.p-model.p)
	return model.material_count >= count

static func travel(model: RefCounted, route: Array, harvest_node: int = -1, nectar: int = 0, material_node: int = -1) -> Dictionary:
	var completed_legs := 0
	var harvest_attempted := false
	var materials_attempted := false
	var stopped := "completed"
	for i in range(1,route.size()):
		if not drive_edge(model,int(route[i-1]),int(route[i])):
			stopped = "movement_stopped"
			break
		completed_legs += 1
		if int(route[i]) == harvest_node and not harvest_attempted:
			harvest_attempted = true
			if not gather(model,nectar):
				stopped = "harvest_stopped"
				break
		if int(route[i]) == material_node and not materials_attempted:
			materials_attempted = true
			if not gather_materials(model):
				stopped = "materials_stopped"
				break
	if model.phase == "active" and completed_legs == route.size()-1 and int(route[-1]) == 0:
		model.step(DT,Vector2.ZERO,true) # Actual E/collect input at the entry.
	var result: Dictionary = model.summary()
	result["planned_route"] = route.duplicate()
	result["completed_legs"] = completed_legs
	result["requested_nectar"] = nectar
	result["requested_materials"] = 2 if material_node >= 0 else 0
	result["driver_status"] = stopped
	result["harvest_attempted"] = harvest_attempted
	result["materials_attempted"] = materials_attempted
	return result

static func sample(region: String, state: String, growth: int, kind: String, route: Array, harvest_node: int, nectar: int, material_node: int = -1) -> Dictionary:
	var model := Model.new()
	model.configure(region,state,growth)
	var result := travel(model,route,harvest_node,nectar,material_node)
	result["sample"] = kind
	return result

func _init() -> void:
	var output := "/private/tmp/region-greybox-route-probe.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	var results: Array[Dictionary] = []
	for region in ["pond","violet"]:
		for state in ["sunny","rain","variant"]:
			for growth in [0,1]:
				results.append(sample(region,state,growth,"near_three",[0,1,2,3,1,0],2,3))
				var route: Array
				if region == "pond": route = [0,1,2,4,5,7,6,1,0] if state == "variant" else [0,1,3,4,5,7,6,1,0]
				else: route = [0,1,2,4,6,5,7,2,1,0] if state == "variant" else [0,1,3,4,6,5,7,2,1,0]
				results.append(sample(region,state,growth,"far_eight_and_materials",route,4 if region == "pond" else 5,8,7 if region == "pond" else 6))
		# Same far target, same one unit, same capability: compare rain routes.
		for growth in [0,1]:
			var direct: Array = [0,1,3,4,3,1,0] if region == "pond" else [0,1,2,5,2,1,0]
			var sheltered: Array = [0,1,6,5,4,5,6,1,0] if region == "pond" else [0,1,3,4,5,4,3,1,0]
			results.append(sample(region,"rain",growth,"rain_direct_one",direct,4 if region == "pond" else 5,1))
			results.append(sample(region,"rain",growth,"rain_sheltered_one",sheltered,4 if region == "pond" else 5,1))
		# Explicitly test a viable first rainy outing, without demanding the full near loop.
		results.append(sample(region,"rain",0,"rain_first_one_at_two",[0,1,2,1,0],2,1))
		results.append(sample(region,"rain",0,"rain_first_one_at_three",[0,1,3,1,0],3,1))
	var report := {"schema":1,"kind":"known_route_model_execution","dt":DT,
		"limits":["No human exploration evidence","Routes intentionally known to driver","No position, cargo or energy writes during routes","Exhausted and incomplete cases retained"],"samples":results}
	var file := FileAccess.open(output,FileAccess.WRITE)
	if file == null:
		push_error("Cannot write route probe: "+output)
		quit(2)
		return
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	for result in results:
		print("%s %s g%d %s: %s cargo=%d material=%d time=%.2f energy=%.2f rain=%.2f" % [result.region,result.condition,result.growth,result.sample,result.result,result.cargo,result.materials,result.elapsed_seconds,result.energy_left,result.rain_seconds])
	print("GREYBOX_ROUTES samples=%d output=%s" % [results.size(),output])
	quit(0)
