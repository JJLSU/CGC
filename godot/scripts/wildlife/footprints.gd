class_name Footprints
extends Node3D
## footprints.js: once the page is white over, the farmer's boots press a trail of little prints into the snow, left,
## right, a stride apart (round hoofprints, two by two, when riding), each a shallow blue-grey dent laid flat; they
## fill in over ~35 s, the oldest reused first. Old Blue leaves paw prints two by two. Nothing at all without snow.

const N := 90
const LIFE := 35.0

var mm := MultiMesh.new()
var paw_mm := MultiMesh.new()
var p: Array = []
var paws: Array = []
var next := 0
var paw_next := 0
var left := false
var last = null
var paw_last = null

func _init() -> void:
	# a boot sole: a rounded toe and a narrower heel
	var sole := PackedVector2Array()
	for i in 17: var a := i / 16.0 * PI; sole.append(Vector2(cos(a) * 0.075, 0.1 + sin(a) * 0.08))
	for i in 11: var a := PI + i / 10.0 * PI; sole.append(Vector2(cos(a) * 0.055, -0.08 + sin(a) * 0.05))
	var paw := PackedVector2Array()
	for i in 12: var a := i / 12.0 * TAU; paw.append(Vector2(cos(a) * 0.05, sin(a) * 0.055))
	# (not the paper stock: that whitens anything facing up when it snows, and these must stay a shadowed blue)
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color.hex(0x8494b4ff); mat.roughness = 1.0; mat.metallic_specular = 0.0
	for pair in [[mm, sole, 0.006, N], [paw_mm, paw, 0.005, 60]]:
		var m: MultiMesh = pair[0]
		m.transform_format = MultiMesh.TRANSFORM_3D; m.mesh = _flat(CardMesh.build(pair[1], pair[2])); m.instance_count = pair[3]; m.visible_instance_count = 0
		var mi := MultiMeshInstance3D.new(); mi.multimesh = m; mi.material_override = mat; mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.custom_aabb = AABB(Vector3(-1e5, -100, -1e5), Vector3(2e5, 400, 2e5)); add_child(mi)
	for i in N: p.append({"age": LIFE, "x": 0.0, "z": 0.0, "y": 0.0, "yaw": 0.0, "s": 1.0})
	for i in 60: paws.append({"age": LIFE, "x": 0.0, "z": 0.0, "y": 0.0, "yaw": 0.0, "s": 1.0})

## The card laid flat, face up, toe along -z (three's rotateX(-PI/2)).
static func _flat(mesh: ArrayMesh) -> ArrayMesh:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES); st.append_from(mesh, 0, Transform3D(Basis(Vector3.RIGHT, -PI / 2), Vector3.ZERO))
	return st.commit()

## Old Blue's tracks: a pair of paw prints every half stride.
func dog_track(snow: float, pos: Vector3) -> void:
	if snow < 0.5: paw_last = null; return
	if paw_last == null: paw_last = pos; return
	var dx: float = pos.x - paw_last.x; var dz: float = pos.z - paw_last.z; var step := sqrt(dx * dx + dz * dz)
	if step > 3.0: paw_last = pos; return
	if step < 0.45: return
	var yaw := atan2(dx, dz)
	for off in [-0.07, 0.07]:
		var x: float = pos.x + cos(yaw) * off; var z: float = pos.z - sin(yaw) * off
		if Terrain.is_water(x, z): continue
		paws[paw_next] = {"age": 0.0, "x": x, "z": z, "y": Terrain.get_height(x, z) + 0.02, "yaw": yaw, "s": 1.0}; paw_next = (paw_next + 1) % paws.size()
	paw_last = pos

## snow: 0..1 cover; pos: the farmer's feet; riding: hoofprints instead of boots.
func update(dt: float, snow: float, pos: Vector3, riding: bool) -> void:
	if snow < 0.5:
		if mm.visible_instance_count or paw_mm.visible_instance_count:
			for P in p + paws: P.age = LIFE
			mm.visible_instance_count = 0; paw_mm.visible_instance_count = 0
		last = null; return
	if last == null: last = pos
	var dx: float = pos.x - last.x; var dz: float = pos.z - last.z; var step := sqrt(dx * dx + dz * dz)
	if step > 3.0: last = pos # (a jump in position: no trail across it)
	elif step > (0.9 if riding else 0.62):
		var yaw := atan2(dx, dz); var side := 1.0 if left else -1.0; left = not left
		for k in (2 if riding else 1):
			var off := (0.22 * (1.0 if k else -1.0)) if riding else 0.13 * side
			var x := pos.x + cos(yaw) * off; var z := pos.z - sin(yaw) * off
			if Terrain.is_water(x, z): continue
			p[next] = {"age": 0.0, "x": x, "z": z, "y": Terrain.get_height(x, z) + 0.02, "yaw": yaw + PI, "s": 1.6 if riding else 1.35}; next = (next + 1) % N
		last = pos
	for pair in [[p, mm, true], [paws, paw_mm, false]]:
		var c := 0
		for P in pair[0]:
			if P.age >= LIFE: continue
			P.age += dt
			if P.age >= LIFE: continue
			var k: float = P.age / LIFE; var s: float = (P.s if pair[2] else 1.0) * (1.0 if k < 0.7 else 1.0 - (k - 0.7) / 0.3) # (filling in towards the end)
			(pair[1] as MultiMesh).set_instance_transform(c, Transform3D(Basis(Vector3.UP, P.yaw).scaled(Vector3(s, 1, s)), Vector3(P.x, P.y, P.z))); c += 1
		(pair[1] as MultiMesh).visible_instance_count = c
