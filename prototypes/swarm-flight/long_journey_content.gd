extends "res://event_data.gd"
## Two bounded long-form chapters. Cell variants author different spatial decisions;
## all routes remain optional ordinary inputs, never progression scripts.
const Builder = preload("res://chapter_data.gd")
const JOURNEY_ID := "summer-long-07-08-r1"

static func build(index: int) -> Dictionary:
	return Builder.build_source(definitions()[clampi(index,0,1)])

static func route(spec: Dictionary,primary: Array,alternate: Array = []) -> Dictionary:
	spec.direct_route = primary
	spec.alternate_route = primary.duplicate(true) if alternate.is_empty() else alternate
	return spec

static func launch() -> Dictionary:
	return {"kind":"burst","direction":Vector2.RIGHT}

static func window(x: float) -> Dictionary:
	return {"kind":"jet_window","jet_x":x,"travel_seconds":1.8}

static func courtyard(name: String,variant: int,rest: bool,cue: String) -> Dictionary:
	var beats: Array = []
	var primary: Array = []
	var alternate: Array = []
	var finish := 420.0
	match variant:
		0: # A thick hedge separates a wind route and an ordinary low route.
			beats = [terrain(540,350,1040,150),chain([Vector2(460,250),Vector2(880,250),Vector2(1300,250)],[],Vector2(1760,250)),dew(980,600,"篱下路线自己的补给","branch"),deco(1480,620,"sign")]
			primary = [Vector2(290,250),launch(),Vector2(1790,250),Vector2(1960,420)]
			alternate = [Vector2(380,600),Vector2(980,600),Vector2(1720,600),Vector2(1960,420)]
		1: # S-shaped flight, visible openings rather than blind jumps.
			beats = [gap(480,280,310),dew(850,400,"两个窗洞之间的补给"),gap(1190,540,310),gap(1770,350,330)]
			primary = [Vector2(340,280),Vector2(660,280),Vector2(850,400),Vector2(1050,540),Vector2(1370,540),Vector2(1630,350),Vector2(1950,350)]
			finish = 350
		2: # Jet route and dry bypass remain independently supplied.
			beats = [terrain(650,450,740,100),jet(790,110,230,340,6.8,2.1),dew(1510,420,"观察喷口后补给"),dew(1020,640,"篱下绕行补给","branch")]
			primary = [Vector2(670,420),window(790),Vector2(1170,420),Vector2(1510,420),Vector2(1960,420)]
			alternate = [Vector2(470,640),Vector2(1020,640),Vector2(1510,640),Vector2(1690,420),Vector2(1960,420)]
		3: # The upper wind ends before an overhang: brake, descend, then exit.
			beats = [chain([Vector2(470,280),Vector2(890,280)],[],Vector2(1350,280)),terrain(1510,80,250,350),dew(1820,560,"转到遮檐下再补给"),deco(1620,220,"lamp")]
			primary = [Vector2(300,280),launch(),Vector2(1350,280),Vector2(1360,560),Vector2(1820,560),Vector2(2040,420)]
			alternate = [Vector2(350,570),Vector2(1100,570),Vector2(1820,560),Vector2(2040,420)]
		4: # Reverse height relationship: wind below, ordinary flight above.
			beats = [terrain(560,300,1010,140),chain([Vector2(470,550),Vector2(890,550),Vector2(1310,550)],[],Vector2(1770,550)),dew(1080,190,"上沿路线自己的补给","branch")]
			primary = [Vector2(300,550),launch(),Vector2(1800,550),Vector2(2020,420)]
			alternate = [Vector2(390,190),Vector2(1080,190),Vector2(1730,190),Vector2(2020,420)]
		5: # Calm the flower or take an actual, separated lower path.
			beats = [terrain(550,410,680,160),flower(760,300),dew(1420,420,"安抚后或绕行后汇合的补给"),deco(1750,610,"sign")]
			primary = [Vector2(590,300),launch(),Vector2(1340,300),Vector2(1420,420),Vector2(2000,420)]
			alternate = [Vector2(380,650),Vector2(1360,650),Vector2(1420,420),Vector2(2000,420)]
		6: # A safe, low-pressure garden with a low-high-low route.
			beats = [terrain(620,80,320,330),terrain(1380,500,360,230),dew(1070,490,"无追赶庭院里的补给"),deco(770,520,"sign"),deco(1510,350,"lamp")]
			primary = [Vector2(460,540),Vector2(1070,490),Vector2(1210,350),Vector2(1880,350),Vector2(2040,420)]
		7: # Jet is now below the hedge. The higher path avoids its timing.
			beats = [terrain(610,290,780,95),jet(810,385,220,325,7.0,2.0,1.4),dew(1530,540,"穿过下方喷口后补给"),dew(1040,185,"上方绕行补给","branch")]
			primary = [Vector2(670,540),window(810),Vector2(1190,540),Vector2(1530,540),Vector2(2040,420)]
			alternate = [Vector2(440,185),Vector2(1040,185),Vector2(1550,185),Vector2(1810,420),Vector2(2040,420)]
		8: # A release in pressure: a broad window and an optional relay.
			beats = [gap(440,420,430),dew(780,420,"宽窗后的补给"),chain([Vector2(1120,420),Vector2(1540,420)],[],Vector2(2000,420))]
			primary = [Vector2(300,420),Vector2(780,420),Vector2(950,420),launch(),Vector2(2020,420)]
			alternate = [Vector2(300,420),Vector2(780,420),Vector2(1060,600),Vector2(1800,600),Vector2(2020,420)]
		9: # The player chooses a landing, then turns down through a wide window.
			beats = [chain([Vector2(480,250),Vector2(900,250)],[],Vector2(1360,250)),gap(1760,540,350),dew(1440,470,"结束借风后，转向下窗前补给")]
			primary = [Vector2(310,250),launch(),Vector2(1360,250),Vector2(1440,470),Vector2(1620,540),Vector2(1950,540)]
			alternate = [Vector2(370,580),Vector2(1250,580),Vector2(1440,470),Vector2(1620,540),Vector2(1950,540)]
			finish = 540
		10: # Both obstacles are quiet geometry, not another timed hazard.
			beats = [terrain(550,480,370,250),terrain(1370,80,350,300),dew(1100,420,"从花台转向遮檐前补给"),deco(740,360,"lamp")]
			primary = [Vector2(380,340),Vector2(1080,340),Vector2(1100,420),Vector2(1220,540),Vector2(1870,540),Vector2(2050,420)]
		11: # A flower followed by a low, safe landing rather than another attack.
			beats = [flower(610,290),terrain(1020,80,370,310),dew(1580,550,"安抚后到低处落脚补给"),gap(1900,500,400)]
			primary = [Vector2(440,290),launch(),Vector2(850,290),Vector2(870,550),Vector2(1580,550),Vector2(1760,500),Vector2(2080,500)]
			alternate = [Vector2(390,580),Vector2(1580,550),Vector2(1760,500),Vector2(2080,500)]
			finish = 500
	beats.append(deco(2130,630,"sign"))
	var spec := encounter(name,2380,beats,finish if rest else -1.0,cue)
	return route(spec,primary,alternate)

