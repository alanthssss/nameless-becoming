## Explicit funded developer UI fixtures; never player evidence.
extends SceneTree
const Scene = preload("res://nectar_harvest.tscn")
var game
var output := "user://nectar-style-probe"
var checks=0
var failures=[]
func _initialize(): call_deferred("run")
func frames(n):
	for i in n: await process_frame
func check(ok,words):
	checks+=1
	if not ok: failures.append(words);push_error(words)
func capture(name):
	await frames(4)
	RenderingServer.force_draw()
	check(root.get_texture().get_image().save_png(output.path_join(name+".png"))==OK,"capture "+name)
func click(b):
	var at=b.get_global_rect().get_center()
	var m=InputEventMouseMotion.new();m.position=at;m.global_position=at
	root.push_input(m,true)
	await frames(2)
	for down in [true,false]:
		var e=InputEventMouseButton.new();e.position=at;e.global_position=at;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down
		root.push_input(e,true)
		await frames(2)
func mode(value):
	game.mode=value;game.ui.show_mode(value);await frames(4)
func bounds():
	var visible=[]
	for b in game.ui.board.buttons.values():
		if b.visible: visible.append(b)
	for b in visible:
		check(Rect2(0,0,1280,800).encloses(b.get_global_rect()),"node inside canvas "+b.kind)
		check(not b.get_global_rect().intersects(game.ui.detail_card.get_global_rect()),"detail does not cover "+b.kind)
		for other in visible:
			if b!=other:check(not b.get_global_rect().intersects(other.get_global_rect()),"nodes do not overlap "+b.kind+" "+other.kind)
	check(Rect2(0,0,1280,800).encloses(game.ui.buy_button.get_global_rect()),"buy stays on page")
func run():
	var isolated := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): output=arg.trim_prefix("--capture-dir=")
		if arg.begins_with("--progress-file="):
			isolated = true
			DirAccess.make_dir_recursive_absolute(arg.trim_prefix("--progress-file=").get_base_dir())
	if not isolated or DisplayServer.get_name()=="headless": quit(2); return
	DirAccess.make_dir_recursive_absolute(output)
	var atlas: Image = preload("res://art/nectar-resource-icons.png").get_image()
	check(atlas.get_size()==Vector2i(1254,1254),"resource atlas retains inspected dimensions")
	for at in [Vector2i(0,0),Vector2i(625,625),Vector2i(1253,0),Vector2i(0,1253),Vector2i(1253,1253),Vector2i(625,0),Vector2i(625,1253)]:
		check(atlas.get_pixelv(at).a==0.0,"transparent resource padding "+str(at))
	game=Scene.instantiate();root.add_child(game);await frames(10)
	game.start_game();game.model.p=game.model.HUB_TREE
	await mode("tree")
	await capture("style-initial")
	await click(game.ui.board.buttons.bag)
	check(game.ui.board.selected=="bag","mouse selects painted icon")
	game.model.owned.assign(["gather1","gather2","reach","bag1","meadow"])
	game.model.coins=100;game.model.materials={"fiber":10,"resin":10};game.ui.refresh()
	game.ui.board.select_node("beat");await frames(3);bounds()
	await capture("style-expanded")
	await mode("play");await capture("style-hud")
	await mode("regions");await capture("style-regions")
	await mode("pause");await capture("style-pause")
	await mode("shop");await capture("style-shop")
	await mode("settings");await capture("style-settings")
	await mode("journal");await capture("style-journal")
	await mode("complete");game.ui.show_toast("花蜜，备好了",4);check(not game.ui.toast_panel.visible,"completion avoids duplicate overlay");await capture("style-complete")
	root.size=Vector2i(960,600)
	await mode("tree");game.ui.board.select_node("reserve");await frames(3);bounds();await capture("style-small")
	await mode("regions");await capture("style-regions-small")
	await mode("pause");await capture("style-pause-small")
	var file=FileAccess.open(output.path_join("style-result.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"classification":"native developer UI fixtures; funded snapshot, not player evidence"},"\t"));file.close()
	print("STYLE VERIFIED ",checks," / ",failures.size())
	game.queue_free();await frames(3);quit(0 if failures.is_empty() else 1)
