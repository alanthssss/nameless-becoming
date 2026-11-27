shader_type canvas_item;
render_mode unshaded;
#include "res://region_game/painted_depth.gdshaderinc"

uniform vec2 center_uv;
uniform vec2 radii_uv;
uniform vec2 world_size;
uniform float seconds;
uniform bool water;

void fragment() {
	vec2 local = (UV - center_uv) / radii_uv;
	float mask = 1.0 - smoothstep(0.20, 1.0, dot(local, local));
	vec2 p = UV * world_size;
	vec4 paint;
	if (water) {
		// Light travels across the painted reflection in shallow horizontal waves.
		float crest = sin(p.y * 0.13 + p.x * 0.009 - seconds * 1.65);
		float swell = sin(p.y * 0.047 - p.x * 0.007 + seconds * 0.79);
		vec2 refraction = vec2(2.9 * crest + 2.1 * swell, 1.35 * swell);
		paint = garden_paint(UV + mask * refraction / world_size, TEXTURE_PIXEL_SIZE);
		paint.rgb *= 1.0 + 0.035 * mask * crest;
	} else {
		// Broad, soft gaps in the canopy cross existing sunlit paint.
		float gaps = sin(p.x * 0.030 + p.y * 0.021 - seconds * 0.64)
				+ sin(p.y * 0.041 - p.x * 0.016 + seconds * 0.43);
		float shade = smoothstep(-0.65, 1.25, gaps) * mask;
		paint = garden_paint(UV, TEXTURE_PIXEL_SIZE);
		paint.rgb *= vec3(1.0) - vec3(0.115, 0.094, 0.062) * shade;
	}
	// An overlapping leaf patch must remain visible outside this soft brush.
	paint.a *= smoothstep(0.0, 0.12, mask);
	COLOR = paint;
}
