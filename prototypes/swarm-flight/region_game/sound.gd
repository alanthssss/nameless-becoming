extends "res://sound.gd"
## Regional loops, a honey-shop dance, and the flute score for the growth journal.
const SPRING := preload("res://region_game/music/spring_explore.ogg")
const AUTUMN := preload("res://region_game/music/autumn_explore.ogg")
const SHOP_MUSIC := preload("res://region_game/music/honey_counter.ogg")
const JOURNAL_MUSIC := preload("res://region_game/music/growth_journal_dizi.ogg")
const BOOK_DELAY := 0.65

const FOLEY_DURATIONS := {
	"harvest":0.20, "pulse":0.22, "fiber_release":0.19, "resin_open":0.26,
	"fiber":0.15, "resin":0.21, "full":0.30, "denied":0.17,
	"book_open":0.22, "book_close":0.19, "depart_wind":0.38,
	"shop_open":0.17, "shop_close":0.12,
}

var _area := ""
var _overlay := false
var _mode := ""
var _book_tween: Tween
var _flute: AudioStreamPlayer
var _book_position := 0.0

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
	for part in [SPRING, AUTUMN, SHOP_MUSIC]:
		var player := _player("Music")
		player.stream = part
		player.volume_linear = 0.0
		_music.append(player)
	for place in ["pond", "meadow"]:
		var player := _player("Ambience")
		player.stream = _field_air(place)
		_ambience.append(player)
	for player in _ambience:
		player.volume_linear = 0.0
		player.play()
	_flute = _player("Music")
	_flute.stream = JOURNAL_MUSIC
	set_muted(_muted)
	set_honey_context("hub", "title")
	set_process(false)

func _exit_tree() -> void:
	if is_instance_valid(_book_tween):
		_book_tween.kill()
	if is_instance_valid(_flute):
		_flute.stop()
		_flute.stream = null
	super._exit_tree()

func _start_book_music() -> void:
	_flute.volume_db = -2.0
	_flute.play(_book_position)

func _stop_book_music() -> void:
	_book_position = fposmod(_flute.get_playback_position(), JOURNAL_MUSIC.get_length())
	_flute.stop()

func _set_book_open(opened: bool) -> void:
	if is_instance_valid(_book_tween):
		_book_tween.kill()
	if not opened and not _flute.playing: return
	_book_tween = create_tween()
	if not opened:
		_book_tween.tween_property(_flute, "volume_linear", 0.0, 0.18)
		_book_tween.tween_callback(_stop_book_music)
	elif _flute.playing:
		# Reopening during the closing fade keeps the same note.
		_book_tween.tween_property(_flute, "volume_linear", db_to_linear(-2.0), 0.18)
	else:
		_book_tween.tween_interval(BOOK_DELAY)
		_book_tween.tween_callback(_start_book_music)

func set_honey_context(area: String, mode: String) -> void:
	if _music.is_empty() or (_area == area and _mode == mode):
		return
	if (mode == "tree") != (_mode == "tree"):
		_set_book_open(mode == "tree")
	_area = area
	_mode = mode
	_overlay = mode not in ["play", "transition"]
	_mix_region()

func _mix_region() -> void:
	if is_instance_valid(_crossfade):
		_crossfade.kill()
	_crossfade = create_tween().set_parallel(true)
	_crossfade.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var score_gain := 0.53 if _overlay else 1.0
	var air_gain := 0.48 if _overlay else 1.0
	var field := _area in ["pond", "meadow"]
	var home_gain := score_gain if not field and _mode not in ["shop", "tree"] else 0.0
	var gains := [home_gain, score_gain * db_to_linear(-1.1) if field else 0.0, 0.90 if _mode == "shop" else 0.0]
	for i in _music.size():
		var player := _music[i]
		var gain: float = gains[i]
		if gain > 0.0 and not player.playing:
			player.play()
		_crossfade.tween_property(player, "volume_linear", gain, 0.52)
	_crossfade.tween_property(_ambience[0], "volume_linear", air_gain if _area == "pond" else 0.0, 0.65)
	_crossfade.tween_property(_ambience[1], "volume_linear", air_gain if _area == "meadow" else 0.0, 0.65)
	_crossfade.chain().tween_callback(_stop_quiet_loops)

func _stop_quiet_loops() -> void:
	for player in _music:
		# The courtyard keeps its place under the shop and the book.
		if player == _music[0] and _area == "hub": continue
		if is_zero_approx(player.volume_linear):
			player.stop()

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
			"shop_open", "shop_close":
				# A wood drawer slides, then touches the counter.
				var knock := maxf(0.0, t - duration * 0.62)
				var wood := sin(TAU * 275.0 * knock) * exp(-105.0 * knock) * 0.23
				tone = soft * sin(PI * u) * 0.16 + wood * (1.0 if kind == "shop_open" else 0.7)
			"depart_wind":
				tone = (soft * 0.32 + (white - soft) * 0.11) * pow(sin(PI * u), 2.0)
			"book_open":
				tone = (white - soft) * 0.18 * pow(sin(PI * u), 1.5)
			"book_close":
				tone = soft * 0.22 * sin(PI * u) + sin(TAU * 225.0 * t) * 0.19 * exp(-28.0 * t)
		buffer[i] = tone * minf(t / 0.004, 1.0) * minf((duration - t) / 0.025, 1.0)
	return _wav(buffer, false)
