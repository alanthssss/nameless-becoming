extends SceneTree
## Native seeded component exercise, known approaches; not independent exploration.
class Fixture extends "res://spring_journey_main.gd":
 func pause_game(): pass
var game
var folder=OS.get_environment("SWARM_BACK_SIGN_QA_DIR")
var frames=[]
var pressed={}
var checks=0
var failures=0
func _initialize(): call_deferred("run")
func check(ok: bool,label: String):
 checks+=1
 if not ok:
  failures+=1
  print("FAIL: "+label)
func action(d: Vector2,held=false):
 var codes=[KEY_LEFT,KEY_RIGHT,KEY_UP,KEY_DOWN,KEY_SPACE]
 var values=[d.x<-.1,d.x>.1,d.y<-.1,d.y>.1,held]
 for i in codes.size():
  if values[i]!=pressed.has(codes[i]):
   var e=InputEventKey.new()
   e.physical_keycode=codes[i]
   e.keycode=codes[i]
   e.pressed=values[i]
   root.push_input(e)
   if values[i]: pressed[codes[i]]=true
   else: pressed.erase(codes[i])
func tick(n=1):
 for i in n:
  game.tick(1.0/60)
  game.world._process(1.0/60)
  frames.append({"frame":frames.size(),"p":[game.model.p.x,game.model.p.y],"passage":game.model.passage_open,"rings":game.model.rings_hit,"input":pressed.keys()})
  if frames.size()%2==0: await process_frame
func fly(target: Vector2):
 for i in 1000:
  var d=target-game.model.p
  if d.length()<9: break
  action(Vector2(signf(d.x) if absf(d.x)>5 else 0,signf(d.y) if absf(d.y)>5 else 0))
  await tick()
 action(Vector2.ZERO)
 await tick(24)
 check(game.model.p.distance_to(target)<34,"ordinary input reaches "+str(target))
func shot(label: String):
 game.queue_redraw()
 game.world.queue_redraw()
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(folder.path_join(label+".png"))
func run():
 if folder.is_empty() or DisplayServer.get_name()=="headless":
  push_error("Native renderer and SWARM_BACK_SIGN_QA_DIR required")
  quit(1)
  return
 DirAccess.make_dir_recursive_absolute(folder)
 game=Fixture.new()
 game.test_mode=true
 game.progress_file=folder.path_join("unused.json")
 root.add_child(game)
 await process_frame
 game.set_process(false)
 game.world.set_process(false)
 game.sound.set_muted(true)
 for route in ["upper","lower","wind"]:
  action(Vector2.ZERO)
  game.model.reset_journey()
  game.played_seconds=0
  game.begin_stage(2)
  var m=game.model
  m.front_open=true
  m.wall_at(2350).broken=true
  m.keeper.state="watch"
  m.p=Vector2(2485,465) if route=="wind" else Vector2(2740,330)
  m.velocity=Vector2.ZERO
  m.clear_input()
  m.save_checkpoint(Vector2(2460,465))
  await tick(2)
  await shot(route+"-01-front")
  if route!="wind":
   action(Vector2.RIGHT,true)
   await tick(30)
   action(Vector2.RIGHT)
   await tick(45)
   check(m.p.x<2817 and not m.passage_open,"front solid blocks "+route)
   await shot(route+"-02-blocked")
   await fly(Vector2(2740,240 if route=="upper" else 500))
   await fly(Vector2(3040,240 if route=="upper" else 500))
   await fly(Vector2(3040,300))
   await fly(Vector2(3070,300))
   await shot(route+"-03-back")
  action(Vector2.RIGHT,true)
  await tick(30)
  action(Vector2.RIGHT)
  for i in 180:
   if m.passage_open: break
   await tick()
  check(m.passage_open,"opens via "+route)
  check(m.rings_hit==0 if route!="wind" else m.rings_hit>=2,"approach wind contact "+route)
  await shot(route+"-04-open")
  await tick(90)
  check(m.recoveries==0,"no recovery "+route)
 action(Vector2.ZERO)
 var f=FileAccess.open(folder.path_join("trace.json"),FileAccess.WRITE)
 f.store_string(JSON.stringify({"kind":"seeded native component fixture; ordinary keyboard input; known approaches; muted","checks":checks,"failures":failures,"frames":frames},"\t"))
 print("BACK SIGN NATIVE: %d checks, %d failures" % [checks,failures])
 game.queue_free()
 await process_frame
 quit(1 if failures else 0)
