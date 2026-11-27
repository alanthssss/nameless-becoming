extends "res://region_game/growth_board.gd"
## The live journal owns purchases; the field guide also shows future abilities.
signal navigated()
const Catalog := preload("res://region_game/growth_catalog_data.gd")
const AtlasCell := preload("res://region_game/growth_catalog_cell.gd")
const DIRECTIONS := ["gather","forage","carry","flight","bloom","trade"]
const ICONS := ["gather","beat","bag","wings","supply","market","reserve"]
const OVERVIEW_LINK_LIMIT := 1.65
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
	# Leave the arrowheads clear even when a caption moves above its hive.
	for source in sources:
		var path := _link_path(source,selected,true)
		var start := path[0]*map_zoom
		var departure := start.move_toward(path[1]*map_zoom,19.0)
		obstacles.append(Rect2(start,Vector2.ZERO).expand(departure).grow(3.0))
		var tip: Vector2 = path[-1]*map_zoom
		var tangent: Vector2 = (path[-1]-path[-2]).normalized()
		var head_center := tip-tangent*5.5
		obstacles.append(Rect2(head_center-Vector2(8,8),Vector2(16,16)))
		if path.size()==3:
			obstacles.append(Rect2(path[1]*map_zoom-Vector2(6,6),Vector2(12,12)))
	for id in entries:
		if not buttons.has(id): continue
		var node = buttons[id]
		var radius: float = maxf(12.0,node._radius()+1.0)
		obstacles.append(Rect2(point(id)*map_zoom-Vector2.ONE*radius,Vector2.ONE*radius*2))
		node.label_rect = Rect2()
	for id in priority:
		if id!=selected and map_zoom<OVERVIEW_LINK_LIMIT: continue
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
		obstacles.append(best.grow(1))
		node.label_rect = Rect2(best.position-center,best.size)
		node.queue_redraw()

func _draw() -> void:
	if model == null: return
	var center := size*.5
	var radius := _radius()
	for i in 6:
		var at := center+Vector2.from_angle(i*TAU/6-PI/2)*radius*1.075
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

func _hex_margin(direction: Vector2, radius: float) -> float:
	var side := fposmod(direction.angle()+PI/6.0,PI/3.0)-PI/6.0
	return (radius*cos(PI/6.0)/cos(side)+2.5)/map_zoom

func _link_path(source: String, target: String, active: bool) -> PackedVector2Array:
	var a := point(source)
	var b := point(target)
	var ray := (b-a).normalized()
	var radius: float = buttons[target]._radius()
	var margin := _hex_margin(ray,radius)
	if active and (a.distance_to(b)-margin*2)*map_zoom<32.0:
		# Neighbouring hexes may nearly touch. Take the short route around
		# their rims so a shaft and a full arrowhead still fit between them.
		var elbow := a.lerp(b,.5)+ray.orthogonal()*(radius+18.0)/map_zoom
		var outgoing := a.direction_to(elbow)
		var incoming := elbow.direction_to(b)
		return PackedVector2Array([a+outgoing*_hex_margin(outgoing,radius),elbow,b-incoming*_hex_margin(incoming,radius)])
	return PackedVector2Array([a+ray*margin,b-ray*margin])

## Keep the nib on the original arrival tangent so arrows still meet the
## correct hex face. Close pairs round their existing routing elbow.
func _ink_curve(path: PackedVector2Array, lean: float) -> PackedVector2Array:
	var curve := PackedVector2Array([path[0]])
	for i in range(1,path.size()):
		var a := path[i-1]
		var b := path[i]
		var chord := b-a
		var bend := chord.normalized().orthogonal()*minf(chord.length()*.13,8.0/map_zoom)*lean
		var c1 := a+chord*.32+bend
		var c2 := b-chord*.30
		if path.size()==3:
			var through := path[0].direction_to(path[2])*chord.length()*.28
			if i==1: c2 = b-through
			else: c1 = a+through
		for step in range(1,13):
			curve.append(a.bezier_interpolate(c1,c2,b,step/12.0))
	return curve

