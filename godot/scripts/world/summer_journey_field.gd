class_name SummerJourneyField
extends JourneySeasonalFieldBase

## Summer is a recovery job, not a second harvesting tutorial. Eight real honey
## portions exist in the world. At most two can be blown loose; lost portions stay
## lost, while the remaining six always keep the chapter completable.

const HONEY_GOAL := JourneyState.SUMMER_HONEY_GOAL
const TOTAL_HONEY := JourneyState.SUMMER_TOTAL_HONEY
const BELONGINGS_GOAL := JourneyState.SUMMER_BELONGINGS_GOAL
const REST_HIVE_POSITION := Vector2(1540.0, 665.0)
const OIL_CRICKET_POSITION := Vector2(1695.0, 720.0)
const STORM_CYCLE := 7.0
const STORM_ACTIVE_TIME := 2.15
const DIRECT_WIND_LANE := Rect2(620.0, 260.0, 1410.0, 360.0)

var honey_pools: Array = []
var belongings: Array = []
var shelters: Array[Rect2] = []
var carried := 0
var recovered_honey := 0
var honey_lost := 0
var belongings_recovered := 0
var rest_hive_repaired := false
var last_loss_cycle := -1
var storm_active := false
var rest_hive_texture: Texture2D
var oil_cricket_texture: Texture2D


func _configure_chapter() -> void:
	segment_id = JourneyState.SUMMER_RECOVERY
	chapter_name = "夏 · 远花路"
	world_bounds = Rect2(0.0, 0.0, 2240.0, 1260.0)
	playable_bounds = Rect2(33.0, 123.0, 1834.0, 1104.0)
	home_position = Vector2(235.0, 470.0)
	home_area = Rect2(135.0, 370.0, 190.0, 165.0)
	ground_color = Color("8fc27b")
	path_color = Color("dec98e")
	accent_color = Color("ecc654")
	background_texture_path = "res://assets/art/commercial/summer_world_ground_v1.png"
	message = "远处有 8 份散落的真花蜜；走长荫路稳，穿直风路快。"


func _build_chapter() -> void:
	var rest_hive_path := "res://assets/art/commercial/rest_hive_exterior_v1.png"
	if ResourceLoader.exists(rest_hive_path):
		rest_hive_texture = ResourceLoader.load(rest_hive_path, "Texture2D") as Texture2D
	var oil_cricket_path := "res://assets/art/commercial/oil_cricket_repairer_states_v2.png"
	if ResourceLoader.exists(oil_cricket_path):
		oil_cricket_texture = ResourceLoader.load(oil_cricket_path, "Texture2D") as Texture2D
	honey_pools = [
		{"position": Vector2(690, 385), "amount": 2, "resolved": false},
		{"position": Vector2(1080, 905), "amount": 2, "resolved": false},
		{"position": Vector2(1715, 345), "amount": 2, "resolved": false},
		{"position": Vector2(1845, 865), "amount": 2, "resolved": false},
	]
	belongings = [
		{"position": Vector2(910, 805), "name": "葫芦杯", "resolved": false},
		{"position": Vector2(1390, 330), "name": "背带", "resolved": false},
		{"position": Vector2(1810, 670), "name": "小工具卷", "resolved": false},
	]
	shelters = [
		Rect2(390, 720, 390, 250),
		Rect2(930, 790, 430, 250),
		Rect2(1480, 760, 430, 260),
		Rect2(1960, 730, 210, 260),
	]


func _process_chapter(delta: float) -> void:
	var cycle_index := floori(elapsed / STORM_CYCLE)
	storm_active = fmod(elapsed, STORM_CYCLE) < STORM_ACTIVE_TIME
	var on_safe_route := _is_in_shelter(bee.position)
	if (
		storm_active
		and DIRECT_WIND_LANE.has_point(bee.position)
		and not on_safe_route
		and carried > 0
		and honey_lost < TOTAL_HONEY - HONEY_GOAL
		and last_loss_cycle != cycle_index
	):
		last_loss_cycle = cycle_index
		carried -= 1
		honey_lost += 1
		sound.play_cue("honey_loss")
		message = "一阵横雨擦过，1 份花蜜实实在在落在路上。余下的还够办完这趟。"
	if rest_hive_repaired and bee.position.distance_to(REST_HIVE_POSITION) <= 112.0:
		bee.energy = minf(bee.max_energy * 0.72, bee.energy + 15.0 * delta)
	if bee.energy <= 0.0:
		bee.environment_speed_multiplier = 0.42
		message = "翅膀累了，仍能慢慢挪到长荫路或修好的小蜂房。"
	else:
		bee.environment_speed_multiplier = 1.0


