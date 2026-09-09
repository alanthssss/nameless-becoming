extends SceneTree
const Model := preload("res://playtest/rain_route/route_model.gd")
const Driver := preload("res://tools/rain_calendar_driver.gd")

func _init() -> void:
	var game = Model.new()
	assert(not game.next_day(), "Unfinished work must not skip a day")
	for expected_day in range(1, 16):
		assert(game.day == expected_day and game.stage == int((expected_day - 1) / 5))
		assert(game.completed_days.size() == expected_day - 1)
		assert(not game.complete, "Three deliveries cannot end a fifteen-day term")
		if game.day != 3:
			game.act()
			assert(not game.day_finished, "Empty hive click must not complete a fresh day's work")
		Driver.work(game)
		Driver.home(game)
		assert(game.day_finished, "Day %d must be finishable through its actual mechanics" % expected_day)
		assert(game.events_done.size() == expected_day)
		var count: int = game.completed_days.size()
		game.act()
		assert(game.completed_days.size() == count, "Closing a day must be idempotent")
		if expected_day < 15:
			assert(game.next_day())
			var restored = Model.new()
			assert(restored.restore(JSON.parse_string(JSON.stringify(game.snapshot()))))
			assert(restored.day == game.day and restored.stage == game.stage and restored.built_site == game.built_site)
			assert(restored.pollinated.size() == game.pollinated.size() and restored.cleared.size() == game.cleared.size())
			game = restored
	assert(game.complete and game.day == 15 and game.completed_days.size() == 15)
	assert(game.home_companions() == 5 and game.beetle_home and game.pollinated.size() == 2)
	assert(not game.next_day())
	var bad: Dictionary = game.snapshot()
	bad.completed_days = [1, 3]
	var empty = Model.new()
	assert(not empty.restore(bad) and empty.day == 1, "Invalid calendar must not mutate a new run")
	var duplicate: Dictionary = game.snapshot()
	duplicate.pollinated = ["0", "0"]
	assert(not empty.restore(duplicate), "Duplicate world-state keys must be rejected")
	var fraction: Dictionary = game.snapshot()
	fraction.day = 14.5
	assert(not empty.restore(fraction), "Fractional days must be rejected")
	var water = Model.new()
	water.position = Vector2(990, 1020)
	Driver.fly(water, Vector2(1490, 1020))
	assert(water.position.x > 1480)
	var turn = Model.new()
	for frame in range(60):
		turn.step(1.0 / 60, Vector2.LEFT, false)
	assert(absf(angle_difference(turn.heading, PI)) < 0.05)
	var last_heading: float = turn.heading
	turn.step(0.3, Vector2.ZERO, true)
	assert(turn.heading == last_heading)
	print("RAIN ROUTE TEST PASSED: fifteen actual days, 5/5/5 pentads, persistent world, dawn restore, distinct work and six-bee completion")
	quit()
