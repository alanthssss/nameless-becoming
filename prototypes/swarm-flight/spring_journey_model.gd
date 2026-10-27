extends "res://long_journey_model.gd"
## Three chapters revisit one source; local behavior never changes07–09.
const SpringContent=preload("res://spring_journey_content.gd")
const SPRING_SAVE_PATH="user://spring_03_05_v1.json"
const SITE_ID="pond-and-home"
const SMALL_HOME=Vector2(2390,360)
const KEEPER_HOME=Vector2(2100,410)
const KNOT=Vector2(2371,465)
const BACK_KNOT=Vector2(3021,300)
const RESULT_HOME=Vector2(3160,630)
const RESULT_SECONDS=2.4
const AIM_SECONDS=0.8
const CHASE_SECONDS=1.0
const COUNT_SECONDS=3.2
const WARNING_SECONDS=2.4
var small: Dictionary={}
var keeper: Dictionary={}
var front_open=false
var passage_open=false
var result_elapsed=0.0
var keeper_seen=false
var weather_phase="dry"
var warning_elapsed=0.0
var color_step=0
var checkpoint_story: Dictionary={}
const SOURCE := Vector2(3200,420)
const COMB := Vector2(3850,500)
const SOURCE_ID := "pond-blue-cluster"
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


static func actor(home: Vector2) -> Dictionary:
	return {"pos":home,"face":Vector2.LEFT,"target":home,"state":"idle","elapsed":0.0}
func change_state(who: Dictionary,state: String) -> void:
	who.state = state
	who.elapsed = 0.0
func sight_clear(a: Vector2,b: Vector2) -> bool:
	for obstacle in walls:
		if obstacle.broken: continue
		var r: Rect2 = obstacle.rect.grow(18.0)
		if r.has_point(a) or r.has_point(b): return false
		for edge in [[r.position,Vector2(r.end.x,r.position.y)],[Vector2(r.end.x,r.position.y),r.end],[r.end,Vector2(r.position.x,r.end.y)],[Vector2(r.position.x,r.end.y),r.position]]:
			if Geometry2D.segment_intersects_segment(a,b,edge[0],edge[1]) != null: return false
	return true
func update_actor(who: Dictionary,home: Vector2,is_keeper: bool,dt: float) -> void:
	who.elapsed += dt
	var distance: float = who.pos.distance_to(p)
	match who.state:
		"idle":
			if started and distance < (460.0 if is_keeper else 330.0) and shelter_index_at(p)<0 and sight_clear(who.pos,p):
				who.target = p
				change_state(who,"aim")
		"aim":
			who.target = p
			who.face = who.pos.direction_to(p)
			if who.elapsed >= AIM_SECONDS:
				who.target = home+(who.target-home).limit_length(300.0 if is_keeper else 235.0)
				change_state(who,"chase")
		"chase":
			var proposed: Vector2 = who.pos.move_toward(who.target,(290.0 if is_keeper else 240.0)*dt)
			who.face = who.pos.direction_to(who.target)
			if sight_clear(who.pos,proposed): who.pos = proposed
			else: who.elapsed = CHASE_SECONDS
			if who.elapsed >= CHASE_SECONDS or who.pos.distance_to(who.target)<3:
				change_state(who,"counting" if is_keeper else "return")
		"counting":
			who.face = Vector2.RIGHT
			if who.elapsed >= COUNT_SECONDS: change_state(who,"return")
		"return":
			who.face = who.pos.direction_to(home)
			who.pos = who.pos.move_toward(home,210.0*dt)
			if who.pos.distance_to(home)<0.1: change_state(who,"rest")
		"rest":
			if who.elapsed >= 1.0: change_state(who,"idle")
	# Contact is a small, visible bump. Dashing avoids it; no honey inventory.
	if who.state == "chase" and p.distance_to(who.pos) < (42.0 if is_keeper else 30.0) and burst_left<=0 and shelter_index_at(p)<0 and sight_clear(who.pos,p):
		hurt("mosquito",8.0)

func result_progress() -> float: return clampf(result_elapsed/RESULT_SECONDS,0.0,1.0)
static func waiting_listener(i: int) -> Dictionary:
	return {"pos":COMB+Vector2(55+i*48,12+i*24),"face":Vector2.LEFT,"state":"waiting","delay":0.0}

static func source_fact(revision: int) -> Dictionary:
	return {"source_id":SOURCE_ID,"revision":revision,"direction":COMB.direction_to(SOURCE),"near_far":"near","flower":"blue-cluster"}

