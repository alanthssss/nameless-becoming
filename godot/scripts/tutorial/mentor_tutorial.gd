class_name MentorTutorial
extends RefCounted

## In-world teaching director: demonstrate, ask for one evidenced imitation,
## then remove the ribbon and require a second real result. Demonstrations are
## ghosts only; they never change nectar, energy, enemies or progression.

const SHOWCASE_STAGES := [0, 7, 13, 19]
const INDIGO := Color("69758f")
const SILVER_WING := Color("dce3df")
const HONEY := Color("f0ca59")
const MENTOR_SCALE := 0.82
const PollenVisualLanguageScript := preload("res://scripts/mechanics/pollen_visual_language.gd")

var main
var profile_id := ""
var lesson_id := ""
var phase := "inactive" # inactive / demo / imitate / practice / complete
var demo_time := 0.0
var demo_duration := 0.0
var mentor_position := Vector2.ZERO
var demo_start := Vector2.ZERO
var demo_target := Vector2.ZERO
var baseline_delivered := 0
var first_evade_seen := false
var seed_practice_baseline := 0
var seed_seen_decisions := 0
var seed_active_flower := -1
var pollination_demo_variant := -1
var pollination_demo_source_index := -1
var pollination_demo_target_index := -1
var practice_flower_id := 8800
var seed_practice_flower_id := 8810

func configure(game) -> void:
	main = game

func start_stage(index: int, data: Dictionary) -> void:
	profile_id = String(data.get("tutorial_profile", ""))
	lesson_id = ""
	phase = "inactive"
	first_evade_seen = false
	seed_practice_baseline = 0
	seed_seen_decisions = 0
	seed_active_flower = -1
	pollination_demo_variant = -1
	pollination_demo_source_index = -1
	pollination_demo_target_index = -1
	if profile_id.is_empty() or not SHOWCASE_STAGES.has(index):
		return
	if index == 0 and bool(main.tutorial_complete):
		profile_id = ""
		return
	match profile_id:
		"first_trip_pollination":
			_start_lesson("sortie")
		"raid_intro":
			_start_lesson("raid")
		"seed_intro":
			_start_lesson("seed")
		"warmth_intro":
			_start_lesson("warmth")

func process(delta: float) -> void:
	if phase == "inactive" or phase == "complete":
		return
	if phase == "demo":
		demo_time = maxf(0.0, demo_time - delta)
		_update_demo_position()
		if demo_time <= 0.0:
			phase = "imitate"
			main.bee.active = true
		return
	match profile_id:
		"first_trip_pollination":
			_process_first_trip()
		"raid_intro":
			_process_raid()
		"seed_intro":
			_process_seed()
		"warmth_intro":
			_process_warmth()

func blocks_simulation() -> bool:
	return phase == "demo"

func owns_guidance() -> bool:
	return phase not in ["inactive", "complete"]

func can_complete_stage() -> bool:
	return profile_id.is_empty() or phase == "complete"

func allows_action(action_id: String) -> bool:
	if phase == "demo":
		return false
	if profile_id == "raid_intro" and phase == "imitate" and action_id == "seasonal":
		return _nearest_raider_has_stolen_honey()
	if profile_id != "first_trip_pollination" or phase in ["inactive", "complete"]:
		return true
	match lesson_id:
		"sortie":
			return action_id in ["move", "harvest", "return"]
		"sense":
			return action_id in (["move", "sense"] if phase == "imitate" else ["move", "harvest", "return"])
		"defense":
			return action_id in ["move", "repel", "return", "drink"]
		"evade":
			return action_id in ["move", "evade", "return", "drink"]
		"pollination":
			return action_id in ["move", "harvest", "seasonal", "return"]
	return true

func notify_event(event_id: String, _payload := {}) -> String:
	if profile_id != "first_trip_pollination":
		return "ignored"
	if lesson_id == "defense" and event_id == "resource_cleared":
		if phase == "imitate":
			phase = "practice"
			return "repeat_without_prompt"
		if phase == "practice":
			main.tutorial_step = 5
			_start_lesson("evade")
			return "advance"
	if lesson_id == "evade" and event_id == "attack_evaded":
		if phase == "imitate" and not first_evade_seen:
			first_evade_seen = true
			phase = "practice"
			return "repeat_without_prompt"
		if phase == "practice":
			main.tutorial_step = 6
			_start_lesson("pollination")
			return "advance"
	return "ignored"

