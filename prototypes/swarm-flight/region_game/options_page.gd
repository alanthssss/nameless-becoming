extends "res://region_game/options_art.gd"
const CABINET := preload("res://art/field-notes-options/cabinet.webp")
var display := Control.new()
var card: TextureRect
var reduced_note: Label

func setup(interface: Control) -> void:
	mount(interface, CABINET)
	ui.settings_scroll = ScrollContainer.new()
	ui.settings_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ui.settings_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sheet.add_child(ui.settings_scroll)
	place(ui.settings_scroll, Rect2(0,0,960,600))
	var inner := Control.new()
	inner.custom_minimum_size = Vector2(960,600)
	ui.settings_scroll.add_child(inner)
	inner.add_child(display)
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture(display,patch(Rect2(280,330,197,166)),Rect2(79,182,197,166))
	picture(display,patch(Rect2(273,143,116,10)),Rect2(117,433,116,10))
	var version := "Demo 0.32.7" if OS.has_feature("pond_feedback") else "Demo 0.29.0"
	var name_line := line(display, ui.driver.DISPLAY_NAME, 32, Color("71583a"))
	name_line.add_theme_font_override("font",face)
	name_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	place(name_line,Rect2(80,353,192,48))
	var version_line := line(display, version, 16, MUTED)
	version_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	place(version_line,Rect2(78,395,194,34))

	ui.settings_sound = painted_button(inner,Rect2(749,118,102,43),"声音",ui.toggle_sound,SWITCH,true,true)
	ui.settings_motion = painted_button(inner,Rect2(749,184,102,43),"简化动画",_toggle_motion,SWITCH,true,true)
	ui.settings_waggle = painted_button(inner,Rect2(483,250,166,84),"摆尾回环",_dance.bind("waggle"),WAGGLE,true,true)
	ui.settings_dance = painted_button(inner,Rect2(682,250,166,84),"侧步摆肩",_dance.bind("side_step"),SIDE_STEP,true,true)
	reduced_note = line(inner,"简化动画已开启",15,MUTED)
	place(reduced_note,Rect2(486,332,280,28))
	ui.controls_button = painted_button(inner,Rect2(694,382,163,41),"查看或改键　›",ui._open_controls)
	ui.settings_about = painted_button(inner,Rect2(756,451,100,41),"查看　›",_toggle_about)
	ui.settings_back = painted_button(inner,Rect2(80,522,119,41),"‹　返回",ui.driver.close_settings)
	card = picture(inner,patch(Rect2(2,337,240,165)),Rect2(57,217,240,165))
	# The native credit label is also the accessible text of this plate.
	ui.settings_credits = line(inner,"%s\n制作　Alan\nGodot Engine（MIT）" % version,17)
	ui.settings_credits.add_theme_constant_override("line_spacing",7)
	var heading := line(inner,ui.driver.DISPLAY_NAME,32)
	heading.add_theme_font_override("font",face)
	place(heading,Rect2(78,223,202,45))
	# The title uses a separate display face. The other three credit lines are native text.
	place(ui.settings_credits,Rect2(79,267,206,92))
	heading.visible = false
	ui.settings_credits.visibility_changed.connect(func(): heading.visible = ui.settings_credits.visible)
	card.hide()
	ui.settings_credits.hide()
	var order := [ui.settings_sound,ui.settings_motion,ui.settings_waggle,ui.controls_button,ui.settings_about,ui.settings_back]
	for i in range(order.size()-1):
		var a: Button = order[i]
		var b: Button = order[i+1]
		a.focus_neighbor_bottom = a.get_path_to(b)
		b.focus_neighbor_top = b.get_path_to(a)
	ui.settings_dance.focus_neighbor_bottom = ui.settings_dance.get_path_to(ui.controls_button)
	ui.settings_dance.focus_neighbor_top = ui.settings_dance.get_path_to(ui.settings_motion)
	ui.settings_dance.focus_neighbor_left = ui.settings_dance.get_path_to(ui.settings_waggle)
	ui.settings_waggle.focus_neighbor_right = ui.settings_waggle.get_path_to(ui.settings_dance)
	sync_motion()
	hide()

func _toggle_about() -> void:
	var opened: bool = not ui.settings_credits.visible
	ui.settings_credits.visible = opened
	card.visible = opened
	display.visible = not opened
	ui.settings_about.text = "收起　⌃" if opened else "查看　›"
	ui.settings_about.accessibility_name = "收起关于" if opened else "查看关于"

func _toggle_motion() -> void:
	ui.driver.reduced_motion = not ui.driver.reduced_motion
	ui.driver.save_settings()
	sync_motion()

func sync_motion() -> void:
	var reduced: bool = ui.driver.reduced_motion
	reduced_note.visible = reduced
	for b: Button in [ui.settings_dance,ui.settings_waggle]:
		b.modulate.a = 0.52 if reduced else 1.0
		b.add_theme_stylebox_override("disabled",b.get_theme_stylebox("pressed" if b.button_pressed else "normal"))
	ui.settings_motion.focus_neighbor_bottom = ui.settings_motion.get_path_to(ui.controls_button if reduced else ui.settings_waggle)
	ui.controls_button.focus_neighbor_top = ui.controls_button.get_path_to(ui.settings_motion if reduced else ui.settings_waggle)

func _dance(style: String) -> void:
	ui.driver.dance_style = style
	ui.driver.save_settings()
