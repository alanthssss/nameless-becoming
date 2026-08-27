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

var failures: Array[String] = []


func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _init() -> void:
	call_deferred("run_test")


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
