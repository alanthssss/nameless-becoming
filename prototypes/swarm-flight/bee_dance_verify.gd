extends SceneTree
const Model = preload("res://bee_dance_model.gd")
const Long = preload("res://long_journey_model.gd")
const Weather = preload("res://weather_window_model.gd")
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
func frames(m,count: int,d := Vector2.ZERO,held := false) -> void:
	for i in count: m.step(d,held,1.0/60)
func fly(m,target: Vector2,held := false) -> void:
	for i in 1500:
		var delta: Vector2 = target-m.p
		if delta.length() < 10: break
		var d := Vector2(signf(delta.x) if absf(delta.x)>6 else 0.0,signf(delta.y) if absf(delta.y)>6 else 0.0).normalized()
		m.step(d,held,1.0/60)
	frames(m,24,Vector2.ZERO,held)
func prepared() -> Model:
	var m := fresh()
	fly(m,Model.SOURCE)
	frames(m,60)
	check(m.observation_valid(),"ordinary flight and settled feeding creates source fact")
	fly(m,Model.COMB)
	check(m.perched,"ordinary flight can land on wax")
	return m
func start_share(m) -> void:
	frames(m,2,Vector2.ZERO,true)
	check(m.share_state == "armed","fresh press arms sharing")
	frames(m,1)
	check(m.share_state == "dancing","release begins one dancer")
func roundtrip(m,label: String,d := Vector2.ZERO,held := false) -> void:
	var expected: Dictionary = m.save_payload()
	var restored := fresh()
	var json: Dictionary = JSON.parse_string(JSON.stringify(expected,"",true,true))
	check(restored.restore_payload(json),"valid snapshot "+label)
	check(restored.save_payload() == expected,"exact JSON snapshot "+label)
	var original := fresh()
	original.restore_payload(expected)
	original.step(d,held,1.0/60)
	restored.step(d,held,1.0/60)
	check(restored.save_payload() == original.save_payload(),"same next input "+label)
func run() -> void:
	var skipped := fresh()
	fly(skipped,Model.COMB)
	frames(skipped,30,Vector2.ZERO,true)
	frames(skipped,30)
	check(skipped.message_revision == 0 and skipped.share_state == "idle","no observed source cannot report")
	fly(skipped,skipped.exit_pos+Vector2(45,0))
	check(skipped.phase == "ending","sharing is optional, ordinary exit remains open")
	roundtrip(skipped,"optional ending")
	var early := fresh()
	fly(early,Model.SOURCE)
	frames(early,1,Vector2.RIGHT)
	check(early.observation.is_empty(),"brief contact is not a source observation")
	var m := prepared()
	var before_bees: int = m.bees
	var before_awards: int = m.garden_total()
	frames(m,2,Vector2.ZERO,true)
	roundtrip(m,"armed",Vector2.ZERO,true)
	frames(m,1)
	frames(m,30)
	roundtrip(m,"first segment")
	frames(m,1,Vector2.UP)
	check(m.message_revision == 0 and m.share_state == "idle" and m.listeners[0].state == "waiting","movement before full segment cancels without recruitment")
	fly(m,Model.COMB)
	start_share(m)
	frames(m,72)
	check(m.message_revision == 1 and m.listeners[0].state == "departing" and m.listeners[1].state == "departing","full first segment commits once")
	check(m.listeners[0].delay < m.listeners[1].delay,"listeners depart at different times")
	roundtrip(m,"committed stagger")
	frames(m,1,Vector2.UP)
	check(m.share_state == "idle" and m.message_revision == 1,"leaving after commit preserves fact")
	frames(m,80)
	roundtrip(m,"listeners in flight")
	check(m.listeners[0].pos.x < Model.COMB.x-100,"listeners really fly toward source world coordinates")
	frames(m,260)
	check(m.listeners[0].state == "foraging" and m.listeners[1].state == "foraging","both arrive at actual source")
	fly(m,Model.COMB)
	frames(m,50,Vector2.ZERO,true)
	frames(m,180)
	check(m.listeners.size()==2 and m.listeners[0].state=="foraging" and m.share_state=="idle" and m.bees==before_bees and m.garden_total()==before_awards,"repeated report cannot duplicate bees, awards or dance")
	roundtrip(m,"repeat")
	for when in ["armed","before_commit","after_commit","foraging"]:
		var expiring := prepared()
		frames(expiring,2,Vector2.ZERO,true)
		if when != "armed": frames(expiring,1)
		if when == "before_commit": frames(expiring,25)
		if when == "after_commit": frames(expiring,90)
		if when == "foraging": frames(expiring,390)
		expiring.invalidate_source()
		check(not expiring.observation_valid() and expiring.share_state=="idle","source content revision invalidates "+when)
		roundtrip(expiring,"expired "+when)
		frames(expiring,600)
		check(expiring.listeners[0].state=="waiting" and expiring.listeners[1].state=="waiting","expired source receives no continuing foragers "+when)
	var held_arrival := fresh()
	fly(held_arrival,Model.SOURCE)
	frames(held_arrival,60)
	fly(held_arrival,Model.COMB,true)
	check(held_arrival.perched and held_arrival.share_state=="idle","holding flight Space into landing is not a new sharing press")
	frames(held_arrival,1)
	check(held_arrival.message_revision==0 and held_arrival.burst_left==0,"release of old flight press neither shares nor launches on wax")
	start_share(held_arrival)
	frames(held_arrival,90)
	held_arrival.restore_checkpoint()
	check(held_arrival.observation.is_empty() and held_arrival.message_revision==0 and held_arrival.listeners[0].state=="waiting","retry rolls back observation, report and listeners together")
	roundtrip(held_arrival,"retry")
	var closed := fresh()
	closed.invalidate_source()
	closed.p = Model.SOURCE
	closed.stamina = 50.0
	frames(closed,60)
	check(closed.stamina<=50.0 and closed.context_cue().text.contains("合拢"),"closed flower neither invites feeding nor restores nectar energy")
	var bad := prepared()
	var before := bad.save_payload()
	var payload := before.duplicate(true)
	payload.dance["message_revision"] = 1
	payload.dance.observation = {}
	check(not bad.restore_payload(payload) and bad.save_payload()==before,"malformed report rejected atomically")
	for other in [Long.new(),Weather.new()]:
		other.load_stage(0)
		check(not other.restore_payload(before) and not bad.restore_payload(other.save_payload()),"old journey and B save isolation")
	print("BEE DANCE VERIFIED: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
