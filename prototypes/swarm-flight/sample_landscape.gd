extends RefCounted
## Two representative sets. Decorative planes have no outlines like colliders,
## no reward-shaped glints and no simulation state. All paths stay code-native.

static func background(v: Node2D, summer: bool, cam: float, clock: float) -> void:
	var sky := Color("b9d9ce") if summer else Color("b7d8d6")
	var horizon := Color("f0e9bd") if summer else Color("f4ebcc")
	for row in 80:
		v.draw_rect(Rect2(0,row*10,1280,11),sky.lerp(horizon,float(row)/79.0))
	# Light is quiet enough for the dark flight silhouettes to stay in front.
	var sun := Vector2(1000-cam*0.007,151)
	v.draw_circle(sun,93,Color(1.0,0.96,0.74,0.12))
	v.draw_circle(sun,67,Color(1.0,0.97,0.79,0.25))
	v.draw_circle(sun,43,Color("fcf2c9"))
	for i in 4:
		var x := fposmod(i*467.0-cam*0.025,1880.0)-230
		var y := 220.0+(i%3)*53.0
		v._paper_shape([Vector2(x-120,y),Vector2(x-75,y-6),Vector2(x-66,y-39),Vector2(x-31,y-21),Vector2(x-12,y-72),Vector2(x+57,y-55),Vector2(x+71,y-23),Vector2(x+119,y-19),Vector2(x+143,y-3),Vector2(x-120,y)],Color(0.99,0.97,0.84,0.34))
	# A long, low garden horizon leaves the actual route readable at y=180–650.
	for layer in 3:
		var color: Color = [Color("b6cbb0"),Color("a3bea1"),Color("8cae91")][layer]
		if summer: color = color.lerp(Color("9bb69c"),0.22)
		var pts := PackedVector2Array([Vector2(-30,820)])
		for i in 70:
			var x := float(i)*20.0-30.0
			var q := x+cam*(0.022+layer*0.025)
			var y := 578.0+layer*44.0+sin(q*0.0047+layer*2.0)*26.0+sin(q*0.012+layer)*10.0
			pts.append(Vector2(x,y))
		pts.append(Vector2(1360,820))
		v.draw_colored_polygon(pts,color)
	if summer: _summer_set(v,cam)
	else: _spring_set(v,cam)
	# Broad lower silhouettes, not a repeated fence across the flight field.
	for i in 12:
		var x := fposmod(i*137.0-cam*0.17,1690.0)-180
		var base := Vector2(x,823)
		var tip := Vector2(x+sin(i*2.8)*70,675+(i%4)*20)
		var sway := sin(clock*0.65+i)*3.0
		v._leaf(base,tip+Vector2(sway,0),25+(i%3)*13,Color("739e7d") if i%2 else Color("86aa80"))
	# Sparse airborne seed strokes are soft scenery, never glowing pickups.
	for i in 7:
		var x := fposmod(i*233.0-cam*0.08+clock*5.0,1450.0)-80
		var y := 270.0+fposmod(i*127.0,420.0)+sin(clock*0.8+i)*9
		v.draw_line(Vector2(x,y),Vector2(x+3,y-2),Color(1,0.98,0.82,0.28),1.0,true)

static func _spring_set(v: Node2D, cam: float) -> void:
	var offset := fposmod(cam*0.045,500.0)
	var p := Vector2(840-offset,575)
	# A distant potting shed and an uneven paling are deliberately unoutlined.
	v.draw_colored_polygon(PackedVector2Array([p+Vector2(-91,0),p+Vector2(-91,-90),p+Vector2(83,-90),p+Vector2(83,0)]),Color("b5bb93"))
	v.draw_colored_polygon(PackedVector2Array([p+Vector2(-115,-87),p+Vector2(-12,-148),p+Vector2(111,-87)]),Color("9eae8d"))
	v.draw_rect(Rect2(p+Vector2(-36,-72),Vector2(36,72)),Color("96aa88"))
	v.draw_rect(Rect2(p+Vector2(20,-67),Vector2(34,29)),Color("e2d8a6"))
	v.draw_line(p+Vector2(37,-67),p+Vector2(37,-38),Color("a4ae8d"),3)
	for i in 16:
		var x := float(i)*100.0-cam*0.09
		x = fposmod(x,1640.0)-160
		var y := 632.0+sin(i*2.2)*7
		v.draw_line(Vector2(x-8,y+72),Vector2(x,y-18),Color("c1c7a0"),13,true)
		v.draw_line(Vector2(x-19,y+32),Vector2(x+91,y+24),Color("c1c7a0"),8,true)
	for i in 5:
		var x := fposmod(i*341.0-cam*0.14,1740.0)-200
		v._ellipse(Vector2(x,746),Vector2(122,18),Color("82a47c"))
		for j in 4:
			var p2 := Vector2(x-64+j*39,737)
			v._leaf(p2,p2+Vector2(-18,-43-j%2*13),18,Color("b7c98c"))
			v._leaf(p2,p2+Vector2(24,-35),14,Color("9db77b"))

