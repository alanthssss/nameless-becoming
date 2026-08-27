extends SceneTree

const CatalogScript := preload("res://scripts/world/journey_level_catalog.gd")
const EXPECTED_CLIMAX_ORDERS := [5, 11, 17, 23]
const EXPECTED_SEASONS := ["spring", "summer", "autumn", "winter"]

var failures: Array[String] = []


func _init() -> void:
	call_deferred("run_test")


func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func run_test() -> void:
	var catalog = CatalogScript.new()
	expect(catalog.catalog_valid, "正式战役目录无法通过运行时校验：%s" % catalog.catalog_error)
	expect(catalog.campaign_id == "solar-term-campaign-v3", "战役目录加载了错误的 campaign_id")
	expect(catalog.total_count() == 24, "战役目录运行时没有恰好加载 24 关")

	var levels: Array[Dictionary] = catalog.levels()
	var season_counts := {"spring": 0, "summer": 0, "autumn": 0, "winter": 0}
	var climax_orders: Array[int] = []
	for order in levels.size():
		var level: Dictionary = levels[order]
		var level_id := String(level.get("id", ""))
		var season_id := String(level.get("season_id", ""))
		expect(int(level.get("order", -1)) == order, "第 %d 关运行时顺序号不连续" % (order + 1))
		expect(int(level.get("number", -1)) == order + 1, "第 %d 关没有一基展示编号" % (order + 1))
		expect(catalog.has_level(level_id), "按 ID 无法找到第 %d 关" % (order + 1))
		expect(catalog.order_of(level_id) == order, "第 %d 关的 ID 反查顺序错误" % (order + 1))
		expect(catalog.level_by_id(level_id) == level, "第 %d 关按 ID 与按顺序读取不一致" % (order + 1))
		expect(String(level.get("term_name", "")).length() > 0, "第 %d 关没有合并节气名" % (order + 1))
		expect(String(level.get("chronicle_title", "")).length() > 0, "第 %d 关没有合并纪事标题" % (order + 1))
		expect(String(level.get("chronicle_record", "")).length() > 0, "第 %d 关没有合并纪事正文" % (order + 1))
		expect(level.get("work_tags", []) is Array and not Array(level.get("work_tags", [])).is_empty(), "第 %d 关没有合并工作标签" % (order + 1))
		if season_counts.has(season_id):
			season_counts[season_id] = int(season_counts[season_id]) + 1
		else:
			expect(false, "第 %d 关出现未知季节 %s" % [order + 1, season_id])
		if catalog.is_climax(level_id):
			climax_orders.append(order)
			expect(Array(level.get("phases", [])).size() == 3, "第 %d 关不是三阶段高潮关" % (order + 1))

	expect(climax_orders == EXPECTED_CLIMAX_ORDERS, "四个高潮关没有固定在 6/12/18/24 关：%s" % str(climax_orders))
	for season in EXPECTED_SEASONS:
		expect(int(season_counts[season]) == 6, "%s 季运行时不是 6 关" % season)

	expect(String(catalog.level_at(0).get("id", "")) == "spring_lichun", "战役第一关不是立春")
	expect(String(catalog.level_at(23).get("id", "")) == "winter_dahan", "战役最终关不是大寒")
	var expected_slice_optional := {"spring_yushui": 6, "spring_guyu": 4}
	var gameplay_approval_count := 0
	var science_approval_count := 0
	var authored_choice_count := 0
	for slice_id in expected_slice_optional:
		var slice_level: Dictionary = catalog.level_by_id(slice_id)
		var matrix: Array = slice_level.get("event_matrix", [])
		expect(matrix.size() == 15, "%s 没有恰好 15 项三候内容" % slice_id)
		var event_ids := {}
		var mechanics := {}
		var optional_count := 0
		for event_index in matrix.size():
			var event := matrix[event_index] as Dictionary
			var event_id := String(event.get("id", ""))
			event_ids[event_id] = true
			mechanics[String(event.get("mechanic", ""))] = true
			optional_count += 1 if bool(event.get("optional", false)) else 0
			var verification_status := String(event.get("verification_status", ""))
			var choice_options := event.get("choice_options", {}) as Dictionary
			if not choice_options.is_empty():
				authored_choice_count += 1
				expect(
					choice_options.has("swift") and choice_options.has("steady"),
					"%s 第 %d 项选择没有两种可执行做法" % [slice_id, event_index + 1]
				)
			else:
				expect("或" not in String(event.get("decision", "")), "%s 第 %d 项仍写着不可执行的假二选一" % [slice_id, event_index + 1])
			gameplay_approval_count += 1 if verification_status == "approved-for-gameplay" else 0
			science_approval_count += 1 if verification_status == "approved-for-player-facing-science" else 0
			expect(not event.has("science_approval"), "%s 第 %d 项玩法内容携带了未获批准的科普字段" % [slice_id, event_index + 1])
			expect(int(event.get("order", -1)) == event_index + 1, "%s 第 %d 项顺序错误" % [slice_id, event_index + 1])
			expect(int(event.get("pentad", -1)) == floori(float(event_index) / 5.0) + 1, "%s 第 %d 项三候错误" % [slice_id, event_index + 1])
			expect(not String(event.get("decision", "")).is_empty(), "%s 第 %d 项没有判断" % [slice_id, event_index + 1])
			expect(not String(event.get("operation", "")).is_empty(), "%s 第 %d 项没有操作" % [slice_id, event_index + 1])
			expect(not String(event.get("consequence", "")).is_empty(), "%s 第 %d 项没有可见后果" % [slice_id, event_index + 1])
			expect(String(event.get("claim_scope", "")) == "design-fiction", "%s 第 %d 项没有标明游戏化转译" % [slice_id, event_index + 1])
		expect(event_ids.size() == 15, "%s 内容 ID 有重复" % slice_id)
		expect(mechanics.size() >= 10, "%s 玩法机制少于 10 种，仍像重复清单" % slice_id)
		expect(optional_count == int(expected_slice_optional[slice_id]), "%s 主线／自选数量错误" % slice_id)
	expect(gameplay_approval_count == 30, "首批 30 项没有全部明确停留在玩法批准")
	expect(science_approval_count == 0, "首批 30 项误冒充已获玩家可见科普批准")
	expect(authored_choice_count == 12, "首批内容的 12 个关键二选一没有完整进入数据合同")
	var pollen_rainline: Dictionary = (
		catalog.level_by_id("spring_yushui").get("event_matrix", []) as Array
	)[3] as Dictionary
	expect(
		Array(pollen_rainline.get("source_ids", [])).has("APIC-CAS-1999-01")
		and Array(pollen_rainline.get("source_ids", [])).has("APIC-CAAS-2001-02"),
		"雨水第 4 项的授粉延迟事实没有映射到 CAS／CAAS 正文来源"
	)
	expect(
		"rejected" not in CatalogScript.EVENT_VERIFICATION_STATUSES
		and "candidate" not in CatalogScript.EVENT_VERIFICATION_STATUSES
		and "modern-crosscheck-required" not in CatalogScript.EVENT_VERIFICATION_STATUSES,
		"未批准或已拒绝的事件状态仍可进入运行目录"
	)
	expect(
		CatalogScript.EVENT_FACT_SOURCE_IDS.get("POLLINATION-LAG-01", [])
		== ["APIC-CAS-1999-01", "APIC-CAAS-2001-02"],
		"授粉延迟事实卡的合法来源映射与登记表不一致"
	)
	expect(
		CatalogScript.PLAYER_FACING_SCIENCE_APPROVALS.is_empty(),
		"尚无现代交叉核验与顾问批准，却预登记了玩家可见科普合同"
	)
	var science_fixture := pollen_rainline.duplicate(true)
	science_fixture["verification_status"] = "approved-for-player-facing-science"
	expect(
		not catalog._player_facing_science_approval_error(science_fixture).is_empty(),
		"只改科普状态字符串即可绕过批准门禁"
	)
	var fixture_hash := "a".repeat(64)
	var registered_approval := {
		"modern_source_ids": ["MODERN-TEST-01"],
		"advisor_review_id": "ADVISOR-TEST-01",
		"reviewed_fact_ids": Array(science_fixture.get("fact_ids", [])).duplicate(),
		"player_facing_copy_sha256": fixture_hash,
	}
	(science_fixture.get("source_ids", []) as Array).append("MODERN-TEST-01")
	science_fixture["science_approval"] = registered_approval.duplicate(true)
	(science_fixture["science_approval"] as Dictionary)["approval_id"] = "SCIENCE-TEST-01"
	var fixture_registry := {"SCIENCE-TEST-01": registered_approval}
	expect(
		catalog._player_facing_science_approval_error(science_fixture, fixture_registry).is_empty(),
		"完整的现代来源、顾问、事实集合与文案哈希合同未能通过纯合同校验"
	)
	var forged_science_fixture := science_fixture.duplicate(true)
	(forged_science_fixture["science_approval"] as Dictionary)["advisor_review_id"] = "ADVISOR-FORGED"
	expect(
		not catalog._player_facing_science_approval_error(forged_science_fixture, fixture_registry).is_empty(),
		"任意顾问批准字符串可以绕过登记合同"
	)
	(forged_science_fixture["science_approval"] as Dictionary)["advisor_review_id"] = "ADVISOR-TEST-01"
	(forged_science_fixture["science_approval"] as Dictionary)["reviewed_fact_ids"] = []
	expect(
		not catalog._player_facing_science_approval_error(forged_science_fixture, fixture_registry).is_empty(),
		"未覆盖事实卡的科普批准可以通过登记合同"
	)
	expect(catalog.level_at(-1).is_empty() and catalog.level_at(24).is_empty(), "越界顺序可以读出伪关卡")
	expect(catalog.level_by_id("missing-level").is_empty(), "未知 ID 可以读出伪关卡")
	expect(catalog.order_of("missing-level") == -1 and not catalog.has_level("missing-level"), "未知 ID 查询没有 fail closed")
	expect(catalog.first_incomplete_id(0) == "spring_lichun", "空进度没有指向第一关")
	expect(catalog.first_incomplete_id(6) == "summer_lixia", "春季完成后没有指向立夏")
	expect(catalog.first_incomplete_id(23) == "winter_dahan", "最终关前没有指向大寒")
	expect(catalog.first_incomplete_id(-1).is_empty() and catalog.first_incomplete_id(24).is_empty(), "无效完成数可以生成下一关")

	# Callers receive deep copies so a scene cannot rewrite authoritative rewards,
	# objectives, or chronology through a returned Dictionary.
	var copied_levels: Array[Dictionary] = catalog.levels()
	copied_levels[0]["reward_honey"] = 999
	(copied_levels[0]["objectives"] as Array)[0]["goal"] = 999
	expect(int(catalog.level_at(0).get("reward_honey", -1)) == 6, "外部列表改写了目录奖励")
	expect(int((catalog.level_at(0).get("objectives", []) as Array)[0].get("goal", -1)) == 2, "外部列表改写了目录目标")
	var copied_level := catalog.level_by_id("winter_dahan")
	copied_level["world_trace"] = "tampered"
	expect(String(catalog.level_by_id("winter_dahan").get("world_trace", "")) != "tampered", "按 ID 返回值泄漏了目录内部引用")
	var copied_slice := catalog.level_by_id("spring_yushui")
	(copied_slice.get("event_matrix", []) as Array)[0]["title"] = "tampered"
	expect(
		String(((catalog.level_by_id("spring_yushui").get("event_matrix", []) as Array)[0] as Dictionary).get("title", "")) != "tampered",
		"三候内容矩阵泄漏了目录内部引用"
	)

	if failures.is_empty():
		print("JOURNEY LEVEL CATALOG TEST PASSED")
		print("TEST PASSED")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
