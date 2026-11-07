extends SceneTree
## Isolated developer fixtures for committed feedback and ephemeral home recaps.
const Model = preload("res://nectar_harvest_model.gd")
const Scene = preload("res://nectar_harvest.tscn")
var game
var checks := 0
var failures := 0
var save_path := ""

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+label)

func grown_model():
	var model = Model.new()
	model.coins = 1000
	model.materials = {"fiber":100,"resin":100}
	for id in ["gather1","bag1","wings1","gather2","bag2","meadow"]:
		check(model.buy(id),"fixture buys "+id)
	model.visited_meadow = true
	model.events.clear()
	return model

func install(model) -> void:
	game.model = model
	game._load_world()
	game.mode = "play"
	game.home_return_summary = ""
	game.home_sale_summary = ""
	game.ui.show_mode("play")
	game.ui.refresh()

func deliver_events() -> void:
	game.consume_events(game.model.events.duplicate(true))
	game.model.events.clear()
	game.ui.refresh()

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--progress-file="):
			save_path = arg.trim_prefix("--progress-file=")
	if not save_path.is_absolute_path() or "journey" in save_path.get_file():
		print("FAIL: explicit isolated absolute progress-file required")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(save_path.get_base_dir())
	game = Scene.instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	check(game.home_return_summary.is_empty(),"cold entry invents no trip summary")
	root.size = Vector2i(960,600)
	var schema: Array = Model.new().to_payload().keys()
	for pair in [[5,3],[1,1],[0,0],[2,4],[0,5],[6,0]]:
		var model = grown_model()
		check(model.transition_to("meadow"),"fixture departs through normal transition")
		model.events.clear()
		model.cargo = {"blue":pair[0],"rose":pair[1]}
		model.materials = {"fiber":7,"resin":3}
		model.energy = .01
		var old_coins: int = model.coins
		var old_owned: Array = model.owned.duplicate()
		model.step(.1,Vector2.ZERO,false,false)
		var event: Dictionary = model.events[-1]
		var blue := int(pair[0]/2)
		var rose := int(pair[1]/2)
		check(event.kind == "rescue" and event.amount == pair[0]+pair[1]-blue-rose,"rescue amount remains total lost")
		check(event.cargo == {"blue":blue,"rose":rose} and event.lost == {"blue":pair[0]-blue,"rose":pair[1]-rose},"per-colour rescue ledger "+str(pair))
		check(event.materials == {"fiber":7,"resin":3} and model.materials == event.materials,"rescue preserves materials")
		check(model.coins == old_coins and model.owned == old_owned and model.at_home(),"rescue preserves bank and growth")
		install(model)
		deliver_events()
		check("蓝花蜜 %d" % blue in game.home_return_summary and "紫花蜜 %d" % rose in game.home_return_summary,"recap exposes retained cargo")
		check("纤维 7" in game.home_return_summary and "树脂 3" in game.home_return_summary,"recap exposes secured materials")
		check("一半" not in game.toast_text,"odd rescue avoids inaccurate half-total claim")
		game.model.p = Model.HUB_SHOP
		game.open_shop()
		check(game.ui.shop_recap.visible,"shop reopens the current rescue result")
		var remembered: String = game.home_return_summary
		game.sell_cargo()
		check(game.home_return_summary == remembered,"sale preserves witnessed rescue result")
		check(game.model.to_payload().keys() == schema,"feedback adds no save keys")
		game.close_shop()
		game.model.p = Model.HUB_SHOP
		game.open_shop()
		check(game.ui.shop_recap.text.contains(remembered),"same-visit shop reopening preserves recap")
		await process_frame
		await process_frame
		check(game.ui.shop_recap.get_global_rect().end.y < game.ui.leave_button.get_global_rect().position.y,"recap fits above shop exit at small size")
		check(game.ui.leave_button.get_global_rect().end.y <= game.ui.size.y,"small-size shop action stays inside viewport")

	var model = grown_model()
	model.transition_to("pond")
	model.events.clear()
	model.cargo = {"blue":5,"rose":3}
	model.materials = {"fiber":7,"resin":3}
	model.p = Model.POND_ENTRY
	install(model)
	var candidate = Model.new()
	check(candidate.restore_payload(model.to_payload()) and candidate.transition_to("hub"),"normal return creates valid candidate")
	check(game.commit_candidate(candidate),"normal return commits")
	check("本次带回 · 蓝花蜜 5 · 紫花蜜 3" in game.home_return_summary,"normal return shows both quantities")
	game.model.p = Model.HUB_SHOP
	game.open_shop()
	var before_sale: int = game.model.coins
	game.sell_cargo()
	check(game.model.coins == before_sale+14 and game.model.cargo_total() == 0,"sale keeps existing prices")
	check("蓝花蜜 5" in game.home_sale_summary and "紫花蜜 3" in game.home_sale_summary and "14 金币" in game.home_sale_summary,"sale receipt shows quantities and actual gain")
	var receipt: String = game.home_sale_summary
	game.sell_cargo()
	check(game.home_sale_summary == receipt and game.model.coins == before_sale+14,"empty repeated sale cannot duplicate receipt or currency")
	game.close_shop()
	game.model.p = Model.HUB_DEPART
	candidate = Model.new()
	candidate.restore_payload(game.model.to_payload())
	candidate.transition_to("pond")
	var blocked := save_path+"-directory"
	DirAccess.make_dir_recursive_absolute(blocked)
	game.saved_path = blocked
	check(not game.commit_candidate(candidate) and game.home_sale_summary == receipt,"failed departure retains home recap")
	game.saved_path = save_path
	check(game.commit_candidate(candidate),"retry departure commits")
	check(game.home_return_summary.is_empty() and game.home_sale_summary.is_empty(),"successful departure clears recap")

	install(grown_model())
	game.model.cargo = {"blue":1,"rose":1}
	game.model.p = Model.HUB_SHOP
	game.open_shop()
	game.saved_path = blocked
	var stable: Dictionary = game.model.to_payload()
	game.sell_cargo()
	check(game.model.to_payload() == stable and game.home_sale_summary.is_empty(),"failed disk sale leaves balance and receipt unchanged")
	check("未能写入" in game.toast_text,"failed disk sale reports failure")
	game.saved_path = save_path

	install(Model.new())
	game.model.coins = 1000
	game.model.materials = {"fiber":100,"resin":100}
	var expected := {
		"gather1":"1.8 → 1.2", "gather2":"1.2 → 0.8", "reach":"100 → 155",
		"twin":"两朵花", "bag1":"6 → 10", "wings1":"36 → 50",
		"bag2":"10 → 16", "wings2":"50 → 70", "meadow":"紫花地已开放",
		"shortcut":"近道往返", "market":"25%", "reserve":"花蜜储备完成", "beat":"2 → 1 次"}
	var plan := ["gather1","bag1","wings1","gather2","reach","twin","bag2","wings2","meadow","shortcut","market","beat","reserve"]
	for id in plan:
		if id in ["market","reserve"]:
			game.model.visited_meadow = true
			game.model.rose_sold = 6
			game.model.sold_total = 6
		game.mode = "tree"
		game.ui.show_mode("tree")
		var definition: Dictionary = game.model.upgrade(id)
		stable = game.model.to_payload()
		game.saved_path = blocked
		game.buy_upgrade(id)
		check(game.model.to_payload() == stable and "未能写入" in game.toast_text,"failed purchase does not claim success "+id)
		game.saved_path = save_path
		game.buy_upgrade(id)
		check(id in game.model.owned and expected[id] in game.toast_text,"purchase confirms active effect "+id)
		check("花费 %d 金币" % definition.cost in game.toast_text,"purchase confirms actual coin cost "+id)
		for kind in ["fiber","resin"]:
			if int(definition.get(kind,0)) > 0:
				check("%d %s" % [definition[kind],"纤维" if kind == "fiber" else "树脂"] in game.toast_text,"purchase confirms material cost "+id)
		if id == "reserve":
			check(game.ui.menu.visible and "花蜜储备完成" in game.ui.menu_body.text and "花费 60 金币" in game.ui.menu_body.text and not game.ui.toast_panel.visible,"completion card shows actual result and paid price without duplicate toast")
		else:
			check(game.ui.toast_panel.visible,"growth result remains visible "+id)
		await process_frame
		await process_frame
		if game.mode == "tree":
			check(not game.ui.toast_panel.get_global_rect().intersects(game.ui.buy_button.get_global_rect()),"growth feedback does not cover purchase "+id)
			check(game.ui.toast_panel.get_global_rect().end.y <= game.ui.size.y,"growth feedback remains inside viewport "+id)
		var paid: int = game.model.coins
		game.buy_upgrade(id)
		check(game.model.coins == paid,"repeated purchase cannot debit again "+id)

	game.home_return_summary = "fixture old return"
	game.home_sale_summary = "fixture old sale"
	game.restart_game()
	check(game.home_return_summary.is_empty() and game.home_sale_summary.is_empty(),"successful fresh game clears all recaps")
	game.home_return_summary = "fixture retain on failure"
	game.saved_path = blocked
	game.restart_game()
	check(game.home_return_summary == "fixture retain on failure","failed fresh game keeps current recap")
	game.saved_path = save_path
	var cold = Scene.instantiate()
	root.add_child(cold)
	await process_frame
	cold.set_process(false)
	check(cold.home_return_summary.is_empty() and cold.home_sale_summary.is_empty() and not cold.ui.shop_recap.visible,"cold reload does not fabricate historical result")
	cold.queue_free()
	game.queue_free()
	await process_frame
	print("NECTAR RETURN FEEDBACK: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
