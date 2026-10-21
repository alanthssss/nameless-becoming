extends Node
## Original composed PCM: no external samples, recordings or transcriptions.
## Three authored arrangements crossfade; one-shots use a fixed voice pool.
const RATE := 22050
const MUSIC_DB := -9.0
const AMBIENCE_DB := -24.0
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
	_samples["dew"] = _make_effect("dew",0.35)
	_samples["spray"] = _make_effect("spray",0.28)
	_samples["flower_calm"] = _make_effect("flower_calm",0.6)
	_samples["burst"] = _make_effect("burst", 0.30)
	_samples["rescue"] = _make_effect("rescue", 0.65)
	_samples["ring"] = _make_effect("ring", 0.55)
	_samples["gate"] = _make_effect("gate", 0.25)
	_samples["hit"] = _make_effect("hit", 0.20)
	_samples["recover"] = _make_effect("recover", 0.75)
	_samples["finish"] = _make_effect("finish", 1.50)
	_samples["ready"] = _make_effect("ready", 0.18)
	_samples["charge_cancel"] = _make_effect("charge_cancel",0.14)
	_samples["blocked"] = _make_effect("blocked",0.15)
	_samples["shield"] = _make_effect("shield",0.48)
	_samples["shield_block"] = _make_effect("shield_block",0.16)
	_samples["shield_end"] = _make_effect("shield_end",0.28)
	_samples["rain_break"] = _samples["gate"]
	_samples["tired"] = _samples["charge_cancel"]
	for kind in ["checkpoint","recover_manual","recover_rain","recover_exhaustion","recover_timeout"]:
		_samples[kind] = _samples["recover"]
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
	if kind == "shield": player.volume_db = -2.0
	elif kind == "shield_block": player.volume_db = -7.0
	elif kind == "shield_end": player.volume_db = -5.0
	player.play()
	if kind in ["rescue", "hit", "finish", "flower_calm"]:
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
	# Eight bars / 32 beats: two distinct 4-bar phrases, composed for this game.
	# Timing, harmony and melodies are authored here; no samples or transcriptions.
	var beat: float = [0.52,0.49,0.46][index]
	var buffer := PackedFloat32Array()
	buffer.resize(int(beat*32.0*RATE))
	var chords: Array = [[48,55,60,64],[45,52,60,64],[53,57,60,65],[43,50,59,62],[48,55,60,67],[52,55,59,64],[50,57,60,65],[43,53,59,62]]
	var melody: Array = [72,0,76,79,0,76,74,72, 69,72,0,76,0,74,72,0, 77,0,76,74,72,0,69,72, 71,74,0,79,77,74,0,0, 76,79,81,0,79,76,72,0, 71,0,74,76,79,0,76,74, 77,76,74,0,72,69,0,74, 71,0,69,67,0,74,72,0]
	if index == 1:
		chords = [[50,57,62,66],[47,54,62,66],[55,59,62,67],[45,52,61,64],[50,57,62,69],[54,57,61,66],[52,59,62,67],[45,55,61,64]]
		melody = [78,0,81,78,76,0,74,0, 73,76,78,0,81,78,76,0, 79,0,78,76,74,0,71,74, 73,76,0,81,0,79,76,0, 81,83,81,0,78,76,74,0, 73,0,76,78,81,0,85,81, 79,78,76,0,74,71,76,0, 73,76,0,69,0,73,74,0]
	elif index == 2:
		chords = [[45,52,57,60],[53,60,65,69],[50,57,62,65],[52,59,64,68],[45,52,60,64],[48,55,60,64],[50,57,62,65],[52,59,64,68]]
		melody = [69,0,72,76,0,74,72,69, 77,0,76,72,69,0,72,0, 74,77,0,76,74,0,72,69, 68,71,74,0,76,0,71,0, 76,79,76,0,72,74,76,0, 79,0,76,72,0,71,72,76, 77,76,74,0,72,74,77,0, 76,74,71,0,68,71,69,0]
	for bar in 8:
		var chord: Array = chords[bar]
		var base := bar*4.0
		# Alternating roots/fifths plus a delayed pickup make the bass gently bounce.
		for pair in [[0.0,0],[1.5,1],[2.0,0],[3.5,1]]:
			_mix_instrument(buffer,(base+pair[0])*beat,beat*0.65,float(chord[pair[1]]-12),0.20,"bass")
		# Short off-beat chord stabs leave breathing room for the lead.
		for at in [0.75,2.75]:
			for note in chord.slice(1):
				_mix_instrument(buffer,(base+at)*beat,beat*0.7,float(note),0.055,"pluck")
		for at in [0.0,2.0]: _mix_drum(buffer,(base+at)*beat,0.17,0.11,"kick",index*100+bar)
		for at in [1.0,3.0]: _mix_drum(buffer,(base+at)*beat,0.10,0.055,"wood",index*100+bar+30)
		for at in [0.5,1.5,2.5,3.5]: _mix_drum(buffer,(base+at)*beat,0.055,0.025,"hat",index*100+bar+60)
		if index == 2:
			for at in [1.75,3.75]: _mix_drum(buffer,(base+at)*beat,0.06,0.025,"wood",bar+300)
	for step in 64:
		var note: int = melody[step]
		if note <= 0: continue
		# A small swing delay on off-eighths; every downbeat stays exact.
		var at := (step*0.5+(0.055 if step%2 else 0.0))*beat
		var voice := "keys" if index==0 else ("mallet" if index==1 else "pluck")
		_mix_instrument(buffer,at,beat*(0.78 if step%4 else 1.15),float(note),0.15,voice)
		if index == 1 and step%4 == 2:
			_mix_instrument(buffer,at+beat*0.25,beat*0.9,float(note-12),0.035,"keys")
	# Fixed gain, not per-run normalization. Keep measurable headroom for SFX.
	for i in buffer.size(): buffer[i] *= 1.45
	return _wav(buffer,true)

