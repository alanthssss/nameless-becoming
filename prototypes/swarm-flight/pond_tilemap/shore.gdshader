shader_type canvas_item;
render_mode unshaded;

uniform sampler2D ground_paint : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D water_paint : source_color, repeat_enable, filter_linear_mipmap;
uniform vec2 camera_origin = vec2(0.0);
uniform bool water_only = false;
varying vec2 world_point;
varying float pattern;

void vertex() {
    world_point = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy + camera_origin;
    // TileData owns the four-corner pattern. No per-frame tile mutation.
    pattern = COLOR.r * 15.0;
}

void fragment() {
    vec2 uv = world_point / 512.0;
    vec3 water = texture(water_paint, uv).rgb;
    if (water_only) {
        COLOR = vec4(water, 1.0);
    } else {
        int mask = int(round(pattern));
        vec2 q = fract(world_point / 64.0);
        float a = float(mask & 1);
        float b = float((mask >> 1) & 1);
        float c = float((mask >> 2) & 1);
        float d = float((mask >> 3) & 1);
        float land = mix(mix(a, b, q.x), mix(d, c, q.x), q.y);
        vec3 grass = texture(ground_paint, uv).rgb;
        // A narrow earthen lip softens the same 0.5 contour used by movement.
        vec3 soil = grass * vec3(0.85, 0.78, 0.56);
        vec3 paint = mix(soil, grass, smoothstep(0.49, 0.64, land));
        float alpha = smoothstep(0.40, 0.51, land);
        COLOR = vec4(paint, alpha);
    }
}
