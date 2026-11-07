extends Node2D
const Model = preload("res://nectar_harvest_model.gd")
const AREA_SCENES := {"hub":preload("res://nectar_hub.tscn"),"pond":preload("res://nectar_pond.tscn"),"meadow":preload("res://nectar_meadow.tscn")}
const Interface = preload("res://nectar_harvest_ui.gd")
const Save = preload("res://save_data.gd")
const Sound = preload("res://sound.gd")
const Migration = preload("res://nectar_save_migration.gd")
const Dance = preload("res://nectar_dance.gd")
signal presentation_changed
const DISPLAY_NAME := "采蜜 Demo"
const SAVE_PATH := "user://nectar_harvest_v1.json"
var model = Model.new()
var world
var ui
var sound
var mode := "title"
var held := {}
var mouse_collect := false
var mouse_pulse := false
var pulse_requested := false
var mouse_pulse_requested := false
var mouse_aim := Vector2.ZERO
var has_save := false
var save_blocked := false
var save_warning := false
var test_mode := false
var saved_path := SAVE_PATH
var autosave := 0.0
var played_seconds := 0.0
var toast_text := ""
var toast_left := 0.0
var sound_cooldown := 0.0
var low_energy_announced := false
var event_log: Array[Dictionary] = []
var transition_candidate
var transition_elapsed := 0.0
var transition_committed := false
var transition_target := ""
var pause_after_transition := false
var reduced_motion := false
var dance_style := "waggle"
var settings_return := "title"
var transition_short := false
# Current home visit only. A cold load has no witnessed expedition result.
var home_return_summary := ""
var home_sale_summary := ""

func _ready() -> void:
	get_window().title = DISPLAY_NAME
	get_tree().auto_accept_quit = false
	for arg in OS.get_cmdline_user_args():
		if arg == "--nectar-qa": test_mode = true
		if arg.begins_with("--progress-file="): saved_path = arg.trim_prefix("--progress-file=")
	# The new mode must never overwrite a named legacy journey save.
	if "journey" in saved_path.get_file(): saved_path = SAVE_PATH
	var loaded := Migration.load_progress(saved_path)
	if loaded.ok:
		has_save = model.restore_payload(loaded.payload)
		model.clear_controls()
	elif loaded.blocked:
		save_blocked = true
	model.update_camera()
	_load_world()
	sound = Sound.new()
	add_child(sound)
	ui = Interface.new()
	ui.driver = self
	var layer := CanvasLayer.new()
	add_child(layer)
	layer.add_child(ui)
	load_settings()
	world.feedback_font = ui.font
	ui.show_mode(mode)
	ui.refresh()

func _load_world() -> void:
	if is_instance_valid(world):
		remove_child(world)
		world.queue_free()
	world = AREA_SCENES[model.area].instantiate()
	world.model = model
	world.reduced_motion = reduced_motion
	add_child(world)
	move_child(world,0)
	if is_instance_valid(ui): world.feedback_font = ui.font

func request_transition(destination: String,via := "gate") -> void:
	if mode not in ["play","regions"]: return
	var candidate = Model.new()
	if not candidate.restore_payload(model.to_payload()) or not candidate.transition_to(destination,via):
		message("这条路暂时不能通行 · 先靠近入口，或查看成长条件",3)
		return
	release_controls()
	transition_candidate = candidate
	transition_target = destination
	transition_elapsed = 0.0
	transition_short = reduced_motion
	transition_committed = false
	pause_after_transition = false
	mode = "transition"
	ui.show_mode(mode)
	ui.set_transition(0.0,area_name(destination))

