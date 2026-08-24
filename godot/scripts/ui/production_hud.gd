extends Control
class_name ProductionHUD

## Delivery-grade shell for the in-run HUD.
##
## Gameplay values and input remain owned by main.gd. This control owns only the
## visual hierarchy: one wax-and-hive top tray, compact contextual cards, and a
## transient teaching ribbon. Everything is drawn from project colors so the UI
## stays crisp at 1280x720 and does not introduce a fourth bitmap art style.

const INK := Color("24342b")
const DEEP_MOSS := Color("1d3028")
const MOSS := Color("294438")
const MOSS_LIGHT := Color("3e5c49")
const WAX := Color("eee2bc")
const WAX_LIGHT := Color("f8efd2")
const HONEY := Color("d9ad43")
const HONEY_LIGHT := Color("f2d477")
const LEAF_TEXT := Color("65705e")
const CREAM_TEXT := Color("f5edcf")
const DANGER := Color("bd5a43")

var host
var phase_label: Label
var tutorial_visible := false

func _ready() -> void:
	name = "ProductionHUD"
	position = Vector2.ZERO
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)

func apply_to(main, ui: CanvasLayer) -> void:
	host = main
	# The value labels remain ordinary Controls for accessibility and tests. Their
	# old ColorRects become transparent windows into the single tray drawn here.
	var forage_panel := ui.get_node_or_null("ForagePanel") as ColorRect
	var flight_panel := ui.get_node_or_null("FlightPanel") as ColorRect
	var hive_panel := ui.get_node_or_null("HivePanel") as ColorRect
	var side := ui.get_node_or_null("ContextRail") as ColorRect
	if forage_panel != null:
		forage_panel.position = Vector2(46, 70)
		forage_panel.size = Vector2(300, 52)
		forage_panel.color = Color.TRANSPARENT
		_style_stat_labels(forage_panel)
	if flight_panel != null:
		flight_panel.position = Vector2(354, 70)
		flight_panel.size = Vector2(310, 52)
		flight_panel.color = Color.TRANSPARENT
		_style_stat_labels(flight_panel)
	if hive_panel != null:
		hive_panel.position = Vector2(672, 70)
		hive_panel.size = Vector2(330, 52)
		hive_panel.color = Color.TRANSPARENT
		_style_stat_labels(hive_panel)

	main.title_label.text = "无名 · 成蜂"
	main.title_label.position = Vector2(60, 24)
	main.title_label.size = Vector2(330, 34)
	main.title_label.add_theme_font_size_override("font_size", 19)
	main.title_label.add_theme_color_override("font_color", CREAM_TEXT)
	main.term_label.visible = false

	main.pause_button.position = Vector2(1154, 26)
	main.pause_button.size = Vector2(78, 32)
	_style_button(main.pause_button, false, true)

	phase_label = Label.new()
	phase_label.text = "巢外"
	phase_label.position = Vector2(1037, 29)
	phase_label.size = Vector2(98, 26)
	phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	phase_label.add_theme_font_size_override("font_size", 12)
	phase_label.add_theme_color_override("font_color", HONEY_LIGHT)
	if main.zh_font != null:
		phase_label.add_theme_font_override("font", main.zh_font)
	add_child(phase_label)

	if side != null:
		side.position = Vector2(1018, 146)
		side.size = Vector2(232, 538)
		side.color = Color.TRANSPARENT
	_reflow_context(main)

	main.tutorial_panel.position = Vector2(276, 612)
	main.tutorial_panel.size = Vector2(486, 58)
	main.tutorial_panel.color = Color.TRANSPARENT
	main.tutorial_title.position = Vector2(22, 9)
	main.tutorial_title.size = Vector2(126, 22)
	main.tutorial_title.add_theme_color_override("font_color", HONEY_LIGHT)
	main.tutorial_body.position = Vector2(150, 9)
	main.tutorial_body.size = Vector2(310, 40)
	main.tutorial_body.add_theme_color_override("font_color", CREAM_TEXT)

	main.energy_bar.position = Vector2(12, 36)
	main.energy_bar.size = Vector2(284, 7)
	main.energy_bar.color = Color("435346")
	main.energy_bar_fill.size.y = 7
	main.energy_bar_fill.color = HONEY

	# All interactive chrome shares one shape language. Overlay buttons are kept
	# slightly larger, while contextual controls remain compact.
	for node in ui.find_children("*", "Button", true, false):
		if node is Button and node != main.pause_button:
			_style_button(node, node == main.overlay_button, false)
	_style_button(main.sense_button, true, false)
	_style_button(main.return_button, false, false)
	queue_redraw()

