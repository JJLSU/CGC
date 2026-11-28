class_name NativeCamps
extends Node3D
## natives.js: the people of the valleys. Three camps, each in an open valley a good ride out, with lodges round a
## cooking fire, a horse picket, and their land marked by a ring of painted poles. Cross the poles and a warrior runs
## out, signals you back and puts an arrow at your feet; stay or push on and they fight (bowmen mount and ride at you,
## shooting from the saddle; the hunter closes in with his club). Step back over and they let you go. Struck, a warrior
## falls. A gift at the poles buys three days' peace, and at a camp at peace you can trade at the fire. The camp's
## folk go about the lodges and the fire, abed at night, and gather out of the way in a fight. (The raids on the
## town: start_raid, driven from main.gd's _raid_tick.)

const R := 56.0  ## their land round the lodges (46 before the camps grew: the player's ask)
const HIT := 25 ## a warrior's club or arrow: a quarter of the farmer's starting health (100) in one blow (the player's ask; the page has 8-12)
static var lodge_glow := 0.0
static var camp_abed := false
static var camp_day := 0
static var player_armed := true ## a bow, six-shooter or rifle to hand: no raid comes on the town till then (main.gd; the player's ask)
static var lodge_mats: Array = []
## A blow or an arrow lands at most this often from all the warriors together (the player found nine of them at a
## quarter of your health a hit killed too quickly): each hit still a quarter, but spaced out so you can fight or run.
const HIT_GAP_MS := 3500
static var _next_hit_ms := 0
static func land_hit(hooks: Dictionary) -> void:
	var now := Time.get_ticks_msec()
	if now < _next_hit_ms or not hooks.has("on_hit"): return
	_next_hit_ms = now + HIT_GAP_MS; hooks.on_hit.call(HIT)

var list: Array = []   ## the camps: [Camp]
var raid: Raid
var at = null

static func set_lodge_glow(night: float, t: float, abed := false, day := 0) -> void:
	camp_abed = abed; camp_day = day
	lodge_glow = maxf(0.0, night - 0.35) * 0.45 * (0.92 + sin(t * 6.1) * 0.04 + sin(t * 1.7) * 0.04)
	for m in lodge_mats: (m as ShaderMaterial).set_shader_parameter("self_fill", 0.28 + lodge_glow * 1.6) # (a fire low in every lodge after dark: the hide glows from within)

static func _mat(hex: int) -> Material: return PaperMats.paper(Color.hex((hex << 8) | 0xff), false)
static func _box(w: float, h: float, d: float, hex: int) -> MeshInstance3D:
	var b := BoxMesh.new(); b.size = Vector3(w, h, d)
	var m := MeshInstance3D.new(); m.mesh = b; m.material_override = _mat(hex); return m

static func marker_pole(rng: PNoise.Mulberry32) -> Node3D:
	var g := Node3D.new()
	var post := _box(0.12, 2.3, 0.12, 0x7a5232); post.position.y = 1.15; g.add_child(post)
	for yb in [[1.7, 0xa8352a], [1.85, 0xefe2c4], [2.0, 0xa8352a], [0.9, 0x4f6680]]: var b := _box(0.15, 0.1, 0.15, yb[1]); b.position.y = yb[0]; g.add_child(b)
	for s in [-1.0, 1.0]: # two feathers on thongs, cream with dark tips
		var f := Node3D.new(); f.position = Vector3(s * 0.09, 2.15, 0); f.rotation.z = s * (0.3 + rng.next() * 0.2)
		var quill := _box(0.035, 0.34, 0.01, 0xefe2c4); quill.position.y = -0.2; f.add_child(quill)
		var tip := _box(0.037, 0.08, 0.012, 0x3a2e28); tip.position.y = -0.34; f.add_child(tip)
		g.add_child(f)
	return g

## A model prop from the reference art sized to len (its larger footprint side), lit like a lodge if asked.
static func prop(model_name: String, length: float, lodge := false) -> Node3D:
	var path := "res://assets/models/props/%s.glb" % model_name
	if not ResourceLoader.exists(path): return null
	var hold := PaperMats.seated(load(path), length, false, false)
	if model_name == "prop_tent": hold.add_to_group("tents") # (a twister can carry it off)
	if lodge:
		for mi in PaperMats._meshes(hold):
			var m := mi as MeshInstance3D
			for i in m.mesh.get_surface_count():
				var mat := m.get_surface_override_material(i)
				if mat is ShaderMaterial: var c := (mat as ShaderMaterial).duplicate() as ShaderMaterial; m.set_surface_override_material(i, c); lodge_mats.append(c)
	return hold

static func bow_mesh() -> Node3D:
	var g := Node3D.new()
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES) # (a torus arc of 1.4 rad, radius 0.62, tube 0.02)
	var arc := 1.4
	for i in 12:
		for j in 5:
			var P := func(a: int, b: int) -> Vector3:
				var u := arc * a / 12.0 + PI / 2.0 - 0.7; var v := TAU * b / 5.0
				return Vector3((0.62 + 0.02 * cos(v)) * cos(u) - 0.62, (0.62 + 0.02 * cos(v)) * sin(u), 0.02 * sin(v))
			for q in [[i, j], [i + 1, j], [i, j + 1], [i + 1, j], [i + 1, j + 1], [i, j + 1]]: st.add_vertex(P.call(q[0], q[1]))
	st.generate_normals()
	var m := MeshInstance3D.new(); m.mesh = st.commit(); m.material_override = _mat(0x8a5e36); g.add_child(m)
	return g

static func _cyl(rt: float, rb: float, h: float, hex: int, z: float) -> MeshInstance3D:
	var c := CylinderMesh.new(); c.top_radius = rt; c.bottom_radius = rb; c.height = h; c.radial_segments = 5; c.rings = 1
	var m := MeshInstance3D.new(); m.mesh = c; m.material_override = _mat(hex); m.rotation.x = PI / 2.0; m.position.z = z; return m

static func spear_mesh() -> Node3D:
	var g := Node3D.new()
	g.add_child(_cyl(0.02, 0.024, 2.1, 0x9a7448, 0.5)); g.add_child(_cyl(0.0, 0.05, 0.22, 0x8e8a80, 1.65))
	var tie := _box(0.06, 0.06, 0.1, 0xa8352a); tie.position.z = 1.48; g.add_child(tie)
	return g

