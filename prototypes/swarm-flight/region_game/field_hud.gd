extends Control
const Art = preload("res://nectar_ui_art.gd")
const Plate = preload("res://region_game/menu_plate.gd")
const INK := Color("403126")
const FieldStyle = preload("res://region_game/field_notes_style.gd")
# Centre points on the painted inventory at its authored 960 x 600 scale.
const RESOURCE_CENTERS := {"honey": Vector2(230,553), "fiber": Vector2(230,522), "resin": Vector2(117,553)}
const INVENTORY_RECT := Rect2(16,497,332,87)
const FULL_BADGE_RECT := Rect2(36,446,240,46)
const ARRIVAL_TIME := 0.38
const GLOW_TIME := 0.30
var ui
var pickup_bursts: Array[Dictionary] = []
var pause_hit := Button.new()
var full_badge := Plate.texture("full-bag")
var backing := Plate.texture("field-hud")

func setup(interface: Control) -> void:
	ui=interface
	mouse_filter = MOUSE_FILTER_IGNORE
	size=Vector2(960,600)
	get_parent_control().resized.connect(_fit)
	_fit()
	add_child(pause_hit)
	pause_hit.position = Vector2(893,528)
	pause_hit.size = Vector2(46,48)
	pause_hit.accessibility_name = "暂停"
	pause_hit.pressed.connect(ui.driver.pause_game)
	for state in ["normal","pressed","hover"]:
		var box := StyleBoxTexture.new()
		box.texture = Plate.texture("field-pause")
		if state=="pressed": box.modulate_color = Color(.84,.80,.73)
		pause_hit.add_theme_stylebox_override(state,box)
	set_process(false)

func _fit() -> void:
	var available := get_parent_control().size
	scale=Vector2.ONE*minf(available.x/960,available.y/600)
	position=(available-size*scale)*.5

func refresh() -> void:
	visible = ui.driver.model.field != null
	pause_hit.tooltip_text = "暂停 · "+ui.driver.control_hint("pause")
	if not visible: pickup_bursts.clear()
	set_process(visible and (not pickup_bursts.is_empty() or ui.energy_dial.is_processing()))
	queue_redraw()

func pickup_obstacles() -> Array[Rect2]:
	var transform_to_screen := get_global_transform_with_canvas()
	var areas: Array[Rect2] = [transform_to_screen * INVENTORY_RECT, pause_hit.get_global_rect()]
	if ui.driver.model.cargo_total() >= ui.driver.model.capacity():
		areas.append(transform_to_screen * FULL_BADGE_RECT)
	return areas

func show_pickups(events: Array[Dictionary]) -> void:
	var groups := {}
	for event in events:
		var kind: String = event.type
		var badge: String = "honey" if event.kind == "harvest" else kind
		if not groups.has(badge): groups[badge] = []
		for unit in event.amount: groups[badge].append(kind)
	for badge in groups:
		pickup_bursts.append({"badge": badge, "units": groups[badge], "age": 0.0})
	set_process(true)
	queue_redraw()

func _process(dt: float) -> void:
	for burst in pickup_bursts: burst.age += dt
	while not pickup_bursts.is_empty() and pickup_bursts.front().age >= ARRIVAL_TIME + GLOW_TIME:
		pickup_bursts.pop_front()
	set_process(not pickup_bursts.is_empty() or ui.energy_dial.is_processing())
	queue_redraw()

func _number(at: Vector2, value: String, width: float, pixels: int, align := HORIZONTAL_ALIGNMENT_RIGHT) -> void:
	var face: Font = ui.font
	while pixels>10 and face.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels).x>width: pixels-=1
	draw_string(face,at,value,align,width,pixels,INK)

func _draw() -> void:
	if not ui or not ui.driver.model.field: return
	var m = ui.driver.model
	draw_texture_rect(backing,INVENTORY_RECT,false)
	var centre := Vector2(62,539)
	var ratio := clampf(m.energy/m.max_energy(),0,1)
	var low: bool = m.energy_is_low()
	if ratio>0: draw_arc(centre,34,-PI/2,-PI/2+TAU*ratio,80,Color("ac5237") if low else Color("315850"),4.7,true)
	if low:
		var pulse: float = ui.energy_dial.pulse_time
		draw_arc(centre,38,0,TAU,90,Color("a75238",.66+.29*cos(TAU*pulse/ui.energy_dial.PULSE_SECONDS)),1.8,true)
	Art.painted_bee(self,Rect2(37,510,49,49),1.0,Color.WHITE,true,m.energy_stage())
	_number(Vector2(32,570),"%d / %d" % [ceili(m.energy),int(m.max_energy())],60,13,HORIZONTAL_ALIGNMENT_CENTER)
	var values := [str(m.coins),str(m.materials.fiber),str(m.materials.resin),"%d / %d" % [m.cargo_total(),m.capacity()]]
	for i in values.size():
		_number(Vector2(161+(i%2)*113,528+floori(i/2.0)*31),values[i],48,15)
	if m.cargo_total()>=m.capacity():
		draw_texture_rect(full_badge,FULL_BADGE_RECT,false)
	for burst in pickup_bursts:
		_draw_pickup_burst(burst)

func _draw_pickup_burst(burst: Dictionary) -> void:
	var center: Vector2 = RESOURCE_CENTERS[burst.badge]
	var age: float = burst.age
	if ui.driver.reduced_motion or age >= ARRIVAL_TIME:
		var fade := smoothstep(ARRIVAL_TIME, ARRIVAL_TIME + GLOW_TIME, age)
		var radius := 14.0 if ui.driver.reduced_motion else 14.0 + 4.0 * fade
		draw_arc(center, radius, 0, TAU, 32, Color("ad7635", 0.85 * (1.0-fade)), 2.8, true)
		draw_arc(center, radius, 0, TAU, 32, Color("fff1b4", 1.0-fade), 1.4, true)
		return
	var t := smoothstep(0.0, ARRIVAL_TIME, age)
	var units: Array = burst.units
	for i in units.size():
		var kind: String = units[i]
		var angle := PI * (0.12 + 0.76 * (i + 0.5) / units.size())
		var side := -1.0 if burst.badge == "fiber" else 1.0
		var start := center + Vector2(cos(angle)*31.0, side*sin(angle)*25.0)
		var rim := center + Vector2(0,-6)
		var bend := Vector2(start.x, minf(start.y, rim.y)-14)
		var at := start.lerp(bend,t).lerp(bend.lerp(rim,t),t)
		var size := lerpf(6.5, 3.5, t)
		if burst.badge == "honey":
			var fill: Color = FieldStyle.PICKUP_COLORS[kind]
			draw_circle(at, size, Color("805f53"), true, -1, true)
			draw_circle(at, size-1.2, fill, true, -1, true)
			draw_circle(at-Vector2.ONE*size*.3, size*.28, Color("fff8dd"), true, -1, true)
		else:
			Art.painted_icon(self, kind, at, size)
