class_name PlaytestTicketValidator
extends RefCounted

const CATALOG_PATH := "res://data/playtest_slices.json"
const PROVENANCE_PATH := "res://data/build_provenance.json"
const MANIFEST_FILENAME := "artifact-manifest.json"
const PRODUCT_ID := "nameless-becoming"
const PRODUCT_DISPLAY_NAME := "一会儿巢里见"
const MAX_IDENTITY_FILE_BYTES := 262144
const SUPPORTED_ARTIFACTS := {
	"macos-universal": {
		"filename": "NamelessBecoming-macOS.zip",
		"os_name": "macOS",
	},
	"windows-x86_64": {
		"filename": "NamelessBecoming-Windows.exe",
		"os_name": "Windows",
	},
}

var _registry: Variant = PlaytestSliceRegistry.new()
var _catalog_bytes_override := PackedByteArray()
var _provenance_bytes_override := PackedByteArray()
var _platform_override := ""
var _fixture_configured := false
var _validation_started := false

func configure_test_fixture(overrides: Dictionary) -> Error:
	if _validation_started or _fixture_configured:
		return ERR_ALREADY_IN_USE
	if not OS.has_feature("editor"):
		return ERR_UNAVAILABLE
	if not _has_exact_keys(overrides, ["catalog_bytes", "platform", "provenance_bytes", "registry"]):
		return ERR_INVALID_DATA
	if not overrides.catalog_bytes is PackedByteArray or not overrides.provenance_bytes is PackedByteArray:
		return ERR_INVALID_DATA
	if not overrides.platform is String or not overrides.registry is Dictionary:
		return ERR_INVALID_DATA
	_catalog_bytes_override = overrides.catalog_bytes.duplicate()
	_provenance_bytes_override = overrides.provenance_bytes.duplicate()
	_platform_override = String(overrides.platform)
	_registry = overrides.registry.duplicate()
	_fixture_configured = true
	return OK

func validate_ticket(ticket_path: String) -> Dictionary:
	_validation_started = true
	if not _is_external_filesystem_path(ticket_path):
		return _failure("PT-TICKET-PATH", "Ticket path must be an absolute filesystem path.")

	var ticket_read := _read_file_bytes(ticket_path, "ticket")
	if not ticket_read.ok:
		return ticket_read
	var ticket_bytes: PackedByteArray = ticket_read.bytes
	var ticket_parse := _parse_json_object(ticket_bytes, "ticket")
	if not ticket_parse.ok:
		return ticket_parse
	var ticket: Dictionary = ticket_parse.value
	var ticket_shape_error := _validate_ticket_shape(ticket)
	if not ticket_shape_error.is_empty():
		return _failure("PT-TICKET-SCHEMA", ticket_shape_error)

	var manifest_path := ticket_path.get_base_dir().path_join(MANIFEST_FILENAME)
	var manifest_read := _read_file_bytes(manifest_path, "artifact manifest")
	if not manifest_read.ok:
		return manifest_read
	var manifest_bytes: PackedByteArray = manifest_read.bytes
	if _sha256(manifest_bytes) != String(ticket.artifact.manifest_sha256):
		return _failure("PT-MANIFEST-SHA", "Artifact manifest raw-byte SHA-256 does not match the ticket.")
	var manifest_parse := _parse_json_object(manifest_bytes, "artifact manifest")
	if not manifest_parse.ok:
		return manifest_parse
	var manifest: Dictionary = manifest_parse.value
	var manifest_error := _validate_manifest(manifest, ticket)
	if not manifest_error.is_empty():
		return _failure("PT-MANIFEST-SCHEMA", manifest_error)

	var provenance_read := _read_runtime_bytes(PROVENANCE_PATH, _provenance_bytes_override, "build provenance")
	if not provenance_read.ok:
		return provenance_read
	var provenance_parse := _parse_json_object(provenance_read.bytes, "build provenance")
	if not provenance_parse.ok:
		return provenance_parse
	var provenance_error := _validate_provenance(provenance_parse.value, ticket.product)
	if not provenance_error.is_empty():
		return _failure("PT-PROVENANCE", provenance_error)

	var catalog_read := _read_runtime_bytes(CATALOG_PATH, _catalog_bytes_override, "playtest catalog")
	if not catalog_read.ok:
		return catalog_read
	var catalog_bytes: PackedByteArray = catalog_read.bytes
	if _sha256(catalog_bytes) != String(ticket.catalog_sha256):
		return _failure("PT-CATALOG-SHA", "Playtest catalog raw-byte SHA-256 does not match the ticket.")
	var catalog_parse := _parse_json_object(catalog_bytes, "playtest catalog")
	if not catalog_parse.ok:
		return catalog_parse
	var catalog_result := _validate_catalog(catalog_parse.value, String(ticket.task.slice_code))
	if not catalog_result.ok:
		return catalog_result
	var slice: Dictionary = catalog_result.slice
	if slice.status == "blocked":
		return _failure("PT-SLICE-BLOCKED", "Requested slice is blocked by the signed catalog.")
	if not _registry_has_code(String(slice.code)):
		return _failure("PT-SLICE-UNREGISTERED", "Requested ready slice is absent from the compiled registry.")
	var scene := _registry_scene(String(slice.code))
	if scene == null:
		return _failure("PT-SLICE-UNIMPLEMENTED", "Requested ready slice has no compiled typed scene.")

	var context := {
		"schema_version": 1,
		"session_id": String(ticket.session_id),
		"task": (ticket.task as Dictionary).duplicate(true),
		"product": (ticket.product as Dictionary).duplicate(true),
		"artifact": (ticket.artifact as Dictionary).duplicate(true),
		"catalog_sha256": String(ticket.catalog_sha256),
		"slice": slice.duplicate(true),
		"ticket_sha256": _sha256(ticket_bytes),
	}
	return {"ok": true, "context": context, "scene": scene}

