extends SceneTree
## Behavioral oracle is the unchanged painted pixels, not the collision implementation.
const Model = preload("res://spring_journey_model.gd")
const Canopy = preload("res://leaf_canopy_geometry.gd")
const Old = preload("res://long_journey_model.gd")
var checks := 0
var failures := 0
var image: Image
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		print("FAIL: "+label)
func fresh(half:=180.0):
	var m := Model.new()
	m.load_stage(1)
	var leaf: Dictionary=m.shelters[0].duplicate()
	leaf.half_width=half
	m.shelters=[leaf]
	m.walls.clear()
	m.rain_fields.clear()
	m.rings.clear()
	m.weather_phase="rain"
	m.rain_timer=1000
	return m
func alpha_at(point: Vector2, leaf: Dictionary) -> float:
	var width: float=leaf.half_width*2+20
	var uv: Vector2=(point-(leaf.pos+Vector2(-width/2,-161)))/Vector2(width,95)
	if uv.x<0 or uv.x>=1 or uv.y<0 or uv.y>=1: return 0.0
	return image.get_pixel(19+int(uv.x*592),822+int(uv.y*251)).a
func painted_top(x: float, leaf: Dictionary) -> float:
	for offset in range(-161,-65):
		if alpha_at(Vector2(x,leaf.pos.y+offset),leaf)>=0.6: return leaf.pos.y+offset
	return INF
func body_clear(point: Vector2, leaf: Dictionary, radius: float) -> bool:
	# Interior disk samples exclude a 2px antialias/trace tolerance at the rim.
	for x in range(-int(radius)+2,int(radius)-1,4):
		for y in range(-int(radius)+2,int(radius)-1,4):
			if Vector2(x,y).length()>radius-2: continue
			if alpha_at(point+Vector2(x,y),leaf)>=0.6: return false
	return true
