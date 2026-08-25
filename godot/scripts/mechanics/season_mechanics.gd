class_name SeasonMechanics
extends Node
## 季节机制调度层。
## 按当前节令的 mechanics 槽位启停对应子系统；所有机制独立实现
## （start / process / on_context_action / on_harvest / on_home /
## on_stage_complete / on_repel_success / draw），
## 不侵入 main.gd 主循环，只通过钩子被调用。

const MECHANIC_SCRIPTS := {
	"pollination": "res://scripts/mechanics/pollination_mechanic.gd",
	"conscription": "res://scripts/mechanics/conscription_mechanic.gd",
	"reserve": "res://scripts/mechanics/reserve_mechanic.gd",
	"huddle": "res://scripts/mechanics/huddle_mechanic.gd"
}

var main
var active: Array = []


func configure(game) -> void:
	main = game


func end_stage() -> void:
	for mechanic in active:
		if mechanic.has_method("end"):
			mechanic.end()
	active.clear()


func start_stage(index: int) -> void:
	end_stage()
	if main == null or main.stages.is_empty():
		return
	var data: Dictionary = main.stages[index]
	var ids: Array = data.get("mechanics", [])
	for id in ids:
		if not MECHANIC_SCRIPTS.has(id):
			continue
		var mechanic = load(MECHANIC_SCRIPTS[id]).new()
		active.append(mechanic)
		if mechanic.has_method("start"):
			mechanic.start(main, data, main.balance)


func process(delta: float) -> void:
	for mechanic in active:
		if mechanic.has_method("process"):
			mechanic.process(delta)


func try_context_action(position: Vector2) -> bool:
	for mechanic in active:
		if mechanic.has_method("try_context_action"):
			if bool(mechanic.try_context_action(position)):
				return true
			continue
		if mechanic.has_method("on_context_action") and bool(mechanic.on_context_action()):
			return true
	return false


func context_action_id(position: Vector2) -> String:
	for mechanic in active:
		if mechanic.has_method("context_action_id"):
			var action_id := String(mechanic.context_action_id(position))
			if not action_id.is_empty():
				return action_id
	return ""


func latched_event() -> Dictionary:
	var best := {"id": "", "remaining": 0.0}
	for mechanic in active:
		if not mechanic.has_method("latched_event"):
			continue
		var candidate: Dictionary = mechanic.latched_event()
		if float(candidate.get("remaining", 0.0)) > float(best.remaining):
			best = candidate
	return best


func harvest_requires_release(flower_index: int) -> bool:
	for mechanic in active:
		if mechanic.has_method("harvest_requires_release") and bool(mechanic.harvest_requires_release(flower_index)):
			return true
	return false


func notify_harvest_released(flower_index: int = -1) -> void:
	for mechanic in active:
		if mechanic.has_method("notify_harvest_released"):
			mechanic.notify_harvest_released(flower_index)


# 测试与旧调用的兼容入口；运行时 main 使用 try_context_action，避免同一帧双触发。
func on_context_action() -> bool:
	if main == null or main.bee == null:
		return false
	return try_context_action(main.bee.position)


func can_complete() -> bool:
	for mechanic in active:
		if mechanic.has_method("can_complete") and not bool(mechanic.can_complete()):
			return false
	return true


func hud_status() -> String:
	var parts: Array[String] = []
	for mechanic in active:
		if mechanic.has_method("hud_status"):
			var status := String(mechanic.hud_status())
			if not status.is_empty():
				parts.append(status)
	return "　".join(parts)


func sense_focus_active() -> bool:
	for mechanic in active:
		if mechanic.has_method("sense_focus_active") and bool(mechanic.sense_focus_active()):
			return true
	return false


func is_flower_available(index: int) -> bool:
	for mechanic in active:
		if mechanic.has_method("is_flower_available") and not bool(mechanic.is_flower_available(index)):
			return false
	return true


func on_harvest(flower_index: int) -> void:
	for mechanic in active:
		if mechanic.has_method("on_harvest"):
			mechanic.on_harvest(flower_index)


func on_home(amount: int, delta: float) -> void:
	for mechanic in active:
		if mechanic.has_method("on_home"):
			mechanic.on_home(amount, delta)


func on_stage_complete() -> void:
	for mechanic in active:
		if mechanic.has_method("on_stage_complete"):
			mechanic.on_stage_complete()


func on_repel_success() -> void:
	for mechanic in active:
		if mechanic.has_method("on_repel_success"):
			mechanic.on_repel_success()


func draw() -> void:
	for mechanic in active:
		if mechanic.has_method("draw"):
			mechanic.draw()


func mechanic_by_id(id: String):
	for mechanic in active:
		if mechanic.get("mechanic_id") == id:
			return mechanic
	return null
