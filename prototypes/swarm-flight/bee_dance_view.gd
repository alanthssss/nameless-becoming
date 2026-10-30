extends "res://world_view.gd"
## Presentation adapter. Model-owned facts, times and listener positions
## are the only source of information; no extra bees or completion particles.

func _landmarks(_act: int) -> void:
	var source: Vector2 = model.SOURCE
	var comb: Vector2 = model.COMB
	if source.x > model.camera_x-220 and source.x < model.camera_x+1500:
		_source_cluster(source)
	if comb.x > model.camera_x-240 and comb.x < model.camera_x+1520:
		_wax_comb(comb)

func _source_cluster(source: Vector2) -> void:
	var center := source + Vector2(18, 20)
	var stem := PackedVector2Array([center+Vector2(0,12),center+Vector2(16,100),Vector2(source.x-40,690),Vector2(source.x+10,830)])
	ArtProps.stalk(self,stem[0],stem[1],stem[2],stem[3],10.0)
	# Side blossoms belong to this rooted plant, including when closed.
	ArtProps.branch(self,stem,0.17,source+Vector2(-41,58),3.8)
	ArtProps.branch(self,stem,0.13,source+Vector2(68,53),3.8)
	ArtProps.branch(self,stem,0.42,Vector2(source.x+4,599),3.2)
	ArtProps.branch(self,stem,0.57,Vector2(source.x-1,646),3.2)
	ArtSprites.small_leaf(self, Vector2(source.x+4,601), Vector2(source.x-110,558), 27)
	ArtSprites.small_leaf(self, Vector2(source.x-1,648), Vector2(source.x+119,611), 33)
	_painted_blossom(source+Vector2(-41,47),1.25,model.source_open)
	_painted_blossom(source+Vector2(68,41),1.40,model.source_open)
	_painted_blossom(center,2.05,model.source_open)
	if model.source_open:
		_ellipse(center+Vector2(0,3),Vector2(8,4),Color("e9b347"))
		_ellipse(center+Vector2(-2,1),Vector2(3,1.4),Color("fff0a9"))
	else:
		# A visibly folded flower agrees with source invalidation. It is not a
		# new red warning icon and is never still shown feeding visitors.
		ArtSprites.small_leaf(self,center+Vector2(5,23),center+Vector2(-26,-24),13)
		ArtSprites.small_leaf(self,center+Vector2(4,23),center+Vector2(27,-19),13)

func _painted_blossom(point: Vector2, size: float, opened: bool) -> void:
	var fold := Vector2(1.0,1.0) if opened else Vector2(0.48,0.75)
	draw_set_transform(_world_offset+point,0.0,fold*size)
	ArtProps.decor(self,Vector2.ZERO,"flower")
	draw_set_transform(_world_offset)

func _wax_comb(comb: Vector2) -> void:
	# A broad leaf and rooted stalk support the visible wax face. The wax is
	# scenery with a model-owned landing area, not a floating UI rectangle.
	ArtProps.stalk(self,comb+Vector2(153,53),comb+Vector2(172,134),Vector2(comb.x+110,720),Vector2(comb.x+138,830),14.0)
	ArtSprites.small_leaf(self,comb+Vector2(174,72),comb+Vector2(-179,68),67)
	var contour := [comb+Vector2(-145,-27),comb+Vector2(-135,-72),comb+Vector2(-60,-82),comb+Vector2(5,-77),comb+Vector2(67,-88),comb+Vector2(136,-65),comb+Vector2(149,-17),comb+Vector2(165,22),comb+Vector2(121,77),comb+Vector2(47,80),comb+Vector2(-25,88),comb+Vector2(-112,75),comb+Vector2(-144,35),comb+Vector2(-154,18),comb+Vector2(-155,-8),comb+Vector2(-145,-27)]
	_silhouette(contour,Color("cc963f"),Color("715025"),3.1)
	var inner: Array = []
	for point in contour: inner.append(comb+(point-comb)*Vector2(0.96,0.92)+Vector2(-1,-3))
	_silhouette(inner,Color("ebbd65"),Color("f6d38b"),2.0)
	for row in 4:
		for col in 7:
			if (row == 0 or row == 3) and (col == 0 or col == 6): continue
			var point := comb+Vector2(-114+col*35+(row%2)*14,-47+row*31)
			_wax_cell(point,16.8+sin(row*2.1+col)*1.5,row*7+col)
	_curve(comb+Vector2(-119,-52),comb+Vector2(-67,-80),comb+Vector2(50,-75),comb+Vector2(119,-42),Color("ffe5a0a8"),2.2)
	_curve(comb+Vector2(-127,44),comb+Vector2(-75,69),comb+Vector2(57,77),comb+Vector2(118,44),Color("a4793790"),2.1)

