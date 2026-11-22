class_name NightSky
extends Node3D
## nightsky.js: the night sky of a pop-up book. Seventy die-cut paper stars (prints baked from the web) and a paper
## crescent moon with a dozing man-in-the-moon (a full moon, pumpkin-gold and low, on harvest nights). At dusk they
## turn in on their creases one by one from edge-on to facing you, with a quiver; at dawn they turn away. They hang
## far out on the sky (380 m), follow the camera like the dome and only exist after dark.

const N := 70
const R := 380.0
var glow := 1.15
var stars: MultiMesh
var list: Array = []
var moon: MeshInstance3D
var full_moon: MeshInstance3D
var moon_mat: ShaderMaterial
var full_mat: ShaderMaterial
var t := 0.0
var clock := 0.0
var harvest := false

static func star_shape(points := 5, r0 := 0.42, r1 := 1.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in points * 2:
		var a := PI / 2.0 + (k * PI) / points; var r := r0 if k % 2 else r1
		pts.append(Vector2(cos(a) * r, sin(a) * r))
	return pts

static func crescent_shape() -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in 25:
		var a := PI * 0.32 + (k / 24.0) * PI * 1.36; pts.append(Vector2(cos(a), sin(a)))
	for k in range(24, -1, -1):
		var a := PI * 0.42 + (k / 24.0) * PI * 1.16; pts.append(Vector2(0.42 + cos(a) * 0.82, sin(a) * 0.82))
	return pts

func _glow_mat(tex: String) -> ShaderMaterial:
	var m := ShaderMaterial.new(); m.shader = preload("res://shaders/glow_card.gdshader")
	m.set_shader_parameter("map", load(tex)); m.set_shader_parameter("glow", glow)
	return m

func _ready() -> void:
	stars = MultiMesh.new()
	stars.transform_format = MultiMesh.TRANSFORM_3D
	stars.use_colors = true
	stars.mesh = CardMesh.build(star_shape(), 0.06)
	stars.instance_count = N
	stars.visible_instance_count = 0
	var smi := MultiMeshInstance3D.new(); smi.multimesh = stars
	smi.material_override = _glow_mat("res://assets/baked/sky/star.png")
	smi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	smi.custom_aabb = AABB(Vector3(-1e5, -1e5, -1e5), Vector3(2e5, 2e5, 2e5))
	add_child(smi)
	var rng := PNoise.Mulberry32.new(919)
	for i in N:
		var az := rng.next() * PI * 2.0; var el := deg_to_rad(14.0 + pow(rng.next(), 0.8) * 66.0)
		stars.set_instance_color(i, _hsl(0.12, 0.5, 0.82 + rng.next() * 0.18))
		list.append({"dir": Vector3(cos(el) * cos(az), sin(el), cos(el) * sin(az)), "size": 2.6 + rng.next() * 3.6, "delay": rng.next() * 2.5, "spin": rng.next() * 6.28, "ph": rng.next() * 6.28})
	moon_mat = _glow_mat("res://assets/baked/sky/moon.png")
	moon = MeshInstance3D.new(); moon.mesh = CardMesh.build(crescent_shape(), 0.05); moon.material_override = moon_mat
	full_mat = _glow_mat("res://assets/baked/sky/fullmoon.png")
	var disc := PackedVector2Array()
	for i in 32: disc.append(Vector2(cos(i / 32.0 * PI * 2.0), sin(i / 32.0 * PI * 2.0)))
	full_moon = MeshInstance3D.new(); full_moon.mesh = CardMesh.build(disc, 0.05); full_moon.material_override = full_mat
	for m in [moon, full_moon]:
		m.visible = false; m.extra_cull_margin = 1e4; m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(m)

## three's Color.setHSL (in its linear working space: the instance colour multiplies the print as is).
static func _hsl(h: float, s: float, l: float) -> Color:
	var q := l * (1.0 + s) if l <= 0.5 else l + s - l * s
	var p := 2.0 * l - q
	var f := func(t: float) -> float:
		if t < 0.0: t += 1.0
		if t > 1.0: t -= 1.0
		if t < 1.0 / 6.0: return p + (q - p) * 6.0 * t
		if t < 0.5: return q
		if t < 2.0 / 3.0: return p + (q - p) * 6.0 * (2.0 / 3.0 - t)
		return p
	return Color(f.call(h + 1.0 / 3.0), f.call(h), f.call(h - 1.0 / 3.0))

## A transform that faces the camera from p (three's Matrix4.lookAt(eye=cam, target=p): +z toward the camera).
static func _face(cam: Vector3, p: Vector3) -> Basis:
	var z := (cam - p).normalized()
	var x := Vector3.UP.cross(z).normalized()
	var y := z.cross(x)
	return Basis(x, y, z)

func update(dt: float, camera: Camera3D, sun_dir: Vector3, night: float, is_harvest := false) -> void:
	harvest = is_harvest
	clock += dt
	var on := night > 0.6
	t = minf(t + dt, 6.0) if on else maxf(t - dt * 1.5, 0.0)
	if t <= 0.0:
		stars.visible_instance_count = 0; moon.visible = false; full_moon.visible = false
		return
	var cam := camera.global_position
	var n := 0
	for i in N:
		var s: Dictionary = list[i]
		var k := Props.spring_rise(maxf(0.0, t - s.delay) * 1.1)
		if k <= 0.001: continue
		var p: Vector3 = s.dir * R + cam
		var b := _face(cam, p) * Basis(Vector3.UP, (1.0 - k) * (PI / 2.0)) * Basis(Vector3.BACK, s.spin + sin(clock * 0.6 + s.ph) * 0.06)
		stars.set_instance_transform(n, Transform3D(b.scaled_local(Vector3.ONE * s.size), p))
		n += 1
	stars.visible_instance_count = n
	# the moon rides opposite the sun, when it's up (low and pumpkin-gold on a harvest night)
	var md := -sun_dir
	if harvest:
		md.y = maxf(md.y, 0.08) * 0.35 + 0.06; md = md.normalized()
	var tint := Vector3(1.15, 0.78, 0.45) if harvest else Vector3.ONE
	moon_mat.set_shader_parameter("tint", tint); full_mat.set_shader_parameter("tint", tint)
	moon.visible = md.y > -0.03
	if moon.visible:
		var k := Props.spring_rise(t * 0.9)
		var p := md * R * 0.98 + cam
		moon.position = p
		moon.basis = (_face(cam, p) * Basis(Vector3.UP, (1.0 - k) * (PI / 2.0)) * Basis(Vector3.BACK, -0.35)).scaled_local(Vector3.ONE * 21.0)
	full_moon.visible = moon.visible and harvest
	if full_moon.visible:
		full_moon.position = moon.position
		full_moon.basis = moon.basis.orthonormalized().scaled_local(Vector3.ONE * 24.0)
		moon.visible = false
