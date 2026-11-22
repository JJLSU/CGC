class_name Hunting
extends Node3D
## hunting.js: the bow and the guns. Hold the button to draw (or raise and steady a gun): a paper reticle stands
## fixed on screen a little above Jim, wide at first and tightening as you draw, gold while game is under it in range
## with a clear line, grey with a cross when something's in the way. Let go and the arrow (or bullet) flies to what's
## under it: the deer (rabbit, turkey, bison) if one is, else the ground there, as far as the draw carries. A miss
## thunks into a trunk or a rock, or the turf, and quivers there. A struck beast folds down; walk up to dress it.

const G := 9.8
const RET_Y := 0.2 # (the reticle's height on screen in NDC: a little above the middle, where Jim stands)
const TRUNKS := ["pine", "maple", "snag", "birch", "goldtree", "sagetree", "appletree"]
const ROCKS := ["rock", "ore", "quartz", "silver", "geode", "amber"]
const BOW := {"draw": 0.9, "range0": 12.0, "range1": 26.0, "spread": 0.07, "speed0": 13.0, "speed1": 15.0, "dmg": 6, "bullet": false}
const REVOLVER := {"draw": 0.35, "range0": 18.0, "range1": 14.0, "spread": 0.05, "speed0": 70.0, "speed1": 20.0, "dmg": 5, "bullet": true}
const RIFLE := {"draw": 1.1, "range0": 30.0, "range1": 45.0, "spread": 0.06, "speed0": 90.0, "speed1": 50.0, "dmg": 12, "bullet": true}
## the wild game: chest height h, width to an arrow (r, hit), how tall (top), how much it takes (hp)
const GAME := {"deer": {"r": 0.55, "h": 0.8, "hit": 0.75, "top": 1.6, "hp": 1}, "rabbit": {"r": 0.32, "h": 0.25, "hit": 0.38, "top": 0.55, "hp": 1},
	"bison": {"r": 1.0, "h": 1.0, "hit": 1.15, "top": 2.1, "hp": 12}, "turkey": {"r": 0.4, "h": 0.45, "hit": 0.5, "top": 0.95, "hp": 1}}

var arrows: Array = []
var puffs: Array = []
var cool := 0.0
var charge := 0.0
var target = null
var blocked := false
var ground_at = null
var aim_dir = null
var cam: Camera3D
var reticle: Reticle
var on_hit: Callable
var on_thunk: Callable
var on_wound: Callable
var on_target: Callable
var targets: Callable   ## () -> [{pos, r, h, ...}]: the guardians and, once it's a fight, the warriors

## The paper reticle: a cream ring between two ink circles, ticks, a red fill arc for the draw; gold on game, grey
## with a cross when blocked.
class Reticle extends Control:
	var k := 0.0
	var on := false
	var blocked := false
	func _draw() -> void:
		var s := size.x / 100.0
		var c := size / 2.0
		var ring := Color("a89a86") if blocked else (Color("f0c048") if on else Color("efe2c4"))
		var fill := Color("7a6a58") if blocked else (Color("d89a20") if on else Color("a8352a"))
		var ink := Color("4a3426")
		draw_arc(c + Vector2(1, 2) * s, 34 * s, 0, TAU, 48, Color(0.24, 0.16, 0.08, 0.35), 5 * s) # (the drop shadow)
		draw_arc(c, 34 * s, 0, TAU, 48, ring, 5 * s)
		draw_arc(c, 37 * s, 0, TAU, 48, ink, 2 * s); draw_arc(c, 31 * s, 0, TAU, 48, ink, 2 * s)
		for d in [Vector2(0, -1), Vector2(0, 1), Vector2(-1, 0), Vector2(1, 0)]: draw_line(c + d * 46 * s, c + d * 26 * s, ink, 3 * s)
		draw_circle(c, 3 * s, ink)
		if k > 0.0: draw_arc(c, 46 * s, -PI / 2.0, -PI / 2.0 + TAU * k, 48, fill, 6 * s)
		if blocked:
			var x := Color("7a3a2a")
			draw_line(c + Vector2(-12, -12) * s, c + Vector2(12, 12) * s, x, 5 * s); draw_line(c + Vector2(12, -12) * s, c + Vector2(-12, 12) * s, x, 5 * s)

func _init() -> void:
	reticle = Reticle.new(); reticle.visible = false; reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE

