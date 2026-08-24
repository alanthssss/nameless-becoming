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
var pollen_charges: Array[int] = [0, 0]


func start(game, _data: Dictionary, balance: Dictionary) -> void:
	main = game
	var mechanics: Dictionary = balance.get("mechanics", {})
	var params: Dictionary = mechanics.get("pollination", {})
	bud_open_range = float(params.get("bud_open_range", 58.0))
	carried_pollen = -1
	pollen_time = 0.0
	opened_buds = 0
	pollen_charges = [0, 0]
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
	pollen_charges[pollen_kind % POLLEN_COLORS.size()] += 1
	pollen_time = 1.0
	main.spawn_pollen(Vector2(flower.position))
	main.message = "花粉落在翅上。"


func on_context_action() -> bool:
	var bud_index := nearest_locked_bud()
	if bud_index < 0:
		return false
	var flower: Dictionary = main.flowers[bud_index]
	var required_kind := int(flower.get("required_pollen", -1))
	if required_kind < 0 or pollen_charges[required_kind % POLLEN_COLORS.size()] <= 0:
		main.message = "锁芽在等花粉。"
		return true

	flower["locked_bud"] = false
	flower["opened_by_pollination"] = true
	flower["pollinated"] = true
	flower["nectar"] = int(flower.get("stored_nectar", 2))
	flower["stored_nectar"] = 0
	main.flowers[bud_index] = flower
	opened_buds += 1
	pollen_charges[required_kind % POLLEN_COLORS.size()] -= 1
	_refresh_visible_pollen()
	main.spawn_pollen(Vector2(flower.position))
	main.flash = maxf(float(main.flash), 0.28)
	main.message = "锁芽打开。"
	return true


func try_context_action(_position: Vector2) -> bool:
	return on_context_action()


func context_action_id(position: Vector2) -> String:
	if nearest_locked_bud_at(position) >= 0:
		return "open_pollination_bud"
	return ""


func required_open_count() -> int:
	return mini(2, bud_indices.size())


func can_complete() -> bool:
	return opened_buds >= required_open_count()


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
	return nearest_locked_bud_at(main.bee.position)


func nearest_locked_bud_at(position: Vector2) -> int:
	var nearest := -1
	var nearest_distance := bud_open_range
	for index in bud_indices:
		if index < 0 or index >= main.flowers.size():
			continue
		var flower: Dictionary = main.flowers[index]
		if not bool(flower.get("locked_bud", false)):
			continue
		var distance: float = position.distance_to(Vector2(flower.position))
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = index
	return nearest


func nearest_matching_bud(kind: int, origin: Vector2) -> int:
	var nearest := -1
	var nearest_distance := INF
	for index in bud_indices:
		if index < 0 or index >= main.flowers.size():
			continue
		var flower: Dictionary = main.flowers[index]
		if not bool(flower.get("locked_bud", false)) or int(flower.get("required_pollen", -1)) != kind:
			continue
		var distance := origin.distance_to(Vector2(flower.position))
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = index
	return nearest


func visual_state_for_flower(index: int) -> String:
	if source_indices.has(index):
		return "pollen_stamens"
	if bud_indices.has(index) and index >= 0 and index < main.flowers.size():
		return "closed_bud" if bool(main.flowers[index].get("locked_bud", false)) else "opened_bloom"
	return "ordinary"


func _refresh_visible_pollen() -> void:
	carried_pollen = -1
	for kind in pollen_charges.size():
		if pollen_charges[kind] > 0:
			carried_pollen = kind
			break
	pollen_time = 1.0 if carried_pollen >= 0 else 0.0


