extends "res://nectar_harvest_main.gd"
const RegionalModel = preload("res://region_game/model.gd")
const RegionalUI = preload("res://region_game/ui.gd")
const HoneySound = preload("res://region_game/sound.gd")
const RegionalView = preload("res://region_game/view.gd")
const PROGRESS := "user://nectar_regions_v2.json"
const Bindings = preload("res://region_game/control_bindings.gd")
const STICK_DEADZONE := 0.22
const MENU_PAD := {"ui_accept":JOY_BUTTON_A,"ui_cancel":JOY_BUTTON_B,"ui_up":JOY_BUTTON_DPAD_UP,"ui_down":JOY_BUTTON_DPAD_DOWN,"ui_left":JOY_BUTTON_DPAD_LEFT,"ui_right":JOY_BUTTON_DPAD_RIGHT}
static var active_interfaces := 0
static var installed_menu_events := {}
signal controls_changed
var bindings := Bindings.new()
var input_device := "kbm"
# The source includes the controller ID, so one release cannot cancel another hold.
var stick_positions := {}
var blocked_sticks := {}
var pending_pulses := {}
const SLOT_COUNT := 3
var evidence_log := ""
var active_slot := 1
var slots_enabled := true
var base_progress_path := ""
var slots_return := "title"
var ink_profile_id := 0
const SHOP_ENTRY_SECONDS := 1.12
const TREE_ENTRY_SECONDS := 0.95


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

func _enter_tree() -> void:
	active_interfaces += 1
	if active_interfaces > 1: return
	for action in MENU_PAD:
		var button := InputEventJoypadButton.new()
		button.device = -1 # Accept the player's controller even after reconnecting under a different ID.
		button.button_index = MENU_PAD[action]
		if not InputMap.action_has_event(action,button):
			InputMap.action_add_event(action,button)
			installed_menu_events[action] = button

func _exit_tree() -> void:
	active_interfaces -= 1
	if active_interfaces > 0: return
	for action in installed_menu_events:
		InputMap.action_erase_event(action,installed_menu_events[action])
	installed_menu_events.clear()

func default_progress_path() -> String:
	return "user://pond_feedback_preview_v1.json" if OS.has_feature("pond_feedback") else PROGRESS

func _ready() -> void:
	base_progress_path = default_progress_path()
	var slot_dir := ""
	var controls_file := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--slot-dir="):
			slot_dir = arg.trim_prefix("--slot-dir=")
			if not slot_dir.is_absolute_path() or not DirAccess.dir_exists_absolute(slot_dir):
				push_error("The requested slot directory must be an existing absolute path.")
				get_tree().quit(2)
				return
		if arg.begins_with("--progress-file="):
			slots_enabled = false
			bindings.path = arg.trim_prefix("--progress-file=")+".controls.cfg"
		if arg.begins_with("--controls-file="): controls_file = arg.trim_prefix("--controls-file=")
	if slots_enabled and not slot_dir.is_empty():
		base_progress_path = slot_dir.path_join(base_progress_path.get_file())
		bindings.path = slot_dir.path_join(bindings.path.get_file())
	bindings.load_from(controls_file if not controls_file.is_empty() else bindings.path)
	bindings.changed.connect(_bindings_changed)
	Input.joy_connection_changed.connect(_joy_connection_changed)
	model = new_model()
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
	if slots_enabled and (mode in ["title","slots"] or (mode in ["settings","controls"] and settings_return == "title")):
		finish_quit()
		return
	super.quit_game()

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
	# A new slot or new game gets its own ink. Returning from the field keeps
	# the active model and its live colour even if cosmetic storage is unavailable.
	if ink_profile_id != model.get_instance_id():
		ink_profile_id = model.get_instance_id()
		var ink := ConfigFile.new()
		if model.at_home() and model.trip_index > 0 and ink.load(saved_path+".courtyard.cfg") == OK:
			var region = ink.get_value("ink","region","")
			if region in ["pond","meadow"] and ink.get_value("ink","trip",-1) == model.trip_index:
				model.last_region = region
	if is_instance_valid(world):
		release_controls()
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
	if mode == "station_entry":
		world.presentation_active = true
		var duration := SHOP_ENTRY_SECONDS if world.station_entry == "shop" else TREE_ENTRY_SECONDS
		world.station_progress = minf(1.0,world.station_progress + minf(delta,0.1) / duration)
		if world.station_progress >= 1.0: _finish_station_entry()
	if mode == "play" and model.return_requested:
		model.return_requested = false
		request_transition("hub")

