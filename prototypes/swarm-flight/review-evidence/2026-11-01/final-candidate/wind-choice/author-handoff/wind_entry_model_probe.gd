extends SceneTree
## Controlled model fixture probes for a visible first-flower relocation, not full play.
const Model=preload("res://spring_journey_model.gd")
var checks=0
var failures=0
var rows=[]
func _initialize():call_deferred("run")
func check(ok: bool,label: String):
 checks+=1
 if not ok:failures+=1;print("FAIL: "+label)
func run():
 for x in [2710,2717.5,2725,2732.5,2740]:
  for y in [457,465,473]:
   var m=Model.new();m.load_stage(2)
   m.front_open=true;m.wall_at(2350).broken=true;m.keeper.state="watch";m.p=Vector2(x,y)
   for i in 30:m.step(Vector2.UP,true,1.0/60)
   for i in 180:m.step(Vector2.UP,false,1.0/60)
   var ok=m.passage_open and m.rings_hit==3 and m.recoveries==0
   rows.append({"start":[x,y],"passed":ok,"p":[m.p.x,m.p.y],"rings":m.rings_hit,"open":m.passage_open,"recovery":m.recoveries})
   check(ok,"upward wind entry "+str(Vector2(x,y)))
 var path=OS.get_environment("SWARM_WIND_PROBE_DIR")
 DirAccess.make_dir_recursive_absolute(path)
 var f=FileAccess.open(path.path_join("entry-probe.json"),FileAccess.WRITE)
 f.store_string(JSON.stringify({"kind":"controlled front-open model fixtures; no player-exploration claim","checks":checks,"failures":failures,"rows":rows},"\t"));f.close()
 print("WIND ENTRY PROBE: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
