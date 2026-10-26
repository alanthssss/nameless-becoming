extends "res://event_data.gd"
## Hand-authored connected gardens. Width, recovery and action order follow the
## experience, not a repeating cell catalogue. Routes are developer inputs only.
const Builder = preload("res://chapter_data.gd")
const STAGE_COUNT := 3
const JOURNEY_ID := "summer-long-07-09-r8"
const ACTS := [["看见两面","风的落点","换一面看","顺畅离开"],["先听一听","穿过呼吸","风与喷嚏","一起离开"],["选好落点","收住，再出发","顺着自己的路"]]

static func v(pair: Array) -> Vector2:
	return Vector2(pair[0],pair[1])

static func relay(points: Array,landing: Array) -> Dictionary:
	var vectors: Array = []
	for point in points: vectors.append(v(point))
	return chain(vectors,[],v(landing))

static func path(points: Array) -> Array:
	var out: Array = []
	for point in points:
		if point is Array: out.append(v(point))
		elif point is String: out.append({"kind":"burst","direction":Vector2.RIGHT})
		else: out.append(point)
	return out

static func scene(name: String,act: int,width: float,beats: Array,primary: Array,alternate: Array,rest: float,cue: String) -> Dictionary:
	var spec := encounter(name,width,beats,rest,cue)
	spec["act"] = act
	spec["direct_route"] = path(primary)
	spec["alternate_route"] = path(alternate) if not alternate.is_empty() else spec.direct_route.duplicate(true)
	return spec

static func build(index: int) -> Dictionary:
	index = clampi(index,0,STAGE_COUNT-1)
	var source: Dictionary = definitions()[index]
	var result := Builder.build_source(source)
	if index == 0:
		# A full wind relay supports the action without refunding more than its cost.
		result["ring_reward"] = 4.0
	if index == 1:
		# Three small drops form a readable forward collection line. Recovery
		# comes from completing an action, not stacked full-size refills.
		result["dew_reward"] = 4.0
		result["dew_radius"] = 42.0
		result["calm_dash_extension"] = 0.38
		result["sprayer_period"] = 2.2
		result["puff_speed"] = 240.0
		for flower_index in result.sprayers.size():
			result.sprayers[flower_index].timer = 1.0 if flower_index == 0 else 0.8
	for i in result.encounters.size():
		result.encounters[i]["act"] = source.encounters[i].act
		result.encounters[i]["act_name"] = ACTS[index][source.encounters[i].act]
	# A quiet coda belongs to the completed final movement, not an unreachable
	# extra checkpoint. The last authored scene deliberately has no shelter.
	if result.sections.size() > result.shelters.size():
		result.sections.pop_back()
		result.sections.back().end_x = result.world_width
		for key in ["encounters","rings","dew","shields"]:
			for item in result[key]:
				if item.has("section"): item.section = mini(item.section,result.sections.size()-1)
	return result

static func chapter(title: String,entry: String,arrival: String,npc: String,stops: Array,encounters: Array) -> Dictionary:
	return {"title":title,"region":1,"theme":1,"music":1,"base_bees":9,"storm":false,"exit_kind":"arch","entry":entry,"arrival":arrival,"npc":npc,"npc_line":"","neighbor_stops":stops,"encounters":encounters}

static func definitions() -> Array:
	return [garden_seven(),garden_eight(),garden_nine()]