func observation_valid() -> bool:
	return source_open and observation == source_fact(source_revision)

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
		if bee.pos.x < 3100 or bee.pos.x > 4050 or bee.pos.y < 350 or bee.pos.y > 600 or bee.face.length() > 1.01 or bee.delay < 0 or bee.delay > 0.7: return {}
		if bee.state in ["departing","foraging"] and (value.message_revision == 0 or not value.source_open): return {}
		if bee.state == "returning" and (value.message_revision == 0 or value.source_open): return {}
		if bee.state == "listening" and (value.share_state != "dancing" or value.message_revision != 0): return {}
	var template := {"source_open":true,"source_revision":1,"observation":{} if value.observation.is_empty() else source_fact(1),"feeding_elapsed":0.0,"perched":false,"share_state":"idle","dance_elapsed":0.0,"message_revision":0,"space_was_held":false,"suppress_space":false,"listeners":[waiting_listener(0),waiting_listener(1)]}
	return typed_copy(value,template)

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
	elif stage==2 and burst_left <= 0 and p.distance_to(COMB) < 38 and velocity.length() < 32:
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
					save_checkpoint(p)
					emit("checkpoint_update",p)
				if dance_elapsed >= DANCE_SECONDS: share_state = "idle"
		super.step(Vector2.ZERO,false,dt)
	else:
		super.step(direction,held and not suppress_space,dt)
	# Keep source, dancer and listeners in one view during communication.
	if stage==2 and p.x>3100: camera_x = clampf(p.x-1100.0,0.0,world_width-1280.0)
	if phase != "playing": return
	if stage!=1 and source_open and p.distance_to(SOURCE) < 34 and velocity.length() < 32 and not moving and not held and burst_left <= 0:
		feeding_elapsed = minf(FEED_SECONDS,feeding_elapsed+dt)
		if feeding_elapsed >= FEED_SECONDS and not observation_valid():
			observation = source_fact(source_revision)
			emit("source_observed",SOURCE)
			save_checkpoint(p)
			emit("checkpoint_update",p)
	else:
		feeding_elapsed = 0.0


func journey_id() -> String: return "spring-03-05-v1"
func journey_stage_count() -> int: return 3
func build_stage(index: int) -> Dictionary: return SpringContent.build(index)
func record_sample_approach(_before: Vector2) -> void: pass
func reset_journey() -> void:
	super.reset_journey()
	observation={}
	source_open=true
	source_revision=1
	message_revision=0
func load_stage(index: int) -> void:
	if index==0:
		observation={}
		source_open=true
		source_revision=1
	message_revision=0
	feeding_elapsed=0.0
	perched=false
	share_state="idle"
	dance_elapsed=0.0
	space_was_held=false
	suppress_space=false
	listeners=[waiting_listener(0),waiting_listener(1)]
	small=actor(SMALL_HOME)
	keeper=actor(KEEPER_HOME)
	front_open=false
	passage_open=false
	result_elapsed=0.0
	keeper_seen=false
	weather_phase="dry" if index!=2 else "after"
	warning_elapsed=0.0
	color_step=index
	super.load_stage(index)
func can_share() -> bool: return stage==2 and passage_open and observation_valid() and message_revision!=source_revision
func wall_at(x: float) -> Dictionary:
	for wall in walls:
		if wall.kind=="curtain" and is_equal_approx(wall.rect.position.x,x): return wall
	return {}
func gate_ready(obstacle: Dictionary) -> bool:
	if stage==2 and obstacle.kind=="curtain":
		if obstacle.rect.position.x==2350: return keeper.state=="counting" or front_open
		if obstacle.rect.position.x==3000: return front_open
	return super.gate_ready(obstacle)
func advance(direction: Vector2,dt: float) -> void:
	var retries:=recoveries
	if stage==0: update_actor(small,SMALL_HOME,false,dt)
	if stage==2 and not front_open: update_actor(keeper,KEEPER_HOME,true,dt)
	if retries!=recoveries: return
	if stage==1 and started:
		if weather_phase=="dry" and p.x>=650:
			weather_phase="warning"
			emit("weather_warning",p)
		if weather_phase=="warning":
			warning_elapsed=minf(WARNING_SECONDS,warning_elapsed+dt)
			if warning_elapsed>=WARNING_SECONDS: weather_phase="rain"
		if p.x>=3690:
			weather_phase="after"
			drops.clear()
	if perched or (stage!=1 and source_open and p.distance_to(SOURCE)<34 and direction.is_zero_approx()): gain_energy(REST_RECOVERY*dt)
	super.advance(direction,dt)
	if retries!=recoveries: return
	if stage!=2: return
	advance_listeners(dt)
	if p.x>=1560: keeper_seen=true
	if wall_at(2350).broken and not front_open:
		front_open=true
		change_state(keeper,"watch")
		keeper.face=Vector2.RIGHT
		save_checkpoint(Vector2(2460,465))
		emit("checkpoint_update",p)
	if wall_at(3000).broken and not passage_open:
		passage_open=true
		result_elapsed=0.0
		change_state(keeper,"tidy")
		keeper.target=Vector2(2240,465)
		save_checkpoint(Vector2(3100,300))
		emit("checkpoint_update",p)
	advance_tidy(dt)