static func _summer_set(v: Node2D, cam: float) -> void:
	for i in 4:
		var x := fposmod(i*493.0-cam*0.075,2010.0)-270
		# An airy pergola is behind the hedge; no dark collider-like bars.
		v._curve(Vector2(x,729),Vector2(x-38,419),Vector2(x+189,419),Vector2(x+179,729),Color("b2bb98"),7)
		v._curve(Vector2(x+21,727),Vector2(x-2,443),Vector2(x+168,443),Vector2(x+157,729),Color("b8c39e"),3)
		for j in 6:
			var p := Vector2(x+14+j*27,514-sin(j*PI/5.0)*33)
			v._leaf(p,p+Vector2(-24,-13),12,Color("a1bb91"))
			v._ellipse(p+Vector2(3,-4),Vector2(10,8),Color("d8baa9"))
	var f := Vector2(1080-fposmod(cam*0.11,1580.0),704)
	v._ellipse(f+Vector2(0,22),Vector2(125,21),Color("7caaa1"))
	v._ellipse(f+Vector2(0,18),Vector2(110,14),Color("c1d5bc"))
	v.draw_line(f+Vector2(0,10),f-Vector2(0,69),Color("aec1aa"),23,true)
	v._ellipse(f-Vector2(0,68),Vector2(61,11),Color("c6d2b6"))
	for side in [-1,1]:
		v._curve(f-Vector2(0,72),f+Vector2(side*28,-119),f+Vector2(side*50,-60),f+Vector2(side*68,12),Color("d0e2cb"),2)
	for i in 6:
		var x := fposmod(i*277.0-cam*0.16,1760.0)-200
		var p := Vector2(x,759)
		v._paper_shape([p+Vector2(-40,-43),p+Vector2(42,-43),p+Vector2(32,9),p+Vector2(-28,9),p+Vector2(-40,-43)],Color("bd9b77"))
		v.draw_line(p+Vector2(-43,-43),p+Vector2(44,-43),Color("d1b28c"),9,true)
		for j in 3:
			var top := p+Vector2(-28+j*26,-76-(j%2)*25)
			v.draw_line(p+Vector2(0,-42),top,Color("89a77c"),3,true)
			v._leaf(p+Vector2(0,-42),top+Vector2(21,12),13,Color("a6ba88"))
			v._ellipse(top,Vector2(18,13),Color("d8b5a5") if j%2 else Color("ded1a7"))

static func foreground(v: Node2D, cam: float, clock: float) -> void:
	# Only the bottom 75 pixels overlap play; wide silhouettes frame the shot.
	for i in 13:
		var x := fposmod(i*118.0-cam*1.08,1580.0)-150
		var sway := sin(clock*1.1+i*2.1)*4
		var p := Vector2(x,824)
		v._leaf(p,p+Vector2(-34+sway,-86-i%3*13),20,Color("3b6957"))
		v._leaf(p+Vector2(9,0),p+Vector2(50+sway,-67-i%2*18),24,Color("537e60"))
		v._leaf(p+Vector2(12,0),p+Vector2(10+sway,-61),12,Color("71935f"))

static func hedge(v: Node2D, r: Rect2) -> void:
	# The exact solid rectangle remains filled. Organic detail stays INSIDE it,
	# so leaves never imply a passable hole or an invisible extended collider.
	v.draw_rect(r,Color("355c3c"))
	v.draw_rect(r.grow(-3),Color("527d43"))
	var rows := maxi(1,int(r.size.y/29.0))
	var cols := maxi(1,int(r.size.x/37.0))
	for row in rows:
		for col in cols:
			var x := r.position.x+18+col*37.0+sin(row*3+col)*5
			var y := r.position.y+17+row*29.0+cos(col*4+row)*3
			var p := Vector2(clampf(x,r.position.x+16,r.end.x-16),clampf(y,r.position.y+15,r.end.y-15))
			var tint: Color = [Color("70964c"),Color("91ae58"),Color("5c8848"),Color("809f4f")][(row*3+col*7)%4]
			var axis := Vector2(12 if (row+col)%2 else -12,-9)
			v._leaf(p-axis,p+axis,10,tint)
	v.draw_rect(r,Color("294e36"),false,3)
	v.draw_line(r.position+Vector2(3,3),Vector2(r.end.x-3,r.position.y+3),Color("bbcb75"),2,true)
	for i in range(1,int(r.size.x/137.0)):
		var p := Vector2(r.position.x+i*137.0,r.position.y+22+i%2*21)
		v._flower(p,8,Color("efd5ae"),float(i))
