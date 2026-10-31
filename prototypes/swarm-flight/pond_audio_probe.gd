extends SceneTree
## Seeded source audit with actual inputs, event consumption and captured native mix.
class NativeFixture extends "res://spring_journey_main.gd":
 func _notification(what: int):
  # The harness remains in control when a separate tool changes OS focus.
  # Explicit Esc pause, disk writes and cold scene restoration stay production.
  if what!=NOTIFICATION_APPLICATION_FOCUS_OUT: super._notification(what)
const Model=preload("res://spring_journey_model.gd")
var game
var folder=OS.get_environment("SWARM_POND_AUDIO_DIR")
var events=[]
var frames=[]
var checks=0
var failures=0
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
func record(kind: String):
 events.append({"frame":frames.size(),"kind":kind,"stage":game.model.stage,"mode":game.mode})
func count(kind: String): return events.filter(func(e): return e.kind==kind).size()
func tick(n=1):
 for i in n:
  game.tick(1.0/30)
  game.world._process(1.0/30)
  game.sound._process(1.0/30)
  frames.append({"frame":frames.size(),"p":[game.model.p.x,game.model.p.y],"weather":game.model.weather_phase,"keeper":game.model.keeper.state,"work":game.model.keeper.elapsed,"dance":game.model.share_state,"rain_db":game.sound._pond_rain.volume_db,"dance_db":game.sound._pond_dance.volume_db,"mode":game.mode})
  await process_frame
func shot(label: String):
 game.queue_redraw()
 game.world.queue_redraw()
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(folder.path_join(label+".png"))
func new_scene():
 game=NativeFixture.new()
 game.progress_file=folder.path_join("save.json")
 root.add_child(game)
 await process_frame
 game.set_process(false)
 game.world.set_process(false)
 game.sound.set_process(false)
 game.sound.event_played.connect(record)
func fixture_position(point: Vector2):
 game.model.p=point
 game.model.velocity=Vector2.ZERO
 game.model.clear_input()
 game.model.started=true
func cold_resume(label: String):
 tap(KEY_ESCAPE)
 var before: Dictionary=game.model.save_payload()
 var before_events=events.size()
 await tick(12)
 check(game.model.save_payload()==before and events.size()==before_events,"pause no state or new audio "+label)
 game.queue_free()
 await process_frame
 await new_scene()
 game.on_secondary()
 check(game.mode=="pause" and game.model.save_payload()==before,"cold exact "+label)
 tap(KEY_ESCAPE)
 await tick()
 check(events.size()==before_events,"cold restore does not replay old events "+label)
func run():
 if folder.is_empty() or DisplayServer.get_name()=="headless":
  quit(1)
  return
 DirAccess.make_dir_recursive_absolute(folder)
 if FileAccess.file_exists(folder.path_join("save.json")): DirAccess.remove_absolute(folder.path_join("save.json"))
 await new_scene()
 tap(KEY_ENTER)
 fixture_position(Model.SOURCE)
 await tick(40)
 check(count("source_observed")==1 and count("bird_greeting")==1,"real feeding and bird each routed once")
 await shot("01-source-bird")
 await cold_resume("source")
 fixture_position(Vector2(3370,400))
 await tick(260)
 check(count("keeper_hang")==3,"three real attachments each sound once")
 await shot("02-three-hangers")
 game.begin_stage(1)
 fixture_position(Vector2(640,520))
 key(KEY_RIGHT,true)
 await tick(12)
 key(KEY_RIGHT,false)
 await tick(12)
 check(game.model.weather_phase=="warning" and count("weather_warning")==1,"real threshold enters warning once")
 await shot("03-weather-warning")
 await tick(80)
 fixture_position(Vector2(1780,400))
 await tick(35)
 check(game.model.weather_phase=="rain" and game.sound._pond_rain_target==0,"exposed local rain has full environmental bed")
 await shot("04-exposed-rain")
 fixture_position(Vector2(2120,520))
 await tick(35)
 check(game.model.shelter_index_at(game.model.p)>=0 and game.sound._pond_rain_target==-13,"leaf shelter reduces actual rain bed")
 await shot("05-sheltered-rain")
 await cold_resume("rain under leaf")
 fixture_position(Vector2(3700,520))
 await tick(35)
 check(game.model.weather_phase=="after" and game.sound._pond_rain.volume_db<=-59.9,"rain ends and fades out")
 await shot("06-after-rain")
 game.begin_stage(2)
 fixture_position(Vector2(2190,440))
 await tick(70)
 check(game.model.keeper.state=="counting" and count("keeper_count")==1,"actual approach creates one counting sound")
 await shot("07-counting")
 var m=game.model
 m.front_open=true
 m.passage_open=true
 m.wall_at(2350).broken=true
 m.wall_at(Model.BACK_WALL_X).broken=true
 m.keeper=Model.actor(Model.PICKUP_POSITION+Vector2(-20,0))
 m.keeper.state="tidy"
 m.keeper.target=Model.PICKUP_POSITION
 m.result_elapsed=0
 fixture_position(Model.SOURCE)
 await tick(40)
 check(count("keeper_lift")==1,"at-sign inspection leads to one lift sound")
 fixture_position(Model.COMB)
 await tick(25)
 key(KEY_SPACE,true)
 await tick(4)
 key(KEY_SPACE,false)
 await tick(12)
 check(m.share_state=="dancing" and game.sound._pond_dance_target==-13,"actual new space gesture starts wing loop")
 await shot("08-dance-wings")
 await cold_resume("dance before commit")
 await tick(72)
 m=game.model
 check(count("dance_commit")==1 and count("listener_depart")==2,"one commit and two real listener departures")
 await shot("09-listeners-leave")
 # Seed only the final approach to inspect the same production end-state branch.
 m.keeper=Model.actor(Model.RESULT_HOME+Vector2(45,0))
 m.keeper.state="tidy"
 m.keeper.target=Model.RESULT_HOME
 m.result_elapsed=Model.INSPECT_SECONDS
 m.phase="ending"
 game.mode="ending"
 await tick(80)
 check(count("keeper_place")==1 and m.events.is_empty(),"ending consumes placement once without queued audio")
 await shot("10-ending-place")
 var counts={}
 for event in events: counts[event.kind]=counts.get(event.kind,0)+1
 var f=FileAccess.open(folder.path_join("trace.json"),FileAccess.WRITE)
 f.store_string(JSON.stringify({"kind":"seeded source-state audit; real input/disk/events; native mix enabled; not player exploration","checks":checks,"failures":failures,"counts":counts,"events":events,"frames":frames},"\t"))
 for kind in game.sound.POND_EVENTS:
  game.sound._samples[kind].save_to_wav(folder.path_join(kind+".wav"))
 game.sound._pond_rain.stream.save_to_wav(folder.path_join("rain-loop.wav"))
 game.sound._pond_dance.stream.save_to_wav(folder.path_join("dance-loop.wav"))
 game.queue_free()
 await process_frame
 print("POND AUDIO NATIVE: %d checks, %d failures" % [checks,failures])
 quit(1 if failures else 0)
