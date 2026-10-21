extends RefCounted
## Authored encounters. Coordinates are local to each named section, never random.
const STAGE_COUNT := 4

static func gap(x: float,y: float,width := 190.0) -> Dictionary:
	return {"kind":"gap","x":x,"y":y,"width":width}
static func rescue(x: float,y: float,count := 1) -> Dictionary:
	return {"kind":"pod","x":x,"y":y,"count":count}
static func wind(x: float,y: float,dy := 0.0) -> Dictionary:
	return {"kind":"ring","x":x,"y":y,"direction":Vector2(1,dy).normalized()}
static func chain(points: Array,openings: Array,landing: Vector2,slow: Array = [],flowers: Array = [],to_leaf := false) -> Dictionary:
	return {"kind":"chain","x":points[0].x,"y":points[0].y,"points":points,"openings":openings,"landing":landing,"slow":slow,"flowers":flowers,"to_leaf":to_leaf}
static func curtain(x: float,y: float) -> Dictionary:
	return {"kind":"curtain","x":x,"y":y}
static func flower(x: float,y: float) -> Dictionary:
	return {"kind":"flower","x":x,"y":y}
static func turn(x: float,y: float) -> Dictionary:
	return {"kind":"turn","x":x,"y":y}
static func weather(x: float,width: float) -> Dictionary:
	return {"kind":"rain","x":x,"y":80.0,"width":width}
static func shield(x: float,y: float) -> Dictionary:
	return {"kind":"shield","x":x,"y":y}
static func encounter(name: String,width: float,beats: Array,dew: Vector2,rest_y := -1.0,cue := "继续向前",speed := 100.0) -> Dictionary:
	return {"name":name,"width":width,"beats":beats,"dew":dew,"rest_y":rest_y,"cue":cue,"budget":55.0,"storm_speed":speed}

