extends "res://playtest/rain_route/route_model.gd"

const PLACES := {
	"门前": Vector2(520, 960), "树桩": Vector2(790, 820), "亮叶": Vector2(970, 1490),
	"近花": Vector2(900, 1140), "池岸": Vector2(1410, 1310), "叶台": Vector2(1800, 930),
	"池花": Vector2(2380, 1190), "远花": Vector2(3160, 900), "草地": Vector2(1960, 1640),
	"甲虫家": Vector2(1565, 1468), "北路": Vector2(1400, 500), "北花": Vector2(2660, 480)
}
const EXTRA_ROOF_PLACES := ["近花", "池岸", "池花", "草地", "北路", "北花", "树桩"]
const NECTAR_DESK := HIVE + Vector2(-60, 70)
const POLLEN_DESK := HIVE + Vector2(65, 70)
var term_index := 0
var calendar: Array = []
var world: Dictionary = {}
var food_kind := ""
var body_pollen := false
var objects: Array[Dictionary] = []
var carried := -1
var visits: Dictionary = {}
var delivered_kinds: Dictionary = {}
var source_visits: Dictionary = {}
var pulse := 0.0
var pulse_point := Vector2.ZERO
var reaction_text := ""
var chapter_departure := false
# Derived geometry: rebuild on world load/repair, never scan history per raindrop.
var repaired_roofs := PackedVector2Array()
var source_stock: Array[int] = []
var novice_collected := false

func calendar_path() -> String:
	return "res://playtest/spring/spring_calendar.json"

func chapter_count() -> int:
	return 6

func place_point(name: String) -> Vector2:
	return PLACES[name]

func configure(index: int, inherited_world: Dictionary = {}) -> void:
	calendar = JSON.parse_string(FileAccess.get_file_as_string(calendar_path())).chapters
	term_index = index
	world = inherited_world.duplicate(true)
	built_site = int(world.get("built_site", -1))
	beetle_home = bool(world.get("beetle_home", false))
	_rebuild_repaired_roofs()
	day = 1
	completed_days.clear()
	complete = false
	start_day()

func today() -> Dictionary:
	if calendar.is_empty():
		return {"mode": "visit", "places": ["门前"], "title": "认认门前的路", "id": "spring_init", "hint": "认认门前的路"}
	return calendar[term_index].days[day - 1]

func event_today() -> Dictionary:
	return {"id": today().id, "title": today().title, "order": day}

func start_day() -> void:
	social.reset()
	stage = int((day - 1) / 5)
	position = HIVE
	velocity = Vector2.ZERO
	cargo = 0
	food_kind = ""
	body_pollen = false
	carried = -1
	day_delivered = 0
	day_finished = false
	day_clock = 0
	homecoming_time = -1
	rain_exposure = 0
	drops.clear()
	visits.clear()
	source_visits.clear()
	delivered_kinds.clear()
	objects.clear()
	source_stock.assign([2, 1, 1])
	novice_collected = false
	companions.clear()
	daily_done.clear()
	pulse = 0
	var mode: String = today().mode
	food_kind = "nectar" if mode in ["nectar", "wind"] else "pollen"
	for i in range(today().places.size()):
		var target: Vector2 = place_point(today().places[i])
		var origin := target + Vector2(-140 - i * 22, 100 + i * 30)
		objects.append({"point": origin, "origin": origin, "target": target, "done": false, "shape": i % 3})
	if mode in ["escort", "convoy"] or today().get("variation") == "novice":
		for i in range(COMPANION_COUNT):
			var point: Vector2 = place_point(today().places[i % today().places.size()]) if mode == "escort" else HIVE
			companions.append({"position": point + Vector2.from_angle(-PI / 2 + i * TAU / 5) * (52 if mode == "escort" else 84), "waiting": mode == "escort", "joined": mode != "escort", "exposure": 0.0, "grace": 2.0, "heading": 0.0})
	if mode == "dual":
		food_kind = "pollen"
	dawn_state = snapshot()

