class_name CommercialPersistenceService
extends Node

## Versioned, single-slot persistence for the product journey and its settings.
##
## Progress is intentionally checkpointed at the main hive. A field scene owns
## transient hazards and carried items, so restoring half of a sortie would be
## less honest than restarting that sortie from the last safe hive hand-off.

signal settings_changed(settings: Dictionary)
signal progress_changed(has_progress: bool)

const JourneyStateScript := preload("res://scripts/world/journey_state.gd")
const FORMAT_ID := "see-you-at-the-hive"
const SCHEMA_VERSION := 1
const PROGRESS_KIND := "journey_progress"
const SETTINGS_KIND := "settings"
const DEFAULT_PROGRESS_PATH := "user://see-you-at-the-hive-progress.json"
const DEFAULT_SETTINGS_PATH := "user://see-you-at-the-hive-settings.json"
const MUSIC_BUS := &"Music"
const SFX_BUS := &"SFX"

const DEFAULT_SETTINGS := {
	"music_volume": 0.78,
	"music_muted": false,
	"sfx_volume": 0.82,
	"sfx_muted": false,
	"fullscreen": false,
	"ui_scale": 1.0,
	"reduce_motion": false,
	"screen_shake": true,
	"show_control_hints": true,
}

var progress_path := DEFAULT_PROGRESS_PATH
var settings_path := DEFAULT_SETTINGS_PATH
var settings: Dictionary = DEFAULT_SETTINGS.duplicate(true)
var last_progress_error := OK
var last_settings_error := OK
var recovered_progress_from_backup := false
var recovered_settings_from_backup := false

var _launch_mode := ""
var _launch_request_pending := false
var _ready_complete := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_audio_buses()
	last_settings_error = load_settings()
	apply_runtime_settings()
	_ready_complete = true


func configure_storage_for_test(test_progress_path: String, test_settings_path: String) -> Error:
	if _ready_complete or test_progress_path.is_empty() or test_settings_path.is_empty():
		return ERR_ALREADY_IN_USE if _ready_complete else ERR_INVALID_PARAMETER
	progress_path = test_progress_path
	settings_path = test_settings_path
	settings = DEFAULT_SETTINGS.duplicate(true)
	return OK


func request_journey_launch(mode: String) -> Error:
	if mode not in ["new", "continue"]:
		return ERR_INVALID_PARAMETER
	_launch_mode = mode
	_launch_request_pending = true
	return OK


func has_pending_launch_request() -> bool:
	return _launch_request_pending


func consume_journey_launch(default_mode := "new") -> String:
	var mode := _launch_mode if _launch_request_pending else default_mode
	_launch_mode = ""
	_launch_request_pending = false
	return mode


func settings_snapshot() -> Dictionary:
	return settings.duplicate(true)


func setting(key: String, fallback: Variant = null) -> Variant:
	return settings.get(key, fallback)


func set_setting(key: String, value: Variant) -> Error:
	if not DEFAULT_SETTINGS.has(key):
		return ERR_INVALID_PARAMETER
	if key == "fullscreen" and bool(value) and OS.has_feature("web"):
		return ERR_UNAVAILABLE
	var candidate := settings.duplicate(true)
	candidate[key] = value
	var sanitized := _sanitize_settings(candidate)
	if sanitized.is_empty():
		return ERR_INVALID_DATA
	var previous := settings
	settings = sanitized
	var save_error := _save_settings()
	if save_error != OK:
		settings = previous
		last_settings_error = save_error
		return save_error
	last_settings_error = OK
	apply_runtime_settings()
	settings_changed.emit(settings_snapshot())
	return OK


