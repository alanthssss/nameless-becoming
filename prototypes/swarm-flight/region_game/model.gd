extends "res://nectar_harvest_model.gd"
## The approved resource world with the existing courtyard economy.
## A canonical v5 home profile preserves its transaction validation; the field
## has a separate, bounded binary snapshot inside this versioned JSON envelope.
const Profile = preload("res://nectar_harvest_model.gd")
const Field = preload("res://region_greybox/model.gd")
const PROFILE_KEYS := ["coins","cargo","materials","owned","completed","trip_index","sold_total","rose_sold","visited_meadow"]
var field
var camera_offset := Vector2.ZERO
var last_trip := {}
var return_requested := false

func upgrade_defs() -> Array:
	return super.upgrade_defs().filter(func(d): return d.id != "shortcut")

func locked_reason(id: String) -> String:
	if id == "shortcut": return "这片花路没有近道"
	return super.locked_reason(id).replace("双簇采蜜或叶间近道：任选其一","先学会双簇采蜜")

func goal_text() -> String:
	return super.goal_text().replace("双簇采蜜或叶间近道 · 任选一项成长","学会双簇采蜜，为蜂巢准备储粮")

func rain_exposed() -> bool: return false

func interaction() -> String:
	if at_home(): return super.interaction()
	return "home" if field != null and field.at_entry() else ""

func update_camera() -> void:
	camera_offset = Vector2.ZERO if at_home() else Vector2(clampf(p.x-640,0,1400),clampf(p.y-400,-100,650))
	camera_x = camera_offset.x
	chapter.region = 1 if area == "meadow" else 0

func clear_controls() -> void:
	super.clear_controls()
	if field != null:
		field.charge = 0.0
		field.charging = false
		field._locked.clear()

func flower_point(flower: Dictionary) -> Vector2:
	return flower.p if flower.has("p") else super.flower_point(flower)

func transition_to(destination: String,via: String = "gate") -> bool:
	if via != "gate" or destination not in ["hub","pond","meadow"] or destination == area: return false
	if destination == "meadow" and "meadow" not in owned: return false
	var previous := area
	if at_home():
		if interaction() != "depart" or destination == "hub": return false
		trip_index += 1
		field = Field.new()
		field.configure("pond" if destination == "pond" else "violet",1,trip_index)
		field.stats.owned.assign(owned)
		field.energy = max_energy()
		field.cargo = cargo_total()
		area = destination
		phase = "field"
		if destination == "meadow": visited_meadow = true
		_sync_field()
		emit("depart",p,trip_index)
	else:
		if destination != "hub" or not field.at_entry(): return false
		last_trip = field.summary()
		last_trip.result = "returned"
		_return_home()
		emit("return",p,cargo_total())
		events[-1]["cargo"] = cargo.duplicate()
		events[-1]["materials"] = materials.duplicate()
	update_camera()
	emit("area_change",p)
	events[-1]["from"] = previous
	events[-1]["to"] = area
	return true

func _return_home() -> void:
	field = null
	area = "hub"
	phase = "home"
	p = HOME
	v = Vector2.ZERO
	energy = max_energy()
	burst_left = 0.0
	clear_controls()
	flowers = flower_layout(trip_index)
	creatures = Encounters.layout(trip_index)
	drops.clear()

func _sync_field() -> void:
	p = field.p
	v = field.v
	face = field.face
	energy = maxf(0,field.energy)
	charge = field.charge
	charging = field.charging
	burst_left = field.burst_left
	pulse_left = field.pulse_left
	pulse_action_left = field.pulse_flash
	field_time = field.elapsed
	flowers.clear()
	for f in field.flowers:
		var item: Dictionary = f.duplicate()
		item.id = str(f.id)
		item.region = 1 if area == "meadow" else 0
		item.type = "rose" if area == "meadow" else "blue"
		flowers.append(item)
	creatures.clear()
	for item in field.materials:
		creatures.append({"id":str(item.id),"pos":item.p,"region":1 if area == "meadow" else 0,"state":"rest" if Field.available(item) and not item.dropped else "gone"})
	harvesting_ids.clear()
	if field.last_action == "采蜜中":
		for id in field._locked: harvesting_ids.append(str(id))