func _reflow_context(main) -> void:
	var side := main.season_label.get_parent() as Control
	for child in side.get_children():
		if child is Label:
			child.add_theme_color_override("font_color", CREAM_TEXT)

	# Card 1: what is happening now. One title, one mechanic state, one short
	# consequence. It replaces the long empty report-like sidebar.
	var heading := side.get_child(0) as Label
	heading.text = "当前"
	heading.position = Vector2(20, 13)
	heading.size = Vector2(80, 18)
	heading.add_theme_font_size_override("font_size", 10)
	heading.add_theme_color_override("font_color", HONEY_LIGHT)
	main.season_label.position = Vector2(20, 34)
	main.season_label.size = Vector2(192, 32)
	main.season_label.add_theme_font_size_override("font_size", 21)
	main.season_label.add_theme_color_override("font_color", CREAM_TEXT)
	main.season_rule.position = Vector2(20, 70)
	main.season_rule.size = Vector2(44, 2)
	main.season_rule.color = HONEY
	main.detail_label.position = Vector2(20, 82)
	main.detail_label.size = Vector2(192, 42)
	main.detail_label.add_theme_font_size_override("font_size", 12)
	main.detail_label.add_theme_color_override("font_color", Color("d7dfc7"))
	main.message_label.position = Vector2(20, 128)
	main.message_label.size = Vector2(192, 45)
	main.message_label.add_theme_font_size_override("font_size", 11)
	main.message_label.add_theme_color_override("font_color", Color("bfcbb8"))

	# Card 2: only the action that can be taken here and now.
	main.context_hint_label.position = Vector2(20, 222)
	main.context_hint_label.size = Vector2(192, 24)
	main.context_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main.context_hint_label.add_theme_font_size_override("font_size", 11)
	main.context_hint_label.add_theme_color_override("font_color", Color("c8d5bf"))
	main.sense_button.position = Vector2(16, 258)
	main.sense_button.size = Vector2(136, 42)
	main.return_button.position = Vector2(158, 258)
	main.return_button.size = Vector2(58, 42)

	# Old separator ColorRects remain as lightweight ornaments instead of office
	# rules spanning a white sheet.
	for child in side.get_children():
		if child is ColorRect and child != main.season_rule:
			child.color = Color.TRANSPARENT
	main.runs_meter.position = Vector2(20, 478)
	main.runs_meter.size = Vector2(192, 18)
	main.runs_meter.add_theme_color_override("font_color", Color("d3ddca"))
	main.runs_meter_farthest.position = Vector2(20, 500)
	main.runs_meter_farthest.size = Vector2(192, 20)
	main.runs_meter_farthest.add_theme_color_override("font_color", Color("8fa18e"))

func update_state(main) -> void:
	if phase_label == null:
		return
	match String(main.phase):
		"paused":
			phase_label.text = "蜂翼暂歇"
		"boss", "boss_victory", "boss_loss":
			phase_label.text = "调律中"
		"between", "upgrade":
			phase_label.text = "归巢"
		"intro":
			phase_label.text = "待出巢"
		_:
			phase_label.text = "巢外"
	tutorial_visible = bool(main.tutorial_panel.visible)
	queue_redraw()