func snapshot() -> Dictionary:
	return {"schema": 1, "term": term_index, "day": day, "completed_days": completed_days.duplicate(), "complete": complete, "world": world.duplicate(true)}

static func valid_world(value) -> bool:
	if not value is Dictionary or value.size() > 512:
		return false
	for key in value:
		var item = value[key]
		if key in ["beetle_home", "cleared_gutter"]:
			if not item is bool:
				return false
		elif key in ["pollen", "nectar", "built_site"]:
			if not (item is int or item is float) or not is_finite(float(item)) or float(item) != floor(float(item)) or item < (-1 if key == "built_site" else 0) or item > (1 if key == "built_site" else 100000):
				return false
		elif item is Dictionary:
			if item.get("kind") not in ["wake", "pollinate", "haul", "sign", "catch", "repair", "water", "fan", "wax", "clean", "warm", "seed", "fruit", "share", "festival"]:
				return false
			if item.has("shape") and (not (item.shape is int or item.shape is float) or not is_finite(float(item.shape)) or float(item.shape) != floor(float(item.shape)) or item.shape < 0 or item.shape > 2):
				return false
			for axis in ["x", "y"]:
				if not (item.get(axis) is int or item.get(axis) is float) or not is_finite(float(item[axis])) or item[axis] < 0 or item[axis] > 3600:
					return false
		else:
			return false
	return true

func restore(data: Dictionary) -> bool:
	if data.get("schema") != 1 or not _whole(data.get("term"), 0, chapter_count() - 1) or int(data.term) == 1 or not _whole(data.get("day"), 1, 15):
		return false
	if not data.get("completed_days") is Array or not data.get("complete") is bool or not valid_world(data.get("world")):
		return false
	var expected := 15 if data.complete else int(data.day) - 1
	if data.completed_days.size() != expected or (data.complete and int(data.day) != 15):
		return false
	for i in range(expected):
		if data.completed_days[i] != i + 1:
			return false
	configure(int(data.term), data.world)
	day = int(data.day)
	for value in data.completed_days:
		completed_days.append(int(value))
	start_day()
	complete = data.complete
	day_finished = complete
	return true

func next_day() -> bool:
	if not day_finished or complete:
		return false
	day += 1
	start_day()
	return true

func rain_strength() -> float:
	var strength := [0.0, 0.65, 0.12, 0.0, 0.24, 0.62][term_index] as float
	return strength * (lerpf(1.0, 0.08, smoothstep(0, 6, homecoming_time)) if homecoming_time >= 0 else 1.0)

func wind_force() -> float:
	if term_index == 3:
		return sin(day_clock * 0.18 + day) * 105
	return sin(day_clock * 0.3 + day) * (110 if term_index == 5 else 22) * (1.5 if carried >= 0 else 1.0)

func raining(point: Vector2) -> bool:
	return rain_strength() > 0.05 and food_kind != "nectar" and not sheltered(point)

func sheltered(point: Vector2) -> bool:
	if point.distance_to(HIVE) < 230:
		return true
	for roof: Vector2 in repaired_roofs:
		if point.distance_squared_to(roof) < 240.0 * 240.0:
			return true
	for place: String in EXTRA_ROOF_PLACES:
		if point.distance_to(place_point(place)) < 155:
			return true
	for p: Vector2 in SHELTERS:
		if point.distance_to(p) < 215:
			return true
	return built_site >= 0 and point.distance_to(roof_position()) < roof_radius()

func maximum_speed() -> float:
	return 270.0 - cargo * 23 - (45 if carried >= 0 else 0)

func drip_gaps() -> Array:
	return []

func _update_drip_hits(_delta: float) -> void:
	pass

func _update_day(_delta: float) -> void:
	pass