static func garden_seven() -> Dictionary:
	return chapter("花篱另一边","小满在花篱另一边。先看风把你带到哪里。","小满：这回，你自己找到了路。\n前面的花园传来一声小小的喷嚏。","bee",[
		{"index":0,"line":"小满：刚才那阵风，把你送到这里了。"},
		{"index":2,"line":"小满：现在你会挑落点啦。"},
		{"index":4,"line":"小满：先看看那扇窗，出口就在它后面。"},
		{"index":5,"line":"小满：最后一段，我在花铃下面等你。"},
		{"index":6,"line":"小满：到了！你飞得越来越从容了。"}
	],[
		# Introduce two viable approaches; merge BEFORE the next decision.
		scene("花篱两面",0,2920,[terrain(540,350,1000,150),relay([[460,250],[880,250],[1300,250]],[1770,250]),dew(2220,420,"借风或绕篱后，在共同出口补给"),gap(2580,420,370)],
			[[290,250],"burst",[1790,250],[2220,420],[2460,420],[2770,420]],
			[[380,600],[1720,600],[2220,420],[2460,420],[2770,420]],-1,"越过花篱，两条路在窗前相会"),
		# A rising relay opens the upper window, then the overhang turns us low.
		scene("风把路抬起来",0,4340,[relay([[420,500],[800,370],[1180,240]],[1650,240]),gap(1430,240,290),terrain(2280,80,380,350),dew(2150,530,"收势后在遮檐下补给"),terrain(3070,500,500,230),dew(2940,330,"升到花台前的通路"),gap(3740,330,350)],
			[[250,500],"burst",[1660,240],[2150,530],[2790,530],[2940,330],[3640,330],[3920,330]],
			[[280,500],[650,430],[1040,310],[1300,240],[1640,240],[2150,530],[2790,530],[2940,330],[3640,330],[3920,330]],420,"从高窗出来，落到遮檐下面"),
		# Develop: fast entry, room to brake, low window, then launch again.
		scene("一阵风，两次转向",1,5760,[relay([[420,270],[840,270],[1260,270]],[1730,270]),terrain(2380,80,420,370),dew(2230,550,"转到下窗前补给"),gap(2980,550,300),terrain(3330,330,1040,110),relay([[3220,560],[3640,560],[4060,560]],[4530,560]),dew(4930,420,"两阵风之后的共同出口"),gap(5320,420,340)],
			[[250,270],"burst",[1740,270],[2230,550],[3050,560],"burst",[4550,560],[4930,420],[5180,420],[5520,420]],
			[[320,570],[2230,550],[3110,550],[3210,560],[4550,560],[4930,420],[5180,420],[5520,420]],-1,"风停后向下转，再接住篱下的风"),
		# Do not reset at the scene boundary: the low exit becomes the next takeoff.
		scene("落点就是起点",1,4880,[terrain(530,80,600,340),dew(370,550,"出发前顺路补给"),relay([[1280,550],[1670,400],[2060,250]],[2530,250]),gap(2320,250,300),terrain(3150,80,380,370),dew(2990,540,"高窗后转入低处"),gap(3820,540,310),terrain(4200,540,280,190)],
			[[370,550],[1110,550],"burst",[2540,250],[2990,540],[3650,540],[4020,540],[4060,390],[4600,390]],
			[[370,550],[1160,550],[1500,440],[1960,260],[2190,250],[2540,250],[2990,540],[3650,540],[4020,540],[4060,390],[4600,390]],-1,"低处出发，高窗落下；下一步从这里接上"),
		# Breather has a small spatial purpose, no new threat or mandatory wait.
		scene("叶影里的小径",1,1400,[terrain(200,80,320,300),terrain(850,540,300,190),dew(650,450,"穿过叶影后继续向前")],
			[[160,510],[550,510],[650,450],[720,370],[1180,370],[1220,420]],[],420,"从叶影下穿过，看看前面的花台"),
		# Choice of landing: two wind branches, both retain their own next angle.
		scene("选一边落下",1,5600,[terrain(660,340,1510,140),fork([Vector2(520,230),Vector2(920,230),Vector2(1320,230)],Vector2(1790,230),[Vector2(520,580),Vector2(920,580),Vector2(1320,580)],Vector2(1790,580),Vector2(2440,420)),dew(2440,420,"两种落点后的共同补给"),gap(2790,420,320),terrain(3190,80,540,350),dew(3030,550,"转入低廊前补给"),relay([[3900,550],[4300,400],[4700,250]],[5170,250])],
			[[350,230],"burst",[1800,230],[2330,230],[2440,420],[2640,420],[2960,420],[3030,550],[3730,550],"burst",[5180,250]],
			[[350,580],"burst",[1800,580],[2330,580],[2440,420],[2640,420],[2960,420],[3030,550],[3730,550],"burst",[5180,250]],300,"上风、下风都通；落点不同，转向也不同"),
		# Twist: a low launch crosses an opening before climbing on the far side.
		scene("篱下的另一面",2,5020,[terrain(560,300,1010,140),relay([[470,550],[890,550],[1310,550]],[1780,550]),dew(2220,420,"借下方风或从上沿绕行后共同补给"),gap(2570,420,330),terrain(2980,480,680,250),dew(2850,270,"从花篱背面抬头"),gap(3880,270,300),terrain(4290,80,310,350)],
			[[300,550],"burst",[1800,550],[2220,420],[2420,420],[2740,420],[2850,270],[3750,270],[4080,270],[4120,550],[4780,550]],
			[[380,190],[1730,190],[2220,420],[2420,420],[2740,420],[2850,270],[3750,270],[4080,270],[4120,550],[4780,550]],-1,"这回从篱下出来，再看高处的窗口"),
		# Long connected descent and climb, not three independent vertical gates.
		scene("顺着叶脉下去",2,6310,[relay([[440,520],[840,390],[1240,260]],[1710,260]),terrain(2330,80,470,350),dew(2190,540,"沿遮檐落向低廊"),terrain(2920,80,1040,310),gap(3330,570,300),relay([[3020,570],[3440,570],[3860,570]],[4330,570]),dew(4730,420,"低廊后的共同补给"),terrain(5110,490,620,240),gap(5940,310,320)],
			[[270,520],"burst",[1720,260],[2190,540],[2850,570],"burst",[4350,570],[4730,420],[4960,310],[5790,310],[6110,310]],
			[[280,520],[1060,300],[1720,260],[2190,540],[2850,570],[4350,570],[4730,420],[4960,310],[5790,310],[6110,310]],380,"上升、收势、穿低廊，再回到阳光里"),
		# A breakable curtain changes the chosen route; bypass rejoins naturally.
		scene("推开叶间的门",2,5000,[terrain(580,80,220,220),terrain(580,540,220,60),{"kind":"curtain","x":620.0,"y":435.0,"height":270.0},dew(1160,420,"推开叶帘或从花台下绕过后补给"),terrain(1560,330,990,140),relay([[1430,230],[1850,230],[2270,230]],[2740,230]),dew(3140,420,"绕过花台后共同落点"),terrain(3540,80,380,360),gap(4350,550,330)],
			[[450,420],"burst",[1160,420],[1260,230],"burst",[2760,230],[3140,420],[3350,550],[4180,550],[4580,550]],
			[[400,650],[960,650],[1160,420],[1380,590],[2740,590],[3140,420],[3350,550],[4180,550],[4580,550]],550,"冲开叶帘走中间，也可以从下方绕过"),
		# Develop the previous leaf-door action: borrowed momentum now opens it.
		# The lower corridor stays open; no extra launch or timing window is required.
		scene("让风推开叶门",2,5680,[terrain(420,80,840,320),dew(1460,540,"低处来向的补给"),relay([[1640,540],[2040,400],[2440,260]],[2910,260]),{"kind":"curtain","x":2690.0,"y":260.0,"height":270.0},terrain(3540,80,470,350),dew(3370,550,"借风开门或从下方绕过后，在出口相会"),gap(4270,550,320),terrain(4680,510,430,220)],
			[[260,540],[1340,540],[1460,540],[1470,540],"burst",[2920,260],[3370,550],[4100,550],[4470,550],[4520,340],[5270,340]],
			[[260,540],[1340,540],[1460,540],[2920,540],[3370,550],[4100,550],[4470,550],[4520,340],[5270,340]],-1,"让上升的风带你穿过叶门；下方也有路"),
		# Preparation and a vista before the single final compound challenge.
		scene("看见最后的窗",2,1250,[terrain(260,540,300,190),terrain(760,80,200,290),dew(660,440,"转过观景花台")],
			[[160,350],[580,350],[660,440],[700,520],[1040,520]],[],420,"小满在叶下等你；下一段用上刚才的飞法"),
		# Payoff: the same wind-to-door relationship now works along the low corridor.
		# A broad lower bypass keeps ordinary flight viable without precision timing.
		scene("把风连成一条路",3,8050,[relay([[430,500],[830,360],[1230,220]],[1700,220]),gap(1470,220,270),terrain(2330,80,420,360),dew(2180,550,"高风收势后的补给"),relay([[2960,550],[3380,550],[3800,550]],[4270,550]),terrain(3040,300,1000,130),{"kind":"curtain","x":4160.0,"y":550.0,"height":220.0},dew(4670,420,"风推开叶门后，顺势收露再抬升"),gap(5040,420,300),relay([[5320,420],[5720,290],[6120,290]],[6590,290]),terrain(7140,80,310,330),dew(6990,540,"末次借风后进入低出口"),gap(7690,540,310)],
			[[260,500],"burst",[1710,220],[2180,550],[2790,550],"burst",[4290,550],[4670,420],[4880,420],[5150,420],"burst",[6600,290],[6990,540],[7540,540],[7890,540]],
			[[260,500],[1040,260],[1330,220],[1710,220],[2180,550],[2790,550],[4000,550],[4000,710],[4350,710],[4670,420],[4880,420],[5210,420],[5600,320],[6600,290],[6990,540],[7540,540],[7890,540]],-1,"先收势落进低廊，再借风推开叶门，接住出口的露珠"),
		# Climax resolves in an open landing; no new hazard after this section.
		scene("自己选最后的落点",3,5290,[terrain(580,330,1530,150),fork([Vector2(430,220),Vector2(830,220),Vector2(1230,220)],Vector2(1700,220),[Vector2(430,580),Vector2(830,580),Vector2(1230,580)],Vector2(1700,580),Vector2(2370,420)),dew(2370,420,"最后一次选路后相会"),gap(2720,420,320),relay([[3060,420],[3460,300],[3860,300]],[4330,300]),dew(4730,420,"到达花铃前的共同补给")],
			[[260,220],"burst",[1710,220],[2250,220],[2370,420],[2560,420],[2890,420],"burst",[4350,300],[4730,420]],
			[[260,580],"burst",[1710,580],[2250,580],[2370,420],[2560,420],[2890,420],"burst",[4350,300],[4730,420]],420,"选定一边，穿过最后的窗；前面就是抵达"),
		# Release: one optional farewell wind, no further examination.
		scene("花铃在前面",3,1600,[relay([[420,420],[830,420]],[1300,420])],
			[[250,420],"burst",[1320,420],[1480,420]],[[250,580],[1300,580],[1480,420]],-1,"小满：走吧，去听听下一座花园的声音")
	])

