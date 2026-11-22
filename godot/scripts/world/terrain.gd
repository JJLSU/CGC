class_name Terrain
## world.js's land, as is: the seed and its noises, the wild lands (landAt, landTint), the mountain ranges on their
## folded-paper lattice, the region field, the continuous elevation with the level sheets (farm, town...), the
## height lookup the mesher and everything else share, and one chunk's mesh.
## All static: there is one world. Call set_seed() (and set_range_center/set_flat_area) before building any chunk.

const CHUNK := 32
const WATER_LEVEL := 0.0
const MAP := 256
const RANGE_STOP := 0.24
const RANGE_H := 30.0
const LAT := 6
const WORLD_SCALE := 0.6
const WATER_T := 0.8
const HIGH_T := 15.0
const PEAK_T := 25.0
const STEP := 0.6
const GRID := 0.5
const CELLS := 64 # CHUNK / GRID
const LAND_IDS := ["hollows", "breaks", "fen", "prairie", "pines"]
const LANDS := {
	"home": {"name": "the home county", "tint": [1.0, 1.0, 1.0]},
	"hollows": {"name": "the Silver Birch Hollows", "tint": [0.96, 1.04, 1.06], "lore": "White birches crowd the hollows like a congregation of ghosts. Something here walks only when you are not looking."},
	"breaks": {"name": "the Redrock Breaks", "tint": [1.12, 0.8, 0.72], "lore": "Rust-red rock, split and stacked like old bread. The prospectors say there is silver in it, and something that walks the hillsides lopsided."},
	"fen": {"name": "the Misty Fen", "tint": [0.84, 0.95, 0.9], "lore": "Black water, dead snags and a cold mist. Pearls lie in the mussel beds, and the Hodag keeps them."},
	"prairie": {"name": "the Golden Prairie", "tint": [1.12, 1.02, 0.78], "lore": "Grass to your belt as far as you can see. Thunder eggs lie out in the open, and the coyotes run in packs."},
	"pines": {"name": "the Bluepine Highlands", "tint": [0.76, 0.9, 1.14], "lore": "High blue timber, cold and quiet. Old pines weep amber here, and the wampus cat hunts the ridges."},
}

static var SEED := 20261120
static var RING := Vector2(130, 210)
static var nCont: PNoise.Simplex; static var nHill: PNoise.Simplex; static var nRidge: PNoise.Simplex; static var nMoist: PNoise.Simplex
static var nPath: PNoise.Simplex; static var nField: PNoise.Simplex; static var nLandA: PNoise.Simplex; static var nLandB: PNoise.Simplex
static var nMarsh: PNoise.Simplex; static var nTear: PNoise.Simplex; static var nTear2: PNoise.Simplex; static var nRange: PNoise.Simplex; static var nRange2: PNoise.Simplex
static var RC := Vector2.ZERO
static var lat_cache := {}
static var full_cache := {}
static var e_memo := {}  ## grid vertex -> elevation, away from built chunks (21f)
static var h_cache := {}   ## "cx,cz" -> PackedFloat32Array (65*65 elevations)
static var r_cache := {}   ## "cx,cz" -> PackedFloat32Array (17*17 region heights)
static var flat = null     ## [x, z, r0, r1]: the farm's level sheet
static var extra_flats: Array = []
static var _lx := 0.0      ## where region_height last looked, for last_range()
static var _lz := 0.0
# landAt's reused result (copy what you need)
static var L_id := "home"
static var L_wild := 0.0
static var L_edge := 0.5
static var L_w := {"hollows": 0.0, "breaks": 0.0, "fen": 0.0, "prairie": 0.0, "pines": 0.0}

