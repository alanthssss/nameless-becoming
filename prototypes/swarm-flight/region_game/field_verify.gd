extends SceneTree
const RegionModel = preload("res://region_game/model.gd")
const Field = preload("res://region_game/field.gd")
const Layout = preload("res://region_greybox/layout.gd")
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL "+label)
func fresh_at(region: String, index: int):
	var f=Field.new()
	f.configure(region,0,1)
	var anchor: Vector2=f.materials[index].anchor
	for direction: Vector2 in [Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN]:
		var approach := anchor-direction*85.0
		if Layout.walkable(f.layout,approach) and f.clear_line(approach,anchor):
			f.p=approach
			f.face=direction
			break
	return f

func check_fiber_handling() -> void:
	var f=fresh_at("pond",0)
	var head: Dictionary=f.materials[0]
	var start: float=f.energy
	f._pulse(-f.face)
	f._pulse(-f.face)
	check(f.energy==start and head.hits==0,"misdirected wingbeat spends nothing")
	var empty_beats: Array=f.events.filter(func(e): return e.kind=="pulse_empty")
	check(empty_beats.size()==1 and empty_beats[0].direction==-f.face,"held empty beat shows its direction once and permits immediate retargeting")
	f._pulse(f.face)
	check(head.dropped and (head.p-head.anchor).dot(f.face)>0.0 and head.p.distance_to(head.anchor)<=25.0,"one on-target beat detaches near seed down on its lee side")
	check(f.material_count==0 and f.energy==start-2.0,"release does not credit unreachable fiber")
	var restored=Field.new()
	check(restored.restore(f.snapshot()) and restored.materials[0].dropped,"loose tuft survives reload")
	restored.cargo=restored.capacity()
	restored.p=restored.materials[0].p
	restored.step(.05,Vector2.ZERO,false)
	restored.step(.05,Vector2.ZERO,false)
	check(restored.material_count==1 and restored.cargo==restored.capacity(),"full honey bag still catches one tuft exactly once")
	for i in 242: f.step(.05,Vector2.ZERO,false)
	check(not head.dropped and not Field.available(head) and f.material_count==0,"uncollected tuft expires after its visible grace period")
	f=fresh_at("pond",2)
	head=f.materials[2]
	f._pulse(f.face)
	check(head.hits==1 and not head.dropped,"thick pocket husk opens in visible stages")
	for i in 12: f.step(.05,Vector2.ZERO,false,false,true,f.face)
	check(head.dropped and f.material_count==0,"held beat finishes thick husk after cooldown")
	f=fresh_at("pond",2)
	f.stats.owned.append("beat")
	f._pulse(f.face)
	check(f.materials[2].dropped,"grown wings open thick husk on first beat")

func check_resin_handling() -> void:
	var f=fresh_at("violet",0)
	var source: Dictionary=f.materials[0]
	f.cargo=f.capacity()
	f.step(.05,Vector2.ZERO,true)
	check(f.material_count==0,"unopened bark cannot give resin on contact")
	f._pulse(f.face)
	check(f.resin_open(source) and not source.dropped,"first bark seam opens on the fixed trunk")
	for i in 13: f.step(.05,Vector2.ZERO,true,false,true,f.face)
	check(not source.has("resin_draw") and f.material_count==0,"holding both actions outside reach cannot harvest open resin")
	var before: float=f.energy
	f._pulse(f.face)
	check(f.energy==before,"wingbeats on already open seam consume no stamina")
	f.p=source.anchor-Vector2(35,0)
	for i in 8: f.step(.05,Vector2.ZERO,true)
	check(is_equal_approx(float(source.get("resin_draw",0)),.4) and f.material_count==0,"resin forms a visible half-drawn bead")
	for i in 8: f.step(.05,Vector2.ZERO,false)
	check(is_equal_approx(float(source.get("resin_draw",0)),.4) and f.drawing_resin_id<0,"releasing E retains resin on the same bark")
	var saved: Dictionary=f.snapshot()
	var clone=Field.new()
	check(clone.restore(saved) and clone.resin_open(clone.materials[0]),"open seam and partial bead resume after save")
	for i in 10: clone.step(.05,Vector2.ZERO,true)
	check(clone.material_count==1 and clone.materials[0].taken and clone.materials[0].phase=="empty","finishing the bead credits resin once even at full honey capacity")
	check(not clone.materials[0].has("resin_draw") and not clone.materials[0].dropped,"spent bark cannot dispense twice")
	var late=fresh_at("violet",0)
	var seam: Dictionary=late.materials[0]
	late._enter_phase(seam,"fading",true)
	seam.phase_time=seam.phase_duration-.04
	late._pulse(late.face)
	check(seam.phase_duration-seam.phase_time>=3.0 and late.resin_open(seam),"even just before expiry a successful opening gives time to approach and extract")
	for i in 64: late.step(.05,Vector2.ZERO,false)
	check(seam.phase=="empty" and not late.resin_open(seam),"abandoned late-opened bark still dries then starts a new cycle")
	var invalid: Dictionary=saved.duplicate(true)
	invalid.materials[0].resin_draw=2.0
	check(not clone.restore(invalid) and clone.material_count==1,"invalid resin progress rejected transactionally")
	f=fresh_at("violet",2)
	source=f.materials[2]
	f._pulse(f.face)
	check(source.hits==1 and not f.resin_open(source),"thick resin bark shows partial opening")
	for i in 13: f.step(.05,Vector2.ZERO,false,false,true,f.face)
	check(f.resin_open(source) and source.p==source.anchor and not source.dropped,"thick bark opens after second beat and stays rooted")
	var legacy: Dictionary=f.snapshot()
	var loose: Dictionary=legacy.materials[2]
	loose.phase="fading"; loose.phase_time=1.0; loose.phase_duration=12.0; loose.hits=3; loose.dropped=true
	check(clone.restore(legacy),"legacy detached resin is a valid save")
	clone.p=clone.materials[2].p
	clone.step(.05,Vector2.ZERO,false)
	check(clone.material_count==1,"legacy detached resin can still be collected without a second interaction")

