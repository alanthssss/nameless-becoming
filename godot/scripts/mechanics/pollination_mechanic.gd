class_name PollinationMechanic
extends RefCounted
## 春分 · 授粉：花田是活的。
## 采蜜即授粉——花被采到半开以下时，远处一朵新花开放（花田的馈赠）；
## 久不采的花进入休眠（蜜保留，来年随循环重开），不是凋零损失。
## 决策改变：从「采哪朵划算」变成「采哪朵让花田活」。

var mechanic_id := "pollination"
var main
var sleep_seconds := 26.0
var new_flower_nectar := 3
var max_extra_flowers := 4
var pollinate_after_ratio := 0.55


func start(game, data: Dictionary, balance: Dictionary) -> void:
	main = game
	var mechanics: Dictionary = balance.get("mechanics", {})
	var params: Dictionary = mechanics.get("pollination", {})
	sleep_seconds = float(params.get("sleep_seconds", 26.0))
	new_flower_nectar = int(params.get("new_flower_nectar", 3))
	max_extra_flowers = int(params.get("max_extra_flowers", 4))
	pollinate_after_ratio = float(params.get("pollinate_after_ratio", 0.55))
	for i in main.flowers.size():
		var flower: Dictionary = main.flowers[i]
		flower["sleep_timer"] = sleep_seconds
		flower["max_nectar"] = int(flower.nectar)
		flower["newly_open"] = false
		flower["pollinated"] = false
		flower["sleeping"] = false
		main.flowers[i] = flower


func process(delta: float) -> void:
	var sleeping_before := 0
	for flower in main.flowers:
		if bool(flower.get("sleeping", false)):
			sleeping_before += 1
	for i in main.flowers.size():
		var flower: Dictionary = main.flowers[i]
		if int(flower.nectar) <= 0 or bool(flower.get("sleeping", false)):
			continue
		flower["sleep_timer"] = maxf(0.0, float(flower.get("sleep_timer", sleep_seconds)) - delta)
		if float(flower["sleep_timer"]) <= 0.0:
			flower["sleeping"] = true
		main.flowers[i] = flower
	var sleeping_after := 0
	for flower in main.flowers:
		if bool(flower.get("sleeping", false)):
			sleeping_after += 1
	if sleeping_after >= 3 and sleeping_before < 3:
		main.message = "花田大半休眠。采蜜即授粉——醒与睡，握在你的航线里。"
	elif sleeping_after == 0 and sleeping_before > 0:
		main.message = "花田重新活了过来。"


func on_harvest(flower_index: int) -> void:
	var flower: Dictionary = main.flowers[flower_index]
	flower["sleep_timer"] = sleep_seconds
	flower["sleeping"] = false
	main.flowers[flower_index] = flower
	if bool(flower.get("pollinated", false)):
		return
	var max_nectar := int(flower.get("max_nectar", int(flower.nectar)))
	if int(flower.nectar) <= maxi(1, roundi(max_nectar * pollinate_after_ratio)):
		flower["pollinated"] = true
		main.flowers[flower_index] = flower
		spawn_new_flower()


func spawn_new_flower() -> void:
	var extra_count := 0
	for flower in main.flowers:
		if bool(flower.get("newly_open", false)):
			extra_count += 1
	if extra_count >= max_extra_flowers or main.flowers.size() >= 12:
		return
	var position: Vector2 = main.find_spaced_flower_position(82.0)
	main.flowers.append({
		"id": 2000 + extra_count,
		"position": position,
		"nectar": new_flower_nectar,
		"max_nectar": new_flower_nectar,
		"kind": extra_count % 3,
		"phase": 0.0,
		"recovery": false,
		"type": "nectar_bloom",
		"sleep_timer": sleep_seconds,
		"newly_open": true,
		"pollinated": false,
		"sleeping": false
	})
	main.spawn_pollen(position)
	main.message = "授粉完成：远处一朵新花开放了。"


func draw() -> void:
	for flower in main.flowers:
		if bool(flower.get("sleeping", false)) or int(flower.nectar) <= 0:
			continue
		var remaining := float(flower.get("sleep_timer", sleep_seconds))
		if remaining < 8.0:
			var pos: Vector2 = flower.position
			main.draw_arc(pos, 20, 0, TAU, 24, Color("c98a4a", 0.5), 2)
			main.draw_arc(pos, 20, -PI / 2.0, -PI / 2.0 + TAU * clampf(remaining / 8.0, 0.0, 1.0), 24, Color("d9a93f", 0.9), 3)