static func definitions() -> Array:
	return [
		{"title":"晨光菜圃","theme":0,"music":0,"base_bees":1,"storm":false,"encounters":[
			encounter("第一声呼救",1650,[turn(380,420),rescue(850,420,2)],Vector2(1320,300),-1,"冲开卷叶，让伙伴先回家"),
			encounter("抬头，再落下来",2050,[gap(460,290,260),gap(1110,500,270)],Vector2(1470,610),500,"上下绕过菜叶，叶亭就在前面"),
			encounter("露珠岔路",1450,[gap(460,420,300),turn(1020,420)],Vector2(1140,220),-1,"上方晨露可补体力，也可以直接向前"),
			encounter("卷叶上的两位",1950,[gap(400,500,260),rescue(970,270,2),gap(1450,320,280)],Vector2(1670,430),320,"抬头冲开卷叶，再到宽叶下"),
			encounter("顺风送你出菜圃",1750,[wind(640,400),turn(1250,400)],Vector2(1380,570),420,"冲进风花，松开方向也能借风向前")
		]},
		{"title":"喷泉花桥","theme":1,"music":1,"base_bees":5,"storm":false,"encounters":[
			encounter("借风，再停稳",1600,[wind(650,450),turn(1250,450)],Vector2(1320,290),-1,"风花会送你一程，之后可以停稳转向"),
			encounter("三朵花一口气",2350,[chain([Vector2(550,500),Vector2(1000,340),Vector2(1450,340)],[Vector3(790,410,260),Vector3(1230,340,250)],Vector2(1940,340))],Vector2(2020,190),360,"冲进第一朵，连续借风，不必重新蓄力"),
			encounter("快路下面的声音",1800,[turn(380,420),rescue(900,570,2),turn(1450,460)],Vector2(1510,630),460,"离开快路，向下救出两位伙伴"),
			encounter("快路还是稳路",2200,[chain([Vector2(570,290),Vector2(1020,290),Vector2(1470,290)],[],Vector2(1970,290),[Vector2(370,510),Vector2(1000,530),Vector2(1750,510),Vector2(1970,430)],[Vector2(1250,290)])],Vector2(2010,600),-1,"上方风花更快；下方宽路可以慢慢飞"),
			encounter("一口气到宽叶下",2450,[chain([Vector2(530,440),Vector2(980,440),Vector2(1430,440)],[],Vector2(1930,440)),turn(2150,440)],Vector2(2060,280),440,"接住最后一阵风，宽叶下松开方向停稳")
		]},
		{"title":"雨中停走","theme":2,"music":2,"base_bees":7,"storm":true,"encounters":[
			encounter("雨在身后",1650,[gap(650,420,300)],Vector2(1110,250),420,"雨幕追来，先到前方大叶下",95),
			encounter("看见雨，再出发",1350,[weather(420,410),turn(350,500),turn(1050,500)],Vector2(1110,640),-1,"灰云下有落雨；看准空隙，或冲刺穿过",140),
			encounter("护雨里转个弯",1550,[shield(620,330),weather(600,560),gap(730,300,240),gap(1100,490,260),turn(1450,490)],Vector2(1490,620),490,"接住护雨叶，五秒内可以顶着雨转向",140),
			encounter("把雨留在后面",1600,[gap(550,330,270),wind(1010,360,0.12)],Vector2(1310,590),-1,"护雨结束，借风拉开与雨幕的距离",100),
			encounter("叶亭旁的一声呼救",1900,[gap(430,480,280),rescue(1010,440),turn(1450,440)],Vector2(800,440),440,"最后这位在叶亭旁，冲开卷叶再歇口气",100)
		]},
		{"title":"归巢之路","theme":3,"music":2,"base_bees":8,"storm":true,"encounters":[
			encounter("熟悉的三阵风",2200,[chain([Vector2(560,480),Vector2(1010,340),Vector2(1460,340)],[Vector3(800,410,260)],Vector2(1940,340))],Vector2(1950,180),-1,"熟悉的借风路，顺着暖光向前",110),
			encounter("最后一位先回家",1700,[rescue(630,440),turn(1230,440)],Vector2(1290,600),440,"冲开卷叶，让最后一位伙伴先回家",110),
			encounter("远处亮着一盏灯",1200,[turn(400,440),turn(820,440)],Vector2(780,270),440,"八位伙伴已经到家；歇好，再走最后一程",175),
			encounter("穿过最后一阵雨",2450,[shield(400,440),weather(610,1000),chain([Vector2(800,440),Vector2(1250,440),Vector2(1700,440)],[],Vector2(2210,440)),{"kind":"curtain","x":2070.0,"y":440.0,"passive":true}],Vector2(2260,620),-1,"护雨叶、风花和冲刺，把最后一阵雨甩开",175),
			encounter("大家在等你",1600,[gap(450,420,340),turn(1110,420)],Vector2(1190,580),420,"灯就在前面，慢慢飞进老树",105)
		]}
	]

static func move_to(point: Vector2) -> Dictionary:
	return {"kind":"move","target":point}

