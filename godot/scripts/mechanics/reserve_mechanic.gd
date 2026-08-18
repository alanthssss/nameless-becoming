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


func start(game, data: Dictionary, balance: Dictionary) -> void:
	main = game
	var mechanics: Dictionary = balance.get("mechanics", {})
	var params: Dictionary = mechanics.get("reserve", {})
	larvae_per_boost = int(params.get("larvae_per_boost", 10))
	boost_energy_cap = int(params.get("boost_energy_cap", 5))
	pending_allocation = false
	pending_harvest = 0


func on_stage_complete() -> void:
	# 秋季节令完成：只在秋末（霜降）触发分配池，等待玩家定夺
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
