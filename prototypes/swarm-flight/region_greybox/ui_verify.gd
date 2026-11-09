extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var scene = load("res://region_greybox/greybox.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.session_log = "user://region_greybox/qa-sessions.jsonl"
	check(scene.stage == "setup" and scene.setup_panel.visible, "launch into condition selection")
	for region in 2:
		for state in 3:
			for growth in 2:
				scene.region_select.select(region)
				scene.state_select.select(state)
				scene.growth_select.select(growth)
				scene.start_trip()
				check(scene.model.region == ["pond","violet"][region], "region selection")
				check(scene.model.condition == ["sunny","rain","variant"][state], "state selection")
				check(scene.model.growth == growth, "growth selection")
				check(scene.model.visits == [0] and scene.model.cargo == 0, "fresh trip")
				scene._toggle_pause()
				var before: Dictionary = scene.model.summary()
				scene._process(0.5)
				check(scene.model.summary() == before, "pause freezes time, state and energy")
				scene._toggle_pause()
				scene.model.finish("returned")
				scene._show_result()
				check(scene.result_panel.visible and "顺利返回" in scene.result_text.text, "return result")
				scene._show_setup()
	# A long loop history must be contained by the scroll area, not overflow the window.
	scene.start_trip()
	for i in 12: scene.model.visits.append(i % 8)
	scene.model.finish("exhausted")
	scene._show_result()
	await process_frame
	check(scene.result_text.get_parent() is ScrollContainer, "long route result scrolls")
	check("体力耗尽" in scene.result_text.text, "failure is not presented as a return")
	scene._show_setup()
	scene.start_trip()
	scene._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(scene.paused, "focus loss pauses game")
	check(scene.session_log.ends_with("qa-sessions.jsonl"), "QA session log isolated")
	print("REGION GREYBOX UI: %d checks, %d failures" % [checks, failures])
	scene.queue_free()
	await process_frame
	quit(1 if failures else 0)
