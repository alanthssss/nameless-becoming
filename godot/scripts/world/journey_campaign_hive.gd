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
const RECEIVING_DURATION := 1.8
const SEASON_COLORS := [Color("eaa06f"), Color("e3c452"), Color("c58850"), Color("8eb2b5")]

var context: Dictionary = {}
var level_entries: Array[Dictionary] = []
var selected_level_id := ""
var returning := false
var return_level_id := ""
var reward := 0
var reserve := 0
var completed_count := 0
var total_count := 24
var journey_complete := false
var legacy_journey_completed := false
var presentation_time := 0.0
var departure_input_enabled := true
var hive_texture: Texture2D
var worker_texture: Texture2D
var mentor_texture: Texture2D
var elapsed := 0.0


func configure(next_context: Dictionary) -> Error:
	context = next_context.duplicate(true)
	returning = bool(context.get("returning", false))
	return_level_id = String(context.get("return_level_id", ""))
	reward = maxi(0, int(context.get("reward", 0)))
	reserve = maxi(0, int(context.get("reserve", 0)))
	completed_count = maxi(0, int(context.get("completed_count", 0)))
	total_count = maxi(1, int(context.get("total_count", 24)))
	journey_complete = bool(context.get("journey_complete", false))
	legacy_journey_completed = bool(context.get("legacy_journey_completed", false))
	level_entries.clear()
	for raw_entry in context.get("level_entries", []):
		if raw_entry is Dictionary:
			level_entries.append((raw_entry as Dictionary).duplicate(true))
	if level_entries.size() != total_count:
		return ERR_INVALID_DATA
	selected_level_id = _default_selection_id()
	presentation_time = RECEIVING_DURATION if returning else 0.0
	return OK


func _ready() -> void:
	if ResourceLoader.exists(HIVE_INTERIOR_PATH):
		hive_texture = ResourceLoader.load(HIVE_INTERIOR_PATH, "Texture2D") as Texture2D
	if ResourceLoader.exists(WORKER_BEE_PATH):
		worker_texture = ResourceLoader.load(WORKER_BEE_PATH, "Texture2D") as Texture2D
	if ResourceLoader.exists(MENTOR_BEE_PATH):
		mentor_texture = ResourceLoader.load(MENTOR_BEE_PATH, "Texture2D") as Texture2D
	queue_redraw()


func _process(delta: float) -> void:
	elapsed += maxf(0.0, delta)
	if presentation_time > 0.0:
		presentation_time = maxf(0.0, presentation_time - delta)
		if presentation_time <= 0.0:
			presentation_finished.emit()
	queue_redraw()


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


func request_selected_sortie() -> bool:
	if not departure_input_enabled or presentation_time > 0.0:
		return false
	var entry := selected_entry()
	if entry.is_empty() or not bool(entry.get("available", false)):
		return false
	departure_input_enabled = false
	sortie_requested.emit(String(entry.id), bool(entry.get("completed", false)))
	return true


func set_departure_input_enabled(enabled: bool) -> void:
	departure_input_enabled = enabled


func heading() -> String:
	if returning and presentation_time > 0.0:
		return "接住啦，往里递"
	if journey_complete:
		return "二十四趟，都在巢里有了位置"
	if legacy_journey_completed and completed_count == 0:
		return "旧旅程收在纪念格，新一年从立春出门"
	var selected := selected_entry()
	return "%02d · %s" % [int(selected.get("number", completed_count + 1)), String(selected.get("term_name", "下一趟"))]


func body_text() -> String:
	if returning and presentation_time > 0.0:
		var entry := entry_by_id(return_level_id)
		if reward > 0:
			return "%s这趟的活已经交到接货队手里，%d 格储备亮了起来。" % [String(entry.get("term_name", "刚才")), reward]
		return "%s重飞得更顺了。旧记录没有重复发货，最好用时已经照实记下。" % String(entry.get("term_name", "这一关"))
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
		return "接货中…"
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
	var progress := 1.0 - clampf(presentation_time / RECEIVING_DURATION, 0.0, 1.0)
	for index in 5:
		var resting := Vector2(735.0 + index * 98.0, 560.0 - float(index % 2) * 28.0)
		var position := resting
		if returning and presentation_time > 0.0:
			position = Vector2(1090.0 - index * 110.0, 450.0 + sin(progress * TAU + index) * 10.0)
		_draw_bee(position, index == 0)
	if returning and presentation_time > 0.0:
		for cup_index in mini(4, maxi(1, reward)):
			var cup := Vector2(1010.0 - cup_index * 105.0, 450.0)
			draw_rect(Rect2(cup - Vector2(9, 3), Vector2(18, 9)), Color("b78a4c"))
			draw_circle(cup - Vector2(0, 4), 5.0, Color("f0c95e"))


func _draw_bee(position: Vector2, mentor: bool) -> void:
	var texture := mentor_texture if mentor else worker_texture
	if texture == null:
		draw_circle(position, 12.0, Color("e2b84b"))
		draw_line(position - Vector2(8, 0), position + Vector2(8, 0), Color("403329"), 4.0)
		return
	draw_set_transform(position, sin(elapsed * 1.7 + position.x) * 0.08, Vector2(0.58, 0.58))
	draw_texture_rect(texture, Rect2(-50, -42, 100, 84), false)
	draw_set_transform(Vector2.ZERO)
