extends SceneTree

const JourneyScene := preload("res://journey.tscn")
const SoundFeedbackScript := preload("res://scripts/sound_feedback.gd")
const MANIFEST_PATH := "res://assets/audio/commercial/manifest.json"
const COMMERCIAL_AUDIO_ROOT := "res://assets/audio/commercial"
const SHIPPING_CUE_SOURCES: Array[String] = [
	"res://scripts/world/journey_game.gd",
	"res://scripts/world/spring_journey_field.gd",
	"res://scripts/world/spring_sign_incident.gd",
	"res://scripts/world/summer_journey_field.gd",
	"res://scripts/world/autumn_journey_field.gd",
	"res://scripts/world/winter_journey_field.gd",
	"res://scripts/world/finale_handoff_field.gd",
	"res://scripts/mechanics/pollination_mechanic.gd",
]
const REQUIRED_JOURNEY_CUES: Array[String] = [
	"harvest",
	"pollinate",
	"sense",
	"evade",
	"honey_loss",
	"repair",
	"seed",
	"seed_shell_rustle",
	"warmth_link",
	"carry_log",
	"handoff",
	"complete",
]

var failures: Array[String] = []


func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _init() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var manifest_value = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	expect(manifest_value is Dictionary, "商业音频清单无法解析")
	var manifest: Dictionary = manifest_value if manifest_value is Dictionary else {}
	var assets = manifest.get("assets", [])
	expect(assets is Array and assets.size() == 16, "商业音频清单没有恰好列出 14 条动作音效和 2 条环境循环")
	var manifest_paths: Dictionary = {}
	var ambience_count := 0
	if assets is Array:
		for raw_asset in assets:
			if not raw_asset is Dictionary:
				expect(false, "商业音频清单含非对象条目")
				continue
			var asset: Dictionary = raw_asset
			var path := "%s/%s" % [COMMERCIAL_AUDIO_ROOT, String(asset.get("file", ""))]
			var stream := load(path) as AudioStreamWAV
			expect(not manifest_paths.has(path), "商业音频清单重复路径：%s" % path)
			manifest_paths[path] = true
			expect(FileAccess.file_exists(path), "商业音频源文件不存在：%s" % path)
			expect(FileAccess.get_sha256(path) == String(asset.get("sha256", "")), "商业音频清单哈希过期：%s" % path)
			expect(stream != null, "Godot 无法装载商业音频：%s" % path)
			if stream != null:
				expect(stream.mix_rate == 44100 and stream.stereo, "商业音频运行时不是 44.1 kHz 立体声：%s" % path)
				expect(stream.get_length() > 0.15, "商业音频运行时长度无效：%s" % path)
			if String(asset.get("kind", "")) == "ambience":
				ambience_count += 1
				expect(bool(asset.get("loop", false)), "环境声没有循环声明：%s" % path)
				expect(stream != null and stream.get_length() >= 9.9, "环境循环不足十秒：%s" % path)
			else:
				expect(not bool(asset.get("loop", true)), "一次性音效错误声明为循环：%s" % path)
	expect(ambience_count == 2, "商业音频清单必须恰好包含巢内与野外两条环境循环")
	expect(
		String(manifest.get("candidate_status", "")).find("requires Alan approval and device mix confirmation") >= 0
		and String(manifest.get("candidate_status", "")).find("not a recording or final master") >= 0,
		"运行时清单没有保留 Alan/设备混音确认与非录音非终稿边界"
	)

	var feedback: SoundFeedback = SoundFeedbackScript.new()
	var generator_player: AudioStreamPlayer = feedback._new_output_player()
	var asset_player: AudioStreamPlayer = feedback._new_asset_player()
	expect(generator_player.playback_type == AudioServer.PLAYBACK_TYPE_STREAM, "程序化旧回退没有使用 Web 流式路径")
	expect(generator_player.stream is AudioStreamGenerator, "程序化旧回退丢失生成器")
	expect(asset_player.playback_type == AudioServer.PLAYBACK_TYPE_SAMPLE, "短动作音效没有使用 Web 低延迟样本路径")
	expect(generator_player.bus == &"SFX" and asset_player.bus == &"SFX", "动作音效没有统一进入 SFX 总线")
	generator_player.free()
	asset_player.free()

	var cue_pattern := RegEx.new()
	expect(cue_pattern.compile("play_cue\\(\"([a-z_]+)\"\\)") == OK, "动作音效调用扫描器无法建立")
	var shipping_cues: Dictionary = {}
	for source_path in SHIPPING_CUE_SOURCES:
		var source_text := FileAccess.get_file_as_string(source_path)
		var matches := cue_pattern.search_all(source_text)
		expect(matches.size() == source_text.count("play_cue("), "Journey 出现无法静态验资的动态音效调用：%s" % source_path)
		for cue_match in matches:
			var cue := cue_match.get_string(1)
			shipping_cues[cue] = true
			feedback.play_cue(cue)
			expect(feedback.last_cue_used_asset, "Journey 动作落到程序化旧回退：%s" % cue)
			expect(feedback.last_asset_path == feedback.cue_asset_path(cue), "Journey 动作解析了错误资产：%s" % cue)
			expect(manifest_paths.has(feedback.last_asset_path), "Journey 动作引用清单外资产：%s" % cue)
			expect(feedback.asset_stream_for_cue(cue) != null, "Journey 动作资产无法装载：%s" % cue)
	for cue in REQUIRED_JOURNEY_CUES:
		expect(shipping_cues.has(cue), "商业旅程缺少关键动作音效调用：%s" % cue)

	# The fallback is deliberately retained for legacy callers, but every literal
	# cue reachable from the commercial Journey above has already resolved to an
	# asset. Caching a failed load exercises that compatibility path without
	# changing the checked-in cue table.
	var fallback_path := feedback.cue_asset_path("harvest")
	feedback.asset_streams[fallback_path] = null
	feedback.play_cue("harvest")
	expect(not feedback.last_cue_used_asset and feedback.last_cue == "harvest", "动作资产缺失时没有保留旧回退路径")
	feedback.free()

	var sfx_bus_index := AudioServer.get_bus_index(&"SFX")
	expect(sfx_bus_index >= 0, "商业启动没有建立可独立控制的 SFX 总线")
	if sfx_bus_index >= 0:
		var previous_mute := AudioServer.is_bus_mute(sfx_bus_index)
		AudioServer.set_bus_mute(sfx_bus_index, true)
		expect(AudioServer.is_bus_mute(sfx_bus_index), "SFX 总线无法独立静音")
		AudioServer.set_bus_mute(sfx_bus_index, previous_mute)

	# Areas are freed at every map transition, so Journey must pass one persistent
	# feedback node into each field instead of constructing a voice pool per map.
	var game = JourneyScene.instantiate()
	game.transition_duration = 0.0
	root.add_child(game)
	await process_frame
	game._begin_sortie()
	await process_frame
	await process_frame
	expect(game.sound != null, "Journey 正式场景没有共享动作音效节点")
	expect(game.router.current_area_id == "spring_field", "商业音频测试无法进入春野")
	if game.router.current_area is SpringJourneyField:
		expect((game.router.current_area as SpringJourneyField).sound == game.sound, "场景切换没有复用 Journey 的共享动作音效节点")
	game.queue_free()
	await process_frame

	finish()


func finish() -> void:
	if failures.is_empty():
		print("COMMERCIAL AUDIO TEST PASSED: 14 deterministic SFX candidates and 2 ambience loops cover every shipping Journey cue")
		print("TEST PASSED")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
