extends "res://wind_route_save_verify.gd"
## v3 isolation replaces v2 coordinate migration; the historical contract is in 9611660.
func suite_name() -> String: return "POND SOURCE ROUTES SAVE"
func folder_environment() -> String: return "SWARM_POND_ROUTES_QA_DIR"
func legacy_sources() -> Array:
	return paths("res://review-evidence/2026-11-01/source-routes/legacy-fixtures",["initial","before-fork","future-wall-live","source-observed","stage-1","stage-2"])
func observed_source():
	var m=fresh(0)
	m.p=M.SOURCE
	for i in 50: m.step(Vector2.ZERO,false,1.0/60)
	check(m.observation_valid(),"current source fixture earned its observation")
	return m
func current_cases() -> Array:
	return [item("initial",fresh().save_payload()),item("source-observed",observed_source().save_payload())]
func invalid_cases() -> Array:
	var base=observed_source().save_payload()
	var result=[]
	for kind in ["unknown","string-marker","missing-marker","damaged-layout","changed-source"]:
		var bad=base.duplicate(true)
		match kind:
			"unknown": bad.pond_layout_revision=99
			"string-marker": bad.pond_layout_revision="1"
			"missing-marker": bad.erase("pond_layout_revision")
			"damaged-layout": bad.state.checkpoint.walls.pop_back()
			"changed-source":
				var story=M.unpack(bad.story)
				story.dance.observation.source_id="another-flower"
				bad.story=M.pack(story)
		result.append(mutation(kind,base,bad))
	return result
