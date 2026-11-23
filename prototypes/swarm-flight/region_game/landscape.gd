extends RefCounted
## Presentation-only place composition. All anchors remain on the real coast;
## dressing never changes resources, movement, collision or saved state.
const Layout = preload("res://region_greybox/layout.gd")
const Props = preload("res://art_props.gd")
const Sprites = preload("res://art_sprites.gd")

static func build(field, compact := false) -> Dictionary:
	var result := {"patches":[],"actors":[],"places":[],"water":[]}
	# This approved slice dresses the pond only; violet keeps its own composition.
	if str(field.region)!="pond": return result
	var nodes: Array = field.layout.nodes
	var scale := .78 if compact else 1.0
	for location in [0,1,4,3]:
		var center: Vector2 = nodes[location].p
		var place := "entry" if location==0 else "bend" if location==1 else "bay" if location==4 else "far"
		result.places.append({"kind":place,"p":center})
		var offset := Vector2(35,72) if location==0 else Vector2(20,-78) if location==1 else Vector2(0,25) if location==4 else Vector2(30,-32)
		var radius := Vector2(245,125)*scale if location!=4 else Vector2(102,130)*scale
		var tone := Color(.76,.65,.36,.43) if location==0 else Color(.27,.44,.23,.38) if location==1 else Color(.40,.35,.24,.52) if location==4 else Color(.86,.81,.50,.43)
		_add_patch(result,field.layout,center+offset*scale,radius,tone,location)
		var arrangements: Array
		match place:
			"entry": arrangements=[[-95,75,"leaf",.9],[85,98,"leaf",.7],[-48,88,"stone",.52]]
			"bend": arrangements=[[-90,-95,"leaf",1.35],[-34,-114,"leaf",.95],[42,-125,"reed",.85],[115,105,"leaf",1.10]]
			"bay": arrangements=[[-84,5,"reed",1.15],[82,35,"reed",.95],[-63,65,"leaf",.85],[68,77,"stone",.65]]
			_: arrangements=[[-80,-105,"stone",1.20],[-22,-83,"stone",.85],[38,-113,"stone",.72],[95,-79,"leaf",1.12],[77,112,"reed",.80]]
		for entry in arrangements:
			var at := center+Vector2(float(entry[0]),float(entry[1]))*scale
			var size := float(entry[3])*scale
			var kind := str(entry[2])
			# Move along the local bank to retain clearance from every potential
			# flower, not just currently enabled ones. No future growth is hidden.
			for adjustment in [Vector2.ZERO,Vector2(-45,15),Vector2(45,20),Vector2(0,42)]:
				var candidate: Vector2 = at+adjustment*scale
				if not Layout.walkable(field.layout,candidate,28): continue
				var height := 104.0 if kind=="reed" else 54.0 if kind=="leaf" else 26.0
				var bounds := Rect2(candidate-Vector2(51,height)*size,Vector2(102,height+12)*size)
				if _covers_resource(field,bounds): continue
				if candidate.distance_to(nodes[0].p)<95: continue
				result.actors.append({"p":candidate,"kind":kind,"size":size,"place":place,"phase":float(location)*1.7+at.x*.01})
				break
	if str(field.region)=="pond":
		# Fallen broad leaves rest on the water, rather than pretending to be
		# walkable islands. Their arrangement follows this map's actual shore.
		for bank_spec in [{"node":1,"offset":Vector2(-90,-180),"size":.86},{"node":4,"offset":Vector2(-160,40),"size":1.18},{"node":3,"offset":Vector2(125,105),"size":.9}]:
			var desired: Vector2 = nodes[int(bank_spec.node)].p+bank_spec.offset*scale
			var bank: Dictionary=_shore(field.layout,desired)
			var centre: Vector2=bank.p+bank.outward*125*scale
			result.water.append({"p":centre,"size":float(bank_spec.size)*scale,"phase":float(bank_spec.node),"edge":bank.p})
		# One substantial reed stand marks the mouth of the material bay.
		# It grows from the wet bank and is drawn with the other ground anchors.
		var bank: Dictionary=_shore(field.layout,nodes[4].p+Vector2(-145,25)*scale)
		var foot: Vector2=bank.p-bank.outward*36
		result.actors.append({"p":foot,"kind":"reed","size":1.45*scale,"place":"bay","phase":6.7})
	return result

