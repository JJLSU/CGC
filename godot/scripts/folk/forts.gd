class_name ArmyForts
extends Node3D
## The cavalry's forts (the player's ask): two or three a county, placed by its seed like the native camps and the
## claim jumpers' camps. Each is a square stockade of sharpened logs (a gate on the side toward town) round a few
## buildings: the officers' house, a barracks barn, a guardhouse, a water tower, a flagpole with the colours, wagons,
## crates and barrels. The troopers keep to their post: a sentry either side of the gate, the rest at drill about the
## yard. They let you be. Strike one and the whole fort turns out, rifles up, till you've gone a long way off; a
## fort's men beaten come back after three days, and by the next day the fort has forgotten it.
##
## The troopers wear the player's cavalry figures (cgc_soldier_*) once Meshy has made them; till then townsmen in
## blue stand in (ModelFigure's hue turns the clothes).

const SIDE := 34.0          ## the stockade's square, metres a side
const NEAR := 180.0
const FAR := 220.0
const AGGRO_LEASH := 110.0  ## an angry fort gives up once you're this far from its gate
const HIT := 22             ## a trooper's rifle ball
const RESPAWN_DAYS := 3
const SOLDIERS := ["cgc_soldier_2", "cgc_soldier_3", "cgc_soldier_4", "cgc_soldier_5", "cgc_soldier_6"]
const OFFICER := "cgc_soldier_officer"
const STAND_INS := ["folk_farmhand_01", "folk_farmhand_02", "folk_farmhand_03", "trades_1", "prospectors_4"]
const NAMES := ["Fort Laramie Creek", "Fort Kearny Bluff", "Fort Bridger Wells", "Fort Sedgwick", "Fort Pike"]

var forts: Array = []       ## {at, face, seed, name, built, nodes, men, angry, angry_day, cleared_day}
var day := 0
var told := false
var blocker: Callable

var world_ref: World = null
func setup(home: Vector3, avoid: Array, world: World = null) -> void:
	world_ref = world
	var rng := PNoise.Mulberry32.new(PNoise.hash2(31, 73, Terrain.SEED + 5150))
	var want := 2 + int(rng.next() * 2.0) # (two or three)
	var names := NAMES.duplicate()
	for tries in 600:
		if forts.size() >= want: break
		var a := rng.next() * TAU; var r := 260.0 + rng.next() * 420.0
		var x := home.x + cos(a) * r; var z := home.z + sin(a) * r
		if Terrain.is_water(x, z) or Terrain.impassable(x, z) or Terrain.range_at(x, z) > 0.01: continue
		var ok := true
		for j in 16:
			var b := j * TAU / 16.0
			for rr in [12.0, 22.0, 30.0]:
				var qx: float = x + cos(b) * rr; var qz: float = z + sin(b) * rr
				if Terrain.is_water(qx, qz) or Terrain.impassable(qx, qz) or Terrain.range_at(qx, qz) > 0.03: ok = false; break
			if not ok: break
		if not ok: continue
		if avoid.any(func(q): return Vector2(q.x - x, q.z - z).length() < 160.0): continue
		if forts.any(func(f): return Vector2(f.at.x - x, f.at.z - z).length() < 260.0): continue
		var at := Vector3(x, Terrain.get_height(x, z), z)
		var face := atan2(home.x - x, home.z - z) # (the gate looks toward the farm and the town)
		var nm: String = names.pop_at(int(rng.next() * names.size()))
		forts.append({"at": at, "face": face, "seed": int(rng.next() * 1e6), "name": nm, "built": false, "nodes": [], "men": [],
			"angry": false, "angry_day": -99, "cleared_day": -999, "walls": [], "job": -1, "job_day": -1})
		if world:
			world.exclusions.append({"x": x, "z": z, "r": SIDE * 0.75})
			# the stockade stops you as a wall does (the world's colliders: posts every 1.4 m along it), the gate open
			var fx := Vector3(cos(face), 0, -sin(face)); var fz := Vector3(sin(face), 0, cos(face))
			for side in 4:
				for k in int(SIDE / 1.4) + 1:
					var u := -SIDE / 2.0 + k * 1.4
					var q := _wall_point(at, fx, fz, side, u)
					if side == 0 and absf(u) < 3.2: continue # (the gate)
					world.colliders.append({"x": q.x, "z": q.z, "r": 0.75})

