extends Node2D

const Model := preload("res://playtest/rain_route/route_model.gd")
const BEE := preload("res://assets/art/commercial/player_bee_topdown_states_v1.png")
const WORKER := preload("res://assets/art/commercial/worker_bee_topdown_v1.png")
const HIVE_ART := preload("res://assets/art/commercial/main_hive_exterior_v1.png")
const GROUND := preload("res://playtest/rain_route/art/rain_garden_v1.png")
const LEAF := preload("res://playtest/rain_route/art/leaf_canopy_v1.png")
const SHELTER_KIT := preload("res://playtest/rain_route/art/shelter_materials_v1.png")
const FLOWER_ART := preload("res://playtest/rain_route/art/pollen_flowers_v1.png")
const MUSIC := preload("res://assets/music/spring_explore.wav")
const LOAD_SOUND := preload("res://assets/audio/commercial/nectar_collect.wav")
const DELIVER_SOUND := preload("res://assets/audio/commercial/handoff.wav")
const FINISH_SOUND := preload("res://assets/audio/commercial/complete.wav")
const LOSS_SOUND := preload("res://assets/audio/commercial/honey_loss.wav")
const INK := Color("2b4438")
const CREAM := Color("f8f0d9")
const GOLD := Color("e9b75e")
var model = Model.new()
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
	_build_hud()

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
	hint_label = _label(Vector2(39, 692), Vector2(1000, 24), 13, CREAM)
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
			_burst(Vector2(650, 320), Color("d6e598"), 25)
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
		if Model.BOUNDS.has_point(get_global_mouse_position()):
			pointer_target = get_global_mouse_position()
			pointer_active = true
	elif event is InputEventScreenTouch and event.pressed and Model.BOUNDS.has_point(event.position):
		pointer_target = event.position
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
	queue_redraw()

func _context_message() -> String:
	if build_glow > 0:
		return "新叶台撑起来了，直路中间也能避雨。" if model.stage == 1 else "风向变了，去花田接三只伙伴一起回来。"
	if delivery_glow > 0:
		return "花粉交好了。大家正在巢里接货。"
	if model.position.distance_to(Model.FLOWERS) < 80:
		return "一份也能出发。带得越多，转弯越要提前。" if model.stage < 2 else "慢下来等伙伴跟上，再选一条一起回家的路。"
	if model.position.distance_to(Model.HIVE) < 80:
		return "花田在右边。穿雨近，叶下稳，自己选一条路。" if model.cargo == 0 else "到家了，按空格把花粉交给接货蜂。"
	if model.raining(model.position):
		return "雨正在落下。靠向叶下，掉下的花粉还能取回。"
	for bee in model.companions:
		if bee.waiting:
			return "有伙伴在等你。靠近它，按住 Shift 慢飞接回。"
	return "叶下能避雨。看看下一阵雨，准备好再出发。" if model.sheltered(model.position) else "看雨的空隙，也可以沿下方的叶棚绕行。"

