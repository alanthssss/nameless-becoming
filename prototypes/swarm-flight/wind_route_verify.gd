extends SceneTree
## True old snapshots plus independent exact migration delta. Known-answer verification.
const M=preload("res://spring_journey_model.gd")
const E=preload("res://wind_layout_expectations.gd")
const FIXTURES="res://review-evidence/2026-11-01/final-candidate/wind-choice/legacy-fixtures/"
var checks=0
var failures=0
func _initialize():call_deferred("run")
func normalized(v):return JSON.parse_string(JSON.stringify(v,"",true,true))
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures+=1;print("FAIL: "+label)
func fixture(name:String):return JSON.parse_string(FileAccess.get_file_as_string(FIXTURES+"old-"+name+".json"))
func fresh(stage:=0):
	var m=M.new();m.load_stage(stage);return m
func reject(data:Dictionary,label:String):
	var m=fresh();var before=m.save_payload();var original=data.duplicate(true)
	check(not m.restore_payload(data) and m.save_payload()==before and data==original,"atomic rejection "+label)
func run():
	for name in ["stage0","stage1","stage2-unopened","before-first-charge","front-open-live-burst","first-wind-active","both-open","settled-after-double-open"]:
		var data=fixture(name);var original=data.duplicate(true);var m=fresh()
		check(not data.has("wind_layout_revision") and m.restore_payload(data) and data==original,"real old accept atomic "+name)
		check(normalized(m.save_payload())==normalized(E.upgraded(original)),"only declared two first-wind fields and marker "+name)
		var saved=m.save_payload();var clone=fresh()
		check(clone.restore_payload(normalized(saved)) and clone.save_payload()==saved,"exact current resume "+name)
		if name in ["front-open-live-burst","first-wind-active"]:
			check(m.burst_left>0 and m.velocity==M.unpack(original.state.velocity) and m.recoveries==int(original.state.recoveries),"live burst velocity and recovery facts preserved "+name)
	for snapshot in ["live","checkpoint"]:
		for defect in ["position","direction","ring-count","wall","shelter","prefix","index","active-type","velocity","missing-key"]:
			var bad=fixture("front-open-live-burst")
			var state=bad.state if snapshot=="live" else bad.state.checkpoint
			match defect:
				"position":state.rings[0].pos=M.pack(Vector2(2760,280))
				"direction":state.rings[0].direction=M.pack(Vector2.UP)
				"ring-count":state.rings.pop_back()
				"wall":state.walls[0].rect.r[2]+=1
				"shelter":state.shelters[0].name="unknown"
				"prefix":state.shelters[-1].reached=true
				"index":state.checkpoint_index=99
				"active-type":state.rings[0].active="true"
				"velocity":
					if snapshot=="live":state.velocity=M.pack(Vector2(9999,0))
					else:state.p="bad"
				"missing-key":state.erase("rings")
			reject(bad,snapshot+" "+defect)
	var current=fresh(2).save_payload()
	for marker in [2,-1,"1",null,true]:
		var bad=current.duplicate(true);bad.wind_layout_revision=marker;reject(bad,"wind marker "+str(marker))
	var stripped=current.duplicate(true);stripped.erase("wind_layout_revision");reject(stripped,"new layout cannot masquerade as old")
	for key in ["rain_layout_revision","pond_layout_revision","small_actor_revision","preparation_revision","route_geometry_revision","keeper_presentation_revision"]:
		var bad=fixture("stage2-unopened");bad[key]="1";reject(bad,"earlier typed marker "+key)
	# Genuine earlier marker chains remain valid; they cannot bypass complete static validation.
	for name in ["stage2-closed","stage2-front","stage2-foraging","stage2-tidy","stage2-settled","stage2-second_gate","stage2-ending"]:
		var old=JSON.parse_string(FileAccess.get_file_as_string("res://review-evidence/2026-11-01/back-sign/legacy-fixtures/"+name+".json"))
		var m=fresh();check(m.restore_payload(old),"earliest two-flower route converts "+name)
		var payload=m.save_payload();var clone=fresh();check(clone.restore_payload(normalized(payload)) and clone.save_payload()==payload,"earliest chain exact current "+name)
		var bad=old.duplicate(true);bad.state.checkpoint.rings[0].direction=M.pack(Vector2.UP);reject(bad,"earliest chain damaged static "+name)
	print("WIND ROUTE VERIFIED: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
