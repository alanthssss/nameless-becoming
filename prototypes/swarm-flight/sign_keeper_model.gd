extends "res://long_journey_model.gd"
const KeeperContent = preload("res://sign_keeper_content.gd")
const KEEPER_SAVE_PATH := "user://sign_keeper_sample_v1.json"
const SMALL_HOME := Vector2(670,440)
const KEEPER_HOME := Vector2(2100,410)
const KNOT := Vector2(2371,465)
const RESULT_HOME := Vector2(2510,630)
const RESULT_SECONDS := 2.4
const AIM_SECONDS := 0.8
const CHASE_SECONDS := 1.0
const COUNT_SECONDS := 3.2
var small: Dictionary = {}
var keeper: Dictionary = {}
var passage_open := false
var result_elapsed := 0.0
var keeper_seen := false
var checkpoint_keeper: Dictionary = {}

static func actor(home: Vector2) -> Dictionary:
	return {"pos":home,"face":Vector2.LEFT,"target":home,"state":"idle","elapsed":0.0}
func journey_id() -> String: return "sign-keeper-sample-v1"
func journey_stage_count() -> int: return 1
func build_stage(_index: int) -> Dictionary: return KeeperContent.build()
func record_sample_approach(_before: Vector2) -> void: pass
func load_stage(index: int) -> void:
	small = actor(SMALL_HOME)
	keeper = actor(KEEPER_HOME)
	passage_open = false
	result_elapsed = 0.0
	keeper_seen = false
	super.load_stage(index)
func knot_wall() -> Dictionary:
	return walls[3]
func gate_ready(obstacle: Dictionary) -> bool:
	if obstacle.kind == "curtain" and obstacle.rect.position.x == 2350:
		return keeper.state == "counting" or passage_open
	return super.gate_ready(obstacle)
func result_progress() -> float: return clampf(result_elapsed/RESULT_SECONDS,0.0,1.0)
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

func advance(direction: Vector2,dt: float) -> void:
	var retries := recoveries
	if not passage_open:
		update_actor(keeper,KEEPER_HOME,true,dt)
	if recoveries != retries: return
	update_actor(small,SMALL_HOME,false,dt)
	if recoveries != retries: return
	super.advance(direction,dt)
	if recoveries != retries: return
	if p.x >= 1560 and not keeper_seen:
		keeper_seen = true
		emit("keeper_seen",p)
	if knot_wall().broken and not passage_open:
		passage_open = true
		result_elapsed = 0.0
		change_state(keeper,"tidy")
		keeper.target = Vector2(2240,465)
		# Opening commits the world change now, before any optional next leaf.
		save_checkpoint(Vector2(2460,465))
		emit("checkpoint_update",p)
	if passage_open:
		result_elapsed = minf(RESULT_SECONDS,result_elapsed+dt)
		keeper.pos = keeper.pos.move_toward(keeper.target,240.0*dt)
		if keeper.pos.distance_to(keeper.target)<0.1:
			if keeper.target==Vector2(2240,465): keeper.target=Vector2(2470,465)
			elif keeper.target==Vector2(2470,465): keeper.target=RESULT_HOME
		keeper.face = Vector2.RIGHT
		keeper.elapsed = result_elapsed
		if result_elapsed >= RESULT_SECONDS and keeper.pos==RESULT_HOME: keeper.state = "settled"

func keeper_state() -> Dictionary:
	return {"small":small.duplicate(true),"keeper":keeper.duplicate(true),"passage_open":passage_open,"result_elapsed":result_elapsed,"keeper_seen":keeper_seen}
func apply_keeper(state: Dictionary) -> void:
	small = state.small.duplicate(true)
	keeper = state.keeper.duplicate(true)
	passage_open = state.passage_open
	result_elapsed = state.result_elapsed
	keeper_seen = state.keeper_seen
