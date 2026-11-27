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
## (each a figure of the player's new folk, re-dyed, once made: "new"; else the old model)
const KEEPERS := {"hollows": {"new": "cgc_woman_greenbustle", "model": "trades_5", "hue": 0.6}, "breaks": {"new": "cgc_man_ragged", "model": "prospectors_4", "hue": 0.0}, "fen": {"new": "cgc_woman_plumstripe", "model": "folk_calico_01", "hue": 2.2}, "prairie": {"new": "cgc_man_youth", "model": "folk_farmhand_02", "hue": 0.4}, "pines": {"new": "cgc_woman_calico", "model": "trades_2", "hue": 3.4}}

var built := false
var depot := Vector3.ZERO
var stops: Array = []
var path: Array = []
var length := 0.0
var depot_group: Node3D
var freight_at = null
var freight := 0
var crates: Array = []
## The line past the town (the player: a station on the other side of town that the tracks go by realistically): it
## runs straight down the far side from Chinatown, TRACK_O out from Main Street, parallel to the streets; the depot
## stands at the end of the north cross street between the town and the track, and the line carries on past it the
## other way (tail: track the trains don't use, so it reads as a through line). Across the track, the storage yard.
const TRACK_O := 74.0
var tail: Array = []
var depot_i := 0      ## the depot's tie along the line (the train's home)
var yard := Vector3.ZERO
var far := 1.0        ## which side of Main Street the station is on (toward x far)
var town_ref: Town
static var _wood: Material
static var _iron: Material

static func wood() -> Material:
	if _wood == null: _wood = PaperMats.paper(Color.hex(0x6a4a30ff))
	return _wood

