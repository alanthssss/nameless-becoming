extends "res://event_data.gd"
## Hand-authored connected gardens. Width, recovery and action order follow the
## experience, not a repeating cell catalogue. Routes are developer inputs only.
const Builder = preload("res://chapter_data.gd")
const JOURNEY_ID := "summer-long-07-08-r5"
const ACTS := [["看见两面","风的落点","换一面看","顺畅离开"],["先听一听","穿过呼吸","风与喷嚏","一起离开"]]

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
	index = clampi(index,0,1)
	var source: Dictionary = definitions()[index]
	var result := Builder.build_source(source)
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
	return [garden_seven(),garden_eight()]

static func garden_seven() -> Dictionary:
	return chapter("花篱另一边","小满在花篱另一边。先看风把你带到哪里。","小满：这回，你自己找到了路。\n前面的花园传来一声小小的喷嚏。","bee",[
		{"index":0,"line":"小满：刚才那阵风，把你送到这里了。"},
		{"index":2,"line":"小满：现在你会挑落点啦。"},
		{"index":4,"line":"小满：先看看那扇窗，出口就在它后面。"},
		{"index":5,"line":"小满：最后一段，我在花铃下面等你。"},
		{"index":6,"line":"小满：到了！你飞得越来越从容了。"}
	],[
		# Introduce two viable approaches; merge BEFORE the next decision.
		scene("花篱两面",0,2600,[terrain(540,350,1000,150),relay([[460,250],[880,250],[1300,250]],[1770,250]),dew(1900,420,"借风或绕篱后，在共同出口补给"),gap(2260,420,370)],
			[[290,250],"burst",[1790,250],[1900,420],[2140,420],[2450,420]],
			[[380,600],[1720,600],[1900,420],[2140,420],[2450,420]],-1,"越过花篱，两条路在窗前相会"),
		# A rising relay opens the upper window, then the overhang turns us low.
		scene("风把路抬起来",0,4000,[relay([[420,500],[800,370],[1180,240]],[1650,240]),gap(1430,240,290),terrain(1940,80,380,350),dew(1810,530,"收势后在遮檐下补给"),terrain(2730,500,500,230),dew(2600,330,"升到花台前的通路"),gap(3400,330,350)],
			[[250,500],"burst",[1660,240],[1810,530],[2450,530],[2600,330],[3300,330],[3580,330]],
			[[280,500],[650,430],[1040,310],[1300,240],[1640,240],[1810,530],[2450,530],[2600,330],[3300,330],[3580,330]],420,"从高窗出来，落到遮檐下面"),
		# Develop: fast entry, room to brake, low window, then launch again.
		scene("一阵风，两次转向",1,5100,[relay([[420,270],[840,270],[1260,270]],[1730,270]),terrain(1970,80,420,370),dew(1820,550,"转到下窗前补给"),gap(2570,550,300),terrain(2920,330,1040,110),relay([[2810,560],[3230,560],[3650,560]],[4120,560]),dew(4270,420,"两阵风之后的共同出口"),gap(4660,420,340)],
			[[250,270],"burst",[1740,270],[1820,550],[2640,560],"burst",[4140,560],[4270,420],[4520,420],[4860,420]],
			[[320,570],[1820,550],[2700,550],[2800,560],[4140,560],[4270,420],[4520,420],[4860,420]],-1,"风停后向下转，再接住篱下的风"),
		# Do not reset at the scene boundary: the low exit becomes the next takeoff.
		scene("落点就是起点",1,4600,[terrain(530,80,600,340),dew(370,550,"出发前顺路补给"),relay([[1280,550],[1670,400],[2060,250]],[2530,250]),gap(2320,250,300),terrain(2870,80,380,370),dew(2710,540,"高窗后转入低处"),gap(3540,540,310),terrain(3920,540,280,190)],
			[[370,550],[1110,550],"burst",[2540,250],[2710,540],[3370,540],[3740,540],[3780,390],[4320,390]],
			[[370,550],[1160,550],[1500,440],[1960,260],[2190,250],[2540,250],[2710,540],[3370,540],[3740,540],[3780,390],[4320,390]],-1,"低处出发，高窗落下；下一步从这里接上"),
		# Breather has a small spatial purpose, no new threat or mandatory wait.
		scene("叶影里的小径",1,2700,[terrain(510,80,560,300),terrain(1630,520,510,210),dew(1350,450,"穿过叶影后继续向前")],
			[[340,510],[1190,510],[1350,450],[1500,370],[2320,370],[2520,420]],[],420,"从叶影下穿过，看看前面的花台"),
		# Choice of landing: two wind branches, both retain their own next angle.
		scene("选一边落下",1,5600,[terrain(660,340,1510,140),fork([Vector2(520,230),Vector2(920,230),Vector2(1320,230)],Vector2(1790,230),[Vector2(520,580),Vector2(920,580),Vector2(1320,580)],Vector2(1790,580),Vector2(2440,420)),dew(2440,420,"两种落点后的共同补给"),gap(2790,420,320),terrain(3190,80,540,350),dew(3030,550,"转入低廊前补给"),relay([[3900,550],[4300,400],[4700,250]],[5170,250])],
			[[350,230],"burst",[1800,230],[2330,230],[2440,420],[2640,420],[2960,420],[3030,550],[3730,550],"burst",[5180,250]],
			[[350,580],"burst",[1800,580],[2330,580],[2440,420],[2640,420],[2960,420],[3030,550],[3730,550],"burst",[5180,250]],300,"上风、下风都通；落点不同，转向也不同"),
		# Twist: a low launch crosses an opening before climbing on the far side.
		scene("篱下的另一面",2,4700,[terrain(560,300,1010,140),relay([[470,550],[890,550],[1310,550]],[1780,550]),dew(1900,420,"借下方风或从上沿绕行后共同补给"),gap(2250,420,330),terrain(2660,480,680,250),dew(2530,270,"从花篱背面抬头"),gap(3560,270,300),terrain(3970,80,310,350)],
			[[300,550],"burst",[1800,550],[1900,420],[2100,420],[2420,420],[2530,270],[3430,270],[3760,270],[3800,550],[4460,550]],
			[[380,190],[1730,190],[1900,420],[2100,420],[2420,420],[2530,270],[3430,270],[3760,270],[3800,550],[4460,550]],-1,"这回从篱下出来，再看高处的窗口"),
		# Long connected descent and climb, not three independent vertical gates.
		scene("顺着叶脉下去",2,5700,[relay([[440,520],[840,390],[1240,260]],[1710,260]),terrain(1950,80,470,350),dew(1810,540,"沿遮檐落向低廊"),terrain(2540,80,1040,310),gap(2950,570,300),relay([[2640,570],[3060,570],[3480,570]],[3950,570]),dew(4120,420,"低廊后的共同补给"),terrain(4500,490,620,240),gap(5330,310,320)],
			[[270,520],"burst",[1720,260],[1810,540],[2470,570],"burst",[3970,570],[4120,420],[4350,310],[5180,310],[5500,310]],
			[[280,520],[1060,300],[1720,260],[1810,540],[2470,570],[3970,570],[4120,420],[4350,310],[5180,310],[5500,310]],380,"上升、收势、穿低廊，再回到阳光里"),
		# A breakable curtain changes the chosen route; bypass rejoins naturally.
		scene("推开叶间的门",2,4800,[terrain(580,80,220,220),terrain(580,540,220,60),{"kind":"curtain","x":620.0,"y":435.0,"height":270.0},dew(1160,420,"推开叶帘或从花台下绕过后补给"),terrain(1560,330,990,140),relay([[1430,230],[1850,230],[2270,230]],[2740,230]),dew(2940,420,"绕过花台后共同落点"),terrain(3340,80,380,360),gap(4150,550,330)],
			[[450,420],"burst",[1160,420],[1260,230],"burst",[2760,230],[2940,420],[3150,550],[3980,550],[4380,550]],
			[[400,650],[960,650],[1160,420],[1380,590],[2740,590],[2940,420],[3150,550],[3980,550],[4380,550]],550,"冲开叶帘走中间，也可以从下方绕过"),
		# Same learned control, changed entrance: descend first, climb second.
		scene("从下面看窗",2,5400,[terrain(420,80,840,320),dew(1460,540,"低处来向的补给"),relay([[1640,540],[2040,400],[2440,260]],[2910,260]),gap(2690,260,310),terrain(3260,80,470,350),dew(3090,550,"高窗后选择低落点"),gap(3990,550,320),terrain(4400,510,430,220)],
			[[260,540],[1340,540],[1460,540],[1470,540],"burst",[2920,260],[3090,550],[3820,550],[4190,550],[4240,340],[4990,340]],
			[[260,540],[1340,540],[1460,540],[1890,430],[2320,280],[2540,260],[2920,260],[3090,550],[3820,550],[4190,550],[4240,340],[4990,340]],-1,"先从下面靠近，再选高窗后的落点"),
		# Preparation and a vista before the single final compound challenge.
		scene("看见最后的窗",2,2400,[terrain(590,510,570,220),terrain(1490,80,300,290),dew(1330,440,"转过观景花台")],
			[[430,350],[1250,350],[1330,440],[1370,520],[1960,520]],[],420,"小满在叶下等你；下一段用上刚才的飞法"),
		# Climax part 1: alternating relays connected by deliberate braking bays.
		scene("把风连成一条路",3,7200,[relay([[430,500],[830,360],[1230,220]],[1700,220]),gap(1470,220,270),terrain(1960,80,420,360),dew(1810,550,"高风收势后的补给"),relay([[2590,550],[3010,550],[3430,550]],[3900,550]),terrain(2670,300,1000,130),dew(4090,420,"低风之后准备抬升"),gap(4460,420,300),relay([[4740,420],[5140,290],[5540,290]],[6010,290]),terrain(6290,80,310,330),dew(6140,540,"末次借风后进入低出口"),gap(6840,540,310)],
			[[260,500],"burst",[1710,220],[1810,550],[2420,550],"burst",[3920,550],[4090,420],[4300,420],[4570,420],"burst",[6020,290],[6140,540],[6690,540],[7040,540]],
			[[260,500],[1040,260],[1330,220],[1710,220],[1810,550],[2420,550],[3920,550],[4090,420],[4300,420],[4630,420],[5020,320],[6020,290],[6140,540],[6690,540],[7040,540]],-1,"接风、收势、换高度；沿途的落点连成一条路"),
		# Climax resolves in an open landing; no new hazard after this section.
		scene("自己选最后的落点",3,5100,[terrain(580,330,1530,150),fork([Vector2(430,220),Vector2(830,220),Vector2(1230,220)],Vector2(1700,220),[Vector2(430,580),Vector2(830,580),Vector2(1230,580)],Vector2(1700,580),Vector2(2370,420)),dew(2370,420,"最后一次选路后相会"),gap(2720,420,320),relay([[3060,420],[3460,300],[3860,300]],[4330,300]),dew(4540,420,"到达花铃前的共同补给")],
			[[260,220],"burst",[1710,220],[2250,220],[2370,420],[2560,420],[2890,420],"burst",[4350,300],[4540,420]],
			[[260,580],"burst",[1710,580],[2250,580],[2370,420],[2560,420],[2890,420],"burst",[4350,300],[4540,420]],420,"选定一边，穿过最后的窗；前面就是抵达"),
		# Release: one optional farewell wind, no further examination.
		scene("花铃在前面",3,1900,[relay([[420,420],[830,420]],[1300,420])],
			[[250,420],"burst",[1320,420],[1700,420]],[[250,580],[1300,580],[1700,420]],-1,"小满：走吧，去听听下一座花园的声音")
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
