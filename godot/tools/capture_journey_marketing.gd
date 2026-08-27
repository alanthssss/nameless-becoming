extends SceneTree

## Developer-only framebuffer capture for the commercial Journey.
##
## This tool instantiates the real journey.tscn, advances its real JourneyState
## through valid settlement APIs, enters the requested PackedScene through the
## production router and captures the production HUD. It does not draw a mock UI
## or composite concept art over the framebuffer.

const CAPTURE_IDS := ["hive", "spring", "summer", "autumn", "winter", "finale"]
const OUTPUT_SIZE := Vector2i(1280, 720)

var capture_id := "hive"
var output_path := ""
var argument_error := ""


func _init() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="):
			capture_id = argument.trim_prefix("--capture=")
		elif argument.begins_with("--output="):
			output_path = argument.trim_prefix("--output=")
		else:
			argument_error = "不支持的采集参数：%s" % argument
	if capture_id not in CAPTURE_IDS:
		argument_error = "未知 Journey 采集场景：%s" % capture_id
	if output_path.is_empty() or not output_path.is_absolute_path() or output_path.get_extension().to_lower() != "png":
		argument_error = "--output 必须是绝对 PNG 路径"
	call_deferred("capture")


func capture() -> void:
	if not argument_error.is_empty():
		push_error(argument_error)
		quit(2)
		return
	var make_error := DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())
	if make_error != OK:
		push_error("无法建立截图目录：%s" % error_string(make_error))
		quit(2)
		return

	var journey_scene := load("res://journey.tscn") as PackedScene
	if journey_scene == null:
		push_error("无法载入真实 Journey 场景")
		quit(2)
		return
	var game = journey_scene.instantiate()
	game.transition_duration = 0.0
	root.add_child(game)
	await process_frame
	if game.router == null or game.router.current_area_id != "hive_threshold":
		push_error("Journey 没有从真实主蜂巢启动")
		quit(2)
		return

	if not _advance_to_capture(game, capture_id):
		quit(2)
		return
	if capture_id != "hive":
		game._show_hive(false, true)
		game._begin_sortie()
		await process_frame
		await process_frame
	else:
		game._show_hive(false, true)
		await process_frame

	if not _stage_representative_runtime_state(game, capture_id):
		quit(2)
		return
	game.story_card.visible = false
	game.fade.color.a = 0.0
	game.fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.transition_label.text = ""
	game.transitioning = false
	if game.router.current_area != null and game.router.current_area.has_method("set_input_enabled"):
		game.router.current_area.set_input_enabled(false)

	for frame in 4:
		await process_frame
	RenderingServer.force_draw()
	await process_frame
	var viewport_texture := root.get_texture()
	if viewport_texture == null:
		push_error("当前显示驱动没有真实帧缓冲；请用带 GPU／显示会话的 Godot，不能使用 --headless 采集")
		quit(2)
		return
	var image := viewport_texture.get_image()
	if image == null:
		push_error("无法从真实 Journey 帧缓冲读取图像")
		quit(2)
		return
	if Vector2i(image.get_width(), image.get_height()) != OUTPUT_SIZE:
		push_error("Journey 截图尺寸错误：%dx%d" % [image.get_width(), image.get_height()])
		quit(2)
		return
	var save_error := image.save_png(output_path)
	if save_error != OK:
		push_error("无法保存 Journey 截图：%s" % error_string(save_error))
		quit(2)
		return
	print("JOURNEY MARKETING CAPTURE SAVED [%s]: %s" % [capture_id, output_path])
	game.queue_free()
	await process_frame
	quit(0)


func _advance_to_capture(game, target: String) -> bool:
	var rank := {
		"spring": 0,
		"summer": 2,
		"autumn": 3,
		"winter": 4,
		"finale": 5,
		"hive": 5,
	}[target] as int
	var state = game.state
	if rank >= 1:
		var spring_token: int = state.begin_sortie(JourneyState.SPRING_ROUTE)
		if not state.settle_return(spring_token, 6, 2):
			return _capture_error("无法建立春季返巢检查点")
		state.mark_title_revealed()
	if rank >= 2:
		var sign_token: int = state.begin_sortie(JourneyState.SIGN_INCIDENT)
		if not state.settle_sign_incident(sign_token, 5, 3, 1):
			return _capture_error("无法建立花牌事故检查点")
	if rank >= 3:
		var summer_token: int = state.begin_sortie(JourneyState.SUMMER_RECOVERY)
		if not state.settle_summer(summer_token, 7, 8, 1, 3, true):
			return _capture_error("无法建立夏季返巢检查点")
	if rank >= 4:
		var autumn_token: int = state.begin_sortie(JourneyState.AUTUMN_HARVEST)
		if not state.settle_autumn(autumn_token, 3, 3, 5, 3):
			return _capture_error("无法建立秋季返巢检查点")
	if rank >= 5:
		var winter_token: int = state.begin_sortie(JourneyState.WINTER_WARMTH)
		if not state.settle_winter(winter_token, 4, 3, true):
			return _capture_error("无法建立冬季返巢检查点")
	return true


