extends Control
## A full-screen overlay for the growth book. Its parent restores the book on closed.
signal closed

const Bay = preload("res://region_game/honey_growth_bay_model.gd")
const Art = preload("res://art_sprites.gd")
const POND: Texture2D = preload("res://art/collection-pond.webp")
const FLOWER: Texture2D = preload("res://art/collection-blue-bloom.webp")
const STAGES := ["初章 · 亲采","中期 · 串花","后期 · 花瀑","满档 · 连锁"]
const RULES := [
	"每朵花各采一份。按住采蜜，依次飞向 A、B、C。",
	"亲手连采三朵，串花会多收附近一朵成熟花。",
	"连续按住采蜜穿过三朵，串花后会沿飞行方向再跳至多两朵。",
	"串花可多收两朵，接出的花瀑沿飞行方向至多再跳三朵。",
]
const KINDS := ["亲采","串花","花瀑"]
const COLORS := [Color("#ffdd8a"),Color("#c3f2c2"),Color("#9de6f6")]
var bay := Bay.new()
var page_font := SystemFont.new()
var plot: Control
var stage_picker: OptionButton
var load_picker: OptionButton
var sticky_button: Button
var rule_label: Label
var wallet_label: Label
var receipt_label: Label
var selected_stage := 0
var key_holding := false
var pointer_holding := false
var touch_index := -1
var closing := false
var reduced_motion := false
var stage_buttons: Array[Button] = []

func setup(rank_or_cell: String) -> void:
	if rank_or_cell.begins_with("cascade"):
		selected_stage = 3 if rank_or_cell == "cascade2" else 2
	elif rank_or_cell.begins_with("garland") or rank_or_cell.begins_with("petal_trace"):
		selected_stage = 1
	else:
		selected_stage = 0
	if is_node_ready():
		stage_picker.select(selected_stage)
		_reset()

func _ready() -> void:
	name = "HoneyGrowthBayPreview"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 30
	page_font.font_names = PackedStringArray(["PingFang SC","Microsoft YaHei","Noto Sans CJK SC","sans-serif"])
	var page_theme := Theme.new()
	page_theme.default_font = page_font
	page_theme.default_font_size = 18
	theme = page_theme
	var backdrop := ColorRect.new()
	backdrop.color = Color("#233f35")
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","top","right","bottom"]:
		margin.add_theme_constant_override("margin_"+side,24)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation",9)
	margin.add_child(stack)
	var header := HBoxContainer.new()
	stack.add_child(header)
	var title := _label("池岸花湾 · 同路对照",27)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(_button("返回成长树",_close))
	var samples := HBoxContainer.new()
	stack.add_child(samples)
	samples.add_child(_label("对照档",16))
	stage_picker = OptionButton.new()
	for caption in STAGES:
		stage_picker.add_item(caption)
	stage_picker.select(selected_stage)
	stage_picker.item_selected.connect(_stage_changed)
	samples.add_child(stage_picker)
	samples.add_child(_label("起始蜜囊",16))
	load_picker = OptionButton.new()
	for initial in [0,6,8]:
		load_picker.add_item("%d / 10" % initial,initial)
	load_picker.item_selected.connect(func(_i: int): _reset())
	samples.add_child(load_picker)
	samples.add_child(_button("重置花湾",_reset))
	rule_label = _label("",18)
	stack.add_child(rule_label)
	plot = Control.new()
	plot.name = "FlowerBay"
	plot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	plot.custom_minimum_size.y = 150
	plot.mouse_filter = Control.MOUSE_FILTER_STOP
	plot.focus_mode = Control.FOCUS_ALL
	plot.draw.connect(_draw_field)
	plot.gui_input.connect(_field_input)
	stack.add_child(plot)
	wallet_label = _label("",21)
	stack.add_child(wallet_label)
	receipt_label = _label("",17)
	receipt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(receipt_label)
	var controls := HBoxContainer.new()
	stack.add_child(controls)
	sticky_button = _button("持续采蜜",func(): _sync_holding())
	sticky_button.toggle_mode = true
	controls.add_child(sticky_button)
	for index in Bay.POSITIONS.size():
		var button := _button(String.chr(65+index),_choose.bind(index))
		button.custom_minimum_size.x = 42
		button.toggle_mode = true
		controls.add_child(button)
		stage_buttons.append(button)
	var hint := _label("1–8 或方向键选花，按住空格 / E 采蜜。手柄十字键选花，按住 A 采蜜，B 返回。演示收获仅在此花湾内结算。",15)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(hint)
	_reset()
	plot.grab_focus()

