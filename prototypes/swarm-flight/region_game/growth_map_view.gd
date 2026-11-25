extends Control
## A camera for the paper map. Buttons use native Control coordinates underneath
## the same transform as the artwork, so zoom never changes hit testing or costs.
signal magnification_changed(value: float)
const MAX_ZOOM := 4.4
const STEP := 1.28
const DEAD_ZONE := .40
var board
var magnification := 1.0
var dragging := false
var pressed_map := false
var press_node := ""
var press_at := Vector2.ZERO
var last_pointer := Vector2.ZERO
var glide: Tween
var left_stick := Vector2.ZERO
var right_stick := Vector2.ZERO
var stick_key := 0
var repeat_left := 0.0
var trigger_down := [false,false]
var suspended := false

func attach(map_board: Control) -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	board = map_board
	board.reparent(self,false)
	board.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	board.selected_changed.connect(_follow)
	resized.connect(_fit_bounds)
	visibility_changed.connect(_visibility)
	get_window().focus_exited.connect(_clear_inputs)
	Input.joy_connection_changed.connect(_joy_connection)
	_fit_bounds()
	_visibility()

func _visibility() -> void:
	_clear_inputs()
	reset_view()

func suspend(value: bool) -> void:
	suspended = value
	_clear_inputs()

func _joy_connection(_device: int, connected: bool) -> void:
	if not connected: _clear_inputs()

func _clear_inputs() -> void:
	_stop_glide()
	dragging = false
	pressed_map = false
	left_stick = Vector2.ZERO
	right_stick = Vector2.ZERO
	stick_key = 0
	trigger_down = [false,false]
	set_process(false)

func _fit_bounds() -> void:
	board.size = size
	board.position = _bounded(board.position)

func _bounded(origin: Vector2) -> Vector2:
	return origin.clamp((size-size*magnification).min(Vector2.ZERO),Vector2.ZERO)

func _stop_glide() -> void:
	if glide:
		glide.kill()
		glide = null

func reset_view() -> void:
	_stop_glide()
	magnification = 1.0
	board.scale = Vector2.ONE
	board.position = Vector2.ZERO
	if board.has_method("update_lod"): board.update_lod(magnification)
	magnification_changed.emit(magnification)

func zoom_at(factor: float, at: Vector2) -> void:
	if not is_finite(factor) or factor <= 0: return
	var value := clampf(magnification*factor,1.0,MAX_ZOOM)
	if is_equal_approx(value,magnification): return
	_stop_glide()
	var map_point: Vector2 = (at-board.position)/magnification
	magnification = value
	board.scale = Vector2.ONE*value
	board.position = _bounded(at-map_point*value)
	if board.has_method("update_lod"): board.update_lod(value)
	magnification_changed.emit(value)

func zoom_selected(factor: float) -> void:
	var at: Vector2 = board.position+board.point(board.selected)*magnification
	zoom_at(factor,at.clamp(Vector2.ZERO,size))
	_follow(board.selected)

func _pan(amount: Vector2) -> void:
	_stop_glide()
	board.position = _bounded(board.position+amount)

