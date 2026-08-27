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
	"seed", "shell", "warmth", "anchor", "climax",
]

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