func _label(caption: String, pixels: int) -> Label:
	var result := Label.new()
	result.text = caption
	result.add_theme_font_size_override("font_size",pixels)
	result.add_theme_color_override("font_color",Color("#fff4d9"))
	return result

func _button(caption: String, action: Callable) -> Button:
	var result := Button.new()
	result.text = caption
	result.pressed.connect(action)
	return result

func _reset() -> void:
	key_holding = false
	pointer_holding = false
	touch_index = -1
	sticky_button.set_pressed_no_signal(false)
	bay.reset(selected_stage,load_picker.get_selected_id())
	rule_label.text = RULES[selected_stage]
	receipt_label.text = "蜂已来到 A 花旁。"
	_choose(0)
	_update_wallet()

func _choose(index: int) -> void:
	bay.target = clampi(index,0,Bay.POSITIONS.size()-1)
	for i in stage_buttons.size():
		stage_buttons[i].set_pressed_no_signal(i == bay.target)
	plot.queue_redraw()

func _stage_changed(index: int) -> void:
	selected_stage = index
	_reset()

func _sync_holding() -> void:
	bay.set_holding(key_holding or pointer_holding or sticky_button.button_pressed)

func _update_wallet() -> void:
	wallet_label.text = "蜜囊  %d / 10       亲手  %d       串花  %d       花瀑  %d" % [bay.total(),bay.received.x,bay.received.y,bay.received.z]

func _close() -> void:
	if closing:
		return
	closing = true
	bay.set_holding(false)
	closed.emit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(sticky_button):
		key_holding = false
		pointer_holding = false
		touch_index = -1
		sticky_button.set_pressed_no_signal(false)
		_sync_holding()

func _input(event: InputEvent) -> void:
	if not is_node_ready() or not is_visible_in_tree() or closing:
		return
	var viewport := get_viewport()
	if event is InputEventJoypadButton:
		if event.button_index == JOY_BUTTON_A:
			key_holding = event.pressed
			_sync_holding()
		elif event.button_index in [JOY_BUTTON_DPAD_LEFT,JOY_BUTTON_DPAD_RIGHT]:
			if event.pressed:
				_choose(posmod(bay.target+(-1 if event.button_index == JOY_BUTTON_DPAD_LEFT else 1),8))
		elif event.button_index == JOY_BUTTON_B:
			if event.pressed:
				_close()
		elif event.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			if event.pressed:
				stage_picker.select((selected_stage+1)%STAGES.size())
				_stage_changed(stage_picker.selected)
		else:
			return
	elif event is InputEventKey:
		match event.keycode:
			KEY_SPACE, KEY_E:
				if not event.echo:
					key_holding = event.pressed
					_sync_holding()
			KEY_LEFT, KEY_RIGHT:
				if event.pressed and not event.echo:
					_choose(posmod(bay.target+(-1 if event.keycode == KEY_LEFT else 1),8))
			KEY_ESCAPE:
				if event.pressed and not event.echo:
					_close()
			_:
				if event.keycode < KEY_1 or event.keycode > KEY_8:
					return
				if event.pressed and not event.echo:
					_choose(event.keycode-KEY_1)
	else:
		return
	viewport.set_input_as_handled()

func _view_scale() -> float:
	return minf(plot.size.x/860.0,plot.size.y/265.0)

func _view_origin() -> Vector2:
	return plot.size*.5 - Vector2(432,245)*_view_scale()

func _select_at(position: Vector2) -> void:
	var field_point := (position-_view_origin())/_view_scale()
	var best := -1
	var limit := 58.0
	for i in Bay.POSITIONS.size():
		var distance: float = field_point.distance_to(Bay.POSITIONS[i])
		if distance < limit:
			best = i
			limit = distance
	if best >= 0:
		_choose(best)