func advance_tidy(dt: float) -> void:
	if passage_open:
		result_elapsed=minf(RESULT_SECONDS,result_elapsed+dt)
		keeper.pos=keeper.pos.move_toward(keeper.target,240.0*dt)
		var route=[Vector2(2240,465),Vector2(2470,465),Vector2(2780,300),Vector2(3090,300),RESULT_HOME]
		if keeper.pos.distance_to(keeper.target)<0.1:
			var next:=route.find(keeper.target)+1
			if next<route.size(): keeper.target=route[next]
		keeper.face=Vector2.RIGHT
		keeper.elapsed=result_elapsed
		if result_elapsed>=RESULT_SECONDS and keeper.pos==RESULT_HOME: keeper.state="settled"
func advance_rain(dt: float) -> void:
	if stage==1 and weather_phase=="rain": super.advance_rain(dt)
func rain_floor_at(x: float) -> float:
	var floor_y := 750.0
	for obstacle in walls:
		var rect: Rect2 = obstacle.rect
		if obstacle.kind == "terrain" and x >= rect.position.x and x <= rect.end.x:
			floor_y = minf(floor_y,rect.position.y)
	for leaf in shelters:
		if absf(x-leaf.pos.x) < float(leaf.half_width)+7.0:
			floor_y = minf(floor_y,leaf.pos.y-95.0)
	return floor_y


func story_state() -> Dictionary:
	return {"site_id":SITE_ID,"dance":dance_state(),"small":small.duplicate(true),"keeper":keeper.duplicate(true),"front_open":front_open,"passage_open":passage_open,"result_elapsed":result_elapsed,"keeper_seen":keeper_seen,"weather_phase":weather_phase,"warning_elapsed":warning_elapsed,"color_step":color_step}
func apply_story(state: Dictionary) -> void:
	apply_dance(state.dance)
	for key in ["small","keeper","front_open","passage_open","result_elapsed","keeper_seen","weather_phase","warning_elapsed","color_step"]: set(key,state[key])
func save_checkpoint(position := Vector2(180,420)) -> void:
	super.save_checkpoint(position)
	checkpoint_story=story_state()
	if passage_open:
		checkpoint_story.result_elapsed=RESULT_SECONDS
		checkpoint_story.keeper=actor(RESULT_HOME)
		checkpoint_story.keeper.state="settled"
		checkpoint_story.keeper.elapsed=RESULT_SECONDS
func restore_checkpoint(reason := "manual") -> void:
	super.restore_checkpoint(reason)
	apply_story(checkpoint_story.duplicate(true))
	perched=false
	space_was_held=false
	suppress_space=false
	cancel_dance()
	if stage==1 and weather_phase in ["warning","rain"]:
		weather_phase="warning"
		warning_elapsed=0.0
	if stage==2 and not front_open: keeper=actor(KEEPER_HOME)
	if stage==0: small=actor(SMALL_HOME)
func save_payload() -> Dictionary:
	var payload:=super.save_payload()
	payload["story"]=pack(story_state())
	payload["checkpoint_story"]=pack(checkpoint_story)
	return payload