func _advance_transition(dt: float) -> void:
	transition_elapsed += dt
	var commit_time: float = Dance.SHORT_COMMIT if transition_short else Dance.COMMIT
	var duration: float = Dance.SHORT_DURATION if transition_short else Dance.DURATION
	world.dance_elapsed = transition_elapsed if not transition_short and not transition_committed else -1.0
	world.dance_style = dance_style
	if not transition_committed and transition_elapsed >= commit_time:
		if not commit_candidate(transition_candidate):
			transition_candidate = null
			world.dance_elapsed = -1.0
			mode = "pause" if pause_after_transition else "play"
			ui.show_mode(mode)
			message("地区切换未能保存 · 已留在原处，请稍后重试",4)
			return
		transition_committed = true
		_load_world()
	var close_span := 0.18 if transition_short else 0.42
	var hold_span := 0.0 if transition_short else 0.22
	var alpha := clampf((transition_elapsed-(commit_time-close_span))/close_span,0,1) if not transition_committed else 1.0-maxf(0.0,transition_elapsed-commit_time-hold_span)/(duration-commit_time-hold_span)
	ui.set_transition(clampf(alpha,0,1),area_name(transition_target))
	if transition_elapsed >= duration:
		transition_candidate = null
		world.dance_elapsed = -1.0
		mode = "pause" if pause_after_transition else "play"
		ui.show_mode(mode)
		if mode == "play": get_viewport().gui_release_focus()
		if mode == "play" and model.at_home() and toast_left > 0.0:
			ui.show_toast(toast_text,toast_left)
		presentation_changed.emit()

func area_name(area: String) -> String:
	return {"hub":"蜂巢庭院","pond":"池岸花丛","meadow":"紫花地"}.get(area,area)

func open_regions() -> void:
	if mode != "play" or model.interaction() not in ["depart","pond"]: return
	release_controls()
	model.v = Vector2.ZERO
	mode = "regions"
	ui.show_mode(mode)

func close_regions() -> void:
	if mode != "regions": return
	release_controls()
	mode = "play"
	ui.show_mode(mode)
	get_viewport().gui_release_focus()

func _process(delta: float) -> void:
	var dt := minf(delta,0.1)
	toast_left = maxf(0,toast_left-dt)
	sound_cooldown = maxf(0,sound_cooldown-dt)
	if mode == "transition":
		_advance_transition(dt)
	if mode == "play":
		var old_hud := _hud_signature()
		played_seconds += dt
		var move := Vector2(float(down(KEY_D) or down(KEY_RIGHT))-float(down(KEY_A) or down(KEY_LEFT)),float(down(KEY_S) or down(KEY_DOWN))-float(down(KEY_W) or down(KEY_UP))).limit_length()
		var collecting: bool = (down(KEY_E) or mouse_collect) and not model.at_home()
		model.step(dt,move,collecting,down(KEY_SPACE),down(KEY_Q) or mouse_pulse or pulse_requested,pulse_direction())
		world.aim_direction = model.pulse_direction(pulse_direction())
		# One-frame presses preserve quick taps, without buffering behind cooldowns.
		pulse_requested = false
		mouse_pulse_requested = false
		if world.area_key != model.area:
			_load_world() # Rescue is stable before its fade-in and cannot double-charge.
			mode = "transition"
			transition_target = model.area
			transition_candidate = null
			transition_committed = true
			transition_short = true
			transition_elapsed = Dance.SHORT_COMMIT
			ui.show_mode(mode)
			ui.set_transition(1.0,area_name(model.area))
		world.collecting = collecting and not model.harvesting_ids.is_empty()
		consume_events(model.events.duplicate(true))
		model.events.clear()
		autosave += dt
		if autosave >= 4.0:
			autosave = 0.0
			persist()
		if model.energy < model.max_energy()*0.27 and not low_energy_announced:
			low_energy_announced = true
			message("体力偏低",4)
		if model.at_home(): low_energy_announced = false
		if old_hud != _hud_signature(): presentation_changed.emit()
	else:
		world.collecting = false
	world.presentation_active = mode in ["play","shop","tree","regions","journal","transition","complete"]
	if is_instance_valid(sound):
		sound.set_pond_context(model.rain_exposed(),false,false,mode in ["title","pause"],true)

func _hud_signature() -> String:
	return str([int(ceil(model.energy)),model.cargo,model.materials,model.coins,model.owned,model.phase,model.area,model.interaction(),model.at_home(),int(ceil(model.hurt_left)),model.rain_exposed(),model.trip_index,model.rose_sold,has_harvest_hint(),has_material_hint()])

