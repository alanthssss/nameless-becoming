extends SceneTree
const Model = preload("res://weather_window_model.gd")
const LongModel = preload("res://long_journey_model.gd")
const Driver = preload("res://route_driver.gd")
const Save = preload("res://save_data.gd")
const Memory = preload("res://color_memory.gd")
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+label)

func fresh() -> Model:
	var m := Model.new()
	m.load_stage(0)
	return m

func roundtrip(m,label: String) -> void:
	var serialized := JSON.parse_string(JSON.stringify(m.save_payload(),"",true,true)) as Dictionary
	var restored := fresh()
	check(restored.restore_payload(serialized),"suspend accepted: "+label)
	check(restored.save_payload() == m.save_payload(),"exact live state and weather roundtrip: "+label)
	m.step(Vector2.RIGHT,false,1.0/60)
	restored.step(Vector2.RIGHT,false,1.0/60)
	check(restored.save_payload() == m.save_payload(),"same next input after resume: "+label)

func run() -> void:
	var idle := fresh()
	for i in 600: idle.step(Vector2.ZERO,false,1.0/60)
	check(idle.weather_phase == "dry" and idle.color_step == 0 and idle.drops.is_empty(),"idle before departure does not cycle weather or color")
	for alternative in [false,true]:
		var m := fresh()
		var driver := Driver.new(m,alternative)
		driver.wait_for_full = false
		var phases := {}
		var contacts := 0
		var hits := 0
		for frame in 9000:
			if m.phase != "playing": break
			var input: Dictionary = driver.next_input()
			m.events.clear()
			m.step(input.direction,input.held,1.0/60)
			for event in m.events:
				if event.kind == "blocked": contacts += 1
				if event.kind == "hit": hits += 1
			if not phases.has(m.weather_phase):
				phases[m.weather_phase] = true
				# Clone for the extra deterministic step so this does not steer the route.
				var probe := fresh()
				check(probe.restore_payload(m.save_payload()),"ordinary-route state can restore")
				roundtrip(probe,m.weather_phase)
			if not driver.error.is_empty() or m.recoveries > 0: break
		check(m.phase == "ending" and driver.error.is_empty(),"ordinary route reaches exit: "+str(alternative)+" "+driver.error+" at "+str(m.p))
		check(contacts == 0 and m.recoveries == 0,"route has no collision or forced recovery: "+str(alternative))
		check(phases.has("warning") and phases.has("rain") and phases.has("after"),"route experiences forecast, rain and clearing")
		check(m.color_step == 2 and m.drops.is_empty(),"exit commits the second color change and clears actual drops")
		if not alternative: check(hits == 0,"under-roof ordinary route is safe without dash or shield")
		print("WEATHER_ROUTE: "+JSON.stringify({"alternate":alternative,"time":m.time,"hits":hits,"contacts":contacts,"recoveries":m.recoveries,"phase":m.phase}))
		roundtrip(m,"ending")
	# Explicit weather-contact fixtures isolate a roof, exposed space and shield.
	for roof in [true,false]:
		var m := fresh()
		m.started = true
		m.weather_phase = "rain"
		m.warning_elapsed = Model.WARNING_SECONDS
		m.p = Vector2(1200 if roof else 1900,520)
		m.invulnerable = 0
		m.rain_fields[0].timer = 99.0
		m.drops.append({"pos":Vector2(m.p.x+17,280),"vel":Vector2(-25,350)})
		var before: float = m.stamina
		for i in 50: m.advance_rain(1.0/60)
		check((m.stamina == before) if roof else (m.stamina < before),"physical raindrop is blocked only by the visible roof: "+str(roof))
		check(m.rain_floor_at(1200) == 330 and m.rain_floor_at(1910) == 750,"visual rain clips at the same roof and leaves the gap exposed")
	var forecast := fresh()
	forecast.started = true
	forecast.p = Vector2(700,520)
	for i in 100: forecast.step(Vector2.ZERO,false,1.0/60)
	check(forecast.weather_phase == "warning" and forecast.drops.is_empty(),"forecast cannot damage before its full duration")
	roundtrip(forecast,"warning-midpoint")
	var rain := fresh()
	rain.started = true
	rain.p = Vector2(1500,520)
	for i in 180: rain.step(Vector2.ZERO,false,1.0/60)
	rain.save_checkpoint(rain.p)
	rain.color_step = 2
	rain.weather_phase = "after"
	rain.restore_checkpoint()
	check(rain.weather_phase == "warning" and rain.warning_elapsed == 0 and rain.color_step == 0,"retry rolls back color and gives a fresh forecast")
	roundtrip(rain,"retry")
	var bad := fresh()
	var before := bad.save_payload()
	var payload := before.duplicate(true)
	payload.environment = Model.pack({"scene_id":Model.WINDOW_ID,"phase":"after","warning_elapsed":0.0,"color_step":0})
	check(not bad.restore_payload(payload) and bad.save_payload() == before,"invalid color/weather rejected without mutation")
	var old := LongModel.new()
	old.load_stage(0)
	check(not bad.restore_payload(old.save_payload()) and not old.restore_payload(before),"sample and existing journey saves are isolated")
	for pair in [[3,"008080"],[9,"dc3c3c"],[15,"f5f5f5"],[21,"101420"]]:
		check(Memory.color_at(pair[0]).to_html(false) == pair[1],"original color anchor "+str(pair[0]))
	print("WEATHER WINDOW VERIFIED: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
