// The RGB data map is registered to the painting: red marks supporting forms,
// green groups quieter values, and blue carries selective light/dark brushwork.
uniform sampler2D plate_art : source_color, filter_linear, repeat_disable;
uniform sampler2D depth_map : filter_linear, repeat_disable;

vec4 garden_paint(vec2 uv, vec2 texel) {
	vec4 paint = texture(plate_art, uv);
	vec3 mask = texture(depth_map, uv).rgb;
	const vec3 weights = vec3(0.299, 0.587, 0.114);
	float value = dot(paint.rgb, weights);
	float relief = 0.0;
	if (mask.r > 0.01) {
		// Work at brushstroke scale. Limit the light side so rims do not glow.
		vec2 step_uv = texel * 2.6;
		vec3 neighbors = texture(plate_art, uv + vec2(step_uv.x, 0.0)).rgb
				+ texture(plate_art, uv - vec2(step_uv.x, 0.0)).rgb
				+ texture(plate_art, uv + vec2(0.0, step_uv.y)).rgb
				+ texture(plate_art, uv - vec2(0.0, step_uv.y)).rgb;
		float stroke = value - dot(neighbors * 0.25, weights);
		relief = mask.r * 0.67 * smoothstep(0.07, 0.25, value) * clamp(stroke, -0.095, 0.058);
	}
	vec3 color = mix(paint.rgb, vec3(value), mask.g * 0.25 + mask.r * 0.065);
	color = mix(color, vec3(0.35, 0.40, 0.315), mask.g * 0.16);
	color -= smoothstep(0.58, 0.94, value) * (mask.g * 0.053 + mask.r * 0.030);
	float brush = (mask.b - 128.0 / 255.0) * 0.30;
	paint.rgb = clamp(color + relief + brush, 0.0, 1.0);
	return paint;
}
