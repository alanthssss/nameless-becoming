extends SceneTree

const SUCCESS_MARKER := "EXPORT PACK CONTENTS VERIFIED"
const REPORT_SCHEMA_VERSION := 1

const REQUIRED_SCENE_REMAPS: Array[String] = [
	"res://commercial_title.tscn.remap",
	"res://campaign.tscn.remap",
	"res://journey.tscn.remap",
	"res://world/journey/campaign_field.tscn.remap",
	"res://world/journey/campaign_hive.tscn.remap",
	"res://world/journey/autumn_field.tscn.remap",
	"res://world/journey/finale_handoff.tscn.remap",
	"res://world/journey/hive_threshold.tscn.remap",
	"res://world/journey/spring_field.tscn.remap",
	"res://world/journey/spring_sign_incident.tscn.remap",
	"res://world/journey/summer_field.tscn.remap",
	"res://world/journey/winter_field.tscn.remap",
]

const REQUIRED_DYNAMIC_FILES: Array[String] = [
	"res://data/build_provenance.json",
	"res://data/commercial_script_class_allowlist.json",
	"res://data/credits_and_licenses.json",
	"res://data/journey_levels.json",
	"res://data/journey_solar_term_chronicles.json",
	"res://assets/audio/commercial/manifest.json",
	"res://fonts/OFL-NotoSansCJK.txt",
]

const GLOBAL_CLASS_CACHE_PATH := "res://.godot/global_script_class_cache.cfg"
const COMMERCIAL_CLASS_ALLOWLIST_PATH := "res://data/commercial_script_class_allowlist.json"
const FORBIDDEN_CLASS_CACHE_TERMS: Array[String] = [
	"nameless",
	"boss",
	"b01",
	"playtest",
	"/main.gd",
	"/bootstrap.gd",
	"production_hud",
	"productionhud",
	"&\"main\"",
]

const COMMERCIAL_TEXTURES: Array[String] = [
	"res://assets/art/commercial/autumn_world_ground_v1.png",
	"res://assets/art/commercial/bear_helper_states_v1.png",
	"res://assets/art/commercial/dahan_result_hero_v1.png",
	"res://assets/art/commercial/dashu_result_hero_v1.png",
	"res://assets/art/commercial/flower_states_topdown_v1.png",
	"res://assets/art/commercial/guyu_result_hero_v1.png",
	"res://assets/art/commercial/hive_threshold_interior_v1.png",
	"res://assets/art/commercial/listening_seed_shell_states_v1.png",
	"res://assets/art/commercial/main_hive_exterior_v1.png",
	"res://assets/art/commercial/mentor_bee_topdown_v1.png",
	"res://assets/art/commercial/mosquito_keeper_states_v1.png",
	"res://assets/art/commercial/oil_cricket_repairer_states_v2.png",
	"res://assets/art/commercial/player_bee_topdown_states_v1.png",
	"res://assets/art/commercial/rest_hive_exterior_v1.png",
	"res://assets/art/commercial/seasonal_work_props_v1.png",
	"res://assets/art/commercial/shuangjiang_result_hero_v1.png",
	"res://assets/art/commercial/spring_world_ground_v1.png",
	"res://assets/art/commercial/summer_world_ground_v1.png",
	"res://assets/art/commercial/thrush_neighbor_states_v3.png",
	"res://assets/art/commercial/winter_world_ground_v1.png",
	"res://assets/art/commercial/worker_bee_topdown_v1.png",
]

const COMMERCIAL_MUSIC: Array[String] = [
	"res://assets/music/autumn_incident.wav",
	"res://assets/music/autumn_explore.wav",
	"res://assets/music/spring_incident.wav",
	"res://assets/music/spring_explore.wav",
	"res://assets/music/summer_incident.wav",
	"res://assets/music/summer_explore.wav",
	"res://assets/music/winter_incident.wav",
	"res://assets/music/winter_explore.wav",
]

const COMMERCIAL_AUDIO: Array[String] = [
	"res://assets/audio/commercial/carry_log.wav",
	"res://assets/audio/commercial/complete.wav",
	"res://assets/audio/commercial/evade_dart.wav",
	"res://assets/audio/commercial/field_day_loop.wav",
	"res://assets/audio/commercial/handoff.wav",
	"res://assets/audio/commercial/hive_room_loop.wav",
	"res://assets/audio/commercial/honey_loss.wav",
	"res://assets/audio/commercial/nectar_collect.wav",
	"res://assets/audio/commercial/observe_rustle.wav",
	"res://assets/audio/commercial/pollination_bloom.wav",
	"res://assets/audio/commercial/pouch_full.wav",
	"res://assets/audio/commercial/relay_drop.wav",
	"res://assets/audio/commercial/repair_tap.wav",
	"res://assets/audio/commercial/seed_place.wav",
	"res://assets/audio/commercial/seed_shell_rustle.wav",
	"res://assets/audio/commercial/warmth_link.wav",
]

