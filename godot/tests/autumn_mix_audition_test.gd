extends SceneTree

const MainScene := preload("res://main.tscn")
const AuditionScript := preload("res://tools/autumn_mix_audition.gd")
const EphemeralSaveManagerScript := preload("res://tools/ephemeral_save_manager.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("run")


func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func run() -> void:
	var game = MainScene.instantiate()
	var ephemeral = EphemeralSaveManagerScript.new()
	game.save_manager = ephemeral
	game.persistence_enabled = false
	root.add_child(game)
	await process_frame

	expect(ephemeral.load_calls == 1, "内部工具没有在 main._ready 前替换磁盘 SaveManager")
	expect(ephemeral.save_calls == 0, "内部工具初始化不应写入任何存档")
	game.tutorial_complete = true
	game.start_game()
	expect(game.stage_index == 0 and game.phase == "playing", "普通 start_game 不再从首节点开始")
	expect(not game.persistence_enabled, "内部工具意外启用了持久化")

	var explore_index: int = AuditionScript.target_stage_index(game.stages, "explore")
	expect(explore_index >= 0, "找不到秋季野外节点")
	if explore_index >= 0:
		game.spawn_stage(explore_index)
		expect(game.phase == "playing", "秋野入口没有进入 playing")
		expect(game.current_flower_set() == "autumn", "秋野入口没有使用秋季花型")
		expect(game.music.family == 2, "秋野入口没有路由到 autumn family")
		expect(game.music.current_track_path() == "res://assets/music/autumn_explore.wav", "秋野入口音乐路由错误")
		expect(not game.persistence_enabled, "秋野入口重新启用了持久化")

	var boss_index: int = AuditionScript.target_stage_index(game.stages, "boss")
	expect(boss_index >= 0, "找不到秋分画眉 Boss 节点")
	if boss_index >= 0:
		game.spawn_stage(boss_index)
		AuditionScript.prepare_target_state(game, "boss")
		expect(game.phase == "boss", "秋 Boss 入口没有进入 boss")
		expect(String(game.current_boss_data.get("id", "")) == "thrush", "秋 Boss 入口没有进入失律之画眉")
		expect(game.music.family == 2, "秋 Boss 入口没有路由到 autumn family")
		expect(game.music.current_track_path() == "res://assets/music/autumn_boss.wav", "秋 Boss 入口音乐路由错误")
		expect(game.bee.energy == AuditionScript.BOSS_AUDITION_ENERGY, "Boss 内部工具没有延长体力")
		expect(not game.persistence_enabled, "秋 Boss 入口重新启用了持久化")

	expect(AuditionScript.target_stage_index(game.stages, "unknown") == -1, "未知模式没有被拒绝")
	var explore_banner: String = AuditionScript.banner_text("explore", "v0.9.5-rc.2 · deadbeef")
	var boss_banner: String = AuditionScript.banner_text("boss", "v0.9.5-rc.2 · deadbeef")
	expect(explore_banner.contains("内部音乐复查") and explore_banner.contains("不计玩法/流程通过") and explore_banner.contains("秋野"), "秋野水印缺少证据边界")
	expect(boss_banner.contains("内部音乐复查") and boss_banner.contains("不计玩法/流程通过") and boss_banner.contains("秋 Boss"), "秋 Boss 水印缺少证据边界")
	expect(ephemeral.save_calls == 0, "内部流程写入了正式存档")

	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("AUTUMN MIX AUDITION TEST PASSED")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
