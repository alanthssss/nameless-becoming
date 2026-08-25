class_name NamelessSaveManager
extends RefCounted

const DEFAULT_SAVE_PATH := "user://nameless.cfg"
# Compatibility name for callers that only need to inspect the ordinary path.
const SAVE_PATH := DEFAULT_SAVE_PATH
const PLAYTEST_SAVE_PREFIX := "user://nameless-playtest-"

var _save_path := DEFAULT_SAVE_PATH
var _namespace_locked := false

var best_stage := 0
var runs_started := 0
var runs_completed := 0
var fullscreen := false
var sound_enabled := true
var last_run_seconds := 0.0

func configure_playtest_namespace(ticket_sha256: String) -> Error:
	if _namespace_locked:
		return ERR_ALREADY_IN_USE
	var sha_pattern := RegEx.new()
	if sha_pattern.compile("^[0-9a-f]{64}$") != OK or sha_pattern.search(ticket_sha256) == null:
		return ERR_INVALID_PARAMETER
	_save_path = "%s%s.cfg" % [PLAYTEST_SAVE_PREFIX, ticket_sha256]
	return OK

func save_path() -> String:
	return _save_path

func namespace_is_locked() -> bool:
	return _namespace_locked

func load_data() -> Error:
	_namespace_locked = true
	var config := ConfigFile.new()
	var load_error := config.load(_save_path)
	if load_error != OK:
		return load_error
	best_stage = int(config.get_value("progress", "best_stage", 0))
	runs_started = int(config.get_value("progress", "runs_started", 0))
	runs_completed = int(config.get_value("progress", "runs_completed", 0))
	fullscreen = bool(config.get_value("settings", "fullscreen", false))
	sound_enabled = bool(config.get_value("settings", "sound_enabled", true))
	last_run_seconds = float(config.get_value("progress", "last_run_seconds", 0.0))
	return OK

func save_data() -> Error:
	_namespace_locked = true
	var config := ConfigFile.new()
	config.set_value("progress", "best_stage", best_stage)
	config.set_value("progress", "runs_started", runs_started)
	config.set_value("progress", "runs_completed", runs_completed)
	config.set_value("settings", "fullscreen", fullscreen)
	config.set_value("settings", "sound_enabled", sound_enabled)
	config.set_value("progress", "last_run_seconds", last_run_seconds)
	return config.save(_save_path)

func begin_run() -> void:
	runs_started += 1
	save_data()

func record_stage(stage: int) -> void:
	best_stage = maxi(best_stage, stage)
	save_data()

func record_completion(duration_seconds := 0.0) -> void:
	runs_completed += 1
	best_stage = maxi(best_stage, 5)
	last_run_seconds = duration_seconds
	save_data()

func record_failure(duration_seconds: float) -> void:
	last_run_seconds = duration_seconds
	save_data()
