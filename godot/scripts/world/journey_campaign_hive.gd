class_name JourneyCampaignHive
extends Node2D

## Persistent-feeling home hub for the formal campaign. Selection lives here,
## while each field remains a disposable PackedScene and must return through the
## receiving line before campaign state can settle.

signal sortie_requested(level_id: String, replay: bool)
signal presentation_finished
signal selection_changed(level: Dictionary)

const HIVE_INTERIOR_PATH := "res://assets/art/commercial/hive_threshold_interior_v1.png"
const WORKER_BEE_PATH := "res://assets/art/commercial/worker_bee_topdown_v1.png"
const MENTOR_BEE_PATH := "res://assets/art/commercial/mentor_bee_topdown_v1.png"
const CLIMAX_RESULT_HERO_PATHS := {
	"spring_guyu": "res://assets/art/commercial/guyu_result_hero_v1.png",
	"summer_dashu": "res://assets/art/commercial/dashu_result_hero_v1.png",
	"autumn_shuangjiang": "res://assets/art/commercial/shuangjiang_result_hero_v1.png",
	"winter_dahan": "res://assets/art/commercial/dahan_result_hero_v1.png",
}
const CLIMAX_RESULT_CAPTIONS := {
	"spring_guyu": "花路重新接上了",
	"summer_dashu": "盛夏的接力稳稳送到了",
	"autumn_shuangjiang": "霜前的收成稳稳入了库",
	"winter_dahan": "最冷的风里，暖路也接上了",
}
const RECEIVING_DURATION := 2.7
const CLIMAX_RECEIVING_DURATION := 3.35
const RESULT_STAGE_RECT := Rect2(976.0, 104.0, 294.0, 606.0)
const SEASON_COLORS := [Color("eaa06f"), Color("e3c452"), Color("c58850"), Color("8eb2b5")]

var context: Dictionary = {}
var level_entries: Array[Dictionary] = []
var selected_level_id := ""
var returning := false
var return_level_id := ""
var return_level_index := -1
var return_replay := false
var reward := 0
var reserve := 0
var completed_count := 0
var total_count := 24
var journey_complete := false
var legacy_journey_completed := false
var legacy_campaign_progress: Dictionary = {}
var next_term_name := ""
var presentation_time := 0.0
var presentation_duration := RECEIVING_DURATION
var presentation_strength: StringName = &"standard"
var reduce_motion := false
var departure_input_enabled := true
var hive_texture: Texture2D
var worker_texture: Texture2D
var mentor_texture: Texture2D
var return_hero_textures: Dictionary = {}
var elapsed := 0.0
var _presentation_audio_started := false
var _audio_director: Node
var _settings_source: Node
var _hero_layer: CanvasLayer
var _hero_root: Control
var _hero_image: TextureRect
var _hero_caption_scrim: ColorRect
var _hero_caption: Label
var _hero_skip_button: Button
var _ui_scale := 1.0


func configure(next_context: Dictionary) -> Error:
	context = next_context.duplicate(true)
	returning = bool(context.get("returning", false))
	return_level_id = String(context.get("return_level_id", ""))
	return_replay = bool(context.get("return_replay", false))
	reward = maxi(0, int(context.get("reward", 0)))
	reserve = maxi(0, int(context.get("reserve", 0)))
	completed_count = maxi(0, int(context.get("completed_count", 0)))
	total_count = maxi(1, int(context.get("total_count", 24)))
	journey_complete = bool(context.get("journey_complete", false))
	legacy_journey_completed = bool(context.get("legacy_journey_completed", false))
	legacy_campaign_progress = Dictionary(context.get("legacy_campaign_progress", {})).duplicate(true)
	var next_level: Dictionary = context.get("next_level", {})
	next_term_name = String(next_level.get("term_name", ""))
	level_entries.clear()
	for raw_entry in context.get("level_entries", []):
		if raw_entry is Dictionary:
			level_entries.append((raw_entry as Dictionary).duplicate(true))
	if level_entries.size() != total_count:
		return ERR_INVALID_DATA
	return_level_index = _entry_index_by_id(return_level_id)
	if returning and return_level_index < 0:
		return ERR_INVALID_DATA
	if return_replay and reward > 0:
		return ERR_INVALID_DATA
	selected_level_id = _default_selection_id()
	var return_entry := entry_by_id(return_level_id)
	presentation_strength = &"climax" if String(return_entry.get("kind", "")) == "climax" else &"standard"
	presentation_duration = CLIMAX_RECEIVING_DURATION if presentation_strength == &"climax" else RECEIVING_DURATION
	presentation_time = presentation_duration if returning else 0.0
	_presentation_audio_started = false
	_refresh_hero_caption()
	if is_inside_tree():
		_ensure_return_hero_overlay()
		_update_return_hero_overlay()
		if returning:
			call_deferred("_ensure_receiving_audio")
	return OK


