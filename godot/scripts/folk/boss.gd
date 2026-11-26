class_name Boss
extends Node3D
## The bosses (the player's ask): a larger-than-life foe out in the wild who holds something the town needs to grow.
## The first is Mad Jebediah, a giant bearded prospector gone strange with gold fever, who stole the townsite deed and
## holed up at his diggings. Beat him and he drops the deed; take it to the assay office and Second Street goes up.
##
## His diggings are placed by the world's seed, 300-450 m from town on dry, level ground. He potters at his mine mouth
## till you come within AGGRO, then fights: from range he lobs pickaxes in a high arc at where you're headed (a dark
## mark shows where each will land: keep moving), and up close he raises his pick over his head and brings it down in
## a slam (a ring spreads on the ground first: get clear). Below half his health he throws two at a time. Lead him
## more than LEASH from his diggings and he stomps home and gets his wind back.

const HP_MAX := 54
const AGGRO := 34.0
const LEASH := 85.0
const SPEED := 3.4          ## he lumbers (the farmer walks at 6): you can always get away
const SCALE := 2.4
const PICK_HIT := 20
const SLAM_HIT := 25
const SLAM_R := 4.2
const PICK_R := 1.5         ## a thrown pick lands this close to you: it hits
const NEAR := 170.0
const FAR := 210.0
const MODEL := "prospectors_6" ## (the white-bearded one with the bedroll pack: looked at in tools/shot_lineup.gd)

var at := Vector3.ZERO      ## his fire, before the mine mouth
var mouth := Vector3.ZERO
var seed_n := 0
var built := false
var nodes: Array = []
var fig: ModelFigure
var hand_pick: Node3D
var hp := HP_MAX
var beaten := false
var delivered := false     ## the deed is back at the assay office
var dead := 0.0
var state := "idle"         ## idle, fight, home
var cool := 1.5
var hurt_t := 0.0
var slam_t := -1.0          ## counting down a slam's wind-up
var ring: MeshInstance3D
var picks: Array = []       ## [{node, mark, from, to, t, dur, landed}]
var told := false
var last_p := Vector3.ZERO
var vel := Vector3.ZERO
var speed := 0.0
var t := 0.0

## Pick his diggings for this world. avoid: places to keep well clear of (home, the native camps, the jumpers' camps).
func setup(town_at: Vector3, avoid: Array, world: World = null) -> void:
	var rng := PNoise.Mulberry32.new(PNoise.hash2(23, 57, Terrain.SEED + 777))
	seed_n = int(rng.next() * 1e6)
	for tries in 600:
		var a := rng.next() * TAU; var r := 300.0 + rng.next() * 150.0 + maxf(0.0, tries - 300) * 0.5
		var x := town_at.x + cos(a) * r; var z := town_at.z + sin(a) * r
		if Terrain.impassable(x, z) or Terrain.is_water(x, z) or Terrain.range_at(x, z) > 0.01: continue
		var level := true
		for j in 12:
			var b := j * TAU / 12.0
			for rr in [10.0, 20.0, 28.0]:
				var qx: float = x + cos(b) * rr; var qz: float = z + sin(b) * rr
				if Terrain.is_water(qx, qz) or Terrain.impassable(qx, qz) or Terrain.range_at(qx, qz) > 0.03: level = false; break
			if not level: break
		if not level: continue
		if avoid.any(func(q): return Vector2(q.x - x, q.z - z).length() < 150.0): continue
		at = Vector3(x, Terrain.get_height(x, z), z)
		break
	if at == Vector3.ZERO: at = town_at + Vector3(320, 0, 0); at.y = Terrain.get_height(at.x, at.z) # (never: but somewhere)
	var face := atan2(town_at.x - at.x, town_at.z - at.z) # (his mine looks back toward the town he robbed)
	var back := Vector3(-sin(face), 0, -cos(face))
	mouth = at + back * 9.0; mouth.y = Terrain.get_height(mouth.x, mouth.z)
	if world: world.exclusions.append({"x": at.x, "z": at.z, "r": 24.0})

func save() -> Dictionary: return {"beaten": beaten, "delivered": delivered}
func load_state(d) -> void:
	if d == null or not d is Dictionary: return
	beaten = bool(d.get("beaten", false)); delivered = bool(d.get("delivered", false))

