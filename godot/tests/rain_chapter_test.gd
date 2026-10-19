extends SceneTree

const Model := preload("res://playtest/rain_route/route_model.gd")
const Driver := preload("res://tools/rain_calendar_driver.gd")


func _init() -> void:
	for site in range(Model.BUILD_SITES.size()):
		var dawns := walk_chapter(site)
		check_authored_lane(dawns[15], site)
		check_optional_rest(dawns[8], dawns[10])
		check_final_participation(dawns[14], dawns[15])
		check_world_cover(dawns[15], site)
	print("RAIN CHAPTER TEST PASSED: both full chapters and authored lanes, optional rest, actual five-bee participation, recovery, dawn reset, useful cover and controllable ending")
	quit()


func restored(dawn: Dictionary):
	var model = Model.new()
	assert(model.restore(JSON.parse_string(JSON.stringify(dawn))))
	return model


func walk_chapter(site: int) -> Dictionary:
	var game = Model.new()
	var dawns: Dictionary = {}
	for day in range(1, 16):
		assert(game.day == day and not game.day_finished)
		dawns[day] = game.dawn_state.duplicate(true)
		assert(game.final_visitors.is_empty(), "A new morning cannot inherit a previous day's participation")
		Driver.work(game, site)
		if day == 15:
			assert(game.final_party_ready(), "All five companions must actually reach the flower field")
			assert(game.final_visitors.size() == Model.COMPANION_COUNT)
		Driver.home(game)
		assert(game.day_finished, "Site %d must complete day %d using the actual work" % [site, day])
		assert(game.completed_days.size() == day)
		assert(game.events_done.size() == day)
		if day >= 3:
			assert(game.built_site == site, "The player's chosen roof must persist throughout the chapter")
		if day < 15:
			assert(game.next_day())
			game = restored(game.snapshot())
	assert(game.complete and not game.next_day())
	var finished: Dictionary = game.snapshot().duplicate(true)
	var copy = restored(finished)
	assert(copy.complete and copy.day_finished and copy.completed_days.size() == 15)
	assert(copy.built_site == site and copy.beetle_home and copy.cleared.size() == 3)
	assert(not copy.next_day() and copy.act() == "", "A completed checkpoint must not reopen or reward the final day")
	assert(copy.snapshot() == finished)
	return dawns


func check_authored_lane(final_dawn: Dictionary, site: int) -> void:
	var game = restored(final_dawn)
	assert(game.day == 15 and game.built_site == site)
	var lane: Array = [
		Model.HIVE, Vector2(1010, 760), Model.BUILD_SITES[0],
		Vector2(2470, 1080), Vector2(3160, 990), Model.FLOWERS
	] if site == 0 else [
		Model.HIVE, Vector2(900, 540), Vector2(1400, 420), Model.BUILD_SITES[1],
		Vector2(2450, 550), Vector2(2850, 640), Model.FLOWERS
	]
	# The slow driver flies every segment; no participant positions or progress are injected.
	# This proves the authored lane is usable, not that human players will avoid every spill.
	for point in lane:
		Driver.fly(game, point)
	assert(game.final_party_ready() and game.waiting_companion_points().is_empty())
	assert(game.act() == "load" and game.act() == "load" and game.cargo == 2)
	lane.reverse()
	for point in lane:
		Driver.fly(game, point)
	assert(game.home_companions() == Model.COMPANION_COUNT)
	assert(game.act() == "deliver")
	assert(game.day_delivered == 2 and game.day_spills == 0 and game.work_ready())
	assert(game.homecoming_time == 0 and not game.day_finished)
	assert(game.act() == "day_end" and game.complete)


func check_optional_rest(day_eight: Dictionary, day_ten: Dictionary) -> void:
	var direct = restored(day_eight)
	Driver.flowers(direct, 2)
	Driver.home(direct)
	assert(direct.day_finished and not direct.daily_done.has("rest"), "Day 8 permits actual delivery without a mandatory roof visit")
	var rested = restored(day_eight)
	Driver.flowers(rested, 2)
	Driver.fly(rested, rested.roof_position())
	# Controlled exposure isolates the retained rest benefit; this is not a playthrough observation.
	rested.rain_exposure = 3.0
	assert(rested.act() == "rest")
	assert(rested.cargo == 2 and rested.day_delivered == 0 and rested.rain_exposure == 0)
	Driver.home(rested)
	assert(rested.day_finished)
	var skipped_shadow = restored(day_ten)
	Driver.flowers(skipped_shadow, 1)
	Driver.home(skipped_shadow)
	assert(skipped_shadow.day_delivered == 1 and not skipped_shadow.day_finished, "Day 10 still requires learning the moving shelter")
	var shadow = restored(day_ten)
	Driver.flowers(shadow, 1)
	Driver.fly(shadow, shadow.SHELTERS[6])
	for frame in range(3600):
		var offset: Vector2 = shadow.moving_roof_position() - shadow.position
		shadow.step(1.0 / 60, offset.normalized() * minf(1, offset.length() / 50), true)
		if shadow.moving_hold >= 1.2:
			break
	assert(shadow.moving_hold >= 1.2 and shadow.cargo > 0)
	Driver.home(shadow)
	assert(shadow.day_finished and not shadow.daily_done.has("rest"), "Moving-shelter work must not add a second compulsory roof stop")


func place_bee(model, index: int, point: Vector2, waiting := false, joined := true) -> void:
	model.companions[index].position = point
	model.companions[index].waiting = waiting
	model.companions[index].joined = joined
	model.companions[index].grace = 0.0
	model.companions[index].exposure = 0.0


