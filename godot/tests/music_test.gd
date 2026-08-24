extends SceneTree

const TRACK_PATHS := [
	["res://assets/music/spring_explore.wav", "res://assets/music/spring_boss.wav"],
	["res://assets/music/summer_explore.wav", "res://assets/music/summer_boss.wav"],
	["res://assets/music/autumn_explore.wav", "res://assets/music/autumn_boss.wav"],
	["res://assets/music/winter_explore.wav", "res://assets/music/winter_boss.wav"],
]

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
				expect(stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "音乐未设置为向前循环：%s" % actual_path)
				expect(stream.loop_begin == 0 and stream.loop_end > 0, "音乐循环区间无效：%s" % actual_path)
			var digest := FileAccess.get_sha256(actual_path)
			expect(not digest.is_empty(), "无法计算音乐哈希：%s" % actual_path)
			unique_paths[actual_path] = true
			unique_hashes[digest] = actual_path

	expect(unique_paths.size() == 8, "四季探索/Boss 应映射到 8 个不同路径，实际 %d 个" % unique_paths.size())
	expect(unique_hashes.size() == 8, "8 个音乐文件内容不应复用，实际只有 %d 个唯一哈希" % unique_hashes.size())

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
		print("MUSIC TEST PASSED: 4 exploration and 4 boss tracks are loadable and unique")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
