extends SceneTree
const Scene:=preload("res://playtest/year/year_route.tscn")
const Driver:=preload("res://tools/year_driver.gd")
const RainDriver:=preload("res://tools/rain_calendar_driver.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var scene=Scene.instantiate()
 scene.spring_save_enabled=false
 scene.import_spring=false
 root.add_child(scene)
 scene.set_physics_process(false)
 for t in range(24):
  assert(scene.term_index==t)
  for d in range(1,16):
   if t==1:
    RainDriver.work(scene.model);RainDriver.home(scene.model,false)
   else:
    Driver.work(scene.model);Driver.home(scene.model,false)
   scene._act()
   if not scene.model.day_finished: scene._act()
   assert(scene.model.day_finished)
   if d%5==0:
    assert(scene.cinema.active and scene.model.completed_days.size()==d)
    var before: Dictionary=scene.model.snapshot().duplicate(true)
    scene.cinema.skip();scene.cinema.replay();scene.cinema.skip()
    assert(scene.model.snapshot()==before,"Replaying must not reward or change gameplay")
   if d<15: scene._next_day()
  var data: Dictionary=JSON.parse_string(JSON.stringify(scene.spring_snapshot()))
  assert(scene.restore_spring(data),"Scene envelope must restore at every term boundary")
  if t<23: scene._next_term()
  await process_frame
 assert(scene.prior_terms.size()==23 and scene.model.complete and scene.cinema.seen.size()==72)
 scene.landscape.route=null
 scene.cinema_canvas.route=null
 scene.queue_free()
 await process_frame
 print("YEAR SCENE TEST PASSED: 360 scene days, 23 transitions, 72 completion dispatches, envelopes and reward-free replays")
 quit()
