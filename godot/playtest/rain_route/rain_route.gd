extends Node2D

const Model := preload("res://playtest/rain_route/route_model.gd")
const BEE := preload("res://assets/art/commercial/player_bee_topdown_states_v1.png")
const HIVE_ART := preload("res://assets/art/commercial/main_hive_exterior_v1.png")
const GROUND := preload("res://assets/art/commercial/spring_world_ground_v1.png")
const FLOWER_ART := preload("res://assets/art/commercial/flower_states_topdown_v1.png")
const MUSIC := preload("res://assets/music/spring_explore.wav")
const LOAD_SOUND := preload("res://assets/audio/commercial/nectar_collect.wav")
const DELIVER_SOUND := preload("res://assets/audio/commercial/handoff.wav")
const FINISH_SOUND := preload("res://assets/audio/commercial/complete.wav")
var model = Model.new()
var font := preload("res://fonts/NotoSansCJKsc-ProjectSubset.otf")
var paused := false
var sound: AudioStreamPlayer
var music: AudioStreamPlayer
var pointer_target := Vector2.ZERO
var pointer_active := false
var touch_braking := false
var trail: Array[Vector2] = []
var visual_time := 0.0
var hud: CanvasLayer
var action_button: Button
var brake_button: Button
var pause_button: Button
var status: Label
var paused_label: Label

func _ready() -> void:
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