func alive() -> bool: return built and fig != null and not beaten and dead == 0.0
func fighting() -> bool: return alive() and state == "fight"
func pos() -> Vector3: return fig.root.position if fig else at
func hp_frac() -> float: return clampf(float(hp) / HP_MAX, 0.0, 1.0)

## For the hunting (arrows and bullets): [{pos, r, h, boss}]
func targets() -> Array:
	return [{"pos": pos(), "r": 1.3, "h": 4.3, "boss": self}] if alive() else []

## Him, if he's in front of the farmer within reach of a blow (he's big: a long reach to him).
func find_target(player: Player, reach: float):
	if not alive(): return null
	var p := pos(); var f := player.forward(); var dx := p.x - player.pos.x; var dz := p.z - player.pos.z; var d := sqrt(dx * dx + dz * dz)
	if d > reach + 1.5 or (d > 0.3 and (dx * f.x + dz * f.z) / d < 0.2): return null
	return self

## A wound; true if he fell. Any blow brings him on, wherever you stand.
func damage(n: int, hooks: Dictionary) -> bool:
	if not alive(): return false
	hp -= n; hurt_t = 0.3
	if state != "fight": state = "fight"; _spotted(hooks)
	if hp > 0: return false
	beaten = true; dead = 0.001; slam_t = -1.0
	if ring: ring.visible = false
	if hand_pick: hand_pick.visible = false
	if hooks.has("on_fall"): hooks.on_fall.call(pos())
	return true

func _spotted(hooks: Dictionary) -> void:
	if not told: told = true; if hooks.has("on_spotted"): hooks.on_spotted.call()

## hooks: on_hit(damage), on_throw(), on_land(at), on_slam(), on_fall(at), on_spotted()
func update(dt: float, player: Player, hooks: Dictionary) -> void:
	t += dt
	var p := player.pos
	var d := Vector2(at.x - p.x, at.z - p.z).length()
	if not built and d < NEAR: _build()
	elif built and d > FAR and state != "fight": _unbuild()
	if not built: return
	if dt > 0.0: vel = vel.lerp((p - last_p) / dt, minf(1.0, dt * 4.0))
	last_p = p
	_picks_update(dt, player, hooks)
	if fig == null: return
	var r := fig.root
	if dead > 0.0:
		dead += dt; r.rotation.x = -minf(1.0, dead / 0.9) * PI / 2.0 * 0.95; fig.update(dt, 0.0, null)
		return
	cool = maxf(0.0, cool - dt); hurt_t = maxf(0.0, hurt_t - dt)
	var me := r.position
	var to_p := Vector3(p.x - me.x, 0, p.z - me.z); var dp := to_p.length()
	var from_home := Vector2(p.x - at.x, p.z - at.z).length()
	if state != "fight" and not player.dead and dp < AGGRO and from_home < LEASH:
		state = "fight"; cool = 1.2; _spotted(hooks)
	if state == "fight" and (player.dead or from_home > LEASH):
		state = "home"; slam_t = -1.0; ring.visible = false
	var want := Vector3.ZERO; var spd := 0.0; var pose = null
	if state == "fight":
		var enraged := hp * 2 < HP_MAX
		if slam_t >= 0.0:
			# the slam: the pick held high while the ring spreads, then down
			slam_t -= dt; pose = "work"
			var k := 1.0 - clampf(slam_t / 0.9, 0.0, 1.0)
			ring.visible = true; ring.position = Vector3(me.x, Terrain.get_height(me.x, me.z) + 0.06, me.z); ring.scale = Vector3(SLAM_R * k, 1, SLAM_R * k)
			if slam_t < 0.0:
				ring.visible = false; cool = 1.6
				if hooks.has("on_slam"): hooks.on_slam.call(me)
				if dp < SLAM_R and not player.dead and hooks.has("on_hit"): hooks.on_hit.call(SLAM_HIT)
		else:
			if dp > 4.0: want = to_p / maxf(dp, 0.01); spd = SPEED
			if cool <= 0.0 and not player.dead:
				if dp < 4.6: slam_t = 0.9 # (wind up)
				elif dp < 32.0:
					var n := 2 if enraged else 1
					for i in n: _throw(me, p, vel, dp, (i - (n - 1) / 2.0) * 2.6)
					cool = (1.9 if enraged else 2.5) + randf() * 0.6; pose = "swing"
					if hooks.has("on_throw"): hooks.on_throw.call()
		r.rotation.y = _turn(r.rotation.y, atan2(to_p.x, to_p.z), dt * 6.0)
	else:
		# at home: back to the mine mouth, a little work at the rock face; his wind back once he's there
		var goal := mouth + (at - mouth).normalized() * 2.5
		var tg := Vector3(goal.x - me.x, 0, goal.z - me.z)
		if tg.length() > 0.6: want = tg.normalized(); spd = SPEED * 0.7
		else:
			if state == "home": state = "idle"; hp = HP_MAX
			r.rotation.y = _turn(r.rotation.y, atan2(mouth.x - me.x, mouth.z - me.z), dt * 2.0)
			pose = "work" if fmod(t, 7.0) < 3.0 else null
		if want != Vector3.ZERO: r.rotation.y = _turn(r.rotation.y, atan2(want.x, want.z), dt * 4.0)
	if spd > 0.0:
		var nx := me.x + want.x * spd * dt; var nz := me.z + want.z * spd * dt
		if not Terrain.is_water(nx, nz): me.x = nx; me.z = nz
	speed = lerpf(speed, spd, minf(1.0, dt * 6.0))
	me.y = Terrain.get_height(me.x, me.z); r.position = me
	r.rotation.x = sin(hurt_t * 40.0) * 0.05 if hurt_t > 0.0 else 0.0
	hand_pick.visible = cool < (1.9 if hp * 2 < HP_MAX else 2.5) - 0.5 or state != "fight" # (a fresh one from his pack)
	fig.update(dt, speed / SCALE * 1.6, pose)

