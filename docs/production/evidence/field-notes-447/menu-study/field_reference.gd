extends SceneTree
## Render still backgrounds for the field lettering study from the frozen #451 art package.
## The view uses an in-memory model. No game session, input bindings, or save path is opened.
const Model = preload("res://region_game/model.gd")

class Plate extends "res://region_game/view.gd":
	func _draw_resource_feedback() -> void: pass
	func _draw_home_bearing() -> void: pass
	func _field_note(_at: Vector2, _words: String, _active: bool, _mark_width := 0, _screen_space := false) -> Rect2:
		return Rect2()

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var dest := OS.get_environment("HONEY_FIELD_STUDY")
	if dest.is_empty() or not DirAccess.dir_exists_absolute(dest):
		quit(2)
		return
	root.size = Vector2i(960,600)
	var anchors := {}
	for fact in [["pond","return"],["pond","flower"],["pond","fiber"],["meadow","resin"],["meadow","tired"],["meadow","open"],["pond","pickup"],["pond","full"],["pond","gathering"]]:
		var model = Model.new()
		model.p=model.HUB_DEPART
		if fact[0]=="meadow": model.owned.append("meadow")
		if not model.transition_to(fact[0]):
			quit(3)
			return
		var target: Vector2 = model.field.layout.nodes[0].p
		match fact[1]:
			"flower","full","gathering": target=model.field.flowers[0].p
			"fiber","resin","tired","open","pickup": target=model.field.materials[0].p
		if fact[1]!="return":
			model.field.p=target+Vector2(-44,6)
			if fact[1]=="tired":
				model.field.energy=6.0
				model.field.p=target+Vector2(-126,82)
			if fact[1]=="full":
				model.field.cargo=model.capacity()
				model.cargo.blue=model.capacity()
			if fact[1]=="pickup":
				model.materials.fiber=1
				model.field.materials[0].phase="empty"
			if fact[1]=="open":
				var item: Dictionary=model.field.materials[0]
				item.phase="ripe"
				item.hits=model.field.shell_strength(item)
				model.field.p=target+Vector2(-16,6)
			if fact[1] in ["flower","gathering"]:
				model.field.flowers[0].phase="ripe"
				model.field.flowers[0].stock=1
			if fact[1]=="gathering":
				model.field.p=target+Vector2(-8,-3)
				model.field._locked.assign([model.field.flowers[0].id])
				model.field.flowers[0].progress=.6
				model.field.last_action="采蜜中"
			model._sync_field()
			model.update_camera()
		var scene:=Plate.new()
		scene.model=model
		scene.area_key=model.area
		scene.reduced_motion=true
		root.add_child(scene)
		scene.collecting=fact[1]=="gathering"
		scene.clock=1
		scene.set_process(false)
		scene.queue_redraw()
		for i in 5: await process_frame
		await RenderingServer.frame_post_draw
		var img:=root.get_texture().get_image()
		var ratio:=Vector2(img.get_size())/root.get_visible_rect().size
		var factor:=ratio*scene.scale
		var point: Vector2=(target-model.camera_offset)*factor
		var bee: Vector2=(model.p-model.camera_offset)*factor
		var home: Vector2=(model.field.layout.nodes[0].p-model.camera_offset)*factor
		var key: String=fact[1]
		anchors[key]={"target":[point.x,point.y],"bee":[bee.x,bee.y],"home":[home.x,home.y],"energy":model.energy,"maximum":model.max_energy(),"capacity":model.capacity(),"honey":model.cargo_total(),"fiber":model.materials.fiber,"resin":model.materials.resin,"coins":model.coins}
		if img.save_png(dest.path_join(key+".png"))!=OK:
			quit(4)
			return
		root.remove_child(scene)
		scene.free()
	var f:=FileAccess.open(dest.path_join("anchors.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify(anchors,"  "))
	f.close()
	quit()