func _button(text_value: String, point: Vector2, width: float, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text_value
	button.position = point
	button.size = Vector2(width, 40)
	button.add_theme_font_override("font", font)
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", Color("f6edc9"))
	var style := StyleBoxFlat.new()
	style.bg_color = Color("294e45")
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	button.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate()
	hover.bg_color = Color("447763")
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	hud.add_child(button)
	return button

func _build_hud() -> void:
	hud = CanvasLayer.new()
	add_child(hud)
	action_button = _button("空格 · 取粉 / 交货", Vector2(836, 664), 202, _act)
	brake_button = _button("按住慢飞", Vector2(1050, 664), 124, func(): pass)
	brake_button.button_down.connect(func(): touch_braking = true)
	brake_button.button_up.connect(func(): touch_braking = false)
	pause_button = _button("暂停", Vector2(1158, 28), 86, _toggle_pause)
	_button("重来", Vector2(1058, 28), 86, _restart)
	status = Label.new()
	status.position = Vector2(40, 622)
	status.size = Vector2(1195, 36)
	status.add_theme_font_override("font", font)
	status.add_theme_font_size_override("font_size", 18)
	status.add_theme_color_override("font_color", Color("f4eac7"))
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud.add_child(status)
	paused_label = Label.new()
	paused_label.text = "暂停中 · 按 Esc 或右上角继续"
	paused_label.position = Vector2(394, 290)
	paused_label.size = Vector2(500, 85)
	paused_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	paused_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	paused_label.add_theme_font_override("font", font)
	paused_label.add_theme_font_size_override("font_size", 24)
	hud.add_child(paused_label)

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
	trail.clear()
	paused = false
	music.stream_paused = false
	pointer_active = false
	touch_braking = false

func _act() -> void:
	if paused or model.complete:
		return
	var result: String = model.act()
	if result != "" or model.complete:
		sound.stream = FINISH_SOUND if model.complete else (DELIVER_SOUND if result == "deliver" else LOAD_SOUND)
		sound.play()

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
		if trail.is_empty() or (trail[-1] as Vector2).distance_to(model.position) > 9.0:
			trail.append(model.position)
			if trail.size() > 35:
				trail.pop_front()
	status.text = model.notice
	paused_label.visible = paused
	pause_button.text = "继续" if paused else "暂停"
	action_button.disabled = paused or model.complete
	brake_button.disabled = paused or model.complete
	if model.position.distance_to(Model.HIVE) < 80.0:
		action_button.text = "空格 · 一起收工" if model.delivered >= 9 else "空格 · 交到巢里"
	elif model.position.distance_to(Model.FLOWERS) < 80.0:
		action_button.text = "已装满 · 可以出发" if model.cargo == 3 else "空格 · 再取一份粉"
	else:
		action_button.text = "空格 · 接回散粉"
	queue_redraw()

func _text(point: Vector2, value: String, size: int, color := Color("f3ebc8")) -> void:
	draw_string(font, point, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _bee(point: Vector2, scale_value: float, angle: float, tint := Color.WHITE) -> void:
	draw_circle(point + Vector2(3, 9), scale_value * 0.29, Color(0.03, 0.15, 0.12, 0.22))
	draw_set_transform(point, angle)
	draw_texture_rect_region(BEE, Rect2(-scale_value / 2, -scale_value / 2, scale_value, scale_value), Rect2(0, 0, 256, 256), tint)
	draw_set_transform(Vector2.ZERO)

func _shelter(center: Vector2, radius: float, built := false) -> void:
	# Geometric canopy footprint is gameplay geometry, not a decorative asset.
	draw_circle(center + Vector2(0, 10), radius + 3, Color("173e38", 0.25))
	draw_circle(center, radius, Color("315d45", 0.88))
	draw_arc(center, radius - 5, 0.15, 3.1, 40, Color("7d9f5b"), 3.0, true)
	draw_line(center + Vector2(-radius * 0.72, 30), center + Vector2(radius * 0.72, -30), Color("6b8e57"), 2.0, true)
	if built:
		draw_arc(center, radius + 6, 0, TAU, 56, Color("f5d476"), 2.5, true)
		_text(center + Vector2(-43, 8), "新叶台", 17)

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color("172f2d"))
	draw_texture_rect(GROUND, Rect2(0, 115, 1280, 505), false, Color("a9bba7"))
	draw_rect(Rect2(0, 115, 1280, 505), Color("244f48", 0.58))
	for center: Vector2 in Model.SHELTERS:
		_shelter(center, 121.0)
	if model.stage >= 1:
		_shelter(Vector2(650, 320), 84.0, true)
	else:
		draw_arc(Vector2(650, 320), 64, 0, TAU, 48, Color("f1d08a", 0.33), 2.0, true)
		_text(Vector2(598, 325), "待撑叶台", 17, Color("e6d8ad", 0.60))
	for index in range(3):
		var area: Rect2 = model.rain_band(index)
		var wet: bool = model.rain_phase(index) < 2.5
		var warning: bool = model.rain_phase(index) > 3.6
		if wet or warning:
			for x in range(int(area.position.x), int(area.end.x), 14):
				for y in range(172, 608, 24):
					var point := Vector2(x, y + fposmod(visual_time * 150.0, 24))
					if not model.sheltered(point):
						var direction := Vector2(-7, -15) if model.stage >= 2 else Vector2(7, 15)
						draw_line(point, point + direction, Color("bde7e6", 0.7 if wet else 0.16), 1.7 if wet else 1.0, true)
			_text(Vector2(area.position.x + 12, 190), "落雨" if wet else "将落雨", 14, Color("d7eddb", 0.9 if wet else 0.5))
	draw_circle(Model.HIVE, 88.0, Color("dfbd65", 0.17))
	draw_texture_rect(HIVE_ART, Rect2(52, 230, 150, 164), false)
	_text(Vector2(80, 423), "巢门 · 交货", 18)
	draw_circle(Model.FLOWERS, 85.0, Color("efd7a1", 0.17))
	for offset in [Vector2(-25, -35), Vector2(25, 5), Vector2(-24, 38)]:
		draw_texture_rect_region(FLOWER_ART, Rect2(Model.FLOWERS + offset - Vector2(33, 33), Vector2(66, 66)), Rect2(0, 0, 256, 256))
	_text(Vector2(1078, 445), "花田 · 取粉", 18)
	_text(Vector2(462, 589), "叶下绕行 · 不淋雨", 18, Color("d3dfac"))
	for index in range(trail.size()):
		draw_circle(trail[index], 2.5, Color("f8d68a", float(index) / maxf(1, trail.size()) * 0.4))
	for point: Vector2 in model.drops:
		for index in range(5):
			draw_circle(point + Vector2.from_angle(index * TAU / 5) * 9, 3.4, Color("f7cb61"))
		draw_arc(point, 21 + sin(visual_time * 3) * 2, 0, TAU, 24, Color("f6d683"), 1.4, true)
	for bee in model.companions:
		_bee(bee.position, 42.0, sin(visual_time * 3) * 0.08)
		if bee.waiting:
			draw_arc(bee.position, 27, 0, TAU, 32, Color("f7d087"), 2, true)
			_text(bee.position + Vector2(-22, -31), "等你", 15)
	_bee(model.position, 58.0, clampf(model.velocity.x / 500.0, -0.35, 0.35))
	for index in range(model.cargo):
		draw_circle(model.position + Vector2(-12 + index * 12, 28), 4.5, Color("ffd86d"))
	if pointer_active:
		draw_arc(pointer_target, 12, 0, TAU, 24, Color("f4e7b8", 0.7), 1.5, true)
	# Quiet, fixed HUD outside all navigable and interactive world geometry.
	draw_rect(Rect2(0, 0, 1280, 115), Color("172f2d"))
	_text(Vector2(36, 43), "雨水", 28)
	_text(Vector2(111, 42), "把雨路跑通", 22)
	_text(Vector2(38, 81), ["先运三份花粉，撑起中间的叶台", "叶台已建好，再运三份，准备接伙伴", "换风了 · 接三只新蜂一起返巢"][model.stage], 17, Color("c9d5b8"))
	_text(Vector2(645, 38), "巢里  %d / 9" % model.delivered, 21)
	_text(Vector2(645, 77), "身上  %d / 3" % model.cargo, 18, Color("ecc66a"))
	if model.stage >= 2:
		var following := 0
		for bee in model.companions:
			if not bee.waiting:
				following += 1
		_text(Vector2(840, 77), "跟队  %d / 3" % following, 17)
	else:
		_text(Vector2(840, 77), "轻载灵活 · 重载转弯慢", 16, Color("c9d5b8"))
	draw_rect(Rect2(0, 618, 1280, 102), Color("172f2d"))
	_text(Vector2(40, 689), "WASD / 方向键 / 点地面  飞行     Shift  慢飞接应     R  重来", 16, Color("adc4b6"))
	if model.complete:
		draw_rect(Rect2(0, 115, 1280, 503), Color("153c35", 0.88))
		for index in range(12):
			var t := fposmod(visual_time * 0.08 + float(index) / 12, 1.0)
			_bee(Vector2(1100 - t * 920, 466 + sin(t * PI) * 65), 37, -0.2, Color("fff0b7"))
		_text(Vector2(355, 255), "这条路，大家都能走了。", 34)
		_text(Vector2(369, 309), "叶台撑住了雨，伙伴也跟你一起回来了。", 21)
		_text(Vector2(414, 361), "%d 趟交货 · %d 次掉粉 · %d 次接回应援" % [model.deliveries, model.spills, model.rescues], 19, Color("cdd6b5"))
		_text(Vector2(421, 402), "按 R 再飞一次，试试另一条路。", 21)
	if paused:
		draw_rect(Rect2(0, 115, 1280, 503), Color("142927", 0.88))
