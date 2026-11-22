// sky.js's watercolour dome, and its hemisphere light. The visible sky: a horizon-to-zenith wash with watercolour
// blooms, the sun's disc and halo, a faint glow round the moon, sparse fibre stars at night. The cubemap pass that
// Godot integrates for ambient light is the HemisphereLight instead (sky colour above, ground colour below, at its
// intensity), so the shade side of every card is lit from the sky as in the web version.
shader_type sky;
#include "res://shaders/paper_common.gdshaderinc"

uniform vec3 zenith : source_color = vec3(0.55, 0.7, 0.8);
uniform vec3 horizon : source_color = vec3(0.95, 0.86, 0.72);
uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
uniform vec3 sun_col : source_color = vec3(1.0, 0.95, 0.84);
uniform float sun_vis = 1.0;
uniform float moon_vis = 0.0;
uniform vec3 hemi_sky : source_color = vec3(0.95, 0.86, 0.72);
uniform vec3 hemi_ground : source_color = vec3(0.54, 0.43, 0.29);
uniform float hemi_intensity = 1.0;

void sky() {
	vec3 dir = EYEDIR;
	if (AT_CUBEMAP_PASS) {
		COLOR = mix(hemi_ground, hemi_sky, dir.y * 0.5 + 0.5) * hemi_intensity;
	} else {
		vec2 sky_uv = dir.xz / (dir.y + 0.35) * 0.35;
		float blooms = ptex(paper_wash, sky_uv).r;
		vec3 col = mix(horizon, zenith, pow(smoothstep(-0.02, 0.6, dir.y), 0.8));
		col *= mix(0.9, 1.03, blooms);
		float sd = dot(dir, sun_dir);
		float disc = smoothstep(0.9968, 0.9975, sd) * sun_vis;
		float halo = (pow(max(sd, 0.0), 24.0) * 0.35 + pow(max(sd, 0.0), 4.0) * 0.12) * sun_vis;
		col = mix(col, sun_col * 1.6, disc) + sun_col * halo;
		float md = dot(dir, -sun_dir);
		col += vec3(0.16, 0.15, 0.12) * pow(max(md, 0.0), 60.0) * moon_vis;
		float star = smoothstep(0.83, 0.9, ptex(paper_fiber, dir.xz / (dir.y + 0.05) * 0.6).r) * moon_vis * smoothstep(0.1, 0.4, dir.y);
		COLOR = col + vec3(star * 0.8);
	}
}
