class_name BuildSystem
extends Node3D
## building.js's BuildSystem: the pieces you build (workbench, campfire, forge, floors and walls on a 2 m grid, roofs
## that slope toward the middle of the house, stairs, fences, lanterns, the yard's odds and ends and the settlers'
## works). The piece meshes are baked from the web (assets/baked/pieces/<type>.glb, models from the reference art as
## placements in pieces.json); the rules come from building.json (PIECES, PIECE_HP, FOOT, chips, the build menu).
## Aiming (camera ray against pieces and the terrain), snapping, validation, placing, taking down for a refund,
## breaking with tools, the springy rise and the fold away, surfaces to walk on, solid walls, the six nearest
## lights (fires flicker, lanterns and jack-o'-lanterns glow after dusk), stations near, roofs for the rain.

const G := 2.0
const WALL_H := 2.2
const FOLDED := -PI / 2.0 + 0.02
const WOOD_CHIPS := [0xc99a5e, 0x8a5a34, 0xefe5cc]
static var DATA := {}
static var PIECES := {}
static var ORDER: Array = []
static var _meshes := {}      ## type -> PackedScene
static var _model_place := {} ## type -> [{model, mesh, m}]
static var LAMP_AT := [0.5, 1.9]

var camera: Camera3D
var pieces: Array = []
var active := false
var selected := 2             ## floor
var rot := 0
var roof_manual := false
var preview = null
var clock := 0.0
var closing: Array = []
var hover = null
var ghost: Node3D
var ghost_type := ""
var ghost_mat: StandardMaterial3D
var light_pool: Array = []
var snow := 0.0
var discovered := {}
var loading := false
var glow := 0.0

## The port's own pieces (the player's ask: more to build), beyond the web's: a Homestead shelf of buildings that do
## something, made from the reference art's models, and a palisade for the Yard. makes: what one morning brings
## (gathered with E; cap mornings' worth wait); use: what E does. Their solid boxes come from the model itself.
const EXTRA := {
	"henhouse": {"name": "Chicken coop", "cost": {"wood": 10, "fiber": 4}, "model": "bldg_coop", "size": 3.6, "makes": {"egg": 3}, "cap": 3, "verb": "Gather the eggs", "hp": 5},
	"haybarn": {"name": "Hay barn", "cost": {"wood": 24, "stone": 6, "rope": 2}, "model": "bldg_barn", "size": 8.0, "makes": {"fiber": 5}, "cap": 3, "verb": "Fork out the straw", "hp": 10},
	"shaft": {"name": "Prospect shaft", "cost": {"wood": 10, "stone": 6, "rope": 2}, "model": "mine_entrance", "size": 4.2, "makes": {"ore": 2, "stone": 3}, "cap": 3, "verb": "Haul up the ore", "hp": 8},
	"well": {"name": "Well", "cost": {"stone": 8, "wood": 4, "rope": 2}, "model": "mine_windlass", "size": 2.0, "use": "drink", "hp": 6},
	"leanto": {"name": "Lean-to", "cost": {"wood": 12, "fiber": 6}, "model": "bldg_leanto", "size": 5.0, "use": "sleep", "hp": 6},
	"palisade": {"name": "Palisade", "cost": {"wood": 4}, "snap": "edge", "solid": [1.0, 0.16, 2.6], "foot": [1.0, 0.16, 2.6], "hp": 9},
}
const EXTRA_SHELF := ["Homestead", ["henhouse", "haybarn", "shaft", "well", "leanto"]]

static func load_data() -> void:
	if not DATA.is_empty(): return
	DATA = JSON.parse_string(FileAccess.open("res://assets/baked/data/building.json", FileAccess.READ).get_as_text())
	PIECES = DATA.PIECES; ORDER = DATA.PIECE_ORDER
	for t in EXTRA:
		var e: Dictionary = EXTRA[t]
		PIECES[t] = {"name": e.name, "cost": e.cost, "snap": e.get("snap", "free"), "free": not e.has("snap")}
		if e.has("solid"): PIECES[t].solid = e.solid
		DATA.PIECE_HP[t] = e.hp
		DATA.FOOT[t] = e.get("foot", [1.2, 1.2, 2.0]) # (a model piece's real box is measured when it's first made)
		if not ORDER.has(t): ORDER.append(t)
	DATA.PIECE_GROUPS.append(EXTRA_SHELF)
	for g in DATA.PIECE_GROUPS: if g[0] == "Yard" and not g[1].has("palisade"): g[1].insert(1, "palisade")
	var pj: Dictionary = JSON.parse_string(FileAccess.open("res://assets/baked/pieces/pieces.json", FileAccess.READ).get_as_text())
	LAMP_AT = pj.LAMP_AT
	for t in pj.pieces: _model_place[t] = pj.pieces[t].models