func step(delta: float, steering: Vector2, braking: bool) -> void:
	if complete or day_finished or delta <= 0:
		return
	super.step(delta, steering, braking)
	pulse = maxf(0, pulse - delta)
	if today().get("variation") == "novice" and not novice_collected and not companions.is_empty():
		if (companions[0].position as Vector2).distance_to(sources()[0]) < 30:
			novice_collected = true
			respond(companions[0].position, "新蜂也采到花粉了")
	if today().mode == "catch":
		for i in range(objects.size()):
			if not objects[i].done and carried != i:
				objects[i].point = (objects[i].origin as Vector2) + Vector2(sin(day_clock * 0.6 + i) * 92, cos(day_clock * 0.5 + i) * 36)
	if today().mode in ["visit", "convoy"]:
		for i in range(today().places.size()):
			var p: Vector2 = place_point(today().places[i])
			if position.distance_to(p) < 65 and (today().mode == "visit" or all_near(p, 195)) and not visits.has(str(i)):
				visits[str(i)] = true
				respond(p, "认得这处了")

func _companion_target(index: int) -> Vector2:
	if today().get("variation") == "novice" and social.dance_age < 0:
		if index > 0:
			return HIVE + Vector2.from_angle(-PI / 2 + index * TAU / 5) * 84
		if not novice_collected and position.distance_to(sources()[0]) < 220:
			return sources()[0]
	return super._companion_target(index)

func all_near(point: Vector2, radius: float) -> bool:
	for b in companions:
		if not b.joined or b.waiting or (b.position as Vector2).distance_to(point) > radius:
			return false
	return companions.size() == COMPANION_COUNT

func objects_done() -> int:
	var count := 0
	for item in objects:
		count += 1 if item.done else 0
	return count

func work_ready() -> bool:
	if today().get("variation") == "novice" and (not novice_collected or home_companions() != 5):
		return false
	match today().mode:
		"visit": return visits.size() == today().places.size()
		"escort": return home_companions() == COMPANION_COUNT
		"convoy": return visits.size() == today().places.size() and home_companions() == COMPANION_COUNT
		"pollen", "nectar": return day_delivered >= int(today().get("quota", today().places.size()))
		"wind": return day_delivered >= today().places.size() and source_visits.size() == today().places.size()
		"dual": return delivered_kinds.has("pollen") and delivered_kinds.has("nectar")
		_: return objects_done() == objects.size()

func sources() -> Array:
	var result: Array = []
	for place: String in today().places:
		result.append(place_point(place))
	if today().get("variation") == "sway":
		var base: Vector2 = place_point(today().places[0])
		result = [base + Vector2(sin(day_clock * 0.85) * 78, -65), base + Vector2(-145, 100), base + Vector2(155, 85)]
	return result

func objective_points() -> Array:
	if work_ready():
		return [HIVE]
	var mode: String = today().mode
	if mode in ["escort", "convoy"]:
		var missing := waiting_companion_points()
		if not missing.is_empty():
			return missing
	if mode in ["visit", "convoy"]:
		var result: Array = []
		for i in range(today().places.size()):
			if not visits.has(str(i)):
				result.append(place_point(today().places[i]))
		return result if not result.is_empty() else [HIVE]
	if mode == "escort":
		return [HIVE]
	if mode in ["pollen", "nectar", "wind", "dual"]:
		if today().get("variation") == "novice" and not novice_collected:
			return sources()
		if cargo > 0:
			return [NECTAR_DESK if food_kind == "nectar" else POLLEN_DESK]
		if mode == "wind":
			var unvisited: Array = []
			for i in range(sources().size()):
				if not source_visits.has(str(i)):
					unvisited.append(sources()[i])
			return unvisited
		if today().get("variation") == "sway":
			var available: Array = []
			for i in range(sources().size()):
				if source_stock[i] > 0:
					available.append(sources()[i])
			return available if not available.is_empty() else drops
		return sources()
	if mode == "pollinate" and not body_pollen:
		return [sources()[0] + Vector2(-90, -70)]
	if carried >= 0:
		return [objects[carried].target]
	var targets: Array = []
	for item in objects:
		if not item.done:
			targets.append(item.target if mode in ["wake", "pollinate"] else item.point)
	return targets