func load_settings() -> Error:
	recovered_settings_from_backup = false
	var result := _load_envelope(settings_path, SETTINGS_KIND, true)
	if not bool(result.get("ok", false)):
		settings = DEFAULT_SETTINGS.duplicate(true)
		last_settings_error = int(result.get("error", ERR_FILE_NOT_FOUND))
		return last_settings_error
	var sanitized := _sanitize_settings(result.get("payload", {}))
	if sanitized.is_empty():
		settings = DEFAULT_SETTINGS.duplicate(true)
		last_settings_error = ERR_INVALID_DATA
		return last_settings_error
	settings = sanitized
	recovered_settings_from_backup = bool(result.get("recovered_from_backup", false))
	last_settings_error = OK
	return OK


func _save_settings() -> Error:
	return _write_envelope_atomic(settings_path, SETTINGS_KIND, settings)


func has_progress() -> bool:
	var result := _load_envelope(progress_path, PROGRESS_KIND, true)
	if not bool(result.get("ok", false)):
		last_progress_error = int(result.get("error", ERR_FILE_NOT_FOUND))
		recovered_progress_from_backup = false
		return false
	if not _validate_progress_payload(result.get("payload", {})):
		last_progress_error = ERR_INVALID_DATA
		recovered_progress_from_backup = false
		return false
	last_progress_error = OK
	recovered_progress_from_backup = bool(result.get("recovered_from_backup", false))
	return true


func progress_file_exists() -> bool:
	## Presence is intentionally separate from validity. The title screen uses it
	## to require an explicit second confirmation before deleting a damaged or
	## newer-version save that this build cannot continue.
	return (
		FileAccess.file_exists(ProjectSettings.globalize_path(progress_path))
		or FileAccess.file_exists(ProjectSettings.globalize_path(_backup_path(progress_path)))
	)


func progress_summary() -> Dictionary:
	var result := _load_envelope(progress_path, PROGRESS_KIND, true)
	if not bool(result.get("ok", false)):
		return {"ok": false, "error": int(result.get("error", ERR_FILE_NOT_FOUND))}
	var payload = result.get("payload", {})
	if not _validate_progress_payload(payload):
		return {"ok": false, "error": ERR_INVALID_DATA}
	var saved_state: Dictionary = payload.get("state", {})
	return {
		"ok": true,
		"reserve": int(saved_state.get("reserve", 0)),
		"next_segment": String(payload.get("next_segment", "")),
		"journey_complete": bool(saved_state.get("journey_complete", false)),
		"saved_at_unix": int(result.get("saved_at_unix", 0)),
		"recovered_from_backup": bool(result.get("recovered_from_backup", false)),
	}


func save_journey_state(journey_state: Object) -> Error:
	if journey_state == null or not journey_state.has_method("to_save_dictionary"):
		return ERR_INVALID_PARAMETER
	# A present but unreadable slot is protected exactly like a future-version
	# slot. A confirmed new journey removes it first; a valid backup still counts
	# as readable and may repair a corrupt primary on the next checkpoint.
	if progress_file_exists() and not has_progress():
		return last_progress_error if last_progress_error != OK else ERR_INVALID_DATA
	var state_data = journey_state.call("to_save_dictionary")
	if not state_data is Dictionary:
		return ERR_INVALID_DATA
	var payload := {
		"checkpoint_area": "hive_threshold",
		"checkpoint_policy": "restart_active_sortie",
		"next_segment": String(journey_state.call("next_segment_id")),
		"state": (state_data as Dictionary).duplicate(true),
	}
	if not _validate_progress_payload(payload):
		return ERR_INVALID_DATA
	var error := _write_envelope_atomic(progress_path, PROGRESS_KIND, payload)
	last_progress_error = error
	if error == OK:
		progress_changed.emit(true)
	return error


func restore_journey_state(journey_state: Object) -> Error:
	if journey_state == null or not journey_state.has_method("restore_from_save_dictionary"):
		return ERR_INVALID_PARAMETER
	var result := _load_envelope(progress_path, PROGRESS_KIND, true)
	if not bool(result.get("ok", false)):
		last_progress_error = int(result.get("error", ERR_FILE_NOT_FOUND))
		return last_progress_error
	var payload = result.get("payload", {})
	if not _validate_progress_payload(payload):
		last_progress_error = ERR_INVALID_DATA
		return last_progress_error
	var restore_error = journey_state.call("restore_from_save_dictionary", payload.get("state", {}))
	if not restore_error is int:
		last_progress_error = ERR_INVALID_DATA
		return last_progress_error
	last_progress_error = int(restore_error)
	recovered_progress_from_backup = bool(result.get("recovered_from_backup", false))
	return last_progress_error