## A trooper's rifle in his fist, held at his side muzzle up: the player's Meshy single-shot rifle (as the farmer's),
## else a plain stick of a rifle.
static var _rifle_scene: PackedScene = null
static func rifle() -> Node3D:
	if _rifle_scene == null and ResourceLoader.exists("res://assets/models/props/prop_gun_rifle_single.glb"): _rifle_scene = load("res://assets/models/props/prop_gun_rifle_single.glb")
	if _rifle_scene:
		var m := _rifle_scene.instantiate() as Node3D; PaperMats.paperize(m, false)
		var k := 1.15 / 1.9 # (the models come 1.9 m long; it lies along x, muzzle at -x)
		m.transform = Transform3D(Basis(Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(1, 0, 0)) * k, Vector3(0, -0.28 * k, 0.04)) # (its length up the hand's line, muzzle up, the stock's wrist in the fist)
		var g := Node3D.new(); g.add_child(m); return g
	var r := MeshInstance3D.new(); var rm := BoxMesh.new(); rm.size = Vector3(0.05, 0.06, 1.05); r.mesh = rm
	r.material_override = PaperMats.paper(Color("4a3a2c")); r.rotation.x = PI / 2.0; r.position = Vector3(0, 0.05, 0.1)
	return r

## A point on the stockade: side 0 faces the gate's way (toward home), then round; u along it from -SIDE/2.
## The Meshy palisade section (a light copy of it) as one mesh to draw many times: its mesh, its card, the transform
## that stands it WALL_H tall on its foot, centred, and its width along the wall then.
const WALL_H := 3.5
static var _kit = null
static func _wall_kit():
	if _kit != null: return _kit if _kit is Dictionary else null
	# (the long wall, 4 m of it, made to measure in the player's Meshy agent work: 3.5 m standing, 0.5 m sunk; else the
	# short section, overlapped)
	var long := ResourceLoader.exists("res://assets/models/props/prop_fort_wall_long.glb")
	var path := "res://assets/models/props/prop_fort_wall_long.glb" if long else "res://assets/models/props/prop_fort_wall_short_lo.glb"
	if not ResourceLoader.exists(path): _kit = false; return null
	var inst := (load(path) as PackedScene).instantiate() as Node3D
	PaperMats.paperize(inst)
	var mis := PaperMats._meshes(inst).filter(func(m): return (m as MeshInstance3D).mesh.get_faces().size() > 30)
	if mis.is_empty(): inst.free(); _kit = false; return null
	var mi: MeshInstance3D = mis[0]
	var xf := Railroad._rel(mi, inst)
	var bb := xf * mi.mesh.get_aabb()
	var k := (WALL_H + 0.5) / bb.size.y if long else WALL_H / bb.size.y
	var local := Transform3D(Basis().scaled(Vector3.ONE * k), Vector3.ZERO) * Transform3D(Basis(), -Vector3(bb.get_center().x, bb.position.y, bb.get_center().z)) * xf
	_kit = {"mesh": mi.mesh, "mat": mi.get_active_material(0), "local": local, "sink": 0.5 if long else 0.25,
		"w": bb.size.x * k * (1.0 if long else 0.66)} # (the long wall butts end to end; the short section overlapped: its outer poles lean out past its body)
	inst.free()
	return _kit

## A piece of the player's fort kit at q, turned by b, true size (the kit is made to measure: ground line at 0, the
## foot sunk 0.5 m below it); false if the model isn't in.
func _piece(f: Dictionary, nm: String, q: Vector3, b: Basis) -> bool:
	var m := _model(nm)
	if m == null: return false
	m.transform = Transform3D(b, Vector3(q.x, Terrain.get_height(q.x, q.z), q.z)); add_child(m); f.nodes.append(m)
	return true
static var _models := {}
static func _model(nm: String) -> Node3D:
	var path := "res://assets/models/props/%s.glb" % nm
	if not ResourceLoader.exists(path): return null
	if not _models.has(nm): _models[nm] = load(path)
	var m := (_models[nm] as PackedScene).instantiate() as Node3D
	PaperMats.paperize(m)
	return m

