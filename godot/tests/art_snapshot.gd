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
		"completion_card":
			game.delivered = 4
			game.message = "敌虫空手嗅探，蜂翼也会受伤。停留片刻恢复体力。"
			game.mentor_tutorial.profile_id = "first_trip_pollination"
			game.mentor_tutorial.phase = "imitate"
			game.mentor_tutorial.lesson_id = "evade"
			game.update_interface()
		"drink_honey":
			game.tutorial_complete = true
			game.tutorial_step = 6
			game.mentor_tutorial.profile_id = ""
			game.mentor_tutorial.phase = "inactive"
			game.carried = 2
			game.crop_fuel_used = 0
			game.bee.energy = 40.0
			game.update_interface()
		"pollination_ecology":
			game.tutorial_complete = true
			game.tutorial_step = 6
			game.context_lessons_seen["sense"] = true
			game.context_lessons_seen["danger"] = true
			game.mentor_tutorial.profile_id = ""
			game.mentor_tutorial.phase = "inactive"
			for flower_index in game.flowers.size():
				var visible_flower: Dictionary = game.flowers[flower_index]
				visible_flower["tutorial_locked"] = false
				visible_flower["tutorial_hidden"] = false
				visible_flower["discovered"] = true
				game.flowers[flower_index] = visible_flower
			var pollination = game.season_mechanics.mechanic_by_id("pollination")
			if pollination != null:
				var donor_index := -1
				var first_target := -1
				var second_target := -1
				for candidate_donor in pollination.donor_indices:
					var variant := int(game.flowers[candidate_donor].get("pollen_variant", -1))
					var matching_targets: Array[int] = []
					for candidate_target in pollination.receptive_indices:
						if int(game.flowers[candidate_target].get("stigma_variant", -2)) == variant:
							matching_targets.append(candidate_target)
					if matching_targets.size() >= 2:
						donor_index = candidate_donor
						first_target = matching_targets[0]
						second_target = matching_targets[1]
						break
				if donor_index >= 0:
					game.season_mechanics.on_harvest(donor_index)
					game.season_mechanics.on_harvest(donor_index)
					game.bee.position = Vector2(game.flowers[first_target].position)
					game.season_mechanics.try_context_action(game.bee.position)
					game.bee.position = Vector2(game.flowers[second_target].position) + Vector2(-44, 20)
			game.update_interface()
		"mentor_sortie":
			game.mentor_tutorial.demo_time = game.mentor_tutorial.demo_duration * 0.58
			game.mentor_tutorial._update_demo_position()
		"mentor_defense":
			game.tutorial_step = 4
			game.tutorial_scent_revealed = true
			game.spawn_tutorial_mosquito()
			game.bee.position = Vector2(505, 445)
			game.mentor_tutorial._start_lesson("defense")
			game.mentor_tutorial.demo_time = game.mentor_tutorial.demo_duration * 0.42
			game.mentor_tutorial._update_demo_position()
		"mentor_evade":
			game.tutorial_step = 5
			game.tutorial_scent_revealed = true
			game.bee.position = Vector2(500, 430)
			game.spawn_tutorial_mosquito()
			game.mentor_tutorial._start_lesson("evade")
			game.mentor_tutorial.demo_time = game.mentor_tutorial.demo_duration * 0.28
			game.mentor_tutorial._update_demo_position()
		"relay_hive":
			game.tutorial_complete = true
			game.context_lessons_seen["sense"] = true
			game.context_lessons_seen["danger"] = true
			game.spawn_stage(9)
			game.mosquitoes.clear()
			game.ants.clear()
			game.crickets.clear()
			game.thrushes.clear()
			game.carried = 1
			game.bee.position = game.relay_hive.position
		"tutorial_attack":
			game.tutorial_step = 5
			game.tutorial_scent_revealed = true
			game.mentor_tutorial.profile_id = "first_trip_pollination"
			game.mentor_tutorial.lesson_id = "evade"
			game.mentor_tutorial.phase = "imitate"
			game.bee.active = true
			game.spawn_tutorial_mosquito()
			game.bee.position = Vector2(520, 410)
			var attacker: Dictionary = game.mosquitoes[-1]
			attacker.position = Vector2(760, 365)
			attacker.attack_state = "locked"
			attacker.attack_time = 0.48
			attacker.aim_direction = (game.bee.position - Vector2(attacker.position)).normalized()
			attacker.locked_origin = attacker.position
			attacker.locked_target = game.bee.position
			attacker.evade_sequence_at_lock = game.bee.evade_sequence
			game.mosquitoes[-1] = attacker
		"tutorial_evade_success":
			game.tutorial_step = 5
			game.tutorial_scent_revealed = true
			game.mentor_tutorial.profile_id = "first_trip_pollination"
			game.mentor_tutorial.lesson_id = "evade"
			game.mentor_tutorial.phase = "practice"
			game.bee.active = true
			game.spawn_tutorial_mosquito()
			var locked_target := Vector2(520, 410)
			game.bee.position = locked_target + Vector2.UP * 60.0
			var attacker: Dictionary = game.mosquitoes[-1]
			attacker.position = locked_target - Vector2(90, 0)
			attacker.velocity = Vector2.LEFT * 520.0
			attacker.attack_state = "dash"
			attacker.attack_time = 0.45
			attacker.aim_direction = Vector2.LEFT
			attacker.locked_origin = locked_target + Vector2.RIGHT * 240.0
			attacker.locked_target = locked_target
			attacker.evade_sequence_at_lock = game.bee.evade_sequence - 1
			game.mosquitoes[-1] = attacker
			game.evade_confirmation_time = 0.8
			game.evade_confirmation_position = locked_target
			game.evade_confirmation_direction = Vector2.LEFT
			game.message = "急转 1 / 2：冲刺穿过残影；提示收起，再独立完成一次。"
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
