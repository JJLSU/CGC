class_name Horse
extends Node3D
## Biscuit, the saddle horse from the livery (main.js makeHorse / the horse block, saddle.js): the model mare at 1.7
## with her tack (a red Navajo-stripe blanket, a tooled stock saddle, fenders and wooden stirrups: printed cards bent
## to her back, riding her spine bones each frame). Ridden, she walks under you; whistled for (X), she comes, galloping
## from afar, walking the last stretch; left near the farm she walks herself into the barn stall at dusk and back out
## to the yard in the morning.

var puppet: Puppet
var saddle: Node3D
var called := false
var stabled := false
var route = null          ## [Vector3] waypoints, or null
var _bones := []          ## spine2, spine_04 (the saddle) and hips, chest (the seat)
var _sk: Skeleton3D

var pos: Vector3:
	get: return puppet.group.position
	set(v): puppet.group.position = v

func _init(x: float, z: float) -> void:
	puppet = Puppet.new("horse", 1.7) # (the model horse stands taller: a horse for a big man)
	add_child(puppet.group)
	pos = Vector3(x, Terrain.get_height(x, z), z)
	if puppet.model:
		var sks := puppet.model.find_children("*", "Skeleton3D", true, false)
		if sks.size(): _sk = sks[0]; for n in ["spine2", "spine_04", "hips", "chest"]: _bones.append(_sk.find_bone(n))
		saddle = make_saddle(); saddle.scale = Vector3.ONE * (puppet.rig.scale.x / 1.7); saddle.top_level = true
		add_child(saddle)

func bone_pos(i: int) -> Vector3: return _sk.global_transform * _sk.get_bone_global_pose(_bones[i]).origin

# ---------------------------------------------------------------- the tack (saddle.js)
static var _mats := {}
static func _mat(k: String) -> Material:
	if not _mats.has(k): _mats[k] = PaperMats.card(load("res://assets/baked/saddle/%s.png" % k), {"snow": 0.0})
	return _mats[k]

## three's CylinderGeometry(r, r, len, 20, 1, true, -arc/2, arc) turned to run along x with its arc over the top.
static func _drape(r: float, length: float, arc: float, mat: Material) -> MeshInstance3D:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg := 20
	var vtx := func(i: int, top: bool) -> Array:
		var th := -arc / 2.0 + arc * i / seg
		var y0 := length / 2.0 if top else -length / 2.0
		return [Vector3(-y0, r * cos(th), -r * sin(th)), Vector2(float(i) / seg, 0.0 if top else 1.0), Vector3(0, cos(th), -sin(th))]
	for i in seg:
		var a: Array = vtx.call(i, true); var b: Array = vtx.call(i + 1, true); var c: Array = vtx.call(i, false); var d: Array = vtx.call(i + 1, false)
		for v in [a, c, b, b, c, d]:
			st.set_uv(v[1]); st.set_normal(v[2]); st.add_vertex(v[0])
	var mi := MeshInstance3D.new(); mi.mesh = st.commit(); mi.material_override = mat
	return mi

## CircleGeometry(r, 12, 0, PI): an upright half-disc in its xy plane.
static func _half_disc(r: float, mat: Material) -> MeshInstance3D:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 12:
		var t0 := PI * i / 12.0; var t1 := PI * (i + 1) / 12.0
		for p in [Vector2.ZERO, Vector2(cos(t1), sin(t1)), Vector2(cos(t0), sin(t0))]:
			st.set_uv(Vector2((p.x + 1.0) / 2.0, 1.0 - (p.y + 1.0) / 2.0)); st.set_normal(Vector3(0, 0, 1)); st.add_vertex(Vector3(p.x * r, p.y * r, 0))
	var mi := MeshInstance3D.new(); mi.mesh = st.commit(); mi.material_override = mat
	return mi

static func _cyl(rt: float, rb: float, h: float, mat: Material) -> MeshInstance3D:
	var cm := CylinderMesh.new(); cm.top_radius = rt; cm.bottom_radius = rb; cm.height = h; cm.radial_segments = 10; cm.rings = 1
	var mi := MeshInstance3D.new(); mi.mesh = cm; mi.material_override = mat
	return mi

