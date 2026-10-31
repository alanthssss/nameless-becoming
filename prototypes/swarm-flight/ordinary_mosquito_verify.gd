extends SceneTree
## Independent bounded geometry/model checks; no player or listening acceptance.
const Model=preload("res://spring_journey_model.gd")
const FIXTURES="res://review-evidence/2026-11-01/ordinary-mosquito/legacy-fixtures/"
var checks=0
var failures=0
func _initialize(): call_deferred("run")
func check(ok: bool,label: String):
	checks+=1
	if not ok:
		failures+=1
		print("FAIL: "+label)
func fresh(point:=Vector2(2320,300)):
	var m=Model.new()
	m.load_stage(0)
	m.p=point
	m.started=true
	m.invulnerable=0
	return m
func distance_edge(p: Vector2,a: Vector2,b: Vector2) -> float:
	var ab=b-a
	var t=clampf((p-a).dot(ab)/ab.length_squared(),0,1) if ab.length_squared()>0 else 0.0
	return p.distance_to(a+ab*t)
func body_clear(m,p: Vector2,radius:=52.0) -> bool:
	for w in m.walls:
		if w.broken: continue
		var r: Rect2=w.rect
		var near=Vector2(clampf(p.x,r.position.x,r.end.x),clampf(p.y,r.position.y,r.end.y))
		if p.distance_to(near)<radius-0.001: return false
	for leaf in m.shelters:
		var poly=Model.Canopy.polygon(leaf)
		if Geometry2D.is_point_in_polygon(p,poly): return false
		for i in poly.size():
			if distance_edge(p,poly[i],poly[(i+1)%poly.size()])<radius-0.001: return false
	return true
func sampled_clear(m,a: Vector2,b: Vector2) -> bool:
	# Independent dense disk sampling, not production capsule endpoint formula.
	var n=maxi(1,int(ceil(a.distance_to(b)/2.0)))
	for i in n+1:
		if not body_clear(m,a.lerp(b,float(i)/n)): return false
	return true
func exact(m,label: String):
	var payload=m.save_payload()
	var copy=Model.new()
	check(copy.restore_payload(payload) and copy.save_payload()==payload,label)
