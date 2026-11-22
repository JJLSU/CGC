class_name ModelBake
## Little helpers the wildlife shares: a reference-art prop model baked into one mesh for a MultiMesh (the web's
## "first mesh, applyMatrix4(matrixWorld), rotateY, fit to a length, feet at 0"), a still model seated in a holder,
## and a card laid flat (cardGeometry(pts, t).rotateX(-PI/2)).

## [mesh, material]: the model's first mesh in model space, turned rot_y, centred, feet at y 0, `length` long in x.
static func baked(path: String, length: float, rot_y := PI / 2.0) -> Array:
	var src := (load(path) as PackedScene).instantiate() as Node3D
	var mesh: ArrayMesh; var mat: Material
	for node in src.find_children("*", "MeshInstance3D", true, false):
		var m := node as MeshInstance3D
		var xf := Transform3D()
		var n: Node = m
		while n != null and n != src:
			if n is Node3D: xf = (n as Node3D).transform * xf
			n = n.get_parent()
		var st := SurfaceTool.new(); st.append_from(m.mesh, 0, Transform3D(Basis(Vector3.UP, rot_y), Vector3.ZERO) * xf)
		mesh = st.commit()
		var sm := m.get_active_material(0) as BaseMaterial3D
		mat = PaperMats.card(sm.albedo_texture, {"albedo": sm.albedo_color, "snow": 0.0}) if sm and sm.albedo_texture else PaperMats.paper(sm.albedo_color if sm else Color.GRAY, false)
		break
	src.free()
	var b := mesh.get_aabb(); var k := length / b.size.x
	var st2 := SurfaceTool.new()
	st2.append_from(mesh, 0, Transform3D(Basis.from_scale(Vector3.ONE * k), Vector3.ZERO) * Transform3D(Basis(), -Vector3(b.position.x + b.size.x / 2.0, b.position.y, b.position.z + b.size.z / 2.0)))
	return [st2.commit(), mat]

## A still copy of the model, printed on card, centred with its feet at 0; scale k = size / its extent along axis.
static func still(path: String, size: float, axis := 1) -> Node3D:
	var m := (load(path) as PackedScene).instantiate() as Node3D
	PaperMats.paperize(m, false)
	var bb := PaperMats._aabb(m, Transform3D.IDENTITY)
	var hold := Node3D.new()
	m.position = Vector3(-(bb.position.x + bb.size.x * 0.5), -bb.position.y, -(bb.position.z + bb.size.z * 0.5))
	hold.add_child(m)
	hold.scale = Vector3.ONE * (size / bb.size[axis])
	return hold

## A card laid flat on its back, as three's cardGeometry(pts, t).rotateX(-PI/2) (+ a lift).
static func flat(pts: Array, t := 0.02, lift := 0.0) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.append_from(CardMesh.build(PackedVector2Array(pts), t), 0, Transform3D(Basis(Vector3.RIGHT, -PI / 2.0), Vector3(0, lift, 0)))
	return st.commit()

static func pts(a: Array) -> Array:
	var out := []
	for q in a: out.append(Vector2(q[0], q[1]))
	return out

static func mesh_node(mesh: Mesh, mat: Material, shadow := true) -> MeshInstance3D:
	var x := MeshInstance3D.new(); x.mesh = mesh; x.material_override = mat
	x.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return x

static func paper(hex: int) -> Material: return PaperMats.paper(Color.hex((hex << 8) | 0xff))
