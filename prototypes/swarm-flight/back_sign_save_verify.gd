extends SceneTree
const Scene=preload("res://spring_journey.tscn")
const Model=preload("res://spring_journey_model.gd")
const Save=preload("res://save_data.gd")
var checks=0
var failures=0
var folder=OS.get_environment("SWARM_BACK_SIGN_QA_DIR")
func _initialize(): call_deferred("run")
func check(ok: bool,label: String):
 checks+=1
 if not ok:
  failures+=1
  print("FAIL: "+label)
func run():
 if folder.is_empty():
  push_error("SWARM_BACK_SIGN_QA_DIR required")
  quit(1)
  return
 DirAccess.make_dir_recursive_absolute(folder)
 var source="res://review-evidence/2026-11-01/back-sign/legacy-fixtures/stage2-front.json"
 var raw=FileAccess.get_file_as_bytes(source)
 for blocked in [false,true]:
  var path=folder.path_join("blocked.json" if blocked else "save.json")
  var f=FileAccess.open(path,FileAccess.WRITE)
  f.store_buffer(raw)
  f.close()
  var backup=path+".before-route-2-"+FileAccess.get_sha256(path).substr(0,12)+".bak"
  if blocked: DirAccess.make_dir_recursive_absolute(backup)
  var game=Scene.instantiate()
  game.progress_file=path
  root.add_child(game)
  await process_frame
  game.set_process(false)
  game.world.set_process(false)
  game.sound.set_muted(true)
  check(not game.saved_payload.is_empty(),"title recognizes old valid save "+str(blocked))
  game.on_secondary()
  if blocked:
   check(not game.has_saved and game.save_warning,"failed backup is visible save failure")
   check(FileAccess.get_file_as_bytes(path)==raw,"failed backup cannot overwrite original")
  else:
   check(game.has_saved and game.model.front_open and not game.model.passage_open,"continue writes valid new geometry without changing gates")
   check(FileAccess.get_file_as_bytes(backup)==raw,"backup preserves every original byte")
   var data=Save.read_payload(path,Model.new())
   check(data.get("route_geometry_revision")==2,"saved new geometry can cold load")
   check(game.persist_progress() and FileAccess.get_file_as_bytes(backup)==raw,"later saves do not overwrite backup")
  game.queue_free()
  await process_frame
 # Unknown and corrupt files are also retained if the user starts a new game.
 for kind in ["unknown","corrupt"]:
  var path=folder.path_join(kind+".json")
  var contents="broken JSON" if kind=="corrupt" else FileAccess.get_file_as_string(source)
  if kind=="unknown":
   var data=JSON.parse_string(contents)
   data.route_geometry_revision=99
   contents=JSON.stringify(data)
  var f=FileAccess.open(path,FileAccess.WRITE)
  f.store_string(contents)
  f.close()
  var backup=path+".before-route-2-"+FileAccess.get_sha256(path).substr(0,12)+".bak"
  var game=Scene.instantiate()
  game.progress_file=path
  root.add_child(game)
  await process_frame
  game.set_process(false)
  game.world.set_process(false)
  game.sound.set_muted(true)
  check(game.saved_payload.is_empty(),"unsupported file is not resumed "+kind)
  game.on_primary()
  check(game.has_saved and FileAccess.get_file_as_string(backup)==contents,"new game retains unsupported original bytes "+kind)
  game.queue_free()
  await process_frame
 print("BACK SIGN SAVE VERIFIED: %d checks, %d failures" % [checks,failures])
 quit(1 if failures else 0)
