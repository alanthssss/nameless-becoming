extends Control
## All coordinates are in the approved 960 × 600 drawing. The same transform
## positions both the ink and its interactive target at every window size.
const ART := "res://art/honey-pages/"
const INK := Color("3c3128")
const MUTED := Color("695940")
var face := SystemFont.new()
var art: TextureRect
var canvas := Control.new()

func setup(page_name: String, veil := Color("34352682")) -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var dim := ColorRect.new()
	add_child(dim)
	dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	dim.color = veil
	add_child(canvas)
	canvas.mouse_filter = MOUSE_FILTER_IGNORE
	canvas.size = Vector2(960,600)
	resized.connect(_fit)
	_fit()
	face.font_names = ["Songti SC","STSong","Noto Serif CJK SC","serif"]
	face.font_weight = 650
	face.oversampling = 2.0
	var body := SystemFont.new()
	body.font_names = ["PingFang SC","Noto Sans CJK SC","sans-serif"]
	body.oversampling = 2.0
	var page_theme := Theme.new()
	page_theme.default_font = body
	theme = page_theme
	texture_filter = TEXTURE_FILTER_LINEAR
	art = picture(page_name,Rect2(0,0,960,600))

func _fit() -> void:
	var factor := minf(size.x/960.0,size.y/600.0)
	canvas.scale = Vector2.ONE*factor
	canvas.position = (size-canvas.size*factor)*.5

static func texture(asset: String) -> Texture2D:
	return load(ART+asset+".webp")

func place(node: Control, rect: Rect2) -> void:
	canvas.add_child(node)
	node.position = rect.position
	node.size = rect.size

func picture(asset: String, rect: Rect2) -> TextureRect:
	var image := TextureRect.new()
	image.texture = texture(asset)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.mouse_filter = MOUSE_FILTER_IGNORE
	place(image,rect)
	return image

func label(words: String, rect: Rect2, pixels: int, align := HORIZONTAL_ALIGNMENT_LEFT, heading := false) -> Label:
	var item := Label.new()
	item.text = words
	item.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	item.horizontal_alignment = align
	item.mouse_filter = MOUSE_FILTER_IGNORE
	item.add_theme_color_override("font_color",INK)
	item.add_theme_font_size_override("font_size",pixels)
	if heading: item.add_theme_font_override("font",face)
	place(item,rect)
	return item

func button(words: String, rect: Rect2, callback: Callable, pixels := 18, asset := "", top_inset := 0) -> Button:
	var item := Button.new()
	item.text = words
	item.add_theme_font_override("font",face)
	item.add_theme_font_size_override("font_size",pixels)
	for state in ["normal","hover","pressed","hover_pressed","disabled","focus"]:
		var box: StyleBox
		if not asset.is_empty():
			var painted := StyleBoxTexture.new()
			painted.texture = texture(asset+"-focus" if state=="focus" else asset)
			if state == "hover": painted.modulate_color = Color(1.08,1.06,1.03)
			if state == "pressed": painted.modulate_color = Color(.87,.83,.73)
			box = painted
		else:
			var surface := StyleBoxFlat.new()
			surface.set_corner_radius_all(10)
			surface.bg_color = Color.TRANSPARENT
			if state == "focus":
				surface.set_border_width_all(2)
				surface.border_color = Color("315850")
			if state in ["hover","pressed"]: surface.bg_color = Color("ab87432b")
			box = surface
		box.set_content_margin_all(0)
		box.content_margin_top = top_inset
		item.add_theme_stylebox_override(state,box)
	for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color","font_hover_pressed_color","font_disabled_color"]:
		item.add_theme_color_override(state,INK)
	place(item,rect)
	item.pressed.connect(callback)
	return item
