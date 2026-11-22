class_name Fair
extends Node3D
## fair.js: the County Fair. Every seventh day (Day 7, 14, 21...) from 07:00 till 19:00 a judging table goes up the
## street before the church: a trestle with a gingham cloth under strings of red, cream and blue bunting, a
## hand-lettered sign, and the judge herself, Mrs. Pruitt, with a clipboard. It hinges up that morning and folds away
## at dusk. E at the table enters the classes (the crafting panel's County Fair tier); each class takes one entry
## per fair and pays a prize and a ribbon. Every ribbon won is pinned as a rosette along the farmhouse porch beam.

const ROSETTE := [[0.05, 0], [0.09, 0.2], [0.03, 0.22], [0.0446, 0.1979], [0.0997, 0.2013], [0.1126, 0.2551], [0.1527, 0.2932], [0.128, 0.3426], [0.1342, 0.3975], [0.0835, 0.4196], [0.053, 0.4657], [0, 0.45], [-0.053, 0.4657], [-0.0835, 0.4196], [-0.1342, 0.3975], [-0.128, 0.3426], [-0.1527, 0.2932], [-0.1126, 0.2551], [-0.0997, 0.2013], [-0.0446, 0.1979], [-0.03, 0.22], [-0.09, 0.2], [-0.05, 0], [0, 0.06]]

static func is_fair_day(day: int) -> bool: return day % 7 == 0

var at: Vector3
var hinge := Node3D.new()
var judge: ModelFigure
var up := 0.0
var t := 0.0
var shown := false
var rosettes: Array = []
var entered := {}
var entered_day := 0

func _init(world: World, house: Dictionary, spot: Dictionary) -> void:
	var x: float = spot.x; var z: float = spot.z; var look: Vector3 = spot.look
	at = Vector3(x, Terrain.get_height(x, z), z)
	world.exclusions.append({"x": x, "z": z, "r": 5.0})
	position = at; rotation.y = atan2(look.x - x, look.z - z) # (the front of the table down the street)
	add_child(hinge)
	# the trestle: two X legs and a plank top's rails
	var R := Vector3.RIGHT
	hinge.add_child(_boxes([[Vector3(0.07, 1.0, 0.07), Transform3D(Basis(R, 0.45), Vector3(-0.9, 0.42, 0))], [Vector3(0.07, 1.0, 0.07), Transform3D(Basis(R, -0.45), Vector3(-0.9, 0.42, 0))],
		[Vector3(0.07, 1.0, 0.07), Transform3D(Basis(R, 0.45), Vector3(0.9, 0.42, 0))], [Vector3(0.07, 1.0, 0.07), Transform3D(Basis(R, -0.45), Vector3(0.9, 0.42, 0))],
		[Vector3(0.06, 0.06, 0.7), Transform3D(Basis(), Vector3(-0.9, 0.3, 0))], [Vector3(0.06, 0.06, 0.7), Transform3D(Basis(), Vector3(0.9, 0.3, 0))]], PaperMats.paper(Color.hex(0x5a3e2aff))))
	# a red-and-cream gingham cloth hanging over the top
	var gm := StandardMaterial3D.new(); gm.albedo_texture = load("res://assets/baked/homestead/gingham.png")
	gm.uv1_triplanar = true; gm.uv1_scale = Vector3.ONE * 1.3; gm.roughness = 1.0; gm.metallic_specular = 0.0
	hinge.add_child(_boxes([[Vector3(2.3, 0.04, 1.0), Transform3D(Basis(), Vector3(0, 0.86, 0))], [Vector3(2.3, 0.36, 0.02), Transform3D(Basis(), Vector3(0, 0.7, 0.5))]], gm))
	# entries on the table: a pie, a honey jar, a fleece, a pumpkin
	var pie := CylinderMesh.new(); pie.top_radius = 0.17; pie.bottom_radius = 0.14; pie.height = 0.07; pie.radial_segments = 12; pie.rings = 1
	var jar := CylinderMesh.new(); jar.top_radius = 0.08; jar.bottom_radius = 0.08; jar.height = 0.2; jar.radial_segments = 10; jar.rings = 1
	var ball := SphereMesh.new(); ball.radius = 0.2; ball.height = 0.4; ball.radial_segments = 10; ball.rings = 6
	for e in [[pie, Vector3(-0.7, 0.92, 0.1), Vector3.ONE, 0xc9915a], [jar, Vector3(-0.25, 0.98, 0.15), Vector3.ONE, 0xd9a441],
			[ball, Vector3(0.25, 0.96, 0.05), Vector3(1.3, 0.6, 1.0), 0xf3ecdc], [ball, Vector3(0.75, 1.02, 0.05), Vector3(1.2, 0.85, 1.0), 0xde7a32]]:
		var mi := MeshInstance3D.new(); mi.mesh = e[0]; mi.position = e[1]; mi.scale = e[2]; mi.material_override = PaperMats.paper(Color.hex((int(e[3]) << 8) | 0xff)); hinge.add_child(mi)
	# bunting: two poles and three drooping strings of pennants
	hinge.add_child(_boxes([[Vector3(0.08, 2.6, 0.08), Transform3D(Basis(), Vector3(-1.6, 1.3, -0.5))], [Vector3(0.08, 2.6, 0.08), Transform3D(Basis(), Vector3(1.6, 1.3, -0.5))]], PaperMats.paper(Color.hex(0x8a6038ff))))
	var cols := [0xb5473a, 0xefe3c4, 0x4f6f96]
	for k in 3:
		var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in range(k, 13, 3):
			var u := i / 12.0; var fx := -1.55 + u * 3.1; var fy := 2.5 - sin(u * PI) * 0.35
			var a := Vector3(fx - 0.11, fy, -0.5); var b := Vector3(fx + 0.11, fy, -0.5); var c := Vector3(fx, fy - 0.26, -0.5)
			for v in [a, c, b]: st.set_normal(Vector3.BACK); st.add_vertex(v) # (front, toward +z)
			for v in [a, b, c]: st.set_normal(Vector3.FORWARD); st.add_vertex(v) # (and back)
		var fm := MeshInstance3D.new(); fm.mesh = st.commit(); fm.material_override = PaperMats.paper(Color.hex((int(cols[k]) << 8) | 0xff)); hinge.add_child(fm)
	# the sign, hand-lettered on a cream board
	var sign := Town.board(1.7, 0.53, "res://assets/baked/homestead/fair_sign", 0.04)
	sign.position = Vector3(0, 2.0 - 0.265, -0.48); hinge.add_child(sign)
	# Mrs. Pruitt, the judge, facing out over the table
	judge = ModelFigure.new("townsfolk_1")
	judge.root.position = Vector3(1.35, 0, -0.25); judge.root.rotation.y = -0.25
	hinge.add_child(judge.root)
	visible = false
	# rosettes for the ribbons you've won, hung in a row under the porch awning (shown as you win them)
	var cs := cos(float(house.rot)); var sn := sin(float(house.rot)); var hy := Terrain.get_height(house.x, house.z)
	for i in 10:
		var m := Town.card(ROSETTE, "res://assets/baked/homestead/rosette", 0.02, 0.0)
		var lx := -2.4 + i * 0.4; var lz := 4.0
		m.position = Vector3(house.x + cs * lx + sn * lz, hy + 2.05, house.z - sn * lx + cs * lz); m.rotation.y = house.rot
		m.set_meta("home", m.position); m.visible = false
		rosettes.append(m)

