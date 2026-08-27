class_name WinterJourneyField
extends JourneySeasonalFieldBase

## Winter replaces combat pressure with route warmth. Reaching zero warmth slows
## the bee but never removes input or an objective, so the player can always crawl
## to a shelter. The bear and repair workers visibly share the windbreak job.

const WARMTH_GOAL := JourneyState.WINTER_WARMTH_GOAL
const WINDBREAK_GOAL := JourneyState.WINTER_WINDBREAK_GOAL
const BEAR_POSITION := Vector2(1835.0, 820.0)
const WALL_ORIGIN := Vector2(1580.0, 650.0)

var warmth_posts: Array = []
var logs: Array = []
var safe_route_sections: Array[Rect2] = []
var warmth := 100.0
var warmth_links := 0
var windbreak_segments := 0
var bear_helped := false
var bear_action_time := 0.0
var bear_texture: Texture2D


func _configure_chapter() -> void:
	segment_id = JourneyState.WINTER_WARMTH
	chapter_name = "冬 · 续暖路"
	world_bounds = Rect2(0.0, 0.0, 2220.0, 1280.0)
	playable_bounds = Rect2(33.0, 123.0, 1814.0, 1124.0)
	home_position = Vector2(235.0, 480.0)
	home_area = Rect2(135.0, 380.0, 190.0, 165.0)
	ground_color = Color("b8c9c1")
	path_color = Color("d6c89e")
	accent_color = Color("d9a74f")
	background_texture_path = "res://assets/art/commercial/winter_world_ground_v1.png"
	message = "四处续暖点和三段挡风木从开局都可见；叶棚路慢一点，但暖得久。"


func _build_chapter() -> void:
	var bear_path := "res://assets/art/commercial/bear_helper_states_v1.png"
	if ResourceLoader.exists(bear_path):
		bear_texture = ResourceLoader.load(bear_path, "Texture2D") as Texture2D
	warmth_posts = [
		{"position": Vector2(560, 790), "resolved": false},
		{"position": Vector2(980, 930), "resolved": false},
		{"position": Vector2(1430, 850), "resolved": false},
		{"position": Vector2(1850, 650), "resolved": false},
	]
	logs = [
		{"position": Vector2(770, 370), "resolved": false, "heavy": false},
		{"position": Vector2(1330, 350), "resolved": false, "heavy": false},
		{"position": Vector2(1810, 875), "resolved": false, "heavy": true},
	]
	safe_route_sections = [
		Rect2(350, 675, 430, 250),
		Rect2(780, 805, 440, 260),
		Rect2(1215, 720, 440, 280),
		Rect2(1630, 560, 430, 280),
	]


func _process_chapter(delta: float) -> void:
	bear_action_time = maxf(0.0, bear_action_time - delta)
	var sheltered := _on_safe_route(bee.position)
	var near_lit_post := false
	for post in warmth_posts:
		if bool(post.resolved) and bee.position.distance_to(Vector2(post.position)) <= 125.0:
			near_lit_post = true
			break
	if near_lit_post:
		warmth = minf(100.0, warmth + 20.0 * delta)
		bee.energy = minf(bee.max_energy * 0.76, bee.energy + 11.0 * delta)
	else:
		warmth = maxf(0.0, warmth - (1.35 if sheltered else 5.6) * delta)
	if warmth <= 0.0 or bee.energy <= 0.0:
		bee.environment_speed_multiplier = 0.40
		if warmth <= 0.0:
			message = "身上不暖了，仍能慢慢飞。最近的叶棚和续暖点一直留在地图上。"
	else:
		bee.environment_speed_multiplier = 1.0


func _handle_primary_action() -> void:
	if home_area.has_point(bee.position):
		if _can_complete():
			message = "挡风墙立稳，四段暖路接成一条。大家一起收工。"
			_complete_journey({
				"deposit": 0,
				"warmth_links": warmth_links,
				"windbreak_segments": windbreak_segments,
				"bear_helped": bear_helped,
			})
		else:
			message = "还有续暖点或挡风木没接上；它们没有被风雪藏起来。"
		return
	var post_index := _nearest_point(warmth_posts, 70.0)
	if post_index >= 0:
		var post: Dictionary = warmth_posts[post_index]
		post["resolved"] = true
		warmth_posts[post_index] = post
		warmth_links += 1
		warmth = minf(100.0, warmth + 32.0)
		sound.play_cue("warmth_link")
		message = "第 %d 段暖路续上。修补蜂把下一只蜡罩递过来。" % warmth_links
		return
	var log_index := _nearest_point(logs, 82.0)
	if log_index >= 0:
		var log_item: Dictionary = logs[log_index]
		log_item["resolved"] = true
		logs[log_index] = log_item
		windbreak_segments += 1
		sound.play_cue("carry_log")
		if bool(log_item.heavy):
			bear_helped = true
			bear_action_time = 1.25
			message = "大熊打了个哈欠，翻起最沉的木段；修补蜂在两边把绳扣收紧。"
		else:
			message = "修补蜂一前一后搬稳木段（%d / %d）。" % [windbreak_segments, WINDBREAK_GOAL]
		return
	bee.trigger_sense()
	message = "下面叶棚路是安全长路；上面雪线更近，也更快散掉暖意。"