func _ready() -> void:
	if ResourceLoader.exists(HIVE_INTERIOR_PATH):
		hive_texture = ResourceLoader.load(HIVE_INTERIOR_PATH, "Texture2D") as Texture2D
	if ResourceLoader.exists(WORKER_BEE_PATH):
		worker_texture = ResourceLoader.load(WORKER_BEE_PATH, "Texture2D") as Texture2D
	if ResourceLoader.exists(MENTOR_BEE_PATH):
		mentor_texture = ResourceLoader.load(MENTOR_BEE_PATH, "Texture2D") as Texture2D
	_ensure_return_hero_overlay()
	call_deferred("_bind_accessibility_settings")
	if returning:
		call_deferred("_ensure_receiving_audio")
	queue_redraw()


func _process(delta: float) -> void:
	elapsed += maxf(0.0, delta)
	if presentation_time > 0.0:
		presentation_time = maxf(0.0, presentation_time - delta)
		if presentation_time <= 0.0:
			_finish_receiving_presentation()
	_update_return_hero_overlay()
	queue_redraw()


func _exit_tree() -> void:
	if _settings_source != null and is_instance_valid(_settings_source):
		var callback := Callable(self, "_on_settings_changed")
		if _settings_source.has_signal("settings_changed") and _settings_source.settings_changed.is_connected(callback):
			_settings_source.settings_changed.disconnect(callback)
	if _audio_director != null and is_instance_valid(_audio_director) and _audio_director.has_method("finish_hive_result"):
		_audio_director.finish_hive_result()


func _default_selection_id() -> String:
	for entry in level_entries:
		if bool(entry.get("available", false)) and not bool(entry.get("completed", false)):
			return String(entry.id)
	for index in range(level_entries.size() - 1, -1, -1):
		if bool(level_entries[index].get("completed", false)):
			return String(level_entries[index].id)
	return ""


func select_level(level_id: String) -> bool:
	var entry := entry_by_id(level_id)
	if entry.is_empty() or not bool(entry.get("available", false)):
		return false
	selected_level_id = level_id
	selection_changed.emit(entry)
	queue_redraw()
	return true


func selected_entry() -> Dictionary:
	return entry_by_id(selected_level_id)


func entry_by_id(level_id: String) -> Dictionary:
	for entry in level_entries:
		if String(entry.id) == level_id:
			return entry.duplicate(true)
	return {}


func _entry_index_by_id(level_id: String) -> int:
	for index in level_entries.size():
		if String(level_entries[index].get("id", "")) == level_id:
			return index
	return -1


func request_selected_sortie() -> bool:
	if presentation_time > 0.0:
		skip_receiving_presentation()
		return false
	if not departure_input_enabled:
		return false
	var entry := selected_entry()
	if entry.is_empty() or not bool(entry.get("available", false)):
		return false
	departure_input_enabled = false
	sortie_requested.emit(String(entry.id), bool(entry.get("completed", false)))
	return true


func set_departure_input_enabled(enabled: bool) -> void:
	departure_input_enabled = enabled


func set_reduce_motion(enabled: bool) -> void:
	reduce_motion = enabled
	# Accessibility changes staticize movement immediately, but never rewrite the
	# running clock. Otherwise toggling the option can skip later authored sounds
	# and consume the player's result beat without consent.
	queue_redraw()