static func _wall_point(at: Vector3, fx: Vector3, fz: Vector3, side: int, u: float) -> Vector3:
	var h := SIDE / 2.0
	match side:
		0: return at + fz * h + fx * u
		1: return at - fz * h + fx * u
		2: return at + fx * h + fz * u
		_: return at - fx * h + fz * u

func save() -> Array: return forts.map(func(f): return [f.cleared_day, f.angry_day, f.job, f.job_day])
func load_state(d) -> void:
	if d == null: return
	for i in mini(d.size(), forts.size()):
		var e = d[i]
		if e is Array:
			forts[i].cleared_day = int(e[0]); forts[i].angry_day = int(e[1])
			if e.size() > 3: forts[i].job = int(e[2]); forts[i].job_day = int(e[3])

## Every live trooper, for the hunting: [{pos, r, h, s}]
func targets() -> Array:
	var out := []
	for f in forts:
		for m in f.men: if not m.dead: out.append({"pos": m.fig.root.position, "r": 0.6, "h": 1.9, "s": m})
	return out

func find_target(player: Player, reach: float):
	var fw := player.forward(); var best = null; var bd := INF
	for f in forts:
		for m in f.men:
			if m.dead: continue
			var p: Vector3 = m.fig.root.position; var dx := p.x - player.pos.x; var dz := p.z - player.pos.z; var d := sqrt(dx * dx + dz * dz)
			if d > reach + 0.8 or (d > 0.3 and (dx * fw.x + dz * fw.z) / d < 0.2): continue
			if d < bd: bd = d; best = m
	return best

## A wound: the whole fort turns out. True if he fell.
func damage(m: Dictionary, n: int, hooks: Dictionary) -> bool:
	if m.dead: return false
	m.hp -= n; m.hurt = 0.3
	for f in forts:
		if m in f.men:
			if not f.angry and hooks.has("on_angry"): hooks.on_angry.call(f)
			f.angry = true; f.angry_day = day
			for o in f.men: o.state = "fight"
	if m.hp > 0: return false
	m.dead = 0.001
	if hooks.has("on_fall"): hooks.on_fall.call(m)
	for f in forts:
		if m in f.men and f.men.all(func(o): return o.dead): f.cleared_day = day
	return true

func near_fort(p: Vector3, r := 40.0):
	for f in forts: if Vector2(f.at.x - p.x, f.at.z - p.z).length() < r: return f
	return null

## hooks: on_hit(dmg), on_shoot(at), on_fall(man), on_angry(fort), on_first(fort)
var clock := 0.5 ## the time of day (main sets it), for the gates
func update(dt: float, today: int, player: Player, hooks: Dictionary) -> void:
	day = today
	var p := player.pos
	for f in forts:
		var d := Vector2(f.at.x - p.x, f.at.z - p.z).length()
		if not f.built and d < NEAR: _build(f)
		elif f.built and d > FAR: _unbuild(f)
		if f.angry and today > f.angry_day: f.angry = false # (a day on, it's forgotten)
		if f.built: _fort_update(f, dt, player, hooks, d)
		if not told and d < SIDE * 0.9:
			told = true
			if hooks.has("on_first"): hooks.on_first.call(f)