func normalize_story(value,index: int) -> Dictionary:
	if not value is Dictionary or value.size()!=11 or value.get("site_id")!=SITE_ID: return {}
	var dance:=normalized_dance(value.get("dance"))
	if dance.is_empty(): return {}
	var template: Dictionary=story_state()
	template.dance=dance
	if not same_shape(value,template): return {}
	value=typed_copy(value,template)
	if value.color_step!=index or value.weather_phase not in ["dry","warning","rain","after"]: return {}
	if value.warning_elapsed<0 or value.warning_elapsed>WARNING_SECONDS: return {}
	if value.weather_phase=="rain" and value.warning_elapsed!=WARNING_SECONDS: return {}
	if index==0 and value.weather_phase!="dry": return {}
	if index==2 and value.weather_phase!="after": return {}
	if index!=2 and (value.front_open or value.passage_open or dance.message_revision!=0 or dance.perched or dance.share_state!="idle"): return {}
	if value.passage_open and not value.front_open: return {}
	if value.result_elapsed<0 or value.result_elapsed>RESULT_SECONDS: return {}
	if value.passage_open!=(value.keeper.state in ["tidy","settled"]): return {}
	if not value.passage_open and value.result_elapsed!=0: return {}
	for key in ["small","keeper"]:
		var who: Dictionary=value[key]
		if who.state not in ["idle","aim","chase","counting","return","rest","watch","tidy","settled"]: return {}
		if not valid_position(who.pos) or not valid_position(who.target) or who.face.length()>1.01 or who.elapsed<0 or who.elapsed>1000000: return {}
		if key=="small" and who.state in ["counting","watch","tidy","settled"]: return {}
	return value
func restore_payload(payload: Dictionary) -> bool:
	var index=int(payload.get("stage",-1))
	if index<0 or index>=3: return false
	var probe=get_script().new()
	probe.load_stage(index)
	var state: Dictionary=probe.normalize_story(unpack(payload.get("story")),index)
	var saved: Dictionary=probe.normalize_story(unpack(payload.get("checkpoint_story")),index)
	var base=unpack(payload.get("state"))
	if state.is_empty() or saved.is_empty() or not base is Dictionary: return false
	if state.dance.perched and (base.get("p")!=COMB or base.get("charging")!=false or base.get("burst_left")!=0): return false
	if not base.get("walls") is Array or not base.get("checkpoint") is Dictionary or not base.checkpoint.get("walls") is Array: return false
	if index==2:
		for pair in [[state,base.walls],[saved,base.checkpoint.walls]]:
			var found:=0
			for wall in pair[1]:
				if not wall is Dictionary or not wall.get("rect") is Rect2: return false
				if wall.kind=="curtain" and wall.rect.position.x in [2350.0,3000.0]:
					found+=1
					if wall.broken!=pair[0].get("front_open" if wall.rect.position.x==2350 else "passage_open"): return false
			if found!=2: return false
	if not super.restore_payload(payload): return false
	apply_story(state)
	checkpoint_story=saved
	return true
func objective() -> String:
	if stage==0: return "花路已经记住了 · 沿池岸绕向叶棚" if observation_valid() else "高低两路看见不同去向；蓝花心可以停一停"
	if stage==1: return "从叶下看雨，再选棚下通路或护雨上层" if weather_phase!="after" else "雨停了，沿熟悉的池岸回去"
	if not front_open: return "看它停下盘点，趁牌绳松开冲开叶结"
	if not passage_open: return "借风抬升后穿过背面通口，也可以普通飞行换层再冲"
	if message_revision>0: return "它们沿你告诉的花路出发了；前面就是家"
	return "归路已经打开，蜡脾上可以把见过的花路告诉同伴"
func hint() -> String:
	return "方向键随时离开 · Esc 暂停并保存" if perched else "方向键 / WASD 飞行 · 空格蓄力后松开冲刺 · Esc 暂停"
func context_cue() -> Dictionary:
	if stage!=1 and not source_open and p.distance_to(SOURCE)<180: return {"pos":SOURCE,"text":"花已经合拢 · 这条花路暂时歇了","kind":"flower"}
	if stage==2 and not front_open and p.distance_to(KNOT)<430:
		return {"pos":KNOT,"text":"绳松了 · 冲开干叶结" if keeper.state=="counting" else "绳还绷着 · 留意它何时盘点","kind":"keeper"}
	if stage==2 and front_open and not passage_open and p.distance_to(BACK_KNOT)<450:
		return {"pos":BACK_KNOT,"text":"背面露出干叶结 · 借风或换层后冲开","kind":"keeper"}
	if stage==2 and perched:
		return {"pos":COMB,"text":"松开空格开始 · 方向键取消" if share_state=="armed" else "方向键随时离开" if share_state=="dancing" else "空格按住再松开 · 分享花路" if can_share() else "旧花路已歇，等下一条消息" if not source_open else "它们已经听到了" if message_revision>0 else "还没有亲自看过的花路","kind":"dance"}
	if stage!=1 and p.distance_to(SOURCE)<180 and not observation_valid(): return {"pos":SOURCE,"text":"在花心停稳，尝一口花蜜","kind":"flower"}
	if stage==2 and p.distance_to(COMB)<210: return {"pos":COMB,"text":"停在蜡脾上 · 可以分享花路","kind":"dance"}
	return super.context_cue()