func skip_receiving_presentation() -> bool:
	if presentation_time <= 0.0:
		return false
	presentation_time = 0.0
	_finish_receiving_presentation()
	queue_redraw()
	return true


func presentation_progress() -> float:
	if not returning or presentation_duration <= 0.0:
		return 1.0
	return 1.0 - clampf(presentation_time / presentation_duration, 0.0, 1.0)


func presentation_phase() -> StringName:
	var progress := presentation_progress()
	if progress < 0.20:
		return &"arrival"
	if progress < 0.62:
		return &"relay"
	if progress < 0.86:
		return &"store"
	return &"settled"


func result_snapshot() -> Dictionary:
	return {
		"returning": returning,
		"strength": presentation_strength,
		"phase": presentation_phase(),
		"progress": presentation_progress(),
		"motion_scale": 0.0 if reduce_motion else 1.0,
		"visible_stage_rect": RESULT_STAGE_RECT,
		"completed_cell": return_level_index if returning and not return_replay else -1,
		"return_level_index": return_level_index,
		"replay": return_replay,
		"reward": reward,
		"visible_reward_count": visible_reward_count(),
		"reserve": reserve,
		"skippable": presentation_time > 0.0,
	}


func visible_reward_count() -> int:
	return mini(8, reward) if returning and not return_replay else 0


func heading() -> String:
	if returning and presentation_time > 0.0:
		return "接住啦，往里递"
	if journey_complete:
		return "二十四趟，都在巢里有了位置"
	if legacy_journey_completed and completed_count == 0:
		return "旧旅程收在纪念格，新一年从立春出门"
	var selected := selected_entry()
	return "%02d · %s" % [int(selected.get("number", completed_count + 1)), String(selected.get("term_name", "下一趟"))]


func legacy_keepsake_text() -> String:
	## Read-only display text: archived v2 facts never enter the selectable 24-cell
	## board and never award reserve or event completion in the current campaign.
	if legacy_campaign_progress.is_empty():
		return ""
	if journey_complete:
		return "纪念格 · 旧版%d/24封存 · 正式%d/%d完成" % [
			int(legacy_campaign_progress.get("completed_count", 0)),
			completed_count,
			total_count,
		]
	var formal_start := next_term_name if not next_term_name.is_empty() else "下一关"
	return "纪念格 · 旧版%d/24封存 · 正式从%s继续" % [
		int(legacy_campaign_progress.get("completed_count", 0)),
		formal_start,
	]


func body_text() -> String:
	if returning and presentation_time > 0.0:
		var entry := entry_by_id(return_level_id)
		if return_replay:
			return "%s重飞得更顺了。旧记录没有重复发货，最好用时已经照实记下。" % String(entry.get("term_name", "这一关"))
		return "%s这趟的活已经交到接货队手里，%d 格储备亮了起来。" % [String(entry.get("term_name", "刚才")), reward]
	if journey_complete:
		return "花牌、小蜂房、种头、种壳、暖路和挡风墙都还在。新蜂沿你示范的花路飞出去，老师傅在门边说：一会儿巢里见。"
	var selected := selected_entry()
	if selected.is_empty():
		return "接货队照常换班，门外的花路也照常等下一趟。"
	if bool(selected.get("completed", false)):
		return "%s已经完成，可以重飞练路线或刷新最好用时；储备和纪事不会重复增加。" % String(selected.get("term_name", "这关"))
	return String(selected.get("intro", "门外正好有活。看清路线，做完以后真实回到这里交接。"))


func action_text() -> String:
	if presentation_time > 0.0:
		return "按一下，收好这一趟"
	var selected := selected_entry()
	if selected.is_empty():
		return "选择一关"
	return "重飞 %s" % String(selected.get("term_name", "这关")) if bool(selected.get("completed", false)) else "出发去 %s" % String(selected.get("term_name", "下一关"))


