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
		main.message = "最后一滴托着种核。"
	elif nectar <= 0:
		if bool(flower.get("seed_ready", false)):
			seeds_lost += 1
		flower["seed_ready"] = false
		flower["seed_lost"] = true
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
			var pulse := 13.0 + sin(main.elapsed * 4.5 + float(flower.get("id", 0))) * 2.0
			main.draw_arc(pos, pulse, 0, TAU, 20, Color("d6b85f"), 3.0)
			main.draw_circle(pos + Vector2(0, -11), 3.5, Color("84683c"))
		elif bool(flower.get("seeded", false)):
			main.draw_circle(pos + Vector2(0, -8), 5.0, Color("8fa466"))
