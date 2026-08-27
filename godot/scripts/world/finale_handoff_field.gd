class_name FinaleHandoffField
extends JourneySeasonalFieldBase

## A playable hand-off, not an epilogue slideshow. The mentor steps aside, the
## player demonstrates the same-form pollen route to a new bee, then says the
## title phrase directly. No prophecy or hidden identity is introduced.

const MENTOR_POSITION := Vector2(470.0, 430.0)
const NEW_BEE_POSITION := Vector2(555.0, 505.0)
const DONOR_POSITION := Vector2(930.0, 330.0)
const STIGMA_POSITION := Vector2(1320.0, 675.0)

var demonstration_steps := 0
var pollen_taken := false
var pollen_delivered := false
var phrase_spoken := false
var mentor_line := "老师傅往旁边让了让：这回你来。"
var spoken_line := ""


func _configure_chapter() -> void:
	segment_id = JourneyState.FINALE_HANDOFF
	chapter_name = "巢前 · 交棒"
	world_bounds = Rect2(0.0, 0.0, 1720.0, 980.0)
	playable_bounds = Rect2(33.0, 123.0, 1314.0, 824.0)
	home_position = Vector2(235.0, 455.0)
	home_area = Rect2(135.0, 355.0, 190.0, 160.0)
	ground_color = Color("a9c985")
	path_color = Color("e4d09b")
	accent_color = Color("e8bd4f")
	# The last lesson happens on the same spring ground as the first one. Reusing
	# that authored place is a concrete neighborhood return, not a mystical loop.
	background_texture_path = "res://assets/art/commercial/spring_world_ground_v1.png"
	message = mentor_line


func _build_chapter() -> void:
	pass


func _process_chapter(_delta: float) -> void:
	if bee.energy <= 0.0:
		bee.environment_speed_multiplier = 0.48
	else:
		bee.environment_speed_multiplier = 1.0


func _handle_primary_action() -> void:
	if bee.position.distance_to(DONOR_POSITION) <= 68.0:
		if pollen_taken:
			message = "散粉已经在身上。下一步是那朵同形开放花心。"
			return
		pollen_taken = true
		demonstration_steps = maxi(demonstration_steps, 1)
		bee.set_pollen_loads([1, 0])
		sound.play_cue("harvest")
		message = "你放慢一点，让新蜂看清散粉怎样落在身上。"
		return
	if bee.position.distance_to(STIGMA_POSITION) <= 68.0:
		if not pollen_taken:
			message = "先从同形花药带一点散粉过来；这朵花心一直开着等。"
			return
		if pollen_delivered:
			message = "这朵已经接到散粉。现在回到新蜂身边。"
			return
		pollen_delivered = true
		demonstration_steps = maxi(demonstration_steps, 2)
		bee.set_pollen_loads([0, 0])
		sound.play_cue("pollinate")
		message = "散粉落进同形花心。你把动作放得很慢，新蜂这回看清了。"
		return
	if bee.position.distance_to(NEW_BEE_POSITION) <= 78.0:
		if not pollen_delivered:
			message = "新蜂头上还顶着花片，认真看着。先把完整动作做给它看。"
			return
		demonstration_steps = 3
		phrase_spoken = true
		spoken_line = "一会儿巢里见。"
		sound.play_cue("handoff")
		message = "你把归巢方向指给它：%s" % spoken_line
		_complete_journey({
			"deposit": 0,
			"demonstration_steps": demonstration_steps,
			"phrase_spoken": phrase_spoken,
		})
		return
	bee.trigger_sense()
	message = "示范清单：取同形散粉、送进开放花心、回到新蜂身边。"


func _handle_secondary_action() -> void:
	if pollen_delivered:
		bee.set_move_target(NEW_BEE_POSITION)
		message = "新蜂在老师傅旁边等着最后一个归巢方向。"
	else:
		bee.set_move_target(DONOR_POSITION if not pollen_taken else STIGMA_POSITION)
		message = "新蜂顺着你指的方向看过去，安静等着下一步。"