func _draw() -> void:
	# A single top tray unifies title, system state and all resources. The warm
	# inner shelf is wax, not a set of spreadsheet cells.
	_draw_panel(Rect2(26, 14, 1228, 118), DEEP_MOSS, Color("a98543"), 16, 2, Color(0, 0, 0, 0.22), 5)
	_draw_panel(Rect2(42, 65, 966, 59), WAX, Color("c6a45a"), 12, 1)
	draw_line(Vector2(346, 73), Vector2(346, 116), Color("b69a61", 0.48), 1.0)
	draw_line(Vector2(666, 73), Vector2(666, 116), Color("b69a61", 0.48), 1.0)
	_draw_hex(Vector2(45, 39), 10, HONEY, 2.0)
	draw_circle(Vector2(45, 39), 3.0, HONEY_LIGHT)

	# Small comb marks bind the unused right end to the same hive language without
	# competing with the title or turning the header into decoration soup.
	for i in 3:
		_draw_hex(Vector2(1018 + i * 19, 92 + (i % 2) * 11), 8, Color(HONEY, 0.28), 1.2)
	_draw_bee(Vector2(1093, 94), Color("d8b758"), Color("e9efd8"))

	# Context is split into compact cards; the gaps deliberately reveal the page
	# background so this no longer reads as a permanent office sidebar.
	_draw_panel(Rect2(1018, 146, 232, 184), Color("20372e", 0.97), Color("6e825f"), 12, 1, Color(0, 0, 0, 0.20), 4)
	_draw_panel(Rect2(1018, 350, 232, 120), Color("294438", 0.96), Color("8a7848"), 12, 1, Color(0, 0, 0, 0.17), 4)
	draw_string(host.zh_font, Vector2(1038, 379), "当下动作", HORIZONTAL_ALIGNMENT_LEFT, 120, 10, HONEY_LIGHT)
	draw_line(Vector2(1038, 389), Vector2(1229, 389), Color("8fa17d", 0.34), 1.0)
	if host.runs_meter.visible or host.runs_meter_farthest.visible:
		_draw_panel(Rect2(1018, 618, 232, 66), Color("1d3028", 0.90), Color("5d735f"), 11, 1)

	# A restrained comb spine makes the negative space intentional and visually
	# connects the contextual controls to colony history.
	draw_line(Vector2(1233, 488), Vector2(1233, 602), Color(HONEY, 0.22), 1.0)
	for i in 3:
		_draw_hex(Vector2(1233, 506 + i * 32), 7, Color(HONEY, 0.25 - i * 0.04), 1.0)

	if tutorial_visible:
		_draw_panel(Rect2(276, 612, 486, 58), Color("1d3028", 0.96), Color("d0a94b"), 14, 1, Color(0, 0, 0, 0.25), 4)
		draw_line(Vector2(414, 622), Vector2(414, 659), Color(HONEY, 0.32), 1.0)

func _style_stat_labels(panel: Control) -> void:
	for child in panel.get_children():
		if child is Label:
			var label := child as Label
			if label.get_theme_font_size("font_size") <= 11:
				label.add_theme_color_override("font_color", LEAF_TEXT)
			else:
				label.add_theme_color_override("font_color", INK)

func _style_button(button: Button, primary: bool, compact: bool) -> void:
	var normal_fill := HONEY if primary else MOSS_LIGHT
	var normal_text := INK if primary else CREAM_TEXT
	button.add_theme_stylebox_override("normal", _button_box(normal_fill, Color("b58b36") if primary else Color("607963"), 9 if compact else 10))
	button.add_theme_stylebox_override("hover", _button_box(normal_fill.lightened(0.10), HONEY_LIGHT, 9 if compact else 10))
	button.add_theme_stylebox_override("pressed", _button_box(normal_fill.darkened(0.12), Color("f0d271"), 9 if compact else 10))
	button.add_theme_stylebox_override("focus", _button_box(Color.TRANSPARENT, HONEY_LIGHT, 9 if compact else 10, 2))
	button.add_theme_stylebox_override("disabled", _button_box(Color("465248"), Color("606a61"), 9 if compact else 10))
	button.add_theme_color_override("font_color", normal_text)
	button.add_theme_color_override("font_hover_color", INK if primary else WAX_LIGHT)
	button.add_theme_color_override("font_pressed_color", INK if primary else WAX_LIGHT)
	button.add_theme_color_override("font_focus_color", normal_text)
	button.add_theme_color_override("font_disabled_color", Color("92978a"))
	button.add_theme_font_size_override("font_size", 12 if compact else 13)

func _button_box(fill: Color, border: Color, radius: int, border_width := 1) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 5
	box.content_margin_bottom = 5
	return box

func _draw_panel(rect: Rect2, fill: Color, border: Color, radius: int, border_width: int, shadow := Color.TRANSPARENT, shadow_size := 0) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(radius)
	if shadow_size > 0:
		box.shadow_color = shadow
		box.shadow_size = shadow_size
	draw_style_box(box, rect)

func _draw_hex(center: Vector2, radius: float, color: Color, width: float) -> void:
	var points := PackedVector2Array()
	for i in 7:
		var angle := -PI / 2.0 + float(i % 6) * TAU / 6.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	draw_polyline(points, color, width, true)

func _draw_bee(center: Vector2, body: Color, wing: Color) -> void:
	draw_circle(center + Vector2(-8, -5), 6, Color(wing, 0.62))
	draw_circle(center + Vector2(7, -5), 6, Color(wing, 0.62))
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-12, 0), center + Vector2(-6, -5),
		center + Vector2(7, -5), center + Vector2(13, 0),
		center + Vector2(7, 5), center + Vector2(-6, 5)
	]), body)
	draw_line(center + Vector2(-2, -5), center + Vector2(-2, 5), DEEP_MOSS, 2.0)
	draw_line(center + Vector2(5, -5), center + Vector2(5, 5), DEEP_MOSS, 2.0)
