extends SceneTree

var output_path := "/tmp/journey-campaign.png"
var snapshot_state := "hive"


func _init() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output_path = argument.trim_prefix("--output=")
		elif argument.begins_with("--state="):
			snapshot_state = argument.trim_prefix("--state=")
	call_deferred("capture")


func capture() -> void:
	var game = (load("res://campaign.tscn") as PackedScene).instantiate()
	game.transition_duration = 0.0
	root.add_child(game)
	await process_frame
	if snapshot_state == "field":
		game._begin_level("spring_lichun", false)
		await process_frame
		var field := game.router.current_area as JourneyCampaignField
		field.bee.position = Vector2(field.tasks[0].source_position)
		field.camera.position_smoothing_enabled = false
		field.camera.position = field.camera_target_for(field.bee.position)
		field._emit_status()
		field.queue_redraw()
	elif snapshot_state == "climax":
		for order in 5:
			var level: Dictionary = game.state.catalog.level_at(order)
			var token: int = game.state.begin_level(String(level.id))
			var counts: Array[int] = []
			for objective in level.objectives:
				counts.append(int((objective as Dictionary).goal))
			game.state.settle_level({
				"journey_token": token,
				"level_id": String(level.id),
				"objectives_complete": true,
				"returned_home": true,
				"objective_counts": counts,
				"phases_completed": 0,
				"elapsed_seconds": 300.0,
				"energy_remaining": 200.0,
				"actions": 10,
				"failed": false,
			})
		game._show_hive(false, true)
		game._begin_level("spring_guyu", false)
		await process_frame
		var field := game.router.current_area as JourneyCampaignField
		field.bee.position = Vector2(field.tasks[0].position)
		field.camera.position_smoothing_enabled = false
		field.camera.position = field.camera_target_for(field.bee.position)
		field._emit_status()
		field.queue_redraw()
	await process_frame
	await process_frame
	var image := root.get_viewport().get_texture().get_image()
	var save_error := image.save_png(output_path)
	if save_error != OK:
		push_error("无法保存正式战役截图：%d" % save_error)
		quit(1)
		return
	print("Saved campaign snapshot to %s" % output_path)
	quit(0)
