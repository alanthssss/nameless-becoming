extends "res://wind_route_save_verify.gd"
## Old actor states stay isolated. Current actor states must survive an exact cold resume.
func suite_name() -> String: return "ORDINARY MOSQUITO SAVE"
func folder_environment() -> String: return "SWARM_MOSQUITO_QA_DIR"
func legacy_sources() -> Array:
	var directory=OS.get_environment("SWARM_MOSQUITO_FIXTURE_DIR")
	if directory.is_empty(): directory="res://review-evidence/2026-11-01/ordinary-mosquito/legacy-fixtures"
	return paths(directory,["idle","aim","chase","return","rest","stage-1","stage-2"])
func active_actor(ticks: int):
	var m=fresh(0)
	m.p=M.SMALL_HOME+Vector2(180,0)
	m.step(Vector2.RIGHT,false,1.0/60)
	for i in ticks: m.step(Vector2.ZERO,false,1.0/60)
	return m
func current_cases() -> Array:
	var aiming=active_actor(10)
	var chasing=active_actor(60)
	check(aiming.small.state=="aim" and chasing.small.state=="chase","current NPC phases produced by ordinary elapsed input")
	return [item("idle",fresh().save_payload()),item("aim",aiming.save_payload()),item("chase",chasing.save_payload()),item("inactive-rain",fresh(1).save_payload())]
func invalid_cases() -> Array:
	var base=active_actor(60).save_payload()
	var result=[]
	for kind in ["unknown","string-marker","missing-marker","unsafe-body","invalid-state","bad-time"]:
		var bad=base.duplicate(true)
		var story=M.unpack(bad.story)
		match kind:
			"unknown": bad.small_actor_revision=99
			"string-marker": bad.small_actor_revision="1"
			"missing-marker": bad.erase("small_actor_revision")
			"unsafe-body": story.small.pos=M.SMALL_HOME+Vector2(500,0)
			"invalid-state": story.small.state="settled"
			"bad-time": story.small.elapsed=-1.0
		bad.story=M.pack(story)
		result.append(mutation(kind,base,bad))
	return result
