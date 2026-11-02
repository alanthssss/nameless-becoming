extends "res://wind_route_save_verify.gd"
## Old gate snapshots cannot migrate into v3. Current gate consequences stay resumable.
func suite_name() -> String: return "BACK SIGN SAVE"
func folder_environment() -> String: return "SWARM_BACK_SIGN_QA_DIR"
func legacy_sources() -> Array:
	return paths("res://review-evidence/2026-11-01/back-sign/legacy-fixtures",["stage2-closed","stage2-front","stage2-second_gate","stage2-tidy","stage2-settled","stage2-ending"],"")
func open_front():
	# Explicit bounded fixture setup, followed by real charge/gate handling.
	var m=fresh(2)
	m.p=M.KNOT-Vector2(150,0)
	m.keeper.state="counting"
	for i in 27: m.step(Vector2.RIGHT,true,1.0/60)
	for i in 45: m.step(Vector2.ZERO,false,1.0/60)
	check(m.front_open and not m.passage_open,"current first-gate fixture opened through collision rules")
	return m
func open_back():
	var m=open_front()
	m.p=M.BACK_KNOT-Vector2(85,0)
	for i in 27: m.step(Vector2.RIGHT,true,1.0/60)
	for i in 45: m.step(Vector2.ZERO,false,1.0/60)
	check(m.passage_open and m.keeper.state=="tidy","current back-gate fixture begins physical tidy action")
	return m
func current_cases() -> Array:
	var front=open_front()
	var back=open_back()
	var settled=open_back()
	for i in 1200: settled.step(Vector2.ZERO,false,1.0/60)
	check(settled.keeper.state=="settled" and settled.recoveries==0,"current placed-sign fixture completes without recovery")
	return [item("closed",fresh(2).save_payload()),item("front-open",front.save_payload()),item("back-open",back.save_payload()),item("settled",settled.save_payload())]
func invalid_cases() -> Array:
	var base=open_back().save_payload()
	var result=[]
	for kind in ["unknown","string-marker","missing-marker","gate-disagreement","bad-result-time"]:
		var bad=base.duplicate(true)
		match kind:
			"unknown": bad.route_geometry_revision=99
			"string-marker": bad.route_geometry_revision="2"
			"missing-marker": bad.erase("route_geometry_revision")
			"gate-disagreement":
				for wall in bad.state.walls:
					if wall.rect.r[0]==M.BACK_WALL_X and wall.kind=="curtain": wall.broken=false
			"bad-result-time":
				var story=M.unpack(bad.story)
				story.result_elapsed=M.RESULT_SECONDS+1
				bad.story=M.pack(story)
		result.append(mutation(kind,base,bad))
	return result
