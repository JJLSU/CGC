class_name Enemies
extends Node3D
## enemies.js: guardians from the old tales watch over treasure, not the whole countryside. Dust-devil coyotes keep
## the iron veins, an old bramble boar each wild-hive grove, and the wild lands' keepers (hodag, wampus cat, sidehill
## gouger, hidebehind) lie in wait by theirs. They patrol near their site, chase only so far from it, wind up (a red
## "!" badge, a growl) and lunge to bite or gore, and fold flat when beaten; a beaten guardian stays gone. A peace
## offering makes a site's guardians doze ("z z") till the next morning.

const WINDUP := 0.5
const GUARDS := {
	"coyote": {"name": "Dust-devil coyote", "hp": 6, "dmg": 9, "speed": 6.2, "aggro": 9.0, "leash": 12.0, "reach": 1.5, "cooldown": 1.2, "pelt": [1, 2], "scale": 1.0, "top": 1.1},
	"boar": {"name": "Old bramble boar", "hp": 12, "dmg": 16, "speed": 5.4, "aggro": 8.0, "leash": 11.0, "reach": 1.7, "cooldown": 1.6, "pelt": [2, 3], "scale": 1.15, "top": 1.25},
	"hodag": {"name": "Hodag", "hp": 16, "dmg": 18, "speed": 4.6, "aggro": 7.0, "leash": 12.0, "reach": 1.9, "cooldown": 1.8, "pelt": [2, 3], "scale": 1.3, "top": 1.6, "lurk": "flat"},
	"wampus": {"name": "Wampus cat", "hp": 10, "dmg": 14, "speed": 7.6, "aggro": 10.0, "leash": 15.0, "reach": 1.7, "cooldown": 1.1, "pelt": [2, 3], "scale": 1.2, "top": 1.25, "lurk": "flat"},
	# the bears (the player's black bear and grizzly): a black bear at many a wild-hive grove (they come for the honey),
	# a grizzly at the groves up in the pines; slower than you on the flat, but they hit hard and take some felling
	"bear": {"name": "Black bear", "hp": 18, "dmg": 18, "speed": 5.0, "aggro": 8.0, "leash": 13.0, "reach": 1.9, "cooldown": 1.7, "pelt": [3, 4], "scale": 1.0, "top": 1.5},
	"grizzly": {"name": "Grizzly", "hp": 28, "dmg": 26, "speed": 5.4, "aggro": 9.0, "leash": 14.0, "reach": 2.1, "cooldown": 1.9, "pelt": [4, 5], "scale": 1.0, "top": 1.8},
	"gouger": {"name": "Sidehill gouger", "hp": 9, "dmg": 11, "speed": 5.0, "aggro": 8.0, "leash": 11.0, "reach": 1.6, "cooldown": 1.4, "pelt": [1, 2], "scale": 1.05, "top": 1.35},
	"hidebehind": {"name": "Hidebehind", "hp": 8, "dmg": 15, "speed": 6.6, "aggro": 6.0, "leash": 10.0, "reach": 1.6, "cooldown": 1.3, "pelt": [1, 2], "scale": 1.0, "top": 2.5, "lurk": "unseen"},
}

var world: World
var list: Array = []
var calm_by_site := {}   ## site key -> clock (day + time) till which its guardians doze (saved with the game)
var rng := PNoise.Mulberry32.new(911)
var clock := 0.0
var on_player_hit: Callable  ## (damage, enemy)
var on_windup: Callable      ## (enemy): a growl before the lunge
var on_ambush: Callable      ## (enemy): a keeper springs up
static var _kits := {}

static func _kit(k: String) -> Array:
	if not _kits.has(k):
		var pts := PackedVector2Array()
		if k == "zz": pts = PackedVector2Array([Vector2(-0.22, 0), Vector2(0.22, 0), Vector2(0.24, 0.2), Vector2(-0.24, 0.2)])
		else:
			for i in 18:
				var a := (i / 18.0) * TAU
				pts.append(Vector2(cos(a) * 0.2, 0.2 + sin(a) * 0.2))
		_kits[k] = [CardMesh.build(pts, 0.015 if k == "zz" else 0.02), PaperMats.card(load("res://assets/baked/wildlife/%s.png" % k), {"flip": true, "snow": 0.0})]
	return _kits[k]

func _init(w: World) -> void:
	world = w
	world.on_site_load = spawn_site
	world.on_site_unload = despawn_site