var world_ref: World ## (the claim's mine puts its walls in the world's colliders)
func _init(world: World, town: Town, home: Vector3) -> void:
	world_ref = world
	visible = false
	var A := town.at; var along := town.along; var toward := town.toward; town_ref = town
	far = -signf(town.street_offs[2]) if town.street_offs.size() > 2 else 1.0
	var dout := along if far < 0.0 else -along # (the way out of the depot: the town on its left, the depot's side)
	depot = A + along * Town.CROSS_N + toward * far * TRACK_O + dout * 14.0 # (a little down the line from where the cross street meets it: the street comes out by the platform's end, not into the house)
	var start := depot + dout * 110.0
	for i in 60: tail.append(depot - dout * (i + 1) * TIE) # (the line on past the depot, the other way)
	yard = A + along * (Town.CROSS_N - 4.0) + toward * far * (TRACK_O + 15.0)
	# the right-of-way and the depot's ground level and clear; the yard's too; the cross street's last stretch out to it
	for i in range(0, 260, 8):
		var q: Vector3 = depot - dout * 90.0 + dout * i
		Terrain.add_flat_area(q.x, q.z, 6, 12)
	Terrain.add_flat_area(yard.x, yard.z, 13, 20); world.exclusions.append({"x": yard.x, "z": yard.z, "r": 12.0})
	var o := 30.0
	while o < TRACK_O:
		var q: Vector3 = A + along * Town.CROSS_N + toward * far * o
		Terrain.add_flat_area(q.x, q.z, 7, 13); world.exclusions.append({"x": q.x, "z": q.z, "r": 6.5}); o += 8.0
	# (wide of the whole town, streets and all, and of the farm)
	var omin := 0.0; var omax := 0.0
	for so in town.street_offs: omin = minf(omin, so); omax = maxf(omax, so)
	omin -= 16.0; omax += 16.0
	var tc: Vector3 = A + toward * ((omin + omax) / 2.0)
	var tr := minf((omax - omin) / 2.0 + 8.0, absf(far * TRACK_O - (omin + omax) / 2.0) - 9.0) # (never so wide it takes in the line past the depot)
	var avoid := [[tc - along * 38.0, tr], [tc, tr], [tc + along * 38.0, tr], [home, 48.0]] # (three, down its length: a town is long, not round)
	var clear_of_town := func(q: Vector3) -> bool:
		for av in avoid: if Vector2(q.x - av[0].x, q.z - av[0].z).length() < float(av[1]) + 28.0: return false
		return true
	# the line (the player: it needn't go anywhere useful; one long track through the whole map, one stop, at town): from
	# far out one way, the straight run past the depot beside the town, and far out the other way, round the mountains
	var fwd_run := start; var back_run := depot - dout * 70.0
	var fwd_end := _open_end(depot, dout, 680.0, clear_of_town); var back_end := _open_end(depot, -dout, 680.0, clear_of_town)
	var fwd := [fwd_run] + _route(fwd_run, fwd_end, avoid, [depot, back_run]) + [fwd_end]
	var laid: Array = [depot, back_run]
	for i in fwd.size() - 1:
		var n := maxi(1, ceili((fwd[i] as Vector3).distance_to(fwd[i + 1]) / 6.0))
		for j in n: laid.append((fwd[i] as Vector3).lerp(fwd[i + 1], float(j) / n))
	var back := [back_run] + _route(back_run, back_end, avoid, laid) + [back_end]
	back.reverse()
	var pts: Array = back + [depot] + fwd
	tail = []
	# sampled every TIE metres
	for i in pts.size() - 1:
		var a: Vector3 = pts[i]; var b: Vector3 = pts[i + 1]; var n := maxi(1, roundi(a.distance_to(b) / TIE))
		for j in n: path.append(a.lerp(b, float(j) / n))
	path.append(pts[-1])
	length = path.size() * TIE
	for j in path.size(): if path[j].distance_to(depot) < path[depot_i].distance_to(depot): depot_i = j
	_grade()
	# the right-of-way: nothing grows on it
	for i in range(0, path.size(), 5): world.exclusions.append({"x": path[i].x, "z": path[i].z, "r": 3.4})
	world.exclusions.append({"x": depot.x, "z": depot.z, "r": 9.0})
	# a trading post in each wild land (no longer a stop on the line: the train calls only at town): its nearest good
	# stretch out in the county, never in the town or by the farm, and well off the track
	var off_line := func(q: Vector3) -> bool:
		for j in range(0, path.size(), 8): if Vector2(path[j].x - q.x, path[j].z - q.z).length() < 30.0: return false
		return true
	var found := {}
	var r := 110.0
	while r < 780.0 and found.size() < 5:
		var a := 0.0
		while a < TAU:
			var x := tc.x + cos(a) * r; var z := tc.z + sin(a) * r
			Terrain.land_at(x, z)
			for k in LAND_KEYS:
				if not found.has(k) and Terrain.L_w[k] > 0.9 and not Terrain.is_water(x, z) and _open_ground(x, z) and clear_of_town.call(Vector3(x, 0, z)) and off_line.call(Vector3(x, 0, z)): found[k] = Vector3(x, 0, z)
			a += 0.06
		r += 25.0
	for k in LAND_KEYS: if found.has(k): stops.append({"land": k, "name": NAMES[k], "at": found[k]})
	for st in stops:
		var k := 0
		for j in range(0, path.size(), 4): if path[j].distance_to(st.at) < path[k].distance_to(st.at): k = j
		var side: Vector3 = Vector3(st.at.x - path[k].x, 0, st.at.z - path[k].z).normalized() # (its front toward the line)
		var alg := Vector3(-side.z, 0, side.x)
		st.geo = {"i": k, "side": side, "along": alg, "plat": st.at, "post": st.at}
		world.exclusions.append({"x": st.at.x, "z": st.at.z, "r": 7.5})
		if st.land == "breaks": # (your gold claim, if you file one: claim.js)
			st.geo.claim = st.at + side * 6.0 - alg * 17.0; world.exclusions.append({"x": st.geo.claim.x, "z": st.geo.claim.z, "r": 9.5})
			# (the claim's ground and its mine's, out along its own -x: levelled and kept clear, a bench cut into the land)
			var ry := atan2(-side.x, -side.z); var xa := Vector3(cos(ry), 0, -sin(ry))
			for mk in [0.0, -6.0, -12.0, -18.0, -24.0]:
				var q: Vector3 = st.geo.claim + xa * mk
				Terrain.add_flat_area(q.x, q.z, 7.0, 12.0); world.exclusions.append({"x": q.x, "z": q.z, "r": 7.5})

## Where the line ends, out along dir: as far as reach on open, dry, low ground, clear of the town (a little either side
## of dir, then nearer, till one is found).
static func _open_end(from: Vector3, dir: Vector3, reach: float, ok: Callable) -> Vector3:
	for d in [reach, reach * 0.85, reach * 0.7, reach * 0.55, reach * 0.4]:
		for ang in [0.0, 0.25, -0.25, 0.5, -0.5]:
			var u := dir.rotated(Vector3.UP, ang); var q: Vector3 = from + u * d
			if not Terrain.is_water(q.x, q.z) and Terrain.range_at(q.x, q.z) < 0.03 and ok.call(q): return Vector3(q.x, 0, q.z)
	return from + dir * 200.0