static func _shore(layout: Dictionary, desired: Vector2) -> Dictionary:
	var coast: PackedVector2Array=layout.coast
	var nearest:=coast[0]
	var outward:=Vector2.LEFT
	for i in coast.size():
		var next: Vector2=coast[(i+1)%coast.size()]
		var point:=Geometry2D.get_closest_point_to_segment(desired,coast[i],next)
		if point.distance_squared_to(desired)<nearest.distance_squared_to(desired):
			nearest=point
			outward=(next-coast[i]).normalized().orthogonal()
	if Layout.walkable(layout,nearest+outward*8,0): outward=-outward
	return {"p":nearest,"outward":outward}

static func _covers_resource(field, bounds: Rect2) -> bool:
	for flower in field.flowers:
		if bounds.grow(10).has_point(flower.p): return true
	for item in field.materials:
		if bounds.grow(15).has_point(item.anchor): return true
	return false

static func _add_patch(result: Dictionary, layout: Dictionary, center: Vector2, radius: Vector2, tone: Color, seed_value: int) -> void:
	if not Layout.walkable(layout,center,8): return
	# Each triangle fades to its outer edge; irregular radii avoid hard discs.
	var edge := PackedVector2Array()
	for i in 32:
		var angle := TAU*float(i)/32.0
		var direction := Vector2(cos(angle),sin(angle))
		var reach := radius*direction*(1.0+.10*sin(angle*3.0+float(seed_value))+.06*cos(angle*5.0))
		var end := center+reach
		for shrink in 8:
			if Layout.walkable(layout,end,12): break
			reach *= .82
			end=center+reach
		edge.append(end)
	result.patches.append({"p":center,"edge":edge,"tone":tone})

static func draw_floor(view: Node2D, data: Dictionary) -> void:
	for group in data.get("water",[]):
		if view._visible(group.p,220): _water_leaves(view,group)
	for patch in data.get("patches",[]):
		if not view._visible(patch.p,230): continue
		var edge: PackedVector2Array = patch.edge
		var tone: Color = patch.tone
		var clear := Color(tone,0.0)
		for i in edge.size():
			var a: Vector2 = edge[i]
			var b: Vector2 = edge[(i+1)%edge.size()]
			var inner_a: Vector2 = patch.p.lerp(a,.46)
			var inner_b: Vector2 = patch.p.lerp(b,.46)
			view.draw_polygon(PackedVector2Array([patch.p,inner_a,inner_b]),PackedColorArray([tone]))
			view.draw_polygon(PackedVector2Array([inner_a,a,b]),PackedColorArray([tone,clear,clear]))
			view.draw_polygon(PackedVector2Array([inner_a,b,inner_b]),PackedColorArray([tone,clear,tone]))
		# Small attached soil flecks sit within the wash, never a bright ring.
		for i in 11:
			var at: Vector2 = patch.p.lerp(edge[(i*7)%edge.size()],.28+float(i%4)*.12)
			view._ellipse(at,Vector2(3.5+float(i%3),1.4),Color(.43,.42,.25,.15))

static func actor_alpha(view, actor: Dictionary) -> float:
	# Fade based on the whole tall silhouette, so the head cannot hide a bee
	# even while its root is more than one bee-height away.
	if float(actor.p.y)<=view.model.p.y+33.0: return 1.0
	var height := 108.0 if str(actor.kind)=="reed" else 55.0 if str(actor.kind)=="leaf" else 27.0
	var rect := Rect2(actor.p-Vector2(52,height)*float(actor.size),Vector2(104,height+12)*float(actor.size)).grow(10)
	var nearest: Vector2 = view.model.p.clamp(rect.position,rect.end)
	return lerpf(.20,1.0,smoothstep(0.0,42.0,view.model.p.distance_to(nearest)))

