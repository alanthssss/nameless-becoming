extends Control
const GrowthNode = preload("res://nectar_growth_node.gd")
const Art = preload("res://nectar_ui_art.gd")
signal selected_changed(id: String)
const NODES := [
	{"id":"gather","title":"采蜜技巧","ranks":["gather1","gather2"],"group":0,"at":Vector2(.17,.15)},
	{"id":"reach","title":"花香触角","ranks":["reach"],"group":0,"at":Vector2(.17,.44)},
	{"id":"beat","title":"利落振翅","ranks":["beat"],"group":0,"at":Vector2(.46,.15)},
	{"id":"twin","title":"双簇采蜜","ranks":["twin"],"group":0,"at":Vector2(.46,.44)},
	{"id":"bag","title":"蜜囊容量","ranks":["bag1","bag2"],"group":1,"at":Vector2(.17,.79)},
	{"id":"wings","title":"双翼续航","ranks":["wings1","wings2"],"group":1,"at":Vector2(.46,.79)},
	{"id":"meadow","title":"紫花地","ranks":["meadow"],"group":2,"at":Vector2(.81,.10)},
	{"id":"shortcut","title":"叶间近道","ranks":["shortcut"],"group":2,"at":Vector2(.81,.37)},
	{"id":"market","title":"好口碑","ranks":["market"],"group":2,"at":Vector2(.81,.64)},
	{"id":"reserve","title":"备好花蜜","ranks":["reserve"],"group":3,"at":Vector2(.81,.91)}
]
var model
var font: Font
var buttons := {}
var selected := "gather"
var group_memory := {}
var reduced_motion := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for data in NODES:
		var b = GrowthNode.new()
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
	if model != null and model.upgrade(str(definition(id).ranks[0])).is_empty(): return false
	if rank_of(id) > 0 or id in ["gather","bag","meadow","reserve"]: return true
	match id:
		"wings": return "gather1" in model.owned or "bag1" in model.owned
		"reach", "beat": return "gather1" in model.owned
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
		b.reduced_motion = reduced_motion
		b.set_rank(rank_of(data.id))
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
	if not buttons[a].visible or not buttons[b].visible: return
	var from := point(a)
	var to := point(b)
	var direction := (to-from).normalized()
	from += direction*55
	to -= direction*55
	# A pencil-like curved stroke keeps dependencies readable on the field journal.
	var normal := direction.orthogonal()*12
	var points := PackedVector2Array()
	for i in 19:
		points.append(from.bezier_interpolate(from+(to-from)*.33+normal,to-(to-from)*.33+normal,to,float(i)/18))
	var color := Color("73814f") if lit else Color("b8aa83")
	if dashed:
		for i in range(0,18,3): draw_line(points[i],points[i+1],color,1.6,true)
	else:
		draw_polyline(points,Color(color,.20),4.5,true)
		draw_polyline(points,color,1.6,true)
	var tip := to-direction*3
	var side := direction.orthogonal()*3
	draw_polyline(PackedVector2Array([tip-direction*7+side,tip,tip-direction*7-side]),color,1.6,true)

func _draw() -> void:
	if model == null or buttons.is_empty(): return
	_edge("gather","reach",rank_of("gather")>0)
	_edge("gather","beat",rank_of("gather")>0)
	_edge("reach","twin",rank_of("reach")>0)
	_edge("gather","twin",rank_of("gather")==2,true)
	_edge("bag","wings",rank_of("bag")>0,true)
	_edge("meadow","shortcut",rank_of("meadow")>0)
	_edge("meadow","market",rank_of("meadow")>0)
	if font:
		draw_string(font,Vector2(18,2),"采蜜与出行",HORIZONTAL_ALIGNMENT_LEFT,-1,19,Color("716b42"))
		draw_string(font,Vector2(size.x*.73,2),"花路与收获",HORIZONTAL_ALIGNMENT_LEFT,-1,19,Color("716b42"))
