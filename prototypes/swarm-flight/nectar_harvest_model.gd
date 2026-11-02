extends RefCounted
## Independent harvest-economy experiment. No legacy journey state is mutated.
const Canopy = preload("res://leaf_canopy_geometry.gd")
const RAIN_SHELTER := {"pos":Vector2(2760,660),"half_width":160.0}
const WORLD_WIDTH := 3600.0
const HOME := Vector2(230,575)
const GATE_X := 1780.0
const CHARGE_READY := 0.32
const SAVE_ID := "nectar-harvest-v1"
const SAVE_VERSION := 1
const SHORTCUTS := [Vector2(1040,400),Vector2(3000,400)]
const UPGRADE_IDS := ["gather1","gather2","reach","twin","bag1","wings1","bag2","wings2","meadow","shortcut","market","reserve"]
var chapter := {"region":0}
var p := HOME
var v := Vector2.ZERO
var face := Vector2.RIGHT
var camera_x := 0.0
var phase := "home"
var energy := 85.0
var charge := 0.0
var charging := false
var burst_left := 0.0
var coins := 0
var cargo := {"blue":0,"rose":0}
var flowers: Array[Dictionary] = []
var owned: Array[String] = []
var events: Array[Dictionary] = []
var completed := false
var trip_index := 0
var sold_total := 0
var rose_sold := 0
var visited_meadow := false
var harvesting_ids: Array[String] = []
var _full_announced := false

func _init() -> void:
	flowers = flower_layout()

static func flower_layout() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var near := [Vector2(620,520),Vector2(800,385),Vector2(960,570),Vector2(1120,300),Vector2(1280,450),Vector2(1440,590),Vector2(1600,330)]
	var far := [Vector2(2110,390),Vector2(2280,565),Vector2(2450,300),Vector2(2630,485),Vector2(2820,310),Vector2(3040,555),Vector2(3270,375)]
	for region in 2:
		var positions: Array = near if region == 0 else far
		for i in positions.size():
			var amount := 12 if region == 0 else 16
			result.append({"id":("blue_" if region == 0 else "rose_")+str(i),"pos":positions[i],"type":"blue" if region == 0 else "rose","stock":amount,"max":amount,"region":region,"progress":0.0})
	return result

func emit(kind: String,where: Vector2,amount := 0) -> void:
	events.append({"kind":kind,"pos":where,"amount":amount})

func at_home() -> bool: return phase == "home" and p.distance_to(HOME) <= 130.0
func cargo_total() -> int: return int(cargo.blue)+int(cargo.rose)
func cargo_value() -> int:
	var base := int(cargo.blue)+int(cargo.rose)*3
	return base+int(floor(base*0.25)) if "market" in owned else base
func capacity() -> int: return 48 if "bag2" in owned else 30 if "bag1" in owned else 18
func max_energy() -> float: return 145.0 if "wings2" in owned else 110.0 if "wings1" in owned else 85.0
func harvest_radius() -> float: return 155.0 if "reach" in owned else 100.0
func harvest_rate() -> float: return 11.0 if "gather2" in owned else 7.5 if "gather1" in owned else 5.0
func rain_floor_at(x: float) -> float:
	return minf(800.0,Canopy.top_at(x,RAIN_SHELTER))
func rain_exposed() -> bool: return phase == "field" and p.x >= 2600.0 and p.x <= 2920.0 and p.y < rain_floor_at(p.x)

func upgrade_defs() -> Array:
	return [
		{"id":"gather1","name":"轻巧采蜜","description":"每秒采蜜 5 → 7.5 份","cost":12,"branch":0,"row":0,"requires":[]},
		{"id":"gather2","name":"熟练采蜜","description":"每秒采蜜 7.5 → 11 份","cost":32,"branch":0,"row":1,"requires":["gather1"]},
		{"id":"reach","name":"花香触角","description":"吸到更远的花蜜（范围 +55%）","cost":48,"branch":0,"row":2,"requires":["gather2"]},
		{"id":"twin","name":"一簇接一簇","description":"同时采集范围内的两朵花","cost":85,"branch":0,"row":3,"requires":["reach"]},
		{"id":"bag1","name":"舒展蜜囊","description":"携带上限 18 → 30","cost":18,"branch":1,"row":0,"requires":[]},
		{"id":"wings1","name":"轻盈双翼","description":"续航上限 85 → 110","cost":25,"branch":1,"row":1,"requires":["bag1"]},
		{"id":"bag2","name":"丰收蜜囊","description":"携带上限 30 → 48","cost":55,"branch":1,"row":2,"requires":["wings1"]},
		{"id":"wings2","name":"远行双翼","description":"续航上限 110 → 145","cost":75,"branch":1,"row":3,"requires":["bag2"]},
		{"id":"meadow","name":"开往紫花地","description":"开放远方花地；先买任一初期成长","cost":90,"branch":2,"row":0,"requires":[]},
		{"id":"shortcut","name":"叶间近道","description":"开通池岸与远方花地的双向近道","cost":65,"branch":2,"row":1,"requires":["meadow"]},
		{"id":"market","name":"蜂巢好口碑","description":"每次售卖获得额外 25% 金币","cost":90,"branch":2,"row":2,"requires":["shortcut"]},
		{"id":"reserve","name":"备好花蜜","description":"交售过 18 份紫花蜜后，为蜂巢备好储粮","cost":180,"branch":2,"row":3,"requires":["market"]}
	]

