extends SceneTree
## Boundary fixtures use a private save. Optional native stills show each cue at play scale.
const Game = preload("res://region_game/main.tscn")
var checks := 0
var failures := 0
var output := ""

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL " + label)

func still(label: String) -> void:
	if output.is_empty(): return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(label + ".png")) == OK, label)

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--stills="): output = arg.trim_prefix("--stills=")
	if not output.is_empty(): DirAccess.make_dir_recursive_absolute(output)
	var game = Game.instantiate()
	root.add_child(game)
	game.set_process(false)
	game.saved_path = OS.get_temp_dir().path_join("home-warning-%s.json" % OS.get_process_id())
	game.save_blocked = false
	game.restart_game()
	game.reduced_motion = false
	var model = game.model
	model.coins = 50
	model.materials.fiber = 2
	check(model.buy("gather1") and model.buy("wings1"),"funded wing rank can have a fractional warning threshold")
	game.request_transition("pond")
	game._advance_transition(3.0)
	var field = model.field
	var dial = game.ui.energy_dial
	var entry: Vector2 = field.layout.nodes[0].p
	field.p = field.layout.nodes[1].p
	field.departed = true
	# An upgrade makes several cutoffs fractional. The model, dial and paper
	# must cross on that actual value, even when the rounded number stays put.
	var limits := [5.0/6.0,2.0/3.0,.5,.25,.125]
	var inks := {}
	var rested_ink: Color = dial.paper_wash.gradient.colors[0]
	for i in limits.size():
		var cutoff: float = model.max_energy()*float(limits[i])
		field.energy = cutoff+.001
		model._sync_field()
		game.ui.refresh()
		check(dial.energy_stage == i and model.energy_stage() == i,"above portrait cutoff %d" % i)
		inks[dial.paper_wash.gradient.colors[0]] = true
		field.energy = cutoff
		model._sync_field()
		check(model.energy_stage() == i+1,"exact boundary uses lower portrait %d" % i)
		field.energy = cutoff+.001
		model._sync_field()
		game._process(.02)
		check(dial.energy_stage == i+1 and model.energy_stage() == i+1,"actor and HUD advance together at cutoff %d" % i)
	inks[dial.paper_wash.gradient.colors[0]] = true
	check(inks.size() == 6,"each of the six portraits has a different paper wash")
	field.energy = 12.51
	model._sync_field()
	model.update_camera()
	game.ui.refresh()
	check(not dial.warning,"over one quarter has no warning")
	game._process(.02)
	check(dial.warning and dial.is_processing(),"same rounded energy crosses the threshold and starts the pulse")
	var start: float = dial.pulse_time
	dial._process(.3)
	check(dial.pulse_time > start,"pulse advances independently of HUD number updates")
	await still("池岸-低体力返程方向")
	game.reduced_motion = true
	game.ui.refresh()
	check(dial.warning and not dial.is_processing(),"simplified animation retains a steady warning")
	game.pause_game()
	check(not dial.warning and not dial.is_processing(),"pause clears the warning")
	game.start_game()
	check(dial.warning and not dial.is_processing(),"resume restores the steady warning")
	field.p = entry
	field.energy = .1
	model._sync_field()
	model.update_camera()
	game.ui.refresh()
	await still("木牌-最后一点体力")
	var e := InputEventKey.new()
	e.keycode = KEY_E
	e.physical_keycode = KEY_E
	e.pressed = true
	root.push_input(e,true)
	check(game.mode == "transition" and not dial.warning,"return press immediately clears the field warning")
	var focus: Vector2 = game.ui.transition_layer.shade_material.get_shader_parameter("focus")
	check(focus.is_equal_approx((field.p - model.camera_offset) * model.MeadowLayout.FIELD_ZOOM),"iris is centred on the bee at the sign")
	game._advance_transition(3.0)
	check(model.at_home() and model.energy == model.max_energy() and not dial.warning,"safe arrival restores energy and leaves the HUD calm")
	check(dial.energy_stage == 0 and model.energy_stage() == 0 and dial.paper_wash.gradient.colors[0] == rested_ink,"return restores the rested portrait and its cool wash")
	await still("庭院-平安带回")
	game.queue_free()
	await process_frame
	await process_frame
	print("Home warning: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
