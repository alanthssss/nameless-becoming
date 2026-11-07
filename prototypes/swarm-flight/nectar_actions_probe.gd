extends SceneTree
## Developer-positioned native fixtures plus ordinary action input; not a novice playtest.
const Scene = preload("res://nectar_harvest.tscn")
var game
var output := ""
var checks := 0
var failures: Array[String] = []

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)
func frames(n: int) -> void:
	for i in n: await process_frame
func key(code: int, pressed: bool) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = pressed
	root.push_input(e,true)
func mouse(pressed: bool, at: Vector2) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_RIGHT
	e.position = at-Vector2(game.model.camera_x,0)
	e.global_position = e.position
	e.pressed = pressed
	root.push_input(e,true)
func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(label+".png")) == OK,"save "+label)
func reset_carrier() -> Dictionary:
	game.release_controls()
	var m = game.model
	var carrier: Dictionary = m.creatures[0]
	carrier.state = "patrol"
	carrier.hits = 0
	carrier.stun = 0.0
	carrier.pos = carrier.anchor
	m.p = carrier.pos-Vector2(85,0)
	m.v = Vector2.ZERO
	m.face = Vector2.LEFT
	m.energy = m.max_energy()
	m.pulse_left = 0.0
	m.update_camera()
	return carrier
func input_combinations() -> void:
	var carrier := reset_carrier()
	game.model.face = Vector2.RIGHT
	key(KEY_SPACE,true)
	key(KEY_Q,true)
	await frames(2)
	check(game.model.charging and carrier.hits == 0,"same-frame SPACE takes precedence over a fresh Q press")
	carrier = reset_carrier()
	game.model.face = Vector2.RIGHT
	var energy_before: float = game.model.energy
	var time_before: float = game.model.field_time
	key(KEY_Q,true)
	mouse(true,game.model.p-Vector2(90,0))
	await frames(2)
	check(carrier.hits == 0 and is_equal_approx(game.model.energy,energy_before-.6*(game.model.field_time-time_before)),"same-frame right mouse aim wins over a valid Q target and adds no empty cost")
	carrier = reset_carrier()
	key(KEY_D,true)
	key(KEY_Q,true)
	await frames(2)
	check(carrier.hits == 1,"fresh Q follows this frame's movement direction")
	carrier = reset_carrier()
	game.model.face = Vector2.RIGHT
	key(KEY_Q,true)
	key(KEY_Q,false)
	await frames(2)
	check(carrier.hits == 1 and not game.down(KEY_Q),"quick Q press/release is one action without a held key")
	carrier = reset_carrier()
	mouse(true,carrier.pos)
	game.pause_game()
	check(not game.mouse_pulse and not game.pulse_requested and not game.mouse_pulse_requested,"pause clears held and pending wing actions")
	game.start_game()
	await frames(2)
	check(carrier.hits == 0,"resume never fires an abandoned wing press")
func run() -> void:
	var isolated := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): output = arg.trim_prefix("--capture-dir=")
		if arg.begins_with("--progress-file="): isolated = true
	if not isolated or output.is_empty() or DisplayServer.get_name() == "headless":
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	game = Scene.instantiate()
	root.add_child(game)
	await frames(4)
	game.start_game()
	for size in [Vector2i(1280,800),Vector2i(960,600)]:
		root.size = size
		game.release_controls()
		game.model = game.Model.new()
		var m = game.model
		m.p = m.HUB_DEPART
		check(m.transition_to("pond"),"fixture departs with normal first-trip population")
		m.area = "pond"
		m.phase = "field"
		m.p = m.flowers[0].pos+Vector2(-55,-6)
		m.update_camera()
		game._load_world()
		game.ui.refresh()
		await frames(5)
		key(KEY_E,true)
		await frames(35)
		check(not m.harvesting_ids.is_empty(),"held E actively selects a flower")
		await capture("harvest-"+str(size.x))
		await frames(85)
		key(KEY_E,false)
		check(m.cargo_total() == 1,"held E finishes one flower")
		await capture("collected-"+str(size.x))
		m.p = m.creatures[0].pos+Vector2(-85,0)
		m.v = Vector2.ZERO
		m.face = Vector2.RIGHT
		m.energy = m.max_energy()
		m.update_camera()
		await frames(4)
		await capture("material-ready-"+str(size.x))
		mouse(true,m.creatures[0].pos)
		await frames(5)
		check(m.creatures[0].hits == 1,"right pointer pulse hits selected carrier")
		await capture("wing-hit-"+str(size.x))
		await frames(36)
		mouse(false,m.creatures[0].pos)
		check(m.creatures[0].state == "gone","held right repeats and releases material")
		await capture("material-drop-"+str(size.x))
		await input_combinations()
		game.release_controls()
		m.area = "hub"
		m.phase = "home"
		m.p = Vector2(740,485)
		m.owned.assign(["gather1"])
		game._load_world()
		game.open_tree()
		for id in ["reach","beat","twin"]:
			if id == "twin":
				m.owned.assign(["gather1","gather2","reach"])
				game.ui.board.refresh(m)
			game.ui.board.select_node(id)
			check(game.ui.board.selected == id,"growth fixture actually selects "+id)
			game.ui._detail()
			await frames(5)
			await capture("growth-"+id+"-"+str(size.x))
		game.close_tree()
	var f := FileAccess.open(output.path_join("result.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify({"classification":"positioned native fixtures / real action input; not player acceptance","checks":checks,"failures":failures},"\t"))
	f.close()
	print("NECTAR ACTION NATIVE: ",checks," checks, ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
