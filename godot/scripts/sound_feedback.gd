class_name SoundFeedback
extends Node

const MIX_RATE := 22050.0

var player: AudioStreamPlayer
var playback: AudioStreamGeneratorPlayback
var music_player: AudioStreamPlayer
var music_playback: AudioStreamGeneratorPlayback
var remaining_frames := 0
var phase := 0.0
var frequency := 440.0
var amplitude := 0.12
var enabled := true
var music_phases := [0.0, 0.0, 0.0]
var music_clock := 0
var season_index := 0
var season_chords := [
	[220.00, 277.18, 329.63],
	[246.94, 311.13, 369.99],
	[196.00, 246.94, 293.66],
	[164.81, 220.00, 246.94]
]

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		return
	player = AudioStreamPlayer.new()
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = MIX_RATE
	stream.buffer_length = 0.25
	player.stream = stream
	player.volume_db = -8.0
	add_child(player)
	player.play()
	playback = player.get_stream_playback()
	music_player = AudioStreamPlayer.new()
	var music_stream := AudioStreamGenerator.new()
	music_stream.mix_rate = MIX_RATE
	music_stream.buffer_length = 0.5
	music_player.stream = music_stream
	music_player.volume_db = -14.0
	add_child(music_player)
	music_player.play()
	music_playback = music_player.get_stream_playback()

func set_season(index: int) -> void:
	season_index = clampi(index, 0, season_chords.size() - 1)

func set_enabled(value: bool) -> void:
	enabled = value
	if player != null and player.is_inside_tree():
		player.stream_paused = not enabled
	if music_player != null and music_player.is_inside_tree():
		music_player.stream_paused = not enabled

func play_cue(cue: String) -> void:
	if not enabled or playback == null:
		return
	match cue:
		"harvest": start_tone(620.0, 0.07, 0.08)
		"home": start_tone(330.0, 0.22, 0.14)
		"repel": start_tone(190.0, 0.09, 0.13)
		"hurt": start_tone(105.0, 0.18, 0.16)
		"upgrade": start_tone(520.0, 0.28, 0.12)
		"tune": start_tone(760.0, 0.32, 0.15)
		"win": start_tone(880.0, 0.55, 0.13)
		"loss": start_tone(145.0, 0.48, 0.12)

func start_tone(next_frequency: float, duration: float, next_amplitude: float) -> void:
	frequency = next_frequency
	amplitude = next_amplitude
	remaining_frames = roundi(duration * MIX_RATE)
	phase = 0.0

func _process(_delta: float) -> void:
	if not enabled:
		return
	if playback != null and remaining_frames > 0:
		var frames := mini(playback.get_frames_available(), remaining_frames)
		for i in frames:
			var envelope := minf(1.0, float(remaining_frames) / (MIX_RATE * 0.04))
			var sample := sin(phase) * amplitude * envelope
			playback.push_frame(Vector2(sample, sample))
			phase = fmod(phase + TAU * frequency / MIX_RATE, TAU)
			remaining_frames -= 1
	fill_music_buffer()

func fill_music_buffer() -> void:
	if music_playback == null:
		return
	var chord: Array = season_chords[season_index]
	var frames := music_playback.get_frames_available()
	for frame in frames:
		var breath := 0.62 + sin(float(music_clock) / MIX_RATE * TAU / 7.0) * 0.18
		var sample := 0.0
		for voice in 3:
			sample += sin(float(music_phases[voice]))
			music_phases[voice] = fmod(float(music_phases[voice]) + TAU * float(chord[voice]) / MIX_RATE, TAU)
		sample = sample / 3.0 * 0.075 * breath
		music_playback.push_frame(Vector2(sample * 0.96, sample))
		music_clock += 1

func _exit_tree() -> void:
	if player == null:
		return
	player.stop()
	playback = null
	player.stream = null
	if music_player != null:
		music_player.stop()
		music_playback = null
		music_player.stream = null
