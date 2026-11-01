extends SceneTree
## Known-route developer verification, not independent exploration or visual acceptance.
const M=preload("res://spring_journey_model.gd")
const RainExpected=preload("res://rain_layout_expectations.gd")
const FIXTURES="res://review-evidence/2026-11-01/source-routes/legacy-fixtures/"
const FORK=Rect2(2860,330,200,120)
var checks=0
var failures=0
var continuity_ok=true
var onscreen_ok=true
func _initialize(): call_deferred("run")
func check(ok: bool,label: String):
	checks+=1
	if not ok:
		failures+=1
		print("FAIL: "+label)
func fresh(point:=Vector2(2770,500)):
	var m=M.new()
	m.load_stage(0)
	m.p=point
	m.started=true
	m.camera_x=point.x-480
	return m
func tick(m,d:=Vector2.ZERO):
	var before: float=m.camera_x
	m.step(d,false,1.0/60)
	# A single60Hz step stays below2% of the1280px viewport; native footage judges comfort.
	continuity_ok=continuity_ok and absf(m.camera_x-before)<24.0
	onscreen_ok=onscreen_ok and m.p.x-m.camera_x>90 and m.p.x-m.camera_x<1190
func fly(m,target: Vector2):
	for i in 700:
		var delta: Vector2=target-m.p
		if delta.length()<7: break
		var d=Vector2(signf(delta.x) if absf(delta.x)>4 else 0.0,signf(delta.y) if absf(delta.y)>4 else 0.0).normalized()
		tick(m,d)
	for i in 20: tick(m)
	check(m.p.distance_to(target)<28,"ordinary inputs reach "+str(target)+" actual="+str(m.p))
func fixture(name: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(FIXTURES+"old-"+name+".json"))
func normalized(value): return JSON.parse_string(JSON.stringify(value,"",true,true))
func expected_upgrade(old: Dictionary) -> Dictionary:
	var expected=old.duplicate(true)
	expected.pond_layout_revision=1
	if old.stage==0:
		var wall=M.pack({"kind":"terrain","material":"hedge","rect":FORK,"broken":false})
		expected.state.walls.append(wall.duplicate(true))
		expected.state.checkpoint.walls.append(wall.duplicate(true))
	return RainExpected.upgraded(expected)
func exact(m,label: String):
	var data=m.save_payload()
	var copy=M.new()
	check(copy.restore_payload(normalized(data)) and copy.save_payload()==data,"exact cold model resume "+label)
func reject(payload: Dictionary,label: String):
	var m=fresh(Vector2(1700,210))
	var before=m.save_payload()
	var original=payload.duplicate(true)
	check(not m.restore_payload(payload) and m.save_payload()==before and payload==original,"atomic reject "+label)
