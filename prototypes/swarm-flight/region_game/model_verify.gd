extends SceneTree
const Model = preload("res://region_game/model.gd")

class FutureWingProfile extends Model:
	func max_energy() -> float: return 120.0

var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL "+label)
func _initialize() -> void:
	last_wing_at_gate()
	energy_stages_after_growth()
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
	check(m.area == "pond" and m.return_requested and m.field.phase == "returned","held harvest locks in a transactional return")
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

func energy_stages_after_growth() -> void:
	var model = Model.new()
	model.coins = 100
	model.materials = {"fiber": 6, "resin": 2}
	check(model.buy("gather1"), "prepare wing purchases")
	check_energy_boundaries(model, 36)
	check(model.buy("wings1"), "buy first wing for stamina stages")
	check_energy_boundaries(model, 50)
	check(model.buy("wings2"), "buy second wing for stamina stages")
	check_energy_boundaries(model, 70)
	check_energy_boundaries(FutureWingProfile.new(), 120)

func check_energy_boundaries(model, expected_max: int) -> void:
	var limits := [5.0/6.0, 2.0/3.0, 0.5, 0.25, 0.125]
	check(model.transition_to("pond") and model.energy == expected_max, "full on departure at %d" % expected_max)
	for i in limits.size():
		var boundary: float = expected_max * limits[i]
		for offset: float in [-0.0001, 0.0, 0.0001]:
			model.field.energy = boundary + offset
			model._sync_field()
			var label := "max %d, cutoff %d, offset %.4f" % [expected_max, i, offset]
			check(model.energy_stage() == (i if offset > 0 else i + 1), "portrait " + label)
			check(model.energy_is_low() == (model.energy <= expected_max * 0.25), "return cue " + label)
	check(model.transition_to("hub") and model.energy == expected_max and model.energy_stage() == 0 and not model.energy_is_low(), "rested at home at %d" % expected_max)

func approaching(region: String, radius: float, remaining: float):
	var m = Model.new()
	if region == "meadow": m.owned.assign(["gather1","bag1","wings1","meadow"])
	m.transition_to(region)
	m.cargo.blue = 3
	m.cargo.rose = 0 if region == "pond" else 2
	m.field.cargo = m.cargo_total()
	m.materials.fiber = 1
	m.events.clear()
	m.field.p = m.field.layout.nodes[0].p + Vector2.RIGHT * radius
	m.field.v = Vector2.LEFT * m.field.SPEED
	m.field.departed = true
	m.field.energy = remaining
	m._sync_field()
	return m

func last_wing_at_gate() -> void:
	for region in ["pond","meadow"]:
		for start_radius in [130.0,145.0]:
			# These enter on substep one or two of the same 100 ms game frame.
			var m = approaching(region,start_radius,.02 if start_radius == 130.0 else .06)
			m.step(.1,Vector2.LEFT,true,false)
			check(m.return_requested and m.field != null and m.energy == 0,region+" final wing reaches gate "+str(start_radius))
			if m.field == null: continue
			var arrival: Dictionary = m.to_payload()
			m.step(.1,Vector2.RIGHT,false,false)
			check(m.to_payload() == arrival,region+" no extra travel or rescue while returning")
			var clone = Model.new()
			check(clone.restore_payload(JSON.parse_string(JSON.stringify(arrival))) and clone.return_requested,region+" zero-energy arrival survives cold load")
			check(clone.transition_to("hub") and clone.cargo == m.cargo and clone.materials == m.materials,region+" returns once with all cargo and materials")
			check(not clone.transition_to("hub") and not clone.return_requested and clone.energy == clone.max_energy(),region+" settled arrival cannot repeat")
			var packet: Dictionary = bytes_to_var(Marshalls.base64_to_raw(arrival.field))
			for invalid in [{"phase":"active"},{"departed":false},{"p":m.field.layout.nodes[0].p+Vector2.RIGHT*140},{"v":Vector2.RIGHT}]:
				var damaged := packet.duplicate()
				damaged.merge(invalid,true)
				arrival.field = Marshalls.raw_to_base64(var_to_bytes(damaged))
				check(not clone.restore_payload(arrival) and clone.at_home(),region+" rejects forged pending arrival "+str(invalid.keys()))
		var near_gate = approaching(region,130.0,.01)
		near_gate.field.departed = false # Short trip or older save inside the outer departure marker.
		near_gate.entry_pressed = true
		near_gate.step(.05,Vector2.LEFT,false,false)
		var resumed = Model.new()
		check(near_gate.return_requested and resumed.restore_payload(near_gate.to_payload()) and resumed.return_requested,region+" short trip crosses the gate and saves a last-frame tap")
		var leaving = approaching(region,0.0,5.0)
		leaving.field.departed = false
		leaving.step(.05,Vector2.RIGHT,true,false)
		check(not leaving.return_requested,region+" holding collect on spawn does not turn the bee back")
		for outside in [true,false]:
			var m = approaching(region,150 if outside else 130,.01)
			m.step(.05,Vector2.LEFT,outside,false)
			check(m.at_home() and m.cargo.blue == 1 and m.materials.fiber == 1 and not m.return_requested,region+" ordinary rescue outside or without input")
			check(m.events.filter(func(e):return e.kind=="rescue").size()==1,region+" single rescue transaction")
	var late = approaching("pond",150,.3)
	late.entry_pressed = true
	late.step(.05,Vector2.LEFT,false,false)
	late.step(.1,Vector2.LEFT,false,false)
	check(late.field.at_entry() and not late.return_requested,"released tap cannot fire in a later frame")