static func set_seed(seed: int, ring := Vector2(130, 210)) -> void:
	SEED = seed & 0xffffffff; RING = ring; e_memo.clear()
	nCont = PNoise.Simplex.new(SEED); nHill = PNoise.Simplex.new(SEED + 1); nRidge = PNoise.Simplex.new(SEED + 2); nMoist = PNoise.Simplex.new(SEED + 3)
	nPath = PNoise.Simplex.new(SEED + 4); nField = PNoise.Simplex.new(SEED + 5)
	nLandA = PNoise.Simplex.new(SEED + 71); nLandB = PNoise.Simplex.new(SEED + 72); nMarsh = PNoise.Simplex.new(SEED + 73)
	nTear = PNoise.Simplex.new(SEED + 9); nTear2 = PNoise.Simplex.new(SEED + 10); nRange = PNoise.Simplex.new(SEED + 77); nRange2 = PNoise.Simplex.new(SEED + 78)
	lat_cache.clear(); full_cache.clear(); h_cache.clear(); r_cache.clear()

static func set_range_center(x: float, z: float) -> void:
	RC = Vector2(x, z); lat_cache.clear(); full_cache.clear(); e_memo.clear()
static func set_flat_area(x: float, z: float, r0: float, r1: float) -> void: flat = [x, z, r0, r1]; e_memo.clear()
static func add_flat_area(x: float, z: float, r0: float, r1: float) -> void: extra_flats.append([x, z, r0, r1]); e_memo.clear()

static func ss(a: float, b: float, x: float) -> float: return PNoise.smoothstep(a, b, x)

# ------------------------------------------------------------------ the lands beyond the county
## Which land (x, z) lies in: sets L_id, L_wild (0 at home .. 1 in the wilds), L_w (per-land weight), L_edge.
static func land_at(x: float, z: float) -> void:
	var r := sqrt(x * x + z * z)
	var wild := ss(RING.x, RING.y, r)
	for k in LAND_IDS: L_w[k] = 0.0
	if wild <= 0.0:
		L_id = "home"; L_wild = 0.0; L_edge = 0.5; return
	var a := PNoise.fbm(nLandA, x * 0.0026, z * 0.0026, 2); var b := PNoise.fbm(nLandB, x * 0.0026, z * 0.0026, 2)
	var s := ((atan2(b, a) + PI) / (PI * 2.0)) * 5.0
	var i := floori(s) % 5; var f := s - floorf(s)
	var nb: int = (i + 1) % 5 if f > 0.5 else (i + 4) % 5
	var edge: float = 1.0 - f if f > 0.5 else f
	var k := 0.5 + 0.5 * ss(0.0, 0.18, edge)
	L_w[LAND_IDS[i]] = k * wild; L_w[LAND_IDS[nb]] = (1.0 - k) * wild
	L_id = LAND_IDS[i] if wild > 0.5 else "home"; L_wild = wild; L_edge = edge

## The land's colour tint at (x, z), blended at the borders.
static func land_tint(x: float, z: float) -> Vector3:
	land_at(x, z)
	var o := Vector3.ONE * (1.0 - L_wild)
	for k in LAND_IDS:
		var w: float = L_w[k]
		if w == 0.0: continue
		var t: Array = LANDS[k]["tint"]
		o += Vector3(t[0], t[1], t[2]) * w
	return o

# ------------------------------------------------------------------ the mountains
static func range_mask(x: float, z: float) -> float:
	var r0 := sqrt(x * x + z * z); var r := Vector2(x - RC.x, z - RC.y).length(); var outer_r := 950.0 + RC.length() * 0.5
	var warp := PNoise.fbm(nRange, x * 0.018, z * 0.018, 2) * 16.0
	var rn := PNoise.ridged(nRange, x * 0.0038 + 3.1, z * 0.0038 - 1.7, 3)
	var brk := ss(-0.2, 0.05, PNoise.fbm(nRange2, x * 0.0032, z * 0.0032, 2))
	var m := ss(0.5, 0.72, rn + warp * 0.004) * brk
	m *= ss(150.0, 210.0, r + warp)
	var wall := ss(outer_r - 30.0, outer_r, r0 + warp)
	return wall if wall > m else m

