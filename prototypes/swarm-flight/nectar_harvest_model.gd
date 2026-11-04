extends RefCounted
## Independent harvest-economy experiment. No legacy journey state is mutated.
const Legacy = preload("res://nectar_legacy_model_v2.gd")
const LegacyV4 = preload("res://nectar_legacy_model_v4.gd")
const Encounters = preload("res://nectar_encounters.gd")
const Canopy = preload("res://leaf_canopy_geometry.gd")
const RAIN_SHELTER := {"pos":Vector2(2760,660),"half_width":160.0}
const WORLD_WIDTH := 3600.0
const HUB_SHOP := Vector2(390,540)
const HUB_TREE := Vector2(760,500)
const HUB_JOURNAL := Vector2(1110,440) # Historical probe identifier; no station interaction.
const HUB_DEPART := Vector2(1080,555)
const HOME := HUB_DEPART
const POND_ENTRY := Vector2(470,575)
const POND_EXIT := Vector2(1660,575)
const MEADOW_ENTRY := Vector2(1900,575)
const GATE_X := 1780.0
const CHARGE_READY := 0.32
const SAVE_ID := "nectar-harvest-v1"
const SAVE_VERSION := 5
const REGROW_SECONDS := 18.0
const SHORTCUTS := [Vector2(1040,400),Vector2(3000,400)]
const UPGRADE_IDS := ["gather1","gather2","reach","twin","bag1","wings1","bag2","wings2","meadow","shortcut","market","reserve","beat"]
var chapter := {"region":0}
var p := HOME
var v := Vector2.ZERO
var face := Vector2.RIGHT
var camera_x := 0.0
var phase := "home"
var area := "hub"
var creatures: Array[Dictionary] = []
var hurt_left := 0.0
var energy := 36.0
var field_time := 0.0
var pulse_left := 0.0
var materials := {"fiber":0,"resin":0}
var drops: Array[Dictionary] = []
var charge := 0.0
var charging := false
var burst_left := 0.0
var coins := 0
var cargo := {"blue":0,"rose":0}
var flowers: Array[Dictionary] = []
var owned: Array[String] = []
# Exact v1 ownership inherited at migration; never add new purchases here.
var legacy_owned: Array[String] = []
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
	creatures = Encounters.layout(0)

static func flower_layout(trip := 0) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var near := [Vector2(620,520),Vector2(800,385),Vector2(960,570),Vector2(1120,300),Vector2(1280,450),Vector2(1440,590),Vector2(1600,330)]
	var far := [Vector2(2110,390),Vector2(2280,565),Vector2(2450,300),Vector2(2630,485),Vector2(2820,310),Vector2(3040,555),Vector2(3270,375)]
	for region in 2:
		var positions: Array = near if region == 0 else far
		for i in positions.size():
			var amount := 1
			var jitter := Vector2(sin(float(trip*37+i*17+region*11))*25,cos(float(trip*19+i*13+region*7))*28) if trip > 0 else Vector2.ZERO
			result.append({"id":("blue_" if region == 0 else "rose_")+str(i),"pos":positions[i]+jitter,"type":"blue" if region == 0 else "rose","stock":amount,"max":amount,"region":region,"progress":0.0,"regrow":0.0,"bloom":1.0})
	return result

func emit(kind: String,where: Vector2,amount := 0) -> void:
	events.append({"kind":kind,"pos":where,"amount":amount})

func at_home() -> bool: return area == "hub"
func cargo_total() -> int: return int(cargo.blue)+int(cargo.rose)
func cargo_value() -> int:
	var base := int(cargo.blue)+int(cargo.rose)*3
	return base+int(floor(base*0.25)) if "market" in owned else base
func capacity() -> int: return 16 if "bag2" in owned else 10 if "bag1" in owned else 6
func max_energy() -> float: return 70.0 if "wings2" in owned else 50.0 if "wings1" in owned else 36.0
func harvest_radius() -> float: return 155.0 if "reach" in owned else 100.0
func harvest_rate() -> float: return 1.25 if "gather2" in owned else 1.0/1.2 if "gather1" in owned else 1.0/1.8
func rain_floor_at(x: float) -> float:
	return minf(800.0,Canopy.top_at(x,RAIN_SHELTER))
