class_name NamelessSaveManager
extends RefCounted

const SAVE_PATH := "user://nameless.cfg"

var best_stage := 0
var runs_started := 0
var runs_completed := 0
var fullscreen := false
var sound_enabled := true
var last_run_seconds := 0.0

func load_data() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	best_stage = int(config.get_value("progress", "best_stage", 0))
	runs_started = int(config.get_value("progress", "runs_started", 0))
	runs_completed = int(config.get_value("progress", "runs_completed", 0))
	fullscreen = bool(config.get_value("settings", "fullscreen", false))
	sound_enabled = bool(config.get_value("settings", "sound_enabled", true))
	last_run_seconds = float(config.get_value("progress", "last_run_seconds", 0.0))

func save_data() -> Error:
	var config := ConfigFile.new()
	config.set_value("progress", "best_stage", best_stage)
	config.set_value("progress", "runs_started", runs_started)
	config.set_value("progress", "runs_completed", runs_completed)
	config.set_value("settings", "fullscreen", fullscreen)
	config.set_value("settings", "sound_enabled", sound_enabled)
	config.set_value("progress", "last_run_seconds", last_run_seconds)
	return config.save(SAVE_PATH)

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
