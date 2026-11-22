class_name Wake
extends Node3D
## wake.js: flat cream paper rings spreading on the water (from the farmer's shins with every wading step, a slow
## one now and then while he stands in it; the ducks' wake; corn tossed on the water). Six rings, round-robin.

const N := 6
const LIFE := 1.6

var rings: Array = []
var idle := 0.0

## A flat ring in the xz plane (three's RingGeometry(inner, outer, seg).rotateX(-PI/2)), seen from both sides.
static func ring_mesh(inner: float, outer: float, seg: int) -> ArrayMesh:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in seg:
		var a0 := TAU * i / seg; var a1 := TAU * (i + 1) / seg
		var p := [Vector3(cos(a0) * inner, 0, sin(a0) * inner), Vector3(cos(a0) * outer, 0, sin(a0) * outer), Vector3(cos(a1) * inner, 0, sin(a1) * inner), Vector3(cos(a1) * outer, 0, sin(a1) * outer)]
		for v in [p[0], p[1], p[2], p[2], p[1], p[3]]:
			st.set_normal(Vector3.UP); st.add_vertex(v)
	return st.commit()

static func flat_mat(color: Color, alpha: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; m.albedo_color = Color(color, alpha)
	m.render_priority = 2
	return m

func _init() -> void:
	var mesh := ring_mesh(0.86, 1.0, 32)
	for i in N:
		var mi := MeshInstance3D.new(); mi.mesh = mesh; mi.material_override = flat_mat(Color.hex(0xf3ead6ff), 0.0)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; mi.visible = false
		add_child(mi)
		rings.append({"m": mi, "t": 9.0, "size": 1.0})

func ring(x: float, z: float, size := 1.0) -> void:
	var r: Dictionary = rings[0]
	for q in rings: if q.t > r.t: r = q
	r.t = 0.0; r.size = size; r.m.position = Vector3(x, 0.035, z); r.m.visible = true

## wading: is he in the water; moving: his speed (m/s).
func update(dt: float, pos: Vector3, wading: bool, moving: float) -> void:
	if wading and moving < 0.3:
		idle -= dt
		if idle <= 0.0: idle = 1.4 + randf() * 0.8; ring(pos.x, pos.z, 0.7)
	for r in rings:
		if r.t > LIFE: r.m.visible = false; continue
		r.t += dt
		var k: float = r.t / LIFE
		r.m.scale = Vector3.ONE * (0.3 + k * 1.3) * r.size
		(r.m.material_override as StandardMaterial3D).albedo_color.a = 0.75 * (1.0 - k) * (1.0 - k)