func status_snapshot() -> Dictionary:
	var snapshot := _base_snapshot()
	snapshot.merge({
		"area": chapter_name,
		"carried": 0,
		"capacity": 0,
		"demonstration_steps": demonstration_steps,
		"demonstration_goal": 3,
		"pollen_taken": pollen_taken,
		"pollen_delivered": pollen_delivered,
		"returned_to_new_bee": phrase_spoken,
		"mentor_line": mentor_line,
		"spoken_line": spoken_line,
	})
	return snapshot


func _draw_chapter() -> void:
	_draw_flower(DONOR_POSITION, false, pollen_taken)
	_draw_flower(STIGMA_POSITION, true, pollen_delivered)
	_draw_mentor()
	_draw_new_bee()
	if pollen_taken and not pollen_delivered:
		draw_dashed_line(DONOR_POSITION, STIGMA_POSITION, Color("f5d65f", 0.55), 4.0, 24.0)
	elif pollen_delivered:
		draw_dashed_line(STIGMA_POSITION, NEW_BEE_POSITION, Color("f1dfa4", 0.42), 3.0, 24.0)


func _draw_flower(position: Vector2, receptive: bool, completed: bool) -> void:
	var petals := Color("d99bb0") if not receptive else Color("e1a8b7")
	if completed:
		petals = petals.darkened(0.18)
	for petal_index in 8:
		var angle := float(petal_index) / 8.0 * TAU
		draw_circle(position + Vector2.from_angle(angle) * 25.0, 14.0, petals)
	draw_circle(position, 14.0, Color("efc953"))
	if receptive and not completed:
		draw_circle(position, 7.0, Color("6da4ac"))
	if not receptive and not completed:
		for grain_index in 5:
			var angle := float(grain_index) / 5.0 * TAU
			draw_circle(position + Vector2.from_angle(angle) * 11.0, 3.0, Color("f6dc68"))


func _draw_mentor() -> void:
	var p := MENTOR_POSITION
	draw_set_transform(p, -0.08)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-8, -5), Vector2(-35, -27), Vector2(-1, -23), Vector2(9, -8),
	]), Color("d4ddd6", 0.72))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-8, 5), Vector2(-35, 27), Vector2(-1, 23), Vector2(9, 8),
	]), Color("d4ddd6", 0.72))
	draw_circle(Vector2(-4, 0), 18.0, Color("b99045"))
	draw_circle(Vector2(18, 0), 12.0, Color("665841"))
	draw_line(Vector2(-12, -12), Vector2(-12, 12), Color("514536"), 5.0)
	draw_set_transform(Vector2.ZERO)
	# The mentor is physically behind the player-new bee line: posture communicates
	# that the job has been handed over without sacrifice or disappearance.
	draw_line(p + Vector2(-20, 36), p + Vector2(-45, 52), Color("6b5b45", 0.48), 3.0)


func _draw_new_bee() -> void:
	var p := NEW_BEE_POSITION
	draw_set_transform(p, 0.12)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-5, -4), Vector2(-22, -17), Vector2(-2, -19), Vector2(7, -7),
	]), Color("edf3eb", 0.82))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-5, 4), Vector2(-22, 17), Vector2(-2, 19), Vector2(7, 7),
	]), Color("edf3eb", 0.82))
	draw_circle(Vector2(0, 0), 13.0, Color("e4b94a"))
	draw_circle(Vector2(15, 0), 9.0, Color("6d5635"))
	draw_line(Vector2(-5, -10), Vector2(-5, 10), Color("44372c"), 4.0)
	# A loose petal repeats the opening gag and makes the learner role readable.
	draw_colored_polygon(PackedVector2Array([
		Vector2(12, -11), Vector2(18, -24), Vector2(27, -13), Vector2(19, -7),
	]), Color("f2a6bc"))
	draw_set_transform(Vector2.ZERO)
