extends SceneTree
## The packaged field guide may reveal future ranks but never makes them purchases.
const Board = preload("res://region_game/growth_catalog_board.gd")
const Model = preload("res://region_game/model.gd")
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func run() -> void:
	var m = Model.new()
	var board = Board.new()
	board.font = SystemFont.new()
	board.size = Vector2(540,497)
	root.add_child(board)
	board.refresh(m)
	check(board.visible_ids().size()==41 and not board.buttons.shortcut.visible,"41 distinct field-guide cells")
	var coins: int = m.coins
	var seen := {}
	var current := 0
	for id in board.visible_ids():
		board.select_node(id)
		for i in board.definition(id).ranks.size():
			if i>0: board.shift_rank(1)
			var data: Dictionary = board.inspect_data()
			check(data.rank_index==i and not seen.has(data.id),"rank browsing visits one distinct rank")
			check(not data.name.is_empty() and not data.effect_text.is_empty(),"each rank has a name and effect")
			seen[data.id]=true
			if data.planned:
				check(board.next_id(id).is_empty(),"future ranks must never reach real purchases")
			else:
				current+=1
				var live: Dictionary = m.upgrade(data.id)
				check(data.cost.coins==live.cost and data.cost.fiber==live.get("fiber",0) and data.cost.resin==live.get("resin",0),"actual price must come from model")
	check(seen.size()==75 and current==14,"75 ranks, 14 current")
	board.select_node("gather")
	check(board.next_id("gather")=="gather1","first real offer")
	board.shift_rank(1)
	check(board.inspect_data().state=="preview" and board.next_id("gather")=="","inspecting future tier within a live cell cannot spend")
	board.shift_rank(-1)
	m.owned.append("gather1")
	board.refresh(m)
	check(board.inspect_data().id=="gather2" and board.next_id("gather")=="gather2","buying the first tier reveals the real next offer")
	board.shift_rank(-1)
	check(board.inspect_data().state=="owned" and board.next_id("gather")=="","owned tier cannot buy next tier")
	board.select_node("twin")
	check(board.inspect_data().cost.coins==29,"real twin price differs from design candidate 19")
	board.select_node("cascade")
	check(board.inspect_data().requirements.contains("已点亮花径灯"),"late capstone has world requirements")
	board.shift_rank(1)
	check(board.inspect_data().cost.resin==4 and board.inspect_data().effect_text.contains("3 株"),"second capstone tier has distinct price and behavior")
	check(m.coins==coins and m.owned==["gather1"],"inspection never alters live wallet or unlocks")
	board.update_lod(4.4)
	check(is_equal_approx(board.buttons.cascade.zoom_lod,4.4),"high zoom names follow real map magnification")
	for id in board.visible_ids():
		check(Rect2(Vector2.ZERO,board.size).has_point(board.point(id)),"every point inside overview")
	for i in board.visible_ids().size(): board.navigate(KEY_TAB)
	check(board.selected=="cascade","Tab traverses full catalog once")
	verify_wayfinding(board,m)
	board.free()
	print("Growth catalog checked 41 cells, 75 ranks, actual prices and preview purchase isolation; failures: ",failures)
	quit(1 if failures else 0)

func verify_wayfinding(board, model) -> void:
	model.owned.clear()
	model.coins = 0
	board.refresh(model)
	check(board.buttons.gather.state=="poor" and board.buttons.reach.state=="locked","available with short funds differs from missing skill")
	check(board.buttons.cascade.icon_opacity()<board.buttons.reach.icon_opacity() and board.buttons.reach.icon_opacity()<board.buttons.gather.icon_opacity(),"preview, locked and affordable-soon art are visibly distinct")
	model.coins = 78
	model.visited_meadow = true
	model.rose_sold = 6
	model.owned.assign(["meadow","gather1","gather2","bag1"])
	board.select_rank("reserve")
	var links: Dictionary = board.selected_links()
	check(links.size()==2 and links.twin=={"optional":false,"met":false} and links.meadow=={"optional":false,"met":true},"reserve highlights its missing twin and satisfied meadow, with no false branches")
	check(board.buttons.reserve.state=="locked" and board.buttons.gather.state=="max","wallet alone cannot light a purchase with missing conditions")
	check(board.buttons.bag.rank==1 and board.buttons.bag.icon_opacity()==1.0 and board.buttons.bag.state_caption().contains("1/2"),"partly trained art stays lit and shows owned ranks despite unmet price")
	board.select_rank("wings1")
	links = board.selected_links()
	check(links.size()==2 and links.gather.optional and links.gather.met and links.bag.met,"either/or routes that were learned are marked as contributing")
	model.owned.erase("bag1")
	board.refresh(model)
	check(board.selected_links().size()==1 and not board.selected_links().has("bag"),"already-met OR does not draw unused alternatives as blockers")
	board.select_rank("meadow")
	links = board.selected_links()
	check(links.gather.optional and links.gather.met and not links.bag.met,"counted ranks from the same skill collapse to one route")
	check(not links.has("beat") and not links.has("supply"),"the map uses the actual regional growth counter")
	model.owned.append("bag1")
	board.refresh(model)
	check(board.selected_links().size()==2 and board.selected_links().bag.met,"three purchased ranks fulfill the threshold even if two share a cell")
	board.select_rank("gather1")
	check(board.inspect_data().id=="gather1" and board.selected_links().is_empty(),"selecting an exact, earlier owned rank shows the correct path")
	board.select_rank("gather2")
	check(board.selected_links().is_empty(),"a previous rank in the same cell has no misleading self-arrow")
	board.select_rank("feast")
	check(board.selected_links().size()==7 and board.selected_links().cascade.optional and not board.selected_links().reserve.optional,"the banquet displays six choices toward a two-of-six goal")
	board.select_rank("not_a_rank")
	check(board.selected=="feast","obsolete rank ids are ignored safely")
	board.size = Vector2(525,283)
	board.select_rank("reserve")
	board.update_lod(1.78)
	var hidden_previews := 0
	for key in board.visible_ids():
		var node = board.buttons[key]
		if node._show_label():
			var label_center: Vector2 = node.CENTER+node.label_rect.get_center()/board.map_zoom
			check(node._has_point(label_center),"each visible label uses its painted box for hit testing")
		else:
			hidden_previews += 1
			check(node.planned and not board.selected_links().has(key),"only secondary planned names yield when crowded")
	check(hidden_previews>0 and board.buttons.reserve._show_label(),"the compact layout gives the actual goal and its prerequisites reading space")
