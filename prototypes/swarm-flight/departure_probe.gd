extends SceneTree
## Controlled source fixtures; seed views only. Not a first-time player review.
const Scene=preload("res://spring_journey.tscn")
const Model=preload("res://spring_journey_model.gd")
var game
var folder=OS.get_environment("SWARM_DEPARTURE_QA_DIR")
var checks=0
var failures=0
var samples=[]
var captured={}
func _initialize(): call_deferred("run")
func check(ok: bool,label: String):
 checks+=1
 if not ok:
  failures+=1
  print("FAIL: "+label)
func key(code: Key,down: bool):
 var e=InputEventKey.new()
 e.physical_keycode=code
 e.keycode=code
 e.pressed=down
 root.push_input(e)
func tap(code: Key):
 key(code,true)
 key(code,false)
func tick(n=1):
 for i in n:
  game.tick(1.0/30)
  game.world._process(1.0/30)
  samples.append({"frame":samples.size(),"p":[game.model.p.x,game.model.p.y],"keeper":[game.model.keeper.pos.x,game.model.keeper.pos.y],"work":game.model.keeper.elapsed,"mode":game.mode})
  await process_frame
func shot(label: String):
 if captured.has(label) or DisplayServer.get_name()=="headless": return
 captured[label]=true
 game.queue_redraw()
 game.world.queue_redraw()
 await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(folder.path_join(label+".png"))==OK,"capture "+label)
func new_scene():
 game=Scene.instantiate()
 game.progress_file=folder.path_join("save.json")
 root.add_child(game)
 await process_frame
 game.set_process(false)
 game.world.set_process(false)
 game.sound.set_muted(true)
func cold_resume(label: String):
 tap(KEY_ESCAPE)
 var before: Dictionary=game.model.save_payload()
 check(game.mode=="pause" and game.has_saved,"disk pause "+label)
 await tick(8)
 check(game.model.save_payload()==before,"paused preparation frozen "+label)
 game.queue_free()
 await process_frame
 await new_scene()
 game.on_secondary()
 check(game.mode=="pause" and game.model.save_payload()==before,"cold exact restore "+label)
 tap(KEY_ESCAPE)
func body_clear():
 var player: Vector2=game.model.p-Vector2(game.model.camera_x,0)
 return not game.cue_panel.get_rect().intersects(Rect2(player-Vector2(62,52),Vector2(124,104)))
func run():
 if folder.is_empty():
  quit(1)
  return
 DirAccess.make_dir_recursive_absolute(folder)
 if FileAccess.file_exists(folder.path_join("save.json")): DirAccess.remove_absolute(folder.path_join("save.json"))
 await new_scene()
 tap(KEY_ENTER)
 await tick(2)
 check(body_clear(),"spawn dialogue clears complete bee rectangle")
 await shot("01-departure")
 for point in [Vector2(210,480),Vector2(330,410),Vector2(400,565),Vector2(490,440)]:
  game.model.p=point
  game.model.velocity=Vector2.ZERO
  game.refresh_hud()
  check(body_clear(),"nearby dialogue clears complete bee at "+str(point))
  await tick(2)
 await shot("02-leaf-contact-right")
 game.model.p=Vector2(190,420)
 game.refresh_hud()
 await shot("03-leaf-contact-left")
 root.size=Vector2i(960,600)
 # Let the normal entry invulnerability blink finish before the small-window capture.
 await tick(40)
 check(body_clear(),"small window retains dialogue clearance")
 await shot("04-small-window")
 root.size=Vector2i(1280,800)
 game.model.p=Vector2(2320,500)
 game.model.velocity=Vector2.ZERO
 await tick(2)
 await shot("05-small-closed-flower")
 game.model.p=Vector2(3370,400)
 game.model.velocity=Vector2.ZERO
 game.model.clear_input()
 game.model.started=true
 await tick(10)
 await shot("06-first-held")
 await cold_resume("first held")
 var moved=false
 for i in 320:
  await tick()
  var m=game.model
  if not moved and m.preparation_count()==1 and m.keeper.pos!=m.keeper.target:
   moved=true
   await shot("07-between-hangers")
   await cold_resume("between hangers")
  if m.preparation_count()==1 and m.keeper.pos==m.keeper.target and m.keeper.elapsed>3:
   await shot("08-second-held")
  if m.preparation_count()==2 and m.keeper.pos==m.keeper.target and m.keeper.elapsed>5:
   await shot("09-third-held")
  if m.keeper.state=="watch": break
 check(moved and game.model.preparation_count()==3,"walk and three attachments actually complete")
 await shot("10-all-hung")
 await cold_resume("all hung")
 key(KEY_RIGHT,true)
 var before: Vector2=game.model.p
 await tick(20)
 key(KEY_RIGHT,false)
 check(game.model.p.x>before.x,"player stays free to fly past preparation")
 var f=FileAccess.open(folder.path_join("trace.json"),FileAccess.WRITE)
 f.store_string(JSON.stringify({"kind":"controlled native source fixture; seeded positions, actual input/disk suspend, muted; not exploration","checks":checks,"failures":failures,"frames":samples,"captures":captured.keys()},"\t"))
 game.queue_free()
 await process_frame
 print("DEPARTURE VERIFIED: %d checks, %d failures" % [checks,failures])
 quit(1 if failures else 0)
