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

func launch(arguments: PackedStringArray, validator: Variant = null, raw_arguments: Variant = null) -> Dictionary:
	var host := Node.new()
	root.add_child(host)
	var bootstrap = BootstrapScene.instantiate()
	var effective_raw_arguments := PackedStringArray()
	if raw_arguments != null:
		effective_raw_arguments = raw_arguments
	var configured := int(bootstrap.configure_test_fixture(arguments, validator if validator != null else PlaytestTicketValidator.new(), effective_raw_arguments))
	expect(configured == OK, "bootstrap fixture 注入失败：%d" % configured)
	host.add_child(bootstrap)
	return {"host": host, "bootstrap": bootstrap, "scene": bootstrap.launched_scene}

func expect_rejected(arguments: PackedStringArray, code: String, validator: Variant = null, raw_arguments: Variant = null) -> void:
	var result := launch(arguments, validator, raw_arguments)
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

	var engine_arguments_only := launch(PackedStringArray(), null, PackedStringArray(["--headless", "--path", "/tmp/ordinary-game"]))
	expect(engine_arguments_only.scene != null and engine_arguments_only.scene.name == "NamelessBecoming", "普通引擎参数被误判为缺少分隔符的 ticket")
	engine_arguments_only.host.free()

	expect_rejected(PackedStringArray(), "PT-ARG-SEPARATOR", null, PackedStringArray(["--playtest-ticket=/tmp/playtest-ticket.json"]))
	expect_rejected(PackedStringArray(), "PT-ARG-SEPARATOR", null, PackedStringArray(["--playtest-ticket", "/tmp/playtest-ticket.json"]))
	expect_rejected(PackedStringArray(["--playtest-ticket=/tmp/correct-position.json"]), "PT-ARG-SEPARATOR", null, PackedStringArray(["--playtest-ticket=/tmp/misplaced.json"]))

	var root_bootstrap = BootstrapScene.instantiate()
	expect(root_bootstrap.configure_test_fixture(PackedStringArray(), PlaytestTicketValidator.new(), PackedStringArray()) == OK, "真实 root bootstrap fixture 注入失败")
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
	expect_rejected(PackedStringArray(["--playtest-ticket=res://playtest-ticket.json"]), "PT-ARG-PATH")
	expect_rejected(PackedStringArray(["--playtest-ticket=user://playtest-ticket.json"]), "PT-ARG-PATH")
	expect_rejected(PackedStringArray(["--playtest-ticket=file:///tmp/playtest-ticket.json"]), "PT-ARG-PATH")
	expect_rejected(PackedStringArray(["--playtest-ticket=file:/tmp/playtest-ticket.json"]), "PT-ARG-PATH")
	expect_rejected(PackedStringArray(["--playtest-ticket=https:/example.invalid/playtest-ticket.json"]), "PT-ARG-PATH")
	expect_rejected(PackedStringArray(["--playtest-ticket=/one.json", "--playtest-ticket=/two.json"]), "PT-ARG-COUNT")

	var unreadable_path := test_root.path_join("missing/playtest-ticket.json")
	expect_rejected(PackedStringArray(["--playtest-ticket=%s" % unreadable_path]), "PT-READ")

	var fixture := fixture_helper.create(test_root.path_join("valid"))
	var validator := fixture_helper.validator(fixture)
	var ordinary_save_path := ProjectSettings.globalize_path(NamelessSaveManager.DEFAULT_SAVE_PATH)
	DirAccess.make_dir_recursive_absolute(ordinary_save_path.get_base_dir())
	var sentinel := FileAccess.open(ordinary_save_path, FileAccess.WRITE)
	expect(sentinel != null, "无法建立普通存档不触碰 sentinel")
	if sentinel != null:
		sentinel.store_string("B01 bootstrap must not read or overwrite this malformed ordinary save.\n")
		sentinel.close()
	var ordinary_save_sha := FileAccess.get_sha256(ordinary_save_path)
	var valid := launch(PackedStringArray(["--playtest-ticket=%s" % fixture.ticket_path]), validator, PackedStringArray(["--headless"]))
	expect(valid.scene is B01EvadeSlice and valid.scene.name == "B01EvadeSlice", "有效受控 fixture 未实例化 B01 typed scene")
	if valid.scene != null:
		var expected_ticket_sha := fixture_helper.sha256(fixture_helper.json_bytes(fixture.ticket))
		expect(valid.scene.playtest_session_context.ticket_sha256 == expected_ticket_sha, "B01 未收到 ticket context")
		expect(valid.scene.find_child("NamelessBecoming", true, false) == null and valid.scene.find_child("*Save*", true, false) == null, "B01 启动仍实例化 Main 或存档管理器")
		var receipt_path: String = String(fixture.directory).path_join("playtest-ready-receipt.json")
		expect(FileAccess.file_exists(receipt_path), "B01 typed scene ready 后未写启动 receipt")
		var receipt = JSON.parse_string(FileAccess.get_file_as_string(receipt_path))
		expect(receipt is Dictionary, "B01 启动 receipt 不是 JSON object")
		if receipt is Dictionary:
			var receipt_dictionary := receipt as Dictionary
			var receipt_keys := receipt_dictionary.keys()
			receipt_keys.sort()
			expect(receipt_keys == ["product_commit", "schema_version", "session_id", "slice_code", "status", "ticket_sha256"], "B01 启动 receipt 字段不精确：%s" % receipt)
			expect(int(receipt_dictionary.get("schema_version", 0)) == 1, "B01 启动 receipt schema 不符")
			expect(receipt_dictionary.get("status") == "ready", "B01 启动 receipt status 不符")
			expect(receipt_dictionary.get("session_id") == fixture.ticket.session_id, "B01 启动 receipt session 不符")
			expect(receipt_dictionary.get("slice_code") == "B01", "B01 启动 receipt slice 不符")
			expect(receipt_dictionary.get("product_commit") == fixture.ticket.product.commit, "B01 启动 receipt commit 不符")
			expect(receipt_dictionary.get("ticket_sha256") == expected_ticket_sha, "B01 启动 receipt ticket SHA 不符")
	expect(not ordinary_save_sha.is_empty() and FileAccess.get_sha256(ordinary_save_path) == ordinary_save_sha, "B01 bootstrap 改写了普通存档")
	valid.host.free()

	var root_fixture := fixture_helper.create(test_root.path_join("valid-root"))
	var root_validator := fixture_helper.validator(root_fixture)
	var root_playtest_bootstrap = BootstrapScene.instantiate()
	var root_ticket_arguments := PackedStringArray(["--playtest-ticket=%s" % root_fixture.ticket_path])
	expect(root_playtest_bootstrap.configure_test_fixture(root_ticket_arguments, root_validator, PackedStringArray(["--headless"])) == OK, "真实 root B01 bootstrap fixture 注入失败")
	root.add_child(root_playtest_bootstrap)
	await process_frame
	var root_b01 := root.get_node_or_null("B01EvadeSlice")
	expect(root_b01 is B01EvadeSlice, "bootstrap 作为导出 current scene 时未激活 B01 typed scene")
	var root_receipt_path: String = String(root_fixture.directory).path_join("playtest-ready-receipt.json")
	expect(FileAccess.file_exists(root_receipt_path), "真实 root B01 ready 后未写启动 receipt")
	expect(not ordinary_save_sha.is_empty() and FileAccess.get_sha256(ordinary_save_path) == ordinary_save_sha, "真实 root B01 bootstrap 改写了普通存档")
	if root_b01 != null:
		root_b01.free()

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