func _handle_secondary_action() -> void:
	bee.set_move_target(home_position)
	message = "沿已经接亮的暖路回巢；修补蜂在挡风墙边等着一起收工。"


func _can_complete() -> bool:
	return warmth_links == WARMTH_GOAL and windbreak_segments == WINDBREAK_GOAL and bear_helped


func _on_safe_route(world_position: Vector2) -> bool:
	for section in safe_route_sections:
		if section.has_point(world_position):
			return true
	return false


func status_snapshot() -> Dictionary:
	var snapshot := _base_snapshot()
	snapshot.merge({
		"area": _area_name_for(bee.position) if bee != null else chapter_name,
		"carried": 0,
		"capacity": 0,
		"warmth": roundi(warmth),
		"warmth_links": warmth_links,
		"warmth_goal": WARMTH_GOAL,
		"windbreak_segments": windbreak_segments,
		"windbreak_goal": WINDBREAK_GOAL,
		"bear_helped": bear_helped,
		"on_safe_route": _on_safe_route(bee.position) if bee != null else true,
		"ready_to_return": _can_complete(),
	})
	return snapshot


func _area_name_for(world_position: Vector2) -> String:
	if world_position.x < 700.0:
		return "冬 · 第一段暖路"
	if world_position.x < 1450.0:
		return "冬 · 叶棚长路"
	if world_position.y < 570.0:
		return "冬 · 迎风雪线"
	return "冬 · 大熊木场"


func _draw_chapter() -> void:
	_draw_safe_route()
	_draw_warmth_posts()
	_draw_logs_and_wall()
	_draw_bear()
	_draw_wind()


func _draw_safe_route() -> void:
	for section in safe_route_sections:
		draw_dashed_line(
			section.position + Vector2(12, section.size.y * 0.70),
			section.end - Vector2(12, section.size.y * 0.30),
			Color("fff4cf", 0.30),
			3.0,
			20.0
		)
		if seasonal_work_props_texture != null:
			var shelter_position := section.position + Vector2(section.size.x * 0.5 - 78.0, -8.0)
			_draw_work_prop(0, Rect2(shelter_position, Vector2(156, 118)))
		else:
			for cover_index in 4:
				var cover_pos := section.position + Vector2(50.0 + float(cover_index) * section.size.x / 4.5, 28.0)
				_draw_snow_leaf(cover_pos, -0.42 + float(cover_index % 3) * 0.31)


func _draw_snow_leaf(position: Vector2, angle: float) -> void:
	draw_set_transform(position, angle)
	draw_line(Vector2(-2, 8), Vector2(-2, 70), Color("5c654f"), 7.0)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-46, 0), Vector2(-16, -23), Vector2(22, -18), Vector2(49, 1),
		Vector2(17, 22), Vector2(-20, 18),
	]), Color("68785f", 0.90))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-40, -3), Vector2(-13, -27), Vector2(21, -22), Vector2(42, -6),
		Vector2(18, -7), Vector2(-13, -10),
	]), Color("f0eee1", 0.88))
	draw_line(Vector2(-38, 1), Vector2(39, 0), Color("465442", 0.72), 2.5)
	draw_set_transform(Vector2.ZERO)


func _draw_warmth_posts() -> void:
	for post in warmth_posts:
		var pos := Vector2(post.position)
		if seasonal_work_props_texture != null:
			var tint := Color.WHITE if bool(post.resolved) else Color("777a72")
			_draw_work_prop(1, Rect2(pos + Vector2(-48, -67), Vector2(96, 118)), tint)
			if bool(post.resolved):
				draw_arc(pos + Vector2(0, -15), 36.0 + sin(elapsed * 2.4) * 2.0, -2.5, 0.65, 18, Color("f8df94", 0.40), 3.0)
			else:
				draw_arc(pos + Vector2(0, -15), 38.0, 0, TAU, 20, Color("ffffff", 0.28), 2.0)
			continue
		draw_line(pos + Vector2(0, 32), pos + Vector2(0, -24), Color("684b36"), 8.0)
		draw_colored_polygon(PackedVector2Array([
			pos + Vector2(-23, -20), pos + Vector2(-13, -37), pos + Vector2(0, -45),
			pos + Vector2(14, -36), pos + Vector2(23, -19), pos + Vector2(13, 9), pos + Vector2(-14, 9),
		]), Color("9a7047"))
		draw_colored_polygon(PackedVector2Array([
			pos + Vector2(-13, -18), pos + Vector2(-7, -29), pos + Vector2(0, -34),
			pos + Vector2(8, -28), pos + Vector2(13, -17), pos + Vector2(7, 2), pos + Vector2(-8, 2),
		]), Color("d6b46e" if bool(post.resolved) else "746a59"))
		for rib_index in 3:
			var rib_x := -9.0 + float(rib_index) * 9.0
			draw_line(pos + Vector2(rib_x, -25), pos + Vector2(rib_x * 0.7, 1), Color("634a35", 0.75), 1.8)
		if bool(post.resolved):
			draw_circle(pos + Vector2(0, -15), 7.0, Color("f2c65b"))
			draw_arc(pos + Vector2(0, -15), 29.0 + sin(elapsed * 2.4) * 2.0, -2.5, 0.65, 18, Color("f8df94", 0.34), 3.0)
		else:
			draw_circle(pos + Vector2(0, -15), 6.0, Color("554f48"))
			draw_dashed_line(pos + Vector2(-29, 18), pos + Vector2(29, 18), Color("ffffff", 0.30), 2.0, 7.0)


