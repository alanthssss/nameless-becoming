extends RefCounted
## Small abstract UI symbols; no gameplay or progression state.
static func icon(c: CanvasItem, kind: String, p: Vector2, r: float, ink := Color("f5e9b7")) -> void:
	var gold := Color("e7be62")
	match kind:
		"coin", "market":
			c.draw_circle(p,r*0.72,gold)
			c.draw_arc(p,r*0.53,0,TAU,32,Color("876432"),2,true)
			c.draw_line(p+Vector2(0,-r*0.34),p+Vector2(0,r*0.34),Color("876432"),3,true)
		"bag":
			var poly := PackedVector2Array([p+Vector2(-r*.46,-r*.36),p+Vector2(-r*.72,r*.50),p+Vector2(-r*.42,r*.76),p+Vector2(r*.42,r*.76),p+Vector2(r*.72,r*.50),p+Vector2(r*.46,-r*.36)])
			c.draw_colored_polygon(poly,ink)
			c.draw_polyline(poly+PackedVector2Array([poly[0]]),Color("927644"),2,true)
			c.draw_line(p+Vector2(-r*.5,-r*.25),p+Vector2(r*.5,-r*.25),gold,4,true)
			c.draw_circle(p+Vector2(0,r*.25),r*.20,gold)
		"fiber":
			for i in 3:
				var y: float = (i-1)*r*.34
				c.draw_polyline(PackedVector2Array([p+Vector2(-r*.76,y+r*.2),p+Vector2(-r*.22,y-r*.18),p+Vector2(r*.35,y+r*.08),p+Vector2(r*.73,y-r*.22)]),Color("dbd7a0"),r*.23,true)
			c.draw_line(p+Vector2(-r*.08,-r*.65),p+Vector2(r*.13,r*.65),Color("8d915a"),r*.16,true)
		"resin":
			var drop := PackedVector2Array([p+Vector2(0,-r*.86),p+Vector2(-r*.58,-r*.05),p+Vector2(-r*.61,r*.40),p+Vector2(-r*.28,r*.73),p+Vector2(r*.29,r*.73),p+Vector2(r*.61,r*.40),p+Vector2(r*.58,-r*.05)])
			c.draw_colored_polygon(drop,Color("d9a05c"))
			c.draw_polyline(drop+PackedVector2Array([drop[0]]),Color("805f38"),r*.11,true)
			c.draw_line(p+Vector2(-r*.25,-r*.06),p+Vector2(-r*.29,r*.30),Color("ffe4a1"),r*.17,true)
		"beat":
			icon(c,"wings",p,r*.70,ink)
			for side in [-1,1]:
				c.draw_arc(p+Vector2(side*r*.20,0),r*.76,-.72 if side>0 else PI-.72,.72 if side>0 else PI+.72,16,gold,2,true)
		"wings", "root":
			for side in [-1,1]:
				var v := PackedVector2Array([p,p+Vector2(side*r*.88,-r*.66),p+Vector2(side*r*.75,r*.12),p+Vector2(side*r*.30,r*.52)])
				c.draw_colored_polygon(v,ink)
				c.draw_line(p,p+Vector2(side*r*.60,-r*.30),Color("a2bda5"),2,true)
			c.draw_line(p+Vector2(0,-r*.20),p+Vector2(0,r*.70),gold,5,true)
		"reach":
			for side in [-1,1]:
				var q := p+Vector2(side*r*.65,-r*.55)
				c.draw_line(p+Vector2(side*r*.12,r*.58),q,ink,3,true)
				c.draw_circle(q,r*.14,gold)
			c.draw_arc(p,r*.92,PI*1.12,PI*1.88,24,Color("9fcbb4"),2,true)
		"shortcut":
			for dy in [-.32,.32]:
				c.draw_line(p+Vector2(-r*.85,r*dy),p+Vector2(r*.85,r*dy),ink,3,true)
			c.draw_polyline(PackedVector2Array([p+Vector2(r*.35,-r*.8),p+Vector2(r*.85,-r*.32),p+Vector2(r*.35,r*.12)]),gold,3,true)
			c.draw_polyline(PackedVector2Array([p+Vector2(-r*.35,-r*.12),p+Vector2(-r*.85,r*.32),p+Vector2(-r*.35,r*.8)]),gold,3,true)
		"reserve":
			var pts := PackedVector2Array()
			for n in 10:
				var a: float = -PI/2+n*PI/5
				pts.append(p+Vector2(cos(a),sin(a))*r*(.92 if n%2 == 0 else .43))
			c.draw_colored_polygon(pts,gold)
			c.draw_circle(p,r*.20,ink)
		"twin":
			flower(c,p+Vector2(-r*.4,0),r*.56,Color("a6c4dc"))
			flower(c,p+Vector2(r*.4,-r*.13),r*.56,Color("d4add7"))
		_:
			flower(c,p,r*.85,Color("c4a1cc") if kind == "meadow" else Color("9fbfcb"))

static func flower(c: CanvasItem, p: Vector2, r: float, tint: Color) -> void:
	for n in 5:
		var a: float = -PI/2+n*TAU/5
		c.draw_circle(p+Vector2(cos(a),sin(a))*r*.58,r*.38,tint)
	c.draw_circle(p,r*.30,Color("f0d389"))
	c.draw_circle(p+Vector2(-r*.07,-r*.09),r*.10,Color("fff4cf"))
