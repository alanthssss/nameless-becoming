extends SceneTree
## Repeated, paired runs of the shipping 0.32 regional model. No save, UI or video.
const RegionalModel = preload("res://region_game/model.gd")
const DT := 1.0 / 30.0
const SEEDS := [1, 2, 3, 4]
const OPTIONS := ["none", "beat", "wings1", "supply1"]
const ROUTES := ["side_seed_head", "near_flowers", "near_revisit", "far_mixed"]
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func fly_to(m, point: Vector2, in_field: bool) -> bool:
	# Smooth ordinary direction input, as in the project's route_probe.drive_to.
	for frame in 600:
		if in_field and m.field == null:
			return false
		var delta: Vector2 = point - m.p
		if delta.length() < 6 and m.v.length() < 23:
			return true
		m.step(DT, (delta / 28.0).limit_length(1.0), false, false)
	if not in_field or m.field != null:
		check(false, "Could not follow an authored route to %s" % point)
	return false

func visit_flowers(m, sites: Array) -> void:
	for id in sites:
		if m.field == null:
			return
		var flower: Dictionary = m.field.flowers[id]
		if not fly_to(m, flower.p, true):
			return
		# At four flower sites shared by every upgrade, stop for 2.4 seconds.
		# Nearby extra enabled flowers may also be harvested by the ordinary model.
		for frame in 72:
			if m.field == null:
				return
			m.step(DT, Vector2.ZERO, true, false)

func get_fiber(m, id: int) -> void:
	if m.field == null:
		return
	var item: Dictionary = m.field.materials[id]
	var before: int = m.field.material_count
	if not fly_to(m, Vector2(item.anchor) - Vector2(64, 0), true):
		return
	for frame in 75:
		if m.field == null:
			return
		if m.field.material_count > before:
			return
		if item.dropped:
			fly_to(m, item.p, true)
			return
		if not m.field.available(item):
			return
		m.step(DT, Vector2.ZERO, false, false, true, Vector2(item.p) - m.p)

func follow_nodes(m, nodes: Array, positions: Array) -> bool:
	for id in nodes:
		if not fly_to(m, positions[id], true):
			return false
	return true

func run_route(m, route: String) -> void:
	var points := []
	for node in m.field.layout.nodes:
		points.append(node.p)
	match route:
		"side_seed_head":
			if follow_nodes(m, [1, 2, 4], points):
				get_fiber(m, 2)
			follow_nodes(m, [4, 2, 1, 0], points)
		"near_flowers":
			visit_flowers(m, [0, 3, 6, 8])
			follow_nodes(m, [1, 0], points)
		"near_revisit":
			visit_flowers(m, [0, 3, 6, 8, 0])
			follow_nodes(m, [0], points)
		"far_mixed":
			visit_flowers(m, [0, 3, 6, 8])
			if follow_nodes(m, [1, 2, 3], points):
				get_fiber(m, 4)
			follow_nodes(m, [3, 2, 1, 0], points)
	if m.field != null:
		check(m.field.at_entry(), "Route ended away from the entrance")
		check(m.transition_to("hub"), "Gate refused the return")

func sample(seed_value: int, upgrade: String, route: String) -> Dictionary:
	var m := RegionalModel.new()
	# Named fixture only. The 4 extra starting coins pay the real gather1 price.
	m.coins = 13
	m.materials.fiber = 2
	m.trip_index = seed_value - 1
	check(fly_to(m, m.HUB_TREE, false) and m.interaction() == "tree", "Tree unreachable")
	check(m.buy("gather1") and m.coins == 9, "Fixture prerequisite")
	for alternative in ["beat", "wings1", "supply1"]:
		check(m.can_buy(alternative), "Missing intended option " + alternative)
	if upgrade != "none":
		check(m.buy(upgrade), "Purchase failed " + upgrade)
	var coins: int = m.coins
	var fiber: int = m.materials.fiber
	check(fly_to(m, m.HUB_DEPART, false), "Outbound gate unreachable")
	check(m.transition_to("pond"), "Could not leave courtyard")
	if m.field == null:
		return {}
	var start_energy: float = m.field.energy
	var field_model = m.field
	var enabled_flowers: int = field_model.flowers.filter(func(f): return f.enabled).size()
	var enabled_materials: int = field_model.materials.filter(func(f): return f.enabled).size()
	run_route(m, route)
	var trip: Dictionary = m.last_trip
	if trip.is_empty():
		check(false, "Missing trip receipt")
		return {}
	var delivered: int = m.cargo_total()
	var fiber_gained: int = m.materials.fiber - fiber
	var hits := 0
	var hit_ids := PackedStringArray()
	var harvest_ids := PackedStringArray()
	var picked_materials := PackedStringArray()
	for event in trip.events:
		if event.kind == "nectar_picked":
			harvest_ids.append(str(event.id))
		elif event.kind == "material_hit":
			hits += 1
			hit_ids.append(str(event.id))
		elif event.kind == "material_picked":
			picked_materials.append(str(event.id))
	check(fly_to(m, m.HUB_SHOP, false) and m.interaction() == "shop", "Shop unreachable")
	var sale: int = m.sell()
	check(sale == delivered and m.coins == coins + sale, "Sale conservation")
	check(picked_materials.size() == fiber_gained, "Fiber conservation")
	check(harvest_ids.size() == trip.cargo, "Harvest receipt")
	check(trip.result == "exhausted" or trip.result == "returned", "Missing return outcome")
	check(m.cargo_total() == 0, "Sale left cargo behind")
	return {"seed": seed_value, "route": route, "upgrade": upgrade, "coins_spent": 9 - coins,
		"fiber_spent": 2 - fiber, "coins_after_buy": coins, "fiber_after_buy": fiber,
		"start_energy": start_energy, "enabled_flower_sites": enabled_flowers,
		"enabled_material_sites": enabled_materials, "outcome": trip.result,
		"seconds": trip.elapsed_seconds, "distance_px": trip.distance_px,
		"energy_before_return": trip.energy_left, "actual_hits": hits, "hit_ids": "|".join(hit_ids),
		"harvested": trip.cargo, "flower_ids": "|".join(harvest_ids), "nectar_delivered": delivered,
		"fiber_picked": fiber_gained, "material_ids": "|".join(picked_materials),
		"sale_coins": sale, "coins_after_sale": m.coins, "fiber_after_sale": m.materials.fiber}

func _init() -> void:
	var out: String = get_script().resource_path.get_base_dir()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	var rows := []
	for seed_value in SEEDS:
		for route in ROUTES:
			for upgrade in OPTIONS:
				rows.append(sample(seed_value, upgrade, route))
	if not failures.is_empty():
		for msg in failures:
			printerr(msg)
		quit(1)
		return
	var jf := FileAccess.open(out.path_join("nectar-choice.json"), FileAccess.WRITE)
	var cf := FileAccess.open(out.path_join("nectar-choice.csv"), FileAccess.WRITE)
	if jf == null or cf == null:
		printerr("Cannot write to ", out)
		quit(2)
		return
	var fields: Array = rows[0].keys()
	cf.store_csv_line(PackedStringArray(fields))
	for row in rows:
		var values := PackedStringArray()
		for key in fields:
			values.append(str(row[key]))
		cf.store_csv_line(values)
	jf.store_string(JSON.stringify({"engine": Engine.get_version_info().string, "dt_s": DT,
		"kind": "paired_scripted_Godot_model_runs", "seeds":SEEDS, "samples": rows}, "\t") + "\n")
	print("Verified ", rows.size(), " field samples")
	quit()
