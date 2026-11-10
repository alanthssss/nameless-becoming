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
	var m := Model.new(); m.configure(region,level,seed_value); return m
# Isolated lifecycle fixture: advances resource time without pretending this
# to be a playable trip or hiding exhaustion in the complete-route driver.
func life_tick(m: RefCounted, seconds: float) -> void:
	for i in roundi(seconds/DT):
		m.elapsed += DT
		m._supply(DT)
func _init() -> void:
	generation()
	lifecycle()
	collection()
	materials_and_growth()
	recovery_and_inputs()
	print("GREYBOX_MODEL checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)
func generation() -> void:
	for region in ["pond","violet"]:
		var changed := false
		var baseline := fresh(region)
		for seed_value in range(1201,1233):
			var low := fresh(region,0,seed_value); var high := fresh(region,1,seed_value)
			check(low.flowers == high.flowers and low.materials == high.materials,"growth keeps supply/initial lifecycle identical")
			check(low.layout == baseline.layout,"seed never changes geography")
			check(low.flowers[0].p == baseline.flowers[0].p,"entry cluster remains predictable")
			changed = changed or low.flowers != baseline.flowers
			var sites := {"near":0,"middle":0,"far":0}; var ripe := sites.duplicate()
			for f in low.flowers:
				sites[f.band] += 1
				if Model.available(f): ripe[f.band] += 1
				check(Layout.walkable(low.layout,f.p,46),"dense flower approach remains inside geometry")
			check(sites == {"near":12,"middle":12,"far":12},"36 sites span near/middle/far equally")
			check(ripe.near >= 8 and ripe.middle >= 8 and ripe.far >= 8,"each initial band mostly harvestable")
			check(low.materials.size() == 6 and Model.available(low.materials[0]),"near material immediately available")
			check(Model.available(low.materials[4]) or Model.available(low.materials[5]),"far pair has initial supply")
		check(changed,"seeds slightly shift flowers")
	var low := fresh(); var high := fresh("pond",1)
	check(low.max_energy()==36 and low.capacity()==6 and high.max_energy()==70 and high.capacity()==16 and "twin" in high.stats.owned,"growth retains existing capacity/stamina/twin")
func lifecycle() -> void:
	var m := fresh("pond",1)
	var f: Dictionary = m.flowers[0]
	m._enter_phase(f,"empty",false)
	life_tick(m,5.9); check(f.phase=="empty" and f.stock==0,"flower rests empty for six seconds")
	life_tick(m,0.1); check(f.phase=="bud" and f.stock==0,"flower generates after empty interval")
	life_tick(m,3.9); check(f.phase=="bud","bud takes four active seconds")
	life_tick(m,0.1); check(f.phase=="ripe" and f.stock==1 and f.progress==0,"maturation grants one fresh harvest")
	life_tick(m,18); check(f.phase=="fading" and f.stock==1,"ripe flower enters visible six-second decline")
	life_tick(m,6); check(f.phase=="empty" and f.stock==0,"unharvested old flower disappears")
	check(m.events.any(func(e):return e.kind=="flower_bud") and m.events.any(func(e):return e.kind=="flower_ripe") and m.events.any(func(e):return e.kind=="flower_fading") and m.events.any(func(e):return e.kind=="flower_empty"),"flower lifecycle records all transitions")
	var item: Dictionary = m.materials[0]
	m._enter_phase(item,"empty",true)
	life_tick(m,18); check(item.phase=="bud","material regenerates after eighteen empty seconds")
	life_tick(m,4); check(item.phase=="ripe" and item.hits==0,"new material starts fresh")
	item.hits=1
	life_tick(m,22); check(item.phase=="fading" and item.hits==1,"material decay preserves existing partial hits")
	life_tick(m,6); check(item.phase=="empty" and item.hits==0,"expired material resets old partial hits")
	for region in ["pond","violet"]:
		var aging := fresh(region)
		for second in 60:
			life_tick(aging,1)
			var available := {"near":0,"middle":0,"far":0}
			for flower in aging.flowers:
				if Model.available(flower): available[flower.band] += 1
			check(available.near>0 and available.middle>0 and available.far>0,"staggering never ages an untouched whole band empty")
			check(Model.available(aging.materials[4]) or Model.available(aging.materials[5]),"far pair keeps an available window including 10–15 second arrival")
func collection() -> void:
	var phase_fixture := fresh("pond",1)
	for f in phase_fixture.flowers: phase_fixture._enter_phase(f,"empty",false)
	var phase_flower: Dictionary = phase_fixture.flowers[0]
	phase_fixture.p=phase_flower.p
	phase_fixture._enter_phase(phase_flower,"bud",false)
	for i in 60: phase_fixture.step(DT,Vector2.ZERO,true)
	check(phase_fixture.cargo==0 and phase_fixture.harvest_seconds==0,"generating flower refuses collection and added harvest cost")
	phase_fixture._enter_phase(phase_flower,"fading",false)
	for i in 48: phase_fixture.step(DT,Vector2.ZERO,true)
	check(phase_fixture.cargo==1,"visibly fading flower remains harvestable")
	var m := fresh("pond",1)
	check(Probe.drive_to(m,Probe.cluster_point(m,0)),"reach entry flowers")
	for i in 3: m._enter_phase(m.flowers[i],"ripe",false)
	for i in 24: m.step(DT,Vector2.ZERO,true)
	check(m.cargo==0,"partial collection pays nothing")
	m.step(DT,Vector2.ZERO,false)
	for i in 24: m.step(DT,Vector2.ZERO,true)
	check(m.cargo==2,"existing twin completes two in 0.8 seconds")
	var emptied: Array = m.flowers.filter(func(f):return f.phase=="empty" and f.cluster==0)
	check(emptied.size()==2,"harvested flowers enter empty phase")
	var flower: Dictionary = emptied[0]
	check(flower.stock==0 and flower.progress==0,"harvest clears partial progress")
	life_tick(m,9.9); check(flower.stock==0,"empty and generating flowers are not harvestable")
	life_tick(m,0.1); check(flower.stock==1 and flower.progress==0,"flower returns after six plus four seconds")
	m.step(DT,Vector2.ZERO,true); check(m.cargo==2,"regrowth cannot pay again in the same frame")
	var full := fresh(); full.cargo=6
	var harvest_time: float = full.harvest_seconds
	for i in 60: full.step(DT,Vector2.ZERO,true)
	check(full.cargo==6 and full.harvest_seconds==harvest_time,"full bag adds no harvest cost or cargo")
func materials_and_growth() -> void:
	var drop := fresh("pond",1)
	var item: Dictionary = drop.materials[0]
	drop.p=item.anchor-Vector2(80,0); drop.face=Vector2.RIGHT
	drop.step(DT,Vector2.ZERO,false,false,true,Vector2.RIGHT)
	check(item.dropped and item.phase=="fading" and item.phase_duration==12,"detached material has visible twelve-second decay")
	life_tick(drop,11.9); check(item.dropped,"drop remains available before timeout")
	life_tick(drop,0.1); check(not item.dropped and item.phase=="empty" and drop.material_count==0,"unpicked drop expires without awarding material")
	check("已消散" in drop.last_action,"expired drop no longer asks player to pick it up")
	var repeated := fresh("pond",1)
	for cycle in 7:
		var carrier: Dictionary = repeated.materials[0]
		if cycle>0: life_tick(repeated,22)
		for i in 36: repeated.step(DT,Vector2.ZERO,false)
		repeated.p=carrier.p-Vector2(20,0)
		repeated.step(DT,Vector2.ZERO,false,false,true,Vector2.RIGHT)
		check(repeated.material_count==cycle+1 and carrier.phase=="empty" and carrier.taken,"picked habitat regenerates and can be harvested in later cycles")
	var restored := Model.new()
	check(restored.restore(repeated.snapshot()) and restored.material_count==7,"save restores cumulative materials beyond site count")
	for region in ["pond","violet"]:
		var initial: Dictionary = Probe.run_trip(region,0,1201,"money")
		var grown: Dictionary = Probe.run_trip(region,1,1201,"mixed")
		var materials: Dictionary = Probe.run_trip(region,0,1201,"far_material")
		check(initial.result=="returned" and initial.cargo==6,"initial money trip brings home six")
		check(materials.result=="returned" and materials.materials==1,"initial far material trip is feasible")
		check(grown.result=="returned" and grown.cargo==16 and grown.materials>=3,"grown trip combines full bag and distributed materials")
		check(grown.energy_left>0,"grown combined trip returns alive")
func recovery_and_inputs() -> void:
	var m := fresh("violet",1)
	Probe.drive_to(m,Probe.cluster_point(m,1)); Probe.gather(m,2)
	for i in 210: m.step(DT,Vector2.RIGHT,false)
	var data: Dictionary = m.snapshot(); var restored := Model.new()
	check(restored.restore(data),"active lifecycle snapshot restores")
	check(restored.snapshot()==data,"restore keeps all phases, timers, progress, position and seed")
	for i in 60:
		m.step(DT,Vector2.ZERO,false); restored.step(DT,Vector2.ZERO,false)
	check(m.snapshot()==restored.snapshot(),"restored active time evolves identically")
	var corrupt: Dictionary = data.duplicate(true); corrupt.flowers[0].stock=5
	var before: Dictionary = restored.snapshot()
	check(not restored.restore(corrupt) and restored.snapshot()==before,"inconsistent phase/stock rejected without mutation")
	corrupt=data.duplicate(true); corrupt.version=2
	check(not restored.restore(corrupt),"old once-per-trip save cannot enter lifecycle version")
	var empty := fresh(); var baseline := fresh()
	for i in 60:
		empty.step(DT,Vector2.ZERO,false,false,true,Vector2.LEFT); baseline.step(DT,Vector2.ZERO,false)
	check(is_equal_approx(empty.energy,baseline.energy),"empty pulses remain free")
	var original: Dictionary = empty.snapshot()
	empty.step(NAN,Vector2.RIGHT,false); empty.step(-1,Vector2.RIGHT,false); empty.step(DT,Vector2(INF,0),false)
	check(empty.snapshot()==original,"invalid input rejected")
	for i in 25: empty.step(DT,Vector2.LEFT,false,true)
	empty.step(DT,Vector2.LEFT,false,false)
	check(empty.burst_left>0,"charged dash retained")
	for i in 120:
		empty.step(DT,Vector2.LEFT,false); check(Layout.walkable(empty.layout,empty.p),"dash respects visible boundary")
	empty.finish("abandoned"); original=empty.snapshot()
	for i in 120: empty.step(DT,Vector2.RIGHT,true,false,true)
	check(empty.snapshot()==original,"finished trip freezes resource aging")