func _stage_representative_runtime_state(game, target: String) -> bool:
	match target:
		"hive":
			if game.router.current_area_id != "hive_threshold":
				return _capture_error("巢内采集没有进入 hive_threshold")
			game._refresh_hive_interface()
			return true
		"spring":
			var field := game.router.current_area as SpringJourneyField
			if field == null:
				return _capture_error("春季采集没有进入 spring_field")
			# Finish the real mentor intro using the same phase transitions as gameplay,
			# then stage a reachable pollen-and-honey carrying state.
			field._update_story_intro(1.10)
			field._update_story_intro(1.15)
			field._update_story_intro(field.STORY_DEMO_END + 0.01)
			field.carried = 3
			field.pollination.pollen_charges[0] = 1
			field.bee.set_pollen_loads([1, 0])
			field.bee.set_visual_load_ratio(3.0 / 8.0)
			field.bee.position = Vector2(1120, 650)
			field.message = "带着散粉飞到同形开放花心；远坡的蜜仍要亲自带回主蜂巢。"
			_refresh_field_capture(field, game)
			return true
		"summer":
			var summer := game.router.current_area as SummerJourneyField
			if summer == null:
				return _capture_error("夏季采集没有进入 summer_field")
			summer.bee.position = Vector2(summer.honey_pools[0].position)
			summer.request_primary_action()
			summer.bee.position = Vector2(summer.belongings[0].position)
			summer.request_primary_action()
			summer.elapsed = 3.0
			summer._process_chapter(0.0)
			summer.bee.position = summer.REST_HIVE_POSITION + Vector2(-45, 30)
			summer.message = "找回的真花蜜和家当都留在实地；三件工具齐了才能一起修横梁。"
			_refresh_field_capture(summer, game)
			return true
		"autumn":
			var autumn := game.router.current_area as AutumnJourneyField
			if autumn == null:
				return _capture_error("秋季采集没有进入 autumn_field")
			autumn.bee.position = Vector2(autumn.autumn_flowers[0].position)
			autumn.request_primary_action()
			autumn.bee.position = Vector2(autumn.autumn_flowers[1].position)
			autumn.request_secondary_action()
			autumn.bee.position = Vector2(autumn.echo_points[0].position)
			autumn.request_primary_action()
			# Frame all three seed shells clear of the right-hand HUD while keeping
			# the bee visibly separate from the ordinary thrush.
			autumn.bee.position = autumn.THRUSH_STAGE + Vector2(-80, 125)
			autumn.message = "一朵收蜜、一朵留种；转正的听声种壳正把空种荚里的风声分开。"
			_refresh_field_capture(autumn, game)
			return true
		"winter":
			var winter := game.router.current_area as WinterJourneyField
			if winter == null:
				return _capture_error("冬季采集没有进入 winter_field")
			winter.bee.position = Vector2(winter.warmth_posts[3].position)
			winter.request_primary_action()
			winter.bee.position = Vector2(winter.logs[0].position)
			winter.request_primary_action()
			winter.bee.position = Vector2(winter.logs[2].position)
			winter.request_primary_action()
			winter.bee.position = winter.BEAR_POSITION + Vector2(-120, -40)
			winter.message = "大熊顶住最沉的木段，修补蜂在两边收绳；暖路仍要逐段接好。"
			_refresh_field_capture(winter, game)
			return true
		"finale":
			var finale := game.router.current_area as FinaleHandoffField
			if finale == null:
				return _capture_error("结局采集没有进入 finale_handoff")
			finale.bee.position = finale.DONOR_POSITION
			finale.request_primary_action()
			finale.bee.position = finale.STIGMA_POSITION
			finale.request_primary_action()
			# Hold the real final action for one frame before JourneyGame performs its
			# deferred return-to-hive transition. This preserves the authored 3/3 HUD
			# and title phrase instead of manufacturing a marketing-only ending card.
			var completion_handler := Callable(game, "_on_journey_completed")
			if finale.journey_completed.is_connected(completion_handler):
				finale.journey_completed.disconnect(completion_handler)
			finale.bee.position = finale.NEW_BEE_POSITION
			finale.request_primary_action()
			_refresh_field_capture(finale, game)
			return true
	return _capture_error("未处理的 Journey 采集场景：%s" % target)


func _refresh_field_capture(field, game) -> void:
	field.bee.velocity = Vector2.ZERO
	field.bee.has_target = false
	field._update_camera()
	if field.camera != null:
		field.camera.position = field.camera_target_for(field.bee.position)
		field.camera.force_update_scroll()
	field._emit_status()
	field.queue_redraw()
	game.solar_term_board.set_hive_available(false)


func _capture_error(message: String) -> bool:
	push_error(message)
	return false