func prompt() -> Dictionary:
	if not owns_guidance():
		return {"visible": false, "title": "", "body": ""}
	if phase == "practice":
		return {"visible": false, "title": "", "body": ""}
	var title := "先看老师傅" if phase == "demo" else "轮到你"
	if lesson_id == "evade":
		title = "先看急转" if phase == "demo" else "轮到你 · 同向 × 2"
	var body := ""
	match lesson_id:
		"sortie":
			body = "看它贴近花心，停在那里直到蜜囊 +1，再落回亮着的巢门。" if phase == "demo" else "贴近花心，等右侧“按住采蜜”亮起；按住空格 / 回车，蜜囊 +1 后松开，再按 Q 归巢。"
		"sense":
			body = "它先停稳，再让花粉沿着气味找到藏花。" if phase == "demo" else "停稳寻迹，让藏花真正出现。"
		"defense":
			body = "它靠近占花者振翅，直到花与敌之间重新拉开距离。" if phase == "demo" else "把占花者真正推出资源区。"
		"evade":
			body = "虚线会跟随，亮起的实线才是锁定路线；老师傅向可行的一侧连飞两次。" if phase == "demo" else "实线停住后，沿一个亮色侧标同向连按两次（鼠标点同侧两次）；冲刺穿过旧位置才算成功。"
		"pollination":
			body = "先从花心带走散粉，再到同花型花心传粉。" if phase == "demo" else "让第一朵同花型花心开始结籽。"
		"raid":
			body = "蜜被抢走后再惊退，蜜滴才会落回原来的花。" if phase == "demo" else "先归巢引出袭扰；等它偷蜜后再惊退。"
		"seed":
			body = "最后一滴露出种核时松手；归巢会让留下的种子成熟。" if phase == "demo" else "在种核前松手，并用一次真实归巢让它成熟。"
		"warmth":
			body = "带一滴蜜到蜂蜡灯旁，点亮后再向远花推进。" if phase == "demo" else "亲自点亮第一盏蜂蜡灯。"
	return {"visible": true, "title": title, "body": body}

func draw() -> void:
	if phase != "demo" or main == null:
		return
	if lesson_id not in ["evade", "pollination"]:
		main.draw_dashed_line(demo_start, demo_target, Color(HONEY, 0.30), 2.0, 8.0)
	_draw_lesson_ghosts()
	if main.colony_bee_texture == null:
		return
	var facing_vector := _mentor_facing_vector()
	var facing := facing_vector.angle()
	main.draw_set_transform(main.field_draw_offset + mentor_position, facing, Vector2(MENTOR_SCALE, MENTOR_SCALE))
	main.draw_texture_rect(main.colony_bee_texture, Rect2(-34, -24, 68, 48), false, Color("d6ddd7"))
	# One indigo wing binding distinguishes the elder without introducing a hat,
	# portrait or another illustration style.
	main.draw_line(Vector2(-10, -13), Vector2(11, 13), INDIGO, 5.0)
	main.draw_circle(Vector2(-16, -17), 4.0, SILVER_WING)
	if lesson_id == "pollination" and pollination_demo_visual_phase() == "carry":
		PollenVisualLanguageScript.draw_cluster(
			main,
			PollenVisualLanguageScript.load_slot(pollination_demo_variant),
			pollination_demo_variant,
			1,
			1.18
		)
	main.draw_set_transform(main.field_draw_offset)


func _mentor_facing_vector() -> Vector2:
	var facing_vector := demo_target - mentor_position
	if lesson_id == "evade":
		var progress := 1.0 - clampf(demo_time / maxf(0.01, demo_duration), 0.0, 1.0)
		var lock_target := demo_start.lerp(demo_target, 0.55)
		facing_vector = Vector2.UP if progress >= 0.58 else lock_target - mentor_position
	if facing_vector.length_squared() < 0.01:
		return Vector2.RIGHT
	return facing_vector


func _mentor_load_world(variant: int) -> Vector2:
	var local_slot: Vector2 = PollenVisualLanguageScript.load_slot(variant) * MENTOR_SCALE
	return mentor_position + local_slot.rotated(_mentor_facing_vector().angle())