static func mtn_node(i: int, j: int) -> float:
	var k := i * 100003 + j
	if lat_cache.has(k): return lat_cache[k]
	var x := float(i * LAT); var z := float(j * LAT); var m := range_mask(x, z)
	var v := RANGE_H * pow(m, 1.5) * (0.8 + 0.35 * PNoise.fbm(nRange2, x * 0.013, z * 0.013, 2)) if m > 0.004 else 0.0
	if lat_cache.size() > 400000: lat_cache.clear()
	lat_cache[k] = v
	return v

static func full_node(i: int, j: int) -> float:
	var k := i * 100003 + j
	if full_cache.has(k): return full_cache[k]
	var x := float(i * LAT); var z := float(j * LAT); var mt := mtn_node(i, j)
	var v := maxf(0.0, elevation(x, z, NAN, NAN, true)) + mt if mt > 0.0 else -1.0
	if full_cache.size() > 400000: full_cache.clear()
	full_cache[k] = v
	return v

static func _lat_at(a: int, b: int) -> float:
	var v := full_node(a, b)
	return v if v >= 0.0 else maxf(0.0, elevation(a * LAT, b * LAT, NAN, NAN, true))

static func lattice_full(x: float, z: float) -> float:
	var gx := x / LAT; var gz := z / LAT; var i := floori(gx); var j := floori(gz); var fx := gx - i; var fz := gz - j
	if fx + fz <= 1.0:
		var A := _lat_at(i, j); var B := _lat_at(i + 1, j); var C := _lat_at(i, j + 1)
		return A + (B - A) * fx + (C - A) * fz
	var D := _lat_at(i + 1, j + 1); var C2 := _lat_at(i, j + 1); var B2 := _lat_at(i + 1, j)
	return D + (C2 - D) * (1.0 - fx) + (B2 - D) * (1.0 - fz)

static func mtn_lattice(x: float, z: float) -> float:
	var gx := x / LAT; var gz := z / LAT; var i := floori(gx); var j := floori(gz); var fx := gx - i; var fz := gz - j
	var a := mtn_node(i, j); var b := mtn_node(i + 1, j); var c := mtn_node(i, j + 1)
	if a == 0.0 and b == 0.0 and c == 0.0 and mtn_node(i + 1, j + 1) == 0.0: return 0.0
	if fx + fz <= 1.0: return a + (b - a) * fx + (c - a) * fz
	var d := mtn_node(i + 1, j + 1)
	return d + (c - d) * (1.0 - fx) + (b - d) * (1.0 - fz)

## How deep in the mountains (x, z) is: 0 in the valleys, 1 on the crests.
static func range_at(x: float, z: float) -> float: return range_mask(x, z)
static func impassable(x: float, z: float) -> bool: return range_at(x, z) > RANGE_STOP

# ------------------------------------------------------------------ region field and elevation
static func region_height(x: float, z: float) -> float:
	land_at(x, z)
	var wx := x; var wz := z
	x *= WORLD_SCALE; z *= WORLD_SCALE
	var cont := PNoise.fbm(nCont, x * 0.0021, z * 0.0021, 3)
	var land := ss(-0.14, 0.22, cont)
	var h := -9.0 + land * 15.0
	h += PNoise.fbm(nHill, x * 0.014, z * 0.014, 4) * 4.5 * (0.35 + land)
	var r := PNoise.ridged(nRidge, x * 0.0065, z * 0.0065, 4)
	h += pow(maxf(0.0, r - 0.52) / 0.48, 1.6) * 42.0 * ss(0.02, 0.32, cont)
	h += 8.0 * exp(-(x * x + z * z) / (2.0 * 60.0 * 60.0))
	if L_wild > 0.0:
		var W := L_w
		if W.fen: h += (1.6 + PNoise.fbm(nMarsh, wx * 0.035, wz * 0.035, 3) * 3.2 - h) * W.fen
		if W.prairie: h += (4.2 + PNoise.fbm(nHill, x * 0.006, z * 0.006, 2) * 2.2 - h) * W.prairie
		if W.breaks:
			var m := maxf(h, 4.0) + 9.0 * ss(0.1, 0.3, PNoise.ridged(nRidge, x * 0.012, z * 0.012, 2))
			h += (floorf(m / 4.0 + 0.5) * 4.0 + fmod(m, 4.0) * 0.25 - h) * W.breaks # (Math.round: half up)
		if W.pines: h += (maxf(h, 7.0) + 9.0 - h) * W.pines
	_lx = wx; _lz = wz # (the range mask there is worked out only if someone asks: last_range(); world.js computes it
	return h        # here every time, though nothing in regionHeight or elevation reads it)

