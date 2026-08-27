class_name JourneyLevelCatalog
extends RefCounted

## Authoritative catalog for the formal twenty-four-level campaign. Runtime
## scenes receive a validated duplicate; they never decide progression or
## rewards from ad-hoc scene payloads.

const LEVELS_PATH := "res://data/journey_levels.json"
const CHRONICLE_PATH := "res://data/journey_solar_term_chronicles.json"
const SCHEMA_VERSION := 1
const TOTAL_LEVELS := 24
const SEASON_IDS := ["spring", "summer", "autumn", "winter"]
const SEASON_NAMES := {
	"spring": "春",
	"summer": "夏",
	"autumn": "秋",
	"winter": "冬",
}
const LEVEL_KINDS := ["standard", "climax"]
const CLIMAX_ORDERS := [5, 11, 17, 23]
const SCENE_KEYS := [
	"spring_prologue",
	"spring_term_field",
	"spring_climax",
	"summer_term_field",
	"summer_climax",
	"autumn_term_field",
	"autumn_climax",
	"winter_term_field",
	"winter_climax",
]
const OBJECTIVE_TYPES := [
	"pollinate", "collect", "observe", "frighten", "carry", "repair",
	"seed", "shell", "warmth", "anchor", "climax", "event",
]
const CONTENT_SLICE_LEVEL_IDS := ["spring_yushui", "spring_guyu"]
const EVENT_MECHANICS := [
	"weather_window", "stabilize_lane", "coop_anchor", "pollen_delivery",
	"rhythm_lane", "route_reveal", "sequence_carry", "handoff_timing",
	"escort_shelter", "moving_shelter", "load_choice", "partner_rescue",
	"mastery_lane", "weather_reread", "convoy_setpiece", "convoy_route",
	"evade_lane", "spatial_match", "route_trial", "trace_search",
	"optional_recovery", "air_catch", "support_choice", "heavy_carry",
	"moving_match", "convoy_anchor",
]
const EVENT_VERIFICATION_STATUSES := [
	"approved-for-gameplay", "approved-for-player-facing-science",
]
# Player-facing science is a separate, fail-closed release gate. An entry in
# this registry may only be added after its modern sources, named advisor
# review, reviewed fact set, and exact player-facing copy hash are archived.
# The historical manuals below can seed gameplay, but none currently satisfies
# that contract, so the production registry intentionally starts empty.
const PLAYER_FACING_SCIENCE_APPROVALS := {}
const EVENT_SOURCE_IDS := [
	"G-FICTION", "APIC-JX-1976-01", "APIC-CAS-1999-01",
	"APIC-CAAS-2001-02",
]
const EVENT_FACT_SOURCE_IDS := {
	"BEE-WORK-01": ["APIC-JX-1976-01", "APIC-CAS-1999-01", "APIC-CAAS-2001-02"],
	"BEE-HIVEWORK-01": ["APIC-JX-1976-01", "APIC-CAS-1999-01", "APIC-CAAS-2001-02"],
	"BEE-WAX-01": ["APIC-JX-1976-01"],
	"BEE-POLLEN-01": ["APIC-JX-1976-01"],
	"BEE-NECTAR-01": ["APIC-JX-1976-01", "APIC-CAS-1999-01", "APIC-CAAS-2001-02"],
	"BEE-SCOUT-01": ["APIC-JX-1976-01", "APIC-CAAS-2001-02"],
	"BEE-ORIENT-01": ["APIC-JX-1976-01", "APIC-CAS-1999-01", "APIC-CAAS-2001-02"],
	"BEE-HOMEOSTASIS-01": ["APIC-JX-1976-01", "APIC-CAS-1999-01", "APIC-CAAS-2001-02"],
	"PLANT-MICROCLIMATE-01": ["APIC-JX-1976-01", "APIC-CAS-1999-01", "APIC-CAAS-2001-02"],
	"PHENOLOGY-DIARY-01": ["APIC-JX-1976-01", "APIC-CAS-1999-01", "APIC-CAAS-2001-02"],
	"POLLINATION-LAG-01": ["APIC-CAS-1999-01", "APIC-CAAS-2001-02"],
}