func _init(cam: Camera3D) -> void:
	camera = cam
	load_data()
	ghost_mat = StandardMaterial3D.new()
	ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost_mat.albedo_color = Color(Color.hex(0x7fd18bff), 0.5)
	ghost_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	ghost_mat.render_priority = 2

func _ready() -> void:
	for i in 6:
		var l := OmniLight3D.new(); l.light_color = Color.hex(0xffa860ff).srgb_to_linear(); l.light_energy = 0.0; l.omni_range = 12.0; l.omni_attenuation = 1.0
		add_child(l); light_pool.append(l)

var type: String:
	get: return ORDER[selected]

static func rot_of(r: int) -> float: return r * PI / 2.0
static func piece_local(p: Dictionary, x: float, z: float) -> Vector2:
	var a := rot_of(p.rot); var c := cos(a); var s := sin(a)
	var dx: float = x - p.x; var dz: float = z - p.z
	return Vector2(c * dx - s * dz, s * dx + c * dz)
static func to_world_dir(p: Dictionary, lx: float, lz: float) -> Vector2:
	var a := rot_of(p.rot); var c := cos(a); var s := sin(a)
	return Vector2(c * lx + s * lz, -s * lx + c * lz)

## A piece's mesh: the baked paper build re-skinned, with any reference-art model placed where the web put it.
func make_mesh(t: String, as_ghost := false) -> Node3D:
	if EXTRA.has(t): return _extra_mesh(t, as_ghost)
	if not _meshes.has(t): _meshes[t] = load("res://assets/baked/pieces/%s.glb" % t)
	var root := (_meshes[t] as PackedScene).instantiate() as Node3D
	if as_ghost: _ghostify(root)
	else: _skin(root)
	for m in _model_place.get(t, []):
		var scene: PackedScene = load("res://assets/models/props/%s.glb" % m.model)
		if scene == null: continue
		var inst := scene.instantiate()
		var meshes := PaperMats._meshes(inst)
		if meshes.size() > int(m.mesh):
			var src: MeshInstance3D = meshes[int(m.mesh)]
			var mi := MeshInstance3D.new(); mi.mesh = src.mesh; mi.transform = Homestead._m(m.m)
			if as_ghost: mi.material_override = ghost_mat; mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			else:
				PaperMats.paperize(inst)
				for s in src.mesh.get_surface_count(): mi.set_surface_override_material(s, src.get_surface_override_material(s))
			root.add_child(mi)
		inst.free()
	return root

## A Homestead piece from its model (seated, its floor at y 0), or the palisade's stakes; its solid box and footprint
## measured from what's made, the first time.
func _extra_mesh(t: String, as_ghost: bool) -> Node3D:
	var e: Dictionary = EXTRA[t]
	var root := Node3D.new()
	if e.has("model"):
		var scene: PackedScene = load("res://assets/models/props/%s.glb" % e.model)
		if scene != null:
			var m := PaperMats.seated(scene, e.size, false, true); root.add_child(m)
			if not PIECES[t].has("solid"):
				var bb := PaperMats._aabb(m, Transform3D.IDENTITY)
				var hx := maxf(0.4, bb.size.x * 0.5 * 0.85); var hz := maxf(0.4, bb.size.z * 0.5 * 0.85)
				PIECES[t].solid = [hx, hz, bb.size.y]; DATA.FOOT[t] = [hx, hz, bb.size.y]
	else: # the palisade: pointed stakes side by side along the edge, a rail behind
		var wood := PaperMats.paper(Color("8a6040"))
		for i in 8:
			var x := -0.875 + i * 0.25; var h := 2.3 + (0.12 if i % 2 else 0.0)
			var c := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.12; cm.bottom_radius = 0.13; cm.height = h; cm.radial_segments = 6; c.mesh = cm
			c.position = Vector3(x, h / 2.0, 0); c.material_override = wood; root.add_child(c)
			var tip := MeshInstance3D.new(); var tm := CylinderMesh.new(); tm.top_radius = 0.0; tm.bottom_radius = 0.12; tm.height = 0.32; tm.radial_segments = 6; tip.mesh = tm
			tip.position = Vector3(x, h + 0.16, 0); tip.material_override = wood; root.add_child(tip)
		for y in [0.6, 1.7]:
			var r := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(2.0, 0.12, 0.08); r.mesh = bm
			r.position = Vector3(0, y, -0.16); r.material_override = PaperMats.paper(Color("6e4a30")); root.add_child(r)
	if as_ghost: _ghostify(root)
	return root

