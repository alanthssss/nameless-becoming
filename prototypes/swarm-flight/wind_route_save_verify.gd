extends SceneTree
## v3 disk isolation and exact-current resume. The v2 migration contract remains
## archived at 0.17.0 / 9611660; these checks never claim migration into this map.
## Related save suites inherit this lifecycle harness and supply domain fixtures.
const Scene=preload("res://spring_journey.tscn")
const M=preload("res://spring_journey_model.gd")
const Save=preload("res://save_data.gd")
var checks=0
var failures=0
var folder=""
func _initialize(): call_deferred("run")
func suite_name() -> String: return "WIND ROUTE SAVE"
func folder_environment() -> String: return "SWARM_WIND_ROUTE_QA_DIR"
func check(ok: bool,label: String):
	checks+=1
	if not ok:
		failures+=1
		print("FAIL: "+label)
func paths(directory: String,names: Array,prefix:="old-") -> Array:
	var result=[]
	for name in names: result.append(directory.path_join(prefix+name+".json"))
	return result
func legacy_sources() -> Array:
	return paths("res://review-evidence/2026-11-01/final-candidate/wind-choice/legacy-fixtures",["stage0","stage1","stage2-unopened","before-first-charge","front-open-live-burst","first-wind-active","both-open","settled-after-double-open"])
func fresh(stage:=0):
	var m=M.new();m.load_stage(stage);return m
func item(label: String,payload: Dictionary) -> Dictionary:
	return {"label":label,"payload":payload}
func mutation(label: String,base: Dictionary,bad: Dictionary) -> Dictionary:
	return {"label":label,"base":base,"bad":bad}
func live_wind():
	# A bounded current-map fixture; subsequent state comes from ordinary input.
	var m=fresh(0)
	m.p=m.rings[0].pos-Vector2(170,0)
	for i in 27: m.step(Vector2.RIGHT,true,1.0/60)
	for i in 12: m.step(Vector2.ZERO,false,1.0/60)
	check(m.rings_hit>0 and m.burst_left>0,"current fixture is genuinely mid-wind")
	return m
func current_cases() -> Array:
	return [item("stage0",fresh(0).save_payload()),item("stage1",fresh(1).save_payload()),item("stage2",fresh(2).save_payload()),item("live-wind",live_wind().save_payload())]
func invalid_cases() -> Array:
	var base=live_wind().save_payload()
	var result=[]
	for kind in ["unknown","string-marker","missing-marker","damaged-layout","damaged-prefix"]:
		var bad=base.duplicate(true)
		match kind:
			"unknown": bad.wind_layout_revision=99
			"string-marker": bad.wind_layout_revision="1"
			"missing-marker": bad.erase("wind_layout_revision")
			"damaged-layout": bad.state.checkpoint.rings[0].direction=M.pack(Vector2.UP)
			"damaged-prefix": bad.state.checkpoint.shelters[-1].reached=true
		result.append(mutation(kind,base,bad))
	return result
func write_bytes(path: String,raw: PackedByteArray):
	var file=FileAccess.open(path,FileAccess.WRITE)
	file.store_buffer(raw)
	file.close()
func backup_path(path: String) -> String:
	return path+".before-rebuild-v3-"+FileAccess.get_sha256(path).substr(0,12)+".bak"
func scene(path: String):
	var game=Scene.instantiate()
	game.progress_file=path
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.world.set_process(false)
	game.sound.set_muted(true)
	return game
func release(game):
	game.queue_free()
	await process_frame
func independent_paths(raw: PackedByteArray):
	var old_path=folder.path_join("spring_03_05_v2.json")
	var new_path=folder.path_join(M.SPRING_SAVE_PATH.get_file())
	check(M.SPRING_SAVE_PATH=="user://pond_journey_rebuild_v3.json" and M.new().journey_id()=="pond-journey-rebuild-v3","new default path and identity are separate")
	write_bytes(old_path,raw)
	var game=await scene(new_path)
	check(game.saved_payload.is_empty() and game.journey_save_path()==M.SPRING_SAVE_PATH,"new title never offers the adjacent v2 file")
	game.on_primary()
	check(game.has_saved and not Save.read_payload(new_path,M.new()).is_empty() and FileAccess.get_file_as_bytes(old_path)==raw,"new play writes only its new file and leaves v2 bytes untouched")
	await release(game)
