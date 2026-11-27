extends Control
## Painted bee portrait; a narrow honey-coloured ink arc carries live stamina.
const Art = preload("res://nectar_ui_art.gd")
const PULSE_SECONDS := 1.2
const INKS := [Color("849ba4"),Color("909aa8"),Color("9c92a4"),Color("a78e9a"),Color("b48982"),Color("b67a6a")]
const LINEN := Color("d5c9b4")
var energy_stage := 0
var source: Range
var warning := false
var pulse_time := 0.0
var paper_wash := GradientTexture2D.new()

func _ready() -> void:
	var wash := Gradient.new()
	wash.offsets = PackedFloat32Array([0.0,.43,.79,.95,1.0])
	wash.colors = _wash_colors()
	paper_wash.gradient = wash
	paper_wash.width = 96
	paper_wash.height = 96
	paper_wash.fill = GradientTexture2D.FILL_RADIAL
	paper_wash.fill_from = Vector2(.50,.50)
	paper_wash.fill_to = Vector2(.99,.50)
	set_process(false)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if source: source.value_changed.connect(_value_changed)

func _wash_colors() -> PackedColorArray:
	var ink: Color = INKS[energy_stage]
	return PackedColorArray([Color(ink,.88),Color(ink.lerp(LINEN,.26),.80),Color(ink.lerp(LINEN,.66),.71),Color(LINEN,.47),Color(LINEN,0)])

func set_energy_stage(value: int) -> void:
	if value == energy_stage: return
	energy_stage = value
	paper_wash.gradient.colors = _wash_colors()
	queue_redraw()

func set_warning(active: bool, reduced_motion: bool) -> void:
	var animate := active and not reduced_motion
	if active == warning and animate == is_processing(): return
	warning = active
	pulse_time = 0.0
	set_process(animate)
	queue_redraw()

func _process(delta: float) -> void:
	pulse_time = fmod(pulse_time + delta, PULSE_SECONDS)
	queue_redraw()

func _value_changed(_value: float) -> void:
	queue_redraw()

func _draw() -> void:
	var at := Vector2(64,62)
	# The slate wash fades back into the real parchment grain at the inner rim.
	draw_texture_rect(paper_wash,Rect2(at-Vector2(36,36),Vector2(72,72)),false)
	draw_arc(at,40,0,TAU,128,Color("be9e64a0"),1.1,true)
	draw_arc(at,36,0,TAU,128,Color("d9c698"),2.8,true)
	var ratio := clampf(source.value/maxf(source.max_value,1.0),0,1) if source else 1.0
	if ratio>0:
		var ink := Color("ae7d37") if ratio>.25 else Color("b65a35")
		draw_arc(at,36,-PI*.5,-PI*.5+TAU*ratio,128,ink,3.1,true)
		draw_arc(at,35,-PI*.5,-PI*.5+TAU*ratio,128,Color("f3d898b0"),.8,true)
	if warning:
		# Keep the remaining-energy arc legible inside a separate warning ring.
		var strength := (1.0 + cos(TAU * pulse_time / PULSE_SECONDS)) * 0.5
		var radius := 44.0 + 3.0 * strength
		draw_arc(at,radius,0,TAU,96,Color("864027"),6.5,true)
		draw_arc(at,radius,0,TAU,96,Color("b85c32").lerp(Color("ffe29a"),strength),4.2,true)
	# Use the whole bee assembly, including both wings, rather than its body atlas.
	Art.painted_bee(self,Rect2(at+Vector2(-31,-32),Vector2(62,62)),1.0,Color.WHITE,true,energy_stage)
