extends "res://region_game/growth_board.gd"
## The live journal owns purchases; the field guide also shows future abilities.
signal navigated()
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
var label_layout_key: Array = []

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
	var reqs := _rank_conditions(r)
	return {"id":r.id,"cell_id":cell.id,"name":r.name if planned else entry.get("name",r.name),
		"cell_name":cell.name,"rank_index":idx,"rank_count":cell.ranks.size(),"branch":cell.branch,
		"stage":cell.stage,"stage_name":stage_names[cell.stage],"state":state,"planned":planned,
		"effect_text":r.effect_text if planned else str(entry.get("description","")),
		"feedback":r.feedback if planned else "","requirements":reqs,"cost":prices}

## Skill requirements shared by the detail panel and the map. World actions and
## the wallet have no map position and are listed separately on the detail page.
func prerequisite_groups(rank_id: String) -> Array[Dictionary]:
	var groups: Array[Dictionary] = []
	if model == null or not ranks_by_id.has(rank_id): return groups
	var data: Dictionary = ranks_by_id[rank_id]
	var all_ranks: Array = data.requires_all
	var choices: Array = data.requires_any
	var count: Dictionary = data.get("requires_count",{})
	if entries[data.cell].stage == "demo":
		all_ranks = model.upgrade(rank_id).get("requires",[]).duplicate()
		choices = []
		count = {}
		match rank_id:
			"wings1": choices = ["gather1","bag1"]
			"meadow": count = {"minimum":3,"from_purchased_ranks":model.MEADOW_GROWTH_RANKS}
			"reserve": all_ranks.append("twin")
	for rank_key in all_ranks:
		groups.append(_requirement_group([rank_key],1,false))
	if not choices.is_empty():
		groups.append(_requirement_group(choices,1,true))
	if not count.is_empty():
		groups.append(_requirement_group(count.from_purchased_ranks,count.minimum,true))
	return groups

func _requirement_group(ranks: Array, minimum: int, optional: bool) -> Dictionary:
	var owned_count := 0
	for rank_id in ranks:
		if rank_id in model.owned: owned_count += 1
	return {"ranks":ranks,"minimum":minimum,"owned_count":owned_count,
		"optional":optional,"met":owned_count >= minimum}

func select_rank(rank_id: String) -> void:
	if model == null or not ranks_by_id.has(rank_id): return
	var cell_id: String = ranks_by_id[rank_id].cell
	var index: int = entries[cell_id].ranks.find(rank_id)
	selected = cell_id
	manual_rank = -1 if index == _base_index(cell_id) else index
	select_node(cell_id)

func _rank_names(ids: Array) -> String:
	var names := PackedStringArray()
	for id in ids:
		if ranks_by_id.has(id): names.append(str(ranks_by_id[id].name))
	return "、".join(names)

func _rank_conditions(row: Dictionary) -> String:
	var words := PackedStringArray()
	for group in prerequisite_groups(row.id):
		var names := _rank_names(group.ranks)
		if not group.optional: words.append("需要 "+names)
		elif group.minimum == 1: words.append("任选一项："+names)
		else: words.append("任选 %d 档：%s" % [group.minimum,names])
	var world: Dictionary = row.get("requires_world",{})
	if world.get("visited_meadow",false): words.append("探索紫花地")
	if world.has("min_lifetime_violet_sold"):
		words.append("交售至少 %d 份紫蜜" % world.min_lifetime_violet_sold)
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

func navigate(key: int, backwards := false) -> void:
	var previous := selected
	super.navigate(key,backwards)
	if selected != previous: navigated.emit()

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
		node.tooltip_text = "%s · %s" % [data.name,node.state_caption()]
		node.queue_redraw()
	_layout_labels()
	queue_redraw()

func update_lod(value: float) -> void:
	map_zoom = value
	for id in entries:
		if buttons.has(id):
			buttons[id].zoom_lod = value
			buttons[id].queue_redraw()
	_layout_labels()
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
		if buttons.has(id):
			buttons[id].position = point(id)-AtlasCell.CENTER
			buttons[id].layout_radius = clampf(_radius()*.047,6.0,10.6)
	_layout_labels()
	queue_redraw()

