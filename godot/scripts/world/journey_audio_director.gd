class_name JourneyAudioDirector
extends Node

## Journey owns a separate audio router so the commercial world scenes can move
## between the eight authored seasonal masters without coupling to the legacy
## Main scene. The two environment layers use project-owned deterministic
## commercial candidates and remain replaceable through the public stream inputs.

signal route_changed(area_id: StringName, route_id: StringName, track_path: String)
signal playback_gate_changed(audible: bool)
signal environment_mix_changed(hive_indoor_db: float, field_outdoor_db: float)

const MUSIC_FAMILIES: Array[String] = ["spring", "summer", "autumn", "winter"]
const SILENCE_DB := -60.0
const DEFAULT_TRANSITION_SECONDS := 0.65

const LAYER_HIVE_INDOOR: StringName = &"hive_indoor"
const LAYER_FIELD_OUTDOOR: StringName = &"field_outdoor"
const ENVIRONMENT_LAYERS: Array[StringName] = [LAYER_HIVE_INDOOR, LAYER_FIELD_OUTDOOR]
const DEFAULT_ENVIRONMENT_PATHS := {
	LAYER_HIVE_INDOOR: "res://assets/audio/commercial/hive_room_loop.wav",
	LAYER_FIELD_OUTDOOR: "res://assets/audio/commercial/field_day_loop.wav",
}

## Every planned commercial chapter has an explicit musical destination. The
## current spring scene ids are exact; aliases below reserve stable destinations
## for the seasonal scenes while those PackedScenes are authored.
const ROUTES := {
	"spring_field": {
		"family": 0, "mode": "explore", "music_db": -13.0,
		"hive_indoor_db": -42.0, "field_outdoor_db": -17.0,
	},
	"spring_sign_incident": {
		"family": 0, "mode": "incident", "music_db": -11.5,
		"hive_indoor_db": -44.0, "field_outdoor_db": -14.0,
	},
	"summer_field": {
		"family": 1, "mode": "explore", "music_db": -13.0,
		"hive_indoor_db": -42.0, "field_outdoor_db": -16.0,
	},
	"summer_rest_hive_repair": {
		"family": 1, "mode": "incident", "music_db": -11.5,
		"hive_indoor_db": -40.0, "field_outdoor_db": -14.5,
	},
	"autumn_field": {
		"family": 2, "mode": "explore", "music_db": -13.0,
		"hive_indoor_db": -42.0, "field_outdoor_db": -17.5,
	},
	"autumn_echo_incident": {
		"family": 2, "mode": "incident", "music_db": -11.5,
		"hive_indoor_db": -44.0, "field_outdoor_db": -15.0,
	},
	"winter_field": {
		"family": 3, "mode": "explore", "music_db": -13.0,
		"hive_indoor_db": -39.0, "field_outdoor_db": -18.0,
	},
	"winter_windbreak": {
		"family": 3, "mode": "incident", "music_db": -11.5,
		"hive_indoor_db": -41.0, "field_outdoor_db": -15.5,
	},
	"ending": {
		# The new bee demonstration closes the year by returning to spring's
		# neighbourhood motif at a quieter, non-triumphal level.
		"family": 0, "mode": "explore", "music_db": -17.0,
		"hive_indoor_db": -19.0, "field_outdoor_db": -27.0,
	},
}

const ROUTE_ALIASES := {
	"spring_prologue": "spring_field",
	"spring_term_field": "spring_field",
	"spring_climax": "spring_sign_incident",
	"spring_route": "spring_field",
	"spring_incident": "spring_sign_incident",
	"sign_incident": "spring_sign_incident",
	"summer_term_field": "summer_field",
	"summer_climax": "summer_rest_hive_repair",
	"summer_route": "summer_field",
	"summer_recovery": "summer_field",
	"summer_incident": "summer_rest_hive_repair",
	"summer_repair_incident": "summer_rest_hive_repair",
	"autumn_term_field": "autumn_field",
	"autumn_climax": "autumn_echo_incident",
	"autumn_route": "autumn_field",
	"autumn_harvest": "autumn_field",
	"autumn_incident": "autumn_echo_incident",
	"autumn_thrush_incident": "autumn_echo_incident",
	"winter_term_field": "winter_field",
	"winter_climax": "winter_windbreak",
	"winter_route": "winter_field",
	"winter_warmth": "winter_field",
	"winter_incident": "winter_windbreak",
	"winter_bear_incident": "winter_windbreak",
	"finale": "ending",
	"finale_handoff": "ending",
}

var transition_seconds := DEFAULT_TRANSITION_SECONDS
var enabled := true
var focus_active := true
var manually_paused := false

var current_area_id: StringName = &""
var current_route_id: StringName = &""
var current_family := 0
var current_mode: StringName = &"hive"
var last_world_family := 0
var _current_track_path := ""

