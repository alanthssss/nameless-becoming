extends RefCounted
const INK:=Color("364940")
const GREEN:=Color("a6b798")
const GOLD:=Color("e6bb62")

static func draw_guest(canvas: Node2D, p: Vector2, season: int, t: float) -> void:
 if season==0:
  canvas.oval(p,Vector2(9,30),Color("a99f7d"))
  canvas.oval(p+Vector2(-12,-9),Vector2(24,9),Color("ede8cf"))
  canvas.oval(p+Vector2(12,-9),Vector2(24,9),Color("ede8cf"))
  canvas.oval(p+Vector2(0,-28),Vector2(11,10),Color("a99f7d"))
  canvas.line([p+Vector2(0,-35),p+Vector2(-28,-58)],INK,2)
  for side in [-1,1]:
   for i in range(3): canvas.line([p+Vector2(side*6,-10+i*13),p+Vector2(side*(35+i*7),5+i*12+sin(t*3)*3)],INK,1.5)
  canvas.shape(PackedVector2Array([p+Vector2(15,0),p+Vector2(48,0),p+Vector2(48,30),p+Vector2(15,30)]),GOLD)
 elif season==1:
  canvas.leaf(p+Vector2(0,-65),110,-0.1,GREEN)
  for side in [-1,1]: canvas.line([p+Vector2(side*20,15),p+Vector2(side*55,-10),p+Vector2(side*65,40)],INK,3)
  canvas.oval(p,Vector2(30,18),Color("9aab7e"))
  canvas.oval(p+Vector2(-24,-10),Vector2(15,15),GREEN)
  canvas.draw_circle(p+Vector2(-30,-14),2.5,INK)
  canvas.line([p+Vector2(-32,-20),p+Vector2(-55,-54+sin(t*3)*5)],INK,2)
 elif season==2:
  canvas.shape(PackedVector2Array([p+Vector2(28,8),p+Vector2(75,-6),p+Vector2(65,29)]),Color("a88d70"))
  for side in [-1,1]:
   canvas.line([p+Vector2(side*17,27),p+Vector2(side*17,52),p+Vector2(side*17-12,54)],INK,2)
  canvas.oval(p,Vector2(45,35),Color("b99b79"))
  canvas.oval(p+Vector2(8,1),Vector2(26,17),Color("aa8f72"))
  canvas.oval(p+Vector2(-38,-30),Vector2(22,23),Color("b99b79"))
  canvas.shape(PackedVector2Array([p+Vector2(-55,-30),p+Vector2(-78,-22),p+Vector2(-55,-18)]),GOLD)
  canvas.line([p+Vector2(-53,-43),p+Vector2(-36,-45),p+Vector2(-21,-41)],Color("eee5c9"),3)
  canvas.draw_circle(p+Vector2(-42,-35),3,INK)
  for i in range(5): canvas.oval(p+Vector2(-75+i*23,50),Vector2(5,3),GOLD)
 else:
  canvas.oval(p,Vector2(67,76),Color("b59b7d"))
  for side in [-1,1]:
   canvas.oval(p+Vector2(side*37,65),Vector2(27,17),Color("a38d72"))
  canvas.oval(p+Vector2(-49,21),Vector2(24,38),Color("b59b7d"))
  canvas.oval(p+Vector2(-30,-65),Vector2(21,23),Color("b59b7d"))
  canvas.oval(p+Vector2(35,-65),Vector2(21,23),Color("b59b7d"))
  canvas.oval(p+Vector2(0,-25),Vector2(57,47),Color("b59b7d"))
  canvas.oval(p+Vector2(-12,-18),Vector2(22,16),Color("d6bd94"))
  canvas.draw_circle(p+Vector2(-20,-22),6,INK)
  canvas.draw_circle(p+Vector2(-28,-42),3,INK)
  canvas.leaf(p+Vector2(-105,55),85,-0.7,GREEN)
