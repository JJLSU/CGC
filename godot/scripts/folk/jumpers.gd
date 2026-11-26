class_name ClaimJumpers
extends Node3D
## Claim jumpers (the player's own addition; not in the web version): hillbilly toughs squatting in ragged camps out in
## the county, violent and quick to fight. No warning, no poles: come within ~30 m of one and the whole camp comes for
## you, brawlers swinging pick handles, gunmen shooting six-shooters from a few paces off. They give up only once
## they've chased you a long way from their fire. Each one beaten drops his poke (main.add_drop); a camp cleared fills
## up again three days later.
##
## Camps are placed by the world's seed (so each county has its own), 150-650 m out from the farm, clear of water, the
## mountains, the town and the native camps. A camp's tent, fire and men are built only while you're within ~170 m.
## The men wear the townsfolk's and prospectors' models with their clothes re-dyed (ModelFigure's hue: never the
## skin), and borrow the warriors' run.

const CAMPS := 5
const AGGRO := 30.0        ## they come for you from this far
const LEASH := 90.0        ## and give up once you've led them this far from their fire
const SPEED := 6.4         ## at a run (the farmer walks at 6, sprints at 11.5: you can outrun them, just)
const REACH := 1.7
const HIT := 25            ## a blow or a bullet: a quarter of the farmer's starting health, as the warriors'
const RESPAWN_DAYS := 3
const NEAR := 170.0        ## built while you're this close; let go past FAR
const FAR := 210.0
## The fighting men (only men fight: the player's ask) and the camp's women, who keep clear of a fight as the
## natives' do and can't be hurt. (Looked at in a line-up, tools/shot_lineup.gd: trades_2 and trades_5 are women.)
const MEN := ["prospectors_1", "prospectors_4", "prospectors_6", "folk_farmhand_01", "folk_farmhand_02", "folk_farmhand_03", "folk_asa", "trades_1"]
const WOMEN := ["trades_2", "trades_5", "folk_calico_01", "folk_calico_02", "folk_calico_03"]

var camps: Array = []      ## {at, seed, cleared_day, built, nodes: [], men: []}
var day := 0
var told_first := false
var blocker: Callable ## (pos) -> pos pushed out of anything built (main: build.collide)

## Pick the camps' spots for this world. avoid: points to keep well clear of (the town, the native camps).
func setup(home: Vector3, avoid: Array, world: World = null) -> void:
	var rng := PNoise.Mulberry32.new(PNoise.hash2(17, 91, Terrain.SEED + 4242))
	var tries := 0
	while camps.size() < CAMPS and tries < 400:
		tries += 1
		var a := rng.next() * TAU; var r := 150.0 + rng.next() * 500.0
		var x := home.x + cos(a) * r; var z := home.z + sin(a) * r
		if Terrain.is_water(x, z) or Terrain.range_at(x, z) > 0.01: continue
		if Terrain.range_at(x + 16.0, z) > 0.03 or Terrain.range_at(x - 16.0, z) > 0.03 or Terrain.range_at(x, z + 16.0) > 0.03 or Terrain.range_at(x, z - 16.0) > 0.03: continue
		if avoid.any(func(q): return Vector2(q.x - x, q.z - z).length() < 140.0): continue
		if camps.any(func(c): return Vector2(c.at.x - x, c.at.z - z).length() < 160.0): continue
		var ok := true
		for j in 16: # (dry ground all round, out past the shack)
			var b := j * TAU / 16.0
			for rr in [8.0, 15.0, 22.0]:
				if Terrain.is_water(x + cos(b) * rr, z + sin(b) * rr): ok = false; break
			if not ok: break
		if not ok: continue
		var at := Vector3(x, Terrain.get_height(x, z), z)
		camps.append({"at": at, "seed": int(rng.next() * 1e6), "cleared_day": -999, "built": false, "nodes": [], "men": [], "women": [], "shack": at})
		if world: world.exclusions.append({"x": x, "z": z, "r": 20.0}) # (a trampled clearing round the fire, the tents and the shack)

func save() -> Array: return camps.map(func(c): return c.cleared_day)
func load_state(d) -> void:
	if d == null: return
	for i in mini(d.size(), camps.size()): camps[i].cleared_day = int(d[i])