func run():
	var m=fresh()
	check(Model.SMALL_HOME==Vector2(2390,285) and Model.SMALL_FLOWER_HOME==Vector2(2390,360),"actor moves while closed flower stays fixed")
	check(body_clear(m,Model.SMALL_HOME),"full52px home body clears actual geometry")
	check(Vector2(79/2.0,59.25*1.015/2.0).length()<52,"52px encloses rotated sprite including maximum flutter")
	for target in [Vector2(2320,300),Vector2(2520,320),Vector2(2520,240)]:
		m=fresh(target)
		var states=["idle"]
		var clear=true
		var returned=false
		var hits=0
		for i in 480:
			var before: Vector2=m.small.pos
			m.events.clear()
			m.step(Vector2.ZERO,false,1.0/120)
			clear=clear and sampled_clear(m,before,m.small.pos) and sampled_clear(m,Model.SMALL_HOME,m.small.pos)
			if m.small.state not in states: states.append(m.small.state)
			for e in m.events:
				if e.kind=="hit":
					hits+=1
					check(e.get("reason")=="mosquito" and e.get("cost")==8,"actual contact retains8 damage")
			if "rest" in states and m.small.state=="idle":
				returned=true
				break
		check(clear,"whole path and home return clear "+str(target))
		check(returned and m.small.pos==Model.SMALL_HOME,"cycle returns exactly home "+str(target))
		check(["aim","chase","return","rest","idle"].all(func(s): return s in states),"real complete actor cycle "+str(target))
		if target==Vector2(2520,240): check(hits==1,"clear reachable target receives one actual contact")
	geometry_counterexamples()
	restore_cases()
	print("ORDINARY MOSQUITO VERIFIED: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func geometry_counterexamples():
	var m=fresh()
	var leaf=m.shelters[1]
	var bounds: Rect2=Model.Canopy.rect(leaf)
	var a=Vector2(bounds.get_center().x,bounds.position.y-60)
	var b=Vector2(bounds.get_center().x,bounds.end.y+60)
	check(body_clear(m,a) and body_clear(m,b),"cross-leaf capsule endpoints are independently clear")
	check(not sampled_clear(m,a,b) and not m.small_path_clear(a,b),"clear endpoints cannot tunnel through leaf middle")
	var top=Vector2(leaf.pos.x,Model.Canopy.top_at(leaf.pos.x,leaf)-51)
	check(not body_clear(m,top) and not m.small_path_clear(top,top),"stationary52px body grazing leaf is rejected")
	var above=Vector2(leaf.pos.x,Model.Canopy.top_at(leaf.pos.x,leaf)-60)
	check(body_clear(m,above) and m.small_path_clear(above,above),"body actually above leaf remains allowed")
func reject_unchanged(payload: Dictionary,label: String):
	var live=fresh(Vector2(1700,210))
	var before=live.save_payload()
	var incoming=payload.duplicate(true)
	check(not live.restore_payload(payload) and live.save_payload()==before and payload==incoming,label)
func restore_cases():
	var m=fresh(Vector2(2520,320))
	for i in 10:
		m.step(Vector2.ZERO,false,1.0/60)
		if m.small.state=="aim": break
	check(m.small.state=="aim" and not body_clear(m,m.small.target),"natural aim can observe player outside52px body space")
	m.save_checkpoint(m.p)
	exact(m,"marked aim and checkpoint restore exactly despite narrow target")
	var current=m.save_payload()
	var bad=current.duplicate(true)
	bad.story.small.pos=Model.pack(Vector2(2390,360))
	reject_unchanged(bad,"marked unsafe live body rejects atomically")
	bad=current.duplicate(true)
	bad.checkpoint_story.small.pos=Model.pack(Vector2(2390,360))
	reject_unchanged(bad,"marked unsafe checkpoint body rejects atomically")
	bad=current.duplicate(true)
	bad.small_actor_revision=99
	reject_unchanged(bad,"unknown actor marker rejects atomically")
	var files=["old-idle","old-aim","old-chase","old-return","old-rest","old-stage-1","old-stage-2"]
	for name in files:
		var raw=JSON.parse_string(FileAccess.get_file_as_string(FIXTURES+name+".json"))
		check(raw is Dictionary and not raw.has("small_actor_revision"),"genuine fixture exists without new marker "+name)
		var original=raw.duplicate(true)
		var copy=Model.new()
		var accepted=copy.restore_payload(raw)
		check(accepted,"genuine old model accepts "+name)
		if not accepted: continue
		check(raw==original,"restore never mutates supplied old payload "+name)
		var upgraded=copy.save_payload()
		var expected=original.duplicate(true)
		expected.small_actor_revision=1
		# Actor is the only permitted changed field in these already-current geometry/preparation fixtures.
		expected.story.small=upgraded.story.small.duplicate(true)
		expected.checkpoint_story.small=upgraded.checkpoint_story.small.duplicate(true)
		check(JSON.parse_string(JSON.stringify(upgraded,"",true,true))==JSON.parse_string(JSON.stringify(expected,"",true,true)),"old upgrade changes only two small actors and marker "+name)
		var old_actor=Model.unpack(original.story.small)
		var preserve=original.stage==0 and sampled_clear(copy,Model.SMALL_HOME,old_actor.pos) and old_actor.pos.distance_to(Model.SMALL_HOME)<=235.01 and old_actor.state not in ["idle","rest"]
		var wanted=old_actor if preserve else Model.actor(Model.SMALL_HOME)
		check(copy.small==wanted and copy.checkpoint_story.small==wanted,"independent safety decides preserve versus reset "+name)
		exact(copy,"upgraded exact second restore "+name)
		bad=original.duplicate(true)
		bad.state.stamina=Model.pack(-1.0)
		reject_unchanged(bad,"invalid unrelated player field rejects before legacy normalization "+name)
	# Controlled variants of genuine old shape; a safe legacy flying pose must not teleport.
	var safe=JSON.parse_string(FileAccess.get_file_as_string(FIXTURES+"old-chase.json"))
	var safe_pos=Vector2(2390,260)
	m=fresh()
	check(body_clear(m,safe_pos) and sampled_clear(m,Model.SMALL_HOME,safe_pos),"safe legacy preservation fixture independently clear")
	for key in ["story","checkpoint_story"]:
		safe[key].small.pos=Model.pack(safe_pos)
		safe[key].small.target=Model.pack(Vector2(2320,300))
	var saved_small=safe.story.small.duplicate(true)
	check(m.restore_payload(safe),"safe old flying pose accepts")
	check(Model.pack(m.small)==saved_small and Model.pack(m.checkpoint_story.small)==saved_small,"safe old live and checkpoint actor preserve exact pose")
	bad=safe.duplicate(true)
	bad.checkpoint_story.small.pos=Model.pack(Vector2(3000,100))
	reject_unchanged(bad,"unknown old checkpoint actor cannot be laundered through migration")
