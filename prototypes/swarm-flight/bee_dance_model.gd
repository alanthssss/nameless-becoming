extends "res://long_journey_model.gd"
## A single observed source and local communication transaction. No economy.
const DanceContent = preload("res://bee_dance_content.gd")
const DANCE_SAVE_PATH := "user://bee_dance_sample_v1.json"
const SOURCE := Vector2(420,420)
const COMB := Vector2(1030,500)
const SOURCE_ID := "blue-bridge-flowers"
const FEED_SECONDS := 0.7
const COMMIT_SECONDS := 1.2
const DANCE_SECONDS := 2.4
var source_open := true
var source_revision := 1
var observation: Dictionary = {}
var feeding_elapsed := 0.0
var perched := false
var share_state := "idle"
var dance_elapsed := 0.0
var message_revision := 0
var space_was_held := false
var suppress_space := false
var listeners: Array = []
var checkpoint_dance: Dictionary = {}

func journey_id() -> String: return "bee-dance-sample-v1"
func journey_stage_count() -> int: return 1
func build_stage(_index: int) -> Dictionary: return DanceContent.build()
func record_sample_approach(_before: Vector2) -> void: pass

static func waiting_listener(i: int) -> Dictionary:
	return {"pos":COMB+Vector2(55+i*48,12+i*24),"face":Vector2.LEFT,"state":"waiting","delay":0.0}

func load_stage(index: int) -> void:
	source_open = true
	source_revision = 1
	observation = {}
	feeding_elapsed = 0.0
	perched = false
	share_state = "idle"
	dance_elapsed = 0.0
	message_revision = 0
	space_was_held = false
	suppress_space = false
	listeners = [waiting_listener(0),waiting_listener(1)]
	super.load_stage(index)

static func source_fact(revision: int) -> Dictionary:
	return {"source_id":SOURCE_ID,"revision":revision,"direction":COMB.direction_to(SOURCE),"near_far":"near","flower":"blue-cluster"}

func observation_valid() -> bool:
	return source_open and observation == source_fact(source_revision)

func can_share() -> bool:
	return observation_valid() and message_revision != source_revision

func step(direction: Vector2, held: bool, delta: float) -> void:
	if phase != "playing" or delta <= 0: return
	var dt := clampf(delta,0.0,0.1)
	var moving := direction.length() > 0.01
	var was_held := space_was_held
	space_was_held = held
	if not held: suppress_space = false
	if moving:
		if perched or share_state != "idle":
			cancel_dance()
			suppress_space = held
		perched = false
	elif burst_left <= 0 and p.distance_to(COMB) < 38 and velocity.length() < 32:
		perched = true
		p = COMB
		velocity = Vector2.ZERO
		charging = false
		charge = 0.0
	if perched:
		charging = false
		charge = 0.0
		if not can_share() and share_state == "armed": cancel_dance()
		if share_state == "idle" and held and not was_held and not suppress_space and can_share():
			share_state = "armed"
		elif share_state == "armed" and not held:
			share_state = "dancing"
			dance_elapsed = 0.0
			for bee in listeners: bee.state = "listening"
		if share_state == "dancing":
			if not observation_valid():
				cancel_dance()
			else:
				dance_elapsed = minf(DANCE_SECONDS,dance_elapsed+dt)
				if dance_elapsed >= COMMIT_SECONDS and message_revision != source_revision:
					message_revision = source_revision
					for i in listeners.size():
						listeners[i].state = "departing"
						listeners[i].delay = 0.2+0.5*i
					emit("dance_commit",COMB)
				if dance_elapsed >= DANCE_SECONDS: share_state = "idle"
		super.step(Vector2.ZERO,false,dt)
	else:
		super.step(direction,held and not suppress_space,dt)
	# Keep source, dancer and listeners in one view during communication.
	camera_x = clampf(p.x-1100.0,0.0,world_width-1280.0)
	if phase != "playing": return
	if source_open and p.distance_to(SOURCE) < 34 and velocity.length() < 32 and not moving and not held and burst_left <= 0:
		feeding_elapsed = minf(FEED_SECONDS,feeding_elapsed+dt)
		if feeding_elapsed >= FEED_SECONDS and not observation_valid():
			observation = source_fact(source_revision)
			emit("source_observed",SOURCE)
	else:
		feeding_elapsed = 0.0

