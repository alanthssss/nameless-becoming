extends "res://playtest/rain_route/route_landscape.gd"

# Four authored shots. Characters and cards are independent of the illustrated plates.
const DURATION := 24.0
const CUTS := [0.0, 5.0, 10.0, 16.0, 24.0]
const WIDE := preload("res://playtest/year/guyu/guyu-wide.png")
const CLOSE := preload("res://playtest/year/guyu/guyu-close.png")
var rustle: AudioStreamPlayer
var chime: AudioStreamPlayer
var last_time := -1.0
var fired: Dictionary = {}

static func shot_at(t: float) -> int:
 return 0 if t<5 else (1 if t<10 else (2 if t<16 else 3))

static func card_phase(t: float) -> String:
 return "attached" if t<12 else ("carried" if t<15 else "placed")

static func card_position(t: float) -> Vector2:
 if t<12: return Vector2(764,337)
 var k:=smoothstep(12,15,t)
 return Vector2(764,337).lerp(Vector2(405,470),k)+Vector2(0,-sin(k*PI)*110)

func _ready() -> void:
 rustle=AudioStreamPlayer.new()
 rustle.stream=preload("res://assets/audio/commercial/seed_shell_rustle.wav")
 rustle.bus=&"SFX"
 rustle.volume_db=-20
 add_child(rustle)
 chime=AudioStreamPlayer.new()
 chime.stream=preload("res://assets/audio/commercial/complete.wav")
 chime.bus=&"SFX"
 chime.volume_db=-17
 add_child(chime)

func _process(_delta: float) -> void:
 if not is_instance_valid(route): return
 var c=route.cinema
 var active: bool=c.term==5 and c.day==15 and c.active
 var preview: bool=route.get("film_preview")==true
 visible=active or preview
 if not visible:
  rustle.stop();chime.stop();last_time=-1;return
 if c.age<last_time: fired.clear()
 for cue in [12.0,15.1]:
  if active and not route.paused and c.age>=cue and not fired.has(cue):
   (rustle if cue==12.0 else chime).play()
   fired[cue]=true
 rustle.stream_paused=route.paused
 chime.stream_paused=route.paused
 last_time=c.age
 queue_redraw()

func _plate(texture: Texture2D, t: float, closeup := false) -> void:
 var z:=1.04 if closeup else lerpf(1.065,1.015,clampf(t/24,0,1))
 var offset:=Vector2(-1280*(z-1)*0.5,-720*(z-1)*0.5)
 draw_texture_rect(texture,Rect2(offset,Vector2(1280,720)*z),false)

func _caption(text: String, alpha := 1.0) -> void:
 var font: Font=route.font
 var width:=font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,25).x
 draw_style_box(_caption_box(alpha),Rect2((1280-width)/2-27,594,width+54,53))
 draw_string(font,Vector2((1280-width)/2,629),text,HORIZONTAL_ALIGNMENT_LEFT,-1,25,Color(INK,alpha))

func _caption_box(alpha: float) -> StyleBoxFlat:
 var box:=StyleBoxFlat.new()
 box.bg_color=Color(PAPER,alpha*0.94)
 box.set_corner_radius_all(18)
 return box

func _card(p: Vector2, angle := 0.0, size := 1.0, finished := true) -> void:
 var tr:=Transform2D(angle,Vector2.ONE*size,0,p)
 shape(tr*PackedVector2Array([Vector2(-26,-22),Vector2(25,-24),Vector2(28,23),Vector2(-24,25)]),Color("dfc88a"),1.8)
 if finished:
  for i in range(5):
   var petal: Vector2=tr*(Vector2.from_angle(i*TAU/5)*8)
   oval(petal,Vector2.ONE*5.3*size,Color("d5a99b"),false)
  draw_circle(p,4*size,Color("e6bb62"))
 else:
  draw_arc(p,9*size,0,TAU,24,Color("829477"),1.5,true)

