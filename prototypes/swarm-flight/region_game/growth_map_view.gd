extends Control
## A camera for the paper map. Buttons use native Control coordinates underneath
## the same transform as the artwork, so zoom never changes hit testing or costs.
signal magnification_changed(value: float)
signal blank_clicked
signal overview_requested
const MAX_ZOOM := 4.4
const STEP := 1.28
const DEAD_ZONE := .40
var board
var detail_overlay: Control
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
var book_open := false
var bookmark_path := ""
var last_view: Dictionary = {}
var saved_on_disk := false
var previous_size := Vector2.ZERO

func attach(map_board: Control) -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	board = map_board
	board.reparent(self,false)
	board.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	board.navigated.connect(center_selection)
	resized.connect(_fit_bounds)
	visibility_changed.connect(_visibility)
	get_window().focus_exited.connect(_clear_inputs)
	Input.joy_connection_changed.connect(_joy_connection)
	_fit_bounds()
	_visibility()

func _visibility() -> void:
	_clear_inputs()

func open_book(progress_path: String) -> void:
	if book_open: return
	book_open = true
	var path := progress_path + ".growth-view.json"
	if path != bookmark_path:
		last_view = {}
		bookmark_path = path
		saved_on_disk = true
	if saved_on_disk or last_view.is_empty():
		last_view = _read_bookmark(path)
		saved_on_disk = not last_view.is_empty()
	if restore_view(last_view):
		# Compare later edits to the transform as represented by this viewport.
		last_view = capture_view()
		return
	last_view = {}
	saved_on_disk = false
	# The labels appear at 178%. Start with a readable neighbourhood on both window sizes.
	var value := clampf(2.75 * 1280.0 / maxf(1.0,get_window().size.x),2.75,3.25)
	_set_zoom(value)
	# Once every live rank is owned, the sealed reserve is the closing landmark.
	var first := "reserve"
	for state in ["ready","poor","locked"]:
		var found := false
		for id in board.visible_ids():
			if board.buttons[id].state == state:
				first = id
				found = true
				break
		if found: break
	_select_current_rank(first)
	center_selection(false)

func _select_current_rank(id: String) -> void:
	var ranks: Array = board.entries[id].ranks
	board.select_rank(ranks[mini(board.rank_of(id),ranks.size()-1)])

func close_book() -> void:
	if not book_open: return
	book_open = false
	_clear_inputs()
	var current := capture_view()
	# A second copy that simply opened/closed the book need not overwrite another reader.
	if saved_on_disk and current == last_view: return
	last_view = current
	saved_on_disk = _write_bookmark(bookmark_path,current)

func forget_book(progress_path: String) -> void:
	var path := progress_path+".growth-view.json"
	if bookmark_path == path:
		book_open = false
		last_view = {}
		saved_on_disk = false
	if FileAccess.file_exists(path): DirAccess.remove_absolute(path)

static func _read_bookmark(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null or file.get_length() > 4096: return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or not json.data is Dictionary: return {}
	return json.data

static func _write_bookmark(path: String, value: Dictionary) -> bool:
	var temporary := "%s.%d.tmp" % [path,OS.get_process_id()]
	var file := FileAccess.open(temporary,FileAccess.WRITE)
	if file == null: return false
	var written := file.store_string(JSON.stringify(value,"",true,true))
	file.close()
	if written and DirAccess.rename_absolute(temporary,path) == OK: return true
	DirAccess.remove_absolute(temporary)
	return false

func capture_view() -> Dictionary:
	var center := _normalized_center(size)
	return {"cell":str(board.selected),"rank":str(board.inspect_data().id),"zoom":magnification,
		"x":center.x,"y":center.y}

func restore_view(value: Dictionary) -> bool:
	var id: Variant = value.get("cell")
	if not id is String or not board.entries.has(id): return false
	for key in ["zoom","x","y"]:
		var n: Variant = value.get(key)
		if not (n is float or n is int) or not is_finite(float(n)): return false
	var rank: Variant = value.get("rank")
	if rank is String and rank in board.entries[id].ranks:
		board.select_rank(rank)
	else:
		_select_current_rank(id)
	_stop_glide()
	_set_zoom(clampf(float(value.zoom),1.0,MAX_ZOOM))
	_move_center(Vector2(value.x,value.y).clamp(Vector2.ZERO,Vector2.ONE))
	return true

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
	var center := _normalized_center(previous_size)
	_stop_glide()
	board.size = size
	previous_size = size
	_move_center(center)

func _normalized_center(extent: Vector2) -> Vector2:
	if extent.x <= 0 or extent.y <= 0: return Vector2(.5,.5)
	return (extent*.5-board.position)/(extent*magnification)

func _move_center(center: Vector2) -> void:
	board.position = _bounded(size*.5-center*size*magnification)

func _bounded(origin: Vector2) -> Vector2:
	return origin.clamp((size-size*magnification).min(Vector2.ZERO),Vector2.ZERO)

func _stop_glide() -> void:
	if glide:
		glide.kill()
		glide = null

func reset_view() -> void:
	_stop_glide()
	_set_zoom(1.0)
	board.position = Vector2.ZERO
	overview_requested.emit()

func _set_zoom(value: float) -> void:
	magnification = value
	board.scale = Vector2.ONE*value
	board.update_lod(value)
	magnification_changed.emit(value)

func zoom_at(factor: float, at: Vector2) -> void:
	if not is_finite(factor) or factor <= 0: return
	var value := clampf(magnification*factor,1.0,MAX_ZOOM)
	if is_equal_approx(value,magnification): return
	_stop_glide()
	var map_point: Vector2 = (at-board.position)/magnification
	_set_zoom(value)
	board.position = _bounded(at-map_point*value)

func zoom_selected(factor: float) -> void:
	var at: Vector2 = board.position+board.point(board.selected)*magnification
	zoom_at(factor,at.clamp(Vector2.ZERO,size))
	if not Rect2(Vector2.ZERO,size).has_point(at): center_selection()

func _pan(amount: Vector2) -> void:
	_stop_glide()
	board.position = _bounded(board.position+amount)

func center_selection(animate := true) -> void:
	var target := _bounded(size*.5-board.point(board.selected)*magnification)
	_stop_glide()
	if not animate or board.reduced_motion or target.distance_squared_to(board.position)<1.0:
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

func _over_detail(viewport_pos: Vector2) -> bool:
	if not is_instance_valid(detail_overlay) or not detail_overlay.is_visible_in_tree(): return false
	var local := detail_overlay.get_global_transform_with_canvas().affine_inverse()*viewport_pos
	return Rect2(Vector2.ZERO,detail_overlay.size).has_point(local)

func _pointer(event: InputEvent) -> bool:
	var at: Vector2 = get_global_transform_with_canvas().affine_inverse()*event.position
	var on_map := Rect2(Vector2.ZERO,size).has_point(at)
	if pressed_map:
		if event is InputEventMouseMotion:
			if at.distance_to(press_at)>=5: dragging = true
			if dragging and magnification>1:
				_pan(at-last_pointer)
				last_pointer = at
			return true
		if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed:
			var clicked := not dragging and at.distance_to(press_at)<5
			dragging = false
			pressed_map = false
			if clicked and on_map and not _over_detail(event.position):
				var released_node := _node_at(at)
				if released_node==press_node:
					if released_node.is_empty(): blank_clicked.emit()
					else: board.select_node(released_node)
			press_node = ""
			return true
	if not on_map or _over_detail(event.position): return false
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
