extends RefCounted

## G-FICTION: bounded route experiment. No Campaign state or persistence writes.
const HIVE := Vector2(360, 900)
const FLOWERS := Vector2(3260, 780)
const BUILD_SITE := Vector2(1800, 930)
const BUILD_SITES := [BUILD_SITE, Vector2(1840, 540)]
const ROOF_RADII := [190.0, 320.0]
const PENTAD_NAMES := ["一候 · 认路", "二候 · 接路", "三候 · 同行"]
const CAPACITY := 3
const GOAL := 9
const COMPANION_COUNT := 5
const BOUNDS := Rect2(90, 120, 3420, 1770)
const SHELTERS := [Vector2(420, 1180), Vector2(650, 1400), Vector2(970, 1490), Vector2(1300, 1510), Vector2(1640, 1480), Vector2(1970, 1430), Vector2(2290, 1340), Vector2(2590, 1230), Vector2(2890, 1090), Vector2(3160, 990)]
const SAFE_ROUTE := [HIVE, Vector2(420, 1180), Vector2(650, 1400), Vector2(970, 1490), Vector2(1300, 1510), Vector2(1640, 1480), Vector2(1970, 1430), Vector2(2290, 1340), Vector2(2590, 1230), Vector2(2890, 1090), Vector2(3160, 990), FLOWERS]
const PONDS := [Vector3(1240, 1020, 170), Vector3(2330, 720, 200)]
var heading := 0.0
var position := HIVE
var velocity := Vector2.ZERO
var elapsed := 0.0
var wind_travel := 0.0
var cargo := 0
var delivered := 0
var stage := 0
var roof_carried := false
var built_site := -1
var events_done: Dictionary = {}
var last_event := ""
var event_catalog: Dictionary = {}

var rain_exposure := 0.0
var drops: Array[Vector2] = []
var companions: Array[Dictionary] = []
var complete := false
var deliveries := 0
var spills := 0
var rescues := 0
var notice := "去右边花田取粉。叶下稳，直路近；装多少由你决定。"


func _init() -> void:
	# Reuse the canonical chapter identifiers/titles, without writing Campaign saves.
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/journey_levels.json"))
	for chapter in data.levels:
		if chapter.id == "spring_yushui":
			for event in chapter.event_matrix:
				event_catalog[event.id] = event

func record_event(id: String) -> void:
	if not events_done.has(id) and event_catalog.has(id):
		events_done[id] = true
		last_event = id

func roof_position() -> Vector2:
	return BUILD_SITES[built_site] if built_site >= 0 else BUILD_SITE

func roof_radius() -> float:
	return ROOF_RADII[built_site] if built_site >= 0 else 0.0

func cargo_capacity() -> int:
	return CAPACITY - (1 if roof_carried else 0)

func wind_force() -> float:
	return (-110.0 if stage >= 2 else 65.0) * (0.8 + sin(elapsed * 0.45) * 0.2)

func _advance_chapter() -> void:
	if stage == 1 and delivered >= 6 and built_site >= 0:
		stage = 2
		for index in range(COMPANION_COUNT):
			companions.append({"position": FLOWERS + Vector2((index - (COMPANION_COUNT - 1) / 2.0) * 18, 35), "waiting": true, "exposure": 0.0, "grace": 0.0, "joined": false, "heading": PI})
		notice = "风向变了。去花田接五只伙伴，用自己接好的路回来。"


func sheltered(point: Vector2) -> bool:
	if point.distance_to(HIVE) < 205.0 or point.distance_to(FLOWERS) < 180.0:
		return true
	for center: Vector2 in SHELTERS:
		if point.distance_to(center) < 215.0:
			return true
	return built_site >= 0 and point.distance_to(roof_position()) < roof_radius()

func rain_strength() -> float:
	return (0.72 if stage >= 2 else 0.6) + sin(elapsed * 0.055) * 0.18

func raining(point: Vector2) -> bool:
	return BOUNDS.has_point(point) and not sheltered(point)

func over_water(point: Vector2) -> bool:
	for pond: Vector3 in PONDS:
		if point.distance_to(Vector2(pond.x, pond.y)) < pond.z + 16:
			return true
	return false

func blocked(_point: Vector2) -> bool:
	# Water and bank plants are below the flight layer.
	return false

func move_on_map(_from: Vector2, target: Vector2) -> Vector2:
	return target

func maximum_speed() -> float:
	return 320.0 - (cargo + (1 if roof_carried else 0)) * 24.0

