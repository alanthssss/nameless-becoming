extends SceneTree
## 《花间慢行》 — editable offline score for a solo dizi. Run from the Godot project:
## godot --headless --script res://region_game/growth_dizi.gd -- --wav=/absolute/path/take.wav
## Encode the WAV as Vorbis quality 6 for music/growth_journal_dizi.ogg.
const RATE := 22050
const BEAT := 60.0 / 92.0
const REST := 0
const TIE := -1
const A4 := 69
const B4 := 71
const D5 := 74
const E5 := 76
const FS5 := 78
const G5 := 79
const A5 := 81
const B5 := 83

# One row per bar in 3/4: [sounding pitch, beats, optional breath strength].
# A rest makes room to inhale. A tie carries the previous note over a bar line.
const BARS := [
	# 1–4. The original call, including its short upper grace note.
	[[A4, .5, .74], [D5, 1.5, .88], [E5, 1, .86]],
	[[A5, 1.5, .94], [FS5, .5, .73], [REST, 1]],
	[[FS5, .075, .66], [E5, .925, .85], [D5, .5, .78], [B4, .5, .71], [A4, 1, .69]],
	[[D5, 3, .83]],
	# 5–12. A reply starts in the space after the downbeat, then settles lower.
	[[REST, .5], [FS5, .5, .69], [E5, .5, .78], [FS5, .5, .78], [A5, 1, .86]],
	[[TIE, .5], [G5, .5, .72], [E5, 1.5, .80], [REST, .5]],
	[[D5, 1.5, .81], [B4, 1, .73], [A4, .5, .66]],
	[[B4, 2, .76], [REST, 1]],
	[[E5, 1, .82], [FS5, .5, .75], [A5, .5, .81], [FS5, 1, .82]],
	[[E5, 2, .78], [D5, .75, .74], [B4, .25, .62]],
	[[A4, 1, .77], [D5, .5, .71], [B4, 1.5, .75]],
	[[A4, 2.25, .73], [REST, .75]],
	# 13–24. Lower register; notes lean over the bar lines like one long breath.
	[[A4, 1.5, .73], [B4, .5, .68], [D5, 1, .79]],
	[[TIE, 1], [B4, .5, .72], [A4, 1, .74], [REST, .5]],
	[[B4, 1.5, .79], [E5, 1.5, .80]],
	[[TIE, .75], [D5, .75, .70], [B4, 1, .75], [REST, .5]],
	[[REST, .5], [D5, .5, .69], [E5, 1, .77], [G5, 1, .81]],
	[[FS5, 2, .80], [D5, 1, .76]],
	[[E5, .75, .75], [D5, .25, .63], [B4, .75, .70], [A4, 1.25, .73]],
	[[TIE, 1.5], [REST, 1.5]],
	[[B4, .5, .65], [D5, 1.5, .76], [FS5, 1, .81]],
	[[E5, 1.5, .80], [G5, .5, .74], [FS5, .5, .78], [E5, .5, .72]],
	[[D5, .75, .75], [A4, .75, .70], [B4, 1.5, .76]],
	[[D5, 2.5, .82], [REST, .5]],
	# 25–36. The longest rise. Only one brief crest reaches B5.
	[[REST, .5], [E5, .5, .74], [FS5, .75, .80], [G5, .25, .65], [A5, 1, .85]],
	[[TIE, 1], [FS5, .5, .74], [E5, .5, .73], [G5, 1, .82]],
	[[FS5, .75, .81], [A5, .75, .84], [B5, 1.5, .86]],
	[[A5, 2, .83], [REST, 1]],
	[[FS5, .5, .72], [G5, 1.5, .79], [E5, 1, .76]],
	[[A5, 1, .85], [G5, .75, .80], [FS5, .75, .78], [E5, .5, .70]],
	[[D5, 1, .74], [B4, .5, .68], [D5, 1.5, .79]],
	[[E5, 2.25, .80], [REST, .75]],
	[[A4, .5, .69], [B4, .5, .72], [E5, 1.5, .79], [FS5, .5, .76]],
	[[G5, 1.5, .82], [E5, 1.5, .78]],
	[[TIE, .5], [FS5, .5, .74], [D5, 1.5, .77], [B4, .5, .68]],
	[[A4, 2.25, .76], [REST, .75]],
	# 37–44. The opening leap returns as an upbeat, with a different answer.
	[[REST, 1], [A4, .5, .65], [D5, .5, .75], [FS5, 1, .80]],
	[[E5, 1, .77], [B4, .5, .68], [D5, 1.5, .79]],
	[[TIE, .5], [FS5, .5, .72], [E5, .75, .75], [D5, .25, .65], [B4, 1, .73]],
	[[A4, 2, .70], [REST, 1]],
	[[D5, .75, .78], [E5, .25, .68], [FS5, 1.5, .81], [A5, .5, .78]],
	[[G5, .75, .77], [FS5, .75, .76], [E5, 1.5, .80]],
	[[D5, .5, .73], [A4, 1, .69], [B4, 1.5, .74]],
	[[TIE, .75], [D5, 1.5, .77], [REST, .75]],
	# 45–48. Widen the phrases; the last low breath prepares the opening pickup.
	[[FS5, 1.5, .76], [E5, .5, .68], [D5, 1, .74]],
	[[TIE, .5], [B4, 1.5, .73], [REST, 1]],
	[[A4, 1, .66], [B4, .5, .65], [E5, .5, .71], [D5, 1, .76]],
	[[TIE, 2.4], [REST, .6]],
]

