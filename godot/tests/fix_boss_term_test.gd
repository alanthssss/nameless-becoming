# 验证：Boss 上下文延续、普通转场不重复节令名、相位护栏
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

	# --- 场景 1：普通关通关 → 只预告失律者，不重复灌输节令名 ---
	game.spawn_stage(5)
	await process_frame
	game.show_between()
	await process_frame
	expect(game.phase == "between", "惊蛰通关后未进入 between")
	expect("失律之蚊" in game.overlay_body.text and not "春分" in game.overlay_body.text,
		"转场应以失律者预告替代节令解释：%s" % game.overlay_body.text)

	# --- 场景 2：春分 boss 通关 → boss_victory 期间顶栏/侧栏保持失律者上下文 ---
	game.spawn_stage(6)
	await process_frame
	expect(game.phase == "boss", "春分节点未进入 boss 相位")
	expect(game.season_mechanics.active.is_empty(), "普通节点机制残留到春分 Boss")
	game.boss.hits = 3
	game.show_boss_victory()
	await process_frame
	expect(game.phase == "boss_victory", "调律完成后未进入 boss_victory")
	expect(game.term_label.text.is_empty(), "行动 HUD 不应重复显示节令名：%s" % game.term_label.text)
	expect(game.season_label.text == "失律之蚊", "boss_victory 侧栏未保持失律者名称：%s" % game.season_label.text)
	expect(game.delivered_title_label.text == "调律" and game.delivered_label.text == "3 / 3", "boss_victory 调律计数错误：%s %s" % [game.delivered_title_label.text, game.delivered_label.text])

	# --- 场景 3：boss_victory 点继续 → 进入清明（普通关） ---
	game.on_overlay_button()
	await process_frame
	expect(game.phase == "playing" and game.stage_index == 7, "boss_victory 后未进入清明")

	# --- 场景 4：相位护栏：playing 状态下点穿 overlay_button 不重置游戏 ---
	var stage_before: int = game.stage_index
	game.on_overlay_button()
	await process_frame
	expect(game.phase == "playing" and game.stage_index == stage_before, "playing 相位点穿按钮错误推进关卡")

	# --- 场景 5：真实通知路由只会进入暂停，绝不能在后台反向解暂停 ---
	game.toggle_pause()
	expect(game.phase == "paused" and game.paused_from_phase == "playing", "手动暂停没有记录 playing 来源")
	game.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	expect(game.phase == "paused" and not game.bee.active, "手动 paused 状态切出后被反向解暂停")
	game.notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	expect(game.phase == "paused" and root.gui_get_focus_owner() == game.overlay_button, "切回应用后没有保持暂停或恢复暂停页焦点")
	game.toggle_pause()
	expect(game.phase == "playing" and game.bee.active, "手动暂停后无法正常恢复 playing")

	game.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	expect(game.phase == "paused" and game.paused_from_phase == "playing" and not game.bee.active, "playing 切出后没有记录来源并进入暂停")
	game.notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	expect(game.phase == "paused", "playing 自动暂停后切回应用时错误恢复了运行")
	game.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	expect(game.phase == "paused" and game.paused_from_phase == "playing", "自动 paused 状态再次切出后被反向解暂停")
	game.toggle_pause()

	game.spawn_stage(6)
	await process_frame
	game.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	expect(game.phase == "paused" and game.paused_from_phase == "boss" and not game.bee.active, "boss 切出后没有记录来源并进入暂停")
	game.notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	expect(game.phase == "paused", "boss 自动暂停后切回应用时错误恢复了战斗")
	game.toggle_pause()
	game.show_boss_victory()
	game.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	expect(game.phase == "boss_victory", "boss_victory 下 focus out 被误暂停")

	# --- 场景 6：Boss 可重试失败页仍使用调律 HUD，不能读取无 goal 的节点 ---
	game.spawn_stage(6)
	await process_frame
	game.boss.hits = 1
	game.hive_lives = 2
	game.show_boss_loss()
	game.update_interface()
	expect(game.phase == "boss_loss" and game._uses_boss_interface_context(), "boss_loss 丢失 Boss HUD 上下文")
	expect(game.delivered_title_label.text == "调律" and game.delivered_label.text == "1 / 3",
		"boss_loss 调律进度错误：%s %s" % [game.delivered_title_label.text, game.delivered_label.text])
	expect(game.season_label.text == "失律之蚊", "boss_loss 侧栏未保持失律者名称：%s" % game.season_label.text)
	expect(game.production_hud.phase_label.text == "调律中", "boss_loss 产品 HUD 相位错误：%s" % game.production_hud.phase_label.text)

	# --- 场景 7：重试回到同一 Boss；Boss 中暂停也保持调律上下文 ---
	game.on_overlay_button()
	await process_frame
	expect(game.phase == "boss" and game.stage_index == 6 and game.hive_lives == 2,
		"boss_loss 重试未回到同一 Boss 或错误重置蜂巢机会")
	game.toggle_pause()
	game.update_interface()
	expect(game.phase == "paused" and game.paused_from_phase == "boss", "Boss 中暂停没有记录来源")
	expect(game._uses_boss_interface_context() and game.delivered_title_label.text == "调律",
		"Boss 暂停页丢失调律 HUD 上下文")
	expect(game.current_flower_set() == "spring", "春分 Boss 暂停时世界主题错误切季：%s" % game.current_flower_set())
	game.toggle_pause()

	# --- 场景 8：显式 Boss 最后一命进入整轮失败，仍不得读取 data.goal ---
	game.hive_lives = 0
	game.show_loss()
	game.update_interface()
	expect(game.phase == "lost" and game.lost_from_phase == "boss", "Boss 整轮失败没有记录来源")
	expect(game._uses_boss_interface_context() and game.delivered_title_label.text == "调律",
		"Boss 整轮失败页丢失调律 HUD 上下文")
	expect(game.current_flower_set() == "spring", "春分 Boss 整轮失败时世界主题错误切季：%s" % game.current_flower_set())

	# --- 场景 9：终点熊战复用普通大雪节点，不能靠 is_boss_stage 推断 ---
	game.spawn_stage(game.stages.size() - 1)
	await process_frame
	game.start_boss()
	await process_frame
	expect(game.phase == "boss" and String(game.current_boss_data.name) == "失律之熊",
		"循环终点未进入失律之熊")
	expect(game.season_mechanics.active.is_empty(), "大雪暖点机制残留到终点熊战")
	game.boss.hits = 1
	game.hive_lives = 2
	game.show_boss_loss()
	game.update_interface()
	game.on_overlay_button()
	await process_frame
	expect(game.phase == "boss" and game.stage_index == game.stages.size() - 1,
		"终点熊战可重试失败后错误返回大雪采集关")
	expect(String(game.current_boss_data.name) == "失律之熊" and game.hive_lives == 2,
		"终点熊战重试没有保持失律者或蜂巢机会")
	game.hive_lives = 0
	game.show_loss()
	game.update_interface()
	expect(game.phase == "lost" and game._uses_boss_interface_context(), "终点熊战失败丢失 Boss HUD 上下文")
	expect(game.season_label.text == "失律之熊" and game.delivered_title_label.text == "调律",
		"终点熊战失败页上下文错误：%s %s" % [game.season_label.text, game.delivered_title_label.text])

	# --- 场景 10：普通关失败即使残留 Boss 数据，也必须回到普通目标 HUD ---
	game.spawn_stage(7)
	await process_frame
	game.hive_lives = 1
	game.phase = "exhausted"
	game.fail_expedition()
	game.update_interface()
	expect(game.phase == "lost" and game.lost_from_phase == "exhausted", "普通关失败来源记录错误")
	expect(not game._uses_boss_interface_context(), "普通关失败被残留 Boss 数据误判为调律上下文")
	expect(game.delivered_title_label.text == "归巢蜜" and game.season_label.text == "过关条件",
		"普通关失败未恢复普通目标 HUD：%s %s" % [game.delivered_title_label.text, game.season_label.text])

	if failures.is_empty():
		print("FIX TEST PASSED: boss 胜败/暂停上下文 / 无节令复读 / 相位护栏 / focus 自动暂停 全部通过")
	else:
		for failure in failures:
			printerr("FAIL: " + failure)
		print("FIX TEST FAILED: %d 项未通过" % failures.size())
	quit(1 if not failures.is_empty() else 0)
