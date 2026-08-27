extends SceneTree

const JourneyScene := preload("res://journey.tscn")
const JourneyStateScript := preload("res://scripts/world/journey_state.gd")
const JourneyAreaRouterScript := preload("res://scripts/world/journey_area_router.gd")
const VIEWPORT_WIDTH := 1280.0

var failures: Array[String] = []


func _init() -> void:
	call_deferred("run_test")


func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func pointer_clear_world_right(world_end_x: float, panel_left_x: float) -> float:
	# At the far-right camera limit, this is the rightmost world coordinate that
	# remains visible left of the 130% UI side panel and can receive a ground tap.
	return world_end_x - VIEWPORT_WIDTH + panel_left_x


func bee_clear_world_right(world_end_x: float, panel_left_x: float) -> float:
	return pointer_clear_world_right(world_end_x, panel_left_x) - 51.0


func run_test() -> void:
	var state = JourneyStateScript.new()
	var next_context: Dictionary = state.next_field_context()
	expect(int(next_context.journey_token) == 1 and state.active_token == 0, "预览出巢上下文提前改写了会话状态")
	var first_token: int = state.begin_sortie()
	expect(first_token > 0, "第一次出巢没有稳定旅程 token")
	var return_preview: Dictionary = state.preview_return_context(6, 2)
	expect(int(return_preview.reserve) == 6 and state.reserve == 0, "返巢预览提前写入了蜂巢储备")
	expect(state.settle_return(first_token, 6, 2), "合法返巢没有结算")
	expect(state.reserve == 6 and state.last_deposit == 6, "返巢花蜜没有进入会话蜂巢状态")
	expect(not state.settle_return(first_token, 6, 2) and state.reserve == 6, "同一次返巢被重复结算，复制了花蜜")
	expect(not state.settle_return(first_token + 10, 6, 2), "未知旅程 token 可以写入蜂巢")
	var full_spring_state = JourneyStateScript.new()
	var full_spring_token: int = full_spring_state.begin_sortie(JourneyState.SPRING_ROUTE)
	expect(full_spring_state.settle_return(full_spring_token, 12, 2), "春野多趟带回全部 12 滴时被错误拒绝")
	expect(
		full_spring_state.reserve == 12
		and full_spring_state.world_results.spring_honey_returned == 12,
		"春野超过 6 滴的真实带回量没有进入巢储账本"
	)
	expect(int(full_spring_state.next_incident_context().reserve) == 6, "花牌周转蜜预览吞掉了春野多带回的余量")
	expect(
		full_spring_state.begin_sortie(JourneyState.SIGN_INCIDENT) > 0
		and full_spring_state.reserve == 6,
		"花牌出巢没有只领走 6 滴周转蜜"
	)
	var incident_context: Dictionary = state.next_incident_context()
	expect(
		int(incident_context.starting_honey) == 6 and int(incident_context.reserve) == 0,
		"花牌事故没有把巢内 6 滴周转蜜明确转为随身携带"
	)
	var incident_token: int = state.begin_sortie(JourneyState.SIGN_INCIDENT)
	expect(incident_token > 0 and state.reserve == 0, "花牌出巢没有从巢储扣除 6 滴周转蜜")
	expect(not state.settle_sign_incident(incident_token, 5, 2, 1), "花牌少理一处也能偷偷结算")
	expect(not state.settle_sign_incident(incident_token, 6, 3, 1), "花牌事故把丢掉的蜜魔法补回后仍能结算")
	expect(state.settle_sign_incident(incident_token, 5, 3, 1), "合法花牌事故没有结算")
	expect(state.reserve == 5 and state.incident_honey_lost == 1, "周转蜜的实得归还或真实损失没有进入会话状态")
	expect(not state.settle_sign_incident(incident_token, 5, 3, 1) and state.reserve == 5, "花牌事故被重复结算，复制了花蜜")
	var underfunded_incident = JourneyStateScript.new()
	underfunded_incident.first_return_complete = true
	underfunded_incident.reserve = 5
	expect(
		not underfunded_incident.can_begin_sortie(JourneyState.SIGN_INCIDENT)
		and underfunded_incident.begin_sortie(JourneyState.SIGN_INCIDENT) == -1
		and underfunded_incident.reserve == 5,
		"巢储不足时仍凭空发出 6 滴周转蜜"
	)
	expect(state.next_segment_id() == JourneyState.SUMMER_RECOVERY, "春章完成后没有顺接夏日追回路线")
	var summer_token: int = state.begin_sortie(JourneyState.SUMMER_RECOVERY)
	expect(
		not state.settle_summer(summer_token, 6, 6, 0, 3, true),
		"夏章只找回 6 / 8 份散落蜜就能提前结算"
	)
	expect(
		not state.settle_summer(summer_token, 7, 8, 0, 3, true),
		"夏日追回把实际损失和带回数量对不上的花蜜魔法结算了"
	)
	expect(state.settle_summer(summer_token, 7, 8, 1, 3, true), "合法夏章结果没有结算")
	expect(state.reserve == 12 and state.world_results.summer_honey_lost == 1, "夏章真实带回量或损失没有持久化")
	expect(not state.settle_summer(summer_token, 7, 8, 1, 3, true) and state.reserve == 12, "夏章同一 token 重复加蜜")
	expect(state.next_segment_id() == JourneyState.AUTUMN_HARVEST, "夏章完成后没有顺接秋花路线")
	var autumn_token: int = state.begin_sortie(JourneyState.AUTUMN_HARVEST)
	expect(not state.settle_autumn(autumn_token, 3, 3, 4, 3), "秋章漏处理一朵花仍能结算")
	expect(state.settle_autumn(autumn_token, 3, 3, 5, 3), "秋章混合收蜜留种结果没有结算")
	expect(
		state.world_results.autumn_harvested == 3 and state.world_results.autumn_seeded == 5,
		"秋章把逐花混合结果压成了单一好坏选择"
	)
	expect(state.next_segment_id() == JourneyState.WINTER_WARMTH, "秋章完成后没有顺接冬日续暖路线")
	var winter_token: int = state.begin_sortie(JourneyState.WINTER_WARMTH)
	expect(not state.settle_winter(winter_token, 4, 2, true), "少一段挡风木也能结束冬章")
	expect(state.settle_winter(winter_token, 4, 3, true), "合法冬章结果没有结算")
	expect(
		state.world_results.winter_bear_helped and state.world_results.winter_windbreak_segments == 3,
		"大熊和修补蜂的挡风墙没有进入跨章世界结果"
	)
	expect(state.next_segment_id() == JourneyState.FINALE_HANDOFF, "冬章完成后没有进入交棒")
	var finale_token: int = state.begin_sortie(JourneyState.FINALE_HANDOFF)
	expect(not state.settle_finale(finale_token, 2, true), "示范没做完就能说标题收尾")
	expect(state.settle_finale(finale_token, 3, true), "完成示范后没有结算结尾")
	expect(state.journey_complete and state.next_segment_id().is_empty(), "交棒后旅程没有稳定结束")
	expect(not state.settle_finale(finale_token, 3, true), "结尾被重复结算")

	var router_host := Node2D.new()
	root.add_child(router_host)
	var router = JourneyAreaRouterScript.new()
	root.add_child(router)
	expect(router.configure(router_host) == OK, "区域路由没有接受唯一 host")
	expect(router.change_area("missing-area") == ERR_DOES_NOT_EXIST, "未知区域没有 fail closed")
	expect(router.change_area("hive_threshold", {}) == OK, "蜂巢门槛场景无法装入")
	var first_area: Node = router.current_area
	expect(first_area is HiveThresholdArea and router_host.get_child_count() == 1, "蜂巢场景没有成为唯一活动区域")
	expect(router.change_area("hive_threshold", {}) == OK, "同一区域无法作为真实新场景重载")
	expect(router_host.get_child_count() == 1 and router.current_area != first_area, "区域切换复制了活动场景或沿用了旧实例")
	expect(
		router.change_area("spring_sign_incident", {"journey_token": 1, "starting_honey": 6}) == OK,
		"花牌事故没有作为真实 PackedScene 接入区域路由"
	)
	expect(router.current_area is SpringSignIncident and router_host.get_child_count() == 1, "花牌事故场景没有成为唯一活动区域")
	var empty_incident := router.current_area as SpringSignIncident
	empty_incident.carried = 0
	empty_incident.honey_lost = 6
	empty_incident.bee.position = empty_incident.mosquito_position + Vector2(20, 0)
	expect(empty_incident.apply_mosquito_contact(), "空蜜囊接触被当成不可处理状态")
	expect(empty_incident.carried == 0 and empty_incident.honey_lost == 6, "空蜜囊接触制造了负数或重复损失")
	for sign_index in empty_incident.signs.size():
		expect(empty_incident._resolve_sign(sign_index), "蜜囊为空时第 %d 处花牌被软锁" % (sign_index + 1))
	expect(empty_incident.final_sign_on_back and empty_incident.mentor_return_active, "蜜囊为空时事故无法进入返巢阶段")
	var seasonal_context := {
		"journey_token": 2,
		"reserve": 5,
		"sortie_count": 3,
		"world_results": {"spring_signs_resolved": 3},
	}
	expect(router.change_area("summer_field", seasonal_context) == OK, "夏章没有作为真实 PackedScene 接入路由")
	var routed_summer := router.current_area as SummerJourneyField
	expect(routed_summer != null and routed_summer.world_bounds.size.x > 1280, "夏章不是可移动的大地图场景")
	expect(router.change_area("autumn_field", seasonal_context) == OK, "秋章没有作为真实 PackedScene 接入路由")
	var routed_autumn := router.current_area as AutumnJourneyField
	expect(routed_autumn != null and routed_autumn.world_bounds.size.y > 720, "秋章不是可移动的大地图场景")
	expect(router.change_area("winter_field", seasonal_context) == OK, "冬章没有作为真实 PackedScene 接入路由")
	var routed_winter := router.current_area as WinterJourneyField
	expect(routed_winter != null and routed_winter.world_bounds.size.x > 1280, "冬章不是可移动的大地图场景")
	expect(router.change_area("finale_handoff", seasonal_context) == OK, "结尾交棒没有作为真实 PackedScene 接入路由")
	expect(router.current_area is FinaleHandoffField, "结尾交棒场景类型错误")
	router_host.queue_free()
	router.queue_free()

	var game = JourneyScene.instantiate()
	game.transition_duration = 0.0
	root.add_child(game)
	await process_frame
	expect(game.router.current_area_id == "hive_threshold", "产品旅程没有从蜂巢门槛开始")
	expect(game.router.current_area is HiveThresholdArea, "启动区域不是浅层蜂巢场景")
	var hive := game.router.current_area as HiveThresholdArea
	expect(game.solar_term_board.top_button.visible and "0 / 24" in game.solar_term_board.top_button.text, "主蜂巢没有显示空的巢内纪事入口")
	var depart_event := InputEventAction.new()
	depart_event.action = "action"
	depart_event.pressed = true
	game.solar_term_board.open_latest()
	hive._unhandled_input(depart_event)
	await process_frame
	expect(game.router.current_area_id == "hive_threshold", "翻看巢内纪事时空格误触出巢")
	game.solar_term_board.close()
	hive._unhandled_input(depart_event)
	await process_frame
	expect(game.router.current_area_id == "spring_field", "键盘出巢没有切换到春野 PackedScene")
	var field := game.router.current_area as SpringJourneyField
	expect(field != null, "春野区域类型错误")
	if field != null:
		expect(field.sound == game.sound, "春野没有复用 Journey 的共享动作音效节点")
		game._apply_side_panel_scale(1.3)
		game._position_side_panel(false)
		expect(is_equal_approx(game.side_panel.position.x, 940.0), "130% UI 的野外清单没有使用预期遮挡边界")
		var spring_pointer_right := pointer_clear_world_right(field.WORLD_BOUNDS.end.x, game.side_panel.position.x)
		expect(
			field.PLAYABLE_BOUNDS.end.x - 18.0 <= bee_clear_world_right(field.WORLD_BOUNDS.end.x, game.side_panel.position.x),
			"春野移动边界会把整只蜂藏到 130% UI 清单下面"
		)
		for flower in field.flowers:
			expect(Vector2(flower.position).x <= spring_pointer_right, "春野花朵在 130% UI 下被清单完全遮住，触屏无法点到")
		expect(field.story_intro_active and field.bee.story_petal_visible, "第一次出巢没有撞花后顶着花瓣的可见动作")
		var flowers_before_demo: Array = field.flowers.duplicate(true)
		var pollen_before_demo: Array = field.pollination.pollen_charges.duplicate()
		field._update_story_intro(1.10)
		expect(not field.bee.story_petal_visible and field.story_intro_phase == "petal_removed", "老师傅没有顺手摘下花瓣")
		field._update_story_intro(1.15)
		expect(field.story_intro_phase == "mentor_demonstration", "老师傅没有进入实际示范动作")
		field._update_story_intro(field.STORY_DEMO_END + 0.01)
		expect(field.mentor_demonstration_completed and not field.story_intro_active, "老师傅示范没有明确结束并把操作交给玩家")
		expect(field.flowers == flowers_before_demo, "老师傅示范改写了真实花朵或花蜜")
		expect(field.pollination.pollen_charges == pollen_before_demo, "老师傅示范偷偷给玩家装入了散粉")
		field.completion_emitted = true
		field.bee.active = false
		game._settle_and_show_hive({
			"journey_kind": JourneyState.SPRING_ROUTE,
			"journey_token": game.state.active_token,
			"deposit": 99,
			"pollinations": 2,
		})
		expect(
			game.router.current_area == field
			and not field.completion_emitted
			and field.input_enabled
			and field.bee.active,
			"异常返巢数据被拒绝后没有恢复当前场景，玩家会永久卡住"
		)
		expect("可选歇脚" in game.objective_label.text, "小蜂房在目标卡中没有明确标为可选")
		expect(field.WORLD_BOUNDS.size.x >= 2.0 * 970.0 and field.WORLD_BOUNDS.size.y >= 2.0 * 538.0, "春野没有达到 2×2 旧视口量级")
		expect(field.flowers.any(func(flower): return Vector2(flower.position).x > 1600.0), "远花仍全部挤在旧单屏范围内")
		expect(field.bee.get_movement_bounds() == field.PLAYABLE_BOUNDS, "玩家没有使用避开固定 HUD 的大地图安全边界")
		expect(field.camera_target_for(Vector2.ZERO) == Vector2(640, 360), "摄像机左上边界没有覆盖完整视口")
		expect(field.camera_target_for(field.WORLD_BOUNDS.end) == Vector2(1500, 820), "摄像机右下边界越过地图")
		expect(not field.camera.position_smoothing_enabled, "摄像机平滑延迟破坏了 HUD 安全边界预算")
		var playable_min := field.PLAYABLE_BOUNDS.position + Vector2(18, 18)
		var playable_max := field.PLAYABLE_BOUNDS.end - Vector2(18, 18)
		var screen_min := field.projected_screen_position(playable_min)
		var screen_max := field.projected_screen_position(playable_max)
		expect(
			screen_min.x - field.BEE_VISUAL_SAFE_EXTENTS.x >= field.HUD_SAFE_RECT.position.x
			and screen_min.y - field.BEE_VISUAL_SAFE_EXTENTS.y >= field.HUD_SAFE_RECT.position.y,
			"大地图左上可移动边界仍会被顶部 HUD 遮挡：%s" % screen_min
		)
		expect(
			screen_max.x + field.BEE_VISUAL_SAFE_EXTENTS.x <= field.HUD_SAFE_RECT.end.x
			and screen_max.y + field.BEE_VISUAL_SAFE_EXTENTS.y <= field.HUD_SAFE_RECT.end.y,
			"大地图右下可移动边界仍会被右侧 HUD 遮挡：%s" % screen_max
		)
		field.camera.position_smoothing_enabled = false
		field.bee.position = Vector2(1200, 600)
		field._update_camera()
		await process_frame
		var converted_center := field.screen_to_world(Vector2(640, 360))
		expect(converted_center.distance_to(Vector2(1200, 600)) < 1.0, "摄像机移动后指针仍把屏幕坐标当世界坐标：%s" % converted_center)
		expect(field.area_name_for(Vector2(1700, 500)) == "春野 · 远花坡", "远区 HUD 仍错误显示为回风路")
		expect(
			field.clamp_to_playable_center(field.WORLD_BOUNDS.end) == field.PLAYABLE_BOUNDS.end - Vector2(18, 18),
			"点击地图边缘没有钳制到可到达位置，会让蜂持续顶墙"
		)

		field.bee.position = Vector2(1200, 600)
		field.bee.energy = 80.0
		field.set_input_enabled(false)
		Input.action_press("move_right")
		Input.action_press("action")
		field._process(0.25)
		expect(field.bee.position == Vector2(1200, 600) and is_equal_approx(field.bee.energy, 80.0), "转场遮罩期间花田仍移动、耗能或执行动作")
		Input.action_release("move_right")
		Input.action_release("action")
		field.set_input_enabled(true)
		Input.action_press("action")
		game._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
		expect(not field.input_enabled and not Input.is_action_pressed("action"), "浏览器失焦后旅程仍在运行，或触摸动作卡在按下状态")
		game._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)
		expect(field.input_enabled, "浏览器重新聚焦后旅程没有恢复")

		field.bee.position = Vector2(1200, 960)
		field.bee.velocity = Vector2(-40, 0)
		var breeze_start_x := field.bee.position.x
		field._update_return_breeze(0.5)
		expect(field.bee.position.x < breeze_start_x, "原有回风在结籽前完全不存在，仍是二元生成")

		field.carried = 1
		field.bee.position = field.RELAY_POSITION
		Input.action_press("action")
		field._handle_actions(0.0)
		Input.action_release("action")
		expect(field.relay_hive.active and field.carried == 0, "小蜂房没有显式消耗一滴随身蜜开门")
		expect(field.delivered == 0 and game.state.reserve == 0, "小蜂房错误承担了主巢交货")

		# Deliver more than the six-drop goal, then finish pollination and return
		# empty-handed. Every accepted drop must survive the transition without
		# freezing the bee or being silently discarded.
		# must be independent of which required job the player finishes first.
		field.carried = 8
		field.bee.position = field.HIVE_RETURN_POS
		field.bee.velocity = Vector2.ZERO
		field.bee.has_target = false
		field._update_main_hive(field.DEPOSIT_DWELL)
		expect(field.delivered == 8 and not field.completion_emitted, "多带两滴时主巢没有照单接货，或未授粉就错误完成")
		expect(game.router.current_area_id == "spring_field" and game.state.reserve == 0, "花田临时交货提前写入会话储备")

		var nectar_before := 0
		for flower in field.flowers:
			nectar_before += int(flower.nectar)
		field.pollination.pollen_charges[0] = 1
		field.pollination.pollen_charges[1] = 1
		field.bee.position = Vector2(field.flowers[4].position)
		expect(field.pollination.try_context_action(field.bee.position), "同形散粉无法送入第一朵开放花心")
		field.pollination.process(0.5)
		field.bee.position = Vector2(field.flowers[5].position)
		expect(field.pollination.try_context_action(field.bee.position), "同形散粉无法送入第二朵开放花心")
		field.pollination.process(0.5)
		var nectar_after := 0
		for flower in field.flowers:
			nectar_after += int(flower.nectar)
		expect(field.pollination.pollinated_flowers == 2, "春野没有让两朵花真实开始结籽")
		expect(nectar_after == nectar_before, "传粉错误增加或消耗了花蜜")
		game._on_field_status(field.status_snapshot())
		expect("回主蜂巢停稳收工" in game.objective_label.text, "两项工作完成后，返巢收工仍是隐藏门禁")

		expect(field.carried == 0, "完成授粉前的空手返程测试意外获得花蜜")
		field.bee.position = field.HIVE_RETURN_POS
		field.bee.velocity = Vector2.ZERO
		field.bee.has_target = false
		field._update_main_hive(field.DEPOSIT_DWELL)
		await process_frame
		await process_frame
		expect(game.state.reserve == 8, "主巢没有把完成路线实际带回的 8 滴蜜结算一次")
		expect(game.state.world_results.spring_honey_returned == 8, "春野多带回的两滴没有写入跨章账本")
		expect(game.router.current_area_id == "hive_threshold", "完成往返后没有切回巢门内侧")
		expect(game.router.current_area is HiveThresholdArea, "返巢结果仍停在花田结果卡")
		expect(game.state.title_revealed and game.title_label.text == "一会儿巢里见", "标题没有在第一次真实接货后揭示")
		expect(game.story_card.visible and "飞一圈，巢里见" in game.story_card_label.text, "首次返巢没有出现完整标题揭示卡")
		expect(game.state.solar_terms.unlocked_count() == 3, "首次返巢没有落成春季前三条巢内纪事")
		expect("立春、雨水、惊蛰" in game.story_card_label.text, "首次返巢没有把新纪事明确告诉玩家")
		expect("3 / 24" in game.solar_term_board.top_button.text, "巢内纪事入口没有显示首次返巢进度")

		var returned_hive := game.router.current_area as HiveThresholdArea
		returned_hive._process(returned_hive.RECEIVING_DURATION + 0.1)
		expect(returned_hive.ready_for_sortie, "首次接货结束后花牌事故没有可进入入口")
		returned_hive.request_sortie()
		await process_frame
		expect(game.router.current_area_id == "spring_sign_incident", "首次返巢后没有进入蚊庄主花牌事故")
		var incident := game.router.current_area as SpringSignIncident
		expect(incident != null, "花牌事故区域类型错误")
		if incident != null:
			expect(incident.sound == game.sound, "花牌事故没有复用 Journey 的共享动作音效节点")
			var incident_pointer_right := pointer_clear_world_right(incident.WORLD_BOUNDS.end.x, game.side_panel.position.x)
			expect(
				incident.PLAYABLE_BOUNDS.end.x - 18.0 <= bee_clear_world_right(incident.WORLD_BOUNDS.end.x, game.side_panel.position.x),
				"花牌地图移动边界会把整只蜂藏到 130% UI 清单下面"
			)
			for sign in incident.signs:
				expect(Vector2(sign.position).x <= incident_pointer_right, "花牌在 130% UI 下被清单完全遮住，触屏无法点到")
			expect(incident.carried == 6 and incident.signs.size() == 3, "事故没有从 6 滴蜜和三处可见花牌开始")
			expect("花标归位  0 / 3" in game.objective_label.text, "花牌事故的三处阻塞条件没有从开局显示")
			expect("一起归巢" in game.objective_label.text, "老师傅并排归巢要求仍是隐藏门禁")
			incident.bee.position = incident.mosquito_position + Vector2(20, 0)
			expect(incident.apply_mosquito_contact(), "庄主接触没有形成可读的擦身损失")
			expect(incident.carried == 5 and incident.honey_lost == 1, "庄主接触没有只扣一滴真实携蜜")
			expect(game.sound.last_cue == "honey_loss" and game.sound.last_cue_used_asset, "庄主造成失蜜没有播放商业候选资产")
			for sign_index in incident.signs.size():
				incident.wind_elapsed = fposmod(0.1 - float(incident.signs[sign_index].phase_offset), incident.WIND_CYCLE)
				expect(incident.is_wind_window_open(sign_index), "第 %d 处花牌没有明确可用风窗" % (sign_index + 1))
				incident.bee.position = Vector2(incident.signs[sign_index].position)
				expect(incident._resolve_sign(sign_index), "第 %d 处花牌无法归位" % (sign_index + 1))
			expect(incident.signs_resolved == 3 and incident.final_sign_on_back, "最后一块牌没有立即落在蚊庄主背上")
			expect(incident.mentor_return_active and "在蚊庄主背上" in game.objective_label.text, "第三处完成后没有立即进入并排返巢阶段")
			incident.bee.position = incident.HIVE_POSITION
			incident.mentor_position = incident.bee.position + Vector2(60, 0)
			incident._update_home()
			await process_frame
			await process_frame
			expect(game.router.current_area_id == "hive_threshold", "与老师傅并排到达巢门后没有立即完成章节")
			expect(game.state.chapter_complete and game.state.incident_signs_resolved == 3, "花牌事故结果没有进入章节状态")
			expect(game.state.reserve == 7 and game.state.incident_honey_lost == 1, "事故没有只领出 6 滴周转蜜再按实得归还")
			expect("带回 5 / 6 滴" in game.story_card_label.text, "章节结果没有如实显示实际带回量")
			expect(game.state.solar_terms.unlocked_count() == 6, "春季花牌返巢后没有恰好六条节气纪事")

			var spring_done_hive := game.router.current_area as HiveThresholdArea
			spring_done_hive._process(spring_done_hive.RECEIVING_DURATION + 0.1)
			expect(spring_done_hive.ready_for_sortie, "春章完成错误封死了后续四季入口")
			expect(spring_done_hive.action_text() == "去夏日远花路", "春章后主巢没有显示夏章入口")
			spring_done_hive.request_sortie()
			await process_frame
			expect(game.router.current_area_id == "summer_field", "春章后没有切入夏季 PackedScene")
			var summer := game.router.current_area as SummerJourneyField
			expect(summer != null, "夏季场景类型错误")
			if summer != null:
				expect(summer.sound == game.sound, "夏章没有复用 Journey 的共享动作音效节点")
				var summer_pointer_right := pointer_clear_world_right(summer.world_bounds.end.x, game.side_panel.position.x)
				expect(
					summer.playable_bounds.end.x - 18.0 <= bee_clear_world_right(summer.world_bounds.end.x, game.side_panel.position.x),
					"夏章移动边界会把整只蜂藏到 130% UI 清单下面"
				)
				expect("找回花蜜  0 / 8" in game.objective_label.text, "夏章没有从开局显示散落花蜜总量")
				expect("油葫芦家当  0 / 3" in game.objective_label.text, "夏章把散落家当做成隐藏门禁")
				expect(int(summer.world_results.get("spring_signs_resolved", 0)) == 3, "春季花牌结果没有带进夏季世界")
				summer.recovered_honey = 6
				summer.carried = 6
				summer.belongings_recovered = 3
				summer.rest_hive_repaired = true
				expect(not summer._can_complete(), "夏章只处理 6 / 8 份散落蜜就能从主巢提前交接")
				summer.recovered_honey = 0
				summer.carried = 0
				summer.belongings_recovered = 0
				summer.rest_hive_repaired = false
				for pool in summer.honey_pools:
					expect(Vector2(pool.position).x <= summer_pointer_right, "夏章真蜜在 130% UI 下被清单完全遮住")
					summer.bee.position = Vector2(pool.position)
					summer.bee._clamp_to_movement_bounds()
					expect(
						summer.bee.position.distance_to(Vector2(pool.position)) <= 66.0,
						"夏章真蜜落在玩家移动边界之外"
					)
					summer.request_primary_action()
				expect(game.sound.last_cue == "harvest" and game.sound.last_cue_used_asset, "夏章找回真蜜没有播放采集资产")
				for belonging in summer.belongings:
					expect(Vector2(belonging.position).x <= summer_pointer_right, "夏章家当在 130% UI 下被清单完全遮住")
					summer.bee.position = Vector2(belonging.position)
					summer.bee._clamp_to_movement_bounds()
					expect(
						summer.bee.position.distance_to(Vector2(belonging.position)) <= 62.0,
						"夏章家当落在玩家移动边界之外"
					)
					summer.request_primary_action()
				expect(summer.recovered_honey == 8 and summer.belongings_recovered == 3, "夏章可见散落物无法全部实际拾回")
				summer.elapsed = 0.1
				summer.last_loss_cycle = -1
				summer.bee.position = Vector2(1120, 420)
				summer._process_chapter(0.05)
				expect(summer.carried == 7 and summer.honey_lost == 1, "夏雨没有制造一次不可回滚的真实花蜜损失")
				expect(game.sound.last_cue == "honey_loss" and game.sound.last_cue_used_asset, "夏雨失蜜没有播放损失资产")
				summer.bee.position = summer.REST_HIVE_POSITION
				summer.request_primary_action()
				expect(summer.rest_hive_repaired, "收齐油葫芦家当后仍无法修好小蜂房")
				expect(game.sound.last_cue == "repair" and game.sound.last_cue_used_asset, "夏季修巢没有播放修理资产")
				expect(summer._can_complete(), "实际带回 7 份、收齐家当并修巢后仍被软锁")
				summer.bee.position = summer.home_position
				summer.request_primary_action()
				await process_frame
				await process_frame
				expect(game.router.current_area_id == "hive_threshold", "夏章完成后没有真实切回主巢")
				expect(game.sound.last_cue == "complete" and game.sound.last_cue_used_asset, "夏章交接完成没有播放完成资产")
				expect(game.state.reserve == 14, "夏章把掉落花蜜补回，或漏结算实际带回的 7 份")
				expect(game.state.world_results.summer_rest_hive_repaired, "修好的小蜂房没有成为跨章结果")
				expect(game.state.solar_terms.unlocked_count() == 12, "夏章返巢后没有恰好十二条节气纪事")

				var summer_done_hive := game.router.current_area as HiveThresholdArea
				summer_done_hive._process(summer_done_hive.RECEIVING_DURATION + 0.1)
				expect(summer_done_hive.action_text() == "去收秋花", "夏章后主巢没有显示秋章入口")
				summer_done_hive.request_sortie()
				await process_frame
				expect(game.router.current_area_id == "autumn_field", "夏章后没有切入秋季 PackedScene")
				var autumn := game.router.current_area as AutumnJourneyField
				expect(autumn != null, "秋季场景类型错误")
				if autumn != null:
					expect(autumn.sound == game.sound, "秋章没有复用 Journey 的共享动作音效节点")
					var autumn_pointer_right := pointer_clear_world_right(autumn.world_bounds.end.x, game.side_panel.position.x)
					expect(
						autumn.playable_bounds.end.x - 18.0 <= bee_clear_world_right(autumn.world_bounds.end.x, game.side_panel.position.x),
						"秋章移动边界会把整只蜂藏到 130% UI 清单下面"
					)
					expect("逐花收尾  0 / 8" in game.objective_label.text, "秋章没有从开局显示全部逐花选择")
					expect(bool(autumn.world_results.get("summer_rest_hive_repaired", false)), "修好的夏季小蜂房没有带进秋季世界")
					for flower_index in autumn.autumn_flowers.size():
						expect(Vector2(autumn.autumn_flowers[flower_index].position).x <= autumn_pointer_right, "秋章花朵在 130% UI 下被清单完全遮住")
						autumn.bee.position = Vector2(autumn.autumn_flowers[flower_index].position)
						autumn.bee._clamp_to_movement_bounds()
						expect(
							autumn.bee.position.distance_to(Vector2(autumn.autumn_flowers[flower_index].position)) <= 62.0,
							"秋章花朵落在玩家移动边界之外"
						)
						if flower_index < 3:
							autumn.request_primary_action()
						else:
							autumn.request_secondary_action()
					expect(game.sound.last_cue == "seed" and game.sound.last_cue_used_asset, "秋章留种没有播放留种资产")
					for echo in autumn.echo_points:
						expect(Vector2(echo.position).x <= autumn_pointer_right, "秋章听声种壳在 130% UI 下被清单完全遮住")
						autumn.bee.position = Vector2(echo.position)
						autumn.bee._clamp_to_movement_bounds()
						expect(
							autumn.bee.position.distance_to(Vector2(echo.position)) <= 65.0,
							"秋章听声种壳落在玩家移动边界之外"
						)
						autumn.request_primary_action()
					expect(autumn.harvested == 3 and autumn.seeded == 5, "秋章没有保留逐花混合结果")
					expect(autumn.echo_points_tuned == 3, "画眉邻居的三处听声种壳没有完成")
					expect(game.sound.last_cue == "seed_shell_rustle" and game.sound.last_cue_used_asset, "听声种壳没有播放种荚轻响资产")
					autumn.bee.position = autumn.home_position
					autumn.request_primary_action()
					await process_frame
					await process_frame
					expect(game.sound.last_cue == "complete" and game.sound.last_cue_used_asset, "秋章交接完成没有播放完成资产")
					expect(game.state.reserve == 17, "秋章没有只把实际收下的 3 份蜜入库")
					expect(
						game.state.world_results.autumn_harvested == 3 and game.state.world_results.autumn_seeded == 5,
						"秋花组合没有跨章记忆"
					)
					expect(game.state.solar_terms.unlocked_count() == 18, "秋章返巢后没有恰好十八条节气纪事")

					var autumn_done_hive := game.router.current_area as HiveThresholdArea
					autumn_done_hive._process(autumn_done_hive.RECEIVING_DURATION + 0.1)
					expect(autumn_done_hive.action_text() == "去续暖路", "秋章后主巢没有显示冬章入口")
					autumn_done_hive.request_sortie()
					await process_frame
					expect(game.router.current_area_id == "winter_field", "秋章后没有切入冬季 PackedScene")
					var winter := game.router.current_area as WinterJourneyField
					expect(winter != null, "冬季场景类型错误")
					if winter != null:
						expect(winter.sound == game.sound, "冬章没有复用 Journey 的共享动作音效节点")
						var winter_pointer_right := pointer_clear_world_right(winter.world_bounds.end.x, game.side_panel.position.x)
						expect(
							winter.playable_bounds.end.x - 18.0 <= bee_clear_world_right(winter.world_bounds.end.x, game.side_panel.position.x),
							"冬章移动边界会把整只蜂藏到 130% UI 清单下面"
						)
						expect("逐段续暖  0 / 4" in game.objective_label.text, "冬章没有从开局显示全部续暖段")
						expect(int(winter.world_results.get("autumn_seeded", 0)) == 5, "秋季种头没有带进冬季世界")
						winter.warmth = 0.0
						winter.bee.energy = 60.0
						winter._process_chapter(0.1)
						expect(
							winter.input_enabled and is_equal_approx(winter.bee.environment_speed_multiplier, 0.40),
							"冬季暖意归零夺走操作或制造软锁"
						)
						for post in winter.warmth_posts:
							expect(Vector2(post.position).x <= winter_pointer_right, "冬章续暖点在 130% UI 下被清单完全遮住")
							winter.bee.position = Vector2(post.position)
							winter.bee._clamp_to_movement_bounds()
							expect(winter.bee.position.distance_to(Vector2(post.position)) <= 70.0, "冬章续暖点落在玩家移动边界之外")
							winter.request_primary_action()
						expect(game.sound.last_cue == "warmth_link" and game.sound.last_cue_used_asset, "冬章续暖没有播放续暖资产")
						for log_item in winter.logs:
							expect(Vector2(log_item.position).x <= winter_pointer_right, "冬章挡风木在 130% UI 下被清单完全遮住")
							winter.bee.position = Vector2(log_item.position)
							winter.bee._clamp_to_movement_bounds()
							expect(winter.bee.position.distance_to(Vector2(log_item.position)) <= 82.0, "冬章挡风木落在玩家移动边界之外")
							winter.request_primary_action()
						expect(winter.warmth_links == 4 and winter.windbreak_segments == 3, "冬章续暖或三段挡风木无法完成")
						expect(game.sound.last_cue == "carry_log" and game.sound.last_cue_used_asset, "冬章搬木没有播放搬木资产")
						expect(winter.bear_helped, "最沉木段没有形成大熊与修补蜂合作结果")
						winter.bee.position = winter.home_position
						winter.request_primary_action()
						await process_frame
						await process_frame
						expect(game.sound.last_cue == "complete" and game.sound.last_cue_used_asset, "冬章交接完成没有播放完成资产")
						expect(game.state.world_results.winter_windbreak_segments == 3, "挡风墙没有跨章记忆")
						expect(game.state.solar_terms.unlocked_count() == 24, "冬章返巢后没有恰好完成二十四节气纪事")

						var winter_done_hive := game.router.current_area as HiveThresholdArea
						winter_done_hive._process(winter_done_hive.RECEIVING_DURATION + 0.1)
						expect(winter_done_hive.action_text() == "把方法交下去", "冬章后没有进入老师傅交棒")
						winter_done_hive.request_sortie()
						await process_frame
						expect(game.router.current_area_id == "finale_handoff", "冬章后没有切入可玩交棒场景")
						var finale := game.router.current_area as FinaleHandoffField
						expect(finale != null, "交棒场景类型错误")
						if finale != null:
							expect(finale.sound == game.sound, "交棒场景没有复用 Journey 的共享动作音效节点")
							var finale_pointer_right := pointer_clear_world_right(finale.world_bounds.end.x, game.side_panel.position.x)
							expect(
								finale.playable_bounds.end.x - 18.0 <= bee_clear_world_right(finale.world_bounds.end.x, game.side_panel.position.x),
								"交棒场景移动边界会把整只蜂藏到 130% UI 清单下面"
							)
							expect(
								maxf(finale.DONOR_POSITION.x, maxf(finale.STIGMA_POSITION.x, finale.NEW_BEE_POSITION.x)) <= finale_pointer_right,
								"交棒关键点在 130% UI 下被清单完全遮住"
							)
							expect(finale.mentor_line == "老师傅往旁边让了让：这回你来。", "老师傅没有直接把示范交给玩家")
							expect("取同形散粉  0 / 1" in game.objective_label.text, "最终示范的三步条件没有从开局显示")
							expect(int(finale.world_results.get("winter_windbreak_segments", 0)) == 3, "冬季挡风墙没有带进最终场景")
							finale.bee.position = finale.DONOR_POSITION
							finale.request_primary_action()
							expect(game.sound.last_cue == "harvest" and game.sound.last_cue_used_asset, "交棒取粉没有播放采集资产")
							finale.bee.position = finale.STIGMA_POSITION
							finale.request_primary_action()
							expect(game.sound.last_cue == "pollinate" and game.sound.last_cue_used_asset, "交棒授粉没有播放授粉资产")
							finale.bee.position = finale.NEW_BEE_POSITION
							finale.request_primary_action()
							expect(game.sound.last_cue == "handoff" and game.sound.last_cue_used_asset, "向新蜂交棒没有播放交接资产")
							await process_frame
							await process_frame
							expect(game.router.current_area_id == "hive_threshold", "给新蜂示范后没有回到主巢收尾")
							expect(game.sound.last_cue == "complete" and game.sound.last_cue_used_asset, "最终交接结算没有播放完成资产")
							expect(game.state.journey_complete, "最后交棒没有把四季旅程标记为完成")
							expect(game.state.world_results.finale_demonstration_complete, "给下一只新蜂的示范没有持久化")
							expect("你：一会儿巢里见。" in game.story_card_label.text, "结尾没有由玩家直接说出标题句")
							expect(game.state.solar_terms.unlocked_count() == 24, "结尾交棒错误制造了第 25 条节气纪事")
							var final_hive := game.router.current_area as HiveThresholdArea
							final_hive._process(final_hive.RECEIVING_DURATION + 0.1)
							expect(not final_hive.ready_for_sortie and final_hive.action_text() == "四季旅程完成", "完整结尾后仍能重复开启结算路线")

	Input.action_release("action")
	Input.action_release("return_hive")
	game.queue_free()
	await process_frame

	# The exported title opens the product journey, while embedded Main fixtures
	# above remain able to exercise the legacy regression loop.
	var launcher = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(launcher)
	current_scene = launcher
	await process_frame
	expect(launcher.title_label.text == "一会儿巢里见", "生产 HUD 仍把实际标题页覆盖成旧产品名")
	launcher.persistence_enabled = false
	launcher.on_overlay_button()
	await process_frame
	await process_frame
	expect(current_scene is JourneyGame, "实际标题主场景没有进入新的产品旅程")
	if current_scene != null:
		current_scene.queue_free()
	current_scene = null
	await process_frame

	if failures.is_empty():
		print("JOURNEY WORLD TEST PASSED")
		print("TEST PASSED")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
