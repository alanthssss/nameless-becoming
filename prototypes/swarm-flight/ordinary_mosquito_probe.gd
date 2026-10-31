extends "res://pond_source_states_probe.gd"
## Fixed-scale actor evidence using real input/rendering; controlled starts disclosed.
func state() -> Dictionary:
	var data: Dictionary=super.state()
	var point: Vector2=game.model.small.pos
	data["mosquito_clear"]=game.model.shelters.all(func(leaf): return Canopy.clear_disk(point,52.0,Canopy.polygon(leaf))) and game.model.walls.all(func(w): return w.broken or not w.rect.grow(52).has_point(point))
	return data
func run():
	if folder.is_empty():
		push_error("Set SWARM_POND_STATES_DIR to an isolated output directory")
		quit(1)
		return
	native=DisplayServer.get_name()!="headless"
	DirAccess.make_dir_recursive_absolute(folder)
	await new_scene()
	await mosquito_cycle()
	section="old-penetration-counterexample"
	fixture(0,Vector2(2320,300))
	await tick(180)
	check(frames.filter(func(f): return f.section==section).all(func(f): return f.mosquito_clear),"old133/180 centre-inside counterexample now has whole52px body clear")
	await shot("11-old-leaf-counterexample")
	section="near-leaf-aim-and-cold"
	fixture(0,Vector2(2520,320))
	check(await until(func(): return game.model.small.state=="aim"),"visible near-leaf player can be observed without fitting mosquito body")
	await shot("12-near-leaf-aim")
	await cold_resume("ordinary mosquito aim near leaf")
	check(await until(func(): return game.model.small.state=="chase"),"resumed aim continues into chase")
	check(await until(func(): return game.model.small.state=="return"),"body obstruction aborts chase instead of entering leaf")
	await shot("13-chase-stopped-at-leaf")
	check(await until(func(): return game.model.small.state=="rest"),"blocked chase returns to clear home")
	await shot("14-clear-home")
	release_keys()
	check(frames.all(func(f): return f.mosquito_clear),"whole mosquito body clear of actual leaf and walls in every sampled frame")
	check(frames.all(func(f): return f.cue_clear and f.cue_caption_clear),"existing bee and damage feedback remain clear")
	var f=FileAccess.open(folder.path_join("trace.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify({"kind":"ordinary mosquito native source fixture;not full journey/exploration","native":native,"checks":assertions.size(),"failures":failures,"seeds":seeds,"assertions":assertions,"events":events,"frames":frames},"\t"))
	f.close()
	game.queue_free()
	await process_frame
	print("ORDINARY MOSQUITO NATIVE VERIFIED: %d checks, %d failures" % [assertions.size(),failures])
	quit(1 if failures else 0)