static func club_mesh() -> Node3D:
	var g := Node3D.new()
	g.add_child(_cyl(0.025, 0.03, 0.75, 0x8a5e36, 0.2))
	var sm := SphereMesh.new(); sm.radius = 0.11; sm.height = 0.22; sm.radial_segments = 6; sm.rings = 3
	var stone := MeshInstance3D.new(); stone.mesh = sm; stone.material_override = _mat(0x8a8680); stone.scale = Vector3(1, 0.8, 1.3); stone.position.z = 0.6; g.add_child(stone)
	var wrap := _box(0.07, 0.07, 0.12, 0xd8c08a); wrap.position.z = 0.5; g.add_child(wrap)
	return g

static func arrow_mesh() -> Node3D:
	var g := Node3D.new()
	g.add_child(_cyl(0.012, 0.012, 0.8, 0xc8a46e, 0.0))
	var fl := _box(0.005, 0.07, 0.16, 0xa8352a); fl.position.z = -0.32; g.add_child(fl)
	return g

## Sit a rider's hips on the middle of the horse's back, facing the way she faces.
static func seat(horse: Puppet, fig: ModelFigure) -> void:
	if horse.model == null or fig.skeleton == null: fig.root.position.y += 1.05; return
	var sks := horse.model.find_children("*", "Skeleton3D", true, false)
	if sks.is_empty(): return
	var sk := sks[0] as Skeleton3D
	var bh := sk.find_bone("hips"); var bc := sk.find_bone("chest"); var hb := fig.skeleton.find_bone("Hips")
	if bh < 0 or bc < 0 or hb < 0: return
	fig.root.rotation.y = (horse.heading if horse.heading != null else horse.flip.rotation.y) + PI / 2.0
	var sa := (sk.global_transform * sk.get_bone_global_pose(bh).origin).lerp(sk.global_transform * sk.get_bone_global_pose(bc).origin, 0.55)
	sa.y += 0.32 * horse.rig.scale.x / 1.7
	var sr := fig.skeleton.global_transform * fig.skeleton.get_bone_global_pose(hb).origin
	fig.root.position += sa - sr

## The sit clip is a chair sit: swing the thighs out over the horse's barrel and let the shins hang down her flanks.
## (The player: the soldiers rode their horses weird, knees up in front of them as if on a chair: the legs were turned
## from a script before the clip posed them, so the clip's chair sit won. Now a modifier on the skeleton turns them
## after the clip, every frame he's called astride; left a frame uncalled, his legs are his clip's again.)
static func astride(fig: ModelFigure) -> void:
	var sk := fig.skeleton
	if sk == null: return
	var m: Astride = null
	for c in sk.get_children(): if c is Astride: m = c; break
	if m == null:
		m = Astride.new(); m.fig_root = fig.root; sk.add_child(m)
		var legs := [["LeftUpLeg", "LeftLeg", "LeftFoot"], ["RightUpLeg", "RightLeg", "RightFoot"]]
		for i in 2: m.ids.append(legs[i].map(func(n): return sk.find_bone(n)))
	m.until = Engine.get_process_frames() + 2

class Astride extends SkeletonModifier3D:
	var fig_root: Node3D
	var ids: Array = []
	var until := 0
	func _process_modification_with_delta(_d: float) -> void: _legs()
	func _process_modification() -> void: _legs()
	func _legs() -> void:
		var sk := get_skeleton()
		if sk == null or fig_root == null or Engine.get_process_frames() > until: return
		var q := fig_root.global_transform.basis.get_rotation_quaternion()
		var fwd := q * Vector3(0, 0, 1); var side := q * Vector3(1, 0, 0)
		for i in 2:
			var sg := 1.0 if i == 0 else -1.0
			var b: Array = ids[i]
			if b.has(-1): continue
			# the thigh out and down over her barrel, a little forward; the shin straight down her flank, heel back
			NativeCamps._aim(sk, b[0], b[1], fwd * 0.38 + side * sg * 0.5 + Vector3(0, -0.78, 0))
			NativeCamps._aim(sk, b[1], b[2], fwd * -0.12 + side * sg * 0.1 + Vector3(0, -1.0, 0))

static func _aim(sk: Skeleton3D, bone: int, child: int, dir_world: Vector3) -> void:
	var inv := sk.global_transform.basis.inverse()
	var want := (inv * dir_world).normalized()
	var g := sk.get_bone_global_pose(bone); var cg := sk.get_bone_global_pose(child)
	var cur := (cg.origin - g.origin).normalized()
	if cur.length_squared() < 1e-6: return
	var rot := Quaternion(cur, want)
	var new_g := Basis(rot) * g.basis
	var parent := sk.get_bone_parent(bone)
	var pb := sk.get_bone_global_pose(parent).basis if parent >= 0 else Basis()
	sk.set_bone_pose_rotation(bone, (pb.inverse() * new_g).get_rotation_quaternion())

func _init(home: Vector3, world: World = null) -> void:
	for spec in [[240, 340, 5150], [400, 560, 7331], [560, 760, 9127]]:
		var avoid := list.map(func(c): return c.at)
		var c := Camp.new(home, spec[0], spec[1], spec[2], avoid, world)
		if c.at != null: list.append(c); add_child(c)
	at = list[0].at if list.size() else null
	raid = Raid.new(); add_child(raid)

func targets() -> Array:
	var out := []
	for c in list: out.append_array(c.targets())
	out.append_array(raid.targets())
	return out
func find_target(player: Player, reach: float):
	for c in list:
		var w = c.find_target(player, reach)
		if w != null: return w
	return raid.find_target(player, reach)
func damage(w: Dictionary, n: int, hooks: Dictionary, raid_hooks := {}) -> bool:
	if w.get("raider", false): return raid.damage(w, n, raid_hooks)
	for c in list: if w in c.warriors: return c.damage(w, n, hooks)
	return false
func on_land(x: float, z: float) -> bool: return list.any(func(c): return c.on_land(x, z))
func at_poles(x: float, z: float):
	for c in list: if c.at_poles(x, z): return c
	return null
