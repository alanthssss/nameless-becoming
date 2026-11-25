extends RefCounted
## Type, ink and controls for the pages of the regional game's garden journal.
const COVER := preload("res://art/honey-pause-folio.webp")
const MARKS := preload("res://art/honey-pause-marks.webp")
const INK := Color("#382e24")
const SECONDARY := Color("#675743")
const GREEN := Color("#354b32")
const CREAM := Color("#fff2cc")
const VEIL := Color("#1d302894")
const DISPLAY := 40
const SUBHEAD := 24
const BODY := 20
const DETAIL := 17
const SERIF := ["Songti SC", "Noto Serif CJK SC", "SimSun", "serif"]

class JournalPaper extends StyleBox:
	# Use the binding and natural paper edges of the approved folio. The
	# illustrated strip stays on the pause page; working pages have a clear face.
	func _draw(item: RID, bounds: Rect2) -> void:
		var top := Rect2(bounds.position, Vector2(bounds.size.x, 28))
		var body := Rect2(bounds.position + Vector2(0,28), bounds.size - Vector2(0,28))
		var paper := COVER.get_rid()
		RenderingServer.canvas_item_add_nine_patch(item, top, Rect2(0,0,573,59), paper,
			Vector2(52,0), Vector2(27,0))
		RenderingServer.canvas_item_add_nine_patch(item, body, Rect2(0,239,573,580), paper,
			Vector2(52,0), Vector2(27,26), RenderingServer.NINE_PATCH_STRETCH,
			RenderingServer.NINE_PATCH_STRETCH, true)

var display_face := SystemFont.new()

func _init() -> void:
	display_face.font_names = PackedStringArray(SERIF)
	display_face.font_weight = 600

func paper(panel: PanelContainer, inset: Vector4) -> void:
	var page := JournalPaper.new()
	for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:
		page.set_content_margin(side,inset[side])
	panel.add_theme_stylebox_override("panel",page)
	panel.set_meta("material_kind","field_notes")

func type_line(label: Label, role: StringName = &"body") -> void:
	var sizes := {&"heading":DISPLAY,&"section":SUBHEAD,&"body":BODY,&"detail":DETAIL}
	label.add_theme_font_size_override("font_size",sizes[role])
	label.add_theme_color_override("font_color",SECONDARY if role == &"detail" else INK)
	if role in [&"heading",&"section"]:
		label.add_theme_font_override("font",display_face)
	label.add_theme_constant_override("shadow_offset_y",0)
	label.add_theme_color_override("font_shadow_color",Color.TRANSPARENT)

func rule(parent: BoxContainer, index: int = -1) -> void:
	var line := HSeparator.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ink := StyleBoxLine.new()
	ink.color = Color("#96784777")
	ink.thickness = 1
	line.add_theme_stylebox_override("separator",ink)
	parent.add_child(line)
	if index >= 0: parent.move_child(line,index)

func wash(fill: Color, edge: Color, border: int = 0) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(border)
	box.set_corner_radius_all(4)
	box.set_content_margin_all(0)
	return box

func button(b: Button, kind: StringName = &"link") -> void:
	var active := kind == &"primary"
	var tab := kind == &"tab"
	var entry := kind == &"entry"
	var base := Color.TRANSPARENT
	var rim := Color("#b3925b")
	b.add_theme_font_size_override("font_size",BODY)
	for state in ["normal","hover","pressed","hover_pressed","disabled"]:
		var selected: bool = tab and state in ["pressed","hover_pressed"]
		var tint := CREAM if active or selected else INK
		if state == "disabled": tint = SECONDARY
		var color_key: String = "font_color" if state == "normal" else "font_"+state+"_color"
		b.add_theme_color_override(color_key,tint)
		if active:
			var brass := StyleBoxTexture.new()
			brass.texture = MARKS
			brass.region_rect = Rect2(0,0,448,95)
			brass.texture_margin_left = 26
			brass.texture_margin_right = 26
			brass.texture_margin_top = 18
			brass.texture_margin_bottom = 18
			brass.set_content_margin_all(0)
			brass.modulate_color = Color("#e1cd9f") if state == "pressed" else Color.WHITE
			b.add_theme_stylebox_override(state,brass)
		else:
			var fill := base
			if state == "hover": fill = Color("#c4aa6f52")
			if state in ["pressed","hover_pressed"]: fill = GREEN if selected else Color("#c7ae80")
			var box := wash(fill,rim)
			if entry:
				box.border_width_bottom = 1
				box.content_margin_left = 12
				box.content_margin_right = 12
			b.add_theme_stylebox_override(state,box)
	b.add_theme_color_override("font_focus_color",CREAM if active else INK)
	b.add_theme_stylebox_override("focus",wash(Color.TRANSPARENT,Color("#87612d"),2))

func field_caption(label: Label) -> void:
	label.add_theme_font_size_override("font_size",BODY)
	label.add_theme_color_override("font_color",Color("#fff2d5"))
	label.add_theme_color_override("font_shadow_color",Color.TRANSPARENT)
	label.add_theme_constant_override("outline_size",0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var backing := wash(Color("#39483ef5"),Color.TRANSPARENT)
	backing.content_margin_left = 10
	backing.content_margin_right = 10
	label.add_theme_stylebox_override("normal",backing)
