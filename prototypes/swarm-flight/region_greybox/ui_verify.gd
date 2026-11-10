extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("FAIL: " + message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var scene = load("res://region_greybox/greybox.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.session_log = "user://region_greybox/qa-resource-sessions.jsonl"
	scene.save_path = "user://region_greybox/qa-resource-save.dat"
	scene._clear_save()
	check(scene.stage == "setup" and scene.setup_panel.visible,"launch into region/growth selection")
	for region in 2:
		for growth in 2:
			scene.region_select.select(region)
			scene.growth_select.select(growth)
			scene.start_trip()
			check(scene.model.region == ["pond","violet"][region],"region selection")
			check(scene.model.growth == growth,"growth selection")
			check(scene.model.visits == [0] and scene.model.cargo == 0,"fresh trip")
			scene._toggle_pause()
			var before: Dictionary = scene.model.snapshot()
			scene._process(0.5)
			check(scene.model.snapshot() == before,"pause freezes supply, action and energy")
			check(FileAccess.file_exists(scene.save_path),"pause saves isolated active trip")
			scene._show_setup()
			scene._resume_saved()
			check(scene.stage == "active" and scene.model.snapshot() == before,"disk resume preserves exact same trip")
			scene._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
			before = scene.model.snapshot()
			scene._process(0.5)
			check(scene.paused and scene.model.snapshot() == before,"focus loss also freezes refill")
			scene.model.finish("returned")
			scene._show_result()
			check(scene.result_panel.visible and "顺利返回" in scene.result_text.text,"return result")
			check(not FileAccess.file_exists(scene.save_path),"finished trip clears resume state")
			scene._show_setup()
	scene.start_trip()
	var seed_value: int = scene.model.trip_seed
	var flowers: Array = scene.model.flowers.duplicate(true)
	scene._abandon()
	scene.keep_layout.button_pressed = true
	scene.growth_select.select(1-scene.growth_select.selected)
	scene.start_trip()
	check(scene.model.trip_seed == seed_value and scene.model.flowers == flowers,"same flowers option compares growth fairly")
	check(scene.model.material_count == 0 and scene.model.cargo == 0,"explicit new trip restores initial supply")
	for i in 18: scene.model.visits.append(i%5)
	scene.model.finish("exhausted")
	scene._show_result()
	await process_frame
	check(scene.result_text.get_parent() is ScrollContainer,"long route result contained")
	check("体力耗尽" in scene.result_text.text,"failure distinguished from return")
	check("雨" not in scene.result_text.text,"weather removed from results")
	scene._clear_save()
	print("REGION GREYBOX UI: %d checks, %d failures" % [checks,failures])
	scene.queue_free()
	await process_frame
	quit(1 if failures else 0)