## TorusGeometry(0.07, 0.018, 6, 12, PI * 1.3): the wooden stirrup, an open hoop in its xy plane.
static func _stirrup(mat: Material) -> MeshInstance3D:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var R := 0.07; var r := 0.018; var arc := PI * 1.3
	var P := func(i: int, j: int) -> Vector3:
		var u := arc * i / 12.0; var v := TAU * j / 6.0
		return Vector3((R + r * cos(v)) * cos(u), (R + r * cos(v)) * sin(u), r * sin(v))
	for i in 12:
		for j in 6:
			var a: Vector3 = P.call(i, j); var b: Vector3 = P.call(i + 1, j); var c: Vector3 = P.call(i, j + 1); var d: Vector3 = P.call(i + 1, j + 1)
			for v in [a, b, c, b, d, c]:
				st.set_uv(Vector2(0.5, 0.5)); st.add_vertex(v)
	st.generate_normals()
	var mi := MeshInstance3D.new(); mi.mesh = st.commit(); mi.material_override = mat
	return mi

## Builds the tack (in metres, +x her forward).
static func make_saddle() -> Node3D:
	var g := Node3D.new()
	var blanket := _drape(0.46, 0.98, 2.2, _mat("blanket")); blanket.position.y = 0.34 - 0.46; g.add_child(blanket) # (a wide curve, so it lies on her barrel, not in it)
	var seat := _drape(0.48, 0.46, 1.1, _mat("leather")); seat.position.y = 0.36 - 0.48; g.add_child(seat)
	for s in [1.0, -1.0]: # skirts: the saddle's square leather flaps down each side over the blanket
		var skirt := _drape(0.47, 0.56, 0.62, _mat("leather")); skirt.position.y = 0.355 - 0.47; skirt.rotation.x = s * 0.62; g.add_child(skirt)
	var cantle := _half_disc(0.17, _mat("leather")); cantle.rotation = Vector3(0, PI / 2.0, -0.25); cantle.position = Vector3(-0.24, 0.3, 0); g.add_child(cantle)
	var pommel := _half_disc(0.12, _mat("leather")); pommel.rotation.y = PI / 2.0; pommel.position = Vector3(0.23, 0.31, 0); g.add_child(pommel)
	var horn := _cyl(0.035, 0.03, 0.12, _mat("leather")); horn.position = Vector3(0.25, 0.47, 0); g.add_child(horn)
	var cap := _cyl(0.06, 0.06, 0.02, _mat("leather")); cap.position = Vector3(0.25, 0.53, 0); g.add_child(cap)
	for s in [1.0, -1.0]: # fenders and stirrups, hanging down her flanks
		var hang := Node3D.new(); hang.position = Vector3(0.02, 0.2, s * 0.36); g.add_child(hang)
		var fender := MeshInstance3D.new(); var pm := QuadMesh.new(); pm.size = Vector2(0.16, 0.5); fender.mesh = pm
		fender.material_override = _mat("leather"); fender.position.y = -0.25; hang.add_child(fender)
		var stirrup := _stirrup(_mat("wood")); stirrup.rotation.z = PI * 1.15; stirrup.position.y = -0.55; hang.add_child(stirrup)
	return g

## Sits the tack on her back for this frame: between two spine bones, a little above them, pitched along her spine.
func place_saddle(lift: float) -> void:
	if saddle == null: return
	if _sk == null or _bones[0] < 0 or _bones[1] < 0: saddle.visible = false; return
	var a := bone_pos(0); var b := bone_pos(1)
	var f := (b - a).normalized()
	var s := Vector3.UP.cross(f).normalized(); var u := f.cross(s)
	var sc := saddle.scale.x
	saddle.global_transform = Transform3D(Basis(f, u, -s).scaled(Vector3.ONE * sc), a.lerp(b, 0.5) + u * (lift - 0.34 * sc))
	saddle.visible = puppet.group.visible

