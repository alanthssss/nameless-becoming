extends "res://event_data.gd"
const Builder = preload("res://chapter_data.gd")
const TITLES := ["池边小径","雨中停走","归巢之路"]
const POND_APPROACH_EXTENSION := 4800.0
const POND_FORK := Rect2(2860+POND_APPROACH_EXTENSION,330,200,120)
const RAIN_LOW_REST := Vector2(2630,600)
const RAIN_HIGH_REST := Vector2(3010,520)
const RAIN_OVERHEAD := Rect2(3150,310,710,85)
const RAIN_UPPER_STEM := Rect2(3150,80,65,231)
static func beat(name: String,width: float,objects: Array,rest: float,cue: String,route: Array,alternate: Array=[]) -> Dictionary:
	var b:=encounter(name,width,objects,rest,cue)
	b.direct_route=route
	b.alternate_route=alternate if not alternate.is_empty() else route
	return b

static func launch(direction:=Vector2.RIGHT,wait_for_keeper_counting:=false) -> Dictionary:
	var command:={"kind":"burst","direction":direction}
	if wait_for_keeper_counting: command["wait_for_keeper_counting"]=true
	return command

static func outward_approach() -> Array:
	return [
		# A self-powered opening precedes borrowed momentum. The low route rejoins
		# at the same supply; neither route ends in a compulsory stop.
		beat("自己打开叶间",1400,[terrain(580,80,220,220),terrain(580,540,220,100),{"kind":"curtain","x":620.0,"y":420.0,"height":240.0},dew(1100,500,"推开叶帘或从低处绕行后相会")],-1,"叶间有一条直路，篱下也能过去",[Vector2(450,420),launch(),Vector2(1100,500),Vector2(1280,520)],[Vector2(400,680),Vector2(960,680),Vector2(1100,500),Vector2(1280,520)]),
		# The relay gets us high; it cannot perform the descent for the player.
		# Room beyond its natural endpoint makes the next low passage visible.
		beat("风停以后，自己落下",2800,[chain([Vector2(360,520),Vector2(760,380),Vector2(1160,240)],[],Vector2(1630,240)),terrain(2140,80,360,340),dew(1980,550,"从高处收势，接住低路的补给")],550,"风送到高处，遮檐下面接着下一段路",[Vector2(190,520),launch(),Vector2(1640,240),Vector2(1980,550),Vector2(2560,550)],[Vector2(220,550),Vector2(1600,550),Vector2(1980,550),Vector2(2560,550)]),
		# The low landing becomes the next launch. Ordinary flight keeps its low
		# approach, while the wind route arrives above the flower-side stem.
		beat("从落点接着出发",1800,[terrain(450,80,600,190),chain([Vector2(320,550),Vector2(720,420),Vector2(1120,300)],[],Vector2(1590,300)),dew(1680,480,"高低来向接回池边小路")],-1,"低处可以再借一阵风，也可以沿池面继续",[Vector2(150,550),launch(),Vector2(1610,300),Vector2(1680,480)],[Vector2(220,550),Vector2(1330,550),Vector2(1680,480)])
	]

static func homeward_approach() -> Array:
	return [
		# Recognisable opening, now clear: the return does not repeat the first
		# leaf-door test. This release leads to a different wind landing.
		beat("又见叶间的小路",1440,[terrain(580,80,220,220),terrain(580,540,220,100),dew(1100,480,"熟悉的通口后接回归路")],-1,"叶间的路还认得，先看看这次风落在哪里",[Vector2(450,420),Vector2(900,420),Vector2(1100,480),Vector2(1320,300)],[Vector2(400,680),Vector2(960,680),Vector2(1100,480),Vector2(1320,300)]),
		# The outward rising arc becomes a descent. The low endpoint asks for a
		# deliberate climb over the next stem, rather than another automatic arc.
		beat("这次从低处回来",2800,[chain([Vector2(360,300),Vector2(760,440),Vector2(1160,560)],[],Vector2(1630,560)),terrain(600,80,600,200),terrain(600,620,800,110),terrain(2140,520,320,210),dew(1980,330,"低风之后主动抬升，接住共同补给")],550,"风落向池面，前面的花茎要从上面过去",[Vector2(190,300),launch(),Vector2(1640,560),Vector2(1980,330),Vector2(2540,330),Vector2(2600,550)],[Vector2(220,420),Vector2(1520,420),Vector2(1980,330),Vector2(2540,330),Vector2(2600,550)]),
		# Reuse the familiar low-to-high relationship before the sign episode.
		# A common landing gives time to see the keeper, without an empty runway.
		beat("看见归路上的花牌",2000,[terrain(180,80,440,300),chain([Vector2(300,550),Vector2(700,420),Vector2(1100,300)],[],Vector2(1570,300)),dew(1680,500,"两种来向在牌架前汇合")],500,"越过熟悉的叶影，池岸那边挂起了花牌",[Vector2(130,550),launch(),Vector2(1590,300),Vector2(1590,500),Vector2(1680,500)],[Vector2(220,550),Vector2(1450,550),Vector2(1680,500)])
	]

