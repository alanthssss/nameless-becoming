extends "res://nectar_harvest_main.gd"
const RegionalModel = preload("res://region_game/model.gd")
const RegionalUI = preload("res://region_game/ui.gd")
const HoneySound = preload("res://region_game/sound.gd")
const RegionalView = preload("res://region_game/view.gd")
const PROGRESS := "user://nectar_regions_v2.json"
var evidence_log := ""


func new_model(): return RegionalModel.new()
func create_interface(): return RegionalUI.new()
func create_sound(): return HoneySound.new()

func update_sound_context() -> void:
	sound.set_honey_context(model.area, mode)

func sound_for_event(event: Dictionary) -> String:
	match event.kind:
		"pulse", "pulse_empty": return "pulse"
		"material_dropped": return "fiber_release"
		"material_opened": return "resin_open"
		"material": return event.type
		"rescue": return "recover"
		"harvest", "dash", "tap", "hurt", "sell", "full", "buy", "denied", "complete":
			return event.kind
	# Unlock accompanies the committed purchase and has no second confirmation.
	return ""

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
	var model_copy = new_model()
	var payload := Save.read_payload(path,model_copy)
	if model_copy.field != null and model_copy.field.region == "pond" and not payload.is_empty():
		var previous: Dictionary = bytes_to_var(Marshalls.base64_to_raw(payload.field))
		if previous.get("space_version",1) < RegionalModel.Field.POND_SPACE_VERSION:
			var raw := FileAccess.get_file_as_bytes(path)
			var source := raw.get_string_from_utf8()
			var backup := path+".pond-"+source.sha256_text()+".bak"
			if JSON.parse_string(source) != payload or not Migration.backup_original(backup,raw).is_empty():
				return {"ok":false,"payload":{},"blocked":true}
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
	if mode == "play" and model.return_requested:
		model.return_requested = false
		request_transition("hub")
	super._process(delta)

func pulse_direction() -> Vector2:
	return (model.screen_to_field(mouse_aim)-model.p).normalized() if mouse_pulse or mouse_pulse_requested else Vector2.ZERO

func has_material_hint() -> bool:
	if model.field == null: return false
	var item: Dictionary = model.field.material_for_hint()
	return not item.is_empty() and RegionalModel.Field.available(item) and not item.dropped and not model.field.resin_open(item)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.physical_keycode == KEY_F: return
	super._unhandled_input(event)

func consume_events(pending: Array) -> void:
	super.consume_events(pending)
	for event in pending:
		if event.kind == "sell" and mode == "shop":
			var side := -1.0 if model.face.x >= 0 else 1.0
			ui.sale_flight.begin(event, model.p + Vector2(side*20,18), ui.shop_coins, reduced_motion)
		elif event.kind == "material" and event.type == "fiber":
			message("纤维 +%d（现有 %d） · 可在庭院升级双翼" % [event.amount, model.materials.fiber], 3.0)
	if pending.is_empty() or evidence_log.is_empty(): return
	var file := FileAccess.open(evidence_log,FileAccess.READ_WRITE if FileAccess.file_exists(evidence_log) else FileAccess.WRITE)
	if file != null:
		file.seek_end()
		for event in pending:
			file.store_line(JSON.stringify({"event":event,"time":played_seconds,"area":model.area,"trip":model.trip_index,"energy":model.energy,"cargo":model.cargo,"materials":model.materials,"owned":model.owned}))
		file.close()