## On the model horse, the rider sits on its back: his hips a hand above the saddle's seat. False if it can't.
func seat_rider(avatar: Avatar) -> bool:
	var fig := avatar.fig
	if puppet.model == null or fig.skeleton == null or _sk == null: return false
	var zf := fig.root.global_transform.basis.z
	puppet.heading = atan2(zf.x, zf.z) - PI / 2.0; puppet.flip.rotation.y = puppet.heading # (the puppet heading is a quarter-turn off its travel)
	var hb := fig.skeleton.find_bone("Hips")
	if _bones[2] < 0 or _bones[3] < 0 or hb < 0: return false
	var sa: Vector3
	if saddle and saddle.visible: sa = saddle.global_transform * Vector3(0, 0.5, 0)
	else: sa = bone_pos(2).lerp(bone_pos(3), 0.55); sa.y += 0.32 * puppet.rig.scale.x / 1.7
	var sr := fig.skeleton.global_transform * fig.skeleton.get_bone_global_pose(hb).origin
	avatar.root.position += sa - sr
	return true

## barn: the homestead's barn_box (or null). Returns nothing; main moves the rider.
func update(dt: float, player: Player, camera: Camera3D, riding: bool, barn, sky_time: float) -> void:
	var hp := pos
	if riding: hp = player.pos
	else: hp.y = Terrain.get_height(hp.x, hp.z)
	# whistled for: she comes to you, galloping from afar, walking the last stretch, and stops beside you
	var call_spd := 0.0
	if called and not riding:
		var dx := player.pos.x - hp.x; var dz := player.pos.z - hp.z; var d := sqrt(dx * dx + dz * dz)
		if d < 2.2: called = false
		else:
			call_spd = 8.0 if d > 12.0 else (3.2 if d > 5.0 else 1.6)
			var nx := hp.x + (dx / d) * call_spd * dt; var nz := hp.z + (dz / d) * call_spd * dt
			if (Terrain.is_water(nx, nz) and not Terrain.wadeable(nx, nz)) or Terrain.impassable(nx, nz): called = false
			else: hp = Vector3(nx, Terrain.get_height(nx, nz), nz)
	# her stall: at dusk, if left near the farm, she walks in through the barn's big doors and stands the night
	if barn != null and not riding and not called:
		var B: Dictionary = barn
		var to_w := func(lx: float, lz: float) -> Vector3:
			lx += B.ox; lz += B.oz
			return Vector3(B.x + B.c * lx + B.s * lz, 0, B.z - B.s * lx + B.c * lz)
		var night := sky_time >= 0.83 or sky_time < 0.22
		var near := Vector2(hp.x - B.x, hp.z - B.z).length() < 70.0
		if night and near and not stabled and route == null: route = [to_w.call(0.0, B.hd + 2.2), to_w.call(0.0, B.hd - 0.8), to_w.call(-0.35, -0.05)]; stabled = true
		elif not night and stabled and route == null: route = [to_w.call(0.0, B.hd - 0.8), to_w.call(0.0, B.hd + 2.2), to_w.call(-1.5, B.hd + 6.0)]; stabled = false
	if riding or called: route = null; stabled = false
	if route != null and not riding:
		var wp: Vector3 = route[0]; var dx := wp.x - hp.x; var dz := wp.z - hp.z; var d := sqrt(dx * dx + dz * dz)
		if d < 0.25:
			route.pop_front()
			if route.is_empty(): route = null
		else:
			call_spd = minf(d / dt, 1.3); hp.x += (dx / d) * call_spd * dt; hp.z += (dz / d) * call_spd * dt; hp.y = Terrain.get_height(hp.x, hp.z)
	pos = hp
	var spd := Vector2(player.vel.x, player.vel.z).length() if riding else call_spd / 0.8
	var cam := camera.global_position
	var yaw_to_cam := atan2(cam.x - hp.x, cam.z - hp.z)
	var cam_right := Vector3(cos(yaw_to_cam), 0, -sin(yaw_to_cam))
	var left := (sin(player.facing) * cam_right.x + cos(player.facing) * cam_right.z) < 0.0 if riding else false
	puppet.update(dt, spd * 0.8, "walk" if spd > 0.2 else "idle", left, yaw_to_cam, 0.0) # (whistled for, the run blends in past a trot)
	if saddle: place_saddle(0.44 * saddle.scale.y) # (her tack rides her back)
