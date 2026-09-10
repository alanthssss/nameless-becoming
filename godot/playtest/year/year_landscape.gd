extends "res://playtest/spring/spring_landscape.gd"
const Year := preload("res://playtest/year/year_model.gd")
const ROOM_NAMES := {"门前":"巢门", "树桩":"旧巢脾", "亮叶":"暖房", "近花":"近蜜房", "池岸":"通风口", "叶台":"团聚处", "池花":"东蜜房", "远花":"远蜜房", "草地":"育幼区旁", "甲虫家":"安静角", "北路":"上层巢道", "北花":"上层蜜房"}

func indoors() -> bool:
 return route.term_index >= 18

func _draw_static() -> void:
 if not indoors():
  super._draw_static()
  if route.term_index >= 6:
   var tint := Color("dfc792",0.20) if route.term_index < 12 else Color("d4a26a",0.28)
   draw_rect(Rect2(0,0,3600,2100),tint)
   if route.term_index >= 12:
    for i in range(70):
     leaf(Vector2(100+fposmod(i*391.0,3400),180+fposmod(i*233.0,1750)),15+i%9,i*2.39,Color("c8ab76"))
  return
 draw_rect(Rect2(0,0,3600,2100),Color("e7d5aa"))
 for row in range(12):
  for col in range(22):
   var p := Vector2(70+col*170+(row%2)*85,60+row*150)
   var vertices := PackedVector2Array()
   for i in range(6): vertices.append(p+Vector2.from_angle(i*TAU/6+PI/6)*92)
   shape(vertices,Color("ddc28e"),1.5)
 for place in Year.ROOMS:
  var p: Vector2 = Year.ROOMS[place]
  oval(p,Vector2(140,95),Color("f0dfb7"))
  label(p+Vector2(-45,125),ROOM_NAMES[place],19)
  if "蜜房" in ROOM_NAMES[place]:
   for i in range(5): oval(p+Vector2(-60+i*30,0),Vector2(12,25),GOLD)
 oval(Model.HIVE,Vector2(140,100),Color("b59b75"))
 label(Model.HIVE+Vector2(-55,140),"巢门 · 收工",22)

func _draw() -> void:
 if not is_instance_valid(route): return
 if not indoors():
  super._draw()
  if not static_pass and not is_rain() and route.model.heat > 0.05:
   var p: Vector2 = route.model.position + Vector2(-24,45)
   line([p,p+Vector2(48,0)],Color("d4c9a5"),4)
   line([p,p+Vector2(48*route.model.heat,0)],Color("c08d53"),4)
  return
 var started := Time.get_ticks_usec()
 if static_pass:
  _draw_static()
  return
 var m = route.model
 var visible_world := Rect2(route.camera_origin-Vector2(160,160),Vector2(1600,1040))
 _daily_world(visible_world)
 for i in range(m.companions.size()):
  var b: Dictionary=m.companions[i]
  var cold: bool=m.today().mode=="warm" and not m.objects[i].done
  var p: Vector2=b.position+Vector2(sin(route.visual_time*18+i)*2 if cold else 0,0)
  bee(p,b.heading,0.75,b.waiting,true)
  if cold: label(p+Vector2(-22,-35),"有点冷",15)
 if m.companions.is_empty():
  for i in range(5): bee(Model.HIVE+Vector2(45+i*32,-65+(i%2)*25),PI/2,0.7,false,true)
 bee(m.position,m.heading,1,false,true)
 _draw_food()
 if m.pulse > 0: label(m.pulse_point+Vector2(-70,-60),m.reaction_text,16)
 var targets: Array = m.objective_points()
 if not targets.is_empty():
  var p: Vector2 = targets[0]
  for t: Vector2 in targets:
   if t.distance_to(m.position) < p.distance_to(m.position): p=t
  var d: Vector2 = p-m.position
  if d.length()>100: leaf(m.position+d.normalized()*65,12,d.angle(),GOLD)
  else: draw_arc(p,36,0,TAU,28,Color("947648"),1.5,true)
 last_draw_us = Time.get_ticks_usec()-started