func respond(point: Vector2, message: String) -> void:
	pulse = 1.8
	pulse_point = point
	reaction_text = message

func act() -> String:
	if day_finished or complete:
		return ""
	social.dance_age = -1
	var mode: String = today().mode
	if work_ready() and position.distance_to(HIVE) < 80:
		if day == 15 and homecoming_time < 0:
			homecoming_time = 0
			respond(HIVE, "这一段路走通了")
			return "deliver"
		day_finished = true
		completed_days.append(day)
		complete = day == 15
		return "day_end"
	if mode in ["pollen", "nectar", "wind", "dual"]:
		if cargo > 0 and position.distance_to(NECTAR_DESK if food_kind == "nectar" else POLLEN_DESK) < 65 and velocity.length() < 115:
			day_delivered += cargo
			delivered_kinds[food_kind] = true
			world["nectar" if food_kind == "nectar" else "pollen"] = int(world.get(food_kind, 0)) + cargo
			respond(position, "伙伴接过花蜜，转身去处理" if food_kind == "nectar" else "花粉卸进巢房，伙伴把它压实")
			cargo = 0
			social.offer_report(self)
			if mode == "dual":
				food_kind = "nectar" if not delivered_kinds.has("nectar") else "pollen"
			return "deliver"
		if cargo < 3:
			for i in range(sources().size()):
				if position.distance_to(sources()[i]) < (38 if today().get("variation") == "sway" else 70) and (mode != "wind" or not source_visits.has(str(i))):
					if today().get("variation") == "sway":
						if source_stock[i] <= 0:
							continue
						source_stock[i] -= 1
					if mode != "dual":
						food_kind = "nectar" if mode in ["nectar", "wind"] else "pollen"
					cargo += 1
					social.remember_forage(sources()[i])
					source_visits[str(i)] = true
					respond(position, "花蜜收进蜜囊" if food_kind == "nectar" else "把花粉收在后足")
					return "load"
		for i in range(drops.size()):
			if cargo < 3 and position.distance_to(drops[i]) < 62:
				drops.remove_at(i)
				cargo += 1
				return "recover"
	if mode == "pollinate":
		if not body_pollen and position.distance_to(sources()[0] + Vector2(-90, -70)) < 65:
			body_pollen = true
			respond(position, "绒毛沾上少量花粉")
			return "load"
		if not body_pollen:
			return ""
	if mode in ["wake", "pollinate"]:
		for i in range(objects.size()):
			if not objects[i].done and position.distance_to(objects[i].target) < 65:
				objects[i].done = true
				remember(mode, objects[i].target)
				respond(objects[i].target, "小虫挪到草茎，让出花口" if mode == "wake" else "花粉接触柱头，花枝轻轻一动")
				return "help"
	if mode in ["haul", "sign", "catch", "repair"]:
		if carried >= 0:
			if position.distance_to(objects[carried].target) < 65 and velocity.length() < 115:
				objects[carried].done = true
				remember(mode, objects[carried].target, int(objects[carried].shape))
				respond(objects[carried].target, "花牌稳住了，留下了一处路标" if mode in ["sign", "catch"] else "这处路稳了，下次还能用")
				carried = -1
				return "help"
		else:
			for i in range(objects.size()):
				if not objects[i].done and position.distance_to(objects[i].point) < 62:
					carried = i
					return "load"
	return ""

func remember(kind: String, point: Vector2, shape_index := 0) -> void:
	var key := "%s:%d:%d" % [kind, point.x, point.y]
	var born := int(world.get(key, {}).get("born_day", term_index * 15 + day))
	world[key] = {"kind": kind, "x": point.x, "y": point.y, "shape": shape_index}
	if kind == "pollinate":
		world[key]["born_day"] = born
	if kind == "repair":
		_rebuild_repaired_roofs()

