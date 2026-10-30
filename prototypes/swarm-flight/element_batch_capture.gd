extends SceneTree
## Developer fixture: production painters at native scale; no player acceptance claim.
const Model = preload("res://spring_journey_model.gd")
class SpecimenView:
	extends "res://spring_journey_view.gd"
	func _draw() -> void:
		draw_rect(Rect2(0,0,1280,800),Color("b9d6cb"))
		# Existing game background and unchanged source painters, without HUD overlap.
		_background(int(model.chapter.region),0.0)
		_shelter(model.shelters[0])
		_ring(model.rings[0],0)
		_source_cluster(Vector2(1070,450))
var folder := OS.get_environment("SWARM_ELEMENT_QA_DIR")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if folder.is_empty() or DisplayServer.get_name()=="headless":
		push_error("Native renderer and SWARM_ELEMENT_QA_DIR required")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(folder)
	root.size=Vector2i(1280,800)
	var view:=SpecimenView.new()
	var model:=Model.new()
	model.load_stage(0)
	model.camera_x=0
	model.shelters=[{"pos":Vector2(230,435),"half_width":180.0,"reached":false,"section":0},{"pos":Vector2(-2000,435),"half_width":180.0,"reached":false,"section":1}]
	model.rings=[{"pos":Vector2(650,395),"active":false,"section":0,"direction":Vector2.RIGHT}]
	view.model=model
	view.set_process(false)
	root.add_child(view)
	for region in [0,3]:
		model.chapter.region=region
		for half in [118.0,180.0]:
			model.shelters[0].half_width=half
			for state in [0,1]:
				model.shelters[0].reached=state==1
				model.rings[0].active=state==1
				model.source_open=state==0
				view.clock=float(state)*1.8
				view.queue_redraw()
				await RenderingServer.frame_post_draw
				var name:="region-%d-width-%d-state-%d.png"%[region,int(half),state]
				if root.get_texture().get_image().save_png(folder.path_join(name))!=OK:
					quit(1)
					return
	model.chapter.region=0
	model.shelters[0].half_width=180.0
	model.source_open=true
	model.rings[0].direction=Vector2(1,-0.55).normalized()
	DirAccess.make_dir_recursive_absolute(folder.path_join("motion"))
	for frame in 12:
		view.clock=float(frame)/6.0
		model.rings[0].active=frame>=2
		view._reactions.clear()
		if frame>=2:
			view._reactions.append({"kind":"ring","pos":model.rings[0].pos,"age":float(frame-2)/6.0})
		model.source_open=frame<7
		view.queue_redraw()
		await RenderingServer.frame_post_draw
		if root.get_texture().get_image().save_png(folder.path_join("motion/frame-%03d.png"%frame))!=OK:
			quit(1)
			return
	print("ELEMENT CAPTURE: 8 native state/width/region combinations; 12 sampled motion frames")
	view.queue_free()
	await process_frame
	quit()
