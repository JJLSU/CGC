// materials.js cardMaterial: a printed die-cut card or a printed model. The art (map) on handmade stock: the sheet's
// pulp and fibres show through the ink; snow settles on what faces the sky (snow: 0 none, 1 full, between = part);
// a tree crown's snow cap (snow_cap: the height in uv above which it whitens); an optional hue turn for clothes that
// spares skin, hair, leather and wood (tintClothes); idle wind sway for instanced props; an emissive self-fill for
// models (so a face in shade stays a face). Lambert, no specular.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_disabled;
#include "res://shaders/paper_common.gdshaderinc"

uniform sampler2D map : source_color, filter_linear_mipmap, repeat_enable;
uniform bool flip_map = false;     // canvas prints were uploaded flipped (flipY); glTF textures were not
uniform bool has_map = true;
uniform vec4 albedo : source_color = vec4(1.0);
uniform float paper_scale = 1.0;
uniform float pulp = 0.55;
uniform float hue = 0.0;           // radians
uniform float snow = 1.0;
uniform float snow_cap = 0.0;
uniform float sway = 0.0;          // metres of bend per metre^2 of height (instanced props)
uniform float faded = 0.0;         // a one-state model run-down: greyed and darkened (town.js faded())
uniform float self_fill = 0.0;     // emissive share of the print (0.28 for the models)
uniform vec3 night_glow = vec3(0.0); // windows: their dark panes glow amber at night (x paper_glow)
uniform bool no_haze = false;      // (the paper clouds: fog: false)
uniform bool ghosts = false;
uniform float alpha_cut = 0.0;     // a cut-out print (its own transparent ground, e.g. the twister's frames): cut where the print's alpha is below this       // a pool whose cards can stand between camera and farmer: INSTANCE_CUSTOM.x is the fade

instance uniform float near_only = 0.0; // (1: drawn only over the built ground, never hanging over the flat sheet past it)
instance uniform vec4 cutaway = vec4(0.0); // (x, z, from y, radius): a cutaway roof, cut off above y within radius (the farmer up in a cabin)
varying vec3 wnor;
varying vec3 wpos;
varying float fade;

vec3 tint_clothes(vec3 c, float a) {
	vec3 k = vec3(0.57735);
	float ca = cos(a), sa = sin(a);
	vec3 spun = c * ca + cross(k, c) * sa + k * dot(k, c) * (1.0 - ca);
	vec3 turned = mix(spun, vec3(dot(spun, vec3(0.299, 0.587, 0.114))), 0.32);
	float chroma = c.r - c.b, gpos = (c.g - c.b) / max(chroma, 0.001);
	float warm = step(c.g, c.r) * step(c.b, c.g);
	float keep = warm * smoothstep(0.06, 0.16, gpos) * (1.0 - smoothstep(0.85, 0.95, gpos)) * smoothstep(0.02, 0.06, chroma);
	return mix(turned, c, clamp(keep, 0.0, 1.0));
}

void vertex() {
	if (sway > 0.0) {
		float ph = fract(sin(float(INSTANCE_ID) * 12.9898) * 43758.5453);
		float w = TIME * (ph * 1.6 + 2.6) + ph * 6.283;
		float gust = sin(TIME * 0.23 + ph * 3.0) * 0.35 + 0.75;
		float y2 = VERTEX.y * VERTEX.y * sway * gust;
		VERTEX += vec3(sin(w) * y2, 0.0, cos(w * 0.83) * y2 * 0.6);
	}
	wnor = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	fade = ghosts ? INSTANCE_CUSTOM.x : 0.0;
}

void fragment() {
	// dissolving to a faint ghost through a fine even stipple (interleaved-gradient noise), no movement
	if (fade > 0.0) { float ign = fract(52.9829189 * fract(FRAGCOORD.x * 0.06711056 + FRAGCOORD.y * 0.00583715)); if (fade > ign) discard; }
	if (near_only > 0.0 && distance(wpos.xz, paper_ground_reach.xy) > paper_ground_reach.z) discard;
	if (cutaway.w > 0.0 && wpos.y > cutaway.z && distance(wpos.xz, cutaway.xy) < cutaway.w) discard;
	vec2 muv = flip_map ? vec2(UV.x, 1.0 - UV.y) : UV;
	if (alpha_cut > 0.0 && texture(map, muv).a < alpha_cut) discard;
	// (the paper's own grain runs in three.js uv space, v up)
	vec2 puv = vec2(UV.x, flip_map ? UV.y : 1.0 - UV.y);
	float fib = fiber2(puv * 2.4 * paper_scale);
	vec3 hand = ptex(paper_handmade, puv * 1.3 * paper_scale).rgb / vec3(0.84, 0.78, 0.65);
	vec3 base = (has_map ? texture(map, muv).rgb : vec3(1.0)) * albedo.rgb * COLOR.rgb;
	if (faded > 0.0) base = mix(base, vec3(dot(base, vec3(0.3, 0.59, 0.11))), 0.55 * faded) * mix(1.0, 0.8, faded);
	if (hue != 0.0) base = tint_clothes(base, hue);
	vec3 ink = base * mix(vec3(1.0), hand, pulp) * (1.0 + (fib - 0.5) * 0.14);
	vec3 col = ink;
	vec3 snowc = hexc(0xf3f0e8) * mix(vec3(1.0), hand, 0.3);
	if (snow > 0.0) col = mix(ink, snowc, paper_snow * snow * smoothstep(0.5, 0.85, wnor.y));
	if (snow_cap > 0.0) col = mix(col, snowc, paper_snow * smoothstep(snow_cap, snow_cap + 0.06, puv.y + (fib - 0.5) * 0.12));
	float hz = no_haze ? 0.0 : haze_factor(wpos);
	ALBEDO = col * (1.0 - hz);
	EMISSION = ink * self_fill * (1.0 - hz) + haze_color(wpos) * hz;
	if (night_glow != vec3(0.0)) EMISSION += night_glow * clamp(1.0 - texture(map, muv).r * 1.4, 0.0, 1.0) * paper_glow;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	NORMAL = bump_normal(VERTEX, NORMAL, lum(hand) * 0.6 + fib * 0.4, 0.02 * min(1.0, pulp / 0.55));
}
