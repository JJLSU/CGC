class_name Homestead
extends Node3D
## homestead.js: the cozy vintage-Americana homestead, a paper model: clapboard farmhouse with porch and chimney smoke,
## the red barn (from the reference art), the windmill with its turning fan, picket fence, kitchen garden, hay, the
## mailbox and its flag, lantern posts that glow after dusk with real lights. Its layout is fixed relative to the farm
## centre (a fixed seed, all on the farm's level sheet), so the paper parts are baked from the web game
## (assets/baked/homestead/homestead.glb + .json: exclusions, colliders, roofs, lights, model placements, hooks).
## The farmhouse from the reference art stands in for the paper house in the state your fortune affords.

var C := Vector3.ZERO
var info: Dictionary
var model_root: Node3D
var house: Node3D
var fan: Node3D
var mail_flag: Node3D
var lights: Array = []       ## [{light, max}]
var smoke: Array = []
var chimney_top := Node3D.new()
var roofs: Array = []
var spawn := Vector3.ZERO
var house_model: Node3D
var on_house_model: Callable ## (the fair's rosettes re-pin to the porch of the house as it now stands)
var house_state := ""
var mailbox := Vector3.ZERO
var front_door := Vector3.ZERO
var front_window := Vector3.ZERO
var mill_at := Vector3.ZERO
var vane_at := Vector3.ZERO
var barn_box = null

## Registers the farm's exclusions, colliders and garden with the world (before any chunk is built).
func _init(world: World, center: Vector3) -> void:
	C = Vector3(center.x, 0, center.z)
	info = JSON.parse_string(FileAccess.open("res://assets/baked/homestead/homestead.json", FileAccess.READ).get_as_text())
	for e in info.exclusions: world.exclusions.append({"x": C.x + e.x, "z": C.z + e.z, "r": e.r})
	for e in info.colliders: world.colliders.append({"x": C.x + e.x, "z": C.z + e.z, "r": e.r})
	# the kitchen garden rows (west of the yard): corn and pumpkins, gathered and regrown like the wild
	var gx := C.x - 9.5; var gz0 := C.z + 1.6; var W := 7.0
	Props.garden = {"x0": gx - W / 2 + 0.6, "x1": gx + W / 2 - 0.6, "rows": [{"z": gz0 + 0.9, "type": "corn"}, {"z": gz0 + 2.3, "type": "corn"}, {"z": gz0 + 3.7, "type": "pumpkin"}, {"z": gz0 + 5.0, "type": "pumpkin"}]}
	for r in info.roofs: roofs.append({"x": C.x + r.x, "z": C.z + r.z, "rot": r.rot, "hw": r.hw, "z0": r.z0, "z1": r.z1})
	spawn = C + Vector3(info.spawn[0], info.spawn[1], info.spawn[2])
	mailbox = C + Vector3(info.mailbox[0], info.mailbox[1], info.mailbox[2]) if info.mailbox != null else C
	front_door = C + _v3(info.frontDoor); front_window = C + _v3(info.frontWindow)
	if info.millAt != null: mill_at = C + _v3(info.millAt)
	vane_at = C + _v3(info.vaneAt)
	if info.barnBox != null:
		barn_box = info.barnBox.duplicate(); barn_box.x += C.x; barn_box.z += C.z

static func _v3(a: Array) -> Vector3: return Vector3(a[0], a[1], a[2])
static func _m(a: Array) -> Transform3D: # (a three.js column-major Matrix4)
	return Transform3D(Basis(Vector3(a[0], a[1], a[2]), Vector3(a[4], a[5], a[6]), Vector3(a[8], a[9], a[10])), Vector3(a[12], a[13], a[14]))

func _ready() -> void:
	position = C
	model_root = (load("res://assets/baked/homestead/homestead.glb") as PackedScene).instantiate()
	add_child(model_root)
	_materials(model_root)
	fan = model_root.find_child("fan", true, false)
	mail_flag = model_root.find_child("mailflag", true, false)
	house = model_root.find_child("house", true, false)
	# the models from the reference art, where the web placed them (the barn, the hay)
	for m in info.models:
		var scene: PackedScene = load("res://assets/models/props/%s.glb" % m.model)
		if scene == null: continue
		var inst := scene.instantiate()
		PaperMats.paperize(inst)
		var meshes := PaperMats._meshes(inst)
		if meshes.size() <= int(m.mesh): inst.free(); continue
		var src: MeshInstance3D = meshes[int(m.mesh)]
		var mi := MeshInstance3D.new(); mi.mesh = src.mesh
		for s in src.mesh.get_surface_count(): mi.set_surface_override_material(s, src.get_surface_override_material(s))
		mi.transform = _m(m.m)
		add_child(mi)
		inst.free()
	# the lanterns' real lights, lit after dusk
	for l in info.lights:
		var o := OmniLight3D.new()
		o.light_color = Color.hex((int(l.color) << 8) | 0xff).srgb_to_linear(); # (as linear: see PORT.md 20d) o.omni_range = l.distance if l.distance > 0 else 11.0
		o.omni_attenuation = l.decay; o.light_energy = 0.0; o.shadow_enabled = false
		o.transform = _m(l.m)
		add_child(o)
		lights.append({"light": o, "max": float(l.max)})
	if house: house.add_child(chimney_top); chimney_top.position = _v3(info.chimneyTop)
	# chimney smoke: nine soft paper puffs rising and spreading
	var pts := PackedVector2Array()
	for i in 14:
		var a := (i / 14.0) * TAU; var r := 0.5 * (1.0 + 0.12 * sin(a * 5.0))
		pts.append(Vector2(cos(a) * r, sin(a) * r))
	var pm := CardMesh.build(pts, 0.06)
	for i in 9:
		var p := MeshInstance3D.new(); p.mesh = pm; p.material_override = PaperMats.paper(Color.hex(0xece4d6ff))
		p.set_meta("t", i / 9.0); p.set_meta("id", i)
		p.top_level = true
		add_child(p); smoke.append(p)

