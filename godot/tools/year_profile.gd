extends SceneTree
const Scene := preload("res://playtest/year/year_route.tscn")
var scene
var output: String
var samples: Array=[]
func _initialize() -> void: call_deferred("run")
func run() -> void:
 output=OS.get_cmdline_user_args()[0]
 DirAccess.make_dir_recursive_absolute(output)
 scene=Scene.instantiate()
 scene.spring_save_enabled=false
 scene.import_spring=false
 root.add_child(scene)
 scene.set_physics_process(false)
 var history: Dictionary={}
 for i in range(200): history["wake:%d" % i]={"kind":"wake","x":float(i%20*170+100),"y":float(i/20*180+100),"shape":i%3}
 history["repair:0"]={"kind":"repair","x":1800.0,"y":930.0,"shape":0}
 for entry in [[2,11],[2,12],[2,13],[7,3],[13,2],[19,6],[23,14]]:
  scene.world=history.duplicate(true)
  scene.term_index=entry[0]
  scene.model=scene.make_model(entry[0])
  scene.model.day=entry[1]
  scene.model.start_day()
  var targets: Array=scene.model.objective_points()
  scene.model.position=targets[0] if not targets.is_empty() else scene.model.HIVE
  scene.camera_center=scene.model.position
  scene._update_camera(1)
  scene.landscape.route=null
  scene.landscape.queue_free()
  scene.landscape=Node2D.new()
  scene.landscape.set_script(scene.landscape_script())
  scene.landscape.route=scene
  scene.landscape.show_behind_parent=true
  scene.add_child(scene.landscape)
  var draws: Array=[]
  var frames: Array=[]
  var stamp:=Time.get_ticks_usec()
  for frame in range(145):
   scene.paused=false
   scene._physics_process(1.0/60)
   await process_frame
   var now:=Time.get_ticks_usec()
   if frame>24:
    draws.append(scene.landscape.last_draw_us/1000.0)
    frames.append((now-stamp)/1000.0)
   stamp=now
  draws.sort();frames.sort()
  samples.append({"term":entry[0],"day":entry[1],"draw_p50_ms":draws[60],"draw_p95_ms":draws[114],"frame_p50_ms":frames[60],"frame_p95_ms":frames[114],"history_count":history.size()})
  RenderingServer.force_draw(false)
  root.get_texture().get_image().save_png(output.path_join("term-%02d-day-%02d.png" % [entry[0]+1,entry[1]]))
 for term in [5,11,17,23]:
  scene.cinema.begin(term,15)
  scene.cinema.age=4.5
  scene.cinema_canvas.visible=true
  scene.cinema_canvas.queue_redraw()
  await process_frame
  RenderingServer.force_draw(false)
  root.get_texture().get_image().save_png(output.path_join("finale-%d.png" % int(term/6)))
  scene.cinema.skip()
 var file:=FileAccess.open(output.path_join("profile.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify(samples,"  "));file.close()
 print(JSON.stringify(samples))
 scene.landscape.route=null
 scene.cinema_canvas.route=null
 scene.queue_free()
 await process_frame
 print("YEAR PROFILE PASSED: seven native scenes and four cinematic snapshots; no player save touched")
 quit()
