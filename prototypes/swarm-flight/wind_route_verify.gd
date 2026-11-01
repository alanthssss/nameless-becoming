extends SceneTree
## v3 identity isolation, current exact resume and static-layout integrity.
## v2 migration evidence remains archived in 0.17.0 / 9611660, not applied to v3.
const M=preload("res://spring_journey_model.gd")
const FIXTURES="res://review-evidence/2026-11-01/final-candidate/wind-choice/legacy-fixtures/"
var checks=0
var failures=0
func _initialize(): call_deferred("run")
func normalized(value): return JSON.parse_string(JSON.stringify(value,"",true,true))
func check(ok: bool,label: String):
	checks+=1
	if not ok: failures+=1;print("FAIL: "+label)
func fresh(stage:=0):
	var m=M.new();m.load_stage(stage);return m
func reject(data: Dictionary,label: String):
	var m=fresh();var before=m.save_payload();var original=data.duplicate(true)
	check(not m.restore_payload(data) and m.save_payload()==before and data==original,"atomic rejection "+label)
func live_wind():
	var m=fresh(0)
	m.p=m.rings[0].pos-Vector2(170,0)
	for i in 27: m.step(Vector2.RIGHT,true,1.0/60)
	for i in 12: m.step(Vector2.ZERO,false,1.0/60)
	check(m.rings_hit>0 and m.burst_left>0,"fixture reached live wind using current ordinary inputs")
	return m
func run():
	for name in ["stage0","stage1","stage2-unopened","before-first-charge","front-open-live-burst","first-wind-active","both-open","settled-after-double-open"]:
		var data=JSON.parse_string(FileAccess.get_file_as_string(FIXTURES+"old-"+name+".json"))
		check(data is Dictionary and data.get("journey_id")=="spring-03-05-v2","genuine v2 identity "+name)
		reject(data,"old journey stays isolated "+name)
	for name in ["stage2-closed","stage2-front","stage2-foraging","stage2-tidy","stage2-settled","stage2-second_gate","stage2-ending"]:
		var data=JSON.parse_string(FileAccess.get_file_as_string("res://review-evidence/2026-11-01/back-sign/legacy-fixtures/"+name+".json"))
		reject(data,"earlier v2 gate state stays isolated "+name)
	var current=live_wind().save_payload()
	for saved in [fresh(0).save_payload(),fresh(1).save_payload(),fresh(2).save_payload(),current]:
		var clone=fresh();var original=saved.duplicate(true)
		check(clone.restore_payload(normalized(saved)) and clone.save_payload()==saved and saved==original,"exact current JSON resume stage "+str(saved.stage))
		var other=fresh();other.restore_payload(saved)
		for i in 24:
			clone.step(Vector2.RIGHT,false,1.0/60)
			other.step(Vector2.RIGHT,false,1.0/60)
		check(clone.save_payload()==other.save_payload(),"current next 24 inputs agree stage "+str(saved.stage))
	# Each mutation starts from this explicitly accepted current live-wind save.
	check(fresh().restore_payload(current),"unmodified tamper baseline is accepted")
	for snapshot in ["live","checkpoint"]:
		for defect in ["position","direction","ring-count","wall","shelter","prefix","index","active-type","velocity","missing-key"]:
			var bad=current.duplicate(true)
			var state=bad.state if snapshot=="live" else bad.state.checkpoint
			match defect:
				"position": state.rings[0].pos=M.pack(Vector2(2760,280))
				"direction": state.rings[0].direction=M.pack(Vector2.UP)
				"ring-count": state.rings.pop_back()
				"wall": state.walls[0].rect.r[2]+=1
				"shelter": state.shelters[0].name="unknown"
				"prefix": state.shelters[-1].reached=true
				"index": state.checkpoint_index=99
				"active-type": state.rings[0].active="true"
				"velocity":
					if snapshot=="live": state.velocity=M.pack(Vector2(9999,0))
					else: state.p="bad"
				"missing-key": state.erase("rings")
			reject(bad,"current "+snapshot+" "+defect)
	for key in ["wind_layout_revision","rain_layout_revision","pond_layout_revision","small_actor_revision","preparation_revision","route_geometry_revision","keeper_presentation_revision"]:
		for marker in [99,-1,"1",null,true]:
			var bad=current.duplicate(true);bad[key]=marker;reject(bad,"current typed marker "+key+" "+str(marker))
		var missing=current.duplicate(true);missing.erase(key);reject(missing,"current missing marker "+key)
	print("WIND ROUTE VERIFIED: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
