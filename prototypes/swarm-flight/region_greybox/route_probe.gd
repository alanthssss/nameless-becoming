extends SceneTree
## Known-route model execution. Only ordinary model.step inputs move/collect;
## fixed targets are disclosed, so this is not natural exploration evidence.
const Model = preload("res://region_greybox/model.gd")
const Layout = preload("res://region_greybox/layout.gd")
const DT := 1.0 / 60.0

static func drive_to(model: RefCounted, target: Vector2) -> bool:
	for frame in 3600:
		if model.phase != "active": return false
		var delta: Vector2 = target - model.p
		if delta.length() < 2.0 and model.v.length() < 4.0: return true
		model.step(DT, delta / 28.0 if delta.length() < 28.0 else delta.normalized(), false)
	return false

static func drive_edge(model: RefCounted, a: int, b: int) -> bool:
	var path: PackedVector2Array = Layout.path_between(model.layout, a, b)
	if path.is_empty(): return false
	for i in range(1, path.size()):
		if not drive_to(model, path[i]): return false
	return true

static func cluster_point(model: RefCounted, cluster_id: int) -> Vector2:
	var total := Vector2.ZERO
	var count := 0
	for flower in model.flowers:
		if int(flower.cluster) == cluster_id:
			total += flower.p
			count += 1
	return total / maxi(1, count)

static func gather(model: RefCounted, count: int) -> bool:
	var target: int = mini(model.capacity(), model.cargo + count)
	for frame in 2400:
		if model.phase != "active": return false
		if model.cargo >= target: return true
		model.step(DT, Vector2.ZERO, true)
	return false

static func material(model: RefCounted, index: int) -> bool:
	var item: Dictionary = model.materials[index]
	if not drive_to(model, item.anchor): return false
	for frame in 240:
		if model.phase != "active": return false
		if item.taken: return true
		model.step(DT, Vector2.ZERO, false, false, true, item.p - model.p)
	return false

static func return_home(model: RefCounted) -> bool:
	# Both authored maps progress left-to-right. Retreat via bends, never
	# shortcut across vegetation from the far end to the entry.
	for id in [2,1,0]:
		if float(model.layout.nodes[id].p.x) < model.p.x + 2.0:
			if not drive_to(model, model.layout.nodes[id].p): return false
	model.step(DT, Vector2.ZERO, true)
	return model.phase == "returned"

static func run_trip(region: String, level: int, seed_value: int, kind: String) -> Dictionary:
	var m := Model.new()
	m.configure(region, level, seed_value)
	var ok := true
	if kind == "far_material":
		ok = drive_edge(m,0,1) and drive_edge(m,1,2) and drive_edge(m,2,3) and material(m,1)
	elif kind == "materials":
		ok = drive_edge(m,0,1) and drive_edge(m,1,2) and material(m,0)
		ok = ok and drive_to(m,m.layout.nodes[2].p) and drive_edge(m,2,3) and material(m,1)
	else:
		var limit := 3 if kind == "money" else 6
		for cluster_id in limit:
			if not drive_to(m,cluster_point(m,cluster_id)): ok = false; break
			var wanted := mini(int(m.layout.clusters[cluster_id].count), 6-m.cargo) if kind == "money" else int(m.layout.clusters[cluster_id].count)
			if not gather(m,maxi(0,wanted)): ok = false; break
			if kind == "mixed" and cluster_id == 3:
				if not drive_to(m,m.layout.nodes[2].p) or not material(m,0) or not drive_to(m,m.layout.nodes[2].p): ok = false; break
		if ok and kind == "mixed": ok = material(m,1)
	if ok: ok = return_home(m)
	var result: Dictionary = m.summary()
	result["sample"] = kind
	result["driver_completed"] = ok
	return result

func _init() -> void:
	var output := "/private/tmp/resource-greybox-routes.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	var results: Array[Dictionary] = []
	for region in ["pond","violet"]:
		for seed_value in [1201,1202]:
			for level in [0,1]:
				for kind in ["money","far_material","materials","mixed"]:
					var result := run_trip(region,level,seed_value,kind)
					results.append(result)
					print("%s seed%d g%d %s: %s nectar%d material%d time%.2f energy%.2f empty%.2f" % [region,seed_value,level,kind,result.result,result.cargo,result.materials,result.elapsed_seconds,result.energy_left,result.longest_empty_flight_seconds])
	var file := FileAccess.open(output,FileAccess.WRITE)
	if file == null: quit(2); return
	file.store_string(JSON.stringify({"schema":2,"kind":"known_route_model_execution","dt":DT,
		"limits":["No human player evidence","Known targets and ordinary inputs","No position/cargo/energy writes during trips","Failures retained"],"samples":results},"\t"))
	print("GREYBOX_ROUTES samples=%d output=%s" % [results.size(),output])
	quit(0)
