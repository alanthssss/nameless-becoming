extends SceneTree

const Model := preload("res://playtest/rain_route/route_model.gd")
var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func fly(model, destination: Vector2, brake := false) -> void:
	for frame in range(1800):
		var offset: Vector2 = destination - model.position
		if offset.length() < 9.0:
			break
		model.step(1.0 / 60.0, offset.normalized() * minf(1, offset.length() / 50.0), brake)
	check((model.position as Vector2).distance_to(destination) < 15.0, "Route waypoint must be reachable: %s" % destination)
	for frame in range(45):
		model.step(1.0 / 60.0, Vector2.ZERO, true)

func outward(model) -> void:
	for waypoint in Model.SAFE_ROUTE:
		fly(model, waypoint)

func homeward(model) -> void:
	var points: Array = Model.SAFE_ROUTE.duplicate()
	points.reverse()
	for waypoint in points:
		fly(model, waypoint, true)

func _init() -> void:
	var light = Model.new()
	var heavy = Model.new()
	heavy.cargo = 3
	for frame in range(15):
		light.step(1.0 / 60, Vector2.RIGHT, false)
		heavy.step(1.0 / 60, Vector2.RIGHT, false)
	check(light.position.x > heavy.position.x + 5, "Heavy cargo must change real acceleration")
	check(heavy.maximum_speed() < light.maximum_speed(), "Heavy cargo must change cruising speed")
	var rain = Model.new()
	rain.cargo = 2
	rain.position = Vector2(1800, 550)
	for frame in range(610):
		rain.step(1.0 / 60, Vector2.ZERO, true)
	check(rain.cargo < 2 and not rain.drops.is_empty(), "Rain must spill exactly one recoverable cargo")
	rain.position = rain.drops[-1]
	check(rain.act() == "recover" and rain.cargo > 0, "Dropped cargo must be collectible")
	var safe = Model.new()
	safe.cargo = 3
	safe.position = Model.SHELTERS[3]
	for frame in range(300):
		safe.step(1.0 / 60, Vector2.ZERO, true)
	check(safe.cargo == 3 and safe.spills == 0, "Real canopy must protect cargo across rain cycles")
	var game = Model.new()
	check(not game.sheltered(Model.BUILD_SITE), "Central shelter must not exist before delivery")
	game.act()
	check(game.delivered == 0, "Empty handoff cannot advance construction")
	for trip in range(3):
		outward(game)
		for load_index in range(4):
			game.act()
		check(game.cargo == 3, "Loading must cap at three without auto-return")
		check(game.delivered == trip * 3, "Loading alone cannot count as delivered")
		if trip == 2:
			for frame in range(90):
				game.step(1.0 / 60, Vector2.ZERO, true)
			check(game.companions.size() == 3, "Final trip must expose three real companions")
		homeward(game)
		game.act()
		check(game.delivered == (trip + 1) * 3, "Safe route must deliver all cargo")
		if trip == 0:
			check(game.sheltered(Model.BUILD_SITE), "First handoff must alter real shelter geometry")
		if trip == 1:
			check(not game.complete, "Enough early cargo cannot skip the final convoy")
	check(game.complete and game.home_companions() == 3, "Three full real routes must end with all companions at home")
	var delivery_count: int = game.deliveries
	game.act()
	check(game.deliveries == delivery_count, "Completion must not duplicate delivery")
	var delayed = Model.new()
	delayed.stage = 2
	delayed.delivered = 9
	delayed.companions.append({"position": Model.FLOWERS, "waiting": true, "joined": true, "exposure": 0.0, "grace": 0.0})
	delayed.act()
	check(not delayed.complete, "Missing companions must block completion even with sufficient cargo")
	delayed.position = Model.FLOWERS
	delayed.step(1.0 / 60, Vector2.ZERO, true)
	check(not delayed.companions[0].waiting and delayed.rescues == 1, "Slow proximity must rescue a waiting companion")
	var turning = Model.new()
	for frame in range(60):
		turning.step(1.0 / 60, Vector2.LEFT, false)
	check(absf(angle_difference(turning.heading, PI)) < 0.05, "Left flight must turn the head left")
	var held_heading: float = turning.heading
	turning.step(0.2, Vector2.ZERO, true)
	check(is_equal_approx(held_heading, turning.heading), "Braking must retain heading")
	check(turning.raining(Vector2(700, 500)) and turning.raining(Vector2(3000, 500)), "Distant exposed points share regional rainfall")
	check(turning.blocked(Vector2(Model.PONDS[0].x, Model.PONDS[0].y)), "Map ponds must affect traversal")
	var freshly_started = Model.new()
	check(freshly_started.delivered == 0 and freshly_started.companions.is_empty() and not freshly_started.complete, "Restart must reset the whole experimental run")
	if failures == 0:
		print("RAIN ROUTE TEST PASSED: physics, rain, recovery, construction, full safe-route traversal, convoy and completion")
	quit(1 if failures else 0)