func rain_exposed() -> bool: return area == "meadow" and p.x >= 2600.0 and p.x <= 2920.0 and p.y < rain_floor_at(p.x)

func upgrade_defs() -> Array:
	return [
		{"id":"gather1","name":"轻巧采蜜","description":"1.8 → 1.2 秒 / 份","cost":4,"branch":0,"row":0,"requires":[]},
		{"id":"gather2","name":"熟练采蜜","description":"1.2 → 0.8 秒 / 份","cost":11,"fiber":2,"branch":0,"row":1,"requires":["gather1"]},
		{"id":"reach","name":"花香触角","description":"采集半径 100 → 155（+55%）","cost":16,"fiber":3,"branch":0,"row":2,"requires":["gather1"]},
		{"id":"twin","name":"双簇采蜜","description":"同时采集范围内的两朵花","cost":29,"resin":3,"branch":0,"row":3,"requires":["gather2","reach"]},
		{"id":"bag1","name":"舒展蜜囊","description":"携带上限 6 → 10","cost":6,"branch":1,"row":0,"requires":[]},
		{"id":"wings1","name":"轻盈双翼","description":"体力 36 → 50","cost":9,"fiber":2,"branch":1,"row":1,"requires":[]},
		{"id":"bag2","name":"丰收蜜囊","description":"携带上限 10 → 16","cost":19,"fiber":3,"branch":1,"row":2,"requires":["bag1"]},
		{"id":"wings2","name":"远行双翼","description":"体力 50 → 70","cost":25,"fiber":4,"resin":2,"branch":1,"row":3,"requires":["wings1"]},
		{"id":"meadow","name":"开往紫花地","description":"开放远方花地；基础能力累计成长3次","cost":30,"branch":2,"row":0,"requires":[]},
		{"id":"shortcut","name":"叶间近道","description":"开通池岸与远方花地的双向近道","cost":22,"branch":2,"row":1,"requires":["meadow"]},
		{"id":"market","name":"好口碑","description":"每次售卖获得额外 25% 金币","cost":30,"branch":2,"row":2,"requires":["meadow"]},
		{"id":"reserve","name":"备好花蜜","description":"交售过 6 份紫花蜜后，为蜂巢备好储粮","cost":60,"branch":2,"row":3,"requires":["meadow"]},
		{"id":"beat","name":"利落振翅","description":"振翅强度 1 → 2","cost":8,"fiber":2,"branch":0,"row":2,"requires":["gather1"]}
	]

func upgrade(id: String) -> Dictionary:
	for definition in upgrade_defs():
		if definition.id == id: return definition
	return {}

func growth_count() -> int:
	return _growth_count(owned)

static func _growth_count(ids: Array) -> int:
	var count := 0
	for id in ["gather1","gather2","bag1","bag2","wings1","wings2","reach","twin"]:
		if id in ids: count += 1
	return count

func locked_reason(id: String) -> String:
	var definition := upgrade(id)
	if definition.is_empty(): return "未知成长"
	if id in owned: return "已经拥有"
	if not at_home(): return "回蜂巢后购买"
	for prerequisite in definition.requires:
		if prerequisite not in owned: return "先获得："+str(upgrade(prerequisite).name)
	if id == "wings1" and "gather1" not in owned and "bag1" not in owned: return "采蜜技巧或蜜囊容量达到1级"
	if id == "meadow" and growth_count() < 3: return "基础能力成长 %d / 3 次" % growth_count()
	if id == "market" and (not visited_meadow or rose_sold < 1): return "先探索紫花地，并交售至少1份紫蜜"
	if id == "reserve" and (not visited_meadow or rose_sold < 6): return "先探索花地并交售 6 份紫花蜜（%d / 6）" % rose_sold
	if id == "reserve" and "twin" not in owned and "shortcut" not in owned: return "双簇采蜜或叶间近道：任选其一"
	for kind in ["fiber","resin"]:
		if materials[kind] < int(definition.get(kind,0)): return "还需 %d %s" % [int(definition[kind])-materials[kind],"纤维" if kind == "fiber" else "树脂"]
	if coins < int(definition.cost): return "还需 %d 金币" % (int(definition.cost)-coins)
	return ""