func advance(direction: Vector2, dt: float) -> void:
	# Landing on wax or an open flower rests the bee; no reward is awarded by dance.
	if perched or (source_open and p.distance_to(SOURCE) < 34 and direction.is_zero_approx()):
		gain_energy(REST_RECOVERY*dt)
	super.advance(direction,dt)
	advance_listeners(dt)

func cancel_dance() -> void:
	share_state = "idle"
	dance_elapsed = 0.0
	for bee in listeners:
		if bee.state == "listening": bee.state = "waiting"

func invalidate_source() -> void:
	# Content event, not wall-clock expiry. The later campaign may call this
	# when the observed flower closes; this sample tests the event explicitly.
	if not source_open: return
	source_open = false
	source_revision += 1
	feeding_elapsed = 0.0
	cancel_dance()
	for bee in listeners:
		if bee.state in ["departing","foraging"]:
			bee.state = "returning"
			bee.delay = 0.0

func advance_listeners(dt: float) -> void:
	for i in listeners.size():
		var bee: Dictionary = listeners[i]
		if bee.state == "listening":
			bee.face = COMB.direction_to(SOURCE)
		elif bee.state in ["departing","returning"]:
			bee.delay = maxf(0.0,bee.delay-dt)
			var target: Vector2 = SOURCE+(Vector2(-45,45) if i == 0 else Vector2(68,42)) if bee.state == "departing" else waiting_listener(i).pos
			bee.face = bee.pos.direction_to(target)
			if bee.delay <= 0: bee.pos = bee.pos.move_toward(target,155.0*dt)
			if bee.pos.distance_to(target) < 0.1:
				bee.state = "foraging" if bee.state == "departing" else "waiting"
		elif bee.state == "waiting": bee.face = bee.pos.direction_to(COMB)

func dance_pose() -> Vector2:
	if share_state != "dancing": return Vector2.ZERO
	var axis := COMB.direction_to(SOURCE)
	var side := axis.orthogonal()
	if dance_elapsed <= COMMIT_SECONDS:
		return axis*(dance_elapsed/COMMIT_SECONDS*54.0)+side*sin(dance_elapsed*33.0)*5.0
	var u := (dance_elapsed-COMMIT_SECONDS)/(DANCE_SECONDS-COMMIT_SECONDS)
	return axis*(54.0*(1-u))+side*sin(u*TAU)*22.0

func dance_state() -> Dictionary:
	return {"source_open":source_open,"source_revision":source_revision,"observation":observation.duplicate(true),"feeding_elapsed":feeding_elapsed,"perched":perched,"share_state":share_state,"dance_elapsed":dance_elapsed,"message_revision":message_revision,"space_was_held":space_was_held,"suppress_space":suppress_space,"listeners":listeners.duplicate(true)}

func apply_dance(state: Dictionary) -> void:
	for key in state: set(key,state[key])

func save_checkpoint(position := Vector2(180,420)) -> void:
	super.save_checkpoint(position)
	checkpoint_dance = dance_state()

func restore_checkpoint(reason := "manual") -> void:
	super.restore_checkpoint(reason)
	apply_dance(checkpoint_dance.duplicate(true))
	# Checkpoint travel is a new attempt, never a held-input replay.
	perched = false
	space_was_held = false
	suppress_space = false
	cancel_dance()

func save_payload() -> Dictionary:
	var payload := super.save_payload()
	payload["dance"] = pack(dance_state())
	payload["checkpoint_dance"] = pack(checkpoint_dance)
	return payload

