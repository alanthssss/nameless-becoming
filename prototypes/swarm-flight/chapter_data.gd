extends RefCounted
## Authored encounters. Coordinates are local to each named section, never random.
const STAGE_COUNT := 4
const SECTION_WIDTH := 2700.0

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
static func section(name: String,rest_y: float,beats: Array,dew: Vector2,budget := 42.0) -> Dictionary:
	return {"name":name,"rest_y":rest_y,"beats":beats,"dew":dew,"budget":budget}

static func definitions() -> Array:
	return [
		{"title":"晨光菜圃","theme":0,"music":0,"base_bees":1,"storm":false,"sections":[
			section("第一声呼救",420,[turn(380,420),rescue(850,420,2),gap(1550,420,250)],Vector2(1830,300)),
			section("菜叶间的小径",470,[gap(480,300,230),rescue(1050,280,2),gap(1670,500,220)],Vector2(1850,620)),
			section("抬头找伙伴",350,[gap(450,550,210),rescue(1120,220,2),gap(1720,320,210)],Vector2(1890,160)),
			section("露珠岔路",500,[gap(500,350,210),curtain(1100,350),gap(1700,530,210)],Vector2(1900,655)),
			section("喷嚏前的空隙",300,[gap(460,500,220),flower(1050,420),gap(1700,280,210)],Vector2(1900,155)),
			section("上下两扇叶",480,[gap(500,250,210),curtain(1160,520),gap(1780,430,190)],Vector2(1960,620)),
			section("顺风送你出菜圃",420,[gap(450,520,220),wind(1050,480,-0.22),gap(1810,340,210)],Vector2(1950,220))
		]},
		{"title":"喷泉花桥","theme":1,"music":1,"base_bees":7,"storm":false,"sections":[
			section("第一阵顺风",420,[gap(420,450,250),wind(1000,450,0.0),gap(1790,450,250)],Vector2(1950,250)),
			section("三朵花一口气",360,[chain([Vector2(700,520),Vector2(1150,360),Vector2(1600,360)],[Vector3(900,445,210),Vector3(1390,360,210)],Vector2(2080,360))],Vector2(1950,150)),
			section("花桥下面的声音",510,[gap(440,300,230),rescue(1060,560),gap(1740,510,210)],Vector2(1910,660)),
			section("不必都走快路",480,[chain([Vector2(700,310),Vector2(1150,450),Vector2(1600,310)],[Vector3(900,380,190),Vector3(1370,380,190)],Vector2(2070,310),[Vector2(560,310),Vector2(760,350),Vector2(830,380),Vector2(1080,380),Vector2(1230,380),Vector2(1550,380),Vector2(1830,520)])],Vector2(1950,640)),
			section("喷泉边的转向",320,[gap(470,270,210),wind(1040,270,0.30),gap(1790,440,210)],Vector2(1960,590)),
			section("最后一声等等我",420,[gap(470,540,220),rescue(1090,300),gap(1740,420,210)],Vector2(1920,620)),
			section("伙伴先回家了",420,[gap(460,310,200),wind(1050,330,0.18),gap(1810,440,230)],Vector2(1950,610))
		]},
		{"title":"雨中停走","theme":2,"music":2,"base_bees":9,"storm":true,"storm_speeds":[110.0,165.0,120.0,205.0,115.0,170.0,125.0],"sections":[
			section("看见第一片屋檐",420,[gap(470,420,250),curtain(1100,420),gap(1740,420,240)],Vector2(1910,220),46),
			section("从低处穿雨",540,[gap(470,550,210),flower(1110,530),gap(1750,520,200)],Vector2(1920,665),42),
			section("留一口气再走",330,[gap(450,300,230),curtain(1090,300),gap(1740,350,210)],Vector2(1930,170),43),
			section("雨帘背后的顺风",470,[gap(450,500,220),wind(1060,480,-0.20),gap(1790,390,210)],Vector2(1950,620),42),
			section("等喷嚏过去",300,[gap(470,270,210),flower(1100,320),gap(1760,340,190)],Vector2(1930,165),44),
			section("两次抬头",470,[gap(390,560,210),gap(970,300,210),curtain(1550,470)],Vector2(1880,650),45),
			section("下一片叶子有灯",420,[gap(450,420,220),wind(1060,420,0),gap(1790,420,220)],Vector2(1950,225),44)
		]},
		{"title":"归巢之路","theme":3,"music":2,"base_bees":9,"storm":true,"storm_speeds":[155.0,120.0,210.0,215.0,115.0,185.0,135.0],"sections":[
			section("顺着暖光飞",380,[gap(450,520,210),wind(1050,490,-0.27),gap(1800,350,200)],Vector2(1950,190),44),
			section("树根上方",520,[gap(470,250,200),curtain(1110,490),gap(1770,520,190)],Vector2(1950,660),43),
			section("把喷嚏留在身后",430,[gap(450,450,230),chain([Vector2(1000,450),Vector2(1450,450),Vector2(1900,450)],[],Vector2(2440,430),[],[Vector2(1800,450)],true)],Vector2(800,180),43),
			section("一高一低的花桥",460,[chain([Vector2(700,300),Vector2(1150,460),Vector2(1600,300)],[Vector3(900,380,190),Vector3(1370,380,190)],Vector2(2080,300))],Vector2(1940,635),42),
			section("最后一处窄弯",320,[gap(420,530,190),gap(1030,310,190),curtain(1600,330)],Vector2(1900,170),43),
			section("还能接住一阵风",490,[gap(450,490,200),wind(1050,470,-0.22),gap(1800,360,190)],Vector2(1960,650),42),
			section("大家都在等这束光",420,[gap(460,300,210),flower(1100,420),gap(1750,420,240)],Vector2(1940,590),46)
		]}
	]