func _text(point: Vector2, value: String, size: int, color := CREAM) -> void:
	draw_string(font, point, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _shadow(point: Vector2, radius: float, opacity := 0.22) -> void:
	draw_set_transform(point, 0, Vector2(1, 0.30))
	for index in range(5):
		draw_circle(Vector2.ZERO, radius + index * 2, Color("173b2a", opacity / 5.0))
	draw_set_transform(Vector2.ZERO)

func _bee(point: Vector2, scale_value: float, angle: float, tint := Color.WHITE, worker := false, loaded := false, fast := false) -> void:
	_shadow(point + Vector2(2, 20), scale_value * 0.35)
	var bob := sin(visual_time * 7 + point.x * 0.02) * 1.7
	draw_set_transform(point + Vector2(0, bob), angle, Vector2(1 + sin(visual_time * 36) * 0.016, 1.0))
	if worker:
		draw_texture_rect(WORKER, Rect2(-scale_value / 2, -scale_value / 2, scale_value, scale_value), false, tint)
	else:
		var frame := 2 if loaded else (1 if fast else 0)
		draw_texture_rect_region(BEE, Rect2(-scale_value / 2, -scale_value / 2, scale_value, scale_value), Rect2(frame * 256, 0, 256, 256), tint)
	draw_set_transform(Vector2.ZERO)

func _shelter(center: Vector2, radius: float, built := false, index := 0) -> void:
	_shadow(center + Vector2(5, 49), radius * 0.86, 0.42)
	var turn: float = sin(visual_time * 1.4 + index * 1.7) * 0.012 + [-0.045, 0.035, -0.022, 0.050][index % 4]
	var breathing := 1.0 + sin(visual_time * 1.1 + index) * 0.006
	draw_set_transform(center + Vector2(0, 9), turn, Vector2(breathing, 1.0))
	var tint := Color(0.88 + index * 0.025, 0.96, 0.86)
	if built:
		tint = Color(1.0, 1.0, 0.94)
	var reveal := clampf((radius + 20 - (model.position as Vector2).distance_to(center)) / 40.0, 0, 1)
	tint.a = 1.0 - reveal * 0.42
	draw_texture_rect(LEAF, Rect2(-radius * 1.20, -radius * 1.20, radius * 2.4, radius * 2.4), false, tint)
	draw_set_transform(Vector2.ZERO)
	# Water leaves the physical roof edge; no debug circle marks shelter space.
	var drop_phase := fposmod(visual_time * 0.65 + index * 0.37, 1)
	var droplet := center + Vector2(radius * 0.10, radius * 0.98 + drop_phase * 25)
	draw_line(droplet, droplet + Vector2(0, 4), Color("e6f4df", (1 - drop_phase) * 0.7), 1.5, true)
	if built and build_glow > 0:
		_text(center + Vector2(-40, -radius - 18), "叶台好了", 18, CREAM)

func _rain() -> void:
	for band_index in range(3):
		var area: Rect2 = model.rain_band(band_index)
		var phase: float = model.rain_phase(band_index)
		var wet := phase < 2.5
		var warning := phase > 3.6
		if not wet and not warning:
			continue
		var strength := minf(1.0, phase / 0.25 + 0.15) if wet else (phase - 3.6) * 0.40
		# Feathered local cloud shade and irregular falling droplets share the
		# exact same spatial predicate as the rain/canopy gameplay collision.
		for index in range(125):
			var offset_x := fposmod(index * 29.371, area.size.x)
			var speed := 235.0 + fposmod(index * 13.72, 105)
			var direction_sign := -1.0 if model.stage >= 2 else 1.0
			var y := 165 + fposmod(index * 53.29 + visual_time * speed * direction_sign, 450)
			var point := Vector2(area.position.x + offset_x, y)
			if model.sheltered(point):
				continue
			var direction := Vector2(-5, -15) if model.stage >= 2 else Vector2(5, 15)
			var alpha := (0.40 + fposmod(index * 0.079, 0.33)) * strength
			if wet:
				draw_line(point, point + direction * (0.6 + fposmod(index * 0.13, 0.7)), Color("dbeadb", alpha), 1.0, true)
				if index % 8 == 0:
					var ripple_point := Vector2(area.position.x + offset_x, 180 + fposmod(index * 49.9, 420))
					if not model.sheltered(ripple_point):
						var ripple := fposmod(visual_time * 1.7 + index * 0.13, 1)
						draw_set_transform(ripple_point, 0, Vector2(1, 0.35))
						draw_arc(Vector2.ZERO, 2 + ripple * 8, 0, TAU, 14, Color("d6e2c7", (1 - ripple) * 0.30), 1, true)
						draw_set_transform(Vector2.ZERO)
			else:
				draw_line(point, point + direction * 0.3, Color("c0d6c4", alpha * 0.65), 1, true)
		# Bent grass-like wind strokes make direction visible without labels.
		var wind_y := 226.0 + sin(visual_time * 1.6 + band_index) * 13
		var wind_points := PackedVector2Array()
		for j in range(12):
			wind_points.append(Vector2(area.position.x - 10 + j * 10, wind_y + sin(j * 0.25) * (12 if model.stage < 2 else -12)))
		draw_polyline(wind_points, Color("eff2d6", 0.22 * strength), 1, true)

func _tag(point: Vector2, label: String, width: float) -> void:
	_panel(Rect2(point, Vector2(width, 32)), Color("234936", 0.87), 11)
	_text(point + Vector2(13, 22), label, 15)

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
	draw_texture_rect(GROUND, Rect2(0, 0, 1280, 720), false)
	# Darker edge vignette keeps the sunlit playable clearing open and readable.
	for index in range(14):
		draw_rect(Rect2(0, index * 3, 1280, 3), Color("153d2b", 0.18 * (1 - index / 14.0)))
		draw_rect(Rect2(0, 720 - index * 3, 1280, 3), Color("153d2b", 0.28 * (1 - index / 14.0)))
	for index in range(Model.SHELTERS.size()):
		_shelter(Model.SHELTERS[index], 121.0, false, index)
	if model.stage >= 1:
		_shelter(Vector2(650, 320), 84.0, true)
	# The unfinished site is a small work bundle, never a target circle.
	else:
		_shadow(Vector2(650, 331), 36, 0.22)
		draw_texture_rect(SHELTER_KIT, Rect2(594, 265, 112, 112), false)
	_rain()
	_shadow(Model.HIVE + Vector2(0, 57), 78, 0.42)
	draw_texture_rect(HIVE_ART, Rect2(Model.HIVE + Vector2(-94, -121), Vector2(188, 210)), false)
	# A waiting worker and delivery motion give the entrance a living scale.
	var host_point := Model.HIVE + Vector2(39 + sin(visual_time * 1.4) * 6, 36)
	_bee(host_point, 35, -0.12, Color.WHITE, true)
	if delivery_glow > 0:
		for i in range(8):
			var t := fposmod(visual_time * 1.5 + i / 8.0, 1)
			draw_circle(Model.HIVE + Vector2(20 - t * 28, 10 - t * 38), 2.5, Color("f9d677", (1 - t) * delivery_glow / 1.6))
	_shadow(Model.FLOWERS + Vector2(0, 39), 60, 0.28)
	draw_set_transform(Model.FLOWERS, sin(visual_time * 1.7) * 0.018)
	draw_texture_rect(FLOWER_ART, Rect2(-95, -106, 190, 190), false)
	draw_set_transform(Vector2.ZERO)
	for i in range(8):
		var t := fposmod(visual_time * 0.3 + i * 0.13, 1)
		var p := Model.FLOWERS + Vector2(sin(i * 2.1 + visual_time * 0.2) * 41, 10 - t * 47)
		draw_circle(p, 1.7, Color("ffd875", sin(t * PI) * 0.75))
	if model.position.distance_to(Model.HIVE) < 135:
		_tag(Vector2(75, 432), "巢门 · 交货", 122)
	if model.position.distance_to(Model.FLOWERS) < 135:
		_tag(Vector2(1067, 432), "花田 · 取粉", 129)
	for point: Vector2 in model.drops:
		_shadow(point + Vector2(0, 8), 15, 0.30)
		for index in range(8):
			var p := point + Vector2.from_angle(index * TAU / 8) * (5 + index % 3 * 3)
			draw_circle(p, 2.5, GOLD)
			draw_circle(p + Vector2(-0.7, -0.7), 1, Color("fff2b6"))
		var shine := fposmod(visual_time + point.x, 2.0)
		if shine < 0.9:
			draw_line(point + Vector2(-4, -15), point + Vector2(4, -15), Color("fff1b5", 1 - shine), 1.3, true)
			draw_line(point + Vector2(0, -19), point + Vector2(0, -11), Color("fff1b5", 1 - shine), 1.3, true)
	for bee in model.companions:
		_bee(bee.position, 43.0, sin(visual_time * 3) * 0.08, Color("ede9cb") if bee.waiting else Color.WHITE, true)
		if bee.waiting:
			var p: Vector2 = bee.position + Vector2(-12, -45)
			_panel(Rect2(p, Vector2(24, 26)), CREAM, 8)
			_text(p + Vector2(8, 18), "!", 17, INK)
	_bee(model.position, 62.0, clampf(model.velocity.x / 500.0, -0.35, 0.35), Color.WHITE, false, model.cargo > 0, model.velocity.length() > 140)
	for index in range(model.cargo):
		var p: Vector2 = model.position + Vector2(-9 + index * 8, 12)
		for j in range(3):
			draw_circle(p + Vector2((j - 1) * 3, (j % 2) * 3), 2.1, Color("edc254"))
	for effect in effects:
		var color: Color = effect.color
		color.a *= 1 - float(effect.age) / float(effect.life)
		draw_circle(effect.point, effect.size, color)
	if pointer_active:
		var p := pointer_target
		draw_line(p + Vector2(-5, 0), p + Vector2(5, 0), Color("f9edbd", 0.85), 1.6, true)
		draw_line(p + Vector2(0, -5), p + Vector2(0, 5), Color("f9edbd", 0.85), 1.6, true)
	_draw_hud()
	if model.complete:
		draw_rect(Rect2(0, 145, 1280, 470), Color("183b2b", 0.12))
		for index in range(12):
			var t := fposmod(visual_time * 0.075 + float(index) / 12, 1)
			_bee(Vector2(1110 - t * 960, 521 + sin(t * PI) * 37), 37, -0.14, Color.WHITE, true)
		_panel(Rect2(348, 204, 584, 290), Color("f7efd7", 0.98), 24, Color("fff4cf"))
		_text(Vector2(537, 248), "一会儿巢里见", 22, Color("74824d"))
		_text(Vector2(403, 300), "这条路，大家都能走了。", 28, INK)
		_text(Vector2(416, 341), "叶台撑住了雨，伙伴也一起回来了。", 19, Color("62724e"))
		_text(Vector2(422, 386), "%d 趟交货   ·   %d 次掉粉   ·   %d 次接回" % [model.deliveries, model.spills, model.rescues], 17, Color("6e795b"))
	if paused:
		draw_rect(Rect2(0, 145, 1280, 470), Color("142f24", 0.75))
