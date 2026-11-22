class_name Frogs
extends Node3D
## frogs.js: pond frogs (the bullfrog from the reference art, baked to one mesh) squatting on lily pads near the
## farmer, every other pad. Walk up close and the nearest leaps off in a high arc and plops in with a ring of
## ripples; a while later it hinges back up onto its pad. At dusk and by night they croak now and then (the throat
## puffs). All frogs one MultiMesh, the ripples another.

const N := 8

var mm := MultiMesh.new()
var rings := MultiMesh.new()
var frogs: Array = []
var ripples: Array = []
var scan_t := 0.0
var on_croak: Callable
var on_plop: Callable

func _init() -> void:
	# the model, baked: nose along +x, profile to +z, feet at 0, 0.3 m long (the card's length)
	var src := (load("res://assets/models/props/animal_frog.glb") as PackedScene).instantiate() as Node3D
	var mesh: ArrayMesh; var mat: Material
	for mi in src.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var xf := Transform3D()
		var n: Node = m
		while n != null and n != src: xf = (n as Node3D).transform * xf if n is Node3D else xf; n = n.get_parent()
		xf = Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3.ZERO) * xf
		var st := SurfaceTool.new(); st.append_from(m.mesh, 0, xf)
		mesh = st.commit()
		var sm := m.get_active_material(0) as BaseMaterial3D
		mat = PaperMats.card(sm.albedo_texture, {"albedo": sm.albedo_color, "snow": 0.0}) if sm and sm.albedo_texture else PaperMats.paper(Color.hex(0x6f8a4aff), false)
		break
	src.free()
	var b := mesh.get_aabb(); var k := 0.3 / b.size.x
	var st2 := SurfaceTool.new()
	st2.append_from(mesh, 0, Transform3D(Basis.from_scale(Vector3.ONE * k), Vector3.ZERO) * Transform3D(Basis(), -Vector3(b.position.x + b.size.x / 2.0, b.position.y, b.position.z + b.size.z / 2.0)))
	mm.transform_format = MultiMesh.TRANSFORM_3D; mm.mesh = st2.commit(); mm.instance_count = N; mm.visible_instance_count = 0
	var fmi := MultiMeshInstance3D.new(); fmi.multimesh = mm; fmi.material_override = mat
	fmi.custom_aabb = AABB(Vector3(-1e5, -100, -1e5), Vector3(2e5, 400, 2e5))
	add_child(fmi)
	# ripple rings, flat on the water
	rings.transform_format = MultiMesh.TRANSFORM_3D; rings.mesh = Wake.ring_mesh(0.9, 1.0, 28); rings.instance_count = N * 2; rings.visible_instance_count = 0
	var rmi := MultiMeshInstance3D.new(); rmi.multimesh = rings; rmi.material_override = Wake.flat_mat(Color.hex(0x4f6f78ff), 0.4)
	rmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; rmi.custom_aabb = fmi.custom_aabb
	add_child(rmi)
	for i in N: frogs.append({"pad": null, "state": "sit", "t": 0.0, "side": 1.0 if i % 2 else -1.0, "from": Vector3.ZERO, "to": Vector3.ZERO, "croakT": 3.0 + randf() * 20.0, "puff": 0.0})

## Lily pads within reach, nearest first (decor resources of the loaded chunks).
func pads(world: World, at: Vector3) -> Array:
	var out := []
	var C := Terrain.CHUNK
	for ch in world.chunks.values():
		if absf((ch.cx + 0.5) * C - at.x) > C + 30.0 or absf((ch.cz + 0.5) * C - at.z) > C + 30.0: continue
		for r in ch.resources:
			if (r.type == "lilypad" or r.type == "lilybloom") and r.alive:
				var d := Vector2(r.x - at.x, r.z - at.z).length()
				if d < 30.0: out.append([d, r])
	out.sort_custom(func(a, b) -> bool: return a[0] < b[0])
	return out.map(func(e): return e[1])

