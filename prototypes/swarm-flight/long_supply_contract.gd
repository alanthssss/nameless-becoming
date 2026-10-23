extends RefCounted
## The same player rule applies to new catalogues: flight and supply stay together.
const Model = preload("res://long_journey_model.gd")
const Content = preload("res://long_journey_content.gd")
const Data = preload("res://chapter_data.gd")
const Driver = preload("res://route_driver.gd")

static func run(check: Callable) -> void:
	for level in Content.definitions():
		for encounter in level.encounters:
			for beat in encounter.beats:
				if beat.kind != "dew": continue
				check.call(beat.route_mode != "branch","Long journey supply never rewards abandoning flight")
				var point := Vector2(beat.x,beat.y)
				check.call(point in encounter.direct_route and point in encounter.alternate_route,"Both long-journey routes pass their supply")
	# Reproduce the reported lower relay and its mirrored upper relay. These
	# observation inputs do not use the content's authored reference route.
	for encounter_index in [0,4]:
		for bypass in [false,true]:
			for condition in ["passing","low-fixture"]:
				var model := Model.new()
				var entrance := Driver.new(model)
				entrance.wait_for_full = false
				var origin: float = model.chapter.encounters[encounter_index].start_x
				if encounter_index > 0:
					for frame in 12000:
						if model.p.x >= origin+180: break
						var input: Dictionary = entrance.next_input()
						model.step(input.direction,input.held,1.0/60)
				check.call(model.recoveries == 0 and entrance.error.is_empty(),"Shared-supply approach uses ordinary flight")
				if condition == "low-fixture":
					check.call(model.shelter_index_at(model.p) < 0,"Low fixture is outside automatic recovery")
					model.stamina = 40.0
				var route_y := (250.0 if encounter_index == 0 else 550.0)
				var bypass_y := (600.0 if encounter_index == 0 else 190.0)
				var points: Array = [Vector2(380,bypass_y),Vector2(1790,bypass_y)] if bypass else [Vector2(290,route_y),"burst",Vector2(1800,route_y)]
				points.append_array([Vector2(1900,420),Vector2(2060,420)])
				var driver := Driver.new(model)
				driver.stage = 0
				driver.wait_for_full = false
				for point in points:
					driver.commands.append({"kind":"burst","direction":Vector2.RIGHT} if point is String else Data.move_to(point+Vector2(origin,0)))
				var rings_before: int = model.rings_hit
				var refund := 0.0
				var picked := false
				var blocked := false
				var furthest_x: float = model.p.x
				var retreat := 0.0
				for frame in 3000:
					if driver.cursor >= driver.commands.size() or not driver.error.is_empty(): break
					var input: Dictionary = driver.next_input()
					furthest_x = maxf(furthest_x,model.p.x)
					model.events.clear()
					model.step(input.direction,input.held,1.0/60)
					retreat = maxf(retreat,furthest_x-model.p.x)
					for event in model.events:
						if event.kind in ["blocked","hit"]: blocked = true
						if event.kind == "dew":
							picked = event.pos == Vector2(origin+1900,420)
							refund += float(event.get("reward",0))
				var label := "%d bypass=%s %s" % [encounter_index,bypass,condition]
				check.call(picked and refund > 1.0,"Long shared supply restores real stamina after chosen action: "+label)
				if condition == "low-fixture": check.call(refund > 11.9,"Shared supply restores its full amount when needed: "+label)
				check.call(not blocked and retreat < 32 and model.recoveries == 0 and driver.error.is_empty() and driver.cursor == driver.commands.size(),"Long supply needs no backtrack, collision or recovery: "+label)
				check.call(model.rings_hit-rings_before == (0 if bypass else 3),"Long supply preserves the three-flower relay: "+label)
				print("LONG_SUPPLY: "+JSON.stringify({"case":label,"refund":refund,"retreat":retreat,"recoveries":model.recoveries}))

	migration(check)

static func migration(check: Callable) -> void:
	for stage in 2:
		var model := Model.new()
		model.load_stage(stage)
		var saved: Dictionary = model.save_payload()
		saved.journey_id = Content.PREVIOUS_ID
		var previous: Array = Content.previous_dew(stage)
		# Explicit old-save fixture: flags consumed on a branch stay consumed at
		# its new shared exit. Live and failure snapshots intentionally differ.
		previous[0].collected = true
		saved.state.dew = Model.pack(previous)
		saved.state.checkpoint.dew = Model.pack(Content.previous_dew(stage))
		saved.state.garden_awards[stage] = 1
		check.call(model.restore_payload(saved),"Previous content save migrates stage "+str(stage))
		check.call(model.dew[0].collected and not model.checkpoint.dew[0].collected,"Migration keeps live and failure pickup flags separate")
		check.call(model.stamina == 100 and model.p == Vector2(180,420) and model.time == 0,"Migration does not refill, move or advance clocks")
		var revised := model.save_payload()
		check.call(model.restore_payload(revised),"Migrated snapshot validates again")
		var malformed := saved.duplicate(true)
		malformed.state.dew[0].pos.v[0] += 30
		check.call(not model.restore_payload(malformed),"Old revision cannot bypass static pickup validation")
		check.call(model.save_payload() == revised,"Rejected migration leaves current state untouched")