func can_buy(id: String) -> bool: return locked_reason(id).is_empty()

func buy(id: String) -> bool:
	if not can_buy(id): return false
	coins -= int(upgrade(id).cost)
	for kind in ["fiber","resin"]: materials[kind] -= int(upgrade(id).get(kind,0))
	owned.append(id)
	energy = max_energy()
	emit("buy",HUB_TREE,int(upgrade(id).cost))
	if id in ["meadow","shortcut"]: emit("unlock",HUB_TREE)
	if id == "reserve":
		completed = true
		emit("complete",HUB_TREE)
	return true

func sell() -> int:
	if not at_home() or cargo_total() == 0: return 0
	var value := cargo_value()
	coins += value
	sold_total += cargo_total()
	rose_sold += int(cargo.rose)
	cargo = {"blue":0,"rose":0}
	_full_announced = false
	emit("sell",HUB_SHOP,value)
	return value

func clear_controls() -> void:
	charge = 0.0
	charging = false
	harvesting_ids.clear()

func interaction() -> String:
	if area == "hub":
		for point in [{"p":HUB_SHOP,"action":"shop"},{"p":HUB_TREE,"action":"tree"},{"p":HUB_DEPART,"action":"depart"}]:
			if p.distance_to(point.p) <= 100.0: return point.action
	elif area == "pond":
		if p.distance_to(POND_ENTRY) <= 70.0: return "home"
		if p.distance_to(POND_EXIT) <= 70.0: return "meadow"
	elif p.distance_to(MEADOW_ENTRY) <= 70.0: return "pond"
	return ""

func update_camera() -> void:
	camera_x = 0.0 if area == "hub" else clampf(p.x-480.0,400.0,440.0) if area == "pond" else clampf(p.x-480.0,1840.0,2240.0)
	chapter.region = 1 if area == "meadow" else 0

func transition_to(destination: String,via: String = "gate") -> bool:
	if destination not in ["hub","pond","meadow"] or destination == area: return false
	if destination == "meadow" and "meadow" not in owned: return false
	var arrival := HOME
	if via == "shortcut":
		if "shortcut" not in owned or area == "hub" or destination == "hub": return false
		var source_index := 0 if area == "pond" else 1
		if p.distance_to(SHORTCUTS[source_index]) > 115.0: return false
		arrival = SHORTCUTS[1-source_index]
	elif via != "gate": return false
	elif area == "hub":
		if interaction() != "depart" or destination == "hub": return false
		arrival = POND_ENTRY if destination == "pond" else MEADOW_ENTRY
	elif area == "pond":
		if destination == "hub":
			if interaction() != "home": return false
		elif destination == "meadow":
			if interaction() != "meadow": return false
			arrival = MEADOW_ENTRY
		else: return false
	else:
		if interaction() != "pond" or destination not in ["hub","pond"]: return false
		arrival = POND_EXIT if destination == "pond" else HOME
	var previous := area
	if previous == "hub":
		trip_index += 1
		flowers = flower_layout(trip_index)
		for flower in flowers: flower.bloom = 0.0
		drops.clear()
		creatures = Encounters.layout(trip_index)
		hurt_left = 0.0
	area = destination
	phase = "home" if area == "hub" else "field"
	p = arrival
	v = Vector2.ZERO
	burst_left = 0.0
	clear_controls()
	if area == "hub":
		energy = max_energy()
		hurt_left = 0.0
		emit("return",p,cargo_total())
	elif previous == "hub": emit("depart",p,trip_index)
	if area == "meadow": visited_meadow = true
	update_camera()
	emit("area_change",p)
	events[-1]["from"] = previous
	events[-1]["to"] = area
	return true

func _rescue() -> void:
	var before := cargo_total()
	var previous := area
	cargo.blue = int(floor(float(cargo.blue)*0.5))
	cargo.rose = int(floor(float(cargo.rose)*0.5))
	area = "hub"
	phase = "home"
	p = HOME
	energy = max_energy()
	v = Vector2.ZERO
	burst_left = 0.0
	hurt_left = 0.0
	clear_controls()
	update_camera()
	_full_announced = false
	emit("area_change",HOME)
	events[-1]["from"] = previous
	events[-1]["to"] = area
	emit("rescue",HOME,before-cargo_total())