## A pickaxe lobbed at where you'll be (he leads you a little), side: metres off to one side (the second of a pair).
func _throw(from: Vector3, p: Vector3, v: Vector3, dp: float, side: float) -> void:
	var dur := clampf(dp / 13.0, 0.8, 1.7)
	var to := p + Vector3(v.x, 0, v.z) * dur * 0.55
	var fwd := Vector3(to.x - from.x, 0, to.z - from.z).normalized()
	to += Vector3(-fwd.z, 0, fwd.x) * side
	to.y = Terrain.get_height(to.x, to.z)
	var n := _pick_mesh(2.3); add_child(n)
	var mark := MeshInstance3D.new(); var dm := CylinderMesh.new(); dm.top_radius = PICK_R; dm.bottom_radius = PICK_R; dm.height = 0.02; dm.radial_segments = 20
	mark.mesh = dm; mark.material_override = _mark_mat(); mark.position = to + Vector3(0, 0.05, 0); add_child(mark)
	picks.append({"node": n, "mark": mark, "from": from + Vector3(0, 4.2, 0), "to": to, "t": 0.0, "dur": dur, "landed": -1.0})

func _picks_update(dt: float, player: Player, hooks: Dictionary) -> void:
	for k in picks.duplicate():
		var n: Node3D = k.node
		if k.landed >= 0.0:
			k.landed += dt
			if k.landed > 4.0: n.queue_free(); picks.erase(k)
			continue
		k.t += dt
		var u := clampf(k.t / k.dur, 0.0, 1.0)
		var q: Vector3 = (k.from as Vector3).lerp(k.to, u); q.y += sin(u * PI) * (3.0 + k.dur * 3.0) # (a high lob)
		n.position = q; n.rotation = Vector3(-k.t * 11.0, atan2(k.to.x - k.from.x, k.to.z - k.from.z), 0)
		var m: MeshInstance3D = k.mark; (m.material_override as StandardMaterial3D).albedo_color.a = 0.2 + 0.4 * u
		if u >= 1.0:
			k.landed = 0.0; m.queue_free()
			n.position = k.to + Vector3(0, 0.5, 0); n.rotation = Vector3(-2.3, n.rotation.y, 0) # (stuck in the dirt, handle up)
			if hooks.has("on_land"): hooks.on_land.call(k.to)
			if Vector2(player.pos.x - k.to.x, player.pos.z - k.to.z).length() < PICK_R and not player.dead and hooks.has("on_hit"): hooks.on_hit.call(PICK_HIT)

