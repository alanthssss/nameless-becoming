extends RefCounted
## Pure deterministic encounter rules. UI and tests use the same transition.
const W := 9
const H := 7
const DIRS := [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]

static func chapters() -> Array:
	return [
		{"name":"第一着 · 风会送你一程", "subtitle":"早春 / 花叶之间", "goal":"抵达右上方的白花。", "intro":"你醒在一片叶子上。远处那只老蜂没有问你是谁，只说：先试试翅膀。", "hint":"点击亮起的位置飞行。风在动物行动之后推动你；叶片上按空格栖停，就能稳住。", "outro":"老蜂：你看，风也不总跟我们作对。前面有人把近路占了。", "rows":[".........","..o..o..E","..#..#...","P.o..o.o.","..#..#...",".o..o..o.","........."], "wind":[Vector2i(1,0),Vector2i(1,0),Vector2i(0,0),Vector2i(-1,0)], "enemies":[]},
		{"name":"第二着 · 油葫芦的跳台", "subtitle":"早春 / 苇叶小径", "goal":"穿过苇丛，抵达白花。", "intro":"油葫芦把这片薄叶当成了练跳的地方。每次落地，整根草茎都跟着抖。", "hint":"红色十字是下一跳。它会压断褐色脆枝；也可以沿最下方的缺口绕过。", "outro":"油葫芦：咦？怎么多了一条路……算了，这边起跳更顺。", "rows":["....t....","..o.t.o.E",".o..t.o..","P.o.t..o.",".o..t.o..","..o.t.o..",".o..o..o."], "wind":[Vector2i(0,0),Vector2i(0,0),Vector2i(1,0),Vector2i(0,0)], "enemies":[{"kind":"cricket", "pos":Vector2i(3,2), "target":Vector2i(2,3), "phase":0}]},
		{"name":"第三着 · 画眉在看哪里", "subtitle":"早春 / 低枝之下", "goal":"从叶荫下穿过画眉的花枝。", "intro":"画眉的脑袋歪向一边。它看见了你，却看不见整片叶子背后的世界。", "hint":"画眉依次啄扫、抖翅、停顿。绿色叶荫能挡住啄扫，但必须先栖停。", "outro":"你从叶后探出头。画眉已经转向另一根枝条；白花后的景色第一次完整展开。", "rows":["....#....","..o.#.o.E","..o.t.o..","P.o.t.o..","..o.t.o..","..o.#.o..","....#...."], "wind":[Vector2i(0,0)], "enemies":[{"kind":"bird", "pos":Vector2i(6,0), "target":Vector2i(2,3), "phase":0}]},
		{"name":"最后一着 · 花地就在那边", "subtitle":"早春 / 花枝尽头", "goal":"让自己到达白花，找到通往新花地的路。", "intro":"风换了方向。油葫芦还在练跳，画眉守着低枝。你已经知道，该怎样从它们中间走过去。", "hint":"近路隔着脆枝；下方留着绕路。让啄扫或跳落改变通路，也可以保住叶荫借风通过。", "outro":"老蜂：你先走吧。这次，我跟着你。", "rows":["....t....",".o..t.o.E","..o.t.o..","P.o.t..o.",".o..t.o..","..o.t.o..",".o..o..o."], "wind":[Vector2i(0,0),Vector2i(0,0),Vector2i(-1,0),Vector2i(0,0)], "enemies":[{"kind":"cricket", "pos":Vector2i(3,5), "target":Vector2i(2,5), "phase":0},{"kind":"bird", "pos":Vector2i(7,0), "target":Vector2i(2,3), "phase":0}]}
	]

static func start(index: int) -> Dictionary:
	var level: Dictionary = chapters()[index]
	var board: Array = []
	var player := Vector2i.ZERO
	var goal := Vector2i.ZERO
	for y in range(H):
		var row: Array = []
		for x in range(W):
			var tile: String = level.rows[y][x]
			if tile == "P":
				player = Vector2i(x,y)
				tile = "o"
			if tile == "E": goal = Vector2i(x,y)
			row.append(tile)
		board.append(row)
	return {"chapter":index, "board":board, "player":player, "goal":goal, "landed":true, "hp":3, "turn":0, "enemies":level.enemies.duplicate(true), "won":false, "lost":false, "broken":0, "message":"先看风与红色预告，再决定这一着。", "events":[]}

static func inside(p: Vector2i) -> bool:
	return p.x >= 0 and p.x < W and p.y >= 0 and p.y < H

static func tile(s: Dictionary, p: Vector2i) -> String:
	if not inside(p): return "#"
	return s.board[p.y][p.x]

static func blocked(s: Dictionary, p: Vector2i) -> bool:
	return tile(s,p) in ["#", "t"]

static func can_perch(s: Dictionary, p: Vector2i) -> bool:
	return tile(s,p) in ["o", "E"]

