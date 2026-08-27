class_name SoundFeedback
extends Node

const MIX_RATE := 22050.0
const ASSET_VOICE_COUNT := 4
const COMMERCIAL_AUDIO_ROOT := "res://assets/audio/commercial"
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
	"pollinate": Vector3(720.0, 0.20, 0.12),
	"mismatch": Vector3(230.0, 0.11, 0.10),
	"honey_loss": Vector3(145.0, 0.30, 0.12),
	"repair": Vector3(360.0, 0.24, 0.11),
	"seed": Vector3(690.0, 0.18, 0.09),
	"seed_shell_rustle": Vector3(420.0, 0.42, 0.10),
	"warmth_link": Vector3(330.0, 0.34, 0.10),
	"carry_log": Vector3(165.0, 0.28, 0.13),
	"handoff": Vector3(650.0, 0.38, 0.10),
	"complete": Vector3(660.0, 0.48, 0.11),
}

## Commercial Journey cues resolve to checked-in, deterministic layered assets.
## The tone table remains only as a compatibility fallback if an asset cannot be
## loaded; no current Journey cue is expected to reach it.
const CUE_ASSET_FILES := {
	"harvest": "nectar_collect.wav",
	"home": "handoff.wav",
	"repel": "evade_dart.wav",
	"evade": "evade_dart.wav",
	"attack_lock": "observe_rustle.wav",
	"evade_clear": "evade_dart.wav",
	"sense": "observe_rustle.wav",
	"decoy": "seed_place.wav",
	"full": "pouch_full.wav",
	"hurt": "honey_loss.wav",
	"upgrade": "complete.wav",
	"tune": "seed_shell_rustle.wav",
	"relay": "relay_drop.wav",
	"win": "complete.wav",
	"loss": "honey_loss.wav",
	"drink": "nectar_collect.wav",
	"pollinate": "pollination_bloom.wav",
	"mismatch": "honey_loss.wav",
	"honey_loss": "honey_loss.wav",
	"repair": "repair_tap.wav",
	"seed": "seed_place.wav",
	"seed_shell_rustle": "seed_shell_rustle.wav",
	"warmth_link": "warmth_link.wav",
	"carry_log": "carry_log.wav",
	"handoff": "handoff.wav",
	"complete": "complete.wav",
}

var player: AudioStreamPlayer
var playback: AudioStreamGeneratorPlayback
var asset_players: Array[AudioStreamPlayer] = []
var asset_streams: Dictionary = {}
var next_asset_voice := 0
var remaining_frames := 0
var phase := 0.0
var frequency := 440.0
var amplitude := 0.12
var enabled := true
## Read-only-by-convention diagnostic hook. Headless tests can verify that a
## production cue was requested without creating an audio device or changing it.
var last_cue := ""
var last_asset_path := ""
var last_cue_used_asset := false

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		return
	player = _new_output_player()
	add_child(player)
	player.play()
	playback = player.get_stream_playback()
	for voice_index in ASSET_VOICE_COUNT:
		var asset_player := _new_asset_player()
		asset_player.name = "CommercialSfxVoice%d" % (voice_index + 1)
		add_child(asset_player)
		asset_players.append(asset_player)

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
		for asset_player in asset_players:
			asset_player.stop()
			asset_player.stream = null
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

func _new_output_player() -> AudioStreamPlayer:
	var output := AudioStreamPlayer.new()
	# Web defaults to sample playback, but a live AudioStreamGenerator can only
	# be consumed as a stream. Force that mode on every platform so Web does not
	# reject the procedural feedback channel during startup.
	output.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	output.stream = _new_generator_stream()
	output.bus = &"SFX" if AudioServer.get_bus_index(&"SFX") >= 0 else &"Master"
	output.volume_db = -8.0
	return output

func _new_asset_player() -> AudioStreamPlayer:
	var output := AudioStreamPlayer.new()
	# Short authored cues use the browser's low-latency sample path. The procedural
	# fallback above remains forced through the mixer stream path it requires.
	output.playback_type = AudioServer.PLAYBACK_TYPE_SAMPLE
	output.bus = &"SFX" if AudioServer.get_bus_index(&"SFX") >= 0 else &"Master"
	return output

func cue_asset_path(cue: String) -> String:
	var filename := String(CUE_ASSET_FILES.get(cue, ""))
	return "" if filename.is_empty() else "%s/%s" % [COMMERCIAL_AUDIO_ROOT, filename]

func asset_stream_for_cue(cue: String) -> AudioStreamWAV:
	var path := cue_asset_path(cue)
	if path.is_empty():
		return null
	if asset_streams.has(path):
		return asset_streams[path] as AudioStreamWAV
	var stream := load(path) as AudioStreamWAV
	if stream != null:
		asset_streams[path] = stream
	return stream

func play_cue(cue: String) -> void:
	if not enabled or (not CUE_TONES.has(cue) and not CUE_ASSET_FILES.has(cue)):
		return
	last_cue = cue
	last_asset_path = ""
	last_cue_used_asset = false
	var asset_stream := asset_stream_for_cue(cue)
	if asset_stream != null:
		last_asset_path = cue_asset_path(cue)
		last_cue_used_asset = true
		if not asset_players.is_empty():
			var asset_player := asset_players[next_asset_voice]
			next_asset_voice = (next_asset_voice + 1) % asset_players.size()
			asset_player.stop()
			asset_player.stream = asset_stream
			asset_player.play()
		return
	if playback == null:
		return
	if not CUE_TONES.has(cue):
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
	for asset_player in asset_players:
		asset_player.stop()
		asset_player.stream = null
	asset_players.clear()
	if player == null:
		return
	player.stop()
	playback = null
	player.stream = null
