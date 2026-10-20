extends Node
## Original, generated PCM: no external music or asset licenses.
## Three authored arrangements crossfade; one-shots use a fixed voice pool.
const RATE := 22050
const MUSIC_DB := -13.0
const AMBIENCE_DB := -21.0
const SFX_DB := -8.0
var _stage := -1
var _muted := false
var _tracks: Array[AudioStreamWAV] = []
var _air: Array[AudioStreamWAV] = []
var _samples: Dictionary = {}
var _music: Array[AudioStreamPlayer] = []
var _ambience: Array[AudioStreamPlayer] = []
var _voices: Array[AudioStreamPlayer] = []
var _active := 0
var _voice := 0
var _crossfade: Tween
var _duck := 0.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.seed = 8753
	_bus("Music", MUSIC_DB)
	_bus("SFX", SFX_DB)
	_bus("Ambience", AMBIENCE_DB)
	for i in 2:
		_music.append(_player("Music"))
		_ambience.append(_player("Ambience"))
	for i in 8:
		_voices.append(_player("SFX"))
	for index in 3:
		_tracks.append(_make_music(index))
		_air.append(_make_air(index))
	_samples["burst"] = _make_effect("burst", 0.30)
	_samples["rescue"] = _make_effect("rescue", 0.65)
	_samples["ring"] = _make_effect("ring", 0.55)
	_samples["gate"] = _make_effect("gate", 0.25)
	_samples["hit"] = _make_effect("hit", 0.20)
	_samples["recover"] = _make_effect("recover", 0.75)
	_samples["finish"] = _make_effect("finish", 1.50)
	_samples["ready"] = _make_effect("ready", 0.18)
	set_stage(0)
	set_muted(_muted)

func _exit_tree() -> void:
	if is_instance_valid(_crossfade):
		_crossfade.kill()
	for player in _music + _ambience + _voices:
		player.stop()
		player.stream = null
	_tracks.clear()
	_air.clear()
	_samples.clear()

func _process(delta: float) -> void:
	_duck = maxf(0.0, _duck - delta)
	var bus := AudioServer.get_bus_index("Music")
	if bus >= 0:
		AudioServer.set_bus_volume_db(bus, MUSIC_DB - 4.0 * minf(1.0, _duck / 0.15))

func set_stage(index: int) -> void:
	index = clampi(index, 0, 2)
	if index == _stage or _tracks.is_empty():
		return
	var previous := _active
	_active = 1 - _active
	var music := _music[_active]
	var air := _ambience[_active]
	music.stream = _tracks[index]
	air.stream = _air[index]
	music.volume_db = -40.0
	air.volume_db = -40.0
	music.play()
	air.play()
	if is_instance_valid(_crossfade):
		_crossfade.kill()
	_crossfade = create_tween().set_parallel(true)
	_crossfade.tween_property(music, "volume_db", 0.0, 1.2)
	_crossfade.tween_property(air, "volume_db", 0.0, 1.6)
	_crossfade.tween_property(_music[previous], "volume_db", -48.0, 1.2)
	_crossfade.tween_property(_ambience[previous], "volume_db", -48.0, 1.6)
	_crossfade.chain().tween_callback(_stop_inactive.bind(previous))
	_stage = index

func _stop_inactive(index: int) -> void:
	if index != _active:
		_music[index].stop()
		_ambience[index].stop()

func play_event(kind: String) -> void:
	if not _samples.has(kind) or _voices.is_empty():
		return
	var player := _voices[_voice]
	_voice = (_voice + 1) % _voices.size()
	player.stop()
	player.stream = _samples[kind]
	player.pitch_scale = _rng.randf_range(0.97, 1.03)
	player.volume_db = -1.5 if kind == "burst" else 0.0
	player.play()
	if kind in ["rescue", "hit", "finish"]:
		_duck = 0.5
	if kind == "finish":
		# The storm settles beneath the final chord, without overriding mute.
		create_tween().tween_property(_ambience[_active], "volume_db", -10.0, 2.0)

func set_muted(value: bool) -> void:
	_muted = value
	for name in ["Music", "SFX", "Ambience"]:
		var index := AudioServer.get_bus_index(name)
		if index >= 0:
			AudioServer.set_bus_mute(index, value)

