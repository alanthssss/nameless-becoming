extends "res://region_game/growth_board.gd"
## The live journal owns purchases; the field guide also shows future abilities.
const Catalog := preload("res://region_game/growth_catalog_data.gd")
const AtlasCell := preload("res://region_game/growth_catalog_cell.gd")
const DIRECTIONS := ["gather","forage","carry","flight","bloom","trade"]
const ICONS := ["gather","beat","bag","wings","supply","market","reserve"]
const SECTOR_TINTS := [Color("b9c97f"),Color("d2ac79"),Color("dfa379"),Color("8dbab2"),Color("a9bb7f"),Color("bd9db0")]
var entries: Dictionary = {}
var ranks_by_id: Dictionary = {}
var stage_names: Dictionary = {}
var manual_rank := -1
var map_zoom := 1.0

func _init() -> void:
	for cell in Catalog.DATA.cells:
		var info: Dictionary = cell.duplicate()
		info["title"] = cell.name
		entries[cell.id] = info
	for entry in Catalog.DATA.ranks: ranks_by_id[entry.id] = entry
	for stage in Catalog.DATA.stages: stage_names[stage.id] = stage.name

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for data in Catalog.DATA.cells:
		var node = AtlasCell.new()
		node.kind = data.id
		node.title = data.name
		node.ui_font = font
		node.hive_cell = true
		node.max_rank = data.ranks.size()
		node.size = Vector2(36,36)
		var sector := DIRECTIONS.find(data.branch)
		node.sector = sector if sector>=0 else 6
		node.icon_name = data.id if Art.JOURNAL_CELLS.has(data.id) else ICONS[node.sector]
		node.planned = data.stage != "demo"
		node.pressed.connect(select_node.bind(data.id))
		node.focus_entered.connect(_focused.bind(data.id))
		add_child(node)
		buttons[data.id] = node
	# The historical shared UI still indexes the removed shortcut during construction.
	# It remains outside this catalog and the game model cannot offer it for sale.
	var shortcut := Button.new()
	shortcut.hide()
	add_child(shortcut)
	buttons["shortcut"] = shortcut
	resized.connect(_layout)
	_layout()

func definition(id: String) -> Dictionary:
	return entries.get(id,{})

func is_revealed(id: String) -> bool:
	return entries.has(id)

func visible_ids() -> Array[String]:
	var ids: Array[String] = []
	for data in Catalog.DATA.cells: ids.append(str(data.id))
	return ids

func _base_index(id: String) -> int:
	var cell: Dictionary = entries[id]
	return mini(rank_of(id),cell.ranks.size()-1)

func viewed_index() -> int:
	if manual_rank < 0: return _base_index(selected)
	return clampi(manual_rank,0,entries[selected].ranks.size()-1)

func rank_of(id: String) -> int:
	if model == null or not entries.has(id): return 0
	var count := 0
	for rank_id in entries[id].ranks:
		if rank_id in model.owned: count += 1
	return count

func next_id(id: String) -> String:
	if model == null or not entries.has(id): return ""
	var cell: Dictionary = entries[id]
	if cell.stage != "demo": return ""
	var n := rank_of(id)
	if n >= cell.ranks.size() or (id == selected and manual_rank >= 0 and manual_rank != n): return ""
	return str(cell.ranks[n])

func _current_rank(id: String) -> Dictionary:
	return ranks_by_id[entries[id].ranks[viewed_index() if id == selected else _base_index(id)]]

func inspect_data() -> Dictionary:
	var cell: Dictionary = entries[selected]
	var idx := viewed_index()
	var r: Dictionary = ranks_by_id[cell.ranks[idx]]
	var planned: bool = cell.stage != "demo"
	var state := "planned"
	var entry: Dictionary = {}
	if not planned and model != null:
		entry = model.upgrade(r.id)
		state = "owned" if r.id in model.owned else ("next" if idx == rank_of(selected) else "preview")
	var prices: Dictionary = r.cost if planned else {"coins":entry.get("cost",0),"fiber":entry.get("fiber",0),"resin":entry.get("resin",0)}
	var reqs := _rank_conditions(r,not planned,entry)
	return {"id":r.id,"cell_id":cell.id,"name":r.name if planned else entry.get("name",r.name),
		"cell_name":cell.name,"rank_index":idx,"rank_count":cell.ranks.size(),"branch":cell.branch,
		"stage":cell.stage,"stage_name":stage_names[cell.stage],"state":state,"planned":planned,
		"effect_text":r.effect_text if planned else str(entry.get("description","")),
		"feedback":r.feedback if planned else "","requirements":reqs,"cost":prices}