func _bee(p: Vector2, angle: float, scale_value: float, t: float, landed := false, pointing := false) -> void:
 # Preserve the familiar ochre abdomen, dark stripes and cream wings, with finer film ink.
 oval(p+Vector2(0,24*scale_value),Vector2(22,6)*scale_value,Color("899b7c",0.13),false)
 draw_set_transform(p,angle,Vector2.ONE*scale_value)
 var wing:=0.35 if landed else 0.7+sin(t*40)*0.2
 oval(Vector2(-3,-15),Vector2(17,10*wing),Color("faf8e9"))
 oval(Vector2(-3,15),Vector2(17,10*wing),Color("faf8e9"))
 oval(Vector2(-5,0),Vector2(22,13),GOLD)
 for x in [-16,-6,4]: line([Vector2(x,-10),Vector2(x-2,0),Vector2(x,10)],INK,2.5)
 oval(Vector2(16,0),Vector2(12,11),GOLD)
 for side in [-1,1]:
  draw_circle(Vector2(20,side*5),2,INK)
  line([Vector2(22,side*7),Vector2(29,side*13),Vector2(34,side*11)],INK,1.3)
 if pointing: line([Vector2(2,11),Vector2(24,22),Vector2(38,18)],INK,1.5)
 draw_set_transform(Vector2.ZERO)

func _mosquito(p: Vector2, scale_value: float, t: float, turn: float, surprise := false, bow := 0.0) -> void:
 # Six jointed legs, two wings, a long proboscis and a little counting gesture.
 var face:=lerpf(-1.0,1.0,turn)
 draw_set_transform(p+Vector2(0,bow*8),bow*0.22,Vector2.ONE*scale_value)
 for side in [-1,1]:
  for i in range(3):
   var lift:=sin(t*4+i)*2 if i==0 else 0.0
   line([Vector2(side*7,-4+i*13),Vector2(side*(25+i*5),4+i*15+lift),Vector2(side*(38+i*5),13+i*16+lift)],INK,1.6)
 oval(Vector2(-14,-16),Vector2(28,10),Color("f5f2dd"))
 oval(Vector2(14,-16),Vector2(28,10),Color("f5f2dd"))
 oval(Vector2(0,13),Vector2(10,32),Color("a8aa82"))
 for i in range(3): line([Vector2(-8,6+i*12),Vector2(8,6+i*12)],Color("778464"),1.4)
 oval(Vector2(0,-15),Vector2(14,18),Color("a8aa82"))
 oval(Vector2(face*5,-38),Vector2(15,14),Color("bbb98e"))
 line([Vector2(face*15,-43),Vector2(face*45,-61)],INK,1.7)
 line([Vector2(face*3,-50),Vector2(face*4,-61),Vector2(face*10,-65)],INK,1.2)
 draw_circle(Vector2(face*11,-40),2.4,INK)
 if surprise:
  draw_arc(Vector2(face*11,-40),6,0,TAU,20,INK,1.2,true)
  draw_arc(Vector2(face*8,-27),3,0,TAU,16,INK,1.2,true)
 else:
  line([Vector2(face*3,-28),Vector2(face*8,-26),Vector2(face*12,-29)],INK,1.2)
 draw_set_transform(Vector2.ZERO)

func _posts(t: float, p: Vector2, gap := 82.0, size := 1.0) -> void:
 for i in range(3):
  var point:=p+Vector2(i*gap,0)
  line([point+Vector2(0,24*size),point+Vector2(0,68*size)],INK,3*size)
  if i<2 or t>=15: _card(point,0,size)
  else: draw_arc(point,18*size,0,TAU,28,Color("8b9978",0.65),1.3,true)

