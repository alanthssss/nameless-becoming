extends SceneTree

const PersistenceScript := preload("res://scripts/system/commercial_persistence.gd")
const JourneyStateScript := preload("res://scripts/world/journey_state.gd")
const CampaignStateScript := preload("res://scripts/world/journey_campaign_state.gd")
const EventMatrixRuntimeScript := preload("res://scripts/world/journey_event_matrix_runtime.gd")
const SolarTermChronicleScript := preload("res://scripts/world/journey_solar_term_chronicle.gd")
const MenuScript := preload("res://scripts/ui/commercial_system_menu.gd")
const TitleScript := preload("res://scripts/ui/commercial_title.gd")
const CampaignHiveScript := preload("res://scripts/world/journey_campaign_hive.gd")
const JourneyScene := preload("res://journey.tscn")

var failures: Array[String] = []
var test_prefix := ""
var progress_path := ""
var settings_path := ""


class V2CampaignCheckpoint:
	extends RefCounted

	var state_data: Dictionary
	var next_id: String


	func _init(source: Dictionary, next_segment: String) -> void:
		state_data = source.duplicate(true)
		next_id = next_segment


	func to_save_dictionary() -> Dictionary:
		return state_data.duplicate(true)


	func next_segment_id() -> String:
		return next_id


func _init() -> void:
	call_deferred("run_test")