func _rank_names(ids: Array) -> String:
	var names := PackedStringArray()
	for id in ids:
		if ranks_by_id.has(id): names.append(str(ranks_by_id[id].name))
	return "、".join(names)

func _rank_conditions(row: Dictionary,live: bool,live_entry: Dictionary) -> String:
	var words := PackedStringArray()
	if live:
		var needs: Array = live_entry.get("requires",[])
		if not needs.is_empty(): words.append("需要 "+_rank_names(needs))
		match str(row.id):
			"wings1": words.append("轻巧采蜜、舒展蜜囊任选一项")
			"meadow": words.append("池岸基础成长累计 3 档")
			"market": words.append("到过紫花地，并交售至少 1 份紫蜜")
			"reserve": words.append("取得双簇采蜜，到过紫花地并交售至少 6 份紫蜜")
	else:
		var all_ranks: Array = row.get("requires_all",[])
		var any_ranks: Array = row.get("requires_any",[])
		if not all_ranks.is_empty(): words.append("需要 "+_rank_names(all_ranks))
		if not any_ranks.is_empty(): words.append("任选 "+_rank_names(any_ranks))
		var count: Dictionary = row.get("requires_count",{})
		if not count.is_empty():
			words.append("%d 项任选 %d 项：%s" % [count.from_purchased_ranks.size(),count.minimum,_rank_names(count.from_purchased_ranks)])
		var world: Dictionary = row.get("requires_world",{})
		if world.get("sealed",false): words.append("已在庭院封罐")
		if world.get("lantern_lit",false): words.append("已点亮花径灯")
	return " · ".join(words)

func shift_rank(step: int) -> void:
	if not entries.has(selected): return
	var target := clampi(viewed_index()+step,0,entries[selected].ranks.size()-1)
	if target == viewed_index(): return
	manual_rank = -1 if target == _base_index(selected) else target
	refresh(model)
	selected_changed.emit(selected)

func cycle_branch(step: int) -> void:
	var start: int = DIRECTIONS.find(entries[selected].branch)
	var branch: String = DIRECTIONS[posmod(start+step,DIRECTIONS.size())]
	for cell in Catalog.DATA.cells:
		if cell.branch == branch:
			select_node(cell.id)
			return

func select_node(id: String) -> void:
	if model == null or not is_revealed(id): return
	if id != selected: manual_rank = -1
	selected = id
	refresh(model)
	buttons[id].grab_focus()
	selected_changed.emit(id)

func _focused(id: String) -> void:
	if model == null or id == selected: return
	select_node(id)

func refresh(next_model) -> void:
	model = next_model
	if model == null: return
	for data in Catalog.DATA.cells:
		if not buttons.has(data.id): continue
		var node = buttons[data.id]
		var future: bool = data.stage != "demo"
		var n := rank_of(data.id)
		node.set_rank(n)
		node.selected = selected == data.id
		node.reduced_motion = reduced_motion
		node.z_index = 2 if node.selected else 0
		if future:
			node.state = "planned"
		elif n == data.ranks.size():
			node.state = "max"
		else:
			var id: String = data.ranks[n]
			node.state = "ready" if model.can_buy(id) else ("poor" if model.locked_reason(id).begins_with("还需") else "locked")
		node.tooltip_text = "%s · %s" % [data.name,("后续开放" if future else "%d / %d" % [n,data.ranks.size()])]
		node.queue_redraw()
	queue_redraw()

func update_lod(value: float) -> void:
	map_zoom = value
	for id in entries:
		if buttons.has(id):
			buttons[id].zoom_lod = value
			buttons[id].queue_redraw()
	queue_redraw()

func _radius() -> float:
	return minf(size.x*.475,size.y*.445)