func has_harvest_hint() -> bool:
	if model.at_home() or model.cargo_total() >= model.capacity() or not model.interaction().is_empty(): return false
	for flower in model.flowers:
		if flower.stock > 0 and int(flower.region) == (1 if model.area == "meadow" else 0) and model.p.distance_to(model.flower_point(flower)) <= model.harvest_radius(): return true
	return false

func has_material_hint() -> bool:
	if model.at_home(): return false
	for creature in model.creatures:
		if creature.state != "gone" and int(creature.region) == (1 if model.area == "meadow" else 0) and model.p.distance_to(creature.pos) <= model.pulse_radius(): return true
	return false

func down(key: Key) -> bool: return bool(held.get(key,false))

func pulse_direction() -> Vector2:
	if mouse_pulse or mouse_pulse_requested:
		return (mouse_aim+Vector2(model.camera_x,0)-model.p).normalized()
	# Resolve keyboard facing after this frame's movement; mouse aim remains explicit.
	return Vector2.ZERO

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion: mouse_aim = event.position
	if event is InputEventKey and is_instance_valid(ui) and ui.tree_key(event):
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key: Key = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if mode == "transition" and key == KEY_SPACE:
			# Skip presentation only; _advance_transition still performs one verified commit.
			transition_elapsed = Dance.SHORT_DURATION if transition_short else Dance.DURATION
			get_viewport().set_input_as_handled()
			return
		if key == KEY_ESCAPE:
			if mode == "tree": close_tree()
			elif mode == "shop": close_shop()
			elif mode == "regions": close_regions()
			elif mode == "journal": close_journal()
			elif mode == "settings": close_settings()
			elif mode == "play": pause_game()
			elif mode == "pause": start_game()
			elif mode == "complete": start_game()
			get_viewport().set_input_as_handled()
		elif key == KEY_M:
			ui.toggle_sound()
			get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if mode != "play": return
	if event is InputEventKey:
		var key: Key = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if event.echo: return
		if key == KEY_E and event.pressed:
			var action: String = model.interaction()
			if not action.is_empty():
				match action:
					"shop": open_shop()
					"tree": open_tree()
					"journal": open_journal()
					"depart", "pond": open_regions()
					"home": request_transition("hub")
					"meadow":
						if "meadow" in model.owned: request_transition("meadow")
						else: message("紫花地尚未开放 · 在庭院成长台查看条件",4)
				get_viewport().set_input_as_handled()
				return
		if key == KEY_Q:
			if event.pressed:
				held[key] = true
				pulse_requested = true
			else: held.erase(key)
			return
		if key == KEY_F and event.pressed:
			request_transition("meadow" if model.area == "pond" else "pond","shortcut")
			return
		if event.pressed and key in [KEY_W,KEY_A,KEY_S,KEY_D,KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT,KEY_E,KEY_SPACE]: held[key] = true
		else: held.erase(key)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		mouse_pulse = event.pressed
		mouse_aim = event.position
		if event.pressed:
			pulse_requested = true
			mouse_pulse_requested = true
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		mouse_collect = event.pressed

func release_controls() -> void:
	held.clear()
	mouse_collect = false
	mouse_pulse = false
	pulse_requested = false
	mouse_pulse_requested = false
	model.clear_controls()
	world.collecting = false

func start_game() -> void:
	pause_after_transition = false
	if save_blocked:
		ui.ask_restart()
		return
	release_controls()
	mode = "play"
	ui.show_mode(mode)
	get_viewport().gui_release_focus()
	if model.trip_index == 0: message("靠近灯球，按 E 出发",3)

func open_journal() -> void:
	if mode != "pause": return
	release_controls()
	mode = "journal"
	ui.show_mode(mode)

func close_journal() -> void:
	if mode != "journal": return
	release_controls()
	mode = "pause"
	ui.show_mode(mode)

func open_settings() -> void:
	if mode not in ["title","pause","complete"]: return
	settings_return = mode
	release_controls()
	mode = "settings"
	ui.show_mode(mode)