## A camp at peace with you whose fire (x, z) is beside: where you can trade.
func fire_at(x: float, z: float, r := 5.0):
	for c in list: if c.peace_until > camp_day and Vector2(x - c.at.x, z - c.at.z).length() < r: return c
	return null
func save() -> Array: return list.map(func(c): return c.peace_until)
func load_state(d) -> void:
	if d == null: return
	for i in mini(d.size(), list.size()): list[i].peace_until = int(d[i])
func update(dt: float, player: Player, camera: Camera3D, hooks: Dictionary, raid_hooks := {}) -> void:
	for c in list: c.update(dt, player, camera, hooks)
	raid.update(dt, player, raid_hooks)
## Send a war party from the nearest camp down on the town, at the building target {id, name, door}. Never from a camp
## you're at peace with.
func start_raid(town_at: Vector3, target: Dictionary) -> bool:
	if raid.on or list.is_empty(): return false
	var c = list[0]
	for q in list: if q.at.distance_to(town_at) < c.at.distance_to(town_at): c = q
	if c.peace_until > camp_day: return false
	raid.start(town_at, c.at, target); return true

## One camp.
class Camp extends Node3D:
	var at = null
	var warriors: Array = []
	var arrows: Array = []
	var horses: Array = []
	var folk: Array = []
	## While the camp is at peace with you, someone by the fire welcomes you as you come in (once a visit).
	const WELCOME := ["Welcome back, friend. Sit by the fire.", "You are welcome here. Rest a while.", "Good to see you. Come, eat with us.", "Our fire is yours, friend."]
	var welcome_card: SayCard
	var welcomed := false
	var lodges: Array = []
	var alarm := "none" # none, warn, fight
	var alarm_t := 0.0
	var warn_shot := false
	var fight_anyway := false
	var peace_until := 0

	func _init(home: Vector3, r0: int, r1: int, seed: int, avoid: Array, world: World) -> void:
		var rng := PNoise.Mulberry32.new(seed)
		# the site: an open valley a good ride out, clear of the mountains and the water for a good way round
		var r := r0
		while r <= r1 and at == null:
			for k in 24:
				if at != null: break
				var a := (k / 24.0) * TAU + r * 0.01 + seed
				var x := home.x + cos(a) * r; var z := home.z + sin(a) * r
				if Terrain.is_water(x, z) or Terrain.range_at(x, z) > 0.005 or avoid.any(func(q): return Vector2(q.x - x, q.z - z).length() < 180.0): continue
				var ok := true
				for j in 12:
					if not ok: break
					var b := (j / 12.0) * TAU
					for d in [14.0, 30.0]:
						var xx: float = x + cos(b) * d; var zz: float = z + sin(b) * d
						if Terrain.is_water(xx, zz) or Terrain.range_at(xx, zz) > 0.05 or Terrain.region_at(xx, zz) == "water": ok = false
				if ok: at = Vector3(x, Terrain.get_height(x, z), z)
			r += 20
		if at == null: return
		if world: world.exclusions.append({"x": at.x, "z": at.z, "r": 42.0}) # (a clearing: no tree, bush or rock among the lodges)
		_rng = rng; _home = home; _seed = seed
		# (the rest, the lodges, horses and people, is made when you first come within sight: populate. Made here for all
		# three camps it cost ~2.7 s of the game's start, the player's ask: the game takes a long time to load up)

	var _rng: PNoise.Mulberry32
	var _home: Vector3
	var _seed := 0
	var populated := false
	## The camp's poles, lodges, picket, horses, warriors and folk, as they always stood (the same seeded draw, in the
	## same order), made the first time it's wanted.
	func populate() -> void:
		if populated or at == null: return
		populated = true
		# the boundary poles
		for i in 22:
			var a := (i / 22.0) * TAU; var x: float = at.x + cos(a) * R; var z: float = at.z + sin(a) * R
			if Terrain.is_water(x, z) or Terrain.range_at(x, z) > 0.2: continue
			var p := NativeCamps.marker_pole(_rng); p.position = Vector3(x, Terrain.get_height(x, z), z); p.rotation.y = -a; add_child(p)
		# the lodges round a cooking fire
		var spots := [[0, -7, "prop_tipi"], [6.5, -2, "prop_tipi_painted"], [-6.5, -2.5, "prop_tipi"], [3.5, 6, "prop_tipi_painted"], [-4, 5.5, "prop_tipi"],
			# (a second ring, the camp grown: the player's ask)
			[9.5, -10.5, "prop_tipi_painted"], [-10.5, -9.5, "prop_tipi"], [13.5, 3.0, "prop_tipi"], [-13.5, 3.5, "prop_tipi_painted"], [8.5, 12.0, "prop_tipi"], [-7.5, 12.5, "prop_tipi_painted"], [0.5, -15.5, "prop_tipi"]]
		for s in spots:
			var t := NativeCamps.prop(s[2], 4.4, true)
			var x: float = at.x + s[0]; var z: float = at.z + s[1]
			t.position = Vector3(x, Terrain.get_height(x, z), z); t.rotation.y = atan2(-s[0], -s[1]); add_child(t)
			lodges.append(Vector3(at.x + s[0] * 0.8, 0, at.z + s[1] * 0.8))
		var fire := NativeCamps.prop("prop_cookfire", 1.8); fire.position = Vector3(at.x, Terrain.get_height(at.x, at.z), at.z); add_child(fire)
		# the horse picket: a rail between two posts on the camp's edge, the horses tied along it
		var pa := atan2(_home.z - at.z, _home.x - at.x) + PI * 0.6
		var px: float = at.x + cos(pa) * 15.0; var pz: float = at.z + sin(pa) * 15.0; var side := pa + PI / 2.0
		for k in [-1.0, 1.0]:
			var post := NativeCamps._box(0.14, 1.3, 0.14, 0x6e4a2c); post.position = Vector3(px + cos(side) * k * 4.0, Terrain.get_height(px, pz) + 0.65, pz + sin(side) * k * 4.0); add_child(post)
		var rail := NativeCamps._box(8, 0.1, 0.1, 0x7a5232); rail.position = Vector3(px, Terrain.get_height(px, pz) + 1.15, pz); rail.rotation.y = -side; add_child(rail)
		for i in 3:
			var h := Puppet.new("horse", 1.7); var k := (i - 1) * 2.6
			var hx := px + cos(side) * k + cos(pa) * 1.6; var hz := pz + sin(side) * k + sin(pa) * 1.6
			h.group.position = Vector3(hx, Terrain.get_height(hx, hz), hz); add_child(h.group)
			horses.append({"puppet": h, "picket": Vector3(hx, 0, hz), "rider": null, "owner": null, "loose": 0.0, "looseA": null})
		for e in [["prop_drying_rack", 2.4, 3, -4.5], ["prop_travois", 3.0, -8, 2], ["prop_drum", 0.9, 1.6, 1.4], ["prop_bedroll", 1.2, -2.2, 2.2],
				["prop_drying_rack", 2.4, -11.5, -4.0], ["prop_travois", 3.0, 11.0, 8.0], ["prop_cookfire", 1.3, 9.0, -5.5], ["prop_cookfire", 1.3, -9.5, 8.5], ["prop_woodpile", 2.0, 4.5, -12.0]]:
			var p := NativeCamps.prop(e[0], e[1])
			if p == null: continue
			var x: float = at.x + e[2]; var z: float = at.z + e[3]; p.position = Vector3(x, Terrain.get_height(x, z), z); p.rotation.y = _rng.next() * 6.0; add_child(p)
		# the warriors, armed as in the reference art: spear and bow, bow, stone-headed club
		var kinds := [["folk_native_warrior", "spear"], ["folk_native_archer", "bow"], ["folk_native_hunter", "club"]]
		var fresh := [["cgc_warrior_1", "spear"], ["cgc_warrior_2", "club"], ["cgc_warrior_3", "bow"]] # (the player's new warriors, once made)
		var roll := []
		for i in kinds.size() * 2: roll.append(kinds[i % kinds.size()]) # (twice the web's three: the player's ask)
		for k in fresh: roll.append(k if ModelFigure.has_folk(k[0]) else kinds[roll.size() % kinds.size()]) # (and three more as the camps grew)
		for i in roll.size():
			var fig := ModelFigure.new(roll[i][0]); var arm: String = roll[i][1]
			if not fig.player or not fig.player.has_animation("run"): fig.borrow_clip("run", "folk_native_warrior")
			if arm != "club": fig.hands[0].add_child(NativeCamps.bow_mesh())
			if arm == "spear": fig.hold(NativeCamps.spear_mesh(), false, Transform3D(Basis(), Vector3(0, 0, -0.55))) # (held at its balance)
			if arm == "club": fig.hold(NativeCamps.club_mesh())
			var a := (i / float(roll.size())) * TAU; var rr: float = [9.0, 13.0, 17.0][i % 3]; var hm := Vector3(at.x + cos(a) * rr, 0, at.z + sin(a) * rr)
			fig.root.position = Vector3(hm.x, Terrain.get_height(hm.x, hm.z), hm.z); add_child(fig.root)
			warriors.append({"fig": fig, "arm": arm, "home": hm, "state": "patrol", "goal": hm, "t": _rng.next() * 3.0, "cool": 0.0, "hp": 9, "horse": null, "my_horse": null, "dead": 0.0, "hurt": 0.0, "mounting": false})
		# the camp's folk: about the lodges and the fire; at the first sign of a fight they gather out of the way
		var people := ["folk_native_woman", "folk_native_maiden", "folk_native_elder", "folk_native_grandfather", "folk_native_girl"]
		var men := [] # (the player's six new men about the camps: up to three to a camp, from those made, by the _seed)
		for i in 6:
			var nm := "cgc_native_%d" % (1 + (i + _seed) % 6)
			if ModelFigure.has_folk(nm) and men.size() < 3: men.append(nm)
		people.append_array(men)
		for nm in people:
			if not ModelFigure.has_folk(nm): continue
			var fig := ModelFigure.new(nm); var a := _rng.next() * 6.28
			var fp := Vector3(at.x + cos(a) * 3.0, 0, at.z + sin(a) * 3.0); fp.y = Terrain.get_height(fp.x, fp.z)
			fig.root.position = fp; add_child(fig.root)
			var kind: String = "man" if nm.begins_with("cgc_native_") else nm.replace("folk_native_", "")
			if kind == "elder": fig.hold(_cyl_static(), false, Transform3D(Basis(Vector3.RIGHT, 1.2), Vector3(0, 0, -0.45))) # (her walking staff, stood up in her fist)
			folk.append({"fig": fig, "kind": kind, "goal": fp, "t": _rng.next() * 4.0, "sit": false, "hiding": false,
				"speed": {"elder": 0.6, "grandfather": 0.7, "girl": 1.5}.get(kind, 1.0)})

	static func _cyl_static() -> MeshInstance3D: return NativeCamps._cyl(0.022, 0.028, 1.7, 0x8a6038, 0.35)

	static func wpos(w: Dictionary) -> Vector3: return w.fig.root.position

	## The warriors the player can strike: {pos, r, h, w} for arrows.
	func targets() -> Array:
		var out := []
		for w in warriors: if not w.dead: out.append({"pos": wpos(w), "r": 1.1 if w.horse != null else 0.55, "h": 3.0 if w.horse != null else 1.9, "w": w})
		return out
	func find_target(player: Player, reach: float):
		var f := player.forward(); var best = null; var bd := INF
		for w in warriors:
			if w.dead: continue
			var p := wpos(w); var dx := p.x - player.pos.x; var dz := p.z - player.pos.z; var d := sqrt(dx * dx + dz * dz)
			if d > reach + 0.8 or (d > 0.3 and (dx * f.x + dz * f.z) / d < 0.2): continue
			if d < bd: bd = d; best = w
		return best
	## A wound: an attack on them is a fight, wherever you stand; enough and he falls. True if he fell.
	func damage(w: Dictionary, n: int, hooks: Dictionary) -> bool:
		if w.dead: return false
		w.hp -= n; w.hurt = 0.3; peace_until = 0 # (an attack ends any peace a gift bought)
		if alarm != "fight":
			alarm = "fight"; alarm_t = 0.0; fight_anyway = true
			if hooks.has("on_fight"): hooks.on_fight.call()
		if w.hp > 0: return false
		w.dead = 0.001
		if w.horse != null: w.horse.rider = null; w.horse.loose = 6.0; w.horse = null
		if hooks.has("on_fall"): hooks.on_fall.call(w)
		return true
	func at_poles(x: float, z: float) -> bool: return at != null and absf(Vector2(x - at.x, z - at.z).length() - R) < 5.0
	## A gift left at the poles: peace on their land for days.
	func gift(days: int) -> void:
		peace_until = NativeCamps.camp_day + days
		if alarm != "fight": alarm = "none"
	func on_land(x: float, z: float) -> bool: return at != null and Vector2(x - at.x, z - at.z).length() < R

	func _turn(fig: ModelFigure, face: float, k: float) -> void:
		var d := face - fig.root.rotation.y; d = atan2(sin(d), cos(d)); fig.root.rotation.y += d * k

	## hooks: on_warn(), on_fight(), on_hit(damage), on_leave(), on_fall(w), on_shoot()
	func update(dt: float, player: Player, camera: Camera3D, hooks: Dictionary) -> void:
		if at == null: return
		if not populated:
			var c0 := camera.global_position
			if Vector2(c0.x - at.x, c0.z - at.z).length() > 220.0 and Vector2(player.pos.x - at.x, player.pos.z - at.z).length() > 220.0: return
			populate()
		if warriors.is_empty(): return
		var p := player.pos; var d_camp := Vector2(p.x - at.x, p.z - at.z).length()
		var cam := camera.global_position
		var near := Vector2(cam.x - at.x, cam.z - at.z).length() < 140.0
		visible = near and World.ground_ready(at.x, at.z) # (no floating over the flat sheet before the camp's ground is built)
		# the camp's mood: a trespasser warned, then fought, then let go once they've gone
		var inside := d_camp < R and not player.dead
		var peace := peace_until > NativeCamps.camp_day
		if peace and inside and not welcomed and folk.size():
			welcomed = true
			if welcome_card == null: welcome_card = SayCard.make(); add_child(welcome_card)
			welcome_card.say(WELCOME[randi() % WELCOME.size()], 3.0)
		if not inside and d_camp > R * 1.5: welcomed = false
		if welcome_card and folk.size(): welcome_card.tick(dt, (folk[0].fig as ModelFigure).root.global_position + Vector3(0, 2.5, 0))
		if inside and alarm == "none" and not peace: alarm = "warn"; alarm_t = 0.0; warn_shot = false
		if alarm != "none": alarm_t += dt
		if alarm == "warn" and inside and (alarm_t > 7.0 or d_camp < R * 0.55): # (stayed, or pushed on toward the lodges)
			alarm = "fight"
			if hooks.has("on_fight"): hooks.on_fight.call()
		if alarm != "none" and (d_camp > (R + 40.0 if fight_anyway else R + 6.0) or player.dead):
			if alarm == "fight" and hooks.has("on_leave"): hooks.on_leave.call()
			alarm = "none"; fight_anyway = false
		if not near: return
		var warner = null
		if alarm == "warn":
			for w in warriors: if warner == null or wpos(w).distance_to(p) < wpos(warner).distance_to(p): warner = w
		for w in warriors:
			var fig: ModelFigure = w.fig
			w.t -= dt; w.cool -= dt
			if w.horse != null: fig.root.position = w.horse.puppet.group.position
			if w.dead: # struck down: he folds over onto the grass, lies a while, and is gone (back another day)
				w.dead += dt; fig.root.rotation.x = -minf(1.0, w.dead / 0.6) * PI / 2.0 * 0.95; fig.play("idle", 0.2)
				var dp := wpos(w); dp.y = Terrain.get_height(dp.x, dp.z); fig.root.position = dp
				if w.dead > 40.0: w.dead = 0.0; w.hp = 9; fig.root.rotation.x = 0.0; fig.root.position = Vector3(w.home.x, Terrain.get_height(w.home.x, w.home.z), w.home.z)
				continue
			var pos := wpos(w)
			# to horse: in a fight a bowman runs to his horse and mounts; when it's over he rides back to the picket
			if alarm == "fight" and w.arm != "club" and w.horse == null:
				if w.my_horse == null:
					for q in horses: if q.owner == null: q.owner = w; w.my_horse = q; break
				var h = w.my_horse
				if h != null and h.rider == null:
					var hp: Vector3 = h.puppet.group.position
					if Vector2(hp.x - pos.x, hp.z - pos.z).length() < 1.6: w.horse = h; h.rider = w
					else: w.goal = Vector3(hp.x, 0, hp.z); w.mounting = true
			else: w.mounting = false
			if w.horse != null and alarm != "fight":
				var pk: Vector3 = w.horse.picket
				if Vector2(pk.x - pos.x, pk.z - pos.z).length() < 1.0: w.horse.rider = null; w.horse = null; fig.root.rotation.x = 0.0
			var dx := p.x - pos.x; var dz := p.z - pos.z; var dP := sqrt(dx * dx + dz * dz)
			var speed := 0.0; var face = null; var act = null; var direct := false
			if w.mounting: face = atan2(w.goal.x - pos.x, w.goal.z - pos.z); speed = 4.6; direct = true
			elif w.horse != null and alarm != "fight":
				var pk: Vector3 = w.horse.picket; face = atan2(pk.x - pos.x, pk.z - pos.z); speed = 3.0; w.goal = Vector3(pk.x, 0, pk.z); direct = true
			elif w.horse != null: # mounted: ride in to bowshot and circle, loosing from the saddle
				face = atan2(dx, dz)
				if dP > 14.0: speed = 8.0
				else: speed = 5.0; face += PI / 2.4
				if dP < 22.0 and w.cool <= 0.0: w.cool = 2.6; act = "Archery_Shot"; shoot(pos, p, randf() < 0.35, hooks)
			elif alarm == "fight":
				face = atan2(dx, dz)
				if (dP > 2.4) if w.arm == "club" else (dP > 16.0): speed = 4.6
				elif dP > 2.6:
					act = "Archery_Shot"
					if w.cool <= 0.0: w.cool = 3.0; shoot(pos, p, randf() < 0.4, hooks)
				else:
					act = "Attack"
					if w.cool <= 0.0:
						w.cool = 2.2
						NativeCamps.land_hit(hooks)
			elif w == warner:
				# out to meet you, stopping a stone's throw off; a signal to turn back, then an arrow at your feet
				face = atan2(dx, dz)
				if dP > 10.0: speed = 4.0
				else: act = "wave" if alarm_t < 4.5 else "idle"
				# the arrow at your feet once you've had a moment to turn back, from bowshot (he needn't be close: from a far
				# post he'd not reach you before the grace ran out, and the fight came with no warning shot)
				if not warn_shot and alarm_t > 3.0 and dP < 25.0:
					warn_shot = true; shoot(pos, p, false, hooks, true)
					if hooks.has("on_warn"): hooks.on_warn.call()
			else: # about the camp: from one spot to another, a pause, then on
				var g: Vector3 = w.goal; var gx := g.x - pos.x; var gz := g.z - pos.z; var gd := sqrt(gx * gx + gz * gz)
				if gd > 0.4: speed = 2.4 if alarm == "none" and pos.distance_to(at) > R * 0.6 else 1.2; face = atan2(gx, gz)
				elif w.t <= 0.0:
					var a := randf() * 6.28; var rr := 3.0 + randf() * 12.0
					w.goal = Vector3(at.x + cos(a) * rr, 0, at.z + sin(a) * rr); w.t = 3.0 + randf() * 6.0
			if speed > 0.0:
				if direct: # to the horse, or back to the picket
					var gx: float = w.goal.x - pos.x; var gz: float = w.goal.z - pos.z; var gl := maxf(1e-6, sqrt(gx * gx + gz * gz))
					pos.x += (gx / gl) * minf(speed * dt, gl); pos.z += (gz / gl) * minf(speed * dt, gl)
				elif w.horse != null: pos.x += sin(face) * speed * dt; pos.z += cos(face) * speed * dt
				else:
					var goal_mode: bool = alarm == "none" or (w != warner and alarm != "fight")
					var tx: float = (w.goal.x - pos.x) if goal_mode else dx; var tz: float = (w.goal.z - pos.z) if goal_mode else dz
					var tl := maxf(1e-6, sqrt(tx * tx + tz * tz))
					pos.x += (tx / tl) * speed * dt; pos.z += (tz / tl) * speed * dt
			pos.y = Terrain.get_height(pos.x, pos.z)
			fig.root.position = pos
			if face != null: _turn(fig, face, minf(1.0, dt * 8.0))
			if w.horse != null:
				# in the saddle: the horse goes where he goes; he sits her back, legs astride, the bow up when he looses
				w.horse.puppet.group.position = pos
				w.horse.puppet.update(dt, speed * 0.8, "walk" if speed > 0.2 else "idle", false, 0.0, 0.0)
				fig.play(act if act != null else "sit", 0.2)
				if act == null: NativeCamps.astride(fig)
				NativeCamps.seat(w.horse.puppet, fig)
			else:
				if act != null: fig.play(act, 0.2)
				elif speed > 3.0: fig.play("run", 0.2)
				elif speed > 0.2: fig.play("walk", 0.25)
				else: fig.play("idle", 0.4)
		# the horses: tied at the picket; a horse whose rider fell runs off a way, then wanders back
		for h in horses:
			if h.rider != null: continue
			var hp: Vector3 = h.puppet.group.position; var spd := 0.0
			if h.loose > 0.0:
				h.loose -= dt; spd = 5.0
				if h.looseA == null: h.looseA = randf() * 6.28
				hp.x += cos(h.looseA) * spd * dt; hp.z += sin(h.looseA) * spd * dt
			else:
				h.looseA = null
				var dx: float = h.picket.x - hp.x; var dz: float = h.picket.z - hp.z; var d := sqrt(dx * dx + dz * dz)
				if d > 0.3: spd = minf(1.4, d); hp.x += (dx / d) * spd * dt; hp.z += (dz / d) * spd * dt
			hp.y = Terrain.get_height(hp.x, hp.z); h.puppet.group.position = hp
			h.puppet.update(dt, spd * 0.8, "walk" if spd > 0.2 else "idle", false, atan2(cam.x - hp.x, cam.z - hp.z), 0.0)
		# the camp's folk
		for i in folk.size():
			var f: Dictionary = folk[i]; var fig: ModelFigure = f.fig
			fig.root.visible = not (NativeCamps.camp_abed and alarm != "fight") # (abed in the lodges till first light)
			if not fig.root.visible: continue
			f.t -= dt
			var fp := fig.root.position
			var speed := 0.0; var act = null
			if alarm == "fight" and not f.hiding: # they gather close by a lodge on the far side from the trouble, in the open
				f.hiding = true; f.sit = false
				var l: Vector3 = lodges[0]
				for q in lodges: if q.distance_to(fp) < l.distance_to(fp): l = q
				var ax: float = at.x - p.x; var az: float = at.z - p.z; var al := maxf(1e-6, sqrt(ax * ax + az * az)); var sd := i - 1
				f.goal = Vector3(l.x + (ax / al) * 3.2 - (az / al) * sd * 1.1, 0, l.z + (az / al) * 3.2 + (ax / al) * sd * 1.1)
			if alarm != "fight": f.hiding = false
			var gx: float = f.goal.x - fp.x; var gz: float = f.goal.z - fp.z; var gd := sqrt(gx * gx + gz * gz)
			if gd > 0.35:
				speed = f.speed * 1.6 if f.hiding else f.speed
				fp.x += (gx / gd) * speed * dt; fp.z += (gz / gd) * speed * dt
				_turn(fig, atan2(gx, gz), minf(1.0, dt * 6.0))
			elif not f.hiding and f.t <= 0.0:
				f.t = 5.0 + randf() * 9.0
				f.sit = randf() < {"elder": 0.8, "grandfather": 0.7, "woman": 0.4, "maiden": 0.3, "girl": 0.12}.get(f.kind, 0.4)
				if f.sit: var a := randf() * 6.28; f.goal = Vector3(at.x + cos(a) * 2.2, 0, at.z + sin(a) * 2.2)
				elif f.kind == "girl" and horses.size() and randf() < 0.45: # (off to see the horses)
					var hk: Vector3 = horses[randi() % horses.size()].picket; f.goal = Vector3(hk.x + (randf() - 0.5) * 3.0, 0, hk.z + (randf() - 0.5) * 3.0); f.t = 4.0 + randf() * 4.0
				elif f.kind == "girl": var a := randf() * 6.28; var rr := 4.0 + randf() * 11.0; f.goal = Vector3(at.x + cos(a) * rr, 0, at.z + sin(a) * rr); f.t = 2.0 + randf() * 4.0
				else: var l: Vector3 = lodges[randi() % lodges.size()]; var a := randf() * 6.28; f.goal = Vector3(l.x + cos(a) * 2.0, 0, l.z + sin(a) * 2.0)
			if gd <= 0.35 and f.sit and not f.hiding: act = "sit"; _turn(fig, atan2(at.x - fp.x, at.z - fp.z), minf(1.0, dt * 4.0))
			fp.y = Terrain.get_height(fp.x, fp.z); fig.root.position = fp
			if act != null: fig.play(act, 0.4)
			elif speed > 1.8: fig.play("walk", 0.2, 1.9)
			elif speed > 0.2: fig.play("walk", 0.25, maxf(0.6, speed / 1.2))
			else: fig.play("idle", 0.4)
		# arrows in flight
		for i in range(arrows.size() - 1, -1, -1):
			var a: Dictionary = arrows[i]; a.t += dt
			var k := minf(1.0, a.t / a.dur); var m: Node3D = a.mesh
			var mp: Vector3 = a.from.lerp(a.to, k); mp.y += sin(k * PI) * a.arc; m.position = mp
			if k < 1.0:
				var ahead: Vector3 = a.from.lerp(a.to, minf(1.0, k + 0.05)); ahead.y = mp.y + cos(k * PI) * a.arc * 0.2
				if ahead.distance_squared_to(mp) > 1e-8: m.look_at(ahead, Vector3.UP, true)
			if k >= 1.0 and not a.landed:
				a.landed = true
				if a.hit:
					NativeCamps.land_hit(hooks)
					m.queue_free(); arrows.remove_at(i); continue
			if a.t > a.dur + 6.0: m.queue_free(); arrows.remove_at(i)

	## Loose an arrow from a warrior at the player: a hit, a near miss, or (warning) into the ground at their feet.
	func shoot(from: Vector3, p: Vector3, hit: bool, hooks: Dictionary, warning := false) -> void:
		var m := NativeCamps.arrow_mesh(); get_parent().add_child(m)
		var src := Vector3(from.x, from.y + 1.4, from.z)
		var off := 1.6 if warning else (0.0 if hit else 1.2 + randf())
		var ang := randf() * 6.28; var dx := p.x - from.x; var dz := p.z - from.z; var d := maxf(1e-6, sqrt(dx * dx + dz * dz))
		var to: Vector3
		if warning:
			var wx := p.x - (dx / d) * off; var wz := p.z - (dz / d) * off
			to = Vector3(wx, Terrain.get_height(wx, wz) + 0.2, wz)
		else: to = Vector3(p.x + cos(ang) * off, p.y + (1.2 if hit else 0.2), p.z + sin(ang) * off)
		m.position = src
		arrows.append({"mesh": m, "from": src, "to": to, "t": 0.0, "dur": maxf(0.25, d / 24.0), "arc": d * 0.04, "hit": hit, "landed": false})
		if hooks.has("on_shoot"): hooks.on_shoot.call()