func _is_external_filesystem_path(path: String) -> bool:
	# String.is_absolute_path() also accepts res:// and user://. Identity files
	# are deliberately external OS files, never bundled resources, app data or a
	# single-slash URI form such as file:/.
	if path.is_empty() or not path.is_absolute_path():
		return false
	if path.begins_with("/") or path.begins_with("\\\\"):
		return true
	var drive_path := RegEx.new()
	return drive_path.compile("^[A-Za-z]:[\\\\/]") == OK and drive_path.search(path) != null

func _validate_ticket_shape(ticket: Dictionary) -> String:
	if not _has_exact_keys(ticket, ["artifact", "catalog_sha256", "product", "schema_version", "session_id", "task"]):
		return "Ticket must contain only the schema v1 top-level fields."
	if ticket.schema_version != 1:
		return "Ticket schema_version must be 1."
	if not ticket.session_id is String or not _matches(String(ticket.session_id), "^[A-Z0-9-]{8,40}$"):
		return "Ticket session_id is invalid."
	if not ticket.task is Dictionary or not _has_exact_keys(ticket.task, ["code", "slice_code"]):
		return "Ticket task must contain exactly code and slice_code."
	if ticket.task.code != "B" or not ticket.task.slice_code is String or not _matches(String(ticket.task.slice_code), "^B[0-9]{2}$"):
		return "Ticket task must identify a B slice code."
	if not ticket.product is Dictionary or not _has_exact_keys(ticket.product, ["commit", "dirty", "display_name", "id", "version"]):
		return "Ticket product has an invalid shape."
	var product: Dictionary = ticket.product
	if String(ProjectSettings.get_setting("application/config/name", "")) != PRODUCT_DISPLAY_NAME:
		return "Running application display name does not match the compiled product identity."
	if product.id != PRODUCT_ID or product.display_name != PRODUCT_DISPLAY_NAME:
		return "Ticket product identity does not match this application."
	if not product.version is String or String(product.version) != String(ProjectSettings.get_setting("application/config/version", "")):
		return "Ticket product version does not match this application."
	if not product.commit is String or not _matches(String(product.commit), "^[0-9a-f]{40}$"):
		return "Ticket product commit must be a full lowercase object ID."
	if typeof(product.dirty) != TYPE_BOOL or product.dirty != false:
		return "Ticket product must identify a clean artifact."
	if not ticket.artifact is Dictionary or not _has_exact_keys(ticket.artifact, ["filename", "manifest_sha256", "platform", "sha256", "size"]):
		return "Ticket artifact has an invalid shape."
	var artifact: Dictionary = ticket.artifact
	if not artifact.platform is String or not SUPPORTED_ARTIFACTS.has(artifact.platform):
		return "Ticket artifact platform is unsupported."
	var expected_artifact: Dictionary = SUPPORTED_ARTIFACTS[artifact.platform]
	if not artifact.filename is String or artifact.filename != expected_artifact.filename:
		return "Ticket artifact filename does not match its platform."
	var running_platform := _platform_override if not _platform_override.is_empty() else OS.get_name()
	if running_platform != expected_artifact.os_name:
		return "Ticket artifact platform does not match the running build."
	if not _is_json_integer(artifact.size) or int(artifact.size) <= 0:
		return "Ticket artifact size must be a positive integer."
	if not artifact.sha256 is String or not _matches(String(artifact.sha256), "^[0-9a-f]{64}$"):
		return "Ticket artifact SHA-256 is invalid."
	if not artifact.manifest_sha256 is String or not _matches(String(artifact.manifest_sha256), "^[0-9a-f]{64}$"):
		return "Ticket manifest SHA-256 is invalid."
	if not ticket.catalog_sha256 is String or not _matches(String(ticket.catalog_sha256), "^[0-9a-f]{64}$"):
		return "Ticket catalog SHA-256 is invalid."
	return ""