func use_station() -> bool:
	var target: String = model.interaction()
	if target not in ["shop","tree"] or reduced_motion:
		return super.use_station()
	if mode != "play": return false
	release_controls()
	model.v = Vector2.ZERO
	world.station_entry = target
	world.station_progress = 0.0
	mode = "station_entry"
	ui.show_mode(mode)
	return true

func _finish_station_entry() -> void:
	var target: String = world.station_entry
	world.station_entry = ""
	world.station_progress = 0.0
	mode = "play"
	if target == "shop": open_shop()
	else: open_tree()
	update_sound_context()

func _cancel_station_entry() -> void:
	world.station_entry = ""
	world.station_progress = 0.0
	mode = "play"
	ui.show_mode(mode)
	get_viewport().gui_release_focus()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and not test_mode and mode == "station_entry":
		_cancel_station_entry()
		pause_game()

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

func control_hint(action: String) -> String:
	return bindings.hint(action,input_device)

func departure_prompt() -> String:
	return "靠近灯球，按 %s 出发" % control_hint("interact")

func _bindings_changed() -> void:
	if is_instance_valid(world): release_controls()
	controls_changed.emit()
	presentation_changed.emit()

func track_device(event: InputEvent) -> void:
	var device := input_device
	if event is InputEventJoypadButton and event.pressed or event is InputEventJoypadMotion and absf(event.axis_value) > STICK_DEADZONE:
		device = "pad"
	elif event is InputEventKey and event.pressed or event is InputEventMouseButton and event.pressed or event is InputEventMouseMotion and event.relative.length_squared() > 1.0:
		device = "kbm"
	if device != input_device:
		input_device = device
		controls_changed.emit()
		presentation_changed.emit()

func _source(event: InputEvent) -> String:
	return "%s:%d:%d" % [Bindings.slot_for(event),event.device,Bindings.code_for(event)]

func _stick_motion(event: InputEventJoypadMotion) -> void:
	var pos: Vector2 = stick_positions.get(event.device,Vector2.ZERO)
	if event.axis == JOY_AXIS_LEFT_X: pos.x = event.axis_value
	elif event.axis == JOY_AXIS_LEFT_Y: pos.y = event.axis_value
	else: return
	if pos.length() <= STICK_DEADZONE:
		blocked_sticks.erase(event.device)
	stick_positions[event.device] = pos
	if mode != "play" and pos.length() > STICK_DEADZONE:
		blocked_sticks[event.device] = true

func flight_direction() -> Vector2:
	var analog := Vector2.ZERO
	for device in stick_positions:
		if blocked_sticks.has(device): continue
		var stick: Vector2 = stick_positions[device]
		if stick.length_squared() > analog.length_squared(): analog = stick
	var strength := clampf((analog.length()-STICK_DEADZONE)/(1.0-STICK_DEADZONE),0,1)
	var actions := held.values()
	var digital := Vector2(float("right" in actions)-float("left" in actions),float("down" in actions)-float("up" in actions))
	return (digital + analog.normalized()*strength).limit_length()

func step_flight(dt: float) -> bool:
	var active := held.values()
	var collecting: bool = "interact" in active and not model.at_home()
	model.step(dt,flight_direction(),collecting,"dash" in active,"pulse" in active or pulse_requested,pulse_direction())
	pending_pulses.clear()
	return collecting

func release_controls() -> void:
	super.release_controls()
	pending_pulses.clear()
	for device in stick_positions:
		if stick_positions[device].length() > STICK_DEADZONE: blocked_sticks[device] = true

func _joy_connection_changed(device: int, connected: bool) -> void:
	if connected: return
	var prefix := "pad:%d:" % device
	var lost_charge := false
	for source in held.keys():
		if source.begins_with(prefix):
			lost_charge = lost_charge or held[source] == "dash"
			held.erase(source)
	for source in pending_pulses.keys():
		if source.begins_with(prefix): pending_pulses.erase(source)
	pulse_requested = not pending_pulses.is_empty()
	if lost_charge and "dash" not in held.values(): model.clear_controls()
	stick_positions.erase(device)
	blocked_sticks.erase(device)
	if input_device == "pad" and Input.get_connected_joypads().is_empty():
		input_device = "kbm"
		controls_changed.emit()
		presentation_changed.emit()