## Every live man, for the hunting (arrows and bullets): [{pos, r, h, j}]
func targets() -> Array:
	var out := []
	for c in camps:
		for m in c.men: if not m.dead: out.append({"pos": m.fig.root.position, "r": 0.6, "h": 1.9, "j": m})
	return out

## The man in front of the farmer within reach, for a blow.
func find_target(player: Player, reach: float):
	var f := player.forward(); var best = null; var bd := INF
	for c in camps:
		for m in c.men:
			if m.dead: continue
			var p: Vector3 = m.fig.root.position; var dx := p.x - player.pos.x; var dz := p.z - player.pos.z; var d := sqrt(dx * dx + dz * dz)
			if d > reach + 0.8 or (d > 0.3 and (dx * f.x + dz * f.z) / d < 0.2): continue
			if d < bd: bd = d; best = m
	return best

## A wound; true if he fell. Any blow sets his camp on you, wherever you stand.
func damage(m: Dictionary, n: int, hooks: Dictionary) -> bool:
	if m.dead: return false
	m.hp -= n; m.hurt = 0.3
	for c in camps: if m in c.men: for o in c.men: o.angry = true
	if m.hp > 0: return false
	m.dead = 0.001
	if hooks.has("on_fall"): hooks.on_fall.call(m)
	for c in camps:
		if m in c.men and c.men.all(func(o): return o.dead): c.cleared_day = day
	return true

func near_camp(p: Vector3, r := 40.0) -> bool:
	return camps.any(func(c): return Vector2(c.at.x - p.x, c.at.z - p.z).length() < r)

## hooks: on_hit(damage), on_fall(man), on_shoot(), on_spotted(camp)
func update(dt: float, today: int, player: Player, hooks: Dictionary) -> void:
	day = today
	var p := player.pos
	for c in camps:
		var d := Vector2(c.at.x - p.x, c.at.z - p.z).length()
		if not c.built and d < NEAR: _build(c)
		elif c.built and d > FAR and not c.men.any(func(m): return not m.dead and m.state == "chase"): _unbuild(c)
		if c.built: _camp_update(c, dt, player, hooks)