## The baked materials by name: card (a print), paper (a colour), glow_window (panes glow amber at night),
## glow_lantern (the lantern glass).
func _materials(n: Node) -> void: bake_materials(n)
static func bake_materials(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			var src := mi.get_active_material(s) as BaseMaterial3D
			if src == null: continue
			var nm := src.resource_name
			var tex := src.albedo_texture
			var mat: ShaderMaterial
			if tex != null:
				mat = PaperMats.card(tex, {"albedo": src.albedo_color})
				if nm.begins_with("glow_window"): mat.set_shader_parameter("night_glow", Vector3(1.0, 0.62, 0.28) * 3.2)
			else:
				mat = PaperMats.paper(src.albedo_color)
				if nm.begins_with("glow_lantern"):
					mat = mat.duplicate(); mat.set_shader_parameter("night_glow", Vector3(1.0, 0.65, 0.3) * 4.0)
			if src.cull_mode == BaseMaterial3D.CULL_DISABLED: pass
			mi.set_surface_override_material(s, mat)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for c in n.get_children(): bake_materials(c)

## The farmhouse from the reference art in the state your fortune affords: the starter shack till $60, partly mended
## from $60, fully mended from $200. The paper house steps aside; the chimney smoke rises from the model's chimney.
func set_fortune(fortune: float) -> void:
	var state := "mended" if fortune >= 200 else ("partly" if fortune >= 60 else "starter")
	if house == null or state == house_state: return
	var scene: PackedScene = load("res://assets/models/props/bldg_farmhouse_%s.glb" % state)
	if scene == null: return
	house_state = state
	if house_model: house_model.queue_free()
	else:
		for c in house.get_children():
			if c is MeshInstance3D: (c as MeshInstance3D).visible = false
	var m := scene.instantiate() as Node3D
	PaperMats.paperize(m)
	var meta: Dictionary = {}
	var jf := FileAccess.open("res://assets/models/props/bldg_farmhouse_%s.json" % state, FileAccess.READ)
	if jf: meta = JSON.parse_string(jf.get_as_text())
	var bb := PaperMats._aabb(m, Transform3D.IDENTITY)
	var body: Dictionary = meta.get("body", {})
	var k := float(info.houseW) / float(body.get("x", bb.size.x))
	var cx: float = body.get("cx", bb.position.x + bb.size.x / 2.0)
	m.scale = Vector3.ONE * k
	m.position = Vector3(-cx * k, -bb.position.y * k, float(info.houseFront) - bb.end.z * k)
	house.add_child(m); house_model = m
	if on_house_model.is_valid(): on_house_model.call_deferred(m)
	# the smoke rises from the model's chimney: the top of the house
	var top := Vector3.ZERO; var hi := -1e9; var n := 0
	var pts := []
	for mi in PaperMats._meshes(m):
		var xf := m.transform * (mi as MeshInstance3D).transform
		var arr := (mi as MeshInstance3D).mesh.surface_get_arrays(0)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		for i in range(0, verts.size(), 3):
			var v := xf * verts[i]; pts.append(v); hi = maxf(hi, v.y)
	for v in pts:
		if v.y > hi - 0.12: top += v; n += 1
	if n: chimney_top.position = Vector3(top.x / n, hi + 0.1, top.z / n)

## Is (x, z) under the farmhouse (or its porch) or the barn?
func covers(x: float, z: float) -> bool:
	for r in roofs:
		var dx: float = x - r.x; var dz: float = z - r.z; var c := cos(r.rot); var s := sin(r.rot)
		var lx := c * dx - s * dz; var lz := s * dx + c * dz
		if absf(lx) < r.hw and lz > r.z0 and lz < r.z1: return true
	return false

func update(dt: float, night: float, camera: Camera3D) -> void:
	var glow := PNoise.smoothstep(0.25, 0.8, night)
	RenderingServer.global_shader_parameter_set("paper_glow", glow)
	for l in lights: l.light.light_energy = glow * l.max / PI
	if fan: fan.rotation.z -= dt * 1.4
	var top := chimney_top.global_position
	for p in smoke:
		var t: float = fmod(float(p.get_meta("t")) + dt / 9.0, 1.0); p.set_meta("t", t)
		var id: int = p.get_meta("id")
		p.global_position = Vector3(top.x + sin(t * 5.0 + id) * 0.4 + t * 2.5, top.y + t * 7.0, top.z + t * 1.2)
		var sc := 0.3 + t * 1.5 * (1.0 - t * 0.4) * (t / 0.08 if t < 0.08 else 1.0) * ((1.0 - t) / 0.15 if t > 0.85 else 1.0)
		p.look_at(camera.global_position, Vector3.UP, true)
		p.scale = Vector3.ONE * sc
