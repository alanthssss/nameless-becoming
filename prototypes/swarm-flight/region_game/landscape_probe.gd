extends SceneTree
## Developer fixture: checks decorative anchors and captures native composition.
## No disk saves, no claim of a player-earned trip or aesthetic acceptance.
const Model = preload("res://region_game/model.gd")
const View = preload("res://region_game/view.gd")
const Layout = preload("res://region_greybox/layout.gd")
const TileScene = preload("res://pond_tilemap/main.tscn")
var failures := 0
var checks := 0
var directory := ""
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL "+label)
func check_ambient(view) -> void:
	# If wind or water samples a different plate/mask, the rectangular patch
	# reappears over the graded base whenever that layer becomes visible.
	for sprite: Sprite2D in view._paint_root.get_children():
		check(sprite.material.get_shader_parameter("plate_art")==sprite.texture,
			"paint remains registered to the same illustration")
		check(sprite.material.get_shader_parameter("depth_map")==View.DEPTH_MAPS[view.area_key],
			"static and moving paint share the scene's depth map")
	# A stationary camera must still show the breeze. Switching accessibility
	# settings mid-frame must restore the original paint in the same view.
	var rect: Rect2 = view._crowns[0].rect
	view.clock = 0.0
	view.reduced_motion = false
	var initial: Vector2 = view._canopy_offset(rect)
	var travel := 0.0
	for step in range(1, 7):
		view.clock = float(step)*.5
		travel = maxf(travel, initial.distance_to(view._canopy_offset(rect)))
	check(travel > 1.0, "visible breeze at rest in "+view.area_key)
	view._update_crowns()
	var visible_surface := false
	for surface in view._surfaces:
		if surface.visible:
			visible_surface = true
			check(surface.material.get_shader_parameter("seconds")==view.clock,"surface follows presentation time")
	check(visible_surface, "ambient surface in the starting view of "+view.area_key)
	view.reduced_motion = true
	view._update_crowns()
	check(view._canopy_offset(rect)==Vector2.ZERO, "no ambient deflection with reduced motion")
	for surface in view._surfaces:
		check(not surface.visible, "reduced motion restores the painted surface")

func _initialize() -> void: call_deferred("run")
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): directory=arg.trim_prefix("--output=")
	if not directory.is_empty(): DirAccess.make_dir_recursive_absolute(directory)
	root.content_scale_size=Vector2i(1280,800)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var hub := View.new()
	hub.model = Model.new()
	hub.area_key = "hub"
	root.add_child(hub)
	hub.set_process(false)
	hub._prepare_paint()
	check_ambient(hub)
	hub.queue_free()
	await process_frame
	for region in ["pond","meadow"]:
		var model=Model.new()
		model.area=region
		model.phase="field"
		model.field=Model.Field.new()
		model.field.configure("pond" if region=="pond" else "violet",1,23)
		model._sync_field()
		var snapshot: Dictionary=model.field.snapshot()
		var view=View.new()
		view.model=model
		view.area_key=region
		view.reduced_motion=true
		root.add_child(view)
		view.set_process(false)
		view._prepare_paint()
		check_ambient(view)
		check(model.field.snapshot()==snapshot,"preparing painted field preserves resources and position")
		check(View.POND_PLATE!=View.MEADOW_PLATE,"each field owns its painted landscape")
		check(view._crowns.size()==(6 if region=="pond" else 7),"registered foliage landmarks for "+region)
		var plate: Texture2D=View.POND_PLATE if region=="pond" else View.MEADOW_PLATE
		var bloom: Texture2D=View.POND_BLOOM if region=="pond" else View.MEADOW_BLOOM
		check(view._bloom_texture()==bloom and bloom.get_size().x>20,"each collection region uses its painted live bloom")
		for crown in view._crowns:
			var rect: Rect2=crown.rect
			var back: Sprite2D=crown.back
			var front: Sprite2D=crown.front
			var uv := Rect2((rect.position-View.PLATE_RECT.position)/View.PLATE_RECT.size,rect.size/View.PLATE_RECT.size)
			check(back.texture==plate and front.texture==plate and back.region_rect==front.region_rect,"both layers sample the identical registered painting")
			check(back.region_rect.position.is_equal_approx(uv.position*plate.get_size()) and back.region_rect.size.is_equal_approx(uv.size*plate.get_size()),"crown maps to the exact world coordinates")
			check(back.z_index<0 and front.z_index>0,"foliage can pass in front of or behind the bee")
			check(view._canopy_offset(rect)==Vector2.ZERO,"reduced motion fixes every canopy")
		var crown: Dictionary=view._crowns[2]
		var rect: Rect2=crown.rect
		view.reduced_motion=false
		model.camera_offset=Vector2(0,-100)
		var left: Vector2=view._canopy_offset(rect)
		model.camera_offset=Vector2(1400,650)
		check(left.distance_to(view._canopy_offset(rect))>3.0,"raised leaves shift with camera travel")
		model.camera_offset=rect.get_center()-Vector2(640,400)
		model.p=rect.get_center()
		view._update_crowns()
		check(crown.front.visible,"registered crown overlays bee when it passes behind")
		model.p=Vector2(rect.get_center().x,rect.end.y+35.0)
		view._update_crowns()
		check(not crown.front.visible,"bee in front of crown remains unobstructed")
		view.reduced_motion=true
		var visible_size := View.MeadowLayout.VIEWPORT/View.MeadowLayout.FIELD_ZOOM
		for extreme: Vector2 in [Vector2(-10000,-10000),Vector2(-10000,10000),Vector2(10000,-10000),Vector2(10000,10000)]:
			model.p = extreme
			model.update_camera()
			check(View.PLATE_RECT.grow(.01).encloses(Rect2(model.camera_offset,visible_size)),"paint covers live zoomed camera extremes")
		var shots: Array=[]
		for index in [0,1,2,4,3]:
			var key: String=["entry","bend","middle","far","bay"][index] if region=="pond" else "unchanged-%d"%index
			shots.append({"kind":key,"p":model.field.layout.nodes[index].p})
		print(region+" painted field: "+str(view._crowns.size())+" registered foliage crowns")
		for size in [Vector2i(1280,800),Vector2i(960,600)]:
			root.size=size
			for place in shots:
				model.field.p=place.p
				model._sync_field()
				model.update_camera()
				view.queue_redraw()
				for i in 3: await process_frame
				if not directory.is_empty() and DisplayServer.get_name()!="headless":
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png(directory.path_join("%s-%s-%d.png"%[region,place.kind,size.x]))
		view.queue_free()
		await process_frame
	var tile=TileScene.instantiate()
	root.add_child(tile)
	tile.set_process(false)
	tile.world.set_process(false)
	var tile_data: Dictionary=tile.world._landscape
	check(tile.world._bloom_texture()==null,"compact experiment retains its original flower family")
	check(tile_data.places.size()==4 and tile_data.water.size()==3,"compact tilemap inherits four places and shore-derived water groups")
	for actor in tile_data.actors:
		check(Layout.walkable(tile.model.field.layout,actor.p,28),"compact scenery roots retain real-bank clearance")
	for group in tile_data.water:
		check(not Layout.walkable(tile.model.field.layout,group.p,0),"compact fallen leaves remain over water")
	tile.queue_free()
	await process_frame
	print("Landscape: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
