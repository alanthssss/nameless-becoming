extends SceneTree
## Disk/title lifecycle checks with byte-preserved genuine previous-model fixtures.
const Scene=preload("res://spring_journey.tscn")
const M=preload("res://spring_journey_model.gd")
const Save=preload("res://save_data.gd")
const FIXTURES="res://review-evidence/2026-11-01/source-routes/legacy-fixtures/"
var checks=0
var failures=0
var folder=OS.get_environment("SWARM_POND_ROUTES_QA_DIR")
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
	if folder.is_empty(): push_error("SWARM_POND_ROUTES_QA_DIR required"); quit(1); return
	DirAccess.make_dir_recursive_absolute(folder)
	for name in ["initial","before-fork","future-wall-live","source-observed","stage-1","stage-2"]:
		var raw=FileAccess.get_file_as_bytes(FIXTURES+"old-"+name+".json")
		check(not raw.is_empty(),"real old bytes exist "+name)
		for blocked in [false,true]:
			var label=name+"-"+str(blocked)
			var path=folder.path_join(label+".json")
			write_bytes(path,raw)
			var backup=path+".before-route-2-"+FileAccess.get_sha256(path).substr(0,12)+".bak"
			if blocked: DirAccess.make_dir_recursive_absolute(backup)
			var game=await scene(path)
			check(not game.saved_payload.is_empty(),"title recognizes legal genuine old file "+label)
			game.on_secondary()
			if blocked:
				check(not game.has_saved and game.save_warning and FileAccess.get_file_as_bytes(path)==raw,"backup failure preserves old bytes and shows failure "+label)
			else:
				var disk=Save.read_payload(path,M.new())
				check(game.has_saved and disk.get("pond_layout_revision")==1,"continue writes readable layout marker "+label)
				check(FileAccess.get_file_as_bytes(backup)==raw,"original bytes retained under original SHA backup "+label)
				if name=="future-wall-live": check(game.model.p==Vector2(2770,500) and game.heading.text=="已回到安全的落脚点","geometry recovery is visible on continue")
				var saved=game.model.save_payload()
				await release(game)
				game=await scene(path)
				game.on_secondary()
				check(game.mode=="pause" and game.model.save_payload()==saved,"migrated current file resumes exact on cold reopen "+label)
				var current_backup=path+".before-route-2-"+FileAccess.get_sha256(path).substr(0,12)+".bak"
				check(game.persist_progress() and FileAccess.get_file_as_bytes(backup)==raw and not FileAccess.file_exists(current_backup),"current save avoids redundant backup and retains original "+label)
			await release(game)
	for kind in ["unknown","string-marker","corrupt","unsafe-checkpoint","damaged-legacy"]:
		for blocked in [false,true]:
			var data=JSON.parse_string(FileAccess.get_file_as_string(FIXTURES+"old-"+("unsafe-checkpoint" if kind=="unsafe-checkpoint" else "before-fork")+".json"))
			if kind=="unknown": data.pond_layout_revision=99
			if kind=="string-marker": data.pond_layout_revision="1"
			if kind=="damaged-legacy": data.state.checkpoint.walls.pop_back()
			var raw=("not JSON" if kind=="corrupt" else JSON.stringify(data,"",true,true)).to_utf8_buffer()
			var label=kind+"-"+str(blocked)
			var path=folder.path_join(label+".json")
			write_bytes(path,raw)
			var backup=path+".before-route-2-"+FileAccess.get_sha256(path).substr(0,12)+".bak"
			if blocked: DirAccess.make_dir_recursive_absolute(backup)
			var game=await scene(path)
			check(game.saved_payload.is_empty() and FileAccess.get_file_as_bytes(path)==raw,"invalid file refuses continue without byte mutation "+label)
			game.on_primary()
			if blocked: check(not game.has_saved and game.save_warning and FileAccess.get_file_as_bytes(path)==raw,"new-game backup failure preserves unsupported bytes "+label)
			else: check(game.has_saved and FileAccess.get_file_as_bytes(backup)==raw,"explicit new game preserves unsupported original bytes "+label)
			await release(game)
	print("POND SOURCE ROUTES SAVE VERIFIED: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