func delete_progress() -> Error:
	var first_error := OK
	for candidate in [progress_path, _temporary_path(progress_path), _backup_path(progress_path)]:
		var absolute := ProjectSettings.globalize_path(candidate)
		if not FileAccess.file_exists(absolute):
			continue
		var remove_error := DirAccess.remove_absolute(absolute)
		if remove_error != OK and first_error == OK:
			first_error = remove_error
	last_progress_error = first_error
	if first_error == OK:
		recovered_progress_from_backup = false
		progress_changed.emit(false)
	return first_error


func apply_runtime_settings() -> void:
	_ensure_audio_buses()
	_apply_audio_bus(MUSIC_BUS, float(settings.music_volume), bool(settings.music_muted))
	_apply_audio_bus(SFX_BUS, float(settings.sfx_volume), bool(settings.sfx_muted))
	if not OS.has_feature("web") and DisplayServer.get_name().to_lower() != "headless":
		DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_FULLSCREEN
			if bool(settings.fullscreen)
			else DisplayServer.WINDOW_MODE_WINDOWED
		)


func _ensure_audio_buses() -> void:
	for bus_name in [MUSIC_BUS, SFX_BUS]:
		if AudioServer.get_bus_index(bus_name) >= 0:
			continue
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)


func _apply_audio_bus(bus_name: StringName, linear_volume: float, muted: bool) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		return
	var safe_volume := clampf(linear_volume, 0.0, 1.0)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(0.0001, safe_volume)))
	AudioServer.set_bus_mute(index, muted or safe_volume <= 0.0001)


func _sanitize_settings(source: Variant) -> Dictionary:
	if not source is Dictionary:
		return {}
	var result := DEFAULT_SETTINGS.duplicate(true)
	var dictionary := source as Dictionary
	for key in ["music_muted", "sfx_muted", "fullscreen", "reduce_motion", "screen_shake", "show_control_hints"]:
		if dictionary.has(key) and typeof(dictionary[key]) != TYPE_BOOL:
			return {}
		result[key] = bool(dictionary.get(key, result[key]))
	for key in ["music_volume", "sfx_volume"]:
		var value = dictionary.get(key, result[key])
		if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
			return {}
		result[key] = clampf(float(value), 0.0, 1.0)
	var ui_scale_value = dictionary.get("ui_scale", result.ui_scale)
	if typeof(ui_scale_value) not in [TYPE_INT, TYPE_FLOAT]:
		return {}
	result.ui_scale = clampf(float(ui_scale_value), 0.9, 1.3)
	if bool(result.reduce_motion):
		result.screen_shake = false
	return result


func _validate_progress_payload(payload: Variant) -> bool:
	if not payload is Dictionary:
		return false
	var dictionary := payload as Dictionary
	if String(dictionary.get("checkpoint_area", "")) != "hive_threshold":
		return false
	if String(dictionary.get("checkpoint_policy", "")) != "restart_active_sortie":
		return false
	if not dictionary.get("state", null) is Dictionary:
		return false
	if not dictionary.get("next_segment", null) is String:
		return false
	var probe = JourneyStateScript.new()
	if probe.restore_from_save_dictionary(dictionary.state) != OK:
		return false
	return String(dictionary.next_segment) == String(probe.next_segment_id())


