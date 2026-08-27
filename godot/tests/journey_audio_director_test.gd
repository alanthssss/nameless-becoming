extends SceneTree

const EXPECTED_ROUTES := {
	"spring_field": "res://assets/music/spring_explore.wav",
	"spring_sign_incident": "res://assets/music/spring_incident.wav",
	"summer_field": "res://assets/music/summer_explore.wav",
	"summer_rest_hive_repair": "res://assets/music/summer_incident.wav",
	"autumn_field": "res://assets/music/autumn_explore.wav",
	"autumn_echo_incident": "res://assets/music/autumn_incident.wav",
	"winter_field": "res://assets/music/winter_explore.wav",
	"winter_windbreak": "res://assets/music/winter_incident.wav",
	"ending": "res://assets/music/spring_explore.wav",
}
const CLIMAX_HERO_CASES := [
	{
		"id": "spring_guyu",
		"completed": 6,
		"term_name": "谷雨",
		"path": "res://assets/art/commercial/guyu_result_hero_v1.png",
		"caption": "花路重新接上了",
	},
	{
		"id": "summer_dashu",
		"completed": 12,
		"term_name": "大暑",
		"path": "res://assets/art/commercial/dashu_result_hero_v1.png",
		"caption": "盛夏的接力稳稳送到了",
	},
	{
		"id": "autumn_shuangjiang",
		"completed": 18,
		"term_name": "霜降",
		"path": "res://assets/art/commercial/shuangjiang_result_hero_v1.png",
		"caption": "霜前的收成稳稳入了库",
	},
	{
		"id": "winter_dahan",
		"completed": 24,
		"term_name": "大寒",
		"path": "res://assets/art/commercial/dahan_result_hero_v1.png",
		"caption": "最冷的风里，暖路也接上了",
	},
]

var failures: Array[String] = []


func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _init() -> void:
	call_deferred("run_test")


func campaign_entries(completed: int) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for index in 24:
		var level_id := "campaign_level_%02d" % (index + 1)
		var term_name := "节气 %02d" % (index + 1)
		if index == 0:
			level_id = "spring_lichun"
		for climax_case in CLIMAX_HERO_CASES:
			if index == int(climax_case.completed) - 1:
				level_id = String(climax_case.id)
				term_name = String(climax_case.term_name)
				break
		entries.append({
			"id": level_id,
			"number": index + 1,
			"term_name": term_name,
			"kind": "climax" if index % 6 == 5 else "standard",
			"available": index <= completed,
			"completed": index < completed,
			"intro": "门外正好有活。",
		})
	return entries


func hive_context(completed: int, return_level_id: String, reward: int, replay := false) -> Dictionary:
	return {
		"returning": true,
		"return_level_id": return_level_id,
		"return_replay": replay,
		"reward": reward,
		"reserve": 30,
		"completed_count": completed,
		"total_count": 24,
		"journey_complete": completed == 24,
		"legacy_journey_completed": false,
		"level_entries": campaign_entries(completed),
	}