func run():
	var m=fresh()
	check(M.SOURCE==Vector2(3200,420) and M.SOURCE_ID=="pond-blue-cluster","real flower identity and position remain fixed")
	check(m.walls.filter(func(w): return w.rect==FORK and w.kind=="terrain" and w.material=="hedge" and not w.broken).size()==1,"one solid source-near fork exists")
	# Direct middle flight must be obstructed; both explicit alternatives remain traversable.
	m=fresh(Vector2(2800,390))
	for i in 80: tick(m,Vector2.RIGHT)
	check(m.p.x<2860 and m.recoveries==0,"middle approach meets real collision without recovery")
	var views=[]
	for upper in [false,true]:
		m=fresh()
		continuity_ok=true
		onscreen_ok=true
		fly(m,Vector2(2770,230 if upper else 500))
		fly(m,Vector2(2850,230 if upper else 500))
		var next_leaf=m.shelters.filter(func(s): return s.pos.x>3200)[0]
		var bounds: Rect2=M.Canopy.rect(next_leaf)
		views.append({"player_x":m.p.x,"center":next_leaf.pos.x-m.camera_x,"left":bounds.position.x-m.camera_x,"right":bounds.end.x-m.camera_x})
		fly(m,Vector2(3150,230 if upper else 500))
		fly(m,M.SOURCE)
		for i in 65: tick(m)
		check(m.observation_valid() and m.observation.source_id=="pond-blue-cluster","both routes can optionally feed at same true flower "+str(upper))
		exact(m,"observed via "+str(upper))
		fly(m,Vector2(3470,600))
		fly(m,Vector2(3550,600))
		check(m.recoveries==0,"both routes need no hidden recovery "+str(upper))
		check(continuity_ok and onscreen_ok,"camera stays continuous and player stays onscreen "+str(upper))
	check(absf(views[0].player_x-views[1].player_x)<15,"visibility comparison uses same actual x")
	check(views[1].center<1280 and views[1].left>=0 and views[1].right<1280 and views[0].center>1280,"high route shows actual next shelter; low route keeps its center beyond screen")
	print("ACTUAL NEXT SHELTER PROJECTIONS: "+JSON.stringify(views))
	for upper in [false,true]:
		m=fresh()
		fly(m,Vector2(2770,230 if upper else 500))
		fly(m,Vector2(3150,230 if upper else 500))
		fly(m,Vector2(3470,600))
		check(m.observation.is_empty() and m.recoveries==0,"either route may skip flower without fabricated observation "+str(upper))
	for point in [Vector2(2500,230),Vector2(3550,230),Vector2(2850,500)]:
		m=fresh(point)
		tick(m)
		check(is_equal_approx(m.p.x-m.camera_x,480),"ordinary framing outside local high route "+str(point))
	m=fresh(Vector2(2500,230))
	continuity_ok=true
	onscreen_ok=true
	fly(m,Vector2(2770,230))
	fly(m,Vector2(2500,230))
	check(continuity_ok and onscreen_ok,"entering and reversing across local camera ramp never jumps or hides player")
	restore_cases()
	print("POND SOURCE ROUTES VERIFIED: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
func restore_cases():
	for name in ["initial","before-fork","source-observed","stage-1","stage-2"]:
		var old=fixture(name)
		check(not old.has("pond_layout_revision"),"genuine old marker absent "+name)
		var original=old.duplicate(true)
		var m=M.new()
		var accepted=m.restore_payload(old)
		check(accepted and old==original,"legacy accepts without changing caller payload "+name)
		if not accepted: continue
		check(normalized(m.save_payload())==normalized(expected_upgrade(old)),"only declared geometry and marker change "+name)
		exact(m,name)
	var old=fixture("future-wall-live")
	var m=M.new()
	check(m.restore_payload(old),"legal old live inside new wall migrates")
	check(m.p==M.unpack(old.state.checkpoint.p) and m.recoveries==int(old.state.recoveries)+1 and m.events.any(func(e): return e.kind=="recover_geometry"),"new-wall live uses existing visible checkpoint recovery")
	check(normalized(M.pack(m.checkpoint))==normalized(expected_upgrade(old).state.checkpoint) and normalized(M.pack(m.checkpoint_story))==normalized(old.checkpoint_story),"both migrated checkpoint geometry and checkpoint facts preserved")
	exact(m,"recovered old live")
	reject(fixture("unsafe-checkpoint"),"old checkpoint inside new fork")
	for snapshot in ["live","checkpoint"]:
		for defect in ["missing","extra","geometry","unknown-key","bad-broken"]:
			var bad=fixture("before-fork")
			var state=bad.state if snapshot=="live" else bad.state.checkpoint
			if defect=="missing": state.walls.pop_back()
			if defect=="extra": state.walls.append(state.walls[0].duplicate(true))
			if defect=="geometry": state.walls[0].rect.r[0]+=1
			if defect=="unknown-key": state.walls[0].surprise=true
			if defect=="bad-broken": state.walls[0].broken="false"
			reject(bad,snapshot+" full old wall set "+defect)
	m=fresh()
	var current=m.save_payload()
	for marker in [2,-1,"1",null]:
		var bad=current.duplicate(true)
		bad.pond_layout_revision=marker
		reject(bad,"unsupported marker "+str(marker))
	var stripped=current.duplicate(true)
	stripped.erase("pond_layout_revision")
	reject(stripped,"current geometry cannot masquerade as genuine old wall set")
	var bad=fixture("before-fork")
	bad.state.stamina=M.pack(-1.0)
	reject(bad,"unrelated corruption before migration")
