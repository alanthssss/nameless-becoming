class_name SoundFeedback
extends Node

const MIX_RATE := 22050.0
const ROOTS := [220.0, 246.94, 196.0, 164.81]
const MELODIES := [
	[0, 2, 4, 7, 4, 2, 1, -1, 0, 2, 5, 4, 2, 1, 0, -1],
	[0, 4, 5, 7, 9, 7, 5, 4, 2, 5, 7, 11, 9, 7, 4, 2],
	[7, 5, 4, 2, 0, 2, 4, -1, 5, 4, 2, 0, -3, 0, 2, -1],
	[0, -3, 2, -1, 4, 2, 0, -1, 0, 2, 5, 2, 0, -3, -5, -1]
]
const PENTATONIC := [0, 2, 4, 7, 9]

var player: AudioStreamPlayer
var playback: AudioStreamGeneratorPlayback
var music_player: AudioStreamPlayer
var music_playback: AudioStreamGeneratorPlayback
var remaining_frames := 0
var phase := 0.0
var frequency := 440.0
var amplitude := 0.12
var enabled := true
var season_index := 0
var music_context := "field" # field / boss / hive
var music_frame := 0
var melody_phase := 0.0
var bass_phase := 0.0
var breeze_phase := 0.0

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
	music_player.volume_db = -18.0
	add_child(music_player)
	music_player.play()
	music_playback = music_player.get_stream_playback()

func set_season(index: int) -> void:
	season_index = clampi(index, 0, 3)
	music_context = "field"
	music_frame = 0

func set_boss(index: int) -> void:
	season_index = clampi(index, 0, 3)
	music_context = "boss"
	music_frame = 0

func set_hive(index: int) -> void:
	season_index = clampi(index, 0, 3)
	music_context = "hive"
	music_frame = 0

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
		"evade": start_tone(410.0, 0.08, 0.10)
		"decoy": start_tone(540.0, 0.16, 0.09)
		"full": start_tone(175.0, 0.12, 0.13)
		"hurt": start_tone(105.0, 0.18, 0.16)
		"upgrade": start_tone(520.0, 0.28, 0.12)
		"tune": start_tone(760.0, 0.32, 0.15)
		"win": start_tone(880.0, 0.55, 0.13)
		"loss": start_tone(145.0, 0.48, 0.12)
		"drink": start_tone(440.0, 0.15, 0.12)

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
	# 四季不再只是同一首曲子的移调。速度、发音、节奏密度和空间层都不同；
	# Boss 使用更快、更密的变奏，蜂巢则退回稳定的宫音呼吸。
	var step_seconds: Array[float] = [0.48, 0.28, 0.58, 0.76]
	if music_context == "boss":
		step_seconds[season_index] *= 0.62
	elif music_context == "hive":
		step_seconds[season_index] = 0.82
	var frames_per_step := roundi(MIX_RATE * step_seconds[season_index])
	var melody: Array = MELODIES[season_index]
	for frame in music_playback.get_frames_available():
		var step := (music_frame / frames_per_step) % melody.size()
		var position_in_step := float(music_frame % frames_per_step) / float(frames_per_step)
		var semitone := int(melody[step])
		var melody_frequency: float = float(ROOTS[season_index]) * pow(2.0, float(semitone) / 12.0)
		var bass_degree: int = int(PENTATONIC[(step / 4) % PENTATONIC.size()])
		var bass_frequency: float = float(ROOTS[season_index]) * 0.5 * pow(2.0, float(bass_degree) / 12.0)
		var envelope_power: Array[float] = [2.6, 0.9, 1.8, 0.45]
		var melody_envelope := pow(maxf(0.0, 1.0 - position_in_step), envelope_power[season_index]) * minf(1.0, position_in_step * 24.0)
		var bass_envelope := 0.35 + 0.25 * pow(maxf(0.0, 1.0 - fmod(position_in_step * 2.0, 1.0)), 2.0)
		var pulse_density: Array[int] = [4, 1, 6, 8]
		var pulse := 0.028 if music_frame % (frames_per_step * pulse_density[season_index]) < 240 else 0.0
		if music_context == "boss":
			pulse *= 2.4
		elif music_context == "hive":
			pulse = 0.0
		var noise_like := sin(breeze_phase) * sin(breeze_phase * 0.731)
		var melody_wave := sin(melody_phase)
		match season_index:
			0: melody_wave = sin(melody_phase) * 0.75 + sin(melody_phase * 2.0) * 0.18 # 木与空气
			1: melody_wave = signf(sin(melody_phase)) * 0.55 + sin(melody_phase * 2.0) * 0.2 # 夏季脉冲
			2: melody_wave = sin(melody_phase) * 0.65 + sin(melody_phase * 0.5) * 0.22 # 秋季留白
			3: melody_wave = sin(melody_phase) * 0.58 + sin(melody_phase * 0.25) * 0.28 # 冬季长音
		var melody_gain := 0.04 if music_context == "hive" else (0.09 if music_context == "boss" else 0.072)
		var sample := melody_wave * melody_gain * melody_envelope
		sample += sin(bass_phase) * (0.06 if season_index == 3 else 0.042) * bass_envelope
		sample += noise_like * pulse
		music_playback.push_frame(Vector2(sample * 0.96, sample))
		melody_phase = fmod(melody_phase + TAU * melody_frequency / MIX_RATE, TAU)
		bass_phase = fmod(bass_phase + TAU * bass_frequency / MIX_RATE, TAU)
		breeze_phase = fmod(breeze_phase + TAU * 1837.0 / MIX_RATE, TAU)
		music_frame += 1

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