var catalog_valid := false
var catalog_error := ""
var campaign_id := ""
var _levels: Array[Dictionary] = []
var _level_by_id: Dictionary = {}


func _init(levels_path := LEVELS_PATH, chronicle_path := CHRONICLE_PATH) -> void:
	_load(levels_path, chronicle_path)


func _load(levels_path: String, chronicle_path: String) -> void:
	catalog_valid = false
	catalog_error = ""
	campaign_id = ""
	_levels.clear()
	_level_by_id.clear()
	var level_document = _read_json_dictionary(levels_path, "关卡目录")
	if not level_document is Dictionary:
		return
	var chronicle_document = _read_json_dictionary(chronicle_path, "节气纪事")
	if not chronicle_document is Dictionary:
		return
	if int(level_document.get("schema_version", -1)) != SCHEMA_VERSION:
		_fail("关卡目录版本不受支持")
		return
	if int(level_document.get("total_levels", -1)) != TOTAL_LEVELS:
		_fail("正式战役必须声明恰好 %d 关" % TOTAL_LEVELS)
		return
	campaign_id = String(level_document.get("campaign_id", ""))
	if campaign_id.is_empty():
		_fail("关卡目录缺少 campaign_id")
		return
	var raw_levels = level_document.get("levels", [])
	var raw_terms = chronicle_document.get("terms", [])
	if not raw_levels is Array or raw_levels.size() != TOTAL_LEVELS:
		_fail("正式战役必须恰好有 %d 条关卡数据" % TOTAL_LEVELS)
		return
	if not raw_terms is Array or raw_terms.size() != TOTAL_LEVELS:
		_fail("节气纪事必须与正式战役一一对应")
		return
	var seen_ids := {}
	var season_counts := {"spring": 0, "summer": 0, "autumn": 0, "winter": 0}
	var climax_count := 0
	for index in TOTAL_LEVELS:
		var raw_level = raw_levels[index]
		var raw_term = raw_terms[index]
		if not raw_level is Dictionary or not raw_term is Dictionary:
			_fail("第 %d 关或对应节气纪事不是对象" % (index + 1))
			return
		var level := (raw_level as Dictionary).duplicate(true)
		var term := raw_term as Dictionary
		if not _validate_level(level, term, index, seen_ids, season_counts):
			return
		level["number"] = index + 1
		level["term_name"] = String(term.get("name", ""))
		level["season_name"] = String(term.get("season", ""))
		level["chronicle_title"] = String(term.get("title", ""))
		level["chronicle_record"] = String(term.get("record", ""))
		level["work_tags"] = Array(term.get("work", [])).duplicate()
		if String(level.kind) == "climax":
			climax_count += 1
		_levels.append(level)
		_level_by_id[String(level.id)] = level
	for season_id in SEASON_IDS:
		if int(season_counts[season_id]) != 6:
			_fail("%s季必须恰好有 6 关" % String(SEASON_NAMES[season_id]))
			return
	if climax_count != 4:
		_fail("正式战役必须恰好有 4 个三阶段高潮关")
		return
	catalog_valid = true


func _read_json_dictionary(path: String, label: String) -> Variant:
	if not FileAccess.file_exists(path):
		_fail("%s不存在：%s" % [label, path])
		return null
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		_fail("%s根节点不是对象" % label)
		return null
	return parsed


func _has_exact_dictionary_keys(source: Dictionary, keys: Array) -> bool:
	if source.size() != keys.size():
		return false
	for key in keys:
		if not source.has(key):
			return false
	return true


