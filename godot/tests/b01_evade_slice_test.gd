extends SceneTree

const SliceScene := preload("res://playtest/b01_evade_slice.tscn")
const EncounterScript := preload("res://scripts/playtest/b01_evade_encounter.gd")
const Rules := preload("res://scripts/mechanics/evade_rules.gd")

var failures: Array[String] = []
var ordinary_save_path := ""
var ordinary_save_sha := ""

func _init() -> void:
	ProjectSettings.set_setting("application/config/use_custom_user_dir", true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name", "nameless-b01-tests-%d" % OS.get_process_id())
	ordinary_save_path = ProjectSettings.globalize_path("user://nameless.cfg")
	DirAccess.make_dir_recursive_absolute(ordinary_save_path.get_base_dir())
	var sentinel := FileAccess.open(ordinary_save_path, FileAccess.WRITE)
	if sentinel != null:
		sentinel.store_string("B01 must neither read nor overwrite this malformed ordinary save.\n")
		sentinel.close()
		ordinary_save_sha = FileAccess.get_sha256(ordinary_save_path)
	call_deferred("run_test")

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func context_fixture() -> Dictionary:
	return {
		"schema_version": 1,
		"session_id": "NB-B01-SLICE-TEST",
		"task": {"code": "B", "slice_code": "B01"},
		"product": {
			"id": "nameless-becoming",
			"display_name": "无名：成蜂",
			"version": String(ProjectSettings.get_setting("application/config/version")),
			"commit": "0123456789abcdef0123456789abcdef01234567",
			"dirty": false,
		},
		"artifact": {
			"platform": "macos-universal",
			"filename": "NamelessBecoming-macOS.zip",
			"size": 12345,
			"sha256": "a".repeat(64),
			"manifest_sha256": "b".repeat(64),
		},
		"catalog_sha256": "c".repeat(64),
		"slice": {
			"code": "B01",
			"assignment": "固定切片 B01",
			"maximum_minutes": 10,
			"status": "ready",
		},
		"ticket_sha256": "d".repeat(64),
	}

func runtime_slice() -> B01EvadeSlice:
	var slice := SliceScene.instantiate() as B01EvadeSlice
	expect(slice != null, "B01 typed scene 无法实例化")
	if slice == null:
		return null
	expect(slice.configure_playtest_session(context_fixture()) == OK, "合法 B01 ready/10min context 被拒绝")
	root.add_child(slice)
	slice._focus_active = true
	return slice

func test_context_contract() -> void:
	var valid := SliceScene.instantiate() as B01EvadeSlice
	expect(valid.configure_playtest_session(context_fixture()) == OK, "exact B01 context 未通过")
	expect(valid.configure_playtest_session(context_fixture()) == ERR_ALREADY_IN_USE, "同一 scene 可重复配置 context")
	valid.free()

	var cases: Array[Dictionary] = []
	var unknown := context_fixture()
	unknown["handler"] = "forbidden"
	cases.append(unknown)
	var wrong_code := context_fixture()
	wrong_code.task.slice_code = "B02"
	cases.append(wrong_code)
	var blocked := context_fixture()
	blocked.slice.status = "blocked"
	cases.append(blocked)
	var wrong_limit := context_fixture()
	wrong_limit.slice.maximum_minutes = 9
	cases.append(wrong_limit)
	var dirty := context_fixture()
	dirty.product.dirty = true
	cases.append(dirty)
	var short_commit := context_fixture()
	short_commit.product.commit = "01234567"
	cases.append(short_commit)
	var bad_artifact := context_fixture()
	bad_artifact.artifact["stage"] = 3
	cases.append(bad_artifact)
	for invalid_context in cases:
		var slice := SliceScene.instantiate() as B01EvadeSlice
		expect(slice.configure_playtest_session(invalid_context) == ERR_INVALID_DATA, "非法或非 exact context 未被拒绝：%s" % JSON.stringify(invalid_context))
		slice.free()

func test_encounter_causality() -> void:
	var encounter := EncounterScript.new()
	encounter.begin(Vector2(980.0, 170.0), 5)
	expect(EncounterScript.ATTACKER_BOUNDS.has_point(encounter.attacker_position), "边界蜂位使 attacker 生成到 WORLD 外")
	expect(not encounter.mark_evade_attempted(), "aim 阶段抢跑被记录为有效尝试")
	var event: Dictionary = encounter.advance(EncounterScript.AIM_SECONDS, Vector2(960.0, 180.0), 9)
	expect(event.kind == "locked", "encounter 未在固定 aim 时长后锁定")
	expect(encounter.evade_sequence_at_lock == 9, "aim -> locked 未原子捕获当前 evade sequence")
	expect(not encounter.evade_attempted, "aim 抢跑污染 attempted 结果")
	expect(encounter.mark_evade_attempted(), "locked 后输入未记录为有效尝试")
	var signature: Dictionary = encounter.config_signature()
	expect(signature.path_clearance == Rules.PATH_CLEARANCE and signature.attack_cross_radius == Rules.ATTACK_CROSS_RADIUS, "encounter 未使用共享 EvadeRules 事实")

func test_timeline_and_pause() -> void:
	var slice := runtime_slice()
	if slice == null:
		return
	expect(slice.phase == B01EvadeSlice.PHASE_DEMONSTRATION and not slice.input_enabled, "B01 未从不可输入的 2.8s 示范开始")
	slice._advance_session(2.799, true)
	expect(slice.phase == B01EvadeSlice.PHASE_DEMONSTRATION, "老师傅示范不足 2.8s 就结束")
	slice._advance_session(0.001, true)
	expect(slice.phase == B01EvadeSlice.PHASE_GUIDED and slice.input_enabled, "2.8s 后未进入引导模仿")

	for attempt in 4:
		slice._resolve_current_encounter(false, false)
	expect(slice.guided_attempts == 4 and slice.phase == B01EvadeSlice.PHASE_PRACTICE, "引导未在 4 次有效尝试处有界结束")
	var teaching_count := slice.teaching_display_count
	expect(slice.current_instruction.is_empty() and not slice._instruction_panel.visible, "无提示实践仍显示教学文字")

	slice._advance_session(B01EvadeSlice.ENCOUNTER_RECOVERY_SECONDS, true)
	var practice_signature: Dictionary = slice._last_encounter_signature.duplicate(true)
	slice._resolve_current_encounter(true, true)
	expect(slice.phase == B01EvadeSlice.PHASE_DELAY and slice.delay_active_seconds == 0.0, "实践首次成功未锚定延迟路线")
	var bee_process_mode := slice.bee.process_mode
	var hard_before_pause := slice.hard_elapsed_seconds
	root.get_tree().paused = true
	slice._physics_process(25.0)
	root.get_tree().paused = false
	expect(slice.delay_active_seconds == 0.0, "暂停仍推进 180s active delay")
	expect(slice.hard_elapsed_seconds == hard_before_pause + 25.0, "暂停时 600s hard clock 未继续")
	expect(bee_process_mode == Node.PROCESS_MODE_PAUSABLE and not slice.bee.active and not slice.bee.is_physics_processing(), "ALWAYS root 下 Bee 未显式冻结")

	slice._advance_session(179.999, true)
	expect(slice.phase == B01EvadeSlice.PHASE_DELAY and is_equal_approx(slice.delay_active_seconds, 179.999), "179.999s 就错误打开复测")
	expect(slice.teaching_display_count == teaching_count and slice.current_instruction.is_empty(), "延迟路线重新显示了教学")
	slice._advance_session(0.001, true)
	expect(slice.phase == B01EvadeSlice.PHASE_RETEST, "180.000s active delay 未打开复测")
	expect(slice.retest_opportunities == 1, "复测机会不是恰好一次")
	expect(slice._last_encounter_signature == practice_signature and slice.encounter.config_signature() == practice_signature, "实践与复测未使用同一 encounter 配置")
	expect(slice.teaching_display_count == teaching_count and slice.current_instruction.is_empty(), "复测泄露教学或答案文字")

	slice.encounter.state_seconds = 0.12
	slice.input_controller.direction_tap_times.left = 4.0
	var hard_before_focus := slice.hard_elapsed_seconds
	slice._set_focus_active(false)
	expect(slice.encounter.state == B01EvadeEncounter.STATE_AIM and is_equal_approx(slice.encounter.state_seconds, B01EvadeEncounter.AIM_SECONDS), "复测 aim 失焦未从完整 aim 重启")
	expect(slice.input_controller.direction_tap_times.left == 0.0 and slice.retest_opportunities == 1 and slice.result_code.is_empty(), "失焦消费机会、保留输入或判定失败")
	expect(not slice.bee.is_physics_processing(), "失焦仍推进 Bee cooldown／移动状态")
	slice._advance_session(30.0, false)
	expect(is_equal_approx(slice.encounter.state_seconds, B01EvadeEncounter.AIM_SECONDS), "失焦期间 encounter 仍推进")
	expect(slice.hard_elapsed_seconds == hard_before_focus + 30.0, "失焦期间 hard clock 未推进")
	slice._set_focus_active(true)

	slice.encounter.state = B01EvadeEncounter.STATE_LOCKED
	slice._consume_evade_input({"evade_attempted": true})
	slice._resolve_current_encounter(false, true)
	expect(slice.phase == B01EvadeSlice.PHASE_COMPLETE and slice.result_code == B01EvadeSlice.RESULT_INCOMPLETE, "复测已尝试未完成未形成唯一结果")
	expect(not slice.input_enabled and not slice.bee.active and slice._end_panel.visible, "终屏没有关闭输入和玩家移动")
	var settled_result := slice.result_code
	slice._resolve_current_encounter(true, true)
	expect(slice.result_code == settled_result and slice.retest_opportunities == 1, "终局被二次结算或生成第二次复测")
	slice.free()

func test_terminal_results_and_limits() -> void:
	var completed := runtime_slice()
	completed._begin_unprompted_retest()
	completed._resolve_current_encounter(true, true)
	expect(completed.result_code == B01EvadeSlice.RESULT_COMPLETED, "独立完成结果错误")
	completed.free()

	var not_attempted := runtime_slice()
	not_attempted._begin_unprompted_retest()
	not_attempted._consume_evade_input({"evade_attempted": true})
	expect(not not_attempted._any_player_attempt and not not_attempted.encounter.evade_attempted, "复测 aim 抢跑被计入最终尝试")
	not_attempted._resolve_current_encounter(false, false)
	expect(not_attempted.result_code == B01EvadeSlice.RESULT_NOT_ATTEMPTED, "未尝试结果错误")
	not_attempted.free()

	var practice_limit := runtime_slice()
	practice_limit._begin_unprompted_practice()
	for attempt in 3:
		practice_limit._resolve_current_encounter(false, true)
	expect(practice_limit.practice_attempts == 3 and practice_limit.result_code == B01EvadeSlice.RESULT_INCOMPLETE, "实践未在 3 次有效尝试后中性结束")
	practice_limit.free()

	var hard_limit := runtime_slice()
	hard_limit._advance_session(B01EvadeSlice.HARD_LIMIT_SECONDS, false)
	expect(hard_limit.phase == B01EvadeSlice.PHASE_COMPLETE and hard_limit.result_code == B01EvadeSlice.RESULT_NOT_ATTEMPTED, "600s hard limit 未单次中性结束")
	hard_limit.free()

	var guided_timeout := runtime_slice()
	guided_timeout._begin_guided_imitation()
	guided_timeout._advance_session(B01EvadeSlice.GUIDED_MAX_SECONDS, true)
	expect(guided_timeout.phase == B01EvadeSlice.PHASE_PRACTICE, "引导未在 90s 上限进入无提示实践")
	guided_timeout.free()

	var practice_timeout := runtime_slice()
	practice_timeout._begin_unprompted_practice()
	practice_timeout._advance_session(B01EvadeSlice.PRACTICE_MAX_SECONDS, true)
	expect(practice_timeout.phase == B01EvadeSlice.PHASE_COMPLETE and practice_timeout.result_code == B01EvadeSlice.RESULT_NOT_ATTEMPTED, "实践未在 90s 上限中性结束")
	practice_timeout.free()

func test_shared_rule_runtime_wiring() -> void:
	var slice := runtime_slice()
	slice._begin_unprompted_retest()
	var lock_event: Dictionary = slice.encounter.advance(
		B01EvadeEncounter.AIM_SECONDS,
		slice.bee.position,
		slice.bee.evade_sequence
	)
	expect(lock_event.kind == "locked", "B01 runtime encounter 未进入 locked")
	slice.input_controller.clear(slice.bee)
	var escape_directions := Rules.cardinal_escape_directions(
		slice.encounter.locked_target,
		slice.encounter.aim_direction,
		B01EvadeSlice.BEE_CENTER_BOUNDS
	)
	expect(not escape_directions.is_empty(), "共享规则未给 B01 中央锁点提供可行侧向")
	if not escape_directions.is_empty():
		var escape: Vector2 = escape_directions[0]
		var locked_target := slice.encounter.locked_target
		slice.bee.evade_cooldown = 0.0
		slice.bee.energy = slice.bee.max_energy
		expect(slice.bee.try_evade(escape, locked_target), "BeePlayer 同输入事实未发动复测急转")
		slice.bee.position = locked_target + escape * (Rules.PATH_CLEARANCE + 2.0)
		slice._consume_evade_input({"evade_attempted": true})
		slice.encounter.advance(B01EvadeEncounter.LOCK_SECONDS, slice.bee.position, slice.bee.evade_sequence)
		slice._advance_encounter(0.5)
		expect(slice.result_code == B01EvadeSlice.RESULT_COMPLETED, "B01 未用共享因果规则结算真实 locked-path 急转")
	slice.free()

func test_no_save_or_private_runtime() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/playtest/b01_evade_slice.gd")
	var encounter_source := FileAccess.get_file_as_string("res://scripts/playtest/b01_evade_encounter.gd")
	var combined := source + "\n" + encounter_source
	for forbidden in ["main.tscn", "mentor_tutorial.gd", "save_manager.gd", "user://", "ConfigFile.new", "stage_index", "tutorial_step"]:
		expect(not combined.contains(forbidden), "B01 私有 runtime 泄露或存档依赖：%s" % forbidden)
	expect(source.contains("evade_input_controller.gd") and encounter_source.contains("evade_rules.gd"), "B01 未接入共享输入／因果规则")
	expect(source.contains("player_bee_v1.png") and source.contains("mosquito_v1.png") and source.contains("_draw_demo_double_tap_cues"), "B01 示范仍用抽象圆点或没有可见双击节奏")
	expect(not ordinary_save_sha.is_empty() and FileAccess.get_sha256(ordinary_save_path) == ordinary_save_sha, "B01 session 改写了普通存档 sentinel")

func run_test() -> void:
	test_context_contract()
	test_encounter_causality()
	test_timeline_and_pause()
	test_terminal_results_and_limits()
	test_shared_rule_runtime_wiring()
	test_no_save_or_private_runtime()
	root.get_tree().paused = false
	if failures.is_empty():
		print("B01 EVADE SLICE TEST PASSED")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
