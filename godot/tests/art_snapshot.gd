extends SceneTree

var output_path := "/tmp/nameless-art-snapshot.png"
var stage_index := 0
var snapshot_state := "tutorial"

func _init() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output_path = argument.trim_prefix("--output=")
		elif argument.begins_with("--stage="):
			stage_index = int(argument.trim_prefix("--stage="))
		elif argument.begins_with("--state="):
			snapshot_state = argument.trim_prefix("--state=")
	call_deferred("capture")

func capture() -> void:
	var packed := load("res://main.tscn") as PackedScene
	var game = packed.instantiate()
	root.add_child(game)
	await process_frame
	game.persistence_enabled = false
	game.start_game()
	if stage_index > 0:
		game.stage_index = mini(stage_index, game.stages.size() - 1)
		game.spawn_stage(game.stage_index)
	match snapshot_state:
		"tutorial_attack":
			game.tutorial_step = 5
			game.tutorial_scent_revealed = true
			game.spawn_tutorial_mosquito()
			game.bee.position = Vector2(520, 410)
			var attacker: Dictionary = game.mosquitoes[-1]
			attacker.position = Vector2(760, 365)
			attacker.attack_state = "aim"
			attacker.attack_time = 0.9
			attacker.aim_direction = (game.bee.position - Vector2(attacker.position)).normalized()
			game.mosquitoes[-1] = attacker
		"summer_raid":
			game.tutorial_complete = true
			game.context_lessons_seen["sense"] = true
			game.context_lessons_seen["danger"] = true
			game.spawn_stage(7)
			game.season_mechanics.on_home(3, 0.1)
			game.bee.position = Vector2(560, 410)
		"autumn_seed":
			game.tutorial_complete = true
			game.context_lessons_seen["sense"] = true
			game.context_lessons_seen["danger"] = true
			game.spawn_stage(13)
			var reserve = game.season_mechanics.mechanic_by_id("reserve")
			var seed_flower: Dictionary = game.flowers[0]
			seed_flower.nectar = 1
			game.flowers[0] = seed_flower
			reserve.on_harvest(0)
			game.bee.position = Vector2(seed_flower.position) + Vector2(46, 0)
		"winter_route":
			game.tutorial_complete = true
			game.context_lessons_seen["sense"] = true
			game.context_lessons_seen["danger"] = true
			game.spawn_stage(19)
			var winter = game.season_mechanics.mechanic_by_id("huddle")
			game.carried = 2
			game.bee.position = Vector2(winter.warm_points[0].position)
			game.season_mechanics.try_context_action(game.bee.position)
		"boss_window":
			game.tutorial_complete = true
			game.context_lessons_seen["sense"] = true
			game.context_lessons_seen["danger"] = true
			game.spawn_stage(6)
			game.boss.position = game.tuning_blooms[0]
			game.bee.position = Vector2(game.boss.position) + Vector2(70, 0)
			game.boss_director.notify_feed_completed()
		_:
			# Move away from the doorway so the player and hive silhouettes do not overlap.
			game.bee.position = Vector2(300, 390)
	game.bee.facing = 0.0
	for frame in 4:
		await process_frame
	# The snapshot runner briefly loses focus while the desktop harness returns
	# control. Remove only that test-induced pause before reading the framebuffer.
	if game.phase == "paused":
		game.toggle_pause()
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
