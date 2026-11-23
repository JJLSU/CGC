class_name Railroad
extends Node3D
## railroad.js: once all three of Cold Glitter Creek's streets stand mended, a line is laid from a paper depot past the
## church out across the county, through a whistle-stop in each wild land. The right-of-way is surveyed from the start
## (cleared before any of the county is built), so the track goes down on open ground the day the town earns it.
## Ties and iron rails (trestles over water), telegraph poles with sagging wires, the depot on its platform, at each
## whistle-stop a platform and name board and a trading post behind it with its keeper out front by day.

const TIE := 0.9
const LAND_KEYS := ["hollows", "breaks", "fen", "prairie", "pines"]
const NAMES := {"hollows": "Silver Birch Hollows", "breaks": "Redrock Breaks", "fen": "Misty Fen", "prairie": "Golden Prairie", "pines": "Bluepine Highlands"}
const KEEPERS := {"hollows": {"model": "trades_5", "hue": 0.6}, "breaks": {"model": "prospectors_4", "hue": 0.0}, "fen": {"model": "folk_calico_01", "hue": 2.2}, "prairie": {"model": "folk_farmhand_02", "hue": 0.4}, "pines": {"model": "trades_2", "hue": 3.4}}

var built := false
var depot := Vector3.ZERO
var stops: Array = []
var path: Array = []
var length := 0.0
var depot_group: Node3D
var freight_at = null
var freight := 0
var crates: Array = []
static var _wood: Material
static var _iron: Material

static func wood() -> Material:
	if _wood == null: _wood = PaperMats.paper(Color.hex(0x6a4a30ff))
	return _wood

func _init(world: World, town: Town, home: Vector3) -> void:
	visible = false
	var A := town.at; var along := town.along
	depot = A + along * 36.0
	var start := A + along * 52.0
	# a whistle-stop in each wild land: its nearest good stretch, visited in turn, nearest first
	var found := {}
	var r := 80.0
	while r < 760.0 and found.size() < 5:
		var a := 0.0
		while a < TAU:
			var x := depot.x + cos(a) * r; var z := depot.z + sin(a) * r
			Terrain.land_at(x, z)
			for k in LAND_KEYS:
				if not found.has(k) and Terrain.L_w[k] > 0.9 and not Terrain.is_water(x, z) and _open_ground(x, z): found[k] = Vector3(x, 0, z)
			a += 0.08
		r += 25.0
	var at := start
	var left := found.keys()
	while left.size():
		left.sort_custom(func(p, q): return found[p].distance_to(at) < found[q].distance_to(at))
		var k: String = left.pop_front()
		stops.append({"land": k, "name": NAMES[k], "at": found[k]}); at = found[k]
	# the route: the depot, a straight run out past the church, then stop to stop, swinging wide of the town and home,
	# and (the port's own: the web runs straight) round the mountains, never up them
	var pts := [depot, start]
	var avoid := [[A, 58.0], [home, 48.0]]
	for s in stops:
		var from: Vector3 = pts[-1]
		var leg := _route(from, s.at, avoid)
		if leg.is_empty():
			for av in avoid:
				var c: Vector3 = av[0]; var rr: float = av[1]
				var d: Vector3 = s.at - from; var len := d.length(); var u := d / len
				var t := clampf((c - from).dot(u), 0.0, len); var close := from + u * t
				if close.distance_to(c) < rr and t > 1.0 and t < len - 1.0:
					var side := Vector3(-u.z, 0, u.x)
					if side.dot(close - c) < 0.0: side = -side
					pts.append(c + side * (rr + 10.0)) # (around it)
		else: pts.append_array(leg)
		pts.append(s.at)
	# sampled every TIE metres
	for i in pts.size() - 1:
		var a: Vector3 = pts[i]; var b: Vector3 = pts[i + 1]; var n := maxi(1, roundi(a.distance_to(b) / TIE))
		for j in n: path.append(a.lerp(b, float(j) / n))
	path.append(pts[-1])
	length = path.size() * TIE
	# the right-of-way: nothing grows on it
	for i in range(0, path.size(), 5): world.exclusions.append({"x": path[i].x, "z": path[i].z, "r": 3.4})
	world.exclusions.append({"x": depot.x, "z": depot.z, "r": 9.0})
	for s in stops: world.exclusions.append({"x": s.at.x, "z": s.at.z, "r": 6.0})
	# each stop's layout: the platform a few ties back along the incoming track on the outside of the bend, the post behind
	for s in stops:
		var k := 0
		for j in path.size(): if path[j].distance_to(s.at) < path[k].distance_to(s.at): k = j
		var i := maxi(2, k - 6)
		var a: Vector3 = path[maxi(0, i - 2)]; var b: Vector3 = path[mini(path.size() - 1, i + 2)]; var yaw := atan2(b.x - a.x, b.z - a.z)
		var side := Vector3(cos(yaw), 0, -sin(yaw))
		var out: Vector3 = path[mini(path.size() - 1, k + 8)] - path[k]
		if out.dot(side) > 0.0: side = -side
		var alg := Vector3(sin(yaw), 0, cos(yaw))
		s.geo = {"i": i, "side": side, "along": alg, "plat": path[i] + side * 2.4, "post": path[i] + side * 8.6 - alg * 1.5}
		world.exclusions.append({"x": s.geo.post.x, "z": s.geo.post.z, "r": 6.5})
		if s.land == "breaks": # (your gold claim, if you file one: claim.js)
			s.geo.claim = path[i] + side * 11.0 - alg * 17.0; world.exclusions.append({"x": s.geo.claim.x, "z": s.geo.claim.z, "r": 9.5})

