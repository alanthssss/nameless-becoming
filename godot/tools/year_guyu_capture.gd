extends SceneTree
const Preview:=preload("res://playtest/year/guyu/guyu_preview.tscn")
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var output: String=OS.get_cmdline_user_args()[0]
 DirAccess.make_dir_recursive_absolute(output)
 var scene=Preview.instantiate()
 root.add_child(scene)
 scene.set_process(false)
 scene.film.set_process(false)
 scene.music.stop()
 for stamp in [3.2,6.8,9.1,11.2,12.8,15.5,18.3,22.5]:
  scene.cinema.age=stamp
  scene.visual_time=stamp
  scene.film.queue_redraw()
  await process_frame
  RenderingServer.force_draw(false)
  root.get_texture().get_image().save_png(output.path_join("shot-%03d.png" % int(stamp*10)))
 scene.queue_free()
 await process_frame
 print("YEAR GUYU CAPTURE TEST PASSED: eight authored poses rendered")
 quit()