func upgrade(id: String) -> Dictionary:
	for definition in upgrade_defs():
		if definition.id == id: return definition
	return {}

func locked_reason(id: String) -> String:
	var definition := upgrade(id)
	if definition.is_empty(): return "未知成长"
	if id in owned: return "已经拥有"
	if not at_home(): return "回蜂巢后购买"
	for prerequisite in definition.requires:
		if prerequisite not in owned: return "先获得："+str(upgrade(prerequisite).name)
	if id == "meadow" and "gather1" not in owned and "bag1" not in owned: return "先购买轻巧采蜜或舒展蜜囊"
	if id == "reserve" and (not visited_meadow or rose_sold < 18): return "先探索花地并交售 18 份紫花蜜（%d / 18）" % rose_sold
	if coins < int(definition.cost): return "还需 %d 金币" % (int(definition.cost)-coins)
	return ""

func can_buy(id: String) -> bool: return locked_reason(id).is_empty()

func buy(id: String) -> bool:
	if not can_buy(id): return false
	coins -= int(upgrade(id).cost)
	owned.append(id)
	energy = max_energy()
	emit("buy",HOME,int(upgrade(id).cost))
	if id in ["meadow","shortcut"]: emit("unlock",HOME)
	if id == "reserve":
		completed = true
		emit("complete",HOME)
	return true

func sell() -> int:
	if not at_home() or cargo_total() == 0: return 0
	var value := cargo_value()
	coins += value
	sold_total += cargo_total()
	rose_sold += int(cargo.rose)
	cargo = {"blue":0,"rose":0}
	_full_announced = false
	emit("sell",HOME,value)
	return value

func clear_controls() -> void:
	charge = 0.0
	charging = false
	harvesting_ids.clear()

func _depart() -> void:
	phase = "field"
	trip_index += 1
	for flower in flowers:
		flower.stock = flower.max
		flower.progress = 0.0
	emit("depart",p,trip_index)

func _return() -> void:
	phase = "home"
	energy = max_energy()
	v = Vector2.ZERO
	burst_left = 0.0
	clear_controls()
	emit("return",p,cargo_total())

func _rescue() -> void:
	var before := cargo_total()
	cargo.blue = int(floor(float(cargo.blue)*0.5))
	cargo.rose = int(floor(float(cargo.rose)*0.5))
	p = HOME
	_return()
	camera_x = 0.0
	_full_announced = false
	emit("rescue",HOME,before-cargo_total())

func use_shortcut() -> bool:
	if "shortcut" not in owned or phase != "field": return false
	for i in 2:
		if p.distance_to(SHORTCUTS[i]) <= 115.0:
			p = SHORTCUTS[1-i]
			v = Vector2.ZERO
			burst_left = 0.0
			clear_controls()
			visited_meadow = true
			camera_x = clampf(p.x-480.0,0.0,WORLD_WIDTH-1280.0)
			emit("unlock",p)
			return true
	return false

