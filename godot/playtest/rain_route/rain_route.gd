extends Node2D

const Model := preload("res://playtest/rain_route/route_model.gd")
const MUSIC := preload("res://assets/music/spring_explore.wav")
const LOAD_SOUND := preload("res://assets/audio/commercial/nectar_collect.wav")
const DELIVER_SOUND := preload("res://assets/audio/commercial/handoff.wav")
const FINISH_SOUND := preload("res://assets/audio/commercial/complete.wav")
const LOSS_SOUND := preload("res://assets/audio/commercial/honey_loss.wav")
const INK := Color("2b4438")
const CREAM := Color("f8f0d9")
const GOLD := Color("e9b75e")
var model = Model.new()
var landscape: Node2D
var camera_center := Model.HIVE
var camera_origin := Vector2.ZERO
var font := preload("res://fonts/NotoSansCJKsc-ProjectSubset.otf")
var paused := false
var sound: AudioStreamPlayer
var music: AudioStreamPlayer
var pointer_target := Vector2.ZERO
var pointer_active := false
var touch_braking := false
var visual_time := 0.0
var hud: CanvasLayer
var action_button: Button
var brake_button: Button
var pause_button: Button
var status: Label
var paused_label: Label
var effects: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
var build_glow := 0.0
var delivery_glow := 0.0
var end_time := 0.0
var last_spills := 0
var last_stage := 0
var hint_label: Label
var result_controls: Control
var main_controls: Array[Control] = []

func _ready() -> void:
	DisplayServer.window_set_title("一会儿巢里见 · 雨水")
	rng.seed = 91328
	sound = AudioStreamPlayer.new()
	sound.bus = &"SFX"
	add_child(sound)
	music = AudioStreamPlayer.new()
	music.stream = MUSIC
	music.bus = &"Music"
	music.volume_db = -9.0
	add_child(music)
	music.finished.connect(func(): music.play())
	music.play()
	landscape = Node2D.new()
	landscape.set_script(preload("res://playtest/rain_route/route_landscape.gd"))
	landscape.show_behind_parent = true
	landscape.route = self
	add_child(landscape)
	_build_hud()
	_update_camera(1.0)

func _panel(rect: Rect2, color: Color, radius := 16, border := Color(0, 0, 0, 0)) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.border_color = border
	style.set_border_width_all(1 if border.a > 0 else 0)
	style.shadow_color = Color("112d24", 0.20)
	style.shadow_size = 0 if rect.size.y < 10 else 7
	style.shadow_offset = Vector2(0, 3)
	draw_style_box(style, rect)

func _button(text_value: String, point: Vector2, width: float, callback: Callable, light := false) -> Button:
	var button := Button.new()
	button.text = text_value
	button.position = point
	button.size = Vector2(width, 44)
	button.add_theme_font_override("font", font)
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", INK if light else CREAM)
	button.add_theme_color_override("font_hover_color", INK if light else Color.WHITE)
	button.add_theme_color_override("font_pressed_color", INK if light else Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color("8e9e85"))
	var style := StyleBoxFlat.new()
	style.bg_color = Color("f5e9c8") if light else Color("284b3d")
	style.set_corner_radius_all(13)
	style.border_color = Color("e6cd95") if light else Color("69836a")
	style.set_border_width_all(1)
	style.shadow_color = Color("122e22", 0.22)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 3)
	button.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate()
	hover.bg_color = Color("fff4d9") if light else Color("3f6652")
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	var disabled := style.duplicate()
	disabled.bg_color = Color("d8dcc9")
	button.add_theme_stylebox_override("disabled", disabled)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	hud.add_child(button)
	return button