func _nearby_icons(curve: PackedVector2Array, source: String, target: String, margin: float) -> PackedVector2Array:
	var bounds := Rect2(curve[0],Vector2.ZERO)
	for p in curve: bounds = bounds.expand(p)
	bounds = bounds.grow(margin)
	var nearby := PackedVector2Array()
	for id in entries:
		if id==source or id==target: continue
		var at := point(id)
		if bounds.has_point(at): nearby.append(at)
	return nearby

func _clearance(curve: PackedVector2Array, nearby: PackedVector2Array) -> float:
	var closest := INF
	for at in nearby:
		for i in range(1,curve.size()):
			var near := Geometry2D.get_closest_point_to_segment(at,curve[i-1],curve[i])
			closest = minf(closest,at.distance_squared_to(near))
	return sqrt(closest)

## Bend long routes around unrelated drawings. Ease to zero at both
## ends so the two anchors and the nib direction stay on their hex faces.
func _route_clear(curve: PackedVector2Array, nearby: PackedVector2Array, margin: float) -> PackedVector2Array:
	var best := curve
	var best_gap := _clearance(curve,nearby)
	if best_gap>=margin: return best
	var normal := curve[0].direction_to(curve[-1]).orthogonal()
	var limit := minf(2.0*margin,curve[0].distance_to(curve[-1])*.44)
	for amount in [.35,-.35,.65,-.65,1.0,-1.0]:
		var candidate := curve.duplicate()
		for i in range(1,curve.size()-1):
			var t := float(i)/(curve.size()-1)
			candidate[i] += normal*limit*float(amount)*pow(sin(PI*t),3)
		var clearance := _clearance(candidate,nearby)
		if clearance>best_gap:
			best_gap = clearance
			best = candidate
		if best_gap>=margin: break
	return best

## A continuous path uses one anti-aliased polyline per visible dash,
## including its bends. Gaps reserve bare paper for status marks.
func _draw_ink_span(curve: PackedVector2Array, distances: PackedFloat32Array, start: float, end: float, hue: Color) -> void:
	if end-start<.1/map_zoom: return
	var stroke := PackedVector2Array()
	for i in range(1,curve.size()):
		if distances[i-1]>=end: break
		if distances[i]<=start: continue
		var length := distances[i]-distances[i-1]
		if stroke.is_empty():
			var t := clampf((start-distances[i-1])/length,0,1)
			stroke.append(curve[i-1].lerp(curve[i],t))
		var t := clampf((end-distances[i-1])/length,0,1)
		stroke.append(curve[i-1].lerp(curve[i],t))
	if stroke.size()>1: draw_polyline(stroke,hue,1.85/map_zoom,true)

func _draw_ink_shaft(curve: PackedVector2Array, hue: Color, optional: bool, mark_index: int, head: float, nearby: PackedVector2Array, margin: float) -> void:
	var u := 1.0/map_zoom
	var distances := PackedFloat32Array([0.0])
	for i in range(1,curve.size()):
		distances.append(distances[-1]+curve[i-1].distance_to(curve[i]))
	var end := distances[-1]-head*.48
	var gaps: Array[Vector2] = []
	if mark_index>=0:
		gaps.append(Vector2(distances[mark_index]-6*u,distances[mark_index]+6*u))
	# Crowded routes can pass behind another drawing. Clip each such
	# crossing to the paper around that drawing, including curved segments.
	for at in nearby:
		for i in range(1,curve.size()):
			var a := curve[i-1]
			var length := distances[i]-distances[i-1]
			if length<=0: continue
			var tangent := a.direction_to(curve[i])
			var projected := (at-a).dot(tangent)
			var perpendicular := absf((at-a).cross(tangent))
			if perpendicular>=margin: continue
			var half := sqrt(margin*margin-perpendicular*perpendicular)
			var enter := maxf(0.0,projected-half)
			var leave := minf(length,projected+half)
			if leave>enter: gaps.append(Vector2(distances[i-1]+enter,distances[i-1]+leave))
	gaps.sort_custom(func(a: Vector2,b: Vector2) -> bool: return a.x<b.x)
	gaps.append(Vector2(end,end))
	var cursor := 0.0
	for gap in gaps:
		var stop := minf(gap.x,end)
		while cursor<stop:
			var dash_end := minf(cursor+6.5*u,stop) if optional else stop
			_draw_ink_span(curve,distances,cursor,dash_end,hue)
			cursor = dash_end+3.5*u if optional else dash_end
		cursor = maxf(cursor,gap.y)
		if cursor>=end: break

