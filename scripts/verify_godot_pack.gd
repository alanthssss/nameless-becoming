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


func has_exact_keys(value: Dictionary, expected: Array[String]) -> bool:
	var actual: Array[String] = []
	for key in value.keys():
		actual.append(String(key))
	actual.sort()
	var normalized := expected.duplicate()
	normalized.sort()
	return actual == normalized


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
		"res://playtest/b01_evade_slice.tscn.remap",
		"res://data/playtest_slices.json",
	]
	var missing_runtime_files: Array[String] = []
	for required_path in required_runtime_files:
		if required_path not in files:
			missing_runtime_files.append(required_path)
	if not missing_runtime_files.is_empty():
		fail("Exported pack is missing required bootstrap/catalog resources: %s\n%s" % [pack_path, "\n".join(missing_runtime_files)])
		return

	var catalog_file := FileAccess.open("res://data/playtest_slices.json", FileAccess.READ)
	if catalog_file == null:
		fail("Exported pack playtest catalog cannot be read.")
		return
	var catalog_parser := JSON.new()
	var catalog_parse_result := catalog_parser.parse(catalog_file.get_as_text())
	catalog_file.close()
	if catalog_parse_result != OK or not catalog_parser.data is Dictionary:
		fail("Exported pack playtest catalog is not a JSON object using schema v1.")
		return
	var catalog: Dictionary = catalog_parser.data
	if not has_exact_keys(catalog, ["schema_version", "slices"]) or catalog.get("schema_version") != 1 or not catalog.get("slices") is Array:
		fail("Exported pack playtest catalog does not use the exact schema v1 shape.")
		return
	var slices: Array = catalog.slices
	if slices.size() != 1 or not slices[0] is Dictionary:
		fail("Exported pack playtest catalog must contain exactly one B01 row.")
		return
	var b01: Dictionary = slices[0]
	if not has_exact_keys(b01, ["assignment", "code", "maximum_minutes", "status"]):
		fail("Exported pack B01 row exposes an unexpected public field.")
		return
	if b01.get("code") != "B01" or b01.get("assignment") != "固定切片 B01" or b01.get("maximum_minutes") != 10 or b01.get("status") != "ready":
		fail("Exported pack does not contain the exact ready B01 / 10-minute catalog row.")
		return

	var b01_scene := load("res://playtest/b01_evade_slice.tscn") as PackedScene
	if b01_scene == null:
		fail("Exported pack B01 scene or one of its compiled dependencies cannot be loaded.")
		return
	var b01_instance := b01_scene.instantiate()
	if b01_instance == null or not b01_instance.has_method("configure_playtest_session"):
		if b01_instance != null:
			b01_instance.free()
		fail("Exported pack B01 scene does not implement the typed session contract.")
		return
	b01_instance.free()

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