func _handle_primary_action() -> void:
	if home_area.has_point(bee.position):
		if _can_complete():
			message = "接货蜂一份份接住，油葫芦也把工具卷收回去了。"
			_complete_journey({
				"deposit": carried,
				"recovered_honey": recovered_honey,
				"honey_lost": honey_lost,
				"belongings_recovered": belongings_recovered,
				"rest_hive_repaired": rest_hive_repaired,
			})
		else:
			message = "先把可见的散落物收齐、带回至少 6 份蜜，再把小蜂房修好。"
		return
	var pool_index := _nearest_point(honey_pools, 66.0)
	if pool_index >= 0:
		var pool: Dictionary = honey_pools[pool_index]
		pool["resolved"] = true
		honey_pools[pool_index] = pool
		var amount := int(pool.get("amount", 0))
		carried += amount
		recovered_honey += amount
		sound.play_cue("harvest")
		bee.set_visual_load_ratio(float(carried) / float(TOTAL_HONEY))
		message = "捞回 %d 份真花蜜。现在蜜囊里有 %d 份。" % [amount, carried]
		return
	var belonging_index := _nearest_point(belongings, 62.0)
	if belonging_index >= 0:
		var belonging: Dictionary = belongings[belonging_index]
		belonging["resolved"] = true
		belongings[belonging_index] = belonging
		belongings_recovered += 1
		sound.play_cue("relay")
		message = "油葫芦的%s找到了（%d / %d）。" % [String(belonging.name), belongings_recovered, BELONGINGS_GOAL]
		return
	if bee.position.distance_to(REST_HIVE_POSITION) <= 105.0:
		if rest_hive_repaired:
			bee.energy = minf(bee.max_energy * 0.72, bee.energy + 28.0)
			message = "修好的小蜂房托稳落脚板。货仍要带回主巢。"
		elif belongings_recovered == BELONGINGS_GOAL:
			rest_hive_repaired = true
			sound.play_cue("repair")
			message = "油葫芦摊开工具，修补蜂扶住横梁。小蜂房重新能歇脚了。"
		else:
			message = "工具还散在路上；三件家当收齐，就能一起修小蜂房。"
		return
	bee.trigger_sense()
	message = "风向分成两条：上面近却迎雨，下面绕一点但有叶棚。"


func _handle_secondary_action() -> void:
	bee.set_move_target(home_position)
	message = "先沿长荫路回防；刚捞回的花蜜跟着你一起绕过叶棚。"


func _can_complete() -> bool:
	return (
		recovered_honey == TOTAL_HONEY
		and carried >= HONEY_GOAL
		and belongings_recovered == BELONGINGS_GOAL
		and rest_hive_repaired
	)


func _is_in_shelter(world_position: Vector2) -> bool:
	for shelter in shelters:
		if shelter.has_point(world_position):
			return true
	return false


func status_snapshot() -> Dictionary:
	var snapshot := _base_snapshot()
	snapshot.merge({
		"area": _area_name_for(bee.position) if bee != null else chapter_name,
		"carried": carried,
		"capacity": TOTAL_HONEY,
		"recovered_honey": recovered_honey,
		"honey_goal": HONEY_GOAL,
		"honey_lost": honey_lost,
		"belongings_recovered": belongings_recovered,
		"belongings_goal": BELONGINGS_GOAL,
		"rest_hive_repaired": rest_hive_repaired,
		"storm_active": storm_active,
		"on_safe_route": _is_in_shelter(bee.position) if bee != null else true,
		"ready_to_return": _can_complete(),
	})
	return snapshot


