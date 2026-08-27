class_name AutumnJourneyField
extends JourneySeasonalFieldBase

## Every autumn flower receives a concrete treatment. Taking one portion of honey
## and leaving the flower to set seed are both ordinary neighborhood work; the
## game records the resulting mix without grading it as a moral alignment.

const FLOWER_GOAL := JourneyState.AUTUMN_FLOWER_GOAL
const ECHO_GOAL := JourneyState.AUTUMN_ECHO_GOAL
const THRUSH_STAGE := Vector2(1730.0, 500.0)

var autumn_flowers: Array = []
var echo_points: Array = []
var harvested := 0
var seeded := 0
var echo_points_tuned := 0
var thrush_texture: Texture2D
var seed_shell_texture: Texture2D


func _configure_chapter() -> void:
	segment_id = JourneyState.AUTUMN_HARVEST
	chapter_name = "秋 · 花田收尾"
	world_bounds = Rect2(0.0, 0.0, 2320.0, 1220.0)
	playable_bounds = Rect2(33.0, 123.0, 1914.0, 1064.0)
	home_position = Vector2(235.0, 455.0)
	home_area = Rect2(135.0, 355.0, 190.0, 160.0)
	ground_color = Color("b9b66c")
	path_color = Color("dbc184")
	accent_color = Color("d88147")
	background_texture_path = "res://assets/art/commercial/autumn_world_ground_v1.png"
	message = "每朵花都可收 1 份蜜，也可留着结籽；一朵一朵慢慢收尾。"


func _build_chapter() -> void:
	var thrush_path := "res://assets/art/commercial/thrush_neighbor_states_v3.png"
	if ResourceLoader.exists(thrush_path):
		thrush_texture = ResourceLoader.load(thrush_path, "Texture2D") as Texture2D
	var seed_shell_path := "res://assets/art/commercial/listening_seed_shell_states_v1.png"
	if ResourceLoader.exists(seed_shell_path):
		seed_shell_texture = ResourceLoader.load(seed_shell_path, "Texture2D") as Texture2D
	autumn_flowers = [
		{"position": Vector2(520, 420), "kind": 0, "choice": "", "resolved": false},
		{"position": Vector2(690, 800), "kind": 1, "choice": "", "resolved": false},
		{"position": Vector2(920, 325), "kind": 1, "choice": "", "resolved": false},
		{"position": Vector2(1110, 930), "kind": 0, "choice": "", "resolved": false},
		{"position": Vector2(1325, 560), "kind": 0, "choice": "", "resolved": false},
		{"position": Vector2(1540, 875), "kind": 1, "choice": "", "resolved": false},
		{"position": Vector2(1820, 300), "kind": 0, "choice": "", "resolved": false},
		{"position": Vector2(1930, 760), "kind": 1, "choice": "", "resolved": false},
	]
	echo_points = [
		{"position": Vector2(1510, 400), "resolved": false, "angle": -0.35},
		{"position": Vector2(1900, 820), "resolved": false, "angle": 0.28},
		{"position": Vector2(1940, 430), "resolved": false, "angle": -0.18},
	]


func _process_chapter(_delta: float) -> void:
	if bee.energy <= 0.0:
		bee.environment_speed_multiplier = 0.45
		message = "风凉了，翅膀慢下来；沿着花畦飞，听声种壳还在前头等你。"
	else:
		bee.environment_speed_multiplier = 1.0
	bee.set_visual_load_ratio(float(harvested) / float(FLOWER_GOAL))


func _handle_primary_action() -> void:
	if home_area.has_point(bee.position):
		if _can_complete():
			message = "接货蜂收下 %d 份蜜；%d 朵种头留在秋风里。" % [harvested, seeded]
			_complete_journey({
				"deposit": harvested,
				"harvested": harvested,
				"seeded": seeded,
				"echo_points": echo_points_tuned,
			})
		else:
			message = "花田边还有花在摇，听声坡也少几只转正的种壳。"
		return
	var echo_index := _nearest_point(echo_points, 65.0)
	if echo_index >= 0:
		var echo: Dictionary = echo_points[echo_index]
		echo["resolved"] = true
		echo["angle"] = 0.0
		echo_points[echo_index] = echo
		echo_points_tuned += 1
		sound.play_cue("seed_shell_rustle")
		if echo_points_tuned == ECHO_GOAL:
			message = "三只听声种壳都转正。画眉抖抖尾羽，这回声音稳稳落在花田里。"
		else:
			message = "第 %d 只听声种壳转正；画眉歪着脑袋又听了一遍。" % echo_points_tuned
		return
	var flower_index := _nearest_point(autumn_flowers, 62.0)
	if flower_index >= 0:
		_resolve_flower(flower_index, "harvest")
		return
	bee.trigger_sense()
	message = "空格在花边收蜜、在种壳旁把它转正；Q 在花边留种，离开花边则指向归巢。"