func run() -> void:
	image=Image.load_from_file(ProjectSettings.globalize_path("res://art/revision-atlas.png"))
	var widths := [180.0]
	if "--variants" in OS.get_cmdline_user_args(): widths=[118.0,149.0,180.0]
	for half in widths:
		var base=fresh(half)
		var leaf: Dictionary=base.shelters[0]
		var q: Vector2=leaf.pos
		for anchor_y in [465.0,500.0,520.0,600.0]:
			var translated: Dictionary=leaf.duplicate()
			translated.pos.y=anchor_y
			var lamp:=Canopy.lamp_anchor(translated)
			check(alpha_at(lamp,translated)>=0.6,"lamp rope starts inside original painted underside "+str([half,anchor_y]))
			var joint: Vector2=translated.pos+Vector2(half+4,-80)
			check(alpha_at(joint,translated)>=0.6,"main stem joins painted leaf "+str([half,anchor_y]))
		for fraction in [-0.85,-0.5,0.0,0.5,0.85]:
			var x: float=q.x+fraction*half
			var top:=painted_top(x,leaf)
			check(absf(base.rain_floor_at(x)-top)<=2.0,"painted roof matches rain at "+str([half,fraction]))
			for slope in [-45.0,0.0,45.0]:
				var rain=fresh(half)
				rain.p=q+Vector2(0,40)
				rain.drops.clear()
				rain.drops.append({"pos":Vector2(x,top-35),"vel":Vector2(slope,350)})
				for frame in 30: rain.advance_rain(1.0/120)
				check(rain.drops.is_empty(),"falling/slanted drop intercepted "+str([half,fraction,slope]))
			for held in [false,true]:
				for above in [false,true]:
					var m=fresh(half)
					m.p=Vector2(x,q.y-230 if above else q.y-15)
					var clear:=true
					for frame in 70:
						m.step(Vector2.DOWN if above else Vector2.UP,held,1.0/60)
						clear=clear and body_clear(m.p,leaf,9.0 if held else 14.0)
					check(clear,"ordinary/charged body clear at every frame "+str([half,fraction,held,above]))
		# Independent GDD radius oracle: 14 ordinary / 9 folded, no former +9 pad.
		for held in [false,true]:
			var radius:=9.0 if held else 14.0
			var free=fresh(half)
			free.charging=held
			free.p=Vector2(q.x,painted_top(q.x,leaf)-radius-3)
			var before: Vector2=free.p
			free.resolve_leaf_roofs(before)
			check(free.p==before,"no invisible padding "+str([half,held]))
			var curled=fresh(half)
			curled.p=q+Vector2(-177*(half*2+20)/380,-113)
			curled.charging=held
			curled.resolve_leaf_roofs(curled.p)
			check(Canopy.contact(curled.p,radius,leaf).is_empty() and body_clear(curled.p,leaf,radius),"concave curl fully separated "+str([half,held]))
			curled.charging=false
			curled.resolve_leaf_roofs(curled.p)
			check(Canopy.contact(curled.p,14,leaf).is_empty(),"unfold at curl fully clear "+str(half))
		for offset in [Vector2(0,-225),Vector2(0,-15),Vector2(-half-60,-113),Vector2(half+60,-90)]:
			var dash=fresh(half)
			dash.p=q+offset
			var target:=q+Vector2(-half+13,-113) if offset.x<0 else q+Vector2(half-10,-90) if offset.x>0 else q+Vector2(0,-120)
			var direction: Vector2=(target-dash.p).normalized()
			for frame in 32: dash.step(Vector2.ZERO,true,1.0/60)
			dash.step(direction,false,1.0/120)
			check(dash.events.any(func(e): return e.kind=="burst"),"real release initiates 880px/s burst "+str([half,offset]))
			var clear:=body_clear(dash.p,leaf,14)
			for frame in 70:
				dash.step(direction,false,1.0/120)
				clear=clear and body_clear(dash.p,leaf,14)
			check(clear,"released burst never embeds "+str([half,offset]))
		for side in [-1.0,1.0]:
			var m=fresh(half)
			m.p=q+Vector2(side*(half+80),0)
			for frame in 40: m.step(Vector2(-side,0),false,1.0/60)
			check(m.shelter_index_at(m.p)==0,"side entry "+str([half,side]))
			m.p=q
			m.velocity=Vector2.ZERO
			for frame in 80: m.step(Vector2(side,0),false,1.0/60)
			check(m.shelter_index_at(m.p)<0 and absf(m.p.x-q.x)>half,"side exit "+str([half,side]))
			var rain=fresh(half)
			rain.drops.clear()
			rain.drops.append({"pos":q+Vector2(side*(half+40),-190),"vel":Vector2(0,350)})
			rain.p=q
			for frame in 45: rain.advance_rain(1.0/120)
			check(rain.drops.size()==1,"no invisible rain roof outside leaf "+str([half,side]))
		for reached in [false,true]:
			var m=fresh(half)
			m.shelters[0].reached=reached
			m.p=q
			m.stamina=50
			m.started=true
			for frame in 30: m.step(Vector2.ZERO,false,1.0/60)
			check(m.stamina>50,"real leaf pocket restores reached="+str(reached))
			check(m.shelter_index_at(q+Vector2(0,-210))<0,"above roof is not recovery")
	# Synthetic legacy v2 fixture uses the actual G0 embedded coordinate.
	var legacy:=Model.new()
	legacy.load_stage(1)
	legacy.p=legacy.shelters[0].pos
	legacy.save_checkpoint(legacy.p)
	var safe: Vector2=legacy.p
	legacy.p=Vector2(619.65,409.71)
	var payload: Dictionary=legacy.save_payload()
	var restored:=Model.new()
	check(restored.restore_payload(JSON.parse_string(JSON.stringify(payload))),"legacy v2 overlapping position accepted via safe checkpoint")
	check(restored.p==safe and restored.events.any(func(e):return e.kind=="recover_geometry"),"old embedded coordinate recovers before first frame")
	check(restored.checkpoint_story==legacy.checkpoint_story and restored.story_state()==legacy.checkpoint_story,"committed story preserved on geometry recovery")
	var exact: Dictionary=restored.save_payload()
	var clone:=Model.new()
	check(clone.restore_payload(exact) and clone.save_payload()==exact,"valid geometry snapshot remains exact")
	for index in [0,1,2]:
		var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://review-evidence/2026-10-30/leaf-canopy/g1/legacy-stage-%d.json"%index))
		var migrated:=Model.new()
		check(migrated.restore_payload(fixture),"actual baseline-generated v2 fixture accepted stage "+str(index))
		check(migrated.p==Vector2(180,420),"safe legacy position remains exact stage "+str(index))
		if index==2:
			check(migrated.rings[0].pos==Vector2(2760,280) and migrated.checkpoint.rings[0].pos==Vector2(2760,280),"known old wind positions migrate through current layout in active and checkpoint state")
			check(migrated.rings[0].active and migrated.checkpoint.rings[0].active,"legacy earned ring flags retained")
			var bad: Dictionary=fixture.duplicate(true)
			bad.state.rings[0].pos=Model.pack(Vector2(2641,465))
			var unchanged: Dictionary=migrated.save_payload()
			check(not migrated.restore_payload(bad) and migrated.save_payload()==unchanged,"unknown ring layout rejected atomically")
	for launch_x in [2465.0,2485.0,2505.0]:
		var route:=Model.new()
		route.load_stage(2)
		route.front_open=true
		route.wall_at(2350).broken=true
		route.keeper.state="watch"
		route.p=Vector2(launch_x,465)
		for frame in 30: route.step(Vector2.RIGHT,true,1.0/60)
		route.step(Vector2.RIGHT,false,1.0/60)
		for frame in 180: route.step(Vector2.RIGHT,false,1.0/60)
		# Keep the former horizontal inputs as a counterexample: they must no
		# longer automatically answer the separate back-side approach.
		check(not route.passage_open and route.rings_hit==0 and route.recoveries==0,"horizontal early/nominal/late release does not auto-open back knot "+str(launch_x))
	for launch_x in [2710.0,2725.0,2740.0]:
		var route:=Model.new()
		route.load_stage(2)
		route.front_open=true
		route.wall_at(2350).broken=true
		route.keeper.state="watch"
		route.p=Vector2(launch_x,465)
		for frame in 30: route.step(Vector2.UP,true,1.0/60)
		for frame in 180: route.step(Vector2.UP,false,1.0/60)
		check(route.passage_open and route.rings_hit==3 and route.recoveries==0 and route.p.x>3400,"deliberate upward wind approach continues beyond back passage "+str(launch_x))
	var old:=Old.new()
	old.load_stage(0)
	var old_leaf: Dictionary=old.shelters[0]
	check(old.rain_hits_shelter(old_leaf.pos-Vector2(0,160),old_leaf.pos-Vector2(0,96),old_leaf)==false,"comparison rain retains historical top")
	check(old.rain_hits_shelter(old_leaf.pos-Vector2(0,96),old_leaf.pos-Vector2(0,94),old_leaf),"comparison rain retains historical cutoff")
	print("CANOPY VERIFIED: ",checks," checks; ",failures," failures; widths=",widths)
	quit(1 if failures else 0)
