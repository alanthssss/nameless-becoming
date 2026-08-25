extends SceneTree

const INTERNAL_RESOURCE_ROOTS := ["tests", "tools"]
const SUCCESS_MARKER := "EXPORT PACK CONTENTS VERIFIED"
const REPORT_SCHEMA_VERSION := 1


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
	if arguments.size() != 1 and arguments.size() != 3:
		fail("Expected a pack path, optionally followed by --report and an absolute JSON report path.")
		return

	var pack_path := arguments[0]
	var report_path := ""
	if arguments.size() == 3:
		if arguments[1] != "--report":
			fail("The only supported pack-inspection option is --report.")
			return
		report_path = arguments[2]
		if not report_path.is_absolute_path():
			fail("Pack inspection report path must be absolute: %s" % report_path)
			return
		if FileAccess.file_exists(report_path):
			fail("Pack inspection report path already exists: %s" % report_path)
			return
	if not FileAccess.file_exists(pack_path):
		fail("Exported pack does not exist: %s" % pack_path)
		return
	if not ProjectSettings.load_resource_pack(pack_path, true):
		fail("Godot could not load exported pack: %s" % pack_path)
		return

	var files: Array[String] = []
	collect_files("res://", files)
	files.sort()
	var required_runtime_files := [
		"res://project.binary",
		"res://bootstrap.tscn.remap",
		"res://main.tscn.remap",
		"res://data/playtest_slices.json",
	]
	var missing_runtime_files: Array[String] = []
	for required_path in required_runtime_files:
		if required_path not in files:
			missing_runtime_files.append(required_path)
	if not missing_runtime_files.is_empty():
		fail("Exported pack is missing required bootstrap/catalog resources: %s\n%s" % [pack_path, "\n".join(missing_runtime_files)])
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

	if not report_path.is_empty():
		var provenance_path := "res://data/build_provenance.json"
		if provenance_path not in files:
			fail("Exported pack is missing build provenance: %s" % provenance_path)
			return
		var provenance_file := FileAccess.open(provenance_path, FileAccess.READ)
		if provenance_file == null:
			fail("Exported pack build provenance cannot be read: %s" % provenance_path)
			return
		var provenance_json := JSON.new()
		var parse_result := provenance_json.parse(provenance_file.get_as_text())
		provenance_file.close()
		if parse_result != OK:
			fail("Exported pack build provenance is malformed JSON at line %d: %s" % [provenance_json.get_error_line(), provenance_json.get_error_message()])
			return
		if typeof(provenance_json.data) != TYPE_DICTIONARY:
			fail("Exported pack build provenance must be a JSON object.")
			return
		var pack_sha256 := FileAccess.get_sha256(pack_path)
		if pack_sha256.length() != 64:
			fail("Could not calculate the exported pack SHA-256: %s" % pack_path)
			return
		var report_file := FileAccess.open(report_path, FileAccess.WRITE)
		if report_file == null:
			fail("Could not create pack inspection report: %s" % report_path)
			return
		var report := {
			"schema_version": REPORT_SCHEMA_VERSION,
			"pack_sha256": pack_sha256,
			"build_provenance": provenance_json.data,
		}
		report_file.store_string(JSON.stringify(report, "\t") + "\n")
		report_file.close()

	print("%s: %s (no res://tests or res://tools)" % [SUCCESS_MARKER, pack_path])
	quit(0)
