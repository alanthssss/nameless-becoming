extends SceneTree
## Developer fixture: checks decorative anchors and captures native composition.
## No disk saves, no claim of a player-earned trip or aesthetic acceptance.
const Model = preload("res://region_game/model.gd")
const View = preload("res://region_game/view.gd")
const Dressing = preload("res://region_game/landscape.gd")
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
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): directory=arg.trim_prefix("--output=")
	if not directory.is_empty(): DirAccess.make_dir_recursive_absolute(directory)
	root.content_scale_size=Vector2i(1280,800)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	for region in ["pond","meadow"]:
		var model=Model.new()
		model.area=region
		model.phase="field"
		model.field=Model.Field.new()
		model.field.configure("pond" if region=="pond" else "violet",1,23)
		model._sync_field()
		var snapshot: Dictionary=model.field.snapshot()
		var data: Dictionary=Dressing.build(model.field)
		check(data.places.size()==(4 if region=="pond" else 0),"pond places; meadow not redressed "+region)
		check(data.patches.size()==(4 if region=="pond" else 0),"pond washes; meadow not recolored "+region)
		var roles := {}
		for actor in data.actors:
			roles[actor.place]=true
			check(Layout.walkable(model.field.layout,actor.p,28),"root remains on actual land")
		check(roles.size()==(4 if region=="pond" else 0),"pond composition; meadow preserved "+region)
		check(model.field.snapshot()==snapshot,"dressing does not change field state")
		for group in data.water:
			check(not Layout.walkable(model.field.layout,group.p,0),"floating-leaf group stays in non-walkable water")
		print(region+" composition: "+str(data.actors.size())+" actors; "+str(roles.keys()))
		var view=View.new()
		view.model=model
		view.area_key=region
		view.reduced_motion=true
		root.add_child(view)
		view.set_process(false)
		var shots: Array=data.places.duplicate()
		if region=="meadow":
			for i in [0,1,4,3]: shots.append({"kind":"unchanged-%d"%i,"p":model.field.layout.nodes[i].p})
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
		# Whole-silhouette retreat applies even if the bee is above the root.
		if not data.actors.is_empty():
			var actor: Dictionary=data.actors[0]
			model.p=actor.p+Vector2(0,-65)*float(actor.size)
			check(Dressing.actor_alpha(view,actor)<=.21,"foreground retreats around bee silhouette")
			model.p=actor.p+Vector2(300,0)
			check(Dressing.actor_alpha(view,actor)>.99,"foreground returns away from bee")
		view.queue_free()
		await process_frame
	var tile=TileScene.instantiate()
	root.add_child(tile)
	tile.set_process(false)
	tile.world.set_process(false)
	var tile_data: Dictionary=tile.world._landscape
	check(tile_data.places.size()==4 and tile_data.water.size()==3,"compact tilemap inherits four places and shore-derived water groups")
	for actor in tile_data.actors:
		check(Layout.walkable(tile.model.field.layout,actor.p,28),"compact scenery roots retain real-bank clearance")
	for group in tile_data.water:
		check(not Layout.walkable(tile.model.field.layout,group.p,0),"compact fallen leaves remain over water")
	tile.queue_free()
	await process_frame
	print("Landscape: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