func _process_first_trip() -> void:
	match lesson_id:
		"sortie":
			if phase == "imitate" and int(main.tutorial_step) >= 3:
				phase = "practice"
				baseline_delivered = int(main.delivered)
				_add_sortie_practice_flower()
			elif phase == "practice" and int(main.delivered) > baseline_delivered:
				_start_lesson("sense")
		"sense":
			if phase == "imitate" and bool(main.tutorial_scent_revealed):
				phase = "practice"
			elif phase == "practice" and int(main.tutorial_step) >= 4:
				_start_lesson("defense")
		"pollination":
			var pollination = main.season_mechanics.mechanic_by_id("pollination")
			if pollination == null:
				return
			if phase == "imitate" and int(pollination.pollinated_flowers) >= 1:
				phase = "practice"
			elif phase == "practice" and int(pollination.pollinated_flowers) >= 2:
				phase = "complete"
				main._complete_contextual_tutorial()

func _process_raid() -> void:
	var raid = main.season_mechanics.mechanic_by_id("conscription")
	if raid == null:
		return
	var event: Dictionary = raid.latched_event()
	if phase == "imitate" and String(event.get("id", "")) == "honey_return":
		phase = "practice"
	elif phase == "practice" and String(raid.state) == "cleared":
		phase = "complete"

func _process_seed() -> void:
	var reserve = main.season_mechanics.mechanic_by_id("reserve")
	if reserve == null:
		return
	var decisions := int(reserve.seeds_matured) + int(reserve.seeds_lost)
	if phase == "imitate" and int(reserve.seeds_matured) >= 1:
		phase = "practice"
		seed_practice_baseline = decisions
		seed_seen_decisions = decisions
		_unlock_next_seed_flower()
	elif phase == "imitate" and decisions > seed_seen_decisions:
		# Taking the last drop is a visible failed choice, not a permanent tutorial
		# lock. Keep the prompt and expose a fresh seed flower for another attempt.
		seed_seen_decisions = decisions
		_unlock_next_seed_flower()
	elif phase == "practice" and decisions > seed_practice_baseline:
		phase = "complete"
		_unlock_all_seed_flowers()

func _process_warmth() -> void:
	var huddle = main.season_mechanics.mechanic_by_id("huddle")
	if huddle == null:
		return
	if phase == "imitate" and int(huddle.activated_points) >= 1:
		phase = "practice"
	elif phase == "practice" and int(huddle.activated_points) >= int(huddle.warm_points.size()):
		phase = "complete"

func _start_lesson(id: String) -> void:
	lesson_id = id
	phase = "demo"
	main.bee.active = false
	demo_duration = 2.8
	match id:
		"sortie":
			demo_start = main.HIVE_RETURN_POS
			demo_target = Vector2(main.flowers[0].position)
			demo_duration = 3.4
		"sense":
			demo_start = Vector2(365, 420)
			demo_target = Vector2(main.flowers[main.tutorial_hidden_index].position)
		"defense":
			demo_start = main.tutorial_resource_position + Vector2(-115, 35)
			demo_target = main.tutorial_resource_position
		"evade":
			demo_start = Vector2(main.bee.position)
			demo_target = demo_start + Vector2(180, -30)
		"pollination":
			var pollination = main.season_mechanics.mechanic_by_id("pollination")
			for flower_index in main.flowers.size():
				var unlocked_flower: Dictionary = main.flowers[flower_index]
				unlocked_flower["tutorial_locked"] = false
				main.flowers[flower_index] = unlocked_flower
			if pollination != null and not pollination.donor_indices.is_empty() and not pollination.receptive_indices.is_empty():
				var source_index := int(pollination.donor_indices[0])
				for candidate in pollination.donor_indices:
					if int(main.flowers[candidate].get("nectar", 0)) > 0:
						source_index = int(candidate)
						break
				var source_variant := int(main.flowers[source_index].get("pollen_variant", -1))
				var receptive_index := int(pollination.receptive_indices[0])
				for candidate in pollination.receptive_indices:
					if int(main.flowers[candidate].get("stigma_variant", -1)) == source_variant:
						receptive_index = int(candidate)
						break
				pollination_demo_variant = source_variant
				pollination_demo_source_index = source_index
				pollination_demo_target_index = receptive_index
				demo_start = Vector2(main.flowers[source_index].position)
				demo_target = Vector2(main.flowers[receptive_index].position)
			else:
				demo_start = Vector2(315, 410)
				demo_target = Vector2(430, 565)
			demo_duration = 3.2
		"raid":
			demo_start = Vector2(520, 410)
			demo_target = Vector2(main.WORLD.end.x - 75.0, 330)
		"seed":
			_prepare_seed_lesson()
			demo_start = Vector2(main.flowers[0].position) + Vector2(-85, 0)
			demo_target = Vector2(main.flowers[seed_active_flower].position) if seed_active_flower >= 0 else Vector2(main.flowers[0].position)
		"warmth":
			var huddle = main.season_mechanics.mechanic_by_id("huddle")
			demo_start = main.HIVE_RETURN_POS
			demo_target = Vector2(huddle.warm_points[0].position) if huddle != null and not huddle.warm_points.is_empty() else Vector2(450, 300)
	demo_time = demo_duration
	mentor_position = demo_start