func close_settings() -> void:
	if mode != "settings": return
	mode = settings_return
	ui.show_mode(mode)

func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(saved_path+".settings.cfg") != OK: return
	var motion: Variant = config.get_value("presentation","reduced_motion",false)
	var muted: Variant = config.get_value("presentation","muted",false)
	reduced_motion = motion is bool and motion
	ui.muted = muted is bool and muted
	dance_style = "side_step" if config.get_value("presentation","dance_style","") == "side_step" else "waggle"
	world.reduced_motion = reduced_motion
	sound.set_muted(ui.muted)

func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("presentation","reduced_motion",reduced_motion)
	config.set_value("presentation","muted",ui.muted)
	config.set_value("presentation","dance_style",dance_style)
	if config.save(saved_path+".settings.cfg") != OK: message("设置暂时未保存，本次仍生效。",3)
	world.reduced_motion = reduced_motion
	ui.refresh_settings()

func pause_game() -> void:
	release_controls()
	persist()
	mode = "pause"
	ui.show_mode(mode)

func open_shop() -> void:
	if mode != "play" or model.interaction() != "shop": return
	release_controls()
	model.v = Vector2.ZERO
	persist()
	mode = "shop"
	ui.show_mode(mode)

func close_shop() -> void:
	release_controls()
	mode = "play"
	ui.show_mode(mode)
	get_viewport().gui_release_focus()

func open_tree() -> void:
	if mode != "play" or model.interaction() != "tree": return
	release_controls()
	mode = "tree"
	ui.show_mode(mode)

func close_tree() -> void:
	if mode != "tree": return
	release_controls()
	mode = "play"
	ui.show_mode(mode)
	get_viewport().gui_release_focus()

func sell_cargo() -> void:
	if mode != "shop": return
	var candidate = Model.new()
	if not candidate.restore_payload(model.to_payload()): return
	var gain: int = candidate.sell()
	if gain <= 0: return
	if commit_candidate(candidate):
		ui.refresh()

func buy_upgrade(id: String) -> void:
	if mode != "tree": return
	var candidate = Model.new()
	if not candidate.restore_payload(model.to_payload()): return
	if not candidate.buy(id):
		message(model.locked_reason(id),3)
		return
	var definition: Dictionary = candidate.upgrade(id)
	if commit_candidate(candidate):
		var effect: String = {"meadow":"紫花地已开放，可从出发处选择","shortcut":"池岸与紫花地可用近道往返","reserve":"花蜜储备完成，伙伴已在广场等你"}.get(id,definition.description)
		var paid := "%d 金币" % int(definition.cost)
		for kind in ["fiber","resin"]:
			if int(definition.get(kind,0)) > 0:
				paid += " · %d %s" % [int(definition[kind]),"纤维" if kind == "fiber" else "树脂"]
		if id == "reserve":
			mode = "complete"
			ui.show_mode(mode)
		ui.refresh()
		message("%s · %s\n花费 %s" % [definition.name,effect,paid],4.5)

func commit_candidate(candidate) -> bool:
	if save_blocked or not Save.write_payload(candidate.to_payload(),saved_path,Model.new()):
		message("进度未能写入，这次操作没有扣钱、扣货或切换地区。",5)
		return false
	var pending: Array = candidate.events.duplicate(true)
	if not model.restore_payload(candidate.to_payload()): return false
	has_save = true
	consume_events(pending)
	return true

func persist() -> bool:
	if save_blocked: return false
	var ok: bool = Save.write_payload(model.to_payload(),saved_path,Model.new())
	if ok:
		has_save = true
		save_warning = false
	elif not save_warning:
		save_warning = true
		message("保存暂时失败 · 请稍后重试，当前进度仍在。",5)
	return ok

