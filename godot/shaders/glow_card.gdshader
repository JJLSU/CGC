// The night sky's cards (nightsky.js basic()): printed paper stars and moons that give their own light, unlit, no
// haze: the print x glow x tint x instance colour. Also the storm's lightning bolt (no map, a hot cream-gold).
shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled, shadows_disabled;

uniform sampler2D map : source_color, filter_linear_mipmap;
uniform bool has_map = true;
uniform float glow = 1.15;
uniform vec3 tint = vec3(1.0);
uniform vec3 flat_color = vec3(1.0);

void fragment() {
	vec3 c = has_map ? texture(map, vec2(UV.x, 1.0 - UV.y)).rgb : flat_color; // (canvas prints: three's flipY)
	ALBEDO = c * glow * tint * COLOR.rgb;
}