func spawn_site(site: Dictionary) -> void:
	var kind: String = site.get("guard", "") if site.get("guard", "") != "" else (Enemies.grove_guard(site) if site.kind == "grove" else "coyote")
	if site.kind == "landmark" or not GUARDS.has(kind): return
	for i in int(site.get("guards", 0)):
		var key := "%s:g%d" % [site.key, i]
		if world.destroyed.has(key): continue
		var a: float = (float(i) / site.guards) * TAU; var d := 3.0 + rng.next() * 2.0
		var x: float = site.x + cos(a) * d; var z: float = site.z + sin(a) * d
		var spec: Dictionary = GUARDS[kind]
		var pup := Puppet.new(kind, spec.scale, "boar" if kind == "gouger" else "")
		if kind == "gouger" and pup.model: _gougerize(pup)
		if kind == "hidebehind": _meshy_hidebehind(pup)
		var wk := _kit("warn"); var warn := MeshInstance3D.new(); warn.mesh = wk[0]; warn.material_override = wk[1]
		warn.position = Vector3(0.3, spec.top, 0.06); warn.visible = false; pup.flip.add_child(warn)
		var zk := _kit("zz"); var zz := MeshInstance3D.new(); zz.mesh = zk[0]; zz.material_override = zk[1]
		zz.position = Vector3(0.2, spec.top - 0.2, 0.06); zz.visible = false; pup.flip.add_child(zz)
		pup.group.position = Vector3(x, Terrain.get_height(x, z), z)
		add_child(pup.group)
		var e := {"kind": kind, "key": key, "site": site, "spec": spec, "puppet": pup, "hp": spec.hp, "state": "guard", "timer": rng.next() * 3.0,
			"target": Vector3(x, 0, z), "dir": Vector3(1, 0, 0), "speed": 0.0, "cool": 0.0, "lunge": 0.0, "hurt": 0.0, "dying": 0.0, "windup": 0.0,
			"warn": warn, "zz": zz, "calmUntil": calm_by_site.get(site.key, 0.0), "rise": 0.0}
		if spec.has("lurk"): # lying in wait: pressed flat on the page, or not there at all
			e.state = "lurk"
			if spec.lurk == "flat": pup.set_fold(0.0)
			else: pup.group.visible = false
		list.append(e)

## The Hidebehind as the player's Meshy one (lanky, shaggy, bear-eared, long-clawed), 2.4 m tall, in place of the
## paper puppet's parts: turned so its face leads the way the puppet goes (the puppet's +x), still as a statue (it only
## ever moves when you aren't looking).
const HIDEBEHIND := "res://assets/models/props/animal_hidebehind.glb"
static func _meshy_hidebehind(pup: Puppet) -> void:
	if not ResourceLoader.exists(HIDEBEHIND): return
	for c in pup.rig.get_children(): if c is Node3D: (c as Node3D).visible = false
	var m := ModelBake.still(HIDEBEHIND, 2.4, 1); m.rotation.y = PI / 2.0
	m.scale /= pup.rig.scale.x # (the rig carries the guard's scale already)
	pup.rig.add_child(m)

## Who keeps a wild-hive grove: a grizzly up in the pines; elsewhere a black bear at about half of them (by the
## site, so it's always the same one), else the old bramble boar.
static func grove_guard(site: Dictionary) -> String:
	if not ResourceLoader.exists("res://assets/models/animals/animal_bear_black.glb"): return "boar"
	Terrain.land_at(site.x, site.z)
	if Terrain.L_w.get("pines", 0.0) > 0.5 and ResourceLoader.exists("res://assets/models/animals/animal_grizzly.glb"): return "grizzly"
	return "bear" if absi(hash(String(site.key))) % 2 == 0 else "boar"

func despawn_site(site: Dictionary) -> void:
	for e in list.duplicate(): if e.site.key == site.key: remove(e)

func remove(e: Dictionary) -> void:
	e.puppet.group.queue_free(); list.erase(e)

static func pos(e: Dictionary) -> Vector3: return e.puppet.group.position

## The guardian the farmer would hit: the nearest awake one in front within reach.
func find_target(player: Player, reach: float):
	var f := player.forward()
	var best = null; var bd := INF
	for e in list:
		if e.dying or is_calm(e, clock): continue # (never strike a dozing guardian)
		var p := pos(e); var dx := p.x - player.pos.x; var dz := p.z - player.pos.z; var d := sqrt(dx * dx + dz * dz)
		if d > reach + 0.6 or absf(p.y - player.pos.y) > 2.0: continue
		if d > 0.3 and (dx * f.x + dz * f.z) / d < 0.2: continue
		if d < bd: bd = d; best = e
	return {"enemy": best, "dist": bd} if best != null else null

## Hit a guardian. Returns {killed, loot (pelts)}.
func damage(e: Dictionary, amount: int, from: Vector3) -> Dictionary:
	e.hp -= amount; e.hurt = 0.3; e.state = "chase"
	var p := pos(e); var dx := p.x - from.x; var dz := p.z - from.z; var d := sqrt(dx * dx + dz * dz)
	if d == 0.0: d = 1.0
	p.x += (dx / d) * 0.5; p.z += (dz / d) * 0.5; e.puppet.group.position = p # (knocked back a little)
	if e.hp > 0: return {"killed": false}
	e.dying = 0.001
	world.destroyed[e.key] = true
	var a: int = e.spec.pelt[0]; var b: int = e.spec.pelt[1]
	return {"killed": true, "loot": a + floori(rng.next() * (b - a + 1))}

