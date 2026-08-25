class_name SoundFeedback
extends Node

const MIX_RATE := 22050.0
const CUE_TONES := {
	"harvest": Vector3(620.0, 0.07, 0.08),
	"home": Vector3(330.0, 0.22, 0.14),
	"repel": Vector3(190.0, 0.09, 0.13),
	"evade": Vector3(410.0, 0.08, 0.10),
	"attack_lock": Vector3(265.0, 0.06, 0.11),
	"evade_clear": Vector3(760.0, 0.16, 0.13),
	"sense": Vector3(470.0, 0.18, 0.08),
	"decoy": Vector3(540.0, 0.16, 0.09),
	"full": Vector3(175.0, 0.12, 0.13),
	"hurt": Vector3(105.0, 0.18, 0.16),
	"upgrade": Vector3(520.0, 0.28, 0.12),
	"tune": Vector3(760.0, 0.32, 0.15),
	"relay": Vector3(590.0, 0.18, 0.10),
	"win": Vector3(880.0, 0.55, 0.13),
	"loss": Vector3(145.0, 0.48, 0.12),
	"drink": Vector3(440.0, 0.15, 0.12),
}

var player: AudioStreamPlayer
var playback: AudioStreamGeneratorPlayback
var remaining_frames := 0
var phase := 0.0
var frequency := 440.0
var amplitude := 0.12
var enabled := true
## Read-only-by-convention diagnostic hook. Headless tests can verify that a
## production cue was requested without creating an audio device or changing it.
var last_cue := ""

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		return
	player = AudioStreamPlayer.new()
	player.stream = _new_generator_stream()
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
	if not enabled:
		# Focus loss is a hard feedback boundary. Discard both ungenerated frames and
		# samples already queued on the audio device so an old cue cannot resume later.
		remaining_frames = 0
		phase = 0.0
		if player != null and player.is_inside_tree():
			player.stop()
			# Godot rejects clear_buffer() while the generator playback is active,
			# including the same frame as stop(). Replacing the generator after stop
			# discards that inaccessible device queue synchronously and safely.
			playback = null
			player.stream = _new_generator_stream()
		return
	if player != null and player.is_inside_tree() and not player.playing:
		player.play()
		playback = player.get_stream_playback()

func _new_generator_stream() -> AudioStreamGenerator:
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = MIX_RATE
	stream.buffer_length = 0.25
	return stream

func play_cue(cue: String) -> void:
	if not enabled or not CUE_TONES.has(cue):
		return
	last_cue = cue
	if playback == null:
		return
	var tone: Vector3 = CUE_TONES[cue]
	start_tone(tone.x, tone.y, tone.z)

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
