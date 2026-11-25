extends SceneTree
## Run with --headless --fixed-fps 60 --script res://region_game/honey_growth_bay_verify.gd.
const Preview = preload("res://region_game/honey_growth_bay_preview.gd")
var overlay
var failures := 0
var checks := 0
var closed_count := 0

func _initialize() -> void:
	call_deferred("run")

func verify(condition: bool, note: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(note)

func keyboard(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	root.push_input(event,true)

func tap(code: Key) -> void:
	keyboard(code,true)
	keyboard(code,false)

func frames(count: int) -> void:
	for i in count:
		await process_frame

func pick_and_wait(index: int, expected_manual: int) -> void:
	tap(KEY_1+index)
	for i in 150:
		if overlay.bay.received.x == expected_manual:
			return
		await process_frame
	verify(false,"Timed out flying to flower %s" % String.chr(65+index))

func run_route(rank_id: String, expected: Vector3i, interrupted := false) -> void:
	overlay.setup(rank_id)
	keyboard(KEY_SPACE,true)
	await pick_and_wait(0,1)
	await pick_and_wait(1,2)
	if interrupted:
		keyboard(KEY_SPACE,false)
		keyboard(KEY_SPACE,true)
	await pick_and_wait(2,3)
	verify(overlay.bay.received == expected,"%s earned %s; expected %s" % [rank_id,overlay.bay.received,expected])
	verify(overlay.bay.total() == expected.x+expected.y+expected.z,"Inventory equals the three sources")
	var sources := {}
	for event in overlay.bay.last_harvest:
		verify(not sources.has(event.flower),"An empty flower cannot pay twice")
		sources[event.flower] = true
		verify(not overlay.bay.ripe[event.flower],"Every applied reward consumes its own ripe flower")
	await frames(65)
	verify(overlay.bay.received == expected,"Holding at an empty flower cannot grant nectar")
	keyboard(KEY_SPACE,false)

func run() -> void:
	overlay = Preview.new()
	overlay.setup("gather1")
	root.add_child(overlay)
	await frames(2)
	verify(overlay.size == root.get_visible_rect().size,"Overlay fills the viewport")
	await run_route("gather1",Vector3i(3,0,0))
	await run_route("garland1",Vector3i(3,1,0))
	await run_route("cascade1",Vector3i(3,1,2))
	await run_route("cascade2",Vector3i(3,2,3))
	await run_route("cascade2",Vector3i(3,2,0),true)
	overlay.load_picker.select(2)
	overlay.load_picker.item_selected.emit(2)
	keyboard(KEY_SPACE,true)
	await pick_and_wait(0,1)
	await pick_and_wait(1,2)
	tap(KEY_3)
	await frames(100)
	verify(overlay.bay.received == Vector3i(2,0,0) and overlay.bay.total() == 10 and overlay.bay.ripe[2],"Full bag leaves C and its branches intact")
	keyboard(KEY_SPACE,false)
	overlay.closed.connect(func(): closed_count += 1)
	tap(KEY_ESCAPE)
	tap(KEY_ESCAPE)
	verify(closed_count == 1 and not overlay.bay.holding,"Esc closes once and stops collecting")
	overlay.queue_free()
	await frames(2)
	print("Honey flower bay: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
