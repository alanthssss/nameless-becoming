extends Node2D
const Model = preload("res://nectar_harvest_model.gd")
const View = preload("res://nectar_harvest_view.gd")
const Interface = preload("res://nectar_harvest_ui.gd")
const Save = preload("res://save_data.gd")
const Sound = preload("res://sound.gd")
const SAVE_PATH := "user://nectar_harvest_v1.json"
var model = Model.new()
var world
var ui
var sound
var mode := "title"
var held := {}
var mouse_collect := false
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

func _ready() -> void:
	get_window().title = "雨来之前 · 采蜜小店 MVP"
	get_tree().auto_accept_quit = false
	for arg in OS.get_cmdline_user_args():
		if arg == "--nectar-qa": test_mode = true
		if arg.begins_with("--progress-file="): saved_path = arg.trim_prefix("--progress-file=")
	# The new mode must never overwrite a named legacy journey save.
	if "journey" in saved_path.get_file(): saved_path = SAVE_PATH
	var existed := FileAccess.file_exists(saved_path)
	var data := Save.read_payload(saved_path,Model.new())
	if not data.is_empty():
		has_save = model.restore_payload(data)
		model.clear_controls()
	elif existed:
		save_blocked = true
	world = View.new()
	world.model = model
	add_child(world)
	sound = Sound.new()
	add_child(sound)
	ui = Interface.new()
	ui.driver = self
	var layer := CanvasLayer.new()
	add_child(layer)
	layer.add_child(ui)
	world.feedback_font = ui.font
	ui.show_mode(mode)
	ui.refresh()

func _process(delta: float) -> void:
	var dt := minf(delta,0.1)
	toast_left = maxf(0,toast_left-dt)
	sound_cooldown = maxf(0,sound_cooldown-dt)
	if mode == "play":
		played_seconds += dt
		var move := Vector2(float(down(KEY_D) or down(KEY_RIGHT))-float(down(KEY_A) or down(KEY_LEFT)),float(down(KEY_S) or down(KEY_DOWN))-float(down(KEY_W) or down(KEY_UP))).limit_length()
		var collecting: bool = (down(KEY_E) or mouse_collect) and not model.at_home()
		model.step(dt,move,collecting,down(KEY_SPACE))
		world.collecting = collecting and not model.harvesting_ids.is_empty()
		consume_events(model.events.duplicate(true))
		model.events.clear()
		autosave += dt
		if autosave >= 4.0:
			autosave = 0.0
			persist()
		if model.energy < 20 and not low_energy_announced:
			low_energy_announced = true
			message("续航不多了 · 带着花蜜回蜂巢吧",4)
		if model.at_home(): low_energy_announced = false
	else:
		world.collecting = false
	world.presentation_active = mode in ["play","shop","complete"]
	if is_instance_valid(sound):
		sound.set_pond_context(model.rain_exposed(),false,false,mode in ["title","pause"],true)
	ui.refresh()

func down(key: Key) -> bool: return bool(held.get(key,false))

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key: Key = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if key == KEY_ESCAPE:
			if mode == "shop": close_shop()
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
		if key == KEY_E and event.pressed and model.at_home():
			open_shop()
			get_viewport().set_input_as_handled()
			return
		if key == KEY_F and event.pressed:
			if model.use_shortcut(): persist()
			return
		held[key] = event.pressed
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		mouse_collect = event.pressed

func release_controls() -> void:
	held.clear()
	mouse_collect = false
	model.clear_controls()
	world.collecting = false

func start_game() -> void:
	if save_blocked:
		ui.ask_restart()
		return
	release_controls()
	mode = "play"
	ui.show_mode(mode)
	get_viewport().gui_release_focus()
	if model.trip_index == 0: message("同伴：先去右边的蓝花丛，带些花蜜回来。",5)

func pause_game() -> void:
	release_controls()
	persist()
	mode = "pause"
	ui.show_mode(mode)

func open_shop() -> void:
	if not model.at_home(): return
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

func sell_cargo() -> void:
	if mode != "shop": return
	var candidate = Model.new()
	if not candidate.restore_payload(model.to_payload()): return
	var gain: int = candidate.sell()
	if gain <= 0: return
	if commit_candidate(candidate):
		message("交付完成 · +%d 金币，挑一个成长再出发吧" % gain,4)
		ui.refresh()

func buy_upgrade(id: String) -> void:
	if mode != "shop": return
	var candidate = Model.new()
	if not candidate.restore_payload(model.to_payload()): return
	if not candidate.buy(id):
		message(model.locked_reason(id),3)
		return
	var title: String = candidate.upgrade(id).name
	if commit_candidate(candidate):
		message("已获得「%s」· 下一趟就能用上" % title,4)
		if id == "reserve":
			mode = "complete"
			ui.show_mode(mode)
		ui.refresh()

func commit_candidate(candidate) -> bool:
	if save_blocked or not Save.write_payload(candidate.to_payload(),saved_path,Model.new()):
		message("进度未能写入，这次交易没有扣钱或扣货。",5)
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
	world.model = model
	save_blocked = false
	has_save = true
	world.nectar_motes.clear()
	world.harvest_texts.clear()
	start_game()

func quit_game() -> void:
	release_controls()
	if save_blocked or persist(): get_tree().quit()
	else:
		mode = "pause"
		ui.show_mode(mode)

func message(words: String,seconds := 3.0) -> void:
	toast_text = words
	toast_left = seconds

func consume_events(pending: Array) -> void:
	for event in pending:
		world.nectar_event(event)
		var kind: String = event.kind
		event_log.append({"kind":kind,"time":played_seconds,"trip":model.trip_index,"coins":model.coins,"cargo":model.cargo_total(),"owned":model.owned.duplicate()})
		if event_log.size() > 2048: event_log.pop_front()
		if kind == "harvest":
			if sound_cooldown <= 0:
				sound.play_event("dew",0)
				sound_cooldown = 0.13
		elif kind == "dash": sound.play_event("burst",0)
		elif kind == "sell": sound.play_event("arrival_bell",0)
		elif kind in ["buy","unlock"]: sound.play_event("ring",0)
		elif kind == "complete": sound.play_event("finish",0)
		elif kind == "rescue":
			sound.play_event("recover",0)
			message("同伴把你送回了蜂巢 · 未交付花蜜损失了一半",5)
			persist()
		elif kind == "full": message("蜜囊装满了 · 回蜂巢按 E 交付",4)
		elif kind == "return":
			message("回到蜂巢 · 按 E 交付花蜜、选购成长",4)
			persist()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit_game()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT and not test_mode and mode == "play" and is_instance_valid(ui):
		pause_game()