func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func event_checkpoint_for(level: Dictionary, pentads: int) -> Dictionary:
	var runtime = EventMatrixRuntimeScript.new()
	if runtime.configure(level.get("event_matrix", [])) != OK:
		return {}
	var target_index := pentads * EventMatrixRuntimeScript.EVENTS_PER_PENTAD
	while runtime.current_index < target_index:
		if runtime.optional_pending():
			runtime.accept_optional()
		if runtime.choice_pending():
			runtime.choose_route("steady")
		if runtime.requires_evade():
			runtime.note_evade()
		var result: Dictionary = runtime.record_step(runtime.current_kind())
		if not bool(result.get("accepted", false)):
			return {}
	var checkpoint := runtime.checkpoint_snapshot()
	checkpoint["level_id"] = String(level.get("id", ""))
	checkpoint["energy"] = 68.0
	checkpoint["elapsed_seconds"] = 142.5
	checkpoint["actions"] = 17
	return checkpoint


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
	expect(
		int(manager.setting("campaign_energy_tutorial_version", -1)) == 0,
		"缺少教学版本的旧设置没有安全补成 0"
	)
	var legacy_settings_path := "%s-legacy-missing-tutorial-settings.json" % test_prefix
	var legacy_progress_path := "%s-legacy-missing-tutorial-progress.json" % test_prefix
	var legacy_writer := PersistenceScript.new()
	expect(
		legacy_writer.configure_storage_for_test(
			legacy_progress_path,
			legacy_settings_path
		) == OK,
		"旧设置迁移写入器无法隔离"
	)
	var legacy_settings_payload := legacy_writer.settings_snapshot()
	legacy_settings_payload.erase("campaign_energy_tutorial_version")
	expect(
		legacy_writer._write_envelope_atomic(
			legacy_settings_path,
			PersistenceScript.SETTINGS_KIND,
			legacy_settings_payload
		) == OK,
		"无法建立缺少体力教学字段的合法旧设置信封"
	)
	legacy_writer.free()
	var legacy_reader := PersistenceScript.new()
	expect(
		legacy_reader.configure_storage_for_test(
			legacy_progress_path,
			legacy_settings_path
		) == OK,
		"旧设置迁移读取器无法隔离"
	)
	root.add_child(legacy_reader)
	await process_frame
	expect(
		legacy_reader.last_settings_error == OK
		and int(legacy_reader.setting("campaign_energy_tutorial_version", -1)) == 0,
		"真实旧设置信封缺少教学字段时没有无损补成 0"
	)
	legacy_reader.queue_free()
	await process_frame
	for legacy_path in [
		legacy_settings_path,
		"%s.tmp" % legacy_settings_path,
		"%s.bak" % legacy_settings_path,
		legacy_progress_path,
		"%s.tmp" % legacy_progress_path,
		"%s.bak" % legacy_progress_path,
	]:
		var legacy_absolute := ProjectSettings.globalize_path(legacy_path)
		if FileAccess.file_exists(legacy_absolute):
			DirAccess.remove_absolute(legacy_absolute)
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

	# Commercial persistence recognizes a legal v2 campaign envelope as a
	# migratable checkpoint.  It exposes the v3-safe summary (Lichun retained,
	# Yushui next) and rewrites v3 only after restore, rather than reporting damage.
	var one_level_campaign = CampaignStateScript.new()
	var lichun: Dictionary = one_level_campaign.catalog.level_at(0)
	var campaign_token: int = one_level_campaign.begin_level(String(lichun.id))
	var campaign_counts: Array[int] = []
	for objective in lichun.objectives:
		campaign_counts.append(int((objective as Dictionary).goal))
	one_level_campaign.settle_level({
		"journey_token": campaign_token,
		"level_id": String(lichun.id),
		"objectives_complete": true,
		"returned_home": true,
		"objective_counts": campaign_counts,
		"phases_completed": 0,
		"elapsed_seconds": 180.0,
		"energy_remaining": 72.0,
		"actions": 8,
		"failed": false,
	})
	var v2_campaign_data := one_level_campaign.to_save_dictionary()
	v2_campaign_data.schema_version = CampaignStateScript.PREVIOUS_CAMPAIGN_SCHEMA_VERSION
	v2_campaign_data.campaign_id = CampaignStateScript.PREVIOUS_CAMPAIGN_ID
	v2_campaign_data.erase("legacy_campaign_progress")
	v2_campaign_data.erase("event_checkpoint")
	# Extend the envelope with the actual pre-v3 Yushui contract archived from
	# git HEAD. This is intentionally [2,3,4], not today's two event counters.
	var old_yushui_result := {
		"level_id": "spring_yushui",
		"number": 2,
		"run_mode": "progression",
		"reward": 4,
		"elapsed_seconds": 540.0,
		"energy_remaining": 318.0,
		"objective_counts": [2, 3, 4],
		"phases_completed": 0,
		"actions": 11,
	}
	v2_campaign_data.completed_level_ids.append("spring_yushui")
	v2_campaign_data.reward_ledger.spring_yushui = 4
	v2_campaign_data.level_results.spring_yushui = old_yushui_result.duplicate(true)
	v2_campaign_data.best_results.spring_yushui = old_yushui_result.duplicate(true)
	v2_campaign_data.world_traces.append({
		"level_id": "spring_yushui",
		"number": 2,
		"season_id": "spring",
		"trace": "叶沟形成稳定滴水线，之后能认作安全路线。",
	})
	v2_campaign_data.reserve = 10
	v2_campaign_data.sortie_count = 2
	v2_campaign_data.attempt_serial = 2
	v2_campaign_data.last_return_level_id = "spring_yushui"
	v2_campaign_data.last_reward = 4
	var old_terms = SolarTermChronicleScript.new()
	old_terms.record_level("spring_lichun", {})
	old_terms.record_level("spring_yushui", {})
	v2_campaign_data.solar_terms = old_terms.to_save_data()
	var v2_checkpoint := V2CampaignCheckpoint.new(v2_campaign_data, "spring_jingzhe")
	expect(manager.save_journey_state(v2_checkpoint) == OK, "测试无法写入合法 v2 Campaign 检查点")
	var v2_primary_bytes := FileAccess.get_file_as_bytes(ProjectSettings.globalize_path(progress_path))
	expect(manager.has_progress(), "合法 v2 Campaign 被商业持久化当作损坏存档")
	var v2_summary := manager.progress_summary()
	expect(
		bool(v2_summary.get("ok", false))
		and bool(v2_summary.get("campaign_save", false))
		and bool(v2_summary.get("migrated_v2", false))
		and bool(v2_summary.get("legacy_archived", false))
		and int(v2_summary.get("completed_count", 0)) == 1
		and int(v2_summary.get("legacy_completed_count", 0)) == 2
		and String(v2_summary.get("next_segment", "")) == "spring_yushui"
		and String(v2_summary.get("next_term_name", "")) == "雨水"
		and not bool(v2_summary.get("protected_v2_backup", true)),
		"v2 Campaign 继续游戏摘要没有反映安全迁移结果"
	)
	var migration_title_logic := TitleScript.new()
	expect(
		migration_title_logic._legacy_migration_status(v2_summary)
		== "旧版 2/24 已封存 · 正式 1/24\n正式进度从雨水继续 · 首次保存会另存旧档",
		"标题没有在首次 v3 保存前说明旧版封存、正式续点与可恢复备份"
	)
	var protected_pending_summary := v2_summary.duplicate(true)
	protected_pending_summary.protected_v2_backup = true
	expect(
		migration_title_logic._legacy_migration_status(protected_pending_summary)
		== "旧版 2/24 已封存 · 正式 1/24\n正式进度从雨水继续 · 原始旧档已保护",
		"v3 写入重试时标题把已经保护的旧档误报成尚未另存"
	)
	var migrated_campaign = CampaignStateScript.new()
	expect(manager.restore_journey_state(migrated_campaign) == OK, "商业持久化无法迁移合法 v2 Campaign")
	expect(
		migrated_campaign.completed_level_ids == ["spring_lichun"]
		and migrated_campaign.next_segment_id() == "spring_yushui"
		and int(migrated_campaign.legacy_campaign_progress.completed_count) == 2,
		"商业持久化迁移丢失了立春前缀或 legacy 纪念"
	)
	expect(manager.save_journey_state(migrated_campaign) == OK, "迁移后无法重写为 v3 Campaign 检查点")
	var protected_v2_path := "%s%s" % [progress_path, PersistenceScript.LEGACY_V2_BACKUP_SUFFIX]
	var protected_v2_absolute := ProjectSettings.globalize_path(protected_v2_path)
	expect(
		FileAccess.file_exists(protected_v2_absolute)
		and FileAccess.get_file_as_bytes(protected_v2_absolute) == v2_primary_bytes,
		"第一次 v3 写入前没有逐字保留独立、受保护的 v2 原始信封"
	)
	var protected_envelope = JSON.parse_string(FileAccess.get_file_as_string(protected_v2_absolute))
	var protected_restore = CampaignStateScript.new()
	expect(
		protected_envelope is Dictionary
		and protected_restore.restore_from_save_dictionary(
			(protected_envelope as Dictionary).get("payload", {}).get("state", {})
		) == OK
		and int(protected_restore.legacy_campaign_progress.get("completed_count", 0)) == 2,
		"受保护 v2 副本不能作为合法旧档恢复"
	)
	var rewritten_campaign_summary := manager.progress_summary()
	expect(
		bool(rewritten_campaign_summary.get("ok", false))
		and not bool(rewritten_campaign_summary.get("migrated_v2", true))
		and bool(rewritten_campaign_summary.get("legacy_archived", false))
		and bool(rewritten_campaign_summary.get("protected_v2_backup", false))
		and int(rewritten_campaign_summary.get("legacy_completed_count", 0)) == 2,
		"v2 Campaign 重写后仍被误报为待迁移存档"
	)
	expect(
		migration_title_logic._legacy_migration_status(rewritten_campaign_summary)
		== "旧版 2/24 已封存 · 正式 1/24\n正式进度从雨水继续 · 原始旧档已保护",
		"标题在迁移后没有继续显示旧版封存与正式续点"
	)
	var completed_migration_summary := rewritten_campaign_summary.duplicate(true)
	completed_migration_summary.completed_count = 24
	completed_migration_summary.journey_complete = true
	completed_migration_summary.next_term_name = ""
	expect(
		migration_title_logic._legacy_migration_status(completed_migration_summary)
		== "旧版 2/24 已封存 · 正式 24/24 已完成\n原始旧档已另存保护",
		"正式 24/24 后迁移摘要退回了不存在的“下一关”"
	)
	var keepsake_hive = CampaignHiveScript.new()
	expect(
		keepsake_hive.configure(migrated_campaign.hive_context(false)) == OK
		and keepsake_hive.legacy_keepsake_text()
		== "纪念格 · 旧版2/24封存 · 正式从雨水继续",
		"主蜂巢没有提供只读旧版纪念摘要"
	)
	keepsake_hive.free()
	var completed_hive_context := migrated_campaign.hive_context(false)
	completed_hive_context.completed_count = 24
	completed_hive_context.journey_complete = true
	completed_hive_context.next_level = {}
	var completed_keepsake_hive = CampaignHiveScript.new()
	expect(
		completed_keepsake_hive.configure(completed_hive_context) == OK
		and completed_keepsake_hive.legacy_keepsake_text()
		== "纪念格 · 旧版2/24封存 · 正式24/24完成",
		"主蜂巢在正式 24/24 后显示了不存在的续点"
	)
	completed_keepsake_hive.free()
	# An archive can outlive both active rotating slots. It remains protected user
	# data for the new-journey confirmation, but must never enable Continue.
	var archive_only_progress_path := "%s-archive-only-progress.json" % test_prefix
	var archive_only_settings_path := "%s-archive-only-settings.json" % test_prefix
	var archive_only_absolute := ProjectSettings.globalize_path(
		"%s%s" % [archive_only_progress_path, PersistenceScript.LEGACY_V2_BACKUP_SUFFIX]
	)
	expect(
		DirAccess.copy_absolute(protected_v2_absolute, archive_only_absolute) == OK,
		"archive-only 回归无法建立独立旧版保护档"
	)
	var archive_only_manager := PersistenceScript.new()
	expect(
		archive_only_manager.configure_storage_for_test(
			archive_only_progress_path,
			archive_only_settings_path
		) == OK,
		"archive-only 回归无法隔离持久化路径"
	)
	expect(
		archive_only_manager.progress_file_exists()
		and archive_only_manager.protected_v2_archive_exists()
		and not archive_only_manager.has_progress(),
		"只剩旧版保护档时被误报为空槽，或错误启用了继续游戏"
	)
	var archive_only_title := TitleScript.new()
	archive_only_title.persistence = archive_only_manager
	var archive_only_ui := Control.new()
	root.add_child(archive_only_ui)
	archive_only_title.continue_button = Button.new()
	archive_only_title.new_button = Button.new()
	archive_only_title.status_label = Label.new()
	archive_only_ui.add_child(archive_only_title.continue_button)
	archive_only_ui.add_child(archive_only_title.new_button)
	archive_only_ui.add_child(archive_only_title.status_label)
	archive_only_title._refresh_slot()
	expect(
		archive_only_title.continue_button.disabled
		and archive_only_title.new_button.text == "重新开始新旅程"
		and "这里只剩旧版保护档" in archive_only_title.status_label.text,
		"archive-only 标题没有禁用继续并说明二次清档确认"
	)
	archive_only_title._prepare_new_journey()
	expect(
		archive_only_title._new_journey_armed
		and archive_only_title.new_button.text == "再按一次：从立春重新开始",
		"archive-only 新旅程没有先停在二次确认"
	)
	expect(
		archive_only_manager.delete_progress() == OK
		and not archive_only_manager.progress_file_exists()
		and not FileAccess.file_exists(archive_only_absolute),
		"明确清档后 archive-only 保护资料没有一起清除"
	)
	archive_only_title.free()
	archive_only_ui.free()
	archive_only_manager.free()
	migration_title_logic.free()
	var yushui_level: Dictionary = migrated_campaign.catalog.level_by_id("spring_yushui")
	var yushui_token: int = migrated_campaign.begin_level("spring_yushui")
	var yushui_checkpoint := event_checkpoint_for(yushui_level, 1)
	expect(
		not yushui_checkpoint.is_empty()
		and migrated_campaign.record_event_checkpoint(yushui_token, yushui_checkpoint),
		"商业持久化测试无法建立合法候级检查点"
	)
	migrated_campaign.abandon_attempt(yushui_token)
	expect(manager.save_journey_state(migrated_campaign) == OK, "候级检查点无法写入真实信封")
	expect(
		FileAccess.get_file_as_bytes(protected_v2_absolute) == v2_primary_bytes,
		"后续 v3 自动保存覆盖了受保护的 v2 原始副本"
	)
	var pentad_summary := manager.progress_summary()
	expect(
		String(pentad_summary.get("checkpoint_level_id", "")) == "spring_yushui"
		and int(pentad_summary.get("checkpoint_pentads_completed", 0)) == 1
		and String(pentad_summary.get("next_segment", "")) == "spring_yushui",
		"继续游戏摘要没有区分主蜂巢与整候检查点"
	)
	var restored_pentad = CampaignStateScript.new()
	expect(
		manager.restore_journey_state(restored_pentad) == OK
		and int(restored_pentad.event_checkpoint.get("next_event_number", 0)) == 6
		and is_equal_approx(float(restored_pentad.event_checkpoint.get("energy", -1.0)), 68.0),
		"真实信封往返没有保留候级进度与体力"
	)

	expect(manager.set_setting("music_volume", 0.45) == OK, "音乐音量无法保存")
	expect(manager.set_setting("music_muted", true) == OK, "音乐静音无法保存")
	expect(manager.set_setting("sfx_volume", 0.65) == OK, "音效音量无法保存")
	expect(manager.set_setting("ui_scale", 1.3) == OK, "界面缩放无法保存")
	expect(manager.set_setting("screen_shake", true) == OK, "屏幕震动开关无法保存")
	expect(manager.set_setting("reduce_motion", true) == OK, "减少动态无法保存")
	expect(not bool(manager.setting("screen_shake", true)), "减少动态没有可靠关闭屏幕震动")
	expect(manager.set_setting("show_control_hints", false) == OK, "操作提示开关无法保存")
	expect(
		manager.set_setting("campaign_energy_tutorial_version", 1) == OK,
		"体力教学版本无法保存"
	)
	var previous_volume := float(manager.setting("music_volume"))
	expect(manager.set_setting("music_volume", "loud") == ERR_INVALID_DATA, "错误类型的音量设置被写入")
	expect(is_equal_approx(float(manager.setting("music_volume")), previous_volume), "错误设置没有回滚")
	for invalid_tutorial_version in [-1, 1.5, "one"]:
		expect(
			manager.set_setting(
				"campaign_energy_tutorial_version",
				invalid_tutorial_version
			) == ERR_INVALID_DATA
			and int(manager.setting("campaign_energy_tutorial_version", -1)) == 1,
			"非法体力教学版本没有被拒绝并回滚：%s" % str(invalid_tutorial_version)
		)

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
		and not bool(reloaded_settings.setting("show_control_hints"))
		and int(reloaded_settings.setting("campaign_energy_tutorial_version", 0)) == 1,
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
		"%s%s" % [progress_path, PersistenceScript.LEGACY_V2_BACKUP_SUFFIX],
		"%s%s.tmp" % [progress_path, PersistenceScript.LEGACY_V2_BACKUP_SUFFIX],
		settings_path,
		"%s.tmp" % settings_path,
		"%s.bak" % settings_path,
	]:
		if path.is_empty():
			continue
		var absolute := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(absolute):
			DirAccess.remove_absolute(absolute)
