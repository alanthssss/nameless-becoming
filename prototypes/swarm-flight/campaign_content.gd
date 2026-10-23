extends "res://event_data.gd"
## Authored seasonal routes. Terrain, jets and air currents exist in the model;
## the two input routes below only exercise them and never create a path.
## Every branch rejoins before its shared checkpoint. NPCs never escort the bee.

static func _short_curtain(x: float,y: float,height: float,bypass_y: float) -> Dictionary:
	var result := curtain(x,y)
	result["height"] = height
	result["bypass_y"] = bypass_y
	return result

static func _routed(spec: Dictionary,direct: Array,alternate: Array = []) -> Dictionary:
	spec["direct_route"] = direct
	spec["alternate_route"] = alternate if not alternate.is_empty() else direct.duplicate(true)
	return spec

static func _burst() -> Dictionary:
	return {"kind":"burst","direction":Vector2.RIGHT}

static func _window(x: float,seconds: float) -> Dictionary:
	return {"kind":"jet_window","jet_x":x,"travel_seconds":seconds}

static func definitions() -> Array:
	var last_curtain := curtain(1910,250)
	last_curtain["height"] = 240.0
	last_curtain["passive"] = true
	return [
		{"title":"花篱另一边","region":1,"theme":1,"music":1,"base_bees":9,"storm":false,"exit_kind":"arch",
		"entry":"花篱上方能借风，下方有晨露，最后在叶下会合。","arrival":"从花篱的两侧，回到同一片叶下。","npc":"bee","npc_line":"小满：你从那一侧来的呀！","decision":"先选花篱的一侧，别把两条路当成两排必吃的风花。","encounters":[
			_routed(encounter("花篱真正分成两路",1320,[terrain(500,335,360,150,"hedge"),chain([Vector2(420,230),Vector2(720,230)],[],Vector2(1000,230)),dew(650,580,"沿花篱下路继续飞行时补给，合流后再选择下一次起冲","branch")],420,"花篱上方借风；下方绕行取露，两路前方合流"),
				[Vector2(250,230),_burst(),Vector2(1140,420)],
				[Vector2(360,580),Vector2(650,580),Vector2(990,580),Vector2(1140,420)]),
			encounter("停稳后换个高度",1650,[gap(460,300,320),dew(820,400,"从分路汇合后，为重新转向和起冲补给"),gap(1120,510,320)],-1,"风停后用普通飞行转向，不必急着再次冲刺"),
			_routed(encounter("喷口上方与篱下",1870,[terrain(620,450,510,100,"hedge"),jet(700,100,220,350)],420,"喷口冒小泡后会喷水；等停喷穿上路，或从篱下绕过"),
				[Vector2(580,420),_window(700,1.8),Vector2(1010,420),Vector2(1300,420),Vector2(1450,420)],
				[Vector2(450,640),Vector2(1220,640),Vector2(1450,420)]),
			_routed(encounter("花篱外，歇歇脚",1380,[terrain(500,650,560,80,"hedge"),wind(400,250)],420,"前方宽叶已经敞开，借风或平飞过去歇歇脚"),
				[Vector2(230,250),_burst(),Vector2(1000,250),Vector2(1100,420)],
				[Vector2(650,420),Vector2(1100,420)])
		]},
		{"title":"喷嚏前后","region":1,"theme":1,"music":1,"base_bees":9,"storm":false,"exit_kind":"arch",
		"entry":"画眉停在花篱外，花朵却先打了个喷嚏。","arrival":"喷嚏和喷泉留在后面，果园就在前面。","npc":"bird","npc_line":"画眉：从下面绕来也行。","decision":"在花篱两侧选择安抚喷嚏或避开它，再观察喷泉的空档。","encounters":[
			_routed(encounter("花篱顶的一声喷嚏",1480,[terrain(480,410,440,150,"hedge"),flower(620,300)],-1,"上方冲刺安抚花朵；下方沿花篱外侧绕行"),
				[Vector2(450,300),_burst(),Vector2(1080,300),Vector2(1250,420)],
				[Vector2(350,640),Vector2(1040,640),Vector2(1250,420)]),
			_routed(encounter("喷口的另一侧",1820,[terrain(620,450,520,100,"hedge"),jet(760,100,210,350,6.2,2.2,1.1),dew(1280,420,"越过喷嚏与喷口后，为末段借风补给")],420,"看清上方喷口的停喷空档；篱下整条路不经过喷口"),
				[Vector2(650,420),_window(760,1.7),Vector2(1060,420),Vector2(1220,420),Vector2(1280,420)],
				[Vector2(460,640),Vector2(1220,640),Vector2(1280,420)]),
			_routed(encounter("安静后的一阵风",1720,[terrain(590,380,510,130,"hedge"),chain([Vector2(500,260),Vector2(920,260)],[],Vector2(1380,260))],430,"可从篱顶借风收尾，也可绕过篱下回到同一片叶下"),
				[Vector2(330,260),_burst(),Vector2(1420,260),Vector2(1480,430)],
				[Vector2(400,610),Vector2(1210,610),Vector2(1480,430)])
		]},
		{"title":"不借这一阵风","region":1,"theme":0,"music":1,"base_bees":9,"storm":false,"exit_kind":"arch",
		"entry":"小满朝高处飞去，下方花篱外的路也敞着。","arrival":"走法不同，谁也没有走错。","npc":"bee","npc_line":"小满：原来不借风，也能这样到。","decision":"花篱把两种走法分开，选好落点再起冲。","encounters":[
			_routed(encounter("高风与篱下通路",1720,[terrain(580,335,560,150,"hedge"),chain([Vector2(500,240),Vector2(920,240)],[],Vector2(1380,240))],420,"上方连续借风；下方绕过实体花篱，不必起冲"),
				[Vector2(330,240),_burst(),Vector2(1420,240),Vector2(1490,420)],
				[Vector2(400,580),Vector2(1240,580),Vector2(1490,420)]),
			encounter("合流后才转向",1650,[gap(450,520,320),turn(920,420),gap(1240,360,320)],-1,"先通过下方缺口，再重新对准上方出口"),
			_routed(encounter("这次喷口在下方",1800,[terrain(580,270,560,80,"hedge"),jet(740,350,220,360,6.0,2.2,0.7)],420,"下路先看停喷空档；上路可以直接绕过喷口"),
				[Vector2(630,420),_window(740,1.7),Vector2(1060,420),Vector2(1250,420),Vector2(1430,420)],
				[Vector2(400,190),Vector2(1240,190),Vector2(1430,420)])
		]},
		{"title":"花桥的骤雨","region":1,"theme":2,"music":2,"base_bees":9,"storm":true,"exit_kind":"arch",
		"entry":"夏雨追来，花篱下方能挡住上面落下的雨。","arrival":"从暴露的花顶，或有顶的篱下，都能来到这里。","npc":"bee","npc_line":"小满：我在合流的宽叶下等你。","decision":"短风路顶雨穿过；篱下绕行利用真实遮蔽。","encounters":[
			_routed(encounter("雨中的花顶与篱下",1950,[shield(350,420),terrain(700,340,680,100,"hedge"),weather(700,680),chain([Vector2(650,240),Vector2(1070,240)],[],Vector2(1530,240))],420,"先接护雨；篱顶借风穿雨，篱下由实体花篱挡雨",95),
				[Vector2(350,420),Vector2(480,240),_burst(),Vector2(1570,240),Vector2(1630,420)],
				[Vector2(350,420),Vector2(530,560),Vector2(1460,560),Vector2(1630,420)]),
			encounter("雨缝中的转向",1500,[gap(500,450,330),dew(900,460,"转向后为第二段穿行补给，不必回头找叶亭"),turn(1220,420)],-1,"这里没有新增落雨，转稳后看下一处喷口",90),
			_routed(encounter("追雨之前再选一次",1870,[terrain(620,450,520,100,"hedge"),jet(740,100,220,350,6.0,2.2,0.8)],420,"上路可以等停喷；不想停就绕篱下，随后两路合流",90),
				[Vector2(630,420),_window(740,1.7),Vector2(1060,420),Vector2(1240,420),Vector2(1460,420)],
				[Vector2(440,640),Vector2(1250,640),Vector2(1460,420)]),
			encounter("雨后的花桥",1220,[gap(450,420,380),turn(900,420)],420,"穿过宽缺口，已经能看见大家等候的地方",65)
		]},
		{"title":"旧路的断点","region":2,"theme":0,"music":0,"base_bees":9,"storm":false,"exit_kind":"arch",
		"entry":"画眉记得的高路，被新堆起的果箱挡住了。","arrival":"旧路确实断了，新出口从箱下继续。","npc":"bird","npc_line":"画眉：我记住了，下次从箱下指路。","decision":"让接力先结束，再绕到实体阻挡的另一侧。","encounters":[
			_routed(encounter("两阵风后真的有断点",2200,[chain([Vector2(460,280),Vector2(880,280)],[],Vector2(1340,280)),terrain(1510,80,180,320,"crate"),deco(1430,240,"withered")],500,"两朵风花后先减速；果箱挡住高路，出口在箱下"),
				[Vector2(290,280),_burst(),Vector2(1350,280),Vector2(1370,540),Vector2(1810,540),Vector2(1940,500)]),
			_routed(encounter("旧枝两侧的通路",1500,[terrain(500,330,480,200,"crate"),deco(660,245,"withered")],-1,"果箱上下都能绕；看清箱子的末端再转回主路"),
				[Vector2(380,620),Vector2(1100,620),Vector2(1260,420)],
				[Vector2(380,230),Vector2(1100,230),Vector2(1260,420)]),
			_routed(encounter("沿箱下的新风路",1750,[terrain(590,80,380,290,"crate"),chain([Vector2(500,540),Vector2(920,540)],[],Vector2(1380,540))],420,"新风路从果箱下方穿过，到了末端再向上收回"),
				[Vector2(330,540),_burst(),Vector2(1420,540),Vector2(1510,420)])
		]},
		{"title":"果箱之间","region":2,"theme":0,"music":1,"base_bees":9,"storm":false,"exit_kind":"arch",
		"entry":"果箱挡住的是不同高度，先看缝在哪里。","arrival":"穿过的不是同一条缝，留出的空处让你重新对准。","npc":"bee","npc_line":"小满：先转过箱角，再起冲就好。","decision":"绕真实箱角换高度；短隧道里的叶帘可以冲开，也能绕外侧。","encounters":[
			_routed(encounter("先箱下再箱上",2080,[terrain(460,80,500,380,"crate"),terrain(1160,300,340,430,"crate")],420,"先绕第一摞箱子的下方，再在箱间向上转过第二摞"),
				[Vector2(300,580),Vector2(1010,580),Vector2(1060,200),Vector2(1570,200),Vector2(1720,420)]),
			_routed(encounter("斜着穿过箱口",1750,[terrain(650,80,300,200,"crate"),terrain(1080,520,250,210,"crate"),chain([Vector2(520,520),Vector2(940,320)],[],Vector2(1400,320))],360,"对准低处第一朵，沿箭头斜着穿过箱口"),
				[Vector2(350,520),_burst(),Vector2(1430,320)]),
			_routed(encounter("穿箱道或绕箱外",1650,[terrain(550,280,550,70,"crate"),terrain(550,510,550,70,"crate"),_short_curtain(800,430,160,650),dew(930,650,"绕箱外继续飞行的补给，末段还有一次起冲","branch")],-1,"中间叶帘用冲刺穿；也可从整摞箱子的下方绕过"),
				[Vector2(380,430),Vector2(630,430),_burst(),Vector2(1180,430),Vector2(1360,420)],
				[Vector2(390,650),Vector2(930,650),Vector2(1210,650),Vector2(1360,420)]),
			_routed(encounter("斜向离开果箱",1760,[terrain(620,550,410,180,"crate"),chain([Vector2(520,340),Vector2(940,440)],[],Vector2(1400,440))],440,"这次向下接力，箱子上方留着清楚的落点"),
				[Vector2(350,340),_burst(),Vector2(1440,440)])
		]},
		{"title":"留一点力气","region":2,"theme":0,"music":0,"base_bees":9,"storm":false,"exit_kind":"arch",
		"entry":"画眉指着最近的箱道，你还可以从外侧绕行。","arrival":"穿帘和绕箱，各花掉了不同的时间与力气。","npc":"bird","npc_line":"画眉：箱子外面，也有一条完整的路。","decision":"短道需要一次冲刺；外侧多飞一段，不必冲开叶帘。","encounters":[
			_routed(encounter("箱道里的叶帘",1500,[terrain(500,260,500,70,"crate"),terrain(500,510,500,70,"crate"),_short_curtain(650,420,180,650),dew(1250,420,"穿帘或绕箱后，为后方风花起冲补给")],-1,"中间短道花一次冲刺；下方绕完整摞箱子，再合流"),
				[Vector2(360,420),Vector2(480,420),_burst(),Vector2(1110,420),Vector2(1250,420)],
				[Vector2(350,650),Vector2(1100,650),Vector2(1250,420)]),
			encounter("把体力用在下一次起冲",2150,[gap(450,420,340),chain([Vector2(950,420),Vector2(1370,420)],[],Vector2(1830,420))],420,"通过宽缺口后再起冲，接力末端才是叶亭"),
			_routed(encounter("这次从箱顶绕",2260,[terrain(500,270,510,70,"crate"),terrain(500,520,510,70,"crate"),_short_curtain(640,430,180,190),wind(1480,420)],420,"中间仍能冲开；箱顶也有绕道，随后借同一阵风收尾"),
				[Vector2(360,430),Vector2(470,430),_burst(),Vector2(1120,430),Vector2(1310,420),_burst(),Vector2(1950,420)],
				[Vector2(350,190),Vector2(1120,190),Vector2(1310,420),_burst(),Vector2(1950,420)])
		]},
		{"title":"秋雨中的新路","region":2,"theme":2,"music":2,"base_bees":9,"storm":true,"exit_kind":"arch",
		"entry":"果箱挡住旧路，也在雨中留出新的遮蔽。","arrival":"绕过箱角、再接短风，这条路是重新找出来的。","npc":"bird","npc_line":"画眉：新的路，我也看见了。","decision":"短风结束后重新换高度；箱顶暴露，箱下能挡落雨。","encounters":[
			_routed(encounter("沿第一摞箱子借风",1700,[terrain(590,80,380,290,"crate"),chain([Vector2(500,500),Vector2(920,420)],[],Vector2(1380,420))],420,"两阵风送到箱外叶下，下一段要重新看路线",90),
				[Vector2(330,500),_burst(),Vector2(1430,420)]),
			_routed(encounter("箱角之间重新转向",1600,[terrain(560,80,260,340,"crate"),terrain(1000,500,260,230,"crate"),dew(1350,340,"绕过两摞箱子后，为雨中的短接力补给")],-1,"先绕箱下，再从箱间向上；前面的露珠是下一次起冲补给",90),
				[Vector2(350,550),Vector2(870,550),Vector2(900,340),Vector2(1350,340)]),
			_routed(encounter("雨里的箱顶与箱下",1950,[terrain(700,340,680,100,"crate"),weather(700,680),chain([Vector2(650,240),Vector2(1070,240)],[],Vector2(1530,240))],420,"箱顶借风穿过雨；箱下由实体果箱挡住落雨",105),
				[Vector2(480,240),_burst(),Vector2(1570,240),Vector2(1630,420)],
				[Vector2(530,560),Vector2(1460,560),Vector2(1630,420)]),
			encounter("沿新枝飞到果园外",1720,[chain([Vector2(500,440),Vector2(920,350)],[],Vector2(1380,350)),deco(1430,250,"withered")],420,"最后一组短风，新的落脚点就在枯枝旁",80)
		]},
		{"title":"霜窗里的暖廊","region":3,"theme":3,"music":0,"base_bees":9,"storm":false,"exit_kind":"arch",
		"entry":"暖廊的通风口向上送风，台面下方则是背风处。","arrival":"你已经能分清：哪阵风可借，哪阵风可以绕。","npc":"bee","npc_line":"小满：风有方向，台面也有背面。","decision":"风口会持续推动你，松键和蓄力也不例外；可修正方向、冲刺抵风，或绕开。","encounters":[
			_routed(encounter("借上升风越过台面",1770,[terrain(650,500,620,90,"glass"),airflow(430,300,190,290,Vector2.UP,180.0)],420,"箭头向上：进入风口就会抬升；也能从台面下方绕过"),
				[Vector2(400,560),Vector2(580,360),Vector2(1370,360),Vector2(1480,420)],
				[Vector2(350,660),Vector2(1380,660),Vector2(1480,420)]),
			_routed(encounter("逆风上路与背风下路",1710,[terrain(560,380,510,90,"glass"),airflow(520,160,360,200,Vector2.LEFT,160.0),wind(430,250),dew(940,580,"绕台面背风处继续飞行的顺路补给","branch")],-1,"上方气流向左，冲刺不受它偏转；台面下方可以避风"),
				[Vector2(260,250),_burst(),Vector2(1120,250),Vector2(1340,460)],
				[Vector2(350,580),Vector2(940,580),Vector2(1180,580),Vector2(1340,460)]),
			_routed(encounter("侧风前重新看方向",1550,[terrain(650,560,420,100,"glass"),airflow(650,310,420,180,Vector2.DOWN,140.0)],460,"中间风口向下推；向上修正，或提前绕到风口上方"),
				[Vector2(430,420),Vector2(1150,420),Vector2(1280,460)],
				[Vector2(430,220),Vector2(1150,220),Vector2(1280,460)])
		]},
		{"title":"灯下再飞一次","region":3,"theme":3,"music":1,"base_bees":9,"storm":false,"exit_kind":"arch",
		"entry":"台面两侧都能到达出口，要不要再借一次风？","arrival":"愿意多试一条风路，也可以直接向前。","npc":"bee","npc_line":"小满：哪条都好，我在前面等你。","decision":"台面下方一直可达，上方弧线是一段自选连冲。","encounters":[
			_routed(encounter("台面上的自选弧线",2160,[terrain(620,380,800,90,"glass"),chain([Vector2(500,280),Vector2(920,220),Vector2(1340,320)],[],Vector2(1800,420)),airflow(940,110,280,190,Vector2.DOWN,120.0)],420,"上层连冲越过台面；下层避开风口，直接到同一片叶下"),
				[Vector2(330,280),_burst(),Vector2(1840,420)],
				[Vector2(400,580),Vector2(1540,580),Vector2(1840,420)]),
			_routed(encounter("背风处慢慢转过",1500,[terrain(500,80,600,300,"glass")],-1,"这里没有追赶，绕过台面的下侧再重新抬高"),
				[Vector2(370,500),Vector2(1220,500),Vector2(1360,420)]),
			_routed(encounter("向上送你一小程",1770,[terrain(680,500,540,90,"glass"),airflow(480,300,170,290,Vector2.UP,160.0),wind(880,330)],420,"借上升风到台面上方，离开风口再蓄力；下方也通向叶下"),
				[Vector2(400,560),Vector2(580,360),Vector2(710,330),_burst(),Vector2(1390,330),Vector2(1480,420)],
				[Vector2(350,660),Vector2(1330,660),Vector2(1480,420)])
		]},
		{"title":"最后一阵风","region":3,"theme":2,"music":2,"base_bees":9,"storm":true,"exit_kind":"arch",
		"entry":"最后一次穿雨。喷口、箱角与风向，都已经见过了。","arrival":"穿过来了，接下来可以从容一点。","npc":"bird","npc_line":"画眉：前面是背风的树廊，慢慢来。","decision":"在熟悉元素的组合里，选自己能稳定完成的走法。","encounters":[
			_routed(encounter("先选喷口或篱下",1870,[terrain(620,450,520,100,"hedge"),jet(740,100,220,350,6.0,2.2,0.4)],430,"先看喷口空档，或直接绕篱下；前方共用宽叶",90),
				[Vector2(630,420),_window(740,1.7),Vector2(1060,420),Vector2(1240,420),Vector2(1460,430)],
				[Vector2(440,640),Vector2(1250,640),Vector2(1460,430)]),
			_routed(encounter("护雨高路与有顶低路",2420,[shield(350,430),terrain(700,340,1000,90,"crate"),weather(620,1080),chain([Vector2(720,250),Vector2(1140,250),Vector2(1560,250)],[],Vector2(2020,250)),last_curtain],430,"高处冲刺穿短帘；箱下挡雨并绕帘，末端同一片宽叶",115),
				[Vector2(350,430),Vector2(550,250),_burst(),Vector2(2060,250),Vector2(2190,430)],
				[Vector2(350,430),Vector2(550,600),Vector2(1840,600),Vector2(2070,600),Vector2(2190,430)]),
			_routed(encounter("箱角后留下最后一次起冲",1650,[terrain(600,490,420,240,"crate"),dew(1260,340,"最后一次绕箱后，为末段起冲留足体力")],-1,"先绕箱顶，为末段补给；雨幕还在身后",90),
				[Vector2(430,340),Vector2(1140,340),Vector2(1260,340)]),
			_routed(encounter("把天气留在身后",1760,[airflow(300,300,200,280,Vector2.UP,140.0),terrain(640,540,460,90,"glass"),chain([Vector2(500,300),Vector2(920,440)],[],Vector2(1380,440))],440,"借上升风离开风口后蓄力；台面下方也能绕过",80),
				[Vector2(250,560),Vector2(330,270),_burst(),Vector2(1420,440)],
				[Vector2(250,670),Vector2(1210,670),Vector2(1450,440)])
		]},
		{"title":"老树下见","region":3,"theme":3,"music":0,"base_bees":9,"storm":false,"exit_kind":"home",
		"entry":"大家各自到了。最后这段路，按你的节奏飞。","arrival":"你回来啦。这里一直有你的位置。","npc":"bee","npc_line":"小满：画眉在新枝头，我们都在。","decision":"亲手飞到老树，轻松借风或慢慢靠近。","encounters":[
			encounter("熟悉的灯与宽缺口",1110,[deco(320,240,"lamp"),gap(600,420,400),turn(850,420)],420,"没有新的考验了，沿灯光飞过宽缺口"),
			encounter("想借风就再借一次",1730,[chain([Vector2(480,440),Vector2(900,440)],[],Vector2(1360,440),[Vector2(310,560),Vector2(930,560),Vector2(1430,440)]),deco(1510,210,"lamp")],440,"借风或正常飞都可以，大家在老树下等你")
		]}
	]