func _layout_labels() -> void:
	if not model or not font or not buttons.has(selected): return
	var current := [size,map_zoom,selected,viewed_index(),model.owned.hash()]
	if current==label_layout_key: return
	label_layout_key = current
	var obstacles: Array[Rect2] = []
	var priority: Array = [selected]
	var sources := selected_links()
	priority.append_array(sources.keys())
	for id in entries:
		if not buttons.has(id): continue
		var node = buttons[id]
		var radius: float = maxf(12.0,node._radius()+1.0)
		obstacles.append(Rect2(point(id)*map_zoom-Vector2.ONE*radius,Vector2.ONE*radius*2))
		node.label_rect = Rect2()
		if not node.planned and id not in priority: priority.append(id)
	for id in entries:
		if id not in priority: priority.append(id)
	for id in priority:
		if id!=selected and map_zoom<1.78: continue
		var node = buttons[id]
		var center := point(id)*map_zoom
		var radius: float = node._radius()
		var label := Vector2(ceilf(font.get_string_size(node.title,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x)+6,18)
		var gap := maxf(12.0,radius+1.0)+3.0
		var offsets := [Vector2(-label.x*.5,gap),Vector2(-label.x*.5,-gap-label.y),
			Vector2(gap,-label.y*.5),Vector2(-gap-label.x,-label.y*.5),
			Vector2(-label.x*.1,gap),Vector2(-label.x*.9,gap),
			Vector2(-label.x*.1,-gap-label.y),Vector2(-label.x*.9,-gap-label.y)]
		var best := Rect2()
		var min_overlap := INF
		for offset: Vector2 in offsets:
			var candidate := Rect2(center+offset,label)
			var overlap := 0.0
			for box in obstacles:
				if box.has_point(candidate.get_center()): overlap += label.x*label.y
				overlap += candidate.intersection(box).get_area()
			if overlap < min_overlap:
				best = candidate
				min_overlap = overlap
			if overlap==0: break
		if min_overlap>0 and node.planned and id!=selected and not sources.has(id): continue
		obstacles.append(best.grow(1))
		node.label_rect = Rect2(best.position-center,best.size)
		node.queue_redraw()

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

## A skill with two ranks may contribute two choices to a count gate, but it
## has only one map position. Once the threshold is met, unused choices drop
## out so they do not look like outstanding obligations.
func selected_links() -> Dictionary:
	var links := {}
	for group in prerequisite_groups(_current_rank(selected).id):
		for rank_id in group.ranks:
			var source: String = ranks_by_id[rank_id].cell
			if source == selected: continue
			var learned: bool = rank_id in model.owned
			if group.optional and group.met and not learned: continue
			var link: Dictionary = links.get(source,{"optional":true,"met":true})
			link.optional = link.optional and group.optional
			link.met = link.met and learned
			links[source] = link
	return links

func _draw_link_between(source: String, target: String, info: Dictionary) -> void:
	if source == target: return
	var delta := point(target)-point(source)
	var ray := delta.normalized()
	var radius: float = buttons[target]._radius()
	var side := fposmod(ray.angle()+PI/6.0,PI/3.0)-PI/6.0
	var margin := (radius*cos(PI/6.0)/cos(side)+2.5)/map_zoom
	var start := point(source)+ray*margin
	var end := point(target)-ray*margin
	if delta.length() < margin*2: return
	if info.is_empty():
		draw_line(start,end,Color("756b573a"),1.0/map_zoom,true)
		return
	var hue := Color("3c623f") if info.met else Color("934522")
	var length_px := start.distance_to(end)*map_zoom
	var head := minf(13.0,length_px*.80)/map_zoom
	var base := end-ray*head
	var width := 2.9/map_zoom
	if info.optional:
		draw_dashed_line(start,base,hue,width,5.0/map_zoom,true,true)
	else:
		draw_line(start,base,hue,width,true)
	var wing := ray.orthogonal()*head*.52
	var triangle := PackedVector2Array([end,base+wing,base-wing])
	draw_polyline(PackedVector2Array([end,base+wing,base-wing,end]),Color("fff3d1"),2.6/map_zoom,true)
	draw_colored_polygon(triangle,hue)
	if map_zoom < 1.78 or length_px < 48.0: return
	# Ink seals make fulfilled and outstanding conditions distinct without colour.
	var seal := start.lerp(base,.36)
	var u := 1.0/map_zoom
	draw_circle(seal,6.8*u,hue,true,-1,true)
	var white := Color("fff5da")
	if info.met:
		draw_polyline(PackedVector2Array([seal+Vector2(-3.3,0)*u,seal+Vector2(-.9,2.7)*u,seal+Vector2(3.5,-2.8)*u]),white,1.6*u,true)
	else:
		draw_line(seal+Vector2.UP*3.6*u,seal+Vector2.DOWN*.7*u,white,1.7*u,true)
		draw_circle(seal+Vector2.DOWN*3.1*u,1.0*u,white,true,-1,true)

func _draw_catalog_links() -> void:
	for data in Catalog.DATA.cells:
		if data.id == selected: continue
		var first: Dictionary = ranks_by_id[data.ranks[0]]
		var needs: Array = first.requires_all
		if data.stage == "demo": needs = model.upgrade(first.id).get("requires",[])
		for from_rank in needs:
			var from_cell: String = ranks_by_id[from_rank].cell
			if entries[from_cell].branch == data.branch:
				_draw_link_between(from_cell,data.id,{})
	var links := selected_links()
	for source in links:
		_draw_link_between(source,selected,links[source])
