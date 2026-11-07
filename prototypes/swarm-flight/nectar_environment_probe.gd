extends SceneTree
## Fixed native views for before/after art review. Deliberately positioned fixtures,
## never represented as a player route, playtest, or proof of visual acceptance.
const Scene = preload("res://nectar_harvest.tscn")
var output := ""
var game
var views: Array[Dictionary] = []

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var isolated := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): output = arg.trim_prefix("--capture-dir=")
		if arg.begins_with("--progress-file="): isolated = true
	if output.is_empty() or not isolated or DisplayServer.get_name() == "headless":
		push_error("Native art capture requires explicit capture and isolated save paths")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	game = Scene.instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.mode = "play"
	game.ui.show_mode("play")
	game.model.owned.assign(["gather1", "bag1", "wings1", "meadow", "shortcut"])
	game.model.energy = game.model.max_energy()
	var fixtures := [
		{"id":"hub", "area":"hub", "p":Vector2(1015,490)},
		{"id":"hub-shop", "area":"hub", "p":Vector2(360,520)},
		{"id":"hub-growth", "area":"hub", "p":Vector2(740,485)},
		{"id":"hub-full-shelves", "area":"hub", "p":Vector2(360,520), "sold":36},
		{"id":"hub-reserve-sealed", "area":"hub", "p":Vector2(539,500), "sold":36, "complete":true},
		{"id":"pond-upper-route", "area":"pond", "p":Vector2(1030,225)},
		{"id":"pond-thicket-edge", "area":"pond", "p":Vector2(765,405)},
		{"id":"meadow-upper-route", "area":"meadow", "p":Vector2(2450,285)},
		{"id":"pond-entry", "area":"pond", "p":Vector2(470,575)},
		{"id":"pond-far", "area":"pond", "p":Vector2(1620,575)},
		{"id":"pond-shortcut", "area":"pond", "p":Vector2(1460,265)},
		{"id":"pond-return-view", "area":"pond", "p":Vector2(1320,575)},
		{"id":"pond-base-bag", "area":"pond", "p":Vector2(820,560), "bag":0},
		{"id":"pond-large-bag", "area":"pond", "p":Vector2(820,560), "bag":2},
		{"id":"meadow-entry", "area":"meadow", "p":Vector2(1900,575)},
		{"id":"meadow-canopy-overlap", "area":"meadow", "p":Vector2(2760,550)},
		{"id":"meadow-rain", "area":"meadow", "p":Vector2(2760,580)},
		{"id":"meadow-shelter", "area":"meadow", "p":Vector2(2760,650)},
		{"id":"meadow-shortcut", "area":"meadow", "p":Vector2(3000,400)},
		{"id":"meadow-return-bearing", "area":"meadow", "p":Vector2(3350,575)}
	]
	for size in [Vector2i(1280,800),Vector2i(960,600)]:
		root.size = size
		for fixture in fixtures:
			game.model.owned.assign(["gather1", "wings1", "meadow", "shortcut"])
			if fixture.get("bag",1) >= 1: game.model.owned.append("bag1")
			if fixture.get("bag",1) == 2: game.model.owned.append("bag2")
			game.model.completed = fixture.get("complete",false)
			if game.model.completed: game.model.owned.append("reserve")
			game.model.sold_total = fixture.get("sold",0)
			game.model.area = fixture.area
			game.model.phase = "home" if fixture.area == "hub" else "field"
			game.model.p = fixture.p
			game.model.v = Vector2.ZERO
			game.model.update_camera()
			game._load_world()
			game.world.set_process(false)
			game.world.clock = 2.0
			game.ui.refresh()
			game.world.queue_redraw()
			for i in 3: await process_frame
			await RenderingServer.frame_post_draw
			var name: String = "%s-%d.png" % [fixture.id,size.x]
			var err := root.get_texture().get_image().save_png(output.path_join(name))
			if err != OK:
				push_error("Cannot save "+name)
				quit(1)
				return
			views.append({"file":name,"area":fixture.area,"p":[fixture.p.x,fixture.p.y],"camera_x":game.model.camera_x,"window":[size.x,size.y],"clock":2.0})
	var file := FileAccess.open(output.path_join("views.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"classification":"developer-positioned native art fixtures; not player evidence","views":views},"\t"))
	file.close()
	print("NECTAR ENVIRONMENT: %d native fixed views saved" % views.size())
	game.queue_free()
	await process_frame
	await process_frame
	quit(0)