## A stop's ground: open country, no mountain within a stone's throw.
static func _open_ground(x: float, z: float) -> bool:
	for k in 9:
		var a := k * TAU / 8.0; var d := 0.0 if k == 8 else 18.0
		if Terrain.range_at(x + cos(a) * d, z + sin(a) * d) > 0.04: return false
	return true

## The line between two points round the mountains (and wide of the town and the farm): a grid search, 12 m cells
## over the pair's box and 240 m round it; mountain ground is solid, water dearer (the track bridges it on trestles).
## The way it finds is smoothed (corner-cutting, twice) and returned without its ends; empty if there's none.
const CELL := 12.0
static func _route(a: Vector3, b: Vector3, avoid: Array) -> Array:
	var x0 := minf(a.x, b.x) - 240.0; var z0 := minf(a.z, b.z) - 240.0
	var w := int((absf(a.x - b.x) + 480.0) / CELL) + 1; var h := int((absf(a.z - b.z) + 480.0) / CELL) + 1
	var g := AStarGrid2D.new(); g.region = Rect2i(0, 0, w, h); g.cell_size = Vector2(CELL, CELL)
	g.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES; g.update()
	var cell := func(p: Vector3) -> Vector2i: return Vector2i(clampi(int((p.x - x0) / CELL), 0, w - 1), clampi(int((p.z - z0) / CELL), 0, h - 1))
	var ca: Vector2i = cell.call(a); var cb: Vector2i = cell.call(b)
	for j in h:
		for i in w:
			var x := x0 + (i + 0.5) * CELL; var z := z0 + (j + 0.5) * CELL
			var c := Vector2i(i, j)
			if c == ca or c == cb: continue
			var blocked := Terrain.range_at(x, z) > 0.1
			for av in avoid: if Vector2(x - av[0].x, z - av[0].z).length() < av[1]: blocked = true
			if blocked: g.set_point_solid(c, true)
			elif Terrain.is_water(x, z): g.set_point_weight_scale(c, 3.0)
	var ids := g.get_id_path(ca, cb)
	if ids.size() < 2: return []
	var pts := []
	for c in ids: pts.append(Vector3(x0 + (c.x + 0.5) * CELL, 0, z0 + (c.y + 0.5) * CELL))
	pts[0] = a; pts[-1] = b
	for it in 2: # (Chaikin: each corner cut to a curve)
		var sm := [pts[0]]
		for k in pts.size() - 1:
			sm.append(pts[k].lerp(pts[k + 1], 0.25)); sm.append(pts[k].lerp(pts[k + 1], 0.75))
		sm.append(pts[-1]); pts = sm
	return pts.slice(1, pts.size() - 1)

func ty(p: Vector3) -> float: return 0.55 if Terrain.is_water(p.x, p.z) else Terrain.get_height(p.x, p.z) + 0.04

