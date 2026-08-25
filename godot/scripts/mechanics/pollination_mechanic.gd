class_name PollinationMechanic
extends RefCounted
## 春 · 开放花传粉。
## 散粉花心与受粉花心是开放花上两种不同的可见部分；它们的变体直接来自
## 花本身的 visual_variant。蜂身上同变体的散粉落到受粉花心后，这朵花进入
## 结籽状态；传粉不创造、储存或增加花蜜。

const POLLEN_COLORS := [Color("f2cf5b"), Color("e99aba")]
const DUST_OFFSETS := [
	Vector2(-19, -9), Vector2(-12, 8), Vector2(-5, -13), Vector2(1, 10),
	Vector2(8, -8), Vector2(14, 5), Vector2(20, -2), Vector2(-2, 1)
]

var mechanic_id := "pollination"
var main
var deposit_range := 58.0
var carried_pollen_variant := -1
var pollinated_flowers := 0
var donor_indices: Array[int] = []
var receptive_indices: Array[int] = []
var pollen_charges: Array[int] = [0, 0]
var registered_flower_count := 0


func start(game, _data: Dictionary, balance: Dictionary) -> void:
	main = game
	var mechanics: Dictionary = balance.get("mechanics", {})
	var params: Dictionary = mechanics.get("pollination", {})
	deposit_range = float(params.get("deposit_range", 58.0))
	carried_pollen_variant = -1
	pollinated_flowers = 0
	pollen_charges = [0, 0]
	donor_indices.clear()
	receptive_indices.clear()
	registered_flower_count = 0
	if main.flowers.size() < 2:
		return

	# Give every visible variant a donor before filling the rest of the donor half.
	# The arrays are traversal caches only: flower fields drive both drawing and play.
	var donor_flags := {}
	for variant in POLLEN_COLORS.size():
		for i in main.flowers.size():
			if _visible_variant(main.flowers[i]) == variant:
				donor_flags[i] = true
				break
	var donor_count := maxi(donor_flags.size(), int(ceil(float(main.flowers.size()) * 0.5)))
	for i in main.flowers.size():
		if donor_flags.size() >= donor_count:
			break
		if not donor_flags.has(i):
			donor_flags[i] = true

	for i in main.flowers.size():
		_register_flower(i, donor_flags.has(i))
	# The first lesson may sequence harvest and danger, but a completion target
	# must not remain a generic closed bud while the HUD already requires it.
	# Receptive flowers are open and visibly marked from the start; mentor action
	# permissions still control when deposition itself can be attempted.
	if String(_data.get("tutorial_profile", "")) == "first_trip_pollination" and not bool(main.tutorial_complete):
		for index in receptive_indices:
			var receptive: Dictionary = main.flowers[index]
			receptive["tutorial_locked"] = false
			main.flowers[index] = receptive
	registered_flower_count = main.flowers.size()


func process(_delta: float) -> void:
	# Loose pollen remains until it reaches a compatible stigma. There is no hidden
	# timer that could exhaust all donors and soft-lock reproduction.
	_register_new_flowers()


func on_harvest(flower_index: int) -> void:
	_register_new_flowers()
	if flower_index < 0 or flower_index >= main.flowers.size():
		return
	var flower: Dictionary = main.flowers[flower_index]
	if not bool(flower.get("has_anthers", false)):
		return
	var variant := int(flower.get("pollen_variant", -1))
	if variant < 0 or variant >= pollen_charges.size():
		return
	carried_pollen_variant = variant
	pollen_charges[variant] += 1
	main.message = "散粉留在蜂身上。"


func on_context_action() -> bool:
	if main == null or main.bee == null:
		return false
	return _deposit_at(main.bee.position)


func try_context_action(position: Vector2) -> bool:
	return _deposit_at(position)


func _deposit_at(position: Vector2) -> bool:
	var flower_index := nearest_receptive_flower_at(position)
	if flower_index < 0:
		return false
	var flower: Dictionary = main.flowers[flower_index]
	var required_variant := int(flower.get("stigma_variant", -1))
	if required_variant < 0 or required_variant >= pollen_charges.size():
		return false
	if pollen_charges[required_variant] <= 0:
		main.message = "这个花心需要同花型的散粉。"
		return true

	# Reproduction changes reproductive state only. Nectar is deliberately neither
	# read nor written here, so deposition cannot become a disguised refill rule.
	flower["pollinated"] = true
	flower["seed_setting"] = true
	main.flowers[flower_index] = flower
	pollinated_flowers += 1
	pollen_charges[required_variant] -= 1
	_refresh_carried_pollen_variant()
	main.spawn_pollen(Vector2(flower.position))
	main.flash = maxf(float(main.flash), 0.28)
	main.message = "同花型散粉落下，花心开始结籽。"
	return true