func step(delta: float,move: Vector2,collect: bool,space_held: bool) -> void:
	if not is_finite(delta) or delta <= 0.0 or not move.is_finite(): return
	var dt := minf(delta,0.1)
	move = move.limit_length(1.0)
	harvesting_ids.clear()
	if cargo_total() < capacity(): _full_announced = false
	if burst_left <= 0.0:
		if not move.is_zero_approx(): face = move.normalized()
		if space_held:
			charging = true
			charge = minf(CHARGE_READY,charge+dt)
		elif charging:
			if charge >= CHARGE_READY and energy >= 4.0:
				burst_left = 0.32
				energy -= 4.0
				emit("dash",p)
			charging = false
			charge = 0.0
	if burst_left > 0.0:
		v = face*500.0
		burst_left = maxf(0.0,burst_left-dt)
	else:
		var speed := 135.0 if charging else 230.0
		v = v.move_toward(move*speed,(1800.0 if move.is_zero_approx() else 1300.0)*dt)
	p += v*dt
	var right := WORLD_WIDTH-80.0 if "meadow" in owned else GATE_X-60.0
	var limited := Vector2(clampf(p.x,80.0,right),clampf(p.y,160.0,650.0))
	if limited.x != p.x: v.x = 0.0
	if limited.y != p.y: v.y = 0.0
	p = limited
	# Hysteresis makes one actual departure one resource refresh.
	if phase == "home" and p.distance_to(HOME) > 180.0: _depart()
	elif phase == "field" and p.distance_to(HOME) <= 130.0: _return()
	if phase == "home":
		energy = max_energy()
	else:
		energy = maxf(0.0,energy-dt*(0.7+(1.8 if rain_exposed() else 0.0)))
		if energy <= 0.0:
			_rescue()
			return
		if p.x > GATE_X: visited_meadow = true
		if collect and not charging and burst_left <= 0.0:
			_harvest(dt)
	camera_x = clampf(p.x-480.0,0.0,WORLD_WIDTH-1280.0)

func _harvest(dt: float) -> void:
	if cargo_total() >= capacity():
		if not _full_announced:
			emit("full",p,capacity())
			_full_announced = true
		return
	var candidates: Array[Dictionary] = []
	for flower in flowers:
		if int(flower.stock) > 0 and p.distance_to(flower.pos) <= harvest_radius() and (int(flower.region) == 0 or "meadow" in owned): candidates.append(flower)
	candidates.sort_custom(func(a,b): return p.distance_squared_to(a.pos) < p.distance_squared_to(b.pos))
	for i in mini(candidates.size(),2 if "twin" in owned else 1):
		var flower: Dictionary = candidates[i]
		if cargo_total() >= capacity(): break
		harvesting_ids.append(flower.id)
		flower.progress = minf(2.0,float(flower.progress)+harvest_rate()*dt)
		var amount := mini(int(floor(float(flower.progress))),mini(int(flower.stock),capacity()-cargo_total()))
		if amount > 0:
			flower.progress -= amount
			flower.stock -= amount
			cargo[flower.type] += amount
			emit("harvest",flower.pos,amount)
			events[-1]["type"] = flower.type
		if int(flower.stock) == 0: flower.progress = 0.0
	if cargo_total() >= capacity() and not _full_announced:
		emit("full",p,capacity())
		_full_announced = true

func goal_text() -> String:
	if completed: return "花蜜备好了 · 继续探索，或回蜂巢歇一歇"
	if "meadow" not in owned:
		if owned.is_empty(): return "带回第一囊花蜜，换一项成长"
		return "攒够 90 金币，开放远方紫花地"
	if not visited_meadow: return "新花地已开放 · 飞过池岸右侧的叶门"
	if rose_sold < 18: return "带回紫花蜜 · 已交售 %d / 18" % rose_sold
	if "shortcut" not in owned: return "开通叶间近道，让两处花地连起来"
	if "market" not in owned: return "让蜂巢口碑带来更丰盛的收获"
	return "备好花蜜 · 为蜂巢留出 180 金币的储粮"

func to_payload() -> Dictionary:
	var stock: Array = []
	for flower in flowers: stock.append({"id":flower.id,"stock":flower.stock,"progress":flower.progress})
	return {"id":SAVE_ID,"version":SAVE_VERSION,"p":[p.x,p.y],"v":[v.x,v.y],"face":[face.x,face.y],"phase":phase,"energy":energy,"charge":charge,"charging":charging,"burst_left":burst_left,"coins":coins,"cargo":cargo.duplicate(true),"owned":owned.duplicate(),"flowers":stock,"completed":completed,"trip_index":trip_index,"sold_total":sold_total,"rose_sold":rose_sold,"visited_meadow":visited_meadow}

static func number(value) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func whole(value,low: int,high: int) -> bool:
	return number(value) and float(value) == floor(float(value)) and float(value) >= low and float(value) <= high

static func pair(value) -> bool:
	return value is Array and value.size() == 2 and number(value[0]) and number(value[1])

static func keys_match(value: Dictionary,keys: Array) -> bool:
	if value.size() != keys.size(): return false
	for key in keys:
		if not value.has(key): return false
	return true

