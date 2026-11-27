// materials.js paperMaterial: solid-colour paper (box folds, posts, the hero's parts). The colour (x vertex/instance
// colour) times the paper tone (handmade sheet + fine fibre, projected on the world by the facet normal), snow on
// whatever faces up, a fibre bump. Lambert, no specular.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
#include "res://shaders/paper_common.gdshaderinc"

uniform vec4 albedo : source_color = vec4(1.0);
uniform bool snow = true;
uniform vec3 night_glow = vec3(0.0); // lantern glass (x paper_glow)

varying vec3 wpos;
varying vec3 wnor;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnor = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// worldPlanar(fn, scale): the top projection on up-facing facets, the side ones on walls
float planar_hand(float s) {
	vec3 p = wpos * s; vec3 n = abs(wnor);
	float side = mix(hand_lum(p.zy), hand_lum(p.xy), smoothstep(0.3, 0.7, n.z));
	return mix(side, hand_lum(p.xz), smoothstep(0.45, 0.75, n.y));
}
float planar_fiber2(float s) {
	vec3 p = wpos * s; vec3 n = abs(wnor);
	float side = mix(fiber2(p.zy), fiber2(p.xy), smoothstep(0.3, 0.7, n.z));
	return mix(side, fiber2(p.xz), smoothstep(0.45, 0.75, n.y));
}
float planar_fiber(float s) {
	vec3 p = wpos * s; vec3 n = abs(wnor);
	float side = mix(fiber_at(p.zy), fiber_at(p.xy), smoothstep(0.3, 0.7, n.z));
	return mix(side, fiber_at(p.xz), smoothstep(0.45, 0.75, n.y));
}

instance uniform float near_only = 0.0; // (1: drawn only over the built ground, never hanging over the flat sheet past it)
void fragment() {
	if (near_only > 0.0 && distance(wpos.xz, paper_ground_reach.xy) > paper_ground_reach.z) discard;
	float tone = planar_hand(0.55) * 0.75 + 0.25 + (planar_fiber2(0.9) - 0.5) * 0.12;
	vec3 base = albedo.rgb * COLOR.rgb;
	float up = snow ? paper_snow * smoothstep(0.5, 0.85, wnor.y) : 0.0;
	float hz = haze_factor(wpos);
	ALBEDO = mix(base * tone, hexc(0xf3f0e8) * tone, up) * (1.0 - hz);
	EMISSION = haze_color(wpos) * hz + night_glow * paper_glow;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	NORMAL = bump_normal(VERTEX, NORMAL, planar_fiber(0.9), 0.02);
}