func _label(point: Vector2, box_size: Vector2, size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = point
	label.size = box_size
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud.add_child(label)
	return label

func _build_hud() -> void:
	action_button = null
	hud = CanvasLayer.new()
	add_child(hud)
	action_button = _button("空格 · 取粉 / 交货", Vector2(831, 648), 229, _act)
	brake_button = _button("Shift · 慢飞", Vector2(1072, 648), 172, func(): pass, true)
	brake_button.button_down.connect(func(): touch_braking = true)
	brake_button.button_up.connect(func(): touch_braking = false)
	pause_button = _button("暂停", Vector2(1162, 27), 82, _toggle_pause, true)
	var restart := _button("重来", Vector2(1070, 27), 82, _restart, true)
	main_controls = [action_button, brake_button, pause_button, restart]
	status = _label(Vector2(53, 629), Vector2(720, 51), 17, INK)
	status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint_label = _label(Vector2(39, 692), Vector2(1000, 24), 13, INK)
	hint_label.text = "WASD / 方向键 / 点地面  飞行     Shift  慢飞接应     R  重来"
	paused_label = _label(Vector2(394, 296), Vector2(500, 85), 25, CREAM)
	paused_label.text = "暂停中"
	paused_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	paused_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result_controls = Control.new()
	result_controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(result_controls)
	var again := _button("再飞一次", Vector2(480, 426), 320, _restart)
	hud.remove_child(again)
	result_controls.add_child(again)
	result_controls.visible = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(music):
		paused = true
		music.stream_paused = true
		pointer_active = false
		touch_braking = false

func _toggle_pause() -> void:
	paused = not paused
	music.stream_paused = paused
	pointer_active = false
	touch_braking = false

func _restart() -> void:
	model = Model.new()
	camera_center = Model.HIVE
	_update_camera(1.0)
	effects.clear()
	build_glow = 0.0
	delivery_glow = 0.0
	end_time = 0.0
	last_spills = 0
	last_stage = 0
	paused = false
	music.stream_paused = false
	pointer_active = false
	touch_braking = false

func _burst(point: Vector2, color: Color, count: int) -> void:
	for index in range(count):
		effects.append({"point": point, "velocity": Vector2.from_angle(rng.randf_range(-PI, PI)) * rng.randf_range(15, 90), "age": 0.0, "life": rng.randf_range(0.4, 1.05), "color": color, "size": rng.randf_range(1.5, 3.8)})

func _act() -> void:
	if paused or model.complete:
		return
	var result: String = model.act()
	if result != "" or model.complete:
		sound.stream = FINISH_SOUND if model.complete else (DELIVER_SOUND if result == "deliver" else LOAD_SOUND)
		sound.play()
		_burst(model.position, GOLD, 16 if result == "deliver" else 8)
		if result == "deliver":
			delivery_glow = 1.6
		if model.stage != last_stage:
			build_glow = 2.0
			_burst(Model.BUILD_SITE, Color("d6e598"), 25)
			last_stage = model.stage

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_toggle_pause()
		elif event.keycode == KEY_R:
			_restart()
		elif event.is_action_pressed("action"):
			_act()
	elif event is InputEventJoypadButton and event.is_action_pressed("action"):
		_act()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if Model.BOUNDS.has_point((get_global_mouse_position() + camera_origin)):
			pointer_target = (get_global_mouse_position() + camera_origin)
			pointer_active = true
	elif event is InputEventScreenTouch and event.pressed and Model.BOUNDS.has_point(event.position + camera_origin):
		pointer_target = event.position + camera_origin
		pointer_active = true

func _physics_process(delta: float) -> void:
	if not paused:
		visual_time += delta
		if model.complete:
			end_time += delta
		var steering := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if steering.length() > 0.05:
			pointer_active = false
		elif pointer_active:
			var offset: Vector2 = pointer_target - model.position
			if offset.length() < 10.0:
				pointer_active = false
			else:
				steering = offset.normalized() * minf(1.0, offset.length() / 55.0)
		model.step(delta, steering, Input.is_physical_key_pressed(KEY_SHIFT) or touch_braking)
		if model.spills > last_spills:
			_burst(model.position, GOLD, 10)
			sound.stream = LOSS_SOUND
			sound.play()
			last_spills = model.spills
		build_glow = maxf(0, build_glow - delta)
		delivery_glow = maxf(0, delivery_glow - delta)
		for index in range(effects.size() - 1, -1, -1):
			var effect := effects[index]
			effect.age = float(effect.age) + delta
			effect.point = (effect.point as Vector2) + (effect.velocity as Vector2) * delta
			effect.velocity = (effect.velocity as Vector2).move_toward(Vector2(0, 12), delta * 75)
			if effect.age >= effect.life:
				effects.remove_at(index)
	status.text = _context_message()
	paused_label.visible = paused
	pause_button.text = "继续" if paused else "暂停"
	action_button.disabled = paused or model.complete
	brake_button.disabled = paused or model.complete
	result_controls.visible = model.complete and not paused
	for control in [action_button, brake_button, status, hint_label]:
		control.visible = not model.complete
	if model.position.distance_to(Model.HIVE) < 80.0:
		action_button.text = "空格 · 一起收工" if model.delivered >= 9 else "空格 · 交到巢里"
	elif model.position.distance_to(Model.FLOWERS) < 80.0:
		action_button.text = "已装满 · 可以出发" if model.cargo == 3 else "空格 · 再取一份粉"
	else:
		action_button.text = "空格 · 接回散粉"
	_update_camera(delta)
	landscape.queue_redraw()
	queue_redraw()

func _context_message() -> String:
	if build_glow > 0:
		return "新叶台撑起来了，洼地中间也能避雨。" if model.stage == 1 else "风向变了，去花田接三只伙伴一起回来。"
	if delivery_glow > 0:
		return "花粉交好了。大家正在巢里接货。"
	if model.position.distance_to(Model.FLOWERS) < 80:
		return "一份也能出发。带得越多，转弯越要提前。" if model.stage < 2 else "慢下来等伙伴跟上，再选一条一起回家的路。"
	if model.position.distance_to(Model.HIVE) < 80:
		return "沿叶下小径向东去花田，也可以从洼地穿过去。" if model.cargo == 0 else "到家了，按空格把花粉交给接货蜂。"
	if model.raining(model.position):
		return "雨正在落下。靠向叶下，掉下的花粉还能取回。"
	for bee in model.companions:
		if bee.waiting:
			return "有伙伴在等你。靠近它，按住 Shift 慢飞接回。"
	return "叶下能避雨。沿着树叶往前，路会绕回花田。" if model.sheltered(model.position) else "露天一直在下雨。留意花粉，沿叶下小径能避雨。"

func _text(point: Vector2, value: String, size: int, color := CREAM) -> void:
	draw_string(font, point, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _update_camera(delta: float) -> void:
	var target: Vector2 = model.position + model.velocity * 0.35
	camera_center = camera_center.lerp(target, 1.0 - exp(-5.5 * delta))
	camera_origin = (camera_center - Vector2(640, 360)).clamp(Vector2.ZERO, Vector2(2320, 1380))
	if is_instance_valid(landscape):
		landscape.position = -camera_origin

func _draw_hud() -> void:
	_panel(Rect2(28, 24, 374, 115), Color("f7efd7", 0.97), 20, Color("fff6dd", 0.65))
	_text(Vector2(50, 59), "雨水", 27, INK)
	_text(Vector2(119, 57), "把雨路跑通", 19, Color("566a48"))
	var goal: String = ["送回花粉，撑起中间的叶台", "再送一趟花粉，准备接伙伴", "接三只新蜂，一起返巢"][model.stage]
	_text(Vector2(50, 91), goal, 17, INK)
	for index in range(3):
		var rect := Rect2(50 + index * 112, 111, 99, 5)
		_panel(rect, Color("d8d8b9"), 2)
		var filled := clampf((model.delivered - index * 3) / 3.0, 0, 1)
		if filled > 0:
			draw_rect(Rect2(rect.position, Vector2(rect.size.x * filled, 5)), Color("729052"))
	_panel(Rect2(687, 25, 361, 76), Color("264b39", 0.96), 18, Color("a4b889", 0.5))
	_text(Vector2(711, 54), "巢里", 14, Color("c0d0ab"))
	_text(Vector2(711, 81), "%d / 9" % model.delivered, 23)
	_text(Vector2(818, 54), "身上花粉", 14, Color("c0d0ab"))
	for index in range(3):
		var center := Vector2(828 + index * 28, 75)
		draw_circle(center, 7.5, GOLD if index < model.cargo else Color("65765a"))
		if index < model.cargo:
			draw_circle(center + Vector2(-2, -2), 2, Color("fff0b5"))
	if model.stage >= 2:
		var following := 0
		for bee in model.companions:
			if not bee.waiting:
				following += 1
		_text(Vector2(935, 54), "伙伴", 14, Color("c0d0ab"))
		_text(Vector2(935, 81), "%d / 3" % following, 23)
	else:
		_text(Vector2(935, 54), "载荷", 14, Color("c0d0ab"))
		_text(Vector2(935, 80), "重" if model.cargo >= 2 else "轻", 22)
	if not model.complete:
		_panel(Rect2(28, 624, 777, 62), Color("f7efd7", 0.97), 16, Color("fff6dd", 0.6))
		draw_circle(Vector2(40, 653), 3, Color("79974d"))

func _draw() -> void:
	_draw_hud()
	# Compact route overview stays in screen space; positions are world coordinates.
	_panel(Rect2(29, 490, 212, 112), CREAM, 13, INK)
	_text(Vector2(44, 513), "雨水 · 花路", 15, INK)
	for i in range(Model.SAFE_ROUTE.size() - 1):
		draw_line(Vector2(40, 514) + Model.SAFE_ROUTE[i] * 0.053, Vector2(40, 514) + Model.SAFE_ROUTE[i + 1] * 0.053, Color("9ba885"), 2, true)
	draw_polyline(PackedVector2Array([Vector2(40, 514) + Model.HIVE * 0.053, Vector2(40, 514) + Model.BUILD_SITE * 0.053, Vector2(40, 514) + Model.FLOWERS * 0.053]), Color("c1b9a0"), 1.5, true)
	draw_rect(Rect2(Vector2(40, 514) + camera_origin * 0.053, Vector2(1280, 720) * 0.053), Color("637960", 0.4), false, 1)
	for p in [Model.HIVE, Model.FLOWERS]:
		draw_circle(Vector2(40, 514) + p * 0.053, 4, INK)
	draw_circle(Vector2(40, 514) + model.position * 0.053, 5, GOLD)
	if model.complete:
		_panel(Rect2(348, 204, 584, 290), CREAM, 24, INK)
		_text(Vector2(537, 248), "一会儿巢里见", 22, INK)
		_text(Vector2(403, 300), "这条路，大家都能走了。", 28, INK)
		_text(Vector2(416, 341), "叶台撑住了雨，伙伴也一起回来了。", 19, INK)
		_text(Vector2(422, 386), "%d 趟交货   ·   %d 次掉粉   ·   %d 次接回" % [model.deliveries, model.spills, model.rescues], 17, INK)
	if paused:
		draw_rect(Rect2(0, 145, 1280, 470), Color("142f24", 0.75))
