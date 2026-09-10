extends SceneTree
const Scene := preload("res://playtest/year/year_route.tscn")
const Driver := preload("res://tools/year_driver.gd")
const Cinema := preload("res://playtest/year/year_cinema.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var path: String="user://year_test_%d.json" % OS.get_process_id()
 var source_path:=path+".spring"
 var scene=Scene.instantiate()
 scene.import_spring=false
 scene.spring_save_path=path
 root.add_child(scene)
 scene.set_physics_process(false)
 Driver.work(scene.model)
 Driver.home(scene.model)
 scene._save_dawn()
 var saved=JSON.parse_string(FileAccess.get_file_as_string(path))
 assert(saved.term==0 and saved.chapter.day==2)
 var file:=FileAccess.open(source_path,FileAccess.WRITE)
 file.store_string(JSON.stringify(saved));file.close()
 DirAccess.remove_absolute(path)
 var copy=Scene.instantiate()
 copy.spring_save_path=path
 copy.import_path=source_path
 root.add_child(copy)
 copy.set_physics_process(false)
 assert(copy.model.day==2 and FileAccess.file_exists(path))
 assert(JSON.parse_string(FileAccess.get_file_as_string(source_path))==saved,"Migration must not change the old save")
 var bad: Dictionary=saved.duplicate(true)
 bad.term=23
 assert(not copy.restore_spring(bad))
 bad=saved.duplicate(true)
 bad.cinema_seen=["0:5","0:5"]
 assert(not copy.restore_spring(bad))
 assert(copy.model.day==2)
 var c:=Cinema.new()
 assert(not c.begin(0,4))
 for term in range(24):
  for day in [5,10,15]:
   assert(c.begin(term,day))
   c.advance(1,true);assert(c.age==0)
   c.advance(1,false);assert(c.age==1)
   c.skip();assert(not c.active)
   assert(not c.begin(term,day))
   assert(c.replay())
   c.advance(c.duration+1,false);assert(not c.active)
 assert(c.seen.size()==72 and Cinema.valid_seen(c.seen))
 for p in [path,source_path]: DirAccess.remove_absolute(p)
 for s in [scene,copy]:
  s.landscape.route=null
  s.cinema_canvas.route=null
  s.queue_free()
 await process_frame
 print("YEAR PERSISTENCE TEST PASSED: isolated migration, strict save, 72 skippable/replayable/pausable scenes")
 quit()