static func _mat(hex: int) -> Material: return PaperMats.paper(Color.hex((hex << 8) | 0xff), false)
static func _flat_mat(hex: int, a := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(Color.hex((hex << 8) | 0xff), a)
	if a < 1.0: m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m

## A paper-fletched ash shaft along +z: shaft, an iron head, four vanes of barn red and cream.
static func arrow_mesh() -> Node3D:
	var g := Node3D.new()
	var cm := CylinderMesh.new(); cm.top_radius = 0.012; cm.bottom_radius = 0.012; cm.height = 0.8; cm.radial_segments = 5; cm.rings = 1
	var shaft := MeshInstance3D.new(); shaft.mesh = cm; shaft.material_override = _mat(0xc8a46e); shaft.rotation.x = PI / 2.0; g.add_child(shaft)
	var cone := CylinderMesh.new(); cone.top_radius = 0.0; cone.bottom_radius = 0.03; cone.height = 0.09; cone.radial_segments = 4; cone.rings = 1
	var head := MeshInstance3D.new(); head.mesh = cone; head.material_override = _mat(0x6e6a64); head.rotation.x = PI / 2.0; head.position.z = 0.44; g.add_child(head)
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for v in [Vector3(0, 0, -0.38), Vector3(0, 0.05, -0.36), Vector3(0, 0, -0.22)]: st.set_normal(Vector3.RIGHT); st.add_vertex(v)
	var vane := st.commit()
	for i in 4:
		var v := MeshInstance3D.new(); v.mesh = vane; v.material_override = _flat_mat(0xefe2c4 if i % 2 else 0xa8352a); v.rotation.z = i * PI / 2.0
		(v.material_override as StandardMaterial3D).shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		g.add_child(v)
	return g

## A little lead slug with a pale streak behind it, so you can see the shot go.
static func bullet_mesh() -> Node3D:
	var g := Node3D.new()
	var sm := SphereMesh.new(); sm.radius = 0.035; sm.height = 0.07; sm.radial_segments = 6; sm.rings = 4
	var slug := MeshInstance3D.new(); slug.mesh = sm; slug.material_override = _flat_mat(0x4a4a4e); g.add_child(slug)
	var cm := CylinderMesh.new(); cm.top_radius = 0.008; cm.bottom_radius = 0.02; cm.height = 0.9; cm.radial_segments = 4; cm.rings = 1
	var streak := MeshInstance3D.new(); streak.mesh = cm; streak.material_override = _flat_mat(0xf2e8d0, 0.55); streak.rotation.x = PI / 2.0; streak.position.z = -0.45
	g.add_child(streak)
	return g

static var _puff_mesh: ArrayMesh
## A cloud of torn cream paper: lobes round a circle (the web's quadratic-curve shape, sampled).
static func puff_mesh() -> ArrayMesh:
	if _puff_mesh: return _puff_mesh
	var pts := PackedVector2Array()
	var n := 9
	var prev := Vector2.ZERO
	for i in n + 1:
		var a := (i / float(n)) * TAU; var r := 0.22 + (0.05 if i % 2 else 0.0) + sin(i * 2.3) * 0.02
		var p := Vector2(cos(a) * r, sin(a) * r * 0.8)
		if i == 0: prev = p; continue
		var am := a - PI / n
		var ctl := Vector2(cos(am) * (r + 0.09), sin(am) * (r + 0.09) * 0.8)
		for s in [1, 2, 3]:
			var t: float = s / 3.0
			pts.append(prev * (1 - t) * (1 - t) + ctl * 2.0 * (1 - t) * t + p * t * t)
		prev = p
	pts.remove_at(pts.size() - 1)
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tri := Geometry2D.triangulate_polygon(pts)
	for i in tri: st.set_normal(Vector3.BACK); st.add_vertex(Vector3(pts[i].x, pts[i].y, 0))
	_puff_mesh = st.commit()
	return _puff_mesh

func aim(dt: float, camera: Camera3D, from: Vector3, critters: Critters, world: World = null, W := BOW) -> void:
	charge = minf(1.0, charge + dt / W.draw)
	var k := charge; var rng: float = W.range0 + W.range1 * k; var spread: float = W.spread * (1.0 - k) + 0.008
	cam = camera
	var vs := camera.get_viewport().get_visible_rect().size
	var sp := Vector2(vs.x / 2.0, (1.0 - RET_Y) / 2.0 * vs.y)
	var o := camera.project_ray_origin(sp); var d := camera.project_ray_normal(sp)
	# the game under the reticle: nearest along the ray whose chest the ray (widened by the spread) passes through
	var best = null; var bt := INF
	for c in critters.list:
		if not GAME.has(c.type) or c.state == "down" or not c.puppet.group.visible: continue
		var g: Dictionary = GAME[c.type]; var cp := critters.pos(c)
		if Vector2(cp.x - from.x, cp.z - from.z).length() > rng: continue
		c.aimY = g.h * c.scale
		var rp := Vector3(cp.x, cp.y + c.aimY, cp.z) - o
		var t := rp.dot(d)
		if t <= 0.0: continue
		if (rp - d * t).length() < g.r * c.scale + spread * t and t < bt: bt = t; best = c
	# a warrior under it, once it's a fight
	if targets.is_valid():
		for tg in targets.call():
			if Vector2(tg.pos.x - from.x, tg.pos.z - from.z).length() > rng: continue
			var sc: float = tg.h / 1.15
			var rp: Vector3 = Vector3(tg.pos.x, tg.pos.y + 0.8 * sc, tg.pos.z) - o
			var tt := rp.dot(d)
			if tt <= 0.0 or tt >= bt: continue
			if (rp - d * tt).length() < tg.r + spread * tt: bt = tt; best = {"fixed": tg.pos, "aimY": 0.8 * sc, "scale": sc}
	blocked = best != null and world != null and covered(from, _tpos(critters, best), world)
	target = null if blocked else best
	# where the reticle meets the ground (for a shot at nothing)
	ground_at = null
	var tm := 1.0
	while tm < 90.0:
		var q := o + d * tm
		if q.y <= Terrain.get_height(q.x, q.z): ground_at = Vector3(q.x, Terrain.get_height(q.x, q.z), q.z); break
		tm += 0.6
	aim_dir = Vector3(d.x, 0, d.z).normalized()
	var size := roundf(84.0 - 52.0 * k) * vs.y / 900.0 # (the web's CSS pixels at a 900-high window)
	reticle.visible = true; reticle.size = Vector2(size, size); reticle.position = sp - reticle.size / 2.0
	reticle.k = k; reticle.on = target != null; reticle.blocked = blocked; reticle.queue_redraw()

func _tpos(critters: Critters, t) -> Vector3: return t.fixed if t.has("fixed") else critters.pos(t)

## Let go: the arrow flies to what's under the reticle (leading a runner), else the ground there. False if barely drawn.
func loose(from: Vector3, critters: Critters, W := BOW) -> bool:
	var k := charge; var tg = target; var ground = ground_at; var dir = aim_dir
	charge = 0.0; target = null; reticle.visible = false
	if k < 0.18 or dir == null: return false # (barely drawn: you ease the string back)
	var speed: float = W.speed0 + W.speed1 * k; var rng: float = W.range0 + W.range1 * k
	var to = null
	if tg != null:
		var tp := _tpos(critters, tg)
		var t0 := Vector2(tp.x - from.x, tp.z - from.z).length() / speed
		var lead: Vector3 = tg.dir * tg.speed * t0 if tg.has("dir") else Vector3.ZERO
		to = Vector3(tp.x + lead.x, tp.y + tg.get("aimY", 0.8 * tg.scale), tp.z + lead.z)
	elif ground != null:
		to = ground
		var dd := Vector2(to.x - from.x, to.z - from.z).length()
		if dd > rng: to.x = from.x + (to.x - from.x) * rng / dd; to.z = from.z + (to.z - from.z) * rng / dd; to.y = Terrain.get_height(to.x, to.z) # (the draw only carries so far)
	var vel: Vector3
	if to != null:
		vel = Vector3(to.x - from.x, 0, to.z - from.z)
		var t := maxf(0.08, vel.length() / speed)
		vel = vel.normalized() * speed; vel.y = (to.y - from.y) / t + 0.5 * G * t
	else: vel = dir * speed; vel.y = 2.0 + 3.0 * k # (aimed at the sky: a long arc)
	var mesh := bullet_mesh() if W.bullet else arrow_mesh()
	add_child(mesh); mesh.position = from
	if W.bullet: puff(from, vel, 1.4 if W.dmg > 8 else 1.0)
	arrows.append({"mesh": mesh, "vel": vel, "age": 0.0, "stuck": false, "bullet": W.bullet, "dmg": W.dmg, "rest": Basis(), "still": false})
	return true

## A cough of powder smoke at the muzzle (big for the rifle).
func puff(from: Vector3, vel: Vector3, big := 1.0) -> void:
	var dir := Vector3(vel.x, 0, vel.z).normalized()
	for k in 3:
		var p = null
		for q in puffs: if q.age >= q.life: p = q; break
		if p == null:
			if puffs.size() >= 18: return
			var m := MeshInstance3D.new(); m.mesh = puff_mesh(); m.material_override = _flat_mat([0xe6dcc4, 0xd8ccb2, 0xcbc0a8][puffs.size() % 3], 0.92)
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var rim := MeshInstance3D.new(); rim.mesh = puff_mesh(); rim.material_override = _flat_mat(0x8a7458, 0.7)
			rim.scale = Vector3.ONE * 1.07; rim.position.z = -0.006; rim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			(rim.material_override as StandardMaterial3D).render_priority = -1
			m.add_child(rim); add_child(m)
			p = {"mesh": m, "rim": rim, "vel": Vector3.ZERO, "age": 0.0, "life": 0.0, "spin": 0.0, "size": 1.0, "roll": 0.0}
			puffs.append(p)
		var f := 0.35 + k * 0.32
		var pos := from + dir * f; pos.y += (randf() - 0.5) * 0.1
		var v := dir * (1.6 - k * 0.35) * big; v.y = 0.35 + randf() * 0.25; v.x += (randf() - 0.5) * 0.3; v.z += (randf() - 0.5) * 0.3
		p.vel = v; p.age = 0.0; p.life = (0.9 + randf() * 0.4) * big; p.spin = (randf() - 0.5) * 1.6; p.size = (0.8 + k * 0.25) * big
		p.mesh.position = pos; p.mesh.scale = Vector3.ONE * p.size; p.mesh.visible = true; p.roll = randf() * 6.28

## Stop drawing without loosing (the bow put away, a menu opened).
func ease() -> void: charge = 0.0; target = null; reticle.visible = false

## Is there a trunk, rock or wall between from and the beast (on the flat)?
func covered(from: Vector3, at: Vector3, world: World) -> bool:
	var ax := from.x; var az := from.z; var dx := at.x - ax; var dz := at.z - az; var L := sqrt(dx * dx + dz * dz)
	if L < 1.0: return false
	var segd := func(x: float, z: float) -> float:
		var t := clampf(((x - ax) * dx + (z - az) * dz) / (L * L), 0.0, 1.0)
		return Vector2(ax + dx * t - x, az + dz * t - z).length()
	var near := func(x: float, z: float) -> bool: return Vector2(x - at.x, z - at.z).length() < 0.9 # (not the ground it stands on)
	for r in world.resources_near((ax + at.x) / 2.0, (az + at.z) / 2.0, L / 2.0 + 1.0):
		var trunk: bool = r.type in TRUNKS
		if not trunk and not r.type in ROCKS: continue
		if not near.call(r.x, r.z) and segd.call(r.x, r.z) < float(Res.TYPES[r.type].radius) * r.scale * (0.7 if trunk else 0.85) + 0.05: return true
	for c in world.colliders:
		if not near.call(c.x, c.z) and absf(c.x - ax - dx / 2.0) < L / 2.0 + c.r and absf(c.z - az - dz / 2.0) < L / 2.0 + c.r and segd.call(c.x, c.z) < c.r: return true
	return false

func _stick(a: Dictionary) -> void: a.stuck = true; a.age = 0.0; a.still = false; a.rest = a.mesh.basis

func _strike(a: Dictionary, world: World) -> bool:
	var p: Vector3 = a.mesh.position; var gy := Terrain.get_height(p.x, p.z)
	for r in world.resources_near(p.x, p.z, 0.1):
		var trunk: bool = r.type in TRUNKS
		var tall := 7.0 if trunk else (1.3 if r.type in ROCKS else 0.0)
		if tall == 0.0 or p.y - gy > tall * r.scale: continue
		if _bury(a, r.x, r.z, float(Res.TYPES[r.type].radius) * r.scale * (0.7 if trunk else 0.85)): return true
	for c in world.colliders:
		if (c.x - p.x) ** 2 + (c.z - p.z) ** 2 > (c.r + 0.1) ** 2 or p.y - gy > 3.0: continue
		if _bury(a, c.x, c.z, c.r): return true
	return false

## Set the arrow on the circle of radius r round (x, z), its head a little inside, and stick it there.
func _bury(a: Dictionary, x: float, z: float, r: float) -> bool:
	var p: Vector3 = a.mesh.position; var dx := p.x - x; var dz := p.z - z; var d := sqrt(dx * dx + dz * dz)
	if d > r or d < 1e-4: return false
	var out := r + 0.3
	p.x = x + (dx / d) * out; p.z = z + (dz / d) * out; a.mesh.position = p
	_stick(a)
	if on_thunk.is_valid(): on_thunk.call()
	return true

func _face(a: Dictionary) -> void:
	var p: Vector3 = a.mesh.position; var v: Vector3 = a.vel
	if v.length_squared() > 1e-6: a.mesh.look_at(p + v, Vector3.UP if absf(v.normalized().y) < 0.99 else Vector3.RIGHT, true)

func _drop(i: int) -> void: arrows[i].mesh.queue_free(); arrows.remove_at(i)

func update(dt: float, critters: Critters, world: World = null) -> void:
	cool = maxf(0.0, cool - dt)
	for p in puffs: # the powder smoke: billowing out, slowing, rising, turning, thinning away
		if p.age >= p.life: continue
		p.age += dt
		var k: float = p.age / p.life; var m: MeshInstance3D = p.mesh
		if k >= 1.0: m.visible = false; continue
		p.vel.x *= exp(-dt * 3.0); p.vel.z *= exp(-dt * 3.0); p.vel.y += dt * 0.3
		m.position += p.vel * dt
		p.roll += p.spin * dt
		if cam: m.basis = (cam.global_transform.basis * Basis(Vector3.BACK, p.roll)).scaled_local(Vector3.ONE * p.size) # (faces the lens, a card held up)
		var op: float = 0.92 * (1.0 if k < 0.55 else 1.0 - (k - 0.55) / 0.45)
		(m.material_override as StandardMaterial3D).albedo_color.a = op; (p.rim.material_override as StandardMaterial3D).albedo_color.a = op * 0.8
	for i in range(arrows.size() - 1, -1, -1):
		var a: Dictionary = arrows[i]
		a.age += dt
		if a.stuck: # it quivers a moment where it struck, then stands still till it's gone
			if a.age < 0.6: a.mesh.basis = a.rest * Basis(Vector3.RIGHT, sin(a.age * 55.0) * 0.09 * (1.0 - a.age / 0.6))
			elif not a.still: a.still = true; a.mesh.basis = a.rest
			if a.age > 8.0: _drop(i)
			continue
		a.vel.y -= G * dt
		# in steps of a few hand-widths, so it can't skip clean through a slim birch between frames
		var n := maxi(1, ceili((a.vel.length() * dt) / 0.18))
		var hit := false; var struck = null
		for s in n:
			if hit or struck != null: break
			a.mesh.position += a.vel * (dt / n)
			var p: Vector3 = a.mesh.position
			if targets.is_valid():
				for tg in targets.call():
					var dy: float = p.y - tg.pos.y
					if (tg.pos.x - p.x) ** 2 + (tg.pos.z - p.z) ** 2 < tg.r * tg.r and dy > 0.2 and dy < tg.h: struck = tg; break
			if struck == null and world != null: hit = _strike(a, world)
		if struck != null:
			if on_target.is_valid(): on_target.call(struck, a)
			_drop(i); continue
		if hit and a.bullet: _drop(i); continue # (a chip of bark or a spark off the rock, and gone)
		if hit: _face(a); a.rest = a.mesh.basis; continue
		_face(a)
		var pp: Vector3 = a.mesh.position
		# a beast in its path (any of the game, not only the one it was aimed at)
		var done := false
		for c in critters.list:
			if not GAME.has(c.type) or c.state == "down": continue
			var g: Dictionary = GAME[c.type]; var cp := critters.pos(c)
			var dy := pp.y - cp.y
			if (cp.x - pp.x) ** 2 + (cp.z - pp.z) ** 2 < (g.hit * c.scale) ** 2 and dy > 0.05 and dy < g.top * c.scale:
				c.hp = c.get("hp", g.hp) - a.dmg
				if c.hp > 0: # (a bison takes more than one: wounded, it lumbers off)
					c.state = "flee"; c.timer = 4.0; var dv := cp - pp; dv.y = 0; c.dir = dv.normalized()
					if on_wound.is_valid(): on_wound.call(c)
				else:
					critters.fell(c)
					if on_hit.is_valid(): on_hit.call(c)
				_drop(i); done = true; break
		if done: continue
		var gy := Terrain.get_height(pp.x, pp.z)
		if a.bullet and (pp.y <= gy + 0.05 or a.age > 1.5): _drop(i); continue # (a bullet kicks up the dirt and is gone)
		if pp.y <= gy + 0.05 or a.age > 2.5: # a miss: it sticks in the turf, quivering, gone in a while
			pp.y = maxf(pp.y, gy + 0.18); a.mesh.position = pp; _stick(a)