func use_shortcut() -> bool:
	return transition_to("meadow" if area == "pond" else "pond","shortcut")

func can_damage(_creature: Dictionary) -> bool:
	return false

func step(delta: float,move: Vector2,collect: bool,space_held: bool) -> void:
	if not is_finite(delta) or delta <= 0.0 or not move.is_finite(): return
	var dt := minf(delta,0.1)
	hurt_left = maxf(0.0,hurt_left-dt)
	pulse_left = maxf(0.0,pulse_left-dt)
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
	var dashing := burst_left > 0.0
	if burst_left > 0.0:
		v = face*500.0
		burst_left = maxf(0.0,burst_left-dt)
	else:
		var speed := 135.0 if charging else 230.0
		v = v.move_toward(move*speed,(1800.0 if move.is_zero_approx() else 1300.0)*dt)
	p += v*dt
	var left := 80.0 if area == "hub" else 400.0 if area == "pond" else 1840.0
	var right := 1200.0 if area == "hub" else 1720.0 if area == "pond" else 3520.0
	var limited := Vector2(clampf(p.x,left,right),clampf(p.y,160.0,650.0))
	if limited.x != p.x: v.x = 0.0
	if limited.y != p.y: v.y = 0.0
	p = limited
	if area == "hub":
		energy = max_energy()
	else:
		field_time = fmod(field_time+dt,86400.0)
		_grow_flowers(dt)
		_pickup_drops(dt)
		energy = maxf(0.0,energy-dt*((1.0 if v.length() > 20.0 else 0.6)+(1.8 if rain_exposed() else 0.0)))
		Encounters.step(self,dt,dashing)
		if energy <= 0.0:
			_rescue()
			return
		if collect and not charging and not dashing:
			_harvest(dt)
			if not harvesting_ids.is_empty(): energy = maxf(0.0,energy-1.3*dt)
			if energy <= 0.0: _rescue()
	update_camera()

func _harvest(dt: float) -> void:
	if cargo_total() >= capacity():
		if not _full_announced:
			emit("full",p,capacity())
			_full_announced = true
		return
	var candidates: Array[Dictionary] = []
	for flower in flowers:
		if int(flower.stock) > 0 and int(flower.region) == (1 if area == "meadow" else 0) and p.distance_to(flower_point(flower)) <= harvest_radius(): candidates.append(flower)
	candidates.sort_custom(func(a,b): return p.distance_squared_to(flower_point(a)) < p.distance_squared_to(flower_point(b)))
	for i in mini(candidates.size(),2 if "twin" in owned else 1):
		var flower: Dictionary = candidates[i]
		if cargo_total() >= capacity(): break
		harvesting_ids.append(flower.id)
		flower.progress = minf(2.0,float(flower.progress)+harvest_rate()*dt)
		var amount := mini(int(floor(float(flower.progress)+0.000001)),mini(int(flower.stock),capacity()-cargo_total()))
		if amount > 0:
			flower.progress = maxf(0.0,float(flower.progress)-amount)
			flower.stock -= amount
			cargo[flower.type] += amount
			emit("harvest",flower_point(flower),amount)
			events[-1]["type"] = flower.type
		if int(flower.stock) == 0:
			flower.progress = 0.0
			flower.regrow = REGROW_SECONDS
	if cargo_total() >= capacity() and not _full_announced:
		emit("full",p,capacity())
		_full_announced = true

func goal_text() -> String:
	if completed: return "花蜜备好了 · 继续探索，或回蜂巢歇一歇"
	if "meadow" not in owned:
		if owned.is_empty(): return "带回第一囊花蜜，换一项成长"
		if growth_count() < 3: return "基础能力成长 %d / 3 · 再开放紫花地" % growth_count()
		return "攒够 30 金币，开放远方紫花地"
	if not visited_meadow: return "新花地已开放 · 到出发路牌选择紫花地"
	if rose_sold < 6: return "带回紫花蜜 · 已交售 %d / 6" % rose_sold
	if "shortcut" not in owned and "twin" not in owned: return "双簇采蜜或叶间近道 · 任选一项成长"
	return "备好花蜜 · 为蜂巢留出 60 金币的储粮"