## The mountain range's mask where region_height last looked (world.js _lastRange), on demand.
static func last_range() -> float: return range_mask(_lx, _lz)

## Continuous elevation (before layering). rh_known / m_known: NAN when not known.
static func elevation(x: float, z: float, rh_known: float = NAN, m_known: float = NAN, base := false) -> float:
	var rh := region_height(x, z) if is_nan(rh_known) else rh_known # (world.js also works out the range mask m here; nothing reads it)
	var land := ss(WATER_T - 0.6, WATER_T + 2.5, rh)
	var e := land * (0.35 + maxf(0.0, rh - WATER_T) * 0.18)
	e = 10.0 + (e - 10.0) * 0.4 if e > 10.0 else e
	e += land * PNoise.fbm(nTear, x * 0.06, z * 0.06, 2) * 0.6
	if not base:
		var mt := mtn_lattice(x, z)
		if mt > 0.0:
			var full := lattice_full(x, z)
			e = e + (full - e) * minf(1.0, mt / 0.3) - 0.9 * ss(1.5, 5.0, mt)
	if flat != null:
		var d := Vector2(x - flat[0], z - flat[1]).length()
		if d < flat[3]: e += (STEP * 1.5 - e) * (1.0 - ss(flat[2], flat[3], d))
	for f in extra_flats:
		var d := Vector2(x - f[0], z - f[1]).length()
		if d < f[3]: e += (STEP * 1.5 - e) * (1.0 - ss(f[2], f[3], d))
	return maxf(0.0, e)

static func _gh(ix: int, iz: int) -> float:
	var cx := floori(float(ix) / CELLS); var cz := floori(float(iz) / CELLS)
	var key := "%d,%d" % [cx, cz]
	if h_cache.has(key):
		var H: PackedFloat32Array = h_cache[key]
		return H[(iz - cz * CELLS) * (CELLS + 1) + (ix - cx * CELLS)]
	# (away from built chunks: each grid vertex's elevation worked out once and kept; a prop layout asks is_water and
	# get_height at the same spot, and neighbouring spots share corners. Exact: the same elevation() call.)
	var k := ix * 1000003 + iz
	if e_memo.has(k): return e_memo[k]
	if e_memo.size() > 300000: e_memo.clear()
	var e := elevation(ix * GRID, iz * GRID)
	e_memo[k] = e
	return e

## Height of the sheet under (x, z): the same triangle split and interpolation the mesher uses.
static func get_height(x: float, z: float) -> float:
	var gx := x / GRID; var gz := z / GRID
	var ix := floori(gx); var iz := floori(gz)
	var fx := gx - ix; var fz := gz - iz
	var ha := _gh(ix, iz); var hb := _gh(ix + 1, iz); var hc := _gh(ix, iz + 1)
	if fx + fz <= 1.0: return ha + (hb - ha) * fx + (hc - ha) * fz
	var hd := _gh(ix + 1, iz + 1)
	return hd + (hc - hd) * (1.0 - fx) + (hb - hd) * (1.0 - fz)