func _draw_link_between(source: String, target: String, info: Dictionary) -> void:
	if source == target: return
	var path := _link_path(source,target,not info.is_empty())
	var lean := .8 if (source+target).hash()%2==0 else -.8
	if info.is_empty():
		if (path[-1]-path[0]).dot(point(target)-point(source))>0:
			draw_polyline(_ink_curve(path,lean),Color("796e575e"),1.05/map_zoom,true)
		return
	var hue := Color("3c623f") if info.met else Color("934522")
	var u := 1.0/map_zoom
	var end := path[-1]
	var ray := path[-2].direction_to(end)
	var last_length := path[-2].distance_to(end)
	var head := minf(10.5*u,last_length*.7)
	if head<2*u: return
	var curve := _ink_curve(path,lean)
	var clearance: float = (buttons[target]._radius()+2.0)*u
	var nearby := _nearby_icons(curve,source,target,clearance*3.0)
	if path.size()==2: curve = _route_clear(curve,nearby,clearance)
	var mark_index := -1
	if map_zoom>=1.78 and (path.size()==3 or last_length*map_zoom>=32.0):
		mark_index = roundi((curve.size()-1)*(.5 if path.size()==3 else .375))
	if mark_index>=0:
		for at in nearby:
			if at.distance_to(curve[mark_index])<clearance+5.0*u:
				mark_index = -1
				break
	_draw_ink_shaft(curve,hue,info.optional,mark_index,head,nearby,clearance)
	# Stop the stroke beneath the nib so its rounded cap cannot blunt the tip.
	var base := end-ray*head
	var wing := ray.orthogonal()*head*.43
	draw_colored_polygon(PackedVector2Array([end,base+wing,base+ray*head*.27,base-wing*.91]),hue)
	if mark_index<0: return
	var mark := curve[mark_index]
	if info.met:
		draw_polyline(PackedVector2Array([mark+Vector2(-4.2,-.5)*u,mark+Vector2(-1.3,2.9)*u,mark+Vector2(4.1,-3.5)*u]),hue,2.0*u,true)
	else:
		draw_line(mark+Vector2(.2,-4.0)*u,mark+Vector2(-.2,.6)*u,hue,2.1*u,true)
		draw_circle(mark+Vector2(-.3,3.8)*u,1.2*u,hue,true,-1,true)

func _draw_overview_links() -> void:
	for data in Catalog.DATA.cells:
		if data.id == selected: continue
		var first: Dictionary = ranks_by_id[data.ranks[0]]
		var needs: Array = first.requires_all
		if data.stage == "demo": needs = model.upgrade(first.id).get("requires",[])
		for from_rank in needs:
			var from_cell: String = ranks_by_id[from_rank].cell
			if entries[from_cell].branch == data.branch:
				_draw_link_between(from_cell,data.id,{})

func _draw_catalog_links() -> void:
	if map_zoom<OVERVIEW_LINK_LIMIT: _draw_overview_links()
	var links := selected_links()
	for source in links:
		_draw_link_between(source,selected,links[source])