var music_players: Array[AudioStreamPlayer] = []
var environment_players: Dictionary = {}
var active_music_index := -1
var outgoing_music_index := -1

var _router: Node
var _fade_active := false
var _fade_elapsed := 0.0
var _fade_duration := DEFAULT_TRANSITION_SECONDS
var _incoming_start_db := SILENCE_DB
var _incoming_target_db := SILENCE_DB
var _outgoing_start_db := SILENCE_DB
var _environment_start_db := {
	LAYER_HIVE_INDOOR: SILENCE_DB,
	LAYER_FIELD_OUTDOOR: SILENCE_DB,
}
var _environment_target_db := {
	LAYER_HIVE_INDOOR: SILENCE_DB,
	LAYER_FIELD_OUTDOOR: SILENCE_DB,
}
var _tree_was_paused := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_create_players()
	_tree_was_paused = get_tree().paused
	call_deferred("_try_bind_parent_router")


func _create_players() -> void:
	if not music_players.is_empty():
		return
	for index in 2:
		var player := AudioStreamPlayer.new()
		player.name = "JourneyMusicA" if index == 0 else "JourneyMusicB"
		# Web must consume these WAV masters through the streaming path. This is
		# the same explicit playback contract used by the fixed generator channel,
		# and avoids the browser selecting a predecoded sample path during a fade.
		player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
		player.bus = &"Music" if AudioServer.get_bus_index(&"Music") >= 0 else &"Master"
		player.volume_db = SILENCE_DB
		add_child(player)
		music_players.append(player)
	for layer_id in ENVIRONMENT_LAYERS:
		var environment_player := AudioStreamPlayer.new()
		environment_player.name = "HiveIndoorAmbience" if layer_id == LAYER_HIVE_INDOOR else "FieldOutdoorAmbience"
		environment_player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
		environment_player.bus = &"SFX" if AudioServer.get_bus_index(&"SFX") >= 0 else &"Master"
		environment_player.volume_db = SILENCE_DB
		var ambience_path := String(DEFAULT_ENVIRONMENT_PATHS.get(layer_id, ""))
		var ambience_source := load(ambience_path) as AudioStreamWAV
		if ambience_source == null:
			push_error("Journey 环境循环无法加载：%s" % ambience_path)
		else:
			environment_player.stream = _prepare_looped_environment(ambience_source)
		add_child(environment_player)
		environment_players[layer_id] = environment_player


func bind_router(router: Node) -> Error:
	if router == null or not router.has_signal("area_changed"):
		return ERR_INVALID_PARAMETER
	var area_changed_callable := Callable(self, "_on_router_area_changed")
	if _router != null and is_instance_valid(_router) and _router.area_changed.is_connected(area_changed_callable):
		_router.area_changed.disconnect(area_changed_callable)
	_router = router
	if not _router.area_changed.is_connected(area_changed_callable):
		_router.area_changed.connect(area_changed_callable)
	if _has_property(_router, &"current_area_id"):
		var initial_area := StringName(String(_router.get("current_area_id")))
		if not initial_area.is_empty():
			return route_to(initial_area)
	return OK


func route_to(area_id: StringName, immediate := false) -> Error:
	var canonical_id := _canonical_route_id(area_id)
	if canonical_id.is_empty():
		return ERR_DOES_NOT_EXIST
	var route := _resolved_route(canonical_id)
	var next_family := int(route.get("family", last_world_family))
	var next_mode := StringName(String(route.get("mode", "explore")))
	var next_track_path := _track_path(next_family, next_mode)
	var next_stream: AudioStreamWAV
	var same_track := active_music_index >= 0 and current_track_path() == next_track_path
	if not same_track:
		next_stream = _load_looped_stream(next_track_path)
		if next_stream == null:
			return ERR_CANT_OPEN

	current_area_id = area_id
	current_route_id = canonical_id
	current_family = next_family
	current_mode = &"hive" if canonical_id == &"hive_threshold" else next_mode
	_current_track_path = next_track_path
	if canonical_id != &"hive_threshold" and canonical_id != &"ending":
		last_world_family = next_family

	_incoming_target_db = float(route.get("music_db", -13.0))
	_environment_target_db[LAYER_HIVE_INDOOR] = float(route.get("hive_indoor_db", SILENCE_DB))
	_environment_target_db[LAYER_FIELD_OUTDOOR] = float(route.get("field_outdoor_db", SILENCE_DB))

	if same_track:
		if outgoing_music_index >= 0:
			_stop_music_player(outgoing_music_index)
		outgoing_music_index = -1
		_incoming_start_db = music_players[active_music_index].volume_db
	else:
		_prepare_incoming_music(next_stream)

	_start_mix_transition(immediate)
	_sync_playback_gate()
	route_changed.emit(current_area_id, current_route_id, next_track_path)
	environment_mix_changed.emit(
		float(_environment_target_db[LAYER_HIVE_INDOOR]),
		float(_environment_target_db[LAYER_FIELD_OUTDOOR])
	)
	return OK


