class_name ReserveMechanic
extends RefCounted
## 秋 · 留种取舍。
## 花剩最后一滴时会显出种核。此时停手并带着别处的蜜归巢，种核成熟为
## 公共储备；继续把最后一滴采走则永久失去这颗种子。收益发生在野外行为
## 之后，而不只存在于关末滑块。

var mechanic_id := "reserve"
var main
var pending_allocation := false
var pending_harvest := 0
var larvae_per_boost := 10
var boost_energy_cap := 5
var seed_reward_reserve := 2
var seeds_matured := 0
var seeds_lost := 0


func start(game, _data: Dictionary, balance: Dictionary) -> void:
	main = game
	var mechanics: Dictionary = balance.get("mechanics", {})
	var params: Dictionary = mechanics.get("reserve", {})
	larvae_per_boost = int(params.get("larvae_per_boost", 10))
	boost_energy_cap = int(params.get("boost_energy_cap", 5))
	seed_reward_reserve = int(params.get("seed_reward_reserve", 2))
	pending_allocation = false
	pending_harvest = 0
	seeds_matured = 0
	seeds_lost = 0
	for i in main.flowers.size():
		var flower: Dictionary = main.flowers[i]
		flower["seed_ready"] = false
		flower["seeded"] = false
		flower["seed_lost"] = false
		flower["seed_release_required"] = false
		flower["seed_final_armed"] = false
		main.flowers[i] = flower


func on_harvest(flower_index: int) -> void:
	if flower_index < 0 or flower_index >= main.flowers.size():
		return
	var flower: Dictionary = main.flowers[flower_index]
	if bool(flower.get("seeded", false)):
		return
	var nectar := int(flower.get("nectar", 0))
	if nectar == 1:
		flower["seed_ready"] = true
		flower["seed_lost"] = false
		# Main queries this flag before the next harvest tick. The current hold is
		# paused at one drop and only a real release + new press may take the seed.
		flower["seed_release_required"] = true
		flower["seed_final_armed"] = false
		main.message = "最后一滴托着种核。"
	elif nectar <= 0:
		if bool(flower.get("seed_ready", false)):
			seeds_lost += 1
		flower["seed_ready"] = false
		flower["seed_lost"] = true
		flower["seed_release_required"] = false
		flower["seed_final_armed"] = false
		main.message = "种核随最后一滴消失。"
	main.flowers[flower_index] = flower


func on_home(amount: int, _delta: float) -> void:
	# 只有一次真实卸蜜才让玩家的“停手”结算；站在巢里挂机不会白得种子。
	if amount <= 0:
		return
	var matured_now := 0
	for i in main.flowers.size():
		var flower: Dictionary = main.flowers[i]
		if not bool(flower.get("seed_ready", false)) or bool(flower.get("seeded", false)):
			continue
		flower["seed_ready"] = false
		flower["seeded"] = true
		flower["seed_release_required"] = false
		flower["seed_final_armed"] = false
		# 留下的最后一滴成为种核，不再能在下一趟被重复采走。
		flower["nectar"] = 0
		main.flowers[i] = flower
		matured_now += 1
		main.spawn_pollen(Vector2(flower.position))
	if matured_now <= 0:
		return
	seeds_matured += matured_now
	main.hive_reserve += matured_now * seed_reward_reserve
	main.flash = maxf(float(main.flash), 0.3)
	main.message = "种核成熟 × %d" % matured_now


func on_stage_complete() -> void:
	# 储备段最后一个采蜜节点仍保留群体分配；它是跨季投资，不替代野外留种。
	if main.stage_index % 6 != 5:
		return
	pending_harvest = main.delivered
	pending_allocation = true


func apply_split(fraction: float) -> void:
	var fed := roundi(pending_harvest * clampf(fraction, 0.0, 1.0))
	var stored := pending_harvest - fed
	main.hive_reserve += stored
	main.larval_boost += fed
	main.message = "带回 %d 滴蜜：公共储备 %d，哺育幼虫 %d。" % [pending_harvest, stored, fed]
	pending_allocation = false
	pending_harvest = 0


func larval_bonus() -> int:
	return int(main.larval_boost / maxi(larvae_per_boost, 1)) * boost_energy_cap


func can_complete() -> bool:
	if seeds_matured > 0:
		return true
	# 不因玩家已经采空所有花而制造无法挽回的软锁；此时失去种子本身就是后果。
	for flower in main.flowers:
		if int(flower.get("nectar", 0)) > 0:
			return false
	return true


func harvest_requires_release(flower_index: int) -> bool:
	if flower_index < 0 or flower_index >= main.flowers.size():
		return false
	return bool(main.flowers[flower_index].get("seed_release_required", false))