func _ready() -> void:
	for m in rosettes: get_parent().add_child.call_deferred(m)

static func _boxes(list: Array, mat: Material) -> MeshInstance3D:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for b in list:
		var bm := BoxMesh.new(); bm.size = b[0]; st.append_from(bm, 0, b[1])
	var mi := MeshInstance3D.new(); mi.mesh = st.commit(); mi.material_override = mat
	return mi

## Pin the rosettes onto the house as it actually stands: a ray from the yard toward the house at each rosette's spot
## finds the porch beam, post or wall it hangs on.
func pin_to(house: Node3D) -> void:
	if house == null or not house.is_inside_tree(): return
	var fwd := house.global_basis.z; fwd.y = 0; fwd = fwd.normalized()
	var centre := Vector3.ZERO
	for m in rosettes: centre += m.get_meta("home") / rosettes.size()
	# the house's triangles near the porch (once)
	var tris := PackedVector3Array()
	var stack: Array = [house]
	while stack.size():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		if not (n is MeshInstance3D) or (n as MeshInstance3D).mesh == null: continue
		var xf := (n as MeshInstance3D).global_transform; var f := (n as MeshInstance3D).mesh.get_faces()
		for i in range(0, f.size(), 3):
			var a := xf * f[i]; var b := xf * f[i + 1]; var c := xf * f[i + 2]
			var mid := (a + b + c) / 3.0
			if Vector2(mid.x - centre.x, mid.z - centre.z).length() < 7.0 and mid.y > centre.y - 2.2 and mid.y < centre.y + 0.4:
				tris.append(a); tris.append(b); tris.append(c)
	for m in rosettes:
		var home: Vector3 = m.get_meta("home"); m.position = home
		for dy in [-0.7, -0.95, -1.2]: # (under the awning: the beam, a post, or the wall behind the porch)
			var o := home + fwd * 4.0; o.y += dy
			var best := 9.0; var hit = null
			for i in range(0, tris.size(), 3):
				var p = Geometry3D.ray_intersects_triangle(o, -fwd, tris[i], tris[i + 1], tris[i + 2])
				if p != null and o.distance_to(p) < best: best = o.distance_to(p); hit = p
			if hit != null: m.position = hit + fwd * 0.04; m.rotation.y = atan2(fwd.x, fwd.z); break

func near(p: Vector3, r := 2.6) -> bool: return shown and up > 0.9 and Vector2(p.x - at.x, p.z - at.z).length() < r
func open(sky: DaySky) -> bool: return is_fair_day(sky.day) and sky.time >= 0.29 and sky.time < 0.8

## Pin up a rosette for each ribbon won (up to ten along the beam).
func show_ribbons(n: int) -> void:
	for i in rosettes.size(): rosettes[i].visible = i < n

func update(dt: float, sky: DaySky) -> bool:
	t += dt
	var want := open(sky)
	if want and entered_day != sky.day: entered.clear(); entered_day = sky.day
	if want and not shown: shown = true; up = 0.0; visible = true
	if shown:
		up = minf(1.5, up + dt * 0.8) if want else up - dt * 1.2
		var k: float = Props.spring_rise(up) if want else pow(maxf(0.0, up), 2)
		hinge.rotation.x = -(1.0 - k) * (PI / 2)
		if not want and up <= 0.0: shown = false; visible = false
		judge.update(dt, 0.0, "clipboard") # (she sways on her heels, considering, clipboard held out)
	return want
