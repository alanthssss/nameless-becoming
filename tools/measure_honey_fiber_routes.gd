extends SceneTree
## Godot 4.6.2. A deterministic, known-route pilot, using the shipped regional model.
## Run --headless --main-pack Honey.pck --script /absolute/path/to/measure_honey_fiber_routes.gd. No save/UI access.
const Model = preload("res://region_game/model.gd")
const DT := 0.05
const ROUTES := [
	["near", 4, "base"],
	["bay", 0, "base"],
	["bay", 2, "base"],
	["bay", 4, "base"],
	["far", 0, "base"],
	["bay_far", 0, "base"],
	["bay", 4, "bag"],
	["bay", 4, "bag_wings"],
	["bay", 4, "gather"],
	["bay", 4, "gather_beat"],
	["middle_trial", 0, "base"],
	["middle_trial", 2, "base"],
	["middle_trial", 4, "base"],
]
const OWNED := {
	"base": [], "bag": ["bag1"], "bag_wings": ["bag1","wings1"],
	"gather": ["gather1"], "gather_beat": ["gather1","beat"],
}
var model
var field
var pulse_hits: int
var stop_reason: String

func tick(motion: Vector2, pulse := false, aim := Vector2.ZERO, collect := false) -> bool:
	model.step(DT, motion, collect, false, pulse, aim)
	for event in model.events:
		if event.kind == "pulse":
			pulse_hits += 1
	model.events.clear()
	if model.field == null:
		stop_reason = "exhausted"
		return false
	return true

func fly_to(point: Vector2, within := 18.0) -> bool:
	for frame in 300:
		if field.p.distance_to(point) <= within:
			return true
		if not tick(field.p.direction_to(point)):
			return false
	stop_reason = "navigation_timeout"
	return false

func take_tuft(index: int) -> bool:
	var source: Dictionary = field.materials[index]
	for frame in 360:
		if source.taken:
			return true
		var distance: float = field.p.distance_to(source.p)
		var motion := Vector2.ZERO
		if distance > 8:
			motion = field.p.direction_to(source.p)
		var aim: Vector2 = field.p.direction_to(source.anchor)
		if not tick(motion, distance < 140 and not source.dropped, aim):
			return false
	stop_reason = "material_timeout"
	return false

func gather_nearest_flowers(goal: int) -> bool:
	var visited: Array[int] = []
	while field.cargo < goal:
		var nearest: Dictionary = {}
		var distance := INF
		for flower in field.flowers:
			if flower.enabled and flower.stock > 0 and flower.id not in visited:
				var d: float = field.p.distance_to(flower.p)
				if d < distance:
					nearest = flower
					distance = d
		if nearest.is_empty():
			stop_reason = "no_flower"
			return false
		if not fly_to(nearest.p, 48):
			return false
		visited.append(nearest.id)
		var previous: int = field.cargo
		for frame in 60:
			if not tick(Vector2.ZERO, false, Vector2.ZERO, true):
				return false
			if field.cargo > previous:
				break
	return true

func follow_route(route: String, honey: int) -> bool:
	# Every route starts at the thin near-pond husk. The harvest quota is filled
	# immediately afterwards. Go to the physical gate and use the normal home transition.
	if not take_tuft(0) or not gather_nearest_flowers(honey):
		return false
	if route == "middle_trial":
		if not take_tuft(2):
			return false
	elif route != "near":
		var junction: Vector2 = field.layout.nodes[2].p
		if not fly_to(junction):
			return false
		if route in ["bay", "bay_far"]:
			if not take_tuft(2) or not fly_to(junction):
				return false
		if route in ["far", "bay_far"]:
			if not take_tuft(4) or not fly_to(junction):
				return false
	if route != "near" and not fly_to(field.layout.nodes[1].p,90):
		return false
	return fly_to(field.layout.nodes[0].p,116)

func measure(seed_value: int, route: String, goal: int, profile: String) -> Dictionary:
	model = Model.new()
	model.trip_index = seed_value - 1
	model.owned.assign(OWNED[profile])
	var departed: bool = model.transition_to("pond")
	assert(departed)
	field = model.field
	model.events.clear()
	pulse_hits = 0
	stop_reason = ""
	if route == "middle_trial":
		# Keep the same three live sources, crop phase, strength, yields and costs.
		# Relocate the pocket ear to the currently unused middle-corridor anchor.
		var middle: Vector2 = field.materials[1].anchor
		field.materials[2].anchor = middle
		field.materials[2].p = middle

	var returned := follow_route(route, goal)
	var energy: float = field.energy
	if returned:
		returned = model.transition_to("hub")
	var carried: int = model.cargo.blue
	var fiber: int = model.materials.fiber
	var coins_before: int = model.coins
	var sale := 0
	if model.at_home():
		sale = model.sell()
	assert(fiber == field.material_count and model.materials.fiber == fiber)
	assert(model.coins - coins_before == sale)
	if returned:
		assert(carried == field.cargo and sale == carried)
	elif stop_reason == "exhausted":
		assert(carried == floori(field.cargo * 0.5) and sale == carried)
	return {
		"seed": seed_value, "profile": profile, "route": route, "target_blue": goal,
		"safe_return": returned, "stop": stop_reason, "successful_pulses": pulse_hits,
		"harvested_blue": field.cargo, "carried_blue": carried, "fiber": fiber, "sale": sale,
		"gate_energy": snappedf(energy,0.01), "field_seconds": snappedf(field.elapsed,0.01),
	}

func _initialize() -> void:
	for seed_value in range(1,9):
		for route in ROUTES:
			print(JSON.stringify(measure(seed_value,route[0],route[1],route[2])))
	quit()
