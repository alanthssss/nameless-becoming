extends SceneTree
## #218 native component fixture; not independent exploration or a player run.
class Fixture extends "res://spring_journey_main.gd":
	func pause_game() -> void: pass

const Model=preload("res://spring_journey_model.gd")
var folder:=OS.get_environment("SWARM_TIDY_QA_DIR")
var game
var captured: Dictionary={}
var frames: Array=[]

func _initialize() -> void: call_deferred("run")
func shot(label: String) -> void:
	if captured.has(label): return
	captured[label]=true
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder.path_join(label+".png"))

func run() -> void:
	if folder.is_empty() or DisplayServer.get_name()=="headless":
		push_error("Native renderer and SWARM_TIDY_QA_DIR required")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(folder)
	game=Fixture.new()
	game.test_mode=true
	game.progress_file=folder.path_join("unused-save.json")
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.world.set_process(false)
	game.sound.set_muted(true)
	game.begin_stage(2)
	var m=game.model
	m.front_open=true
	m.passage_open=true
	m.wall_at(2350).broken=true
	m.wall_at(Model.BACK_WALL_X).broken=true
	m.keeper=Model.actor(Model.KEEPER_HOME)
	m.keeper.state="tidy"
	m.keeper.target=Model.TIDY_APPROACH[0]
	m.p=Vector2(3600,630)
	m.clear_input()
	m.events.clear()
	for i in 480:
		game.tick(1.0/30)
		# Fixture camera observes source animation; production player control is unchanged.
		m.camera_x=clampf(m.keeper.pos.x-480,0,m.world_width-1280)
		var near_exit: bool=m.result_elapsed==Model.INSPECT_SECONDS and m.keeper.pos.x>3550 and m.keeper.pos.y<310
		if near_exit: m.camera_x=3300
		game.world._process(1.0/30)
		game.queue_redraw()
		game.world.queue_redraw()
		frames.append({"frame":i,"keeper":[m.keeper.pos.x,m.keeper.pos.y],"sign":[m.keeper_sign_position().x,m.keeper_sign_position().y],"elapsed":m.result_elapsed,"state":m.keeper.state,"camera_x":m.camera_x})
		await process_frame
		if i==60: await shot("01-approach")
		if m.keeper.pos==Model.PICKUP_POSITION and m.result_elapsed>0: await shot("02-inspect-hook")
		if m.result_elapsed==Model.INSPECT_SECONDS and m.keeper.pos.x>3300: await shot("03-carry")
		if near_exit: await shot("04-carry-near-exit-camera")
		if m.keeper.pos==Model.RESULT_HOME and m.keeper.state!="settled": await shot("05-place")
		if m.keeper.state=="settled":
			await shot("06-settled")
			break
	var passed: bool=captured.size()==6 and m.keeper.state=="settled"
	var file:=FileAccess.open(folder.path_join("trace.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"issue":218,"kind":"native source-component fixture; gates seeded open, actor-follow fixture camera, muted; not player validation","passed":passed,"captures":captured.keys(),"frames":frames},"\t"))
	game.queue_free()
	await process_frame
	print("KEEPER TIDY NATIVE: ",passed,"; captures=",captured.size())
	quit(0 if passed else 1)
