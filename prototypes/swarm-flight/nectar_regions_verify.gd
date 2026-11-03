extends SceneTree
## Rule fixtures and real disk persistence, not independent human playtest evidence.
const Model = preload("res://nectar_harvest_model.gd")
const Encounters = preload("res://nectar_encounters.gd")
const Save = preload("res://save_data.gd")
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+label)
func tick(m,seconds: float,move := Vector2.ZERO) -> void:
	for i in int(round(seconds*60.0)): m.step(1.0/60.0,move,false,false)
func unlock(m) -> void:
	m.coins = 1000
	for id in ["gather1","bag1","gather2","meadow","shortcut"]: m.buy(id)
func depart(m,area := "pond") -> bool:
	m.p = Model.HUB_DEPART
	return m.transition_to(area)
func reject(m,data: Dictionary,label: String) -> void:
	var before: Dictionary = m.to_payload()
	check(not m.restore_payload(data) and m.to_payload() == before,"atomic rejection: "+label)

func run() -> void:
	var m = Model.new()
	check(m.area == "hub" and m.at_home() and m.creatures.all(func(c): return c.state == "gone"),"new hub contains no active population")
	for entry in [{"p":Model.HUB_SHOP,"action":"shop"},{"p":Model.HUB_TREE,"action":"tree"},{"p":Model.HUB_DEPART,"action":"depart"}]:
		m.p = entry.p
		check(m.interaction() == entry.action,"hub function is uniquely addressed: "+entry.action)
	m.p = Model.HOME
	check(m.interaction().is_empty() and not m.transition_to("pond"),"hub has no remote menu/exit trigger")
	m.step(0.1,Vector2.RIGHT,true,false)
	check(m.area == "hub" and m.energy == 85 and m.cargo_total() == 0 and m.trip_index == 0,"life scene neither collects nor spends expedition energy")
	m.p = Model.HUB_DEPART
	check(not m.transition_to("meadow") and m.trip_index == 0,"locked destination is denied without starting trip")
	check(m.transition_to("pond") and m.p == Model.POND_ENTRY and m.phase == "field" and m.trip_index == 1,"departure creates one explicit expedition")
	check(m.creatures.filter(func(c): return c.region == 0 and c.state != "gone").size() == 1 and m.creatures.filter(func(c): return c.region == 1 and c.state != "gone").size() == 2,"regional population caps are one scout and two guards")
	for c in m.creatures:
		check(not Encounters.safe_at("pond" if c.region == 0 else "meadow",c.anchor),"spawn anchor respects entrance safety: "+c.id)
	var far_before: Dictionary = m.creatures[1].duplicate(true)
	tick(m,1.0)
	check(m.creatures[1] == far_before,"inactive region population is frozen")
	check(m.interaction() == "home" and m.area == "pond","entry never automatically bounces back")
	m.p = m.flowers[0].pos
	check(m.interaction().is_empty(),"first flower collection cannot accidentally activate return gate")
	for frame in 120: m.step(1.0/60.0,Vector2.ZERO,true,false)
	check(m.cargo_total() == 10 and m.hurt_left == 0,"safe first source gives resources without an enemy attack")
	m.p = Model.POND_EXIT
	check(not m.transition_to("meadow") and m.area == "pond","walking to far gate cannot bypass upgrade")
	m.p = Model.POND_ENTRY
	check(m.transition_to("hub"),"field entry returns home")
	unlock(m)
	check(depart(m),"upgraded expedition starts")
	m.flowers[0].stock = 3
	m.creatures[0].state = "gone"
	m.energy = 63.0
	m.p = Model.POND_EXIT
	m.v = Vector2(100,0)
	m.charging = true
	m.charge = 0.2
	check(m.transition_to("meadow") and m.area == "meadow" and m.visited_meadow,"physical gate enters different unlocked area")
	check(m.energy == 63.0 and m.trip_index == 2 and m.flowers[0].stock == 3 and m.creatures[0].state == "gone","cross-region move preserves depletion, population and energy")
	check(m.v == Vector2.ZERO and not m.charging and m.charge == 0 and m.burst_left == 0,"scene transition clears movement, charge and burst")
	check(m.camera_x >= 1840 and m.camera_x <= 2240,"meadow uses its own camera bounds")
	m.p = Model.MEADOW_ENTRY
	check(m.transition_to("pond") and m.p == Model.POND_EXIT and m.energy == 63.0,"reverse gate preserves field expedition")
	m.p = Model.SHORTCUTS[0]
	check(m.use_shortcut() and m.area == "meadow" and m.p == Model.SHORTCUTS[1] and m.trip_index == 2,"near shortcut is actual scene travel")
	check(m.use_shortcut() and m.area == "pond" and m.energy == 63.0,"reverse shortcut grants no energy or refill")
	var path := "user://nectar-regions-%d.json" % OS.get_process_id()
	check(Save.write_payload(m.to_payload(),path,Model.new()),"depleted region state atomically saves")
	var cold = Model.new()
	check(cold.restore_payload(Save.read_payload(path,Model.new())) and cold.area == "pond" and cold.creatures[0].state == "gone" and cold.flowers[0].stock == 3,"cold resume retains region, driven-away enemy and depleted flowers")
	var saved_population: Array = Encounters.payload(cold.creatures)
	cold.step(0.0,Vector2.ZERO,true,false)
	check(Encounters.payload(cold.creatures) == saved_population and cold.trip_index == 2,"pause cannot reset or advance population")
	m.p = Model.POND_ENTRY
	check(m.transition_to("hub") and m.energy == m.max_energy() and m.cargo_total() == 10,"return restores energy and retains carried nectar")
	check(depart(m) and m.trip_index == 3 and m.flowers[0].stock == 12 and m.creatures[0].state == "patrol","only a new departure refreshes flowers and encounters")
	var c: Dictionary = m.creatures[0]
	m.p = c.anchor+Vector2(100,0)
	m.v = Vector2.ZERO
	tick(m,0.1)
	check(c.state == "warn" and c.timer > 0.5,"nearby creature visibly warns before chasing")
	var start_energy: float = m.energy
	tick(m,0.4)
	check(c.state == "warn" and m.hurt_left == 0 and m.energy > start_energy-1.0,"warning interval cannot inflict contact damage")
	tick(m,0.3)
	check(c.state == "chase","finished warning begins finite pursuit")
	m.p = Model.POND_ENTRY
	tick(m,0.1)
	check(c.state == "return" and not m.can_damage(c),"safe entrance immediately breaks chase")
	tick(m,2.0)
	check(c.state == "patrol" and c.pos.distance_to(c.anchor) < 45.0,"disengaged creature returns to its own habitat")
	c.state = "chase"
	c.timer = 0.02
	m.p = c.anchor+Vector2(120,0)
	tick(m,0.05)
	check(c.state == "return","chase duration ends even while target remains nearby")
	c.state = "chase"
	c.timer = 2.0
	c.pos = c.anchor
	m.p = c.pos
	m.energy = 80.0
	m.hurt_left = 0.0
	m.step(1.0/60.0,Vector2.ZERO,false,false)
	check(m.energy < 72.0 and m.energy > 71.9 and m.hurt_left == 1.5 and c.state == "return","ordinary contact removes exactly scout damage plus normal frame drain")
	c.state = "chase"
	c.timer = 2.0
	m.p = c.pos
	start_energy = m.energy
	m.step(1.0/60.0,Vector2.ZERO,false,false)
	check(m.energy > start_energy-0.1,"global protection prevents repeat contact damage")
	c.state = "chase"
	c.timer = 2.0
	m.p = c.pos-Vector2(10,0)
	m.face = Vector2.RIGHT
	m.burst_left = 0.01
	m.hurt_left = 0.0
	start_energy = m.energy
	var before_coins: int = m.coins
	var before_cargo: Dictionary = m.cargo.duplicate()
	m.step(1.0/60.0,Vector2.ZERO,false,false)
	check(c.state == "gone" and m.hurt_left == 0 and m.energy > start_energy-0.1,"dash final movement frame drives enemy away before damage")
	check(m.coins == before_coins and m.cargo == before_cargo,"driving away enemies never creates sale currency or cargo")
	tick(m,4.0)
	check(c.state == "gone","driven-away enemy never respawns during expedition")
	check(Model.new().restore_payload(m.to_payload()),"post-combat state satisfies strict persistence")
	var valid: Dictionary = m.to_payload()
	for key in ["area","creatures","hurt_left"]:
		var absent: Dictionary = valid.duplicate(true)
		absent.erase(key)
		reject(cold,absent,"missing "+key)
	for kind in ["area","phase","bounds","timer","anchor","count","state","face","hurt","extra","identity"]:
		var bad: Dictionary = valid.duplicate(true)
		match kind:
			"area": bad.area = "invented"
			"phase": bad.phase = "home"
			"bounds": bad.p = [3000.0,400.0]
			"timer": bad.creatures[0].timer = -1.0
			"anchor": bad.creatures[0].anchor[0] += 1.0
			"count": bad.creatures.pop_back()
			"state": bad.creatures[0].state = "attack_forever"
			"face": bad.creatures[0].face = [0.0,0.0]
			"hurt": bad.hurt_left = 99.0
			"extra": bad.creatures[0].extra = true
			"identity": bad.creatures[0].id = "mosquito_1"
		reject(cold,bad,kind)
	DirAccess.remove_absolute(path)
	print("NECTAR REGIONS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures > 0 else 0)
