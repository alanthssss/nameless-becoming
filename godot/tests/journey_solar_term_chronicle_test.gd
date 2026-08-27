extends SceneTree

const ChronicleScript := preload("res://scripts/world/journey_solar_term_chronicle.gd")
const JourneyStateScript := preload("res://scripts/world/journey_state.gd")
const BoardScript := preload("res://scripts/world/journey_solar_term_board.gd")

const EXPECTED_NAMES := [
	"立春", "雨水", "惊蛰", "春分", "清明", "谷雨",
	"立夏", "小满", "芒种", "夏至", "小暑", "大暑",
	"立秋", "处暑", "白露", "秋分", "寒露", "霜降",
	"立冬", "小雪", "大雪", "冬至", "小寒", "大寒",
]
const EXPECTED_WORK := ["采蜜", "授粉", "搬运", "修补", "留种", "听声", "挡风", "交接"]
const FORBIDDEN_COPY := ["失律", "调律", "净化", "堕落", "预言", "命定", "真正身份", "三弦", "回声板", "校声", "校回声"]

var failures: Array[String] = []


func _init() -> void:
	call_deferred("run_test")


func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func run_test() -> void:
	var chronicle = ChronicleScript.new()
	expect(chronicle.catalog_valid, "当前旅程节气纪事数据未通过结构验证：%s" % chronicle.catalog_error)
	var catalog: Array[Dictionary] = chronicle.catalog_entries()
	expect(catalog.size() == 24 and chronicle.total_count() == 24, "当前旅程节气纪事不是恰好 24 条")
	var names: Array[String] = []
	var ids := {}
	var work_seen := {}
	var season_counts := {"春": 0, "夏": 0, "秋": 0, "冬": 0}
	var all_player_copy := ""
	for index in catalog.size():
		var entry: Dictionary = catalog[index]
		var term_id := String(entry.id)
		var term_name := String(entry.name)
		names.append(term_name)
		expect(not ids.has(term_id), "节气纪事 ID 重复：%s" % term_id)
		ids[term_id] = true
		expect(int(entry.order) == index, "节气纪事顺序号不连续：%s" % term_name)
		var season := String(entry.season)
		season_counts[season] = int(season_counts.get(season, 0)) + 1
		for action in entry.work:
			work_seen[String(action)] = true
		all_player_copy += "%s %s %s %s\n" % [term_name, " ".join(entry.work), String(entry.title), String(entry.record)]
	expect(names == EXPECTED_NAMES, "24 节气名称或顺序不完整：%s" % [names])
	expect(ids.size() == 24, "24 节气没有各自唯一 ID")
	for season in ["春", "夏", "秋", "冬"]:
		expect(int(season_counts[season]) == 6, "%s季不是恰好 6 条节气纪事" % season)
	for action in EXPECTED_WORK:
		expect(work_seen.has(action), "节气纪事没有覆盖正式行为：%s" % action)
	for forbidden in FORBIDDEN_COPY:
		expect(forbidden not in all_player_copy, "节气纪事重新使用已否决表达：%s" % forbidden)

	var first_unlock := chronicle.record_return("spring_route", {"deposit": 6, "pollinations": 2})
	expect(first_unlock.size() == 3 and chronicle.unlocked_count() == 3, "第一次返巢没有落成春季前三条纪事")
	expect("2 朵花" in String(first_unlock[2].resolved_record) and "6 滴蜜" in String(first_unlock[2].resolved_record), "纪事没有保存本次实际授粉和带回结果")
	expect(chronicle.record_return("spring_route", {"deposit": 99}).is_empty(), "重复返巢又插入了一遍同组节气")
	expect(chronicle.unlocked_count() == 3, "重复返巢改变了节气计数")
	expect(chronicle.record_return("not_a_return").is_empty(), "未知返巢类型可以解锁节气")

	var sign_unlock := chronicle.record_return("sign_incident", {"deposit": 5, "honey_lost": 1})
	expect(sign_unlock.size() == 3 and chronicle.unlocked_count() == 6, "春季花牌返巢没有落成后三条纪事")
	var summer_unlock := chronicle.record_return("summer_recovery", {
		"deposit": 7,
		"recovered_honey": 8,
		"honey_lost": 1,
		"belongings_recovered": 3,
	})
	expect(summer_unlock.size() == 6 and chronicle.unlocked_count() == 12, "夏季返巢没有落成六条纪事")
	var autumn_unlock := chronicle.record_return("autumn_harvest", {
		"harvested": 3,
		"seeded": 5,
		"echo_points": 3,
	})
	expect(autumn_unlock.size() == 6 and chronicle.unlocked_count() == 18, "秋季返巢没有落成六条纪事")
	var winter_unlock := chronicle.record_return("winter_warmth", {
		"warmth_links": 4,
		"windbreak_segments": 3,
	})
	expect(winter_unlock.size() == 6 and chronicle.unlocked_count() == 24, "冬季返巢没有落成六条纪事")
	expect(chronicle.progress_snapshot().complete, "全部四季返巢后节气纪事没有标记完成")
	expect(chronicle.unlocked_entries().map(func(entry): return String(entry.name)) == EXPECTED_NAMES, "解锁纪事没有保持正式节气顺序")
	expect(chronicle.record_return("winter_warmth").is_empty() and chronicle.unlocked_count() == 24, "冬季重复结算制造第 25 条纪事")

	var save_data: Dictionary = chronicle.to_save_data()
	var restored = ChronicleScript.new()
	expect(restored.load_save_data(save_data), "节气纪事无法从当前存档格式恢复")
	expect(restored.unlocked_count() == 24, "节气纪事存档恢复丢失进度")
	expect(
		String(restored.unlocked_entries()[2].resolved_record) == String(chronicle.unlocked_entries()[2].resolved_record),
		"节气纪事存档恢复丢失当时的实际数字"
	)
	var migrated = ChronicleScript.new()
	expect(migrated.load_save_data({
		"schema_version": 0,
		"completed_ids": ["summer_xiazhi", "spring_lichun", "spring_lichun", "old_removed_term"],
	}), "旧字段 completed_ids 没有被安全迁移")
	expect(
		migrated.unlocked_entries().map(func(entry): return String(entry.id)) == ["spring_lichun", "summer_xiazhi"],
		"旧存档迁移没有去重、过滤未知 ID 或恢复目录顺序"
	)
	var before_rejected_load := migrated.unlocked_count()
	expect(not migrated.load_save_data({"schema_version": 99, "unlocked_ids": []}), "未来存档版本没有 fail closed")
	expect(migrated.unlocked_count() == before_rejected_load, "拒绝未来存档版本时破坏了现有节气进度")

	# Settlement is the only Journey-state mutation point. Its existing token gate
	# therefore protects honey, world results and the chronicle with one decision.
	var state = JourneyStateScript.new()
	var first_token: int = state.begin_sortie(JourneyState.SPRING_ROUTE)
	expect(state.settle_return(first_token, 6, 2), "状态集成测试无法结算首次返巢")
	expect(state.solar_terms.unlocked_count() == 3, "JourneyState 首次结算没有写入节气纪事")
	expect(not state.settle_return(first_token, 6, 2), "JourneyState 接受了重复 token")
	expect(state.solar_terms.unlocked_count() == 3, "JourneyState 重复 token 复制了节气纪事")
	var sign_token: int = state.begin_sortie(JourneyState.SIGN_INCIDENT)
	expect(state.settle_sign_incident(sign_token, 5, 3, 1), "状态集成测试无法结算花牌事故")
	var summer_token: int = state.begin_sortie(JourneyState.SUMMER_RECOVERY)
	expect(state.settle_summer(summer_token, 7, 8, 1, 3, true), "状态集成测试无法结算夏季")
	var autumn_token: int = state.begin_sortie(JourneyState.AUTUMN_HARVEST)
	expect(state.settle_autumn(autumn_token, 3, 3, 5, 3), "状态集成测试无法结算秋季")
	var winter_token: int = state.begin_sortie(JourneyState.WINTER_WARMTH)
	expect(state.settle_winter(winter_token, 4, 3, true), "状态集成测试无法结算冬季")
	expect(state.solar_terms.unlocked_count() == 24, "JourneyState 四季结算后没有恰好 24 条节气纪事")
	expect(int(state.hive_context(true).solar_terms.unlocked_count) == 24, "巢内上下文没有携带节气纪事进度")

	var legacy_state = JourneyStateScript.new()
	legacy_state.first_return_complete = true
	legacy_state.sign_incident_complete = true
	legacy_state.summer_complete = true
	legacy_state.world_results["spring_honey_lost"] = 1
	legacy_state.world_results["summer_honey_returned"] = 7
	legacy_state.world_results["summer_honey_lost"] = 1
	legacy_state.world_results["summer_belongings_recovered"] = 3
	legacy_state.reconcile_solar_term_progress()
	expect(legacy_state.solar_terms.unlocked_count() == 12, "旧 Journey 存档没有按已完成章节补齐节气纪事")
	legacy_state.reconcile_solar_term_progress()
	expect(legacy_state.solar_terms.unlocked_count() == 12, "旧存档重复迁移复制了节气纪事")

	var board = BoardScript.new()
	board.configure(chronicle)
	root.add_child(board)
	await process_frame
	board.set_hive_available(true)
	expect(board.top_button.visible and "24 / 24" in board.top_button.text, "巢内纪事入口没有显示正式进度")
	board.open_latest()
	expect(board.is_open(), "巢内纪事入口无法打开回看面板")
	expect(String(board.current_entry().name) == "大寒", "纪事面板没有默认翻到最新落成的一张")
	expect("最后一墙" in board.title_label.text and "站稳" in board.title_label.text, "纪事面板没有显示当前小事件标题")
	board.show_previous()
	expect(String(board.current_entry().name) == "小寒", "纪事面板无法逐张回看")
	board.close()
	expect(not board.is_open(), "纪事面板无法收好")
	board.set_hive_available(false)
	expect(not board.top_button.visible, "离开主蜂巢后纪事入口仍遮挡大地图")
	board.queue_free()
	await process_frame

	var empty_board = BoardScript.new()
	empty_board.configure(ChronicleScript.new())
	root.add_child(empty_board)
	await process_frame
	empty_board.set_hive_available(true)
	empty_board.open_latest()
	expect("第一次返巢后" in empty_board.title_label.text, "空纪事板没有解释真实解锁方式")
	empty_board.queue_free()
	await process_frame
	var hive := HiveThresholdArea.new()
	expect(hive.configure({}) == OK, "纪事输入阻断测试无法建立主蜂巢")
	hive.set_departure_input_enabled(false)
	expect(not hive.request_sortie() and hive.ready_for_sortie, "翻纪事时仍会误触出巢")
	hive.set_departure_input_enabled(true)
	expect(hive.request_sortie() and not hive.ready_for_sortie, "收好纪事后没有恢复主蜂巢出发输入")
	hive.free()

	if failures.is_empty():
		print("JOURNEY SOLAR TERM CHRONICLE TEST PASSED")
		print("TEST PASSED")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