static func draw_actor(view, actor: Dictionary) -> void:
	var at: Vector2 = actor.p
	var size: float = actor.size
	var alpha := actor_alpha(view,actor)
	view._ground_shadow(at+Vector2(0,3),Vector2(40,8)*size,.13*alpha)
	match str(actor.kind):
		"stone": _stone(view,at,size,alpha)
		"reed":
			view._ellipse(at+Vector2(0,4),Vector2(40,9)*size,Color(.31,.36,.20,.20*alpha))
			for i in 5:
				var root := at+Vector2(float(i-2)*8,2*sin(float(i)))*size
				var sway := 0.0 if view.reduced_motion else sin(view.clock*1.2+float(actor.phase)+float(i)*.2)*3.0
				var tip := root+Vector2(float(i-2)*8+sway,-64-float((i*3)%5)*10)*size
				view._curve(root,root+Vector2(-3,-35)*size,tip+Vector2(-5,22)*size,tip,Color(.32,.43,.22,alpha*.84),2.1*size)
				view._curve(root+Vector2(-1,0),root+Vector2(-5,-31)*size,tip+Vector2(-6,20)*size,tip-Vector2(1,0),Color(.69,.70,.37,alpha*.6),.9*size)
				_leaf(view,root+Vector2(0,-19)*size,root+Vector2((-30 if i%2==0 else 30),-45)*size,8*size,alpha)
				# Warm, small reed heads are scenery, not the large outlined fiber pod.
				view._ellipse(tip+Vector2(0,-6)*size,Vector2(4.2,12)*size,Color(.43,.38,.22,.82*alpha))
				view._ellipse(tip+Vector2(-1,-8)*size,Vector2(1.8,8)*size,Color(.69,.58,.33,.65*alpha))
		"leaf":
			for i in 4:
				var root := at+Vector2(float(i-1)*3,0)*size
				var sway := 0.0 if view.reduced_motion else sin(view.clock*.85+float(actor.phase)) * 2
				var tip := root+Vector2([-46.0,-24.0,28.0,49.0][i]+sway,[-23.0,-51.0,-42.0,-18.0][i])*size
				_leaf(view,root,tip,(18.0 if i%2==0 else 21.0)*size,alpha)
	view.draw_set_transform(view._world_offset)

static func _water_leaves(view, group: Dictionary) -> void:
	var at: Vector2=group.p
	var size: float=group.size
	var drift:=0.0 if view.reduced_motion else sin(view.clock*.42+float(group.phase))*2.0
	for i in 5:
		var p:=at+Vector2([-56.0,-11.0,48.0,16.0,-55.0][i],[-14.0,-37.0,-3.0,32.0,39.0][i])*size
		var width: float=[105.0,123.0,95.0,131.0,73.0][i]*size
		var height:=width*.43
		# Do not let decorative water leaves spill onto traversable land.
		if Layout.walkable(view.model.field.layout,p,0): continue
		view._ellipse(p+Vector2(0,7)*size,Vector2(width*.46,height*.48),Color(.12,.36,.29,.17))
		view.draw_set_transform(view._world_offset+p+Vector2(drift,0),[-.22,.31,-.38,.17,-.42][i])
		view.draw_texture_rect_region(Sprites.ATLAS,Rect2(-width*.5,-height*.5,width,height),Sprites.LEAF,Color(.69,.86,.65,.75))
		view.draw_set_transform(view._world_offset)
		var below:=p+Vector2(0,height*.5+10)
		view._curve(below+Vector2(-width*.45,0),below+Vector2(-width*.21,6),below+Vector2(width*.13,6),below+Vector2(width*.29,1),Color(.73,.89,.72,.27),1.3)
	view._curve(at+Vector2(-112,-37)*size,at+Vector2(-115,-7)*size,at+Vector2(-98,22)*size,at+Vector2(-80,30)*size,Color(.76,.89,.73,.18),1.7)

static func _leaf(view, root: Vector2, tip: Vector2, height: float, alpha: float) -> void:
	var length := root.distance_to(tip)
	view.draw_set_transform(view._world_offset+root,(root-tip).angle())
	view.draw_texture_rect_region(Sprites.ATLAS,Rect2(-length,-height,length,height),Sprites.LEAF,Color(.87,.93,.76,alpha))
	view.draw_set_transform(view._world_offset)

static func _stone(view, at: Vector2, size: float, alpha: float) -> void:
	# Reuse the painted stone surface from the existing terrain atlas; the
	# outline is a low shore pebble, not a new raised platform or collider.
	var shape := PackedVector2Array()
	for i in 24:
		var angle := TAU*float(i)/24.0
		shape.append(Vector2(cos(angle)*42.0,sin(angle)*17.0-7.0)*(1.0+.045*sin(angle*3.0+.5)))
	var points := PackedVector2Array()
	var uv := PackedVector2Array()
	for point in shape:
		points.append(at+point*size)
		uv.append((Vector2(700,949)+Vector2((point.x+45)/90.0*450,(point.y+27)/41.0*35))/Vector2(Props.TERRAIN.get_size()))
	view.draw_polygon(points,PackedColorArray([Color(.91,.92,.78,alpha)]),uv,Props.TERRAIN)
	view.draw_polyline(PackedVector2Array([at+Vector2(-34,-13)*size,at+Vector2(-12,-20)*size,at+Vector2(14,-22)*size]),Color(.87,.85,.64,.55*alpha),1.2,true)