func context_action_id(position: Vector2) -> String:
	if nearest_receptive_flower_at(position) >= 0:
		return "deposit_pollen"
	return ""


func required_pollination_count() -> int:
	return mini(2, receptive_indices.size())


func can_complete() -> bool:
	return pollinated_flowers >= required_pollination_count()


func hud_status() -> String:
	var required := required_pollination_count()
	return "传粉 %d / %d" % [mini(pollinated_flowers, required), required]


func is_flower_available(index: int) -> bool:
	# Donors and receptive flowers are already open and remain ordinary nectar
	# sources before and after reproduction.
	return index >= 0 and index < main.flowers.size()


func nearest_receptive_flower_at(position: Vector2) -> int:
	_register_new_flowers()
	var nearest := -1
	var nearest_distance := deposit_range
	for index in receptive_indices:
		if index < 0 or index >= main.flowers.size():
			continue
		var flower: Dictionary = main.flowers[index]
		if not bool(flower.get("receptive_stigma", false)) or bool(flower.get("pollinated", false)):
			continue
		if bool(flower.get("tutorial_hidden", false)) and not bool(flower.get("discovered", false)):
			continue
		if bool(flower.get("tutorial_locked", false)):
			continue
		var distance: float = position.distance_to(Vector2(flower.position))
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = index
	return nearest


func nearest_matching_receptive(variant: int, origin: Vector2) -> int:
	_register_new_flowers()
	var nearest := -1
	var nearest_distance := INF
	for index in receptive_indices:
		if index < 0 or index >= main.flowers.size():
			continue
		var flower: Dictionary = main.flowers[index]
		if (
			not bool(flower.get("receptive_stigma", false))
			or bool(flower.get("pollinated", false))
			or int(flower.get("stigma_variant", -1)) != variant
		):
			continue
		if not _flower_is_visible(flower):
			continue
		var distance := origin.distance_to(Vector2(flower.position))
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = index
	return nearest


func visual_state_for_flower(index: int) -> String:
	if index < 0 or index >= main.flowers.size():
		return "ordinary"
	var flower: Dictionary = main.flowers[index]
	if bool(flower.get("seed_setting", false)):
		return "seed_setting"
	if bool(flower.get("has_anthers", false)):
		return "donor_anthers" if int(flower.get("nectar", 0)) > 0 else "spent_donor"
	if bool(flower.get("receptive_stigma", false)):
		return "receptive_stigma"
	return "ordinary"


func _visible_variant(flower: Dictionary) -> int:
	return clampi(int(flower.get("visual_variant", 0)), 0, POLLEN_COLORS.size() - 1)


func _register_flower(index: int, is_donor: bool) -> void:
	if index < 0 or index >= main.flowers.size():
		return
	var flower: Dictionary = main.flowers[index]
	var variant := _visible_variant(flower)
	flower["sleeping"] = false
	flower["has_anthers"] = is_donor
	flower["receptive_stigma"] = not is_donor
	flower["pollen_variant"] = variant if is_donor else -1
	flower["stigma_variant"] = variant if not is_donor else -1
	flower["pollinated"] = false
	flower["seed_setting"] = false
	if is_donor:
		donor_indices.append(index)
	else:
		receptive_indices.append(index)
	main.flowers[index] = flower


func _register_new_flowers() -> void:
	if main == null:
		return
	while registered_flower_count < main.flowers.size():
		var index := registered_flower_count
		var variant := _visible_variant(main.flowers[index])
		var donors_of_variant := 0
		var receptive_of_variant := 0
		for donor_index in donor_indices:
			if donor_index < main.flowers.size() and int(main.flowers[donor_index].get("pollen_variant", -1)) == variant:
				donors_of_variant += 1
		for receptive_index in receptive_indices:
			if receptive_index < main.flowers.size() and int(main.flowers[receptive_index].get("stigma_variant", -1)) == variant:
				receptive_of_variant += 1
		# Alternate each visible variant between donor and receptive roles. A mentor
		# practice bloom or recovery bloom therefore joins the same visible rule as
		# authored flowers instead of becoming an unmarked exception.
		_register_flower(index, donors_of_variant <= receptive_of_variant)
		registered_flower_count += 1