func to_payload() -> Dictionary:
	var stock: Array = []
	for flower in flowers: stock.append({"id":flower.id,"stock":flower.stock,"progress":flower.progress,"regrow":flower.regrow,"bloom":flower.bloom})
	return {"field_time":field_time,"pulse_left":pulse_left,"materials":materials.duplicate(true),"drops":_drops_payload(),"id":SAVE_ID,"version":SAVE_VERSION,"area":area,"creatures":Encounters.payload(creatures),"hurt_left":hurt_left,"p":[p.x,p.y],"v":[v.x,v.y],"face":[face.x,face.y],"phase":phase,"energy":energy,"charge":charge,"charging":charging,"burst_left":burst_left,"coins":coins,"cargo":cargo.duplicate(true),"owned":owned.duplicate(),"legacy_owned":legacy_owned.duplicate(),"flowers":stock,"completed":completed,"trip_index":trip_index,"sold_total":sold_total,"rose_sold":rose_sold,"visited_meadow":visited_meadow}

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
	var expected_keys: Array = to_payload().keys()
	if not keys_match(data,expected_keys): return false
	var expected_version := SAVE_VERSION
	if data.id != SAVE_ID or not whole(data.version,expected_version,expected_version): return false
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
		if not whole(data.cargo[kind],0,16): return false
	if not data.owned is Array or data.owned.size() > UPGRADE_IDS.size(): return false
	var next_owned: Array[String] = []
	for id in data.owned:
		if not id is String or id not in UPGRADE_IDS or id in next_owned: return false
		next_owned.append(id)
	var next_legacy: Array[String] = []
	if not data.legacy_owned is Array or data.legacy_owned.size() > next_owned.size(): return false
	for id in data.legacy_owned:
		if not id is String or id not in next_owned or id in next_legacy: return false
		next_legacy.append(id)
	if not Legacy._legacy_prerequisites_valid(next_legacy): return false
	for id in next_owned:
		if id in next_legacy: continue
		for prerequisite in upgrade(id).requires:
			if prerequisite not in next_owned: return false
		if id == "wings1" and "gather1" not in next_owned and "bag1" not in next_owned: return false
		if id == "meadow" and _growth_count(next_owned) < 3: return false
		if id == "market" and (not data.visited_meadow or data.rose_sold < 1): return false
		if id == "reserve" and "twin" not in next_owned and "shortcut" not in next_owned: return false
	if data.completed != ("reserve" in next_owned): return false
	if data.visited_meadow and "meadow" not in next_owned: return false
	if (int(data.cargo.rose) > 0 or data.rose_sold > 0) and not data.visited_meadow: return false
	if "reserve" in next_owned and (not data.visited_meadow or data.rose_sold < 6): return false
	var limit := 16 if "bag2" in next_owned else 10 if "bag1" in next_owned else 6
	var maximum := 70.0 if "wings2" in next_owned else 50.0 if "wings1" in next_owned else 36.0
	if int(data.cargo.blue)+int(data.cargo.rose) > limit: return false
	if data.energy < 0.0 or data.energy > maximum or data.charge < 0.0 or data.charge > CHARGE_READY or data.burst_left < 0.0 or data.burst_left > 0.32: return false
	if not data.charging and data.charge != 0.0: return false
	if data.charging and data.burst_left > 0.0: return false
	var next_p := Vector2(float(data.p[0]),float(data.p[1]))
	var next_v := Vector2(float(data.v[0]),float(data.v[1]))
	var next_face := Vector2(float(data.face[0]),float(data.face[1]))
	if data.area not in ["hub","pond","meadow"]: return false
	if data.phase != ("home" if data.area == "hub" else "field"): return false
	if not number(data.hurt_left) or data.hurt_left != 0.0: return false
	var left := 80.0 if data.area == "hub" else 400.0 if data.area == "pond" else 1840.0
	var right := 1200.0 if data.area == "hub" else 1720.0 if data.area == "pond" else 3520.0
	if next_p.x < left or next_p.x > right or next_p.y < 160.0 or next_p.y > 650.0: return false
	if next_v.length() > 500.01 or absf(next_face.length()-1.0) > 0.001: return false
	if data.phase == "field" and (data.trip_index < 1 or data.energy <= 0.0): return false
	if data.phase == "home" and data.energy != maximum: return false
	if data.area == "meadow" and (not data.visited_meadow or "meadow" not in next_owned): return false
	var next_creatures: Array[Dictionary] = Encounters.restore(data.creatures,int(data.trip_index))
	if next_creatures.size() != 3: return false
	if not data.flowers is Array or data.flowers.size() != flowers.size(): return false
	var next_flowers := flower_layout(int(data.trip_index))
	for i in next_flowers.size():
		var item = data.flowers[i]
		if not item is Dictionary or not keys_match(item,["id","stock","progress","regrow","bloom"]): return false
		if item.id != next_flowers[i].id or not whole(item.stock,0,int(next_flowers[i].max)): return false
		if not number(item.progress) or item.progress < 0.0 or item.progress >= 1.0: return false
		if item.stock == 0 and item.progress != 0.0: return false
		if next_flowers[i].region == 1 and "meadow" not in next_owned and (item.stock != next_flowers[i].max or item.progress != 0.0): return false
		if not number(item.regrow) or item.regrow < 0.0 or item.regrow > REGROW_SECONDS: return false
		if not number(item.bloom) or item.bloom < 0.0 or item.bloom > 1.0: return false
		if (item.stock > 0 and item.regrow != 0.0) or (item.stock == 0 and item.regrow <= 0.0): return false
		next_flowers[i].regrow = float(item.regrow)
		next_flowers[i].bloom = float(item.bloom)
		next_flowers[i].stock = int(item.stock)
		next_flowers[i].progress = float(item.progress)
	if not number(data.field_time) or data.field_time < 0.0 or data.field_time >= 86400.0: return false
	if not number(data.pulse_left) or data.pulse_left < 0.0 or data.pulse_left > 0.55: return false
	if not data.materials is Dictionary or not keys_match(data.materials,["fiber","resin"]): return false
	for kind in ["fiber","resin"]:
		if not whole(data.materials[kind],0,1000000000): return false
	if not data.drops is Array or data.drops.size() > 3: return false
	var next_drops: Array[Dictionary] = []
	var drop_ids: Array = []
	for drop in data.drops:
		if not drop is Dictionary or not keys_match(drop,["id","kind","pos","region","amount","age"]): return false
		if drop.id in drop_ids or drop.id not in ["mosquito_0","mosquito_1","mosquito_2"]: return false
		var index: int = int(str(drop.id).trim_prefix("mosquito_"))
		if next_creatures[index].state != "gone" or int(data.trip_index) == 0: return false
		if drop.region != next_creatures[index].region or drop.kind != ("fiber" if index == 0 else "resin"): return false
		if not whole(drop.amount,2 if index == 0 else 1,2 if index == 0 else 1) or not pair(drop.pos): return false
		if not number(drop.age) or drop.age < 0.0 or drop.age > 1.0: return false
		var at := Vector2(drop.pos[0],drop.pos[1])
		if at.distance_to(next_creatures[index].anchor) > 300.0: return false
		var item: Dictionary = drop.duplicate(true)
		item.pos = at
		next_drops.append(item)
		drop_ids.append(drop.id)
	# Only commit after every field and cross-field invariant is valid.
	field_time = float(data.field_time)
	pulse_left = float(data.pulse_left)
	materials = {"fiber":int(data.materials.fiber),"resin":int(data.materials.resin)}
	drops = next_drops
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
	legacy_owned = next_legacy
	flowers = next_flowers
	completed = data.completed
	trip_index = int(data.trip_index)
	sold_total = int(data.sold_total)
	rose_sold = int(data.rose_sold)
	visited_meadow = data.visited_meadow
	area = data.area
	creatures = next_creatures
	hurt_left = 0.0
	update_camera()
	events.clear()
	harvesting_ids.clear()
	_full_announced = false
	return true

