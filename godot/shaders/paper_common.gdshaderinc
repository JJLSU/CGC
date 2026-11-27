// Shared paper helpers: the four baked paper textures (from the web game's textures.js canvases, see PORT.md), the
// world uniforms sky.js and the weather set (key light direction, snow, ice, cloud shade), sRGB hex colours,
// MaterialX cell/perlin noise (as TSL's mx_* nodes) and a derivative bump map (as TSL's bumpMap).
// The canvas textures were uploaded flipped in three.js (flipY), so they're sampled at (u, -v) here.

global uniform sampler2D paper_fiber : filter_linear_mipmap, repeat_enable;
global uniform sampler2D paper_wash : filter_linear_mipmap, repeat_enable;
global uniform sampler2D paper_handmade : source_color, filter_linear_mipmap, repeat_enable;
global uniform sampler2D paper_noise : filter_linear_mipmap, repeat_enable;
global uniform vec3 paper_key_dir;
global uniform vec4 paper_ground_reach; // (x, z, radius): how far out the real ground is built round the farmer (World sets it)
global uniform float paper_snow;
global uniform float paper_ice;
global uniform float paper_cloud_shade;
global uniform vec3 paper_focus;
global uniform vec3 paper_haze;
global uniform vec3 paper_horizon;
global uniform float paper_haze_amt;
global uniform float paper_glow;     // 0 by day .. 1 at night: lit windows and lanterns (homestead.js glowU)

// sky.js's haze, not fog: subtle and only far off, measured on the ground from the hero so the ring travels with the
// subject; past 95 m the page fades into the sky's horizon colour. Applied after lighting: albedo * (1 - f), plus
// the haze colour as emission.
float haze_factor(vec3 wp) {
	float d = distance(wp.xz, paper_focus.xz);
	float near = smoothstep(34.0, 95.0, d) * paper_haze_amt;
	float far = smoothstep(95.0, 150.0, d);
	float high = 1.0 - smoothstep(5.5, 11.0, wp.y) * 0.9;
	return min(near + far, 1.0) * high;
}
vec3 haze_color(vec3 wp) { return mix(paper_haze, paper_horizon, smoothstep(95.0, 150.0, distance(wp.xz, paper_focus.xz))); }

vec4 ptex(sampler2D t, vec2 uv) { return texture(t, vec2(uv.x, -uv.y)); }
float fiber_at(vec2 uv) { return ptex(paper_fiber, uv).r; }
float fiber2(vec2 uv) { return fiber_at(uv) * 0.6 + fiber_at(uv * 3.73 + vec2(0.37, 0.61)) * 0.4; }
float wash_at(vec2 uv) { return ptex(paper_wash, uv).r; }
float lum(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }
float hand_lum(vec2 uv) { return lum(ptex(paper_handmade, uv).rgb) / 0.79; }

// an sRGB 0xRRGGBB colour as linear (three's color(hex))
vec3 hexc(int h) {
	vec3 c = vec3(float((h >> 16) & 255), float((h >> 8) & 255), float(h & 255)) / 255.0;
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

// ---- MaterialX noise (mx_cell_noise_float, mx_noise_float), as three's TSL ports them
uint mx_rotl32(uint x, uint k) { return (x << k) | (x >> (32u - k)); }
uint mx_bjfinal(uint a, uint b, uint c) {
	c ^= b; c -= mx_rotl32(b, 14u);
	a ^= c; a -= mx_rotl32(c, 11u);
	b ^= a; b -= mx_rotl32(a, 25u);
	c ^= b; c -= mx_rotl32(b, 16u);
	a ^= c; a -= mx_rotl32(c, 4u);
	b ^= a; b -= mx_rotl32(a, 14u);
	c ^= b; c -= mx_rotl32(b, 24u);
	return c;
}
uint mx_hash3(int x, int y, int z) {
	uint a = 0xdeadbeefu + (3u << 2u) + 13u; uint b = a; uint c = a;
	a += uint(x); b += uint(y); c += uint(z);
	return mx_bjfinal(a, b, c);
}
float mx_cell_noise_float(vec3 p) { ivec3 i = ivec3(floor(p)); return float(mx_hash3(i.x, i.y, i.z)) / 4294967295.0; }
float mx_fade(float t) { return t * t * t * (t * (t * 6.0 - 15.0) + 10.0); }
float mx_grad(uint hash, vec3 p) {
	uint h = hash & 15u;
	float u = h < 8u ? p.x : p.y;
	float v = h < 4u ? p.y : ((h == 12u || h == 14u) ? p.x : p.z);
	return ((h & 1u) != 0u ? -u : u) + ((h & 2u) != 0u ? -v : v);
}
float mx_noise_float(vec3 p) {
	ivec3 i = ivec3(floor(p)); vec3 f = fract(p);
	float u = mx_fade(f.x), v = mx_fade(f.y), w = mx_fade(f.z);
	float n000 = mx_grad(mx_hash3(i.x, i.y, i.z), f);
	float n100 = mx_grad(mx_hash3(i.x + 1, i.y, i.z), f - vec3(1, 0, 0));
	float n010 = mx_grad(mx_hash3(i.x, i.y + 1, i.z), f - vec3(0, 1, 0));
	float n110 = mx_grad(mx_hash3(i.x + 1, i.y + 1, i.z), f - vec3(1, 1, 0));
	float n001 = mx_grad(mx_hash3(i.x, i.y, i.z + 1), f - vec3(0, 0, 1));
	float n101 = mx_grad(mx_hash3(i.x + 1, i.y, i.z + 1), f - vec3(1, 0, 1));
	float n011 = mx_grad(mx_hash3(i.x, i.y + 1, i.z + 1), f - vec3(0, 1, 1));
	float n111 = mx_grad(mx_hash3(i.x + 1, i.y + 1, i.z + 1), f - vec3(1, 1, 1));
	float r = mix(mix(mix(n000, n100, u), mix(n010, n110, u), v), mix(mix(n001, n101, u), mix(n011, n111, u), v), w);
	return 0.982 * r;
}

// ---- bumpMap(height, scale): perturb the view-space normal by the screen-space slope of a height
vec3 bump_normal(vec3 view_pos, vec3 n, float h, float scale) {
	vec3 dpx = dFdx(view_pos), dpy = dFdy(view_pos);
	float dhx = dFdx(h) * scale, dhy = dFdy(h) * scale;
	vec3 r1 = cross(dpy, n), r2 = cross(n, dpx);
	float det = dot(dpx, r1);
	vec3 grad = sign(det) * (dhx * r1 + dhy * r2);
	return normalize(abs(det) * n - grad);
}
