extends "res://sound.gd"
## Honey's courtyard tune: two short taps on one pitch, a lower landing, then air.
## The field answers with fragments over the same bass and twelve-bar form.
const BEAT := 0.625
const BEATS_PER_BAR := 4
# Bass, lower chord tone, upper chord tone.
const HARMONY := [
	[41, 57, 62], [43, 58, 65], [40, 55, 62], [41, 57, 60],
	[46, 57, 62], [45, 55, 60], [43, 53, 58], [48, 58, 64],
	[41, 57, 62], [38, 53, 60], [46, 55, 62], [41, 57, 60],
]
# Notes are [onset in beats, MIDI pitch, duration in beats].
const COURTYARD := [
	[[0.0,69,0.20], [0.38,69,0.20], [1.25,65,1.05]],
	[[0.75,67,0.38], [1.50,70,0.60], [2.75,67,0.55]],
	[[0.0,64,0.20], [0.38,64,0.20], [1.25,62,0.75], [3.0,67,0.36]],
	[[0.25,65,1.35]],
	[[1.50,62,0.36], [2.25,69,0.65]], [[0.50,67,0.75]],
	[[1.25,65,0.40], [2.0,62,0.90]], [],
	[[0.0,69,0.20], [0.38,69,0.20], [1.25,65,0.85], [3.0,67,0.35]],
	[[0.75,69,0.38], [1.50,72,0.55], [2.75,69,0.55]],
	[[0.0,67,0.20], [0.38,67,0.20], [1.25,62,0.75]],
	[[0.25,65,1.35]],
]
const FIELD_ANSWERS := [
	[[0.0,69,0.18], [0.38,69,0.16]], [[1.25,65,0.55]],
	[], [[2.0,60,0.20], [2.38,60,0.18]],
	[[0.75,62,0.42]], [], [[1.50,65,0.35], [2.25,62,0.55]], [],
	[[0.0,69,0.18], [0.38,69,0.16]], [[1.25,65,0.55], [3.0,62,0.25]],
	[], [[0.25,65,0.75]],
]
const FOLEY_DURATIONS := {
	"harvest":0.20, "pulse":0.22, "fiber_release":0.19, "resin_open":0.26,
	"fiber":0.15, "resin":0.21, "full":0.30, "denied":0.17,
	"book_open":0.22, "book_close":0.19,
}

var _area := ""
var _overlay := false

func _ready() -> void:
	_rng.seed = 8753
	_bus("Music", MUSIC_DB)
	_bus("Ambience", AMBIENCE_DB)
	_bus("SFX", SFX_DB)
	for i in 8:
		_voices.append(_player("SFX"))
	for kind in FOLEY_DURATIONS:
		_samples[kind] = _garden_foley(kind, FOLEY_DURATIONS[kind])
	for item in [["dash","burst",0.30], ["tap","spray",0.19], ["hurt","hit",0.20],
			["sell","arrival_bell",0.70], ["buy","ring",0.55], ["recover","recover",0.75],
			["complete","finish",1.5]]:
		_samples[item[0]] = _make_effect(item[1], item[2])
	_samples["unlock"] = _samples["buy"]
	for item in [["burst","dash"], ["spray","tap"], ["dew","harvest"], ["hit","hurt"],
			["arrival_bell","sell"], ["ring","buy"], ["finish","complete"]]:
		_samples[item[0]] = _samples[item[1]]
	for part in _garden_score():
		var player := _player("Music")
		player.stream = part
		_music.append(player)
	for place in ["pond", "meadow"]:
		var player := _player("Ambience")
		player.stream = _field_air(place)
		_ambience.append(player)
	for player in _music + _ambience:
		player.volume_linear = 0.0
		player.play()
	set_muted(_muted)
	set_honey_context("hub", "title")
	# The inherited weather controller drives the earlier flight game.
	# Honey's continuous stems are mixed only when its place or overlay changes.
	set_process(false)

func set_honey_context(area: String, mode: String) -> void:
	var overlay := mode not in ["play", "transition"]
	if _music.is_empty() or (_area == area and _overlay == overlay):
		return
	var first_mix := _area.is_empty()
	_area = area
	_overlay = overlay
	var field := area in ["pond", "meadow"]
	var score_gain := 0.53 if overlay else 1.0
	var air_gain := 0.48 if overlay else 1.0
	if first_mix:
		_music[0].volume_linear = score_gain
		_music[1].volume_linear = score_gain if not field else 0.0
		_music[2].volume_linear = score_gain if field else 0.0
		_ambience[0].volume_linear = air_gain if area == "pond" else 0.0
		_ambience[1].volume_linear = air_gain if area == "meadow" else 0.0
		return
	if is_instance_valid(_crossfade):
		_crossfade.kill()
	_crossfade = create_tween().set_parallel(true)
	_crossfade.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_crossfade.tween_property(_music[0], "volume_linear", score_gain, 0.48)
	_crossfade.tween_property(_music[1], "volume_linear", 0.0 if field else score_gain, 0.8)
	_crossfade.tween_property(_music[2], "volume_linear", score_gain if field else 0.0, 0.8)
	_crossfade.tween_property(_ambience[0], "volume_linear", air_gain if area == "pond" else 0.0, 0.65)
	_crossfade.tween_property(_ambience[1], "volume_linear", air_gain if area == "meadow" else 0.0, 0.65)