static func is_water(x: float, z: float) -> bool: return get_height(x, z) < 0.12
static func wadeable(x: float, z: float) -> bool: return region_height(x, z) > WATER_T - 4.0
static func wade_depth(x: float, z: float) -> float: return clampf((WATER_T - region_height(x, z)) / 4.0, 0.0, 1.0)
static func moisture(x: float, z: float) -> float:
	land_at(x, z)
	return PNoise.fbm(nMoist, x * 0.004 * WORLD_SCALE, z * 0.004 * WORLD_SCALE, 2) + 0.3 * L_w.hollows + 0.2 * L_w.fen + 0.15 * L_w.pines - 0.4 * L_w.prairie - 0.1 * L_w.breaks
static func path_field(x: float, z: float) -> float: return absf(PNoise.fbm(nPath, x * 0.0075 * WORLD_SCALE, z * 0.0075 * WORLD_SCALE, 2))
static func field_mask(x: float, z: float) -> float:
	var wild := ss(RING.x - 20.0, RING.x + 40.0, sqrt(x * x + z * z))
	if wild >= 1.0: return 0.0
	return ss(0.18, 0.3, PNoise.fbm(nField, x * 0.012 * WORLD_SCALE, z * 0.012 * WORLD_SCALE, 2)) * (1.0 - wild)
static func region_at(x: float, z: float) -> String:
	var h := region_height(x, z)
	if h < WATER_T: return "water"
	if h > PEAK_T: return "peak"
	if h > HIGH_T: return "highland"
	if field_mask(x, z) > 0.5: return "field"
	return "forest" if moisture(x, z) > 0.02 else "meadow"

## The coarse region height at a chunk's local metre (i, j), from the chunk's 2 m grid if it's built.
static func coarse_region(cx: int, cz: int, i: int, j: int) -> float:
	var key := "%d,%d" % [cx, cz]
	if not r_cache.has(key): return region_height(cx * CHUNK + i, cz * CHUNK + j)
	var R: PackedFloat32Array = r_cache[key]; var CN := CHUNK / 2 + 1
	var fx := i / 2.0; var fz := j / 2.0; var i0 := floori(fx); var j0 := floori(fz); var tx := fx - i0; var tz := fz - j0
	var r0 := R[j0 * CN + i0] + (R[j0 * CN + i0 + 1] - R[j0 * CN + i0]) * tx
	var r1 := R[(j0 + 1) * CN + i0] + (R[(j0 + 1) * CN + i0 + 1] - R[(j0 + 1) * CN + i0]) * tx
	return r0 + (r1 - r0) * tz

## Where the farm goes: the first meadow/forest/field spot with no water or heights within 24 m.
static func find_spawn() -> Vector3:
	var r := 0
	while r < 260:
		var a := 0.0
		while a < PI * 2.0:
			var x := float(roundi(cos(a) * r)); var z := float(roundi(sin(a) * r))
			var reg := region_at(x, z)
			if reg == "meadow" or reg == "forest" or reg == "field":
				var ok := true
				for k in 12:
					var b := (k / 12.0) * PI * 2.0
					var rr := region_at(x + cos(b) * 24.0, z + sin(b) * 24.0)
					if rr == "water" or rr == "peak" or rr == "highland": ok = false; break
				if ok: return Vector3(x, 0, z)
			a += 0.35
		r += 6
	return Vector3.ZERO

# ------------------------------------------------------------------ one chunk's sheet
## A 0.5 m grid over the chunk with smooth normals (the height layers are printed by the ground shader).
static func build_chunk_mesh(cx: int, cz: int) -> ArrayMesh:
	var job := chunk_job(cx, cz)
	while not chunk_step(job, 1 << 30): pass
	return job.mesh

