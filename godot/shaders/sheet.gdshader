// A translucent lit paper sheet (mist.js's tissue, puddles.js's puddle): the print's colour (optionally tinted) on
// Lambert light, its alpha x opacity, both sides, no depth writes. Canvas prints: three's flipY.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_disabled, depth_draw_never;

uniform sampler2D map : source_color, filter_linear_mipmap;
uniform float opacity = 1.0;
uniform vec3 tint = vec3(1.0);
uniform bool unlit = false;

void fragment() {
	vec4 t = texture(map, vec2(UV.x, 1.0 - UV.y));
	ALBEDO = t.rgb * tint;
	ALPHA = t.a * opacity;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
