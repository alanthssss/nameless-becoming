extends "res://nectar_harvest_main.gd"
const RegionalModel = preload("res://region_game/model.gd")
const RegionalUI = preload("res://region_game/ui.gd")
const HoneySound = preload("res://region_game/sound.gd")
const RegionalView = preload("res://region_game/view.gd")
const PROGRESS := "user://nectar_regions_v2.json"
const SLOT_COUNT := 3
var evidence_log := ""
var active_slot := 1
var slots_enabled := true
var base_progress_path := ""
var slots_return := "title"


func new_model(): return RegionalModel.new()
func create_interface(): return RegionalUI.new()
func create_sound(): return HoneySound.new()

func finish_quit() -> void:
	if is_queued_for_deletion(): return
	ui.growth_map.close_book()
	var tree := get_tree()
	# Release the looping players while the audio driver can still process their stops.
	queue_free()
	tree.create_timer(0.25, true, false, true).timeout.connect(tree.quit)

func restart_game() -> void:
	var previous = model
	super.restart_game()
	if model != previous: ui.growth_map.forget_book(saved_path)

func update_sound_context() -> void:
	sound.set_honey_context(model.area, mode)

func sound_for_event(event: Dictionary) -> String:
	match event.kind:
		"depart": return "depart_wind"
		"pulse", "pulse_empty": return "pulse"
		"material_dropped": return "fiber_release"
		"material_opened": return "resin_open"
		"material": return event.type
		"rescue": return "recover"
		"harvest", "dash", "tap", "hurt", "sell", "full", "buy", "denied", "complete":
			return event.kind
	# Unlock accompanies the committed purchase and has no second confirmation.
	return ""

func default_progress_path() -> String:
	return "user://pond_feedback_preview_v1.json" if OS.has_feature("pond_feedback") else PROGRESS

func _ready() -> void:
	model = new_model()
	base_progress_path = default_progress_path()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--progress-file="): slots_enabled = false
	if slots_enabled:
		var selection := ConfigFile.new()
		if selection.load(base_progress_path+".slots.cfg") == OK:
			var last: Variant = selection.get_value("slots","last",1)
			if last is int and last >= 1 and last <= SLOT_COUNT: active_slot = last
	saved_path = slot_path(active_slot)
	super._ready()
	if not has_save and not save_blocked: ui.growth_map.forget_book(saved_path)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--record-dir="):
			var recorder = preload("res://region_game/recorder.gd").new()
			recorder.driver = self
			recorder.directory = arg.trim_prefix("--record-dir=")
			evidence_log = recorder.directory.path_join("events.jsonl")
			add_child(recorder)

func slot_path(id: int) -> String:
	if id == 1: return base_progress_path
	return base_progress_path.get_basename()+".slot%d.json" % id

func settings_path() -> String:
	if slots_enabled: return base_progress_path+".settings.cfg"
	return super.settings_path()

func slot_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for id in range(1,SLOT_COUNT+1):
		var path := slot_path(id)
		var row := {"id":id,"status":"empty","area":"","coins":0,"trip":0}
		if FileAccess.file_exists(path):
			var preview = new_model()
			if Save.read_payload(path,preview).is_empty():
				row.status = "blocked"
			else:
				row.merge({"status":"occupied","area":area_name(preview.area),"coins":preview.coins,"trip":preview.trip_index},true)
		rows.append(row)
	return rows

func open_slots() -> void:
	if not slots_enabled or mode not in ["title","pause"]: return
	if mode == "pause" and not persist(): return
	slots_return = mode
	mode = "slots"
	ui.show_mode(mode)

func close_slots() -> void:
	if mode != "slots": return
	mode = slots_return
	ui.show_mode(mode)

func choose_slot(id: int) -> void:
	if mode != "slots" or id < 1 or id > SLOT_COUNT: return
	var path := slot_path(id)
	var loaded := read_progress(path)
	var next = new_model()
	if loaded.blocked or (loaded.ok and not next.restore_payload(loaded.payload)):
		message("存档 %d 暂时无法读取，请选择其他档位。" % id,4)
		return
	if not loaded.ok and not Save.write_payload(next.to_payload(),path,new_model()):
		message("无法建立存档 %d，请检查保存位置后重试。" % id,4)
		return
	var selection_saved := true
	if active_slot != id:
		var selection := ConfigFile.new()
		selection.set_value("slots","last",id)
		var pref := base_progress_path+".slots.cfg"
		var temporary := "%s.%d.tmp" % [pref,OS.get_process_id()]
		selection_saved = selection.save(temporary) == OK and DirAccess.rename_absolute(temporary,pref) == OK
		if not selection_saved and FileAccess.file_exists(temporary): DirAccess.remove_absolute(temporary)
	release_controls()
	active_slot = id
	saved_path = path
	if not loaded.ok: ui.growth_map.forget_book(path)
	model = next
	model.clear_controls()
	has_save = true
	save_blocked = false
	save_warning = false
	home_return_summary = ""
	home_sale_summary = ""
	autosave = 0.0
	played_seconds = 0.0
	low_energy_announced = false
	event_log.clear()
	toast_left = 0.0
	_load_world()
	start_game()
	if not selection_saved: message("档位已打开。下次启动请手动选择存档 %d。" % id,4)

func quit_game() -> void:
	# Browsing from the title or a saved pause must never create an empty slot.
	if slots_enabled and (mode in ["title","slots"] or (mode == "settings" and settings_return == "title")):
		finish_quit()
		return
	super.quit_game()

func _input(event: InputEvent) -> void:
	if mode == "slots" and event.is_action_pressed("ui_cancel"):
		close_slots()
		get_viewport().set_input_as_handled()
		return
	super._input(event)

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
	if pending.is_empty() or evidence_log.is_empty(): return
	var file := FileAccess.open(evidence_log,FileAccess.READ_WRITE if FileAccess.file_exists(evidence_log) else FileAccess.WRITE)
	if file != null:
		file.seek_end()
		for event in pending:
			file.store_line(JSON.stringify({"event":event,"time":played_seconds,"area":model.area,"trip":model.trip_index,"energy":model.energy,"cargo":model.cargo,"materials":model.materials,"owned":model.owned}))
		file.close()