func _handle_secondary_action() -> void:
	var flower_index := _nearest_point(autumn_flowers, 62.0)
	if flower_index >= 0:
		_resolve_flower(flower_index, "seed")
		return
	bee.set_move_target(home_position)
	message = "花还是刚才的样子；左边巢门的方向已经亮起来了。"


func _resolve_flower(flower_index: int, choice: String) -> bool:
	if flower_index < 0 or flower_index >= autumn_flowers.size():
		return false
	var flower: Dictionary = autumn_flowers[flower_index]
	if bool(flower.resolved):
		return false
	flower["resolved"] = true
	flower["choice"] = choice
	autumn_flowers[flower_index] = flower
	if choice == "harvest":
		harvested += 1
		sound.play_cue("harvest")
		message = "收下 1 份成熟花蜜。这里留下短花梗，蜂巢多一份秋储。"
	else:
		seeded += 1
		sound.play_cue("seed")
		message = "这朵留作种头。这里少 1 份秋储，来年多一处花籽。"
	return true


func _can_complete() -> bool:
	return harvested + seeded == FLOWER_GOAL and echo_points_tuned == ECHO_GOAL


func status_snapshot() -> Dictionary:
	var snapshot := _base_snapshot()
	snapshot.merge({
		"area": _area_name_for(bee.position) if bee != null else chapter_name,
		"carried": harvested,
		"capacity": FLOWER_GOAL,
		"flowers_resolved": harvested + seeded,
		"flower_goal": FLOWER_GOAL,
		"harvested": harvested,
		"seeded": seeded,
		"echo_points": echo_points_tuned,
		"echo_goal": ECHO_GOAL,
		"ready_to_return": _can_complete(),
	})
	return snapshot


func _area_name_for(world_position: Vector2) -> String:
	if world_position.x < 760.0:
		return "秋 · 近花畦"
	if world_position.x < 1450.0:
		return "秋 · 种头坡"
	if world_position.y < 650.0:
		return "秋 · 听声坡"
	return "秋 · 种壳坡"


func _draw_chapter() -> void:
	_draw_autumn_flowers()
	_draw_echo_points()
	_draw_thrush_stage()
	if bee != null and bee.sense_time > 0.0:
		for flower in autumn_flowers:
			if not bool(flower.resolved):
				draw_dashed_line(bee.position, Vector2(flower.position), Color("f4d58a", 0.28), 2.0, 22.0)


func _draw_autumn_flowers() -> void:
	for flower in autumn_flowers:
		var pos := Vector2(flower.position)
		var choice := String(flower.choice)
		if choice == "harvest":
			draw_line(pos + Vector2(0, 24), pos + Vector2(0, -10), Color("667447"), 5.0)
			draw_circle(pos + Vector2(0, -13), 8.0, Color("8e7550"))
			continue
		if choice == "seed":
			draw_line(pos + Vector2(0, 28), pos + Vector2(0, -24), Color("667447"), 5.0)
			draw_circle(pos + Vector2(0, -29), 16.0, Color("8f7547"))
			for seed_index in 7:
				var angle := float(seed_index) / 7.0 * TAU
				draw_circle(pos + Vector2.from_angle(angle) * 12.0 + Vector2(0, -29), 2.6, Color("d8bd78"))
			continue
		var petal_color := Color("d88a56") if int(flower.kind) == 0 else Color("b77ca0")
		for petal_index in 8:
			var angle := float(petal_index) / 8.0 * TAU
			draw_circle(pos + Vector2.from_angle(angle) * 17.0, 10.0, petal_color)
		draw_circle(pos, 10.0, Color("e7bd54"))
		draw_arc(pos, 31.0, 0, TAU, 24, Color("fff0b0", 0.42), 2.0)


