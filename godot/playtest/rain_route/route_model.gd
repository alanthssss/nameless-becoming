extends RefCounted

## G-FICTION: bounded route experiment. No Campaign state or persistence writes.
const HIVE := Vector2(360, 900)
const ROOF_PICKUP := HIVE + Vector2(150, 55)
const FLOWERS := Vector2(3260, 780)
const BUILD_SITE := Vector2(1800, 930)
const BUILD_SITES := [BUILD_SITE, Vector2(1840, 540)]
const ROOF_RADII := [190.0, 320.0]
const PENTAD_NAMES := ["一候 · 认路", "二候 · 接路", "三候 · 同行"]
const CAPACITY := 3
const GOAL := 15
const Calendar := preload("res://playtest/rain_route/route_calendar.gd")
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
var day := 1
var day_finished := false
var day_delivered := 0
var day_spills := 0
var visited: Dictionary = {}
var daily_done: Dictionary = {}
var completed_days: Array[int] = []
var pollinated: Dictionary = {}
var cleared: Dictionary = {}
var rack_stock := 0
var route_revealed := false
var beetle_home := false
var beetle_position := Vector2(1100, 1480)
var escort_roof := false
var carried_seed := -1
var drip_hit_flash := 0.0
var drip_hit_points: Dictionary = {}
var moving_hold := 0.0
var day_clock := 0.0
var homecoming_time := -1.0
var dry_days := 0
var dawn_state: Dictionary = {}

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
	_begin_day()

func record_event(id: String) -> void:
	if not events_done.has(id) and event_catalog.has(id):
		events_done[id] = true
		last_event = id

func today() -> Dictionary:
	return Calendar.DAYS[day - 1]

func event_today() -> Dictionary:
	for event in event_catalog.values():
		if int(event.order) == day:
			return event
	return {}

func beetle_rest_position() -> Vector2:
	return Calendar.DAYS[8].target + Vector2(55, -32)

func moving_roof_position() -> Vector2:
	return Vector2(2050 + sin(day_clock * 0.3) * 170, 1190)

func drip_open() -> bool:
	return fposmod(day_clock, 4.5) >= 2.7

func _begin_day() -> void:
	stage = int((day - 1) / 5)
	position = HIVE
	velocity = Vector2.ZERO
	cargo = 0
	roof_carried = false
	escort_roof = false
	carried_seed = -1
	day_finished = false
	day_delivered = 0
	day_spills = 0
	day_clock = 0
	homecoming_time = -1.0
	moving_hold = 0
	rain_exposure = 0
	drops.clear()
	visited.clear()
	drip_hit_points.clear()
	drip_hit_flash = 0.0
	daily_done.clear()
	if day == 12 and companions.is_empty():
		for i in range(COMPANION_COUNT):
			companions.append({"position": SHELTERS[2 + i], "waiting": true, "exposure": 0.0, "grace": 0.0, "joined": false, "heading": PI})
	elif day > 12:
		for i in range(companions.size()):
			companions[i].position = HIVE + Vector2(-18 * (i + 1), 0)
			companions[i].waiting = false
			companions[i].joined = true
			companions[i].exposure = 0.0
			companions[i].grace = 2.0
	if day == 14:
		for i in range(companions.size()):
			companions[i].position = roof_position() + Vector2(-40 + i * 20, 24)
			companions[i].waiting = true
			companions[i].joined = false
	notice = today().hint
	dawn_state = snapshot()

func snapshot() -> Dictionary:
	# Dawn-only checkpoint; no partially carried items are persisted.
	return {"schema": 1, "day": day, "built_site": built_site, "pollinated": pollinated.keys(), "cleared": cleared.keys(), "rack_stock": rack_stock, "route_revealed": route_revealed, "beetle_home": beetle_home, "delivered": delivered, "dry_days": dry_days, "deliveries": deliveries, "spills": spills, "rescues": rescues, "completed_days": completed_days.duplicate(), "complete": complete}