## Lay the track and put up the depot (once: the town has earned its railroad).
func build() -> void:
	if built: return
	built = true; visible = true
	var ys := path.map(func(p): return ty(p))
	# ties, one MultiMesh down the whole line; trestle legs down to the water's bottom
	var tm := MultiMesh.new(); tm.transform_format = MultiMesh.TRANSFORM_3D; var tb := BoxMesh.new(); tb.size = Vector3(1.7, 0.08, 0.24); tm.mesh = tb; tm.instance_count = path.size()
	var posts := SurfaceTool.new(); posts.begin(Mesh.PRIMITIVE_TRIANGLES); var any_post := false
	for i in path.size():
		var a: Vector3 = path[maxi(0, i - 1)]; var b: Vector3 = path[mini(path.size() - 1, i + 1)]; var yaw := atan2(b.x - a.x, b.z - a.z)
		tm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, yaw), Vector3(path[i].x, ys[i], path[i].z))) # (square across the rails: the web turns them a quarter too far, lying along the track)
		if ys[i] > Terrain.get_height(path[i].x, path[i].z) + 0.3 and i % 3 == 0:
			for s in [-0.7, 0.7]:
				var px: float = path[i].x + cos(yaw) * s; var pz: float = path[i].z - sin(yaw) * s; var h: float = ys[i] - minf(0.0, Terrain.get_height(px, pz)) + 0.2
				var bm := BoxMesh.new(); bm.size = Vector3(0.14, h, 0.14); posts.append_from(bm, 0, Transform3D(Basis(), Vector3(px, ys[i] - h / 2.0, pz))); any_post = true
	var tmi := MultiMeshInstance3D.new(); tmi.multimesh = tm; tmi.material_override = wood(); tmi.custom_aabb = AABB(Vector3(-1e5, -100, -1e5), Vector3(2e5, 400, 2e5)); add_child(tmi)
	if any_post: var pm := MeshInstance3D.new(); pm.mesh = posts.commit(); pm.material_override = wood(); add_child(pm)
	# the two iron rails, a short straight bar between every few ties, following the ground
	var bars := SurfaceTool.new(); bars.begin(Mesh.PRIMITIVE_TRIANGLES)
	var i := 0
	while i + 3 < path.size():
		var a: Vector3 = path[i]; var b: Vector3 = path[i + 3]; var ya: float = ys[i] + 0.08; var yb: float = ys[i + 3] + 0.08; var yaw := atan2(b.x - a.x, b.z - a.z)
		for s in [-0.55, 0.55]:
			var from := Vector3(a.x + cos(yaw) * s, ya, a.z - sin(yaw) * s); var to := Vector3(b.x + cos(yaw) * s, yb, b.z - sin(yaw) * s)
			var bm := BoxMesh.new(); bm.size = Vector3(0.07, 0.07, from.distance_to(to) + 0.02)
			bars.append_from(bm, 0, Transform3D(Basis.looking_at(to - from, Vector3.UP), (from + to) * 0.5))
		i += 3
	var rails := MeshInstance3D.new(); rails.mesh = bars.commit(); rails.material_override = PaperMats.paper(Color.hex(0x3a3632ff)); add_child(rails)
	_string_wire(ys)
	_make_depot()
	freight_at = depot_group.to_global(Vector3(-4.6, 0.3, 2.4)) # (the freight office's end of the platform)
	for s in stops: _make_stop(s)