func _build(f: Dictionary) -> void:
	f.built = true
	var rng := PNoise.Mulberry32.new(f.seed)
	var at: Vector3 = f.at; var face: float = f.face
	var fx := Vector3(cos(face), 0, -sin(face)); var fz := Vector3(sin(face), 0, cos(face))
	var add := func(n: Node3D) -> void: add_child(n); f.nodes.append(n)
	# the stockade: sharpened logs shoulder to shoulder, two multimeshes (the shafts and their points)
	var shafts := MultiMesh.new(); shafts.transform_format = MultiMesh.TRANSFORM_3D
	var cm := CylinderMesh.new(); cm.top_radius = 0.2; cm.bottom_radius = 0.22; cm.height = 3.2; cm.radial_segments = 6; shafts.mesh = cm
	var tips := MultiMesh.new(); tips.transform_format = MultiMesh.TRANSFORM_3D
	var tm := CylinderMesh.new(); tm.top_radius = 0.0; tm.bottom_radius = 0.2; tm.height = 0.55; tm.radial_segments = 6; tips.mesh = tm
	var spots := []
	for side in 4:
		for k in int(SIDE / 0.42) + 1:
			var u := -SIDE / 2.0 + k * 0.42
			if side == 0 and absf(u) < 3.2: continue
			spots.append(_wall_point(at, fx, fz, side, u))
	shafts.instance_count = spots.size(); tips.instance_count = spots.size()
	for i in spots.size():
		var q: Vector3 = spots[i]; var y := Terrain.get_height(q.x, q.z); var hh := 3.0 + rng.next() * 0.45
		shafts.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(1, hh / 3.2, 1)), Vector3(q.x, y + hh / 2.0 - 0.15, q.z)))
		tips.set_instance_transform(i, Transform3D(Basis(), Vector3(q.x, y + hh - 0.15 + 0.27, q.z)))
	var kit = _wall_kit()
	if kit != null:
		# (the player's Meshy palisade, a section at a time end to end along each side, the gate left open; the
		# colliders as before)
		var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.mesh = kit.mesh
		var xfs := []
		var corners := ResourceLoader.exists("res://assets/models/props/prop_fort_corner.glb") # (the player's corner pieces: 2 m legs)
		var end_gap := 2.0 if corners else 0.0
		for side in 4:
			var along_v: Vector3 = fx if side < 2 else fz; var out_v: Vector3 = (fz if side == 0 else -fz) if side < 2 else (fx if side == 2 else -fx)
			var run := SIDE - end_gap * 2.0
			var n := ceili(run / kit.w) # (rounded up: the sections overlap a hair rather than leave a gap)
			for k in n:
				var u := -run / 2.0 + (k + 0.5) * (run / n)
				if side == 0 and absf(u) < 3.2: continue
				if side == 1 and k == n / 2: # (one section broken through at the back; fallen right down while the fort stands empty, its garrison beaten)
					var ruin := "prop_fort_wall_collapsed" if day < f.cleared_day + RESPAWN_DAYS else "prop_fort_wall_breached"
					if _piece(f, ruin, _wall_point(at, fx, fz, side, u), Basis(along_v, Vector3.UP, out_v)): continue
				var q: Vector3 = _wall_point(at, fx, fz, side, u); var y := Terrain.get_height(q.x, q.z) - float(kit.sink) # (its foot sunk into the ground)
				var hh := 1.0 + (rng.next() - 0.5) * 0.12
				var b := Basis(along_v, Vector3.UP * hh, out_v) # (its x along the wall, a touch taller or shorter section to section)
				xfs.append(Transform3D(b, Vector3(q.x, y, q.z)) * kit.local)
		mm.instance_count = xfs.size()
		for i in xfs.size(): mm.set_instance_transform(i, xfs[i])
		if corners: # (the four corners: each piece's outside corner on the stockade's, its legs back along the two walls)
			for sx in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					var q: Vector3 = at + fx * (sx * SIDE / 2.0) + fz * (sz * SIDE / 2.0)
					var X: Vector3 = -fx * sx; var Z: Vector3 = -fz * sz
					if X.cross(Vector3.UP).dot(Z) < 0.0: var tmp := X; X = Z; Z = tmp # (right-handed: never mirrored)
					_piece(f, "prop_fort_corner", q, Basis(X, Vector3.UP, Z))
		# the gate: two leaves hung on the gate posts, swung in by day, shut at night
		if ResourceLoader.exists("res://assets/models/props/prop_fort_gate.glb"):
			f.leaves = []
			for s in [-1.0, 1.0]:
				var hinge: Vector3 = at + fz * (SIDE / 2.0) + fx * (3.2 * s)
				var hold := Node3D.new(); hold.position = Vector3(hinge.x, Terrain.get_height(hinge.x, hinge.z), hinge.z)
				hold.basis = Basis(fx * -s, Vector3.UP, fz * -s) if s > 0 else Basis(fx, Vector3.UP, fz) # (its leaf out along the gateway from its post)
				add.call(hold)
				var leaf := _model("prop_fort_gate"); hold.add_child(leaf)
				f.leaves.append({"hold": hold, "side": s, "shut": hold.basis, "open": 0.0})
		var mi := MultiMeshInstance3D.new(); mi.multimesh = mm; mi.material_override = kit.mat
		mi.custom_aabb = AABB(at - Vector3(SIDE, 5, SIDE), Vector3(SIDE * 2, 20, SIDE * 2)); add.call(mi)
	else:
		for pair in [[shafts, "7a5634"], [tips, "a88458"]]:
			var mi := MultiMeshInstance3D.new(); mi.multimesh = pair[0]; mi.material_override = PaperMats.paper(Color(pair[1]))
			mi.custom_aabb = AABB(at - Vector3(SIDE, 5, SIDE), Vector3(SIDE * 2, 20, SIDE * 2)); add.call(mi)
	# the gate posts, a little taller, and a sign over the way in
	for s in [-1.0, 1.0]:
		var gp := _box(0.5, 4.4, 0.5, 0x5e4228); var q: Vector3 = at + fz * (SIDE / 2.0) + fx * (3.4 * s)
		gp.position = Vector3(q.x, Terrain.get_height(q.x, q.z) + 2.2, q.z); gp.rotation.y = face; add.call(gp)
	var beam := _box(7.4, 0.4, 0.35, 0x5e4228); var gq := at + fz * (SIDE / 2.0)
	beam.position = Vector3(gq.x, Terrain.get_height(gq.x, gq.z) + 4.2, gq.z); beam.rotation.y = face; add.call(beam)
	var sign := Label3D.new(); sign.text = String(f.name).to_upper(); sign.font_size = 56; sign.pixel_size = 0.006; sign.modulate = Color("efe2c4")
	sign.alpha_cut = Label3D.ALPHA_CUT_OPAQUE_PREPASS; sign.position = beam.position + fz * 0.2 + Vector3(0, 0.02, 0); sign.rotation.y = face; add.call(sign)
	# the buildings inside, round a parade ground
	var place := func(model: String, length: float, lx: float, lz: float, yaw: float) -> Node3D:
		var n := NativeCamps.prop(model, length)
		if n == null: return null
		var q: Vector3 = at + fx * lx + fz * lz
		n.position = Vector3(q.x, Terrain.get_height(q.x, q.z), q.z); n.rotation.y = face + yaw; add.call(n); return n
	place.call("bldg_cottage_restored", 9.0, 0.0, -11.0, 0.0)            # the officers' house, facing the gate
	place.call("bldg_barn", 11.0, -10.5, -1.0, PI / 2.0)                 # the barracks and stables
	place.call("bldg_jail_restored", 6.5, 10.5, 4.0, -PI / 2.0)          # the guardhouse
	place.call("prop_watertower", 4.0, 11.5, -9.5, 0.0)
	place.call("prop_gun_gatling", 2.4, 6.0, 13.0, PI / 2.0)              # the Gatling gun inside the gate, its barrels on the way in
	place.call("veh_covered_wagon", 5.0, 9.0, 11.5, PI * 0.6)
	place.call("prop_cart", 2.6, -11.0, 11.0, 0.4)
	for c in [[-5.5, 9.0], [-6.8, 10.2], [5.5, -6.5]]: place.call("prop_crates", 1.5, c[0], c[1], rng.next())
	for c in [[6.6, -5.0], [-12.5, -9.5], [-12.0, -10.8]]: place.call("prop_barrel", 0.9, c[0], c[1], 0.0)
	# the flagpole on the parade ground, the colours on it
	var fp := at + fz * 2.0
	var pole := MeshInstance3D.new(); var pm := CylinderMesh.new(); pm.top_radius = 0.05; pm.bottom_radius = 0.08; pm.height = 9.0; pm.radial_segments = 6
	pole.mesh = pm; pole.material_override = PaperMats.paper(Color("e8dcc0")); pole.position = Vector3(fp.x, Terrain.get_height(fp.x, fp.z) + 4.5, fp.z); add.call(pole)
	var flag := Node3D.new(); flag.position = pole.position + Vector3(0, 3.6, 0); flag.rotation.y = face + PI / 2.0
	for i in 7: # (the stripes, red and white, the blue canton in the corner)
		var st := _box(2.2, 0.18, 0.02, 0xa8352a if i % 2 == 0 else 0xf0e6d0); st.position = Vector3(1.1, 0.54 - i * 0.18, 0); flag.add_child(st)
	var canton := _box(0.9, 0.72, 0.025, 0x2e3e6a); canton.position = Vector3(0.45, 0.36, 0.005); flag.add_child(canton)
	add.call(flag); f["flag"] = flag
	# the troopers (none back yet if the fort's men were beaten in the last few days)
	if day < f.cleared_day + RESPAWN_DAYS: return
	var posts := [[3.0, SIDE / 2.0 + 1.2, "sentry"], [-3.0, SIDE / 2.0 + 1.2, "sentry"], [0.0, -6.5, "officer"], [-4.0, 3.0, "drill"], [-1.5, 3.0, "drill"], [1.0, 3.0, "drill"], [6.0, -1.5, "chores"]]
	for i in posts.size():
		var pst: Array = posts[i]
		var nm: String = OFFICER if pst[2] == "officer" else SOLDIERS[i % SOLDIERS.size()]
		var stand_in := not ModelFigure.has_folk(nm)
		if stand_in: nm = STAND_INS[i % STAND_INS.size()]
		var fig := ModelFigure.new(nm, {"hue": 3.6} if stand_in else {}) # (townsmen in borrowed blue, till the troopers' own figures come)
		fig.borrow_clip("run", "folk_native_warrior"); fig.work_tool = "axe" # (at chores, splitting wood)
		var rifle := ArmyForts.rifle(); if pst[2] != "chores": fig.hands[1].add_child(rifle) # (the man at chores has his axe instead)
		else: rifle.free() # (held at the side, muzzle up, as the pick handles are)
		var hm := at + fx * float(pst[0]) + fz * float(pst[1])
		fig.root.position = Vector3(hm.x, Terrain.get_height(hm.x, hm.z), hm.z); fig.root.rotation.y = face
		add_child(fig.root)
		f.men.append({"fig": fig, "home": hm, "role": pst[2], "state": "post", "hp": 10, "dead": 0.0, "hurt": 0.0, "cool": 1.0 + rng.next(),
			"t": rng.next() * 6.0, "goal": hm, "speed": 0.0})

