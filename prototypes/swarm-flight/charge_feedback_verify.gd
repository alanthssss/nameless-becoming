extends SceneTree
## #219: repeat-charge feedback through the production keyboard/UI path.
class Fixture extends "res://spring_journey_main.gd":
	func pause_game() -> void: pass # Suppress only OS focus pauses during native capture.

var game
var checks := 0
var failures := 0
var folder := OS.get_environment("SWARM_FEEDBACK_QA_DIR")
var samples: Array = []

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: " + label)

func key(down: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_SPACE
	event.pressed = down
	root.push_input(event)

func tick(count: int) -> void:
	for i in count:
		game.tick(1.0/30)
		game.world._process(1.0/30)

func shot(label: String) -> void:
	samples.append({"label":label,"toast":game.toast.text,"visible":game.toast.visible,
		"charging":game.model.charging,"charge":game.model.charge,
		"bursts":game.model.bursts,"stamina":game.model.stamina})
	if folder.is_empty() or DisplayServer.get_name()=="headless": return
	game.world.queue_redraw()
	game.queue_redraw()
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(folder.path_join(label+".png"))==OK,"capture "+label)

func run() -> void:
	if not folder.is_empty(): DirAccess.make_dir_recursive_absolute(folder)
	game=Fixture.new()
	game.test_mode=true
	game.progress_file=OS.get_cache_dir().path_join("unused-charge-feedback-save.json")
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.world.set_process(false)
	game.sound.set_muted(true)
	game.begin_stage(0)
	game.model.p=Vector2(850,230)
	game.model.velocity=Vector2.ZERO
	game.model.face=Vector2.RIGHT
	game.model.clear_input()
	game.model.camera_x=370
	tick(36)
	key(true)
	tick(6)
	key(false)
	tick(1)
	check(game.toast.visible and game.toast.text.contains("还没蓄好力"),"early release explains cancellation")
	check(game.model.bursts==0,"early release does not launch")
	await shot("cancel")
	key(true)
	tick(1)
	check(not (game.toast.visible and game.toast.text.contains("还没蓄好力")),"new charge invalidates old cancellation")
	await shot("retry")
	tick(10)
	check(game.model.charge<game.model.CHARGE_READY,"11/30 seconds is not ready")
	tick(1)
	check(game.model.charge>=game.model.CHARGE_READY,"12/30 seconds is ready")
	check(not (game.toast.visible and game.toast.text.contains("还没蓄好力")),"ready has no stale cancellation")
	await shot("ready")
	var before: float=game.model.stamina
	key(false)
	tick(1)
	check(game.model.bursts==1 and game.model.burst_left>0,"ready release launches once")
	check(absf(before-game.model.stamina-20-2.0/30)<0.001,"launch keeps 20-point cost plus flight drain")
	check(not (game.toast.visible and game.toast.text.contains("还没蓄好力")),"successful burst has no stale cancellation")
	await shot("burst")
	tick(20)
	game.event_message("hit","受击反馈",2.4)
	key(true)
	tick(1)
	check(game.toast.visible and game.toast.text=="受击反馈","new charge retains an unrelated damage message")
	key(false)
	tick(1)
	check(game.toast.visible and game.toast.text.contains("还没蓄好力"),"another early release gets fresh cancellation feedback")
	tick(30)
	check(game.toast.visible,"cancellation remains readable when the player does not retry")
	tick(60)
	check(not game.toast.visible,"unretried cancellation expires normally")
	for kind in ["hit","blocked","recover_manual"]:
		game.event_message(kind,"保留当前反馈",2.4)
		var original: String=game.toast.text
		game.event_message("dew","较低优先级",1.9)
		key(true)
		tick(1)
		check(game.toast.visible and game.toast.text==original,"retry preserves "+kind+" even after a rejected lower-priority event")
		key(false)
		tick(1)
		if kind == "recover_manual":
			check(game.toast.visible and game.toast.text==original,"recovery rejects the lower-priority cancellation")
			key(true)
			tick(1)
			check(game.toast.visible and game.toast.text==original,"rejected cancellation cannot relabel and clear recovery on retry")
			key(false)
	if not folder.is_empty():
		var file:=FileAccess.open(folder.path_join("trace.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify({"issue":219,"kind":"developer keyboard/UI regression","checks":checks,"failures":failures,"samples":samples},"\t"))
	game.queue_free()
	await process_frame
	print("CHARGE FEEDBACK VERIFIED: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
