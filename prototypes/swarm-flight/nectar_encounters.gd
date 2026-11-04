extends RefCounted
## Peaceful per-expedition wildlife; proximity and dash never inflict harm.
const STATES := ["patrol","gone"]
const WARN_TIME := 0.65
const CHASE_TIME := 2.2
const HURT_TIME := 1.5
const CONTACT_RADIUS := 38.0

static func layout(trip: int) -> Array[Dictionary]:
	var offset := 1 if trip % 2 == 0 else 0
	var anchors := [Vector2(1200+offset*100,420),Vector2(2420+offset*80,350),Vector2(3060-offset*80,510)]
	var result: Array[Dictionary] = []
	for i in 3:
		result.append({"id":"mosquito_"+str(i),"kind":"scout" if i == 0 else "guard","region":0 if i == 0 else 1,"anchor":anchors[i],"pos":anchors[i],"face":Vector2.LEFT,"state":"gone" if trip == 0 else "patrol","timer":0.0,"hits":0,"stun":0.0})
	return result

static func safe_at(area: String,position: Vector2) -> bool:
	if area == "hub": return true
	var gates := [Vector2(470,575),Vector2(1660,575)] if area == "pond" else [Vector2(1900,575)]
	for gate in gates:
		if position.distance_to(gate) < 220.0: return true
	return false

static func leash(creature: Dictionary) -> float:
	return 190.0 if creature.kind == "scout" else 230.0

static func step(model,dt: float,_dashing: bool) -> void:
	if model.area == "hub": return
	var region := 1 if model.area == "meadow" else 0
	for creature in model.creatures:
		if int(creature.region) != region or creature.state == "gone": continue
		creature.stun = maxf(0.0,float(creature.stun)-dt)
		if creature.stun > 0.0: continue
		var previous: Vector2 = creature.pos
		creature.state = "patrol"
		creature.timer = fmod(float(creature.timer)+dt,TAU)
		var target: Vector2 = creature.anchor+Vector2(sin(float(creature.timer))*34.0,cos(float(creature.timer)*2.0)*16.0)
		creature.pos = creature.pos.move_toward(target,50.0*dt)
		var movement: Vector2 = creature.pos-previous
		if not movement.is_zero_approx(): creature.face = movement.normalized()

static func payload(creatures: Array[Dictionary]) -> Array:
	var result: Array = []
	for creature in creatures:
		var data: Dictionary = creature.duplicate(true)
		for key in ["anchor","pos","face"]: data[key] = [creature[key].x,creature[key].y]
		result.append(data)
	return result

static func numeric(value) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func vector(value) -> bool:
	return value is Array and value.size() == 2 and numeric(value[0]) and numeric(value[1])

static func restore(data,trip: int) -> Array[Dictionary]:
	var none: Array[Dictionary] = []
	if not data is Array or data.size() != 3: return none
	var expected := layout(trip)
	for i in 3:
		var item = data[i]
		if not item is Dictionary or item.size() != expected[i].size(): return none
		for key in expected[i].keys():
			if not item.has(key): return none
		for key in ["id","kind","region"]:
			if item[key] != expected[i][key]: return none
		for key in ["anchor","pos","face"]:
			if not vector(item[key]): return none
		if Vector2(item.anchor[0],item.anchor[1]) != expected[i].anchor: return none
		if not numeric(item.hits) or item.hits != floor(item.hits) or item.hits < 0 or item.hits > 3: return none
		if not numeric(item.stun) or item.stun < 0.0 or item.stun > 0.42: return none
		if item.state == "patrol" and item.hits >= (2 if item.kind == "scout" else 3): return none
		if item.state == "gone" and item.stun != 0.0: return none
		if item.state not in STATES or not numeric(item.timer): return none
		var maximum := TAU if item.state == "patrol" else 0.0
		if item.timer < 0.0 or item.timer > maximum: return none
		if trip == 0 and item.state != "gone": return none
		var pos := Vector2(float(item.pos[0]),float(item.pos[1]))
		var face := Vector2(float(item.face[0]),float(item.face[1]))
		if pos.distance_to(expected[i].anchor) > leash(expected[i])+20.0 or absf(face.length()-1.0) > 0.001: return none
		expected[i].hits = int(item.hits)
		expected[i].stun = float(item.stun)
		expected[i].pos = pos
		expected[i].face = face
		expected[i].state = item.state
		expected[i].timer = float(item.timer)
	return expected
