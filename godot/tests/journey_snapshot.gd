extends SceneTree

var output_path := "/tmp/journey-world.png"
var snapshot_state := "field_mid"


func _init() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output_path = argument.trim_prefix("--output=")
		elif argument.begins_with("--state="):
			snapshot_state = argument.trim_prefix("--state=")
	call_deferred("capture")


func capture() -> void:
	var game = (load("res://journey.tscn") as PackedScene).instantiate()
	game.transition_duration = 0.0
	root.add_child(game)
	await process_frame
	if snapshot_state == "hive":
		pass
	elif snapshot_state == "hive_return":
		var token: int = game.state.begin_sortie()
		game.state.settle_return(token, 6, 2)
		game._show_hive(true, true)
	else:
		game._begin_sortie()
		await process_frame
		var field := game.router.current_area as SpringJourneyField
		match snapshot_state:
			"field_home":
				field.bee.position = Vector2(330, 560)
			"field_far":
				field.bee.position = Vector2(1760, 690)
				field.carried = 5
				field.relay_hive.active = true
			"field_return":
				field.bee.position = Vector2(1220, 960)
				field.carried = 6
				field.pollination.pollinated_flowers = 2
				field.relay_hive.active = true
			_:
				field.bee.position = Vector2(1060, 565)
				field.carried = 2
		field.camera.position_smoothing_enabled = false
		field.camera.position = field.camera_target_for(field.bee.position)
		field._emit_status()
		field.queue_redraw()
	await process_frame
	await process_frame
	var image := root.get_viewport().get_texture().get_image()
	var save_error := image.save_png(output_path)
	if save_error != OK:
		push_error("无法保存旅程截图：%d" % save_error)
		quit(1)
		return
	print("Saved journey snapshot to %s" % output_path)
	quit(0)