## Telegraph poles beside the line, a crossarm and two glass insulators on each, and two sagging wires between them.
func _string_wire(ys: Array) -> void:
	var poles := SurfaceTool.new(); poles.begin(Mesh.PRIMITIVE_TRIANGLES)
	var glass := SurfaceTool.new(); glass.begin(Mesh.PRIMITIVE_TRIANGLES)
	var wire := PackedVector3Array(); var last = null; var any := false
	var clear_of := func(x: float, z: float) -> bool:
		for s in stops:
			if Vector2(s.geo.plat.x - x, s.geo.plat.z - z).length() <= 6.0 or Vector2(s.geo.post.x - x, s.geo.post.z - z).length() <= 7.0: return false
		return Vector2(depot.x - x, depot.z - z).length() > 11.0
	var i := 8
	while i < path.size() - 4:
		var a: Vector3 = path[i - 1]; var b: Vector3 = path[i + 1]; var yaw := atan2(b.x - a.x, b.z - a.z)
		var x: float = path[i].x - cos(yaw) * 2.9; var z: float = path[i].z + sin(yaw) * 2.9
		if Terrain.is_water(x, z) or ys[i] > Terrain.get_height(path[i].x, path[i].z) + 0.3 or not clear_of.call(x, z): last = null; i += 24; continue
		var y := Terrain.get_height(x, z); var lean := ((i * 7919) % 100) / 100.0 - 0.5 # (each pole a little off true)
		var pb := BoxMesh.new(); pb.size = Vector3(0.16, 4.6, 0.16)
		poles.append_from(pb, 0, Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.BACK, lean * 0.04), Vector3(x, y, z)) * Transform3D(Basis(), Vector3(0, 2.3, 0)))
		var cb := BoxMesh.new(); cb.size = Vector3(1.3, 0.12, 0.12)
		poles.append_from(cb, 0, Transform3D(Basis(Vector3.UP, yaw), Vector3(x, y, z)) * Transform3D(Basis(), Vector3(0, 4.3, 0)))
		var ends := [Vector3(x + cos(yaw) * -0.55, y + 4.46, z - sin(yaw) * -0.55), Vector3(x + cos(yaw) * 0.55, y + 4.46, z - sin(yaw) * 0.55)]
		for e in ends: var gc := CylinderMesh.new(); gc.top_radius = 0.05; gc.bottom_radius = 0.07; gc.height = 0.16; gc.radial_segments = 6; gc.rings = 1; glass.append_from(gc, 0, Transform3D(Basis(), e - Vector3(0, 0.02, 0)))
		if last != null:
			for w in 2: # each wire sags between its two poles
				var p0: Vector3 = last[w]; var p1: Vector3 = ends[w]
				for k in 6:
					var t0 := k / 6.0; var t1 := (k + 1) / 6.0
					wire.append(p0.lerp(p1, t0) - Vector3(0, sin(t0 * PI) * 0.45, 0)); wire.append(p0.lerp(p1, t1) - Vector3(0, sin(t1 * PI) * 0.45, 0))
		last = ends; any = true
		i += 24
	if not any: return
	var pm := MeshInstance3D.new(); pm.mesh = poles.commit(); pm.material_override = PaperMats.paper(Color.hex(0x5e4630ff)); add_child(pm)
	var gm := MeshInstance3D.new(); gm.mesh = glass.commit(); gm.material_override = PaperMats.paper(Color.hex(0x7fb0a0ff)); add_child(gm)
	var im := ImmediateMesh.new(); var lm := StandardMaterial3D.new(); lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; lm.albedo_color = Color.hex(0x2a2018ff)
	im.surface_begin(Mesh.PRIMITIVE_LINES, lm)
	for v in wire: im.surface_add_vertex(v)
	im.surface_end()
	var wm := MeshInstance3D.new(); wm.mesh = im; wm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; add_child(wm)