func _player(bus_name: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = bus_name
	add_child(player)
	return player

func _bus(bus_name: String, gain_db: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		AudioServer.add_bus()
		index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, "Master")
	AudioServer.set_bus_volume_db(index, gain_db)

func _make_music(index: int) -> AudioStreamWAV:
	var beat := 0.64 if index == 2 else 0.8
	var duration := beat * 16.0
	var buffer := PackedFloat32Array()
	buffer.resize(int(duration * RATE))
	var chords: Array
	var melody: Array
	if index == 0:
		chords = [[55, 62, 67], [52, 59, 64], [48, 55, 62], [50, 57, 62]]
		melody = [74, 0, 71, 69, 67, 0, 64, 67, 69, 0, 74, 71, 69, 67, 62, 0]
	elif index == 1:
		chords = [[52, 59, 66], [48, 55, 62], [55, 62, 69], [50, 57, 64]]
		melody = [71, 0, 74, 76, 74, 0, 71, 69, 67, 0, 69, 71, 66, 0, 62, 0]
	else:
		chords = [[52, 59, 64], [48, 55, 62], [50, 57, 62], [55, 62, 67]]
		melody = [64, 67, 71, 74, 72, 67, 64, 67, 69, 66, 62, 66, 67, 71, 74, 0]
	for bar in 4:
		for note in chords[bar]:
			_mix_note(buffer, bar * beat * 4.0, beat * 4.7, float(note), 0.09, true)
	for step in 16:
		if melody[step] > 0:
			_mix_note(buffer, step * beat, beat * 1.8, float(melody[step]), 0.19 if index < 2 else 0.14, false)
		if index == 2:
			_mix_note(buffer, step * beat, beat * 0.72, float(chords[step / 4][0] - 12), 0.12, false)
	return _wav(buffer, true)

func _mix_note(buffer: PackedFloat32Array, start: float, duration: float, midi: float, gain: float, pad: bool) -> void:
	var begin := int(start * RATE)
	var samples := int(duration * RATE)
	var frequency := 440.0 * pow(2.0, (midi - 69.0) / 12.0)
	for i in samples:
		var t := float(i) / RATE
		var envelope: float
		var value: float
		if pad:
			envelope = minf(t / 0.30, 1.0) * minf((duration - t) / 0.65, 1.0)
			value = sin(TAU * frequency * t) * 0.65 + sin(TAU * frequency * 1.002 * t) * 0.30 + sin(TAU * frequency * 2.0 * t) * 0.05
		else:
			envelope = minf(t / 0.008, 1.0) * exp(-t * 4.0 / duration) * minf((duration - t) / 0.08, 1.0)
			value = sin(TAU * frequency * t) + sin(TAU * frequency * 2.0 * t) * exp(-t * 5.0) * 0.25 + sin(TAU * frequency * 3.0 * t) * 0.06
		# Tails wrap into the beginning so the generated loop has no cut-off notes.
		var offset := (begin + i) % buffer.size()
		buffer[offset] += value * envelope * gain

func _make_air(index: int) -> AudioStreamWAV:
	var duration := 6.0
	var buffer := PackedFloat32Array()
	buffer.resize(int(duration * RATE))
	var noise := RandomNumberGenerator.new()
	noise.seed = 1204 + index
	var low := 0.0
	var previous := 0.0
	for i in buffer.size():
		var t := float(i) / RATE
		var white := noise.randf_range(-1.0, 1.0)
		low = low * 0.97 + white * 0.03
		var breeze := (0.66 + sin(TAU * t / duration) * 0.19 + sin(TAU * t * 3.0 / duration) * 0.15)
		var value := low * breeze * (0.65 + index * 0.35)
		if index == 2:
			value += (white - previous) * 0.045
		previous = white
		buffer[i] = value
	# A short seam crossfade keeps the noise bed loop click-free.
	var seam := 512
	for i in seam:
		var t := float(i) / seam
		buffer[buffer.size() - seam + i] = lerpf(buffer[buffer.size() - seam + i], buffer[i], t)
	return _wav(buffer, true)

func _make_effect(kind: String, duration: float) -> AudioStreamWAV:
	var buffer := PackedFloat32Array()
	buffer.resize(int(duration * RATE))
	var noise := RandomNumberGenerator.new()
	noise.seed = kind.hash()
	var low := 0.0
	for i in buffer.size():
		var t := float(i) / RATE
		var u := t / duration
		var envelope := minf(t / 0.007, 1.0) * pow(1.0 - u, 1.7)
		var white := noise.randf_range(-1.0, 1.0)
		low = low * 0.86 + white * 0.14
		var value := 0.0
		match kind:
			"burst":
				value = low * 1.2 + sin(TAU * (300.0 * t - 200.0 * t * t)) * 0.28
			"gate":
				value = white * exp(-t * 24.0) * 0.7 + low * 0.9 + sin(TAU * 94.0 * t) * exp(-t * 16.0) * 0.25
			"hit":
				value = sin(TAU * (180.0 * t - 210.0 * t * t)) * 0.45 + low * 0.25
			"rescue", "recover", "ring", "finish":
				var notes: Array = [67, 71, 74] if kind != "recover" else [62, 67, 71]
				if kind == "ring":
					notes = [74, 79, 86]
				if kind == "finish":
					notes = [55, 62, 67, 71, 74, 79]
				for n in notes.size():
					var delay := n * (0.07 if kind != "finish" else 0.10)
					if t < delay:
						continue
					var nt := t - delay
					var frequency := 440.0 * pow(2.0, (float(notes[n]) - 69.0) / 12.0)
					var attack := minf(nt / 0.006, 1.0)
					value += (sin(TAU * frequency * nt) + sin(TAU * frequency * 2.0 * nt) * 0.18) * exp(-nt * 3.6) * attack * 0.22
			"ready":
				value = sin(TAU * 880.0 * t) * 0.20 + sin(TAU * 1320.0 * t) * 0.07
		buffer[i] = value * envelope * 0.75
	return _wav(buffer, false)

func _wav(buffer: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(buffer.size() * 2)
	for i in buffer.size():
		bytes.encode_s16(i * 2, int(clampf(buffer[i], -0.92, 0.92) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = bytes
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = buffer.size()
	return stream
