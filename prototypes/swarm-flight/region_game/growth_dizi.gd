extends RefCounted
## Original solo for the growth journal. Scale degree 1 is D5, in 3/4.
const RATE := 22050
const BEAT := 60.0 / 92.0
# [onset in beats, MIDI pitch, length in beats, breath strength]
const NOTES := [
	[0.0, 69, 0.5, 0.74], [0.5, 74, 1.5, 0.88], [2.0, 76, 1.0, 0.86],
	[3.0, 81, 1.5, 0.94], [4.5, 78, 0.5, 0.73], # Beat six is a breath.
	[6.0, 78, 0.075, 0.66], [6.075, 76, 0.925, 0.85], # Upper grace into 2.
	[7.0, 74, 0.5, 0.78], [7.5, 71, 0.5, 0.71], [8.0, 69, 1.0, 0.69],
	[9.0, 74, 3.0, 0.83],
]

static func make_phrase() -> AudioStreamWAV:
	var noise := RandomNumberGenerator.new()
	noise.seed = 5112026
	var dry := PackedFloat32Array()
	dry.resize(ceili((12.0 * BEAT + 0.24) * RATE))
	for note in NOTES:
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
	# Keep the final note's room tail and a short breath before the next pickup.
	stream.loop_begin = 0
	stream.loop_end = dry.size()
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	return stream

static func _render_note(dry: PackedFloat32Array, note: Array, noise: RandomNumberGenerator) -> void:
	var start := roundi(float(note[0]) * BEAT * RATE)
	var duration := float(note[2]) * BEAT
	var frequency := 440.0 * pow(2.0, (float(note[1]) - 69.0) / 12.0)
	var strength := float(note[3])
	var attack := minf(0.047, duration * 0.18)
	var release := minf(0.14, duration * 0.25)
	if note[0] == 9.0:
		release = 0.38 # Let the held tonic run out of air.
	var phase := 0.0
	var air_fast := 0.0
	var air_slow := 0.0
	for i in roundi(duration * RATE):
		var t := float(i) / RATE
		var envelope := smoothstep(0.0, attack, t) * smoothstep(0.0, release, duration - t)
		var breath := strength * (0.84 + 0.16 * sin(PI * t / duration))
		# Vibrato only blooms on held notes, with less than ten cents of excursion.
		var vibrato := 0.0045 * smoothstep(0.26, 0.72, t) * sin(TAU * (4.5 * t + 0.18 * t * t))
		phase += TAU * frequency * (1.0 + vibrato) / RATE
		air_fast = lerpf(air_fast, noise.randf_range(-1.0, 1.0), 0.65)
		air_slow = lerpf(air_slow, air_fast, 0.15)
		var air := (air_fast - air_slow) * (0.10 + 0.19 * exp(-t * 30.0))
		var bore := sin(phase) + 0.16 * sin(2.0 * phase) + 0.21 * sin(3.0 * phase)
		var membrane := 0.10 * sin(4.0 * phase + 0.4) + 0.07 * sin(6.0 * phase)
		dry[start + i] = 0.32 * envelope * breath * (bore + breath * membrane + air)