func _back() -> bool:
	match mode:
		"station_entry": _cancel_station_entry()
		"tree": close_tree()
		"shop": close_shop()
		"regions": close_regions()
		"journal": close_journal()
		"settings": close_settings()
		"slots": close_slots()
		"play": pause_game()
		"pause","complete": start_game()
		_: return false
	return true

func _input(event: InputEvent) -> void:
	if restart_has_input(event): return
	track_device(event)
	if event is InputEventMouseMotion or event is InputEventMouseButton: mouse_aim = event.position
	if event is InputEventJoypadMotion:
		_stick_motion(event)
	if not is_instance_valid(ui): return
	if ui.has_method("controls_input") and ui.controls_input(event):
		get_viewport().set_input_as_handled()
		return
	if mode == "controls": return
	var slot := Bindings.slot_for(event)
	var code := Bindings.code_for(event)
	if slot.is_empty(): return
	# Track releases before GUI hit-testing. A mouse can cross onto a HUD button while held.
	if not event.is_pressed():
		held.erase(_source(event))
		if slot == "mouse":
			var mouse_action := bindings.action_for(slot,code)
			if mouse_action == "pulse": mouse_pulse = false
			if mouse_action == "interact": mouse_collect = false
	if event is InputEventKey and ui.tree_key(event):
		get_viewport().set_input_as_handled()
		return
	if not event.is_pressed() or event.is_echo(): return
	var action := bindings.action_for(slot,code)
	if mode == "transition" and action == "dash":
		transition_elapsed = Dance.SHORT_DURATION if transition_short else Dance.DURATION
	elif (slot == "key" and code == KEY_ESCAPE) or (slot == "pad" and (code == JOY_BUTTON_START or (code == JOY_BUTTON_B and mode != "play"))):
		if not _back(): return
	elif action == "pause" and mode == "play":
		_back()
	elif action == "mute" and (mode == "play" or (slot == "key" and code == KEY_M)):
		ui.toggle_sound()
	else: return
	get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if mode != "play" or event.is_echo() or not event.is_pressed(): return
	var slot := Bindings.slot_for(event)
	var action := bindings.action_for(slot,Bindings.code_for(event))
	if action.is_empty(): return
	if action == "interact":
		if use_station():
			get_viewport().set_input_as_handled()
			return
		if model.field != null: model.entry_pressed = true
	var source := _source(event)
	held[source] = action
	if action == "pulse":
		pending_pulses[source] = true
		pulse_requested = true
		if slot == "mouse":
			mouse_pulse = true
			mouse_pulse_requested = true
	elif action == "interact" and slot == "mouse":
		mouse_collect = true
	get_viewport().set_input_as_handled()

func consume_events(pending: Array) -> void:
	super.consume_events(pending)
	var pickup_gains: Dictionary[String, int] = {}
	for event in pending:
		if event.kind == "area_change" and event.to == "hub" and event.from in ["pond","meadow"]:
			model.last_region = event.from
			var ink := ConfigFile.new()
			ink.set_value("ink","trip",model.trip_index)
			ink.set_value("ink","region",model.last_region)
			var path := saved_path+".courtyard.cfg"
			var temporary := "%s.%d.tmp" % [path,OS.get_process_id()]
			if ink.save(temporary) == OK and DirAccess.rename_absolute(temporary,path) != OK:
				DirAccess.remove_absolute(temporary)
		elif event.kind == "sell" and mode == "shop":
			var side := -1.0 if model.face.x >= 0 else 1.0
			ui.sale_flight.begin(event, model.p + Vector2(side*20,18), ui.shop_coins, reduced_motion)
		elif event.kind in ["material","harvest"] and model.field != null:
			var key: String = event.type
			pickup_gains[key] = pickup_gains.get(key, 0) + event.amount
	if not pickup_gains.is_empty():
		ui.field_hud.show_pickups(pickup_gains)
	if pending.is_empty() or evidence_log.is_empty(): return
	var file := FileAccess.open(evidence_log,FileAccess.READ_WRITE if FileAccess.file_exists(evidence_log) else FileAccess.WRITE)
	if file != null:
		file.seek_end()
		for event in pending:
			file.store_line(JSON.stringify({"event":event,"time":played_seconds,"area":model.area,"trip":model.trip_index,"energy":model.energy,"cargo":model.cargo,"materials":model.materials,"owned":model.owned}))
		file.close()
