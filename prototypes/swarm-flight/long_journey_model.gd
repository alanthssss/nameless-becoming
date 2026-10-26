extends "res://game_model.gd"
## Suspend is a frozen live state; checkpoint recovery remains a separate action.
const Content = preload("res://long_journey_content.gd")
const SAVE_PATH := "user://summer_long_07_08_r7.json"
const FIELDS := ["phase","p","velocity","face","charge","charging","burst_left","burst_braking","bees","stamina","energy_spent","energy_gained","rain_remaining","invulnerable","shield_left","shield_feedback_left","hazard_clock","time","camera_x","storm_x","storm_active","completed","exit_ready","bursts","recoveries","rings_hit","wind_chain","sample_approach","rain_timer","checkpoint_index","started","blocked_cooldown","garden_awards","checkpoint","pods","walls","rings","shelters","dew","sprayers","shields","rain_fields","drops","puffs"]
const DYNAMIC := {"pods":["open"],"walls":["broken"],"rings":["active"],"shelters":["reached"],"dew":["collected"],"sprayers":["timer","stun_left","flash","rewarded"],"shields":["collected"],"rain_fields":["timer"]}

func build_stage(index: int) -> Dictionary:
	return Content.build(index)

func last_stage_index() -> int:
	return 1

func record_sample_approach(before: Vector2) -> void:
	if stage != 0 or checkpoint_index >= 0 or p.x <= before.x: return
	var r: Rect2 = walls[0].rect
	if before.x < r.end.x and p.x >= r.end.x:
		var crossing_y := lerpf(before.y,p.y,(r.end.x-before.x)/(p.x-before.x))
		if crossing_y < r.position.y: sample_approach = "top"
		elif crossing_y > r.end.y: sample_approach = "bottom"

func advance_shelters() -> void:
	# Resting is optional. Crossing the leaf's station records a safe recovery
	# point even when the chosen flight line passes above or below its canopy.
	# Ordinary leaf contact still restores stamina through the base rules.
	super.advance_shelters()
	var next := checkpoint_index+1
	if next >= shelters.size() or p.x < shelters[next].pos.x: return
	if not section_cleared(next): return
	shelters[next].reached = true
	checkpoint_index = next
	rain_remaining = sections[mini(next+1,sections.size()-1)].budget
	save_checkpoint(shelters[next].pos)
	emit("checkpoint",shelters[next].pos)

func journey_dew_total() -> int:
	return Content.build(0).dew.size()+Content.build(1).dew.size()

func save_payload() -> Dictionary:
	var state := {}
	for key in FIELDS: state[key] = pack(get(key))
	return {"version":1,"journey_id":Content.JOURNEY_ID,"stage":stage,"completed":completed,"state":state,"rng_state":str(rng.state)}

static func pack(value):
	if value is float:
		var bytes := PackedByteArray()
		bytes.resize(8)
		bytes.encode_double(0,value)
		return {"f":bytes.hex_encode()}
	if value is Vector2: return {"v":[value.x,value.y]}
	if value is Rect2: return {"r":[value.position.x,value.position.y,value.size.x,value.size.y]}
	if value is Array:
		var out := []
		for item in value: out.append(pack(item))
		return out
	if value is Dictionary:
		var out := {}
		for key in value: out[key] = pack(value[key])
		return out
	return value

static func number(value) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and absf(float(value)) < 100000000.0

static func unpack(value,depth := 0):
	if depth > 12: return null
	if value is Dictionary:
		if value.size() == 1 and value.has("f"):
			if not value.f is String or value.f.length() != 16 or not value.f.is_valid_hex_number(): return null
			var bytes: PackedByteArray = value.f.hex_decode()
			if bytes.size() != 8: return null
			var n := bytes.decode_double(0)
			return n if number(n) else null
		if value.size() == 1 and (value.has("v") or value.has("r")):
			var key := "v" if value.has("v") else "r"
			var coords = value[key]
			if not coords is Array or coords.size() != (2 if key == "v" else 4): return null
			for n in coords:
				if not number(n): return null
			return Vector2(coords[0],coords[1]) if key == "v" else Rect2(coords[0],coords[1],coords[2],coords[3])
		var out := {}
		for key in value:
			out[key] = unpack(value[key],depth+1)
			if out[key] == null: return null
		return out
	if value is Array:
		if value.size() > 512: return null
		var out := []
		for item in value:
			var decoded = unpack(item,depth+1)
			if decoded == null: return null
			out.append(decoded)
		return out
	if value is String: return value if value.length() < 1024 else null
	if value is bool: return value
	return value if number(value) else null

static func same_shape(value,template) -> bool:
	if template is int: return number(value) and float(value) == floor(float(value))
	if template is float: return number(value)
	if typeof(value) != typeof(template): return false
	if template is Array:
		if value.size() != template.size(): return false
		for i in template.size():
			if not same_shape(value[i],template[i]): return false
	if template is Dictionary:
		if value.size() != template.size(): return false
		for key in template:
			if not value.has(key) or not same_shape(value[key],template[key]): return false
	return true

