extends RefCounted

const COMMIT := "0123456789abcdef0123456789abcdef01234567"
const OTHER_COMMIT := "89abcdef0123456789abcdef0123456789abcdef"
const ARTIFACT_SHA := "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

func json_bytes(value: Variant) -> PackedByteArray:
	return (JSON.stringify(value, "\t") + "\n").to_utf8_buffer()

func sha256(bytes: PackedByteArray) -> String:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(bytes)
	return hashing.finish().hex_encode()

func write_bytes(path: String, bytes: PackedByteArray) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_buffer(bytes)
	file.close()
	return OK

func make_catalog(code := "B01", status := "ready") -> Dictionary:
	return {
		"schema_version": 1,
		"slices": [{
			"code": code,
			"assignment": "固定切片 %s" % code,
			"maximum_minutes": 10,
			"status": status,
		}],
	}

func make_provenance(commit := COMMIT) -> Dictionary:
	return {
		"schema_version": 1,
		"product_version": String(ProjectSettings.get_setting("application/config/version")),
		"commit": commit,
		"dirty": false,
	}

func make_manifest(commit := COMMIT) -> Dictionary:
	return {
		"schema_version": 1,
		"product_version": String(ProjectSettings.get_setting("application/config/version")),
		"commit": commit,
		"dirty": false,
		"platform": "macos-universal",
		"filename": "NamelessBecoming-macOS.zip",
		"size": 12345,
		"sha256": ARTIFACT_SHA,
	}

func make_ticket(manifest_bytes: PackedByteArray, catalog_bytes: PackedByteArray, code := "B01", commit := COMMIT) -> Dictionary:
	return {
		"schema_version": 1,
		"session_id": "NB-B01-TEST-0001",
		"task": {"code": "B", "slice_code": code},
		"product": {
			"id": "nameless-becoming",
			"display_name": "一会儿巢里见",
			"version": String(ProjectSettings.get_setting("application/config/version")),
			"commit": commit,
			"dirty": false,
		},
		"artifact": {
			"platform": "macos-universal",
			"filename": "NamelessBecoming-macOS.zip",
			"size": 12345,
			"sha256": ARTIFACT_SHA,
			"manifest_sha256": sha256(manifest_bytes),
		},
		"catalog_sha256": sha256(catalog_bytes),
	}

func create(directory: String, code := "B01", status := "ready") -> Dictionary:
	DirAccess.make_dir_recursive_absolute(directory)
	var catalog := make_catalog(code, status)
	var provenance := make_provenance()
	var manifest := make_manifest()
	var catalog_bytes := json_bytes(catalog)
	var provenance_bytes := json_bytes(provenance)
	var manifest_bytes := json_bytes(manifest)
	var ticket := make_ticket(manifest_bytes, catalog_bytes, code)
	var fixture := {
		"directory": directory,
		"ticket_path": directory.path_join("playtest-ticket.json"),
		"manifest_path": directory.path_join("artifact-manifest.json"),
		"ticket": ticket,
		"catalog": catalog,
		"provenance": provenance,
		"manifest": manifest,
		"catalog_bytes": catalog_bytes,
		"provenance_bytes": provenance_bytes,
		"manifest_bytes": manifest_bytes,
		"registry": {code: load("res://playtest/b01_evade_slice.tscn") as PackedScene},
	}
	write_fixture(fixture)
	return fixture

func write_fixture(fixture: Dictionary) -> void:
	fixture.catalog_bytes = json_bytes(fixture.catalog)
	fixture.provenance_bytes = json_bytes(fixture.provenance)
	fixture.manifest_bytes = json_bytes(fixture.manifest)
	fixture.ticket.catalog_sha256 = sha256(fixture.catalog_bytes)
	fixture.ticket.artifact.manifest_sha256 = sha256(fixture.manifest_bytes)
	write_bytes(fixture.manifest_path, fixture.manifest_bytes)
	write_bytes(fixture.ticket_path, json_bytes(fixture.ticket))

func validator(fixture: Dictionary, registry_override: Variant = null, platform := "macOS") -> PlaytestTicketValidator:
	var instance := PlaytestTicketValidator.new()
	var registry: Dictionary = fixture.registry if registry_override == null else registry_override
	var configure_error := instance.configure_test_fixture({
		"catalog_bytes": fixture.catalog_bytes,
		"provenance_bytes": fixture.provenance_bytes,
		"platform": platform,
		"registry": registry,
	})
	assert(configure_error == OK)
	return instance

func remove_tree(path: String) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		var child := path.path_join(entry)
		if directory.current_is_dir():
			remove_tree(child)
		else:
			DirAccess.remove_absolute(child)
		entry = directory.get_next()
	directory.list_dir_end()
	DirAccess.remove_absolute(path)
