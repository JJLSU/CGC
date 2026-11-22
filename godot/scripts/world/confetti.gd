class_name Confetti
extends Node3D
## particles.js: paper confetti and chips, one MultiMesh of up to 500 tiny fluttering card scraps (16 x 10 cm).
## burst(pos, colours, count, power): scraps fly up and out, flutter down (paper never drops faster than 1.8 m/s),
## settle on the ground and shrink away.

const MAX := 500
var mm: MultiMesh
var parts: Array = []
var next := 0
var ground_at: Callable

func _ready() -> void:
	var qm := QuadMesh.new(); qm.size = Vector2(0.16, 0.1)
	mm = MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.use_colors = true; mm.mesh = qm
	mm.instance_count = MAX
	for i in MAX: mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO)); mm.set_instance_color(i, Color.WHITE)
	var mmi := MultiMeshInstance3D.new(); mmi.multimesh = mm
	var mat := PaperMats.paper(Color.WHITE, false).duplicate() as ShaderMaterial
	mmi.material_override = mat
	mmi.custom_aabb = AABB(Vector3(-1e5, -100, -1e5), Vector3(2e5, 400, 2e5))
	add_child(mmi)
	parts.resize(MAX)

func burst(pos: Vector3, colors: Array, count := 20, power := 1.0) -> void:
	for n in count:
		var i := next; next = (next + 1) % MAX
		var a := randf() * TAU; var up := 2.0 + randf() * 4.0; var sp := (1.0 + randf() * 2.5) * power
		parts[i] = {"p": Vector3(pos.x + (randf() - 0.5) * 0.6, pos.y + randf() * 0.6, pos.z + (randf() - 0.5) * 0.6),
			"v": Vector3(cos(a) * sp, up * power, sin(a) * sp), "r": Vector3(randf() * 6, randf() * 6, randf() * 6),
			"w": Vector3((randf() - 0.5) * 14, (randf() - 0.5) * 14, (randf() - 0.5) * 14),
			"life": 1.6 + randf() * 1.2, "seed": randf() * 10.0, "s": 0.7 + randf() * 0.8}
		var c := Color.hex((int(colors[n % colors.size()]) << 8) | 0xff)
		c.v = clampf(c.v + (randf() - 0.5) * 0.1, 0.0, 1.0) # (three's offsetHSL on lightness, near enough)
		mm.set_instance_color(i, c.srgb_to_linear())

func update(dt: float) -> void:
	for i in MAX:
		var q = parts[i]
		if q == null: continue
		q.life -= dt
		if q.life <= 0.0:
			parts[i] = null; mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO)); continue
		q.v.y -= 9.0 * dt
		if q.v.y < -1.8: q.v.y = -1.8 # paper flutters, it doesn't drop
		q.v.x *= 1.0 - dt * 1.5; q.v.z *= 1.0 - dt * 1.5
		var t: float = Time.get_ticks_msec() * 0.001 + q.seed
		q.p.x += (q.v.x + sin(t * 5.0) * 0.6) * dt
		q.p.z += (q.v.z + cos(t * 4.0) * 0.6) * dt
		q.p.y += q.v.y * dt
		var g: float = (ground_at.call(q.p.x, q.p.z) if ground_at.is_valid() else Terrain.get_height(q.p.x, q.p.z)) + 0.03
		if q.p.y < g: q.p.y = g; q.v = Vector3.ZERO; q.w *= 0.8
		q.r += q.w * dt
		var s: float = q.s * minf(1.0, q.life * 2.0)
		mm.set_instance_transform(i, Transform3D(Basis.from_euler(q.r) * Basis.from_scale(Vector3.ONE * s), q.p))
