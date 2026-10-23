extends RefCounted
## SF-R14/R19: supply supports the next action on a shared route.
## These observation paths are independent of the production reference routes.
const Model = preload("res://game_model.gd")
const Data = preload("res://chapter_data.gd")
const Driver = preload("res://route_driver.gd")

static func cases() -> Array:
	return [
		{"stage":9,"boundary_stamina":50.0,"checkpoint":1,"encounter":2,"approach":Vector2(4070,360),"supply":Vector2(5190,420),"follow":[Vector2(5830,340),"burst",Vector2(6920,440)],
		"upper":[Vector2(4210,430),Vector2(4460,430),"burst",Vector2(5010,430),Vector2(5190,420)],
		"lower":[Vector2(4220,650),Vector2(5040,650),Vector2(5190,420)]},
		{"stage":12,"boundary_stamina":32.0,"checkpoint":0,"encounter":1,"approach":Vector2(2010,420),"supply":Vector2(3110,460),"follow":[Vector2(3910,420),Vector2(4630,420),Vector2(4760,460)],
		"upper":[Vector2(2030,250),"burst",Vector2(2890,250),Vector2(3110,460)],
		"lower":[Vector2(2120,580),Vector2(2950,580),Vector2(3110,460)]}
	]

static func commands(spec: Dictionary,lower: bool) -> Array:
	var result := [Data.move_to(spec.approach)]
	for point in (spec.lower if lower else spec.upper)+spec.follow:
		result.append({"kind":"burst","direction":Vector2.RIGHT} if point is String else Data.move_to(point))
	return result

static func run(check: Callable) -> void:
	# Inspect all authored branches, not just the three reported coordinates.
	# A branch's stamina pickup must be available on BOTH routes. This does not
	# outlaw the first level's optional excursion, or prescribe a pixel radius.
	for level in Data.definitions():
		for encounter in level.encounters:
			for beat in encounter.beats:
				if beat.kind != "dew": continue
				check.call(beat.route_mode != "branch","Stamina supply never rewards abandoning the encounter's flight action")
				if encounter.has("direct_route"):
					var point := Vector2(beat.x,beat.y)
					check.call(point in encounter.direct_route and point in encounter.alternate_route,"Both authored branches retain access to their stamina supply")
	var opening: Dictionary = Data.definitions()[4].encounters[0]
	check.call(not opening.beats.any(func(b): return b.kind == "dew"),"Full-stamina summer opening does not bait a branch with redundant supply")
	for spec in cases():
		for lower in [false,true]:
			for condition in ["passing","rested","low-fixture"]:
				var m = Model.new()
				m.load_stage(spec.stage)
				var entrance = Driver.new(m)
				for frame in 6000:
					if m.checkpoint_index >= spec.checkpoint: break
					var action: Dictionary = entrance.next_input()
					m.step(action.direction,action.held,1.0/60.0)
				check.call(m.checkpoint_index == spec.checkpoint and m.recoveries == 0,"Supply test reaches its preceding leaf by ordinary flight")
				if condition == "rested":
					for frame in 600: m.step(Vector2.ZERO,false,1.0/60.0)
				elif condition == "low-fixture":
					# Leave the real refill zone with ordinary input BEFORE setting
					# this explicit boundary fixture; the leaf must not refill it.
					var leave = Driver.new(m)
					leave.stage = m.stage
					leave.commands = [Data.move_to(spec.approach)]
					for frame in 600:
						if leave.cursor >= leave.commands.size(): break
						var action: Dictionary = leave.next_input()
						m.step(action.direction,action.held,1.0/60.0)
					check.call(m.shelter_index_at(m.p) < 0,"Low-stamina fixture starts outside automatic refill")
					m.stamina = spec.boundary_stamina
				var before_bursts: int = m.bursts
				var before_rings: int = m.rings_hit
				var driver = Driver.new(m)
				driver.stage = m.stage
				driver.commands = commands(spec,lower)
				var picked := false
				var before_next_action := false
				var refund := 0.0
				var furthest_x: float = m.p.x
				var retreat := 0.0
				var hit := false
				for frame in 2400:
					if driver.cursor >= driver.commands.size(): break
					var action: Dictionary = driver.next_input()
					furthest_x = maxf(furthest_x,m.p.x)
					m.events.clear()
					var energy_before: float = m.stamina
					m.step(action.direction,action.held,1.0/60.0)
					retreat = maxf(retreat,furthest_x-m.p.x)
					for event in m.events:
						if event.kind in ["blocked","hit"]: hit = true
						if event.kind == "dew":
							picked = true
							before_next_action = driver.cursor == (spec.lower.size() if lower else spec.upper.size())
							refund += m.stamina-energy_before
				var label := "%02d %s %s" % [spec.stage+1,"lower" if lower else "upper",condition]
				check.call(picked and before_next_action,"Supply is collected at the shared exit before the next action: "+label)
				check.call(refund > 5.0,"Shared supply has a real stamina deficit to fill: "+label)
				check.call(retreat < 32.0 and not hit and m.recoveries == 0 and driver.error.is_empty() and driver.cursor == driver.commands.size(),"Supply and following flight need no backtracking, collision or recovery: "+label)
				check.call(m.bursts == before_bursts+(0 if lower else 1)+(1 if spec.stage == 9 else 0),"Supply preserves the chosen flight or bypass action: "+label)
				if spec.stage == 12 and not lower:
					check.call(m.rings_hit == before_rings+1,"Winter flight reaches shared supply after using the counterwind flower")
				print("SUPPLY_ROUTE: "+JSON.stringify({"case":label,"refund":refund,"remaining":m.stamina,"picked_before_next_action":before_next_action,"maximum_retreat_pixels":retreat,"recoveries":m.recoveries}))