## A peace offering: every guardian at this one's site dozes till the next morning (clock: day + time).
func calm(e: Dictionary, now: float) -> void:
	var until := floorf(now) + 1.25
	calm_by_site[e.site.key] = until
	for g in list:
		if g.site.key == e.site.key and not g.dying: g.calmUntil = until; g.state = "guard"; g.windup = 0.0; g.lunge = 0.0; g.warn.visible = false

func is_calm(e: Dictionary, now: float) -> bool: return now < e.calmUntil

## The nearest awake guardian within r (for offering it something), or null.
func awake_near(p: Vector3, now: float, r := 3.6):
	var best = null; var bd := r
	for e in list:
		if e.dying or is_calm(e, now): continue
		var d := Vector2(pos(e).x - p.x, pos(e).z - p.z).length()
		if d < bd: bd = d; best = e
	return best

func update(dt: float, player: Player, camera: Camera3D, now := 0.0) -> void:
	clock = now
	var p := player.pos
	var cam := camera.global_position
	var cam_yaw := atan2(cam.x - p.x, cam.z - p.z)
	var cam_right := Vector3(cos(cam_yaw), 0, -sin(cam_yaw))
	var ms := Time.get_ticks_msec()
	for e in list.duplicate():
		var pup: Puppet = e.puppet
		var ep := pos(e)
		var yaw_to_cam := atan2(cam.x - ep.x, cam.z - ep.z)
		if e.dying: # folds flat onto the page along its creases, then leaves it
			e.dying += dt
			pup.set_fold(1.0 - minf(1.0, e.dying / 0.5) ** 2)
			if e.dying > 1.4: remove(e)
			continue
		var s: Dictionary = e.spec
		if is_calm(e, now):
			# dozing by the treasure: settled low, legs tucked, chin down, a "z z" bobbing over its head
			pup.update(dt, 0.0, "idle", e.dir.dot(cam_right) < 0.0, yaw_to_cam, 0.0)
			if pup.model == null: pup.rig.position.y -= 0.12 * s.scale
			for l in pup.legs: l.rotation.z = -1.35 if l.position.x > 0 else 1.35
			pup.head.rotation.z = -0.35 + sin(ms * 0.0012) * 0.03
			e.zz.visible = true; e.zz.position.y = s.top - 0.2 + sin(ms * 0.002) * 0.05
			pup.flip.rotation.x = 0.0; pup.set_fold(1.0)
			continue
		e.zz.visible = false
		var to_p := Vector3(p.x - ep.x, 0, p.z - ep.z)
		var dist := to_p.length()
		# lying in wait: still as paper till you're close, then up it springs on its hinge
		if e.state == "lurk":
			if dist < s.aggro * 0.75 and not player.dead:
				e.state = "rise"; e.rise = 0.0; pup.group.visible = true; e.dir = to_p.normalized()
				if on_ambush.is_valid(): on_ambush.call(e)
			else:
				if s.lurk == "flat": pup.update(dt, 0.0, "idle", false, yaw_to_cam, 0.0)
				continue
		if e.state == "rise":
			e.rise += dt
			var k := Props.spring_rise(e.rise * 1.1)
			pup.set_fold(k) # (unfolds up off the page with a springy overshoot)
			pup.update(dt, 0.0, "attack", e.dir.dot(cam_right) < 0.0, yaw_to_cam, maxf(0.0, 1.0 - e.rise * 2.0) * 0.6)
			if s.get("lurk", "") == "unseen": pup.group.scale = Vector3.ONE * minf(1.0, 0.3 + k * 0.7)
			if e.rise > 0.8: e.state = "chase"; e.timer = 0.0; pup.set_fold(1.0); pup.group.scale = Vector3.ONE
			continue
		var from_home := Vector2(ep.x - e.site.x, ep.z - e.site.z).length()
		var player_from_home := Vector2(p.x - e.site.x, p.z - e.site.z).length()
		e.cool = maxf(0.0, e.cool - dt); e.hurt = maxf(0.0, e.hurt - dt); e.timer -= dt
		# decide
		if player.dead: e.state = "return"
		elif e.state == "guard" and dist < s.aggro: e.state = "chase"; e.timer = 0.0
		if (e.state == "chase" or e.state == "attack") and (player_from_home > s.leash or from_home > s.leash + 4.0): e.state = "return"
		if e.state == "return" and from_home < 3.0: e.state = "guard"; e.timer = 1.0
		if e.state == "chase" and dist < s.reach: e.state = "attack"
		if e.state == "attack" and dist > s.reach + 0.6: e.state = "chase"
		# act
		var speed := 0.0
		if e.state == "guard":
			if e.timer <= 0.0: # pace round the treasure
				var a := rng.next() * TAU; var d := 1.5 + rng.next() * 4.0
				e.target = Vector3(e.site.x + cos(a) * d, 0, e.site.z + sin(a) * d)
				e.timer = 3.0 + rng.next() * 4.0
			var to := Vector3(e.target.x - ep.x, 0, e.target.z - ep.z)
			if to.length() > 0.4: e.dir = to.normalized(); speed = 1.2
		elif e.state == "chase": e.dir = to_p.normalized(); speed = s.speed
		elif e.state == "return": e.dir = Vector3(e.site.x - ep.x, 0, e.site.z - ep.z).normalized(); speed = s.speed * 0.6
		elif e.state == "attack":
			e.dir = to_p.normalized()
			# a readable wind-up before every lunge: it rears back, the red "!" pops up, a growl; step away to dodge
			if e.cool <= 0.0 and e.windup <= 0.0 and e.lunge <= 0.0:
				e.windup = WINDUP; e.warn.visible = true
				if on_windup.is_valid(): on_windup.call(e)
		if e.windup > 0.0:
			e.windup -= dt
			if e.windup <= 0.0 or e.state != "attack":
				e.warn.visible = false
				if e.state == "attack": e.cool = s.cooldown; e.lunge = 1.0
				e.windup = 0.0
		# the lunge: snaps forward, and lands the hit at its peak
		if e.lunge > 0.0:
			var before: float = e.lunge
			e.lunge = maxf(0.0, e.lunge - dt * 3.2)
			if before > 0.55 and e.lunge <= 0.55 and dist < s.reach + 0.5 and not player.dead and on_player_hit.is_valid(): on_player_hit.call(s.dmg, e)
		e.speed += (speed - e.speed) * minf(1.0, dt * 7.0)
		if e.speed > 0.01:
			var nx: float = ep.x + e.dir.x * e.speed * dt; var nz: float = ep.z + e.dir.z * e.speed * dt
			if not Terrain.is_water(nx, nz): ep.x = nx; ep.z = nz
		ep.y = Terrain.get_height(ep.x, ep.z)
		pup.group.position = ep
		var left: bool = e.dir.dot(cam_right) < 0.0
		var lunge_amt: float = (-0.5 * (1.0 - e.windup / WINDUP)) if e.windup > 0.0 else (sin(minf(1.0, 1.0 - e.lunge) * PI) * (1.0 if e.lunge > 0.0 else 0.0))
		if e.warn.visible: e.warn.scale = Vector3.ONE * (1.0 + sin((WINDUP - e.windup) * 30.0) * 0.08) # (the badge quivers)
		pup.update(dt, e.speed, "attack" if e.state == "attack" else ("chase" if e.state == "chase" else "idle"), left, yaw_to_cam, lunge_amt)
		pup.flip.rotation.x = sin(e.hurt * 40.0) * 0.08 if e.hurt > 0.0 else 0.0 # (a flinch when struck)