func _refresh_carried_pollen_variant() -> void:
	carried_pollen_variant = -1
	for variant in pollen_charges.size():
		if pollen_charges[variant] > 0:
			carried_pollen_variant = variant
			break


func _flower_is_visible(flower: Dictionary) -> bool:
	if bool(flower.get("tutorial_hidden", false)) and not bool(flower.get("discovered", false)):
		return false
	return not bool(flower.get("tutorial_locked", false))


func _draw_anthers(flower: Dictionary) -> void:
	var variant := int(flower.get("pollen_variant", 0))
	if variant < 0 or variant >= POLLEN_COLORS.size():
		return
	var pos := Vector2(flower.position)
	var color: Color = POLLEN_COLORS[variant]
	for stamen in 5:
		var angle: float = TAU * float(stamen) / 5.0 + float(main.elapsed) * 0.12
		var head := pos + Vector2.from_angle(angle) * 11.0
		main.draw_line(pos, head, Color("66512f", 0.82), 2.2)
		main.draw_circle(head, 4.2, Color("66512f", 0.88))
		main.draw_circle(head, 3.0, color)
	main.draw_circle(pos, 3.8, Color("66512f", 0.92))


func _draw_receptive_stigma(flower: Dictionary) -> void:
	var variant := int(flower.get("stigma_variant", 0))
	if variant < 0 or variant >= POLLEN_COLORS.size():
		return
	var pos := Vector2(flower.position)
	var color: Color = POLLEN_COLORS[variant].lightened(0.12)
	# One raised, three-lobed stigma is deliberately unlike the donor's five anthers.
	main.draw_line(pos + Vector2(0, 9), pos + Vector2(0, -7), Color("f6eed2", 0.95), 4.0)
	for lobe_position in [Vector2(0, -10), Vector2(-5, -7), Vector2(5, -7)]:
		main.draw_circle(pos + lobe_position, 5.0, Color("405840", 0.90))
		main.draw_circle(pos + lobe_position, 3.6, Color(color, 0.96))


func _draw_seed_setting(flower: Dictionary) -> void:
	var pos := Vector2(flower.position)
	main.draw_colored_polygon(PackedVector2Array([
		pos + Vector2(0, -11), pos + Vector2(-8, -3),
		pos + Vector2(-6, 9), pos + Vector2(0, 14),
		pos + Vector2(6, 9), pos + Vector2(8, -3)
	]), Color("86a85f", 0.94))
	for seed in 3:
		main.draw_circle(pos + Vector2(0, -3 + seed * 5), 2.2, Color("f3d474"))


func _draw_loose_body_dust() -> void:
	for variant in pollen_charges.size():
		if pollen_charges[variant] <= 0:
			continue
		var color: Color = POLLEN_COLORS[variant]
		for mote in DUST_OFFSETS.size():
			if mote % pollen_charges.size() != variant:
				continue
			var base: Vector2 = DUST_OFFSETS[mote]
			var drift := Vector2(0, sin(float(main.elapsed) * 4.0 + float(mote)) * 1.8)
			main.draw_circle(Vector2(main.bee.position) + base + drift, 2.2 + float(mote % 3) * 0.30, Color(color, 0.88))


func draw() -> void:
	_register_new_flowers()
	for index in donor_indices:
		if index < 0 or index >= main.flowers.size():
			continue
		var flower: Dictionary = main.flowers[index]
		if _flower_is_visible(flower) and bool(flower.get("has_anthers", false)) and int(flower.get("nectar", 0)) > 0:
			_draw_anthers(flower)
	for index in receptive_indices:
		if index < 0 or index >= main.flowers.size():
			continue
		var flower: Dictionary = main.flowers[index]
		if not _flower_is_visible(flower):
			continue
		if bool(flower.get("seed_setting", false)):
			_draw_seed_setting(flower)
		elif bool(flower.get("receptive_stigma", false)):
			_draw_receptive_stigma(flower)
	_draw_loose_body_dust()


func end() -> void:
	carried_pollen_variant = -1
	pollen_charges = [0, 0]