func _draw_logs_and_wall() -> void:
	for log_index in logs.size():
		var log_item: Dictionary = logs[log_index]
		if bool(log_item.resolved):
			var wall_pos := WALL_ORIGIN + Vector2(float(log_index) * 78.0, float(log_index % 2) * 45.0)
			if seasonal_work_props_texture != null:
				_draw_work_prop(2, Rect2(wall_pos + Vector2(-75, -63), Vector2(150, 120)))
			else:
				_draw_bark_log(wall_pos, 108.0, -0.56)
				draw_arc(wall_pos, 21.0, -0.4, 1.2, 12, Color("d3b56d"), 4.0)
			_draw_worker_bee(wall_pos + Vector2(-54, 33), 0.54)
			_draw_worker_bee(wall_pos + Vector2(-4, -48), 0.54)
		else:
			var pos := Vector2(log_item.position)
			var width := 125.0 if bool(log_item.heavy) else 92.0
			_draw_bark_log(pos, width, -0.35)
			draw_arc(pos, 47.0 if bool(log_item.heavy) else 37.0, 0, TAU, 22, Color("fff5cd", 0.20), 2.0)


func _draw_bark_log(position: Vector2, width: float, angle: float) -> void:
	draw_set_transform(position, angle)
	draw_rect(Rect2(-width * 0.5, -12, width, 24), Color("6c4933"))
	draw_rect(Rect2(-width * 0.5 + 4, -7, width - 8, 7), Color("9b7048"))
	for knot_index in 3:
		var knot_x := -width * 0.3 + float(knot_index) * width * 0.28
		draw_arc(Vector2(knot_x, 1), 4.0, 0, TAU, 10, Color("493529", 0.72), 1.5)
	draw_circle(Vector2(-width * 0.5, 0), 12.0, Color("b48655"))
	draw_circle(Vector2(-width * 0.5, 0), 6.0, Color("745038"), false, 2.0)
	draw_circle(Vector2(width * 0.5, 0), 12.0, Color("a8784b"))
	draw_circle(Vector2(width * 0.5, 0), 6.0, Color("745038"), false, 2.0)
	draw_set_transform(Vector2.ZERO)


func _draw_bear() -> void:
	var p := BEAR_POSITION if not bear_helped else WALL_ORIGIN + Vector2(180, 145)
	if bear_texture != null:
		var frame := 1 if bear_action_time > 0.0 else (2 if bear_helped else 0)
		draw_texture_rect_region(
			bear_texture,
			Rect2(p + Vector2(-115, -105), Vector2(230, 210)),
			Rect2(float(frame) * 256.0, 0.0, 256.0, 256.0)
		)
		return
	draw_circle(p, 55.0, Color("80654f"))
	draw_circle(p + Vector2(42, -24), 34.0, Color("95765a"))
	draw_circle(p + Vector2(27, -51), 13.0, Color("765b47"))
	draw_circle(p + Vector2(54, -54), 13.0, Color("765b47"))
	draw_circle(p + Vector2(55, -24), 5.0, Color("493c32"))
	if not bear_helped:
		draw_arc(p + Vector2(38, -28), 12.0, 0.2, PI - 0.2, 10, Color("493c32"), 3.0)
	else:
		draw_line(p + Vector2(-30, 30), p + Vector2(-85, 4), Color("80654f"), 25.0)


func _draw_wind() -> void:
	for wind_index in 14:
		var start := Vector2(520.0 + float((wind_index * 151) % 1500), 220.0 + float((wind_index * 67) % 330))
		draw_line(start, start + Vector2(-70, 13), Color("eef7f4", 0.38 + 0.08 * sin(elapsed * 2.1 + wind_index)), 4.0)
