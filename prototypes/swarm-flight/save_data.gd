extends RefCounted
## V4 retains the 0.5.1 entity layout; 0.5.2 adds optional arrival completion.
## Previous v1/v2/v3 files are never read/written.
const Model = preload("res://game_model.gd")
const PATH := "user://before_the_rain_chapter_v4.json"
const MAX_BYTES := 65536

static func read_payload(path: String = PATH) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null or file.get_length() > MAX_BYTES: return {}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK or not parser.data is Dictionary: return {}
	var model = Model.new()
	return parser.data if model.restore_payload(parser.data) else {}

static func write_payload(data: Dictionary,path: String = PATH) -> bool:
	var model = Model.new()
	if not model.restore_payload(data): return false
	var contents := JSON.stringify(data)
	if contents.to_utf8_buffer().size() > MAX_BYTES: return false
	var file := FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file == null: return false
	file.store_string(contents)
	file.flush()
	var ok := file.get_error() == OK
	file.close()
	if not ok: return false
	return DirAccess.rename_absolute(path+".tmp",path) == OK