static func _box(w: float, h: float, d: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var b := BoxMesh.new(); b.size = Vector3(w, h, d); var m := MeshInstance3D.new(); m.mesh = b; m.material_override = mat; m.position = pos; return m

## The depot: the telegraph office's model on a long plank platform beside the line, the name board on two posts.
func _make_depot() -> void:
	var g := Node3D.new(); var y := Terrain.get_height(depot.x, depot.z)
	g.add_child(_box(14, 0.3, 4.6, Vector3(0, 0.15, 2.6), wood()))
	var house := Town.model("bldg_telegraph_restored", 7.0, 0)
	if house:
		var bb := PaperMats._aabb(house.get_child(0), Transform3D.IDENTITY)
		house.scale = Vector3.ONE * (7.0 / maxf(bb.size.x, bb.size.z)); house.position = Vector3(0, 0, -1.4); g.add_child(house)
	var sign := Town.card([[-2.1, 0], [2.1, 0.02], [2.15, 0.62], [-2.1, 0.6]], "res://assets/baked/rail/depot_sign", 0.04); sign.position = Vector3(5.2, 2.1, 4.6); g.add_child(sign)
	for x in [3.3, 7.1]: g.add_child(_box(0.14, 2.6, 0.14, Vector3(x, 1.3, 4.6), wood()))
	var a: Vector3 = path[0]; var b: Vector3 = path[6]; var yaw := atan2(b.x - a.x, b.z - a.z); var side := Vector3(cos(yaw), 0, -sin(yaw))
	g.rotation.y = yaw + PI / 2.0 # (its front and platform toward the track)
	var p: Vector3 = path[3] - side * 5.4; g.position = Vector3(p.x, y, p.z)
	add_child(g); depot_group = g

## A whistle-stop: a short plank platform beside the line and a name board on two posts; and its trading post.
func _make_stop(s: Dictionary) -> void:
	var side: Vector3 = s.geo.side; var p: Vector3 = s.geo.plat; var y := Terrain.get_height(p.x, p.z)
	var g := Node3D.new()
	g.add_child(_box(2.4, 0.25, 6, Vector3(0, 0.12, 0), wood()))
	for z in [-2.2, 2.2]: g.add_child(_box(0.12, 2.2, 0.12, Vector3(0.9, 1.1, z * 0.45), wood()))
	var board := Town.card([[-1.2, 0], [1.2, 0.02], [1.22, 0.42], [-1.2, 0.4]], "res://assets/baked/rail/stop_" + s.land, 0.04); board.position = Vector3(0.9, 2.0, 0); board.rotation.y = -PI / 2.0; g.add_child(board) # (read from the track)
	g.position = Vector3(p.x, y, p.z); g.rotation.y = atan2(side.x, side.z) - PI / 2.0 # (lookAt the outside, then a quarter turn: deck along the track, the board facing it)
	add_child(g); s.platform = p; s.stand = path[s.geo.i]
	_make_post(s)

## The trading post behind a whistle-stop: a little cottage store facing the track, a barrel and crates, a plank walk
## down to the platform, the sign, and its keeper out front by day.
func _make_post(s: Dictionary) -> void:
	var side: Vector3 = s.geo.side; var post: Vector3 = s.geo.post; var y := Terrain.get_height(post.x, post.z); var face := atan2(-side.x, -side.z)
	var g := Node3D.new(); g.position = Vector3(post.x, y, post.z); g.rotation.y = face
	var put := func(nm: String, size: float, x: float, z: float, turn := 0.0, by_height := false) -> void:
		var path_m := "res://assets/models/props/%s.glb" % nm
		if not ResourceLoader.exists(path_m): return
		var h := PaperMats.seated(load(path_m), size, by_height); h.position = Vector3(x, 0, z); h.rotation.y = turn; g.add_child(h)
	put.call("bldg_cottage_restored", 6.2, 0.0, -0.6)
	put.call("prop_barrel", 0.95, 2.7, 2.6, 0.4, true); put.call("prop_crates", 1.0, -2.8, 2.4, -0.3, true)
	for k in 5: var pl := _box(1.3, 0.06, 0.32, Vector3((k % 2) * 0.08 - 0.04, 0.03, 3.1 + k * 0.62), wood()); g.add_child(pl)
	var sign := Town.card([[-1.5, 0], [1.5, 0.03], [1.52, 0.56], [-1.48, 0.54]], "res://assets/baked/rail/post_" + s.land, 0.04); sign.position = Vector3(-2.6, 1.9, 3.0); g.add_child(sign)
	for x in [-3.8, -1.4]: g.add_child(_box(0.12, 2.3, 0.12, Vector3(x, 1.15, 3.0), wood()))
	add_child(g); s.post_group = g
	s.door = g.to_global(Vector3(0, 0, 2.6)) # (where you trade: the step before the door)
	var K: Dictionary = KEEPERS[s.land]
	var f := ModelFigure.new(K.model, {"hue": K.hue}); var kat := g.to_global(Vector3(1.3, 0, 2.9))
	f.root.position = Vector3(kat.x, Terrain.get_height(kat.x, kat.z), kat.z); f.root.rotation.y = face + 0.3; add_child(f.root); s.keeper = f

## The whistle-stop whose trading post (x, z) is standing at, if any.
func post_at(x: float, z: float, r := 3.0):
	if not built: return null
	for s in stops: if s.has("door") and Vector2(s.door.x - x, s.door.z - z).length() < r: return s
	return null

## The keepers: out front by day, and only animated while you're near.
func update(dt: float, player: Player, day: bool) -> void:
	if not built: return
	for s in stops:
		if not s.has("keeper"): continue
		var near := Vector2(s.door.x - player.pos.x, s.door.z - player.pos.z).length() < 60.0
		s.keeper.root.visible = day and near
		if s.keeper.root.visible: s.keeper.update(dt, 0.0, null)

## A crate of freight set out on the platform (stacking up, four to a row) for the next train.
func add_freight() -> void:
	freight += 1
	if depot_group == null or freight - 1 >= 8: return
	var i := freight - 1
	var h := PaperMats.seated(load("res://assets/models/props/prop_crates.glb"), 1.1, true)
	h.position = Vector3(-5.8 + (i % 4) * 1.1, 0.3, 3.6 - floori(i / 4.0) * 1.1); h.rotation.y = fmod(i * 1.7, 1.0) - 0.5
	depot_group.add_child(h); crates.append(h)
## The train has called at the depot and taken the freight aboard.
func take_freight() -> int:
	var n := freight
	for c in crates: c.queue_free()
	crates = []; freight = 0
	return n
func save() -> Dictionary: return {"built": built, "freight": freight}