func run_test() -> void:
	var director_script := load("res://scripts/world/journey_audio_director.gd") as Script
	expect(director_script != null, "JourneyAudioDirector 脚本无法加载")
	if director_script == null:
		finish()
		return

	var director = director_script.new()
	director.transition_seconds = 1.0
	root.add_child(director)
	await process_frame
	for player in director.music_players:
		expect(player.playback_type == AudioServer.PLAYBACK_TYPE_STREAM, "Journey 音乐没有强制使用 Web 可用的流式播放")
		expect(player.bus == &"Music", "Journey 音乐没有进入可独立静音的 Music 总线")
	for layer_id in director.environment_players:
		expect(director.environment_players[layer_id].playback_type == AudioServer.PLAYBACK_TYPE_STREAM, "Journey 环境层没有强制使用 Web 可用的流式播放")
		expect(director.environment_players[layer_id].bus == &"SFX", "Journey 环境层没有进入可独立静音的 SFX 总线")

	# The shipping route table reaches all eight verified masters, plus a quiet
	# spring reprise for the ending instead of a generated placeholder track.
	var reached_paths: Dictionary = {}
	for area_id in EXPECTED_ROUTES:
		var error: Error = director.route_to(StringName(area_id), true)
		expect(error == OK, "音频路由失败：%s (%d)" % [area_id, error])
		var expected_path: String = EXPECTED_ROUTES[area_id]
		expect(director.current_track_path() == expected_path, "%s 映射错误：%s" % [area_id, director.current_track_path()])
		expect(FileAccess.file_exists(expected_path), "音乐文件不存在：%s" % expected_path)
		reached_paths[director.current_track_path()] = true
	expect(reached_paths.size() == 8, "Journey 路由必须覆盖 8 条不同季节母带，实际 %d 条" % reached_paths.size())
	var segment_aliases := {
		"spring_route": "res://assets/music/spring_explore.wav",
		"sign_incident": "res://assets/music/spring_incident.wav",
		"summer_recovery": "res://assets/music/summer_explore.wav",
		"autumn_harvest": "res://assets/music/autumn_explore.wav",
		"winter_warmth": "res://assets/music/winter_explore.wav",
		"finale_handoff": "res://assets/music/spring_explore.wav",
	}
	for segment_id in segment_aliases:
		expect(director.route_to(StringName(segment_id), true) == OK, "剧情段落没有稳定音频别名：%s" % segment_id)
		expect(director.current_track_path() == segment_aliases[segment_id], "剧情段落音频别名映射错误：%s" % segment_id)

	# Returning home keeps the last world's family, swaps incidents back to its
	# explore master, and establishes a clearly indoor environment snapshot.
	director.route_to(&"autumn_echo_incident", true)
	expect(director.current_mode == &"incident", "秋季事故段没有使用明确的 incident 音乐模式")
	director.route_to(&"hive_threshold", true)
	expect(director.current_track_path() == "res://assets/music/autumn_explore.wav", "秋季归巢没有切回秋季探索母带")
	expect(director.current_mode == &"hive", "主巢没有进入 hive 混音状态")
	expect(
		director.environment_target_db(director.LAYER_HIVE_INDOOR) > director.environment_target_db(director.LAYER_FIELD_OUTDOOR),
		"主巢必须突出巢内环境层并压低室外层"
	)
	director.route_to(&"spring_field", true)
	expect(
		director.environment_target_db(director.LAYER_FIELD_OUTDOOR) > director.environment_target_db(director.LAYER_HIVE_INDOOR),
		"春野必须突出室外环境层并压低巢内层"
	)
	var field_player_index: int = director.active_music_index
	var field_stream: AudioStream = director.music_players[field_player_index].stream
	director.route_to(&"hive_threshold", false)
	expect(director.active_music_index == field_player_index, "同季探索曲归巢时不应重启母带")
	expect(director.music_players[field_player_index].stream == field_stream, "归巢音量快照替换了同一条探索流")
	expect(director.outgoing_music_index == -1, "同曲归巢不应占用第二个音乐播放器")
	director.finish_transition()

	# Unknown ids must not silently play a plausible but wrong seasonal track.
	var before_unknown: String = director.current_track_path()
	expect(director.route_to(&"unplanned_secret_realm") == ERR_DOES_NOT_EXIST, "未知场景必须显式拒绝音频路由")
	expect(director.current_track_path() == before_unknown, "未知场景破坏了当前播放状态")

	# Crossfades retain the outgoing authored stream until the hand-off completes.
	director.route_to(&"spring_field", true)
	var first_index: int = director.active_music_index
	director.route_to(&"spring_sign_incident", false)
	var second_index: int = director.active_music_index
	expect(first_index != second_index, "跨曲切换没有使用双播放器交叉淡化")
	expect(director.outgoing_music_index == first_index, "旧曲没有保留到淡出完成")
	expect(director.music_players[first_index].stream != null, "淡出开始时旧曲已经被提前清空")
	expect(director.music_players[second_index].stream != null, "淡入开始时新曲尚未装载")
	director._advance_mix(0.5)
	expect(director.music_players[first_index].volume_db < -11.5, "交叉淡化中点没有压低旧曲")
	expect(director.music_players[second_index].volume_db > director.SILENCE_DB, "交叉淡化中点没有抬起新曲")
	expect(director.music_players[first_index].volume_db > -30.0, "交叉淡化错误地在线性 dB 中点形成静音坑")
	expect(director.music_players[second_index].volume_db > -30.0, "淡入曲在线性 dB 中点几乎听不见")
	director._advance_mix(0.5)
	expect(director.outgoing_music_index == -1, "交叉淡化结束后仍保留旧播放器")
	expect(director.music_players[first_index].stream == null, "交叉淡化结束后旧曲资源未释放")
	expect(is_equal_approx(director.music_players[second_index].volume_db, -11.5), "事故曲最终音量不符合路由快照")

	# Sound settings, OS focus and game pause are independent playback gates. A
	# route remains loaded while suspended so focus return resumes instead of
	# restarting the composition.
	director.set_focus_active(false)
	expect(not director.is_playback_audible(), "失焦后音频门仍为开启")
	expect(director.music_players[director.active_music_index].stream_paused, "失焦后当前音乐没有暂停")
	for layer_id in director.environment_players:
		expect(director.environment_players[layer_id].stream_paused, "失焦后环境循环没有暂停：%s" % layer_id)
	director.set_focus_active(true)
	expect(director.is_playback_audible(), "重新聚焦后音频门没有恢复")
	director.set_game_paused(true)
	expect(not director.is_playback_audible(), "游戏暂停后音频门仍为开启")
	expect(director.music_players[director.active_music_index].stream_paused, "游戏暂停没有暂停当前音乐")
	director.set_game_paused(false)
	director.set_enabled(false)
	expect(not director.is_playback_audible(), "声音关闭后音频门仍为开启")
	director.set_enabled(true)
	expect(director.is_playback_audible(), "声音重新开启后当前路由没有恢复")

	# Both shipping environment layers start from the checked-in project-owned
	# candidates. They remain replaceable through the public seam for later mix
	# approval; neither layer is a procedural/simple-tone placeholder.
	var ambience_paths := {
		director.LAYER_HIVE_INDOOR: "res://assets/audio/commercial/hive_room_loop.wav",
		director.LAYER_FIELD_OUTDOOR: "res://assets/audio/commercial/field_day_loop.wav",
	}
	for layer_id in ambience_paths:
		var source := load(String(ambience_paths[layer_id])) as AudioStreamWAV
		var runtime_stream := director.environment_stream(layer_id) as AudioStreamWAV
		expect(source != null, "环境候选文件无法加载：%s" % ambience_paths[layer_id])
		expect(runtime_stream != null, "Journey 没有默认接入环境候选：%s" % layer_id)
		if runtime_stream != null:
			expect(runtime_stream.mix_rate == 44100 and runtime_stream.stereo, "环境候选不是 44.1 kHz 立体声：%s" % layer_id)
			expect(runtime_stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "环境候选没有设置正向循环：%s" % layer_id)
			expect(runtime_stream.loop_begin == 0 and runtime_stream.loop_end > 0, "环境候选循环区间无效：%s" % layer_id)
	expect(
		FileAccess.get_sha256(String(ambience_paths[director.LAYER_HIVE_INDOOR]))
		!= FileAccess.get_sha256(String(ambience_paths[director.LAYER_FIELD_OUTDOOR])),
		"巢内与野外环境循环错误复用了同一份声音"
	)
	var replacement_ambience := load("res://assets/audio/commercial/hive_room_loop.wav") as AudioStream
	director.set_enabled(false)
	expect(director.set_environment_stream(director.LAYER_FIELD_OUTDOOR, replacement_ambience) == OK, "室外环境层无法替换候选流")
	expect(director.environment_stream(director.LAYER_FIELD_OUTDOOR) is AudioStreamWAV, "室外环境层没有保留替换后的 WAV 流")
	expect(
		is_equal_approx(
			director.environment_players[director.LAYER_FIELD_OUTDOOR].volume_db,
			director.environment_target_db(director.LAYER_FIELD_OUTDOOR)
		),
		"后接入的环境流没有采用当前场景混音快照"
	)
	expect(director.set_environment_stream(&"unknown_layer", replacement_ambience) == ERR_DOES_NOT_EXIST, "未知环境层没有被拒绝")

	# A hive return is a three-beat authored result, not a single completion blip.
	# Climaxes add a relay answer and a final physical tray-settle beat, while the
	# reduced-motion version keeps the same result information on a shorter clock.
	director.set_enabled(true)
	expect(director.hive_result_players.size() == 3, "返巢结果没有独立的一次性音效声部")
	for player in director.hive_result_players:
		expect(player.playback_type == AudioServer.PLAYBACK_TYPE_SAMPLE, "返巢短音效没有走 Web 低延迟采样路径")
		expect(player.bus == &"SFX", "返巢结果音效没有进入可独立静音的 SFX 总线")
	expect(director.begin_hive_result(false) == OK, "普通关返巢结果无法开始")
	expect(director.hive_result_cue_log == [&"arrival"], "普通关没有从接住货物的第一拍开始")
	director._process(0.50)
	expect(director.hive_result_cue_log.size() == 2 and director.hive_result_cue_log[-1] == &"relay", "普通关接货链没有第二拍传递声")
	director._process(0.80)
	expect(director.hive_result_cue_log.size() == 3 and director.hive_result_cue_log[-1] == &"group_response", "普通关缺少群蜂收货响应")
	for path in director.HIVE_RESULT_CUE_PATHS.values():
		expect(FileAccess.file_exists(String(path)), "返巢结果复用的商业音效不存在：%s" % path)
	director.finish_hive_result()
	expect(not director.hive_result_active(), "普通关结果结束后仍占用音频时间线")
	expect(director.begin_hive_result(true) == OK, "高潮关返巢结果无法开始")
	director._process(0.90)
	expect(director.hive_result_cue_log.size() == 3, "高潮关接货队没有形成前后呼应")
	director._process(0.60)
	expect(director.hive_result_cue_log[-1] == &"group_response", "高潮关没有在接货链后形成群蜂响应")
	director._process(0.70)
	expect(director.hive_result_cue_log.size() == 5 and director.hive_result_cue_log[-1] == &"tray_settle", "高潮关缺少更强的最终入库落点")
	director.finish_hive_result()
	director.begin_hive_result(false, true)
	director._process(0.95)
	expect(director.hive_result_cue_log.size() == 2, "减少动态错误压缩了返巢结果音频时钟")
	director._process(0.40)
	expect(
		director.hive_result_cue_log.size() == 3 and director.hive_result_cue_log[-1] == &"group_response",
		"减少动态没有保留完整、等时长的返巢音频信息"
	)
	director.finish_hive_result()
	director.begin_hive_result(false)
	var cue_count_before_focus_loss: int = director.hive_result_cue_log.size()
	director.set_focus_active(false)
	director._process(2.0)
	expect(director.hive_result_cue_log.size() == cue_count_before_focus_loss, "失焦时返巢音效时间线仍在后台偷跑")
	director.set_focus_active(true)
	director.finish_hive_result()

	# Exercise the hive-owned visual contract in the same shipping test without
	# adding a second runner entry. Each sixth seasonal return owns one reviewed
	# commercial hero; standard, stale and replay results never claim that beat.
	var hive_game := Node.new()
	var hive_director = director_script.new()
	hive_director.name = "JourneyAudioDirector"
	var hive_host := Node2D.new()
	hive_host.name = "AreaHost"
	hive_game.add_child(hive_director)
	hive_game.add_child(hive_host)
	root.add_child(hive_game)
	var hive_script := load("res://scripts/world/journey_campaign_hive.gd") as Script
	expect(hive_script != null, "JourneyCampaignHive 脚本无法加载")
	if hive_script != null:
		for climax_case in CLIMAX_HERO_CASES:
			var hero_texture := load(String(climax_case.path)) as Texture2D
			expect(hero_texture != null, "季度高潮插画无法加载：%s" % climax_case.path)
			if hero_texture != null:
				expect(hero_texture.get_size() == Vector2(1672, 941), "季度高潮插画没有保留 1672 x 941 源尺寸：%s" % climax_case.path)
		var invalid_replay_hive = hive_script.new()
		expect(
			invalid_replay_hive.configure(hive_context(24, "spring_guyu", 8, true)) == ERR_INVALID_DATA,
			"重飞结果仍可携带并绘制伪造的新奖励"
		)
		invalid_replay_hive.free()
		# JourneyCampaignGame creates the hub before settlement, then reconfigures
		# that already-ready instance with the committed result.  Protect that real
		# lifecycle; direct construction with a final context alone is insufficient.
		var lifecycle_hive = hive_script.new()
		var preview_context := hive_context(5, "spring_guyu", 0)
		preview_context["returning"] = false
		preview_context["return_level_id"] = ""
		preview_context["reward"] = 0
		preview_context["level_entries"] = campaign_entries(5)
		expect(lifecycle_hive.configure(preview_context) == OK, "结算前蜂巢预览配置失败")
		hive_host.add_child(lifecycle_hive)
		await process_frame
		expect(lifecycle_hive._hero_layer == null, "结算前蜂巢预览提前加载了高潮插画")
		expect(
			lifecycle_hive.configure(hive_context(6, "spring_guyu", 8)) == OK,
			"已 ready 的蜂巢不能接收谷雨结算上下文"
		)
		await process_frame
		expect(
			lifecycle_hive._hero_layer != null
				and lifecycle_hive._hero_layer.visible
				and lifecycle_hive._hero_image.texture.resource_path == String(CLIMAX_HERO_CASES[0].path),
			"真实预览→结算重配流程没有懒加载并显示高潮插画"
		)
		lifecycle_hive.skip_receiving_presentation()
		lifecycle_hive.queue_free()
		await process_frame

		var climax_hive = hive_script.new()
		expect(climax_hive.configure(hive_context(6, "spring_guyu", 8)) == OK, "谷雨返巢结果配置失败")
		hive_host.add_child(climax_hive)
		await process_frame
		await process_frame
		var climax_snapshot: Dictionary = climax_hive.result_snapshot()
		expect(climax_snapshot.strength == &"climax", "谷雨没有进入高潮强度的接货演出")
		expect(climax_hive.presentation_duration == climax_hive.CLIMAX_RECEIVING_DURATION, "高潮返巢没有获得更完整的演出时长")
		expect(Rect2(climax_snapshot.visible_stage_rect).position.x >= 960.0, "结果轨道仍藏在 930px 关卡板后面")
		expect(
			int(climax_snapshot.completed_cell) == 5
				and int(climax_snapshot.return_level_index) == 5
				and int(climax_snapshot.reward) == 8
				and int(climax_snapshot.visible_reward_count) == 8,
			"右侧结果轨道没有使用谷雨实际索引或完整画出 8 份奖励"
		)
		expect(climax_hive._uses_return_hero(), "谷雨首次收尾没有选择季度高潮插画")
		expect(climax_hive._hero_layer != null and climax_hive._hero_layer.visible, "谷雨商业结果卡没有在 UI 上层出现")
		expect(climax_hive._hero_skip_button != null, "谷雨结果卡没有为鼠标提供整幅可跳过表面")
		expect(
			climax_hive._hero_caption_scrim != null
				and climax_hive._hero_caption_scrim.color.a >= 0.6
				and climax_hive._hero_caption_scrim.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"季度结果字幕没有稳定的深色底板，或底板错误吞掉了鼠标输入"
		)
		expect(
			climax_hive._hero_image.texture.resource_path == String(CLIMAX_HERO_CASES[0].path)
				and String(CLIMAX_HERO_CASES[0].caption) in climax_hive._hero_caption.text,
			"谷雨结果卡没有使用对应插画与专属结果文案"
		)
		expect(hive_director.hive_result_active(), "蜂巢没有启动分段返巢音频")
		var remaining_before_reduce: float = climax_hive.presentation_time
		climax_hive.set_reduce_motion(true)
		expect(is_zero_approx(float(climax_hive.result_snapshot().motion_scale)), "减少动态仍在移动返巢蜂群")
		expect(
			is_equal_approx(climax_hive.presentation_duration, climax_hive.CLIMAX_RECEIVING_DURATION)
				and is_equal_approx(climax_hive.presentation_time, remaining_before_reduce)
				and hive_director.hive_result_active(),
			"中途开启减少动态缩短了演出或截断了返巢音频"
		)
		climax_hive._on_settings_changed({"ui_scale": 1.3, "reduce_motion": true})
		expect(
			climax_hive._hero_caption != null
				and climax_hive._hero_caption.get_theme_font_size("font_size") == 39
				and climax_hive._hero_caption.size.y >= 120.0,
			"结果插画字幕没有随 130% UI 缩放并保留两行高度"
		)
		var finish_holder := {"count": 0}
		climax_hive.presentation_finished.connect(func(): finish_holder.count = int(finish_holder.count) + 1)
		expect(not climax_hive.request_selected_sortie(), "第一次互动跳过结果时错误启动了下一关")
		expect(int(finish_holder.count) == 1 and not bool(climax_hive.result_snapshot().skippable), "结果卡无法一次跳过或重复发出结束信号")
		expect(not climax_hive._hero_layer.visible and not hive_director.hive_result_active(), "跳过结果后插画或音频仍遮住蜂巢")
		expect(climax_hive.request_selected_sortie(), "跳过结果后的第二次互动无法正常出发")
		climax_hive.queue_free()
		await process_frame

		for case_index in range(1, CLIMAX_HERO_CASES.size()):
			var climax_case: Dictionary = CLIMAX_HERO_CASES[case_index]
			var seasonal_climax_hive = hive_script.new()
			expect(
				seasonal_climax_hive.configure(
					hive_context(int(climax_case.completed), String(climax_case.id), 8)
				) == OK,
				"季度高潮返巢结果配置失败：%s" % climax_case.id
			)
			hive_host.add_child(seasonal_climax_hive)
			await process_frame
			await process_frame
			expect(seasonal_climax_hive._uses_return_hero(), "首次季度高潮没有选择结果插画：%s" % climax_case.id)
			expect(
				seasonal_climax_hive._hero_layer != null
					and seasonal_climax_hive._hero_layer.visible
					and seasonal_climax_hive._hero_image.texture.resource_path == String(climax_case.path),
				"首次季度高潮没有显示对应的商业结果卡：%s" % climax_case.id
			)
			expect(
				String(climax_case.term_name) in seasonal_climax_hive._hero_caption.text
					and String(climax_case.caption) in seasonal_climax_hive._hero_caption.text,
				"季度高潮没有使用对应节气与结果文案：%s" % climax_case.id
			)
			seasonal_climax_hive.skip_receiving_presentation()
			seasonal_climax_hive.queue_free()
			await process_frame

		var standard_hive = hive_script.new()
		expect(standard_hive.configure(hive_context(7, "spring_lichun", 8)) == OK, "普通返巢结果配置失败")
		hive_host.add_child(standard_hive)
		await process_frame
		expect(standard_hive.presentation_strength == &"standard", "普通关错误升级成高潮返巢")
		expect(not standard_hive._uses_return_hero(), "季度高潮插画错误出现在普通关")
		expect(standard_hive._hero_layer == null, "普通关不应加载或创建季度高潮插画层")
		expect(
			int(standard_hive.result_snapshot().completed_cell) == 0
				and int(standard_hive.result_snapshot().visible_reward_count) == 8,
			"普通返巢错误使用 completed_count-1 或漏画第八份奖励"
		)
		standard_hive._process(standard_hive.RECEIVING_DURATION + 0.1)
		expect(standard_hive.presentation_phase() == &"settled", "普通接货演出结束后没有停在可见结果态")
		standard_hive.queue_free()
		await process_frame

		var stale_climax_hive = hive_script.new()
		expect(stale_climax_hive.configure(hive_context(12, "spring_guyu", 0)) == OK, "非当前进度高潮上下文配置失败")
		expect(not stale_climax_hive._uses_return_hero(), "非当前进度高潮错误重播了首次收尾插画")
		stale_climax_hive.free()

		for climax_case in CLIMAX_HERO_CASES:
			var replay_hive = hive_script.new()
			expect(
				replay_hive.configure(hive_context(24, String(climax_case.id), 0, true)) == OK,
				"季度高潮重飞结果配置失败：%s" % climax_case.id
			)
			hive_host.add_child(replay_hive)
			await process_frame
			var replay_snapshot: Dictionary = replay_hive.result_snapshot()
			expect(
				bool(replay_snapshot.replay)
					and int(replay_snapshot.return_level_index) == int(climax_case.completed) - 1
					and int(replay_snapshot.completed_cell) == -1
					and int(replay_snapshot.visible_reward_count) == 0,
				"重飞没有保留实际关卡索引，或伪造了最后完成格/新奖励：%s" % climax_case.id
			)
			expect(not replay_hive._uses_return_hero(), "季度高潮重飞误播了首次收尾结果卡：%s" % climax_case.id)
			expect(replay_hive._hero_layer == null, "季度高潮重飞不应加载或创建首次收尾插画层：%s" % climax_case.id)
			expect("重飞" in replay_hive.body_text() and "没有重复发货" in replay_hive.body_text(), "重飞结果文案没有使用显式 replay 语义")
			replay_hive.queue_free()
			await process_frame
	hive_game.queue_free()
	await process_frame

	# The production scene owns the director as an independent child and its
	# deferred binder follows the Journey router's initial main-hive scene.
	director.queue_free()
	await process_frame
	var journey_scene := load("res://journey.tscn") as PackedScene
	expect(journey_scene != null, "Journey 正式场景无法加载")
	if journey_scene != null:
		var journey = journey_scene.instantiate()
		root.add_child(journey)
		await process_frame
		await process_frame
		var scene_director = journey.get_node_or_null("JourneyAudioDirector")
		expect(scene_director != null, "Journey 正式场景没有接入音频导演")
		if scene_director != null:
			expect(scene_director.current_area_id == &"hive_threshold", "音频导演没有自动跟随初始主巢路由")
			expect(scene_director.current_track_path() == "res://assets/music/spring_explore.wav", "初始主巢没有使用轻量春季探索母带")
		journey.queue_free()
		await process_frame

	finish()


func finish() -> void:
	if failures.is_empty():
		print("JOURNEY AUDIO DIRECTOR TEST PASSED: 8 authored masters and 2 project-owned ambience candidates route with crossfades and focus gates")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
