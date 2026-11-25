extends Control
## Coordinates are in the approved 960 × 600 drawing. Keep the entire cabinet in view.
const HARDWARE := preload("res://art/field-notes-options/hardware.webp")
const INK := Color("403126")
const MUTED := Color("685642")
const LIGHT := Color("fff4dc")
const JADE := Color("315850")
const NAV := Rect2(4,2,175,41)
const CONTEXT := Rect2(4,51,175,40)
const SWITCH := Rect2(4,102,102,43)
const WAGGLE := Rect2(4,150,166,84)
const SIDE_STEP := Rect2(4,240,166,84)

var sheet := Control.new()
var face := SystemFont.new()
var ui

func mount(interface: Control, painting: Texture2D) -> void:
	ui = interface
	face.font_names = PackedStringArray(["Songti SC", "Noto Serif CJK SC", "serif"])
	face.font_weight = 650
	face.oversampling = 2.0
	var body_font := SystemFont.new()
	body_font.font_names = PackedStringArray(["PingFang SC","Noto Sans CJK SC","sans-serif"])
	body_font.oversampling = 2.0
	var page_theme := Theme.new()
	page_theme.default_font = body_font
	theme = page_theme
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var backdrop := ColorRect.new()
	backdrop.color = Color("34352682")
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(sheet)
	sheet.size = Vector2(960,600)
	sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture(sheet, painting, Rect2(0,0,960,600))
	resized.connect(_fit_page)
	_fit_page()

func _fit_page() -> void:
	var ratio := minf(size.x / 960.0, size.y / 600.0)
	sheet.scale = Vector2.ONE * ratio
	sheet.position = (size - sheet.size * ratio) * 0.5

func place(item: Control, bounds: Rect2) -> void:
	item.position = bounds.position
	item.size = bounds.size

func picture(parent: Control, art: Texture2D, bounds: Rect2) -> TextureRect:
	var image := TextureRect.new()
	image.texture = art
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(image)
	place(image, bounds)
	return image

func patch(region: Rect2) -> AtlasTexture:
	var art := AtlasTexture.new()
	art.atlas = HARDWARE
	art.region = Rect2(region.position * 2,region.size * 2)
	art.filter_clip = true
	return art

func line(parent: Control, words: String, px: int, tint := INK) -> Label:
	var label := Label.new()
	label.text = words
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", px)
	label.add_theme_color_override("font_color", tint)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func rim(tint: Color, fill := Color.TRANSPARENT, width := 2) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = tint
	style.set_border_width_all(width)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(0)
	return style

func painted_button(parent: Control, bounds: Rect2, title: String, action: Callable, region := NAV, toggle := false, baked_label := false) -> Button:
	var b := Button.new()
	b.text = title
	b.accessibility_name = title
	b.toggle_mode = toggle
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_override("font", face)
	b.add_theme_font_size_override("font_size", 17)
	for state in ["normal","hover","pressed","hover_pressed","disabled"]:
		var active: bool = state in ["pressed","hover_pressed"]
		var texture := StyleBoxTexture.new()
		texture.texture = patch(Rect2(region.position + Vector2(200 if toggle and active else 0,0), region.size))
		texture.set_content_margin_all(0)
		texture.modulate_color = Color("ffefcd") if state in ["hover","hover_pressed"] else Color.WHITE
		b.add_theme_stylebox_override(state,texture)
		var c := LIGHT if toggle and active else INK
		b.add_theme_color_override("font_color" if state == "normal" else "font_"+state+"_color", Color.TRANSPARENT if baked_label else c)
	b.add_theme_color_override("font_focus_color", Color.TRANSPARENT if baked_label else INK)
	b.add_theme_stylebox_override("focus",rim(JADE))
	b.pressed.connect(action)
	parent.add_child(b)
	place(b,bounds)
	return b
