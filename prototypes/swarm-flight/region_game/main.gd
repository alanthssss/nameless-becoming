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
	saved_path = PROGRESS
	super._ready()
	get_window().title = "采蜜 Demo · 池岸与紫花地"
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

func _process(delta: float) -> void:
	if mode == "play" and model.return_requested:
		model.return_requested = false
		request_transition("hub")
	super._process(delta)

func pulse_direction() -> Vector2:
	return (mouse_aim+model.camera_offset-model.p).normalized() if mouse_pulse or mouse_pulse_requested else Vector2.ZERO

func has_material_hint() -> bool:
	if model.field == null: return false
	for item in model.field.materials:
		if RegionalModel.Field.available(item) and not item.dropped and model.p.distance_to(item.p) <= model.pulse_radius() and model.field.clear_line(model.p,item.p): return true
	return false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.physical_keycode == KEY_F: return
	super._unhandled_input(event)

func consume_events(pending: Array) -> void:
	super.consume_events(pending)
	if pending.is_empty() or evidence_log.is_empty(): return
	var file := FileAccess.open(evidence_log,FileAccess.READ_WRITE if FileAccess.file_exists(evidence_log) else FileAccess.WRITE)
	if file != null:
		file.seek_end()
		for event in pending:
			file.store_line(JSON.stringify({"event":event,"time":played_seconds,"area":model.area,"trip":model.trip_index,"energy":model.energy,"cargo":model.cargo,"materials":model.materials,"owned":model.owned}))
		file.close()