func check_final_participation(day_fourteen: Dictionary, day_fifteen: Dictionary) -> void:
	# Position fixtures below are deliberate rule counterexamples, not evidence of a real full journey.
	var earlier = restored(day_fourteen)
	earlier.position = Model.FLOWERS
	for index in range(Model.COMPANION_COUNT):
		place_bee(earlier, index, Model.FLOWERS + Vector2(index * 12, 0))
	earlier.step(1.0 / 60, Vector2.ZERO, true)
	assert(earlier.final_visitors.is_empty(), "Earlier foraging must not pre-credit the final journey")
	var solo = restored(day_fifteen)
	solo.position = Model.FLOWERS
	assert(solo.act() == "load" and solo.act() == "load")
	solo.position = Model.HIVE
	solo.act()
	assert(solo.day_delivered == 2 and solo.home_companions() == 5)
	assert(not solo.final_party_ready() and not solo.work_ready() and not solo.day_finished)
	assert(solo.homecoming_time < 0, "Cargo plus five bees at home cannot impersonate a shared round trip")
	assert(not solo.final_stage_hint().is_empty())
	var party = restored(day_fifteen)
	party.position = Model.FLOWERS
	for index in range(4):
		place_bee(party, index, Model.FLOWERS + Vector2(index * 12, 0))
	place_bee(party, 4, Model.FLOWERS + Vector2(180, 0), true)
	party.step(1.0 / 60, Vector2.ZERO, true)
	assert(party.final_visitors.size() == 4 and not party.final_visitors.has("4"))
	assert(not party.final_party_ready(), "A waiting bee near the field has not participated")
	place_bee(party, 4, Model.FLOWERS + Vector2(180, 0), false, false)
	party.step(1.0 / 60, Vector2.ZERO, true)
	assert(party.final_visitors.size() == 4, "An unjoined bee cannot be credited either")
	assert(party.act() == "load" and party.act() == "load")
	party.position = Model.HIVE
	for index in range(Model.COMPANION_COUNT):
		place_bee(party, index, Model.HIVE + Vector2.from_angle(index * TAU / 5) * 80)
	party.act()
	assert(party.day_delivered == 2 and party.home_companions() == 5 and not party.work_ready())
	var replay = restored(party.dawn_state)
	assert(replay.final_visitors.is_empty() and replay.day_delivered == 0)
	assert(replay.day == 15 and replay.built_site == party.built_site)
	# Recovery uses normal movement with the whole party, retaining the delivery already made.
	for point in Driver.safe_route(party):
		Driver.fly(party, point)
	assert(party.final_party_ready() and party.final_visitors.size() == 5)
	assert(party.day_delivered == 2 and not party.work_ready(), "The party must still return home")
	Driver.home(party, false)
	assert(party.work_ready())
	assert(party.act() == "deliver" and party.homecoming_time == 0 and not party.day_finished)
	var saved_visitors: Dictionary = party.final_visitors.duplicate()
	Driver.fly(party, Model.HIVE + Vector2(310, 0))
	assert(not party.day_finished and party.position.distance_to(Model.HIVE) > 250)
	assert(party.final_visitors == saved_visitors, "Leaving during the ending must not erase the completed journey")
	Driver.fly(party, Model.HIVE)
	assert(party.act() == "day_end" and party.complete)
	var count: int = party.completed_days.size()
	assert(party.act() == "" and party.completed_days.size() == count)
	var reset = restored(party.dawn_state)
	assert(reset.day == 15 and reset.final_visitors.is_empty() and not reset.complete)
	assert(reset.homecoming_time < 0 and reset.day_delivered == 0)


func unique_cover_point(improved, baseline, center: Vector2, radius: float) -> Vector2:
	# Search the existing footprint so natural shelters may change without hardcoding a test-only route.
	for dx in range(-int(radius) + 30, int(radius) - 29, 25):
		for dy in range(-int(radius) + 30, int(radius) - 29, 25):
			var point := center + Vector2(dx, dy)
			var interior := point.distance_to(center) < radius - 25
			for offset in [Vector2.ZERO, Vector2(20, 0), Vector2(-20, 0), Vector2(0, 20), Vector2(0, -20), Vector2(20, 20), Vector2(-20, -20), Vector2(-20, 20), Vector2(20, -20)]:
				interior = interior and improved.sheltered(point + offset) and not baseline.sheltered(point + offset)
			if interior:
				return point
	assert(false, "A persistent improvement must retain some real cover beyond pre-existing shelters")
	return center


func check_cover_exposure(improved, baseline, point: Vector2) -> void:
	for model in [improved, baseline]:
		model.position = point
		model.velocity = Vector2.ZERO
		place_bee(model, 0, point)
		model.companions[0].exposure = 1.0
		model.step(1.0 / 60, Vector2.ZERO, true)
	assert(improved.companions[0].exposure == 0.0, "The prepared place must shelter an actual companion")
	assert(baseline.companions[0].exposure > 1.0, "Without that improvement the same companion is exposed")


func check_world_cover(final_dawn: Dictionary, site: int) -> void:
	# Counterfactual flags are used only in memory to measure the consequence of earlier work.
	var roof = restored(final_dawn)
	var no_roof = restored(final_dawn)
	no_roof.built_site = -1
	var roof_point := unique_cover_point(roof, no_roof, Model.BUILD_SITES[site], Model.ROOF_RADII[site])
	check_cover_exposure(roof, no_roof, roof_point)
	var gutter = restored(final_dawn)
	var no_gutter = restored(final_dawn)
	no_gutter.cleared.clear()
	var dry_point := unique_cover_point(gutter, no_gutter, Vector2(2470, 1080), 215)
	check_cover_exposure(gutter, no_gutter, dry_point)
