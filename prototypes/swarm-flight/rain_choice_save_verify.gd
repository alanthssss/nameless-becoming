extends "res://wind_route_save_verify.gd"
## Preserve v2 rain snapshots as bytes; only current-map rain state may resume in v3.
func suite_name() -> String: return "RAIN CHOICE SAVE"
func folder_environment() -> String: return "SWARM_RAIN_CHOICE_QA_DIR"
func legacy_sources() -> Array:
	return paths("res://review-evidence/2026-11-01/rain-choice/legacy-fixtures",["stage-0","stage-2","checkpoint--1","checkpoint-0","checkpoint-1","checkpoint-2","checkpoint-3","rain-shield-live","rain-shield-committed","after-third","new-overhead-live","new-upper-stem-live","new-low-leaf-live","new-high-leaf-live"])
func shielded_rain():
	var m=fresh(1)
	m.p=m.shields[0].pos
	m.step(Vector2.RIGHT,false,1.0/60)
	for i in 30: m.step(Vector2.ZERO,false,1.0/60)
	check(m.shield_left>0 and m.shields[0].collected,"current rain fixture has a real active shield")
	return m
func current_cases() -> Array:
	return [item("dry",fresh(1).save_payload()),item("shield-live",shielded_rain().save_payload())]
func invalid_cases() -> Array:
	var base=shielded_rain().save_payload()
	var result=[]
	for kind in ["unknown","string-marker","missing-marker","damaged-layout","damaged-prefix","shield-duration"]:
		var bad=base.duplicate(true)
		match kind:
			"unknown": bad.rain_layout_revision=99
			"string-marker": bad.rain_layout_revision="1"
			"missing-marker": bad.erase("rain_layout_revision")
			"damaged-layout": bad.state.checkpoint.shelters[2].name="unknown"
			"damaged-prefix": bad.state.checkpoint.shelters[2].reached=true
			"shield-duration": bad.state.shield_left=M.pack(50.0)
		result.append(mutation(kind,base,bad))
	return result