static func build(index: int) -> Dictionary:
	var source: Dictionary = definitions()[clampi(index,0,STAGE_COUNT-1)]
	var out := {"title":source.title,"theme":source.theme,"music":source.music,"base_bees":source.base_bees,"storm":source.storm,"sections":[],"encounters":[],"shields":[],"rain_fields":[],"pods":[],"walls":[],"rings":[],"shelters":[],"dew":[],"sprayers":[],"route":[],"optional_route":[]}
	var origin := 0.0
	var i := 0
	for encounter_index in source.encounters.size():
		var spec: Dictionary = source.encounters[encounter_index]
		var rest := Vector2(origin+spec.width-180,spec.rest_y)
		if out.sections.size() == i:
			out.sections.append({"name":spec.name,"start_x":origin,"end_x":origin+spec.width,"rest":rest,"budget":spec.budget,"storm_speed":spec.storm_speed if source.storm else 0.0,"route_index":out.route.size(),"optional_route_index":out.optional_route.size()})
		out.encounters.append({"name":spec.name,"start_x":origin,"end_x":origin+spec.width,"section":i,"cue":spec.cue,"storm_speed":spec.storm_speed})
		var finishes_in_leaf := false
		for beat in spec.beats:
			var point := Vector2(origin+beat.x,beat.y)
			var steps: Array = []
			var optional_steps: Array = []
			match beat.kind:
				"gap":
					var half: float = beat.width*0.5
					out.walls.append({"rect":Rect2(point.x,80,48,point.y-half-80),"kind":"stem","broken":false})
					out.walls.append({"rect":Rect2(point.x,point.y+half,48,730-point.y-half),"kind":"stem","broken":false})
					steps = [move_to(point-Vector2(140,0)),move_to(point+Vector2(180,0))]
				"pod":
					out.pods.append({"pos":point,"open":false,"count":beat.count,"section":i,"encounter":encounter_index})
					steps = [move_to(point-Vector2(170,0)),{"kind":"burst","direction":Vector2.RIGHT}]
				"ring":
					out.rings.append({"pos":point,"active":false,"direction":beat.direction,"section":i,"encounter":encounter_index})
					steps = [move_to(point-Vector2(170,0)),{"kind":"burst","direction":Vector2.RIGHT}]
				"chain":
					for j in beat.points.size():
						var current: Vector2 = beat.points[j]
						var following: Vector2 = beat.points[j+1] if j+1 < beat.points.size() else beat.landing
						out.rings.append({"pos":current+Vector2(origin,0),"active":false,"direction":(following-current).normalized(),"chain":true,"section":i,"encounter":encounter_index})
					for opening in beat.openings:
						var half: float = opening.z*0.5
						out.walls.append({"rect":Rect2(origin+opening.x,80,48,opening.y-half-80),"kind":"stem","broken":false})
						out.walls.append({"rect":Rect2(origin+opening.x,opening.y+half,48,730-opening.y-half),"kind":"stem","broken":false})
					for flower_pos in beat.flowers:
						out.sprayers.append({"pos":flower_pos+Vector2(origin,0),"timer":2.4,"stun_left":0.0,"flash":0.0,"rewarded":false})
					steps = [move_to(point-Vector2(170,0)),{"kind":"burst","direction":Vector2.RIGHT},move_to(beat.landing+Vector2(origin,0))]
					for slow_point in beat.slow: optional_steps.append(move_to(slow_point+Vector2(origin,0)))
					if beat.to_leaf:
						optional_steps = [move_to(spec.dew+Vector2(origin,0))]
						optional_steps.append_array(steps.duplicate(true))
					finishes_in_leaf = beat.to_leaf
				"curtain":
					out.walls.append({"rect":Rect2(point.x,80,42,650),"kind":"curtain","broken":false})
					steps = [move_to(point-Vector2(170,0)),{"kind":"burst","direction":Vector2.RIGHT}]
					if beat.get("passive",false): steps = []
				"flower":
					out.sprayers.append({"pos":point,"timer":2.4,"stun_left":0.0,"flash":0.0,"rewarded":false})
					steps = [move_to(point-Vector2(170,0)),{"kind":"burst","direction":Vector2.RIGHT}]
				"rain":
					out.rain_fields.append({"rect":Rect2(point.x,80,beat.width,650),"timer":0.2})
				"shield":
					out.shields.append({"pos":point,"collected":false,"section":i})
					steps = [move_to(point)]
				"turn": steps = [move_to(point)]
			out.route.append_array(steps)
			out.optional_route.append_array(optional_steps if not optional_steps.is_empty() else steps.duplicate(true))
		var dew_pos: Vector2 = spec.dew+Vector2(origin,0)
		out.dew.append({"pos":dew_pos,"collected":false,"section":i,"encounter":encounter_index})
		if not finishes_in_leaf: out.optional_route.append(move_to(dew_pos))
		if spec.rest_y >= 0:
			out.sections[i].end_x = origin+spec.width
			out.sections[i].rest = rest
			out.shelters.append({"pos":rest,"reached":false,"section":i,"name":spec.name,"half_width":180.0})
			for route_name in ["route","optional_route"]:
				out[route_name].append_array([move_to(rest),{"kind":"rest","section":i}])
			i += 1
		origin += spec.width
	out["world_width"] = origin+520
	out["exit_pos"] = Vector2(out.world_width-180,420)
	for route_name in ["route","optional_route"]: out[route_name].append(move_to(out.exit_pos))
	return out
