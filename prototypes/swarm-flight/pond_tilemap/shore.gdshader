shader_type canvas_item;
render_mode unshaded;

uniform sampler2D ground_paint : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D water_paint : source_color, repeat_enable, filter_linear_mipmap;
uniform vec2 camera_origin = vec2(0.0);
uniform bool water_only = false;
uniform sampler2D shore_field : repeat_disable, filter_linear;
uniform vec2 field_origin = vec2(0.0);
uniform vec2 field_size = vec2(1.0);
varying vec2 world_point;

void vertex() {
    world_point = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy + camera_origin;
}

void fragment() {
    vec2 uv = world_point / 512.0;
    vec3 water = texture(water_paint, uv).rgb;
    if (water_only) {
        COLOR = vec4(water, 1.0);
    } else {
        float land = texture(shore_field, ((world_point-field_origin)/4.0+0.5)/field_size).r;
        vec3 grass = texture(ground_paint, uv).rgb;
        // A restrained ochre contact edge, with width from the existing brushwork.
        // No added palette or uniform dark outline around the whole peninsula.
        float brush = dot(grass,vec3(0.299,0.587,0.114));
        vec3 soil = grass * vec3(0.91, 0.85, 0.69);
        vec3 paint = mix(soil, grass, smoothstep(0.48, 0.60+0.06*brush, land));
        float alpha = smoothstep(0.43, 0.55, land);
        COLOR = vec4(paint, alpha);
    }
}