static func typed_copy(value,template):
	if template is int: return int(value)
	if template is float: return float(value)
	if template is Dictionary:
		var out := {}
		for key in template: out[key] = typed_copy(value[key],template[key])
		return out
	if template is Array:
		var out := []
		for i in value.size(): out.append(typed_copy(value[i],template[i]))
		return out
	return value

func valid_objects(values: Dictionary,reference: Dictionary) -> bool:
	for key in DYNAMIC:
		if not values.has(key): continue
		if not same_shape(values[key],reference[key]): return false
		for i in reference[key].size():
			for field in reference[key][i]:
				if field not in DYNAMIC[key] and values[key][i][field] != reference[key][i][field]: return false
	return true

func valid_checkpoint(saved: Dictionary) -> bool:
	if not same_shape(saved,checkpoint): return false
	if not valid_objects(saved,checkpoint): return false
	if saved.checkpoint_index < -1 or saved.checkpoint_index >= shelters.size(): return false
	if not valid_position(saved.p) or saved.bees != chapter.base_bees: return false
	for i in saved.shelters.size():
		if saved.shelters[i].reached != (i <= saved.checkpoint_index): return false
	return true

func valid_position(point: Vector2) -> bool:
	return point.x >= 0 and point.x <= world_width+100 and point.y >= 60 and point.y <= 750

func valid_state(state: Dictionary) -> bool:
	if state.size() != FIELDS.size(): return false
	for key in FIELDS:
		if not state.has(key): return false
		if key not in ["drops","puffs"] and not same_shape(state[key],get(key)): return false
	var reference := {}
	for key in DYNAMIC: reference[key] = get(key)
	if not valid_objects(state,reference) or not valid_checkpoint(state.checkpoint): return false
	if not valid_position(state.p) or state.velocity.length() > 2000 or state.face.length() > 1.01: return false
	if state.stamina < 0 or state.stamina > MAX_STAMINA or state.charge < 0 or state.charge > 1: return false
	if state.burst_left < 0 or state.burst_left > 1 or state.shield_left < 0 or state.shield_left > SHIELD_SECONDS: return false
	if state.checkpoint_index != state.checkpoint.checkpoint_index or state.bees != chapter.base_bees: return false
	if state.phase not in ["playing","transition","ending"]: return false
	if state.completed != (state.phase == "ending") or (state.phase == "ending" and stage != 1) or (state.phase == "transition" and stage != 0): return false
	if state.storm_active or state.sample_approach not in ["","top","bottom"]: return false
	for key in ["time","hazard_clock","energy_spent","energy_gained","rain_remaining","invulnerable","shield_feedback_left","bursts","recoveries","rings_hit","wind_chain","rain_timer","blocked_cooldown"]:
		if state[key] < 0: return false
	var collected := 0
	for item in state.dew:
		if item.collected: collected += 1
	if state.garden_awards[stage] != collected: return false
	for i in state.garden_awards.size():
		var maximum := 0
		if i < 2:
			maximum = Content.build(i).dew.size()
		if state.garden_awards[i] < 0 or state.garden_awards[i] > maximum: return false
	for i in state.shelters.size():
		if state.shelters[i].reached != (i <= state.checkpoint_index): return false
	if state.phase != "playing" and state.checkpoint_index != shelters.size()-1: return false
	for key in ["drops","puffs"]:
		if not state[key] is Array or state[key].size() > 256: return false
		var shape := {"pos":Vector2.ZERO,"vel":Vector2.ZERO} if key == "drops" else {"pos":Vector2.ZERO,"vel":Vector2.ZERO,"life":0.0,"source":0}
		for item in state[key]:
			if not same_shape(item,shape): return false
			if item.pos.x < -2000 or item.pos.x > world_width+2000 or absf(item.pos.y) > 2000 or item.vel.length() > 2000: return false
			if key == "puffs" and (item.source < 0 or item.source >= sprayers.size() or item.life < 0 or item.life > 4): return false
	return true

func restore_payload(data: Dictionary) -> bool:
	if not data.get("journey_id") is String or not number(data.get("version")): return false
	# Geometry is reauthored. Old r1/r2/r3 files remain with their original build.
	if data.journey_id != Content.JOURNEY_ID or data.version != 1: return false
	if not number(data.get("stage")) or (float(data.stage) != floor(float(data.stage)) or int(data.stage) not in [0,1]): return false
	if not data.get("rng_state") is String or not data.rng_state.is_valid_int() or str(int(data.rng_state)) != data.rng_state: return false
	var state = unpack(data.get("state"))
	if not state is Dictionary: return false
	# Validate on a fresh model so malformed files cannot partially mutate live play.
	var probe = get_script().new()
	probe.load_stage(int(data.stage))
	if not data.get("completed") is bool: return false
	if not probe.valid_state(state) or data.completed != state.completed: return false
	load_stage(int(data.stage))
	for key in FIELDS:
		if key not in ["drops","puffs"]: state[key] = typed_copy(state[key],get(key))
		elif key == "puffs":
			for item in state.puffs: item.source = int(item.source)
		if get(key) is Array: get(key).assign(state[key])
		else: set(key,state[key])
	rng.state = int(data.rng_state)
	events.clear()
	return true