func set_enabled(value: bool) -> void:
	if enabled == value:
		return
	enabled = value
	_sync_playback_gate()


func set_focus_active(value: bool) -> void:
	if focus_active == value:
		return
	focus_active = value
	_sync_playback_gate()


func set_game_paused(value: bool) -> void:
	if manually_paused == value:
		return
	manually_paused = value
	_sync_playback_gate()


func is_playback_audible() -> bool:
	return enabled and focus_active and not manually_paused and not _tree_was_paused


func current_track_path() -> String:
	return _current_track_path


func environment_target_db(layer_id: StringName) -> float:
	return float(_environment_target_db.get(layer_id, SILENCE_DB))


func environment_stream(layer_id: StringName) -> AudioStream:
	var player := environment_players.get(layer_id) as AudioStreamPlayer
	return player.stream if player != null else null


func set_environment_stream(layer_id: StringName, stream: AudioStream) -> Error:
	var player := environment_players.get(layer_id) as AudioStreamPlayer
	if player == null:
		return ERR_DOES_NOT_EXIST
	player.stop()
	player.stream = _prepare_looped_environment(stream)
	player.volume_db = (
		float(_environment_target_db.get(layer_id, SILENCE_DB))
		if not current_route_id.is_empty()
		else SILENCE_DB
	)
	_sync_playback_gate()
	return OK


func set_environment_stream_path(layer_id: StringName, path: String) -> Error:
	if path.is_empty():
		return set_environment_stream(layer_id, null)
	var stream := load(path) as AudioStream
	if stream == null:
		return ERR_CANT_OPEN
	return set_environment_stream(layer_id, stream)


func finish_transition() -> void:
	if not _fade_active:
		return
	_advance_mix(_fade_duration - _fade_elapsed)


func _process(delta: float) -> void:
	var tree_paused := get_tree().paused
	if _tree_was_paused != tree_paused:
		_tree_was_paused = tree_paused
		_sync_playback_gate()
	if _fade_active and is_playback_audible():
		_advance_mix(delta)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		set_focus_active(false)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		set_focus_active(true)


func _exit_tree() -> void:
	if _router != null and is_instance_valid(_router):
		var area_changed_callable := Callable(self, "_on_router_area_changed")
		if _router.area_changed.is_connected(area_changed_callable):
			_router.area_changed.disconnect(area_changed_callable)
	for player in music_players:
		player.stop()
		player.stream = null
	for layer_id in environment_players:
		var environment_player := environment_players[layer_id] as AudioStreamPlayer
		environment_player.stop()
		environment_player.stream = null
	_current_track_path = ""


func _try_bind_parent_router() -> void:
	var parent := get_parent()
	if parent == null or not _has_property(parent, &"router"):
		return
	var candidate := parent.get("router") as Node
	if candidate != null:
		var error := bind_router(candidate)
		if error != OK:
			push_error("Journey 音频路由绑定失败：%d" % error)


func _on_router_area_changed(area_id: String, _area: Node) -> void:
	var error := route_to(StringName(area_id))
	if error != OK:
		push_warning("Journey 场景没有音频路由：%s" % area_id)


func _canonical_route_id(area_id: StringName) -> StringName:
	var area_text := String(area_id)
	if area_text == "hive_threshold":
		return &"hive_threshold"
	if ROUTES.has(area_text):
		return area_id
	if ROUTE_ALIASES.has(area_text):
		return StringName(String(ROUTE_ALIASES[area_text]))
	return &""


func _resolved_route(canonical_id: StringName) -> Dictionary:
	if canonical_id == &"hive_threshold":
		return {
			"family": last_world_family,
			"mode": "explore",
			"music_db": -18.0,
			"hive_indoor_db": -16.0,
			"field_outdoor_db": -36.0,
		}
	return (ROUTES[String(canonical_id)] as Dictionary).duplicate(true)


func _track_path(family_index: int, mode: StringName) -> String:
	var safe_family := clampi(family_index, 0, MUSIC_FAMILIES.size() - 1)
	var suffix := "incident" if mode == &"incident" else "explore"
	return "res://assets/music/%s_%s.wav" % [MUSIC_FAMILIES[safe_family], suffix]


