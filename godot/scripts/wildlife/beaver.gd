class_name Beaver
extends Node3D
## beaver.js: a beaver at home. Near the farmer, a paper beaver swims slow loops round its lodge, head and back just
## showing, a flat scaly tail trailing and a pale V of wake behind; now and then it slaps its tail (a plop) and dives,
## coming up again further round. Flat cards just above the water, built to read from above. Near lodges only.

var g := Node3D.new()
var wake: Array = []
var lodge = null
var a := 0.0
var R := 2.6
var dive := 0.0
var next := 18.0
var scan_t := 0.0
var on_slap: Callable

## cardGeometry(pts, t).rotateX(-PI/2): a card laid flat.
static func _flat(pts: Array, t := 0.03) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.append_from(CardMesh.build(PackedVector2Array(pts), t), 0, Transform3D(Basis(Vector3.RIGHT, -PI / 2.0), Vector3.ZERO))
	return st.commit()

func _m(mesh: ArrayMesh, hex: int, shadow := true) -> MeshInstance3D:
	var x := MeshInstance3D.new(); x.mesh = mesh; x.material_override = PaperMats.paper(Color.hex((hex << 8) | 0xff))
	x.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.add_child(x)
	return x

func _init() -> void:
	# nose toward +x: a plump brown back, a rounder head with little ears, a dark paddle of a tail
	_m(_flat([Vector2(0.32, 0), Vector2(0.24, 0.13), Vector2(0, 0.18), Vector2(-0.24, 0.15), Vector2(-0.34, 0), Vector2(-0.24, -0.15), Vector2(0, -0.18), Vector2(0.24, -0.13)]), 0x7a5232)
	_m(_flat([Vector2(0.5, 0), Vector2(0.44, 0.08), Vector2(0.36, 0.12), Vector2(0.3, 0.1), Vector2(0.3, -0.1), Vector2(0.36, -0.12), Vector2(0.44, -0.08)], 0.04), 0x6a4428).position.y = 0.02
	_m(_flat([Vector2(-0.3, 0.07), Vector2(-0.5, 0.11), Vector2(-0.66, 0.08), Vector2(-0.7, 0), Vector2(-0.66, -0.08), Vector2(-0.5, -0.11), Vector2(-0.3, -0.07)], 0.02), 0x3a2a20).position.y = -0.01
	# the wake: two pale streaks spreading back from the nose in a V
	var streak := _flat([Vector2(0, 0.012), Vector2(-1.4, 0.03), Vector2(-1.4, -0.03), Vector2(0, -0.012)], 0.005)
	for s in [1.0, -1.0]:
		var w := _m(streak, 0xe6ece6, false); w.position = Vector3(0.45, -0.02, 0); w.rotation.y = s * 0.42; wake.append(w)
	g.scale = Vector3.ONE * 1.35; g.visible = false
	add_child(g)

func update(dt: float, world: World, center: Vector3) -> void:
	# which lodge is ours: the nearest within 45 m of the farmer (looked up now and then)
	scan_t -= dt
	if scan_t <= 0.0:
		scan_t = 2.0
		var pool = world.pools.get("lodge")
		var best = null; var bd := 45.0 * 45.0
		if pool != null:
			for i in pool.count:
				var r = pool.owners[i]
				if r == null: continue
				var d: float = (r.x - center.x) ** 2 + (r.z - center.z) ** 2
				if d < bd: bd = d; best = r
		if (best == null) != (lodge == null) or (best != null and best.key != lodge.key): lodge = best; a = randf() * 6.28
	if lodge == null: g.visible = false; return
	g.visible = true
	# round and round the lodge, a slow paddle
	a += dt * (0.9 / R)
	var x: float = lodge.x + cos(a) * R; var z: float = lodge.z + sin(a) * R
	g.position = Vector3(x, 0.03, z)
	g.rotation.y = -a - PI # (facing along the circle, counter-clockwise)
	# the slap and dive, then up again further round
	next -= dt
	if next <= 0.0 and dive == 0.0:
		dive = 0.001
		if on_slap.is_valid(): on_slap.call()
	if dive > 0.0:
		dive += dt
		g.position.y = 0.03 - minf(1.0, dive / 0.6) * 0.6
		if dive > 0.6: g.visible = false
		if dive > 5.0: dive = 0.0; next = 20.0 + randf() * 25.0; a += 1.6
	if not Terrain.is_water(x, z) and dive == 0.0: g.visible = false # (round the far side of a small pond he swims under the bank)
	for w in wake: w.visible = dive == 0.0