func _mix_instrument(buffer: PackedFloat32Array, start: float, duration: float, midi: float, gain: float, voice: String) -> void:
	var begin := int(start*RATE)
	var frequency := 440.0*pow(2.0,(midi-69.0)/12.0)
	for i in int(duration*RATE):
		var t := float(i)/RATE
		var phase := TAU*frequency*t
		var attack := minf(t/0.004,1.0)
		var release := clampf((duration-t)/0.045,0.0,1.0)
		var value := 0.0
		match voice:
			"bass":
				value = (sin(phase)*0.8+sin(phase*2)*0.16+sin(phase*3)*0.04)*exp(-t*4.5)
			"mallet":
				value = sin(phase)*exp(-t*6)+sin(phase*3.99)*exp(-t*22)*0.32+sin(phase*9.96)*exp(-t*42)*0.09
			"pluck":
				value = (sin(phase)+sin(phase*2)*0.38+sin(phase*3)*0.15+sin(phase*4)*0.07)*exp(-t*8)
			"keys":
				value = sin(phase)*exp(-t*5)+sin(phase*2)*exp(-t*10)*0.28+sin(phase*3.001)*exp(-t*17)*0.10
		buffer[(begin+i)%buffer.size()] += value*attack*release*gain

func _mix_drum(buffer: PackedFloat32Array, start: float, duration: float, gain: float, kind: String, seed_value: int) -> void:
	var noise := RandomNumberGenerator.new()
	noise.seed = seed_value+5719
	var begin := int(start*RATE)
	var low := 0.0
	for i in int(duration*RATE):
		var t := float(i)/RATE
		var white := noise.randf_range(-1,1)
		low = low*0.82+white*0.18
		var value := 0.0
		match kind:
			"kick": value = sin(TAU*(65*t+3*(1-exp(-t*30))))*exp(-t*28)
			"wood": value = (sin(TAU*790*t)*0.7+sin(TAU*1230*t)*0.3+low*0.2)*exp(-t*65)
			"hat": value = (white-low)*exp(-t*80)
		buffer[(begin+i)%buffer.size()] += value*minf(t/0.002,1.0)*gain

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
			"dew":
				value = (sin(TAU*1174.66*t)+sin(TAU*1760*t)*0.35)*exp(-t*8)*0.23
			"spray":
				value = low*0.85*exp(-t*9)+sin(TAU*(220*t-200*t*t))*exp(-t*15)*0.15
			"flower_calm":
				value = (sin(TAU*523.25*t)+sin(TAU*659.25*t)*0.65+sin(TAU*783.99*t)*0.4)*exp(-t*5)*0.2
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
			"charge_cancel":
				value = sin(TAU*(540.0*t-1000.0*t*t))*0.16
			"blocked":
				value = sin(TAU*110.0*t)*exp(-t*24.0)*0.3+low*0.16
			"ready":
				value = sin(TAU * 880.0 * t) * 0.20 + sin(TAU * 1320.0 * t) * 0.07
			"shield":
				# A soft opening interval, separate from the brighter dew/relay chimes.
				value = sin(TAU*659.25*t)*exp(-t*5.0)*0.22
				if t > 0.09:
					var nt := t-0.09
					value += sin(TAU*987.77*nt)*minf(nt/0.008,1.0)*exp(-nt*6.0)*0.16
			"shield_block":
				# A cushioned water tap: no low impact thump and no music ducking.
				value = sin(TAU*(970.0*t-350.0*t*t))*exp(-t*24.0)*0.22+low*exp(-t*35.0)*0.08
			"shield_end":
				value = sin(TAU*(740.0*t-360.0*t*t))*exp(-t*11.0)*0.14+low*exp(-t*16.0)*0.10
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