# Validate immutable old rules first, then transform a complete candidate.
# No original file is written here; nectar_save_migration owns byte backup/replace.
func restore_v1_payload(data) -> bool:
	return restore_legacy_payload(data,1)

func restore_legacy_payload(data,version: int) -> bool:
	var previous = LegacyV4.new()
	var valid: bool = previous.restore_payload(data) if version == 4 else previous.restore_legacy_payload(data,version) if version in [1,2,3] else false
	if not valid: return false
	var candidate: Dictionary = previous.to_payload()
	candidate.version = SAVE_VERSION
	var old_max: float = previous.max_energy()
	var new_max := 70.0 if "wings2" in previous.owned else 50.0 if "wings1" in previous.owned else 36.0
	candidate.energy = new_max if previous.at_home() else maxf(0.01,new_max*previous.energy/old_max)
	candidate.field_time = 0.0
	candidate.pulse_left = 0.0
	candidate.materials = {"fiber":0,"resin":0}
	candidate.drops = []
	for flower in candidate.flowers:
		flower.regrow = REGROW_SECONDS if flower.stock == 0 else 0.0
		flower.bloom = 1.0
	for creature in candidate.creatures:
		creature.hits = 0
		creature.stun = 0.0
	return restore_payload(candidate)

static func _third(value: int) -> int:
	return ceili(float(value)/3.0)