func _skin(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			var src := mi.get_active_material(s) as BaseMaterial3D
			if src == null: continue
			var mat: ShaderMaterial
			if src.albedo_texture != null:
				mat = PaperMats.card(src.albedo_texture, {"albedo": src.albedo_color})
				if src.resource_name.begins_with("glow_window"): mat.set_shader_parameter("night_glow", Vector3(1.0, 0.62, 0.28) * 3.2)
			else:
				mat = PaperMats.paper(src.albedo_color)
				if src.resource_name.begins_with("glow_lantern"):
					mat = mat.duplicate(); mat.set_shader_parameter("night_glow", Vector3(1.0, 0.65, 0.3) * 4.0)
			mi.set_surface_override_material(s, mat)
	for c in n.get_children(): _skin(c)

func _ghostify(n: Node) -> void:
	if n is MeshInstance3D:
		(n as MeshInstance3D).material_override = ghost_mat
		(n as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in n.get_children(): _ghostify(c)

# ------------------------------------------------------------------ queries for the player
## The highest walkable surface under (x, z) he can step onto from height y.
func surface_at(x: float, z: float, y: float) -> float:
	var best := -INF
	for p in nearby(x, z, 2.0):
		var def: Dictionary = PIECES[p.type]
		if not def.has("surface"): continue
		var l := piece_local(p, x, z)
		if absf(l.x) > 1.0 or absf(l.y) > 1.0: continue
		var top: float = p.y + 0.2 if def.surface == "floor" else p.y + ((l.y + 1.0) / 2.0) * WALL_H
		if top <= y + 0.65 and top > best: best = top
	return best

## Push the player's circle out of solid pieces (mutates and returns pos).
func collide(pos: Vector3, radius := 0.32) -> Vector3:
	for p in nearby(pos.x, pos.z, 2.5):
		var def: Dictionary = PIECES[p.type]
		if not def.has("solid"): continue
		var boxes: Array = [[-0.725, 0.275, 0.1, WALL_H], [0.725, 0.275, 0.1, WALL_H]] if typeof(def.solid) == TYPE_STRING else [[0.0, def.solid[0], def.solid[1], def.solid[2]]]
		for b in boxes:
			var cx: float = b[0]; var hx: float = b[1]; var hz: float = b[2]; var h: float = b[3]
			if pos.y > p.y + h - 0.3 or pos.y + 1.7 < p.y: continue
			var l := piece_local(p, pos.x, pos.z); var lx := l.x - cx; var lz := l.y
			var qx := clampf(lx, -hx, hx); var qz := clampf(lz, -hz, hz)
			var dx := lx - qx; var dz := lz - qz; var d := sqrt(dx * dx + dz * dz)
			if d >= radius: continue
			var nx: float; var nz: float; var push: float
			if d > 1e-5: nx = dx / d; nz = dz / d; push = radius - d
			else:
				var ox := hx - absf(lx); var oz := hz - absf(lz)
				if ox < oz: nx = signf(lx) if lx != 0.0 else 1.0; nz = 0.0; push = ox + radius
				else: nx = 0.0; nz = signf(lz) if lz != 0.0 else 1.0; push = oz + radius
			var w := to_world_dir(p, nx, nz)
			pos.x += w.x * push; pos.z += w.y * push
	return pos

func nearby(x: float, z: float, r: float) -> Array:
	var out := []
	for p in pieces:
		if absf(p.x - x) < r + 1.5 and absf(p.z - z) < r + 1.5: out.append(p)
	return out

func has_workbench_near(x: float, z: float, r := 20.0) -> bool:
	for p in pieces:
		if p.type == "workbench" and (p.x - x) * (p.x - x) + (p.z - z) * (p.z - z) < r * r: return true
	return false

# ------------------------------------------------------------------ placement
## A ray from the camera through the screen centre: {point, normal, piece, dist} or null.
func aim():
	var origin := camera.global_position
	var dir := -camera.global_basis.z
	var hit = null
	# (pieces are found by their footprint boxes along the ray: a cheap stand-in for three's mesh raycast)
	var best_t := INF
	for p in pieces:
		var f: Array = DATA.FOOT.get(p.type, [1, 1, 1])
		var inv := Transform3D(Basis(Vector3.UP, rot_of(p.rot)), Vector3(p.x, p.y, p.z)).affine_inverse()
		var o := inv * origin; var dv := inv.basis * dir
		var box := AABB(Vector3(-f[0], 0, -f[1]), Vector3(f[0] * 2, f[2], f[1] * 2))
		var t = _ray_box(o, dv, box)
		if t != null and t < best_t and t < 40.0:
			best_t = t
			var hp: Vector3 = o + dv * t
			var n := Vector3.UP
			var e := 0.02
			if absf(hp.y - box.end.y) < e: n = Vector3.UP
			elif absf(hp.x - box.position.x) < e: n = Vector3.LEFT
			elif absf(hp.x - box.end.x) < e: n = Vector3.RIGHT
			elif absf(hp.z - box.position.z) < e: n = Vector3.FORWARD
			elif absf(hp.z - box.end.z) < e: n = Vector3.BACK
			hit = {"point": origin + dir * t, "normal": Basis(Vector3.UP, rot_of(p.rot)) * n, "piece": p, "dist": t}
	# march the terrain
	var prev_t := 0.0
	var t := 0.5
	while t < 40.0:
		var q := origin + dir * t
		if q.y < Terrain.get_height(q.x, q.z):
			var a := prev_t; var b := t
			for k in 10:
				var m := (a + b) / 2.0; var qq := origin + dir * m
				if qq.y < Terrain.get_height(qq.x, qq.z): b = m
				else: a = m
			if hit == null or b < hit.dist: hit = {"point": origin + dir * b, "normal": Vector3.UP, "piece": null, "dist": b}
			break
		prev_t = t; t += 0.35
	return hit

static func _ray_box(o: Vector3, d: Vector3, box: AABB):
	var tmin := -INF; var tmax := INF
	for i in 3:
		if absf(d[i]) < 1e-9:
			if o[i] < box.position[i] or o[i] > box.end[i]: return null
		else:
			var t1 := (box.position[i] - o[i]) / d[i]; var t2 := (box.end[i] - o[i]) / d[i]
			tmin = maxf(tmin, minf(t1, t2)); tmax = minf(tmax, maxf(t1, t2))
	if tmax < maxf(tmin, 0.0): return null
	return maxf(tmin, 0.0)

## Snap a hit to a placement for the selected piece.
func snap(hit: Dictionary) -> Dictionary:
	var t := type; var def: Dictionary = PIECES[t]
	var x: float = hit.point.x; var z: float = hit.point.z
	var r := rot
	var px: float; var pz: float
	var at_wall_side: bool = def.snap == "cell" and hit.piece != null and PIECES[hit.piece.type].has("solid") and absf(hit.normal.y) < 0.5
	if at_wall_side: x -= hit.normal.x * G * 0.5; z -= hit.normal.z * G * 0.5
	var at_floor_side: bool = t == "floor" and hit.piece != null and hit.piece.type == "floor" and absf(hit.normal.y) < 0.5
	if at_floor_side: x += hit.normal.x * G * 0.5; z += hit.normal.z * G * 0.5
	if def.snap == "cell": px = floorf(x / G) * G + G / 2.0; pz = floorf(z / G) * G + G / 2.0
	elif def.snap == "edge":
		if r % 2 == 0: pz = roundf(z / G) * G; px = floorf(x / G) * G + G / 2.0
		else: px = roundf(x / G) * G; pz = floorf(z / G) * G + G / 2.0
	else: px = roundf(x * 2.0) / 2.0; pz = roundf(z * 2.0) / 2.0
	var y: float
	if hit.piece != null:
		y = hit.point.y if hit.normal.y > 0.6 else hit.piece.y
		if hit.normal.y > 0.6 and PIECES[hit.piece.type].has("solid"): y = hit.piece.y + WALL_H
		if hit.normal.y > 0.6 and hit.piece.type == "floor": y = hit.piece.y + 0.2
		if hit.piece.type == "stairs" and t == "floor": y = hit.piece.y + WALL_H - 0.2
	elif t == "floor":
		y = -INF
		for o in [[-1, -1], [1, -1], [1, 1], [-1, 1], [0, 0]]: y = maxf(y, Terrain.get_height(px + o[0], pz + o[1]))
		for p in pieces:
			if absf(p.x - px) + absf(p.z - pz) != G: continue
			if p.type == "floor" and p.y >= y - 0.01 and p.y < y + 1.6: y = maxf(y, p.y)
			if p.type == "stairs": y = maxf(y, p.y + WALL_H - 0.2)
	elif def.snap == "edge":
		var e := Vector2(1, 0) if r % 2 == 0 else Vector2(0, 1)
		y = minf(minf(Terrain.get_height(px - e.x, pz - e.y), Terrain.get_height(px + e.x, pz + e.y)), Terrain.get_height(px, pz)) - 0.05
	else: y = Terrain.get_height(px, pz)
	if t == "roof" or t == "floor":
		var tops := wall_tops_around(px, pz)
		if tops.size():
			if t == "roof":
				var ok := [tops.min()]
				for tp in tops: if tp <= hit.point.y + WALL_H + 0.5: ok.append(tp)
				y = ok.max()
			elif at_wall_side or (hit.piece != null and (hit.piece.type == "floor" or PIECES[hit.piece.type].has("solid"))):
				var base: float = hit.piece.y if hit.piece != null else y
				var above := []
				for tp in tops: if tp > base + 0.5: above.append(tp)
				if above.size(): y = above.min()
	if t == "ridge":
		var rf = hit.piece if hit.piece != null and hit.piece.type == "roof" else null
		if rf == null: return {"type": t, "x": px, "y": y, "z": pz, "rot": r, "no_roof": true}
		var u := to_world_dir(rf, 0, 1)
		return {"type": t, "x": rf.x + roundf(u.x) * G, "y": rf.y + 1.15, "z": rf.z + roundf(u.y) * G, "rot": rf.rot}
	y = roundf(y * 20.0) / 20.0
	if t == "roof" and not roof_manual: r = roof_rotation(px, y, pz, r)
	return {"type": t, "x": px, "y": y, "z": pz, "rot": r}

func wall_tops_around(cx: float, cz: float) -> Array:
	var tops := []
	for p in pieces:
		var d: Dictionary = PIECES[p.type]
		if d.snap != "edge" or not d.has("solid") or p.type == "fence": continue
		var on_edge: bool = (absf(p.x - cx) < 0.01 and absf(absf(p.z - cz) - G / 2.0) < 0.01) if int(p.rot) % 2 == 0 else (absf(p.z - cz) < 0.01 and absf(absf(p.x - cx) - G / 2.0) < 0.01)
		if on_edge: tops.append(p.y + WALL_H)
	return tops

## The roof turn that slopes up toward the middle of the house below it (neighbouring roofs meet in a ridge).
func roof_rotation(x: float, y: float, z: float, fallback: int) -> int:
	var sx := 0.0; var sz := 0.0; var n := 0
	for p in pieces:
		if p.type != "floor" and not PIECES[p.type].has("solid"): continue
		if p.y < y - 3.6 or p.y > y + 0.3: continue
		if absf(p.x - x) > 9.0 or absf(p.z - z) > 9.0: continue
		sx += p.x; sz += p.z; n += 1
	if n == 0: return fallback
	var dx := sx / n - x; var dz := sz / n - z
	if maxf(absf(dx), absf(dz)) < 0.25: return fallback
	if absf(dx) > absf(dz): return 1 if dx > 0 else 3
	return 0 if dz > 0 else 2

func validate(pl: Dictionary, inventory: Dictionary, player_pos: Vector3) -> String:
	var def: Dictionary = PIECES[pl.type]
	if pl.get("no_roof", false): return "Aim at a roof: the ridge finishes it, peaking the next square up its slope"
	for k in def.cost:
		if inventory.get(k, 0) < def.cost[k]: return "Needs " + Crafting.cost_text(_ints(def.cost))
	if not def.get("free", false) and not has_workbench_near(pl.x, pl.z): return "Needs a workbench within 20 m"
	if def.get("needsSnow", false) and not (snow > 0.4): return "Needs snow on the ground"
	if EXTRA.has(pl.type) and EXTRA[pl.type].has("model"): # (a building wants dry, level-ish ground under it)
		var f: Array = DATA.FOOT[pl.type]
		for k in 8:
			var a := k * TAU / 8.0
			if Terrain.is_water(pl.x + cos(a) * f[0], pl.z + sin(a) * f[1]): return "Not in the water: build it on dry ground"
		if Terrain.impassable(pl.x, pl.z): return "Too steep here for a building"
	if def.has("work") and not discovered.has(def.work): return "Gather some %s yourself first" % def.work
	if def.get("needsWater", false):
		var wet := false
		for k in 8: wet = wet or Terrain.is_water(pl.x + cos(k * 0.785) * 3.5, pl.z + sin(k * 0.785) * 3.5)
		if not wet: return "Build it beside running water (a creek or pond within a few strides)"
	for p in pieces:
		if p.type == pl.type and p.x == pl.x and p.z == pl.z and absf(p.y - pl.y) < 0.3 and (def.snap != "edge" or int(p.rot) % 2 == int(pl.rot) % 2): return "Already built here"
	if def.snap == "free":
		for p in pieces:
			if PIECES[p.type].snap == "free" and Vector2(p.x - pl.x, p.z - pl.z).length() < 1.4 and absf(p.y - pl.y) < 1.0: return "Too close to something"
	var d := Vector2(player_pos.x - pl.x, player_pos.z - pl.z).length()
	if d > 14.0: return "Too far away"
	if def.has("solid") and d < 0.9 and absf(player_pos.y - pl.y) < 2.0: return "You are standing there"
	return ""

static func _ints(d: Dictionary) -> Dictionary:
	var o := {}
	for k in d: o[k] = int(d[k])
	return o

func update(dt: float, inventory: Dictionary, player_pos: Vector3, night: float) -> void:
	glow = PNoise.smoothstep(0.25, 0.8, night)
	update_lights(player_pos)
	animate(dt)
	if not active:
		if ghost: ghost.visible = false
		preview = null; hover = null
		return
	if ghost_type != type:
		if ghost: ghost.queue_free()
		ghost = make_mesh(type, true); add_child(ghost); ghost_type = type
	var hit = aim()
	hover = hit.piece if hit != null else null
	if hit == null:
		ghost.visible = false; preview = null; return
	var pl := snap(hit)
	pl.reason = validate(pl, inventory, player_pos)
	pl.valid = pl.reason == ""
	preview = pl
	ghost.visible = true
	ghost.position = Vector3(pl.x, pl.y, pl.z)
	ghost.rotation = Vector3(0, rot_of(pl.rot), 0)
	ghost_mat.albedo_color = Color(Color.hex((0x7fd18b if pl.valid else 0xe0675a) << 8 | 0xff), 0.5)

## Place the previewed piece, spending what it costs. Returns a note (or "" when there's nothing aimed at).
func place(inventory: Dictionary) -> String:
	var pl = preview
	if pl == null: return ""
	if not pl.valid: return pl.reason
	var def: Dictionary = PIECES[pl.type]
	for k in def.cost: inventory[k] = inventory.get(k, 0) - int(def.cost[k])
	add(pl)
	return "Built " + String(def.name).to_lower()

func remove_hovered(inventory: Dictionary) -> String:
	var p = hover
	if p == null: return ""
	var def: Dictionary = PIECES[p.type]
	for k in def.cost: inventory[k] = inventory.get(k, 0) + int(def.cost[k])
	fold_away(p); hover = null
	return "Took down %s (refunded)" % String(def.name).to_lower()

## The built piece he'd hit: the nearest one in front within reach whose height overlaps his body.
func find_target(pos: Vector3, fwd_x: float, fwd_z: float, reach: float):
	var best = null; var best_d := INF
	for p in nearby(pos.x, pos.z, reach + 1.5):
		var f: Array = DATA.FOOT[p.type]
		if p.y + f[2] < pos.y - 0.6 or p.y > pos.y + 1.9: continue
		var l := piece_local(p, pos.x, pos.z)
		if absf(l.x) <= f[0] and absf(l.y) <= f[1] and pos.y >= p.y + f[2] - 0.35: continue
		var qx := clampf(l.x, -f[0], f[0]); var qz := clampf(l.y, -f[1], f[1])
		var w := to_world_dir(p, qx - l.x, qz - l.y)
		var d := w.length()
		if d > reach: continue
		if d > 0.05 and (w.x * fwd_x + w.y * fwd_z) / d < 0.25: continue
		if d < best_d: best_d = d; best = p
	return {"piece": best, "dist": best_d} if best != null else null

## Damage a piece; broken, it's gone and its cost refunded.
func damage(p: Dictionary, amount: int, inventory: Dictionary) -> Dictionary:
	p.hp = p.get("hp", int(DATA.PIECE_HP.get(p.type, 3))) - amount
	p.shake = 1.0
	if p.hp > 0: return {"destroyed": false}
	var def: Dictionary = PIECES[p.type]
	for k in def.cost: inventory[k] = inventory.get(k, 0) + int(def.cost[k])
	(p.mesh as Node).queue_free()
	pieces.erase(p)
	if hover == p: hover = null
	return {"destroyed": true, "refund": _ints(def.cost)}

func chips_for(t: String) -> Array: return DATA.PIECE_CHIPS.get(t, WOOD_CHIPS)

## Add a piece: it starts folded back flat on the page and rises about its base hinge (upright: from a save).
func add(d: Dictionary, upright := false) -> Dictionary:
	var piece := {"type": d.type, "x": d.x, "y": d.y, "z": d.z, "rot": int(d.rot), "stock": d.get("stock"), "day": d.get("day"), "stage": d.get("stage"), "tendDay": d.get("tendDay"), "born": clock, "risen": upright, "hinge": 0.0 if upright else FOLDED}
	var mesh := make_mesh(d.type)
	mesh.position = Vector3(d.x, d.y, d.z)
	mesh.rotation_order = EULER_ORDER_YXZ
	mesh.rotation = Vector3(piece.hinge, rot_of(piece.rot), 0)
	piece.mesh = mesh
	add_child(mesh)
	pieces.append(piece)
	if not loading and (d.type == "floor" or (PIECES[d.type].snap == "edge" and PIECES[d.type].has("solid"))): trim_legs()
	return piece

func on_wall_tops(t: String, x: float, y: float, z: float) -> bool:
	if t != "floor": return false
	for tp in wall_tops_around(x, z): if absf(tp - y) < 0.06: return true
	return false

## A floor on the wall tops (an upper storey), or carried on out from one, hangs there: no legs under it.
func trim_legs() -> void:
	var floors := []
	for p in pieces: if p.type == "floor": floors.append(p)
	var hung := {}
	for p in floors: if on_wall_tops("floor", p.x, p.y, p.z): hung[p] = true
	var grew := true
	while grew:
		grew = false
		for p in floors:
			if hung.has(p) or p.y <= Terrain.get_height(p.x, p.z) + 1.2: continue
			for q in floors:
				if hung.has(q) and absf(q.y - p.y) < 0.06 and absf(q.x - p.x) + absf(q.z - p.z) == G: hung[p] = true; grew = true; break
	for p in floors:
		var legs = (p.mesh as Node).find_child("part1", false, false)
		if legs: legs.visible = not hung.has(p)

func fold_away(p: Dictionary) -> void:
	pieces.erase(p)
	if PIECES[p.type].snap == "edge" and PIECES[p.type].has("solid"): trim_legs()
	closing.append({"mesh": p.mesh, "from": (p.mesh as Node3D).rotation.x, "t": 0.0})

func animate(dt: float) -> void:
	clock += dt
	for p in pieces:
		if not p.risen:
			var t: float = clock - p.born
			p.hinge = (1.0 - Props.spring_rise(t)) * FOLDED
			if t > 1.3: p.risen = true; p.hinge = 0.0
		var x: float = p.hinge; var z := 0.0
		if p.get("shake", 0.0) > 0.0:
			p.shake = maxf(0.0, p.shake - dt / 0.35)
			z = sin(clock * 45.0) * 0.035 * p.shake
			x += cos(clock * 50.0) * 0.02 * p.shake
		(p.mesh as Node3D).rotation = Vector3(x, rot_of(p.rot), z)
	for i in range(closing.size() - 1, -1, -1):
		var c: Dictionary = closing[i]
		c.t += dt
		var k := minf(1.0, c.t / 0.45)
		var m: Node3D = c.mesh
		m.rotation.x = c.from + (FOLDED - c.from) * k * k
		if k >= 1.0: m.queue_free(); closing.remove_at(i)

## The six nearest lights: fires flicker always, lanterns and jack-o'-lanterns glow after dusk.
func update_lights(center: Vector3) -> void:
	var emitters := []
	for p in pieces:
		if PIECES[p.type].has("light"): emitters.append([p, (p.x - center.x) * (p.x - center.x) + (p.z - center.z) * (p.z - center.z)])
	emitters.sort_custom(func(a, b): return a[1] < b[1])
	var t := Time.get_ticks_msec() * 0.001
	for i in light_pool.size():
		var l: OmniLight3D = light_pool[i]
		if i >= emitters.size() or emitters[i][1] > 3600.0: l.light_energy = 0.0; continue
		var p: Dictionary = emitters[i][0]
		var kind: String = PIECES[p.type].light
		if kind == "jack":
			l.position = Vector3(p.x, p.y + 0.4, p.z); l.light_color = Color.hex(0xff8a30ff).srgb_to_linear()
			l.light_energy = glow * (2.6 + sin(t * 9.0 + i) * 0.5 + sin(t * 21.0) * 0.3) / PI; l.omni_range = 6.0
		elif kind == "fire":
			l.position = Vector3(p.x, p.y + 0.8, p.z); l.light_color = Color.hex(0xff9a48ff).srgb_to_linear()
			l.light_energy = (5.0 + sin(t * 11.0 + i) * 1.0 + sin(t * 23.0) * 0.6) / PI; l.omni_range = 10.0
		else:
			var o := to_world_dir(p, LAMP_AT[0], 0)
			l.position = Vector3(p.x + o.x, p.y + LAMP_AT[1], p.z + o.y); l.light_color = Color.hex(0xffa860ff).srgb_to_linear()
			l.light_energy = glow * 4.5 / PI; l.omni_range = 11.0

func _near_type(t: String, pos: Vector3, r: float, dy := INF):
	for p in pieces:
		if p.type == t and Vector2(p.x - pos.x, p.z - pos.z).length() < r and absf(p.y - pos.y) < dy: return p
	return null
func bed_near(pos: Vector3, r := 2.4): return _near_type("bed", pos, r, 1.5)
func skep_near(pos: Vector3, r := 2.2): return _near_type("skep", pos, r)
func press_near(pos: Vector3, r := 2.3): return _near_type("press", pos, r)
func apple_tree_near(pos: Vector3, r := 2.6): return _near_type("homeapple", pos, r)
func patch_near(pos: Vector3, r := 2.6): return _near_type("patch", pos, r)
func woodpile_near(pos: Vector3, r := 2.2): return _near_type("woodpile", pos, r)
func feeder_near(pos: Vector3, r := 2.2): return _near_type("feeder", pos, r)

## Snowmen melt when the snow does: each folds down onto the page and is gone.
func melt_snowmen() -> void:
	for p in pieces.duplicate(): if p.type == "snowman": fold_away(p)
## Each morning every Homestead producer fills another morning's worth (up to its cap waiting).
func tend_producers(day: int, time: float) -> void:
	for p in pieces:
		if not EXTRA.has(p.type) or not EXTRA[p.type].has("makes"): continue
		if p.stock == null: p.stock = 0
		if p.day == null: p.day = day
		if day != p.day and time >= 0.25: p.day = day; p.stock = mini(int(EXTRA[p.type].cap), int(p.stock) + 1)

## The Homestead piece the farmer stands at (within its footprint and a step), or null.
func extra_near(pos: Vector3):
	for p in pieces:
		if not EXTRA.has(p.type) or p.type == "palisade": continue
		var f: Array = DATA.FOOT[p.type]
		var l := piece_local(p, pos.x, pos.z)
		if absf(l.x) < f[0] + 1.6 and absf(l.y) < f[1] + 1.6 and absf(p.y - pos.y) < 2.5: return p
	return null

## Each morning every skep's bees fill another comb (up to 3 waiting).
func tend_skeps(day: int, time: float) -> void:
	for p in pieces:
		if p.type != "skep": continue
		if p.stock == null: p.stock = 0
		if p.day == null: p.day = day
		if day != p.day and time >= 0.25: p.day = day; p.stock = mini(3, p.stock + 1)
## Each morning the birds eat a day's worth from every feeder.
func tend_feeders(day: int, time: float) -> void:
	for p in pieces:
		if p.type != "feeder": continue
		if p.stock == null: p.stock = 0
		if p.day == null: p.day = day
		if day != p.day and time >= 0.25: p.day = day; p.stock = maxi(0, p.stock - 1)
## Saplings grow into apple trees two mornings after planting; your trees ripen two apples each morning (up to 6).
func tend_trees(day: int, time: float, on_grown: Callable) -> void:
	for p in pieces.duplicate():
		if p.type == "sapling":
			if p.day == null: p.day = day
			if day - p.day >= 2 and time >= 0.25:
				fold_away(p)
				var t := add({"type": "homeapple", "x": p.x, "y": p.y, "z": p.z, "rot": p.rot, "stock": 2, "day": day})
				if on_grown.is_valid(): on_grown.call(t)
		elif p.type == "homeapple":
			if p.stock == null: p.stock = 2
			if p.day == null: p.day = day
			if day != p.day and time >= 0.25: p.day = day; p.stock = mini(6, p.stock + 2)

func fire_distance(pos: Vector3) -> float:
	var d := INF
	for p in pieces: if p.type == "campfire": d = minf(d, Vector2(p.x - pos.x, p.z - pos.z).length())
	return d

func roof_at(x: float, z: float) -> bool:
	for p in nearby(x, z, 1.2):
		if p.type != "roof" and p.type != "ridge": continue
		var l := piece_local(p, x, z)
		if absf(l.x) < 1.1 and absf(l.y) < 1.1: return true
	return false

func station_near(t: String, pos: Vector3, r := 7.0) -> bool:
	for p in pieces: if p.type == t and (p.x - pos.x) * (p.x - pos.x) + (p.z - pos.z) * (p.z - pos.z) < r * r: return true
	return false

func near_fire(pos: Vector3) -> bool:
	for p in pieces: if p.type == "campfire" and (p.x - pos.x) * (p.x - pos.x) + (p.z - pos.z) * (p.z - pos.z) < 16.0: return true
	return false

## What a save keeps of each piece.
func save_pieces() -> Array:
	var out := []
	for p in pieces: out.append({"type": p.type, "x": p.x, "y": p.y, "z": p.z, "rot": p.rot, "stock": p.stock, "day": p.day, "stage": p.stage, "tendDay": p.tendDay})
	return out
func load_pieces(list: Array) -> void:
	loading = true
	for p in list: if PIECES.has(p.type): add(p, true)
	loading = false
	trim_legs()
