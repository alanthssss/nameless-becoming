extends "res://pond_source_states_probe.gd"
## Controlled rain particles and real keyboard lamp traversal; not independent exploration.
func state() -> Dictionary:
	var data: Dictionary=super.state()
	data["drops"]=game.model.drops.map(func(d): return [d.pos.x,d.pos.y])
	data["color_step"]=game.model.color_step
	data["shelter_index"]=game.model.shelter_index_at(game.model.p)
	data["rain_floor"]=game.model.rain_floor_at(game.model.p.x)
	return data
func roof_case(inside: bool):
	section="roof-inside" if inside else "roof-outside"
	var x=1920.0 if inside else 1880.0
	fixture(1,Vector2(x,480))
	check(await until(func(): return game.model.weather_phase=="rain",90),"real dry-warning-rain transition")
	check(game.model.shield_left==0 and game.model.invulnerable==0,"no shield or invulnerability masks rain consequence")
	game.model.drops.clear()
	for field in game.model.rain_fields: field.timer=60.0
	game.model.rain_timer=60.0
	game.model.drops.append({"pos":Vector2(x,295),"vel":Vector2(0,350)})
	seeds.append({"section":section,"frame":frames.size(),"note":"After natural warning/rain transition, replace particles with one physical drop at y295,vy350;other emitters delayed60s to isolate roof boundary. No hurt invocation."})
	check(game.model.rain_floor_at(x)==(330.0 if inside else 750.0),"rendered rain floor agrees with roof extent")
	var start=events.size()
	var energy: float=game.model.stamina
	await shot("01-inside-before" if inside else "03-outside-before")
	await tick(18)
	check(game.model.drops.is_empty(),"physical drop removed by roof or contact")
	check(count("hit",start)==(0 if inside else 1),"roof intercepts inside; exposed drop hits outside")
	check(absf(energy-game.model.stamina-(1.2 if inside else 31.2))<0.05,"energy records only flight drain plus exposed30 hit")
	await shot("02-inside-after" if inside else "04-outside-after")
func run():
	if folder.is_empty():
		push_error("Set SWARM_POND_STATES_DIR to an isolated output directory")
		quit(1)
		return
	native=DisplayServer.get_name()!="headless"
	DirAccess.make_dir_recursive_absolute(folder)
	await new_scene()
	await roof_case(true)
	await roof_case(false)
	section="middle-lamp"
	fixture(1,Vector2(3900,500))
	await tick()
	check(game.model.color_step==1 and game.model.weather_phase=="after","middle lamp uses actual stage1 color and natural after-rain state")
	check(game.model.shelter_index_at(game.model.p)<0,"lamp approach starts outside shelter")
	await shot("05-lamp-approach")
	key(KEY_RIGHT,true)
	check(await until(func(): return game.model.p.x>=4120),"ordinary keyboard enters last shelter")
	release_keys()
	check(game.model.shelter_index_at(game.model.p)==game.model.shelters.size()-1,"player under last lamp")
	await shot("06-lamp-middle-color")
	key(KEY_RIGHT,true)
	check(await until(func(): return game.model.p.x>=4340),"ordinary keyboard exits last shelter")
	release_keys()
	check(game.model.shelter_index_at(game.model.p)<0,"lamp exit outside shelter")
	await shot("07-lamp-exit")
	check(frames.all(func(f): return f.cue_clear and f.cue_caption_clear),"cue remains clear of player and feedback")
	var file=FileAccess.open(folder.path_join("trace.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"kind":"controlled physical roof rain and middle lamp native source evidence;not full journey or player exploration","native":native,"checks":assertions.size(),"failures":failures,"seeds":seeds,"assertions":assertions,"events":events,"frames":frames},"\t"))
	file.close()
	game.queue_free()
	await process_frame
	print("RAIN SOURCES VERIFIED: %d checks, %d failures" % [assertions.size(),failures])
	quit(1 if failures else 0)