func _update_demo_position() -> void:
	var progress := 1.0 - clampf(demo_time / maxf(0.01, demo_duration), 0.0, 1.0)
	if lesson_id == "sortie":
		if progress < 0.42:
			mentor_position = demo_start.lerp(demo_target, progress / 0.42)
		elif progress < 0.68:
			mentor_position = demo_target + Vector2(0, sin(progress * 32.0) * 3.0)
		else:
			mentor_position = demo_target.lerp(demo_start, (progress - 0.68) / 0.32)
	elif lesson_id == "evade":
		var lock_target := demo_start.lerp(demo_target, 0.55)
		if progress < 0.45:
			mentor_position = demo_start.lerp(lock_target, progress / 0.45)
		elif progress < 0.58:
			mentor_position = lock_target
		else:
			var sidestep := clampf((progress - 0.58) / 0.20, 0.0, 1.0)
			mentor_position = lock_target + Vector2(0, -95.0 * sidestep)
	elif lesson_id == "pollination":
		# Four embodied beats: collect at the anther, carry a persistent body load,
		# stop beside the compatible stigma, then release one grain into it.
		var staging_position := demo_target + Vector2(-42, 20)
		if progress < 0.22:
			mentor_position = demo_start
		elif progress < 0.68:
			mentor_position = demo_start.lerp(staging_position, (progress - 0.22) / 0.46)
		else:
			mentor_position = staging_position
	else:
		var travel := clampf(progress / 0.70, 0.0, 1.0)
		mentor_position = demo_start.lerp(demo_target, travel)
		if progress > 0.70:
			mentor_position.y += sin(progress * 34.0) * 3.0

func _add_sortie_practice_flower() -> void:
	for flower in main.flowers:
		if int(flower.get("id", -1)) == practice_flower_id:
			return
	main.flowers.append({
		"id": practice_flower_id,
		"position": Vector2(330, 540),
		"nectar": 1,
		"max_nectar": 1,
		"kind": 0,
		"visual_variant": 0,
		"large_bloom": false,
		"phase": 0.0,
		"recovery": false,
		"type": "first_bloom",
		"mentor_practice": true
	})
	main.message = "老师傅退到一旁。照刚才的路线，再独立走一趟。"

func _prepare_seed_lesson() -> void:
	seed_active_flower = -1
	for i in main.flowers.size():
		if bool(main.flowers[i].get("showcase_seed", false)):
			seed_active_flower = i
			break
	if seed_active_flower < 0 and not main.flowers.is_empty():
		seed_active_flower = 0
	for i in main.flowers.size():
		var flower: Dictionary = main.flowers[i]
		flower["tutorial_locked"] = i != seed_active_flower
		main.flowers[i] = flower

func _unlock_next_seed_flower() -> void:
	var next_index := -1
	# Prefer the second authored two-drop flower; fall back to any unresolved
	# flower, so even a deliberate failed choice cannot exhaust the lesson.
	for prefer_showcase in [true, false]:
		for i in main.flowers.size():
			if i == seed_active_flower:
				continue
			var flower: Dictionary = main.flowers[i]
			if bool(flower.get("seeded", false)) or bool(flower.get("seed_lost", false)):
				continue
			if prefer_showcase and not bool(flower.get("showcase_seed", false)):
				continue
			next_index = i
			break
		if next_index >= 0:
			break
	if next_index < 0:
		next_index = _add_seed_practice_flower()
	seed_active_flower = next_index
	for i in main.flowers.size():
		var flower: Dictionary = main.flowers[i]
		flower["tutorial_locked"] = i != seed_active_flower
		main.flowers[i] = flower

