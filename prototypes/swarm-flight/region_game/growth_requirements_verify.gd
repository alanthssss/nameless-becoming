extends SceneTree
const StationEntry = preload("res://region_game/station_entry_probe.gd")
## The exact wallet and missing prerequisite in the reported journal screenshot.
const Scene = preload("res://region_game/main.tscn")
var game
var checks := 0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL "+message)

func key(code: Key) -> void:
	for down in [true,false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.keycode = code
		event.pressed = down
		root.push_input(event,true)
		await process_frame

func pad(code: JoyButton) -> void:
	for down in [true,false]:
		var event := InputEventJoypadButton.new()
		event.button_index = code
		event.pressed = down
		root.push_input(event,true)
		await process_frame

func click(button: Button) -> void:
	for down in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = button.get_global_transform_with_canvas()*(button.size*.5)
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		root.push_input(event,true)
		await process_frame

func run() -> void:
	game = Scene.instantiate()
	root.add_child(game)
	await process_frame
	game.saved_path = OS.get_temp_dir().path_join("honey-requirements-%d.json" % OS.get_process_id())
	game.save_blocked = false
	game.restart_game()
	var ui = game.ui
	var board = ui.board
	var m = game.model
	m.coins = 78
	m.materials = {"fiber":1,"resin":1}
	m.owned.assign(["gather1","bag1","bag2","meadow"])
	m.visited_meadow = true
	m.rose_sold = 6
	m.p = m.HUB_TREE
	await key(KEY_E)
	await StationEntry.settle(game)
	check(game.mode=="tree" and not ui.skill_note.visible and not ui.tree_progress.visible and not ui.tree_footer.visible,"opening shows the map without a note, counters or instructions")
	check(not ui.tree_fiber.get_parent().visible and not ui.tree_coins.get_parent().visible and not ui.tree_resin.get_parent().visible,"wallet stays out of the unselected map")
	board.select_rank("reserve")
	await process_frame
	await key(KEY_I)
	check(not ui.skill_note.visible,"I dismisses the selected note")
	await pad(JOY_BUTTON_BACK)
	check(ui.skill_note.visible and ui.tree_coins.get_parent().visible and not ui.tree_fiber.get_parent().visible,"controller reopens just the note and its relevant currency")
	var condition = ui.conditions
	var rows: Array = condition.shown_rows
	check(rows.size()==4 and rows[0].targets==["twin"] and not rows[0].met,"single missing skill leads the reserve list")
	check(rows.slice(1).all(func(r): return r.met),"open, visit and six sold have distinct completed states")
	check(ui.buy_button.disabled and not ui.buy_button.visible and ui.detail_costs.coin.text=="60","sufficient gold never masks the missing skill")
	check(ui.cost_stock.coin.text=="金币" and "持有 78" in ui.cost_stock.coin.get_parent().tooltip_text,"the actual reserve price and current holdings appear together")
	check(not ui.detail_level.visible and not ui.detail_title.get_parent().get_parent().get_node("CatalogRankPicker").visible,"single-rank page omits both redundant counters")
	check(condition.links.size()==2 and condition.links[1].get_meta("group","")=="completed","reserve initially offers its one action and completed disclosure")
	await click(condition.links[1])
	check(condition.show_completed and condition.links.any(func(b): return "开往紫花地" in b.text),"pointer reveals completed links")
	await key(KEY_ENTER)
	check(not condition.show_completed and condition.links.size()==2,"folding preserves focus and keyboard activation")
	var wallet: Dictionary = m.to_payload().duplicate(true)
	var origin: Dictionary = ui.growth_map.capture_view()
	var link: Button = condition.links[0]
	check("双簇采蜜" in link.text and "→" in link.text,"visible prerequisite is a named destination")
	await click(link)
	check(board.inspect_data().id=="twin" and ui.return_to_goal.visible and "备好花蜜" in ui.return_to_goal.text,"pointer opens the exact dependency with named way back")
	var twin_requirements: Array = condition.shown_rows
	check(twin_requirements.any(func(r): return r.targets==["gather2"] and "第 2 档" in r.text),"multi-rank dependency identifies exact second rank")
	check(ui.cost_stock.resin.text=="树脂" and "持有 1" in ui.cost_stock.resin.get_parent().tooltip_text and ui.detail_costs.resin.text=="3","multi-material price and stock label")
	check(twin_requirements.any(func(r): return r.kind=="cost" and "还差 2 树脂" in r.text),"three resin recipe and one resin held explain the deficit")
	check(not condition.show_remaining and condition.links.any(func(b): return b.get_meta("group","")=="remaining"),"other outstanding work collapses behind an actionable summary")
	await pad(JOY_BUTTON_LEFT_STICK)
	await pad(JOY_BUTTON_LEFT_STICK)
	await pad(JOY_BUTTON_A)
	check(condition.show_remaining,"controller opens remaining requirements")
	await pad(JOY_BUTTON_A)
	condition.links[0].grab_focus()
	await key(KEY_ENTER)
	check(board.inspect_data().id=="gather2","keyboard follows second-rank prerequisite")
	await key(KEY_ESCAPE)
	check(game.mode=="tree" and board.inspect_data().id=="twin","back unwinds one dependency")
	await pad(JOY_BUTTON_B)
	var restored: Dictionary = ui.growth_map.capture_view()
	var same_center := Vector2(restored.x,restored.y).is_equal_approx(Vector2(origin.x,origin.y))
	check(restored.rank=="reserve" and restored.zoom==origin.zoom and same_center,"controller restores original goal, exact rank, framing and zoom")
	await pad(JOY_BUTTON_LEFT_STICK)
	await pad(JOY_BUTTON_A)
	check(board.inspect_data().id=="twin" and m.to_payload()==wallet,"controller follows link without changing inventory or buying")
	await pad(JOY_BUTTON_B)
	board.select_rank("wings1")
	check(condition.shown_rows.any(func(r): return r.kind=="skill" and r.met and r.targets==["gather1","bag1"]),"either prerequisite satisfies wings")
	board.select_rank("meadow")
	# Show the genuine live counter on a fresh profile rather than the plan's list.
	m.owned.clear()
	ui.refresh()
	var group: Dictionary = condition.shown_rows[0]
	check(not group.met and group.targets==m.MEADOW_GROWTH_RANKS and "0 / 3" in group.text,"actual counted ranks and current progress")
	await key(KEY_F)
	await key(KEY_ENTER)
	check(condition.links.size()==1+m.MEADOW_GROWTH_RANKS.size(),"optional group opens every counted exact rank")
	await key(KEY_F)
	await key(KEY_ENTER)
	check(board.inspect_data().id==m.MEADOW_GROWTH_RANKS[0],"keyboard follows expanded candidate")
	await key(KEY_ESCAPE)
	board.select_rank("feast")
	check(condition.shown_rows.any(func(r): return r.targets.size()==6 and "0 / 2" in r.text),"planned banquet correctly shows two from six")
	check(condition.shown_rows.any(func(r): return "点亮花径灯" in r.text) and ui.buy_button.disabled,"planned world gate and locked purchase")
	var examined := 0
	var constraints_match := true
	for id in board.ranks_by_id:
		board.select_rank(id)
		examined += 1
		if board.inspect_data().state=="next":
			var missing: bool = not condition.shown_rows.all(func(r): return r.met)
			if missing==m.can_buy(id): constraints_match = false
	check(examined==75 and constraints_match,"all 75 pages render and every available next rank uses its actual purchase conditions")
	await key(KEY_ESCAPE)
	check(game.mode=="play","back at root closes journal")
	# Use a valid fresh run for the actual persisted purchase.
	game.restart_game()
	m = game.model
	m.coins = 78
	m.p = m.HUB_TREE
	await key(KEY_E)
	await StationEntry.settle(game)
	board.select_rank("beat")
	await key(KEY_F)
	await key(KEY_SPACE)
	check(board.inspect_data().id=="gather1" and m.coins==78,"Space follows a prerequisite without buying it")
	await key(KEY_ENTER)
	check("gather1" in m.owned and m.coins==74,"first deliberate Enter after the Space jump buys exactly one rank")
	await key(KEY_ESCAPE)
	game.queue_free()
	# Even under fixed FPS the audio driver drains its stream buffers on wall time.
	var drain_until := Time.get_ticks_msec()+350
	while Time.get_ticks_msec()<drain_until:
		OS.delay_msec(10)
		await process_frame
	print("Growth requirement navigation: %d checks, %d failures" % [checks,failures])
	quit(int(failures>0))