func update(dt: float, world: World, player: Player, camera: Camera3D, night: float, snow: float) -> void:
	# every couple of seconds, settle frogs onto the nearest free pads (every other pad: never crowded)
	scan_t -= dt
	if scan_t <= 0.0:
		scan_t = 2.0
		var all := [] if snow > 0.3 else pads(world, player.pos)
		var P := []
		for i in all.size(): if i % 2 == 0: P.append(all[i])
		var keep := {}
		for r in P: keep[r.key] = true
		for f in frogs: if f.pad != null and not keep.has(f.pad.key) and f.state == "sit": f.pad = null
		var used := {}
		for f in frogs: if f.pad != null: used[f.pad.key] = true
		for f in frogs:
			if f.pad != null: continue
			var pick = null
			for r in P: if not used.has(r.key): pick = r; break
			if pick == null: break
			f.pad = pick; used[pick.key] = true; f.state = "rise"; f.t = 0.0
	var n := 0
	var cam := camera.global_position
	for f in frogs:
		if f.pad == null: continue
		f.t += dt
		var x: float = f.pad.x; var z: float = f.pad.z; var y: float = f.pad.y + 0.02
		var near := Vector2(player.pos.x - x, player.pos.z - z).length() < 3.6
		var px := x; var py := y; var pz := z; var pitch := 0.0; var rise := 1.0
		if f.state == "rise":
			rise = Props.spring_rise(f.t * 1.2)
			if f.t > 1.2: f.state = "sit"; f.t = 0.0
		elif f.state == "sit" and near:
			# leap away from the farmer, out over open water
			f.state = "leap"; f.t = 0.0
			var ax := x - player.pos.x; var az := z - player.pos.z; var l := sqrt(ax * ax + az * az)
			if l == 0.0: l = 1.0
			f.from = Vector3(x, y, z); f.to = Vector3(x + (ax / l) * 1.6, y - 0.05, z + (az / l) * 1.6)
			var yc := atan2(cam.x - x, cam.z - z)
			f.side = 1.0 if ax * cos(yc) - az * sin(yc) > 0.0 else -1.0
		elif f.state == "sit":
			# the odd croak at dusk and by night, quieter the farther off
			if night > 0.3:
				f.croakT -= dt
				if f.croakT <= 0.0:
					f.croakT = 14.0 + randf() * 30.0; f.puff = 0.5
					if on_croak.is_valid(): on_croak.call(maxf(0.2, 1.0 - Vector2(player.pos.x - x, player.pos.z - z).length() / 30.0))
		if f.state == "leap":
			var k := minf(1.0, f.t / 0.55)
			px = f.from.x + (f.to.x - f.from.x) * k; pz = f.from.z + (f.to.z - f.from.z) * k
			py = f.from.y + (f.to.y - f.from.y) * k + sin(k * PI) * 0.9
			pitch = 0.6 - k * 1.4
			if k >= 1.0:
				f.state = "under"; f.t = 0.0
				ripples.append({"p": f.to + Vector3(0, 0.06, 0), "t": 0.0}); ripples.append({"p": f.to + Vector3(0, 0.06, 0), "t": -0.35})
				if on_plop.is_valid(): on_plop.call()
		if f.state == "under":
			if f.t > 18.0 and not near: f.state = "rise"; f.t = 0.0
			continue
		f.puff = maxf(0.0, f.puff - dt)
		var puff := 1.0 + sin(minf(1.0, f.puff / 0.5) * PI * 2.0) * 0.08 * (1.0 if f.puff > 0.0 else 0.0)
		# hinged up from lying flat on the pad, facing the camera, nose left or right
		var basis := Basis.from_euler(Vector3(-(1.0 - rise) * (PI / 2.0), atan2(cam.x - px, cam.z - pz), pitch * f.side), EULER_ORDER_YXZ)
		mm.set_instance_transform(n, Transform3D(basis.scaled_local(Vector3(2.2 * f.side, 2.2 * puff, 2.2)), Vector3(px, py, pz)))
		n += 1
	mm.visible_instance_count = n
	# ripples spread and fade
	var r := 0
	var keep_r := []
	for w in ripples:
		w.t += dt
		if w.t < 1.4: keep_r.append(w)
	ripples = keep_r
	for w in ripples:
		if w.t < 0.0: continue
		var s: float = 0.15 + w.t * 0.7
		rings.set_instance_transform(r, Transform3D(Basis.from_scale(Vector3(s, 1, s)), w.p)); r += 1
	rings.visible_instance_count = r