func _validate_manifest(manifest: Dictionary, ticket: Dictionary) -> String:
	var core_keys := ["commit", "dirty", "filename", "platform", "product_version", "schema_version", "sha256", "size"]
	var source_keys := core_keys + ["github_run_id", "source_ref"]
	if not _has_exact_keys(manifest, core_keys) and not _has_exact_keys(manifest, source_keys):
		return "Artifact manifest must use the exact schema v1 core fields, optionally with paired source metadata."
	if manifest.schema_version != 1:
		return "Artifact manifest schema_version must be 1."
	if manifest.product_version != ticket.product.version or manifest.commit != ticket.product.commit or typeof(manifest.dirty) != TYPE_BOOL or manifest.dirty != false:
		return "Artifact manifest product provenance does not match the ticket."
	for key in ["platform", "filename", "size", "sha256"]:
		if manifest.get(key) != ticket.artifact.get(key):
			return "Artifact manifest %s does not match the ticket." % key
	if manifest.has("source_ref"):
		if not manifest.source_ref is String or String(manifest.source_ref).is_empty():
			return "Artifact manifest source_ref is invalid."
		if not manifest.github_run_id is String or not _matches(String(manifest.github_run_id), "^[1-9][0-9]*$"):
			return "Artifact manifest github_run_id is invalid."
	return ""

func _validate_provenance(provenance: Dictionary, product: Dictionary) -> String:
	if not _has_exact_keys(provenance, ["commit", "dirty", "product_version", "schema_version"]):
		return "Build provenance must contain only the exact schema v1 fields."
	if provenance.schema_version != 1:
		return "Build provenance schema_version must be 1."
	if provenance.product_version != product.version or provenance.commit != product.commit:
		return "Embedded build provenance does not match the ticket product."
	if typeof(provenance.dirty) != TYPE_BOOL or provenance.dirty != false:
		return "Embedded build provenance must identify a clean artifact."
	return ""