func _whole(value, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and value >= low and value <= high

func restore(data: Dictionary) -> bool:
	if data.get("schema") != 1 or not _whole(data.get("day"), 1, 15):
		return false
	if not _whole(data.get("built_site"), -1, 1):
		return false
	for key in ["rack_stock", "delivered", "dry_days", "deliveries", "spills", "rescues"]:
		if not _whole(data.get(key), 0, 100000):
			return false
	for key in ["complete", "route_revealed", "beetle_home"]:
		if not data.get(key) is bool:
			return false
	var saved_day := int(data.day)
	var finished = data.get("completed_days", [])
	if saved_day < 1 or saved_day > 15 or not finished is Array:
		return false
	var ended: bool = data.get("complete", false) == true
	if ended and saved_day != 15:
		return false
	if finished.size() != (15 if ended else saved_day - 1):
		return false
	for i in range(finished.size()):
		if finished[i] != i + 1:
			return false
	var site := int(data.get("built_site", -1))
	if site < -1 or site >= BUILD_SITES.size() or (saved_day > 3 and site < 0):
		return false
	for key in ["pollinated", "cleared"]:
		if not data.get(key, []) is Array:
			return false
		var seen: Dictionary = {}
		for entry in data.get(key, []):
			if seen.has(str(entry)):
				return false
			seen[str(entry)] = true
			if not str(entry).is_valid_int() or int(entry) < 0 or int(entry) >= (2 if key == "pollinated" else 3):
				return false
	if saved_day <= 3 and site != -1:
		return false
	if data.get("pollinated", []).size() != (2 if saved_day > 4 else 0) or data.get("cleared", []).size() != (3 if saved_day > 7 else 0):
		return false
	if saved_day > 6 and not data.route_revealed:
		return false
	if saved_day > 9 and not data.beetle_home:
		return false
	day = saved_day
	built_site = site
	pollinated.clear()
	cleared.clear()
	for key in data.get("pollinated", []):
		pollinated[str(key)] = true
	for key in data.get("cleared", []):
		cleared[str(key)] = true
	rack_stock = maxi(0, int(data.get("rack_stock", 0)))
	route_revealed = data.get("route_revealed", false) == true
	beetle_home = data.get("beetle_home", false) == true
	beetle_position = beetle_rest_position() if beetle_home else Calendar.DAYS[8].start
	delivered = maxi(0, int(data.get("delivered", 0)))
	dry_days = maxi(0, int(data.get("dry_days", 0)))
	deliveries = maxi(0, int(data.get("deliveries", 0)))
	spills = maxi(0, int(data.get("spills", 0)))
	rescues = maxi(0, int(data.get("rescues", 0)))
	completed_days.clear()
	events_done.clear()
	for value in finished:
		completed_days.append(int(value))
		for event in event_catalog.values():
			if int(event.order) == int(value):
				record_event(event.id)
	companions.clear()
	if day >= 12:
		for i in range(COMPANION_COUNT):
			companions.append({"position": SHELTERS[2 + i] if day == 12 else HIVE + Vector2(-18 * (i + 1), 0), "waiting": day == 12, "joined": day > 12, "grace": 2.0, "exposure": 0.0, "heading": PI})
	complete = ended
	_begin_day()
	day_finished = ended
	return true

func next_day() -> bool:
	if not day_finished or complete or day >= 15:
		return false
	day += 1
	_begin_day()
	return true

func work_ready() -> bool:
	match today().mode:
		"scout": return visited.size() == today().points.size()
		"drips": return day_delivered >= 1
		"build": return built_site >= 0
		"pollinate": return pollinated.size() == 2
		"gutter": return cleared.size() == 3
		"beetle": return beetle_home
		"rescue": return home_companions() == COMPANION_COUNT
		"leaf_delivery": return day_delivered >= int(today().quota) and visited.size() >= 2
		"rack": return daily_done.has("rest") and day_delivered >= int(today().quota)
		"moving": return daily_done.has("rest") and day_delivered >= int(today().quota) and moving_hold >= 1.2
		"mastery", "wind", "final": return day_delivered >= int(today().quota) and home_companions() == COMPANION_COUNT
		_: return day_delivered >= int(today().get("quota", 1))

func _remaining(points: Array, done: Dictionary) -> Array:
	var result: Array = []
	for i in range(points.size()):
		if not done.has(str(i)):
			result.append(points[i])
	return result

func work_progress() -> String:
	match today().mode:
		"scout": return "  %d / %d" % [visited.size(), today().points.size()]
		"pollinate": return "  %d / 2" % pollinated.size()
		"gutter": return "  %d / 3" % cleared.size()
		"rescue": return "  %d / 5 回巢" % home_companions()
		_: return "  %d / %d" % [day_delivered, int(today().quota)] if today().has("quota") else ""

func moving_stage_hint() -> String:
	if moving_hold < 1.2:
		return "第 1 / 2 步 · 取一份粉，跟随移动叶影。叶下进度 %d%%" % mini(99, int(moving_hold / 1.2 * 100))
	return rest_stage_hint()

func rest_stage_hint() -> String:
	if daily_done.has("rest"):
		return "已在叶台歇脚。花粉还在身上，带回蜂巢。" + delivery_hint()
	if cargo <= 0:
		return "先到花田取粉，再到新叶台歇脚。" + delivery_hint()
	return "到新叶台慢下来，按空格歇脚；花粉最终送回巢。"

func delivery_hint() -> String:
	return " 已送回 %d / %d · 身上 %d / 3" % [day_delivered, int(today().get("quota", 1)), cargo]

func forage_stage_hint() -> String:
	if not waiting_companion_points().is_empty():
		return "有伙伴停下了，沿指引回去慢飞接应。" + delivery_hint()
	if day_delivered >= int(today().quota):
		return "花粉已送够，等五位伙伴都到巢门，再按空格收工。"
	if cargo <= 0:
		return "带伙伴到右边花田，按空格取粉，再送回巢。" + delivery_hint()
	return "带花粉和伙伴回巢，按空格交粉。途中掉粉可以接回。" + delivery_hint()

func waiting_companion_points() -> Array:
	var points: Array = []
	for bee in companions:
		if not bee.joined or bee.waiting:
			points.append(bee.position)
	return points

func wind_stage_hint() -> String:
	var missing := waiting_companion_points().size()
	if missing > 0:
		return "第 1 / 3 步 · 到伙伴身边慢下来接应。已会合 %d / 5，伙伴在叶台避雨。" % (COMPANION_COUNT - missing) if not daily_done.has("rendezvous") else "有伙伴停下了，跟随指引回去，慢下来接上它。"
	if cargo <= 0 and day_delivered < int(today().quota):
		return "第 2 / 3 步 · 伙伴齐了，带大家去右边花田，按空格取一份粉。"
	return "第 3 / 3 步 · 带花粉和五位伙伴回巢，过弯时照顾队尾。"

func objective_points() -> Array:
	if day_finished or work_ready():
		return [HIVE]
	match today().mode:
		"scout":
			var result: Array = []
			for i in range(today().points.size()):
				if not visited.has(str(i)):
					result.append(today().points[i])
			return result
		"build": return BUILD_SITES if roof_carried else [ROOF_PICKUP]
		"pollinate": return _remaining(Calendar.DAYS[3].points, pollinated) if cargo > 0 else [FLOWERS]
		"gutter": return [today().target] if carried_seed >= 0 else _remaining(today().points, cleared)
		"beetle": return [today().target] if escort_roof else [beetle_position]
		"rack": return ([HIVE] if daily_done.has("rest") else [roof_position()]) if cargo > 0 else [FLOWERS]
		"moving": return [moving_roof_position() if moving_hold < 1.2 else (HIVE if daily_done.has("rest") else roof_position())] if cargo > 0 else [FLOWERS]
		"mastery", "final":
			var missing := waiting_companion_points()
			return missing if not missing.is_empty() else ([HIVE] if cargo > 0 or day_delivered >= int(today().quota) else [FLOWERS])
		"wind":
			var missing := waiting_companion_points()
			return missing if not missing.is_empty() else ([HIVE] if cargo > 0 or day_delivered > 0 else [FLOWERS])
		"rescue":
			var result: Array = []
			for bee in companions:
				if not bee.joined or bee.waiting:
					result.append(bee.position)
			return result if not result.is_empty() else [HIVE]
		_: return [HIVE] if cargo > 0 else [FLOWERS]

func _update_day(delta: float) -> void:
	var mode: String = today().mode
	if mode == "scout":
		for i in range(today().points.size()):
			if position.distance_to(today().points[i]) < 45:
				visited[str(i)] = true
	if mode == "leaf_delivery" and cargo > 0:
		for i in range(SHELTERS.size()):
			if position.distance_to(SHELTERS[i]) < 160:
				visited[str(i)] = true
	if mode == "moving" and cargo > 0 and position.distance_to(moving_roof_position()) < 115:
		moving_hold = minf(1.2, moving_hold + delta)
	if mode == "beetle" and escort_roof and beetle_position.distance_to(position) < 135:
		if beetle_position.distance_to(position) > 25:
			beetle_position = beetle_position.move_toward(position, 65 * delta)
		if beetle_position.distance_to(today().target) < 65:
			beetle_home = true
			escort_roof = false
	if beetle_home:
		beetle_position = beetle_position.move_toward(beetle_rest_position(), 90 * delta)
	if day == 6 and work_ready():
		route_revealed = true

func roof_position() -> Vector2:
	return BUILD_SITES[built_site] if built_site >= 0 else BUILD_SITE

func roof_radius() -> float:
	return ROOF_RADII[built_site] if built_site >= 0 else 0.0

func cargo_capacity() -> int:
	return CAPACITY - (1 if roof_carried or carried_seed >= 0 else 0)

func wind_force() -> float:
	return (-110.0 if day >= 14 else 65.0) * (0.8 + sin(elapsed * 0.45) * 0.2)

func drip_gaps() -> Array:
	return Calendar.DAYS[4].points if day == 5 else []

func drip_gap(point: Vector2) -> bool:
	for center: Vector2 in drip_gaps():
		if ((point - center) / Vector2(52, 100)).length_squared() < 1.0:
			return true
	return false

func drip_position(center: Vector2) -> Vector2:
	return center + Vector2(0, -90 + fposmod(day_clock, 0.9) / 0.9 * 180)

func sheltered(point: Vector2) -> bool:
	if drip_gap(point):
		return false
	for center: Vector2 in drip_gaps():
		if point.distance_to(center + Vector2(0, 150)) < 145:
			return true
	if day == 10 and point.distance_to(moving_roof_position()) < 135:
		return true
	if escort_roof and point.distance_to(position) < 135:
		return true
	if cleared.size() == 3 and point.distance_to(Vector2(2470, 1080)) < 215:
		return true
	if point.distance_to(HIVE) < 205.0 or point.distance_to(FLOWERS) < 180.0:
		return true
	for center: Vector2 in SHELTERS:
		if point.distance_to(center) < 215.0:
			return true
	return built_site >= 0 and point.distance_to(roof_position()) < roof_radius()

func rain_strength() -> float:
	return ((0.72 if day >= 14 else 0.6) + sin(elapsed * 0.055) * 0.18) * (lerpf(1.0, 0.08, smoothstep(0, 6, homecoming_time)) if homecoming_time >= 0 else 1.0)

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
	if escort_roof:
		return 130.0
	return 320.0 - (cargo + (1 if roof_carried else 0)) * 24.0

func step(delta: float, steering: Vector2, braking: bool) -> void:
	if complete or day_finished or delta <= 0.0:
		return
	if homecoming_time >= 0:
		homecoming_time += delta
	drip_hit_flash = maxf(0.0, drip_hit_flash - delta)
	elapsed += delta
	day_clock += delta
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
			day_spills += 1
			drops.append(position)
			rain_exposure = -0.65
			notice = "花粉落下了。靠近黄色散粉，按空格取回；也可以先回叶下。"
	else:
		rain_exposure = move_toward(rain_exposure, 0.0, delta * 2.0)
	_update_drip_hits(delta)
	_update_companions(delta)
	_update_day(delta)
	if day == 14 and waiting_companion_points().is_empty():
		daily_done["rendezvous"] = true

func _update_drip_hits(delta: float) -> void:
	if day != 5 or drip_open() or not drip_gap(position):
		return
	var pulse := int(floor(day_clock / 0.9))
	for i in range(drip_gaps().size()):
		var key := "%d:%d" % [i, pulse]
		var drop := drip_position(drip_gaps()[i])
		# Swept fall segment prevents a low frame rate skipping the impact.
		var previous := drop - Vector2(0, minf(delta * 200, 180))
		if Geometry2D.get_closest_point_to_segment(position, previous, drop).distance_to(position) < 23 and not drip_hit_points.has(key):
			drip_hit_points[key] = true
			velocity *= 0.25
			drip_hit_flash = 1.2
			if cargo > 0:
				cargo -= 1
				spills += 1
				day_spills += 1
				drops.append(position)
				notice = "水滴打落一份花粉，靠近散粉按空格取回。"
			else:
				notice = "水滴打慢了翅膀，等停水再飞，或从下方叶下绕行。"

func roof_available() -> bool:
	return today().mode == "build" and built_site < 0 and not roof_carried and not day_finished

func can_take_roof() -> bool:
	return roof_available() and (position.distance_to(ROOF_PICKUP) < 90 or position.distance_to(HIVE) < 130)

func act() -> String:
	if complete or day_finished:
		return ""
	var mode: String = today().mode
	if can_take_roof():
		roof_carried = true
		return "roof"
	if mode == "build" and roof_carried:
		for i in range(BUILD_SITES.size()):
			if position.distance_to(BUILD_SITES[i]) < 85:
				built_site = i
				roof_carried = false
				notice = "叶台撑好了，以后每天都能来这里避雨。回巢收工。"
				return "build"
	if mode == "pollinate" and cargo > 0:
		for i in range(today().points.size()):
			if not pollinated.has(str(i)) and position.distance_to(today().points[i]) < 65:
				cargo -= 1
				pollinated[str(i)] = true
				return "pollinate"
	if mode == "gutter":
		if carried_seed >= 0 and position.distance_to(today().target) < 75:
			cleared[str(carried_seed)] = true
			carried_seed = -1
			return "clear"
		if carried_seed < 0:
			for i in range(today().points.size()):
				if not cleared.has(str(i)) and position.distance_to(today().points[i]) < 65:
					carried_seed = i
					return "seed"
	if mode == "beetle" and not beetle_home and position.distance_to(beetle_position) < 70:
		escort_roof = true
		return "roof"
	if mode in ["rack", "moving"] and not daily_done.has("rest") and cargo > 0 and position.distance_to(roof_position()) < 85 and velocity.length() < 105:
		if mode != "moving" or moving_hold >= 1.2:
			daily_done["rest"] = true
			rain_exposure = 0
			return "rest"
	if position.distance_to(HIVE) < 80:
		if cargo > 0:
			day_delivered += cargo
			delivered += cargo
			cargo = 0
			deliveries += 1
		if day == 15 and work_ready() and homecoming_time < 0:
			homecoming_time = 0
			return "deliver"
		if work_ready():
			day_finished = true
			completed_days.append(day)
			record_event(event_today().id)
			if day == 13 and day_spills == 0:
				dry_days += 1
			complete = day == 15
			notice = "今天的事做完了，回巢歇一会儿。"
			return "day_end"
		notice = today().hint
		return "deliver"
	if cargo < cargo_capacity():
		for i in range(drops.size()):
			if position.distance_to(drops[i]) < 62:
				drops.remove_at(i)
				cargo += 1
				rain_exposure = -0.8
				return "recover"
		if position.distance_to(FLOWERS) < 80:
			cargo += 1
			return "load"
	return ""

func action_label() -> String:
	if homecoming_time >= 0:
		return "空格 · 收工" if position.distance_to(HIVE) < 80 else "回巢 · 收工"
	if roof_available():
		return "空格 · 带上遮雨叶" if can_take_roof() else "到巢门右侧带叶"
	if position.distance_to(HIVE) < 80:
		if work_ready() or cargo > 0:
			return "空格 · 交货 / 收工"
		if today().mode == "build" and not roof_carried:
			return "空格 · 带上遮雨叶"
	if roof_carried:
		return "空格 · 在支点撑叶"
	if today().mode == "gutter":
		if carried_seed >= 0:
			return "空格 · 放下种壳" if position.distance_to(today().target) < 75 else "跟随指引 · 到种壳堆"
		return "空格 · 搬起种壳"
	if today().mode == "pollinate" and cargo > 0:
		return "空格 · 给花传粉"
	if today().mode == "beetle":
		if beetle_home:
			return "回巢 · 收工"
		if escort_roof:
			return "Shift · 慢慢带它走"
		return "空格 · 接起叶篷" if position.distance_to(beetle_position) < 70 else "跟着指引找小甲虫"
	if today().mode == "wind" and not waiting_companion_points().is_empty():
		return "Shift · 靠近伙伴接应"
	if today().mode == "moving" and cargo > 0 and moving_hold < 1.2:
		return "跟随叶影 · 留在叶下"
	if today().mode in ["rack", "moving"] and cargo > 0:
		return "带粉回巢" if daily_done.has("rest") else "空格 · 叶台歇脚"
	return "空格 · 取粉 / 接回散粉"

func _update_companions(delta: float) -> void:
	if homecoming_time >= 0:
		for i in range(companions.size()):
			var target := HIVE + Vector2(-66 + i * 33, 56 + (i % 2) * 20)
			var movement: Vector2 = target - companions[i].position
			if movement.length() > 3:
				companions[i].heading = lerp_angle(float(companions[i].heading), movement.angle(), minf(1, delta * 5))
			companions[i].position = (companions[i].position as Vector2).move_toward(target, delta * 45)
		return
	var leader := position
	for bee in companions:
		bee.grace = maxf(0.0, float(bee.grace) - delta)
		var p: Vector2 = bee.position
		if bee.waiting:
			if p.distance_to(position) < 65.0 and velocity.length() < 105.0:
				bee.waiting = false
				if bee.joined:
					rescues += 1
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