func _initialize() -> void:
	var path := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--wav="): path = arg.trim_prefix("--wav=")
	if not path.is_absolute_path() or not path.ends_with(".wav"):
		printerr("Pass -- --wav=/absolute/path/take.wav")
		quit(1)
		return
	var stream := render_score()
	if stream == null:
		quit(1)
		return
	var err := stream.save_to_wav(path)
	if err != OK:
		printerr("Could not write ", path, ": ", error_string(err))
		quit(1)
		return
	print("Growth journal: %d bars, %.6f s, written to %s" % [BARS.size(), stream.get_length(), path])
	quit()

static func render_score() -> AudioStreamWAV:
	var notes: Array[Array] = []
	for bar in BARS.size():
		var beat := 0.0
		for mark in BARS[bar]:
			var onset := bar * 3.0 + beat
			var duration := float(mark[1])
			if mark[0] == TIE:
				if notes.is_empty() or not is_equal_approx(notes[-1][0] + notes[-1][2], onset):
					push_error("Tie without a preceding sound in bar %d" % (bar + 1))
					return null
				notes[-1][2] += duration
			elif mark[0] != REST:
				notes.append([onset, mark[0], duration, mark[2]])
			beat += duration
		if not is_equal_approx(beat, 3.0):
			push_error("Incomplete bar %d" % (bar + 1))
			return null

	var noise := RandomNumberGenerator.new()
	noise.seed = 5112026
	var dry := PackedFloat32Array()
	dry.resize(roundi(BARS.size() * 3.0 * BEAT * RATE))
	for note in notes:
		_render_note(dry, note, noise)

	var pcm := PackedByteArray()
	pcm.resize(dry.size() * 2)
	var near_reflection := roundi(0.093 * RATE)
	var far_reflection := roundi(0.181 * RATE)
	for i in dry.size():
		var sample := dry[i]
		if i >= near_reflection:
			sample += dry[i - near_reflection] * 0.090
		if i >= far_reflection:
			sample += dry[i - far_reflection] * 0.042
		pcm.encode_s16(i * 2, roundi(clampf(sample, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.mix_rate = RATE
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.data = pcm
	return stream

static func _render_note(dry: PackedFloat32Array, note: Array, noise: RandomNumberGenerator) -> void:
	var start := roundi(float(note[0]) * BEAT * RATE)
	var duration := float(note[2]) * BEAT
	var frequency := 440.0 * pow(2.0, (float(note[1]) - 69.0) / 12.0)
	var strength := float(note[3])
	var attack := minf(0.047, duration * 0.18)
	var release := minf(0.14, duration * 0.25)
	if note[0] == 9.0:
		release = 0.38
	elif note[0] >= 12.0:
		# Slightly softer tongue for flowing eighth notes; let sustained notes taper.
		attack = minf(0.040, duration * 0.16)
		release = minf(0.32 if duration > 1.25 else 0.075, duration * 0.22)
	var phase := 0.0
	var air_fast := 0.0
	var air_slow := 0.0
	for i in roundi(duration * RATE):
		var t := float(i) / RATE
		var envelope := smoothstep(0.0, attack, t) * smoothstep(0.0, release, duration - t)
		var breath := strength * (0.84 + 0.16 * sin(PI * t / duration))
		var vibrato := 0.0045 * smoothstep(0.26, 0.72, t) * sin(TAU * (4.5 * t + 0.18 * t * t))
		phase += TAU * frequency * (1.0 + vibrato) / RATE
		air_fast = lerpf(air_fast, noise.randf_range(-1.0, 1.0), 0.65)
		air_slow = lerpf(air_slow, air_fast, 0.15)
		var air := (air_fast - air_slow) * (0.10 + 0.19 * exp(-t * 30.0))
		var bore := sin(phase) + 0.16 * sin(2.0 * phase) + 0.21 * sin(3.0 * phase)
		var membrane := 0.10 * sin(4.0 * phase + 0.4) + 0.07 * sin(6.0 * phase)
		dry[start + i] = 0.32 * envelope * breath * (bore + breath * membrane + air)