func _validate_catalog(catalog: Dictionary, requested_code: String) -> Dictionary:
	if not _has_exact_keys(catalog, ["schema_version", "slices"]) or catalog.schema_version != 1 or not catalog.slices is Array:
		return _failure("PT-CATALOG-SCHEMA", "Playtest catalog must use the exact schema v1 shape.")
	var seen := {}
	var requested_slice: Dictionary = {}
	for value in catalog.slices:
		if not value is Dictionary or not _has_exact_keys(value, ["assignment", "code", "maximum_minutes", "status"]):
			return _failure("PT-CATALOG-SCHEMA", "Every catalog slice must use the exact public field set.")
		var slice: Dictionary = value
		if not slice.code is String or not _matches(String(slice.code), "^B[0-9]{2}$"):
			return _failure("PT-CATALOG-SCHEMA", "Catalog slice code is invalid.")
		var code := String(slice.code)
		if seen.has(code):
			return _failure("PT-SLICE-DUPLICATE", "Catalog contains a duplicate slice code.")
		seen[code] = true
		if not slice.assignment is String or slice.assignment != "固定切片 %s" % code:
			return _failure("PT-CATALOG-SCHEMA", "Catalog assignment must remain neutral and code-based.")
		if not _is_json_integer(slice.maximum_minutes) or int(slice.maximum_minutes) <= 0 or int(slice.maximum_minutes) > 60:
			return _failure("PT-CATALOG-SCHEMA", "Catalog maximum_minutes is invalid.")
		if not slice.status is String or String(slice.status) not in ["blocked", "ready"]:
			return _failure("PT-CATALOG-SCHEMA", "Catalog status is invalid.")
		if code == requested_code:
			requested_slice = slice
	if requested_slice.is_empty():
		return _failure("PT-SLICE-UNKNOWN", "Requested slice code is absent from the catalog.")
	return {"ok": true, "slice": requested_slice}

func _registry_has_code(code: String) -> bool:
	if _registry is Dictionary:
		return (_registry as Dictionary).has(code)
	return _registry.has_code(code)

func _registry_scene(code: String) -> PackedScene:
	var candidate: Variant
	if _registry is Dictionary:
		candidate = (_registry as Dictionary).get(code)
	else:
		candidate = _registry.scene_for_code(code)
	return candidate as PackedScene if candidate is PackedScene else null

func _read_runtime_bytes(path: String, override: PackedByteArray, label: String) -> Dictionary:
	if _fixture_configured:
		if override.is_empty():
			return _failure("PT-FIXTURE", "Injected %s bytes are empty." % label)
		return {"ok": true, "bytes": override.duplicate()}
	return _read_file_bytes(path, label)

func _read_file_bytes(path: String, label: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _failure("PT-READ", "Could not read %s at %s (error %d)." % [label, path, FileAccess.get_open_error()])
	var length := file.get_length()
	if length < 0 or length > MAX_IDENTITY_FILE_BYTES:
		file.close()
		return _failure("PT-READ", "%s exceeds the identity file size limit at %s." % [label, path])
	var bytes := file.get_buffer(length)
	file.close()
	if bytes.size() != length:
		return _failure("PT-READ", "Short read while reading %s at %s." % [label, path])
	return {"ok": true, "bytes": bytes}

func _parse_json_object(bytes: PackedByteArray, label: String) -> Dictionary:
	var text := bytes.get_string_from_utf8()
	if text.to_utf8_buffer() != bytes:
		return _failure("PT-JSON", "%s is not canonical UTF-8." % label)
	var parser := JSON.new()
	var parse_error := parser.parse(text)
	if parse_error != OK:
		return _failure("PT-JSON", "%s is malformed JSON at line %d: %s" % [label, parser.get_error_line(), parser.get_error_message()])
	if not parser.data is Dictionary:
		return _failure("PT-JSON", "%s must be a JSON object." % label)
	return {"ok": true, "value": parser.data}

func _has_exact_keys(value: Dictionary, expected: Array) -> bool:
	var actual: Array[String] = []
	for key in value.keys():
		actual.append(String(key))
	actual.sort()
	var normalized: Array[String] = []
	for key in expected:
		normalized.append(String(key))
	normalized.sort()
	return actual == normalized

func _matches(value: String, expression: String) -> bool:
	var pattern := RegEx.new()
	return pattern.compile(expression) == OK and pattern.search(value) != null

func _is_json_integer(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	if typeof(value) != TYPE_FLOAT:
		return false
	var number := float(value)
	return is_finite(number) and number == floor(number)

func _sha256(bytes: PackedByteArray) -> String:
	var hashing := HashingContext.new()
	if hashing.start(HashingContext.HASH_SHA256) != OK:
		return ""
	if hashing.update(bytes) != OK:
		return ""
	return hashing.finish().hex_encode()

func _failure(code: String, detail: String) -> Dictionary:
	return {"ok": false, "code": code, "detail": detail}
