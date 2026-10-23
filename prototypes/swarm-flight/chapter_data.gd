extends "res://event_data.gd"
## Authored whole-game encounter catalogue.
const Extra = preload("res://campaign_content.gd")
const STAGE_COUNT := 16
const REGIONS := ["春 · 归家", "夏 · 花篱外", "秋 · 旧果园", "冬 · 暖廊与老树"]

static func definitions() -> Array:
	var original := [
		{"title":"晨光菜圃","theme":0,"music":0,"base_bees":1,"storm":false,"encounters":[
			encounter("第一声呼救",1650,[turn(380,420),rescue(850,420,2)],-1,"冲开卷叶，让伙伴先回家"),
			encounter("抬头，再落下来",2050,[gap(460,290,260),dew(850,390,"上下转向之间顺路补给，继续飞到第二个缺口"),gap(1110,500,270)],500,"穿过上方缺口，顺着晨露向下转"),
			encounter("露珠岔路",1450,[gap(460,420,300),dew(1000,260,"选择抬高路线，为前方救援多留体力","detour"),turn(1200,420)],-1,"上沿晨露补给后可以返回主路，也可以直接向前"),
			encounter("卷叶上的两位",1950,[gap(400,500,260),rescue(970,270,2),gap(1450,320,280)],-1,"救出伙伴补充体力，穿过缺口继续飞"),
			encounter("顺风送你出菜圃",1750,[wind(640,400),turn(1250,400)],420,"用刚才的补给借风，前方宽叶下落脚")
		]},
		{"title":"喷泉花桥","theme":1,"music":1,"base_bees":5,"storm":false,"encounters":[
			encounter("借风，再停稳",1600,[wind(650,450),turn(1250,450)],-1,"风花会送你一程，之后可以停稳转向"),
			encounter("三朵花一口气",2350,[chain([Vector2(550,500),Vector2(1000,340),Vector2(1450,340)],[Vector3(790,410,260),Vector3(1230,340,250)],Vector2(1940,340))],360,"冲进第一朵，连续借风，不必重新蓄力"),
			encounter("快路下面的声音",1800,[turn(380,420),rescue(900,570,2),turn(1450,460)],-1,"向下救出伙伴，补好体力继续选择路线"),
			encounter("借风，或从下方绕行",2200,[dew(240,420,"进入分路前顺路补给，再选择抬头借风或从下方绕行"),chain([Vector2(570,290),Vector2(1020,290),Vector2(1470,290)],[],Vector2(1970,290),[Vector2(370,510),Vector2(900,530),Vector2(1540,510),Vector2(1970,430)],[Vector2(1250,290)])],-1,"抬头连续借风；也可以从下方绕过喷嚏花"),
			encounter("一口气到宽叶下",2450,[chain([Vector2(530,440),Vector2(980,440),Vector2(1430,440)],[],Vector2(1930,440)),turn(2150,440)],440,"接住最后一阵风，宽叶下松开方向停稳")
		]},
		{"title":"雨中停走","theme":2,"music":2,"base_bees":7,"storm":true,"encounters":[
			encounter("雨在身后",1650,[gap(650,420,300)],420,"雨幕追来，先到前方大叶下",95,true),
			encounter("看见雨，再出发",1350,[weather(420,410),turn(350,500),dew(1040,500,"穿过第一片雨后顺路补给，再接近护雨转弯"),turn(1200,500)],-1,"灰云下有落雨；穿过后顺路补给，继续向前",140,true),
			encounter("护雨里转个弯",1550,[shield(620,330),weather(600,560),gap(730,300,240),gap(1100,490,260)],490,"接住护雨叶，五秒内可以顶着雨转向",140,true),
			encounter("把雨留在后面",1600,[gap(550,330,270),dew(780,350,"离开叶亭不停满后，为避雨借风补足冲刺体力"),wind(1010,360,0.12)],-1,"护雨结束，借风拉开与雨幕的距离",100,true),
			encounter("叶亭前的一声呼救",1900,[gap(430,480,280),dew(800,440,"救援前顺路补充冲刺体力"),rescue(1010,440),turn(1450,440)],440,"顺路接住晨露，冲开卷叶再到叶下",100,true)
		]},
		{"title":"归巢之路","theme":3,"music":2,"base_bees":8,"storm":true,"encounters":[
			encounter("熟悉的三阵风",2200,[chain([Vector2(560,480),Vector2(1010,340),Vector2(1460,340)],[Vector3(800,410,260)],Vector2(1940,340))],-1,"熟悉的借风路，顺着暖光向前",110,true),
			encounter("最后一位先回家",1250,[rescue(630,440),turn(1040,440)],-1,"冲开卷叶，让最后一位伙伴先回家",110),
			encounter("远处亮着一盏灯",900,[turn(240,440),turn(620,440)],440,"大家已到家；前方叶下歇好，再穿过最后的雨",85),
			encounter("穿过最后一阵雨",2450,[shield(400,440),weather(610,1000),chain([Vector2(800,440),Vector2(1250,440),Vector2(1700,440)],[],Vector2(2210,440)),{"kind":"curtain","x":2070.0,"y":440.0,"passive":true}],-1,"护雨叶、风花和冲刺，把最后一阵雨甩开",175,true),
			encounter("大家在等你",1300,[gap(450,420,340),turn(970,420)],420,"前面没有新挑战了，沿灯光飞进老树",65)
		]}
	]
	for i in original.size():
		original[i]["region"] = 0
		original[i]["exit_kind"] = "home" if i == 3 else "arch"
	original[3]["arrival"] = "春天，八位伙伴都到家了。\n夏天到了，小满想去看看花篱外。"
	return original+Extra.definitions()