func _wax_cell(center: Vector2, radius: float, seed_value: int) -> void:
	var points := PackedVector2Array()
	for i in 6:
		var angle := PI/6+float(i)*TAU/6
		var irregular := 1.0+sin(float(seed_value)*1.3+i*2.2)*0.045
		points.append(center+Vector2(cos(angle),sin(angle))*radius*irregular)
	points.append(points[0])
	var fill := Color("e4aa4e").lerp(Color("efc778"),float(seed_value%4)/6.0)
	draw_colored_polygon(points,fill)
	draw_polyline(points,Color("bb873d"),1.8,true)
	draw_polyline(PackedVector2Array([points[3]+Vector2(0,-1),points[4]+Vector2(0,-1),points[5]+Vector2(0,-1)]),Color("ffe0a1"),1.4,true)

func _neighbors() -> void:
	for i in model.listeners.size():
		var listener: Dictionary = model.listeners[i]
		var point: Vector2 = listener.pos
		if point.x < model.camera_x-90 or point.x > model.camera_x+1370: continue
		if listener.state in ["waiting","listening","foraging"]:
			_grounded_bee(point,listener.face,0.77,0.0)
			if listener.state == "foraging" and model.source_open:
				_sip(point,listener.face)
		else:
			_bee(point,0.77,listener.face,1.0,false,float(i)+4,"depart")

func _leader() -> void:
	if model.phase == "playing" and model.perched:
		var dancing: bool = model.share_state == "dancing"
		var offset: Vector2 = model.dance_pose() if dancing else Vector2.ZERO
		var direction: Vector2 = (model.SOURCE-model.COMB).normalized()
		var sway := sin(model.dance_elapsed*26.0)*0.055 if dancing else 0.0
		_grounded_bee(model.p+offset,direction,1.0,sway)
	elif model.phase == "playing" and model.feeding_elapsed > 0.0:
		_grounded_bee(model.p,Vector2.RIGHT,1.0,0.0)
		_sip(model.p,Vector2.RIGHT)
	else:
		super._leader()

func _grounded_bee(point: Vector2, direction: Vector2, size: float, sway: float) -> void:
	var mirror := -1.0 if direction.x < 0 else 1.0
	var pitch := atan2(direction.y,absf(direction.x))*mirror*0.35+sway
	draw_set_transform(_world_offset+point,pitch,Vector2(mirror,1.0)*size)
	# Folded wings and planted feet distinguish a listener from a dancing bee.
	_silhouette([Vector2(-2,-6),Vector2(-8,-18),Vector2(-28,-21),Vector2(-29,-12),Vector2(-27,-4),Vector2(-9,-5),Vector2(-2,-6)],Color("d6e7cfe8"),INK,1.4)
	_curve(Vector2(-9,-7),Vector2(-17,-9),Vector2(-24,-12),Vector2(-26,-14),Color("fffce4"),1.1)
	for x in [-10.0,3.0]:
		_curve(Vector2(x,8),Vector2(x-3,13),Vector2(x-4,19),Vector2(x+2,19),INK,1.8)
	ArtSprites.bee_body(self,1.0,false,0.0,false)
	draw_set_transform(_world_offset)

func _sip(point: Vector2, direction: Vector2) -> void:
	var mouth := point+Vector2(-24 if direction.x < 0 else 24,8)
	var destination: Vector2 = model.SOURCE+Vector2(18,21)
	if mouth.distance_to(destination) < 84:
		_curve(mouth,mouth+Vector2(2,8),destination-Vector2(0,5),destination,Color("6d4e29"),1.0)

func _waiting_friends() -> void:
	pass

func neighbor_words() -> String:
	return ""

func _shelter(shelter: Dictionary) -> void:
	var point: Vector2 = shelter.pos
	var half: float = shelter.half_width
	ArtProps.shelter_plant(self,point,half)
	draw_line(point+Vector2(-7,-91),point+Vector2(-7,-55),INK,2,true)
	ArtProps.decor(self,point+Vector2(-7,-40),"shelter_lamp_lit" if shelter.reached else "shelter_lamp")
