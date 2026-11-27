// materials.js groundMaterial: the printed page, layered torn handmade paper. Each region is its own dyed sheet laid
// over the one below (water -> land -> meadow -> forest -> crop fields -> highland -> footpaths), every edge torn
// (ragged line, pale fibrous core, loose fibres, a short soft shadow away from the key light); fallen leaves and
// grass marks; contour sheets every 0.6 m with a white lip and a shadow; the great ranges in cold blue paper with a
// torn snow line; cloud blots, snow, ice and the wild lands' dyes. Lambert, no specular.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
#include "res://shaders/paper_common.gdshaderinc"

uniform sampler2D map_tex : filter_linear, repeat_enable;   // R region, G path, B moisture, A crop field (256 m, wraps)
uniform sampler2D land_tex : filter_linear, repeat_enable;  // land dye at 0.8x
uniform float water_t = 0.18333;  // (WATER_T + 10) / 60
uniform float high_t = 0.41667;
uniform float peak_t = 0.58333;
uniform float kind = 0.0;          // 3 = the backdrop page (always land)
const float MAPN = 256.0;

varying vec3 wpos;
varying vec3 wnor;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnor = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec4 nz(vec2 u) { return ptex(paper_noise, u); }
float tear_at(vec2 q) {
	vec4 a = nz(q * 0.011), b = nz(q * 0.047), c = nz(q * 0.33);
	return (a.r - 0.5) * 0.9 + (b.g - 0.5) * 0.45 + (c.b - 0.5) * 0.22;
}
// one torn sheet: x inside, y rim (with hairs), z the shadow it casts
vec3 sheet(float vA, float vB, float thr, float amp, float width, float tA, float tB, float fine) {
	float dA = vA + tA * amp - thr, dB = vB + tB * amp - thr;
	float inside = smoothstep(-width * 0.08, width * 0.08, dA);
	float rimW = width * (fine * 0.9 + 0.5);
	float rim = inside * (1.0 - smoothstep(rimW * 0.35, rimW, dA));
	float hairs = (1.0 - inside) * smoothstep(0.66, 0.74, fine) * (1.0 - smoothstep(0.0, rimW * 0.7, -dA));
	float shadow = smoothstep(-width * 0.4, width * 0.4, dB) * (1.0 - inside);
	return vec3(inside, max(rim, hairs), shadow);
}

const float GROUND_TONE = 0.78; // (how much darker the ground sheet prints)
const float GROUND_SAT = 1.0;   // (and how much deeper its colour)

