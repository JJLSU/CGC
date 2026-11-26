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

func setup(home: Vector3, avoid: Array, world: World = null) -> void:
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
			"angry": false, "angry_day": -99, "cleared_day": -999, "walls": []})
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

## A point on the stockade: side 0 faces the gate's way (toward home), then round; u along it from -SIDE/2.
static func _wall_point(at: Vector3, fx: Vector3, fz: Vector3, side: int, u: float) -> Vector3:
	var h := SIDE / 2.0
	match side:
		0: return at + fz * h + fx * u
		1: return at - fz * h + fx * u
		2: return at + fx * h + fz * u
		_: return at - fx * h + fz * u

func save() -> Array: return forts.map(func(f): return [f.cleared_day, f.angry_day])
func load_state(d) -> void:
	if d == null: return
	for i in mini(d.size(), forts.size()):
		var e = d[i]
		if e is Array: forts[i].cleared_day = int(e[0]); forts[i].angry_day = int(e[1])

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
		fig.borrow_clip("run", "folk_native_warrior")
		var rifle := MeshInstance3D.new(); var rm := BoxMesh.new(); rm.size = Vector3(0.05, 0.06, 1.05); rifle.mesh = rm
		rifle.material_override = PaperMats.paper(Color("4a3a2c")); rifle.position = Vector3(0, 0.02, 0.3); fig.hands[1].add_child(rifle)
		var hm := at + fx * float(pst[0]) + fz * float(pst[1])
		fig.root.position = Vector3(hm.x, Terrain.get_height(hm.x, hm.z), hm.z); fig.root.rotation.y = face
		add_child(fig.root)
		f.men.append({"fig": fig, "home": hm, "role": pst[2], "state": "post", "hp": 10, "dead": 0.0, "hurt": 0.0, "cool": 1.0 + rng.next(),
			"t": rng.next() * 6.0, "goal": hm, "speed": 0.0})

func _unbuild(f: Dictionary) -> void:
	f.built = false
	for n in f.nodes: if is_instance_valid(n): (n as Node).queue_free()
	for m in f.men: m.fig.root.queue_free()
	f.nodes = []; f.men = []

func _fort_update(f: Dictionary, dt: float, player: Player, hooks: Dictionary, d_gate: float) -> void:
	var p := player.pos; var at: Vector3 = f.at; var face: float = f.face
	var fx := Vector3(cos(face), 0, -sin(face)); var fz := Vector3(sin(face), 0, cos(face))
	if f.has("flag"): (f.flag as Node3D).rotation.z = sin(Time.get_ticks_msec() / 700.0) * 0.06 # (the colours stirring)
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
