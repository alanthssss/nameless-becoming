extends SceneTree

const FixtureScript := preload("res://tests/playtest_fixture.gd")
const BootstrapScene := preload("res://bootstrap.tscn")

var failures: Array[String] = []
var fixture_helper = FixtureScript.new()
var test_root := ""

func _init() -> void:
	ProjectSettings.set_setting("application/config/use_custom_user_dir", true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name", "nameless-bootstrap-tests-%d" % OS.get_process_id())
	test_root = ProjectSettings.globalize_path("user://bootstrap-fixtures")
	call_deferred("run_test")

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func launch(arguments: PackedStringArray, validator: Variant = null) -> Dictionary:
	var host := Node.new()
	root.add_child(host)
	var bootstrap = BootstrapScene.instantiate()
	var configured := int(bootstrap.configure_test_fixture(arguments, validator if validator != null else PlaytestTicketValidator.new()))
	expect(configured == OK, "bootstrap fixture 注入失败：%d" % configured)
	host.add_child(bootstrap)
	return {"host": host, "bootstrap": bootstrap, "scene": bootstrap.launched_scene}

func expect_rejected(arguments: PackedStringArray, code: String, validator: Variant = null) -> void:
	var result := launch(arguments, validator)
	expect(result.scene == null, "%s 失败路径仍实例化 Main" % code)
	expect(result.bootstrap.last_error_code == code, "%s 错误码不符：%s" % [code, result.bootstrap.last_error_code])
	expect(result.bootstrap.find_child("ErrorCode", true, false) != null, "%s 未显示中性错误码" % code)
	result.host.free()

func run_test() -> void:
	var no_ticket := launch(PackedStringArray())
	expect(no_ticket.scene != null and no_ticket.scene.name == "NamelessBecoming", "无 ticket 未实例化原 main.tscn")
	if no_ticket.scene != null:
		expect(no_ticket.scene.playtest_session_context.is_empty(), "无 ticket 普通启动被误配置为 playtest")
		expect(no_ticket.scene.save_manager.save_path() == NamelessSaveManager.DEFAULT_SAVE_PATH, "无 ticket 改变普通存档路径")
		expect(no_ticket.scene.configure_playtest_session({}) == ERR_ALREADY_IN_USE, "Main 进入场景树后仍接受 session 注入")
	no_ticket.host.free()

	var root_bootstrap = BootstrapScene.instantiate()
	expect(root_bootstrap.configure_test_fixture(PackedStringArray(), PlaytestTicketValidator.new()) == OK, "真实 root bootstrap fixture 注入失败")
	root.add_child(root_bootstrap)
	await process_frame
	var root_main := root.get_node_or_null("NamelessBecoming")
	expect(root_main != null, "bootstrap 作为导出 current scene 时未 deferred 激活原 Main")
	if root_main != null:
		expect(root_main.playtest_session_context.is_empty(), "真实 root 无 ticket 启动被误配置")
		root_main.free()

	expect_rejected(PackedStringArray(["--playtest-ticket"]), "PT-ARG-FORMAT")
	expect_rejected(PackedStringArray(["--slice=B01"]), "PT-ARG-FORMAT")
	expect_rejected(PackedStringArray(["--playtest-ticket=relative.json"]), "PT-ARG-PATH")
	expect_rejected(PackedStringArray(["--playtest-ticket=/one.json", "--playtest-ticket=/two.json"]), "PT-ARG-COUNT")

	var unreadable_path := test_root.path_join("missing/playtest-ticket.json")
	expect_rejected(PackedStringArray(["--playtest-ticket=%s" % unreadable_path]), "PT-READ")

	var fixture := fixture_helper.create(test_root.path_join("valid"))
	var validator := fixture_helper.validator(fixture)
	var valid := launch(PackedStringArray(["--playtest-ticket=%s" % fixture.ticket_path]), validator)
	expect(valid.scene != null and valid.scene.name == "NamelessBecoming", "有效受控 fixture 未实例化 Main")
	if valid.scene != null:
		var expected_ticket_sha := fixture_helper.sha256(fixture_helper.json_bytes(fixture.ticket))
		expect(valid.scene.playtest_session_context.ticket_sha256 == expected_ticket_sha, "Main 未在 ready 前收到 ticket context")
		expect(valid.scene.save_manager.namespace_is_locked(), "Main ready 的首次 load 后 namespace 未锁死")
		expect(valid.scene.save_manager.save_path() == "user://nameless-playtest-%s.cfg" % expected_ticket_sha, "Main 未使用 ticket raw-byte 派生 namespace")
	valid.host.free()

	var bootstrap_source := FileAccess.get_file_as_string("res://scripts/bootstrap.gd")
	expect(not bootstrap_source.contains("get_environment"), "bootstrap 不得从环境变量接收 ticket")
	expect(not bootstrap_source.contains("--stage") and not bootstrap_source.contains("debug"), "bootstrap 暴露了未授权 stage/debug 入口")

	fixture_helper.remove_tree(test_root)
	if failures.is_empty():
		print("PLAYTEST BOOTSTRAP TEST PASSED")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