func _area_name_for(world_position: Vector2) -> String:
	if world_position.x < 720.0:
		return "夏 · 巢边回防路"
	if world_position.y > 700.0:
		return "夏 · 长荫路"
	if world_position.x < 1550.0:
		return "夏 · 直风路"
	return "夏 · 油葫芦的远坡"


func _draw_chapter() -> void:
	_draw_shelters()
	_draw_honey_pools()
	_draw_belongings()
	_draw_rest_hive()
	_draw_oil_cricket()
	_draw_storm()


func _draw_shelters() -> void:
	for shelter in shelters:
		draw_dashed_line(
			shelter.position + Vector2(16, shelter.size.y * 0.72),
			shelter.end - Vector2(16, shelter.size.y * 0.28),
			Color("eef0b4", 0.28),
			3.0,
			19.0
		)
		for leaf_index in 5:
			var leaf_pos := shelter.position + Vector2(35.0 + float(leaf_index) * shelter.size.x / 5.5, 28.0)
			_draw_shelter_leaf(leaf_pos, -0.48 + float(leaf_index % 3) * 0.34)


func _draw_shelter_leaf(position: Vector2, angle: float) -> void:
	draw_set_transform(position, angle)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-49, 0), Vector2(-18, -23), Vector2(22, -18), Vector2(52, 0),
		Vector2(19, 22), Vector2(-20, 19),
	]), Color("4f7f43", 0.88))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-35, -3), Vector2(-9, -16), Vector2(24, -12), Vector2(43, -1),
		Vector2(13, 8), Vector2(-18, 8),
	]), Color("79a753", 0.78))
	draw_line(Vector2(-43, 1), Vector2(43, -1), Color("395e36", 0.74), 3.0)
	for vein_index in 3:
		var vein_x := -18.0 + float(vein_index) * 18.0
		draw_line(Vector2(vein_x, 0), Vector2(vein_x + 10, -11), Color("d3d58a", 0.38), 1.5)
	draw_set_transform(Vector2.ZERO)


func _draw_honey_pools() -> void:
	for pool in honey_pools:
		var pos := Vector2(pool.position)
		if bool(pool.resolved):
			draw_circle(pos, 13.0, Color("725b3a", 0.20))
			continue
		draw_circle(pos, 32.0 + sin(elapsed * 2.0 + pos.x) * 2.0, Color("f0cb55", 0.20))
		for portion_index in int(pool.amount):
			draw_circle(pos + Vector2(float(portion_index) * 17.0 - 8.5, 0), 10.0, Color("f5cf54"))
			draw_circle(pos + Vector2(float(portion_index) * 17.0 - 11.0, -3.0), 3.0, Color("fff0a8"))


func _draw_belongings() -> void:
	for item_index in belongings.size():
		var item: Dictionary = belongings[item_index]
		if bool(item.resolved):
			continue
		var pos := Vector2(item.position)
		if item_index == 0:
			draw_circle(pos, 18.0, Color("8b683d"))
			draw_circle(pos, 11.0, ground_color)
		elif item_index == 1:
			draw_arc(pos, 23.0, 0.1, PI * 1.7, 18, Color("725039"), 7.0)
		else:
			draw_rect(Rect2(pos - Vector2(25, 15), Vector2(50, 30)), Color("a45e45"))
			draw_line(pos + Vector2(-20, 0), pos + Vector2(20, 0), Color("e2bd72"), 4.0)
		draw_arc(pos, 35.0, 0, TAU, 24, Color("fff0b0", 0.55), 3.0)


