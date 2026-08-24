class_name SoundFeedback
extends Node

const MIX_RATE := 22050.0

var player: AudioStreamPlayer
var playback: AudioStreamGeneratorPlayback
var remaining_frames := 0
var phase := 0.0
var frequency := 440.0
var amplitude := 0.12
var enabled := true

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

## Compatibility shim for callers that have not moved to MusicDirector yet.
## SoundFeedback now owns sound effects only, so changing season is a safe no-op.
func set_season(_index: int) -> void:
	pass

func set_enabled(value: bool) -> void:
	enabled = value
	if player != null and player.is_inside_tree():
		player.stream_paused = not enabled

func play_cue(cue: String) -> void:
	if not enabled or playback == null:
		return
	match cue:
		"harvest": start_tone(620.0, 0.07, 0.08)
		"home": start_tone(330.0, 0.22, 0.14)
		"repel": start_tone(190.0, 0.09, 0.13)
		"evade": start_tone(410.0, 0.08, 0.10)
		"sense": start_tone(470.0, 0.18, 0.08)
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

func _exit_tree() -> void:
	if player == null:
		return
	player.stop()
	playback = null
	player.stream = null