func _unbuild(f: Dictionary) -> void:
	if world_ref and f.has("gate_cols"):
		for c in f.gate_cols: world_ref.colliders.erase(c)
		f.erase("gate_cols")
	f.built = false
	for n in f.nodes: if is_instance_valid(n): (n as Node).queue_free()
	for m in f.men: m.fig.root.queue_free()
	f.nodes = []; f.men = []

func _fort_update(f: Dictionary, dt: float, player: Player, hooks: Dictionary, d_gate: float) -> void:
	var p := player.pos; var at: Vector3 = f.at; var face: float = f.face
	var fx := Vector3(cos(face), 0, -sin(face)); var fz := Vector3(sin(face), 0, cos(face))
	if f.has("flag"): (f.flag as Node3D).rotation.z = sin(Time.get_ticks_msec() / 700.0) * 0.06 # (the colours stirring)
	# the gate: swung in by day (and while the fort's turned out against you, shut), shut at night
	var want_open := 1.0 if clock > 0.26 and clock < 0.8 and not f.angry else 0.0
	# (shut, the gate stops you as the wall does: posts across the gateway in the world's colliders; open, they're gone)
	if world_ref and f.has("leaves"):
		var shut: bool = f.leaves.size() > 0 and f.leaves[0].open < 0.3
		if shut and not f.has("gate_cols"):
			f.gate_cols = []
			for k in 5:
				var q: Vector3 = at + fz * (SIDE / 2.0) + fx * (-2.8 + k * 1.4)
				var c := {"x": q.x, "z": q.z, "r": 0.75}; world_ref.colliders.append(c); f.gate_cols.append(c)
		elif not shut and f.has("gate_cols"):
			for c in f.gate_cols: world_ref.colliders.erase(c)
			f.erase("gate_cols")
	for L in f.get("leaves", []):
		L.open = move_toward(L.open, want_open, dt * 0.4)
		var a: float = smoothstep(0.0, 1.0, L.open) * 1.6 * -float(L.side) # (swung inward on its post)
		(L.hold as Node3D).basis = Basis(Vector3.UP, a) * L.shut
	var gate := at + fz * (SIDE / 2.0)
	var from_gate := Vector2(p.x - gate.x, p.z - gate.z).length()
	if f.angry and (player.dead or from_gate > AGGRO_LEASH):
		for m in f.men: if not m.dead: m.state = "home"
	for m in f.men:
		var fig: ModelFigure = m.fig; var r: Node3D = fig.root
		if m.dead:
			m.dead += dt; r.rotation.x = -minf(1.0, m.dead / 0.6) * PI / 2.0 * 0.95; fig.update(dt, 0.0, null)
			if m.dead > 30.0: r.visible = false
			continue
		m.t += dt; m.cool = maxf(0.0, m.cool - dt); m.hurt = maxf(0.0, m.hurt - dt)
		var pos := r.position; var want := Vector3.ZERO; var spd := 0.0; var pose = null
		var to_p := Vector3(p.x - pos.x, 0, p.z - pos.z); var dp := to_p.length()
		if m.state == "fight" and f.angry and not player.dead and from_gate < AGGRO_LEASH:
			# rifles up: close to a dozen paces, kneel and fire; back off if you're right on them
			if dp > 13.0: want = to_p / maxf(dp, 0.01); spd = 6.0
			elif dp < 5.0: want = -to_p / maxf(dp, 0.01); spd = 3.0
			if m.cool <= 0.0 and dp < 26.0:
				m.cool = 2.2 + randf() * 0.9
				var aa := AimArm.on(m.fig); if aa: aa.raise(p + Vector3(0, 1.3, 0)) # (the rifle up at you)
				if hooks.has("on_shoot"): hooks.on_shoot.call(pos)
				if randf() < 0.4 and hooks.has("on_hit"): hooks.on_hit.call(HIT)
			r.rotation.y = _turn(r.rotation.y, atan2(to_p.x, to_p.z), dt * 8.0)
		else:
			if m.state != "post" and not f.angry: m.state = "post"
			var goal: Vector3 = m.home
			if m.role == "drill" and m.state == "post": # (marching up and down the parade ground)
				var leg := fmod(m.t, 12.0); goal = m.home + fx * (4.0 if leg < 6.0 else -4.0)
			elif m.role == "chores" and m.state == "post" and m.t > 8.0: m.t = 0.0; m.goal = at + fx * (randf() * 16.0 - 8.0) + fz * (randf() * 14.0 - 9.0)
			if m.role == "chores": goal = m.goal
			var tg := Vector3(goal.x - pos.x, 0, goal.z - pos.z)
			if tg.length() > 0.4: want = tg.normalized(); spd = 1.5 if m.role == "drill" else (3.5 if m.state == "home" else 1.2)
			if want != Vector3.ZERO: r.rotation.y = _turn(r.rotation.y, atan2(want.x, want.z), dt * 5.0)
			elif m.role == "sentry" or m.role == "officer": r.rotation.y = _turn(r.rotation.y, face, dt * 2.0) # (eyes out the gate)
			if m.role == "chores" and want == Vector3.ZERO: pose = "work" if fmod(m.t, 5.0) < 2.5 else null
		if spd > 0.0:
			var nx := pos.x + want.x * spd * dt; var nz := pos.z + want.z * spd * dt
			if not Terrain.is_water(nx, nz): pos.x = nx; pos.z = nz
			if blocker.is_valid(): pos = blocker.call(pos)
		m.speed = lerpf(m.speed, spd, minf(1.0, dt * 8.0))
		pos.y = Terrain.get_height(pos.x, pos.z); r.position = pos
		r.rotation.x = sin(m.hurt * 40.0) * 0.06 if m.hurt > 0.0 else 0.0
		fig.update(dt, m.speed, pose)