## The same, a slice at a time: chunk_step(job, rows) does up to `rows` rows of samples and returns true once the
## mesh is made (job.mesh). (World builds a new chunk across frames this way so walking into new country never
## stalls a frame: the heights are GDScript noise, ~50 ms a chunk.)
static func chunk_job(cx: int, cz: int) -> Dictionary:
	var C := 2; var CN := CHUNK / C + 1; var S := CELLS + 1
	var R := PackedFloat32Array(); R.resize(CN * CN); var M := PackedFloat32Array(); M.resize(CN * CN)
	var H := PackedFloat32Array(); H.resize(S * S)
	return {"cx": cx, "cz": cz, "R": R, "M": M, "H": H, "rj": 0, "hj": 0, "mesh": null}

static func chunk_step(job: Dictionary, rows: int) -> bool:
	var N := CELLS; var S := N + 1; var ox: int = job.cx * CHUNK; var oz: int = job.cz * CHUNK
	var C := 2; var CN := CHUNK / C + 1
	var R: PackedFloat32Array = job.R; var M: PackedFloat32Array = job.M; var H: PackedFloat32Array = job.H
	while rows > 0 and job.rj < CN:
		var j: int = job.rj
		for i in CN:
			R[j * CN + i] = region_height(ox + i * C, oz + j * C); M[j * CN + i] = 0.0 # (the range mask it carried is never read)
		job.rj += 1; rows -= 1
	job.R = R; job.M = M
	if job.rj < CN: return false
	while rows > 0 and job.hj < S:
		var j: int = job.hj
		for i in S:
			var fx := (i * GRID) / C; var fz := (j * GRID) / C
			var i0 := mini(CN - 2, floori(fx)); var j0 := mini(CN - 2, floori(fz))
			var tx := fx - i0; var tz := fz - j0
			var r0 := R[j0 * CN + i0] + (R[j0 * CN + i0 + 1] - R[j0 * CN + i0]) * tx
			var r1 := R[(j0 + 1) * CN + i0] + (R[(j0 + 1) * CN + i0 + 1] - R[(j0 + 1) * CN + i0]) * tx
			var m0 := M[j0 * CN + i0] + (M[j0 * CN + i0 + 1] - M[j0 * CN + i0]) * tx
			var m1 := M[(j0 + 1) * CN + i0] + (M[(j0 + 1) * CN + i0 + 1] - M[(j0 + 1) * CN + i0]) * tx
			H[j * S + i] = elevation(ox + i * GRID, oz + j * GRID, r0 + (r1 - r0) * tz, m0 + (m1 - m0) * tz)
		job.hj += 1; rows -= 1
	job.H = H
	if job.hj < S: return false
	var key := "%d,%d" % [job.cx, job.cz]
	h_cache[key] = H; r_cache[key] = R
	var pos := PackedVector3Array(); pos.resize(S * S)
	var nor := PackedVector3Array(); nor.resize(S * S)
	for j in S:
		for i in S:
			var o := j * S + i
			pos[o] = Vector3(ox + i * GRID, H[o], oz + j * GRID)
			var nx := (H[j * S + maxi(0, i - 1)] - H[j * S + mini(N, i + 1)]) / (2.0 * GRID)
			var nz := (H[maxi(0, j - 1) * S + i] - H[mini(N, j + 1) * S + i]) / (2.0 * GRID)
			nor[o] = Vector3(nx, 1.0, nz).normalized()
	var idx := PackedInt32Array(); idx.resize(N * N * 6)
	var k := 0
	for j in N:
		for i in N:
			var a := j * S + i; var b := a + 1; var c := a + S; var d := c + 1
			# (the same split as get_height; Godot's front faces wind clockwise, the reverse of three.js)
			idx[k] = a; idx[k + 1] = b; idx[k + 2] = c
			idx[k + 3] = b; idx[k + 4] = d; idx[k + 5] = c
			k += 6
	var arrays := []; arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = pos; arrays[Mesh.ARRAY_NORMAL] = nor; arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	job.mesh = mesh
	return true

static func forget_chunk(cx: int, cz: int) -> void:
	var key := "%d,%d" % [cx, cz]
	h_cache.erase(key); r_cache.erase(key)