func _build(c: Dictionary) -> void:
	c.built = true
	var rng := PNoise.Mulberry32.new(c.seed)
	var at: Vector3 = c.at
	var turn := rng.next() * TAU # (the camp's lay-out, turned its own way)
	var place := func(model: String, length: float, dx: float, dz: float, face := -1.0) -> Node3D:
		var n := NativeCamps.prop(model, length)
		if n == null: return null
		var o := Vector2(dx, dz).rotated(turn); var x: float = at.x + o.x; var z: float = at.z + o.y
		if Terrain.is_water(x, z) or Terrain.range_at(x, z) > 0.05: n.queue_free(); return null # (never in a pond or up a slope)
		n.position = Vector3(x, Terrain.get_height(x, z), z)
		n.rotation.y = (atan2(at.x - x, at.z - z) if face < 0.0 else face) + (rng.next() - 0.5) * 0.4 # (facing the fire, roughly)
		add_child(n); c.nodes.append(n); return n
	# a ragged camp: three tents and a lean-to shack round the cookfire, and the clutter of men working a stolen claim
	place.call("bldg_leanto", 5.5, 0.0, -10.5)
	c.shack = at + Vector3(Vector2(0.0, -14.0).rotated(turn).x, 0, Vector2(0.0, -14.0).rotated(turn).y) # (behind it, out of the way)
	for t in [[-8.5, -3.0], [8.0, -4.5], [-6.0, 7.5]]: place.call("prop_tent", 3.2, t[0], t[1])
	place.call("prop_cookfire", 1.1, 0.0, 0.0)
	for e in [["mine_sluice", 3.4, 9.5, 6.5], ["mine_orecart", 1.6, 5.5, 9.0], ["veh_handcart", 2.2, -10.5, 3.5], ["prop_crates", 1.4, 3.5, -8.0],
			["prop_barrel", 0.8, -2.8, -8.5], ["prop_barrel", 0.8, 11.0, -1.5], ["prop_bedroll", 1.2, -3.0, 3.2], ["prop_bedroll", 1.2, 3.0, 2.8], ["rock_boulders", 2.4, 12.0, -9.0]]:
		place.call(e[0], e[1], e[2], e[3])
	# the women, about the fire: they don't fight, and in a fight they gather by the shack
	for i in 1 + int(rng.next() * 2.0):
		var nm: String = WOMEN[int(rng.next() * WOMEN.size())]
		if not ModelFigure.has_folk(nm): continue
		var wf := ModelFigure.new(nm, {"hue": 0.35 + rng.next() * 2.2})
		var a0 := rng.next() * TAU; var hm := Vector3(at.x + cos(a0) * 4.5, 0, at.z + sin(a0) * 4.5)
		wf.root.position = Vector3(hm.x, Terrain.get_height(hm.x, hm.z), hm.z); add_child(wf.root)
		c.women.append({"fig": wf, "home": hm, "goal": hm, "t": rng.next() * 6.0, "speed": 0.0, "hide": Vector3((i - 0.5) * 1.6, 0, rng.next() - 0.5)})
	if day < c.cleared_day + RESPAWN_DAYS: return # (cleared out, and nobody back yet)
	var count := 3 + int(rng.next() * 3.0) # (three to five fighting men)
	for i in count:
		var nm: String = MEN[int(rng.next() * MEN.size())]
		if not ModelFigure.has_folk(nm): continue
		var fig := ModelFigure.new(nm, {"hue": 0.35 + rng.next() * 2.2}) # (their clothes re-dyed: never the skin)
		fig.borrow_clip("run", "folk_native_warrior")
		var gun := i % 3 == 2
		if gun:
			var g := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(0.05, 0.06, 0.26); g.mesh = bm
			g.material_override = PaperMats.paper(Color("2e2c2a")); g.position = Vector3(0, 0.02, 0.1); fig.hands[1].add_child(g)
		else:
			var h := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.03; cm.bottom_radius = 0.026; cm.height = 0.85; h.mesh = cm
			h.material_override = PaperMats.paper(Color("8a5e36")); h.rotation.x = PI / 2.0; h.position = Vector3(0, 0, 0.3); fig.hands[1].add_child(h)
		var a := i * TAU / count + rng.next() * 0.6
		var home := Vector3(at.x + cos(a) * 3.6, 0, at.z + sin(a) * 3.6)
		fig.root.position = Vector3(home.x, Terrain.get_height(home.x, home.z), home.z)
		fig.root.rotation.y = atan2(at.x - home.x, at.z - home.z)
		add_child(fig.root)
		c.men.append({"fig": fig, "gun": gun, "home": home, "state": "idle", "angry": false, "hp": 8, "dead": 0.0, "hurt": 0.0, "cool": 1.0 + rng.next(), "t": rng.next() * 4.0, "goal": home, "speed": 0.0})

func _unbuild(c: Dictionary) -> void:
	c.built = false
	for n in c.nodes: (n as Node).queue_free()
	for m in c.men: m.fig.root.queue_free()
	for w in c.women: w.fig.root.queue_free()
	c.nodes = []; c.men = []; c.women = []

