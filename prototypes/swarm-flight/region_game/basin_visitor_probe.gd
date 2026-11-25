extends SceneTree
## Checks the real Honey driver with an isolated save. Optional output is
## individual review stills of the ten cosmetic variants, not a recording.
const Scene = preload("res://region_game/main.tscn")
const Visitor = preload("res://region_game/basin_visitor.gd")
var checks := 0
var failures := 0
var output := ""

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL ", label)

func run() -> void:
	var private_save := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg.begins_with("--progress-file="): private_save = true
	if not private_save:
		printerr("Pass an isolated --progress-file=... for this fixture")
		quit(1)
		return
	if not output.is_empty(): DirAccess.make_dir_recursive_absolute(output)
	# Observe actual fresh views separately from explicitly exercised art variants.
	var sampled := {}
	for i in 96:
		var sampled_visitor := Visitor.new()
		root.add_child(sampled_visitor)
		sampled[Vector2i(int(sampled_visitor.is_fish), sampled_visitor.palette_index)] = true
		sampled_visitor.free()
	print("Fresh visitor draws: ", sampled.size(), " distinct combinations in 96 visits")
	var game = Scene.instantiate()
	root.add_child(game)
	game.test_mode = true # Focus changes during review must not open the pause sheet.
	game.set_process(false)
	game.restart_game()
	var visitor = game.world.basin_visitor
	check(game.mode == "play" and visitor is Visitor, "new game has a basin visitor")
	var original := Vector2i(int(visitor.is_fish), visitor.palette_index)
	var identity: int = visitor.get_instance_id()
	var arrival: Vector2 = game.model.p
	for pair in [[game.model.HUB_SHOP, "open_shop", "shop", "close_shop"], [game.model.HUB_TREE, "open_tree", "tree", "close_tree"], [arrival, "pause_game", "pause", "start_game"]]:
		game.model.p = pair[0]
		game.call(pair[1])
		check(game.mode == pair[2], "opened " + pair[2])
		game.call(pair[3])
		check(game.mode == "play", "returned from " + pair[2])
		await process_frame
	game.model.p = arrival
	check(game.world.basin_visitor == visitor and original == Vector2i(int(visitor.is_fish), visitor.palette_index), "shop, book and pause keep the same visitor")
	var wallet: Dictionary = game.model.to_payload()
	# Use the normal viewport transform, including the scale at 960 × 600.
	var shore: Rect2 = game.world.get_global_transform_with_canvas() * Rect2(13,632,158,91)
	var hud_rect: Rect2 = game.ui.hud_status.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, game.ui.hud_status.size)
	check(not hud_rect.intersects(shore), "courtyard HUD clears the water bowl")
	for fish: bool in [true, false]:
		visitor.is_fish = fish
		for colour in Visitor.COLOURS.size():
			visitor.palette_index = colour
			visitor.apply_appearance()
			visitor.pose(0, true)
			check(visitor.material.get_shader_parameter("pigment").is_equal_approx(Visitor.COLOURS[colour]), "paint matches selected pigment")
			var still: Transform2D = visitor.transform
			visitor.pose(2.0, true)
			check(visitor.transform.is_equal_approx(still), "reduced motion stays still")
			visitor.pose(1.4, false)
			check(not visitor.transform.is_equal_approx(still), "swim or breath changes shape")
			if fish:
				check(absf(visitor.material.get_shader_parameter("tail_bend")) > .01, "moving fish bends tail")
				visitor.pose(5.6, false)
				var rest: Transform2D = visitor.transform
				visitor.pose(6.4, false)
				check(visitor.transform.is_equal_approx(rest) and absf(visitor.material.get_shader_parameter("tail_bend")) < .001, "fish stops in the water")
			if not output.is_empty():
				game.world.set_process(false)
				visitor.pose(0.9, false)
				await RenderingServer.frame_post_draw
				var name := "%s-%d.png" % ["fish" if fish else "frog", colour]
				check(root.get_texture().get_image().save_png(output.path_join(name)) == OK, "native still saved")
	await process_frame
	check(wallet == game.model.to_payload(), "visitors never change saved state")
	game.model.p = game.model.HUB_DEPART
	game.request_transition("pond")
	check(game.transition_candidate != null, "ordinary departure was accepted in " + game.mode)
	if game.transition_candidate == null:
		quit(1)
		return
	game._advance_transition(10)
	check(game.model.area == "pond" and game.world.basin_visitor == null, "native departure removes the basin visitor")
	check(is_equal_approx(game.ui.hud_status.position.x, 24), "field HUD is in its ordinary position")
	game.request_transition("hub")
	game._advance_transition(10)
	check(game.model.at_home() and game.world.basin_visitor != null and game.world.basin_visitor.get_instance_id() != identity, "committed return creates a new visit")
	print("BASIN VISITORS ",checks," checks, ",failures," failures")
	game.free()
	# Allow the audio driver to release its stopped looping streams.
	await create_timer(.35).timeout
	quit(1 if failures else 0)