static func _perms(a: Array) -> Array:
	if a.size() <= 1: return [a.duplicate()]
	var out := []
	for i in a.size():
		var rest := a.duplicate(); var x = rest.pop_at(i)
		for p in _perms(rest): out.append([x] + p)
	return out

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
## The railbed's grade (the player's ask: the track runs on level-ish ground that makes sense): the ground along the
## line, smoothed over ~70 m, then held to a 3% climb either way (passes forward and back), never below the water's
## level (trestles cross water). Terrain eases a narrow strip to it: cuts through rises, banks over hollows.
const MAX_GRADE := 0.03
func _grade() -> void:
	var raw := PackedFloat32Array(); raw.resize(path.size())
	for i in path.size(): raw[i] = Terrain.elevation(path[i].x, path[i].z)
	var w := 40; var g := PackedFloat32Array(); g.resize(path.size())
	var acc := 0.0; var cnt := 0
	for i in range(0, mini(w, path.size())): acc += raw[i]; cnt += 1
	for i in path.size():
		if i + w < path.size(): acc += raw[i + w]; cnt += 1
		if i - w - 1 >= 0: acc -= raw[i - w - 1]; cnt -= 1
		g[i] = acc / cnt
	var step := MAX_GRADE * TIE
	for i in range(1, path.size()): g[i] = clampf(g[i], g[i - 1] - step, g[i - 1] + step)
	for i in range(path.size() - 2, -1, -1): g[i] = clampf(g[i], g[i + 1] - step, g[i + 1] + step)
	var pts := PackedVector3Array(); pts.resize(path.size())
	for i in path.size(): pts[i] = Vector3(path[i].x, maxf(0.5, g[i]), path[i].z)
	for q in tail: pts.append(Vector3(q.x, maxf(0.5, g[0]), q.z)) # (the line on past the depot, level with it)
	Terrain.set_railbed(pts)

static var fallbacks := 0  ## (legs that found no way round and were laid straight: the layout test counts them)
## A leg round everything: tried in a 240 m margin, then 480 m, then (last) without keeping off the line already laid.
static func _route(a: Vector3, b: Vector3, avoid: Array, laid: Array = []) -> Array:
	for t in [[240.0, false], [480.0, false], [480.0, true]]:
		var r := _route_in(a, b, avoid, laid, t[0], t[1])
		if not r.is_empty(): return r
	fallbacks += 1
	return []
static func _route_in(a: Vector3, b: Vector3, avoid: Array, laid: Array, margin: float, soft := false) -> Array:
	var x0 := minf(a.x, b.x) - margin; var z0 := minf(a.z, b.z) - margin
	var w := int((absf(a.x - b.x) + margin * 2.0) / CELL) + 1; var h := int((absf(a.z - b.z) + margin * 2.0) / CELL) + 1
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
	# the line already laid: 14 m either side of it is out of bounds (no crossing, no running alongside), save
	# where this leg sets off from it
	for q in laid:
		if Vector2(q.x - a.x, q.z - a.z).length() < 8.0: continue
		var cq: Vector2i = cell.call(q)
		for dj in range(-1, 2):
			for di in range(-1, 2):
				var c := Vector2i(cq.x + di, cq.y + dj)
				if c.x < 0 or c.y < 0 or c.x >= w or c.y >= h or c == ca or c == cb: continue
				var cx := x0 + (c.x + 0.5) * CELL; var cz := z0 + (c.y + 0.5) * CELL
				if Vector2(cx - q.x, cz - q.z).length() < 14.0:
					if soft: g.set_point_weight_scale(c, 40.0) # (last try: across it only where there's no other way)
					else: g.set_point_solid(c, true)
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

func ty(p: Vector3) -> float: return (maxf(0.55, Terrain._rail_at(p.x, p.z).y) + 0.04) if Terrain.is_water(p.x, p.z) else Terrain.get_height(p.x, p.z) + 0.04 # (over water the trestle carries the grade across)
## The rail's height at tie i: the graded bed itself (the ground is eased to it; where the line passes near another
## stretch of itself the ground can't take both, but the track keeps its own grade).
func grade_at(i: int) -> float: return (Terrain.rail_pts[i].y if i < Terrain.rail_pts.size() else ty(path[i])) + 0.04
## ... at distance d along the line (the train).
func grade_d(d: float) -> float:
	var f := clampf(d / TIE, 0.0, path.size() - 1.001); var i := floori(f)
	return lerpf(grade_at(i), grade_at(i + 1), f - i)

