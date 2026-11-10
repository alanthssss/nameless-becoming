extends SceneTree
const Model = preload("res://region_greybox/model.gd")
const Layout = preload("res://region_greybox/layout.gd")
const Probe = preload("res://region_greybox/route_probe.gd")
const DT := 1.0/60.0
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func fresh(region := "pond", level := 0, seed_value := 1201) -> RefCounted:
	var m := Model.new()
	m.configure(region,level,seed_value)
	return m
func _init() -> void:
	generation()
	collection_and_refill()
	materials_and_growth()
	recovery_and_inputs()
	print("GREYBOX_MODEL checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)
func generation() -> void:
	for region in ["pond","violet"]:
		var changed := false
		var baseline := fresh(region)
		for seed_value in range(1201,1233):
			var low := fresh(region,0,seed_value)
			var high := fresh(region,1,seed_value)
			check(low.flowers == high.flowers, "growth does not change supply")
			check(low.materials == high.materials, "growth does not change material habitats")
			check(low.layout == baseline.layout, "seed never changes geography")
			check(low.flowers[0].p == baseline.flowers[0].p, "entry cluster stays fixed")
			changed = changed or low.flowers != baseline.flowers
			var bands := {"near":0,"middle":0,"far":0}
			for f in low.flowers:
				bands[f.band] += int(f.stock)
				check(Layout.walkable(low.layout,f.p,46), "flower has action clearance")
			check(bands == {"near":4,"middle":6,"far":6}, "guaranteed 4/6/6 initial supply")
			check(low.materials.size() == 2 and low.materials[0].band == "middle" and low.materials[1].band == "far", "both materials guaranteed")
		check(changed, "new seeds can slightly relocate flowers")
	check(baseline_stats(), "existing initial and grown abilities")
func baseline_stats() -> bool:
	var low := fresh(); var high := fresh("pond",1)
	return low.max_energy() == 36 and low.capacity() == 6 and high.max_energy() == 70 and high.capacity() == 16 and "twin" in high.stats.owned
func collection_and_refill() -> void:
	var m := fresh("pond",1)
	check(Probe.drive_to(m,Probe.cluster_point(m,0)),"reach first cluster")
	for i in 24: m.step(DT,Vector2.ZERO,true)
	check(m.cargo == 0,"partial progress pays nothing")
	m.step(DT,Vector2.ZERO,false)
	for i in 24: m.step(DT,Vector2.ZERO,true)
	check(m.cargo == 2,"two flowers collected with existing twin after 0.8 seconds")
	check(m.flowers[0].stock == 0 and m.flowers[1].stock == 0 and m.flowers[0].progress == 0,"empty flowers clear progress")
	for i in 1079: m.step(DT,Vector2.ZERO,false)
	check(m.flowers[0].stock == 0,"no refill before 18 active seconds")
	m.step(DT,Vector2.ZERO,false)
	check(m.flowers[0].stock == 1 and m.flowers[0].progress == 0,"refill exactly one with fresh progress")
	for i in 60: m.step(DT,Vector2.ZERO,false)
	check(m.flowers[0].stock == 1 and m.flowers[0].regrow == 0,"full flower accumulates no hidden inventory")
	m.step(DT,Vector2.ZERO,true)
	check(m.cargo == 2,"refilled flower needs a complete new collection")
	var full := fresh()
	for id in [0,1,2]:
		check(Probe.drive_to(full,Probe.cluster_point(full,id)) and Probe.gather(full,2),"ordinary flight collects six")
	check(full.cargo == 6,"capacity reached")
	var harvest_time: float = full.harvest_seconds
	for i in 60: full.step(DT,Vector2.ZERO,true)
	check(full.cargo == 6 and full.harvest_seconds == harvest_time,"full bag adds no harvest cost or cargo")
func materials_and_growth() -> void:
	for region in ["pond","violet"]:
		for level in [0,1]:
			var m := fresh(region,level)
			check(Probe.drive_edge(m,0,1) and Probe.drive_edge(m,1,2) and Probe.material(m,0),"first material reached and picked normally")
			var required := 2 if region == "pond" else 3
			var hits := 0
			for event in m.events:
				if event.kind == "material_hit": hits += 1
			check(hits == ceili(float(required)/(2 if level else 1)),"region hardness and grown strength retained")
			for i in 900: m.step(DT,Vector2.ZERO,false,false,true)
			check(m.material_count == 1 and m.materials[0].taken,"same carrier never pays twice")
		var initial: Dictionary = Probe.run_trip(region,0,1201,"money")
		var grown: Dictionary = Probe.run_trip(region,1,1201,"mixed")
		var materials: Dictionary = Probe.run_trip(region,0,1201,"far_material")
		check(initial.result == "returned" and initial.cargo == 6,"initial money trip returns with six")
		check(materials.result == "returned" and materials.materials == 1,"initial far-only material trip can reach far and return")
		check(grown.result == "returned" and grown.cargo == 16 and grown.materials == 2,"grown mixed trip carries sixteen plus both materials")
		check(grown.energy_left > 10,"grown route retains turning margin")
func recovery_and_inputs() -> void:
	var m := fresh("violet",1)
	Probe.drive_to(m,Probe.cluster_point(m,0))
	Probe.gather(m,2)
	for i in 210: m.step(DT,Vector2.RIGHT,false)
	var data: Dictionary = m.snapshot()
	var restored := Model.new()
	check(restored.restore(data),"active trip snapshot restores")
	check(restored.snapshot() == data,"restoration keeps resources, refill progress, position and seed")
	for i in 60:
		m.step(DT,Vector2.ZERO,false)
		restored.step(DT,Vector2.ZERO,false)
	check(m.snapshot() == restored.snapshot(),"restored active time evolves identically")
	var corrupt: Dictionary = data.duplicate(true)
	corrupt.flowers[0].stock = 5
	var before: Dictionary = restored.snapshot()
	check(not restored.restore(corrupt) and restored.snapshot() == before,"corrupt supply rejected without mutation")
	corrupt = data.duplicate(true); corrupt.version = 1
	check(not restored.restore(corrupt),"old-layout save cannot load into new geometry")
	var empty := fresh(); var baseline := fresh()
	for i in 60:
		empty.step(DT,Vector2.ZERO,false,false,true,Vector2.LEFT)
		baseline.step(DT,Vector2.ZERO,false)
	check(is_equal_approx(empty.energy,baseline.energy),"empty pulses free")
	var original: Dictionary = empty.snapshot()
	empty.step(NAN,Vector2.RIGHT,false); empty.step(-1,Vector2.RIGHT,false); empty.step(DT,Vector2(INF,0),false)
	check(empty.snapshot() == original,"invalid input rejected")
	for i in 25: empty.step(DT,Vector2.LEFT,false,true)
	empty.step(DT,Vector2.LEFT,false,false)
	check(empty.burst_left > 0,"charged dash retained")
	for i in 120:
		empty.step(DT,Vector2.LEFT,false)
		check(Layout.walkable(empty.layout,empty.p),"dash and ordinary inputs respect visible boundary")
	empty.finish("abandoned"); original = empty.snapshot()
	for i in 120: empty.step(DT,Vector2.RIGHT,true,false,true)
	check(empty.snapshot() == original,"finished trip freezes supply and action")
