extends "res://playtest/rain_route/route_landscape.gd"

func _ready() -> void:
 var guyu:=Node2D.new()
 guyu.set_script(preload("res://playtest/year/guyu/guyu_film.gd"))
 guyu.route=route
 add_child(guyu)

func _draw() -> void:
 if not is_instance_valid(route) or not route.cinema.active: return
 var c=route.cinema
 if c.term==5 and c.day==15: return
 var season:=int(c.term/6)
 var t: float=c.age
 var chapter: Dictionary=route.year_calendar[c.term]
 draw_rect(Rect2(0,0,1280,720),[Color("e8ead2"),Color("d8e2c9"),Color("ead9b7"),Color("e8d5af")][season])
 var drift:=smoothstep(0,3,t)
 # A small animated aftermath: the group arrives, settles, and the neighbour responds.
 var center:=Vector2(670,370)
 leaf(center+Vector2(0,95),260,0,Color("b0bd98") if season<2 else Color("c5af7f"))
 for i in range(6):
  var angle:=i*TAU/6-PI/2
  var destination:=center+Vector2(cos(angle)*120,sin(angle)*52)
  var p:=Vector2(200-i*48,460+i%2*25).lerp(destination,drift)
  p.y+=sin(t*3+i)*3
  bee(p,lerp_angle(0,angle+PI/2,drift),0.9,false,season==3 or t>3)
 var finale: bool=c.term%6==5 and c.day==15
 if finale:
  preload("res://playtest/year/year_neighbors.gd").draw_guest(self,Vector2(990,350)+Vector2(0,sin(t*2)*4),season,t)
 else:
  # Completed work remains the focal object for this five-day beat.
  var mode: String=chapter.days[c.day-1].mode
  for i in range(3):
   var p:=Vector2(985+i*24,370-sin(t*1.5+i)*5)
   if mode in ["water","fan"]: oval(p,Vector2(8,14),Color("88afb8"))
   elif mode in ["seed","fruit"]: oval(p,Vector2(12,8),Color("bc9968"))
   elif mode in ["wax","share","warm"]: oval(p,Vector2(12,15),GOLD)
   else: flower(p,15,Color("d5a99b"))
 label(Vector2(76,95),chapter.name+" · "+("这一季的相聚" if finale else ["一候","二候","三候"][int(c.day/5)-1]),28)
 label(Vector2(76,590),chapter.ending if finale else chapter.hou_captions[int(c.day/5)-1],26)
 label(Vector2(76,632),"你做过的事，留在了路上。" if season<3 else "外面很冷，巢里有彼此。",19)
 label(Vector2(960,674),"空格跳过 · C 回看",16)
 if route.paused: label(Vector2(500,170),"已暂停 · Esc 继续",22)
 draw_line(Vector2(76,670),Vector2(76+820*t/c.duration,670),GOLD,3,true)
