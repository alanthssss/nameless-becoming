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
	board.free()
	print("Growth catalog checked 41 cells, 75 ranks, actual prices and preview purchase isolation; failures: ",failures)
	quit(1 if failures else 0)
