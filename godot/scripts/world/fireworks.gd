class_name Fireworks
extends Node3D
## fireworks.js: once all three streets are mended, every Saturday evening rockets go up one after another from the
## field behind the church, trailing a few sparks, and burst into rounds of little cut-paper stars (red, cream, gold,
## blue, pink) that open out, hang a moment and drift down shrinking away. One MultiMesh of 240 stars, lit by their own
## colour, only while the show is on.

const MAX := 240
const STAR := 30
const COLORS := [0xff6a4a, 0xfff0c8, 0xffc848, 0x7ab0ff, 0xff8ac0]

var mm := MultiMesh.new()
var p: Array = []
var next := 0
var wait := 0.0
var rockets: Array = []

func _init() -> void:
	var star := PackedVector2Array()
	for i in 10:
		var a := (i / 10.0) * TAU + PI / 2.0; var r := 0.45 if i % 2 else 1.0
		star.append(Vector2(cos(a) * r, sin(a) * r))
	mm.transform_format = MultiMesh.TRANSFORM_3D; mm.use_colors = true; mm.mesh = CardMesh.build(star, 0.04); mm.instance_count = MAX; mm.visible_instance_count = 0
	var mi := MultiMeshInstance3D.new(); mi.multimesh = mm
	var m := StandardMaterial3D.new(); m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; m.cull_mode = BaseMaterial3D.CULL_DISABLED; m.vertex_color_use_as_albedo = true
	mi.material_override = m; mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(Vector3(-1e5, -100, -1e5), Vector3(2e5, 400, 2e5)); add_child(mi)
	for i in MAX: p.append({"age": 9.0, "life": 1.0, "pos": Vector3.ZERO, "vel": Vector3.ZERO, "s": 0.2, "spin": 0.0, "col": 0})

func _spawn(o: Dictionary) -> void:
	p[next].merge(o, true); next = (next + 1) % MAX

## on: the show is running; at: where rockets go up from; on_pop(pos) for the bang.
func update(dt: float, on: bool, at: Vector3, camera: Camera3D, on_pop := Callable()) -> void:
	if on:
		wait -= dt
		if wait <= 0.0:
			wait = 1.4 + randf() * 1.6
			rockets.append({"pos": Vector3(at.x + (randf() - 0.5) * 8.0, at.y, at.z + (randf() - 0.5) * 8.0), "vy": 16.0 + randf() * 4.0, "t": 0.0, "fuse": 1.4 + randf() * 0.5, "col": COLORS[randi() % COLORS.size()]})
	for i in range(rockets.size() - 1, -1, -1):
		var R: Dictionary = rockets[i]
		R.t += dt; R.vy -= 6.0 * dt; R.pos.y += R.vy * dt
		if randf() < dt * 14.0: _spawn({"age": 0.0, "life": 0.5, "pos": R.pos, "vel": Vector3((randf() - 0.5) * 0.6, -1.0, (randf() - 0.5) * 0.6), "s": 0.12, "spin": randf() * 6.0, "col": 0xffd890}) # (its trail)
		if R.t >= R.fuse: # burst: a ring of stars thrown out on a sphere
			var sp := 7.0 + randf() * 3.0
			for k in STAR:
				var u := randf() * 2.0 - 1.0; var a := randf() * TAU; var r := sqrt(1.0 - u * u)
				_spawn({"age": 0.0, "life": 2.0 + randf() * 0.8, "pos": R.pos, "vel": Vector3(cos(a) * r * sp, u * sp, sin(a) * r * sp), "s": 0.45 + randf() * 0.15, "spin": randf() * 6.0, "col": 0xfff0c8 if randf() < 0.2 else R.col})
			if on_pop.is_valid(): on_pop.call(R.pos)
			rockets.remove_at(i)
	var n := 0
	var cam := camera.global_position
	for P in p:
		if P.age >= P.life: continue
		P.age += dt
		if P.age >= P.life: continue
		var drag := maxf(0.0, 1.0 - dt * 2.2) # (they open fast, then hang and drift down)
		var v: Vector3 = P.vel; v.x *= drag; v.z *= drag; v.y = v.y * drag - 2.4 * dt; P.vel = v
		P.pos += v * dt
		var k: float = P.age / P.life; var s: float = P.s * (k / 0.08 if k < 0.08 else 1.0) * (1.0 - k * k)
		var pp: Vector3 = P.pos
		var basis := Basis.from_euler(Vector3(-atan2(cam.y - pp.y, Vector2(cam.x - pp.x, cam.z - pp.z).length()), atan2(cam.x - pp.x, cam.z - pp.z), P.spin + P.age * 3.0), EULER_ORDER_YXZ)
		mm.set_instance_transform(n, Transform3D(basis.scaled_local(Vector3.ONE * maxf(0.001, s)), pp))
		mm.set_instance_color(n, Color.hex((P.col << 8) | 0xff).srgb_to_linear() * 1.6); n += 1
	mm.visible_instance_count = n
