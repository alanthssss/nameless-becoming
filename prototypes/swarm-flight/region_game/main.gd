extends "res://nectar_harvest_main.gd"
const RegionalModel = preload("res://region_game/model.gd")
const RegionalUI = preload("res://region_game/ui.gd")
const RegionalView = preload("res://region_game/view.gd")
const PROGRESS := "user://nectar_regions_v2.json"
var evidence_log := ""


func new_model(): return RegionalModel.new()
func create_interface(): return RegionalUI.new()

func _ready() -> void:
	model = new_model()
	saved_path = "user://pond_feedback_preview_v1.json" if OS.has_feature("pond_feedback") else PROGRESS
	super._ready()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--record-dir="):
			var recorder = preload("res://region_game/recorder.gd").new()
			recorder.driver = self
			recorder.directory = arg.trim_prefix("--record-dir=")
			evidence_log = recorder.directory.path_join("events.jsonl")
			add_child(recorder)

func read_progress(path: String) -> Dictionary:
	var payload := Save.read_payload(path,new_model())
	return {"ok":not payload.is_empty(),"payload":payload,"blocked":FileAccess.file_exists(path) and payload.is_empty()}

func _load_world() -> void:
	if is_instance_valid(world):
		remove_child(world)
		world.queue_free()
	world = RegionalView.new()
	world.model = model
	world.area_key = model.area
	world.reduced_motion = reduced_motion
	add_child(world)
	move_child(world,0)
	if is_instance_valid(ui): world.feedback_font = ui.font

func plays_departure_dance() -> bool:
	# Only the courtyard view performs the pre-iris dance.
	return model.at_home()

func _process(delta: float) -> void:
	super._process(delta)
	if mode == "play" and model.return_requested:
		model.return_requested = false
		request_transition("hub")

func _advance_transition(dt: float) -> void:
	super._advance_transition(dt)
	if transition_target == "hub" and not transition_committed and mode in ["play","pause"]:
		# A failed write leaves a live outing playable. At zero, keep the earned
		# arrival at the gate so another press can retry without losing the cargo.
		if model.field != null and model.field.phase == "returned" and model.energy > 0.0:
			model.field.phase = "active"

func pulse_direction() -> Vector2:
	return (model.screen_to_field(mouse_aim)-model.p).normalized() if mouse_pulse or mouse_pulse_requested else Vector2.ZERO

func has_material_hint() -> bool:
	if model.field == null: return false
	var item: Dictionary = model.field.material_for_hint()
	return not item.is_empty() and RegionalModel.Field.available(item) and not item.dropped and not model.field.resin_open(item)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.physical_keycode == KEY_F: return
	if mode == "play" and model.field != null and event.is_pressed() and not event.is_echo():
		var use_key: bool = event is InputEventKey and (event.physical_keycode if event.physical_keycode != 0 else event.keycode) == KEY_E
		var use_mouse: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT
		if use_key or use_mouse:
			if model.field.at_entry():
				model.return_requested = false
				request_transition("hub")
				get_viewport().set_input_as_handled()
				return
			# A down/up between render frames still counts if movement enters the gate this frame.
			model.entry_pressed = true
	super._unhandled_input(event)

func consume_events(pending: Array) -> void:
	super.consume_events(pending)
	for event in pending:
		if event.kind == "sell" and mode == "shop":
			var side := -1.0 if model.face.x >= 0 else 1.0
			ui.sale_flight.begin(event, model.p + Vector2(side*20,18), ui.shop_coins, reduced_motion)
		elif event.kind == "material" and event.type == "fiber":
			message("纤维 +%d（现有 %d） · 可在庭院升级双翼" % [event.amount, model.materials.fiber], 3.0)
		elif event.kind == "full":
			sound.play_event("ring",0)
	if pending.is_empty() or evidence_log.is_empty(): return
	var file := FileAccess.open(evidence_log,FileAccess.READ_WRITE if FileAccess.file_exists(evidence_log) else FileAccess.WRITE)
	if file != null:
		file.seek_end()
		for event in pending:
			file.store_line(JSON.stringify({"event":event,"time":played_seconds,"area":model.area,"trip":model.trip_index,"energy":model.energy,"cargo":model.cargo,"materials":model.materials,"owned":model.owned}))
		file.close()
