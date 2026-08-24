extends SceneTree

var output_path := "/tmp/nameless-art-snapshot.png"

func _init() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output_path = argument.trim_prefix("--output=")
	call_deferred("capture")

func capture() -> void:
	var packed := load("res://main.tscn") as PackedScene
	var game = packed.instantiate()
	root.add_child(game)
	await process_frame
	game.persistence_enabled = false
	game.start_game()
	# Move away from the doorway so the player and hive silhouettes do not overlap.
	game.bee.position = Vector2(300, 390)
	game.bee.facing = 0.0
	for frame in 4:
		await process_frame
	RenderingServer.force_draw()
	var image := root.get_texture().get_image()
	if image == null:
		push_error("当前显示驱动不提供帧缓冲；请勿用 --headless 生成美术快照。")
		quit(1)
		return
	var error := image.save_png(output_path)
	if error != OK:
		push_error("无法保存美术快照：%s" % error_string(error))
		quit(1)
		return
	print("ART SNAPSHOT SAVED: %s" % output_path)
	quit(0)