func check_material_economy() -> void:
	var m = RegionModel.new()
	m.coins = 100 # Currency fixture. The final material for each purchase comes from play.
	m.materials.fiber = 1
	check(m.buy("gather1") and m.buy("bag1") and not m.can_buy("wings1"),"initial wing recipe requires the second fiber")
	check(m.transition_to("pond"),"travel to fiber habitat")
	var head: Dictionary = m.field.materials[0]
	m.field.p = head.anchor-Vector2(85,0)
	m.step(.05,Vector2.ZERO,false,false,true,Vector2.RIGHT)
	check(head.dropped and m.materials.fiber==1,"tuft releases before inventory credit")
	var landing: Vector2 = head.p
	m.field.p=landing
	m.step(.05,Vector2.ZERO,false,false)
	var picked: Array = m.events.filter(func(e): return e.kind=="material")
	var strikes: Array = m.events.filter(func(e): return e.kind=="pulse")
	check(picked.size()==1 and picked[0].pos==landing and strikes.size()==1 and strikes[0].to==head.anchor,"hit is shown at the stem and pickup at the loose tuft")
	m.field.p=m.field.layout.nodes[0].p
	check(m.transition_to("hub") and m.buy("wings1") and m.materials.fiber==0 and m.max_energy()==50,"collected fiber pays for working wings")
	check(m.buy("meadow") and m.transition_to("meadow"),"earned wings satisfy the meadow gate")
	m.materials.fiber=4
	m.materials.resin=1
	var bark: Dictionary=m.field.materials[0]
	m.field.p=bark.anchor-Vector2(45,0)
	m.step(.05,Vector2.ZERO,false,false,true,Vector2.RIGHT)
	check(m.materials.resin==1 and m.field.resin_open(bark),"opening bark alone gives no resin")
	for i in 22: m.step(.05,Vector2.ZERO,true,false)
	var gathered: Array=m.events.filter(func(e): return e.kind=="material" and e.type=="resin")
	check(m.materials.resin==2 and gathered.size()==1 and gathered[0].pos==bark.anchor,"resin enters the separate material pocket once")
	m.field.p=m.field.layout.nodes[0].p
	var before: int=m.coins
	check(m.transition_to("hub") and m.buy("wings2") and before-m.coins==25 and m.materials=={"fiber":0,"resin":0} and m.max_energy()==70,"returned fiber and resin pay the actual second wings recipe")
	check(not m.buy("wings2") and m.materials=={"fiber":0,"resin":0},"no duplicate upgrade payment")

func _initialize() -> void:
	check_fiber_handling()
	check_resin_handling()
	check_material_economy()
	for region in ["pond","violet"]:
		for seed_value in range(1,9):
			for rank in 3:
				var field = Field.new()
				field.configure(region,1,seed_value)
				field.set_supply_rank(rank)
				check(field.flowers.filter(func(f): return f.enabled).size() == [16,24,36][rank],"flower abundance "+region)
				check(field.materials.filter(func(m): return m.enabled).size() == [3,4,6][rank],"material abundance "+region)
				for i in field.flowers.size():
					var flower: Dictionary = field.flowers[i]
					check(Layout.walkable(field.layout,flower.p,55),"flower stays on visible ground")
					for j in i: check(flower.p.distance_to(field.flowers[j].p) >= 80,"flower breathing room")
				for item in field.materials: check(Layout.walkable(field.layout,item.p,35),"material reachable from ground")
				var copy = Field.new()
				check(copy.restore(field.snapshot()),"population cold restore")
				check(copy.supply_rank == rank and copy.flowers == field.flowers,"no hidden population reset")
				var bad: Dictionary = field.snapshot()
				bad.flowers[2].enabled = not bad.flowers[2].enabled
				check(not copy.restore(bad),"reject illegal enabled slot")
	for rank in 3:
		var f = Field.new()
		f.configure("pond",1,4)
		f.set_supply_rank(rank)
		f._enter_phase(f.flowers[0],"empty",false)
		var seconds: float = [20,14,10][rank]
		for i in int((seconds-.1)/.05): f._supply(.05)
		check(f.flowers[0].phase == "bud","flower still grows before deadline")
		for i in 4: f._supply(.05)
		check(f.flowers[0].phase == "ripe","upgraded flower regenerates on time")
		f._enter_phase(f.materials[0],"empty",true)
		seconds = [44,30.8,22][rank]
		for i in int((seconds-.1)/.05): f._supply(.05)
		check(f.materials[0].phase == "bud","material still grows before deadline")
		for i in 4: f._supply(.05)
		check(f.materials[0].phase == "ripe","upgraded material regenerates on time")
	print("Regional field: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
