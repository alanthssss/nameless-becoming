class_name SeasonMechanics
extends Node
## 季节机制调度层。
## 按当前节令的 mechanics 槽位启停对应子系统；所有机制独立实现
## （start / process / on_harvest / on_home / on_stage_complete / on_repel_success / draw），
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


func start_stage(index: int) -> void:
	for mechanic in active:
		if mechanic.has_method("end"):
			mechanic.end()
	active.clear()
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

func completion_ready() -> bool:
	for mechanic in active:
		if mechanic.has_method("completion_ready") and not mechanic.completion_ready():
			return false
	return true


func draw() -> void:
	for mechanic in active:
		if mechanic.has_method("draw"):
			mechanic.draw()


func mechanic_by_id(id: String):
	for mechanic in active:
		if mechanic.get("mechanic_id") == id:
			return mechanic
	return null
