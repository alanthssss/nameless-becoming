shader_type canvas_item;

uniform bool submerged = false;
uniform float tail_bend = 0.0;

// The three painted islands follow the fish texture's back. Ivory flank and
// fins stay exposed at native size, and tail flex carries its markings along.
float koi_patch(vec2 uv, vec2 centre, vec2 radius) {
	vec2 local = (uv - centre) / radius;
	float edge = length(local) + 0.11 * sin(4.0 * local.x + 2.0 * local.y);
	return 1.0 - smoothstep(0.87, 1.06, edge);
}

void fragment() {
	vec2 uv = UV;
	// The reference fish faces right. Bend its tail but keep the head anchored.
	uv.y += tail_bend * (1.0 - smoothstep(0.02, 0.48, uv.x));
	vec4 paint = texture(TEXTURE, clamp(uv, vec2(0.0), vec2(1.0)));
	float light = dot(paint.rgb, vec3(0.299, 0.587, 0.114));
	vec3 pigment = vec3(0.33, 0.59, 0.14);
	if (submerged) {
		float red = max(koi_patch(uv, vec2(0.83, 0.38), vec2(0.095, 0.21)),
			max(koi_patch(uv, vec2(0.60, 0.51), vec2(0.12, 0.18)),
				koi_patch(uv, vec2(0.37, 0.43), vec2(0.057, 0.105))));
		pigment = mix(vec3(0.96, 0.925, 0.85), vec3(0.90, 0.20, 0.105), red);
	}
	vec3 ink = mix(vec3(0.10, 0.095, 0.075), pigment, 0.13);
	vec3 body = mix(ink, pigment, clamp((light - 0.20) / 0.32, 0.0, 1.0));
	body = mix(body, vec3(1.0, 0.96, 0.82), clamp((light - 0.52) / 0.42, 0.0, 1.0) * 0.95);
	if (submerged) {
		body = mix(body, vec3(0.39, 0.58, 0.50), 0.10);
	}
	float within = step(0.0, uv.y) * step(uv.y, 1.0);
	COLOR = vec4(body, paint.a * within * (submerged ? 0.93 : 1.0));
}