func _draw() -> void:
	if hive_texture != null:
		draw_texture_rect(hive_texture, Rect2(0, 0, 1280, 720), false)
	else:
		draw_rect(Rect2(0, 0, 1280, 720), Color("5e5138"))
		draw_rect(Rect2(0, 520, 1280, 200), Color("725536"))
	_draw_campaign_shelves()
	_draw_result_stage()
	_draw_receiving_line()


func _draw_campaign_shelves() -> void:
	# Four low shelves form a season-by-season home record. The actual selection
	# UI overlays these cells, while the world art remains readable without HUD.
	for season_index in 4:
		var shelf_origin := Vector2(70.0, 176.0 + season_index * 90.0)
		draw_rect(Rect2(shelf_origin, Vector2(570, 66)), Color("4b3a2c", 0.28), true)
		draw_line(shelf_origin + Vector2(0, 62), shelf_origin + Vector2(570, 62), Color("d4b474", 0.76), 7.0)
		for term_index in 6:
			var level_index := season_index * 6 + term_index
			var center := shelf_origin + Vector2(48.0 + term_index * 91.0, 31.0)
			var filled := level_index < completed_count
			var selected := level_index < level_entries.size() and String(level_entries[level_index].id) == selected_level_id
			draw_circle(center, 19.0, SEASON_COLORS[season_index] if filled else Color("756b55", 0.46))
			if level_index % 6 == 5:
				draw_arc(center, 26.0, 0.0, TAU, 20, Color("f5e1a1", 0.78), 4.0)
			if selected:
				draw_arc(center, 31.0, 0.0, TAU, 22, Color("fff1a9"), 4.0)


func _draw_receiving_line() -> void:
	var progress := presentation_progress()
	if _uses_return_hero() and progress >= 0.70:
		_draw_bee(Vector2(1026, 576), true)
		_draw_bee(Vector2(1220, 576), false)
	else:
		var bee_count := 7 if presentation_strength == &"climax" and returning else 5
		for index in bee_count:
			_draw_bee(_receiving_bee_position(index, progress), index == 0)
	if not returning:
		return
	var cargo_count := visible_reward_count()
	for cargo_index in cargo_count:
		var cargo_progress := clampf((progress - 0.18 - float(cargo_index) * 0.035) / 0.62, 0.0, 1.0)
		var start := Vector2(1218.0, 433.0)
		var finish := Vector2(1018.0 + float(cargo_index % 4) * 43.0, 635.0 + float(cargo_index / 4) * 19.0)
		var cup := start.lerp(finish, _smoothstep(cargo_progress))
		if reduce_motion:
			cup = finish if cargo_progress >= 0.5 else start
		_draw_honey_cup(cup, 1.0 if reward > 0 else 0.48)


