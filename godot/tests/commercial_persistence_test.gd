extends SceneTree

const PersistenceScript := preload("res://scripts/system/commercial_persistence.gd")
const JourneyStateScript := preload("res://scripts/world/journey_state.gd")
const MenuScript := preload("res://scripts/ui/commercial_system_menu.gd")
const TitleScript := preload("res://scripts/ui/commercial_title.gd")
const JourneyScene := preload("res://journey.tscn")

var failures: Array[String] = []
var test_prefix := ""
var progress_path := ""
var settings_path := ""


func _init() -> void:
	call_deferred("run_test")


func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func run_test() -> void:
	test_prefix = "user://commercial-persistence-test-%d" % OS.get_process_id()
	progress_path = "%s-progress.json" % test_prefix
	settings_path = "%s-settings.json" % test_prefix
	_cleanup_files()

	var manager := PersistenceScript.new()
	expect(manager.configure_storage_for_test(progress_path, settings_path) == OK, "测试存储路径无法隔离")
	root.add_child(manager)
	await process_frame
	expect(not manager.has_progress(), "空测试目录被误报为有旅程存档")
	expect(manager.request_journey_launch("continue") == OK, "继续旅程启动请求被拒绝")
	expect(manager.has_pending_launch_request(), "启动请求没有跨场景保留")
	expect(manager.consume_journey_launch() == "continue" and not manager.has_pending_launch_request(), "启动请求没有恰好消费一次")

	var first_state = JourneyStateScript.new()
	var first_token: int = first_state.begin_sortie(JourneyState.SPRING_ROUTE)
	expect(first_state.settle_return(first_token, 6, 2), "测试前置春野返巢失败")
	first_state.mark_title_revealed()
	expect(manager.save_journey_state(first_state) == OK, "第一份主巢检查点写入失败")
	expect(manager.has_progress(), "合法检查点写入后仍没有继续游戏")
	var legacy_spring_data: Dictionary = first_state.to_save_dictionary()
	legacy_spring_data.world_results.erase("spring_honey_returned")
	var migrated_spring_ledger = JourneyStateScript.new()
	expect(
		migrated_spring_ledger.restore_from_save_dictionary(legacy_spring_data) == OK
		and migrated_spring_ledger.reserve == 6
		and migrated_spring_ledger.world_results.spring_honey_returned == 6,
		"旧检查点缺少春野实收字段时没有按旧规则迁移为 6 滴"
	)
	var temporary_absolute := ProjectSettings.globalize_path("%s.tmp" % progress_path)
	expect(not FileAccess.file_exists(temporary_absolute), "原子写入完成后遗留临时文件")

	var incident_token: int = first_state.begin_sortie(JourneyState.SIGN_INCIDENT)
	expect(first_state.settle_sign_incident(incident_token, 5, 3, 1), "测试前置花牌返巢失败")
	expect(manager.save_journey_state(first_state) == OK, "第二份检查点写入失败")
	var restored_current = JourneyStateScript.new()
	expect(manager.restore_journey_state(restored_current) == OK, "当前检查点无法恢复")
	expect(
		restored_current.reserve == 5
		and restored_current.sign_incident_complete
		and restored_current.world_results.spring_honey_lost == 1,
		"章节、巢中资源或跨章花牌痕迹没有一起恢复"
	)
	expect(restored_current.solar_terms.unlocked_count() == 6, "二十四节气纪事没有进入版本化存档")
	var inflated_reserve: Dictionary = restored_current.to_save_dictionary()
	inflated_reserve.reserve = 11
	expect(
		JourneyStateScript.new().restore_from_save_dictionary(inflated_reserve) == ERR_INVALID_DATA,
		"花牌周转蜜被重复入库的矛盾存档仍能恢复"
	)

	var corrupt_file := FileAccess.open(ProjectSettings.globalize_path(progress_path), FileAccess.WRITE)
	corrupt_file.store_string("{broken progress")
	corrupt_file.close()
	var restored_backup = JourneyStateScript.new()
	expect(manager.restore_journey_state(restored_backup) == OK, "主存档损坏后没有恢复上一份安全备份")
	expect(manager.recovered_progress_from_backup, "备份恢复没有向 UI 暴露")
	expect(
		restored_backup.reserve == 6 and restored_backup.first_return_complete and not restored_backup.sign_incident_complete,
		"备份不是上一份完整主巢检查点"
	)
	expect(restored_backup.solar_terms.unlocked_count() == 3, "备份中的节气纪事没有同步恢复")
	expect(manager.save_journey_state(restored_backup) == OK, "从备份恢复后无法写回新主存档")
	var restored_rewritten = JourneyStateScript.new()
	expect(manager.restore_journey_state(restored_rewritten) == OK and restored_rewritten.reserve == 6, "恢复后的主存档仍不可读")

	var legacy_state_data: Dictionary = restored_rewritten.to_save_dictionary()
	legacy_state_data.erase("solar_terms")
	var migrated_state = JourneyStateScript.new()
	expect(migrated_state.restore_from_save_dictionary(legacy_state_data) == OK, "旧存档缺少纪事字段时无法迁移")
	expect(migrated_state.solar_terms.unlocked_count() == 3, "旧存档迁移没有按已完成章节补齐纪事")
	var untouched_state = JourneyStateScript.new()
	var invalid_data := legacy_state_data.duplicate(true)
	invalid_data.reserve = -50
	expect(untouched_state.restore_from_save_dictionary(invalid_data) == ERR_INVALID_DATA, "负资源损坏存档被接纳")
	expect(untouched_state.reserve == 0 and not untouched_state.first_return_complete, "损坏存档失败前部分改写了内存状态")
	var tampered_terms: Dictionary = restored_rewritten.to_save_dictionary()
	tampered_terms.solar_terms = first_state.solar_terms.to_save_data()
	expect(
		JourneyStateScript.new().restore_from_save_dictionary(tampered_terms) == ERR_INVALID_DATA,
		"章节标记与节气解锁数量不一致的存档被接纳"
	)
	var tampered_prefix: Dictionary = restored_rewritten.to_save_dictionary()
	var wrong_solar_data: Dictionary = tampered_prefix.solar_terms.duplicate(true)
	wrong_solar_data.unlocked_ids = ["winter_lidong", "winter_xiaoxue", "winter_daxue"]
	wrong_solar_data.rendered_records = {}
	tampered_prefix.solar_terms = wrong_solar_data
	expect(
		JourneyStateScript.new().restore_from_save_dictionary(tampered_prefix) == ERR_INVALID_DATA,
		"数量相同但章节顺序错误的节气存档被接纳"
	)
	var tampered_world: Dictionary = restored_rewritten.to_save_dictionary()
	tampered_world.world_results.spring_signs_resolved = 3
	expect(
		JourneyStateScript.new().restore_from_save_dictionary(tampered_world) == ERR_INVALID_DATA,
		"未完成章节却带有跨章世界痕迹的存档被接纳"
	)
	var mid_sortie = JourneyStateScript.new()
	mid_sortie.begin_sortie(JourneyState.SPRING_ROUTE)
	expect(
		mid_sortie.restore_from_save_dictionary(mid_sortie.to_save_dictionary()) == ERR_INVALID_DATA,
		"野外未交接快照被误当成主蜂巢检查点"
	)

	expect(manager.set_setting("music_volume", 0.45) == OK, "音乐音量无法保存")
	expect(manager.set_setting("music_muted", true) == OK, "音乐静音无法保存")
	expect(manager.set_setting("sfx_volume", 0.65) == OK, "音效音量无法保存")
	expect(manager.set_setting("ui_scale", 1.3) == OK, "界面缩放无法保存")
	expect(manager.set_setting("screen_shake", true) == OK, "屏幕震动开关无法保存")
	expect(manager.set_setting("reduce_motion", true) == OK, "减少动态无法保存")
	expect(not bool(manager.setting("screen_shake", true)), "减少动态没有可靠关闭屏幕震动")
	expect(manager.set_setting("show_control_hints", false) == OK, "操作提示开关无法保存")
	var previous_volume := float(manager.setting("music_volume"))
	expect(manager.set_setting("music_volume", "loud") == ERR_INVALID_DATA, "错误类型的音量设置被写入")
	expect(is_equal_approx(float(manager.setting("music_volume")), previous_volume), "错误设置没有回滚")

	var reloaded_settings := PersistenceScript.new()
	expect(reloaded_settings.configure_storage_for_test(progress_path, settings_path) == OK, "重载设置管理器无法隔离")
	root.add_child(reloaded_settings)
	await process_frame
	expect(
		is_equal_approx(float(reloaded_settings.setting("music_volume")), 0.45)
		and bool(reloaded_settings.setting("music_muted"))
		and is_equal_approx(float(reloaded_settings.setting("sfx_volume")), 0.65)
		and is_equal_approx(float(reloaded_settings.setting("ui_scale")), 1.3)
		and bool(reloaded_settings.setting("reduce_motion"))
		and not bool(reloaded_settings.setting("show_control_hints")),
		"音频、显示或无障碍设置没有跨启动恢复"
	)
	expect(AudioServer.get_bus_index(&"Music") >= 0 and AudioServer.get_bus_index(&"SFX") >= 0, "音乐与音效没有独立混音总线")

	var menu := MenuScript.new()
	menu.configure(reloaded_settings)
	root.add_child(menu)
	await process_frame
	var valid_dirty_identity := {
		"schema_version": 1,
		"product_version": "0.9.5-rc.2",
		"commit": "0123456789abcdef0123456789abcdef01234567",
		"dirty": true,
	}
	expect(
		MenuScript.build_identity_from_document(valid_dirty_identity, "0.9.5-rc.2") == "v0.9.5-rc.2 · 01234567+dirty",
		"商业构建身份遗漏 dirty 标记或读取了错误版本字段"
	)
	var valid_clean_identity: Dictionary = valid_dirty_identity.duplicate(true)
	valid_clean_identity.dirty = false
	expect(
		MenuScript.build_identity_from_document(valid_clean_identity, "0.9.5-rc.2") == "v0.9.5-rc.2 · 01234567",
		"干净商业构建身份格式错误"
	)
	var invalid_identity: Dictionary = valid_dirty_identity.duplicate(true)
	invalid_identity.product_version = "0.0.0"
	expect(
		MenuScript.build_identity_from_document(invalid_identity, "0.9.5-rc.2") == "v0.9.5-rc.2 · invalid+dirty",
		"不匹配的构建来源被误报为可验证身份"
	)
	var title_logic := TitleScript.new()
	expect(title_logic._build_identity() == MenuScript.build_identity(), "商业标题没有复用严格构建身份")
	title_logic.free()
	expect(
		menu.build_identity_label != null
		and menu.build_identity_label.text == MenuScript.build_identity(),
		"暂停／设置覆盖层没有装入可验证的构建身份"
	)
	menu.open_pause(false)
	expect(menu.is_open() and menu.current_view() == "pause", "暂停菜单无法打开")
	expect(menu.build_identity_label.is_visible_in_tree(), "暂停覆盖层没有显示构建身份")
	expect(menu.resume_button.size.y >= 44.0 and menu.new_journey_button.size.y >= 44.0, "暂停菜单触屏目标小于 44px")
	expect(menu.quit_button.visible == not OS.has_feature("web"), "Web 暂停菜单仍提供会停住画布的退出按钮")
	menu.open_settings_only()
	expect(menu.current_view() == "settings" and menu.music_slider.focus_mode == Control.FOCUS_ALL, "键盘无法进入设置控件")
	expect(menu.music_slider.size.y >= 44.0 and menu.sfx_slider.size.y >= 44.0, "音量滑杆触屏目标小于 44px")
	expect(menu.fullscreen_toggle.disabled == OS.has_feature("web"), "Web 全屏没有安全降级")
	menu.open_credits_only()
	expect(
		"Godot Engine" in menu.credits_text.text
		and "Noto Sans CJK SC" in menu.credits_text.text
		and "不上传个人数据" in menu.credits_text.text,
		"制作人员、第三方许可或隐私入口内容不完整"
	)
	menu.close()

	var game = JourneyScene.instantiate()
	game.transition_duration = 0.0
	root.add_child(game)
	await process_frame
	game._apply_commercial_settings(reloaded_settings.settings_snapshot())
	expect(
		game.side_panel.size.x > 232.0
		and game.objective_label.size.x > 196.0
		and game.title_button.size.y >= 44.0,
		"130% 大字设置没有为 Journey HUD 扩展可读区域或触屏目标"
	)
	game._open_pause_menu(false)
	expect(paused and game.paused_by_menu and game.system_menu.is_open(), "暂停菜单没有真正停止 SceneTree")
	game._resume_from_menu()
	expect(not paused and not game.paused_by_menu, "继续按钮没有恢复玩法时钟")
	game._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	await process_frame
	expect(paused and game.paused_by_menu, "持续失焦没有安全冻结玩法")
	game._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)
	expect(paused, "重新聚焦时未经玩家确认自动恢复")
	game._resume_from_menu()
	expect(not paused, "失焦暂停后无法继续")
	game.transitioning = true
	game._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	await process_frame
	expect(not paused, "转场中途失焦破坏了正在提交的场景切换")
	game._finish_transition()
	await process_frame
	expect(paused and game.paused_by_menu, "转场期间持续失焦后没有补开安全暂停")
	game._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)
	game._resume_from_menu()
	expect(not paused, "转场失焦暂停后无法显式继续")
	game.queue_free()
	menu.queue_free()
	reloaded_settings.queue_free()
	manager.queue_free()
	await process_frame

	var cleanup_manager := PersistenceScript.new()
	cleanup_manager.configure_storage_for_test(progress_path, settings_path)
	expect(cleanup_manager.delete_progress() == OK, "新旅程无法清除主存档与备份")
	expect(not cleanup_manager.has_progress(), "清档后继续游戏仍然可用")
	# A newer-version primary must not fall back to an older valid backup or be
	# overwritten by a downgraded build. Explicit delete remains the escape hatch.
	expect(cleanup_manager.save_journey_state(restored_rewritten) == OK, "未来版本保护测试无法建立当前存档")
	var progress_absolute := ProjectSettings.globalize_path(progress_path)
	var backup_absolute := ProjectSettings.globalize_path("%s.bak" % progress_path)
	expect(DirAccess.copy_absolute(progress_absolute, backup_absolute) == OK, "未来版本保护测试无法建立旧备份")
	var future_envelope = JSON.parse_string(FileAccess.get_file_as_string(progress_absolute))
	expect(future_envelope is Dictionary, "未来版本保护测试无法读取信封")
	if future_envelope is Dictionary:
		future_envelope.schema_version = PersistenceScript.SCHEMA_VERSION + 1
		var future_file := FileAccess.open(progress_absolute, FileAccess.WRITE)
		future_file.store_string(JSON.stringify(future_envelope, "\t") + "\n")
		future_file.close()
		var future_bytes := FileAccess.get_file_as_bytes(progress_absolute)
		expect(not cleanup_manager.has_progress(), "未来版本存档被误报为可继续")
		expect(cleanup_manager.last_progress_error == ERR_UNAVAILABLE, "未来版本没有 fail-closed 错误")
		expect(cleanup_manager.progress_file_exists(), "不可读取的存档被误当成空槽")
		expect(cleanup_manager.save_journey_state(restored_rewritten) == ERR_UNAVAILABLE, "降级构建覆盖了未来版本存档")
		expect(FileAccess.get_file_as_bytes(progress_absolute) == future_bytes, "拒绝降级写入后未来版本存档仍被改写")
	expect(cleanup_manager.delete_progress() == OK, "明确清档无法移除未来版本存档")
	_cleanup_files()

	if failures.is_empty():
		print("COMMERCIAL PERSISTENCE TEST PASSED")
		print("TEST PASSED")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _cleanup_files() -> void:
	for path in [
		progress_path,
		"%s.tmp" % progress_path,
		"%s.bak" % progress_path,
		settings_path,
		"%s.tmp" % settings_path,
		"%s.bak" % settings_path,
	]:
		if path.is_empty():
			continue
		var absolute := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(absolute):
			DirAccess.remove_absolute(absolute)