func save_checkpoint(position := Vector2(180,420)) -> void:
	super.save_checkpoint(position)
	checkpoint_keeper = keeper_state()
	if passage_open:
		# Explicit retry skips the already earned self-tidying animation.
		checkpoint_keeper.result_elapsed = RESULT_SECONDS
		checkpoint_keeper.keeper.pos = RESULT_HOME
		checkpoint_keeper.keeper.target = RESULT_HOME
		checkpoint_keeper.keeper.state = "settled"
		checkpoint_keeper.keeper.elapsed = RESULT_SECONDS
func restore_checkpoint(reason := "manual") -> void:
	super.restore_checkpoint(reason)
	apply_keeper(checkpoint_keeper)
	if not passage_open:
		keeper = actor(KEEPER_HOME)
		small = actor(SMALL_HOME)
func save_payload() -> Dictionary:
	var payload := super.save_payload()
	payload["keeper"] = pack(keeper_state())
	payload["checkpoint_keeper"] = pack(checkpoint_keeper)
	return payload
static func normalized_keeper(value) -> Dictionary:
	var template := {"small":actor(SMALL_HOME),"keeper":actor(KEEPER_HOME),"passage_open":false,"result_elapsed":0.0,"keeper_seen":false}
	if not same_shape(value,template): return {}
	if value.result_elapsed<0 or value.result_elapsed>RESULT_SECONDS: return {}
	for pair in [["small",SMALL_HOME,360.0],["keeper",KEEPER_HOME,700.0]]:
		var who: Dictionary = value[pair[0]]
		if who.state not in ["idle","aim","chase","counting","return","rest","tidy","settled"]: return {}
		if who.pos.distance_to(pair[1])>pair[2] or who.face.length()>1.01 or who.target.x<0 or who.target.x>3610 or who.target.y<60 or who.target.y>750 or who.elapsed<0 or who.elapsed>1000000: return {}
		if pair[0]=="small" and who.state in ["counting","tidy","settled"]: return {}
	if value.passage_open != (value.keeper.state in ["tidy","settled"]): return {}
	if not value.passage_open and value.result_elapsed != 0: return {}
	if value.keeper.state == "settled" and value.result_elapsed != RESULT_SECONDS: return {}
	return typed_copy(value,template)
func restore_payload(payload: Dictionary) -> bool:
	var state := normalized_keeper(unpack(payload.get("keeper")))
	var saved_checkpoint := normalized_keeper(unpack(payload.get("checkpoint_keeper")))
	var base = unpack(payload.get("state"))
	if state.is_empty() or saved_checkpoint.is_empty() or not base is Dictionary: return false
	# Reject contradictory geometry before mutating any live fields.
	if not base.get("walls") is Array or base.walls.size()!=4 or not base.get("checkpoint") is Dictionary: return false
	if not base.checkpoint.get("walls") is Array or base.checkpoint.walls.size()!=4: return false
	if not base.walls[3] is Dictionary or not base.checkpoint.walls[3] is Dictionary: return false
	if state.passage_open != base.walls[3].get("broken") or saved_checkpoint.passage_open != base.checkpoint.walls[3].get("broken"): return false
	if not super.restore_payload(payload): return false
	apply_keeper(state)
	checkpoint_keeper = saved_checkpoint
	return true
func objective() -> String:
	if passage_open: return "花牌挪到旁边了 · 穿过留下的通口"
	if p.x < 1440: return "它只追近一小段 · 换层或借花篱绕过"
	return "看它停下盘点 · 趁牌绳松开，冲开干叶结"
func hint() -> String: return "方向键 / WASD 飞行 · 空格蓄力后松开冲刺 · Esc 暂停"
func context_cue() -> Dictionary:
	if p.distance_to(KNOT)<430 and not passage_open:
		return {"pos":KNOT,"text":"绳松了 · 冲开干叶结" if keeper.state=="counting" else "绳还绷着 · 留意它何时盘点","kind":"keeper"}
	return super.context_cue()