func _wide(t: float) -> void:
 _plate(WIDE,t)
 if t<5:
  for i in range(6):
   var k:=smoothstep(i*0.13,4.7+i*0.04,t)
   var p:=Vector2(-70-i*48,410+i%2*25).lerp(Vector2(420-i*48,416+i%2*30),k)
   _bee(p+Vector2(0,sin(t*3+i)*5),-0.1,0.90,t)
  _posts(0,Vector2(840,410),72,0.80)
  _mosquito(Vector2(1010,393),0.95,t,0)
  if t>1: _caption("雨停了。花路上，还差最后一张牌。",smoothstep(1,1.6,t))
  for i in range(12):
   var drop:=Vector2(65+i*109,fposmod(t*210+i*61,510))
   line([drop,drop+Vector2(3,13)],Color("8ba6a0",maxf(0,0.28-t*0.10)),1)
 else:
  _posts(t,Vector2(840,410),72,0.80)
  _mosquito(Vector2(1010,393),0.95,t,1,sin(t*1.5)>0.9,sin(clampf((t-16)/2,0,1)*PI))
  for i in range(6):
   var k:=smoothstep(17,23.2,t)
   var home:=Vector2(245,132)+Vector2.from_angle(-PI*0.8+i*TAU/6)*56
   var p:=Vector2(740-i*75,440+i%2*65).lerp(home,k)
   p+=Vector2(sin(k*PI)*(-150),sin(k*PI)*28)
   _bee(p,-2.12,lerpf(1.0,0.37,k),t,k>=1)
  if t<20.4: _caption("这回，真的齐了。")
  else: _caption("一会儿，巢里见。",smoothstep(20.4,21,t))

func _counting(t: float) -> void:
 _plate(CLOSE,t,true)
 _posts(0,Vector2(390,459),102,1.08)
 _mosquito(Vector2(820,351),1.75,t,smoothstep(7.1,9.3,t))
 if t>7: _card(Vector2(782,370),-0.15,0.88)
 for i in range(6):
  var p:=Vector2(140+i%3*65,385+i/3*62)
  _bee(p,0,0.90,t,true,i==0 and t>8)
 # An articulated front leg counts the first two signs and pauses at the empty third.
 var index:=mini(2,int((t-5)/0.9))
 line([Vector2(794,340),Vector2(727,390),Vector2(390+index*102,423)],INK,2)
 _caption("一张，两张……咦？")

func _reveal(t: float) -> void:
 _plate(CLOSE,t,true)
 _mosquito(Vector2(820,330),2.5,t,1,t<13.3,smoothstep(14.7,15.6,t)*0.35)
 _posts(0,Vector2(245,470),80,1.0)
 var p:=card_position(t)
 if t<15: _card(p,lerpf(-0.12,0,smoothstep(12,15,t)),1.13)
 else: _card(Vector2(405,470),0,1.0)
 var lead:=Vector2(450,360).lerp(Vector2(704,340),smoothstep(10,11.7,t))
 if t>=12: lead=p+Vector2(-66,-12)
 _bee(lead,0,1.62,t,t>=15,true)
 for i in range(5): _bee(Vector2(128+i*61,535+sin(i)*8),-0.2,0.75,t,true)
 if t<12: _caption("原来，一直在你背上。")
 elif t<14.7: _caption("别动，我帮你。")
 else:
  for i in range(7):
   var k:=clampf((t-15)/0.8,0,1)
   var d:=Vector2.from_angle(i*TAU/7)
   line([Vector2(405,470)+d*(38+k*18),Vector2(405,470)+d*(43+k*22)],Color(GOLD,1-k),2)
  _caption("好了。")

func _draw() -> void:
 if not is_instance_valid(route): return
 var t: float=clampf(route.cinema.age,0,DURATION)
 match shot_at(t):
  0,3: _wide(t)
  1: _counting(t)
  2: _reveal(t)
 # Short paper dissolves hide camera changes; never hide the central joke for long.
 for cut in [5.0,10.0,16.0]:
  var veil:=maxf(0,1-absf(t-cut)/0.23)
  if veil>0: draw_rect(Rect2(0,0,1280,720),Color(PAPER,veil))
 if t<1.6:
  draw_string(route.font,Vector2(66,75),"谷雨 · 最后一张花牌",HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color(INK,smoothstep(0,0.7,t)))
 draw_string(route.font,Vector2(930,688),"空格跳过   C 回看   Esc 暂停",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color(INK,0.70))
 if route.paused: _caption("已暂停 · Esc 继续")