static func _box(w: float, h: float, d: float, hex: int) -> MeshInstance3D:
	var m := MeshInstance3D.new(); var b := BoxMesh.new(); b.size = Vector3(w, h, d); m.mesh = b
	m.material_override = PaperMats.paper(Color.hex((hex << 8) | 0xff)); return m

static func _turn(cur: float, want: float, k: float) -> float:
	var dd := want - cur; dd = atan2(sin(dd), cos(dd)); return cur + dd * minf(1.0, k)

## The fort's officer, if the farmer is within a few paces of him and the fort isn't riled (for his jobs and stores).
func officer_near(p: Vector3, r := 3.0):
	for f in forts:
		if f.angry: continue
		for m in f.men:
			if m.role == "officer" and not m.dead and Vector2(m.fig.root.position.x - p.x, m.fig.root.position.z - p.z).length() < r: return f
	return null

# ------------------------------------------------------------------ the patrols (the troopers about the county)
## By day each fort sends two troopers on horseback out to the town and back at a walk: there and back once a day,
## leaving in the morning, home by evening. They nod you by; they're only drawn while you're within NEAR of them.
## (A story element as the player asked: you meet the army on the road.)
var patrols: Array = []      ## {fort, riders: [{fig, horse}], pos, built}
var town_at := Vector3.ZERO