func _add_seed_practice_flower() -> int:
	var new_index: int = int(main.flowers.size())
	main.flowers.append({
		"id": seed_practice_flower_id + new_index,
		"position": main.find_spaced_flower_position(82.0),
		"nectar": 2,
		"max_nectar": 2,
		"kind": 1,
		"visual_variant": 1,
		"large_bloom": true,
		"phase": 0.0,
		"recovery": false,
		"type": "seed_bloom",
		"showcase_seed": true,
		"seed_ready": false,
		"seeded": false,
		"seed_lost": false,
		"seed_release_required": false,
		"seed_final_armed": false,
		"tutorial_locked": false
	})
	return new_index

func _unlock_all_seed_flowers() -> void:
	for i in main.flowers.size():
		var flower: Dictionary = main.flowers[i]
		flower["tutorial_locked"] = false
		main.flowers[i] = flower

func _nearest_raider_has_stolen_honey() -> bool:
	if main == null or main.season_mechanics == null:
		return false
	var raid = main.season_mechanics.mechanic_by_id("conscription")
	if raid == null:
		return false
	var nearest := int(raid.nearest_raider_at(main.bee.position))
	if nearest < 0 or nearest >= raid.raid_ants.size():
		return false
	return int(raid.raid_ants[nearest].get("stolen", 0)) > 0

