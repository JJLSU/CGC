class_name DaySky
extends Node3D
## sky.js: the day (720 s, deep night three times as fast), the sun's path, the key light placed relative to the
## camera by the papercraft lens rule (55 degrees off the camera axis toward screen-left, a little toward the camera,
## ~50 degrees up by day, lower toward golden hour, 45 for the moon), the warm sun / blue moon, the hemisphere ambient
## that rises toward dusk and night, the frontal fill, the haze ring round the hero, a passing shower's grey, the
## watercolour dome and twenty die-cut paper clouds drifting overhead, always turned to the camera.

const DAY_LENGTH := 720.0
static func C(h: int) -> Color: return Color.hex((h << 8) | 0xff)
var PAL := {
	"zenithDay": C(0x8db4cc), "horizonDay": C(0xf2dcb8), "zenithNight": C(0x1a2340), "horizonNight": C(0x3a3a5a),
	"sunset": C(0xf09a5c), "sunsetHigh": C(0xd98a8a), "sunHigh": C(0xffe2b8), "sunLow": C(0xff9a58), "moon": C(0x8ea2e0),
	"hemiDay": C(0xf3dcb8), "hemiNight": C(0x3a56b0), "duskSky": C(0xa898d0), "duskGround": C(0x5a4a78),
	"hazeDay": C(0xc9c2a8), "hazeDusk": C(0xc98fa0), "hazeNight": C(0x0e1a44),
	"fillDay": C(0xf2dcc2), "fillGolden": C(0xb9bcd8), "fillDusk": C(0x6f63a8), "fillNight": C(0x7890d0),
	"groundDay": C(0x8a6d4a), "groundNight": C(0x22243a),
}
## Godot's light units vs three's: tuned once against web frames (see PORT.md).
## (21a: measured against the web, the key and fill keep their colours as sRGB; only the point lights take theirs as
## linear, see PORT.md 20d)
const SUN_K := 1.0 / PI # (three's lights land on a Lambert surface divided by pi; Godot's do not)
const FILL_K := 1.0 / PI
const HEMI_K := 1.0 / PI

var time := 0.31
var day := 1
var night := 0.0
var dusk := 0.0
var rain := 0.0
var sun_dir := Vector3.UP
var key_dir := Vector3.UP
var sun: DirectionalLight3D
var fill: DirectionalLight3D
var env: Environment
var sky_mat: ShaderMaterial
var clouds: Array = []
var hemi_intensity := 1.0
var haze := Color()
var haze_amt := 0.3
var horizon_col := Color()

func _init(environment: Environment) -> void:
	env = environment
	sky_mat = ShaderMaterial.new(); sky_mat.shader = preload("res://shaders/sky.gdshader")
	var skyres := Sky.new()
	skyres.sky_material = sky_mat
	skyres.radiance_size = Sky.RADIANCE_SIZE_32
	skyres.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	env.background_mode = Environment.BG_SKY
	env.sky = skyres
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 1.0
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED

func _ready() -> void:
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.shadow_bias = 0.03
	sun.shadow_normal_bias = 1.0
	sun.directional_shadow_max_distance = 80.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	add_child(sun)
	fill = DirectionalLight3D.new()
	fill.shadow_enabled = false
	add_child(fill)
	_build_clouds()

func _build_clouds() -> void:
	var rng := PNoise.Mulberry32.new(42)
	var shapes := []
	for v in 3:
		var pts := PackedVector2Array()
		var bumps := 3 + v; var w := 10.0 + v * 3
		pts.append(Vector2(w / 2.0, 0))
		for b in bumps:
			var cx := w / 2.0 - (w / bumps) * (b + 0.5); var r := (w / bumps) * (0.55 + rng.next() * 0.25)
			var lift := (1.0 - absf(b - (bumps - 1) / 2.0) / bumps) * 2.2
			for k in 9:
				var a := (k / 8.0) * PI
				pts.append(Vector2(cx + cos(a) * r, lift + sin(a) * r * 0.9))
		pts.append(Vector2(-w / 2.0, 0))
		var tex: Texture2D = load("res://assets/baked/sky/cloud%d.png" % v)
		var mat := PaperMats.card(tex, {"flip": true, "snow": 0.0})
		mat.set_shader_parameter("no_haze", true)
		shapes.append({"mesh": CardMesh.build(pts, 0.25), "mat": mat})
	for i in 20:
		var s: Dictionary = shapes[i % shapes.size()]
		var m := MeshInstance3D.new(); m.mesh = s.mesh; m.material_override = s.mat
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var x := (rng.next() - 0.5) * 440.0; var y := 50.0 + rng.next() * 30.0; var z := (rng.next() - 0.5) * 440.0
		m.position = Vector3(x, y, z)
		m.scale = Vector3.ONE * (0.9 + rng.next() * 0.9)
		add_child(m)
		clouds.append(m)

static func ss(a: float, b: float, x: float) -> float: return PNoise.smoothstep(a, b, x)

