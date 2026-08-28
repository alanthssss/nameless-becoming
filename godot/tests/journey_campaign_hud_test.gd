extends SceneTree

const CampaignScene := preload("res://campaign.tscn")

var failures: Array[String] = []


class TutorialPersistence:
	extends CommercialPersistenceService

	var writes: Array[Dictionary] = []


	func set_setting(key: String, value: Variant) -> Error:
		writes.append({"key": key, "value": value})
		return OK


func _init() -> void:
	call_deferred("run_test")


func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func controls_overlap(first: Control, second: Control) -> bool:
	return first.visible and second.visible and first.get_global_rect().intersects(second.get_global_rect())


func run_test() -> void:
	var game = CampaignScene.instantiate()
	root.add_child(game)
	await process_frame
	game.full_transition_duration = 0.0
	game.transition_duration = 0.0
	game._set_field_hud_visible(true)
	for level_button in game.level_buttons.values():
		expect(
			String((level_button as Button).tooltip_text).is_empty(),
			"主巢关卡悬停长文会浮在其他节气按钮上"
		)

	var long_message := (
		"风从高坡下来，先绕到叶棚背面，再沿着发亮的花标稳稳飞过去；"
		+ "这是一条故意超过两行的状态消息，用来验证提示不会重新长成常驻说明栏。"
	)
	game._on_field_status({
		"level_number": 18,
		"term_name": "霜降",
		"area": "画眉邻居的回声坡",
		"energy": 72.0,
		"energy_cap": 120.0,
		"has_collection": true,
		"honey_cargo": 2,
		"capacity": 4,
		"time_remaining": 414.0,
		"objective_lines": ["听风辨声  3 / 3", "送轻种过霜线  1 / 4"],
		"objective_counts": [3, 1],
		"objective_goals": [3, 4],
		"ready_to_return": false,
		"message": long_message,
		"hazard_active": true,
		"action_label": "停翅听清最近的回声",
		"action_enabled": true,
		"return_label": "指路回巢",
	})

	expect(game.field_panel.size == game.FIELD_OBJECTIVE_SIZE, "正式 Campaign 仍使用旧式纵向目标栏")
	expect(
		game.transition_layer != null and game.transition_layer.layer > 40,
		"转场遮罩层级低于结果插画，高潮画面会抢在转场前闪现"
	)
	expect(game.field_panel.position.x < 100.0 and game.field_panel.size.y <= 130.0, "当前目标没有保持为左上紧凑卡")
	var right_play_lane := Rect2(1000, 104, 262, 500)
	expect(not game.field_panel.get_global_rect().intersects(right_play_lane), "紧凑目标卡仍遮住右侧主要玩法区")
	expect(
		game.field_panel.mouse_filter == Control.MOUSE_FILTER_IGNORE
			and game.field_heading_label.mouse_filter == Control.MOUSE_FILTER_IGNORE
			and game.objective_label.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"目标纸片的空白或文字仍会吞掉场景点击"
	)
	expect(
		game.objective_toggle_button.mouse_filter == Control.MOUSE_FILTER_STOP
			and game.objective_toggle_button.get_parent() == game.ui_layer,
		"目标纸片点击穿透时误伤了唯一开关，或开关仍被挂在穿透装饰下面"
	)
	expect(
		is_equal_approx(game.FIELD_PLAY_SAFE_RIGHT, JourneyCampaignField.CAMPAIGN_HUD_SAFE_RECT.end.x)
			and game.action_panel.position.x >= game.FIELD_PLAY_SAFE_RIGHT
			and game.action_panel.get_global_rect().end.x <= 1280.0,
		"动作托盘没有完整离开 field 的 x<=1008 玩法安全区"
	)
	expect(
		game.action_button.get_global_rect().end.x <= game.action_panel.get_global_rect().end.x
			and game.return_button.get_global_rect().end.y <= game.action_panel.get_global_rect().end.y,
		"纵向动作按钮越出了右侧托盘"
	)
	expect(game.objective_label.max_lines_visible == 3, "当前目标卡没有预留标题、操作与进度三行")
	expect(
		game.objective_label.text == "送轻种过霜线 1 / 4",
		"目标卡没有跳过已完成事项并只显示当前动作：%s" % game.objective_label.text
	)
	expect(game.message_label.max_lines_visible == 2 and game.toast_panel.visible, "现场消息没有使用双行按需 toast")
	expect(game.toast_time == game.FIELD_TOAST_SECONDS, "新消息没有取得有限显示时长")
	expect(game.cargo_label.text == "蜜囊 2 / 4" and not "蜜囊" in game.objective_label.text, "蜜囊没有从目标说明中独立出来")
	expect(game.energy_label.text == "体力 72 / 120", "体力没有作为独立资源显示")
	expect(
		"空格/A 停翅听清最近的回声" in game.controls_label.text
			and "Q/Y 指路回巢" in game.controls_label.text,
		"底部操作说明没有跟随当前两个情境动作：%s" % game.controls_label.text
	)

	# A lesson is durable only after the production toast is visible and every
	# wrapped line fits. Exercise the exact product text at normal and maximum UI
	# scale, and verify the HUD->settings acknowledgement bridge writes once.
	var actual_persistence: CommercialPersistenceService = game.persistence
	var original_tutorial_version: int = game.energy_tutorial_version_seen
	var tutorial_persistence := TutorialPersistence.new()
	game.persistence = tutorial_persistence
	var tutorial_text := JourneyCampaignField.CAMPAIGN_ENERGY_TUTORIAL_TEXT
	var tutorial_snapshot := {
		"level_number": 2,
		"term_name": "雨水",
		"area": "雨后花路",
		"energy": 94.0,
		"energy_cap": 100.0,
		"energy_state": "急转 -6",
		"time_remaining": 480.0,
		"ready_to_return": false,
		"message": tutorial_text,
		"action_label": "穿过雨线",
		"action_enabled": true,
		"return_label": "指路回巢",
		"event_runtime": {
			"current_event_number": 2,
			"event_count": 15,
			"current_event_title": "穿过滴水线",
			"ui_hint": "看清亮缝再急转",
			"optional": false,
		},
		"player_instruction": "飞进黄色圆圈，连续按两次同一个方向",
		"progress_label": "已通过 1/3",
		"energy_tutorial_delivery_version": 1,
		"energy_tutorial_delivery_text": tutorial_text,
	}
	for ui_scale in [1.0, 1.3]:
		tutorial_persistence.writes.clear()
		game.energy_tutorial_version_seen = 0
		game._apply_settings({
			"ui_scale": ui_scale,
			"reduce_motion": false,
			"show_control_hints": true,
		})
		game._on_field_status(tutorial_snapshot)
		await process_frame
		# If font shaping was not ready during the first status, the next normal
		# field tick retries acknowledgement without producing a duplicate write.
		game._on_field_status(tutorial_snapshot)
		expect(
			game.toast_panel.visible
			and game.message_label.text == tutorial_text
			and game.message_label.get_line_count() > 0
			and game.message_label.get_line_count()
				<= game.message_label.max_lines_visible,
			"%d%% 字体下体力教学没有完整装进双行现场提示：lines=%d"
			% [roundi(ui_scale * 100.0), game.message_label.get_line_count()]
		)
		expect(
			game.energy_tutorial_version_seen == 1
			and tutorial_persistence.writes.size() == 1
			and String(tutorial_persistence.writes[0].get("key", ""))
				== "campaign_energy_tutorial_version"
			and int(tutorial_persistence.writes[0].get("value", 0)) == 1,
			"%d%% 字体下 HUD 未在完整显示后恰好一次确认体力教学"
			% roundi(ui_scale * 100.0)
		)
	game.persistence = actual_persistence
	game.energy_tutorial_version_seen = original_tutorial_version
	tutorial_persistence.free()

	# Feed the longest authored Guyu title+hint through the real production HUD;
	# this catches clipping regressions when content writers revise the matrix.
	var event_title := ""
	var event_hint := ""
	var event_number := 1
	var player_instruction := "飞进黄色圆圈，连续按两次同一个方向"
	var progress_label := "已通过 0/3"
	var guyu_level: Dictionary = game.state.catalog.level_by_id("spring_guyu")
	for authored_event in guyu_level.get("event_matrix", []):
		var candidate_title := String((authored_event as Dictionary).get("title", ""))
		var candidate_hint := String((authored_event as Dictionary).get("ui_hint", ""))
		if candidate_title.length() + candidate_hint.length() > event_title.length() + event_hint.length():
			event_title = candidate_title
			event_hint = candidate_hint
			event_number = int((authored_event as Dictionary).get("order", 1))
	expect(not event_title.is_empty() and not event_hint.is_empty(), "谷雨正式事件矩阵没有可测量的 title/hint")
	game._on_field_status({
		"level_number": 6,
		"term_name": "谷雨",
		"display_name": "季节大忙",
		"is_climax": true,
		"area": "雨后接货坡",
		"energy": 88.0,
		"energy_cap": 100.0,
		"energy_state": "逆风",
		"time_remaining": 240.0,
		"ready_to_return": false,
		"message": "%s · %s" % [event_title, event_hint],
		"hazard_active": false,
		"action_label": "选短线",
		"action_enabled": true,
		"return_label": "选稳线",
		"event_runtime": {
			"current_event_number": event_number,
			"event_count": 15,
			"current_event_title": event_title,
			"ui_hint": event_hint,
			"optional": false,
			"choice_pending": true,
		},
		"player_instruction": player_instruction,
		"progress_label": progress_label,
	})
	expect(
		game.field_heading_label.text == "主线 %02d/15" % event_number,
		"三候事件没有同时标明主线与进度：%s" % game.field_heading_label.text
	)
	expect(
		game.objective_label.text == "%s\n%s\n%s" % [event_title, player_instruction, progress_label],
		"真实事件没有分行显示标题、白话操作和进度：%s" % game.objective_label.text
	)
	expect(game.energy_label.text == "体力 88 / 100 · 逆风", "体力 HUD 没有告诉玩家正在为什么消耗或恢复")
	expect(
		not game.toast_panel.visible and game.message_label.text.is_empty(),
		"事件准备把目标卡已有的标题与提示又弹成了 toast"
	)
	expect(
		"空格/A 选短线" in game.controls_label.text and "Q/Y 选稳线" in game.controls_label.text,
		"路线选择仍显示固定互动/回巢说明：%s" % game.controls_label.text
	)
	game._on_field_status({
		"level_number": 6,
		"term_name": "谷雨",
		"is_climax": true,
		"area": "雨后接货坡",
		"energy": 88.0,
		"energy_cap": 100.0,
		"energy_state": "休息点 · 快速回满",
		"time_remaining": 240.0,
		"ready_to_return": false,
		"message": "第一块花牌扣稳了。 %s · %s" % [event_title, event_hint],
		"action_label": "继续核对",
		"action_enabled": true,
		"return_label": "指路回巢",
		"event_runtime": {
			"current_event_number": event_number,
			"event_count": 15,
			"current_event_title": event_title,
			"ui_hint": event_hint,
			"optional": true,
		},
		"player_instruction": player_instruction,
		"progress_label": "",
	})
	expect(game.field_heading_label.text == "自选 %02d/15" % event_number, "自选内容在目标卡上被误标为主线")
	expect(
		game.objective_label.text == "%s\n%s" % [event_title, player_instruction],
		"自选/选路的空进度标签被 HUD 擅自补成了假进度"
	)
	expect(
		game.toast_panel.visible and game.message_label.text == "第一块花牌扣稳了。",
		"去重下一目标时把前面的事件后果一起吞掉了：%s" % game.message_label.text
	)
	var top_row: Array[Control] = [
		game.energy_label,
		game.cargo_label,
		game.reserve_label,
		game.timer_label,
		game.save_label,
		game.pause_button,
	]
	for ui_scale in [1.0, 1.15, 1.3]:
		game._apply_settings({
			"ui_scale": ui_scale,
			"reduce_motion": false,
			"show_control_hints": true,
		})
		await process_frame
		for index in top_row.size():
			for other_index in range(index + 1, top_row.size()):
				expect(
					not controls_overlap(top_row[index], top_row[other_index]),
					"%d%% 字体下顶栏第 %d、%d 项重叠" % [roundi(ui_scale * 100.0), index, other_index]
				)
		expect(
			not controls_overlap(game.field_heading_label, game.objective_label),
			"%d%% 字体下目标标题压到当前动作" % roundi(ui_scale * 100.0)
		)
		expect(
			not controls_overlap(game.objective_label, game.objective_toggle_button),
			"%d%% 字体下当前动作压到收起按钮" % roundi(ui_scale * 100.0)
		)
		expect(
			not controls_overlap(game.action_button, game.return_button),
			"%d%% 字体下两个必要动作互相覆盖" % roundi(ui_scale * 100.0)
		)
		expect(
			game.objective_label.clip_text and game.action_button.clip_text,
			"%d%% 字体没有安全截断，长文可能越界" % roundi(ui_scale * 100.0)
		)
		var controls_font: Font = game.controls_label.get_theme_font("font")
		var controls_width := controls_font.get_string_size(
			game.controls_label.text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			game.controls_label.get_theme_font_size("font_size")
		).x
		expect(
			controls_width <= game.controls_label.size.x,
			"%d%% 字体下动态操作说明被截断：%.1f > %.1f"
				% [roundi(ui_scale * 100.0), controls_width, game.controls_label.size.x]
		)
		var energy_font: Font = game.energy_label.get_theme_font("font")
		var energy_width := energy_font.get_string_size(
			game.energy_label.text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			game.energy_label.get_theme_font_size("font_size")
		).x
		expect(
			energy_width <= game.energy_label.size.x,
			"%d%% 字体下体力原因被截断：%.1f > %.1f"
				% [roundi(ui_scale * 100.0), energy_width, game.energy_label.size.x]
		)
		expect(
			game.field_panel.get_global_rect().encloses(game.objective_label.get_global_rect())
				and game.objective_toggle_button.get_global_rect().end.x <= 1280.0
				and game.objective_toggle_button.get_global_rect().end.y <= 720.0,
			"%d%% 字体下目标正文或角落箭头越出容器" % roundi(ui_scale * 100.0)
		)
		expect(
			game.objective_label.max_lines_visible == 3
				and minf(game.objective_toggle_button.size.x, game.objective_toggle_button.size.y) >= 44.0,
			"%d%% 字体下三行目标或 44px 触控命中区失效" % roundi(ui_scale * 100.0)
		)

	game._toggle_field_hud()
	expect(game.field_hud_collapsed and game.field_panel.size == game.FIELD_OBJECTIVE_COLLAPSED_SIZE, "目标卡无法收起")
	expect(
		not game.objective_label.visible
			and game.objective_toggle_button.text == "→"
			and is_equal_approx(game.objective_toggle_button.rotation_degrees, 90.0),
		"收起后仍保留大段目标文字或箭头方向错误"
	)
	expect(
		game.action_panel.visible and game.energy_label.visible and game.cargo_label.visible,
		"收起目标时误藏了必要动作或资源"
	)
	expect(game.objective_toggle_button.focus_mode == Control.FOCUS_ALL, "目标开关不能由键盘或手柄聚焦")
	expect(minf(game.objective_toggle_button.size.x, game.objective_toggle_button.size.y) >= 44.0, "收起后的目标开关小于 44px")
	game._toggle_field_hud()
	expect(
		not game.field_hud_collapsed
			and game.objective_label.visible
			and is_equal_approx(game.objective_toggle_button.rotation_degrees, -90.0),
		"目标卡无法重新展开"
	)

	game._apply_settings({"ui_scale": 1.0, "reduce_motion": false, "show_control_hints": false})
	expect(not game.controls_label.visible, "关闭操作提示的无障碍设置没有作用")
	expect(game.pause_button.focus_mode == Control.FOCUS_ALL, "暂停入口失去键盘或手柄焦点")
	game._open_pause_menu(false)
	expect(game.paused_by_menu and game.system_menu.is_open() and paused, "HUD 重排破坏了正式暂停入口")
	game._resume_from_menu()
	expect(not game.paused_by_menu and not paused, "暂停页无法恢复游戏")
	game._process(game.FIELD_TOAST_SECONDS + 0.1)
	expect(not game.toast_panel.visible, "现场 toast 到时后仍常驻遮挡画面")

	# Exercise one real field -> hive settlement. The commercial result audio and
	# receiving line own the first beat; only presentation_finished starts the
	# readable story timer, and the old generic `complete` cue stays silent.
	game.sound.last_cue = ""
	game._begin_level("spring_lichun", false)
	await process_frame
	var field := game.router.current_area as JourneyCampaignField
	expect(field != null, "HUD 回归无法进入第一趟正式花田")
	if field != null:
		var actions_before_gate: int = field.action_count
		Input.action_press("action")
		field.set_input_enabled(false)
		field.set_input_enabled(true)
		field._process(0.01)
		expect(field.action_count == actions_before_gate, "出巢/恢复时仍把确认键穿透成世界动作")
		Input.action_release("action")
		field._process(0.01)

		game.action_button.grab_focus()
		field.request_primary_action()
		var actions_after_button: int = field.action_count
		Input.action_press("action")
		field._process(0.01)
		expect(field.action_count == actions_after_button, "聚焦动作按钮时 Space/A 被 GUI 与世界轮询派发两次")
		Input.action_release("action")
		field._process(0.01)
		game.action_button.release_focus()

		field.force_complete_for_test()
		await process_frame
		await process_frame
		await process_frame
		var return_hive := game.router.current_area as JourneyCampaignHive
		expect(return_hive != null and return_hive.presentation_time > 0.0, "完成第一趟后没有进入返巢接货演出")
		expect(
			not game.story_card.visible and is_zero_approx(game.story_time) and not game.pending_hive_story_text.is_empty(),
			"返巢故事在 presentation_finished 之前已经显示或开始倒计时"
		)
		expect(game.sound.last_cue != "complete", "通用 complete 音效仍与蜂巢结果时间线重叠")
		game._process(1.0)
		expect(is_zero_approx(game.story_time), "接货演出期间故事阅读时间被提前消耗")
		if return_hive != null:
			return_hive.skip_receiving_presentation()
			expect(
				game.story_card.visible and game.story_time > 4.7 and game.pending_hive_story_text.is_empty(),
				"presentation_finished 没有准确启动并清空待播故事"
			)
			var story_time_before: float = game.story_time
			game._process(0.5)
			expect(game.story_time < story_time_before, "故事出现后计时器没有正常推进")
			await process_frame

	var campaign_audio := game.get_node_or_null("JourneyAudioDirector")
	if campaign_audio != null:
		campaign_audio.queue_free()
		await process_frame
	game.queue_free()
	await process_frame
	await process_frame
	if failures.is_empty():
		print("JOURNEY CAMPAIGN HUD TEST PASSED")
		print("TEST PASSED")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
