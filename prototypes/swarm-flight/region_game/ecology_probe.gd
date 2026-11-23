extends SceneTree
## A genuine field step drives every resource change. The camera and placements
## are controlled developer fixtures to compare the exact same flower at play scale.
const Model = preload("res://region_game/model.gd")
const View = preload("res://region_game/view.gd")
var checks := 0
var failures := 0
var output := ""
var legacy := ""

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL "+label)

func _initialize() -> void: call_deferred("run")

func shot(view: Node2D,label: String) -> void:
	if output.is_empty() or DisplayServer.get_name()=="headless": return
	view.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(label+".png"))==OK,"native "+label)

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
		if arg.begins_with("--legacy="): legacy=arg.trim_prefix("--legacy=")
	if not output.is_empty(): DirAccess.make_dir_recursive_absolute(output)
	root.content_scale_size=Vector2i(1280,800)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.size=Vector2i(1280,800)
	if not legacy.is_empty():
		var model=Model.new()
		var old = JSON.parse_string(FileAccess.get_file_as_string(legacy))
		check(model.restore_payload(old) and model.area=="meadow","0.31 shipped entrance migrates")
		var next=Model.new()
		check(next.restore_payload(model.to_payload()) and next.p==model.p,"migrated position round-trips exactly")
	for region in ["pond","meadow"]:
		var m=Model.new()
		m.area=region
		m.field=Model.Field.new()
		var field=m.field
		field.configure("pond" if region=="pond" else "violet",0,23)
		var flower: Dictionary=field.flowers[0]
		# An ordinary newly opened flower starts with one nectar serving.
		field.p=flower.p+Vector2(44,13)
		m._sync_field()
		m.update_camera()
		var view=View.new()
		view.model=m
		view.area_key=region
		view.reduced_motion=true
		root.add_child(view)
		view.set_process(false)
		check(field.nectar_fill(flower)==1.0 and "按住" in view._nectar_caption(flower),"full flower advertises ready action")
		check(m.screen_to_field((flower.p-m.camera_offset)*View.MeadowLayout.FIELD_ZOOM).distance_to(flower.p)<.001,"mouse and world positions agree")
		var foot: Vector2=view._resource_root(flower)
		m.p=foot+Vector2(0,-45)
		check(view._flower_depth(flower)>m.p.y+view.BEE_FOOT.y,"bee can pass behind flower")
		m.p=foot+Vector2(0,5)
		check(view._flower_depth(flower)<m.p.y+view.BEE_FOOT.y,"bee can pass in front")
		m._sync_field()
		print("FLOWER PIXEL ",region," ",(flower.p-m.camera_offset)*View.MeadowLayout.FIELD_ZOOM)
		await shot(view,region+"-a-ready")
		view.collecting=true
		for i in 20: m.step(.05,Vector2.ZERO,true,false)
		check(flower.progress>.4 and flower.stock==1 and view._flower_depth(flower)<m.p.y+view.BEE_FOOT.y,"locked working flower sits behind the bee and shows action progress")
		await shot(view,region+"-b-contact")
		var plant_age: float=flower.phase_time
		for i in 17: m.step(.05,Vector2.ZERO,true,false)
		view.collecting=false
		check(field.cargo==1 and flower.stock==0 and flower.phase=="ripe" and flower.phase_time>plant_age,"nectar removed once; the same open plant keeps aging")
		check(not field.events.any(func(e): return e.kind=="flower_empty" and e.id==0),"harvesting never emits flower death")
		check(field.nectar_fill(flower)<.02 and view._nectar_caption(flower)=="补蜜中","empty nectar gauge is distinguished from ecology")
		var saved=Model.Field.new()
		check(saved.restore(field.snapshot()) and saved.flowers[0].nectar_wait==flower.nectar_wait,"taking nectar survives reload mid-refill")
		var bad: Dictionary=field.snapshot()
		bad.flowers[0].nectar_wait=-1
		check(not saved.restore(bad) and saved.flowers[0].stock==0,"invalid cooldown rejected without altering restored flower")
		await shot(view,region+"-c-drained")
		for i in 200: m.step(.05,Vector2.ZERO,false,false)
		check(flower.stock==0 and absf(field.nectar_fill(flower)-.5)<.01,"visible nectar half-full at mid refill")
		await shot(view,region+"-d-refilling")
		for i in 201: m.step(.05,Vector2.ZERO,false,false)
		check(flower.stock==1 and flower.phase=="ripe" and field.nectar_fill(flower)==1 and field.cargo==1,"same open flower can replenish; no automatic credit")
		await shot(view,region+"-e-full")
		field._enter_phase(flower,"fading",false)
		field._after_nectar_picked(flower)
		flower.phase_time=flower.phase_duration-.01
		field._supply(.05)
		check(flower.phase=="empty" and flower.stock==0 and not flower.has("nectar_wait"),"natural end of flower phase discards residual nectar clock")
		if region=="meadow":
			var host: Dictionary=field.materials[0]
			field._enter_phase(host,"ripe",true)
			field.p=host.p-Vector2(0,23)
			field._pulse(Vector2.DOWN)
			for i in 8: m.step(.05,Vector2.ZERO,true,false)
			check(field.drawing_resin_id==host.id and view._material_depth(host)<m.p.y+View.BEE_FOOT.y,"extracting resin keeps working bee in front of the bark")
			await shot(view,"meadow-resin-contact")
		view.queue_free()
		await process_frame
	print("FIELD ECOLOGY %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
