extends SceneTree

const FixtureScript := preload("res://tests/playtest_fixture.gd")

var failures: Array[String] = []
var fixture_helper = FixtureScript.new()
var user_root := ""

func _init() -> void:
	ProjectSettings.set_setting("application/config/use_custom_user_dir", true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name", "nameless-save-tests-%d" % OS.get_process_id())
	user_root = ProjectSettings.globalize_path("user://")
	call_deferred("run_test")

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func file_sha(path: String) -> String:
	return FileAccess.get_sha256(path) if FileAccess.file_exists(path) else ""

func run_test() -> void:
	DirAccess.make_dir_recursive_absolute(user_root)
	var normal := ConfigFile.new()
	normal.set_value("progress", "best_stage", 41)
	normal.set_value("sentinel", "must_remain", "ordinary-save")
	expect(normal.save(NamelessSaveManager.DEFAULT_SAVE_PATH) == OK, "无法写入隔离测试普通 sentinel")
	var normal_path := ProjectSettings.globalize_path(NamelessSaveManager.DEFAULT_SAVE_PATH)
	var normal_sha := file_sha(normal_path)

	var ticket_sha := "1".repeat(64)
	var session_path := "user://nameless-playtest-%s.cfg" % ticket_sha
	var session := ConfigFile.new()
	session.set_value("progress", "best_stage", 7)
	session.set_value("progress", "runs_started", 2)
	expect(session.save(session_path) == OK, "无法写入隔离测试 session save")

	var manager := NamelessSaveManager.new()
	expect(manager.save_path() == NamelessSaveManager.DEFAULT_SAVE_PATH, "普通 SaveManager 默认路径改变")
	expect(manager.configure_playtest_namespace(ticket_sha) == OK, "合法 playtest namespace 配置失败")
	expect(manager.load_data() == OK, "playtest namespace load 失败")
	expect(manager.best_stage == 7 and manager.runs_started == 2, "playtest session 未读取自身 namespace")
	expect(manager.best_stage != 41, "playtest session 回退读取了普通 sentinel")
	expect(manager.configure_playtest_namespace("2".repeat(64)) == ERR_ALREADY_IN_USE, "首次 load 后 namespace 仍可切换")
	manager.best_stage = 8
	expect(manager.save_data() == OK, "playtest namespace save 失败")
	expect(file_sha(normal_path) == normal_sha, "playtest session 改写了普通 sentinel")

	var missing_manager := NamelessSaveManager.new()
	var missing_sha := "3".repeat(64)
	expect(missing_manager.configure_playtest_namespace(missing_sha) == OK, "缺失 session namespace 配置失败")
	expect(missing_manager.load_data() != OK, "缺失 session save 被误报成功")
	expect(missing_manager.best_stage == 0, "session load 失败后回退读取了普通存档")
	expect(missing_manager.namespace_is_locked(), "失败的首次 load 没有锁死 namespace")
	expect(missing_manager.configure_playtest_namespace(ticket_sha) == ERR_ALREADY_IN_USE, "失败的首次 load 后可回退其他 namespace")

	var other_manager := NamelessSaveManager.new()
	expect(other_manager.configure_playtest_namespace("4".repeat(64)) == OK, "第二 ticket namespace 配置失败")
	expect(other_manager.save_path() != manager.save_path(), "不同 ticket 未隔离到不同 namespace")
	expect(NamelessSaveManager.new().configure_playtest_namespace("ABC") == ERR_INVALID_PARAMETER, "非法 namespace token 未拒绝")

	fixture_helper.remove_tree(user_root)
	if failures.is_empty():
		print("PLAYTEST SAVE ISOLATION TEST PASSED")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