func restore_payload(data) -> bool:
	if not data is Dictionary: return false
	if not keys_match(data,to_payload().keys()): return false
	if data.id != SAVE_ID or not whole(data.version,1,1): return false
	for key in ["p","v","face"]:
		if not pair(data[key]): return false
	if data.phase not in ["home","field"]: return false
	for key in ["energy","charge","burst_left"]:
		if not number(data[key]): return false
	for key in ["charging","completed","visited_meadow"]:
		if not data[key] is bool: return false
	for key in ["coins","trip_index","sold_total","rose_sold"]:
		if not whole(data[key],0,1000000000): return false
	if data.rose_sold > data.sold_total: return false
	if not data.cargo is Dictionary or not keys_match(data.cargo,["blue","rose"]): return false
	for kind in ["blue","rose"]:
		if not whole(data.cargo[kind],0,48): return false
	if not data.owned is Array or data.owned.size() > UPGRADE_IDS.size(): return false
	var next_owned: Array[String] = []
	for id in data.owned:
		if not id is String or id not in UPGRADE_IDS or id in next_owned: return false
		next_owned.append(id)
	for id in next_owned:
		for prerequisite in upgrade(id).requires:
			if prerequisite not in next_owned: return false
	if "meadow" in next_owned and "gather1" not in next_owned and "bag1" not in next_owned: return false
	if data.completed != ("reserve" in next_owned): return false
	if data.visited_meadow and "meadow" not in next_owned: return false
	if (int(data.cargo.rose) > 0 or data.rose_sold > 0) and not data.visited_meadow: return false
	if "reserve" in next_owned and (not data.visited_meadow or data.rose_sold < 18): return false
	var limit := 48 if "bag2" in next_owned else 30 if "bag1" in next_owned else 18
	var maximum := 145.0 if "wings2" in next_owned else 110.0 if "wings1" in next_owned else 85.0
	if int(data.cargo.blue)+int(data.cargo.rose) > limit: return false
	if data.energy < 0.0 or data.energy > maximum or data.charge < 0.0 or data.charge > CHARGE_READY or data.burst_left < 0.0 or data.burst_left > 0.32: return false
	if not data.charging and data.charge != 0.0: return false
	if data.charging and data.burst_left > 0.0: return false
	var next_p := Vector2(float(data.p[0]),float(data.p[1]))
	var next_v := Vector2(float(data.v[0]),float(data.v[1]))
	var next_face := Vector2(float(data.face[0]),float(data.face[1]))
	var right := WORLD_WIDTH-80.0 if "meadow" in next_owned else GATE_X-60.0
	if next_p.x < 80.0 or next_p.x > right or next_p.y < 160.0 or next_p.y > 650.0: return false
	if next_v.length() > 500.01 or absf(next_face.length()-1.0) > 0.001: return false
	if data.phase == "home" and next_p.distance_to(HOME) > 180.01: return false
	if data.phase == "field" and (next_p.distance_to(HOME) < 129.99 or data.trip_index < 1 or data.energy <= 0.0): return false
	if data.phase == "home" and data.energy != maximum: return false
	if next_p.x > GATE_X and not data.visited_meadow: return false
	if not data.flowers is Array or data.flowers.size() != flowers.size(): return false
	var next_flowers := flower_layout()
	for i in next_flowers.size():
		var item = data.flowers[i]
		if not item is Dictionary or not keys_match(item,["id","stock","progress"]): return false
		if item.id != next_flowers[i].id or not whole(item.stock,0,int(next_flowers[i].max)): return false
		if not number(item.progress) or item.progress < 0.0 or item.progress >= 2.0: return false
		if item.stock == 0 and item.progress != 0.0: return false
		if next_flowers[i].region == 1 and "meadow" not in next_owned and (item.stock != next_flowers[i].max or item.progress != 0.0): return false
		next_flowers[i].stock = int(item.stock)
		next_flowers[i].progress = float(item.progress)
	# Only commit after every field and cross-field invariant is valid.
	p = next_p
	v = next_v
	face = next_face
	phase = data.phase
	energy = float(data.energy)
	charge = float(data.charge)
	charging = data.charging
	burst_left = float(data.burst_left)
	coins = int(data.coins)
	cargo = {"blue":int(data.cargo.blue),"rose":int(data.cargo.rose)}
	owned = next_owned
	flowers = next_flowers
	completed = data.completed
	trip_index = int(data.trip_index)
	sold_total = int(data.sold_total)
	rose_sold = int(data.rose_sold)
	visited_meadow = data.visited_meadow
	camera_x = clampf(p.x-480.0,0.0,WORLD_WIDTH-1280.0)
	events.clear()
	harvesting_ids.clear()
	_full_announced = false
	return true
