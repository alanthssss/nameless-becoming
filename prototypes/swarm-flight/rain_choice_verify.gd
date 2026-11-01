extends SceneTree
## Independent migration and bounded player-rule checks; no first-time exploration.
const M=preload("res://spring_journey_model.gd")
const E=preload("res://rain_layout_expectations.gd")
const FIXTURES="res://review-evidence/2026-11-01/rain-choice/legacy-fixtures/"
var checks=0
var failures=0
func _initialize(): call_deferred("run")
func check(ok: bool,label: String):
	checks+=1
	if not ok:
		failures+=1
		print("FAIL: "+label)
func fixture(name: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(FIXTURES+"old-"+name+".json"))
func fresh(stage:=1):
	var m=M.new()
	m.load_stage(stage)
	return m
func exact(m,label: String):
	var payload=m.save_payload()
	var other=fresh()
	check(other.restore_payload(E.normalized(payload)) and other.save_payload()==payload,"exact current cold resume "+label)
func reject(data: Dictionary,label: String):
	var m=fresh(0)
	var before=m.save_payload()
	var original=data.duplicate(true)
	check(not m.restore_payload(data) and m.save_payload()==before and data==original,"atomic rejection "+label)
func run():
	for name in ["stage-0","stage-2","checkpoint--1","checkpoint-0","checkpoint-1","checkpoint-2","checkpoint-3","rain-shield-live","rain-shield-committed","after-third"]:
		reject(fixture(name),"v2 rain state is isolated "+name)
	var valid=fresh().save_payload()
	for snapshot in ["live","checkpoint"]:
		for defect in ["missing-wall","extra-wall","wall-rect","shelter-name","shelter-width","dew-purpose","dew-section","bad-prefix","bad-index","shield-position"]:
			var bad=valid.duplicate(true)
			var state=bad.state if snapshot=="live" else bad.state.checkpoint
			if defect=="missing-wall": state.walls.pop_back()
			if defect=="extra-wall": state.walls.append(state.walls[0].duplicate(true))
			if defect=="wall-rect": state.walls[0].rect.r[0]+=1
			if defect=="shelter-name": state.shelters[2].name="unrecognized"
			if defect=="shelter-width": state.shelters[2].half_width=M.pack(117.0)
			if defect=="dew-purpose": state.dew[1].purpose="changed"
			if defect=="dew-section": state.dew[1].section=1
			if defect=="bad-prefix": state.shelters[2].reached=true
			if defect=="bad-index": state.checkpoint_index=99
			if defect=="shield-position": state.shields[0].pos=M.pack(Vector2(2380,450))
			reject(bad,snapshot+" current validation "+defect)
	var current=fresh().save_payload()
	for marker in [2,-1,"1",null,true]:
		var bad=current.duplicate(true)
		bad.rain_layout_revision=marker
		reject(bad,"unsupported rain marker "+str(marker))
	for key in ["pond_layout_revision","small_actor_revision","preparation_revision","route_geometry_revision","keeper_presentation_revision"]:
		var bad=current.duplicate(true)
		bad[key]="1"
		reject(bad,"earlier marker string cannot bypass validation "+key)
	var stripped=current.duplicate(true)
	stripped.erase("rain_layout_revision")
	reject(stripped,"new layout cannot masquerade as old by losing marker")
	legacy_chain_cases()
	bounded_player_rules()
	ordinary_choices()
	print("RAIN CHOICE VERIFIED: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
func legacy_chain_cases():
	var paths=[]
	for name in ["stage0-plain","stage1-plain","stage2-closed","stage2-front","stage2-foraging","stage2-tidy","stage2-settled","stage2-second_gate","stage2-ending"]: paths.append("back-sign/legacy-fixtures/"+name+".json")
	for name in ["initial","working","watch","hung","inherited_idle"]: paths.append("departure/legacy-fixtures/"+name+".json")
	for name in ["idle","aim","chase","return","rest","stage-1","stage-2"]: paths.append("ordinary-mosquito/legacy-fixtures/old-"+name+".json")
	for name in ["initial","before-fork","future-wall-live","source-observed","stage-1","stage-2"]: paths.append("source-routes/legacy-fixtures/old-"+name+".json")
	for path in paths:
		var data=JSON.parse_string(FileAccess.get_file_as_string("res://review-evidence/2026-11-01/"+path))
		var before=data.duplicate(true)
		var m=fresh()
		var stable=m.save_payload()
		check(not m.restore_payload(data) and data==before and m.save_payload()==stable,"earlier map remains isolated "+path)
func bounded_player_rules():
	var m=fresh()
	m.p=Vector2(2630,600)
	m.stamina=40.0
	m.started=true
	var before=m.stamina
	for i in 60: m.step(Vector2.ZERO,false,1.0/60)
	check(m.shelter_index_at(m.p)==2 and m.stamina>before,"new low leaf is real shelter restoration, not only rain interception")
	var high=m.shelters[3]
	var low=m.shelters[2]
	var camera=2340.0-480.0
	check(M.Canopy.rect(low).position.x>=camera and M.Canopy.rect(high).end.x<=camera+1280,"both real leaf silhouettes fit the declared safe observation viewport")
	check(m.shelter_index_at(Vector2(2340,520))==1,"declared observation point remains a real safe area")
	check(m.walls.any(func(w): return w.rect==Rect2(3150,80,65,231)) and m.walls.any(func(w): return w.rect==Rect2(3150,310,710,85)),"upper branch overlaps actual common roof by1px")
func fly(m,target: Vector2):
	for i in 900:
		var delta: Vector2=target-m.p
		if delta.length()<7: break
		var d=Vector2(signf(delta.x) if absf(delta.x)>4 else 0.0,signf(delta.y) if absf(delta.y)>4 else 0.0).normalized()
		m.step(d,false,1.0/60)
	for i in 12: m.step(Vector2.ZERO,false,1.0/60)
	check(m.p.distance_to(target)<30,"ordinary route reaches "+str(target)+" actual="+str(m.p))
func ordinary_choices():
	for high in [false,true]:
		var m=fresh()
		m.rng.seed=206
		m.p=Vector2(2330,520)
		m.started=true
		for i in 2: m.shelters[i].reached=true
		m.checkpoint_index=1
		m.save_checkpoint(Vector2(2170,520))
		for i in 180: m.step(Vector2.ZERO,false,1.0/60)
		check(m.weather_phase=="rain" and m.shelter_index_at(m.p)==1,"both choices begin in actual safe area with rain active")
		if high:
			fly(m,Vector2(2385,450))
			check(m.shield_left>0,"upper route deliberately contacts real shield")
			fly(m,Vector2(2460,380))
			fly(m,Vector2(2860,380))
			fly(m,Vector2(2860,520))
			fly(m,Vector2(3010,520))
			check(m.shelter_index_at(m.p)==3 and m.shield_left>0 and m.shield_left<5,"upper exposure consumes protection before different real landing")
		else:
			fly(m,Vector2(2330,630))
			fly(m,Vector2(2630,600))
			check(m.shelter_index_at(m.p)==2 and m.shield_left==0 and not m.shields[0].collected,"lower route reaches true resting leaf without consuming shield pickup")
			for i in 90: m.step(Vector2.ZERO,false,1.0/60)
			fly(m,Vector2(2780,600))
			fly(m,Vector2(2860,520))
			fly(m,Vector2(3010,520))
		exact(m,"chosen rain landing "+str(high))
		fly(m,Vector2(3158,520))
		fly(m,Vector2(3158,435))
		fly(m,Vector2(3400,435))
		check(m.recoveries==0,"both ordinary choices pass connected common opening without recovery "+str(high))
	# Same original UP/RIGHT loophole height: the new connected stem is a visible obstruction.
	var m=fresh()
	m.p=Vector2(2450,100)
	m.started=true
	for i in 600: m.step(Vector2.RIGHT,false,1.0/60)
	check(m.p.x<3150 and m.recoveries==0,"above-cloud fixed-height bypass meets connected stem")
