extends SceneTree
## Reproducible signal checks, not a substitute for listening or player review.
const Sound = preload("res://sound.gd")
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var sound := Sound.new()
	# Measure the actual generator without starting playback in a headless driver.
	for bus in [["Music",Sound.MUSIC_DB],["SFX",Sound.SFX_DB],["Ambience",Sound.AMBIENCE_DB]]:
		sound._bus(bus[0],bus[1])
	sound.set_muted(true)
	var destination := OS.get_environment("SWARM_AUDIO_DIR")
	if destination.is_empty(): destination = OS.get_cache_dir().path_join("before-the-rain-audio-qa")
	DirAccess.make_dir_recursive_absolute(destination)
	var report := {"sample_rate":Sound.RATE,"evidence":"Deterministic PCM measurement; no human listening acceptance", "music":[],"sfx":[],"passed":true}
	for i in 3:
		var track: AudioStreamWAV = sound._make_music(i)
		var metrics := inspect(track)
		metrics["stage"] = i+1
		metrics["beats"] = 32
		metrics["file"] = "garden-act-%d.wav"%(i+1)
		var result := track.save_to_wav(destination.path_join(metrics.file))
		metrics["saved"] = result == OK
		metrics["passed"] = metrics.peak > 0.1 and metrics.peak < 0.9 and metrics.rms > 0.03 and metrics.seam_delta < 0.02 and metrics.duration > 14.0 and result == OK
		report.music.append(metrics)
		report.passed = report.passed and metrics.passed
	for kind in ["dew","spray","flower_calm"]:
		var length: float = {"dew":0.35,"spray":0.28,"flower_calm":0.6}[kind]
		var metrics := inspect(sound._make_effect(kind,length))
		metrics["event"] = kind
		metrics["passed"] = metrics.peak > 0.03 and metrics.peak < 0.9
		report.sfx.append(metrics)
		report.passed = report.passed and metrics.passed
	# Bus separation, mute and ducking keep the user preference authoritative.
	# Exercise the duck envelope separately; runtime event routing belongs to UI QA.
	sound._duck = 0.5
	sound._process(0.01)
	report["duck_db"] = AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))
	report["mute_survives_duck"] = AudioServer.is_bus_mute(AudioServer.get_bus_index("Music"))
	report.passed = report.passed and report.mute_survives_duck and report.duck_db < Sound.MUSIC_DB
	var file := FileAccess.open(destination.path_join("signal-report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  ")+"\n")
	file.close()
	print("GARDEN_AUDIO: ",JSON.stringify(report))
	sound.free()
	await process_frame
	quit(0 if report.passed else 1)
func inspect(stream: AudioStreamWAV) -> Dictionary:
	var pcm := stream.data
	var count := pcm.size()/2
	var peak := 0.0
	var energy := 0.0
	var step := 0.0
	var previous := 0.0
	for i in count:
		var value := pcm.decode_s16(i*2)/32768.0
		peak = maxf(peak,absf(value))
		energy += value*value
		if i>0: step = maxf(step,absf(value-previous))
		previous = value
	return {"duration":float(count)/stream.mix_rate,"peak":peak,"peak_dbfs":linear_to_db(peak),"rms":sqrt(energy/count),"rms_dbfs":linear_to_db(sqrt(energy/count)),"maximum_sample_delta":step,"seam_delta":absf(pcm.decode_s16(0)-pcm.decode_s16(pcm.size()-2))/32768.0}
