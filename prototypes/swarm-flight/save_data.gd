extends RefCounted
## Changed route geometry uses a new path; journey v1 and chapter v4 stay untouched.
const Model = preload("res://game_model.gd")
const PATH := "user://before_the_rain_journey_v2.json"
const MAX_BYTES := 262144

static func read_payload(path: String = PATH,validator = null) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null or file.get_length() > MAX_BYTES: return {}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK or not parser.data is Dictionary: return {}
	var model = Model.new() if validator == null else validator
	return parser.data if model.restore_payload(parser.data) else {}

static func write_payload(data: Dictionary,path: String = PATH,validator = null) -> bool:
	var model = Model.new() if validator == null else validator
	if not model.restore_payload(data): return false
	var contents := JSON.stringify(data,"",true,true)
	if contents.to_utf8_buffer().size() > MAX_BYTES: return false
	var file := FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file == null: return false
	file.store_string(contents)
	file.flush()
	var ok := file.get_error() == OK
	file.close()
	if not ok: return false
	return DirAccess.rename_absolute(path+".tmp",path) == OK