func point(id: String) -> Vector2:
	var mid := size*.5
	if not entries.has(id): return mid
	var cell: Dictionary = entries[id]
	var sector := DIRECTIONS.find(cell.branch)
	var r := _radius()
	if sector < 0:
		return mid+Vector2((1.0 if id=="feast" else -1.0)*.083*r,0)
	var axis := Vector2.from_angle(sector*TAU/6-PI/2)
	var distance: float = (cell.ring*74.0+13.0)/508.0*r
	var offset: float = cell.slot*minf(78.0,38.0+5.5*cell.ring)/508.0*r
	return mid+axis*distance+axis.rotated(PI/2)*offset

func _layout() -> void:
	for id in entries:
		if buttons.has(id): buttons[id].position = point(id)-AtlasCell.CENTER
	queue_redraw()

func _draw() -> void:
	if model == null: return
	var center := size*.5
	var radius := _radius()
	var tips := PackedVector2Array()
	for i in 6: tips.append(center+Vector2.from_angle(i*TAU/6-PI/2)*radius)
	var dividers := [0.42,0.72,1.0]
	for i in 6:
		var v := tips[i]
		var prev := v.lerp(tips[posmod(i-1,6)],.5)
		var next := v.lerp(tips[(i+1)%6],.5)
		draw_colored_polygon(PackedVector2Array([center,prev,v,next]),Color(SECTOR_TINTS[i],.16))
	for divider in dividers:
		var loop := PackedVector2Array()
		for v in tips: loop.append(center+(v-center)*divider)
		loop.append(loop[0])
		draw_polyline(loop,Color("9687638a"),1.0/map_zoom,true)
	for i in 6:
		var ray := tips[i]-center
		var at := center+ray*1.075
		var label_size := maxi(8,roundi(15.0/map_zoom))
		draw_string(font,at+Vector2(-40,5/map_zoom),SECTORS[i],HORIZONTAL_ALIGNMENT_CENTER,80,label_size,INK)
	_draw_catalog_links()

func _line(source: String,target: String,choice: bool,highlight: bool) -> void:
	if source==target or not entries.has(source): return
	var ray := (point(target)-point(source)).normalized()
	var margin := clampf(10.6*map_zoom,10.6,31.0)/map_zoom
	var a := point(source)+ray*margin
	var b := point(target)-ray*margin
	var line_color := Color("91692d") if highlight else Color("857b5868")
	var width := (1.9 if highlight else 1.1)/map_zoom
	if choice: draw_dashed_line(a,b,line_color,width,4/map_zoom,true,true)
	else: draw_line(a,b,line_color,width,true)
	if highlight:
		var wing := ray.orthogonal()*3.0/map_zoom
		draw_polyline(PackedVector2Array([b-ray*6.0/map_zoom+wing,b,b-ray*6.0/map_zoom-wing]),line_color,width,true)

func _draw_catalog_links() -> void:
	var active: Dictionary = _current_rank(selected)
	for data in Catalog.DATA.cells:
		if data.id == selected: continue
		var first: Dictionary = ranks_by_id[data.ranks[0]]
		var needs: Array = first.requires_all
		if data.stage == "demo": needs = model.upgrade(first.id).get("requires",[])
		for from_rank in needs:
			var from_cell: String = ranks_by_id[from_rank].cell
			if entries[from_cell].branch == data.branch:
				_line(from_cell,data.id,false,false)
	var required: Array = active.requires_all.duplicate()
	var optional: Array = active.requires_any.duplicate()
	if entries[selected].stage == "demo":
		required = model.upgrade(active.id).get("requires",[]).duplicate()
		optional.clear()
		match str(active.id):
			"wings1": optional = ["gather1","bag1"]
			"meadow": optional = model.MEADOW_GROWTH_RANKS
			"reserve": required.append("twin")
	else:
		optional.append_array(active.get("requires_count",{}).get("from_purchased_ranks",[]))
	var seen := {}
	for from_rank in required+optional:
		var from_cell: String = ranks_by_id[from_rank].cell
		if seen.has(from_cell): continue
		seen[from_cell] = true
		_line(from_cell,selected,from_rank in optional,true)