func _field_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_select_at(event.position)
			plot.grab_focus()
		pointer_holding = event.pressed
	elif event is InputEventScreenTouch:
		if event.pressed and touch_index < 0:
			touch_index = event.index
			_select_at(event.position)
			pointer_holding = true
		elif event.index == touch_index and not event.pressed:
			pointer_holding = false
			touch_index = -1
	elif event is InputEventMouseMotion and pointer_holding:
		_select_at(event.position)
	elif event is InputEventScreenDrag and event.index == touch_index:
		_select_at(event.position)
	else:
		return
	_sync_holding()
	plot.accept_event()

func _process(delta: float) -> void:
	if not is_visible_in_tree() or closing:
		return
	var before := bay.harvest_count
	bay.step(minf(delta,.08))
	if bay.harvest_count != before:
		var parts := PackedStringArray()
		for event in bay.last_harvest:
			parts.append("%s %s" % [String.chr(65+event.flower),KINDS[event.kind]])
		receipt_label.text = " → ".join(parts)+"　实收 +%d" % parts.size()
		if bay.total() == Bay.CAPACITY:
			receipt_label.text += " · 蜜囊已满"
		_update_wallet()
	plot.queue_redraw()

func _draw_field() -> void:
	var width := plot.size.x
	var height := plot.size.y
	plot.draw_texture_rect(POND,Rect2(0,0,width,height),false,Color(.82,.86,.82))
	plot.draw_rect(Rect2(0,0,width,height),Color(.10,.16,.11,.18))
	var zoom := _view_scale()
	plot.draw_set_transform(_view_origin(),0,Vector2.ONE*zoom)
	for i in Bay.POSITIONS.size():
		var point: Vector2 = Bay.POSITIONS[i]
		var tint := Color.WHITE if bay.ripe[i] else Color(.46,.54,.46,.68)
		plot.draw_texture_rect(FLOWER,Rect2(point-Vector2(25,30),Vector2(50,60)),false,tint)
		if i == bay.target:
			plot.draw_arc(point,29,0,TAU,38,Color("#f8de77"),2.5,true)
		if i == bay.mark:
			plot.draw_arc(point,33,0,TAU,38,Color("#d0eeb5"),2.0,true)
		if bay.progress[i] > 0:
			plot.draw_arc(point,23,-PI/2,-PI/2+TAU*bay.progress[i],30,Color("#fff8c8"),3.0,true)
		var label_at := point+Vector2(-12,38)
		plot.draw_rect(Rect2(label_at-Vector2(0,16),Vector2(24,20)),Color("#274137"))
		plot.draw_string(page_font,label_at+Vector2(1,0),String.chr(65+i),HORIZONTAL_ALIGNMENT_CENTER,22,15,Color.WHITE)
	for i in bay.last_harvest.size():
		var event: Dictionary = bay.last_harvest[i]
		var elapsed: float = bay.clock-event.at
		var delay := 0.0 if reduced_motion else .055*i
		if elapsed < delay or elapsed > .85:
			continue
		var point: Vector2 = Bay.POSITIONS[event.flower]
		var amount := 1.0 if reduced_motion else minf(1.0,(elapsed-delay)/.13)
		var color: Color = COLORS[event.kind]
		if event.kind != Bay.MANUAL:
			plot.draw_line(event.from,event.from.lerp(point,amount),color,3.8,true)
		plot.draw_string_outline(page_font,point+Vector2(5,-30),"+1",HORIZONTAL_ALIGNMENT_LEFT,-1,19,4,Color("#324135"))
		plot.draw_string(page_font,point+Vector2(5,-30),"+1",HORIZONTAL_ALIGNMENT_LEFT,-1,19,color)
	var sprite_size := Vector2(46,41)
	# Use the same field transform for the bee as for the flowers.
	plot.draw_set_transform(_view_origin()+(bay.bee+Vector2(1,-16))*zoom,0,Vector2((-1 if bay.facing.x<0 else 1)*zoom,zoom))
	plot.draw_texture_rect_region(Art.ATLAS,Rect2(-sprite_size*.5,sprite_size),Art.BEE)
	plot.draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
