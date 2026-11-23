extends SceneTree
## Developer-composed native views, not a human playthrough.
const Scene = preload("res://pond_tilemap/main.tscn")
var directory := "/tmp/pond-tilemap-native"
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): directory=arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(directory)
	root.content_scale_size=Vector2i(1280,800)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var game=Scene.instantiate()
	root.add_child(game)
	game.set_process(false)
	for size in [Vector2i(1280,800),Vector2i(960,600)]:
		root.size=size
		for shot in [{"name":"entry","p":Vector2(230,512)},{"name":"fork","p":Vector2(960,540)},{"name":"pocket","p":Vector2(960,890)},{"name":"far","p":Vector2(1450,450)}]:
			game.model.field.p=shot.p
			game.model._sync_field()
			game.update_camera()
			game._process(0)
			for i in 4: await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(directory.path_join("%s-%d.png"%[shot.name,size.x]))
	game.queue_free()
	await process_frame
	print("Native TileMap views: ",directory)
	quit()
