extends RefCounted
const BODY := 20

func field_caption(label: Label) -> void:
	label.add_theme_font_size_override("font_size",BODY)
	label.add_theme_color_override("font_color",Color("#fff2d5"))
	label.add_theme_color_override("font_shadow_color",Color.TRANSPARENT)
	label.add_theme_constant_override("outline_size",0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var backing := StyleBoxFlat.new()
	backing.bg_color = Color("35594e")
	backing.set_corner_radius_all(8)
	backing.content_margin_left = 10
	backing.content_margin_right = 10
	label.add_theme_stylebox_override("normal",backing)
