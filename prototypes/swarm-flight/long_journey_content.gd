extends "res://event_data.gd"
## Hand-authored connected gardens. Width, recovery and action order follow the
## experience, not a repeating cell catalogue. Routes are developer inputs only.
const Builder = preload("res://chapter_data.gd")
const JOURNEY_ID := "summer-long-07-08-r3"
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

static func garden_eight() -> Dictionary:
	return chapter("喷嚏前后","画眉：先听一听，花朵吸气时会鼓起来。","画眉：花朵安静了，我们也到啦。","bird",[
		{"index":0,"line":"画眉：花朵先吸气，才会打喷嚏。"},
		{"index":2,"line":"画眉：你给它留了空档，也给自己留了路。"},
		{"index":3,"line":"画眉：不用急，先看看前面那一朵。"},
		{"index":5,"line":"画眉：听，终于安静下来了。"}
	],[
		# Directly after 07, a short sheltered approach frames the first flower.
		scene("先听一口气",0,3100,[terrain(470,80,620,300),flower(1570,420),terrain(1440,550,520,180),dew(2200,420,"第一朵花之后的共同补给")],
			[[310,520],[1210,520],[1400,420],"burst",[2200,420]],
			[[310,520],[1210,520],[1290,240],[1990,240],[2200,420]],420,"看花朵鼓起，再选择安抚或绕过"),
		# Different approach height. Shelter on the route absorbs outgoing puffs.
		scene("叶影挡住喷嚏",0,4500,[terrain(450,340,350,190),flower(1130,290),dew(1730,420,"花朵之后落回共同出口"),terrain(2100,80,450,340),flower(2940,550),dew(3540,420,"低花之后抬头补给"),gap(3910,420,350)],
			[[290,250],[960,290],"burst",[1730,420],[1930,550],[2770,550],"burst",[3540,420],[3750,420],[4130,420]],
			[[290,610],[1500,610],[1730,420],[1930,550],[2650,550],[2650,230],[3290,230],[3540,420],[3750,420],[4130,420]],-1,"借叶影靠近；离开遮挡后再决定怎么过去"),
		# Transfer the player's 07 skill: calm, then brake into a low opening.
		scene("安静后的转弯",1,4900,[flower(540,280),terrain(1050,80,420,350),dew(900,550,"安抚或绕行后先落到低处"),gap(1710,550,320),relay([[2080,550],[2480,410],[2880,270]],[3350,270]),flower(3290,270),dew(3950,420,"借风安抚后落回共同通路"),gap(4370,420,330)],
			[[370,280],"burst",[900,550],[1550,550],[1900,550],[1910,550],"burst",[3370,270],[3950,420],[4210,420],[4580,420]],
			[[300,600],[900,550],[1550,550],[1900,550],[2600,430],[3150,480],[3710,480],[3950,420],[4210,420],[4580,420]],420,"安抚之后别直冲，下一扇窗在下面"),
		# Two independent breaths with a safe turn between, never a blind volley.
		scene("两次呼吸之间",1,5700,[terrain(460,490,440,240),flower(1190,320),dew(1770,420,"第一声喷嚏之后补给"),terrain(2130,80,460,340),flower(2970,550),dew(3550,420,"第二声喷嚏后回到同一路"),terrain(3910,500,570,230),gap(4780,300,330),dew(5120,420,"转出花台后的补给")],
			[[300,330],[1020,320],"burst",[1770,420],[1960,550],[2800,550],"burst",[3550,420],[3740,300],[4600,300],[4970,300],[5120,420]],
			[[300,330],[930,330],[930,170],[1570,170],[1770,420],[1960,550],[2670,550],[2670,230],[3320,230],[3550,420],[3740,300],[4600,300],[4970,300],[5120,420]],-1,"转弯把两朵花隔开，先处理眼前这一朵"),
		scene("水声旁歇一口气",1,2800,[terrain(500,80,520,300),terrain(1620,520,490,210),dew(1320,440,"在叶影与花台之间经过")],
			[[330,520],[1170,520],[1320,440],[1460,340],[2290,340]],[],420,"这里没有喷嚏，沿着叶影从容飞过去"),
		# Develop timing separately before combining it with flowers.
		scene("看见停喷的空档",2,4700,[terrain(650,450,780,110),jet(820,100,220,350,6.8,2.1),dew(1740,420,"穿过空档或绕行后的共同补给"),gap(2130,420,340),flower(2720,420),terrain(2600,550,500,180),dew(3350,420,"喷口之后再安抚花朵"),terrain(3740,80,360,330)],
			[[670,420],{"kind":"jet_window","jet_x":820.0,"travel_seconds":1.8},[1220,420],[1740,420],[1960,420],[2350,420],[2550,420],"burst",[3350,420],[3540,540],[4320,540]],
			[[460,650],[1570,650],[1740,420],[1960,420],[2350,420],[2420,250],[3130,250],[3350,420],[3540,540],[4320,540]],-1,"先看水的空档，转过窗后再听花朵"),
		# A wind-assisted calm, then a deliberate low approach to the next flower.
		scene("借风送去安静",2,5700,[relay([[430,540],[830,400],[1230,260]],[1700,260]),flower(1540,260),terrain(2040,80,370,360),dew(1860,550,"借风安抚后在低处补给"),gap(2720,550,330),flower(3240,550),dew(3840,420,"第二朵花后共同补给"),terrain(4230,490,660,240),gap(5150,310,330)],
			[[260,540],"burst",[1720,260],[1860,550],[2550,550],[2930,550],[3070,550],"burst",[3840,420],[4050,310],[4980,310],[5370,310]],
			[[260,540],[1450,570],[1860,550],[2550,550],[2930,550],[2930,280],[3580,280],[3840,420],[4050,310],[4980,310],[5370,310]],420,"借到的风也能安抚花朵；下一朵由你出发"),
		# Breather directly before the chapter's peak; no repeated mini-exams.
		scene("听清最后一段",2,2500,[terrain(600,80,500,310),terrain(1610,530,400,200),dew(1340,450,"穿过叶影，看向最后一片花园")],
			[[400,530],[1230,530],[1340,450],[1470,340],[2220,340]],[],420,"画眉：最后几朵花了，先看清，再出发"),
		# Climax: timed water, wind-calm, brake and last voluntary calm/bypass.
		scene("把呼吸接成一路",3,7300,[terrain(620,450,720,100),jet(800,100,220,350,6.8,2.1),dew(1630,420,"水园之后顺路补给"),relay([[1910,420],[2310,290],[2710,290]],[3180,290]),flower(3000,290),terrain(3520,80,410,360),dew(3340,550,"借风安抚后落向低廊"),gap(4240,550,310),flower(4800,550),dew(5420,420,"最后的花之后回到共同出口"),terrain(5820,500,610,230),gap(6740,320,350)],
			[[640,420],{"kind":"jet_window","jet_x":800.0,"travel_seconds":1.8},[1180,420],[1630,420],[1740,420],"burst",[3200,290],[3340,550],[4070,550],[4450,550],[4630,550],"burst",[5420,420],[5640,320],[6550,320],[6960,320]],
			[[440,650],[1470,650],[1630,420],[1860,560],[3140,560],[3340,550],[4070,550],[4450,550],[4490,280],[5150,280],[5420,420],[5640,320],[6550,320],[6960,320]],420,"水的空档、风的落点、花的呼吸，都看得见"),
		# Payoff and coda are quiet: no last flower or repeat examination.
		scene("画眉等候的叶下",3,1800,[terrain(510,600,620,130)],
			[[1450,420]],[],420,"听不见喷嚏了，画眉就在前面的叶下"),
		scene("一起穿过花铃",3,900,[],[[620,420]],[],-1,"画眉：这条路，我也记住啦")
	])
