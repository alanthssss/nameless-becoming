shader_type canvas_item;
render_mode unshaded;
#include "res://region_game/painted_depth.gdshaderinc"

void fragment() {
	COLOR = garden_paint(UV, TEXTURE_PIXEL_SIZE);
}
