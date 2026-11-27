// post.js, as a full-screen pass drawn after the opaque scene: one bounce of light (the lit image blurred wide, taken
// back tinted by each surface's own hue, mostly in the shade), a thin warm silhouette line where a card stands in front
// of something farther off, the tilt-shift macro lens (one sharp band on the hero, blur by relative depth and screen
// height, gathered from two blur levels), Neutral tone mapping at the exposure, then the mild vintage grade in display
// space (saturation, warm shadows, white balance, a warm shadow lift, contrast, navy night), a light warm vignette
// and ~1 % grain. Godot's environment does the contact occlusion (SSAO) and the bloom on lit panes (glow).
// The environment tone mapper is Linear at exposure 1, so this pass owns the tone curve; it outputs linear light.
shader_type spatial;
render_mode unshaded, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled, shadows_disabled;

uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;
uniform float exposure = 1.4;
uniform float focus_z = 30.0;      // view depth of the hero (the focus point)
uniform float focus_y = 0.5;       // screen height of the focus line (the camera looks at the hero)
uniform float k_d = 1.2;           // relative depth -> frame heights: 1 / (fovY * cot(pitch))
uniform float band = 0.3;
uniform float ramp = 0.3;
uniform float depth_weight = 0.8;
uniform float near_gain = 1.55;
uniform float far_gain = 0.35;    // how hard what lies beyond the focus blurs: a third of the near side (the player found the distance too soft)
uniform float night = 0.0;
uniform float saturation = 0.98;
uniform float shadow_warmth = 0.7;
uniform float contrast = 0.32;
uniform float dof_enabled = 1.0;
uniform float bounce = 0.5;
global uniform float paper_snow; // (snow lying: the grade cools, the shade on it goes blue, as snow light does)
// the look (the player: the land read pale and washed out): the engine's own screen-space bounce (SSIL) now carries
// light into the shade, so the faked one is taken down; a touch less exposure and less orange in the darks
uniform float bounce_k = 0.45;      // (share of the faked bounce kept; 1.0 = as before)
uniform float exposure_k = 0.9;
uniform float warmth_k = 0.65;
uniform float contrast_add = 0.08;
uniform bool line_enabled = true;

void vertex() {
	POSITION = vec4(VERTEX.xy * 2.0, 1.0, 1.0); // (a 1x1 quad stretched over the whole screen)
}

float view_z(vec2 uv, mat4 inv_proj) {
	float d = texture(depth_tex, uv).r;
	vec4 v = inv_proj * vec4(uv * 2.0 - 1.0, d, 1.0);
	return -v.z / v.w;
}