func protected_new_game(raw: PackedByteArray,label: String):
	for blocked in [false,true]:
		var path=folder.path_join(label+"-"+str(blocked)+".json")
		write_bytes(path,raw)
		var backup=backup_path(path)
		if blocked: DirAccess.make_dir_recursive_absolute(backup)
		var game=await scene(path)
		check(game.saved_payload.is_empty() and FileAccess.get_file_as_bytes(path)==raw,"unsupported title refuses continue without rewriting "+label)
		game.on_secondary()
		check(game.mode=="title" and FileAccess.get_file_as_bytes(path)==raw,"continue cannot reinterpret unsupported coordinates "+label)
		# An explicitly selected old path may be reused only after preserving it.
		game.on_primary()
		if blocked:
			check(not game.has_saved and game.save_warning and FileAccess.get_file_as_bytes(path)==raw,"failed backup cannot overwrite original "+label)
		else:
			check(game.has_saved and FileAccess.get_file_as_bytes(backup)==raw,"explicit new game keeps every original byte "+label)
			var disk=Save.read_payload(path,M.new())
			check(disk.get("journey_id")==M.new().journey_id() and int(disk.get("stage",-1))==0,"replacement is a fresh v3 journey, not migrated progress "+label)
			check(game.persist_progress() and FileAccess.get_file_as_bytes(backup)==raw,"later writes preserve original backup "+label)
		await release(game)
func exact_current(entry: Dictionary):
	var payload: Dictionary=entry.payload
	var validator=fresh()
	var accepted: bool=validator.restore_payload(payload)
	check(accepted and validator.save_payload()==payload,"current baseline is valid and exact "+entry.label)
	if not accepted: return
	var path=folder.path_join("current-"+entry.label+".json")
	write_bytes(path,JSON.stringify(payload,"",true,true).to_utf8_buffer())
	var original_backup=backup_path(path)
	var game=await scene(path)
	check(not game.saved_payload.is_empty(),"title recognizes current save "+entry.label)
	game.on_secondary()
	check(game.mode=="pause" and game.model.save_payload()==payload,"current cold resume is exact "+entry.label)
	var expected=fresh();expected.restore_payload(payload)
	for i in 8:
		expected.step(Vector2.RIGHT,false,1.0/60)
		game.model.step(Vector2.RIGHT,false,1.0/60)
	check(game.model.save_payload()==expected.save_payload(),"current next inputs remain deterministic "+entry.label)
	check(game.persist_progress() and not FileAccess.file_exists(original_backup),"valid current writes need no migration backup "+entry.label)
	var saved: Dictionary=game.model.save_payload()
	await release(game)
	game=await scene(path)
	game.on_secondary()
	check(game.mode=="pause" and game.model.save_payload()==saved,"current progress survives second cold reopen "+entry.label)
	await release(game)
func run():
	folder=OS.get_environment(folder_environment())
	if folder.is_empty(): push_error(folder_environment()+" required");quit(1);return
	folder=folder.path_join(suite_name().to_lower().replace(" ","-")+"-v3-"+str(OS.get_process_id())+"-"+str(Time.get_ticks_usec()))
	DirAccess.make_dir_recursive_absolute(folder)
	var sources=legacy_sources()
	if not sources.is_empty(): await independent_paths(FileAccess.get_file_as_bytes(sources[0]))
	for path in sources:
		var raw=FileAccess.get_file_as_bytes(path)
		check(not raw.is_empty(),"genuine v2 fixture exists "+path.get_file())
		var old=JSON.parse_string(raw.get_string_from_utf8())
		check(old is Dictionary and old.get("journey_id")=="spring-03-05-v2","fixture has real older identity "+path.get_file())
		await protected_new_game(raw,"legacy-"+path.get_file().get_basename())
	for entry in current_cases(): await exact_current(entry)
	for entry in invalid_cases():
		var baseline=fresh()
		check(baseline.restore_payload(entry.base),"tamper test starts from accepted current payload "+entry.label)
		var receiver=fresh();var before=receiver.save_payload();var original=entry.bad.duplicate(true)
		check(not receiver.restore_payload(entry.bad) and receiver.save_payload()==before and entry.bad==original,"current tamper rejects atomically "+entry.label)
		await protected_new_game(JSON.stringify(entry.bad,"",true,true).to_utf8_buffer(),"invalid-"+entry.label)
	await protected_new_game("not JSON".to_utf8_buffer(),"corrupt")
	print("%s VERIFIED: %d checks, %d failures" % [suite_name(),checks,failures])
	quit(1 if failures else 0)