func _is_saved_integer(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or (
		typeof(value) == TYPE_FLOAT
		and is_finite(float(value))
		and is_equal_approx(float(value), roundf(float(value)))
	)


func _validate_level(
	level: Dictionary,
	term: Dictionary,
	index: int,
	seen_ids: Dictionary,
	season_counts: Dictionary
) -> bool:
	var required := [
		"id", "order", "season_id", "kind", "scene_key", "scenario_id",
		"reward_honey", "target_minutes", "time_limit_seconds", "energy_drain",
		"hazard", "map_variant", "intro", "dialogue", "world_trace", "objectives",
	]
	for key in required:
		if not level.has(key):
			_fail("第 %d 关缺少 %s" % [index + 1, key])
			return false
	var level_id := String(level.id)
	var season_id := String(level.season_id)
	var kind := String(level.kind)
	if level_id.is_empty() or seen_ids.has(level_id):
		_fail("第 %d 关 ID 为空或重复：%s" % [index + 1, level_id])
		return false
	if level_id != String(term.get("id", "")) or index != int(term.get("order", -1)):
		_fail("第 %d 关与节气纪事没有按 ID 和顺序对齐" % (index + 1))
		return false
	if int(level.order) != index:
		_fail("第 %d 关顺序号不连续" % (index + 1))
		return false
	if season_id not in SEASON_IDS or String(term.get("season", "")) != String(SEASON_NAMES.get(season_id, "")):
		_fail("第 %d 关季节无效或与节气纪事不符" % (index + 1))
		return false
	if int(level.map_variant) != index % 6:
		_fail("第 %d 关地图变体必须在季内按 0—5 排列" % (index + 1))
		return false
	if kind not in LEVEL_KINDS or String(level.scene_key) not in SCENE_KEYS:
		_fail("第 %d 关类型或场景键无效" % (index + 1))
		return false
	var should_be_climax := index in CLIMAX_ORDERS
	if should_be_climax != (kind == "climax"):
		_fail("第 %d 关的高潮关位置不符合 6/12/18/24 关合同" % (index + 1))
		return false
	if int(level.reward_honey) < 0 or int(level.target_minutes) < 4:
		_fail("第 %d 关奖励或目标时长无效" % (index + 1))
		return false
	if int(level.time_limit_seconds) < int(level.target_minutes) * 60:
		_fail("第 %d 关时限短于目标时长" % (index + 1))
		return false
	if float(level.energy_drain) <= 0.0:
		_fail("第 %d 关体力倍率无效" % (index + 1))
		return false
	for text_key in ["scenario_id", "hazard", "intro", "dialogue", "world_trace"]:
		if String(level.get(text_key, "")).is_empty():
			_fail("第 %d 关含空的 %s" % [index + 1, text_key])
			return false
	var objectives = level.objectives
	if not objectives is Array or objectives.is_empty() or objectives.size() > 4:
		_fail("第 %d 关目标数量无效" % (index + 1))
		return false
	for raw_objective in objectives:
		if not raw_objective is Dictionary:
			_fail("第 %d 关含无效目标")
			return false
		var objective := raw_objective as Dictionary
		if String(objective.get("type", "")) not in OBJECTIVE_TYPES:
			_fail("第 %d 关含未知目标类型" % (index + 1))
			return false
		if String(objective.get("label", "")).is_empty() or int(objective.get("goal", 0)) <= 0:
			_fail("第 %d 关含空目标或无效数量" % (index + 1))
			return false
	if not _validate_event_matrix(level, index):
		return false
	if kind == "climax":
		var phases = level.get("phases", [])
		if not phases is Array or phases.size() != 3:
			_fail("第 %d 关必须恰好有三阶段" % (index + 1))
			return false
		var phase_ids := {}
		for raw_phase in phases:
			if not raw_phase is Dictionary:
				_fail("第 %d 关含无效阶段" % (index + 1))
				return false
			var phase := raw_phase as Dictionary
			var phase_id := String(phase.get("id", ""))
			if (
				phase_id.is_empty()
				or phase_ids.has(phase_id)
				or String(phase.get("label", "")).is_empty()
				or String(phase.get("instruction", "")).is_empty()
				or "\n" in String(phase.get("instruction", ""))
			):
				_fail("第 %d 关阶段 ID 重复或文案为空" % (index + 1))
				return false
			phase_ids[phase_id] = true
	seen_ids[level_id] = true
	season_counts[season_id] = int(season_counts[season_id]) + 1
	return true


func _validate_event_matrix(level: Dictionary, level_index: int) -> bool:
	var level_id := String(level.get("id", ""))
	var has_matrix := level.has("event_matrix")
	if level_id in CONTENT_SLICE_LEVEL_IDS and not has_matrix:
		_fail("%s 必须提供首批 15 项正式内容矩阵" % level_id)
		return false
	if not has_matrix:
		return true
	var matrix = level.get("event_matrix", [])
	if not matrix is Array or matrix.size() != 15:
		_fail("第 %d 关内容矩阵必须恰好有 15 项" % (level_index + 1))
		return false
	var seen_event_ids := {}
	var required_text := [
		"id", "title", "mechanic", "ui_hint", "decision", "operation",
		"consequence", "claim_scope", "actor_scope", "regional_scope",
		"gameplay_abstraction", "verification_status",
	]
	for event_index in matrix.size():
		var raw_event = matrix[event_index]
		if not raw_event is Dictionary:
			_fail("第 %d 关第 %d 项内容不是对象" % [level_index + 1, event_index + 1])
			return false
		var event := raw_event as Dictionary
		for key in required_text:
			if String(event.get(key, "")).is_empty():
				_fail("第 %d 关第 %d 项内容缺少 %s" % [level_index + 1, event_index + 1, key])
				return false
		var event_id := String(event.id)
		if seen_event_ids.has(event_id) or not event_id.begins_with(level_id.trim_prefix("spring_") + "_"):
			_fail("第 %d 关第 %d 项内容 ID 重复或前缀错误" % [level_index + 1, event_index + 1])
			return false
		var expected_pentad := floori(float(event_index) / 5.0) + 1
		if int(event.get("order", -1)) != event_index + 1 or int(event.get("pentad", -1)) != expected_pentad:
			_fail("第 %d 关第 %d 项内容顺序或三候分组无效" % [level_index + 1, event_index + 1])
			return false
		if typeof(event.get("optional", null)) != TYPE_BOOL:
			_fail("第 %d 关第 %d 项没有明确主线／自选属性" % [level_index + 1, event_index + 1])
			return false
		if String(event.mechanic) not in EVENT_MECHANICS:
			_fail("第 %d 关第 %d 项使用未知玩法机制" % [level_index + 1, event_index + 1])
			return false
		if "\n" in String(event.ui_hint) or String(event.ui_hint).length() > 20:
			_fail("第 %d 关第 %d 项短提示过长或含换行" % [level_index + 1, event_index + 1])
			return false
		if event.has("runtime_steps"):
			if not _is_saved_integer(event.runtime_steps) or int(event.runtime_steps) <= 0 or int(event.runtime_steps) > 6:
				_fail("第 %d 关第 %d 项运行步数无效" % [level_index + 1, event_index + 1])
				return false
		var choice_options = event.get("choice_options", {})
		if not choice_options is Dictionary:
			_fail("第 %d 关第 %d 项 choice_options 不是对象" % [level_index + 1, event_index + 1])
			return false
		if not (choice_options as Dictionary).is_empty():
			if not _has_exact_dictionary_keys(choice_options as Dictionary, ["swift", "steady"]):
				_fail("第 %d 关第 %d 项选择必须恰好提供两种做法" % [level_index + 1, event_index + 1])
				return false
			for choice_id in ["swift", "steady"]:
				var option = (choice_options as Dictionary).get(choice_id, {})
				if not option is Dictionary or not _has_exact_dictionary_keys(option as Dictionary, ["label", "effect", "steps"]):
					_fail("第 %d 关第 %d 项选择合同字段不完整" % [level_index + 1, event_index + 1])
					return false
				if (
					String((option as Dictionary).get("label", "")).is_empty()
					or String((option as Dictionary).get("label", "")).length() > 8
					or String((option as Dictionary).get("effect", "")).is_empty()
					or not _is_saved_integer((option as Dictionary).get("steps", 0))
					or int((option as Dictionary).get("steps", 0)) <= 0
					or int((option as Dictionary).get("steps", 0)) > 6
				):
					_fail("第 %d 关第 %d 项选择标签、效果或步数无效" % [level_index + 1, event_index + 1])
					return false
		elif "或" in String(event.decision):
			_fail("第 %d 关第 %d 项写了二选一，却没有可玩的 choice_options" % [level_index + 1, event_index + 1])
			return false
		if String(event.claim_scope) != "design-fiction" or String(event.actor_scope) != "fictional-character":
			_fail("第 %d 关第 %d 项没有诚实标明游戏化主体" % [level_index + 1, event_index + 1])
			return false
		var verification_status := String(event.verification_status)
		if verification_status not in EVENT_VERIFICATION_STATUSES:
			_fail("第 %d 关第 %d 项尚未批准进入运行目录" % [level_index + 1, event_index + 1])
			return false
		if verification_status == "approved-for-player-facing-science":
			var science_error := _player_facing_science_approval_error(event)
			if not science_error.is_empty():
				_fail("第 %d 关第 %d 项科普批准合同无效：%s" % [level_index + 1, event_index + 1, science_error])
				return false
		elif event.has("science_approval"):
			_fail("第 %d 关第 %d 项仅获玩法批准却携带科普批准字段" % [level_index + 1, event_index + 1])
			return false
		var source_ids = event.get("source_ids", [])
		var fact_ids = event.get("fact_ids", [])
		if not source_ids is Array or source_ids.is_empty() or not fact_ids is Array:
			_fail("第 %d 关第 %d 项缺少来源或事实索引数组" % [level_index + 1, event_index + 1])
			return false
		var seen_source_ids := {}
		for raw_source_id in source_ids:
			var source_id := String(raw_source_id)
			if not _is_registered_event_source(source_id) or seen_source_ids.has(source_id):
				_fail("第 %d 关第 %d 项含未知或重复来源 ID" % [level_index + 1, event_index + 1])
				return false
			seen_source_ids[source_id] = true
		if not seen_source_ids.has("G-FICTION"):
			_fail("第 %d 关第 %d 项缺少游戏创作来源标记" % [level_index + 1, event_index + 1])
			return false
		if fact_ids.is_empty():
			if source_ids.size() != 1:
				_fail("第 %d 关第 %d 项没有事实卡却声明了专业来源" % [level_index + 1, event_index + 1])
				return false
		else:
			var seen_fact_ids := {}
			for raw_fact_id in fact_ids:
				var fact_id := String(raw_fact_id)
				if not EVENT_FACT_SOURCE_IDS.has(fact_id) or seen_fact_ids.has(fact_id):
					_fail("第 %d 关第 %d 项含未知或重复事实 ID" % [level_index + 1, event_index + 1])
					return false
				seen_fact_ids[fact_id] = true
				var fact_is_sourced := false
				for mapped_source_id in EVENT_FACT_SOURCE_IDS[fact_id]:
					if seen_source_ids.has(String(mapped_source_id)):
						fact_is_sourced = true
						break
				if not fact_is_sourced:
					_fail("第 %d 关第 %d 项事实 %s 没有对应来源" % [level_index + 1, event_index + 1, fact_id])
					return false
			for source_id in seen_source_ids:
				if String(source_id) == "G-FICTION":
					continue
				if _is_event_science_modern_source(event, String(source_id)):
					continue
				var source_is_used := false
				for fact_id in seen_fact_ids:
					if String(source_id) in EVENT_FACT_SOURCE_IDS[String(fact_id)]:
						source_is_used = true
						break
				if not source_is_used:
					_fail("第 %d 关第 %d 项来源 %s 没有对应事实卡" % [level_index + 1, event_index + 1, source_id])
					return false
		seen_event_ids[event_id] = true
	return true


func _is_registered_event_source(source_id: String) -> bool:
	if source_id in EVENT_SOURCE_IDS:
		return true
	for raw_approval in PLAYER_FACING_SCIENCE_APPROVALS.values():
		if (
			raw_approval is Dictionary
			and source_id in Array((raw_approval as Dictionary).get("modern_source_ids", []))
		):
			return true
	return false


func _is_event_science_modern_source(event: Dictionary, source_id: String) -> bool:
	var approval = event.get("science_approval", null)
	return (
		approval is Dictionary
		and source_id in Array((approval as Dictionary).get("modern_source_ids", []))
	)


func _player_facing_science_approval_error(
	event: Dictionary,
	approval_registry: Dictionary = PLAYER_FACING_SCIENCE_APPROVALS
) -> String:
	var approval = event.get("science_approval", null)
	if not approval is Dictionary:
		return "缺少 science_approval 对象"
	var science_approval := approval as Dictionary
	var required_keys := [
		"approval_id", "modern_source_ids", "advisor_review_id",
		"reviewed_fact_ids", "player_facing_copy_sha256",
	]
	for key in required_keys:
		if not science_approval.has(key):
			return "science_approval 缺少 %s" % key
	var approval_id := String(science_approval.get("approval_id", ""))
	var registered = approval_registry.get(approval_id, null)
	if approval_id.is_empty() or not registered is Dictionary:
		return "approval_id 未登记"
	var registered_approval := registered as Dictionary
	for key in required_keys.slice(1):
		if not registered_approval.has(key):
			return "批准登记缺少 %s" % key
	var modern_source_ids = science_approval.get("modern_source_ids", null)
	var reviewed_fact_ids = science_approval.get("reviewed_fact_ids", null)
	if not modern_source_ids is Array or modern_source_ids.is_empty():
		return "现代交叉核验来源为空"
	if not reviewed_fact_ids is Array or reviewed_fact_ids.is_empty():
		return "顾问没有逐项确认事实卡"
	if not event.get("source_ids", null) is Array or not event.get("fact_ids", null) is Array:
		return "事件缺少来源或事实索引数组"
	if modern_source_ids != registered_approval.get("modern_source_ids"):
		return "现代来源与批准登记不一致"
	if reviewed_fact_ids != registered_approval.get("reviewed_fact_ids"):
		return "复核事实卡与批准登记不一致"
	if reviewed_fact_ids != event.get("fact_ids"):
		return "复核事实卡没有覆盖事件的完整事实集合"
	for source_id in modern_source_ids:
		if String(source_id).is_empty() or String(source_id) not in event.get("source_ids"):
			return "现代来源未进入事件来源链"
	if (
		String(science_approval.get("advisor_review_id", "")).is_empty()
		or science_approval.get("advisor_review_id") != registered_approval.get("advisor_review_id")
	):
		return "蜂学顾问批准未登记或不一致"
	var copy_sha256 := String(science_approval.get("player_facing_copy_sha256", ""))
	if (
		copy_sha256.length() != 64
		or not copy_sha256.is_valid_hex_number(false)
		or copy_sha256 != String(registered_approval.get("player_facing_copy_sha256", ""))
	):
		return "玩家可见文案哈希未锁定"
	return ""


func _fail(message: String) -> void:
	catalog_error = message
	push_error(message)


func total_count() -> int:
	return _levels.size()


func levels() -> Array[Dictionary]:
	return _levels.duplicate(true)


func level_at(order: int) -> Dictionary:
	if order < 0 or order >= _levels.size():
		return {}
	return _levels[order].duplicate(true)


func level_by_id(level_id: String) -> Dictionary:
	var level = _level_by_id.get(level_id)
	return (level as Dictionary).duplicate(true) if level is Dictionary else {}


func order_of(level_id: String) -> int:
	var level = _level_by_id.get(level_id)
	return int((level as Dictionary).get("order", -1)) if level is Dictionary else -1


func has_level(level_id: String) -> bool:
	return _level_by_id.has(level_id)


func is_climax(level_id: String) -> bool:
	var level = _level_by_id.get(level_id)
	return level is Dictionary and String((level as Dictionary).get("kind", "")) == "climax"


func first_incomplete_id(completed_count: int) -> String:
	if completed_count < 0 or completed_count >= _levels.size():
		return ""
	return String(_levels[completed_count].id)