func notify_harvest_released(flower_index: int = -1) -> void:
	# A release arms the deliberate second press. Passing -1 lets the input router
	# acknowledge every pending pod when it does not retain the previous target.
	for i in main.flowers.size():
		if flower_index >= 0 and i != flower_index:
			continue
		var flower: Dictionary = main.flowers[i]
		if not bool(flower.get("seed_release_required", false)):
			continue
		flower["seed_release_required"] = false
		flower["seed_final_armed"] = true
		main.flowers[i] = flower


func visual_state_for_flower(flower_index: int) -> String:
	if flower_index < 0 or flower_index >= main.flowers.size():
		return "ordinary"
	var flower: Dictionary = main.flowers[flower_index]
	if bool(flower.get("seeded", false)):
		return "mature_seed_head"
	if bool(flower.get("seed_lost", false)):
		return "broken_pod"
	if bool(flower.get("seed_ready", false)):
		return "ripe_seed_pod"
	return "ordinary"


func hud_status() -> String:
	if seeds_matured > 0:
		return "留种 %d" % seeds_matured
	return "最后一滴可留种"


func is_flower_available(_index: int) -> bool:
	return true


func draw() -> void:
	for flower in main.flowers:
		var pos := Vector2(flower.position)
		if bool(flower.get("seed_ready", false)):
			_draw_ripe_pod(pos, bool(flower.get("seed_release_required", false)))
		elif bool(flower.get("seeded", false)):
			_draw_mature_seed_head(pos)
		elif bool(flower.get("seed_lost", false)):
			_draw_broken_pod(pos)


func _draw_ripe_pod(pos: Vector2, waiting_for_release: bool) -> void:
	var sway: float = sin(float(main.elapsed) * 3.2 + pos.x * 0.01) * 1.5
	var pod_center: Vector2 = pos + Vector2(sway, -9)
	main.draw_line(pos + Vector2(0, 12), pod_center + Vector2(0, 8), Color("66734c"), 4.0)
	main.draw_colored_polygon(PackedVector2Array([
		pod_center + Vector2(0, -18),
		pod_center + Vector2(-11, -7),
		pod_center + Vector2(-9, 9),
		pod_center + Vector2(0, 16),
		pod_center + Vector2(9, 9),
		pod_center + Vector2(11, -7)
	]), Color("c99b43") if waiting_for_release else Color("b78436"))
	main.draw_line(pod_center + Vector2(0, -15), pod_center + Vector2(0, 13), Color("76542e"), 2.0)
	for seed_index in 3:
		main.draw_circle(pod_center + Vector2(-3.0 if seed_index % 2 == 0 else 3.0, -7.0 + seed_index * 8.0), 3.0, Color("f1d47a"))
	if waiting_for_release:
		# A brief pair of opening sepals is the physical pause cue; it remains
		# visible for as long as the current harvest hold is blocked.
		main.draw_line(pod_center + Vector2(-9, -9), pod_center + Vector2(-16, -16), Color("f1d47a"), 3.0)
		main.draw_line(pod_center + Vector2(9, -9), pod_center + Vector2(16, -16), Color("f1d47a"), 3.0)


func _draw_mature_seed_head(pos: Vector2) -> void:
	main.draw_line(pos + Vector2(0, 14), pos + Vector2(0, -18), Color("5c7048"), 4.0)
	main.draw_colored_polygon(PackedVector2Array([
		pos + Vector2(0, -22), pos + Vector2(-14, -13),
		pos + Vector2(-10, 0), pos + Vector2(0, 8),
		pos + Vector2(10, 0), pos + Vector2(14, -13)
	]), Color("7f9659"))
	for seed_index in 5:
		var angle := -PI * 0.82 + float(seed_index) * PI * 0.41
		main.draw_circle(pos + Vector2(0, -8) + Vector2.from_angle(angle) * 10.0, 3.5, Color("d8bd66"))
	main.draw_colored_polygon(PackedVector2Array([
		pos + Vector2(0, 8), pos + Vector2(-16, 1), pos + Vector2(-7, 14)
	]), Color("91a866"))


func _draw_broken_pod(pos: Vector2) -> void:
	main.draw_line(pos + Vector2(0, 14), pos + Vector2(-5, -4), Color("756653", 0.78), 4.0)
	main.draw_line(pos + Vector2(-5, -4), pos + Vector2(-15, -13), Color("756653", 0.78), 4.0)
	main.draw_colored_polygon(PackedVector2Array([
		pos + Vector2(-17, -16), pos + Vector2(-7, -13), pos + Vector2(-13, -3)
	]), Color("7a6246", 0.82))
	for seed_index in 3:
		main.draw_circle(pos + Vector2(-11.0 + seed_index * 11.0, 20.0 + abs(seed_index - 1) * 3.0), 3.0, Color("6a5847", 0.72))
