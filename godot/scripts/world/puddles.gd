class_name Puddles
extends Node3D
## puddles.js: rain on the ground. While a shower lasts, torn-paper puddles gather on the gentler stretches of the
## footpaths near the farmer, flush with the ground (never on a hillside), and dry away over a few minutes after.
## On ponds (and in the puddles) little rings of rain open and spread all round you.

const PUDDLES := 18
const RINGS := 40
var pmm: MultiMesh
var rmm: MultiMesh
var pmat: ShaderMaterial
var spots: Array = []
var anchor := Vector3(1e9, 0, 0)
var drops: Array = []
var level := 0.0

func _ready() -> void:
	pmat = ShaderMaterial.new(); pmat.shader = preload("res://shaders/sheet.gdshader")
	pmat.set_shader_parameter("map", load("res://assets/baked/sky/puddle.png"))
	pmat.render_priority = 1
	var pm := PlaneMesh.new(); pm.size = Vector2(1, 1)
	pmm = _pool(pm, pmat, PUDDLES)
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; rm.albedo_color = Color(Color.hex(0xdfe8e6ff), 0.5)
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; rm.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	rm.cull_mode = BaseMaterial3D.CULL_DISABLED
	rmm = _pool(_ring_mesh(0.88, 1.0, 20), rm, RINGS)
	for i in RINGS: drops.append({"x": 0.0, "y": 0.0, "z": 0.0, "t": 1.0 + randf()})

func _pool(mesh: Mesh, mat: Material, n: int) -> MultiMesh:
	var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.mesh = mesh
	mm.instance_count = n; mm.visible_instance_count = 0
	var mmi := MultiMeshInstance3D.new(); mmi.multimesh = mm; mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.custom_aabb = AABB(Vector3(-1e5, -100, -1e5), Vector3(2e5, 400, 2e5))
	add_child(mmi)
	return mm

static func _ring_mesh(r0: float, r1: float, seg: int) -> ArrayMesh:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in seg:
		var a0 := TAU * i / seg; var a1 := TAU * (i + 1) / seg
		var p := [Vector3(cos(a0) * r0, 0, sin(a0) * r0), Vector3(cos(a0) * r1, 0, sin(a0) * r1), Vector3(cos(a1) * r1, 0, sin(a1) * r1), Vector3(cos(a1) * r0, 0, sin(a1) * r0)]
		for k in [0, 1, 2, 0, 2, 3]: st.set_normal(Vector3.UP); st.add_vertex(p[k])
	return st.commit()

## Find puddle spots on the footpaths round the farmer (again when he wanders off).
func place(center: Vector3) -> void:
	anchor = center; spots = []
	var rng := PNoise.Mulberry32.new((floori(center.x / 10.0) * 7919) ^ floori(center.z / 10.0))
	var tries := 0
	while tries < 400 and spots.size() < PUDDLES:
		tries += 1
		var a := rng.next() * PI * 2.0; var d := 3.0 + rng.next() * 26.0
		var x := center.x + cos(a) * d; var z := center.z + sin(a) * d
		if Terrain.is_water(x, z) or Terrain.path_field(x, z) > 0.06: continue
		var close := false
		for s in spots:
			if Vector2(s.x - x, s.z - z).length() < 2.5: close = true; break
		if close: continue
		var w := 1.2 + rng.next() * 1.6; var dd := 0.7 + rng.next() * 0.8; var rot := rng.next() * PI
		var cs := cos(rot); var sn := sin(rot); var y0 := Terrain.get_height(x, z); var e := 0.5
		var gx := (Terrain.get_height(x + e, z) - Terrain.get_height(x - e, z)) / (2.0 * e)
		var gz := (Terrain.get_height(x, z + e) - Terrain.get_height(x, z - e)) / (2.0 * e)
		if Vector2(gx, gz).length() > 0.2: continue
		var bend := 0.0
		for uv in [[0.5, 0], [-0.5, 0], [0, 0.5], [0, -0.5], [0.35, 0.35], [-0.35, 0.35], [0.35, -0.35], [-0.35, -0.35]]:
			var lx: float = uv[0] * w; var lz: float = uv[1] * dd
			var px := x + lx * cs + lz * sn; var pz := z - lx * sn + lz * cs
			bend = maxf(bend, absf(Terrain.get_height(px, pz) - (y0 + gx * (px - x) + gz * (pz - z))))
		if bend > 0.035: continue
		var n := Vector3(-gx, 1, -gz).normalized()
		var q := Basis(Quaternion(Vector3.UP, n)) * Basis(Vector3.UP, rot)
		spots.append({"x": x, "z": z, "y": y0 + 0.025, "w": w, "d": dd, "rot": rot, "q": q})

func update(dt: float, center: Vector3, rain: float, snowing: bool) -> void:
	var target := 1.0 if rain > 0.3 and not snowing else 0.0
	level += (target - level) * minf(1.0, dt * (0.03 if target > 0.0 else 0.012))
	if level < 0.01 and rain < 0.05:
		pmm.visible_instance_count = 0; rmm.visible_instance_count = 0
		return
	if anchor.distance_squared_to(center) > 18.0 * 18.0: place(center)
	pmat.set_shader_parameter("opacity", minf(1.0, level * 1.2))
	var n := 0
	for s in spots:
		var k := 0.6 + 0.4 * level # they spread a little as they fill
		pmm.set_instance_transform(n, Transform3D(s.q * Basis.from_scale(Vector3(s.w * k, 1, s.d * k)), Vector3(s.x, s.y, s.z)))
		n += 1
	pmm.visible_instance_count = n
	var r := 0
	if rain > 0.2 and not snowing:
		for d in drops:
			d.t += dt * 1.6
			if d.t >= 1.0:
				d.t = randf() * 0.2
				if randf() < 0.35 and spots.size():
					var s: Dictionary = spots[randi() % spots.size()]
					d.x = s.x + (randf() - 0.5) * s.w * 0.6; d.z = s.z + (randf() - 0.5) * s.d * 0.6; d.y = s.y + 0.01
				else:
					var a := randf() * PI * 2.0; var dd := 2.0 + randf() * 20.0
					d.x = center.x + cos(a) * dd; d.z = center.z + sin(a) * dd
					if not Terrain.is_water(d.x, d.z): d.t = 1.0; continue
					d.y = Terrain.get_height(d.x, d.z) + 0.05
			var sc: float = 0.05 + d.t * 0.35
			rmm.set_instance_transform(r, Transform3D(Basis.from_scale(Vector3(sc, 1, sc)), Vector3(d.x, d.y, d.z)))
			r += 1
	rmm.visible_instance_count = r
