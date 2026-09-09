extends RefCounted

## G-FICTION: bounded route experiment. No Campaign state or persistence writes.
const HIVE := Vector2(360, 900)
const FLOWERS := Vector2(3260, 780)
const BUILD_SITE := Vector2(1800, 930)
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
var cargo := 0
var delivered := 0
var stage := 0
var rain_exposure := 0.0
var drops: Array[Vector2] = []
var companions: Array[Dictionary] = []
var complete := false
var deliveries := 0
var spills := 0
var rescues := 0
var notice := "去右边花田取粉。叶下稳，直路近；装多少由你决定。"

func sheltered(point: Vector2) -> bool:
	if point.distance_to(HIVE) < 205.0 or point.distance_to(FLOWERS) < 180.0:
		return true
	for center: Vector2 in SHELTERS:
		if point.distance_to(center) < 215.0:
			return true
	return stage >= 1 and point.distance_to(BUILD_SITE) < 210.0

func rain_strength() -> float:
	return 0.6 + sin(elapsed * 0.055) * 0.25

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
	return 320.0 - cargo * 24.0

func step(delta: float, steering: Vector2, braking: bool) -> void:
	if complete or delta <= 0.0:
		return
	elapsed += delta
	if steering.length() > 0.08:
		heading = lerp_angle(heading, steering.angle(), 1.0 - exp(-12.0 * delta))
	var acceleration := 700.0 / (1.0 + cargo * 0.45)
	var target := steering.limit_length() * maximum_speed() * (0.40 if braking else 1.0)
	velocity = velocity.move_toward(target, acceleration * delta * (2.6 if braking else 1.0))
	if not sheltered(position):
		var wind := Vector2(-65.0 if stage >= 2 else 65.0, 14.0)
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
	_update_companions(delta)

func act() -> String:
	if complete:
		return ""
	if position.distance_to(HIVE) < 80.0:
		if cargo > 0:
			delivered += cargo
			cargo = 0
			deliveries += 1
			if delivered >= 3 and stage == 0:
				stage = 1
				notice = "中间的新叶台撑起来了！下一趟可以在直路中途避雨。"
			elif delivered >= 6 and stage == 1:
				stage = 2
				for index in range(COMPANION_COUNT):
					companions.append({"position": FLOWERS + Vector2((index - (COMPANION_COUNT - 1) / 2.0) * 18, 35), "waiting": true, "exposure": 0.0, "grace": 0.0, "joined": false, "heading": PI})
				notice = "风向变了。再去花田接五只新蜂，一起把最后的花粉带回来。"
			else:
				notice = "花粉交到巢里了。再选一条飞法。"
			_check_finish()
			return "deliver"
		_check_finish()
		if not complete:
			notice = "还要接回花田的伙伴。" if stage >= 2 else "先去右边的花田取粉。"
		return ""
	if cargo < CAPACITY:
		for index in range(drops.size()):
			if position.distance_to(drops[index]) < 62.0:
				drops.remove_at(index)
				cargo += 1
				rain_exposure = -0.8
				notice = "接回来了。先找片叶子稳住，再看下一阵雨。"
				return "recover"
		if position.distance_to(FLOWERS) < 80.0:
			cargo += 1
			notice = "装了 %d / 3 份。现在出发也可以；越重越要提前转弯。" % cargo
			return "load"
	notice = "花粉已装满，找一条返巢的路。" if cargo == CAPACITY else "靠近花田取粉、落粉取回，或巢门交货。"
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
		notice = "这条路，大家都能走了。"
	elif delivered >= GOAL:
		notice = "花粉够了。把五只伙伴都接到巢门，再按空格一起收工。"