func _draw_result_stage() -> void:
	# The campaign board covers most of the world layer. This rail deliberately
	# occupies the uncovered 304 px on the right, so a return result remains
	# readable without another instruction panel.
	var progress := presentation_progress()
	var focus := sin(clampf(progress, 0.0, 1.0) * PI) if returning and presentation_time > 0.0 else 0.0
	draw_rect(RESULT_STAGE_RECT, Color("2d281f", 0.34 + focus * 0.12), true)
	draw_rect(Rect2(RESULT_STAGE_RECT.position + Vector2(8, 8), RESULT_STAGE_RECT.size - Vector2(16, 16)), Color("f5dfaa", 0.06 + focus * 0.05), true)
	draw_line(Vector2(990, 374), Vector2(1256, 374), Color("e2bd70", 0.54), 3.0)

	var current_cell := return_level_index if returning and not return_replay else -1
	for index in total_count:
		var row := index / 6
		var column := index % 6
		var center := Vector2(1011.0 + float(column) * 43.5, 143.0 + float(row) * 50.0)
		var was_filled := index < completed_count and index != current_cell
		var current_fill := 1.0
		if index == current_cell and presentation_time > 0.0:
			current_fill = clampf((progress - 0.62) / 0.24, 0.0, 1.0)
		var filled := was_filled or (index == current_cell and current_fill > 0.0)
		var color: Color = SEASON_COLORS[clampi(index / 6, 0, 3)]
		draw_circle(center, 10.5, Color(color, (0.28 + current_fill * 0.72) if filled else 0.12))
		draw_arc(center, 12.5, 0.0, TAU, 16, Color("f4dfac", 0.42 if filled else 0.20), 2.0)
		if index % 6 == 5:
			draw_arc(center, 16.5, 0.0, TAU, 18, Color("f8d889", 0.66), 2.0)
		if index == current_cell and returning:
			var mark_alpha := 1.0 if presentation_time <= 0.0 else clampf((progress - 0.74) / 0.18, 0.0, 1.0)
			draw_line(center + Vector2(-5, 0), center + Vector2(-1, 5), Color("fff0b2", mark_alpha), 2.5)
			draw_line(center + Vector2(-1, 5), center + Vector2(7, -5), Color("fff0b2", mark_alpha), 2.5)

	# A broad paper shutter gives climax returns one extra composition beat. It is
	# a physical layer sliding aside, not a glow, aura, or supernatural effect.
	if returning and presentation_strength == &"climax" and not reduce_motion and progress < 0.42:
		var shutter_height := lerpf(92.0, 0.0, _smoothstep(progress / 0.42))
		draw_rect(Rect2(990, 374, 266, shutter_height), Color("7a5132", 0.78), true)
		for fold in 5:
			draw_line(Vector2(1000 + fold * 51, 380), Vector2(1000 + fold * 51, 374 + shutter_height), Color("d0a56b", 0.38), 2.0)
	var return_hero_texture := _return_hero_texture()
	if _uses_return_hero() and return_hero_texture != null:
		draw_texture_rect(return_hero_texture, Rect2(994, 390, 260, 146), false, Color("ffffff", 0.94))
		draw_rect(Rect2(994, 390, 260, 146), Color("f4d68b", 0.74), false, 3.0)

	# The low tray stays after the animation: dots are the delivered reward, while
	# a replay uses a tied route card instead of pretending it created new stock.
	draw_rect(Rect2(994, 612, 260, 70), Color("5c422c", 0.72), true)
	draw_rect(Rect2(1000, 619, 248, 52), Color("b9864d", 0.24), true)
	if returning and return_replay:
		draw_rect(Rect2(1086, 629, 76, 28), Color("e9d6a6", 0.80), true)
		draw_line(Vector2(1098, 643), Vector2(1148, 643), Color("8d6c3f", 0.76), 3.0)
		draw_circle(Vector2(1158, 643), 5.0, Color("bd7352", 0.88))


func _receiving_bee_position(index: int, progress: float) -> Vector2:
	var resting_positions := [
		Vector2(1218, 425), Vector2(1170, 472), Vector2(1124, 512), Vector2(1076, 548),
		Vector2(1028, 580), Vector2(1198, 548), Vector2(1144, 586),
	]
	var target: Vector2 = resting_positions[clampi(index, 0, resting_positions.size() - 1)]
	if not returning or presentation_time <= 0.0 or reduce_motion:
		return target
	var arrival := clampf((progress - float(index) * 0.025) / 0.30, 0.0, 1.0)
	var start := target + Vector2(105.0 + float(index % 2) * 26.0, -54.0)
	var position := start.lerp(target, _smoothstep(arrival))
	if progress > 0.30:
		position.y += sin((progress - 0.30) * TAU * 2.0 + float(index) * 0.8) * (3.5 if presentation_strength == &"standard" else 6.0)
	return position


func _draw_honey_cup(position: Vector2, alpha: float) -> void:
	draw_rect(Rect2(position - Vector2(9, 3), Vector2(18, 9)), Color("9c6d3b", alpha))
	draw_circle(position - Vector2(0, 4), 5.5, Color("f0c95e", alpha))


func _smoothstep(value: float) -> float:
	var safe := clampf(value, 0.0, 1.0)
	return safe * safe * (3.0 - 2.0 * safe)