func _write_envelope_atomic(path: String, kind: String, payload: Dictionary) -> Error:
	var envelope := {
		"format": FORMAT_ID,
		"schema_version": SCHEMA_VERSION,
		"kind": kind,
		"saved_at_unix": int(Time.get_unix_time_from_system()),
		"payload": _canonicalize(payload),
	}
	envelope["payload_sha256"] = _payload_checksum(envelope.payload)
	var encoded := JSON.stringify(envelope, "\t") + "\n"
	var temporary := _temporary_path(path)
	var temporary_absolute := ProjectSettings.globalize_path(temporary)
	var final_absolute := ProjectSettings.globalize_path(path)
	var backup_absolute := ProjectSettings.globalize_path(_backup_path(path))
	# A downgraded build must never silently replace data written by a newer
	# schema. Progress can still be removed through the explicit, confirmed
	# new-journey action; settings remain untouched until a compatible build runs.
	for existing_path in [path, _backup_path(path)]:
		if not FileAccess.file_exists(ProjectSettings.globalize_path(existing_path)):
			continue
		var existing_result := _read_envelope(existing_path, kind)
		if int(existing_result.get("error", OK)) == ERR_UNAVAILABLE:
			DirAccess.remove_absolute(temporary_absolute)
			return ERR_UNAVAILABLE
	var directory_error := DirAccess.make_dir_recursive_absolute(final_absolute.get_base_dir())
	if directory_error != OK:
		return directory_error
	var file := FileAccess.open(temporary_absolute, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(encoded)
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		DirAccess.remove_absolute(temporary_absolute)
		return write_error
	var verification := _load_envelope(temporary, kind, false)
	if not bool(verification.get("ok", false)):
		DirAccess.remove_absolute(temporary_absolute)
		return ERR_FILE_CORRUPT
	var moved_original := false
	if FileAccess.file_exists(final_absolute):
		var existing_is_valid := bool(_load_envelope(path, kind, false).get("ok", false))
		if existing_is_valid:
			if FileAccess.file_exists(backup_absolute):
				var remove_backup_error := DirAccess.remove_absolute(backup_absolute)
				if remove_backup_error != OK:
					DirAccess.remove_absolute(temporary_absolute)
					return remove_backup_error
			var backup_error := DirAccess.rename_absolute(final_absolute, backup_absolute)
			if backup_error != OK:
				DirAccess.remove_absolute(temporary_absolute)
				return backup_error
			moved_original = true
		else:
			# Never replace a known-good backup with a corrupt primary. The verified
			# temporary file is about to become the new primary.
			var remove_corrupt_error := DirAccess.remove_absolute(final_absolute)
			if remove_corrupt_error != OK:
				DirAccess.remove_absolute(temporary_absolute)
				return remove_corrupt_error
	var replace_error := DirAccess.rename_absolute(temporary_absolute, final_absolute)
	if replace_error != OK:
		if moved_original:
			DirAccess.rename_absolute(backup_absolute, final_absolute)
		DirAccess.remove_absolute(temporary_absolute)
		return replace_error
	return OK


func _load_envelope(path: String, expected_kind: String, allow_backup: bool) -> Dictionary:
	var result := _read_envelope(path, expected_kind)
	if bool(result.get("ok", false)) and not _payload_is_valid_for_kind(expected_kind, result.get("payload", {})):
		result = {"ok": false, "error": ERR_INVALID_DATA}
	if bool(result.get("ok", false)) or not allow_backup:
		return result
	# A newer primary is authoritative. Falling back to an older backup here
	# would look like a successful continue while actually rolling progress back.
	if int(result.get("error", OK)) == ERR_UNAVAILABLE:
		return result
	var backup_result := _read_envelope(_backup_path(path), expected_kind)
	if bool(backup_result.get("ok", false)) and not _payload_is_valid_for_kind(expected_kind, backup_result.get("payload", {})):
		backup_result = {"ok": false, "error": ERR_INVALID_DATA}
	if bool(backup_result.get("ok", false)):
		backup_result["recovered_from_backup"] = true
		return backup_result
	# Preserve the incompatibility signal when only the backup is from a newer
	# version; callers can then protect it instead of treating the slot as empty.
	if int(backup_result.get("error", OK)) == ERR_UNAVAILABLE:
		return backup_result
	return result


func _payload_is_valid_for_kind(kind: String, payload: Variant) -> bool:
	if kind == PROGRESS_KIND:
		return _validate_progress_payload(payload)
	if kind == SETTINGS_KIND:
		return not _sanitize_settings(payload).is_empty()
	return false


func _read_envelope(path: String, expected_kind: String) -> Dictionary:
	var absolute := ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(absolute):
		return {"ok": false, "error": ERR_FILE_NOT_FOUND}
	var file := FileAccess.open(absolute, FileAccess.READ)
	if file == null:
		return {"ok": false, "error": FileAccess.get_open_error()}
	var parser := JSON.new()
	var parse_error := parser.parse(file.get_as_text())
	file.close()
	if parse_error != OK:
		return {"ok": false, "error": ERR_FILE_CORRUPT}
	var parsed = parser.data
	if not parsed is Dictionary:
		return {"ok": false, "error": ERR_FILE_CORRUPT}
	var envelope := parsed as Dictionary
	if String(envelope.get("format", "")) != FORMAT_ID:
		return {"ok": false, "error": ERR_FILE_UNRECOGNIZED}
	var raw_version = envelope.get("schema_version", -1)
	if typeof(raw_version) not in [TYPE_INT, TYPE_FLOAT] or float(raw_version) != floorf(float(raw_version)):
		return {"ok": false, "error": ERR_FILE_UNRECOGNIZED}
	var version := int(raw_version)
	if version > SCHEMA_VERSION:
		return {"ok": false, "error": ERR_UNAVAILABLE}
	if version < 1:
		return {"ok": false, "error": ERR_FILE_UNRECOGNIZED}
	if String(envelope.get("kind", "")) != expected_kind:
		return {"ok": false, "error": ERR_INVALID_DATA}
	var payload = envelope.get("payload", null)
	if not payload is Dictionary:
		return {"ok": false, "error": ERR_INVALID_DATA}
	if String(envelope.get("payload_sha256", "")) != _payload_checksum(payload):
		return {"ok": false, "error": ERR_FILE_CORRUPT}
	return {
		"ok": true,
		"payload": (payload as Dictionary).duplicate(true),
		"saved_at_unix": int(envelope.get("saved_at_unix", 0)),
		"recovered_from_backup": false,
	}


func _payload_checksum(payload: Variant) -> String:
	# Godot's JSON parser represents JSON numbers as floats. Normalize numbers to
	# canonical strings for the digest so an integer 6 and parsed 6.0 verify as
	# the same JSON value while the stored payload keeps its numeric types.
	return JSON.stringify(_canonicalize_for_checksum(payload)).sha256_text()


func _canonicalize_for_checksum(value: Variant) -> Variant:
	if value is Dictionary:
		var source := value as Dictionary
		var keys: Array[String] = []
		for source_key in source.keys():
			keys.append(String(source_key))
		keys.sort()
		var result := {}
		for key in keys:
			result[key] = _canonicalize_for_checksum(source.get(key))
		return result
	if value is Array:
		var result: Array = []
		for item in value:
			result.append(_canonicalize_for_checksum(item))
		return result
	if typeof(value) in [TYPE_INT, TYPE_FLOAT]:
		return str(float(value))
	return value


func _canonicalize(value: Variant) -> Variant:
	if value is Dictionary:
		var source := value as Dictionary
		var keys: Array[String] = []
		for source_key in source.keys():
			keys.append(String(source_key))
		keys.sort()
		var result := {}
		for key in keys:
			result[key] = _canonicalize(source.get(key))
		return result
	if value is Array:
		var result: Array = []
		for item in value:
			result.append(_canonicalize(item))
		return result
	return value


func _temporary_path(path: String) -> String:
	return "%s.tmp" % path


func _backup_path(path: String) -> String:
	return "%s.bak" % path
