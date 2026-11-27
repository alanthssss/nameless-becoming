shader_type canvas_item;
render_mode unshaded;
#include "res://region_game/painted_depth.gdshaderinc"

// Sample the same registered paint as the terrain at the perimeter and root.
// Inside the crown, camera travel and wind displace foliage away from its attachment.
uniform vec2 center_uv;
uniform vec2 radii_uv;
uniform vec2 shift_uv;
uniform vec2 player_uv;
uniform vec2 world_size;
uniform bool hanging = false;
uniform bool foreground = false;

void fragment() {
	vec2 local = (UV - center_uv) / radii_uv;
	float feather = 1.0 - smoothstep(0.24, 1.0, dot(local, local));
	float elevation = 1.0 - smoothstep(-0.28, 0.90, hanging ? -local.y : local.y);
	vec4 paint = garden_paint(UV - shift_uv * feather * elevation, TEXTURE_PIXEL_SIZE);
	if (foreground) {
		float distance_to_bee = length((UV - player_uv) * world_size);
		paint.a *= feather * elevation * mix(0.17, 1.0, smoothstep(24.0, 70.0, distance_to_bee));
	}
	COLOR = paint;
}
