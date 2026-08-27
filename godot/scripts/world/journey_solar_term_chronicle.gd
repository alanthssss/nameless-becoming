class_name JourneySolarTermChronicle
extends RefCounted

## Formal Journey-world solar-term catalog and exact-once progress ledger.
##
## The formal campaign unlocks one record after each matching level. The earlier
## six-sortie Journey still calls record_return(), so both save generations can
## be read while the title migrates to the twenty-four-level campaign.

const CATALOG_PATH := "res://data/journey_solar_term_chronicles.json"
const SAVE_SCHEMA_VERSION := 1
const TOTAL_TERMS := 24
const SEASONS := ["春", "夏", "秋", "冬"]
const RETURN_ORDER := [
	"spring_route",
	"sign_incident",
	"summer_recovery",
	"autumn_harvest",
	"winter_warmth",
]
const VALUE_DEFAULTS := {
	"deposit": 0,
	"pollinations": 0,
	"honey_lost": 0,
	"recovered_honey": 0,
	"belongings_recovered": 0,
	"harvested": 0,
	"seeded": 0,
	"echo_points": 0,
	"warmth_links": 0,
	"windbreak_segments": 0,
}

var catalog_valid := false
var catalog_error := ""
var _entries: Array[Dictionary] = []
var _entry_by_id: Dictionary = {}
var _unlocked_ids: Array[String] = []
var _unlocked_set: Dictionary = {}
var _rendered_records: Dictionary = {}
var _last_unlock_ids: Array[String] = []


func _init(catalog_path := CATALOG_PATH) -> void:
	_load_catalog(catalog_path)


func _load_catalog(catalog_path: String) -> void:
	catalog_valid = false
	catalog_error = ""
	_entries.clear()
	_entry_by_id.clear()
	if not FileAccess.file_exists(catalog_path):
		_fail_catalog("节气纪事数据不存在：%s" % catalog_path)
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(catalog_path))
	if not parsed is Dictionary:
		_fail_catalog("节气纪事数据根节点不是对象")
		return
	var document := parsed as Dictionary
	if int(document.get("schema_version", -1)) != SAVE_SCHEMA_VERSION:
		_fail_catalog("节气纪事数据版本不受支持")
		return
	var raw_terms = document.get("terms", [])
	if not raw_terms is Array or raw_terms.size() != TOTAL_TERMS:
		_fail_catalog("节气纪事必须恰好有 %d 条" % TOTAL_TERMS)
		return
	var seen_ids := {}
	var seen_names := {}
	var season_counts := {"春": 0, "夏": 0, "秋": 0, "冬": 0}
	for index in raw_terms.size():
		var raw_entry = raw_terms[index]
		if not raw_entry is Dictionary:
			_fail_catalog("第 %d 条节气纪事不是对象" % index)
			return
		var entry := (raw_entry as Dictionary).duplicate(true)
		var required := ["id", "order", "name", "season", "unlock_return", "work", "title", "record"]
		for key in required:
			if not entry.has(key):
				_fail_catalog("第 %d 条节气纪事缺少 %s" % [index, key])
				return
		var term_id := String(entry.id)
		var term_name := String(entry.name)
		var season := String(entry.season)
		var unlock_return := String(entry.unlock_return)
		if term_id.is_empty() or term_name.is_empty() or String(entry.title).is_empty() or String(entry.record).is_empty():
			_fail_catalog("第 %d 条节气纪事含空字段" % index)
			return
		if seen_ids.has(term_id) or seen_names.has(term_name):
			_fail_catalog("节气纪事 ID 或名称重复：%s / %s" % [term_id, term_name])
			return
		if int(entry.order) != index:
			_fail_catalog("节气纪事顺序号不连续：%s" % term_name)
			return
		if season not in SEASONS or unlock_return not in RETURN_ORDER:
			_fail_catalog("节气纪事季节或返巢落点无效：%s" % term_name)
			return
		if not entry.work is Array or entry.work.is_empty():
			_fail_catalog("节气纪事没有对应实际行为：%s" % term_name)
			return
		seen_ids[term_id] = true
		seen_names[term_name] = true
		season_counts[season] = int(season_counts[season]) + 1
		_entries.append(entry)
		_entry_by_id[term_id] = entry
	for season in SEASONS:
		if int(season_counts[season]) != 6:
			_fail_catalog("%s季节气纪事不是 6 条" % season)
			return
	catalog_valid = true


func _fail_catalog(message: String) -> void:
	catalog_error = message
	push_error(message)


func total_count() -> int:
	return _entries.size()


func unlocked_count() -> int:
	return _unlocked_ids.size()