static func legal_move(s: Dictionary, p: Vector2i) -> bool:
	if s.won or s.lost or not inside(p) or blocked(s,p) or p == s.player: return false
	var d: Vector2i = p - s.player
	if abs(d.x) > 2 or abs(d.y) > 2 or abs(d.x) + abs(d.y) > 3: return false
	# Supercover of the flight segment: corners cannot cross a blocking plant.
	var from: Vector2 = Vector2(s.player) + Vector2(0.5,0.5)
	var to: Vector2 = Vector2(p) + Vector2(0.5,0.5)
	for i in range(1,25):
		var q: Vector2 = from.lerp(to, float(i)/24.0)
		if blocked(s, Vector2i(floori(q.x),floori(q.y))): return false
		if is_equal_approx(q.x,round(q.x)) and blocked(s,Vector2i(int(q.x)-1,floori(q.y))): return false
		if is_equal_approx(q.y,round(q.y)) and blocked(s,Vector2i(floori(q.x),int(q.y)-1)): return false
	return true

static func wind(s: Dictionary) -> Vector2i:
	var cycle: Array = chapters()[s.chapter].wind
	var result: Vector2i = cycle[s.turn % cycle.size()]
	for enemy in s.enemies:
		if enemy.kind == "bird" and enemy.phase == 1:
			result = Vector2i(1 if int(s.turn / 3) % 2 == 0 else -1, 0)
	return result

static func footprint(enemy: Dictionary) -> Array:
	var cells: Array = []
	if enemy.kind == "bird" and enemy.phase != 0: return cells
	if enemy.kind == "cricket":
		cells.append(enemy.target)
		for d in DIRS: cells.append(enemy.target + d)
	else:
		for y in range(-1,2):
			for x in range(-1,2): cells.append(enemy.target + Vector2i(x,y))
	return cells.filter(func(p): return inside(p))

static func actions(s: Dictionary) -> Array:
	var result: Array = []
	for y in range(H):
		for x in range(W):
			var p := Vector2i(x,y)
			if legal_move(s,p): result.append({"kind":"fly", "to":p})
	if can_perch(s,s.player): result.append({"kind":"perch"})
	result.append({"kind":"wait"})
	return result

static func advance(s: Dictionary, action: Dictionary) -> Dictionary:
	if s.won or s.lost: return s.duplicate(true)
	if action.kind == "fly" and not legal_move(s, action.to): return s.duplicate(true)
	if action.kind == "perch" and not can_perch(s,s.player): return s.duplicate(true)
	if action.kind not in ["fly","perch","wait"]: return s.duplicate(true)
	var next: Dictionary = s.duplicate(true)
	next.events = []
	var gust := wind(s)
	if action.kind == "fly":
		next.player = action.to
		next.landed = false
	elif action.kind == "perch":
		next.landed = true
		next.events.append("收拢翅膀，贴住叶面。")
	# Resolve every locked attack against the same post-action position.
	var hit := false
	for enemy in s.enemies:
		var area := footprint(enemy)
		if next.player in area:
			var sheltered: bool = enemy.kind == "bird" and next.landed and can_perch(next,next.player)
			if sheltered: next.events.append("叶荫挡住了画眉的啄扫。")
			else: hit = true
		for p in area:
			if tile(next,p) == "t":
				next.board[p.y][p.x] = "."
				next.broken += 1
				next.events.append("脆枝折断，一条新路打开了。")
			elif enemy.kind == "cricket" and p == enemy.target and tile(next,p) == "o":
				next.board[p.y][p.x] = "."
				if next.player == p: next.landed = false
				next.events.append("落点的薄叶被压下了。")
	if hit:
		next.hp -= 1
		next.events.append("撞上了预告中的危险。可以撤回这一着。")
	# Wind is deliberately AFTER attacks; a flight preview uses this exact result.
	if not next.landed and gust != Vector2i.ZERO:
		var drift: Vector2i = next.player + gust
		if blocked(next,drift):
			next.hp -= 1
			next.events.append("风把你推向苇丛边缘。")
		else: next.player = drift
	for enemy in next.enemies:
		if enemy.kind == "cricket":
			enemy.pos = enemy.target
			var delta: Vector2i = next.player - enemy.pos
			enemy.target = enemy.pos + Vector2i(clampi(delta.x,-2,2),clampi(delta.y,-2,2))
		else:
			enemy.phase = (enemy.phase + 1) % 3
			if enemy.phase == 0: enemy.target = next.player
	next.turn += 1
	next.lost = next.hp <= 0
	next.won = next.player == next.goal and not next.lost
	if next.won: next.events.append("白花就在眼前。你找到了自己的路。")
	next.message = "这一着很稳。看看接下来会发生什么。" if next.events.is_empty() else " ".join(next.events)
	return next

static func key(s: Dictionary) -> String:
	var board_key := ""
	for row in s.board: board_key += "".join(row)
	var enemies_key := ""
	for e in s.enemies: enemies_key += "%s:%s:%s;" % [e.pos,e.target,e.phase]
	return "%s|%s|%s|%s|%s|%s" % [s.player,s.landed,s.hp,s.turn % 12,board_key,enemies_key]