func _follow(id: String) -> void:
	if magnification <= 1.0 or dragging: return
	var local: Vector2 = board.position + board.point(id)*magnification
	# Give both the illustration and its caption room inside the paper edge.
	var inset := size.min(Vector2(175,170)*magnification)*.5
	var target := _bounded(board.position+local.clamp(inset,size-inset)-local)
	_stop_glide()
	if board.reduced_motion or target.distance_squared_to(board.position)<1.0:
		board.position = target
	else:
		glide = create_tween()
		glide.tween_property(board,"position",target,.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _node_at(at: Vector2) -> String:
	var in_map: Vector2 = (at-board.position)/magnification
	var nearest := ""
	var distance := INF
	for id in board.visible_ids():
		var node: Control = board.buttons[id]
		if not node._has_point(node.get_transform().affine_inverse()*in_map): continue
		var squared: float = board.point(id).distance_squared_to(in_map)
		if squared < distance:
			distance = squared
			nearest = id
	return nearest

func _input(event: InputEvent) -> void:
	if board == null or suspended or not is_visible_in_tree(): return
	if event is InputEventMouse or event is InputEventGesture:
		if _pointer(event): get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		var key: int = event.physical_keycode if event.physical_keycode else event.keycode
		match key:
			KEY_EQUAL,KEY_PLUS,KEY_KP_ADD: zoom_selected(STEP)
			KEY_MINUS,KEY_KP_SUBTRACT: zoom_selected(1.0/STEP)
			KEY_HOME,KEY_0: reset_view()
			_: return
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton:
		if event.button_index not in [JOY_BUTTON_LEFT_SHOULDER,JOY_BUTTON_RIGHT_SHOULDER,JOY_BUTTON_RIGHT_STICK]: return
		if event.pressed:
			match event.button_index:
				JOY_BUTTON_LEFT_SHOULDER: zoom_selected(1.0/STEP)
				JOY_BUTTON_RIGHT_SHOULDER: zoom_selected(STEP)
				JOY_BUTTON_RIGHT_STICK: reset_view()
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadMotion and _axis(event):
		get_viewport().set_input_as_handled()

func _pointer(event: InputEvent) -> bool:
	var at: Vector2 = get_global_transform_with_canvas().affine_inverse()*event.position
	if pressed_map:
		if event is InputEventMouseMotion:
			if not dragging and magnification>1 and at.distance_to(press_at)>=5:
				dragging = true
			if dragging:
				_pan(at-last_pointer)
				last_pointer = at
			return true
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			pressed_map = false
			var clicked := not dragging and not press_node.is_empty() and at.distance_to(press_at)<5
			dragging = false
			if clicked and Rect2(Vector2.ZERO,size).has_point(at) and _node_at(at)==press_node:
				board.select_node(press_node)
			return true
	if not Rect2(Vector2.ZERO,size).has_point(at): return false
	if event is InputEventMagnifyGesture:
		zoom_at(event.factor,at)
		return true
	if event is InputEventPanGesture:
		_pan(-event.delta*28)
		return true
	if not event is InputEventMouseButton or not event.pressed: return false
	match event.button_index:
		MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN:
			var steps: float = event.factor if event.factor>0 else 1.0
			zoom_at(pow(STEP,steps if event.button_index==MOUSE_BUTTON_WHEEL_UP else -steps),at)
		MOUSE_BUTTON_LEFT:
			_stop_glide()
			pressed_map = true
			dragging = false
			press_at = at
			press_node = _node_at(at)
			last_pointer = at
		_: return false
	return true

func _axis(event: InputEventJoypadMotion) -> bool:
	match event.axis:
		JOY_AXIS_LEFT_X: left_stick.x = event.axis_value
		JOY_AXIS_LEFT_Y: left_stick.y = event.axis_value
		JOY_AXIS_RIGHT_X: right_stick.x = event.axis_value
		JOY_AXIS_RIGHT_Y: right_stick.y = event.axis_value
		JOY_AXIS_TRIGGER_LEFT,JOY_AXIS_TRIGGER_RIGHT:
			var index := 0 if event.axis == JOY_AXIS_TRIGGER_LEFT else 1
			if event.axis_value > .62 and not trigger_down[index]:
				trigger_down[index] = true
				zoom_selected(1.0/STEP if index == 0 else STEP)
			elif event.axis_value < .32: trigger_down[index] = false
			return true
		_: return false
	if left_stick.length()<DEAD_ZONE: stick_key = 0
	set_process(left_stick.length()>=DEAD_ZONE or right_stick.length()>=DEAD_ZONE)
	return true

func _process(dt: float) -> void:
	if left_stick.length()>=DEAD_ZONE:
		var key: int
		if absf(left_stick.x)>absf(left_stick.y): key = KEY_RIGHT if left_stick.x>0 else KEY_LEFT
		else: key = KEY_DOWN if left_stick.y>0 else KEY_UP
		repeat_left -= dt
		if key != stick_key or repeat_left <= 0:
			board.navigate(key)
			repeat_left = .34 if key != stick_key else .17
			stick_key = key
	if right_stick.length()>=DEAD_ZONE:
		_pan(-right_stick.limit_length()*size.y*1.35*dt)