func _daily_world(visible_world: Rect2) -> void:
 if is_rain():
  super._daily_world(visible_world)
  return
 var m = route.model
 if not indoors(): super._daily_world(visible_world)
 var mode: String = m.today().mode
 if mode in ["water","share"]:
  for p: Vector2 in m.sources():
   if visible_world.has_point(p):
    oval(p,Vector2(52,28),Color("abc8c4") if mode=="water" else GOLD)
    oval(p+Vector2(-14,9),Vector2(24,12),Color("c4c6a5"))
    label(p+Vector2(-45,-48),"湿石 · 取水" if mode=="water" else "蜜房 · 取蜜",18)
  var desk: Vector2 = Model.HIVE+Vector2(70,-45)
  oval(desk,Vector2(45,23),Color("abc8c4") if mode=="water" else GOLD)
  label(desk+Vector2(-45,-40),"交水处" if mode=="water" else "递蜜处",18)
 for i in range(m.objects.size()):
  var item: Dictionary = m.objects[i]
  var p: Vector2 = item.target
  if mode in ["fan","wax","warm"] and visible_world.has_point(p):
   if mode=="fan":
    var direction := Vector2.from_angle(m.vent_angle(i))
    for j in range(3):
     var wave: Vector2 = p+direction*fposmod(route.visual_time*30+j*22,90)-direction*45
     line([wave-direction*10,wave],Color("7a9fa3"),2)
    var tip: Vector2 = p+direction*45
    line([p-direction*40,tip,tip-direction.rotated(0.6)*15,tip,tip-direction.rotated(-0.6)*15],INK,2)
    label(p+Vector2(-60,-60),"顺箭头按住空格",16)
   elif mode=="wax":
    line([p+Vector2(-25,-30),p+Vector2(5,-12),p+Vector2(-8,10),p+Vector2(22,30)],GOLD if item.done else INK,6 if item.done else 3)
    label(p+Vector2(-40,-50),"补好了" if item.done else "待补裂缝",16)
   else:
    oval(p,Vector2(40,36),Color("e9bd6f",0.23 if item.done else 0.10),false)
   draw_arc(p,42,-PI/2,-PI/2+TAU*maxf(0.01,m.task_progress[i]),32,GOLD,3,true)
  if mode in ["clean","seed","fruit"]:
   if visible_world.has_point(p):
    oval(p,Vector2(48,28),Color("b7aa83") if mode=="clean" else Color("d3bb88"))
    label(p+Vector2(-38,50),"收拢处" if mode=="clean" else ("草窝" if mode=="fruit" else "土缝"),17)
    if mode=="seed": line([p+Vector2(-15,4),p+Vector2(4,-3),p+Vector2(18,4)],INK,2)
   if not item.done and m.carried != i and visible_world.has_point(item.point):
    p=item.point
    if mode=="fruit":
     for j in range(1,6):
      var trace: Vector2=(item.point as Vector2).lerp(item.target,j/6.0)
      line([trace+Vector2(-5,8),trace+Vector2(5,8)],Color("a8a782"),2)
     oval(p,Vector2(28,26),Color("ca9267"))
     leaf(p+Vector2(10,-27),13,-0.4,GREEN)
     var d: Vector2 = (item.target-p).normalized()
     line([p-d*62,p-d*40],INK,2)
     label(p+Vector2(-50,-55),"从后面轻推",16)
    elif mode=="seed": oval(p,Vector2(12,7),Color("b49a69"))
    else:
     for j in range(3): leaf(p+Vector2(j*12,-j*5),13,j*1.1,Color("a69473"))
 # The same seasonal neighbour is encountered before the finale and remains afterward.
 var season: int=int(route.term_index/6)
 var guest: Vector2=[Vector2(1400,500),Vector2(1810,930),Vector2(2150,1510),Vector2(180,900)][season]
 if season<3: guest+=Vector2(130,-130)
 if route.term_index%6 in [0,2,5] or m.world.has("festival:%d" % season):
  if visible_world.has_point(guest):
   preload("res://playtest/year/year_neighbors.gd").draw_guest(self,guest,season,route.visual_time if m.position.distance_to(guest)<220 else 0)
   label(guest+Vector2(-50,100),["蚊庄主的花牌","油葫芦的凉亭","画眉的种子站","门外的大熊"][season],17)
   var record: Dictionary=m.world.get("festival:%d" % season,{})
   var phase: int=record.get("phase",0)
   for j in range(phase):
    var p: Vector2=guest+Vector2(-65+j*28,135)
    if season==0: post(p,j%3,true)
    elif season==1: leaf(p,25,-0.25,GREEN)
    elif season==2: oval(p,Vector2(7,4),GOLD)
    else: oval(p,Vector2(12,15),GOLD)
 if indoors() and mode in ["visit","convoy"]:
  for i in range(m.sources().size()):
   var p: Vector2 = m.sources()[i]
   if visible_world.has_point(p): label(p+Vector2(-40,-45),"已认得" if m.visits.has(str(i)) else "在这里聚一聚",17)

func _draw_food() -> void:
 if is_rain():
  super._draw_food()
  return
 var m=route.model
 if m.food_kind in ["water","honey"]:
  for i in range(m.cargo): oval(m.position+Vector2(-10+i*9,24),Vector2(5,7),Color("88afb8") if m.food_kind=="water" else GOLD)
 elif m.carried>=0 and m.today().mode in ["seed","clean"]:
  leaf(m.position+Vector2(-15,25),14,-0.3,Color("b49a69"))
 else: super._draw_food()

func board(p: Vector2, kind: int, twig := false) -> void:
 if not is_rain() and twig and route.model.today().get("variation")=="wide":
  leaf(p,50,-0.3,Color("c9b989"))
 else: super.board(p,kind,twig)
