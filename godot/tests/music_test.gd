extends SceneTree

const TRACK_PATHS := [
	["res://assets/music/spring_explore.wav", "res://assets/music/spring_boss.wav"],
	["res://assets/music/summer_explore.wav", "res://assets/music/summer_boss.wav"],
	["res://assets/music/autumn_explore.wav", "res://assets/music/autumn_boss.wav"],
	["res://assets/music/winter_explore.wav", "res://assets/music/winter_boss.wav"],
]
const EXPECTED_DURATIONS := [
	[27.692313, 25.945941],
	[24.827596, 22.325578],
	[28.571429, 22.857143],
	[26.666667, 30.0],
]
const ANALYSIS_PATH := "res://assets/music/analysis.json"

var failures: Array[String] = []


func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _init() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var director_script := load("res://scripts/music_director.gd") as Script
	expect(director_script != null, "MusicDirector 脚本无法加载")
	if director_script == null:
		finish()
		return

	var director = director_script.new()
	root.add_child(director)
	await process_frame
	# Mapping/load verification does not need an audio device or active playback.
	director.set_enabled(false)

	var unique_paths: Dictionary = {}
	var unique_hashes: Dictionary = {}
	for family_index in TRACK_PATHS.size():
		for mode_index in 2:
			if mode_index == 0:
				director.enter_explore(family_index)
			else:
				director.enter_boss(family_index)
			var expected_path: String = TRACK_PATHS[family_index][mode_index]
			var actual_path: String = director.current_track_path()
			expect(actual_path == expected_path, "音乐映射错误：期望 %s，实际 %s" % [expected_path, actual_path])
			expect(FileAccess.file_exists(actual_path), "音乐文件不存在：%s" % actual_path)
			var stream := load(actual_path) as AudioStreamWAV
			expect(stream != null, "音乐文件无法作为 AudioStreamWAV 加载：%s" % actual_path)
			if stream != null:
				expect(stream.resource_path == actual_path, "MusicDirector 复用了错误资源：%s" % actual_path)
				expect(director.player.stream == stream, "MusicDirector 未播放映射资源：%s" % actual_path)
				expect(stream.mix_rate == 44100, "音乐必须为 44.1kHz：%s" % actual_path)
				expect(stream.stereo, "音乐必须为立体声：%s" % actual_path)
				expect(absf(stream.get_length() - float(EXPECTED_DURATIONS[family_index][mode_index])) < 0.002,
					"音乐时长必须来自完整小节：%s" % actual_path)
				expect(stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "音乐未设置为向前循环：%s" % actual_path)
				expect(stream.loop_begin == 0 and stream.loop_end > 0, "音乐循环区间无效：%s" % actual_path)
				if mode_index == 1:
					expect(is_equal_approx(director.player.pitch_scale, 1.0), "Boss 音乐不应再被全局降调：%s" % actual_path)
			var digest := FileAccess.get_sha256(actual_path)
			expect(not digest.is_empty(), "无法计算音乐哈希：%s" % actual_path)
			unique_paths[actual_path] = true
			unique_hashes[digest] = actual_path

	expect(unique_paths.size() == 8, "四季探索/Boss 应映射到 8 个不同路径，实际 %d 个" % unique_paths.size())
	expect(unique_hashes.size() == 8, "8 个音乐文件内容不应复用，实际只有 %d 个唯一哈希" % unique_hashes.size())

	# Hashes prove only that bytes differ.  The durable analysis also gates the
	# low-mid drone, click-free seams, stereo field, dynamics and pair separation.
	expect(FileAccess.file_exists(ANALYSIS_PATH), "缺少音乐客观分析：%s" % ANALYSIS_PATH)
	var analysis_text := FileAccess.get_file_as_string(ANALYSIS_PATH)
	var analysis = JSON.parse_string(analysis_text)
	expect(typeof(analysis) == TYPE_DICTIONARY, "音乐分析 JSON 无法解析")
	if typeof(analysis) == TYPE_DICTIONARY:
		var report: Dictionary = analysis
		expect(bool(report.get("passed", false)), "音乐分析门禁未通过：%s" % str(report.get("failures", [])))
		var thresholds: Dictionary = report.get("thresholds", {})
		var track_metrics: Dictionary = report.get("tracks", {})
		expect(track_metrics.size() == 8, "音乐分析必须覆盖 8 轨")
		for track_name in track_metrics:
			var metrics: Dictionary = track_metrics[track_name]
			var analyzed_path := "res://assets/music/%s.wav" % track_name
			expect(FileAccess.get_sha256(analyzed_path) == String(metrics.get("source_sha256", "")), "%s 的分析报告已过期" % track_name)
			expect(int(metrics.get("sample_rate", 0)) == 44100, "%s 分析采样率错误" % track_name)
			expect(int(metrics.get("channels", 0)) == 2, "%s 分析声道错误" % track_name)
			expect(int(metrics.get("frames", -1)) == int(metrics.get("expected_frames", -2)), "%s 不是整数小节渲染" % track_name)
			expect(float(metrics.get("loop_seam_dbfs", 0.0)) <= float(thresholds.get("max_loop_seam_dbfs", -50.0)), "%s 循环接缝可能点击" % track_name)
			expect(float(metrics.get("low_mid_40_250_share", 1.0)) <= float(thresholds.get("max_low_mid_share", 0.7)), "%s 低中频再次堆积" % track_name)
			expect(float(metrics.get("low_mid_occupancy", 1.0)) <= float(thresholds.get("max_low_mid_occupancy", 0.8)), "%s 出现持续低频地毯" % track_name)
			expect(float(metrics.get("active_dynamic_range_db", 0.0)) >= float(thresholds.get("min_active_dynamic_range_db", 3.0)), "%s 缺乏呼吸和留白" % track_name)
		var similarities: Dictionary = report.get("same_season_explore_boss_cosine", {})
		for season_name in similarities:
			expect(float(similarities[season_name]) <= float(thresholds.get("max_same_season_cosine", 0.92)), "%s 探索/Boss 听感骨架仍过近" % season_name)

	director.enter_boss(3)
	director.set_boss_tuning_progress(0)
	expect(is_equal_approx(director.player.pitch_scale, 1.0), "Boss 调律 0 不应降低整曲音高")
	director.set_boss_tuning_progress(3)
	expect(is_equal_approx(director.player.pitch_scale, 1.0), "Boss 调律完成不应依赖恢复全局音高")

	# Hive reuses the current family's exploration arrangement, never its Boss file.
	director.enter_boss(2)
	director.enter_hive()
	expect(director.current_track_path() == TRACK_PATHS[2][0], "蜂巢状态错误复用了 Boss 音轨")
	expect(director.player.stream != null and director.player.stream.resource_path == TRACK_PATHS[2][0], "蜂巢状态未切回本季探索音轨")

	# Existing callers may still invoke SoundFeedback.set_season during migration.
	var feedback_script := load("res://scripts/sound_feedback.gd") as Script
	expect(feedback_script != null, "SoundFeedback 脚本无法加载")
	if feedback_script != null:
		var feedback = feedback_script.new()
		feedback.set_season(-1)
		feedback.set_season(99)
		feedback.free()

	director.queue_free()
	await process_frame
	finish()


func finish() -> void:
	if failures.is_empty():
		print("MUSIC TEST PASSED: 8 stereo arrangements are bar-aligned, distinct and free of the continuous low-mid drone")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