static func _migration_sale_value(carried: Dictionary,market: bool) -> int:
	var base := int(carried.blue)+3*int(carried.rose)
	return base+int(floor(base*0.25)) if market else base

func flower_point(flower: Dictionary) -> Vector2:
	var sway := sin(field_time*1.55+float(flower.pos.x)*0.019)*7.0
	return flower.pos+Vector2(sway,cos(field_time*1.8+flower.pos.x)*1.8)

func _grow_flowers(dt: float) -> void:
	for flower in flowers:
		if int(flower.region) != (1 if area == "meadow" else 0): continue
		if flower.stock == 0:
			flower.bloom = maxf(0.0,float(flower.bloom)-dt/0.36)
			flower.regrow = maxf(0.0,float(flower.regrow)-dt)
			if flower.regrow <= 0.0:
				flower.stock = 1
				flower.bloom = 0.0
				emit("blossom",flower_point(flower))
		else: flower.bloom = minf(1.0,float(flower.bloom)+dt/0.8)

func pulse_radius() -> float: return 205.0 if "reach" in owned else 150.0

func pulse() -> bool:
	if at_home() or pulse_left > 0.0 or energy <= 2.0 or charging or burst_left > 0.0: return false
	energy -= 2.0
	pulse_left = 0.55
	emit("pulse",p)
	var nearest: Dictionary = {}
	for creature in creatures:
		if creature.state == "gone" or int(creature.region) != (1 if area == "meadow" else 0): continue
		if p.distance_to(creature.pos) <= pulse_radius() and (nearest.is_empty() or p.distance_squared_to(creature.pos) < p.distance_squared_to(nearest.pos)): nearest = creature
	if nearest.is_empty(): return true
	nearest.hits = mini(3,int(nearest.hits)+(2 if "beat" in owned else 1))
	nearest.stun = 0.42
	var away: Vector2 = (nearest.pos-p).normalized()
	if away.is_zero_approx(): away = Vector2.RIGHT
	nearest.pos += away*24.0
	emit("tap",nearest.pos,nearest.hits)
	var needed := 2 if nearest.kind == "scout" else 3
	if nearest.hits >= needed:
		nearest.state = "gone"
		nearest.timer = 0.0
		nearest.stun = 0.0
		emit("repel",nearest.pos)
		events[-1]["id"] = nearest.id
		drops.append({"id":nearest.id,"kind":"fiber" if nearest.kind == "scout" else "resin","pos":nearest.pos,"region":nearest.region,"amount":2 if nearest.kind == "scout" else 1,"age":0.0})
	return true

func _pickup_drops(dt: float) -> void:
	for i in range(drops.size()-1,-1,-1):
		var drop: Dictionary = drops[i]
		if int(drop.region) != (1 if area == "meadow" else 0): continue
		drop.age = minf(1.0,float(drop.age)+dt)
		if drop.age < 0.3: continue
		if p.distance_to(drop.pos) <= 85.0:
			materials[drop.kind] += int(drop.amount)
			emit("material",drop.pos,int(drop.amount))
			events[-1]["type"] = drop.kind
			drops.remove_at(i)

func _drops_payload() -> Array:
	var result: Array = []
	for drop in drops:
		var item: Dictionary = drop.duplicate(true)
		item.pos = [drop.pos.x,drop.pos.y]
		result.append(item)
	return result
