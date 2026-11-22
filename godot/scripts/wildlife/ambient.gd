class_name Ambient
extends Node3D
## ambient.js: printed autumn leaves fluttering down by day (fewer at night), fireflies after dusk. Each a single
## MultiMesh updated on the CPU. firefly_near / catch_firefly feed the jar.

const LEAVES := 70
const FLIES := 60
const LEAF_COLS := [0xe08a3a, 0xc8552f, 0xd9a441, 0xb8452e, 0xe6b45a]

var rng := PNoise.Mulberry32.new(31337)
var leaves := MultiMesh.new()
var flies := MultiMesh.new()
var leaf_state: Array = []
var fly_state: Array = []
var fly_home_t := 0.0
var time := 0.0
var glow := 0.0
var fly_mat: ShaderMaterial

static func leaf_points() -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 12: # (three's 13th point closes the loop on the first)
		var t := (i / 12.0) * TAU
		pts.append(Vector2(cos(t) * 0.09, 0.13 + sin(t) * 0.13 * (1.0 - 0.35 * cos(t))))
	return pts

func _init() -> void:
	leaves.transform_format = MultiMesh.TRANSFORM_3D; leaves.use_colors = true
	leaves.mesh = CardMesh.build(leaf_points(), 0.01); leaves.instance_count = LEAVES
	for i in LEAVES:
		leaves.set_instance_color(i, Color.hex((LEAF_COLS[i % LEAF_COLS.size()] << 8) | 0xff).srgb_to_linear())
		leaf_state.append({"p": Vector3.ZERO, "v": Vector3.ZERO, "rot": Vector3.ZERO, "w": Vector3.ZERO, "seed": rng.next() * 10.0, "alive": false, "ground": 0.0})
	var lmi := MultiMeshInstance3D.new(); lmi.multimesh = leaves
	lmi.material_override = PaperMats.card(load("res://assets/baked/wildlife/leaf.png"), {"flip": true, "snow": 0.0})
	lmi.custom_aabb = AABB(Vector3(-1e5, -100, -1e5), Vector3(2e5, 400, 2e5))
	add_child(lmi)
	# fireflies: tiny glowing beads
	var ico := SphereMesh.new(); ico.radius = 0.035; ico.height = 0.07; ico.radial_segments = 6; ico.rings = 3
	flies.transform_format = MultiMesh.TRANSFORM_3D; flies.mesh = ico; flies.instance_count = FLIES
	for i in FLIES: fly_state.append({"home": Vector3.ZERO, "pos": Vector3.ZERO, "seed": rng.next() * 100.0})
	fly_mat = ShaderMaterial.new(); fly_mat.shader = Shader.new()
	fly_mat.shader.code = "shader_type spatial;\nrender_mode unshaded, shadows_disabled;\nuniform float glow = 0.0;\nvoid fragment() { ALBEDO = vec3(2.4, 2.1, 0.7) * glow; }\n"
	var fmi := MultiMeshInstance3D.new(); fmi.multimesh = flies; fmi.material_override = fly_mat
	fmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fmi.custom_aabb = lmi.custom_aabb
	add_child(fmi)

## The nearest glowing firefly within r of pos (and not far overhead), or -1.
func firefly_near(pos: Vector3, r := 1.7) -> int:
	if glow < 0.3: return -1
	var best := -1; var bd := r * r
	for i in FLIES:
		var f: Dictionary = fly_state[i]
		var d: float = (f.pos.x - pos.x) ** 2 + (f.pos.z - pos.z) ** 2
		if d < bd and f.pos.y - pos.y < 2.6: bd = d; best = i
	return best

## Caught: into the jar, and a fresh one wanders in somewhere off in the dark.
func catch_firefly(i: int) -> void:
	var f: Dictionary = fly_state[i]
	var a := rng.next() * TAU; var d := 10.0 + rng.next() * 12.0
	var fx: float = f.home.x + cos(a) * d; var fz: float = f.home.z + sin(a) * d
	f.home = Vector3(fx, Terrain.get_height(fx, fz) + 0.5 + rng.next() * 1.6, fz)
	f.pos = Vector3(1e6, 0, 1e6)

func _respawn_leaf(s: Dictionary, center: Vector3, anywhere: bool) -> void:
	var a := rng.next() * TAU; var d := 3.0 + rng.next() * 22.0
	var base := Terrain.get_height(center.x, center.z)
	var y := base + (rng.next() * 9.0 if anywhere else 7.0 + rng.next() * 3.0)
	s.p = Vector3(center.x + cos(a) * d, y, center.z + sin(a) * d)
	s.v = Vector3((rng.next() - 0.5) * 0.6, -0.4 - rng.next() * 0.5, (rng.next() - 0.5) * 0.6)
	s.rot = Vector3(rng.next() * 6, rng.next() * 6, rng.next() * 6)
	s.w = Vector3((rng.next() - 0.5) * 5, (rng.next() - 0.5) * 5, (rng.next() - 0.5) * 5)
	s.alive = true
	s.ground = Terrain.get_height(s.p.x, s.p.z) + 0.02

func update(dt: float, center: Vector3, night: float, wind := 0.6) -> void:
	time += dt
	var t := time
	var zero := Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO)
	var active := roundi(LEAVES * (1.0 - 0.7 * night))
	for i in LEAVES:
		var s: Dictionary = leaf_state[i]
		if i >= active: leaves.set_instance_transform(i, zero); s.alive = false; continue
		if not s.alive or s.p.y < s.ground or absf(s.p.x - center.x) > 30.0 or absf(s.p.z - center.z) > 30.0: _respawn_leaf(s, center, not s.alive)
		# flutter: side-to-side sway and a steady drift with the wind
		var p: Vector3 = s.p
		p.x += (s.v.x + sin(t * 2.1 + s.seed) * 0.7 + wind * 0.5) * dt
		p.z += (s.v.z + cos(t * 1.7 + s.seed) * 0.5) * dt
		p.y += s.v.y * dt * (0.8 + 0.4 * sin(t * 3.0 + s.seed))
		s.p = p
		s.rot += s.w * dt
		leaves.set_instance_transform(i, Transform3D(Basis.from_euler(s.rot, EULER_ORDER_XYZ), p))
	# fireflies: slow loops near the ground, blinking; only after dusk
	glow = smoothstep(0.45, 0.85, night)
	fly_mat.set_shader_parameter("glow", glow)
	fly_home_t -= dt
	if fly_home_t <= 0.0:
		fly_home_t = 4.0
		for f in fly_state:
			if f.home.distance_squared_to(center) > 26.0 * 26.0 or f.home.length_squared() == 0.0:
				var a := rng.next() * TAU; var d := 3.0 + rng.next() * 20.0
				var fx := center.x + cos(a) * d; var fz := center.z + sin(a) * d
				f.home = Vector3(fx, Terrain.get_height(fx, fz) + 0.5 + rng.next() * 1.6, fz)
	var on := glow > 0.01
	for i in FLIES:
		var f: Dictionary = fly_state[i]
		if not on: flies.set_instance_transform(i, zero); continue
		var k: float = f.seed
		var p := Vector3(f.home.x + sin(t * 0.4 + k) * 1.4, f.home.y + sin(t * 0.9 + k * 2.0) * 0.35, f.home.z + cos(t * 0.33 + k) * 1.4)
		f.pos = p
		var blink := maxf(0.0, sin(t * (1.3 + fmod(k, 1.0)) + k * 7.0))
		flies.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * (0.4 + blink * 0.9)), p))