func _draw_rest_hive() -> void:
	var p := REST_HIVE_POSITION
	if rest_hive_texture != null:
		draw_texture_rect(rest_hive_texture, Rect2(p + Vector2(-100, -75), Vector2(200, 150)), false)
		if not rest_hive_repaired:
			draw_line(p + Vector2(-78, -28), p + Vector2(78, 30), Color("654f3d"), 9.0)
		else:
			for glow_index in 3:
				draw_circle(p + Vector2(-46.0 + float(glow_index) * 46.0, 34.0), 5.0, Color("f0c955"))
		return
	var shell := Color("bd9c65") if rest_hive_repaired else Color("847860")
	draw_colored_polygon(PackedVector2Array([
		p + Vector2(-92, -44), p + Vector2(-60, -72),
		p + Vector2(68, -72), p + Vector2(96, -44),
	]), shell.lightened(0.12))
	draw_rect(Rect2(p + Vector2(-78, -43), Vector2(156, 92)), shell)
	for frame_index in 3:
		var frame_x := p.x - 48.0 + float(frame_index) * 48.0
		draw_rect(Rect2(frame_x, p.y - 28.0, 28, 55), Color("5c4d3b"), false, 4.0)
	if not rest_hive_repaired:
		draw_line(p + Vector2(-80, -28), p + Vector2(78, 30), Color("654f3d"), 9.0)
	else:
		for glow_index in 3:
			draw_circle(p + Vector2(-46.0 + float(glow_index) * 46.0, 0), 5.0, Color("f0c955"))


func _draw_oil_cricket() -> void:
	var p := OIL_CRICKET_POSITION
	var hop_offset := Vector2(0, -18.0) if storm_active and not rest_hive_repaired else Vector2.ZERO
	if oil_cricket_texture != null:
		var frame := 2 if rest_hive_repaired else (1 if storm_active else 0)
		var frame_width := float(oil_cricket_texture.get_width()) / 3.0
		draw_texture_rect_region(
			oil_cricket_texture,
			Rect2(p + hop_offset + Vector2(-122, -126), Vector2(244, 244)),
			Rect2(frame_width * float(frame), 0.0, frame_width, float(oil_cricket_texture.get_height()))
		)
		return
	# The abdomen is the tool container: a broad readable vessel rather than a
	# realistic cricket pasted beside unrelated repair props.
	draw_set_transform(p + hop_offset + Vector2(-13, 0), -0.08, Vector2(1.42, 0.92))
	draw_circle(Vector2.ZERO, 31.0, Color("3b2d25"))
	draw_circle(Vector2(-1, -1), 26.0, Color("7f5831"))
	draw_arc(Vector2(-4, -3), 20.0, -2.5, 0.65, 24, Color("c58b46"), 5.0)
	draw_set_transform(p + hop_offset, -0.08)
	for slot_index in 3:
		var slot_x := -35.0 + float(slot_index) * 15.0
		draw_line(Vector2(slot_x, -11), Vector2(slot_x + 2, 12), Color("d9b067"), 4.0)
		if not rest_hive_repaired:
			draw_circle(Vector2(slot_x + 1, -14), 3.0, Color("f0d394"))
	draw_circle(Vector2(31, -2), 17.0, Color("403027"))
	draw_circle(Vector2(36, -6), 3.2, Color("e9c96e"))
	# Long feelers and spring legs carry its always-in-motion work habit.
	draw_polyline(PackedVector2Array([Vector2(40, -10), Vector2(57, -29), Vector2(77, -35)]), Color("4b3428"), 3.0)
	draw_polyline(PackedVector2Array([Vector2(40, 5), Vector2(61, 23), Vector2(79, 27)]), Color("4b3428"), 3.0)
	for side in [-1.0, 1.0]:
		draw_polyline(PackedVector2Array([
			Vector2(-10, side * 16), Vector2(-34, side * 36), Vector2(-57, side * 24),
		]), Color("4b3428"), 5.0)
		draw_polyline(PackedVector2Array([
			Vector2(18, side * 13), Vector2(37, side * 31), Vector2(57, side * 36),
		]), Color("4b3428"), 4.0)
	draw_set_transform(Vector2.ZERO)
	# Three landing beats remain as a small physical gag beside the container body.
	for beat_index in 3:
		draw_arc(p + Vector2(-58.0 - float(beat_index) * 16.0, 38.0), 7.0, 0, PI, 8, Color("6c5137", 0.62), 2.0)


func _draw_storm() -> void:
	if not storm_active:
		return
	for line_index in 18:
		var start := Vector2(640.0 + float((line_index * 137) % 1330), 285.0 + float((line_index * 71) % 300))
		draw_line(start, start + Vector2(-55, 26), Color("d9edf0", 0.48), 4.0)