func _load_looped_stream(path: String) -> AudioStreamWAV:
	var source := load(path) as AudioStreamWAV
	if source == null:
		push_error("Journey 音乐文件无法加载：%s" % path)
		return null
	# A shallow resource duplicate keeps loop metadata local while the immutable
	# PCM byte array remains copy-on-write; Web should not hold a second full copy.
	var stream := source.duplicate() as AudioStreamWAV
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = maxi(1, roundi(stream.get_length() * float(stream.mix_rate)))
	return stream


func _prepare_looped_environment(source: AudioStream) -> AudioStream:
	if source == null:
		return null
	if source is AudioStreamWAV:
		var stream := source.duplicate() as AudioStreamWAV
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = maxi(1, roundi(stream.get_length() * float(stream.mix_rate)))
		return stream
	return source


func _prepare_incoming_music(stream: AudioStreamWAV) -> void:
	if outgoing_music_index >= 0 and outgoing_music_index != active_music_index:
		_stop_music_player(outgoing_music_index)
	var next_index := 0 if active_music_index != 0 else 1
	_stop_music_player(next_index)
	outgoing_music_index = active_music_index
	active_music_index = next_index
	var incoming := music_players[active_music_index]
	incoming.stream = stream
	incoming.volume_db = SILENCE_DB
	_incoming_start_db = SILENCE_DB
	_outgoing_start_db = (
		music_players[outgoing_music_index].volume_db
		if outgoing_music_index >= 0
		else SILENCE_DB
	)


func _start_mix_transition(immediate: bool) -> void:
	_fade_elapsed = 0.0
	_fade_duration = maxf(0.01, transition_seconds)
	for layer_id in ENVIRONMENT_LAYERS:
		var player := environment_players[layer_id] as AudioStreamPlayer
		_environment_start_db[layer_id] = player.volume_db
	if immediate or transition_seconds <= 0.0:
		_apply_mix(1.0)
		_complete_transition()
		return
	_fade_active = true


func _advance_mix(delta: float) -> void:
	if not _fade_active:
		return
	_fade_elapsed = minf(_fade_duration, _fade_elapsed + maxf(0.0, delta))
	var progress := _fade_elapsed / _fade_duration
	# A smoothstep keeps both the entry and hand-off free of abrupt gain changes.
	var eased := progress * progress * (3.0 - 2.0 * progress)
	_apply_mix(eased)
	if progress >= 1.0:
		_complete_transition()


func _apply_mix(progress: float) -> void:
	if active_music_index >= 0:
		music_players[active_music_index].volume_db = _interpolate_db(_incoming_start_db, _incoming_target_db, progress)
	if outgoing_music_index >= 0:
		music_players[outgoing_music_index].volume_db = _interpolate_db(_outgoing_start_db, SILENCE_DB, progress)
	for layer_id in ENVIRONMENT_LAYERS:
		var environment_player := environment_players[layer_id] as AudioStreamPlayer
		environment_player.volume_db = _interpolate_db(
			float(_environment_start_db[layer_id]),
			float(_environment_target_db[layer_id]),
			progress
		)


func _interpolate_db(from_db: float, to_db: float, progress: float) -> float:
	# Interpolating decibels directly creates a near-silent hole halfway through
	# a crossfade. Blend gain instead, then convert back to the engine's dB control.
	var floor_gain := db_to_linear(SILENCE_DB)
	var mixed_gain := lerpf(db_to_linear(from_db), db_to_linear(to_db), clampf(progress, 0.0, 1.0))
	return linear_to_db(maxf(floor_gain, mixed_gain))


func _complete_transition() -> void:
	_fade_active = false
	_fade_elapsed = _fade_duration
	if outgoing_music_index >= 0:
		_stop_music_player(outgoing_music_index)
		outgoing_music_index = -1
	if active_music_index >= 0:
		music_players[active_music_index].volume_db = _incoming_target_db
	for layer_id in ENVIRONMENT_LAYERS:
		var player := environment_players[layer_id] as AudioStreamPlayer
		player.volume_db = float(_environment_target_db[layer_id])


func _sync_playback_gate() -> void:
	var audible := is_playback_audible()
	for player in music_players:
		_sync_player_gate(player, audible)
	for layer_id in environment_players:
		_sync_player_gate(environment_players[layer_id] as AudioStreamPlayer, audible)
	playback_gate_changed.emit(audible)


func _sync_player_gate(player: AudioStreamPlayer, audible: bool) -> void:
	if player.stream == null:
		return
	if audible:
		if not player.playing:
			player.play()
		player.stream_paused = false
	elif player.playing:
		player.stream_paused = true


func _stop_music_player(index: int) -> void:
	if index < 0 or index >= music_players.size():
		return
	var player := music_players[index]
	player.stop()
	player.stream = null
	player.volume_db = SILENCE_DB


func _has_property(object: Object, property_name: StringName) -> bool:
	for property in object.get_property_list():
		if StringName(property.get("name", "")) == property_name:
			return true
	return false
