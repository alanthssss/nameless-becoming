extends SceneTree

var failures: Array[String] = []

func _init() -> void:
	call_deferred("run_test")

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func run_test() -> void:
	var packed := load("res://main.tscn") as PackedScene
	var game = packed.instantiate()
	root.add_child(game)
	await process_frame
	game.persistence_enabled = false
	expect(game.term_label.text.is_empty() and game.season_label.text == "过关条件", "首次进入仍直接显示季节或节气名称，或没有预告固定过关条件卡")
	expect(game.delivered_title_label.text == "归巢蜜", "顶部归巢进度仍使用模糊的本关进度标签")
	game.start_game()
	var first_goal := int(game.stages[0].goal)
	var first_mechanics_status := String(game.season_mechanics.hud_status())
	expect(game.season_label.text == "过关条件" and game.detail_label.text.contains("归巢蜜 0 / %d" % first_goal), "首关没有常驻显示归巢蜜过关条件")
	expect(not first_mechanics_status.is_empty() and game.detail_label.text.contains(first_mechanics_status), "首关教学期间隐藏了季节机制过关条件")
	expect(game.detail_label.text.contains("教学 · 观看采蜜归巢示范"), "首关老师傅演示没有在过关条件卡显示当前教学要求")
	# Every mentor blocker must fit above the transient world message. The delivery
	# HUD previously left only 42px here, so the fourth wrapped line painted over it.
	var original_profile: String = game.mentor_tutorial.profile_id
	var original_phase: String = game.mentor_tutorial.phase
	var original_lesson: String = game.mentor_tutorial.lesson_id
	var condition_font: Font = game.detail_label.get_theme_font("font")
	var condition_font_size: int = game.detail_label.get_theme_font_size("font_size")
	var condition_line_height: float = condition_font.get_height(condition_font_size)
	var condition_line_spacing: int = game.detail_label.get_theme_constant("line_spacing")
	for lesson in ["sortie", "sense", "defense", "evade", "pollination", "raid", "seed", "warmth"]:
		for mentor_phase in ["demo", "imitate", "practice"]:
			game.mentor_tutorial.profile_id = "layout_regression"
			game.mentor_tutorial.phase = mentor_phase
			game.mentor_tutorial.lesson_id = lesson
			game.update_interface()
			await process_frame
			var rendered_lines: int = game.detail_label.get_line_count()
			var required_height := rendered_lines * condition_line_height + maxi(0, rendered_lines - 1) * condition_line_spacing
			expect(required_height <= game.detail_label.size.y + 0.5, "过关条件溢出卡片：%s/%s 需要 %.1fpx，只有 %.1fpx" % [lesson, mentor_phase, required_height, game.detail_label.size.y])
	expect(game.detail_label.position.y + game.detail_label.size.y + 5.0 <= game.message_label.position.y, "过关条件与情境消息没有保留安全间距")
	expect(game.message_label.position.y + game.message_label.size.y <= 212.0, "情境消息溢出第一张状态卡")
	expect(game.message_label.clip_text and game.message_label.max_lines_visible == 2, "情境消息没有限制为卡片内两行，长文案仍可能覆盖下一张卡")
	game.mentor_tutorial.profile_id = original_profile
	game.mentor_tutorial.phase = original_phase
	game.mentor_tutorial.lesson_id = original_lesson
	game.update_interface()
	# The legacy causal route remains independently tested here; the dedicated
	# mentor test owns demonstrate -> imitate -> practice sequencing.
	game.mentor_tutorial.profile_id = ""
	game.mentor_tutorial.phase = "inactive"
	game.update_interface()
	game.bee.active = true
	expect(game.phase == "playing" and game.stage_index == 0, "新循环未进入冬至")
	expect(game.is_in_hive_entry(game.HIVE_RETURN_POS), "归巢目标没有落在可见巢门内")
	expect(not game.is_in_hive_entry(Vector2(game.HIVE_RETURN_POS.x, 220.0)), "左侧任意高度仍被误判为蜂巢")
	expect(game.is_spring_gathering_stage(0) and game.is_spring_gathering_stage(3), "授粉玩法组未被春季正式美术路由识别")
	expect(not game.is_spring_gathering_stage(6), "春分失律者关不应启用春季普通关美术")
	expect(not game.is_spring_gathering_stage(7) and not game.is_spring_gathering_stage(9), "袭扰玩法组错误沿用春季正式美术")
	expect(game.tutorial_step == 0 and game.tutorial_panel.visible, "首局没有从单一步骤的移动教学开始")
	var first_pollination = game.season_mechanics.mechanic_by_id("pollination")
	expect(first_pollination != null and first_pollination.receptive_indices.all(func(index): return not bool(game.flowers[index].get("tutorial_locked", false))), "HUD 已显示传粉条件，但首局受粉花仍被教学锁藏成闭合花苞")
	expect(not game.flower_configs.spring.has("pollen_transfer") and game.chain_window_s == 0.0, "首局仍有快速访花加蜜或连环增殖绕过教学路线")
	var goal_regression_game = packed.instantiate()
	root.add_child(goal_regression_game)
	goal_regression_game.persistence_enabled = false
	goal_regression_game.start_game()
	goal_regression_game.delivered = int(goal_regression_game.stages[0].goal)
	goal_regression_game.update_game(0.0)
	expect(goal_regression_game.phase == "playing", "首局不应以伪造进度绕过尚未发生的能力教学")
	goal_regression_game.queue_free()
	var pacing_game = packed.instantiate()
	root.add_child(pacing_game)
	pacing_game.persistence_enabled = false
	pacing_game.tutorial_complete = true
	pacing_game.start_game()
	var base_capacity: int = int(pacing_game.carry_capacity)
	for upgrade_round in 6:
		pacing_game.phase = "between"
		pacing_game.on_upgrade_selected(1)
	expect(int(pacing_game.carry_capacity) == base_capacity, "采蜜蜂成长重新扩大蜜囊，后期关卡会退化为一次归巢")
	pacing_game.queue_free()
	expect(not game.fullscreen_button.visible and not game.sound_button.visible and not game.quit_button.visible, "系统级操作仍常驻在游戏过程界面")
	expect(not game.sense_button.visible and not game.return_button.visible, "尚未行动时提前展示了采蜜或归巢")
	game.bee.position = game.tutorial_origin + Vector2(70, 0)
	game.update_progressive_guidance()
	expect(game.tutorial_step == 1, "移动完成后没有进入采蜜教学")
	game.carried = 1
	game.update_progressive_guidance()
	expect(game.tutorial_step == 2 and game.return_button.visible, "采到第一滴后没有出现归巢教学")
	game.delivered = 1
	game.carried = 0
	game._on_tutorial_home(1)
	game.update_progressive_guidance()
	expect(game.tutorial_step == 3 and not game.tutorial_complete and game.tutorial_panel.visible, "第一次存蜜后没有进入寻迹练习")
	game.bee.sense_cooldown = 0.0
	game._do_sense()
	expect(game.tutorial_step == 3 and game.tutorial_scent_revealed and bool(game.flowers[game.tutorial_hidden_index].discovered), "只按寻迹键没有揭出隐藏蜜源")
	expect(game.mosquitoes.is_empty(), "寻迹键本身不应被误算成找到隐藏花")
	game._on_tutorial_harvest(game.tutorial_hidden_index)
	expect(game.tutorial_step == 4 and game.mosquitoes.any(func(unit): return bool(unit.get("tutorial", false))), "实际采到隐藏花后没有形成资源争夺情境")
	game.bee.position = Vector2(game.mosquitoes[-1].position) + Vector2(10, 0)
	game.sting_cooldown = 0.0
	game.bee.energy = 100.0
	game._do_repel()
	expect(game.tutorial_step == 4, "仅按下惊退键、不确认敌虫离开资源圈就提前完成了教学")
	for frame in 20:
		game.update_mosquitoes(0.1)
		if game.tutorial_step == 5:
			break
	expect(game.tutorial_step == 5, "敌虫实际离开资源圈后没有发动可见攻击线")
	game.last_dir_tap["up"] = 10.0
	game.last_world_tap_time = 10.0
	game.last_world_tap_direction = Vector2.UP
	var locking_enemy: Dictionary = game.mosquitoes[-1]
	locking_enemy.attack_state = "aim"
	locking_enemy.attack_time = 0.01
	game.mosquitoes[-1] = locking_enemy
	game.update_mosquitoes(0.02)
	expect(String(game.mosquitoes[-1].attack_state) == "locked", "跟随虚线结束后没有进入独立锁定阶段")
	expect(float(game.last_dir_tap.up) == 0.0 and game.last_world_tap_time == 0.0, "锁定前的第一次输入没有清除，仍可与锁定后的第二次输入拼成抢跑急转")
	game.bee.energy = 100.0
	game.bee.velocity = Vector2.RIGHT
	expect(game.bee.try_evade(Vector2.UP), "教学急转动作未能触发")
	expect(game.bee.velocity.normalized().dot(Vector2.UP) > 0.99, "双击方向没有决定急转方向，仍沿旧速度飞行")
	game.on_evade_started()
	expect(game.tutorial_step == 5 and not game.tutorial_complete, "空放一次急转就错误完成了闪避教学")
	expect(not game.message.contains("掠过攻击线"), "空放急转仍被文案误报成已经躲开攻击")
	var tutorial_enemy: Dictionary = game.mosquitoes[-1]
	var locked_target: Vector2 = game.bee.position
	tutorial_enemy.position = locked_target - Vector2(45, 0)
	tutorial_enemy.velocity = Vector2(520, 0)
	tutorial_enemy.attack_state = "dash"
	tutorial_enemy.attack_time = 0.3
	tutorial_enemy.aim_direction = Vector2.RIGHT
	tutorial_enemy.locked_origin = tutorial_enemy.position
	tutorial_enemy.locked_target = locked_target
	tutorial_enemy.evade_sequence_at_lock = game.bee.evade_sequence
	game.mosquitoes[-1] = tutorial_enemy
	expect(not game._evade_cleared_locked_path(Vector2.RIGHT, locked_target, game.bee.evade_sequence), "锁定前已经发动的急转被错误沿用为本次闪避证据")
	game.bee.evade_cooldown = 0.0
	game.bee.energy = 100.0
	expect(game.bee.try_evade(Vector2.RIGHT), "沿攻击路线的错误急转没有触发动作")
	game.bee.position = locked_target + Vector2.RIGHT * 60.0
	expect(not game._evade_cleared_locked_path(Vector2.RIGHT, locked_target, int(tutorial_enemy.evade_sequence_at_lock)), "沿红色通道急转被错误算成侧向离线")
	game.bee.position = locked_target + Vector2.RIGHT * 80.0
	game.bee.evade_cooldown = 0.0
	game.bee.energy = 100.0
	expect(game.bee.try_evade(Vector2.UP), "远离锁点后的对照急转没有触发动作")
	game.bee.position += Vector2.UP * 60.0
	expect(not game._evade_cleared_locked_path(Vector2.RIGHT, locked_target, int(tutorial_enemy.evade_sequence_at_lock)), "先普通飞离锁点、再在远处空放急转被错误算成因果闪避")
	game.bee.position = locked_target
	game.bee.evade_cooldown = 0.0
	game.bee.energy = 100.0
	expect(game.bee.try_evade(Vector2.UP), "锁定后侧向急转没有触发")
	game.on_evade_started()
	game.bee.position = locked_target + Vector2.UP * 35.0
	expect(not game._evade_cleared_locked_path(Vector2.RIGHT, locked_target, int(tutorial_enemy.evade_sequence_at_lock)), "蜂心尚在 36px 危险通道内却被算成成功")
	game.bee.position = locked_target + Vector2.UP * 36.0
	expect(game._evade_cleared_locked_path(Vector2.RIGHT, locked_target, int(tutorial_enemy.evade_sequence_at_lock)), "蜂心到达可见危险通道边界后仍不算离线")
	game.bee.position = locked_target + Vector2.UP * 60.0
	game.update_mosquitoes(0.1)
	game.update_progressive_guidance()
	expect(game.tutorial_step == 6 and game.tutorial_complete and not game.tutorial_panel.visible, "攻击穿过旧位置且蜜蜂离开危险通道后教学仍未完成")
	game.context_lesson_time = 0.0
	game.bee.energy = 30.0
	game.update_progressive_guidance()
	expect(game.context_lesson_id == "low_energy" and game.tutorial_panel.visible, "低体力首次出现时没有情境教学")
	game.context_lesson_time = 0.0
	game.bee.energy = 100.0
	game.context_lessons_seen.erase("danger")
	game.mosquitoes = [{"id": 0, "position": game.bee.position + Vector2(20, 0), "velocity": Vector2.ZERO, "repel_time": 0.0}]
	game.update_progressive_guidance()
	expect(game.sense_button.text == "惊退", "敌害逼近时情境动作没有变为惊退")
	game.mosquitoes.clear()
	game.context_lesson_time = 0.0
	game.update_progressive_guidance()
	expect(not game.tutorial_panel.visible, "一次性情境教学结束后仍常驻界面")
	game.delivered = 0
	var gathering_total := 0
	for stage_index in 24:
		# 正色节点（春分/夏至/秋分）是失律者关卡，没有采蜜数据
		if game.stages[stage_index].has("boss"):
			continue
		gathering_total += 1
		game.spawn_stage(stage_index)
		var permanent_budget: int = int(game.stage_permanent_honey_budget(stage_index))
		expect(game.total_recoverable_honey() >= int(game.stages[stage_index].goal) + permanent_budget, "节令 %d 未给合法饮蜜或机制消耗保留资源预算" % stage_index)
		expect(int(game.stages[stage_index].goal) > int(game.carry_capacity), "节令 %d 仍可在一只基础蜜囊内完成" % stage_index)
		for flower_index in game.flowers.size():
			for other_index in range(flower_index + 1, game.flowers.size()):
				expect(Vector2(game.flowers[flower_index].position).distance_to(Vector2(game.flowers[other_index].position)) >= 81.9, "节令 %d 花朵生成间距不足" % stage_index)
		var expected_id: String = ["pollination", "conscription", "reserve", "huddle"][clampi(stage_index / 6, 0, 3)]
		expect(game.season_mechanics.mechanic_by_id(expected_id) != null, "节令 %d 未激活 %s 机制" % [stage_index, expected_id])
		var stage_mechanics_status := String(game.season_mechanics.hud_status())
		expect(game.delivered_title_label.text == "归巢蜜" and game.season_label.text == "过关条件", "节令 %d 没有保持归巢蜜顶部标签和过关条件侧栏" % stage_index)
		expect(game.detail_label.text.contains("归巢蜜 0 / %d" % int(game.stages[stage_index].goal)), "节令 %d 没有常驻显示归巢蜜目标" % stage_index)
		expect(not stage_mechanics_status.is_empty() and game.detail_label.text.contains(stage_mechanics_status), "节令 %d 没有常驻显示季节机制条件" % stage_index)
		if stage_index in [7, 13, 19]:
			expect(game.detail_label.text.contains("教学 · 观看"), "机制首关 %d 的老师傅门禁没有常驻显示" % stage_index)
			var visual_variants := {}
			for flower in game.flowers:
				visual_variants[int(flower.get("visual_variant", -1))] = true
			expect(visual_variants.has(0) and visual_variants.has(1), "机制首关 %d 没有稳定展示两种花" % stage_index)
		if stage_index == 13:
			expect(int(game.flowers[0].nectar) == 2 and int(game.flowers[1].nectar) == 2, "秋季两朵教学花被资源补偿改坏，无法先模仿再独立取舍")
			expect(bool(game.flowers[0].get("showcase_seed", false)) and bool(game.flowers[1].get("showcase_seed", false)), "秋季两次留种练习没有固定真实种花身份")
	# 中继巢只改变远路休息点，不改变归巢结算语义。
	game.spawn_stage(9)
	expect(game.relay_hive.enabled and not game.relay_hive.active, "立夏远路没有出现未点亮的中继巢")
	var relay_delivered_before: int = int(game.delivered)
	var main_hive_activity_before: float = float(game.hive_activity_time)
	game.carried = 1
	game.bee.position = game.relay_hive.position
	expect(game._try_activate_relay_hive() and game.relay_hive.active and game.carried == 0, "靠近后使用一滴蜜没有点亮中继巢")
	expect(game.delivered == relay_delivered_before, "中继巢错误把燃料算作主巢交付")
	expect(game.hive_activity_time == main_hive_activity_before, "中继巢点亮错误触发主巢活动反馈")
	game.bee.energy = 20.0
	game.bee.velocity = Vector2.ZERO
	game.bee.has_target = false
	game._update_relay_hive(1.0)
	expect(game.bee.energy == 32.0, "中继巢没有按固定位置慢速恢复体力")
	game.bee.position = Vector2(800, 540)
	Input.action_press("return_hive")
	game.update_game(0.0)
	Input.action_release("return_hive")
	expect(game.bee.target == game.HIVE_RETURN_POS, "Q 被中继巢劫持，不再指向唯一主巢")
	# 正色节点直接进入失律者遭遇
	var pattern_by_boss := {"mosquito": "orbital", "cricket": "erratic", "thrush": "lure", "bear": "charge"}
	for boss_stage in [6, 12, 18]:
		game.spawn_stage(boss_stage)
		game.update_interface()
		expect(game.phase == "boss" and game.stage_index == boss_stage, "正色节点 %d 未进入失律者关卡" % boss_stage)
		expect(game.delivered_title_label.text == "调律" and not game.delivered_label.text.begins_with("调律") and game.detail_label.text.begins_with("调律 · "), "正色节点 %d 错误沿用归巢蜜过关条件或重复调律标签" % boss_stage)
		game.update_progressive_guidance()
		expect(not game.return_button.visible and not game.boss_director.can_tune(), "失律者开场不应直接暴露调律窗口")
		expect(String(game.current_boss_data.move_pattern) == pattern_by_boss[String(game.stages[boss_stage].boss)], "正色节点 %d 失律者移动模式错误" % boss_stage)
		expect(game.tuning_blooms.size() == int(game.current_boss_data.bloom_count), "正色节点 %d 调律共鸣点数量错误" % boss_stage)
		var pattern := String(game.current_boss_data.move_pattern)
		game.boss.position = game.tuning_blooms[0]
		game.bee.position = Vector2(game.boss.position) + Vector2(10, 0)
		match pattern:
			"orbital":
				game.boss.feed_clock = 0.0
				game.update_boss(0.01)
			"erratic":
				game.boss.landing_clock = 0.0
				game.update_boss(0.01)
			"lure":
				game.bee.velocity = Vector2.ZERO
				game.bee.sense_cooldown = 0.0
				game._reveal_boss_truth()
		expect(game.boss_director.can_tune(), "Boss %s 的真实行为没有打开专属破绽窗口" % pattern)
		var speed_before := float(game.boss_director.parameters.speed_multiplier)
		game._attempt_boss_tune()
		expect(int(game.boss.hits) == 1 and game.tuning_blooms.size() == int(game.current_boss_data.bloom_count) - 1, "Boss %s 的破绽窗口没有接入真实调律" % pattern)
		expect(float(game.boss_director.parameters.speed_multiplier) > speed_before, "Boss %s 第一次调律后没有升级参数" % pattern)
	# 熊：只有冲锋期间急转、再撞入暖花，才会暴露。
	game.stage_index = 23
	game.start_boss()
	var warm_bloom: Vector2 = game.tuning_blooms[0]
	game.boss.position = warm_bloom + Vector2(100, 0)
	game.bee.position = warm_bloom + Vector2(220, 0)
	game.boss.charge_state = "dash"
	game.boss.state_time = 1.0
	game.boss.aim_direction = Vector2.RIGHT
	game.boss.velocity = Vector2.RIGHT * 4.2
	game.boss.evade_armed = false
	game.boss.locked_origin = game.boss.position
	game.boss.locked_target = game.bee.position
	game.boss.evade_sequence_at_lock = game.bee.evade_sequence
	game.bee.evade_cooldown = 0.0
	game.bee.energy = 100.0
	expect(game.bee.try_evade(Vector2.UP), "熊冲锋锁定后侧向急转没有触发")
	game.bee.position = Vector2(game.boss.locked_target) + Vector2.UP * 60.0
	game.update_boss(0.1)
	expect(bool(game.boss.evade_armed) and not game.boss_director.can_tune(), "熊锁定后侧向急转没有记录闪避，或未撞暖花就提前暴露")
	game.boss.position = warm_bloom + Vector2(30, 0)
	game.boss.velocity = Vector2.ZERO
	game.update_boss(0.0)
	expect(game.boss_director.can_tune() and String(game.boss_director.state) == "warm_stun", "熊没有把急转与暖花碰撞组合成眩晕窗口")
	game.spawn_stage(0)
	var movement_start: Vector2 = game.bee.position
	var d_key := InputEventKey.new()
	d_key.physical_keycode = KEY_D
	d_key.pressed = true
	expect(InputMap.event_is_action(d_key, "move_right"), "物理 D 键没有映射到向右移动")
	Input.action_press("move_right")
	game.bee._physics_process(0.1)
	Input.action_release("move_right")
	expect(game.bee.position.x > movement_start.x, "WASD 的 D 键动作没有驱动玩家")
	game.last_dir_tap = {"left": 0.0, "right": 0.0, "up": 0.0, "down": 0.0}
	game.bee.energy = 100.0
	game.bee.evade_cooldown = 0.0
	var evade_sequence_before: int = game.bee.evade_sequence
	var actual_evade_origin: Vector2 = game.bee.position
	expect(not game._register_direction_tap("up", Vector2.UP, 10.0), "第一次方向输入就错误触发了急转")
	expect(game.bee.evade_tap_time > 0.0, "第一次方向输入没有给出已记录反馈")
	expect(game._register_direction_tap("up", Vector2.UP, 10.2), "0.34 秒窗口内的同方向第二次输入没有触发急转")
	expect(game.bee.evade_sequence == evade_sequence_before + 1 and game.bee.velocity.normalized().dot(Vector2.UP) > 0.99, "方向登记窗口没有沿所按方向触发一次急转")
	game.bee._physics_process(0.1)
	expect(actual_evade_origin.y - game.bee.position.y >= 36.0, "急转位移没有稳定离开 36px 教学危险带")
	game.bee.evade_cooldown = 0.0
	game.bee.evade_time = 0.0
	game.bee.energy = 100.0
	game._clear_evade_tap_buffers()
	game.last_dir_tap.right = 30.0
	game.last_dir_tap.up = 30.0
	game.last_dir_tap_origin.right = game.bee.position
	game.last_dir_tap_origin.up = game.bee.position
	var chord_sequence_before: int = game.bee.evade_sequence
	var chord_directions: Array[String] = ["right", "up"]
	expect(game._process_evade_pressed_directions(chord_directions, 30.2, Vector2.RIGHT), "同一帧的斜向第二击没有发动急转")
	expect(game.bee.evade_sequence == chord_sequence_before + 1 and game.bee.last_evade_direction.dot(Vector2.UP) > 0.99 and not game.message.contains("尚未恢复"), "斜向同帧输入没有选择远离攻击线的有效轴，或用冷却失败覆盖了成功反馈")
	expect(game.last_dir_tap.values().all(func(value): return float(value) == 0.0), "斜向急转成功后仍遗留另一方向的首击缓存")
	game.bee.evade_cooldown = 0.0
	game.bee.energy = 100.0
	game.bee.evade_time = 0.0
	game.bee.velocity = Vector2.ZERO
	game._clear_evade_tap_buffers()
	var world_tap_sequence_before: int = game.bee.evade_sequence
	var repeated_world_point: Vector2 = game.bee.position + Vector2.UP * 42.0
	var first_click := InputEventMouseButton.new()
	first_click.button_index = MOUSE_BUTTON_LEFT
	first_click.pressed = true
	first_click.position = repeated_world_point
	game._unhandled_input(first_click)
	expect(game.bee.has_target and game.last_world_tap_time > 0.0, "真实鼠标第一次点击没有登记移动与急转首击")
	game.bee._physics_process(0.2)
	expect(game.bee.position.distance_to(repeated_world_point) < 2.0, "鼠标稳定性对照没有让第一次点击真实移动到侧标")
	var second_click := InputEventMouseButton.new()
	second_click.button_index = MOUSE_BUTTON_LEFT
	second_click.pressed = true
	second_click.position = repeated_world_point
	game._unhandled_input(second_click)
	expect(game.bee.evade_sequence == world_tap_sequence_before + 1 and game.bee.velocity.normalized().dot(Vector2.UP) > 0.99, "蜂已移动到侧标后，第二次真实鼠标点击没有沿第一次点击方向触发急转")
	game.bee.evade_cooldown = 0.0
	game.bee.evade_time = 0.0
	game.bee.energy = 100.0
	game.bee.velocity = Vector2.ZERO
	game._clear_evade_tap_buffers()
	var touch_sequence_before: int = game.bee.evade_sequence
	var repeated_touch_point: Vector2 = game.bee.position + Vector2.LEFT * 42.0
	var first_touch := InputEventScreenTouch.new()
	first_touch.pressed = true
	first_touch.position = repeated_touch_point
	game._unhandled_input(first_touch)
	expect(game.bee.evade_sequence == touch_sequence_before and game.last_world_tap_time > 0.0, "一次真实触摸被误算成完整双击急转")
	game.bee._physics_process(0.2)
	var second_touch := InputEventScreenTouch.new()
	second_touch.pressed = true
	second_touch.position = repeated_touch_point
	game._unhandled_input(second_touch)
	expect(game.bee.evade_sequence == touch_sequence_before + 1 and game.bee.velocity.normalized().dot(Vector2.LEFT) > 0.99, "第二次真实触摸没有沿首触方向发动急转")
	game.bee.energy = 100.0
	game.bee.evade_cooldown = 0.0
	game.bee.velocity = Vector2.RIGHT
	expect(game.bee.try_evade(Vector2.UP) and game.bee.velocity.normalized().dot(Vector2.UP) > 0.99 and game.bee.invulnerable_time > 0.0 and game.bee.energy == 88.0, "急转没有沿输入方向产生位移防护与体力消耗")
	game.delivered = 3
	var conserved_before: int = game.total_recoverable_honey()
	game.flowers[0].nectar = int(game.flowers[0].nectar) - 2
	game.carried = 2
	game.fail_expedition()
	expect(game.total_recoverable_honey() == conserved_before, "体力耗尽后花蜜没有回到生态循环")
	expect(game.delivered == 1, "力竭应按 exhaustion_delivered_penalty 回退已入库进度（3-2=1），且守恒不破")
	game.delivered = 0
	# 显式饮蜜：E 键主动饮下蜜囊里的一滴蜜续力，每节气受 crop_fuel_limit 限制；
	# 被饮下的蜜不生成返蜜花，它转化成了飞行本身
	game.carried = 2
	game.bee.energy = 0.0
	var drunk_before: int = game.total_recoverable_honey()
	expect(game._drink_honey() and game.carried == 1 and game.bee.energy > 0.0, "饮蜜未消耗携带蜜或未恢复体力")
	expect(game.total_recoverable_honey() == drunk_before - 1, "饮蜜应恰好消耗 1 滴可回收蜜（转化为飞行）")
	expect(game.crop_fuel_used == 1, "续力计数未随饮蜜递增")
	# 续力次数封顶：同一节气内限饮 2 口，用尽后即使有蜜也不再续力
	game.carried = 3
	game.bee.energy = 0.0
	expect(game._drink_honey() and game.carried == 2 and game.crop_fuel_used == 2, "上限内第二口续力应正常")
	expect(not game._drink_honey() and game.carried == 2, "续力次数用尽后不应再消耗携带蜜")
	game.carried = 0
	game.bee.energy = 0.0
	expect(not game._drink_honey(), "蜜尽后不应再续力")
	# 饮蜜回力是加法并钳到体力上限：旧实现「设为 refill」只在体力见底时碰巧等价，
	# 但显式饮蜜可在任意体力值触发——高体力时只回零头甚至倒扣
	var refill_amount: float = game.balance_value("player", "crop_fuel_refill", 22.0)
	game.crop_fuel_used = 0
	game.carried = 2
	game.bee.energy = 10.0
	expect(game._drink_honey() and is_equal_approx(game.bee.energy, 10.0 + refill_amount), "饮蜜应按增量恢复体力而非设为定值")
	game.bee.energy = 95.0
	expect(game._drink_honey() and game.bee.energy == 100.0 and game.carried == 0, "高体力饮蜜应钳到体力上限而非倒扣")
	# 体力上限数据驱动：基准来自 balance.json player.max_energy（_ready 注入），
	# 越冬幼虫加成通过 energy_cap_override 抬高实际上限，饮蜜钳制跟随两者较大值
	expect(game.bee.max_energy == game.balance_value("player", "max_energy", 100.0), "体力上限未从 balance.json 注入")
	game.crop_fuel_used = 0
	game.carried = 1
	game.energy_cap_override = 130.0
	game.bee.energy = 125.0
	expect(game._drink_honey() and game.bee.energy == 130.0, "饮蜜应钳到实际体力上限（含冬季加成）")
	# 还原力竭用例的前置条件：蜜尽 + 体力归零
	game.energy_cap_override = 100.0
	game.bee.energy = 0.0
	# 力竭停顿拍：蜜尽才真正倒下，世界静止、体力归零可见，随后回巢重置
	game.begin_exhaustion()
	expect(game.phase == "exhausted" and not game.bee.active and game.bee.energy == 0.0, "力竭未进入停顿拍（世界应静止且体力为 0）")
	game.resolve_exhaustion()
	expect(game.phase == "playing" and game.bee.active and game.bee.energy > 0.0, "力竭停顿后未回巢重置")
	expect(game.bee.energy < 100.0, "力竭归巢不应满体力（蜂群照料需要时间）")
	# 终局失败：最后一命力竭直接进失败页，体力条应停在 0 而不是先被重置为满
	game.hive_lives = 1
	game.carried = 0
	game.bee.energy = 0.0
	game.begin_exhaustion()
	game.resolve_exhaustion()
	expect(game.phase == "lost" and game.bee.energy == 0.0, "终局失败页体力条未停在 0（回巢重置先于判负）")
	# 恢复现场，不干扰后续用例
	game.phase = "playing"
	game.bee.active = true
	game.hive_lives = 3
	game.bee.energy = 60.0
	game.carried = 1
	var before_decoy: int = game.total_recoverable_honey()
	game.drop_honey_decoy()
	expect(game.decoys.size() == 1 and game.total_recoverable_honey() == before_decoy, "L 诱饵没有生效或破坏了花蜜守恒")
	game.bee.position = Vector2(100, 410)
	game.bee.energy = 50.0
	game.carried = 0
	game.update_hive_rest(1.0, true)
	expect(game.bee.energy > 50.0 and game.delivered == 0, "空手归巢没有恢复体力")
	# 入巢卸蜜延迟：落巢后需站稳 hive_deposit_delay 才入库，期间离开则计时清零
	game.carried = 2
	game.bee.position = Vector2(300, 410)
	game.update_hive_rest(0.05, true)
	game.bee.position = Vector2(100, 410)
	game.update_hive_rest(0.2, true)
	expect(game.delivered == 0 and game.carried == 2, "入巢未满延迟不应提前卸蜜")
	game.update_hive_rest(0.3, true)
	expect(game.delivered == 2 and game.carried == 0, "站稳 hive_deposit_delay 后应完成卸蜜")
	# 离巢再回：计时清零，需重新站稳
	game.carried = 1
	game.bee.position = Vector2(300, 410)
	game.update_hive_rest(0.3, true)
	game.bee.position = Vector2(100, 410)
	game.update_hive_rest(0.3, true)
	expect(game.delivered == 2 and game.carried == 1, "离开蜂巢应清零卸蜜计时，回来未满延迟不应卸蜜")
	game.update_hive_rest(0.2, true)
	expect(game.delivered == 3 and game.carried == 0, "回巢重新站稳后应完成卸蜜")
	# 蜜香招敌：携带蜜扩大蚊虫嗅觉半径——330px 外、感官加成内的蚊应转向追击
	game.decoys.clear()
	game.carried = 8
	game.bee.position = Vector2(280, 410)
	game.mosquitoes = [{"id": 0, "position": Vector2(620, 410), "velocity": Vector2.ZERO, "repel_time": 0.0}]
	game.update_mosquitoes(0.1)
	expect(Vector2(game.mosquitoes[0].velocity).length() > 0.5, "满载蜜香未把嗅觉外的蚊虫引来")
	game.carried = 0
	game.mosquitoes = [{"id": 0, "position": Vector2(620, 410), "velocity": Vector2.ZERO, "repel_time": 0.0}]
	game.update_mosquitoes(0.1)
	expect(Vector2(game.mosquitoes[0].velocity).length() < 0.5, "空载时 330px 外的蚊虫不应被吸引")
	game.carried = 0
	game.mosquitoes = [{"id": 0, "position": Vector2(210, 410), "velocity": Vector2(-2, 0), "repel_time": 0.0}]
	game.update_mosquitoes(0.2)
	expect(float(game.mosquitoes[0].position.x) >= game.HIVE_SAFE_X, "蚊虫越过蜂巢安全边界")
	game.bee.position = Vector2(280, 410)
	game.mosquitoes = [{"id": 0, "position": Vector2(320, 410), "velocity": Vector2.ZERO, "repel_time": 1.0}]
	game.update_mosquitoes(0.2)
	expect(float(game.mosquitoes[0].position.x) > 320.0, "惊退状态没有让蚊虫实际远离玩家")
	game.bee.sense_time = 3.0
	expect(game.best_foraging_target() >= 0, "触角寻迹没有给出采集建议")

	# 全流程推进：21 个采蜜关穿插 3 个正色失律者关卡，终点回到冬至的熊
	var boss_terms := ["春分", "夏至", "秋分", "冬至"]
	var boss_encounters := 0
	for index in 24:
		if game.stages[index].has("boss"):
			continue
		game.spawn_stage(index)
		game.delivered = int(game.stages[index].goal)
		game.show_between()
		expect(game.phase == "between", "节令 %d 未进入蜂巢成长" % index)
		var reserve_m = game.season_mechanics.mechanic_by_id("reserve")
		if reserve_m != null and reserve_m.pending_allocation:
			expect(game.allocation_pending, "白露未进入分配界面")
			game.allocation_fraction = 0.5
			game.confirm_allocation()
			expect(not game.allocation_pending, "白露分配后界面未关闭")
		# 测试直接推进：重置成长计数，保证所有选择都有效
		game.upgrade_counts = {"long_wing": 0, "forager": 0, "guard": 0}
		game.on_upgrade_selected(0)
		var next_index := index + 1
		if next_index < game.stages.size() and game.stages[next_index].has("boss"):
			expect(game.phase == "boss" and game.stage_index == next_index, "节令 %d 后未进入正色失律者关卡" % index)
			expect(String(game.current_boss_data.term) == boss_terms[boss_encounters], "第 %d 位失律者节点错误" % boss_encounters)
			boss_encounters += 1
			game.show_boss_victory()
			expect(game.phase == "boss_victory", "失律者归律后未进入休整界面")
			game.on_overlay_button()
			expect(game.phase == "playing" and game.stage_index == next_index + 1, "失律者归律后无法进入下一季")
		elif next_index < game.stages.size():
			expect(game.phase == "playing" and game.stage_index == next_index, "节令 %d 无法推进" % index)
		else:
			expect(game.phase == "boss", "大雪后未回到冬至遭遇失律之熊")
			expect(String(game.current_boss_data.term) == "冬至" and String(game.current_boss_data.move_pattern) == "charge", "循环终点的失律者应为熊（冬至）")
			boss_encounters += 1
			game.show_boss_victory()
			expect(game.phase == "boss_victory", "熊归律后未进入休整界面")
			game.on_overlay_button()
			expect(game.phase == "won", "熊归律后未通关")

	expect(boss_encounters == 4, "四位失律者遭遇没有全部发生")
	expect(game.chosen_upgrades.size() == gathering_total, "蜂巢成长次数与采蜜关数量不一致")
	expect(game.hive_reserve > 0, "公共储备没有在四季间积累")
	# 成长满级后的防死锁回退：全部分工达上限时直接给出继续按钮
	game.spawn_stage(5)
	game.delivered = int(game.stages[5].goal)
	game.upgrade_counts = {"long_wing": 99, "forager": 99, "guard": 99}
	game.show_between()
	expect(game.phase == "between" and game.overlay_button.visible, "成长满级后没有回退到继续按钮")
	game.on_overlay_button()
	expect(game.phase == "boss", "满级回退后季末未进入失律者遭遇")
	# 冬季热源接力（寒露入冬，冷区减速；携蜜可点亮沿路暖点）
	game.spawn_stage(19)
	expect(game.warmth == 100.0, "入冬出巢温暖未初始化")
	game.bee.position = Vector2(500, 410)
	game.season_mechanics.process(1.0)
	expect(game.warmth < 100.0 and game.bee.environment_speed_multiplier < 1.0, "冬季冷区没有同时消耗温暖并降低速度")
	var huddle = game.season_mechanics.mechanic_by_id("huddle")
	expect(huddle != null and not huddle.warm_points.is_empty(), "冬季缺少沿路暖点")
	if huddle != null and not huddle.warm_points.is_empty():
		game.carried = 2
		game.bee.position = Vector2(huddle.warm_points[0].position)
		game.season_mechanics.on_context_action()
		expect(bool(huddle.warm_points[0].active) and game.carried == 1, "携蜜没有点亮冬季暖点")
		game.warmth = 50.0
		var cold_warmth: float = game.warmth
		game.season_mechanics.process(1.0)
		expect(game.warmth > cold_warmth and game.bee.environment_speed_multiplier == 1.0, "点亮的暖区没有恢复温暖和正常速度")

	game.spawn_stage(0)
	game.toggle_pause()
	expect(game.phase == "paused" and not game.bee.active, "暂停未冻结玩家")
	var provenance_file := FileAccess.open("res://data/build_provenance.json", FileAccess.READ)
	expect(provenance_file != null, "测试/构建链路未注入构建来源")
	if provenance_file != null:
		var provenance = JSON.parse_string(provenance_file.get_as_text())
		expect(provenance is Dictionary, "构建来源不是有效 JSON 对象")
		if provenance is Dictionary:
			var dirty_suffix := "+dirty" if bool(provenance.get("dirty", false)) else ""
			var expected_provenance := "v%s · %s%s" % [String(provenance.get("product_version", "")), String(provenance.get("commit", "")).left(8), dirty_suffix]
			expect(game.build_provenance_label.text == expected_provenance, "暂停层构建来源错误：%s" % game.build_provenance_label.text)
			expect(typeof(provenance.get("dirty", null)) == TYPE_BOOL, "构建来源缺少 dirty worktree 状态")
			expect(not provenance.has("branch"), "构建来源不应注入可能误导的分支名")
	expect(game.build_provenance_label.is_visible_in_tree(), "暂停层没有显示构建来源")
	game.toggle_pause()
	expect(game.phase == "playing" and game.bee.active, "继续未恢复玩家")

	# 四季机制因果探针
	# 春·开放花授粉：采花药携散粉，同可见花型柱头才会结籽
	game.spawn_stage(0)
	var pollinator = game.season_mechanics.mechanic_by_id("pollination")
	expect(pollinator != null, "春季花粉连接机制缺失")
	if pollinator != null:
		expect(not pollinator.donor_indices.is_empty() and not pollinator.receptive_indices.is_empty(), "春季没有同时生成开放花药与柱头")
		if not pollinator.donor_indices.is_empty() and not pollinator.receptive_indices.is_empty():
			var receptive_index: int = pollinator.receptive_indices[0]
			var required: int = int(game.flowers[receptive_index].stigma_variant)
			var donor_index := -1
			for candidate in pollinator.donor_indices:
				if int(game.flowers[candidate].pollen_variant) == required:
					donor_index = candidate
					break
			expect(donor_index >= 0, "柱头没有同可见花型的花粉源")
			if donor_index >= 0:
				game.season_mechanics.on_harvest(donor_index)
				expect(pollinator.has_pollen_variant(required) and game.bee.pollen_loads[required] == 1, "采花药后蜂身没有携带对应形色散粉")
				var nectar_before_pollination := int(game.flowers[receptive_index].nectar)
				game.bee.position = Vector2(game.flowers[receptive_index].position)
				game.season_mechanics.on_context_action()
				expect(bool(game.flowers[receptive_index].pollination_pending) and not bool(game.flowers[receptive_index].seed_setting), "同花型散粉没有先进入可见飞行/pending，或过早结籽")
				pollinator.process(0.47)
				expect(bool(game.flowers[receptive_index].pollinated) and bool(game.flowers[receptive_index].seed_setting), "同花型散粉落地后没有使柱头花结籽")
				expect(int(game.flowers[receptive_index].nectar) == nectar_before_pollination, "授粉不应产生或回填花蜜")

	# 夏·实体袭扰：首次卸蜜触发，袭扰者移动并取走真实花蜜，惊退后归还
	game.spawn_stage(7)
	var conscription = game.season_mechanics.mechanic_by_id("conscription")
	expect(conscription != null, "夏季实体袭扰机制缺失")
	if conscription != null:
		game.season_mechanics.on_home(3, 0.2)
		expect(conscription.state == "active" and not conscription.raid_ants.is_empty(), "首次真实卸蜜没有触发袭扰者")
		if not conscription.raid_ants.is_empty():
			var target_index: int = int(conscription.raid_ants[0].target)
			var raider: Dictionary = conscription.raid_ants[0]
			raider["position"] = Vector2(game.flowers[target_index].position)
			raider["steal_clock"] = 0.0
			conscription.raid_ants[0] = raider
			var nectar_before_raid: int = int(game.flowers[target_index].nectar)
			game.season_mechanics.process(0.1)
			expect(int(game.flowers[target_index].nectar) == nectar_before_raid - 1, "袭扰者没有取走真实花蜜")
			game.bee.position = Vector2(conscription.raid_ants[0].position)
			game.season_mechanics.on_context_action()
			expect(String(conscription.raid_ants[0].state) == "escape" and int(game.flowers[target_index].nectar) == nectar_before_raid, "惊退没有截断袭扰并归还被夺花蜜")

	# 秋·留种：停在最后一滴并归巢产生储备；继续采尽则失去收益
	game.spawn_stage(13)
	var reserve_mechanic = game.season_mechanics.mechanic_by_id("reserve")
	expect(reserve_mechanic != null, "秋季留种机制缺失")
	if reserve_mechanic != null:
		var seed_flower: Dictionary = game.flowers[0]
		seed_flower["nectar"] = 1
		game.flowers[0] = seed_flower
		game.season_mechanics.on_harvest(0)
		expect(bool(game.flowers[0].seed_ready), "花剩最后一滴时没有形成可留种状态")
		var seed_reserve_before: int = game.hive_reserve
		game.season_mechanics.on_home(2, 0.1)
		expect(bool(game.flowers[0].seeded) and game.hive_reserve > seed_reserve_before, "停手归巢没有让种核成熟")
		var stripped: Dictionary = game.flowers[1]
		stripped["nectar"] = 1
		game.flowers[1] = stripped
		game.season_mechanics.on_harvest(1)
		stripped = game.flowers[1]
		stripped["nectar"] = 0
		game.flowers[1] = stripped
		game.season_mechanics.on_harvest(1)
		var reserve_after_stripping: int = game.hive_reserve
		game.season_mechanics.on_home(2, 0.1)
		expect(bool(game.flowers[1].seed_lost) and game.hive_reserve == reserve_after_stripping, "采尽最后一滴后仍错误获得留种收益")

	# 敌物候学单元探针
	# 惊蛰·掠蜜蚁：沿信息素轨迹（巢口→花田）往返巡逻
	game.spawn_stage(5)
	expect(game.ants.size() == int(game.stages[5].ants), "惊蛰蚁数量与配置不符")
	if not game.ants.is_empty():
		var scout: Dictionary = game.ants[0]
		var scout_trail: Array = scout.get("trail", [])
		expect(scout_trail.size() >= 2, "掠蜜蚁缺少信息素轨迹")
		if scout_trail.size() >= 2:
			expect(Vector2(scout_trail[0]).x > Vector2(scout_trail[scout_trail.size() - 1]).x, "蚁迹应从巢口（右缘）出发")
			game.bee.position = Vector2(150, 300)
			scout["trail_index"] = 1
			scout["position"] = Vector2(scout_trail[1]) + Vector2(60, 0)
			game.ants[0] = scout
			game.update_ants(0.5)
			expect(Vector2(game.ants[0].position).distance_to(Vector2(scout_trail[1])) < 60.0, "蚁没有沿轨迹向路点移动")
	# 小雪·深冬：花田无虫，寒冷与匮乏本身即敌人
	game.spawn_stage(22)
	expect(game.mosquitoes.is_empty() and game.ants.is_empty() and game.crickets.is_empty() and game.thrushes.is_empty() and game.bears.is_empty(), "深冬关不应生成任何敌害")
	# 小满·油葫芦：蓄力结束起跳并留下残影
	game.spawn_stage(10)
	expect(game.crickets.size() == int(game.stages[10].crickets), "小满油葫芦数量与配置不符")
	if not game.crickets.is_empty():
		var hopper: Dictionary = game.crickets[0]
		hopper["hop_clock"] = 0.01
		game.crickets[0] = hopper
		game.update_crickets(0.05)
		expect(bool(game.crickets[0].hopping), "油葫芦蓄力结束后未起跳")
		expect(game.field_afterimages.size() >= 1, "油葫芦起跳没有留下残影")
	# 清明·画眉：鸣唱催生幻花，近身识破
	game.spawn_stage(7)
	expect(game.thrushes.size() == int(game.stages[7].thrushes), "清明画眉数量与配置不符")
	if not game.thrushes.is_empty():
		var songbird: Dictionary = game.thrushes[0]
		songbird["song_clock"] = 0.01
		game.thrushes[0] = songbird
		game.bee.position = Vector2(200, 200)
		game.update_thrushes(0.05)
		expect(game.phantom_flowers.size() == 1, "画眉鸣唱未催生幻花")
		if not game.phantom_flowers.is_empty():
			var pollen_before_reveal: int = game.pollen.size()
			game.bee.position = Vector2(game.phantom_flowers[0].position)
			game.update_thrushes(0.05)
			expect(game.phantom_flowers.is_empty(), "靠近幻花没有被识破")
			expect(game.pollen.size() > pollen_before_reveal, "识破幻花没有散落标记")
	# 立秋·熊：碾压花田，抵达巢区直食储备
	game.spawn_stage(15)
	expect(game.bears.size() == int(game.stages[15].bears), "立秋熊数量与配置不符")
	if not game.bears.is_empty():
		game.bee.position = Vector2(150, 300)
		var bruin: Dictionary = game.bears[0]
		bruin["position"] = Vector2(game.flowers[0].position)
		game.bears[0] = bruin
		game.update_bears(0.05)
		expect(float(game.flowers[0].get("flatten_time", 0.0)) > 0.0, "熊没有压平沿途花朵")
		bruin = game.bears[0]
		bruin["position"] = Vector2(game.HIVE_SAFE_X, 410.0)
		bruin["eat_clock"] = 0.01
		game.bears[0] = bruin
		var reserve_before_bear: int = game.hive_reserve
		game.update_bears(0.05)
		expect(game.hive_reserve == reserve_before_bear - 1 and int(game.bears[0].eaten) == 1, "熊抵巢后没有吃掉储备蜜")

	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("FLOW TEST PASSED: title-to-boss state path is reachable")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