func _draw_lesson_ghosts() -> void:
	var progress := 1.0 - clampf(demo_time / maxf(0.01, demo_duration), 0.0, 1.0)
	match lesson_id:
		"sortie":
			# The first harvest has a real dwell time. Show nectar converging while
			# the elder waits, then carry one embodied honey drop home; neither cue
			# changes resources or leaves another target ring in the field.
			if progress >= 0.42 and progress < 0.68:
				var gather_progress := clampf((progress - 0.42) / 0.26, 0.0, 1.0)
				for mote in 6:
					var angle := float(mote) * TAU / 6.0 + _demo_rotation()
					var radius := lerpf(28.0, 5.0, gather_progress)
					var pos := demo_target + Vector2.from_angle(angle) * radius
					main.draw_circle(pos, 2.2 + gather_progress, Color(HONEY, 0.48 + gather_progress * 0.40))
			elif progress >= 0.68:
				var drop := mentor_position + Vector2(0, 19)
				main.draw_colored_polygon(PackedVector2Array([
					drop + Vector2(0, -6), drop + Vector2(-4, 1),
					drop + Vector2(0, 6), drop + Vector2(4, 1)
				]), Color(HONEY, 0.90))
		"sense":
			for mote in 6:
				var ratio := fmod(progress * 0.65 + float(mote) / 6.0, 1.0)
				var pos := demo_start.lerp(demo_target, ratio)
				pos.y -= sin(ratio * PI) * 20.0
				main.draw_circle(pos, 2.5 + ratio, Color(HONEY, 0.38 + ratio * 0.40))
		"pollination":
			var visual_phase := pollination_demo_visual_phase()
			if visual_phase == "pickup":
				var pickup_progress := clampf(progress / 0.22, 0.0, 1.0)
				for mote in 4:
					var angle := float(mote) * TAU / 4.0 + _demo_rotation()
					var radius := lerpf(24.0, 5.0, pickup_progress)
					PollenVisualLanguageScript.draw_grain(
						main,
						demo_start + Vector2.from_angle(angle) * radius,
						pollination_demo_variant,
						0.62 + pickup_progress * 0.28,
						0.82
					)
			elif visual_phase == "transfer":
				var transfer_progress := clampf((progress - 0.68) / 0.20, 0.0, 1.0)
				var source := _mentor_load_world(pollination_demo_variant)
				var grain_position := source.lerp(demo_target, transfer_progress)
				grain_position.y -= sin(transfer_progress * PI) * 12.0
				PollenVisualLanguageScript.draw_grain(main, grain_position, pollination_demo_variant, 0.95, 0.96)
			elif visual_phase == "seed":
				main.draw_colored_polygon(PackedVector2Array([
					demo_target + Vector2(0, -11), demo_target + Vector2(-8, -3),
					demo_target + Vector2(-6, 9), demo_target + Vector2(0, 14),
					demo_target + Vector2(6, 9), demo_target + Vector2(8, -3)
				]), Color("86a85f", 0.92))
				for seed in 3:
					main.draw_circle(demo_target + Vector2(0, -3 + seed * 5), 2.2, Color("f3d474"))
		"defense":
			var ghost := demo_target + Vector2(20, -6)
			for ray in 4:
				var angle := float(ray) * TAU / 4.0
				main.draw_line(ghost + Vector2.from_angle(angle) * 17.0, ghost + Vector2.from_angle(angle) * 30.0, Color(HONEY, 0.62), 3.0)
		"raid":
			var ghost := demo_target + Vector2(20, -6)
			main.draw_circle(ghost, 12.0, Color("7b4d45", 0.70))
			for ray in 4:
				var angle := float(ray) * TAU / 4.0
				main.draw_line(ghost + Vector2.from_angle(angle) * 17.0, ghost + Vector2.from_angle(angle) * 30.0, Color(HONEY, 0.62), 3.0)
		"evade":
			var lock_target := demo_start.lerp(demo_target, 0.55)
			var attack_origin := lock_target + Vector2(190, 0)
			var attack_direction := Vector2.LEFT
			if progress < 0.45:
				var tracking_direction := (mentor_position - attack_origin).normalized()
				main.draw_dashed_line(attack_origin, attack_origin + tracking_direction * 430.0, Color("d95d54", 0.42), 3.0, 12.0)
			else:
				main.draw_committed_attack_corridor(attack_origin, attack_direction, lock_target, 36.0, 0.72, progress < 0.76)
			var attacker := attack_origin
			if progress > 0.58:
				var dash_progress := clampf((progress - 0.58) / 0.34, 0.0, 1.0)
				attacker = attack_origin.lerp(lock_target - Vector2(110, 0), dash_progress)
				main.draw_line(attacker + Vector2(65, 0), attacker, Color(HONEY, 0.78), 6.0)
			if main.spring_mosquito_texture != null:
				main.draw_set_transform(main.field_draw_offset + attacker, attack_direction.angle())
				main.draw_texture_rect(main.spring_mosquito_texture, Rect2(-34, -24, 68, 48), false, Color.WHITE)
				main.draw_set_transform(main.field_draw_offset)
			else:
				main.draw_circle(attacker, 12.0, Color("d95d54", 0.90))
			main.draw_circle(lock_target, 11.0, Color(INDIGO, 0.18))
		"seed":
			var pod := demo_target + Vector2(0, -24)
			main.draw_colored_polygon(PackedVector2Array([
				pod + Vector2(0, -12), pod + Vector2(-9, -2),
				pod + Vector2(0, 12), pod + Vector2(9, -2)
			]), Color("c99b43", 0.82))
			for seed in 3:
				main.draw_circle(pod + Vector2(0, -5 + seed * 5), 2.5, HONEY)
		"warmth":
			var lamp := demo_target
			main.draw_line(lamp + Vector2(0, 8), lamp + Vector2(0, -14), Color("5a4936"), 4.0)
			main.draw_colored_polygon(PackedVector2Array([
				lamp + Vector2(0, -29), lamp + Vector2(-7, -14),
				lamp + Vector2(0, -8), lamp + Vector2(7, -14)
				]), Color("f6a43d", 0.84))


func pollination_demo_visual_phase() -> String:
	if lesson_id != "pollination" or phase != "demo" or demo_duration <= 0.0:
		return "inactive"
	var progress := 1.0 - clampf(demo_time / demo_duration, 0.0, 1.0)
	if progress < 0.22:
		return "pickup"
	if progress < 0.68:
		return "carry"
	if progress < 0.88:
		return "transfer"
	return "seed"

func _demo_rotation() -> float:
	return (1.0 - clampf(demo_time / maxf(0.01, demo_duration), 0.0, 1.0)) * TAU * 1.5
