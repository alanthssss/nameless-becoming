extends "res://event_data.gd"
## Authored Alpha routes for 05–16. Shared leaves close both branches.
## NPCs are witnesses, never escort targets or extra rescued-bee counts.

static func _passing_flower(x: float,y: float,bypass_y: float) -> Dictionary:
	var result := flower(x,y)
	result["bypass_y"] = bypass_y
	return result

static func _short_curtain(x: float,y: float,height: float,bypass_y: float) -> Dictionary:
	var result := curtain(x,y)
	result["height"] = height
	result["bypass_y"] = bypass_y
	return result

static func definitions() -> Array:
	var last_curtain := curtain(1910,430)
	last_curtain["height"] = 240.0
	last_curtain["passive"] = true
	return [
		{"title":"花篱另一边","region":1,"theme":1,"music":1,"base_bees":9,"storm":false,"exit_kind":"arch",
		"entry":"夏天，小满先看见了花篱外的风。","arrival":"两条风路，落在同一片叶下。","npc":"bee","npc_line":"小满：你从那边来的呀！","decision":"先看风花的落点，再选入口。","encounters":[
			encounter("先看会落在哪里",1780,[fork([Vector2(470,290),Vector2(890,330)],Vector2(1350,330),[Vector2(470,550),Vector2(890,510)],Vector2(1350,510),Vector2(1520,420))],420,"高低两条风路都通向宽叶，先看落点"),
			encounter("停稳后换个高度",1650,[gap(460,300,320),dew(820,400,"从高低风路汇合后，为重新转向和起冲补给"),gap(1120,510,320)],-1,"风停后用普通飞行转向，不必急着再次冲刺"),
			encounter("这次从另一边看",1870,[fork([Vector2(500,280),Vector2(920,380)],Vector2(1380,380),[Vector2(500,550),Vector2(920,520)],Vector2(1380,520),Vector2(1560,420))],420,"两条路的末端高度不同，选好再蓄力"),
			encounter("花篱外的第一处落脚",1800,[gap(430,420,360),wind(1080,420),deco(1450,260,"lamp")],420,"绕过花茎，借一阵风到前方宽叶")
		]},
		{"title":"喷嚏前后","region":1,"theme":1,"music":1,"base_bees":9,"storm":false,"exit_kind":"arch",
		"entry":"画眉停在花篱外，花朵却先打了个喷嚏。","arrival":"喷嚏过去，果园就在前面。","npc":"bird","npc_line":"画眉：绕过来也行，别着急。","decision":"等喷嚏空档，或冲刺安抚再过去。","encounters":[
			encounter("一朵花的呼吸",1380,[_passing_flower(620,360,560),turn(1120,420)],-1,"看花的预警；可以冲刺安抚，也可以从下方绕过"),
			encounter("前后两声喷嚏",1900,[_passing_flower(500,300,560),dew(960,420,"连续处理喷嚏花后，为下一次起冲留足体力"),_passing_flower(1350,440,230)],420,"两朵花分开判断，别把第一次的节奏照搬过去"),
			encounter("安静后的一阵风",1720,[chain([Vector2(500,430),Vector2(920,430)],[],Vector2(1380,430),[Vector2(330,570),Vector2(930,570),Vector2(1450,430)])],430,"前方可借风收尾，也可沿下方正常飞到叶下")
		]},
		{"title":"不借这一阵风","region":1,"theme":0,"music":1,"base_bees":9,"storm":false,"exit_kind":"arch",
		"entry":"小满朝高处飞去，下方的近路也敞着。","arrival":"走法不同，谁也没有走错。","npc":"bee","npc_line":"小满：原来不借风，也能这样到。","decision":"比较风路的落点与绕行，不是每朵都要借。","encounters":[
			encounter("高风与低路",1720,[chain([Vector2(500,280),Vector2(920,280)],[],Vector2(1380,280),[Vector2(330,530),Vector2(940,530),Vector2(1450,420)])],420,"上方快一些，下方少转弯；两路在宽叶汇合"),
			encounter("合流后才转向",1650,[gap(450,520,320),turn(920,420),gap(1240,360,320)],-1,"先通过下方缺口，再重新对准上方出口"),
			encounter("把最后一阵风留给自己",1800,[chain([Vector2(470,500),Vector2(890,400)],[],Vector2(1350,400),[Vector2(300,280),Vector2(890,280),Vector2(1420,420)]),turn(1510,420)],420,"这一阵风也可以不借，按自己的节奏到叶下")
		]},
		{"title":"花桥的骤雨","region":1,"theme":2,"music":2,"base_bees":9,"storm":true,"exit_kind":"arch",
		"entry":"夏雨追来，小满第一次在前面的叶下等你。","arrival":"等一等，也是一种一起出发。","npc":"bee","npc_line":"小满：我在宽叶下等，慢慢看好再来。","decision":"入口先选走法，把穿雨拆成自己能接住的两段。","encounters":[
			encounter("第一片雨之前",1870,[shield(400,420),weather(700,680),chain([Vector2(650,300),Vector2(1070,300)],[],Vector2(1530,300),[Vector2(450,540),Vector2(1060,540),Vector2(1590,420)])],420,"先接护雨，再选高处借风或下方穿行；前方共用宽叶",95),
			encounter("雨缝中的转向",1500,[gap(500,450,330),dew(900,460,"转向后为第二段穿雨补给，不必回头找叶亭"),turn(1220,420)],-1,"这里不再新增落雨，转稳后准备下一段",100),
			encounter("接住下一片宽叶",1940,[shield(380,420),weather(650,650),chain([Vector2(720,440),Vector2(1140,440)],[],Vector2(1600,440),[Vector2(550,570),Vector2(1120,570),Vector2(1660,440)])],440,"两条路线都回到同一叶下，护雨不会替你停住时间",110),
			encounter("雨后的花桥",1220,[gap(450,420,380),turn(900,420)],420,"穿过宽缺口，已经能看见大家等候的地方",65)
		]},
		{"title":"旧路的断点","region":2,"theme":0,"music":0,"base_bees":9,"storm":false,"exit_kind":"arch",
		"entry":"秋天到了。画眉记得的第三朵花，已经枯了。","arrival":"旧路停在这里，新路从旁边继续。","npc":"bird","npc_line":"画眉：我记住了，下次从这边指路。","decision":"看清接力在哪里结束，在落点重新选路。","encounters":[
			encounter("只有两朵仍在借风",1700,[chain([Vector2(500,380),Vector2(920,380)],[],Vector2(1380,380)),deco(1340,260,"withered")],380,"只有带箭头的花会借风；枯花旁先落稳"),
			encounter("绕过旧枝的另一侧",1450,[deco(440,250,"withered"),gap(650,500,320),turn(1150,440)],-1,"旧花不再接力，用普通飞行从下方绕过树干"),
			encounter("新出口不在高处",1750,[chain([Vector2(500,500),Vector2(920,390)],[],Vector2(1380,390),[Vector2(330,570),Vector2(920,570),Vector2(1450,420)])],420,"重新看箭头，新出口在前方宽叶")
		]},
		{"title":"果箱之间","region":2,"theme":0,"music":1,"base_bees":9,"storm":false,"exit_kind":"arch",
		"entry":"果箱换了位置，熟练也要重新对准。","arrival":"飞得准，也要留得下减速的地方。","npc":"bee","npc_line":"小满：这里够宽，停稳了再走。","decision":"先对齐入口，让斜向接力后的落点保持宽敞。","encounters":[
			encounter("先高后低的箱缝",1500,[deco(480,690,"crate"),gap(480,300,300),gap(1080,500,320)],500,"两个缺口高度不同，普通转向后再决定起冲"),
			encounter("斜着穿过中间",1750,[chain([Vector2(520,500),Vector2(940,360)],[Vector3(750,425,320)],Vector2(1400,360)),deco(750,690,"crate")],360,"先水平冲进风花，它会沿箭头带你斜着穿过"),
			encounter("留出重新对准的空处",1560,[gap(480,520,300),dew(850,460,"连续穿过箱缝后，为下一组风花起冲补给"),gap(1200,350,310)],-1,"穿缝后先换高度，露珠在下一次起冲之前"),
			encounter("从宽出口离开",1760,[chain([Vector2(520,340),Vector2(940,440)],[],Vector2(1400,440))],440,"这次向下接力，末端有足够空间停稳")
		]},
		{"title":"留一点力气","region":2,"theme":0,"music":0,"base_bees":9,"storm":false,"exit_kind":"arch",
		"entry":"画眉指着最近的路，这次你先看看剩下的体力。","arrival":"路短一点，未必总是更省力。","npc":"bird","npc_line":"画眉：原来还可以把力气留给后面。","decision":"冲开短帘省路，或绕过去为下一次起冲留力。","encounters":[
			encounter("帘子没有挡住整条路",1500,[_short_curtain(650,330,260,570),turn(1120,420),dew(1250,420,"越过叶帘或绕行后，为前方接力保留起冲体力")],-1,"上方叶帘可冲开，下方也能绕过；两路都要继续向前"),
			encounter("把体力用在下一次起冲",2150,[gap(450,420,340),chain([Vector2(950,420),Vector2(1370,420)],[],Vector2(1830,420))],420,"通过宽缺口后再起冲，接力末端才是叶亭"),
			encounter("这次也可以从上面走",2260,[_short_curtain(640,450,250,230),turn(1080,420),wind(1480,420)],420,"叶帘上方有绕行空间，随后用同一阵风收尾")
		]},
		{"title":"秋雨中的新路","region":2,"theme":2,"music":2,"base_bees":9,"storm":true,"exit_kind":"arch",
		"entry":"旧花不再相连。画眉把目光移向新的落点。","arrival":"没有从头不断的风，也能穿过这一场雨。","npc":"bird","npc_line":"画眉：新的路，我也看见了。","decision":"让短接力结束，再为下一段重新判断。","encounters":[
			encounter("先接短短的两阵风",1700,[chain([Vector2(500,500),Vector2(920,400)],[],Vector2(1380,400))],400,"这组风只送到前方叶下，别急着寻找第三朵",95),
			encounter("抬头再重新出发",1450,[gap(500,300,320),dew(870,380,"离开第一处落点并转向后，为雨中的短接力补给"),turn(1150,440)],-1,"短接力已经结束，转过缺口后再看下一组箭头",95),
			encounter("雨区里的第二次选择",1940,[weather(650,500),chain([Vector2(720,440),Vector2(1140,480)],[],Vector2(1600,480),[Vector2(540,280),Vector2(1160,280),Vector2(1660,480)])],480,"起冲穿雨或从上方正常穿行，都要看清共同落点",110),
			encounter("沿新枝飞到果园外",1720,[chain([Vector2(500,440),Vector2(920,350)],[],Vector2(1380,350)),deco(1430,250,"withered")],420,"最后一组短风，新的落脚点就在枯枝旁",80)
		]},
		{"title":"霜窗里的暖廊","region":3,"theme":3,"music":0,"base_bees":9,"storm":false,"exit_kind":"arch",
		"entry":"霜留在窗外，暖廊里还能慢慢飞。","arrival":"风少了，自己的方向反而更清楚。","npc":"bee","npc_line":"小满：这次先看你想从哪边走。","decision":"只借有用的风，宽弯道也可以正常飞过。","encounters":[
			encounter("暖廊里的宽弯",1450,[gap(460,330,380),gap(1050,510,360),deco(860,180,"lamp")],510,"窗外是霜，通行范围仍在清楚的宽缺口里"),
			encounter("留着不借的一阵风",1740,[chain([Vector2(520,310),Vector2(940,310)],[],Vector2(1400,310),[Vector2(350,570),Vector2(950,570),Vector2(1470,500)])],-1,"上方风花更快，下方宽弯可以自己飞过去"),
			encounter("窗边的一小片雨",1490,[turn(350,460),dew(480,460,"从宽弯飞来后，在短雨带之前恢复一点体力"),weather(620,320),turn(1130,460),deco(1220,200,"lamp")],460,"看清窗边雨带，穿过后就是暖叶下")
		]},
		{"title":"灯下再飞一次","region":3,"theme":3,"music":1,"base_bees":9,"storm":false,"exit_kind":"arch",
		"entry":"出口已经看得见。小满说，要不要再飞一次？","arrival":"愿意多飞一圈，也可以直接向前。","npc":"bee","npc_line":"小满：哪条都好，我在前面等你。","decision":"安全出口始终可达，连冲只是自愿挑战。","encounters":[
			encounter("可选的上层弧线",2160,[chain([Vector2(500,280),Vector2(920,280),Vector2(1340,420)],[],Vector2(1800,420),[Vector2(330,540),Vector2(1040,540),Vector2(1860,420)]),deco(1650,180,"lamp")],420,"上层可以连冲，下方直接通向同一片宽叶"),
			encounter("两条路都亮着灯",1350,[gap(450,420,400),turn(1050,420),deco(780,200,"lamp")],-1,"不计连冲分数，正常飞过宽缺口也能继续"),
			encounter("最后一条自选弧线",1750,[chain([Vector2(480,450),Vector2(900,350)],[],Vector2(1360,350),[Vector2(310,560),Vector2(930,560),Vector2(1430,420)]),deco(1500,190,"lamp")],420,"想借风就对准入口，想慢一点就走下方")
		]},
		{"title":"最后一阵风","region":3,"theme":2,"music":2,"base_bees":9,"storm":true,"exit_kind":"arch",
		"entry":"最后一次穿雨。你已经知道怎样看路了。","arrival":"穿过来了，接下来可以从容一点。","npc":"bird","npc_line":"画眉：前面是背风的树廊，慢慢来。","decision":"在天气压力下选择自己能稳定完成的组合。","encounters":[
			encounter("先选能接住的落点",1800,[fork([Vector2(470,300),Vector2(890,400)],Vector2(1350,400),[Vector2(470,560),Vector2(890,500)],Vector2(1350,500),Vector2(1530,430))],430,"两条短接力先汇合，再准备最后的雨带",105),
			encounter("护雨之内接三阵风",2350,[shield(350,430),weather(620,780),chain([Vector2(720,430),Vector2(1140,430),Vector2(1560,430)],[],Vector2(2020,430),[Vector2(550,600),Vector2(1160,600),Vector2(1740,600),Vector2(2020,600),Vector2(2080,430)]),last_curtain],430,"高处冲刺穿过短叶帘，下方能绕行；末端同一片宽叶",140,true),
			encounter("雨后还要重新对准",1400,[turn(320,440),dew(650,440,"最后雨带之后，为末次起冲留足体力"),gap(1020,340,320)],-1,"露珠在最后起冲之前，先转过上方缺口",95),
			encounter("把天气留在身后",1760,[chain([Vector2(500,340),Vector2(920,440)],[],Vector2(1380,440))],440,"用已经学过的短接力到达背风树廊",80)
		]},
		{"title":"老树下见","region":3,"theme":3,"music":0,"base_bees":9,"storm":false,"exit_kind":"home",
		"entry":"大家各自到了。最后这段路，按你的节奏飞。","arrival":"你回来啦。这里一直有你的位置。","npc":"bee","npc_line":"小满：画眉在新枝头，我们都在。","decision":"亲手飞到老树，轻松借风或慢慢靠近。","encounters":[
			encounter("熟悉的灯与宽缺口",1110,[deco(320,240,"lamp"),gap(600,420,400),turn(850,420)],420,"没有新的考验了，沿灯光飞过宽缺口"),
			encounter("想借风就再借一次",1730,[chain([Vector2(480,440),Vector2(900,440)],[],Vector2(1360,440),[Vector2(310,560),Vector2(930,560),Vector2(1430,440)]),deco(1510,210,"lamp")],440,"借风或正常飞都可以，大家在老树下等你")
		]}
	]