## A raid on the town (natives.js Raid). Now and then a war party of three rides down out of the hills from the nearest
## camp, straight for one of the mended buildings, and circles it whooping and loosing arrows. Bring down two of the
## three and the last wheels away; let them circle long enough (22 s) and they wreck the place, so it stands run-down
## again and wants mending (at half the cost). hooks: on_sack(id), on_repelled(), on_hit(damage), on_shoot(), on_fall(w).
class Raid extends Node3D:
	var on := false
	var riders: Array = []
	var arrows: Array = []
	var from := Vector3.ZERO
	var target := {}
	var t := 0.0
	var sack_t := 0.0
	var town := Vector3.ZERO
	const LEAVE := 150.0 ## (they only fall on the town while you're there; go off and they ride away)
	var fleeing := false

	func start(town_at: Vector3, camp_at: Vector3, tgt: Dictionary) -> void:
		var dx := camp_at.x - town_at.x; var dz := camp_at.z - town_at.z; var d := maxf(1e-6, sqrt(dx * dx + dz * dz))
		from = Vector3(town_at.x + (dx / d) * 110.0, 0, town_at.z + (dz / d) * 110.0) # (out of the hills on the camp's side of town)
		target = tgt; on = true; t = 0.0; sack_t = 0.0; fleeing = false; town = town_at
		var kinds := ["folk_native_warrior", "folk_native_archer", "folk_native_hunter"]
		for i in 3:
			var fig := ModelFigure.new(kinds[i]); fig.hands[0].add_child(NativeCamps.bow_mesh())
			var h := Puppet.new("horse", 1.7)
			var side := (i - 1) * 4.0; var x := from.x - (dz / d) * side; var z := from.z + (dx / d) * side
			h.group.position = Vector3(x, Terrain.get_height(x, z), z); add_child(h.group); add_child(fig.root)
			fig.root.position = h.group.position
			riders.append({"fig": fig, "raider": true, "horse": {"puppet": h}, "loose": null, "hp": 7, "dead": 0.0, "cool": 1.0 + i, "ang": (i / 3.0) * TAU, "circling": false})

	static func rpos(w: Dictionary) -> Vector3: return w.fig.root.position
	func targets() -> Array:
		var out := []
		for w in riders: if not w.dead: out.append({"pos": rpos(w), "r": 1.1, "h": 3.0, "w": w})
		return out
	func find_target(player: Player, reach: float):
		var best = null; var bd := reach + 1.2
		for w in riders:
			if w.dead: continue
			var d := Vector2(rpos(w).x - player.pos.x, rpos(w).z - player.pos.z).length()
			if d < bd: bd = d; best = w
		return best
	func damage(w: Dictionary, n: int, hooks: Dictionary) -> bool:
		if w.dead: return false
		w.hp -= n
		if w.hp > 0: return false
		w.dead = 0.001; w.loose = w.horse; w.horse = null # (his horse bolts riderless back to the hills)
		if hooks.has("on_fall"): hooks.on_fall.call(w)
		if not fleeing and riders.filter(func(q): return not q.dead).size() <= 1:
			fleeing = true
			if hooks.has("on_repelled"): hooks.on_repelled.call()
		return true
	func end() -> void:
		for w in riders:
			w.fig.root.queue_free()
			var h = w.horse if w.horse != null else w.loose
			if h != null: h.puppet.group.queue_free()
		for a in arrows: a.mesh.queue_free()
		riders = []; arrows = []; on = false

	func shoot(src_pos: Vector3, p: Vector3, hit: bool, hooks: Dictionary) -> void:
		var m := NativeCamps.arrow_mesh(); add_child(m)
		var src := Vector3(src_pos.x, src_pos.y + 1.4, src_pos.z)
		var off := 0.0 if hit else 1.2 + randf(); var ang := randf() * 6.28
		var d := maxf(1e-6, Vector2(p.x - src_pos.x, p.z - src_pos.z).length())
		var to := Vector3(p.x + cos(ang) * off, p.y + (1.2 if hit else 0.2), p.z + sin(ang) * off)
		m.position = src
		arrows.append({"mesh": m, "from": src, "to": to, "t": 0.0, "dur": maxf(0.25, d / 24.0), "arc": d * 0.04, "hit": hit, "landed": false})
		if hooks.has("on_shoot"): hooks.on_shoot.call()

	func update(dt: float, player: Player, hooks: Dictionary) -> void:
		if not on: return
		t += dt
		var door: Vector3 = target.door; var p := player.pos
		if not fleeing and Vector2(p.x - town.x, p.z - town.z).length() > LEAVE: # (you've gone: with no one to stand against them they ride off, and the town is spared)
			fleeing = true
			if hooks.has("on_off"): hooks.on_off.call()
		if not fleeing:
			if riders.any(func(w): return not w.dead and w.circling): sack_t += dt
			if sack_t > 22.0: # (they've had long enough at it)
				fleeing = true
				if hooks.has("on_sack"): hooks.on_sack.call(target.id)
		var gone := 0
		for w in riders:
			var fig: ModelFigure = w.fig; var fr := fig.root
			if w.dead: # thrown from the saddle: he lies a while in the dust, then is gone
				w.dead += dt; fr.rotation.x = -minf(1.0, w.dead / 0.6) * PI / 2.0 * 0.95; fig.play("idle", 0.2)
				var dp := fr.position; dp.y = Terrain.get_height(dp.x, dp.z); fr.position = dp
				if w.loose != null:
					var hp: Vector3 = w.loose.puppet.group.position; var a := atan2(from.z - hp.z, from.x - hp.x)
					hp.x += cos(a) * 7.0 * dt; hp.z += sin(a) * 7.0 * dt; hp.y = Terrain.get_height(hp.x, hp.z); w.loose.puppet.group.position = hp
					w.loose.puppet.update(dt, 5.6, "walk", false, 0.0, 0.0)
				if w.dead > 25.0:
					fr.visible = false
					if w.loose != null: w.loose.puppet.group.visible = false
					gone += 1
				continue
			w.cool -= dt
			var pos: Vector3 = w.horse.puppet.group.position
			var gx: float; var gz: float; var speed: float; var act = null
			if fleeing: gx = from.x; gz = from.z; speed = 10.0
			else:
				var dd := Vector2(door.x - pos.x, door.z - pos.z).length()
				if not w.circling and dd < 9.0: w.circling = true
				if w.circling: w.ang += dt * 0.55; gx = door.x + cos(w.ang) * 7.0; gz = door.z + sin(w.ang) * 7.0; speed = 5.5
				else: gx = door.x; gz = door.z; speed = 9.0
				var dP := Vector2(p.x - pos.x, p.z - pos.z).length()
				if dP < 24.0 and w.cool <= 0.0 and not player.dead: w.cool = 2.4 + randf(); act = "Archery_Shot"; shoot(pos, p, randf() < 0.4, hooks)
			var tx := gx - pos.x; var tz := gz - pos.z; var tl := maxf(1e-6, sqrt(tx * tx + tz * tz)); var step := minf(speed * dt, tl)
			pos.x += (tx / tl) * step; pos.z += (tz / tl) * step; pos.y = Terrain.get_height(pos.x, pos.z)
			if fleeing and tl < 3.0: fr.visible = false; w.horse.puppet.group.visible = false; gone += 1; continue
			fr.position = pos; w.horse.puppet.group.position = pos
			w.horse.puppet.update(dt, speed * 0.8, "walk", false, 0.0, 0.0)
			fig.play(act if act != null else "sit", 0.2)
			if act == null: NativeCamps.astride(fig)
			NativeCamps.seat(w.horse.puppet, fig)
		for i in range(arrows.size() - 1, -1, -1):
			var a: Dictionary = arrows[i]; a.t += dt
			var k := minf(1.0, a.t / a.dur); var m: Node3D = a.mesh
			var mp: Vector3 = a.from.lerp(a.to, k); mp.y += sin(k * PI) * a.arc; m.position = mp
			if k < 1.0:
				var ahead: Vector3 = a.from.lerp(a.to, minf(1.0, k + 0.05)); ahead.y = mp.y + cos(k * PI) * a.arc * 0.2
				if ahead.distance_squared_to(mp) > 1e-8: m.look_at(ahead, Vector3.UP, true)
			if k >= 1.0 and not a.landed:
				a.landed = true
				if a.hit:
					NativeCamps.land_hit(hooks)
					m.queue_free(); arrows.remove_at(i); continue
			if a.t > a.dur + 6.0: m.queue_free(); arrows.remove_at(i)
		if gone >= riders.size() or t > 240.0: end()
