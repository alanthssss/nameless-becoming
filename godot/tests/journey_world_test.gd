extends SceneTree

const JourneyScene := preload("res://journey.tscn")
const JourneyStateScript := preload("res://scripts/world/journey_state.gd")
const JourneyAreaRouterScript := preload("res://scripts/world/journey_area_router.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("run_test")


func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


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
	router_host.queue_free()
	router.queue_free()

	var game = JourneyScene.instantiate()
	game.transition_duration = 0.0
	root.add_child(game)
	await process_frame
	expect(game.router.current_area_id == "hive_threshold", "产品旅程没有从蜂巢门槛开始")
	expect(game.router.current_area is HiveThresholdArea, "启动区域不是浅层蜂巢场景")
	var hive := game.router.current_area as HiveThresholdArea
	var depart_event := InputEventAction.new()
	depart_event.action = "action"
	depart_event.pressed = true
	hive._unhandled_input(depart_event)
	await process_frame
	expect(game.router.current_area_id == "spring_field", "键盘出巢没有切换到春野 PackedScene")
	var field := game.router.current_area as SpringJourneyField
	expect(field != null, "春野区域类型错误")
	if field != null:
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

		# Deliver first, then finish pollination and return empty-handed. Completion
		# must be independent of which required job the player finishes first.
		field.carried = 6
		field.bee.position = field.HIVE_RETURN_POS
		field.bee.velocity = Vector2.ZERO
		field.bee.has_target = false
		field._update_main_hive(field.DEPOSIT_DWELL)
		expect(field.delivered == 6 and not field.completion_emitted, "只交够花蜜就错误完成，或主巢没有接货")
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
		expect(game.state.reserve == 6, "主巢没有把完成路线的 6 滴蜜结算一次")
		expect(game.router.current_area_id == "hive_threshold", "完成往返后没有切回巢门内侧")
		expect(game.router.current_area is HiveThresholdArea, "返巢结果仍停在花田结果卡")

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