## Advance the day and place the sun, the lights and the clouds round the player (center) for this camera.
func update(dt: float, center: Vector3, camera: Camera3D) -> void:
	time += (dt * (3.0 if night > 0.8 else 1.0)) / DAY_LENGTH
	if time >= 1.0: time -= 1.0; day += 1
	var a := (time - 0.25) * PI * 2.0
	sun_dir = Vector3(cos(a), sin(a) * 0.85, 0.45).normalized()
	var e := sun_dir.y
	var day_amt := ss(-0.16, 0.2, e)
	dusk = (1.0 - ss(0.0, 0.32, absf(e))) * ss(-0.25, 0.0, e)
	night = 1.0 - day_amt
	var zen: Color = PAL.zenithNight.lerp(PAL.zenithDay, day_amt).lerp(PAL.sunsetHigh, dusk * 0.25)
	var hor: Color = PAL.horizonNight.lerp(PAL.horizonDay, day_amt).lerp(PAL.sunset, dusk * 0.7)
	horizon_col = hor
	var sun_col: Color = PAL.sunLow.lerp(PAL.sunHigh, ss(0.0, 0.45, e))
	sky_mat.set_shader_parameter("zenith", zen)
	sky_mat.set_shader_parameter("horizon", hor)
	sky_mat.set_shader_parameter("sun_dir", sun_dir)
	sky_mat.set_shader_parameter("sun_col", sun_col)
	sky_mat.set_shader_parameter("sun_vis", ss(-0.08, 0.02, e))
	sky_mat.set_shader_parameter("moon_vis", ss(0.0, -0.12, e))
	var is_day := e > -0.02
	# the key light, placed relative to the camera
	var fwd := center - camera.global_position; fwd.y = 0; fwd = fwd.normalized()
	var left_x := fwd.z; var left_z := -fwd.x
	var az := deg_to_rad(55.0)
	var hx := -fwd.x * cos(az) + left_x * sin(az); var hz := -fwd.z * cos(az) + left_z * sin(az)
	var elev := deg_to_rad(26.0 + 24.0 * ss(0.05, 0.45, e) if is_day else 45.0)
	key_dir = Vector3(hx * cos(elev), sin(elev), hz * cos(elev)).normalized()
	sun.light_color = sun_col if is_day else PAL.moon
	sun.light_energy = (3.8 * ss(-0.02, 0.22, e) if is_day else 1.6 * ss(0.02, 0.2, -e)) * SUN_K
	sun.global_basis = Basis.looking_at(-key_dir, Vector3.UP if absf(key_dir.y) < 0.99 else Vector3.FORWARD)
	RenderingServer.global_shader_parameter_set("paper_key_dir", key_dir)
	# ambient rises toward dusk and night (violet at dusk, saturated blue at night)
	var night_amt := 1.0 - day_amt
	hemi_intensity = 0.88 + 0.55 * night_amt + 0.3 * dusk
	var hemi_sky: Color = PAL.hemiNight.lerp(PAL.hemiDay, day_amt).lerp(PAL.duskSky, dusk * 0.6)
	var hemi_ground: Color = PAL.groundNight.lerp(PAL.groundDay, day_amt).lerp(PAL.duskGround, dusk * 0.5)
	# the frontal fill from behind the camera
	var golden := ss(0.32, 0.08, e) * ss(-0.02, 0.06, e)
	fill.light_color = PAL.fillDay.lerp(PAL.fillGolden, golden).lerp(PAL.fillDusk, dusk).lerp(PAL.fillNight, ss(0.3, 0.8, night_amt))
	fill.light_energy = (0.38 + 0.35 * golden + 0.8 * dusk + 0.45 * ss(0.3, 0.8, night_amt)) * FILL_K
	var back := camera.global_position - center; back.y = 0; back = back.normalized()
	var fill_from := back * 60.0 + Vector3(0, 40, 0)
	fill.global_basis = Basis.looking_at(-fill_from.normalized(), Vector3.UP)
	# paper clouds drift and wrap round the player, turned to face the camera
	for c in clouds:
		c.position.x += dt * 1.2
		var ddx: float = c.position.x - center.x; var ddz: float = c.position.z - center.z
		if ddx > 220.0: c.position.x -= 440.0
		elif ddx < -220.0: c.position.x += 440.0
		if ddz > 220.0: c.position.z -= 440.0
		elif ddz < -220.0: c.position.z += 440.0
		c.rotation.y = atan2(camera.global_position.x - c.position.x, camera.global_position.z - c.position.z)
	# the haze follows the hero
	haze = PAL.hazeDay.lerp(PAL.hazeDusk, dusk).lerp(PAL.hazeNight, ss(0.3, 0.85, night_amt))
	haze_amt = 0.24 + 0.41 * dusk + 0.5 * ss(0.3, 0.85, night_amt)
	# a passing shower: the key softens and greys, the haze thickens to a pale rainy blue-grey
	if rain > 0.001:
		sun.light_energy *= 1.0 - 0.55 * rain
		hemi_intensity *= 1.0 - 0.1 * rain
		sun.light_color = sun.light_color.lerp(C(0xc9d2d8), 0.5 * rain)
		haze = haze.lerp(C(0xa9b2b4), 0.55 * rain)
		haze_amt += 0.35 * rain
	sky_mat.set_shader_parameter("hemi_sky", hemi_sky)
	sky_mat.set_shader_parameter("hemi_ground", hemi_ground)
	sky_mat.set_shader_parameter("hemi_intensity", hemi_intensity * HEMI_K)
	RenderingServer.global_shader_parameter_set("paper_focus", center)
	var hl := haze.srgb_to_linear(); var hzl := hor.srgb_to_linear()
	RenderingServer.global_shader_parameter_set("paper_haze", Vector3(hl.r, hl.g, hl.b))
	RenderingServer.global_shader_parameter_set("paper_horizon", Vector3(hzl.r, hzl.g, hzl.b))
	RenderingServer.global_shader_parameter_set("paper_haze_amt", haze_amt)

func clock_text() -> String:
	var mins := floori(time * 24.0 * 60.0)
	return "Day %d · %02d:%02d" % [day, mins / 60, floori((mins % 60) / 10.0) * 10]