func _camp_update(c: Dictionary, dt: float, player: Player, hooks: Dictionary) -> void:
	var p := player.pos
	var at: Vector3 = c.at
	var from_fire := Vector2(p.x - at.x, p.z - at.z).length()
	var fight: bool = c.men.any(func(m): return not m.dead and m.state == "chase")
	for w in c.women: _woman(w, c, dt, fight)
	for m in c.men:
		var fig: ModelFigure = m.fig; var r: Node3D = fig.root
		if m.dead:
			m.dead += dt; r.rotation.x = -minf(1.0, m.dead / 0.6) * PI / 2.0 * 0.95; fig.update(dt, 0.0, null)
			if m.dead > 30.0: r.visible = false
			continue
		m.t += dt; m.cool = maxf(0.0, m.cool - dt); m.hurt = maxf(0.0, m.hurt - dt)
		var pos := r.position
		var to_p := Vector3(p.x - pos.x, 0, p.z - pos.z); var dp := to_p.length()
		# the mood: they see you, and come
		if m.state != "chase" and not player.dead and (dp < AGGRO or m.angry) and from_fire < LEASH:
			m.state = "chase"
			if not told_first: told_first = true; if hooks.has("on_spotted"): hooks.on_spotted.call(c)
		if m.state == "chase" and (player.dead or from_fire > LEASH): m.state = "home"; m.angry = false
		var want := Vector3.ZERO; var spd := 0.0; var pose = null
		if m.state == "chase":
			var stand := 10.0 if m.gun else REACH * 0.8 # (the gunman keeps a few paces off)
			if dp > stand: want = to_p / maxf(dp, 0.01); spd = SPEED
			elif m.gun and dp < 5.0: want = -to_p / maxf(dp, 0.01); spd = 3.0 # (and backs off if you close on him)
			if m.cool <= 0.0 and not player.dead:
				if m.gun and dp < 22.0:
					m.cool = 2.0 + randf() * 0.8
					if hooks.has("on_shoot"): hooks.on_shoot.call(pos)
					if randf() < 0.45 and hooks.has("on_hit"): hooks.on_hit.call(HIT)
				elif not m.gun and dp < REACH:
					m.cool = 1.3 + randf() * 0.4; pose = "swing"
					if hooks.has("on_hit"): hooks.on_hit.call(HIT)
			r.rotation.y = _turn(r.rotation.y, atan2(to_p.x, to_p.z), dt * 10.0)
		else:
			# idle about the fire: now and then a few steps to a new spot; home again after a chase
			var goal: Vector3 = m.home if m.state == "home" else m.goal
			if m.state == "idle" and m.t > 5.0: m.t = 0.0; var a := randf() * TAU; m.goal = Vector3(at.x + cos(a) * (2.5 + randf() * 3.0), 0, at.z + sin(a) * (2.5 + randf() * 3.0))
			var tg := Vector3(goal.x - pos.x, 0, goal.z - pos.z)
			if tg.length() > 0.4: want = tg.normalized(); spd = 1.4 if m.state == "idle" else 3.5
			elif m.state == "home": m.state = "idle"
			if want != Vector3.ZERO: r.rotation.y = _turn(r.rotation.y, atan2(want.x, want.z), dt * 5.0)
			elif m.state == "idle": r.rotation.y = _turn(r.rotation.y, atan2(at.x - pos.x, at.z - pos.z), dt * 2.0)
		if spd > 0.0:
			var nx := pos.x + want.x * spd * dt; var nz := pos.z + want.z * spd * dt
			if not Terrain.is_water(nx, nz): pos.x = nx; pos.z = nz
			if blocker.is_valid(): pos = blocker.call(pos) # (your walls and palisades stop them)
		m.speed = lerpf(m.speed, spd, minf(1.0, dt * 8.0))
		pos.y = Terrain.get_height(pos.x, pos.z); r.position = pos
		r.rotation.x = sin(m.hurt * 40.0) * 0.06 if m.hurt > 0.0 else 0.0 # (a flinch when struck)
		fig.update(dt, m.speed, pose if pose != null else (fig.current if fig.current == "work" and m.cool > 0.9 and not m.gun else null))

## A camp woman: about the fire by day, a few steps now and then; in a fight she hurries to the shack and waits there.
func _woman(w: Dictionary, c: Dictionary, dt: float, fight: bool) -> void:
	var fig: ModelFigure = w.fig; var r: Node3D = fig.root; var pos := r.position
	w.t += dt
	var at: Vector3 = c.at
	if fight: w.goal = c.shack + w.hide # (each her own spot by the shack)
	elif w.t > 6.0: w.t = 0.0; var a := randf() * TAU; w.goal = Vector3(at.x + cos(a) * (3.0 + randf() * 3.0), 0, at.z + sin(a) * (3.0 + randf() * 3.0))
	var to := Vector3(w.goal.x - pos.x, 0, w.goal.z - pos.z); var d := to.length()
	var spd := 0.0
	if d > 0.5: spd = 4.5 if fight else 1.2; var stp := to / d * spd * dt; pos.x += stp.x; pos.z += stp.z; r.rotation.y = _turn(r.rotation.y, atan2(to.x, to.z), dt * 6.0)
	elif not fight: r.rotation.y = _turn(r.rotation.y, atan2(at.x - pos.x, at.z - pos.z), dt * 2.0)
	pos.y = Terrain.get_height(pos.x, pos.z); r.position = pos
	w.speed = lerpf(w.speed, spd, minf(1.0, dt * 8.0))
	fig.update(dt, w.speed, null)

static func _turn(cur: float, want: float, k: float) -> float:
	var d := want - cur; d = atan2(sin(d), cos(d)); return cur + d * minf(1.0, k)