const COMMERCIAL_AMBIENCE: Array[String] = [
	"res://assets/audio/commercial/field_day_loop.wav",
	"res://assets/audio/commercial/hive_room_loop.wav",
]

const FORBIDDEN_SOURCE_FILES: Array[String] = [
	"res://bootstrap.tscn",
	"res://main.tscn",
	"res://scripts/bootstrap.gd",
	"res://scripts/main.gd",
	"res://playtest/b01_evade_slice.tscn",
	"res://data/playtest_slices.json",
	"res://assets/music/analysis.json",
	"res://assets/art/commercial/oil_cricket_states_v1.png",
	"res://assets/art/commercial/thrush_tuner_states_v1.png",
	"res://assets/audio/commercial/trichord_echo.wav",
]

const FORBIDDEN_UID_CACHE_TERMS: Array[String] = [
	"assets/art/launch/",
	"assets/art/seasonal/",
	"textile",
	"oil_cricket_states_v1",
	"thrush_tuner_states_v1",
	"trichord_echo",
]

const FORBIDDEN_PREFIXES: Array[String] = [
	"res://tests/",
	"res://tools/",
	"res://playtest/",
	"res://scripts/playtest/",
	"res://assets/art/launch/",
	"res://assets/art/seasonal/",
]


func collect_files(directory_path: String, output: Array[String]) -> void:
	var directory := DirAccess.open(directory_path)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		var entry_path := directory_path.path_join(entry)
		if directory.current_is_dir():
			collect_files(entry_path, output)
		else:
			output.append(entry_path)
		entry = directory.get_next()
	directory.list_dir_end()


func fail(message: String) -> void:
	push_error(message)
	quit(1)


func has_exact_keys(value: Dictionary, expected: Array[String]) -> bool:
	var actual: Array[String] = []
	for key in value.keys():
		actual.append(String(key))
	actual.sort()
	var normalized := expected.duplicate()
	normalized.sort()
	return actual == normalized


func is_sha256(value: Variant) -> bool:
	var pattern := RegEx.new()
	return pattern.compile("^[0-9a-f]{64}$") == OK and pattern.search(String(value)) != null


func source_variant_matches(file_path: String, source_path: String) -> bool:
	if file_path == source_path or file_path == source_path + ".remap":
		return true
	if source_path.ends_with(".gd") and file_path == source_path.trim_suffix(".gd") + ".gdc":
		return true
	return false


func is_forbidden_source_path(file_path: String) -> bool:
	for source_path in FORBIDDEN_SOURCE_FILES:
		if source_variant_matches(file_path, source_path):
			return true
	for prefix in FORBIDDEN_PREFIXES:
		if file_path.begins_with(prefix):
			return true
	var lower_path := file_path.to_lower()
	return (
		lower_path.find("textile") >= 0
		or lower_path.find("_boss.wav") >= 0
		or lower_path.find("oil_cricket_states_v1") >= 0
		or lower_path.find("thrush_tuner_states_v1") >= 0
		or lower_path.find("trichord_echo") >= 0
	)


