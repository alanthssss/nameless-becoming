extends SceneTree

const INTERNAL_RESOURCE_ROOTS := ["tests", "tools"]
const SUCCESS_MARKER := "EXPORT PACK CONTENTS VERIFIED"


func collect_files(directory_path: String, output: Array[String]) -> void:
	var directory := DirAccess.open(directory_path)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		var entry_path := directory_path.path_join(entry)
		if directory.current_is_dir():
			collect_files(entry_path, output)
		else:
			output.append(entry_path)
		entry = directory.get_next()
	directory.list_dir_end()


func fail(message: String) -> void:
	push_error(message)
	quit(1)


func _init() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 1:
		fail("Expected exactly one exported PCK, ZIP pack, or executable path.")
		return

	var pack_path := arguments[0]
	if not FileAccess.file_exists(pack_path):
		fail("Exported pack does not exist: %s" % pack_path)
		return
	if not ProjectSettings.load_resource_pack(pack_path, true):
		fail("Godot could not load exported pack: %s" % pack_path)
		return

	var files: Array[String] = []
	collect_files("res://", files)
	files.sort()
	if "res://project.binary" not in files or "res://main.tscn.remap" not in files:
		fail("Exported pack is missing the project settings or main scene remap: %s" % pack_path)
		return

	var internal_files: Array[String] = []
	for file_path in files:
		var relative_path := file_path.trim_prefix("res://")
		var root_directory := relative_path.get_slice("/", 0)
		if root_directory in INTERNAL_RESOURCE_ROOTS:
			internal_files.append(file_path)
	if not internal_files.is_empty():
		fail("Exported pack contains internal resources:\n%s" % "\n".join(internal_files))
		return

	print("%s: %s (no res://tests or res://tools)" % [SUCCESS_MARKER, pack_path])
	quit(0)
