extends SceneTree
const Year:=preload("res://playtest/year/year_model.gd")
const Driver:=preload("res://tools/year_driver.gd")
func find_day(mode: String, variation: String=""):
 var m:=Year.new()
 m.configure(6)
 for t in range(6,24):
  for d in range(15):
   var row: Dictionary=m.calendar[t].days[d]
   if row.mode==mode and (variation.is_empty() or row.variation==variation):
    m.configure(t);m.day=d+1;m.start_day();return m
 assert(false,"Missing designed mode")
 return m
func _init() -> void:
 var m=find_day("fan","crosswind")
 var i:=1 if m.objects.size()>1 else 0
 m.position=m.objects[i].target
 m.heading=m.vent_angle(i)+PI
 m.working=true
 for n in range(120): m.step(1.0/60,Vector2.ZERO,true)
 assert(m.task_progress[i]==0,"Wrong-facing fanning cannot fill progress")
 m.heading=m.vent_angle(i)
 m.working=false
 for n in range(120): m.step(1.0/60,Vector2.ZERO,true)
 assert(m.task_progress[i]==0,"Standing alone is not doing the work")
 m.working=true
 for n in range(90): m.step(1.0/60,Vector2.ZERO,true)
 assert(m.objects[i].done)
 m=find_day("warm","spread")
 assert(m.companions.size()==5 and not m.work_ready())
 for n in range(300): m.step(1.0/60,Vector2.ZERO,true)
 assert(m.objects_done()==0)
 Driver.work(m);Driver.home(m)
 assert(m.day_finished)
 m=find_day("seed","drift")
 var start: Vector2=m.objects[0].point
 for n in range(90): m.step(1.0/60,Vector2.ZERO,true)
 assert(m.objects[0].point.distance_to(start)>10)
 m.position=m.objects[0].point
 assert(m.act()=="load")
 m.position=m.HIVE
 assert(m.act()=="" and m.carried==0,"Wrong delivery retains the seed")
 m=find_day("water")
 m.position=m.sources()[0]
 assert(m.act()=="load" and m.food_kind=="water")
 m.position=m.POLLEN_DESK+Vector2(40,25)
 assert(m.act()=="" and m.cargo==1,"Water is not pollen")
 m=find_day("fruit")
 start=m.objects[0].point
 m.position=m.objects[0].target
 for n in range(120): m.step(1.0/60,Vector2.ZERO,true)
 assert(m.objects[0].point==start and not m.work_ready(),"Merely reaching the goal cannot move the fruit")
 Driver.work(m);assert(m.objects_done()==m.objects.size())
 print("YEAR INTERACTIONS TEST PASSED: hold/heading, five cold companions, drifting seed, wrong delivery, physical fruit pushing")
 quit()