vec3 neutral(vec3 color) {
	const float start = 0.8 - 0.04;
	const float desat = 0.15;
	color *= exposure * mix(exposure_k, 1.0, night); // (the trim by day only: night is dark enough)
	float x = min(color.r, min(color.g, color.b));
	float offset = x < 0.08 ? x - 6.25 * x * x : 0.04;
	color -= offset;
	float peak = max(color.r, max(color.g, color.b));
	if (peak < start) return color;
	float d = 1.0 - start;
	float new_peak = 1.0 - d * d / (peak + d - start);
	color *= new_peak / peak;
	float g = 1.0 - 1.0 / (desat * (peak - new_peak) + 1.0);
	return mix(color, vec3(new_peak), g);
}
vec3 to_srgb(vec3 c) { c = max(c, vec3(0.0)); return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), c)); }
vec3 to_linear(vec3 c) { return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c)); }
float lum(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 px = 1.0 / VIEWPORT_SIZE;
	float z = view_z(uv, INV_PROJECTION_MATRIX);
	// ---- tilt-shift amount (0 sharp .. 1 full blur): screen height mixed with relative depth (three's screenUV.y is
	// up from the bottom; Godot's SCREEN_UV.y runs down)
	float sY = (1.0 - uv.y) - focus_y;
	float sD = (z - focus_z) / focus_z * k_d;
	float cc = mix(sY, sD, depth_weight);
	float a0 = clamp((abs(cc) - band * 0.5) / ramp, 0.0, 1.0);
	float a1 = a0 * a0 * (3.0 - a0 * 2.0) * 0.35 + a0 * 0.65;
	float blur_amt = min(a1 * (sD < 0.0 ? near_gain : far_gain), 1.0) * dof_enabled;
	vec3 base = textureLod(screen, uv, 0.0).rgb;
	// ---- one bounce of light
	vec3 around = textureLod(screen, uv, 4.5).rgb;
	float L = lum(base);
	vec3 albedo = clamp(base / max(L, 0.12) * 0.55, 0.0, 1.4);
	float shade = 1.0 - smoothstep(0.18, 0.7, L);
	base += around * albedo * bounce * bounce_k * (shade * 0.75 + 0.25);
	// ---- thin silhouette line where a card stands in front of something farther away (~1 px, warm)
	if (line_enabled) {
		float farther = max(max(view_z(uv + vec2(px.x, 0.0), INV_PROJECTION_MATRIX), view_z(uv - vec2(px.x, 0.0), INV_PROJECTION_MATRIX)),
			max(view_z(uv + vec2(0.0, px.y), INV_PROJECTION_MATRIX), view_z(uv - vec2(0.0, px.y), INV_PROJECTION_MATRIX)));
		float line = smoothstep(0.04, 0.12, (farther - z) / z) * (1.0 - blur_amt);
		base = mix(base, base * vec3(0.76, 0.67, 0.58), line * 0.7);
	}
	// ---- the lens: two blur levels (the screen texture's blurred mips), gathered progressively
	vec3 blur_a = textureLod(screen, uv, 1.6).rgb;
	vec3 blur_b = textureLod(screen, uv, 2.6).rgb;
	vec3 dofed = mix(mix(base, blur_a, smoothstep(0.0, 0.45, blur_amt)), blur_b, smoothstep(0.45, 1.0, blur_amt));
	// ---- tone map, then the grade in display space
	vec3 c = to_srgb(neutral(dofed));
	float l = lum(c);
	c = mix(vec3(l), c, mix(saturation, saturation * 0.9, night));
	float shadow_w = 1.0 - smoothstep(0.0, 0.5, l);
	c = mix(c, c * vec3(1.16, 0.9, 0.78), shadow_w * shadow_warmth * warmth_k * (1.0 - paper_snow * 0.8));
	c = mix(c, c * vec3(0.8, 0.91, 1.15), (1.0 - smoothstep(0.35, 0.85, l)) * paper_snow); // (snow in shade is still bright: a wider weight) // (blue shade on the snow)
	c = mix(c, c * vec3(0.93, 0.97, 1.05), paper_snow * (1.0 - night)); // (a cooler day)
	c *= vec3(1.03, 0.985, 0.95);
	c += vec3(0.227, 0.125, 0.047) * 0.03 * (1.0 - smoothstep(0.0, 0.45, l));
	c = mix(c, c * c * (3.0 - c * 2.0), contrast + contrast_add);
	c = mix(c, c * vec3(0.82, 0.9, 1.1), night * (1.0 - smoothstep(0.3, 0.75, l)) * 0.5);
	float asp = VIEWPORT_SIZE.x / VIEWPORT_SIZE.y;
	float d = length((uv - 0.5) * vec2(asp, 1.0));
	c *= 1.0 - smoothstep(0.45, 1.1, d) * mix(0.12, 0.26, night);
	float grain = fract(sin(dot(FRAGCOORD.xy + fract(TIME * 13.7) * 97.0, vec2(12.9898, 78.233))) * 43758.5453);
	c += (grain - 0.5) * 0.012;
	ALBEDO = to_linear(clamp(c, 0.0, 1.0));
}