func step(delta: float, steering: Vector2, braking: bool) -> void:
	if complete or delta <= 0.0:
		return
	elapsed += delta
	wind_travel += wind_force() * delta
	if steering.length() > 0.08:
		heading = lerp_angle(heading, steering.angle(), 1.0 - exp(-12.0 * delta))
	var acceleration := 700.0 / (1.0 + (cargo + (1 if roof_carried else 0)) * 0.45)
	var target := steering.limit_length() * maximum_speed() * (0.40 if braking else 1.0)
	velocity = velocity.move_toward(target, acceleration * delta * (2.6 if braking else 1.0))
	if not sheltered(position):
		var wind := Vector2(wind_force(), 14.0)
		velocity += wind * delta * (1.0 + cargo * 0.24) * (0.38 if braking else 1.0)
	var next_position := position + velocity * delta
	position = move_on_map(position, next_position)
	if not position.is_equal_approx(next_position):
		velocity *= 0.65
	var clamped := position.clamp(BOUNDS.position, BOUNDS.end)
	if clamped.x != position.x:
		velocity.x = 0.0
	if clamped.y != position.y:
		velocity.y = 0.0
	position = clamped
	if raining(position) and cargo > 0:
		rain_exposure += delta * rain_strength()
		if rain_exposure >= 6.0:
			cargo -= 1
			spills += 1
			drops.append(position)
			rain_exposure = -0.65
			notice = "花粉落下了。靠近黄色散粉，按空格取回；也可以先回叶下。"
	else:
		rain_exposure = move_toward(rain_exposure, 0.0, delta * 2.0)
	if position.distance_to(HIVE) > 250:
		record_event("yushui_01_takeoff_window")
	if position.distance_to(HIVE) > 500 and sheltered(position):
		record_event("yushui_02_underleaf_flight")
	if stage >= 1 and built_site < 0:
		for site: Vector2 in BUILD_SITES:
			if position.distance_to(site) < 95:
				record_event("yushui_06_vein_backroute")
	if stage >= 2 and not sheltered(position):
		record_event("yushui_14_shifted_dropline")
	_update_companions(delta)

func act() -> String:
	if complete:
		return ""
	if roof_carried:
		for index in range(BUILD_SITES.size()):
			if position.distance_to(BUILD_SITES[index]) < 85:
				built_site = index
				roof_carried = false
				record_event("yushui_03_dry_landing")
				_advance_chapter()
				notice = "叶台撑好了。下一趟可以从这里穿过雨地。"
				return "build"
	if position.distance_to(HIVE) < 80.0:
		if cargo > 0:
			if stage >= 2:
				record_event("yushui_11_heavy_or_light")
			delivered += cargo
			cargo = 0
			deliveries += 1
			if delivered >= 3 and stage == 0:
				stage = 1
				notice = "遮雨叶准备好了。再按空格带上，去两处支点选一个撑起来。"
			else:
				notice = "花粉交到巢里了。再选一条飞法。"
			_advance_chapter()
			_check_finish()
			return "deliver"
		if stage == 1 and built_site < 0 and not roof_carried:
			roof_carried = true
			notice = "带好遮雨叶了。中路较短，上路叶台更宽；到选中的支点按空格。"
			return "roof"
		_check_finish()
		if not complete:
			notice = "还要接回花田的伙伴。" if stage >= 2 else "先去右边的花田取粉。"
		return ""
	if cargo < cargo_capacity():
		for index in range(drops.size()):
			if position.distance_to(drops[index]) < 62.0:
				drops.remove_at(index)
				cargo += 1
				rain_exposure = -0.8
				notice = "接回来了。先找片叶子稳住，再看下一阵雨。"
				return "recover"
		if position.distance_to(FLOWERS) < 80.0:
			cargo += 1
			notice = "装了 %d / %d 份。现在出发也可以；越重越要提前转弯。" % [cargo, cargo_capacity()]
			return "load"
	notice = "花粉已装满，找一条返巢的路。" if cargo == cargo_capacity() else "靠近花田取粉、落粉取回，或巢门交货。"
	return ""

func _update_companions(delta: float) -> void:
	var leader := position
	for bee in companions:
		bee.grace = maxf(0.0, float(bee.grace) - delta)
		var p: Vector2 = bee.position
		if bee.waiting:
			if p.distance_to(position) < 65.0 and velocity.length() < 105.0:
				bee.waiting = false
				if bee.joined:
					rescues += 1
					record_event("yushui_12_partner_rescue")
				bee.joined = true
				bee.grace = 2.0
				bee.exposure = 0.0
				notice = "跟上啦。按住 Shift 慢飞，过弯时给队尾一点余地。"
		else:
			var distance := p.distance_to(leader)
			var spacing := 18.0 if p.distance_to(HIVE) < 230.0 else 30.0
			if distance > spacing:
				p = move_on_map(p, p.move_toward(leader, minf(300.0 * delta, distance - spacing)))
			var movement: Vector2 = p - (bee.position as Vector2)
			if movement.length() > 0.01:
				bee.heading = lerp_angle(float(bee.get("heading", PI)), movement.angle(), 1.0 - exp(-12.0 * delta))
			bee.position = p
			if raining(p) and float(bee.grace) <= 0.0:
				bee.exposure = float(bee.exposure) + delta * rain_strength()
				if float(bee.exposure) > 7.0:
					bee.waiting = true
					bee.exposure = 0.0
					notice = "有伙伴停下了。回到它身边，按住 Shift 稳住，就能接回。"
			else:
				bee.exposure = 0.0
		leader = p

func home_companions() -> int:
	var count := 0
	for bee in companions:
		if bee.joined and not bee.waiting and (bee.position as Vector2).distance_to(HIVE) < 112.0:
			count += 1
	return count

func _check_finish() -> void:
	if delivered >= GOAL and companions.size() == COMPANION_COUNT and home_companions() == COMPANION_COUNT:
		complete = true
		record_event("yushui_15_full_rain_route")
		notice = "这条路，大家都能走了。"
	elif delivered >= GOAL:
		notice = "花粉够了。把五只伙伴都接到巢门，再按空格一起收工。"