func _garden_score() -> Array[AudioStreamWAV]:
	var backing := PackedFloat32Array()
	var home := PackedFloat32Array()
	var field := PackedFloat32Array()
	backing.resize(roundi(HARMONY.size() * BEATS_PER_BAR * BEAT * RATE))
	home.resize(backing.size())
	field.resize(backing.size())
	for bar in HARMONY.size():
		var start := bar * BEATS_PER_BAR * BEAT
		var chord: Array = HARMONY[bar]
		# Leave the opening taps, and their return in bar nine, unaccompanied.
		var bass_beat := 1.25 if bar in [0, 8] else 0.0
		_mix_instrument(backing, start + bass_beat * BEAT, 1.20 * BEAT, chord[0], 0.135, "bass")
		_mix_instrument(backing, start + 2.5 * BEAT, 0.54 * BEAT, chord[1], 0.062, "pluck")
		_mix_instrument(backing, start + 2.54 * BEAT, 0.68 * BEAT, chord[2], 0.046, "keys")
		for note in COURTYARD[bar]:
			var voice := "mallet" if note[2] <= 0.40 else "keys"
			_mix_instrument(home, start + note[0] * BEAT, note[2] * BEAT, note[1], 0.22, voice)
		for note in FIELD_ANSWERS[bar]:
			_mix_instrument(field, start + note[0] * BEAT, note[2] * BEAT, note[1], 0.19, "pluck")
		if bar % 4 in [0, 2]:
			_mix_drum(field, start + 1.75 * BEAT, 0.065, 0.050, "wood", bar)
	return [_wav(backing, true), _wav(home, true), _wav(field, true)]

func _field_air(place: String) -> AudioStreamWAV:
	var duration := 7.5
	var buffer := PackedFloat32Array()
	buffer.resize(roundi(duration * RATE))
	var noise := RandomNumberGenerator.new()
	noise.seed = place.hash()
	var soft := 0.0
	var dark := 0.0
	for i in buffer.size():
		var t := float(i) / RATE
		var white := noise.randf_range(-1.0, 1.0)
		soft = lerpf(soft, white, 0.22)
		dark = lerpf(dark, soft, 0.033)
		var swell := 0.5 + 0.5 * sin(TAU * t / duration)
		if place == "pond":
			# A continuous little current with three unequal eddies per loop.
			var eddy := fposmod(t, 2.5)
			var bubble := sin(TAU * (420.0 * eddy + 340.0 * eddy * eddy)) * exp(-18.0 * eddy)
			buffer[i] = dark * (1.15 + 0.40 * swell) + soft * 0.26 + bubble * 0.12 * swell
		else:
			var gust := pow(swell, 3.0) + 0.45 * pow(0.5 + 0.5 * sin(TAU * 3.0 * t / duration), 5.0)
			buffer[i] = dark * 0.52 + (soft - dark) * (0.08 + 0.65 * gust)
		var edge := mini(i, buffer.size() - 1 - i)
		buffer[i] *= minf(1.0, float(edge) / 180.0)
	return _wav(buffer, true)

func _garden_foley(kind: String, duration: float) -> AudioStreamWAV:
	var buffer := PackedFloat32Array()
	buffer.resize(roundi(RATE * duration))
	var noise := RandomNumberGenerator.new()
	noise.seed = kind.hash()
	var soft := 0.0
	for i in buffer.size():
		var t := float(i) / RATE
		var u := t / duration
		var white := noise.randf_range(-1.0, 1.0)
		soft = lerpf(soft, white, 0.23)
		var tone := 0.0
		match kind:
			"harvest": # Rounded drop with a brief rising attack.
				tone = sin(TAU * (850.0 * t - 10.0 * (1.0 - exp(-36.0 * t)))) * exp(-18.0 * t) * 0.30
			"pulse":
				tone = (soft * 0.75 + sin(TAU * (145.0 * t + 240.0 * t*t)) * 0.16) * sin(PI * u)
			"fiber_release":
				tone = (white - soft) * 0.30 * (0.6 + 0.4 * cos(TAU * 23 * t)) * exp(-12.0 * t)
			"fiber":
				tone = (soft * 0.25 + sin(TAU * 485.0 * t) * 0.24) * exp(-29.0 * t)
			"resin_open":
				tone = soft * 0.62 * (0.65 + 0.35 * sin(TAU * (22.0 * t + 35.0 * t*t))) * sin(PI * u)
			"resin":
				tone = sin(TAU * (320.0 * t - 240.0 * t*t)) * 0.31 * exp(-20.0 * t) + soft * 0.13
			"full": # A soft cork seats in the bag.
				tone = (sin(TAU * 294.0 * t) * 0.29 + sin(TAU * 440.0 * t) * 0.11) * exp(-15.0 * t)
			"denied":
				tone = (sin(TAU * 170.0 * t) * 0.22 + soft * 0.16) * exp(-27.0 * t)
			"book_open":
				tone = (white - soft) * 0.18 * pow(sin(PI * u), 1.5)
			"book_close":
				tone = soft * 0.22 * sin(PI * u) + sin(TAU * 225.0 * t) * 0.19 * exp(-28.0 * t)
		buffer[i] = tone * minf(t / 0.004, 1.0) * minf((duration - t) / 0.025, 1.0)
	return _wav(buffer, false)