# Collection follows the actual launch line, beyond the natural dash endpoint.
static func ribbon(x: float,y: float) -> Array:
	return [dew(x,y,"冲刺出口顺势收集"),dew(x+100,y,"沿飞行方向连续收集"),dew(x+200,y,"收集之后继续向前")]

static func garden_eight() -> Dictionary:
	return chapter("喷嚏前后","画眉：花已经在吸气了，找好穿过去的那条线。","画眉：刚才那一串，你飞得真漂亮。","bird",[
		{"index":0,"line":"画眉：冲过去，露珠就在前面接着你。"},
		{"index":1,"line":"画眉：换个高度，又找到了一条路。"},
		{"index":2,"line":"画眉：借来的风，也能送你穿过喷嚏。"},
		{"index":3,"line":"画眉：到了，我们一起穿过花铃吧。"}
	],[
		# First earn a refill: read two windows, meet a real attack, then collect.
		scene("穿窗，迎上第一口气",0,3600,[gap(620,420,340),gap(1200,340,300),flower(2000,340),terrain(1850,540,600,190),gap(3000,340,340)]+ribbon(2360,340),
			[[450,420],[850,420],[1000,340],[1460,340],[1650,340],"burst",[2700,340],[3220,340]],
			[[450,420],[850,420],[1000,340],[1460,340],[1580,150],[2220,150],[2360,340],[2700,340],[3220,340]],-1,"花朵鼓起时准备；冲过喷嚏，顺势接住露珠"),
		# One flower, then a different action: collect, climb and open the curtain.
		scene("花后换线，穿过叶帘",0,4120,[terrain(450,80,400,310),flower(1200,540),gap(2470,340,330),{"kind":"curtain","x":2970.0,"y":340.0,"height":250.0}]+ribbon(1560,540)+ribbon(3340,340),
			[[290,540],[850,540],"burst",[1960,540],[2210,340],[2660,340],[2800,340],"burst",[3710,340]],
			[[290,540],[900,540],[900,180],[1420,180],[1560,540],[1960,540],[2210,340],[2660,340],[2700,600],[3230,600],[3340,340],[3710,340]],540,"冲过花，接住露珠；抬高后穿过叶帘"),
		# Straight reward lane and room to turn; trim only the unused scene tail.
		scene("先飞尽兴，再换一层",1,4900,[flower(650,280),terrain(1780,80,420,330),gap(2390,540,320),relay([[2800,540],[3200,410],[3600,280]],[4070,280]),flower(3910,280)]+ribbon(1010,280)+ribbon(4230,280),
			[[300,280],"burst",[1430,280],[1570,540],[2220,540],[2600,540],[2630,540],"burst",[4230,280],[4620,280],[4680,420]],
			[[300,540],[900,540],[1010,280],[1430,280],[1570,540],[2220,540],[2600,540],[2980,540],[3750,540],[4110,540],[4230,280],[4620,280],[4680,420]],-1,"先沿着露珠飞出去，前面留好了转向的地方"),
		# A high flower and a low flower require two separate approaches.
		scene("高处接招，低处再起",1,5220,[terrain(440,500,420,230),flower(1200,320),terrain(2250,80,400,330),flower(3150,550),gap(4540,320,330)]+ribbon(1560,320)+ribbon(3510,550),
			[[280,320],[850,320],"burst",[1780,320],[2000,550],[2800,550],"burst",[3940,550],[4270,320],[4780,320]],
			[[280,320],[930,150],[1430,150],[1560,320],[1780,320],[2000,550],[2800,550],[2850,210],[3370,210],[3510,550],[3940,550],[4270,320],[4780,320]],420,"上一串收完再换高度；给下一次冲刺选好入口"),
		# Short release: collect under the leaf, with the water approach next.
		scene("沿着水声滑过去",1,800,[terrain(220,80,300,290),dew(660,460,"短暂收势后顺路补给")],
			[[150,460],[760,460]],[],-1,"沿着叶下露珠，顺势靠近水幕"),
		# A horizontal launch crosses the active jet; its underside is a safe bypass.
		scene("冲开水幕的间隙",2,4000,[terrain(250,500,720,110),jet(500,100,180,400,4.0,1.8),gap(1750,420,340),flower(2450,420),terrain(2320,580,530,150)]+ribbon(1050,420)+ribbon(2810,420),
			[[330,420],"burst",[1400,420],[1580,420],[1990,420],[2100,420],"burst",[3250,420],[3740,420]],
			[[40,670],[1030,670],[1050,420],[1400,420],[1580,420],[1990,420],[2090,220],[2670,220],[2810,420],[3250,420],[3740,420]],-1,"冲刺可以穿过水幕；从下方也能绕到同一串露珠"),
		# Wind landing and manual attack each have an open forward collection lane.
		scene("借风穿过，再自己出手",2,5200,[relay([[430,540],[830,400],[1230,260]],[1700,260]),flower(1540,260),terrain(2660,80,370,330),gap(3270,550,330),flower(3910,550)]+ribbon(1850,260)+ribbon(4270,550),
			[[260,540],"burst",[1850,260],[2260,260],[2440,550],[3090,550],[3490,550],[3560,550],"burst",[4680,550],[4880,420]],
			[[260,540],[1530,570],[1730,570],[1850,260],[2260,260],[2440,550],[3090,550],[3490,550],[3520,280],[4130,280],[4270,550],[4680,550],[4880,420]],420,"借风冲过去，接完露珠再换层；下一朵由你出手"),
		# A short readable approach instead of a second empty garden of travel.
		scene("看见最后的连线",2,400,[terrain(120,80,180,250)],
			[[100,470],[320,420]],[],-1,"从叶下接向水幕，准备把学过的飞法连起来"),
		# Water, wind, a new low approach and a curtain; no redundant same-line pair.
		scene("把冲刺接成一路",3,7800,[terrain(250,500,720,100),jet(500,100,180,400,4.0,1.8),relay([[1720,420],[2120,290],[2520,290]],[2990,290]),flower(2800,290),terrain(3950,80,410,330),gap(4570,550,310),flower(5290,550),{"kind":"curtain","x":6660.0,"y":380.0,"height":250.0}]+ribbon(1050,420)+ribbon(3140,290)+ribbon(5650,550)+ribbon(7030,380),
			[[330,420],"burst",[1400,420],[1550,420],"burst",[3140,290],[3550,290],[3740,550],[4400,550],[4780,550],[4940,550],"burst",[6060,550],[6340,380],[6490,380],"burst",[7420,380]],
			[[40,670],[1030,670],[1050,420],[1400,420],[1690,570],[2920,570],[3140,290],[3550,290],[3740,550],[4400,550],[4780,550],[4950,250],[5510,250],[5650,550],[6060,550],[6340,600],[6920,600],[7030,380],[7420,380]],420,"穿水幕、借风、换层接招，再冲开叶帘"),
		# The final leaf already provides recovery; the farewell leads straight out.
		scene("花铃前的小径",3,350,[terrain(80,600,200,130)],
			[[200,420]],[],-1,"画眉：刚才那一串，接得真漂亮"),
		scene("一起穿过花铃",3,250,[],[[150,420]],[],-1,"画眉：走吧，花铃就在前面")
	])


