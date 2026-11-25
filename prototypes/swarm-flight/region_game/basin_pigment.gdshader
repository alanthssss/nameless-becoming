shader_type canvas_item;

uniform vec4 pigment : source_color = vec4(0.1, 0.5, 0.5, 1.0);
uniform bool submerged = false;
uniform float tail_bend = 0.0;

void fragment() {
	vec2 uv = UV;
	// The reference fish faces right. Bend its tail but keep the head anchored.
	uv.y += tail_bend * (1.0 - smoothstep(0.02, 0.48, uv.x));
	vec4 paint = texture(TEXTURE, clamp(uv, vec2(0.0), vec2(1.0)));
	float light = dot(paint.rgb, vec3(0.299, 0.587, 0.114));
	vec3 ink = mix(vec3(0.10, 0.095, 0.075), pigment.rgb, 0.13);
	vec3 body = mix(ink, pigment.rgb, clamp((light - 0.20) / 0.32, 0.0, 1.0));
	body = mix(body, vec3(1.0, 0.96, 0.82), clamp((light - 0.52) / 0.42, 0.0, 1.0) * 0.95);
	if (submerged) {
		body = mix(body, vec3(0.39, 0.58, 0.50), 0.10);
	}
	float within = step(0.0, uv.y) * step(uv.y, 1.0);
	COLOR = vec4(body, paint.a * within * (submerged ? 0.93 : 1.0));
}
