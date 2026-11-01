extends SceneTree
const Scene=preload("res://spring_journey.tscn")
const M=preload("res://spring_journey_model.gd")
const Save=preload("res://save_data.gd")
var checks=0
var failures=0
var folder=OS.get_environment("SWARM_MOSQUITO_QA_DIR")
var fixtures=OS.get_environment("SWARM_MOSQUITO_FIXTURE_DIR")
func _initialize(): call_deferred("run")
func check(ok: bool,label: String):
	checks+=1
	if not ok:
		failures+=1
		print("FAIL: "+label)
func write_bytes(path: String,raw: PackedByteArray):
	var f=FileAccess.open(path,FileAccess.WRITE)
	f.store_buffer(raw)
	f.close()
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
func without_small(value: Dictionary) -> Dictionary:
	var copy=value.duplicate(true)
	copy.erase("small")
	return copy
func expected_pond_state(old: Dictionary) -> Dictionary:
	var state=old.state.duplicate(true)
	if old.stage==0:
		var fork=M.pack({"kind":"terrain","material":"hedge","rect":Rect2(2860,330,200,120),"broken":false})
		state.walls.append(fork.duplicate(true))
		state.checkpoint.walls.append(fork.duplicate(true))
	return state
func run():
	if folder.is_empty():
		push_error("SWARM_MOSQUITO_QA_DIR required")
		quit(1)
		return
	if fixtures.is_empty(): fixtures="res://review-evidence/2026-11-01/ordinary-mosquito/legacy-fixtures"
	DirAccess.make_dir_recursive_absolute(folder)
	for name in ["idle","aim","chase","return","rest","stage-1","stage-2"]:
		var raw=FileAccess.get_file_as_bytes(fixtures.path_join("old-"+name+".json"))
		check(not raw.is_empty(),"real legacy fixture bytes exist "+name)
		if raw.is_empty(): continue
		for blocked in [false,true]:
			var label=name+"-"+str(blocked)
			var path=folder.path_join(label+".json")
			write_bytes(path,raw)
			var backup=path+".before-route-2-"+FileAccess.get_sha256(path).substr(0,12)+".bak"
			if blocked: DirAccess.make_dir_recursive_absolute(backup)
			var game=await scene(path)
			check(not game.saved_payload.is_empty(),"title recognizes valid old file "+label)
			game.on_secondary()
			if blocked:
				check(not game.has_saved and game.save_warning,"backup conflict is visible save failure "+label)
				check(FileAccess.get_file_as_bytes(path)==raw,"backup failure preserves original bytes "+label)
			else:
				check(game.has_saved,"continue writes migrated file "+label)
				check(FileAccess.get_file_as_bytes(backup)==raw,"exact old bytes retained "+label)
				var old=JSON.parse_string(raw.get_string_from_utf8())
				var disk=Save.read_payload(path,M.new())
				check(disk.get("small_actor_revision")==1,"new marker is cold-readable "+label)
				var expected=M.new()
				check(expected.restore_payload(old),"independent model accepts old snapshot "+label)
				check(game.model.small==expected.small and game.model.checkpoint_story.small==expected.checkpoint_story.small,"disk path migrates both NPC snapshots "+label)
				check(disk.state==expected_pond_state(old) and disk.get("pond_layout_revision")==1 and disk.stage==old.stage and without_small(disk.story)==without_small(old.story) and without_small(disk.checkpoint_story)==without_small(old.checkpoint_story),"all original non-NPC state and facts retained except declared pond wall "+label)
				var saved: Dictionary=game.model.save_payload()
				await release(game)
				game=await scene(path)
				game.on_secondary()
				check(game.mode=="pause" and game.model.save_payload()==saved,"migrated file cold resumes exact "+label)
				check(game.persist_progress() and FileAccess.get_file_as_bytes(backup)==raw,"later writes retain original backup "+label)
			await release(game)
	var current=M.new()
	current.load_stage(0)
	for kind in ["unknown","corrupt","unsafe-current","bad-legacy"]:
		for blocked in [false,true]:
			var data: Dictionary=current.save_payload()
			if kind=="unknown": data.small_actor_revision=99
			if kind=="unsafe-current":
				var state=M.unpack(data.story)
				state.small.pos=Vector2(2390,360)
				data.story=M.pack(state)
			if kind=="bad-legacy":
				data=JSON.parse_string(FileAccess.get_file_as_string(fixtures.path_join("old-idle.json")))
				data.story["bird_elapsed"]=-1
			var raw=("not valid JSON" if kind=="corrupt" else JSON.stringify(data)).to_utf8_buffer()
			var label=kind+"-"+str(blocked)
			var path=folder.path_join(label+".json")
			write_bytes(path,raw)
			var backup=path+".before-route-2-"+FileAccess.get_sha256(path).substr(0,12)+".bak"
			if blocked: DirAccess.make_dir_recursive_absolute(backup)
			var game=await scene(path)
			check(game.saved_payload.is_empty(),"invalid file never resumes "+label)
			game.on_primary()
			if blocked:
				check(not game.has_saved and game.save_warning and FileAccess.get_file_as_bytes(path)==raw,"new-game backup conflict cannot destroy unsupported bytes "+label)
			else:
				check(game.has_saved and FileAccess.get_file_as_bytes(backup)==raw,"new game retains unsupported original bytes "+label)
			await release(game)
	print("ORDINARY MOSQUITO SAVE VERIFIED: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
