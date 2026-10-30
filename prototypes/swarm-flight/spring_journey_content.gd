extends "res://event_data.gd"
const Builder = preload("res://chapter_data.gd")
const TITLES := ["池边小径","雨中停走","归巢之路"]
static func beat(name: String,width: float,objects: Array,rest: float,cue: String,route: Array,alternate: Array=[]) -> Dictionary:
	var b:=encounter(name,width,objects,rest,cue)
	b.direct_route=route
	b.alternate_route=alternate if not alternate.is_empty() else route
	return b
static func build(index: int) -> Dictionary:
	var beats: Array
	if index==0:
		beats=[
			beat("池岸的两层路",1200,[terrain(560,330,450,150),dew(1060,480,"高低两路合流后补给")],500,"高处看见前路，低处沿池岸绕行",[Vector2(400,230),Vector2(1080,230),Vector2(1270,500),Vector2(1060,480)],[Vector2(400,600),Vector2(1070,600),Vector2(1060,480)]),
			beat("荫边有人守着花",1500,[terrain(970,280,65,555,"stem")],500,"它只追一小段，花茎能隔开视线",[Vector2(70,500),Vector2(250,630),Vector2(620,630),Vector2(850,190),Vector2(1080,190),Vector2(1080,530)],[Vector2(70,500),Vector2(250,190),Vector2(850,190),Vector2(1080,190),Vector2(1080,530)]),
			beat("还开着的蓝花",1000,[],500,"花心可以停一停，也可以继续向前",[Vector2(70,500),Vector2(500,420),Vector2(770,600),Vector2(1010,600)]),
			beat("沿池岸绕向雨廊",650,[],500,"枝架通到另一侧，归巢的小路就在前面",[Vector2(270,600),Vector2(470,500)])]
	elif index==1:
		beats=[
			beat("从叶下看雨",800,[],520,"云经过叶尖，前面留着棚下通路",[Vector2(620,520)]),
			beat("从棚下抬高一步",1550,[terrain(20,250,800,80),terrain(610,470,65,365,"stem"),terrain(1100,330,350,95),weather(0,1550),dew(960,520,"穿过露天后共有的补给")],520,"先抬升穿过叶下通口，再接住下一片叶棚",[Vector2(450,520),Vector2(550,400),Vector2(740,400),Vector2(960,520),Vector2(1320,520)]),
			beat("从两层接住下一片叶",1500,[terrain(70,500,710,85),terrain(930,480,65,355,"stem"),weather(0,1250),shield(20,450),dew(1210,420,"两路重新合流时补给")],520,"取护雨从上层穿过，或沉到低棚下再从叶尖抬升",[Vector2(-40,630),Vector2(830,630),Vector2(850,420),Vector2(1210,420)],[Vector2(20,520),Vector2(20,450),Vector2(1210,420)]),
			beat("看见熟悉的池岸",450,[],500,"雨停了，那簇蓝花还在池岸边",[Vector2(230,500)])]
	else:
		beats=[
			beat("归路换了模样",1440,[terrain(870,270,80,300,"stem"),dew(1100,580,"接近牌架前补给")],500,"同一条池岸，前面却挂起了花牌",[Vector2(620,620),Vector2(1000,620),Vector2(1260,500)]),
			beat("等它停下盘点",1100,[terrain(910,80,42,315,"stem"),terrain(910,535,42,225,"stem"),{"kind":"curtain","x":910.0,"y":465.0,"height":140.0}],465,"牌绳绷着时先观察，盘点时冲开干叶结",[Vector2(410,590),Vector2(750,465)]),
			beat("从牌架背面穿过",900,[chain([Vector2(200,465),Vector2(320,300)],[],Vector2(690,300)),terrain(460,80,42,130,"stem"),terrain(460,390,42,370,"stem"),{"kind":"curtain","x":460.0,"y":300.0,"height":180.0},dew(700,420,"开通后与源花同路的补给")],500,"借花抬升后接住背面的通口，也可以自行换层",[Vector2(200,465),Vector2(320,300),Vector2(920,300),Vector2(920,620),Vector2(720,620)]),
			beat("把花路带回家",910,[],500,"巢门就在前面，蜡脾边有人等着出发",[Vector2(410,500),Vector2(730,500)])]
	var source={"title":TITLES[index],"region":0,"theme":0 if index!=1 else 2,"music":0 if index==0 else 2,"base_bees":1,"storm":false,"exit_kind":"home" if index==2 else "arch","entry":["池岸分成两层，蓝花还在前面开着。","雨要经过这段回廊，先从叶下看一看。","绕回熟悉的池岸，庄主把花牌挂到了路中间。!"][index].trim_suffix("!"),"arrival":["沿池岸的枝架，绕到有叶棚的那一侧。","雨停了，回家的路就在那簇蓝花旁边。",""][index],"npc":"","neighbor_stops":[],"encounters":beats}
	var result: Dictionary=Builder.build_source(source)
	if index==0:
		result.shelters[2].pos=Vector2(3710,600)
		result.sections[2].rest=Vector2(3710,600)
		for route_name in ["route","optional_route"]:
			for command in result[route_name]:
				if command.kind=="move" and command.target==Vector2(3520,500): command.target=Vector2(3710,600)
	if index==2:
		result.shelters[1].pos=Vector2(2490,465)
		result.sections[1].rest=Vector2(2490,465)
	for route_name in ["route","optional_route"]:
		result[route_name].insert(result[route_name].size()-1,Builder.move_to(Vector2(4360 if index==1 else 4410,500)))
	for i in result.encounters.size():
		result.encounters[i]["act"]=i
		result.encounters[i]["act_name"]=beats[i].name
	return result