func _draw_closed_bud(pos: Vector2, color: Color) -> void:
	# A stem, two sepals and folded petals read as a physical bud rather than
	# the abstract empty target rings used by the first implementation.
	main.draw_line(pos + Vector2(0, 12), pos + Vector2(0, 38), Color("49634d"), 4.0)
	main.draw_colored_polygon(PackedVector2Array([
		pos + Vector2(0, -19), pos + Vector2(-8, -17),
		pos + Vector2(-14, -8), pos + Vector2(-13, 4),
		pos + Vector2(-6, 12), pos + Vector2(0, 15),
		pos + Vector2(6, 12), pos + Vector2(13, 4),
		pos + Vector2(14, -8), pos + Vector2(8, -17)
	]), Color(color, 0.92))
	main.draw_colored_polygon(PackedVector2Array([
		pos + Vector2(0, -17), pos + Vector2(-7, -5),
		pos + Vector2(-4, 10), pos + Vector2(0, 14),
		pos + Vector2(4, 10), pos + Vector2(7, -5)
	]), Color(color.darkened(0.18), 0.82))
	main.draw_colored_polygon(PackedVector2Array([
		pos + Vector2(0, 15),
		pos + Vector2(-13, 4),
		pos + Vector2(-5, 0)
	]), Color("66825c"))
	main.draw_colored_polygon(PackedVector2Array([
		pos + Vector2(0, 15),
		pos + Vector2(13, 4),
		pos + Vector2(5, 0)
	]), Color("66825c"))
	main.draw_line(pos + Vector2(0, 10), pos + Vector2(0, -15), Color("fff2b3", 0.52), 1.5)


func draw() -> void:
	for index in source_indices:
		if index >= main.flowers.size():
			continue
		var source: Dictionary = main.flowers[index]
		if int(source.get("nectar", 0)) <= 0:
			continue
		if bool(source.get("tutorial_hidden", false)) and not bool(source.get("discovered", false)):
			continue
		if bool(source.get("tutorial_locked", false)):
			continue
		var kind := int(source.get("pollen_kind", 0)) % POLLEN_COLORS.size()
		var pos := Vector2(source.position)
		# Five bright stamens sit inside the existing flower silhouette. Their
		# arrangement and color are repeated on the matching closed bud.
		for stamen in 5:
			var angle: float = TAU * float(stamen) / 5.0 + float(main.elapsed) * 0.22
			var head: Vector2 = pos + Vector2.from_angle(angle) * (8.0 + sin(float(main.elapsed) * 4.0 + stamen) * 1.2)
			main.draw_line(pos, head, Color(POLLEN_COLORS[kind], 0.58), 1.5)
			main.draw_circle(head, 3.2, POLLEN_COLORS[kind])
	for index in bud_indices:
		if index >= main.flowers.size():
			continue
		var bud: Dictionary = main.flowers[index]
		if not bool(bud.get("locked_bud", false)):
			continue
		var kind := int(bud.get("required_pollen", 0)) % POLLEN_COLORS.size()
		var pos := Vector2(bud.position)
		_draw_closed_bud(pos, POLLEN_COLORS[kind])
	if pollen_time > 0.0:
		for kind in pollen_charges.size():
			if pollen_charges[kind] <= 0:
				continue
			var color: Color = POLLEN_COLORS[kind]
			var leg_side := -1.0 if kind == 0 else 1.0
			# Pollen is carried as two small clumps on the bee's hind legs.
			main.draw_circle(main.bee.position + Vector2(-8, 12.0 * leg_side), 4.5, color)
			main.draw_circle(main.bee.position + Vector2(-14, 9.0 * leg_side), 3.2, Color(color, 0.86))
			var match_index := nearest_matching_bud(kind, main.bee.position)
			if match_index < 0:
				continue
			var target := Vector2(main.flowers[match_index].position)
			for mote in 5:
				var ratio := fmod(main.elapsed * 0.22 + float(mote) / 5.0, 1.0)
				var guide_pos: Vector2 = Vector2(main.bee.position).lerp(target, ratio)
				guide_pos.y += sin(ratio * PI) * -18.0
				main.draw_circle(guide_pos, 2.0 + ratio, Color(color, 0.28 + ratio * 0.34))


func end() -> void:
	carried_pollen = -1
	pollen_time = 0.0
	pollen_charges = [0, 0]
