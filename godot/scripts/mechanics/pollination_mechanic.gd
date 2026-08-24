class_name PollinationMechanic
extends RefCounted
## 春 · 花粉连接。
## 开放花提供两类可见花粉；玩家采到花粉后，需要把它带到颜色匹配的锁芽旁，
## 再使用同一个情境动作打开花芽。锁芽的蜜在打开前为 0，因此春季不能靠
## 守着一朵高蜜花完成，必须在花与花之间规划路线。

const POLLEN_COLORS := [Color("f2cf5b"), Color("8fc9ee")]

var mechanic_id := "pollination"
var main
var bud_open_range := 58.0
var carried_pollen := -1
var pollen_time := 0.0
var opened_buds := 0
var source_indices: Array[int] = []
var bud_indices: Array[int] = []


func start(game, _data: Dictionary, balance: Dictionary) -> void:
	main = game
	var mechanics: Dictionary = balance.get("mechanics", {})
	var params: Dictionary = mechanics.get("pollination", {})
	bud_open_range = float(params.get("bud_open_range", 58.0))
	carried_pollen = -1
	pollen_time = 0.0
	opened_buds = 0
	source_indices.clear()
	bud_indices.clear()
	if main.flowers.size() < 2:
		return

	# 一半是花粉源，一半是锁芽。花粉类型交错，任何锁芽都至少有一个匹配源。
	var source_count := maxi(1, int(ceil(float(main.flowers.size()) * 0.5)))
	for i in main.flowers.size():
		var flower: Dictionary = main.flowers[i]
		flower["sleeping"] = false
		flower["pollinated"] = false
		flower["locked_bud"] = false
		flower["pollen_source"] = false
		flower["pollen_kind"] = -1
		flower["required_pollen"] = -1
		flower["opened_by_pollination"] = false
		if i < source_count:
			flower["pollen_source"] = true
			flower["pollen_kind"] = i % POLLEN_COLORS.size()
			source_indices.append(i)
		else:
			flower["locked_bud"] = true
			flower["required_pollen"] = (i - source_count) % POLLEN_COLORS.size()
			flower["stored_nectar"] = maxi(2, int(flower.get("nectar", 2)))
			flower["nectar"] = 0
			bud_indices.append(i)
		main.flowers[i] = flower


func process(_delta: float) -> void:
	# 花粉保持到匹配锁芽被打开；不设置隐形倒计时，避免花粉源采尽后的软锁。
	pass


func on_harvest(flower_index: int) -> void:
	if flower_index < 0 or flower_index >= main.flowers.size():
		return
	var flower: Dictionary = main.flowers[flower_index]
	if bool(flower.get("locked_bud", false)):
		return
	var pollen_kind := int(flower.get("pollen_kind", -1))
	if pollen_kind < 0:
		return
	carried_pollen = pollen_kind
	pollen_time = 1.0
	main.spawn_pollen(Vector2(flower.position))
	main.message = "花粉落在翅上。"


func on_context_action() -> bool:
	var bud_index := nearest_locked_bud()
	if bud_index < 0:
		return false
	var flower: Dictionary = main.flowers[bud_index]
	if carried_pollen < 0 or pollen_time <= 0.0:
		main.message = "锁芽在等花粉。"
		return true
	if int(flower.get("required_pollen", -1)) != carried_pollen:
		main.message = "颜色没有相合。"
		return true

	flower["locked_bud"] = false
	flower["opened_by_pollination"] = true
	flower["pollinated"] = true
	flower["nectar"] = int(flower.get("stored_nectar", 2))
	flower["stored_nectar"] = 0
	main.flowers[bud_index] = flower
	opened_buds += 1
	carried_pollen = -1
	pollen_time = 0.0
	main.spawn_pollen(Vector2(flower.position))
	main.flash = maxf(float(main.flash), 0.28)
	main.message = "锁芽打开。"
	return true


func try_context_action(_position: Vector2) -> bool:
	return on_context_action()


func can_complete() -> bool:
	return opened_buds > 0 or bud_indices.is_empty()


func hud_status() -> String:
	if can_complete():
		return "花粉连接 %d" % opened_buds
	if carried_pollen >= 0:
		return "携粉 · 寻同色锁芽"
	return "锁芽未开"


func is_flower_available(index: int) -> bool:
	if index < 0 or index >= main.flowers.size():
		return false
	return not bool(main.flowers[index].get("locked_bud", false))


func nearest_locked_bud() -> int:
	var nearest := -1
	var nearest_distance := bud_open_range
	for index in bud_indices:
		if index < 0 or index >= main.flowers.size():
			continue
		var flower: Dictionary = main.flowers[index]
		if not bool(flower.get("locked_bud", false)):
			continue
		var distance: float = main.bee.position.distance_to(Vector2(flower.position))
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = index
	return nearest


func draw() -> void:
	for index in source_indices:
		if index >= main.flowers.size():
			continue
		var source: Dictionary = main.flowers[index]
		if int(source.get("nectar", 0)) <= 0:
			continue
		var kind := int(source.get("pollen_kind", 0)) % POLLEN_COLORS.size()
		var pulse := 15.0 + sin(main.elapsed * 4.0 + float(index)) * 2.0
		main.draw_arc(Vector2(source.position), pulse, 0, TAU, 20, POLLEN_COLORS[kind], 2.0)
	for index in bud_indices:
		if index >= main.flowers.size():
			continue
		var bud: Dictionary = main.flowers[index]
		if not bool(bud.get("locked_bud", false)):
			continue
		var kind := int(bud.get("required_pollen", 0)) % POLLEN_COLORS.size()
		var pos := Vector2(bud.position)
		main.draw_circle(pos, 9.0, Color("40534f"))
		main.draw_arc(pos, 13.0, -PI * 0.8, PI * 0.8, 18, POLLEN_COLORS[kind], 3.0)
	if carried_pollen >= 0 and pollen_time > 0.0:
		var color: Color = POLLEN_COLORS[carried_pollen % POLLEN_COLORS.size()]
		main.draw_arc(main.bee.position, 25.0, 0, TAU, 24, Color(color, 0.85), 3.0)


func end() -> void:
	carried_pollen = -1
	pollen_time = 0.0
