extends Control
const HexNode = preload("res://nectar_growth_node.gd")
const Art = preload("res://nectar_ui_art.gd")
signal selected_changed(id: String)
const NODES := [
	{"id":"gather","title":"采蜜技巧","ranks":["gather1","gather2"],"group":0,"at":Vector2(.18,.35)},
	{"id":"reach","title":"花香触角","ranks":["reach"],"group":0,"at":Vector2(.18,.63)},
	{"id":"twin","title":"双簇采蜜","ranks":["twin"],"group":0,"at":Vector2(.36,.81)},
	{"id":"bag","title":"蜜囊容量","ranks":["bag1","bag2"],"group":1,"at":Vector2(.72,.35)},
	{"id":"wings","title":"双翼续航","ranks":["wings1","wings2"],"group":1,"at":Vector2(.80,.63)},
	{"id":"meadow","title":"紫花地","ranks":["meadow"],"group":2,"at":Vector2(.43,.12)},
	{"id":"shortcut","title":"叶间近道","ranks":["shortcut"],"group":2,"at":Vector2(.66,.10)},
	{"id":"market","title":"好口碑","ranks":["market"],"group":2,"at":Vector2(.87,.16)},
	{"id":"reserve","title":"备好花蜜","ranks":["reserve"],"group":3,"at":Vector2(.60,.83)}
]
var model
var font: Font
var buttons := {}
var selected := "gather"
var group_memory := {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for data in NODES:
		var b = HexNode.new()
		b.kind = data.id
		b.title = data.title
		b.ui_font = font
		b.max_rank = data.ranks.size()
		b.size = Vector2(128,124)
		b.pressed.connect(select_node.bind(data.id))
		b.focus_entered.connect(_focused.bind(data.id))
		add_child(b)
		buttons[data.id] = b
	resized.connect(_layout)
	_layout()

func definition(id: String) -> Dictionary:
	for d in NODES:
		if d.id == id: return d
	return NODES[0]

func rank_of(id: String) -> int:
	var result := 0
	for rank_id in definition(id).ranks:
		if rank_id in model.owned: result += 1
	return result

func next_id(id: String) -> String:
	var data := definition(id)
	var level := rank_of(id)
	return "" if level >= data.ranks.size() else str(data.ranks[level])

func is_revealed(id: String) -> bool:
	if rank_of(id) > 0 or id in ["gather","bag","meadow","reserve"]: return true
	match id:
		"wings": return "gather1" in model.owned or "bag1" in model.owned
		"reach": return "gather1" in model.owned
		"twin": return "reach" in model.owned
		"shortcut", "market": return "meadow" in model.owned
	return false

func visible_ids() -> Array[String]:
	var result: Array[String] = []
	for data in NODES:
		if is_revealed(data.id): result.append(data.id)
	return result

func refresh(next_model) -> void:
	model = next_model
	if buttons.is_empty(): return
	for data in NODES:
		var b = buttons[data.id]
		b.visible = is_revealed(data.id)
		b.rank = rank_of(data.id)
		b.selected = selected == data.id
		var rank_id := next_id(data.id)
		b.state = "max" if rank_id.is_empty() else "ready" if model.can_buy(rank_id) else "poor" if model.locked_reason(rank_id).begins_with("还需") else "locked"
		b.tooltip_text = data.title+" · "+("已满级" if rank_id.is_empty() else model.locked_reason(rank_id) if not model.can_buy(rank_id) else "可升级")
		b.queue_redraw()
	if selected not in visible_ids(): selected = "gather"
	queue_redraw()

func select_node(id: String) -> void:
	if model == null or not is_revealed(id): return
	selected = id
	group_memory[int(definition(id).group)] = id
	refresh(model)
	buttons[id].grab_focus()
	selected_changed.emit(id)

func _focused(id: String) -> void:
	if selected == id: return
	selected = id
	group_memory[int(definition(id).group)] = id
	refresh(model)
	selected_changed.emit(id)

func navigate(key: int, backwards := false) -> void:
	var ids := visible_ids()
	if ids.is_empty(): return
	var destination := selected
	if key == KEY_TAB:
		destination = ids[posmod(ids.find(selected)+(-1 if backwards else 1),ids.size())]
	elif key in [KEY_UP,KEY_DOWN]:
		var group: int = definition(selected).group
		var local: Array[String] = []
		for id in ids:
			if int(definition(id).group) == group: local.append(id)
		destination = local[posmod(local.find(selected)+(-1 if key == KEY_UP else 1),local.size())]
	elif key in [KEY_LEFT,KEY_RIGHT]:
		var group: int = posmod(int(definition(selected).group)+(-1 if key == KEY_LEFT else 1),4)
		for i in 4:
			var local: Array[String] = []
			for id in ids:
				if int(definition(id).group) == group: local.append(id)
			if not local.is_empty():
				destination = str(group_memory.get(group,local[0]))
				if destination not in local: destination = local[0]
				break
			group = posmod(group+(-1 if key == KEY_LEFT else 1),4)
	select_node(destination)

func point(id: String) -> Vector2:
	if id == "root": return size*Vector2(.46,.43)
	return size*Vector2(definition(id).at)

func _layout() -> void:
	for data in NODES:
		buttons[data.id].position = point(data.id)-Vector2(64,48)
	queue_redraw()

func _edge(a: String,b: String, lit: bool, dashed := false) -> void:
	if a != "root" and not buttons[a].visible: return
	if b != "root" and not buttons[b].visible: return
	var from := point(a)
	var to := point(b)
	var direction := (to-from).normalized()
	from += direction*48
	to -= direction*48
	var color := Color("b9bd80") if lit else Color("58776b")
	if dashed: draw_dashed_line(from,to,color,2,7,true,true)
	else: draw_line(from,to,color,2.2,true)
	var tip := to-direction*5
	var side := Vector2(-direction.y,direction.x)*4
	draw_colored_polygon(PackedVector2Array([tip,tip-direction*9+side,tip-direction*9-side]),color)

func _draw() -> void:
	if model == null or buttons.is_empty(): return
	# Faint abstract guides provide direction without suggesting purchasable cells.
	for i in 6:
		var angle: float = TAU*i/6
		draw_line(point("root"),point("root")+Vector2(cos(angle),sin(angle))*210,Color(0.5,.66,.56,.06),1,true)
	_edge("root","gather",rank_of("gather")>0)
	_edge("root","bag",rank_of("bag")>0)
	_edge("gather","reach",rank_of("gather")>0)
	_edge("reach","twin",rank_of("reach")>0)
	_edge("gather","twin",rank_of("gather")==2,true)
	_edge("bag","wings",rank_of("bag")>0,true)
	_edge("root","wings",rank_of("gather")>0,true)
	_edge("root","meadow",model.growth_count()>=3,true)
	_edge("meadow","shortcut",rank_of("meadow")>0)
	# Market shares the meadow prerequisite; it does not require the shortcut.
	if buttons.market.visible:
		var from := point("meadow")+Vector2(35,35)
		var to := point("market")+Vector2(0,48)
		var route_y := size.y*.27
		draw_polyline(PackedVector2Array([from,Vector2(from.x,route_y),Vector2(to.x,route_y),to]),Color("b9bd80"),2,true)
	_edge("twin","reserve",rank_of("twin")>0,true)
	# Shortcut has an OR route to the outcome, documented in the outcome condition strip.
	var root_at := point("root")
	draw_circle(root_at,35,Color("365c4d"))
	draw_arc(root_at,35,0,TAU,48,Color("a9b282"),1.5,true)
	Art.icon(self,"root",root_at,23)
	if font:
		draw_string(font,root_at+Vector2(-45,62),"此刻的你",HORIZONTAL_ALIGNMENT_CENTER,90,16,Color("9bb5a0"))
		draw_string(font,Vector2(24,size.y*.13),"采 集",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("a3c4ae"))
		draw_string(font,Vector2(size.x*.78,size.y*.31),"出 行",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("a3c4ae"))
		draw_string(font,Vector2(size.x*.36,12),"花 路 与 收 益",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("a3c4ae"))
		if buttons.twin.visible: draw_string(font,point("twin")+Vector2(-48,-59),"技巧 2级 ＋ 触角",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("c8d1b8"))
		if buttons.wings.visible: draw_string(font,point("wings")+Vector2(-59,-59),"初始成长任选一项",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("c8d1b8"))
		draw_string(font,point("reserve")+Vector2(-67,-61),"双采 或 近道 · 18紫蜜",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("c8d1b8"))
