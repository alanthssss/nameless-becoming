class_name ReserveMechanic
extends RefCounted
## 秋分 · 储备：为来年投资。
## 节令完成的蜜成为两种投资——储冬蜜（越冬燃料，hive_reserve）
## 或哺育幼虫（来年劳动力，larval_boost，冬季出巢能量上限）。
## 决策发生在蜂巢里（分配滑块），野外零新增操作。

var mechanic_id := "reserve"
var main
var pending_allocation := false
var pending_harvest := 0
var larvae_per_boost := 10
var boost_energy_cap := 5
var stored_found := false
var larvae_found := false


func start(game, data: Dictionary, balance: Dictionary) -> void:
	main = game
	var mechanics: Dictionary = balance.get("mechanics", {})
	var params: Dictionary = mechanics.get("reserve", {})
	larvae_per_boost = int(params.get("larvae_per_boost", 10))
	boost_energy_cap = int(params.get("boost_energy_cap", 5))
	pending_allocation = false
	pending_harvest = 0
	stored_found = false
	larvae_found = false
	# 秋季花田直接出现两种未来：蜡环花补储备，籽心花哺育幼虫。
	# 玩家必须改变采集路线并至少带回两类，而不是关末才读一个滑块。
	for i in main.flowers.size():
		var flower: Dictionary = main.flowers[i]
		flower["reserve_kind"] = "store" if i % 2 == 0 else "larvae"
		flower["reserve_claimed"] = false
		main.flowers[i] = flower

func on_harvest(flower_index: int) -> void:
	var flower: Dictionary = main.flowers[flower_index]
	if bool(flower.get("reserve_claimed", false)):
		return
	var max_nectar := maxi(1, int(flower.get("max_nectar", flower.nectar)))
	if int(flower.nectar) > max_nectar / 2:
		return
	flower["reserve_claimed"] = true
	main.flowers[flower_index] = flower
	if String(flower.get("reserve_kind", "store")) == "store":
		stored_found = true
		main.hive_reserve += 1
	else:
		larvae_found = true
		main.larval_boost += 1
	main.spawn_pollen(Vector2(flower.position))

func completion_ready() -> bool:
	return stored_found and larvae_found

func draw() -> void:
	for flower in main.flowers:
		if bool(flower.get("reserve_claimed", false)) or int(flower.nectar) <= 0:
			continue
		var color := Color("d8ad43", 0.75) if String(flower.get("reserve_kind", "store")) == "store" else Color("8fbd77", 0.75)
		main.draw_arc(Vector2(flower.position), 26.0, 0, TAU, 24, color, 3)


func on_stage_complete() -> void:
	# 储备段完成：只在白露（储备段最后的采蜜关）触发分配池，等待玩家定夺
	if main.stage_index % 6 != 5:
		return
	pending_harvest = main.delivered
	pending_allocation = true


func apply_split(fraction: float) -> void:
	var fed := roundi(pending_harvest * clampf(fraction, 0.0, 1.0))
	var stored := pending_harvest - fed
	main.hive_reserve += stored
	main.larval_boost += fed
	main.message = "本季 %d 滴蜜：储冬蜜 %d，哺育幼虫 %d。" % [pending_harvest, stored, fed]
	pending_allocation = false
	pending_harvest = 0


func larval_bonus() -> int:
	return int(main.larval_boost / maxi(larvae_per_boost, 1)) * boost_energy_cap
