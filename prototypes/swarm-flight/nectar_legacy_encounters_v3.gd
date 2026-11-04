extends RefCounted
## Frozen v3 encounter schema for validating old saves before migration.
const STATES := ["patrol","warn","chase","return","gone"]
const WARN_TIME := 0.65
const CHASE_TIME := 2.2
const HURT_TIME := 1.5
const CONTACT_RADIUS := 38.0

static func layout(trip: int) -> Array[Dictionary]:
	var offset := 1 if trip % 2 == 0 else 0
	var anchors := [Vector2(1200+offset*100,420),Vector2(2420+offset*80,350),Vector2(3060-offset*80,510)]
	var result: Array[Dictionary] = []
	for i in 3:
		result.append({"id":"mosquito_"+str(i),"kind":"scout" if i == 0 else "guard","region":0 if i == 0 else 1,"anchor":anchors[i],"pos":anchors[i],"face":Vector2.LEFT,"state":"gone" if trip == 0 else "patrol","timer":0.0})
	return result

static func safe_at(area: String,position: Vector2) -> bool:
	if area == "hub": return true
	var gates := [Vector2(470,575),Vector2(1660,575)] if area == "pond" else [Vector2(1900,575)]
	for gate in gates:
		if position.distance_to(gate) < 220.0: return true
	return false

static func leash(creature: Dictionary) -> float:
	return 190.0 if creature.kind == "scout" else 230.0

static func step(model,dt: float,dashing: bool) -> void:
	if model.area == "hub": return
	var region := 1 if model.area == "meadow" else 0
	for creature in model.creatures:
		if int(creature.region) != region or creature.state == "gone": continue
		var previous: Vector2 = creature.pos
		var player_distance: float = creature.pos.distance_to(model.p)
		var safe: bool = safe_at(model.area,model.p)
		var within_leash: bool = model.p.distance_to(creature.anchor) <= leash(creature)
		if creature.state in ["warn","chase"] and (safe or not within_leash):
			creature.state = "return"
			creature.timer = 0.0
		if creature.state == "patrol":
			creature.timer = fmod(float(creature.timer)+dt,TAU)
			var target: Vector2 = creature.anchor+Vector2(sin(float(creature.timer))*34.0,cos(float(creature.timer)*2.0)*16.0)
			creature.pos = creature.pos.move_toward(target,50.0*dt)
			var notice := 145.0 if creature.kind == "scout" else 175.0
			if not safe and within_leash and player_distance <= notice:
				creature.state = "warn"
				creature.timer = WARN_TIME
				model.emit("warn",creature.pos)
		elif creature.state == "warn":
			creature.timer = maxf(0.0,float(creature.timer)-dt)
			var direction: Vector2 = model.p-creature.pos
			if not direction.is_zero_approx(): creature.face = direction.normalized()
			if creature.timer <= 0.0:
				creature.state = "chase"
				creature.timer = CHASE_TIME
		elif creature.state == "chase":
			creature.timer = maxf(0.0,float(creature.timer)-dt)
			creature.pos = creature.pos.move_toward(model.p,(145.0 if creature.kind == "scout" else 185.0)*dt)
			if creature.timer <= 0.0:
				creature.state = "return"
		elif creature.state == "return":
			creature.pos = creature.pos.move_toward(creature.anchor,160.0*dt)
			if creature.pos.distance_to(creature.anchor) <= 1.0:
				creature.pos = creature.anchor
				creature.state = "patrol"
				creature.timer = 0.0
		var movement: Vector2 = creature.pos-previous
		if not movement.is_zero_approx(): creature.face = movement.normalized()
		if creature.pos.distance_to(model.p) > CONTACT_RADIUS: continue
		# A dash always wins over damage, including its final movement frame.
		if dashing:
			creature.state = "gone"
			creature.timer = 0.0
			model.emit("repel",creature.pos)
			model.events[-1]["id"] = creature.id
		elif model.can_damage(creature):
			var amount := 8 if creature.kind == "scout" else 12
			model.energy = maxf(0.0,model.energy-amount)
			model.hurt_left = HURT_TIME
			creature.state = "return"
			creature.timer = 0.0
			model.emit("hurt",model.p,amount)

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
		if item.state not in STATES or not numeric(item.timer): return none
		var maximum := TAU if item.state == "patrol" else WARN_TIME if item.state == "warn" else CHASE_TIME if item.state == "chase" else 0.0
		if item.timer < 0.0 or item.timer > maximum: return none
		if trip == 0 and item.state != "gone": return none
		var pos := Vector2(float(item.pos[0]),float(item.pos[1]))
		var face := Vector2(float(item.face[0]),float(item.face[1]))
		if pos.distance_to(expected[i].anchor) > leash(expected[i])+20.0 or absf(face.length()-1.0) > 0.001: return none
		expected[i].pos = pos
		expected[i].face = face
		expected[i].state = item.state
		expected[i].timer = float(item.timer)
	return expected