void fragment() {
	vec2 p = wpos.xz;
	vec2 sv = -normalize(paper_key_dir.xz) * 0.14;
	vec2 ps = p - sv;
	vec4 sA = texture(map_tex, (p + 0.5) / MAPN);
	vec4 sB = texture(map_tex, (ps + 0.5) / MAPN);
	float tA = tear_at(p), tB = tear_at(ps);
	float fine = nz(p * 1.7).b;
	float hA = sA.r, hB = sB.r;
	bool backdrop = kind > 2.5;
	float landMask = backdrop ? 1.0 : smoothstep(0.2, 0.35, wpos.y);
	float bankY = wpos.y + (fine - 0.5) * 0.06;
	float bankRim = backdrop ? 0.0 : smoothstep(0.17, 0.21, bankY) * (1.0 - smoothstep(0.23, 0.28, bankY));
	vec3 water = vec3(landMask, bankRim, 0.0);
	vec3 forest = sheet(sA.b, sB.b, 0.515, 0.09, 0.02, tA, tB, fine) * landMask;
	vec3 field = sheet(sA.a, sB.a, 0.5, 0.35, 0.06, tA, tB, fine) * landMask;
	vec3 highl = sheet(hA, hB, high_t, 0.03, 0.006, tA, tB, fine) * landMask;
	vec3 peak = sheet(hA, hB, peak_t, 0.03, 0.006, tA, tB, fine) * landMask;
	vec3 path = sheet(-sA.g, -sB.g, -0.14, 0.06, 0.012, tA, tB, fine);

	float ripple = abs(fract(nz(p * 0.055 + TIME * 0.004).r * 7.0) - 0.5);
	float strokes = smoothstep(0.56, 0.66, nz(p * 0.21 + vec2(0.37, 0.11)).g);
	float depth = smoothstep(water_t, water_t - 0.05, hA);
	vec3 col = mix(hexc(0x78a8bc), hexc(0x3d7896), depth);
	col = mix(col, hexc(0xd6e6e8), (1.0 - smoothstep(0.01, 0.03, ripple)) * strokes * 0.34 * (depth * 0.5 + 0.5));
	float skate = 1.0 - smoothstep(0.004, 0.012, abs(fract(nz(p * 0.09 + vec2(0.2, 0.6)).r * 5.0) - 0.5));
	float crack = (1.0 - smoothstep(0.003, 0.01, abs(fract(nz(p * 0.03 + vec2(0.7, 0.1)).g * 4.0) - 0.5))) * smoothstep(0.55, 0.7, nz(p * 0.05).b);
	vec3 iceCol = mix(hexc(0x8fb8d0), hexc(0xb8d6e4), fine * 0.6 + nz(p * 0.012).r * 0.4) * (1.0 - crack * 0.35) + vec3(skate * 0.18);
	col = mix(col, iceCol, paper_ice * (1.0 - landMask));
	float bankShade = smoothstep(water_t - 0.035, water_t + 0.005, hB) * (1.0 - landMask);
	col *= 1.0 - bankShade * 0.32;
	col = mix(col, hexc(0xc8c6a6), water.x);
	vec3 leafy = mix(col, hexc(0xaeb28e), forest.x);
	col = mix(leafy * (1.0 - forest.z * 0.22), leafy, forest.x);
	// the field patchwork: wheat, fresh plough or mown hay, each patch's rows run its own way
	float fpick = nz(p * 0.0045 + vec2(0.13, 0.71)).g + tA * 0.025;
	float fang = nz(p * 0.0045 + vec2(0.53, 0.29)).r * 6.283;
	vec2 fdir = vec2(cos(fang), sin(fang));
	float along = dot(p, fdir);
	float wobble = (nz(p * 0.08).b - 0.5) * 0.6;
	float rowWave = sin((along + wobble) * 3.4);
	float isWheat = smoothstep(0.446, 0.454, fpick) * (1.0 - smoothstep(0.621, 0.629, fpick));
	float isPlough = smoothstep(0.621, 0.629, fpick);
	float patchRim = max(1.0 - smoothstep(0.003, 0.009, abs(fpick - 0.45)), 1.0 - smoothstep(0.003, 0.009, abs(fpick - 0.625)));
	float isHay = max(1.0 - isWheat - isPlough, 0.0);
	vec3 wheat = mix(hexc(0xbfa86e), hexc(0x9a8150), smoothstep(0.55, 0.95, rowWave)) * (1.0 + smoothstep(0.8, 0.95, fine) * 0.12);
	vec3 plough = mix(mix(hexc(0x8a6448), hexc(0x5e4130), smoothstep(-0.2, 0.7, rowWave)), hexc(0xa8805c), smoothstep(0.7, 0.95, -rowWave) * 0.6);
	float swath = sin((along + wobble) * 0.55);
	vec3 hay = mix(hexc(0x9aa070), hexc(0x7e8a5a), smoothstep(-0.15, 0.15, swath)) * (1.0 - smoothstep(0.6, 0.95, rowWave) * 0.06);
	vec3 fieldCol = mix(wheat * isWheat + plough * isPlough + hay * isHay, hexc(0xf3ead6), patchRim * 0.75);
	col *= 1.0 - field.z * 0.22;
	col = mix(col, fieldCol, field.x);
	col *= 1.0 - highl.z * 0.2;
	col = mix(col, hexc(0xc4bdaa), highl.x);
	col = mix(col, hexc(0xd9d6cf), peak.x);
	float yW = wpos.y + (nz(p * 0.045).r - 0.5) * 5.0 + (nz(p * 0.16).g - 0.5) * 2.2;
	vec3 mcol = mix(hexc(0x56689a), hexc(0x9caccc), smoothstep(4.0, 21.0, yW));
	mcol = mix(mcol, hexc(0xf4f6fa), smoothstep(22.5, 24.0, yW));
	mcol *= 0.94 + fine * 0.1;
	col = mix(col, mcol, peak.x * smoothstep(2.5, 6.0, wpos.y));
	// grass marks and fallen leaves in drifts (meadow and forest only)
	vec2 cellP = p * 0.9;
	vec2 cell = floor(cellP);
	float jx = mx_cell_noise_float(vec3(cell, 1.0)), jy = mx_cell_noise_float(vec3(cell, 2.0));
	vec2 lc = fract(cellP) - (vec2(jx, jy) * 0.6 + 0.2);
	float pick = mx_cell_noise_float(vec3(cell, 3.0));
	float ang = pick * 6.283;
	vec2 rl = vec2(lc.x * cos(ang) - lc.y * sin(ang), lc.x * sin(ang) + lc.y * cos(ang));
	float leaf = 1.0 - smoothstep(0.85, 1.0, length(rl * vec2(4.2, 8.5)));
	float grass = 1.0 - smoothstep(0.05, 0.08, length(lc * vec2(1.0, 0.45)));
	float drift = smoothstep(0.5, 0.66, nz(p * 0.04).r) * smoothstep(0.3, 0.6, pick + nz(p * 0.2).g - 0.5);
	float onGreen = water.x * (1.0 - field.x) * (1.0 - highl.x);
	vec3 leafCol = mix(mix(hexc(0xc8642f), hexc(0xb3402c), smoothstep(0.3, 0.6, pick)), hexc(0xd9a441), smoothstep(0.6, 0.9, pick));
	float leafOn = leaf * drift * onGreen * smoothstep(0.35, 0.55, sA.b);
	col = mix(col, hexc(0x8e9862), grass * (1.0 - drift) * onGreen * 0.55);
	col = mix(col * (1.0 - leafOn * 0.15), leafCol, leafOn * 0.9);
	// the footpaths: a torn cream strip over everything (never across water)
	col *= 1.0 - path.z * 0.25 * landMask;
	col = mix(col, hexc(0xefe3c4), path.x * landMask);
	float rims = max(max(max(water.y, forest.y * 0.85), max(field.y, highl.y)), path.y * landMask);
	col = mix(col, hexc(0xf8f2e2), rims * 0.9);
	// handmade paper: pulp, fibres, inclusions (two scales) and the dye's broad watercolour unevenness
	vec3 hp1 = ptex(paper_handmade, p * 0.21).rgb, hp2 = ptex(paper_handmade, p * 0.067 + vec2(0.31, 0.57)).rgb;
	vec3 cream = vec3(0.84, 0.78, 0.65);
	vec3 tint = hp1 / cream * 0.6 + hp2 / cream * 0.4;
	col *= mix(vec3(1.0), tint, 0.85);
	col *= mix(0.9, 1.04, wash_at(p * 0.017));
	// printed contour sheets every 0.6 m (rock strata, tilted and wider, up the great ranges)
	float ny = max(wnor.y, 0.25);
	float slope = sqrt(max(1.0 - ny * ny, 0.0)) / ny;
	float mtnK = peak.x * smoothstep(4.0, 8.0, wpos.y);
	float tiltA = nz(p * 0.0045 + vec2(0.31, 0.77)).r * 9.4;
	vec2 tiltD = vec2(cos(tiltA), sin(tiltA));
	float strata = dot(p, tiltD) * 0.55 + sin(dot(p, vec2(-tiltD.y, tiltD.x)) * 0.07) * 3.5;
	float band = mix(0.6, 2.2, mtnK);
	float yT = wpos.y + strata * mtnK + (nz(p * 0.35).b - 0.5) * mix(0.16, 0.9, mtnK) + (nz(p * 1.9).b - 0.5) * 0.05;
	float fL = fract(yT / band) * band;
	float onHill = landMask * smoothstep(0.25, 0.4, wpos.y) * smoothstep(0.02, 0.08, slope) * (1.0 - mtnK);
	float lipH = slope * 0.07 + 0.004;
	float lipC = (1.0 - smoothstep(lipH * 0.45, lipH, fL)) * onHill;
	float shadeH = slope * 0.4 + 0.01;
	float shadeC = smoothstep(band - shadeH, band, fL) * onHill;
	col *= 1.0 - shadeC * 0.2;
	col = mix(col, hexc(0xfbf6ea) * mix(vec3(1.0), tint, 0.4), lipC * 0.9);
	// cloud blots, snow (the paths stay trodden through it) and the wild lands' dyes
	vec2 cp = p * 0.02 + vec2(TIME * 0.016, TIME * 0.006);
	float cn = mx_noise_float(vec3(cp, 0.0)) * 0.7 + mx_noise_float(vec3(cp * 2.1, 3.7)) * 0.3;
	float blot = smoothstep(0.08, 0.32, cn);
	col *= 1.0 - blot * paper_cloud_shade * 0.18;
	float snowAmt = smoothstep(0.0, 0.3, paper_snow * 1.3 - fine * 0.35 - 0.08) * landMask;
	col = mix(col, hexc(0xf3f0e8) * mix(vec3(1.0), tint, 0.25), snowAmt);
	col = mix(col, hexc(0xc2ab84) * (0.92 + fine * 0.12), path.x * landMask * snowAmt * 0.75);
	vec3 landDye = texture(land_tex, (p + 0.5) / MAPN).rgb * 1.25;
	col *= mix(vec3(1.0), landDye, landMask * (1.0 - snowAmt * 0.7));
	col *= mix(vec3(1.0), min(landDye, vec3(1.0)), (1.0 - landMask) * 0.85);
	// the ground a deeper, richer sheet (the player: the land read pale and washed out under the bright sun): darker,
	// its colour a step more saturated, so the cards and figures stand out on it; the paths and rims stay paler
	float gl = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(gl), col, GROUND_SAT) * GROUND_TONE;
	float hz = haze_factor(wpos);
	ALBEDO = col * (1.0 - hz);
	EMISSION = haze_color(wpos) * hz;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	NORMAL = bump_normal(VERTEX, NORMAL, lum(ptex(paper_handmade, p * 0.21).rgb), 0.06); // (three's bumpMap scale reads ~6x softer than this one)
}