## The sidehill gouger wears the bramble boar's model, dyed a shaggy rust red, with its uphill (left) legs drawn short
## (0.66, the upper front leg and the rear leg's first bone) so on level ground it lists like a barn in a gale, as the
## tale says: the body rolled -0.6 rad and dropped 0.1 so its paws stay on the ground.
static func _gougerize(pup: Puppet) -> void:
	var sks := pup.model.find_children("*", "Skeleton3D", true, false)
	if sks.size():
		var sk := sks[0] as Skeleton3D
		var ids := PackedInt32Array()
		for names in [["frontUpr.L", "frontUpr_L", "frontUprL"], ["rearLeg.L_01", "rearLeg_L_01", "rearLegL_01"]]: # (three.js drops the dot)
			for n in names:
				var b := sk.find_bone(n)
				if b >= 0: ids.append(b); break
		if ids.size() == 2:
			var lop := LopLegs.new(); lop.bones = ids; sk.add_child(lop)
			pup.lop = {"roll": -0.6, "drop": 0.1}
	for mi in pup.model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for i in m.mesh.get_surface_count():
			var mat := m.get_surface_override_material(i)
			if mat is ShaderMaterial:
				var c := (mat as ShaderMaterial).duplicate() as ShaderMaterial
				var al: Color = c.get_shader_parameter("albedo") if c.get_shader_parameter("albedo") != null else Color.WHITE
				c.set_shader_parameter("albedo", Color(al.r * 1.22, al.g * 0.7, al.b * 0.52, al.a))
				m.set_surface_override_material(i, c)
