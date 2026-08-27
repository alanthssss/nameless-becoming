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
	expect(catalog.campaign_id == "solar-term-campaign-v2", "战役目录加载了错误的 campaign_id")
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

	if failures.is_empty():
		print("JOURNEY LEVEL CATALOG TEST PASSED")
		print("TEST PASSED")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
