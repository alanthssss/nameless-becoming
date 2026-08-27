class_name MusicDirector
extends Node

const FAMILY_NAMES: Array[String] = ["spring", "summer", "autumn", "winter"]

var player: AudioStreamPlayer = AudioStreamPlayer.new()
var enabled := true
var family := 0
var mode: StringName = &"explore"
var tuning_progress := 0


func _ready() -> void:
	player.volume_db = -13.0
	add_child(player)


func set_enabled(value: bool) -> void:
	enabled = value
	player.stream_paused = not value
	if value and player.stream != null and not player.playing:
		player.play()


func enter_explore(next_family: int) -> void:
	family = clampi(next_family, 0, 3)
	mode = &"explore"
	tuning_progress = 0
	_play_current()


func enter_incident(next_family: int) -> void:
	family = clampi(next_family, 0, 3)
	mode = &"incident"
	tuning_progress = 0
	_play_current()


func enter_boss(next_family: int) -> void:
	# Compatibility alias for the legacy Main phase schema. The maintained audio
	# identity is an incident arrangement; the old caller does not select a Boss
	# file or expose Boss framing in the commercial Journey package.
	enter_incident(next_family)


func enter_hive() -> void:
	# The field theme remains recognisable at the hive, but breathes more softly.
	var needs_explore_stream := mode == &"incident" or player.stream == null
	mode = &"hive"
	if needs_explore_stream:
		_play_current()
	player.pitch_scale = 0.985
	player.volume_db = -18.0


func set_boss_tuning_progress(value: int) -> void:
	tuning_progress = clampi(value, 0, 3)
	if mode != &"incident":
		return
	# The eight masters already contain their intended key and tempo.  Global
	# pitch-shifting made the slower incident arrangements sound like the same low drone, so
	# tuning now changes presence without detuning the written arrangement.
	player.pitch_scale = 1.0
	player.volume_db = lerpf(-11.0, -14.0, float(tuning_progress) / 3.0)


func current_track_path() -> String:
	var suffix := "incident" if mode == &"incident" else "explore"
	return "res://assets/music/%s_%s.wav" % [FAMILY_NAMES[family], suffix]


func _play_current() -> void:
	# Stop the previous playback before replacing its stream. Rapid state changes
	# (including tests and scene transitions) must not retain WAV playback objects.
	player.stop()
	var stream := load(current_track_path()) as AudioStreamWAV
	if stream == null:
		push_error("音乐文件无法加载：%s" % current_track_path())
		return
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = maxi(1, roundi(stream.get_length() * float(stream.mix_rate)))
	player.stream = stream
	player.pitch_scale = 1.0
	player.volume_db = -11.0 if mode == &"incident" else -13.0
	if enabled:
		player.play()


func _exit_tree() -> void:
	player.stop()
	player.stream = null