static func move_to(point: Vector2) -> Dictionary:
	return {"kind":"move","target":point}

static func build(index: int) -> Dictionary:
	var source: Dictionary = definitions()[clampi(index,0,STAGE_COUNT-1)]
	var out := {"title":source.title,"theme":source.theme,"music":source.music,"base_bees":source.base_bees,"storm":source.storm,"sections":[],"pods":[],"walls":[],"rings":[],"shelters":[],"dew":[],"sprayers":[],"route":[],"optional_route":[]}
	for i in source.sections.size():
		var spec: Dictionary = source.sections[i]
		var origin: float = i*SECTION_WIDTH
		var rest := Vector2(origin+2440,spec.rest_y)
		var details := {"name":spec.name,"start_x":origin,"end_x":origin+SECTION_WIDTH,"rest":rest,"budget":spec.budget,"storm_speed":source.storm_speeds[i] if source.storm else 0.0,"route_index":out.route.size(),"optional_route_index":out.optional_route.size()}
		out.sections.append(details)
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
					out.pods.append({"pos":point,"open":false,"count":beat.count,"section":i})
					steps = [move_to(point-Vector2(170,0)),{"kind":"burst","direction":Vector2.RIGHT}]
				"ring":
					out.rings.append({"pos":point,"active":false,"direction":beat.direction,"section":i})
					steps = [move_to(point-Vector2(170,0)),{"kind":"burst","direction":Vector2.RIGHT}]
				"chain":
					for j in beat.points.size():
						var current: Vector2 = beat.points[j]
						var following: Vector2 = beat.points[j+1] if j+1 < beat.points.size() else beat.landing
						out.rings.append({"pos":current+Vector2(origin,0),"active":false,"direction":(following-current).normalized(),"chain":true,"section":i})
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
				"flower":
					out.sprayers.append({"pos":point,"timer":2.4,"stun_left":0.0,"flash":0.0,"rewarded":false})
					steps = [move_to(point-Vector2(170,0)),{"kind":"burst","direction":Vector2.RIGHT}]
				"turn": steps = [move_to(point)]
			out.route.append_array(steps)
			out.optional_route.append_array(optional_steps if not optional_steps.is_empty() else steps.duplicate(true))
		var dew_pos: Vector2 = spec.dew+Vector2(origin,0)
		out.dew.append({"pos":dew_pos,"collected":false,"section":i})
		if not finishes_in_leaf: out.optional_route.append(move_to(dew_pos))
		out.walls.append({"rect":Rect2(origin+2200,80,42,650),"kind":"curtain","broken":false,"needs_section":i})
		out.shelters.append({"pos":rest,"reached":false,"section":i,"name":spec.name})
		for route_name in ["route","optional_route"]:
			if not finishes_in_leaf:
				out[route_name].append_array([move_to(Vector2(origin+2030,spec.rest_y)),{"kind":"burst","direction":Vector2.RIGHT}])
			out[route_name].append_array([move_to(rest),{"kind":"rest","section":i}])
	out["world_width"] = source.sections.size()*SECTION_WIDTH+520
	out["exit_pos"] = Vector2(out.world_width-180,420)
	for route_name in ["route","optional_route"]: out[route_name].append(move_to(out.exit_pos))
	return out