func restart_game() -> void:
	if FileAccess.file_exists(saved_path):
		var backup := saved_path+".backup-"+str(Time.get_unix_time_from_system()).replace(".","-")
		if DirAccess.copy_absolute(saved_path,backup) != OK:
			message("旧进度备份失败，尚未重新开始。",5)
			return
	var candidate = Model.new()
	if not Save.write_payload(candidate.to_payload(),saved_path,Model.new()):
		message("新进度无法保存，原进度未改变。",5)
		return
	model = candidate
	home_return_summary = ""
	home_sale_summary = ""
	_load_world()
	save_blocked = false
	has_save = true
	world.nectar_motes.clear()
	world.harvest_texts.clear()
	start_game()

func quit_game() -> void:
	release_controls()
	if save_blocked or persist(): get_tree().quit()
	else:
		# A failed quit cancels presentation, preserving whichever stable area
		# was last committed. Resuming must not retain an abandoned dance pose.
		transition_candidate = null
		transition_elapsed = 0.0
		transition_committed = false
		transition_target = ""
		pause_after_transition = false
		world.dance_elapsed = -1.0
		mode = "pause"
		ui.show_mode(mode)

func message(words: String,seconds := 3.0) -> void:
	toast_text = words
	toast_left = seconds
	if is_instance_valid(ui) and is_instance_valid(ui.toast_timer): ui.show_toast(words,seconds)

func consume_events(pending: Array) -> void:
	for event in pending:
		world.nectar_event(event)
		var kind: String = event.kind
		event_log.append({"kind":kind,"area":model.area,"detail":event.duplicate(true),"time":played_seconds,"trip":model.trip_index,"coins":model.coins,"cargo":model.cargo_total(),"materials":model.materials.duplicate(),"energy":model.energy,"owned":model.owned.duplicate()})
		if event_log.size() > 2048: event_log.pop_front()
		if kind == "harvest":
			if sound_cooldown <= 0:
				sound.play_event("dew",0)
				sound_cooldown = 0.13
		elif kind == "dash": sound.play_event("burst",0)
		elif kind == "pulse": sound.play_event("burst",0)
		elif kind == "tap": sound.play_event("spray",0)
		elif kind == "material": sound.play_event("dew",0)
		elif kind == "hurt": sound.play_event("hit",0)
		elif kind == "sell":
			sound.play_event("arrival_bell",0)
			var delivered: Dictionary = event.cargo
			home_sale_summary = "已交付 · 蓝花蜜 %d · 紫花蜜 %d\n获得 %d 金币" % [delivered.blue,delivered.rose,event.amount]
			message("交付蓝花蜜 %d、紫花蜜 %d · 获得 %d 金币" % [delivered.blue,delivered.rose,event.amount],4)
		elif kind in ["buy","unlock"]: sound.play_event("ring",0)
		elif kind == "complete": sound.play_event("finish",0)
		elif kind == "rescue":
			sound.play_event("recover",0)
			home_return_summary = "救援带回 · 蓝花蜜 %d · 紫花蜜 %d\n损失 · 蓝花蜜 %d · 紫花蜜 %d\n材料保留 · 纤维 %d · 树脂 %d" % [event.cargo.blue,event.cargo.rose,event.lost.blue,event.lost.rose,event.materials.fiber,event.materials.resin]
			home_sale_summary = ""
			message("同伴送回 · 蓝蜜保留 %d、损失 %d\n紫蜜保留 %d、损失 %d · 材料保留" % [event.cargo.blue,event.lost.blue,event.cargo.rose,event.lost.rose],5)
			persist()
		elif kind == "full": message("蜜囊已满",2)
		elif kind == "return":
			home_return_summary = "本次带回 · 蓝花蜜 %d · 紫花蜜 %d\n材料现有 · 纤维 %d · 树脂 %d" % [event.cargo.blue,event.cargo.rose,event.materials.fiber,event.materials.resin]
			home_sale_summary = ""
			message("带回蓝花蜜 %d、紫花蜜 %d · 体力已补满" % [event.cargo.blue,event.cargo.rose],4)
			persist()
		elif kind == "depart":
			home_return_summary = ""
			home_sale_summary = ""

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit_game()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT and not test_mode and is_instance_valid(ui):
		release_controls()
		ui.enter_held = false
		ui.purchase_double_click = false
		if mode == "transition": pause_after_transition = true
		elif mode == "play": pause_game()