static func garden_nine() -> Dictionary:
	return chapter("不借这一阵风","小满：先看看落在哪里，再决定借不借这阵风。","小满：你选的路，把我们带到了这里。","bee",[
		{"index":0,"line":"小满：高处往下转，低处往上走，都能到花窗。"},
		{"index":1,"line":"小满：风停了，下一次出发由你来。"}
	],[
		# A high wind landing asks for a descent; ordinary lower flight asks for
		# a climb. Shared supply follows BOTH decisions, never rewards a detour.
		scene("高处落下，低处抬头",0,3600,[terrain(580,350,700,150),relay([[380,340],[580,280],[780,230]],[1250,230]),terrain(2000,80,240,260),terrain(2000,560,240,170),dew(2530,440,"两种落点都在穿过花窗后补给"),terrain(2900,550,280,180)],
			[[210,340],"burst",[1270,230],[1510,230],[1910,440],[2530,440],[2760,440],[3300,420]],
			[[350,600],[1500,600],[1910,440],[2530,440],[2760,440],[3300,420]],420,"先看风的高落点；从下方绕过，也能抬头穿窗"),
		# Opposed half-arcs are separated by a generous manual transfer. The
		# first relay cannot reach the second; the next launch stays a choice.
		scene("收住，再接下一阵",1,6000,[relay([[500,540],[900,400],[1300,260]],[1770,260]),terrain(630,590,700,140),dew(2200,430,"第一阵风后自己收势，准备下一次出发"),terrain(2630,510,500,220),relay([[3330,250],[3730,390],[4130,530]],[4600,530]),terrain(3480,80,700,140),dew(5030,420,"第二阵风或普通飞行后的共同补给"),terrain(5430,540,260,190)],
			[[330,540],"burst",[1790,260],[2200,430],[2420,430],[2470,250],[3160,250],"burst",[4620,530],[5030,420],[5290,350],[5790,420]],
			[[350,540],[1460,540],[2200,430],[2420,430],[2470,350],[3200,350],[3260,600],[4620,600],[5030,420],[5290,350],[5790,420]],420,"接完上升的风，自己换层；再决定怎样接住下降的风"),
		# A short release, with no new examination or mandatory farewell burst.
		scene("自己的路",2,700,[],[[250,420],[540,420]],[],-1,"小满：前面就是花铃，按你自己的节奏飞吧")
	])