func _draw_bee(position: Vector2, mentor: bool) -> void:
	var texture := mentor_texture if mentor else worker_texture
	if texture == null:
		draw_circle(position, 12.0, Color("e2b84b"))
		draw_line(position - Vector2(8, 0), position + Vector2(8, 0), Color("403329"), 4.0)
		return
	var rotation := 0.0 if reduce_motion else sin(elapsed * 1.7 + position.x) * 0.08
	draw_set_transform(position, rotation, Vector2(0.50, 0.50))
	draw_texture_rect(texture, Rect2(-50, -42, 100, 84), false)
	draw_set_transform(Vector2.ZERO)


func _finish_receiving_presentation() -> void:
	presentation_time = 0.0
	if _audio_director != null and is_instance_valid(_audio_director) and _audio_director.has_method("finish_hive_result"):
		_audio_director.finish_hive_result()
	_update_return_hero_overlay()
	presentation_finished.emit()


func _ensure_receiving_audio() -> void:
	if not returning or presentation_time <= 0.0 or _presentation_audio_started:
		return
	_audio_director = _find_named_ancestor_child("JourneyAudioDirector")
	if _audio_director == null or not _audio_director.has_method("begin_hive_result"):
		return
	_presentation_audio_started = true
	_audio_director.begin_hive_result(presentation_strength == &"climax", reduce_motion)


func _bind_accessibility_settings() -> void:
	var campaign_root := get_parent()
	if campaign_root != null:
		campaign_root = campaign_root.get_parent()
	if campaign_root != null and _has_property(campaign_root, &"persistence"):
		_settings_source = campaign_root.get("persistence") as Node
	if _settings_source == null or not is_instance_valid(_settings_source):
		return
	if _settings_source.has_method("settings_snapshot"):
		_on_settings_changed(_settings_source.settings_snapshot())
	if _settings_source.has_signal("settings_changed"):
		var callback := Callable(self, "_on_settings_changed")
		if not _settings_source.settings_changed.is_connected(callback):
			_settings_source.settings_changed.connect(callback)


func _on_settings_changed(next_settings: Dictionary) -> void:
	set_ui_scale(float(next_settings.get("ui_scale", 1.0)))
	set_reduce_motion(bool(next_settings.get("reduce_motion", false)))


func set_ui_scale(value: float) -> void:
	_ui_scale = clampf(value, 0.9, 1.3)
	if _hero_caption != null:
		_hero_caption.add_theme_font_size_override("font_size", roundi(30.0 * _ui_scale))


func _find_named_ancestor_child(node_name: String) -> Node:
	var ancestor := get_parent()
	while ancestor != null:
		var candidate := ancestor.get_node_or_null(NodePath(node_name))
		if candidate != null:
			return candidate
		ancestor = ancestor.get_parent()
	return null


func _uses_return_hero() -> bool:
	return (
		returning
		and not return_replay
		and presentation_strength == &"climax"
		and CLIMAX_RESULT_HERO_PATHS.has(return_level_id)
		and return_level_index >= 0
		and completed_count == return_level_index + 1
	)


func _return_hero_texture() -> Texture2D:
	return return_hero_textures.get(return_level_id) as Texture2D


func _ensure_return_hero_overlay() -> void:
	if not _uses_return_hero():
		return
	var hero_path := String(CLIMAX_RESULT_HERO_PATHS.get(return_level_id, ""))
	if not return_hero_textures.has(return_level_id) and ResourceLoader.exists(hero_path):
		return_hero_textures[return_level_id] = ResourceLoader.load(hero_path, "Texture2D") as Texture2D
	var return_hero_texture := _return_hero_texture()
	if return_hero_texture == null:
		return
	if _hero_layer == null:
		_build_return_hero_overlay()
	elif _hero_image != null:
		_hero_image.texture = return_hero_texture
	_refresh_hero_caption()


