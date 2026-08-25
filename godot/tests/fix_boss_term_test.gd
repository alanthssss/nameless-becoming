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

	# --- 场景 5：focus out 自动暂停 / focus in 不误伤静态界面 ---
	game.phase = "playing"
	game._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	expect(game.phase == "paused", "切走程序未自动暂停：%s" % game.phase)
	game.phase = "boss_victory"
	game._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	expect(game.phase == "boss_victory", "boss_victory 下 focus out 被误暂停：%s" % game.phase)

	if failures.is_empty():
		print("FIX TEST PASSED: boss 上下文延续 / 无节令复读 / 相位护栏 / focus 自动暂停 全部通过")
	else:
		for failure in failures:
			printerr("FAIL: " + failure)
		print("FIX TEST FAILED: %d 项未通过" % failures.size())
	quit(1 if not failures.is_empty() else 0)