func _draw_echo_points() -> void:
	for echo_index in echo_points.size():
		var echo: Dictionary = echo_points[echo_index]
		var pos := Vector2(echo.position)
		var angle := float(echo.angle)
		# Keep the loose pod grounded as an ordinary field object, not a floating
		# collectible or something attached to the neighboring bird.
		draw_set_transform(pos + Vector2(4.0, 31.0), angle, Vector2(1.0, 0.34))
		draw_circle(Vector2.ZERO, 34.0, Color("493322", 0.24))
		draw_set_transform(pos, angle)
		if seed_shell_texture != null:
			var frame := 2 if bool(echo.resolved) else echo_index % 2
			var frame_width := float(seed_shell_texture.get_width()) / 3.0
			draw_texture_rect_region(
				seed_shell_texture,
				Rect2(Vector2(-56, -50), Vector2(112, 100)),
				Rect2(frame_width * float(frame), 0.0, frame_width, float(seed_shell_texture.get_height()))
			)
		else:
			# Safe fallback: one ordinary hollow seed pod lying on the ground.
			draw_set_transform(pos, angle, Vector2(1.18, 0.88))
			draw_circle(Vector2.ZERO, 27.0, Color("ad7844"))
			draw_circle(Vector2(-6, 1), 17.0, Color("563a29"))
			draw_arc(Vector2.ZERO, 27.0, -2.8, 2.8, 22, Color("e0b873"), 3.0)
			draw_line(Vector2(18, -18), Vector2(31, -31), Color("755034"), 5.0)
		draw_set_transform(Vector2.ZERO)
		if bool(echo.resolved):
			draw_arc(pos, 45.0 + sin(elapsed * 2.0) * 4.0, -0.8, 0.8, 14, Color("efd38b", 0.48), 3.0)
		else:
			draw_arc(pos, 45.0, 0, TAU, 20, Color("fff0b0", 0.35), 2.0)


func _draw_thrush_stage() -> void:
	var p := THRUSH_STAGE
	var performing := echo_points_tuned == ECHO_GOAL
	var listening := echo_points_tuned > 0 and not performing
	if thrush_texture != null:
		var frame := 2 if performing else (1 if listening else 0)
		var frame_width := float(thrush_texture.get_width()) / 3.0
		draw_texture_rect_region(
			thrush_texture,
			Rect2(p + Vector2(-138, -130), Vector2(276, 260)),
			Rect2(frame_width * float(frame), 0.0, frame_width, float(thrush_texture.get_height()))
		)
		if performing:
			for seed_index in 5:
				var seed_pos := p + Vector2(116.0 + float(seed_index) * 13.0, -25.0 + float(seed_index % 3) * 17.0)
				draw_colored_polygon(PackedVector2Array([
					seed_pos + Vector2(-5, 0), seed_pos + Vector2(0, -3),
					seed_pos + Vector2(7, 0), seed_pos + Vector2(0, 3),
				]), Color("c69b55", 0.82))
		return
	# Safe fallback is an ordinary complete songbird with a compact tail fan.
	draw_colored_polygon(PackedVector2Array([
		p + Vector2(-28, 15), p + Vector2(-93, 33), p + Vector2(-73, 55),
		p + Vector2(-17, 40),
	]), Color("774b32"))
	draw_set_transform(p, -0.08 if listening else 0.03, Vector2(1.16, 0.96))
	draw_circle(Vector2(0, 4), 39.0, Color("814d35"))
	draw_circle(Vector2(6, 1), 33.0, Color("b96d3e"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-19, -12), Vector2(-52, 7), Vector2(-42, 39),
		Vector2(-3, 31), Vector2(13, 4),
	]), Color("77432f"))
	# The folded wing stays visibly feathered without dressing the bird in clothes.
	draw_polyline(PackedVector2Array([
		Vector2(-25, -13), Vector2(-46, 8), Vector2(-38, 36), Vector2(-5, 28),
	]), Color("e0aa59"), 3.0)
	draw_circle(Vector2(34, -23), 21.0, Color("c57b46"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(51, -27), Vector2(72, -20), Vector2(52, -13),
	]), Color("493326"))
	draw_circle(Vector2(41, -28), 4.5, Color("2d2822"))
	draw_circle(Vector2(39.5, -29.5), 1.4, Color("f6e5b6"))
	# An ordinary feathered chest keeps the fallback anatomy comfortable.
	for speck_index in 5:
		var speck_pos := Vector2(5.0 + float(speck_index % 2) * 11.0, -4.0 + float(speck_index) * 6.0)
		draw_circle(speck_pos, 2.6, Color("6f4934", 0.72))
	draw_set_transform(Vector2.ZERO)

	if performing:
		for seed_index in 5:
			var seed_pos := p + Vector2(95.0 + float(seed_index) * 15.0, -22.0 + float(seed_index % 3) * 18.0)
			draw_colored_polygon(PackedVector2Array([
				seed_pos + Vector2(-5, 0), seed_pos + Vector2(0, -3), seed_pos + Vector2(7, 0), seed_pos + Vector2(0, 3),
			]), Color("c69b55", 0.82))
