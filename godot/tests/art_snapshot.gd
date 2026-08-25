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
	var frozen_feedback_mechanic = null
	var frozen_feedback_kind := ""
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
					pollination.process(0.47)
					game.bee.position = Vector2(game.flowers[second_target].position) + Vector2(-44, 20)
			game.update_interface()
		"pollination_dual_carry_sense":
			game.tutorial_complete = true
			game.tutorial_step = 6
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
				for variant in 2:
					for candidate in pollination.donor_indices:
						if int(game.flowers[candidate].get("pollen_variant", -1)) == variant:
							game.season_mechanics.on_harvest(candidate)
							game.season_mechanics.on_harvest(candidate)
							break
			game.bee.position = Vector2(560, 430)
			game.bee.sense_time = 3.0
			game.update_interface()
		"pollination_transfer":
			game.tutorial_complete = true
			game.tutorial_step = 6
			game.mentor_tutorial.profile_id = ""
			game.mentor_tutorial.phase = "inactive"
			for flower_index in game.flowers.size():
				var visible_flower: Dictionary = game.flowers[flower_index]
				visible_flower["tutorial_locked"] = false
				visible_flower["tutorial_hidden"] = false
				visible_flower["discovered"] = true
				game.flowers[flower_index] = visible_flower
			var pollination = game.season_mechanics.mechanic_by_id("pollination")
			frozen_feedback_mechanic = pollination
			frozen_feedback_kind = "deposit"
			if pollination != null and not pollination.receptive_indices.is_empty():
				var target_index := int(pollination.receptive_indices[0])
				var target_variant := int(game.flowers[target_index].get("stigma_variant", -1))
				for candidate in pollination.donor_indices:
					if int(game.flowers[candidate].get("pollen_variant", -2)) == target_variant:
						game.season_mechanics.on_harvest(candidate)
						game.season_mechanics.on_harvest(candidate)
						break
				game.bee.position = Vector2(game.flowers[target_index].position) + Vector2(-48, 0)
				game.season_mechanics.try_context_action(game.bee.position)
				pollination.process(0.20)
			game.update_interface()
		"pollination_mismatch":
			game.tutorial_complete = true
			game.tutorial_step = 6
			game.mentor_tutorial.profile_id = ""
			game.mentor_tutorial.phase = "inactive"
			for flower_index in game.flowers.size():
				var visible_flower: Dictionary = game.flowers[flower_index]
				visible_flower["tutorial_locked"] = false
				visible_flower["tutorial_hidden"] = false
				visible_flower["discovered"] = true
				game.flowers[flower_index] = visible_flower
			var pollination = game.season_mechanics.mechanic_by_id("pollination")
			frozen_feedback_mechanic = pollination
			frozen_feedback_kind = "rejection"
			if pollination != null and not pollination.receptive_indices.is_empty():
				var target_index := int(pollination.receptive_indices[0])
				var target_variant := int(game.flowers[target_index].get("stigma_variant", -1))
				for candidate in pollination.donor_indices:
					if int(game.flowers[candidate].get("pollen_variant", -1)) != target_variant:
						game.season_mechanics.on_harvest(candidate)
						break
				game.bee.position = Vector2(game.flowers[target_index].position) + Vector2(-48, 0)
				game.season_mechanics.try_context_action(game.bee.position)
				pollination.process(0.18)
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
	if not frozen_feedback_kind.is_empty():
		if not assert_frozen_feedback(game, frozen_feedback_mechanic, frozen_feedback_kind):
			quit(1)
			return
		# Main is the only owner that advances SeasonMechanics feedback. Freeze both
		# process domains before waiting for the renderer so the requested image cannot
		# silently become a landed/expired state on a slow desktop frame.
		game.set_process(false)
		game.bee.set_physics_process(false)
	for frame in 4:
		await process_frame
	# The snapshot runner briefly loses focus while the desktop harness returns
	# control. Remove only that test-induced pause before reading the framebuffer.
	if game.phase == "paused":
		game.toggle_pause()
		await process_frame
	if not frozen_feedback_kind.is_empty() and not assert_frozen_feedback(game, frozen_feedback_mechanic, frozen_feedback_kind):
		quit(1)
		return
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


func assert_frozen_feedback(game, mechanic, expected_kind: String) -> bool:
	if mechanic == null or String(mechanic.feedback_event.get("kind", "")) != expected_kind:
		push_error("美术快照目标状态已过期：期待 %s，实际 %s" % [expected_kind, String(mechanic.feedback_event.get("kind", "")) if mechanic != null else "missing"])
		return false
	var event: Dictionary = mechanic.feedback_event
	var flower_index := int(event.get("flower_index", -1))
	if flower_index < 0 or flower_index >= game.flowers.size():
		push_error("美术快照反馈目标花索引无效")
		return false
	if expected_kind == "deposit" and not bool(game.flowers[flower_index].get("pollination_pending", false)):
		push_error("传粉中途快照没有保持 pollination_pending")
		return false
	if expected_kind == "rejection":
		var authority_total := 0
		var body_total := 0
		for value in mechanic.pollen_charges:
			authority_total += int(value)
		for value in game.bee.pollen_loads:
			body_total += int(value)
		if body_total + 1 != authority_total:
			push_error("异型中途快照没有保持身体 + 飞行粒 = 权威载粉")
			return false
		var duration := maxf(0.01, float(event.get("duration", 0.01)))
		var progress := 1.0 - clampf(float(event.get("remaining", 0.0)) / duration, 0.0, 1.0)
		var grain_position: Vector2 = mechanic._rejection_grain_position(event, progress)
		var grain_local: Vector2 = (grain_position - Vector2(game.bee.position)).rotated(-float(game.bee.facing))
		if absf(grain_local.x) <= 41.0 and absf(grain_local.y) <= 30.0:
			push_error("异型中途快照的飞行粒仍被 82×60 蜂轮廓遮挡")
			return false
	return true
