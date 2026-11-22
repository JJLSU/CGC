class_name HoofDust
extends Node3D
## dust.js: riding hard on dry ground, Biscuit's hooves kick up little rounds of tan paper that puff out behind her,
## drift up a hand or two and shrink away. None in the wet (rain, the fen) and only at a lope or better.

const N := 28
const LIFE := 1.1

var mm := MultiMesh.new()
var p: Array = []
var next := 0
var acc := 0.0

func _init() -> void:
	var puff := PackedVector2Array()
	for i in 18: var a := i / 18.0 * TAU; var r := 0.4 + 0.1 * absf(sin(a * 2.5)); puff.append(Vector2(cos(a) * r, sin(a) * r * 0.8))
	mm.transform_format = MultiMesh.TRANSFORM_3D; mm.mesh = CardMesh.build(puff, 0.03); mm.instance_count = N; mm.visible_instance_count = 0
	var mi := MultiMeshInstance3D.new(); mi.multimesh = mm
	mi.material_override = PaperMats.card(null, {"albedo": Color.hex(0xcdb48aff), "snow": 0.0, "self_fill": 0.25})
	mi.custom_aabb = AABB(Vector3(-1e5, -100, -1e5), Vector3(2e5, 400, 2e5)); add_child(mi)
	for i in N: p.append({"age": LIFE, "x": 0.0, "y": 0.0, "z": 0.0, "vx": 0.0, "vz": 0.0, "s": 1.0, "spin": 0.0})

## pos/vel: the horse's; on: riding at a lope on dry ground.
func update(dt: float, pos: Vector3, vel: Vector3, on: bool, camera: Camera3D) -> void:
	var sp := Vector2(vel.x, vel.z).length()
	if on and sp > 4.0:
		acc += dt * minf(14.0, sp * 1.6) # (more puffs the harder she runs)
		while acc >= 1.0:
			acc -= 1.0
			var P: Dictionary = p[next]; next = (next + 1) % N
			var bx := pos.x - vel.x / sp * 0.9 + (randf() - 0.5) * 0.7; var bz := pos.z - vel.z / sp * 0.9 + (randf() - 0.5) * 0.7
			if Terrain.is_water(bx, bz): continue
			P.merge({"age": 0.0, "x": bx, "y": Terrain.get_height(bx, bz) + 0.15, "z": bz, "vx": -vel.x * 0.12 + (randf() - 0.5) * 0.6, "vz": -vel.z * 0.12 + (randf() - 0.5) * 0.6, "s": 0.35 + randf() * 0.3, "spin": randf() * 6.0}, true)
	else: acc = 0.0
	var cp := camera.global_position; var n := 0
	for P in p:
		if P.age >= LIFE: continue
		P.age += dt
		if P.age >= LIFE: continue
		var k: float = P.age / LIFE
		P.x += P.vx * dt; P.z += P.vz * dt; P.y += dt * 0.5 * (1.0 - k); P.vx *= 1.0 - dt * 2.0; P.vz *= 1.0 - dt * 2.0
		var s: float = P.s * (0.5 + k * 0.9) * (k / 0.12 if k < 0.12 else 1.0) * (1.0 - k * k) # (swell out, then shrink away)
		var b := Basis.from_euler(Vector3(-atan2(cp.y - P.y, Vector2(cp.x - P.x, cp.z - P.z).length()), atan2(cp.x - P.x, cp.z - P.z), P.spin + k), EULER_ORDER_YXZ)
		mm.set_instance_transform(n, Transform3D(b.scaled_local(Vector3.ONE * maxf(0.001, s)), Vector3(P.x, P.y, P.z))); n += 1
	mm.visible_instance_count = n
