extends SceneTree

const FixtureScript := preload("res://tests/playtest_fixture.gd")

var failures: Array[String] = []
var fixture_helper = FixtureScript.new()
var test_root := ""
var serial := 0

func _init() -> void:
	ProjectSettings.set_setting("application/config/use_custom_user_dir", true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name", "nameless-validator-tests-%d" % OS.get_process_id())
	test_root = ProjectSettings.globalize_path("user://validator-fixtures")
	call_deferred("run_test")

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func next_fixture(code := "B01", status := "ready") -> Dictionary:
	serial += 1
	return fixture_helper.create(test_root.path_join("case-%03d" % serial), code, status)

func expect_code(result: Dictionary, code: String, label: String) -> void:
	expect(not bool(result.get("ok", false)) and result.get("code") == code, "%s：预期 %s，实际 %s" % [label, code, JSON.stringify(result)])

func validate(fixture: Dictionary, registry_override: Variant = null, platform := "macOS") -> Dictionary:
	return fixture_helper.validator(fixture, registry_override, platform).validate_ticket(fixture.ticket_path)

func run_test() -> void:
	var production_catalog_text := FileAccess.get_file_as_string("res://data/playtest_slices.json")
	var production_catalog = JSON.parse_string(production_catalog_text)
	expect(production_catalog is Dictionary and production_catalog.keys().size() == 2 and production_catalog.has("schema_version") and production_catalog.has("slices"), "生产 catalog 顶层不是 exact schema v1")
	if production_catalog is Dictionary and production_catalog.get("slices") is Array:
		expect(production_catalog.slices.size() == 1, "生产 catalog 必须只有中性 B01")
		if production_catalog.slices.size() == 1:
			var production_slice: Dictionary = production_catalog.slices[0]
			expect(production_slice.keys().size() == 4 and production_slice.code == "B01" and production_slice.assignment == "固定切片 B01" and int(production_slice.maximum_minutes) == 10 and production_slice.status == "ready", "生产 B01 必须保持 exact ready/10min 公共模型")
	expect(not production_catalog_text.contains("handler") and not production_catalog_text.contains("stage") and not production_catalog_text.contains("seed") and not production_catalog_text.contains("path") and not production_catalog_text.contains("override") and not production_catalog_text.contains("patch"), "生产 catalog 泄露执行路径或 override 字段")
	var production_registry := PlaytestSliceRegistry.new()
	var production_b01_scene := production_registry.scene_for_code("B01")
	expect(production_registry.has_code("B01") and production_b01_scene != null, "生产 registry 没有编译 B01 typed scene")
	if production_b01_scene != null:
		expect(production_b01_scene.resource_path == "res://playtest/b01_evade_slice.tscn", "生产 B01 registry 指向了 Main 或其他场景")

	var relative_result := PlaytestTicketValidator.new().validate_ticket("relative/playtest-ticket.json")
	expect_code(relative_result, "PT-TICKET-PATH", "相对 ticket")
	for virtual_path in ["res://playtest-ticket.json", "user://playtest-ticket.json", "file:///tmp/playtest-ticket.json", "file:/tmp/playtest-ticket.json", "https:/example.invalid/playtest-ticket.json"]:
		expect_code(PlaytestTicketValidator.new().validate_ticket(virtual_path), "PT-TICKET-PATH", "非外部文件路径 %s" % virtual_path)
	var missing_path := test_root.path_join("missing/playtest-ticket.json")
	expect_code(PlaytestTicketValidator.new().validate_ticket(missing_path), "PT-READ", "不可读 ticket")

	var malformed := next_fixture()
	fixture_helper.write_bytes(malformed.ticket_path, "{not-json\n".to_utf8_buffer())
	expect_code(fixture_helper.validator(malformed).validate_ticket(malformed.ticket_path), "PT-JSON", "畸形 ticket")

	var unknown_top := next_fixture()
	unknown_top.ticket["unexpected"] = true
	fixture_helper.write_fixture(unknown_top)
	expect_code(validate(unknown_top), "PT-TICKET-SCHEMA", "ticket 未知顶层字段")

	var unknown_nested := next_fixture()
	unknown_nested.ticket.product["unexpected"] = true
	fixture_helper.write_fixture(unknown_nested)
	expect_code(validate(unknown_nested), "PT-TICKET-SCHEMA", "ticket 未知嵌套字段")

	var dirty := next_fixture()
	dirty.ticket.product.dirty = true
	fixture_helper.write_fixture(dirty)
	expect_code(validate(dirty), "PT-TICKET-SCHEMA", "dirty ticket")

	var short_commit := next_fixture()
	short_commit.ticket.product.commit = "01234567"
	fixture_helper.write_fixture(short_commit)
	expect_code(validate(short_commit), "PT-TICKET-SCHEMA", "短提交号")

	var wrong_product := next_fixture()
	wrong_product.ticket.product.id = "another-product"
	fixture_helper.write_fixture(wrong_product)
	expect_code(validate(wrong_product), "PT-TICKET-SCHEMA", "产品 ID 不符")

	var wrong_display := next_fixture()
	wrong_display.ticket.product.display_name = "另一个游戏"
	fixture_helper.write_fixture(wrong_display)
	expect_code(validate(wrong_display), "PT-TICKET-SCHEMA", "产品展示名不符")

	var wrong_version := next_fixture()
	wrong_version.ticket.product.version = "0.0.0"
	fixture_helper.write_fixture(wrong_version)
	expect_code(validate(wrong_version), "PT-TICKET-SCHEMA", "产品版本不符")

	var wrong_commit := next_fixture()
	wrong_commit.ticket.product.commit = fixture_helper.OTHER_COMMIT
	fixture_helper.write_fixture(wrong_commit)
	expect_code(validate(wrong_commit), "PT-MANIFEST-SCHEMA", "manifest 与 ticket commit 不符")

	var wrong_platform := next_fixture()
	expect_code(validate(wrong_platform, null, "Windows"), "PT-TICKET-SCHEMA", "运行平台不符")

	var wrong_filename := next_fixture()
	wrong_filename.ticket.artifact.filename = "renamed.zip"
	fixture_helper.write_fixture(wrong_filename)
	expect_code(validate(wrong_filename), "PT-TICKET-SCHEMA", "artifact 文件名不符")

	var wrong_size := next_fixture()
	wrong_size.ticket.artifact.size = 0
	fixture_helper.write_fixture(wrong_size)
	expect_code(validate(wrong_size), "PT-TICKET-SCHEMA", "artifact 大小不符")

	var wrong_artifact_sha := next_fixture()
	wrong_artifact_sha.ticket.artifact.sha256 = "short"
	fixture_helper.write_fixture(wrong_artifact_sha)
	expect_code(validate(wrong_artifact_sha), "PT-TICKET-SCHEMA", "artifact SHA 不符")

	var manifest_sha_mismatch := next_fixture()
	manifest_sha_mismatch.ticket.artifact.manifest_sha256 = "b".repeat(64)
	fixture_helper.write_bytes(manifest_sha_mismatch.ticket_path, fixture_helper.json_bytes(manifest_sha_mismatch.ticket))
	expect_code(validate(manifest_sha_mismatch), "PT-MANIFEST-SHA", "manifest 原始字节 SHA 不符")

	var manifest_field_mismatch := next_fixture()
	manifest_field_mismatch.manifest.size = 999
	fixture_helper.write_fixture(manifest_field_mismatch)
	expect_code(validate(manifest_field_mismatch), "PT-MANIFEST-SCHEMA", "manifest 字段不符")

	var manifest_unknown := next_fixture()
	manifest_unknown.manifest["unexpected"] = true
	fixture_helper.write_fixture(manifest_unknown)
	expect_code(validate(manifest_unknown), "PT-MANIFEST-SCHEMA", "manifest 未知字段")

	var provenance_mismatch := next_fixture()
	provenance_mismatch.provenance.commit = fixture_helper.OTHER_COMMIT
	fixture_helper.write_fixture(provenance_mismatch)
	expect_code(validate(provenance_mismatch), "PT-PROVENANCE", "包内 provenance commit 不符")

	var provenance_dirty := next_fixture()
	provenance_dirty.provenance.dirty = true
	fixture_helper.write_fixture(provenance_dirty)
	expect_code(validate(provenance_dirty), "PT-PROVENANCE", "包内 provenance dirty")

	var catalog_sha_mismatch := next_fixture()
	catalog_sha_mismatch.ticket.catalog_sha256 = "c".repeat(64)
	fixture_helper.write_bytes(catalog_sha_mismatch.ticket_path, fixture_helper.json_bytes(catalog_sha_mismatch.ticket))
	expect_code(validate(catalog_sha_mismatch), "PT-CATALOG-SHA", "catalog 原始字节 SHA 不符")

	var catalog_unknown_field := next_fixture()
	catalog_unknown_field.catalog.slices[0]["handler"] = "forbidden"
	fixture_helper.write_fixture(catalog_unknown_field)
	expect_code(validate(catalog_unknown_field), "PT-CATALOG-SCHEMA", "catalog 私有字段")

	var unknown_slice := next_fixture()
	unknown_slice.ticket.task.slice_code = "B02"
	fixture_helper.write_fixture(unknown_slice)
	expect_code(validate(unknown_slice), "PT-SLICE-UNKNOWN", "未知 slice")

	var blocked := next_fixture("B01", "blocked")
	expect_code(validate(blocked), "PT-SLICE-BLOCKED", "生产 B01 blocked gate")

	var duplicate := next_fixture()
	duplicate.catalog.slices.append(duplicate.catalog.slices[0].duplicate(true))
	fixture_helper.write_fixture(duplicate)
	expect_code(validate(duplicate), "PT-SLICE-DUPLICATE", "重复 slice code")

	var unregistered := next_fixture()
	expect_code(validate(unregistered, {}), "PT-SLICE-UNREGISTERED", "未注册 slice")

	var unimplemented := next_fixture()
	expect_code(validate(unimplemented, {"B01": null}), "PT-SLICE-UNIMPLEMENTED", "无 typed scene slice")

	var valid := next_fixture()
	var valid_result := validate(valid)
	expect(bool(valid_result.get("ok", false)), "受控 fixture 应通过：%s" % JSON.stringify(valid_result))
	if valid_result.get("ok", false):
		expect(valid_result.scene is PackedScene and valid_result.scene.resource_path == "res://playtest/b01_evade_slice.tscn", "ready B01 validator 没有返回编译期 typed scene")
		expect(valid_result.context.ticket_sha256 == fixture_helper.sha256(fixture_helper.json_bytes(valid.ticket)), "成功 context 未绑定 ticket 原始字节 SHA")
		expect(valid_result.context.slice.code == "B01" and int(valid_result.context.slice.maximum_minutes) == 10 and valid_result.context.slice.status == "ready", "成功 context 未携带 catalog 公共 slice")

	fixture_helper.remove_tree(test_root)
	if failures.is_empty():
		print("PLAYTEST TICKET VALIDATOR TEST PASSED")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
