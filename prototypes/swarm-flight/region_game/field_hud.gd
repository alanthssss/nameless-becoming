extends Control
const Art = preload("res://nectar_ui_art.gd")
const Plate = preload("res://region_game/menu_plate.gd")
const INK := Color("403126")
const PICKUP_NAMES := {"fiber": "纤维", "resin": "树脂", "blue": "蓝花蜜", "rose": "紫花蜜"}
var ui
var receipt_gains: Dictionary[String, int] = {}
var receipt_left := 0.0
var receipt_art := {
	"blue": Plate.texture("pickup-honey"),
	"rose": Plate.texture("pickup-honey"),
	"fiber": Plate.texture("pickup-fiber"),
	"resin": Plate.texture("pickup-resin"),
}
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
	if not visible: receipt_left=0
	set_process(visible and (receipt_left>0 or ui.energy_dial.is_processing()))
	queue_redraw()

func show_pickups(gains: Dictionary[String, int]) -> void:
	receipt_gains = gains
	receipt_left = 1.6
	set_process(true)
	queue_redraw()

func _process(dt: float) -> void:
	receipt_left = maxf(0,receipt_left-dt)
	set_process(receipt_left>0 or ui.energy_dial.is_processing())
	queue_redraw()

func _number(at: Vector2, value: String, width: float, pixels: int, align := HORIZONTAL_ALIGNMENT_RIGHT) -> void:
	var face: Font = ui.font
	while pixels>10 and face.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels).x>width: pixels-=1
	draw_string(face,at,value,align,width,pixels,INK)

func _draw() -> void:
	if not ui or not ui.driver.model.field: return
	var m = ui.driver.model
	draw_texture_rect(backing,Rect2(16,497,332,87),false)
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
		draw_texture_rect(full_badge,Rect2(36,446,240,46),false)
	if receipt_left > 0:
		var y := 395 if m.cargo_total() >= m.capacity() else 445
		var x := 31
		for key in receipt_gains:
			draw_texture_rect(receipt_art[key], Rect2(x, y, 138, 52), false)
			var label := "%s +%d" % [PICKUP_NAMES[key], receipt_gains[key]]
			_number(Vector2(x+46, y+31), label, 84, 18, HORIZONTAL_ALIGNMENT_LEFT)
			x += 142