func setup_patrols(town_pos: Vector3) -> void:
	town_at = town_pos
	for f in forts: patrols.append({"fort": f, "riders": [], "pos": f.at, "built": false})

## Where the patrol is at this hour (time 0-1): out from the gate at 0.3, at the town by 0.5, home by 0.72.
func patrol_pos(pt: Dictionary, time: float) -> Vector3:
	var f: Dictionary = pt.fort
	var gate: Vector3 = f.at + Vector3(sin(f.face), 0, cos(f.face)) * (SIDE / 2.0 + 4.0)
	var u := 0.0
	if time > 0.3 and time < 0.5: u = (time - 0.3) / 0.2
	elif time >= 0.5 and time < 0.52: u = 1.0
	elif time >= 0.52 and time < 0.72: u = 1.0 - (time - 0.52) / 0.2
	var to_town: Vector3 = town_at + (gate - town_at).normalized() * 60.0 # (they turn back at the edge of town)
	return gate.lerp(to_town, u)

func patrols_update(dt: float, time: float, player: Player) -> void:
	for pt in patrols:
		var was: Vector3 = pt.pos
		var pos := patrol_pos(pt, time); pos.y = Terrain.get_height(pos.x, pos.z)
		pt.pos = pos
		var out: bool = time > 0.3 and time < 0.72 and not pt.fort.angry
		var near := Vector2(pos.x - player.pos.x, pos.z - player.pos.z).length() < NEAR
		if out and near and not pt.built: _patrol_build(pt)
		elif pt.built and (not out or not near): _patrol_unbuild(pt)
		if not pt.built: continue
		var mv := Vector3(pos.x - was.x, 0, pos.z - was.z); var spd := mv.length() / maxf(dt, 1e-4)
		var head: float = atan2(mv.x, mv.z) if mv.length() > 1e-4 else pt.get("head", 0.0)
		pt.head = head
		var side := Vector3(cos(head), 0, -sin(head))
		for i in pt.riders.size():
			var r: Dictionary = pt.riders[i]
			var hp: Vector3 = pos + side * ((i - 0.5) * 2.6) - Vector3(sin(head), 0, cos(head)) * (i * 1.5)
			hp.y = Terrain.get_height(hp.x, hp.z)
			var h: Puppet = r.horse
			h.group.position = hp # (the puppet turns itself the way it goes)
			h.update(dt, minf(spd, 4.0) * 0.8, "walk", false, 0.0, 0.0)
			var fig: ModelFigure = r.fig
			fig.root.position = hp; fig.play("sit", 0.2)
			NativeCamps.astride(fig); NativeCamps.seat(h, fig)

func _patrol_build(pt: Dictionary) -> void:
	pt.built = true
	for i in 2:
		var nm: String = SOLDIERS[(i + forts.find(pt.fort)) % SOLDIERS.size()]
		if not ModelFigure.has_folk(nm): nm = STAND_INS[i]
		var fig := ModelFigure.new(nm)
		var rifle := ArmyForts.rifle(); fig.hands[1].add_child(rifle)
		var h := Puppet.new("horse", 1.7)
		add_child(h.group); add_child(fig.root)
		pt.riders.append({"fig": fig, "horse": h})

func _patrol_unbuild(pt: Dictionary) -> void:
	pt.built = false
	for r in pt.riders: (r.fig as ModelFigure).root.queue_free(); (r.horse as Puppet).group.queue_free()
	pt.riders = []