func _build_return_hero_overlay() -> void:
	var return_hero_texture := _return_hero_texture()
	if _hero_layer != null or return_hero_texture == null:
		return
	_hero_layer = CanvasLayer.new()
	_hero_layer.name = "SeasonalResultHeroLayer"
	_hero_layer.layer = 40
	add_child(_hero_layer)
	_hero_root = Control.new()
	_hero_root.name = "SeasonalResultHero"
	_hero_root.position = Vector2.ZERO
	_hero_root.size = Vector2(1280, 720)
	_hero_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hero_layer.add_child(_hero_root)
	var backdrop := ColorRect.new()
	backdrop.position = Vector2.ZERO
	backdrop.size = Vector2(1280, 720)
	backdrop.color = Color("171b18", 1.0)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hero_root.add_child(backdrop)
	_hero_image = TextureRect.new()
	_hero_image.texture = return_hero_texture
	_hero_image.position = Vector2.ZERO
	_hero_image.size = Vector2(1280, 720)
	_hero_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hero_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_hero_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hero_root.add_child(_hero_image)
	_hero_caption_scrim = ColorRect.new()
	_hero_caption_scrim.name = "SeasonalResultCaptionScrim"
	_hero_caption_scrim.position = Vector2(44, 526)
	_hero_caption_scrim.size = Vector2(1192, 174)
	_hero_caption_scrim.color = Color("17140f", 0.68)
	_hero_caption_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hero_root.add_child(_hero_caption_scrim)
	_hero_caption = Label.new()
	_hero_caption.position = Vector2(86, 558)
	_hero_caption.size = Vector2(1108, 128)
	_hero_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hero_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hero_caption.add_theme_color_override("font_color", Color("fff1bd"))
	_hero_caption.add_theme_color_override("font_shadow_color", Color("16140f", 0.86))
	_hero_caption.add_theme_constant_override("shadow_offset_x", 2)
	_hero_caption.add_theme_constant_override("shadow_offset_y", 2)
	_hero_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hero_root.add_child(_hero_caption)
	set_ui_scale(_ui_scale)
	_refresh_hero_caption()
	_hero_skip_button = Button.new()
	_hero_skip_button.name = "SkipSeasonalResultHero"
	_hero_skip_button.position = Vector2.ZERO
	_hero_skip_button.size = Vector2(1280, 720)
	_hero_skip_button.flat = true
	_hero_skip_button.self_modulate = Color(1, 1, 1, 0)
	_hero_skip_button.focus_mode = Control.FOCUS_NONE
	# Confirm on down so the release cannot land on the story modal that this
	# result reveal creates synchronously.
	_hero_skip_button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	_hero_skip_button.tooltip_text = "收好这一趟"
	_hero_skip_button.pressed.connect(skip_receiving_presentation)
	_hero_root.add_child(_hero_skip_button)
	_hero_layer.visible = false


func _refresh_hero_caption() -> void:
	if _hero_caption == null:
		return
	if return_level_index < 0:
		_hero_caption.text = ""
		return
	var entry := entry_by_id(return_level_id)
	var result_caption := String(CLIMAX_RESULT_CAPTIONS.get(return_level_id, "这一季的活稳稳收好了"))
	_hero_caption.text = "%s · %s\n第 %d / %d 趟收好 · 按互动键继续" % [
		String(entry.get("term_name", "本季收尾")),
		result_caption,
		return_level_index + 1,
		total_count,
	]


func _update_return_hero_overlay() -> void:
	if _hero_layer == null or _hero_root == null or _hero_image == null:
		return
	var should_show := _uses_return_hero() and presentation_time > 0.0
	_hero_layer.visible = should_show
	if not should_show:
		return
	var progress := presentation_progress()
	var alpha := 1.0
	if not reduce_motion:
		alpha = minf(clampf(progress / 0.12, 0.0, 1.0), clampf((1.0 - progress) / 0.10, 0.0, 1.0))
		var zoom := lerpf(1.0, 1.035, _smoothstep(progress))
		_hero_image.size = Vector2(1280, 720) * zoom
		_hero_image.position = (Vector2(1280, 720) - _hero_image.size) * 0.5
	else:
		_hero_image.position = Vector2.ZERO
		_hero_image.size = Vector2(1280, 720)
	_hero_root.modulate = Color(1, 1, 1, alpha)


func _has_property(object: Object, property_name: StringName) -> bool:
	for property in object.get_property_list():
		if StringName(property.get("name", "")) == property_name:
			return true
	return false
