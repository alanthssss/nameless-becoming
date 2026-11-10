extends SceneTree
const Model = preload("res://region_game/model.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL "+label)
func _initialize() -> void:
	var m = Model.new()
	check(m.upgrade_defs().size() == 14 and not m.can_buy("shortcut"),"only useful growth is purchasable")
	check(not m.transition_to("meadow"),"meadow locked")
	check(m.transition_to("pond"),"depart courtyard")
	check(m.field.flowers.size() == 36 and m.field.materials.size() == 6,"potential sites")
	check(m.field.flowers.filter(func(f): return f.enabled).size() == 16,"sparse initial population")
	check(m.max_energy() == 36 and m.capacity() == 6,"actual initial stats")
	m.field.p = m.field.flowers[0].p # Focused harvest fixture; native travel is checked separately.
	m._sync_field()
	for i in 110: m.step(.05,Vector2.ZERO,true,false)
	check(m.cargo_total() > 0,"ordinary collection credits profile")
	var saved: Dictionary = m.to_payload()
	var clone = Model.new()
	check(clone.restore_payload(JSON.parse_string(JSON.stringify(saved))),"JSON roundtrip active region")
	check(clone.p == m.p and clone.field.flowers == m.field.flowers and clone.energy == m.energy,"exact life and location restored")
	clone.step(.05,Vector2.ZERO,false,false)
	m.step(.05,Vector2.ZERO,false,false)
	check(clone.field.flowers == m.field.flowers,"resumed phase advances consistently")
	var wrong: Dictionary = saved.duplicate(true)
	wrong.profile.owned = ["bag2"]
	check(not clone.restore_payload(wrong),"reject invalid growth without mutating state")
	check(clone.p == m.p,"failed restore transactional")
	m.field.p = m.field.layout.nodes[0].p
	m._sync_field()
	m.field.departed = true
	m.step(.05,Vector2.ZERO,true,false)
	check(m.area == "pond" and m.return_requested and m.field.phase == "active","held harvest requests a transactional return")
	check(m.transition_to("hub"),"return to courtyard")
	var count: int = m.cargo_total()
	check(m.sell() == count and m.coins == count and m.cargo_total() == 0,"sale conservation")
	m.coins = 1000 # Explicit economy fixture, not player-earned evidence.
	m.materials = {"fiber":1000,"resin":1000}
	for id in ["gather1","bag1","wings1","gather2","reach","beat","bag2","wings2","meadow","supply1","supply2"]:
		check(m.buy(id),"purchase "+id)
		check(clone.restore_payload(m.to_payload()),"save purchase "+id)
	check(m.capacity() == 16 and m.max_energy() == 70,"earned owned changes stats")
	check(m.transition_to("meadow"),"unlocked purple destination")
	check(m.field.stats.owned == m.owned and m.field.energy == 70,"field receives each purchased rank")
	check(m.field.supply_rank == 2 and m.field.flowers.filter(func(f):return f.enabled).size() == 36,"real resource growth enables new sites")
	m.field.p = m.field.flowers[0].p
	m._sync_field()
	for i in 110: m.step(.05,Vector2.ZERO,true,false)
	check(m.cargo.rose > 0,"violet cargo identity")
	for i in 2600:
		if m.at_home(): break
		m.step(.05,Vector2.ZERO,false,false)
	check(m.at_home() and m.energy == 70,"exhaustion restores safe courtyard")
	check(clone.restore_payload(m.to_payload()),"rescue save valid")
	m.rose_sold = 6
	m.sold_total = maxi(6,m.sold_total)
	for id in ["twin","market","reserve"]:
		check(m.buy(id),"purchase "+id)
		check(clone.restore_payload(m.to_payload()),"save "+id)
	check(m.completed and m.owned.size() == 14,"all available growth and completion")
	check(not m.buy("reserve"),"no duplicate spend")
	print("Regional model: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