func is_unlocked(term_id: String) -> bool:
	return _unlocked_set.has(term_id)


func catalog_entries() -> Array[Dictionary]:
	return _entries.duplicate(true)


func record_return(return_kind: String, payload: Dictionary = {}) -> Array[Dictionary]:
	_last_unlock_ids.clear()
	var newly_unlocked: Array[Dictionary] = []
	if not catalog_valid or return_kind not in RETURN_ORDER:
		return newly_unlocked
	for entry in _entries:
		if String(entry.unlock_return) != return_kind:
			continue
		var term_id := String(entry.id)
		if _unlocked_set.has(term_id):
			continue
		_unlocked_set[term_id] = true
		_unlocked_ids.append(term_id)
		_last_unlock_ids.append(term_id)
		_rendered_records[term_id] = _render_record(String(entry.record), payload)
		newly_unlocked.append(_resolved_entry(entry))
	return newly_unlocked


func record_level(term_id: String, payload: Dictionary = {}) -> Dictionary:
	## Campaign progress is an exact catalog prefix. A replay may refresh its best
	## time elsewhere, but it can never append or duplicate a chronicle entry.
	_last_unlock_ids.clear()
	if not catalog_valid or not _entry_by_id.has(term_id):
		return {}
	if _unlocked_set.has(term_id):
		return {}
	if _unlocked_ids.size() >= _entries.size():
		return {}
	var next_entry := _entries[_unlocked_ids.size()]
	if String(next_entry.id) != term_id:
		return {}
	_unlocked_set[term_id] = true
	_unlocked_ids.append(term_id)
	_last_unlock_ids.append(term_id)
	_rendered_records[term_id] = _render_record(String(next_entry.record), payload)
	return _resolved_entry(next_entry)


func unlocked_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in _entries:
		if _unlocked_set.has(String(entry.id)):
			result.append(_resolved_entry(entry))
	return result


func latest_unlock_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for term_id in _last_unlock_ids:
		var entry = _entry_by_id.get(term_id)
		if entry is Dictionary:
			result.append(_resolved_entry(entry as Dictionary))
	return result


func unlocked_entries_for_season(season: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in _entries:
		if String(entry.season) == season and _unlocked_set.has(String(entry.id)):
			result.append(_resolved_entry(entry))
	return result


func _resolved_entry(entry: Dictionary) -> Dictionary:
	var result := entry.duplicate(true)
	var term_id := String(entry.id)
	result["resolved_record"] = String(_rendered_records.get(term_id, _render_record(String(entry.record), {})))
	return result


func _render_record(template: String, values: Dictionary) -> String:
	var result := template
	for key in VALUE_DEFAULTS:
		var value = values.get(key, VALUE_DEFAULTS[key])
		result = result.replace("{{%s}}" % String(key), str(value))
	return result


func progress_snapshot() -> Dictionary:
	return {
		"schema_version": SAVE_SCHEMA_VERSION,
		"unlocked_count": unlocked_count(),
		"total_count": total_count(),
		"unlocked_ids": _unlocked_ids.duplicate(),
		"latest_unlock_ids": _last_unlock_ids.duplicate(),
		"complete": unlocked_count() == total_count() and total_count() == TOTAL_TERMS,
	}


func to_save_data() -> Dictionary:
	return {
		"schema_version": SAVE_SCHEMA_VERSION,
		"unlocked_ids": _unlocked_ids.duplicate(),
		"rendered_records": _rendered_records.duplicate(true),
	}


func load_save_data(data: Dictionary) -> bool:
	if not catalog_valid:
		return false
	var version := int(data.get("schema_version", 0))
	if version < 0 or version > SAVE_SCHEMA_VERSION:
		return false
	var raw_ids = data.get("unlocked_ids", data.get("completed_ids", []))
	if not raw_ids is Array:
		return false
	var saved_records = data.get("rendered_records", {})
	if not saved_records is Dictionary:
		saved_records = {}
	var requested := {}
	for raw_id in raw_ids:
		var term_id := String(raw_id)
		if _entry_by_id.has(term_id):
			requested[term_id] = true
	var restored_ids: Array[String] = []
	var restored_set := {}
	var restored_records := {}
	for entry in _entries:
		var term_id := String(entry.id)
		if not requested.has(term_id):
			continue
		restored_ids.append(term_id)
		restored_set[term_id] = true
		var saved_text := String((saved_records as Dictionary).get(term_id, ""))
		restored_records[term_id] = saved_text if not saved_text.is_empty() else _render_record(String(entry.record), {})
	_unlocked_ids = restored_ids
	_unlocked_set = restored_set
	_rendered_records = restored_records
	_last_unlock_ids.clear()
	return true