func parse_json_object(path: String, label: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		fail("Commercial pack is missing %s: %s" % [label, path])
		return {}
	var parser := JSON.new()
	var parse_result := parser.parse(FileAccess.get_file_as_string(path))
	if parse_result != OK or not parser.data is Dictionary:
		fail("Commercial pack %s is not a JSON object: %s" % [label, path])
		return {}
	return parser.data


func validate_file_boundary(files: Array[String], pack_path: String) -> bool:
	var required_files: Array[String] = ["res://project.binary", GLOBAL_CLASS_CACHE_PATH]
	required_files.append_array(REQUIRED_SCENE_REMAPS)
	required_files.append_array(REQUIRED_DYNAMIC_FILES)
	var missing: Array[String] = []
	for required_path in required_files:
		if required_path not in files:
			missing.append(required_path)
	if not missing.is_empty():
		fail("Commercial pack is missing required runtime files: %s\n%s" % [pack_path, "\n".join(missing)])
		return false

	var exported_scenes: Array[String] = []
	for file_path in files:
		if file_path.ends_with(".tscn.remap"):
			exported_scenes.append(file_path)
	exported_scenes.sort()
	var expected_scenes := REQUIRED_SCENE_REMAPS.duplicate()
	expected_scenes.sort()
	if exported_scenes != expected_scenes:
		fail(
			"Commercial pack scene closure is not exact.\nExpected:\n%s\nActual:\n%s"
			% ["\n".join(expected_scenes), "\n".join(exported_scenes)]
		)
		return false

	var exported_texture_imports: Array[String] = []
	for file_path in files:
		if file_path.begins_with("res://assets/art/commercial/") and file_path.ends_with(".png.import"):
			exported_texture_imports.append(file_path)
	exported_texture_imports.sort()
	var expected_texture_imports: Array[String] = []
	for texture_path in COMMERCIAL_TEXTURES:
		expected_texture_imports.append(texture_path + ".import")
	expected_texture_imports.sort()
	if exported_texture_imports != expected_texture_imports:
		fail(
			"Commercial texture closure is not exact.\nExpected:\n%s\nActual:\n%s"
			% ["\n".join(expected_texture_imports), "\n".join(exported_texture_imports)]
		)
		return false

	# Imported audio is addressed through one remap per selected WAV. Requiring
	# the exact commercial set prevents a stale render from silently riding along
	# in a candidate build, while the broader boundary below still rejects all
	# prototype and test resources.
	var exported_audio_imports: Array[String] = []
	for file_path in files:
		if file_path.begins_with("res://assets/audio/commercial/") and file_path.ends_with(".wav.import"):
			exported_audio_imports.append(file_path)
	exported_audio_imports.sort()
	var expected_audio_imports: Array[String] = []
	for audio_path in COMMERCIAL_AUDIO:
		expected_audio_imports.append(audio_path + ".import")
	expected_audio_imports.sort()
	if exported_audio_imports != expected_audio_imports:
		fail(
			"Commercial pack audio closure is not exact.\nExpected:\n%s\nActual:\n%s"
			% ["\n".join(expected_audio_imports), "\n".join(exported_audio_imports)]
		)
		return false

	var exported_music_imports: Array[String] = []
	for file_path in files:
		if file_path.begins_with("res://assets/music/") and file_path.ends_with(".wav.import"):
			exported_music_imports.append(file_path)
	exported_music_imports.sort()
	var expected_music_imports: Array[String] = []
	for music_path in COMMERCIAL_MUSIC:
		expected_music_imports.append(music_path + ".import")
	expected_music_imports.sort()
	if exported_music_imports != expected_music_imports:
		fail(
			"Commercial pack music closure is not exact.\nExpected:\n%s\nActual:\n%s"
			% ["\n".join(expected_music_imports), "\n".join(exported_music_imports)]
		)
		return false

	var forbidden: Array[String] = []
	for file_path in files:
		if is_forbidden_source_path(file_path):
			forbidden.append(file_path)
	if not forbidden.is_empty():
		fail("Commercial pack contains prototype, playtest, internal, or rejected-art resources:\n%s" % "\n".join(forbidden))
		return false
	var uid_cache_path := "res://.godot/uid_cache.bin"
	if uid_cache_path in files:
		var uid_cache_text := FileAccess.get_file_as_bytes(uid_cache_path).get_string_from_utf8().to_lower()
		for forbidden_term in FORBIDDEN_UID_CACHE_TERMS:
			if uid_cache_text.find(forbidden_term) >= 0:
				fail("Commercial UID cache retains a rejected asset identity: %s" % forbidden_term)
				return false
	return true


func validate_commercial_class_cache(files: Array[String]) -> bool:
	var allowlist := parse_json_object(COMMERCIAL_CLASS_ALLOWLIST_PATH, "commercial script-class allowlist")
	if allowlist.is_empty():
		return false
	if not has_exact_keys(allowlist, ["entries", "schema_version"]) or int(allowlist.get("schema_version", 0)) != 1:
		fail("Commercial script-class allowlist does not use the exact schema-v1 shape.")
		return false
	var raw_allowlist_entries = allowlist.get("entries", [])
	if not raw_allowlist_entries is Array or raw_allowlist_entries.is_empty():
		fail("Commercial script-class allowlist must contain at least one entry.")
		return false

	var expected_by_class: Dictionary = {}
	var expected_paths: Dictionary = {}
	for raw_entry in raw_allowlist_entries:
		if not raw_entry is Dictionary:
			fail("Commercial script-class allowlist contains a non-object entry.")
			return false
		var entry: Dictionary = raw_entry
		if not has_exact_keys(entry, ["base", "class", "path"]):
			fail("Commercial script-class allowlist entry does not use the exact base/class/path shape.")
			return false
		var allowed_class := String(entry.get("class", ""))
		var base_name := String(entry.get("base", ""))
		var source_path := String(entry.get("path", ""))
		var entry_identity := "%s\n%s\n%s" % [allowed_class, base_name, source_path]
		var lower_identity := entry_identity.to_lower()
		for forbidden_term in FORBIDDEN_CLASS_CACHE_TERMS:
			if lower_identity.find(forbidden_term) >= 0:
				fail("Commercial script-class allowlist contains forbidden legacy identity text: %s" % forbidden_term)
				return false
		if (
			allowed_class.is_empty()
			or base_name.is_empty()
			or not source_path.begins_with("res://scripts/")
			or not source_path.ends_with(".gd")
			or is_forbidden_source_path(source_path)
			or expected_by_class.has(allowed_class)
			or expected_paths.has(source_path)
		):
			fail("Commercial script-class allowlist contains an invalid, duplicate, or excluded entry: %s %s" % [allowed_class, source_path])
			return false
		expected_by_class[allowed_class] = entry
		expected_paths[source_path] = true
	for file_path in files:
		if not file_path.begins_with("res://scripts/"):
			continue
		var exported_source_path := ""
		if file_path.ends_with(".gd"):
			exported_source_path = file_path
		elif file_path.ends_with(".gdc"):
			exported_source_path = file_path.trim_suffix(".gdc") + ".gd"
		elif file_path.ends_with(".gd.remap"):
			exported_source_path = file_path.trim_suffix(".remap")
		if not exported_source_path.is_empty() and not expected_paths.has(exported_source_path):
			fail("Commercial PCK contains a script outside the reviewed class allowlist: %s" % file_path)
			return false

	var cache_text := FileAccess.get_file_as_string(GLOBAL_CLASS_CACHE_PATH)
	if not cache_text.begins_with("list="):
		fail("Commercial global script-class cache is absent or does not begin with list=.")
		return false
	var lower_cache_text := cache_text.to_lower()
	for forbidden_term in FORBIDDEN_CLASS_CACHE_TERMS:
		if lower_cache_text.find(forbidden_term) >= 0:
			fail("Commercial global script-class cache contains forbidden legacy text: %s" % forbidden_term)
			return false
	var parsed_cache = str_to_var(cache_text.trim_prefix("list="))
	if not parsed_cache is Array:
		fail("Commercial global script-class cache is not a parseable Variant array.")
		return false
	if parsed_cache.size() != expected_by_class.size():
		fail(
			"Commercial global script-class cache is not exact: expected %d entries, found %d."
			% [expected_by_class.size(), parsed_cache.size()]
		)
		return false

	var seen_classes: Dictionary = {}
	for raw_cache_entry in parsed_cache:
		if not raw_cache_entry is Dictionary:
			fail("Commercial global script-class cache contains a non-object entry.")
			return false
		var cache_entry: Dictionary = raw_cache_entry
		if not has_exact_keys(cache_entry, ["base", "class", "icon", "is_abstract", "is_tool", "language", "path"]):
			fail("Commercial global script-class cache entry does not use Godot's exact reviewed shape.")
			return false
		var cache_class := String(cache_entry.get("class", ""))
		var cache_path := String(cache_entry.get("path", ""))
		if not expected_by_class.has(cache_class) or seen_classes.has(cache_class):
			fail("Commercial global script-class cache contains an unknown or duplicate class: %s" % cache_class)
			return false
		var expected: Dictionary = expected_by_class[cache_class]
		if (
			String(cache_entry.get("base", "")) != String(expected.get("base", ""))
			or cache_path != String(expected.get("path", ""))
			or String(cache_entry.get("icon", "")) != ""
			or bool(cache_entry.get("is_abstract", true))
			or bool(cache_entry.get("is_tool", true))
			or String(cache_entry.get("language", "")) != "GDScript"
			or is_forbidden_source_path(cache_path)
		):
			fail("Commercial global script-class cache entry does not match its reviewed allowlist row: %s" % cache_class)
			return false

		var found_compiled_source := false
		for file_path in files:
			if source_variant_matches(file_path, cache_path):
				found_compiled_source = true
				break
		if not found_compiled_source:
			fail("Commercial class-cache path has no actual source or compiled script in the PCK: %s" % cache_path)
			return false
		seen_classes[cache_class] = true
	return true


func validate_commercial_resources() -> bool:
	for texture_path in COMMERCIAL_TEXTURES:
		var texture := load(texture_path) as Texture2D
		if texture == null:
			fail("Commercial texture is absent or cannot load from the pack: %s" % texture_path)
			return false
		if texture_path.ends_with("_result_hero_v1.png") and texture.get_size() != Vector2(1672, 941):
			fail("Seasonal result illustration must retain its reviewed 1672 x 941 source dimensions: %s" % texture_path)
			return false
	for music_path in COMMERCIAL_MUSIC:
		var stream := load(music_path) as AudioStreamWAV
		if stream == null:
			fail("Authored Journey music is absent or cannot load from the pack: %s" % music_path)
			return false
	var journey_audio_script := load("res://scripts/world/journey_audio_director.gd") as Script
	if journey_audio_script == null:
		fail("Commercial Journey audio director is absent from the pack.")
		return false
	var journey_audio = journey_audio_script.new()
	for route_id in journey_audio.ROUTES:
		var route: Dictionary = journey_audio.ROUTES[route_id]
		if String(route.get("mode", "")) == "boss":
			journey_audio.free()
			fail("Commercial Journey audio route still exposes Boss framing: %s" % route_id)
			return false
	for incident_route_id in [
		"spring_sign_incident",
		"summer_rest_hive_repair",
		"autumn_echo_incident",
		"winter_windbreak",
	]:
		var incident_route: Dictionary = journey_audio.ROUTES.get(incident_route_id, {})
		var incident_family := int(incident_route.get("family", -1))
		if (
			String(incident_route.get("mode", "")) != "incident"
			or not String(journey_audio._track_path(incident_family, &"incident")).ends_with("_incident.wav")
		):
			journey_audio.free()
			fail("Commercial Journey incident route has an invalid music identity: %s" % incident_route_id)
			return false
	journey_audio.free()
	for audio_path in COMMERCIAL_AUDIO:
		var commercial_audio := load(audio_path) as AudioStreamWAV
		if commercial_audio == null:
			fail("Commercial SFX or ambience candidate is absent or cannot load from the pack: %s" % audio_path)
			return false
		if commercial_audio.mix_rate != 44100 or not commercial_audio.stereo or commercial_audio.get_length() <= 0.15:
			fail("Commercial audio candidate has an invalid 44.1 kHz stereo runtime stream: %s" % audio_path)
			return false
	var project_font := load("res://fonts/NotoSansCJKsc-ProjectSubset.otf") as Font
	if project_font == null:
		fail("Commercial Noto CJK project font is absent or cannot load from the pack.")
		return false

	var commercial_scene := load("res://commercial_title.tscn") as PackedScene
	if commercial_scene == null:
		fail("Commercial title scene or one of its dependencies cannot load from the pack.")
		return false
	var commercial_instance := commercial_scene.instantiate()
	if commercial_instance == null or not commercial_instance.has_method("_start_new_journey") or not commercial_instance.has_method("_open_credits"):
		if commercial_instance != null:
			commercial_instance.free()
		fail("Commercial title does not expose its Journey and credits contracts.")
		return false
	commercial_instance.free()

	var campaign_scene := load("res://campaign.tscn") as PackedScene
	if campaign_scene == null:
		fail("Formal campaign scene or one of its area dependencies cannot load from the pack.")
		return false
	var campaign_instance := campaign_scene.instantiate()
	if campaign_instance == null or not campaign_instance.has_method("_begin_level") or not campaign_instance.has_method("_return_to_title"):
		if campaign_instance != null:
			campaign_instance.free()
		fail("Formal campaign does not expose its level and title-return contracts.")
		return false
	campaign_instance.free()

	var journey_scene := load("res://journey.tscn") as PackedScene
	if journey_scene == null:
		fail("Commercial Journey scene or one of its area dependencies cannot load from the pack.")
		return false
	var journey_instance := journey_scene.instantiate()
	if journey_instance == null or not journey_instance.has_method("_begin_sortie") or not journey_instance.has_method("_return_to_title"):
		if journey_instance != null:
			journey_instance.free()
		fail("Commercial Journey does not expose its sortie and title-return contracts.")
		return false
	journey_instance.free()

	for scene_remap in REQUIRED_SCENE_REMAPS:
		if scene_remap in ["res://commercial_title.tscn.remap", "res://campaign.tscn.remap", "res://journey.tscn.remap"]:
			continue
		var scene_path := scene_remap.trim_suffix(".remap")
		var area_scene := load(scene_path) as PackedScene
		if area_scene == null:
			fail("Commercial Journey area cannot load from the pack: %s" % scene_path)
			return false
		var area_instance := area_scene.instantiate()
		if area_instance == null or not area_instance.has_method("configure"):
			if area_instance != null:
				area_instance.free()
			fail("Commercial Journey area lacks its context contract: %s" % scene_path)
			return false
		area_instance.free()
	return true


func validate_dynamic_documents() -> Dictionary:
	var provenance := parse_json_object("res://data/build_provenance.json", "build provenance")
	if provenance.is_empty():
		return {}
	if not has_exact_keys(provenance, ["schema_version", "product_version", "commit", "dirty"]):
		fail("Commercial build provenance does not use the exact schema v1 shape.")
		return {}
	var commit_pattern := RegEx.new()
	if (
		commit_pattern.compile("^[0-9a-f]{40}$") != OK
		or int(provenance.get("schema_version", 0)) != 1
		or String(provenance.get("product_version", "")).is_empty()
		or commit_pattern.search(String(provenance.get("commit", ""))) == null
		or typeof(provenance.get("dirty", null)) != TYPE_BOOL
	):
		fail("Commercial build provenance contains invalid identity fields.")
		return {}

	var credits := parse_json_object("res://data/credits_and_licenses.json", "credits and licenses")
	if credits.is_empty():
		return {}
	if (
		int(credits.get("schema_version", 0)) != 1
		or not credits.get("credits", []) is Array
		or (credits.get("credits", []) as Array).is_empty()
		or not credits.get("third_party", []) is Array
	):
		fail("Commercial credits and licenses document is incomplete.")
		return {}
	var found_noto_license := false
	for notice in credits.get("third_party", []):
		if notice is Dictionary and String((notice as Dictionary).get("license_file", "")) == "res://fonts/OFL-NotoSansCJK.txt":
			found_noto_license = true
			break
	if not found_noto_license:
		fail("Commercial credits do not point to the bundled Noto OFL text.")
		return {}

	var audio_manifest := parse_json_object("res://assets/audio/commercial/manifest.json", "commercial audio manifest")
	if audio_manifest.is_empty():
		return {}
	if not has_exact_keys(
		audio_manifest,
		["assets", "candidate_status", "generator", "generator_sha256", "schema_version", "source_parameters", "source_parameters_sha256"]
	):
		fail("Commercial audio manifest does not use the exact schema-v1 shape.")
		return {}
	var candidate_status := String(audio_manifest.get("candidate_status", "")).to_lower()
	if (
		int(audio_manifest.get("schema_version", 0)) != 1
		or String(audio_manifest.get("generator", "")) != "scripts/generate_commercial_audio.mjs"
		or String(audio_manifest.get("source_parameters", "")) != "scripts/commercial_audio_sources.json"
		or not is_sha256(audio_manifest.get("generator_sha256", ""))
		or not is_sha256(audio_manifest.get("source_parameters_sha256", ""))
		or candidate_status.find("project-owned deterministic synthesis candidate") < 0
		or candidate_status.find("alan approval") < 0
		or candidate_status.find("device mix confirmation") < 0
		or candidate_status.find("not a recording") < 0
		or candidate_status.find("not a") < 0
		or candidate_status.find("final master") < 0
	):
		fail("Commercial audio manifest does not preserve candidate provenance and approval limits.")
		return {}
	var manifest_assets = audio_manifest.get("assets", [])
	if not manifest_assets is Array or manifest_assets.size() != COMMERCIAL_AUDIO.size():
		fail("Commercial audio manifest must contain the exact 16-asset candidate set.")
		return {}
	var manifest_by_path: Dictionary = {}
	for raw_asset in manifest_assets:
		if not raw_asset is Dictionary:
			fail("Commercial audio manifest contains a non-object asset row.")
			return {}
		var asset: Dictionary = raw_asset
		if not has_exact_keys(
			asset,
			["channels", "duration_seconds", "file", "frames", "id", "kind", "loop", "pcm_bits", "recipe", "sample_rate", "sha256", "source_kind"]
		):
			fail("Commercial audio manifest asset does not use the exact schema-v1 shape: %s" % asset.get("file", ""))
			return {}
		var asset_path := "res://assets/audio/commercial/%s" % String(asset.get("file", ""))
		var expected_ambience := asset_path in COMMERCIAL_AMBIENCE
		var expected_kind := "ambience" if expected_ambience else "sfx"
		var frames := int(asset.get("frames", 0))
		if (
			asset_path not in COMMERCIAL_AUDIO
			or manifest_by_path.has(asset_path)
			or String(asset.get("id", "")).is_empty()
			or String(asset.get("recipe", "")) != String(asset.get("id", ""))
			or String(asset.get("kind", "")) != expected_kind
			or bool(asset.get("loop", false)) != expected_ambience
			or String(asset.get("source_kind", "")) != "project_owned_deterministic_synthesis"
			or int(asset.get("sample_rate", 0)) != 44100
			or int(asset.get("channels", 0)) != 2
			or int(asset.get("pcm_bits", 0)) != 16
			or frames <= 0
			or absf(float(asset.get("duration_seconds", 0.0)) - float(frames) / 44100.0) > 0.0001
			or not is_sha256(asset.get("sha256", ""))
		):
			fail("Commercial audio manifest contains invalid candidate metadata: %s" % asset_path)
			return {}
		manifest_by_path[asset_path] = asset
	for expected_path in COMMERCIAL_AUDIO:
		if not manifest_by_path.has(expected_path):
			fail("Commercial audio manifest is missing: %s" % expected_path)
			return {}

	var audio_provenance: Dictionary = {}
	var provenance_rows = credits.get("asset_provenance", [])
	if provenance_rows is Array:
		for raw_row in provenance_rows:
			if raw_row is Dictionary and String((raw_row as Dictionary).get("asset_set", "")) == "commercial_sfx_and_ambience_v1":
				audio_provenance = raw_row
				break
	if audio_provenance.is_empty():
		fail("Commercial credits omit the project-owned audio candidate provenance record.")
		return {}
	if (
		String(audio_provenance.get("kind", "")) != "project_owned_audio_candidates"
		or String(audio_provenance.get("creation_method", "")).find("不是录音") < 0
		or String(audio_provenance.get("creation_method", "")).find("不是终稿") < 0
		or String(audio_provenance.get("generator_path", "")) != String(audio_manifest.get("generator", ""))
		or String(audio_provenance.get("generator_sha256", "")) != String(audio_manifest.get("generator_sha256", ""))
		or String(audio_provenance.get("parameters_path", "")) != String(audio_manifest.get("source_parameters", ""))
		or String(audio_provenance.get("parameters_sha256", "")) != String(audio_manifest.get("source_parameters_sha256", ""))
		or String(audio_provenance.get("runtime_manifest_path", "")) != "res://assets/audio/commercial/manifest.json"
		or String(audio_provenance.get("runtime_manifest_sha256", "")) != FileAccess.get_sha256("res://assets/audio/commercial/manifest.json")
		or String(audio_provenance.get("approval_status", "")) != "candidate_requires_alan_and_device_mix_confirmation"
		or audio_provenance.get("approved_by", true) != null
		or audio_provenance.get("approved_at", true) != null
		or not audio_provenance.get("third_party_sources", null) is Array
		or not (audio_provenance.get("third_party_sources", []) as Array).is_empty()
	):
		fail("Commercial credits contain invalid audio candidate provenance or approval state.")
		return {}
	var credited_audio = audio_provenance.get("files", [])
	if not credited_audio is Array or credited_audio.size() != COMMERCIAL_AUDIO.size():
		fail("Commercial credits must enumerate the exact 16 audio candidates.")
		return {}
	var credited_paths: Dictionary = {}
	for raw_file in credited_audio:
		if not raw_file is Dictionary:
			fail("Commercial credits contain a non-object audio file row.")
			return {}
		var credited_file: Dictionary = raw_file
		var credited_path := String(credited_file.get("path", ""))
		if (
			not manifest_by_path.has(credited_path)
			or credited_paths.has(credited_path)
			or String(credited_file.get("sha256", "")) != String((manifest_by_path[credited_path] as Dictionary).get("sha256", ""))
			or String(credited_file.get("kind", "")) != String((manifest_by_path[credited_path] as Dictionary).get("kind", ""))
			or String(credited_file.get("role", "")) != String((manifest_by_path[credited_path] as Dictionary).get("id", ""))
		):
			fail("Commercial credits do not match the audio runtime manifest: %s" % credited_path)
			return {}
		credited_paths[credited_path] = true
	var ofl_text := FileAccess.get_file_as_string("res://fonts/OFL-NotoSansCJK.txt")
	if ofl_text.find("SIL OPEN FONT LICENSE Version 1.1") < 0:
		fail("Bundled Noto license is missing the SIL Open Font License 1.1 heading.")
		return {}

	var chronicle := parse_json_object("res://data/journey_solar_term_chronicles.json", "solar-term chronicle")
	if chronicle.is_empty():
		return {}
	var terms = chronicle.get("terms", [])
	if int(chronicle.get("schema_version", 0)) != 1 or not terms is Array or terms.size() != 24:
		fail("Commercial solar-term chronicle must contain exactly 24 schema-v1 entries.")
		return {}
	var ids: Dictionary = {}
	var names: Dictionary = {}
	for index in terms.size():
		if not terms[index] is Dictionary:
			fail("Commercial solar-term chronicle row %d is not an object." % index)
			return {}
		var term: Dictionary = terms[index]
		var term_id := String(term.get("id", ""))
		var term_name := String(term.get("name", ""))
		if term_id.is_empty() or term_name.is_empty() or int(term.get("order", -1)) != index or ids.has(term_id) or names.has(term_name):
			fail("Commercial solar-term chronicle row %d has an invalid id, name, order, or duplicate." % index)
			return {}
		ids[term_id] = true
		names[term_name] = true

	var campaign_catalog := parse_json_object("res://data/journey_levels.json", "formal campaign catalog")
	if campaign_catalog.is_empty():
		return {}
	var campaign_levels = campaign_catalog.get("levels", [])
	if (
		int(campaign_catalog.get("schema_version", 0)) != 1
		or int(campaign_catalog.get("total_levels", 0)) != 24
		or not campaign_levels is Array
		or campaign_levels.size() != 24
	):
		fail("Formal campaign catalog must contain exactly 24 schema-v1 levels.")
		return {}
	var climax_orders: Array[int] = []
	var content_slice_optional_counts := {
		"spring_yushui": 6,
		"spring_guyu": 4,
	}
	var content_slice_ids := {}
	for index in campaign_levels.size():
		if not campaign_levels[index] is Dictionary:
			fail("Formal campaign level %d is not an object." % index)
			return {}
		var level: Dictionary = campaign_levels[index]
		if String(level.get("id", "")) != String((terms[index] as Dictionary).get("id", "")) or int(level.get("order", -1)) != index:
			fail("Formal campaign level %d does not align with its solar term." % index)
			return {}
		if String(level.get("kind", "")) == "climax":
			climax_orders.append(index)
			if not level.get("phases", []) is Array or (level.get("phases", []) as Array).size() != 3:
				fail("Formal campaign climax level %d does not have exactly three phases." % index)
				return {}
		var level_id := String(level.get("id", ""))
		if content_slice_optional_counts.has(level_id):
			var matrix = level.get("event_matrix", [])
			if not matrix is Array or matrix.size() != 15:
				fail("Commercial content slice %s must contain exactly 15 events." % level_id)
				return {}
			var event_ids := {}
			var mechanics := {}
			var optional_count := 0
			for event_index in matrix.size():
				if not matrix[event_index] is Dictionary:
					fail("Commercial content slice %s event %d is not an object." % [level_id, event_index])
					return {}
				var event: Dictionary = matrix[event_index]
				var event_id := String(event.get("id", ""))
				var mechanic := String(event.get("mechanic", ""))
				if (
					event_id.is_empty()
					or event_ids.has(event_id)
					or int(event.get("order", -1)) != event_index + 1
					or int(event.get("pentad", -1)) != floori(float(event_index) / 5.0) + 1
					or typeof(event.get("optional", null)) != TYPE_BOOL
					or mechanic.is_empty()
					or String(event.get("decision", "")).is_empty()
					or String(event.get("operation", "")).is_empty()
					or String(event.get("consequence", "")).is_empty()
					or String(event.get("verification_status", "")) not in ["approved-for-gameplay", "approved-for-player-facing-science"]
					or not event.get("source_ids", []) is Array
					or (event.get("source_ids", []) as Array).is_empty()
					or not event.get("fact_ids", []) is Array
				):
					fail("Commercial content slice %s event %d violates the shipping contract." % [level_id, event_index])
					return {}
				event_ids[event_id] = true
				mechanics[mechanic] = true
				if bool(event.get("optional", false)):
					optional_count += 1
			if optional_count != int(content_slice_optional_counts[level_id]) or mechanics.size() < 10:
				fail("Commercial content slice %s has the wrong main/optional split or too little mechanic variety." % level_id)
				return {}
			content_slice_ids[level_id] = true
	if climax_orders != [5, 11, 17, 23]:
		fail("Formal campaign climax levels are not fixed at 6/12/18/24.")
		return {}
	if content_slice_ids.size() != content_slice_optional_counts.size():
		fail("Formal campaign pack is missing the reviewed 30-event content slice.")
		return {}
	var catalog_script := load("res://scripts/world/journey_level_catalog.gd") as Script
	if catalog_script == null:
		fail("Formal campaign runtime catalog validator is absent from the pack.")
		return {}
	var runtime_catalog = catalog_script.new()
	if runtime_catalog == null or not bool(runtime_catalog.catalog_valid):
		fail("Formal campaign runtime catalog rejected the packed 30-event source and verification contracts.")
		return {}
	return provenance


func _init() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 1 and arguments.size() != 3:
		fail("Expected a pack path, optionally followed by --report and an absolute JSON report path.")
		return

	var pack_path := arguments[0]
	var report_path := ""
	if arguments.size() == 3:
		if arguments[1] != "--report":
			fail("The only supported pack-inspection option is --report.")
			return
		report_path = arguments[2]
		if not report_path.is_absolute_path():
			fail("Pack inspection report path must be absolute: %s" % report_path)
			return
		if FileAccess.file_exists(report_path):
			fail("Pack inspection report path already exists: %s" % report_path)
			return
	if not FileAccess.file_exists(pack_path):
		fail("Exported pack does not exist: %s" % pack_path)
		return
	if not ProjectSettings.load_resource_pack(pack_path, true):
		fail("Godot could not load exported pack: %s" % pack_path)
		return

	var files: Array[String] = []
	collect_files("res://", files)
	files.sort()
	if not validate_file_boundary(files, pack_path):
		return
	if not validate_commercial_class_cache(files):
		return
	if not validate_commercial_resources():
		return
	var provenance := validate_dynamic_documents()
	if provenance.is_empty():
		return

	if not report_path.is_empty():
		var pack_sha256 := FileAccess.get_sha256(pack_path)
		if pack_sha256.length() != 64:
			fail("Could not calculate the exported pack SHA-256: %s" % pack_path)
			return
		var report_file := FileAccess.open(report_path, FileAccess.WRITE)
		if report_file == null:
			fail("Could not create pack inspection report: %s" % report_path)
			return
		var report := {
			"schema_version": REPORT_SCHEMA_VERSION,
			"pack_sha256": pack_sha256,
			"build_provenance": provenance,
		}
		report_file.store_string(JSON.stringify(report, "\t") + "\n")
		report_file.close()

	print(
		"%s: %s (commercial title + formal campaign closure + exact %d-texture and 16-audio candidate sets; no prototype, playtest, tests, tools, or rejected art)"
		% [SUCCESS_MARKER, pack_path, COMMERCIAL_TEXTURES.size()]
	)
	quit(0)