func _build() -> void:
	built = true
	var rng := PNoise.Mulberry32.new(seed_n)
	var face := atan2(at.x - mouth.x, at.z - mouth.z)
	var place := func(model: String, length: float, q: Vector3, yaw: float) -> Node3D:
		var n := NativeCamps.prop(model, length)
		if n == null: return null
		if Terrain.is_water(q.x, q.z): n.queue_free(); return null
		n.position = Vector3(q.x, Terrain.get_height(q.x, q.z), q.z); n.rotation.y = yaw
		add_child(n); nodes.append(n); return n
	var side := Vector3(cos(face), 0, -sin(face)) # (across the mine's face)
	var outw := (at - mouth).normalized()
	place.call("mine_entrance", 7.0, mouth, face)
	place.call("mine_windlass", 2.6, mouth + side * 6.5 + outw * 1.5, face + 0.3)
	place.call("mine_toolrack", 2.0, mouth - side * 5.5 + outw * 1.0, face - 0.4)
	place.call("mine_orecart", 1.8, mouth + side * 3.2 + outw * 3.5, face + 1.3)
	place.call("prop_cookfire", 1.1, at, 0.0)
	place.call("prop_tent", 3.4, at - side * 7.5 + outw * 2.0, face + 2.4)
	place.call("prop_bedroll", 1.2, at + side * 2.2 + outw * 1.0, face)
	place.call("prop_barrel", 0.8, at + side * 4.0 - outw * 1.5, 0.0)
	for i in 4:
		var a := rng.next() * TAU; var rr := 13.0 + rng.next() * 8.0
		place.call("rock_boulders", 2.0 + rng.next() * 1.6, at + Vector3(cos(a) * rr, 0, sin(a) * rr), rng.next() * TAU)
	# a heap of picks, broken and whole, by the rack: his stock
	for i in 5:
		var pk := _pick_mesh(1.4); var q := mouth - side * (4.0 + rng.next() * 2.5) + outw * (2.5 + rng.next() * 1.5)
		pk.position = Vector3(q.x, Terrain.get_height(q.x, q.z) + 0.12, q.z); pk.rotation = Vector3(PI / 2.0 + rng.next() * 0.2, rng.next() * TAU, 0); add_child(pk); nodes.append(pk)
	ring = MeshInstance3D.new(); var tm := TorusMesh.new(); tm.inner_radius = 0.86; tm.outer_radius = 1.0; tm.rings = 32; tm.ring_segments = 4
	ring.mesh = tm; ring.material_override = PaperMats.paper(Color("a8352a")); ring.visible = false; add_child(ring); nodes.append(ring)
	if beaten: return
	if not ModelFigure.has_folk(MODEL): return
	fig = ModelFigure.new(MODEL, {"scale": SCALE})
	fig.borrow_clip("run", "folk_native_warrior")
	hand_pick = _pick_mesh(0.85); hand_pick.rotation.x = PI / 2.0; hand_pick.position = Vector3(0, 0, 0.25); fig.hands[1].add_child(hand_pick)
	var home := mouth + outw * 2.5
	fig.root.position = Vector3(home.x, Terrain.get_height(home.x, home.z), home.z); fig.root.rotation.y = atan2(mouth.x - home.x, mouth.z - home.z)
	add_child(fig.root)
	hp = HP_MAX; state = "idle"; dead = 0.0

func _unbuild() -> void:
	built = false
	for n in nodes: if is_instance_valid(n): (n as Node).queue_free()
	for k in picks: (k.node as Node).queue_free(); if is_instance_valid(k.mark): (k.mark as Node).queue_free()
	nodes = []; picks = []; ring = null
	if fig: fig.root.queue_free(); fig = null; hand_pick = null

## A pickaxe: an ash handle along its own z, an iron head across the far end. length: the handle.
static func _pick_mesh(length: float) -> Node3D:
	var g := Node3D.new()
	var h := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = length * 0.035; cm.bottom_radius = length * 0.04; cm.height = length; cm.radial_segments = 6
	h.mesh = cm; h.material_override = PaperMats.paper(Color("8a6038")); h.rotation.x = PI / 2.0; h.position = Vector3(0, 0, length * 0.5 - 0.1); g.add_child(h)
	var hd := MeshInstance3D.new(); var hm := CylinderMesh.new(); hm.top_radius = length * 0.012; hm.bottom_radius = length * 0.045; hm.height = length * 0.7; hm.radial_segments = 5
	hd.mesh = hm; hd.material_override = PaperMats.paper(Color("9a9da2")); hd.position = Vector3(0, length * 0.12, length - 0.12); g.add_child(hd)
	return g

static func _mark_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.25, 0.13, 0.08, 0.3); m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

static func _turn(cur: float, want: float, k: float) -> float:
	var dd := want - cur; dd = atan2(sin(dd), cos(dd)); return cur + dd * minf(1.0, k)
