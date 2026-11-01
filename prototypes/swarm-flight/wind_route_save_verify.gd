extends SceneTree
const Scene=preload("res://spring_journey.tscn")
const M=preload("res://spring_journey_model.gd")
const Save=preload("res://save_data.gd")
const FIXTURES="res://review-evidence/2026-11-01/final-candidate/wind-choice/legacy-fixtures/"
var checks=0
var failures=0
var folder=OS.get_environment("SWARM_WIND_ROUTE_QA_DIR")
func _initialize(): call_deferred("run")
func check(ok: bool,label: String):
	checks+=1
	if not ok:
		failures+=1
		print("FAIL: "+label)
func write_bytes(path: String,raw: PackedByteArray):
	var file=FileAccess.open(path,FileAccess.WRITE)
	file.store_buffer(raw)
	file.close()
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
func run():
	if folder.is_empty(): push_error("SWARM_WIND_ROUTE_QA_DIR required"); quit(1); return
	DirAccess.make_dir_recursive_absolute(folder)
	for name in ["stage0","stage1","stage2-unopened","before-first-charge","front-open-live-burst","first-wind-active","both-open","settled-after-double-open"]:
		var raw=FileAccess.get_file_as_bytes(FIXTURES+"old-"+name+".json")
		check(not raw.is_empty(),"genuine old bytes exist "+name)
		for blocked in [false,true]:
			var label=name+"-"+str(blocked)
			var path=folder.path_join(label+".json")
			write_bytes(path,raw)
			var backup=path+".before-route-2-"+FileAccess.get_sha256(path).substr(0,12)+".bak"
			if blocked: DirAccess.make_dir_recursive_absolute(backup)
			var game=await scene(path)
			check(not game.saved_payload.is_empty(),"title recognizes true old save "+label)
			game.on_secondary()
			if blocked:
				check(not game.has_saved and game.save_warning and FileAccess.get_file_as_bytes(path)==raw,"backup failure cannot overwrite old bytes "+label)
			else:
				var disk=Save.read_payload(path,M.new())
				check(game.has_saved and disk.get("wind_layout_revision")==1,"current marker is cold readable "+label)
				check(FileAccess.get_file_as_bytes(backup)==raw,"original SHA backup retains exact bytes "+label)
				check(game.model.recoveries==int(JSON.parse_string(raw.get_string_from_utf8()).state.recoveries),"wind-only migration does not invent recovery "+label)
				var saved=game.model.save_payload()
				await release(game)
				game=await scene(path)
				game.on_secondary()
				check(game.mode=="pause" and game.model.save_payload()==saved,"exact current cold reopen "+label)
				var current_backup=path+".before-route-2-"+FileAccess.get_sha256(path).substr(0,12)+".bak"
				check(game.persist_progress() and not FileAccess.file_exists(current_backup) and FileAccess.get_file_as_bytes(backup)==raw,"current rewrite creates no redundant backup "+label)
			await release(game)
	for kind in ["unknown","string-marker","corrupt","damaged-layout","damaged-prefix","new-without-marker"]:
		for blocked in [false,true]:
			var data=JSON.parse_string(FileAccess.get_file_as_string(FIXTURES+"old-front-open-live-burst.json"))
			if kind=="unknown": data.wind_layout_revision=99
			if kind=="string-marker": data.wind_layout_revision="1"
			if kind=="damaged-layout": data.state.checkpoint.rings[0].direction=M.pack(Vector2.UP)
			if kind=="damaged-prefix": data.state.checkpoint.shelters[-1].reached=true
			if kind=="new-without-marker":
				var m=M.new();m.load_stage(2);data=m.save_payload();data.erase("wind_layout_revision")
			var raw=("not JSON" if kind=="corrupt" else JSON.stringify(data,"",true,true)).to_utf8_buffer()
			var label=kind+"-"+str(blocked)
			var path=folder.path_join(label+".json")
			write_bytes(path,raw)
			var backup=path+".before-route-2-"+FileAccess.get_sha256(path).substr(0,12)+".bak"
			if blocked: DirAccess.make_dir_recursive_absolute(backup)
			var game=await scene(path)
			check(game.saved_payload.is_empty() and FileAccess.get_file_as_bytes(path)==raw,"invalid save refuses continue without mutation "+label)
			game.on_primary()
			if blocked: check(not game.has_saved and game.save_warning and FileAccess.get_file_as_bytes(path)==raw,"new game preserves unsupported bytes on backup failure "+label)
			else: check(game.has_saved and FileAccess.get_file_as_bytes(backup)==raw,"new game backs up unsupported bytes "+label)
			await release(game)
	print("WIND ROUTE SAVE VERIFIED: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
