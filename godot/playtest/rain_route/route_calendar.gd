extends RefCounted

# Fifteen authored days, keyed to the existing Rain Water matrix. No delivery counter controls the calendar.
const DAYS := [
	{"mode": "scout", "hint": "沿叶下小径，看清两处落脚点，再回巢。", "points": [Vector2(650, 1400), Vector2(970, 1490)]},
	{"mode": "leaf_delivery", "hint": "去花田取一份粉，经过两片叶下，再带回巢。", "quota": 1},
	{"mode": "build", "hint": "到巢门右侧的叶架，按空格带叶，再到中路或上路支点撑叶。"},
	{"mode": "pollinate", "hint": "到花田取粉，给地图上的两处花送粉，再回巢。", "points": [Vector2(3020, 960), Vector2(2780, 1150)]},
	{"mode": "drips", "hint": "取一份花粉带回巢。缺口等停水走近路，或从下方叶下绕行。", "quota": 1, "points": [Vector2(1130, 1490), Vector2(1450, 1510)]},
	{"mode": "scout", "hint": "沿上方小路辨认三处地标，连起一条支路。", "points": [Vector2(900, 540), Vector2(1400, 420), Vector2(1840, 540)]},
	{"mode": "gutter", "hint": "把堵在叶沟里的三枚种壳搬到下方干地。", "points": [Vector2(2470, 1060), Vector2(2520, 1100), Vector2(2420, 1120)], "target": Vector2(2590, 1230)},
	{"mode": "rack", "hint": "取两份粉，带到建好的叶台，慢下来交到晾架。", "quota": 2},
	{"mode": "beetle", "hint": "去小甲虫身边接起叶篷，慢慢带它走到右边的叶下。", "start": Vector2(1100, 1480), "target": Vector2(1510, 1500)},
	{"mode": "moving", "hint": "带一份粉，在移动叶影下稳住一会儿，再交到叶台。", "quota": 1},
	{"mode": "delivery", "hint": "送回三份花粉。一趟带满，或分几趟轻装，自由选择。", "quota": 3},
	{"mode": "rescue", "hint": "沿叶下路接回五只等候的新蜂，一起回巢。"},
	{"mode": "mastery", "hint": "带一份粉走走过的路，试着不掉粉回巢。失误也能收工。", "quota": 1},
	{"mode": "wind", "hint": "今天风向变了，借叶台等齐伙伴，把一份粉带回巢。", "quota": 1},
	{"mode": "final", "hint": "带回最后两份花粉，大家一起走完十五天接好的路。", "quota": 2}
]

const AFTER := [
	"两个落脚点记住了，明天带花粉时用得上。",
	"第一份花粉平安到家，叶下路走通了。",
	"叶台撑起来了，以后每天都能来避雨。",
	"花上留下了花粉，过几天再来看变化。",
	"花粉送到了。等水停或绕叶下，两条路都能回家。",
	"上方支路记进了地图，后面可以换一条飞法。",
	"三枚种壳搬开了，叶沟下多了一片干地。",
	"花粉交到了晾架，明天还看得到。",
	"小甲虫到家了，会留在那片叶下歇脚。",
	"跟着移动叶影带回了花粉，晾架又多了一份。",
	"三份花粉交齐了，轻装重载都能完成工作。",
	"五只伙伴都回家了，以后可以一起出门。",
	"花粉和伙伴都回来了，不掉粉是额外的练习。",
	"换风后的路也走通了，大家没有落在外面。",
	"十五天的花路、叶台和伙伴，都留在这里。"
]