func _rebuild_repaired_roofs() -> void:
	repaired_roofs.clear()
	for value in world.values():
		if value is Dictionary and value.get("kind") == "repair":
			repaired_roofs.append(Vector2(float(value.x), float(value.y)))

func hint() -> String:
	if homecoming_time >= 0:
		return "这一段路走通了。可以再待一会儿，到巢门按空格收工。"
	if work_ready():
		return "今天的事做好了。回到巢门，按空格收工。"
	var mode: String = today().mode
	if today().get("variation") == "sway":
		return "晃动花可取两份，也可到两朵稳花各取一份。带回巢：%d / 2 · 身上 %d" % [day_delivered, cargo]
	if today().get("variation") == "novice":
		return "陪新蜂靠近花头，让它亲自采一次；你也带一份粉。" if not novice_collected else "新蜂采到了。带它和你的花粉回巢，慢些过弯。"
	match mode:
		"visit": return "沿金色叶片指引认清地标，靠近后会记住。已到 %d / %d" % [visits.size(), today().places.size()]
		"escort": return "伙伴在路边等候。靠近慢飞接上它们，带五位伙伴一起回巢。"
		"convoy": return "带队经过指引中的落脚点，再一起回巢。全队到齐才算。%d / %d" % [visits.size(), today().places.size()]
		"pollen", "nectar", "wind", "dual":
			var name := "花蜜" if food_kind == "nectar" or mode in ["nectar", "wind"] else "花粉"
			return "带%s到巢门%s，慢下来按空格。身上 %d / 3 · 已送回 %d" % [name, "左侧接蜜处" if name == "花蜜" else "右侧储粉处", cargo, day_delivered] if cargo > 0 else ("两种都要送：先带粉到右侧，再带蜜到左侧。" if mode == "dual" else ("到不同花丛各取一份花蜜，再带回巢。已送回 %d / %d" % [day_delivered, today().places.size()] if mode == "wind" else "去指引中的花取%s，再带回巢。已送回 %d / %d" % [name, day_delivered, today().places.size()]))
		"pollinate": return "先到有金色花心的花边沾粉，再接触指引中的花。" if not body_pollen else "绒毛上的粉带到另一朵花。已传粉 %d / %d" % [objects_done(), objects.size()]
		"wake": return "靠近花口的小虫，按空格轻振翅膀请它换到草茎。%d / %d" % [objects_done(), objects.size()]
		_: return "已带在身上，跟随指引到同形支点，慢下来按空格放好。" if carried >= 0 else "跟随拖痕找到物件，靠近按空格带走。已安放 %d / %d" % [objects_done(), objects.size()]

func action_label() -> String:
	if work_ready():
		return "空格 · 收工" if position.distance_to(HIVE) < 80 else "回巢 · 收工"
	if today().mode in ["visit", "convoy"]:
		return "跟随指引 · 慢飞认路"
	if today().mode == "escort":
		return "Shift · 靠近接应"
	if carried >= 0:
		return "空格 · 稳稳放好"
	if today().mode == "wake":
		return "空格 · 轻振翅膀"
	if today().mode == "pollinate":
		return "空格 · 接触花朵" if body_pollen else "空格 · 绒毛沾粉"
	if today().mode in ["pollen", "nectar", "wind", "dual"]:
		var desk: Vector2 = NECTAR_DESK if food_kind == "nectar" else POLLEN_DESK
		if cargo > 0 and position.distance_to(desk) < 100:
			return "空格 · 交给接蜜伙伴" if food_kind == "nectar" else "空格 · 卸进储粉处"
		return "空格 · 取花蜜" if food_kind == "nectar" else "空格 · 取花粉"
	return "空格 · 带起物件"
