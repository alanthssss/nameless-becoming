extends HFlowContainer
## One cap per alternate input. Physical key names may themselves contain "/".
const WAX := preload("res://region_game/controls_wax_keycap.png")
const PAINTED_Q := preload("res://region_game/controls_wax_q.png")
const INK := Color("583011")
const HEIGHT := 31
static var blank_face := _face(WAX)
static var q_face := _face(PAINTED_Q)

static func _face(texture: Texture2D) -> StyleBoxTexture:
	var face := StyleBoxTexture.new()
	face.texture = texture
	face.texture_margin_left = 9
	face.texture_margin_right = 9
	face.texture_margin_top = 7
	face.texture_margin_bottom = 10
	face.content_margin_left = 6
	face.content_margin_right = 6
	face.content_margin_top = 0
	face.content_margin_bottom = 3
	return face

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("h_separation", 4)
	add_theme_constant_override("v_separation", 2)

func display(names: PackedStringArray, instruction := "") -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	if not instruction.is_empty():
		_add_note(instruction)
	for i in names.size():
		if i > 0: _add_note("或")
		var cap := Label.new()
		cap.text = names[i]
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cap.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cap.custom_minimum_size = Vector2(32, HEIGHT)
		cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cap.add_theme_font_size_override("font_size", 18)
		var painted := cap.text == "Q"
		cap.add_theme_stylebox_override("normal", q_face if painted else blank_face)
		cap.add_theme_color_override("font_color", Color.TRANSPARENT if painted else INK)
		add_child(cap)

func depress(pressed: bool) -> void:
	scale = Vector2(1.0, 0.92) if pressed else Vector2.ONE
	pivot_offset = Vector2(0, size.y)
	modulate = Color("ebdbbd") if pressed else Color.WHITE

func _add_note(words: String) -> void:
	var note := Label.new()
	note.text = words
	note.custom_minimum_size.y = HEIGHT
	note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	note.add_theme_font_size_override("font_size", 15)
	note.add_theme_color_override("font_color", Color("f1e4bf"))
	add_child(note)