## Lay the track and put up the depot (once: the town has earned its railroad).
func build() -> void:
	if built: return
	built = true; visible = true
	var ys := range(path.size()).map(func(i): return grade_at(i))
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
	_lay_tail()
	_pole()
	_string_wire(ys)
	_make_depot()
	_make_yard()
	if town_ref: town_ref.cross_sheet(far * (Town.STREET_OFF + 7.0), far * (TRACK_O - 4.0), Town.CROSS_N) # (the cross street's run out to the depot)
	freight_at = depot_group.to_global(Vector3(-4.6, 0.3, 2.4)) # (the freight office's end of the platform)
	for s in stops: _make_stop(s)

## The line on past the depot (tail): ties and rails as on the main line, level with the depot, running out of sight.
func _lay_tail() -> void:
	if tail.is_empty(): return
	var y: float = grade_at(0)
	var line := [path[0]] + tail
	var tm := MultiMesh.new(); tm.transform_format = MultiMesh.TRANSFORM_3D; var tb := BoxMesh.new(); tb.size = Vector3(1.7, 0.08, 0.24); tm.mesh = tb; tm.instance_count = line.size()
	var yaw := atan2(line[1].x - line[0].x, line[1].z - line[0].z)
	for i in line.size(): tm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, yaw), Vector3(line[i].x, y, line[i].z)))
	var tmi := MultiMeshInstance3D.new(); tmi.multimesh = tm; tmi.material_override = wood(); add_child(tmi)
	var bars := SurfaceTool.new(); bars.begin(Mesh.PRIMITIVE_TRIANGLES)
	var a: Vector3 = line[0]; var b: Vector3 = line[-1]
	for sd in [-0.55, 0.55]:
		var from := Vector3(a.x + cos(yaw) * sd, y + 0.08, a.z - sin(yaw) * sd); var to := Vector3(b.x + cos(yaw) * sd, y + 0.08, b.z - sin(yaw) * sd)
		var bm := BoxMesh.new(); bm.size = Vector3(0.07, 0.07, from.distance_to(to)); bars.append_from(bm, 0, Transform3D(Basis.looking_at(to - from, Vector3.UP), (from + to) * 0.5))
	var rails := MeshInstance3D.new(); rails.mesh = bars.commit(); rails.material_override = PaperMats.paper(Color.hex(0x3a3632ff)); add_child(rails)
	# a buffer stop where it ends: two posts and a beam
	var bs := Node3D.new(); bs.position = Vector3(b.x, y, b.z); bs.rotation.y = yaw
	for sd in [-0.6, 0.6]: bs.add_child(_box(0.25, 1.0, 0.25, Vector3(sd, 0.5, 0), wood()))
	bs.add_child(_box(1.8, 0.3, 0.3, Vector3(0, 0.85, 0), PaperMats.paper(Color.hex(0xa8352aff)))); add_child(bs)

