extends RefCounted
## Only the current chapter is persisted, never executable objects or old-game data.
const PATH := "user://before_the_rain_v1.json"

static func read_stage(path: String = PATH) -> int:
	if not FileAccess.file_exists(path):
		return -1
	var f := FileAccess.open(path,FileAccess.READ)
	if f == null or f.get_length() > 2048:
		return -1
	var parser := JSON.new()
	if parser.parse(f.get_as_text()) != OK:
		return -1
	var data = parser.data
	if not data is Dictionary or data.get("version") != 1:
		return -1
	var index = data.get("stage")
	if not (index is int or index is float) or index != floor(index) or index < 0 or index > 2:
		return -1
	return int(index)

static func write_stage(index: int, path: String = PATH) -> bool:
	if index < 0 or index > 2:
		return false
	var f := FileAccess.open(path + ".tmp",FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify({"version":1,"stage":index}))
	f.flush()
	var ok := f.get_error() == OK
	f.close()
	if not ok:
		return false
	return DirAccess.rename_absolute(path + ".tmp",path) == OK