static func chapter(title: String,entry: String,arrival: String,npc: String,line: String,groups: Array) -> Dictionary:
	var encounters: Array = []
	var stops := [{"index":0,"line":line}]
	for group in groups:
		for j in group[1].size():
			var cell: Array = group[1][j]
			encounters.append(courtyard(group[0]+" · "+cell[0],cell[1],j%2==1,cell[2]))
		stops.append({"index":encounters.size()/2-1,"line": "画眉：这条路，我也记住了。" if npc == "bird" else "小满：换一面看，同一座庭院也不一样。"})
	return {"neighbor_stops":stops,"title":title,"region":1,"theme":1,"music":1,"base_bees":9,"storm":false,"exit_kind":"arch","entry":entry,"arrival":arrival,"npc":npc,"npc_line":line,"encounters":encounters}

static func definitions() -> Array:
	return [
		chapter("花篱另一边","从篱口看清两面。每两段都有叶亭；Esc 随时保存当前位置。","花篱已经在身后。画眉停在另一边的花园，等你一起过去。","bee","小满：路可以自己选，我在叶下等你。",[
			["一·篱口",[["看见上方的风",0,"上方借风，篱下也有补给；选一边就好"],["第一扇宽窗",8,"宽窗后是第一片叶下，触到就记住，不必停满"],["看清两扇窗",1,"先抬高，再转向低窗；这里没有追赶"],["遮檐后的庭院",6,"从遮檐下出来，再绕过花台"],["下方也有风",4,"这次风在篱下，上沿有自己的露珠"],["窗后落脚",10,"绕过花台与遮檐，前方同一片叶下"]]],
			["二·自己选路",[["长篱两侧",0,"花篱把路线分开，前方会合"],["风停了再转身",9,"接力结束先停稳，出口在下方宽窗"],["喷口前看一眼",2,"上路观察停喷空档，篱下可以直接绕行"],["回到宽窗",8,"穿过宽窗，借风或平飞到叶下"],["高处没有喷口",7,"喷口换到了下面，上沿仍能直接通行"],["选好风的落点",3,"风后是遮檐，停稳转到下面再向前"]]],
			["三·窗后庭院",[["从另一面看花台",10,"花台、窗洞和遮檐换了次序，按自己的节奏转向"],["安静的小径",6,"没有追赶，沿路牌上方的空隙过去"],["低处看见高窗",1,"从低窗转到高窗，露珠在转向之间"],["花篱背面的路",4,"沿篱下借风，也可以看上沿的景色"],["庭院里的一声喷嚏",5,"安抚花朵或从篱下绕过，两路在露珠旁汇合"],["回应后的歇脚处",8,"花朵安静了；前方宽叶可以停，也可以继续"]]],
			["四·重新选落点",[["先观察再出发",2,"先看喷口，再决定从上面穿过还是绕篱下"],["风后还有一扇窗",9,"借风后转到低窗，别一直向前冲"],["喷口换了高度",7,"上方路线绕过喷口；下方留意小泡预告"],["遮檐挡住直线",3,"高风结束后下降，遮檐下才是出口"],["花台之间换方向",10,"上绕花台，再从遮檐下穿过去"],["重见两面的花篱",0,"最后再选一次：篱顶连续借风，篱下普通飞行"]]],
			["五·顺畅离开",[["宽窗后的微风",8,"熟悉的宽窗和风花，顺着自己的节奏离开"],["花篱下的长风",4,"这段没有喷口，接住风或从上沿走"],["最后一次换高度",1,"两次宽转弯，先看落点再飞"],["背风的小院",6,"把喷口留在身后，前方可以从容停稳"],["窗前再借一阵",8,"宽窗后再借一次风，叶下就在前面"],["小满等候的叶下",10,"沿花台与遮檐之间的空隙，飞进通往下一座庭院的门"]]]
		]),
		chapter("喷嚏前后","先在安静的庭院里转个弯，再去看花朵。","两座庭院走完了。画眉记住了你的新路线。","bird","画眉：安抚它，或者绕过去，都能到。",[
			["一·放慢一点",[["先到背风处",6,"上一关已经很长，这里没有喷口，先慢慢转向"],["窗里看花园",8,"宽窗后可以借风，也可以平飞"],["花台两侧",10,"沿花台上方，转到遮檐下面"],["篱外的安静路",0,"在两条宽路里选一条，前方叶下会合"]]],
			["二·喷嚏前后",[["花朵先吸一口气",5,"花朵鼓起来会喷嚏；冲刺安抚，或者绕下方"],["安静之后往低处",11,"安抚后立刻选低处的落点；下方也能直接绕行"],["花篱之间的喘息",6,"这里没有花朵喷射，慢慢补好体力"],["这次由你决定",5,"再决定一次安抚或绕行，别把两条路都当必做"],["安抚后的新出口",11,"花朵后有遮檐，从它下面继续"],["转过宽窗",8,"离开喷嚏区，前方一段安静的路"]]],
			["三·只有空间",[["从花台上面",10,"先上绕花台，再下穿遮檐"],["两扇窗之间",1,"这一段只需要观察窗洞的高度"],["篱下的风",4,"风在下面，上面仍有普通飞行的通路"],["先停稳，再下降",3,"接力的尽头不是出口，停稳后下降"],["安静的小庭院",6,"这里没有计时压力，转好方向再出发"],["下窗回到叶亭",9,"借风后穿下方宽窗，叶亭就在窗后"]]],
			["四·水园空档",[["第一处喷口",2,"观察小泡与停喷；篱下也有补给"],["不急着接下一段",10,"喷口后先从安静的花台间转向"],["水在下面",7,"喷口换到下面，上方通路没有喷水"],["水声后的宽窗",8,"穿过宽窗补给，不必停着等下一阵喷口"],["最后一次选空档",2,"穿停喷的上路，或绕到篱下"],["选定落点离开",9,"借风结束后转到低窗，水园已经在身后"]]],
			["五·一起离开",[["安静的小径旁",6,"没有新的危险了，沿路牌上方经过"],["花篱下再借风",4,"想借风就再借一次，上沿也可以慢慢飞"],["宽窗与远处的门",8,"前方宽窗后就是最后一片叶下"],["画眉记住的新路",10,"穿过花台与遮檐，亲手飞进庭院出口"]]]
		])
	]