static func normalized_dance(value) -> Dictionary:
	if not value is Dictionary or value.size() != 11: return {}
	for key in ["source_open","perched","space_was_held","suppress_space"]:
		if not value.get(key) is bool: return {}
	for key in ["source_revision","message_revision"]:
		if not number(value.get(key)) or value[key] != floor(value[key]): return {}
	if int(value.source_revision) not in [1,2] or int(value.message_revision) not in [0,1]: return {}
	if value.source_open != (value.source_revision == 1): return {}
	if value.get("share_state") not in ["idle","armed","dancing"]: return {}
	for pair in [["feeding_elapsed",FEED_SECONDS],["dance_elapsed",DANCE_SECONDS]]:
		if not number(value.get(pair[0])) or value[pair[0]] < 0 or value[pair[0]] > pair[1]: return {}
	if not value.get("observation") is Dictionary: return {}
	if not value.observation.is_empty():
		if not same_shape(value.observation,source_fact(1)): return {}
		value.observation = typed_copy(value.observation,source_fact(1))
		if value.observation != source_fact(1): return {}
	if value.message_revision == 1 and value.observation.is_empty(): return {}
	if value.share_state != "idle" and (not value.perched or not value.source_open or value.observation.is_empty()): return {}
	if value.share_state == "armed" and (not value.space_was_held or value.message_revision == 1): return {}
	if value.share_state == "dancing" and ((value.dance_elapsed >= COMMIT_SECONDS) != (value.message_revision == 1)): return {}
	if not value.get("listeners") is Array or value.listeners.size() != 2: return {}
	for bee in value.listeners:
		if not same_shape(bee,waiting_listener(0)): return {}
		if bee.state not in ["waiting","listening","departing","foraging","returning"]: return {}
		if bee.pos.x < 350 or bee.pos.x > 1200 or bee.pos.y < 350 or bee.pos.y > 600 or bee.face.length() > 1.01 or bee.delay < 0 or bee.delay > 0.7: return {}
		if bee.state in ["departing","foraging"] and (value.message_revision == 0 or not value.source_open): return {}
		if bee.state == "returning" and (value.message_revision == 0 or value.source_open): return {}
		if bee.state == "listening" and (value.share_state != "dancing" or value.message_revision != 0): return {}
	var template := {"source_open":true,"source_revision":1,"observation":{} if value.observation.is_empty() else source_fact(1),"feeding_elapsed":0.0,"perched":false,"share_state":"idle","dance_elapsed":0.0,"message_revision":0,"space_was_held":false,"suppress_space":false,"listeners":[waiting_listener(0),waiting_listener(1)]}
	return typed_copy(value,template)

func restore_payload(payload: Dictionary) -> bool:
	var state := normalized_dance(unpack(payload.get("dance")))
	var saved_checkpoint := normalized_dance(unpack(payload.get("checkpoint_dance")))
	if state.is_empty() or saved_checkpoint.is_empty(): return false
	var base = unpack(payload.get("state"))
	if not base is Dictionary: return false
	if state.perched and (base.get("p") != COMB or base.get("charging") != false or base.get("burst_left") != 0): return false
	if not super.restore_payload(payload): return false
	apply_dance(state)
	checkpoint_dance = saved_checkpoint
	return true

func objective() -> String:
	if not source_open: return "花已经合拢，旧花路不再招来采集者；前路仍然敞开"
	if message_revision > 0: return "它们记住了花路；可以跟去看看，也可以继续向前"
	if observation_valid(): return "把看见的花路带到蜡脾边，或继续自己的旅程"
	return "蓝花簇上可以停一停；前面的路始终敞开"

func hint() -> String:
	if perched: return "方向键随时离开 · Esc 暂停并保存"
	return "方向键 / WASD 飞行 · 空格蓄力冲刺 · Esc 暂停"

func context_cue() -> Dictionary:
	if not source_open and p.distance_to(SOURCE) < 180: return {"pos":SOURCE,"text":"花已合拢 · 这条花路暂时歇了","kind":"flower"}
	if perched:
		var text := "旧花路已歇，等下一条消息" if not source_open else "空格按住再松开 · 分享花路" if can_share() else "它们已经听到了" if message_revision > 0 else "还没有亲自看过的花路"
		if share_state == "armed": text = "松开空格开始 · 方向键取消"
		if share_state == "dancing": text = "方向键随时离开"
		return {"pos":COMB,"text":text,"kind":"dance"}
	if p.distance_to(SOURCE) < 180 and not observation_valid():
		return {"pos":SOURCE,"text":"在花心停稳，尝一口花蜜","kind":"flower"}
	if p.distance_to(COMB) < 210: return {"pos":COMB,"text":"停在蜡脾上 · 可以分享花路","kind":"dance"}
	return super.context_cue()