static func dew_count(index: int) -> int:
	var total := 0
	for spec in definitions()[index].encounters:
		for beat in spec.beats:
			if beat.kind == "dew": total += 1
	return total

static func move_to(point: Vector2) -> Dictionary:
	return {"kind":"move","target":point}

static func build(index: int) -> Dictionary:
	return build_source(definitions()[clampi(index,0,STAGE_COUNT-1)])

static func build_source(source: Dictionary) -> Dictionary:
	var out := {"title":source.title,"theme":source.theme,"music":source.music,"base_bees":source.base_bees,"storm":source.storm,"sections":[],"encounters":[],"shields":[],"rain_fields":[],"pods":[],"walls":[],"rings":[],"shelters":[],"dew":[],"sprayers":[],"route":[],"optional_route":[],"decor":[],"jets":[],"airflows":[],"region":source.get("region",0),"exit_kind":source.get("exit_kind","arch"),"entry":source.get("entry",source.encounters[0].cue),"arrival":source.get("arrival",""),"npc":source.get("npc",""),"npc_line":source.get("npc_line",""),"decision":source.get("decision","")}
	if source.has("neighbor_stops"): out["neighbor_stops"] = source.neighbor_stops
	var origin := 0.0
	var i := 0
	for encounter_index in source.encounters.size():
		var spec: Dictionary = source.encounters[encounter_index]
		var rest := Vector2(origin+spec.width-180,spec.rest_y)
		if out.sections.size() == i:
			out.sections.append({"name":spec.name,"start_x":origin,"end_x":origin+spec.width,"rest":rest,"budget":spec.budget,"storm_speed":spec.storm_speed if source.storm else 0.0,"route_index":out.route.size(),"optional_route_index":out.optional_route.size()})
		out.encounters.append({"name":spec.name,"start_x":origin,"end_x":origin+spec.width,"section":i,"cue":spec.cue,"storm_speed":spec.storm_speed,"ambient_rain":spec.ambient_rain})
		var route_start: int = out.route.size()
		var alternate_start: int = out.optional_route.size()
		for beat in spec.beats:
			var point := Vector2(origin+beat.x,beat.y)
			var steps: Array = []
			var optional_steps: Array = []
			match beat.kind:
				"terrain":
					out.walls.append({"rect":Rect2(point,Vector2(beat.width,beat.height)),"kind":"terrain","material":beat.style,"broken":false})
				"jet":
					out.jets.append({"rect":Rect2(point,Vector2(beat.width,beat.height)),"period":beat.period,"active_seconds":beat.active_seconds,"offset":beat.offset})
				"airflow":
					out.airflows.append({"rect":Rect2(point,Vector2(beat.width,beat.height)),"direction":beat.direction,"strength":beat.strength})
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
				"fork":
					for branch in ["top","bottom"]:
						var points: Array = beat[branch]
						var landing: Vector2 = beat[branch+"_landing"]
						for j in points.size():
							var next: Vector2 = points[j+1] if j+1 < points.size() else landing
							out.rings.append({"pos":points[j]+Vector2(origin,0),"active":false,"direction":points[j].direction_to(next),"chain":true,"section":i,"encounter":encounter_index,"branch":branch})
						var path := [move_to(points[0]+Vector2(origin-170,0)),{"kind":"burst","direction":Vector2.RIGHT},move_to(landing+Vector2(origin,0)),move_to(beat.merge+Vector2(origin,0))]
						if branch == "top": steps = path
						else: optional_steps = path
				"deco":
					out.decor.append({"pos":point,"style":beat.style})
				"chain":
					for j in beat.points.size():
						var current: Vector2 = beat.points[j]
						var following: Vector2 = beat.points[j+1] if j+1 < beat.points.size() else beat.landing
						out.rings.append({"pos":current+Vector2(origin,0),"active":false,"direction":(following-current).normalized(),"chain":true,"section":i,"encounter":encounter_index,"branch":"chain_%d" % encounter_index})
					for opening in beat.openings:
						var half: float = opening.z*0.5
						out.walls.append({"rect":Rect2(origin+opening.x,80,48,opening.y-half-80),"kind":"stem","broken":false})
						out.walls.append({"rect":Rect2(origin+opening.x,opening.y+half,48,730-opening.y-half),"kind":"stem","broken":false})
					for flower_pos in beat.flowers:
						out.sprayers.append({"pos":flower_pos+Vector2(origin,0),"timer":2.4,"stun_left":0.0,"flash":0.0,"rewarded":false})
					steps = [move_to(point-Vector2(170,0)),{"kind":"burst","direction":Vector2.RIGHT},move_to(beat.landing+Vector2(origin,0))]
					for slow_point in beat.slow: optional_steps.append(move_to(slow_point+Vector2(origin,0)))
				"curtain":
					var curtain_height: float = beat.get("height",650.0)
					out.walls.append({"rect":Rect2(point.x,80 if not beat.has("height") else point.y-curtain_height*0.5,42,curtain_height),"kind":"curtain","broken":false})
					steps = [move_to(point-Vector2(170,0)),{"kind":"burst","direction":Vector2.RIGHT}]
					if beat.get("passive",false): steps = []
					if beat.has("bypass_y"): optional_steps = [move_to(Vector2(point.x-180,beat.bypass_y)),move_to(Vector2(point.x+280,beat.bypass_y))]
				"flower":
					out.sprayers.append({"pos":point,"timer":2.4,"stun_left":0.0,"flash":0.0,"rewarded":false})
					steps = [move_to(point-Vector2(170,0)),{"kind":"burst","direction":Vector2.RIGHT}]
					if beat.has("bypass_y"): optional_steps = [move_to(Vector2(point.x-180,beat.bypass_y)),move_to(Vector2(point.x+300,beat.bypass_y))]
				"rain":
					out.rain_fields.append({"rect":Rect2(point.x,80,beat.width,650),"timer":0.2})
				"shield":
					out.shields.append({"pos":point,"collected":false,"section":i})
					steps = [move_to(point)]
				"dew":
					out.dew.append({"pos":point,"collected":false,"section":i,"encounter":encounter_index,"purpose":beat.purpose})
					if beat.route_mode == "through": steps = [move_to(point)]
					elif beat.route_mode == "detour": optional_steps = [move_to(point)]
					# Branch pickups are already on the chain's ordinary-flight alternative.
				"turn": steps = [move_to(point)]
			out.route.append_array(steps)
			out.optional_route.append_array(optional_steps if not optional_steps.is_empty() else steps.duplicate(true))
		# Explicit reference routes describe ordinary inputs through authored geometry.
		# They never alter the playable level or grant progress.
		if spec.has("direct_route"):
			out.route.resize(route_start)
			out.route.append_array(translate_route(spec.direct_route,origin))
			out.optional_route.resize(alternate_start)
			out.optional_route.append_array(translate_route(spec.get("alternate_route",spec.direct_route),origin))
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
	# The goal is a visible threshold, not an invisible proximity sphere.
	for route_name in ["route","optional_route"]: out[route_name].append(move_to(out.exit_pos+Vector2(45,0)))
	return out

static func translate_route(commands: Array,origin: float) -> Array:
	var translated: Array = []
	for command in commands:
		if command is Vector2: translated.append(move_to(command+Vector2(origin,0)))
		else:
			var next: Dictionary = command.duplicate(true)
			if next.has("target"): next.target += Vector2(origin,0)
			if next.has("jet_x"): next.jet_x += origin
			translated.append(next)
	return translated