func step(delta: float,move: Vector2,collect: bool,space_held: bool,pulse_held: bool = false,aim: Vector2 = Vector2.ZERO) -> void:
	if at_home():
		super.step(delta,move,collect,space_held,pulse_held,aim)
		update_camera()
		return
	if not is_finite(delta) or delta <= 0: return
	var remaining := minf(delta,0.1)
	while remaining > 0.00001 and field != null:
		var dt := minf(remaining,0.05)
		remaining -= dt
		var before_cargo: int = field.cargo
		var before_material: int = field.material_count
		var before_event: int = field.events.size()
		var before_burst: float = field.burst_left
		field.step(dt,move,collect,space_held,pulse_held,aim)
		cargo["blue" if area == "pond" else "rose"] += field.cargo-before_cargo
		materials["fiber" if area == "pond" else "resin"] += field.material_count-before_material
		_sync_field()
		if field.burst_left > before_burst: emit("dash",p)
		for i in range(before_event,field.events.size()):
			_translate_event(field.events[i])
		if cargo_total() >= capacity() and not _full_announced:
			emit("full",p,capacity())
			_full_announced = true
		if field.phase == "exhausted":
			last_trip = field.summary()
			field = null
			super._rescue()
			flowers = flower_layout(trip_index)
			creatures = Encounters.layout(trip_index)
		elif field.phase == "returned":
			field.phase = "active"
			return_requested = true
	update_camera()

func _translate_event(e: Dictionary) -> void:
	var kind: String = e.kind
	var at := p
	if int(e.id) >= 0:
		at = field.flowers[e.id].p if kind.begins_with("flower_") or kind == "nectar_picked" else field.materials[e.id].p
	if kind == "nectar_picked":
		emit("harvest",at,1)
		events[-1].type = "blue" if area == "pond" else "rose"
	elif kind == "material_picked":
		emit("material",at,1)
		events[-1].type = "fiber" if area == "pond" else "resin"
	elif kind == "material_hit":
		emit("pulse",p,1)
		events[-1].direction = face
		events[-1].to = at
	elif kind not in ["returned","exhausted"]:
		emit(kind,at,int(e.id))

func _profile() -> RefCounted:
	var result = Profile.new()
	for key in PROFILE_KEYS:
		if get(key) is Array or get(key) is Dictionary: result.set(key,get(key).duplicate(true))
		else: result.set(key,get(key))
	result.flowers = flower_layout(trip_index)
	result.creatures = Encounters.layout(trip_index)
	result.energy = result.max_energy()
	if at_home():
		result.p = p
		result.v = v
		result.face = face
	return result

func to_payload() -> Dictionary:
	var snapshot := ""
	if field != null:
		var state: Dictionary = field.snapshot()
		# Metrics are recorded separately; keep saves bounded during long visits.
		state.trace = []
		state.events = []
		snapshot = Marshalls.raw_to_base64(var_to_bytes(state))
	return {"id":"nectar-regions","version":1,"profile":_profile().to_payload(),"field":snapshot}

func restore_payload(data) -> bool:
	if not data is Dictionary or not keys_match(data,["id","version","profile","field"]): return false
	if data.id != "nectar-regions" or data.version != 1 or not data.field is String or data.field.length() > 180000: return false
	var next_profile = Profile.new()
	if not next_profile.restore_payload(data.profile) or not next_profile.at_home() or "shortcut" in next_profile.owned: return false
	var next_field
	if not data.field.is_empty():
		var decoded = bytes_to_var(Marshalls.base64_to_raw(data.field))
		next_field = Field.new()
		if not next_field.restore(decoded): return false
		if next_field.region == "violet" and ("meadow" not in next_profile.owned or not next_profile.visited_meadow): return false
		if next_profile.trip_index < 1 or next_field.trip_seed != next_profile.trip_index: return false
		if next_field.cargo != next_profile.cargo_total() or next_field.energy > next_profile.max_energy(): return false
		if next_field.v.length() > 500.01 or absf(next_field.face.length()-1.0) > 0.001: return false
		if next_field.charge > 0.32 or next_field.burst_left > 0.32 or (not next_field.charging and next_field.charge != 0): return false
		next_field.stats.owned.assign(next_profile.owned)
	for key in PROFILE_KEYS:
		if get(key) is Array: get(key).assign(next_profile.get(key))
		else: set(key,next_profile.get(key))
	field = next_field
	if field == null:
		area = "hub"
		phase = "home"
		p = next_profile.p
		v = next_profile.v
		face = next_profile.face
		energy = max_energy()
		flowers = flower_layout(trip_index)
		creatures = Encounters.layout(trip_index)
		burst_left = 0.0
		clear_controls()
	else:
		area = "pond" if field.region == "pond" else "meadow"
		phase = "field"
		_sync_field()
	return_requested = false
	events.clear()
	_full_announced = cargo_total() >= capacity()
	update_camera()
	return true