## The storage yard across the track from the depot (the player: a storage yard with lots of boxes and stuff): stacks
## of crates, barrels in rows, a freight wagon and a handcart, piles of sawn lumber, all inside a rail fence.
func _make_yard() -> void:
	var g := Node3D.new(); var y := Terrain.get_height(yard.x, yard.z)
	g.position = Vector3(yard.x, y, yard.z); g.rotation.y = atan2(town_ref.along.x, town_ref.along.z) if town_ref else 0.0
	var put := func(nm: String, size: float, x: float, z: float, turn := 0.0, by_height := false, up := 0.0) -> void:
		var pm := "res://assets/models/props/%s.glb" % nm
		if not ResourceLoader.exists(pm): return
		var h := PaperMats.seated(load(pm), size, by_height); h.position = Vector3(x, up, z); h.rotation.y = turn; g.add_child(h)
	var rng := RandomNumberGenerator.new(); rng.seed = hash("yard")
	# crates, stacked two and three high
	for i in 6:
		for j in 2:
			var x := -8.0 + i * 1.5; var z := -6.0 + j * 1.4
			for k in rng.randi_range(1, 2): put.call("prop_crates", 1.1, x + rng.randf_range(-0.1, 0.1), z, rng.randf_range(-0.2, 0.2), true, k * 1.08 - 1.08) # (on the ground, one or two high)
	# barrels in rows
	for i in 5:
		for j in 2: put.call("prop_barrel", 1.0, 3.0 + i * 1.05, -6.2 + j * 1.05, rng.randf_range(0, TAU), true)
	# a freight wagon and a handcart
	put.call("veh_freight_wagon", 5.5, -3.0, 2.8, 0.15)
	put.call("veh_handcart", 2.2, 5.0, 2.5, -0.6)
	put.call("prop_haybales", 2.4, 8.5, 5.5, 0.3)
	# the player's cargo and supplies, about the yard: cotton bales off the last train, black powder and dynamite kept
	# well apart in a far corner, barrels of tools, crates of rifles, crates of bottles, an open crate, a box, a trunk
	for e in [["prop_cotton_bale", 1.5, 1.2, 5.6, 0.1, 0.0], ["prop_cotton_bale", 1.5, 2.9, 5.7, -0.15, 0.0], ["prop_cotton_bale", 1.5, 2.0, 5.65, 0.05, 1.0],
			["prop_powder_barrels", 1.6, 8.6, -1.0, 0.4, 0.0], ["prop_dynamite", 1.0, 8.8, 1.0, -0.3, 0.0],
			["prop_tool_barrels", 1.6, -8.6, 1.6, 0.2, 0.0], ["prop_weapon_crates", 1.5, -6.2, 0.6, -0.4, 0.0],
			["prop_bottle_crates", 1.2, 0.8, -1.6, 0.6, 0.0], ["prop_crate_open", 1.3, 2.4, -0.2, 0.3, 0.0],
			["prop_box_closed", 1.2, -1.0, -1.4, -0.2, 0.0], ["prop_trunk", 1.1, -0.4, 4.6, 1.2, 0.0]]:
		put.call(e[0], e[1], e[2], e[3], e[4], false, e[5])
	# sawn lumber, piled on sleepers
	for pile in [[-8.0, 5.5], [-8.0, 8.0]]:
		for k in 5:
			var plank := _box(4.2, 0.16, 0.9 - k * 0.08, Vector3(pile[0], 0.12 + k * 0.17, pile[1]), PaperMats.paper(Color.hex(0xc49a62ff) if k % 2 else Color.hex(0xb08650ff)))
			g.add_child(plank)
	# a rail fence round it, a gap toward the track
	var fence := PaperMats.paper(Color.hex(0x7a5a3cff))
	var fx := -far * 10.5 # (local +x is away from Main Street; the track's side, local far * x, left open)
	for side in [[fx, -8.5, fx, 10.0], [-10.5, -8.5, 10.5, -8.5], [-10.5, 10.0, 10.5, 10.0]]:
		var a := Vector2(side[0], side[1]); var b := Vector2(side[2], side[3]); var n: int = ceili(a.distance_to(b) / 2.5)
		for k in n + 1:
			var q := a.lerp(b, float(k) / n); g.add_child(_box(0.14, 1.2, 0.14, Vector3(q.x, 0.6, q.y), fence))
		for hgt in [0.5, 1.0]:
			var mid := (a + b) / 2.0; var len := a.distance_to(b)
			var rail := _box(0.07, 0.1, len, Vector3(mid.x, hgt, mid.y), fence); rail.rotation.y = atan2(b.x - a.x, b.y - a.y); g.add_child(rail)
	add_child(g)

## The Meshy telegraph pole as one mesh to draw many times: its mesh and printed card, the transform that stands it
## POLE_H tall on its foot, and where its outer insulators carry the wires (from its reference art: the top arm's
## outer pair, a third of the arm out either side, at 94% of the height).
const POLE_H := 5.4
var pole_kit = null
var pole_xfs: Array = []
func _pole() -> void:
	var path := "res://assets/models/props/prop_telegraph_medium.glb"
	if not ResourceLoader.exists(path): return
	var inst := (load(path) as PackedScene).instantiate() as Node3D
	PaperMats.paperize(inst)
	var mis := PaperMats._meshes(inst)
	if mis.is_empty(): inst.free(); return
	var mi: MeshInstance3D = mis[0]
	var xf := mi.global_transform if mi.is_inside_tree() else _rel(mi, inst)
	var bb := xf * mi.mesh.get_aabb()
	var k := POLE_H / bb.size.y
	var local := Transform3D(Basis().scaled(Vector3.ONE * k), Vector3.ZERO) * Transform3D(Basis(), -Vector3(bb.get_center().x, bb.position.y, bb.get_center().z)) * xf
	pole_kit = {"mesh": mi.mesh, "mat": mi.get_active_material(0), "local": local, "wire_y": POLE_H * 0.94, "wire_x": bb.size.x * k * 0.35}
	inst.free()