static func relocate_rest(result: Dictionary,name: String,position: Vector2) -> void:
	for leaf in result.shelters:
		if leaf.name!=name: continue
		var previous: Vector2=leaf.pos
		leaf.pos=position
		result.sections[leaf.section].rest=position
		for route_name in ["route","optional_route"]:
			for command in result[route_name]:
				if command.kind=="move" and command.target==previous: command.target=position
		return

static func omit_reference_rest(result: Dictionary,name: String) -> void:
	# Passing the leaf station already records the checkpoint. Do not make a
	# known-answer route reverse after a wind exit just to touch an optional leaf.
	for leaf in result.shelters:
		if leaf.name!=name: continue
		for route_name in ["route","optional_route"]:
			result[route_name]=result[route_name].filter(func(command): return not (command.kind=="move" and command.target==leaf.pos) and not (command.kind=="rest" and command.get("section")==leaf.section))
		return

static func build(index: int) -> Dictionary:
	var beats: Array
	if index==0:
		beats=outward_approach()+[
			beat("荫边有人守着花",1500,[terrain(970,280,65,555,"stem")],-1,"它只追一小段，花茎能隔开视线",[Vector2(70,500),Vector2(250,630),Vector2(620,630),Vector2(850,190),Vector2(1080,190),Vector2(1080,530)],[Vector2(70,500),Vector2(250,190),Vector2(850,190),Vector2(1080,190),Vector2(1080,530)]),
			beat("还开着的蓝花",1000,[terrain(POND_FORK.position.x-2700-POND_APPROACH_EXTENSION,POND_FORK.position.y,POND_FORK.size.x,POND_FORK.size.y)],600,"叶影分开了去向，蓝花仍开着",[Vector2(50,500),Vector2(50,230),Vector2(500,230),Vector2(770,230),Vector2(770,600),Vector2(1010,600)],[Vector2(50,500),Vector2(400,500),Vector2(500,420),Vector2(770,600),Vector2(1010,600)]),
			beat("沿池岸绕向雨廊",650,[],-1,"枝架通到另一侧，归巢的小路就在前面",[Vector2(270,600),Vector2(470,500)])]
	elif index==1:
		beats=[
			beat("从叶下看雨",800,[],520,"云经过叶尖，前面留着棚下通路",[Vector2(620,520)]),
			beat("从棚下抬高一步",1550,[terrain(20,250,800,80),terrain(610,470,65,365,"stem"),terrain(1100,330,350,95),weather(0,1550),dew(960,520,"穿过露天后共有的补给")],520,"先抬升穿过叶下通口，再接住下一片叶棚",[Vector2(450,520),Vector2(550,400),Vector2(740,400),Vector2(960,520),Vector2(1320,520)]),
			beat("低叶下的一处歇脚",460,[weather(0,1250),shield(20,450)],600,"低叶留着歇脚处，护雨叶在露天前轻晃",[Vector2(-20,630),Vector2(280,600)],[Vector2(40,520),Vector2(20,450),Vector2(110,380),Vector2(450,380)]),
			beat("从两层接住下一片叶",1040,[terrain(RAIN_OVERHEAD.position.x-2810,RAIN_OVERHEAD.position.y,RAIN_OVERHEAD.size.x,RAIN_OVERHEAD.size.y),terrain(RAIN_UPPER_STEM.position.x-2810,RAIN_UPPER_STEM.position.y,RAIN_UPPER_STEM.size.x,RAIN_UPPER_STEM.size.y,"stem"),terrain(470,480,65,355,"stem"),dew(750,420,"两路重新合流时补给")],520,"绕过叶尖再抬升，雨顶下的通口接回共同小路",[Vector2(-30,600),Vector2(50,520),Vector2(200,520)],[Vector2(50,380),Vector2(50,520),Vector2(200,520)]),
			beat("看见熟悉的池岸",450,[],500,"雨停了，那簇蓝花还在池岸边",[Vector2(-692,520),Vector2(-692,435),Vector2(-650,435),Vector2(-450,435),Vector2(-290,420),Vector2(230,500)])]
	else:
		beats=homeward_approach()+[
			beat("等它停下盘点",1100,[terrain(910,80,42,315,"stem"),terrain(910,535,42,225,"stem"),{"kind":"curtain","x":910.0,"y":465.0,"height":140.0}],465,"牌绳绷着时先观察，盘点时冲开干叶结",[Vector2(410,590),Vector2(410,370),Vector2(575,370),Vector2(575,465),launch(Vector2.RIGHT,true),Vector2(1050,465)]),
			beat("从牌架背面穿过",900,[chain([Vector2(220,280),Vector2(340,180),Vector2(460,275)],[],Vector2(1010,300)),terrain(290,290,60,160,"sign_board"),terrain(315,125,276,14,"sign_beam"),terrain(570,80,42,130,"stem"),terrain(570,390,42,370,"stem"),{"kind":"curtain","x":570.0,"y":300.0,"height":180.0},dew(1030,500,"穿开叶门后，顺着出口落向共同补给")],500,"借花抬升后接住背面的通口，也可以自行换层",[Vector2(185,465),launch(Vector2.UP),Vector2(1010,300),Vector2(1030,500)],[Vector2(200,465),Vector2(200,500),Vector2(500,500),Vector2(500,300),Vector2(530,300),launch(),Vector2(1010,300),Vector2(1030,500)]),
			beat("把花路带回家",910,[],-1,"巢门就在前面，蜡脾边有人等着出发",[Vector2(410,500),Vector2(730,500)])]
	var source={"title":TITLES[index],"region":0,"theme":0 if index!=1 else 2,"music":0 if index==0 else 2,"base_bees":1,"storm":false,"exit_kind":"home" if index==2 else "arch","entry":["这边的花还没开，沿池岸找一找。","雨要经过这段回廊，先从叶下看一看。","绕回熟悉的池岸，庄主把花牌挂到了路中间。!"][index].trim_suffix("!"),"arrival":["沿池岸的枝架，绕到有叶棚的那一侧。","雨停了，回家的路就在那簇蓝花旁边。",""][index],"npc":"","neighbor_stops":[],"encounters":beats}
	var result: Dictionary=Builder.build_source(source)
	# Three flowers support one choice without refunding the whole dash.
	result["ring_reward"]=4.0
	if index==0:
		relocate_rest(result,"还开着的蓝花",Vector2(3710+POND_APPROACH_EXTENSION,600))
	if index==1:
		result.shelters[2].half_width=118.0
		result.shelters[3].pos=RAIN_HIGH_REST
		result.shelters[3].half_width=118.0
		result.sections[3].rest=RAIN_HIGH_REST
		# Reference input only: the upper choice passes the low leaf without resting.
		result.optional_route=result.optional_route.filter(func(command): return not (command.kind=="move" and command.target==RAIN_LOW_REST) and not (command.kind=="rest" and command.get("section")==2))
		for route_name in ["route","optional_route"]:
			for command in result[route_name]:
				if command.kind=="move" and command.target==Vector2(3670,520): command.target=RAIN_HIGH_REST
	if index==2:
		# The descent lands before the leaf's left edge. Its painted canopy is
		# solid on both faces, so putting it directly over the descent traps it.
		relocate_rest(result,"这次从低处回来",Vector2(4300,550))
		relocate_rest(result,"等它停下盘点",Vector2(2490+POND_APPROACH_EXTENSION,465))
		omit_reference_rest(result,"从牌架背面穿过")
	for route_name in ["route","optional_route"]:
		result[route_name].insert(result[route_name].size()-1,Builder.move_to(Vector2(4360 if index==1 else 4410+POND_APPROACH_EXTENSION,500)))
	for i in result.encounters.size():
		result.encounters[i]["act"]=i
		result.encounters[i]["act_name"]=beats[i].name
	# The quiet departure/home stretch belongs to the last completed movement;
	# it must not create a final section with no reachable checkpoint.
	if result.sections.size()>result.shelters.size():
		result.sections.pop_back()
		result.sections.back().end_x=result.world_width
		for key in ["encounters","rings","dew","shields"]:
			for item in result[key]:
				if item.has("section"): item.section=mini(item.section,result.sections.size()-1)
	return result