static func _rel(n: Node3D, top: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY; var c: Node = n
	while c != null and c != top: t = (c as Node3D).transform * t; c = c.get_parent()
	return t

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
		var ends: Array
		if pole_kit != null: # (the player's Meshy telegraph pole, its crossarms across the line; the wires on its outer insulators)
			pole_xfs.append(Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.BACK, lean * 0.04), Vector3(x, y, z)) * pole_kit.local)
			var wy: float = y + pole_kit.wire_y; var wx: float = pole_kit.wire_x
			ends = [Vector3(x + cos(yaw) * -wx, wy, z - sin(yaw) * -wx), Vector3(x + cos(yaw) * wx, wy, z - sin(yaw) * wx)]
		else:
			var pb := BoxMesh.new(); pb.size = Vector3(0.16, 4.6, 0.16)
			poles.append_from(pb, 0, Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.BACK, lean * 0.04), Vector3(x, y, z)) * Transform3D(Basis(), Vector3(0, 2.3, 0)))
			var cb := BoxMesh.new(); cb.size = Vector3(1.3, 0.12, 0.12)
			poles.append_from(cb, 0, Transform3D(Basis(Vector3.UP, yaw), Vector3(x, y, z)) * Transform3D(Basis(), Vector3(0, 4.3, 0)))
			ends = [Vector3(x + cos(yaw) * -0.55, y + 4.46, z - sin(yaw) * -0.55), Vector3(x + cos(yaw) * 0.55, y + 4.46, z - sin(yaw) * 0.55)]
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
	if pole_kit != null:
		var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.mesh = pole_kit.mesh; mm.instance_count = pole_xfs.size()
		for k in pole_xfs.size(): mm.set_instance_transform(k, pole_xfs[k])
		var mmi := MultiMeshInstance3D.new(); mmi.multimesh = mm; mmi.material_override = pole_kit.mat; mmi.custom_aabb = AABB(Vector3(-1e5, -100, -1e5), Vector3(2e5, 400, 2e5)); add_child(mmi)
	else:
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
	var dsign := Town.board_post("prop_sign_wide", 3.0, "res://assets/baked/rail/depot_sign", 5.33) # (the player's two-post sign)
	if dsign: dsign.position = Vector3(5.2, 0, 4.6); g.add_child(dsign)
	else:
		var sign := Town.card([[-2.1, 0], [2.1, 0.02], [2.15, 0.62], [-2.1, 0.6]], "res://assets/baked/rail/depot_sign", 0.04); sign.position = Vector3(5.2, 2.1, 4.6); g.add_child(sign)
		for x in [3.3, 7.1]: g.add_child(_box(0.14, 2.6, 0.14, Vector3(x, 1.3, 4.6), wood()))
	var a: Vector3 = path[depot_i]; var b: Vector3 = path[depot_i + 6]; var yaw := atan2(b.x - a.x, b.z - a.z); var side := Vector3(cos(yaw), 0, -sin(yaw))
	g.rotation.y = yaw + PI / 2.0 # (its front and platform toward the track)
	var p: Vector3 = path[depot_i + 3] - side * 5.4; g.position = Vector3(p.x, y, p.z)
	add_child(g); depot_group = g

## A whistle-stop: a short plank platform beside the line and a name board on two posts; and its trading post.
func _make_stop(s: Dictionary) -> void:
	s.platform = s.geo.post; s.stand = path[s.geo.i] # (no platform now: the train calls only at town)
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
	var psign := Town.board_post("prop_sign_wide", 2.6, "res://assets/baked/rail/post_" + s.land, 5.12)
	if psign: psign.position = Vector3(-2.6, 0, 3.0); g.add_child(psign)
	else:
		var sign := Town.card([[-1.5, 0], [1.5, 0.03], [1.52, 0.56], [-1.48, 0.54]], "res://assets/baked/rail/post_" + s.land, 0.04); sign.position = Vector3(-2.6, 1.9, 3.0); g.add_child(sign)
		for x in [-3.8, -1.4]: g.add_child(_box(0.12, 2.3, 0.12, Vector3(x, 1.15, 3.0), wood()))
	add_child(g); s.post_group = g
	s.door = g.to_global(Vector3(0, 0, 2.6)) # (where you trade: the step before the door)
	var K: Dictionary = KEEPERS[s.land]
	var f := ModelFigure.new(K.new if ModelFigure.has_folk(K.new) else K.model, {"hue": K.hue * 0.5 if ModelFigure.has_folk(K.new) else K.hue}); var kat := g.to_global(Vector3(1.3, 0, 2.9))
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
