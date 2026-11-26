class_name Props
## world.js prop placement, as is: placeProps (the jittered 2.9 m grid with the region and land tables, pond life,
## fallen logs, field bales and stooks, old orchards, lost satchels, the kitchen garden, the landmark clearing and
## the guarded sites), uniqueEncounters (each landmark placed once per world), fieldKindAt (the field patchwork read
## from the baked noise texture on the CPU, as the shader picks it) and springRise. Every random draw is in the
## web's order, so a chunk comes out with the same props in the same places.

const TABLES := {
	"forest": [["mushroom", 0.045], ["snag", 0.008], ["pine", 0.2], ["birch", 0.07], ["maple", 0.14], ["goldtree", 0.1], ["sagetree", 0.07], ["rock", 0.055], ["bush", 0.095], ["flowers", 0.07], ["grass", 0.1]],
	"meadow": [["maple", 0.05], ["birch", 0.02], ["goldtree", 0.05], ["sagetree", 0.02], ["pine", 0.03], ["bush", 0.1], ["mushroom", 0.02], ["flowers", 0.15], ["grass", 0.2], ["rock", 0.055]],
	"field": [["grass", 0.06], ["flowers", 0.03]],
	"highland": [["rock", 0.19], ["snag", 0.025], ["pine", 0.12], ["bush", 0.03], ["grass", 0.12], ["flowers", 0.04]],
	"peak": [["rock", 0.1], ["pine", 0.05]],
}
const LAND_TABLES := {
	"hollows": {"forest": [["birch", 0.42], ["mushroom", 0.08], ["maple", 0.01], ["goldtree", 0.015], ["bush", 0.06], ["flowers", 0.1], ["grass", 0.1], ["rock", 0.03], ["snag", 0.01]],
		"meadow": [["birch", 0.2], ["flowers", 0.24], ["grass", 0.2], ["mushroom", 0.06], ["bush", 0.08], ["rock", 0.03]]},
	"breaks": {"any": [["quartz", 0.012], ["rock", 0.3], ["snag", 0.05], ["pine", 0.04], ["grass", 0.08], ["bush", 0.02], ["flowers", 0.02]]},
	"fen": {"any": [["snag", 0.09], ["birch", 0.03], ["sagetree", 0.05], ["mushroom", 0.07], ["grass", 0.26], ["bush", 0.03], ["flowers", 0.02]]},
	"prairie": {"any": [["grass", 0.36], ["flowers", 0.26], ["bush", 0.04], ["goldtree", 0.012], ["rock", 0.02]]},
	"pines": {"any": [["quartz", 0.008], ["pine", 0.38], ["rock", 0.1], ["bush", 0.04], ["grass", 0.08], ["snag", 0.02], ["birch", 0.02]]},
}
const PROP_TINT := {"breaks": {"rock": [1.18, 0.84, 0.68], "snag": [1.08, 0.9, 0.8], "grass": [1.08, 0.92, 0.75]}, "pines": {"pine": [0.66, 0.86, 1.2], "rock": [0.86, 0.94, 1.1]},
	"fen": {"sagetree": [0.85, 0.92, 0.86], "grass": [0.88, 0.95, 0.85], "birch": [0.92, 0.96, 0.94]}, "prairie": {"grass": [1.12, 1.02, 0.74], "goldtree": [1.08, 1.02, 0.86]}, "hollows": {"birch": [1.04, 1.06, 1.06]}}
const LAND_SITES := {"hollows": {"kind": "sang", "guard": "hidebehind", "guards": 1}, "breaks": {"kind": "silver", "guard": "gouger", "guards": 2}, "fen": {"kind": "pearl", "guard": "hodag", "guards": 1}, "prairie": {"kind": "geode", "guard": "coyote", "guards": 3}, "pines": {"kind": "amber", "guard": "wampus", "guards": 1}}
const UNIQUES := [["breaks", "arch"], ["fen", "steamboat"], ["pines", "lookout"], ["prairie", "schooner"], ["hollows", "birch"], ["pines", "babe"], ["hollows", "hermit"]]
const CHUNK := 32

static var garden = null   ## {x0, x1, rows: [{z, type}]} (the homestead's kitchen garden)
static var _uniques = null
static var _uniques_seed := -1
static var landmark_colliders: Callable = func(_mark: String, _x: float, _z: float, _rot: float) -> Array: return []

static func spring_rise(t: float) -> float:
	if t <= 0.0: return 0.0
	var zeta := 0.56; var wn := 9.0; var wd := wn * sqrt(1.0 - zeta * zeta)
	return 1.0 - exp(-zeta * wn * t) * (cos(wd * t) + ((zeta * wn) / wd) * sin(wd * t))

static func _pick(roll: float, table: Array):
	var acc := 0.0
	for e in table:
		acc += e[1]
		if roll < acc: return e[0]
	return null

# ------------------------------------------------------------------ the field patchwork, read on the CPU
static var _noise_img: Image
static func _noise_g(u: float, v: float) -> float:
	if _noise_img == null: _noise_img = (load("res://assets/baked/paper/noise.png") as Texture2D).get_image()
	var S := _noise_img.get_width()
	var x := u * S - 0.5; var y := (1.0 - v) * S - 0.5
	var x0 := floori(x); var y0 := floori(y); var tx := x - x0; var ty := y - y0
	var at := func(i: int, j: int) -> float: return floorf(_noise_img.get_pixel(posmod(i, S), posmod(j, S)).g * 255.0 + 0.5) / 255.0
	var a: float = at.call(x0, y0) + (at.call(x0 + 1, y0) - at.call(x0, y0)) * tx
	var b: float = at.call(x0, y0 + 1) + (at.call(x0 + 1, y0 + 1) - at.call(x0, y0 + 1)) * tx
	return a + (b - a) * ty
## "hay" | "wheat" | "plough" | "" (too near a patch border) for a crop field at (x, z).
static func field_kind_at(x: float, z: float) -> String:
	var f := _noise_g(x * 0.0045 + 0.13, z * 0.0045 + 0.71)
	if f < 0.43: return "hay"
	if f > 0.462 and f < 0.613: return "wheat"
	if f > 0.645: return "plough"
	return ""

# ------------------------------------------------------------------ one-of-a-kind landmarks
static func unique_encounters() -> Array:
	if _uniques != null and _uniques_seed == Terrain.SEED: return _uniques
	_uniques_seed = Terrain.SEED; _uniques = []
	var rng := PNoise.Mulberry32.new(PNoise.hash2(17, 29, Terrain.SEED + 101))
	var dry := func(x: float, z: float) -> bool:
		for k in 8:
			if Terrain.is_water(x + cos(k * 0.785) * 5.0, z + sin(k * 0.785) * 5.0): return false
		return true
	for U in UNIQUES:
		var land: String = U[0]; var mark: String = U[1]
		var start := 4 + floori(rng.next() * 6.0); var turn := rng.next()
		var found = null
		var r := start
		while r <= 30 and found == null:
			var ring := []
			for dz in range(-r, r + 1):
				for dx in range(-r, r + 1):
					if maxi(absi(dx), absi(dz)) == r: ring.append([dx, dz, fposmod(atan2(dz, dx) / (PI * 2.0) + 1.0 + turn, 1.0)])
			ring.sort_custom(func(a, b): return a[2] < b[2])
			for e in ring:
				var cx: int = e[0]; var cz: int = e[1]
				var h := PNoise.Mulberry32.new(PNoise.hash2(cx, cz, Terrain.SEED + 61))
				var x := cx * CHUNK + 8 + h.next() * 16.0; var z := cz * CHUNK + 8 + h.next() * 16.0; var rot := h.next() * PI * 2.0
				Terrain.land_at(x, z)
				if Terrain.L_id != land or Terrain.L_wild < 0.9 or Terrain.L_w[land] < 0.9: continue
				if Terrain.range_mask(x, z) > 0.04: continue
				var close := false
				for u in _uniques:
					if Vector2(u.x - x, u.z - z).length() < 150.0: close = true; break
				if close: continue
				var ok: bool
				if mark == "babe": ok = not Terrain.is_water(x, z)
				elif mark == "steamboat":
					ok = Terrain.is_water(x, z)
					for k in [0, 2, 4, 6]: ok = ok or Terrain.is_water(x + cos(k * 0.785) * 5.0, z + sin(k * 0.785) * 5.0)
				else: ok = dry.call(x, z)
				if not ok: continue
				found = {"cx": cx, "cz": cz, "x": x, "z": z, "rot": rot, "mark": mark, "land": land}
				break
			r += 1
		if found != null: _uniques.append(found)
	return _uniques

# ------------------------------------------------------------------ placeProps
## {list: [{type, x, z, y, lx, lz, rot, scale, lean, tint?, tone?}], colliders: [...], sites: [...]}
static var _last_exclusions: Array = []
static func place(cx: int, cz: int, exclusions: Array) -> Dictionary:
	_last_exclusions = exclusions
	return _finish(cx, cz, _place(cx, cz, exclusions))

## Iron within an easy walk of the farm (the player's ask): one small outcrop a county, 45-75 m out on dry ground
## clear of the farm's level sheet and anything kept clear (the town), chosen by the world's seed: five rusty ore
## rocks and two plain ones. Each lands in whichever chunk holds it (_finish adds it to that chunk's layout).
static var _starter: Array = []
static var _starter_seed := -1
static func starter_ore(exclusions: Array) -> Array:
	if _starter_seed == Terrain.SEED and not _starter.is_empty(): return _starter
	_starter_seed = Terrain.SEED; _starter = []
	if Terrain.flat == null: return _starter
	var fx: float = Terrain.flat[0]; var fz: float = Terrain.flat[1]
	var rng := PNoise.Mulberry32.new(PNoise.hash2(3, 77, Terrain.SEED + 911))
	var at := Vector2.INF
	for k in 48:
		var a := rng.next() * TAU; var d := 45.0 + rng.next() * 30.0
		var x := fx + cos(a) * d; var z := fz + sin(a) * d
		if Terrain.is_water(x, z) or Terrain.range_at(x, z) > 0.04: continue
		if exclusions.any(func(e): return Vector2(e.x - x, e.z - z).length() < e.r + 6.0): continue
		var dry := true
		for j in 8: if Terrain.is_water(x + cos(j * 0.785) * 6.0, z + sin(j * 0.785) * 6.0): dry = false
		if dry: at = Vector2(x, z); break
	if at == Vector2.INF: return _starter
	for i in 7:
		var a := i * TAU / 7.0 + rng.next() * 0.5; var d := 1.6 + rng.next() * 2.6
		var x := at.x + cos(a) * d; var z := at.y + sin(a) * d
		if Terrain.is_water(x, z): continue
		_starter.append({"type": "ore" if i < 5 else "rock", "x": x, "z": z, "rot": rng.next() * 6.28, "scale": 0.95 + rng.next() * 0.25})
	return _starter

static func _finish(cx: int, cz: int, out: Dictionary) -> Dictionary:
	for q in starter_ore(_last_exclusions):
		if floori(q.x / CHUNK) == cx and floori(q.z / CHUNK) == cz:
			out.list.append({"type": q.type, "x": q.x, "z": q.z, "y": maxf(0.02, Terrain.get_height(q.x, q.z)), "lx": q.x - cx * CHUNK, "lz": q.z - cz * CHUNK, "rot": q.rot, "scale": q.scale, "lean": 0.0})
	var ap: Array = out.list.filter(func(q): return q.type == "appletree")
	var satchels := []; var si := 0
	for q in out.list:
		if q.type == "satchel": satchels.append({"x": q.x, "z": q.z, "key": "%d,%d,satchel,%d" % [cx, cz, si]}); si += 1
	site_cache["%d,%d" % [cx, cz]] = {"satchels": satchels, "sites": out.sites, "orchard": Vector2(ap.reduce(func(a, q): return a + q.x, 0.0) / ap.size(), ap.reduce(func(a, q): return a + q.z, 0.0) / ap.size()) if ap.size() else null}
	return out

## Every chunk laid out so far (by the world, the rumour scan or the map): its guarded sites and old orchard's
## middle, so the county map and the rumour note needn't lay a chunk out twice (main.js world.sitesFor/orchardFor).
static var site_cache := {}
static func sites_for(cx: int, cz: int, exclusions: Array) -> Dictionary:
	var k := "%d,%d" % [cx, cz]
	if not site_cache.has(k): place(cx, cz, exclusions)
	return site_cache[k]

## A chunk's lost satchel without laying the chunk out (it has its own seed): {x, z, key} or null. (A guarded
## site's clearing can still take it, so a caller that must be sure confirms with sites_for.)
static func satchel_guess(cx: int, cz: int, exclusions: Array):
	var k := "%d,%d" % [cx, cz]
	if site_cache.has(k): return site_cache[k].satchels[0] if site_cache[k].satchels.size() else null
	var W := Terrain
	var srng := PNoise.Mulberry32.new(PNoise.hash2(cx, cz, Terrain.SEED + 37))
	var sx0 := cx * CHUNK + 4 + srng.next() * 24.0; var sz0 := cz * CHUNK + 4 + srng.next() * 24.0
	var far: bool = W.flat == null or Vector2(sx0 - W.flat[0], sz0 - W.flat[1]).length() > 60.0
	if not (srng.next() < 0.07 and far): return null
	for e in exclusions: if (e.x - sx0) * (e.x - sx0) + (e.z - sz0) * (e.z - sz0) < (e.r + 2.0) * (e.r + 2.0): return null
	if W.is_water(sx0, sz0) or W.region_at(sx0, sz0) == "peak" or W.range_at(sx0, sz0) >= 0.01: return null
	for U in unique_encounters(): if U.cx == cx and U.cz == cz and Vector2(U.x - sx0, U.z - sz0).length() < 70.0: return null
	return {"x": sx0, "z": sz0, "key": "%d,%d,satchel,0" % [cx, cz]}

static func _place(cx: int, cz: int, exclusions: Array) -> Dictionary:
	var rng := PNoise.Mulberry32.new(PNoise.hash2(cx, cz, Terrain.SEED + 7))
	var list := []
	var colliders := []
	var spacing := 2.9
	var x0 := cx * CHUNK - 8.0; var x1 := (cx + 1) * CHUNK + 8.0; var z0 := cz * CHUNK - 8.0; var z1 := (cz + 1) * CHUNK + 8.0
	var near := []
	for e in exclusions:
		if e.x + e.r > x0 and e.x - e.r < x1 and e.z + e.r > z0 and e.z - e.r < z1: near.append(e)
	var blocked := func(x: float, z: float, pad := 0.0) -> bool:
		for e in near:
			if (e.x - x) * (e.x - x) + (e.z - z) * (e.z - z) < (e.r + pad) * (e.r + pad): return true
		return false
	var W := Terrain
	var gz := 0.0
	while gz < CHUNK:
		var gx := 0.0
		while gx < CHUNK:
			var lx := gx + rng.next() * spacing; var lz := gz + rng.next() * spacing
			var x := cx * CHUNK + lx; var z := cz * CHUNK + lz
			var roll := rng.next(); var s := rng.next(); var rot := rng.next() * PI * 2.0; var lean := (rng.next() - 0.5) * 0.08
			gx += spacing
			var region := W.region_at(x, z)
			if region == "water" or W.path_field(x, z) < 0.05 or blocked.call(x, z): continue
			if W.last_range() > 0.03 or W.mtn_lattice(x, z) > 0.25: continue
			var near_water := W.is_water(x + 1.5, z) or W.is_water(x - 1.5, z) or W.is_water(x, z + 1.5) or W.is_water(x, z - 1.5)
			if near_water and not (roll < 0.35 and not W.is_water(x, z)): continue
			W.land_at(x, z); var lid := W.L_id
			var LT = LAND_TABLES.get(lid) if lid != "home" else null
			var type
			if near_water: type = "clay"
			else:
				var table: Array
				if LT != null: table = LT.get(region, LT.get("any", LT.get("forest")))
				else: table = TABLES[region]
				type = _pick(roll, table)
			if type == null: continue
			var scale: float
			if type == "clay": scale = 0.8 + s * 0.5
			elif type == "rock": scale = 0.75 + s * 0.7
			elif type == "bush" or type == "flowers": scale = 0.75 + s * 0.45
			elif type == "grass": scale = 0.6 + s * 0.6
			else: scale = 0.85 + s * 0.45
			var y := W.get_height(x, z)
			if absf(W.get_height(x + 0.8, z) - y) + absf(W.get_height(x, z + 0.8) - y) > 0.7: continue
			var p := {"type": type, "x": x, "z": z, "y": y, "lx": lx, "lz": lz, "rot": rot, "scale": scale, "lean": lean}
			if lid != "home" and PROP_TINT.has(lid) and PROP_TINT[lid].has(type): p.tint = PROP_TINT[lid][type]
			list.append(p)
		gz += spacing
	# hills & peaks: no longer placed (the mountains are real terrain), but their draws stay in the stream
	gz = 0.0
	while gz < CHUNK:
		var gx := 0.0
		while gx < CHUNK:
			rng.next(); rng.next()
			gx += 11.0
		gz += 11.0
	# pond life (own seed): cattails on the banks, lily pads in the shallows, a beaver lodge out in open water
	var prng := PNoise.Mulberry32.new(PNoise.hash2(cx, cz, Terrain.SEED + 29))
	var lodged := false
	gz = 0.0
	while gz < CHUNK:
		var gx := 0.0
		while gx < CHUNK:
			var lx := gx + prng.next() * 2.2; var lz := gz + prng.next() * 2.2; var roll := prng.next(); var s := prng.next(); var rot := prng.next() * PI * 2.0
			gx += 2.2
			var x := cx * CHUNK + lx; var z := cz * CHUNK + lz
			if blocked.call(x, z): continue
			var h := W.get_height(x, z)
			var shore := func(d: float) -> bool: return W.get_height(x + d, z) > 0.32 or W.get_height(x - d, z) > 0.32 or W.get_height(x, z + d) > 0.32 or W.get_height(x, z - d) > 0.32
			var open_all := func() -> bool:
				for k in 8:
					if not W.is_water(x + cos(k * 0.785) * 2.8, z + sin(k * 0.785) * 2.8): return false
				return true
			if not lodged and h < 0.1 and roll > 0.9 and shore.call(6.0) and open_all.call():
				lodged = true
				list.append({"type": "lodge", "x": x, "z": z, "y": -0.18, "lx": lx, "lz": lz, "rot": rot, "scale": 0.95 + s * 0.3, "lean": 0.0})
				colliders.append({"x": x, "z": z, "r": 1.3})
			elif h > 0.1 and h < 0.45 and roll < 0.16:
				var n := 2 + (1 if roll < 0.06 else 0)
				for k in n:
					var ox := (prng.next() - 0.5) * 1.1; var oz := (prng.next() - 0.5) * 1.1
					list.append({"type": "cattail", "x": x + ox, "z": z + oz, "y": W.get_height(x + ox, z + oz), "lx": lx + ox, "lz": lz + oz, "rot": rot + k * 1.1, "scale": 1.05 + prng.next() * 0.5, "lean": 0.0})
			elif h < 0.1 and roll < 0.32 and shore.call(5.5):
				list.append({"type": "lilybloom" if roll < 0.08 else "lilypad", "x": x, "z": z, "y": h + 0.03, "lx": lx, "lz": lz, "rot": rot, "scale": 0.75 + s * 0.55, "lean": 0.0})
		gz += 2.2
	# the wild woods floor: now and then a fallen log (own seed)
	var wrng := PNoise.Mulberry32.new(PNoise.hash2(cx, cz, Terrain.SEED + 53))
	gz = 0.0
	while gz < CHUNK:
		var gx := 0.0
		while gx < CHUNK:
			var lx := gx + 1.0 + wrng.next() * 6.0; var lz := gz + 1.0 + wrng.next() * 6.0; var roll := wrng.next(); var rot := wrng.next() * PI * 2.0; var s := wrng.next()
			gx += 8.0
			var x := cx * CHUNK + lx; var z := cz * CHUNK + lz
			if roll > 0.22 or W.region_at(x, z) != "forest" or blocked.call(x, z, 1.6) or W.path_field(x, z) < 0.1 or W.is_water(x, z): continue
			list.append({"type": "log", "x": x, "z": z, "y": W.get_height(x, z), "lx": lx, "lz": lz, "rot": rot, "scale": 0.95 + s * 0.4, "lean": 0.0})
			for k in [-0.8, 0.0, 0.8]: colliders.append({"x": x + cos(rot) * k * (0.95 + s * 0.4), "z": z - sin(rot) * k * (0.95 + s * 0.4), "r": 0.45})
		gz += 8.0
	# field dressing: round bales on the mown hay, wheat stooked in short rows (own seed)
	var frng := PNoise.Mulberry32.new(PNoise.hash2(cx, cz, Terrain.SEED + 41))
	gz = 0.0
	while gz < CHUNK:
		var gx := 0.0
		while gx < CHUNK:
			var lx := gx + frng.next() * 4.5; var lz := gz + frng.next() * 4.5; var roll := frng.next(); var rot := frng.next() * PI * 2.0; var s := frng.next()
			gx += 4.5
			var x := cx * CHUNK + lx; var z := cz * CHUNK + lz
			if roll > 0.3 or W.region_at(x, z) != "field" or W.field_mask(x, z) < 0.62 or blocked.call(x, z, 1.0) or W.path_field(x, z) < 0.08: continue
			var kind := field_kind_at(x, z)
			if kind == "hay" and roll < 0.12:
				list.append({"type": "bale", "x": x, "z": z, "y": W.get_height(x, z), "lx": lx, "lz": lz, "rot": rot, "scale": 1.25 + s * 0.3, "lean": 0.0})
				colliders.append({"x": x, "z": z, "r": 0.7})
			elif kind == "wheat":
				for k in 2 + (1 if roll < 0.15 else 0):
					var sx := x + cos(rot) * k * 1.3; var sz := z + sin(rot) * k * 1.3
					if floori(sx / CHUNK) != cx or floori(sz / CHUNK) != cz or field_kind_at(sx, sz) != "wheat": continue
					list.append({"type": "stook", "x": sx, "z": sz, "y": W.get_height(sx, sz), "lx": sx - cx * CHUNK, "lz": sz - cz * CHUNK, "rot": rot + k * 0.9, "scale": 1.45 + s * 0.35, "lean": (s - 0.5) * 0.1})
		gz += 4.5
	# old orchards (own seed)
	var orng := PNoise.Mulberry32.new(PNoise.hash2(cx, cz, Terrain.SEED + 31))
	var ox := cx * CHUNK + 6 + orng.next() * 20.0; var oz := cz * CHUNK + 6 + orng.next() * 20.0
	if orng.next() < 0.3 and W.region_at(ox, oz) == "meadow" and not blocked.call(ox, oz, 6.0):
		var yaw := orng.next() * PI
		for i in range(-1, 2):
			for j in range(-1, 2):
				if orng.next() < 0.25: continue
				var gx := i * 5.5 + (orng.next() - 0.5) * 1.2; var gz2 := j * 5.5 + (orng.next() - 0.5) * 1.2
				var x := ox + gx * cos(yaw) - gz2 * sin(yaw); var z := oz + gx * sin(yaw) + gz2 * cos(yaw)
				if floori(x / CHUNK) != cx or floori(z / CHUNK) != cz or W.is_water(x, z) or blocked.call(x, z) or W.path_field(x, z) < 0.05: continue
				_clear(list, x, z, 6.5)
				list.append({"type": "appletree", "x": x, "z": z, "y": W.get_height(x, z), "lx": x - cx * CHUNK, "lz": z - cz * CHUNK, "rot": orng.next() * 6.28, "scale": 0.85 + orng.next() * 0.3, "lean": (orng.next() - 0.5) * 0.06})
				var a := orng.next() * PI * 2.0; var hx := x + cos(a) * 1.5; var hz := z + sin(a) * 1.5
				if floori(hx / CHUNK) == cx and floori(hz / CHUNK) == cz and not W.is_water(hx, hz):
					list.append({"type": "apples", "x": hx, "z": hz, "y": W.get_height(hx, hz), "lx": hx - cx * CHUNK, "lz": hz - cz * CHUNK, "rot": orng.next() * 6.28, "scale": 1.3 + orng.next() * 0.3, "lean": 0.0})
	# a lost satchel, now and then, far out (own seed)
	var srng := PNoise.Mulberry32.new(PNoise.hash2(cx, cz, Terrain.SEED + 37))
	var sx0 := cx * CHUNK + 4 + srng.next() * 24.0; var sz0 := cz * CHUNK + 4 + srng.next() * 24.0
	var far: bool = W.flat == null or Vector2(sx0 - W.flat[0], sz0 - W.flat[1]).length() > 60.0
	if srng.next() < 0.07 and far and not W.is_water(sx0, sz0) and not blocked.call(sx0, sz0, 2.0) and W.region_at(sx0, sz0) != "peak" and W.range_at(sx0, sz0) < 0.01:
		_clear(list, sx0, sz0, 4.0)
		list.append({"type": "satchel", "x": sx0, "z": sz0, "y": W.get_height(sx0, sz0), "lx": sx0 - cx * CHUNK, "lz": sz0 - cz * CHUNK, "rot": srng.next() * 6.28, "scale": 1.2, "lean": 0.0})
	# the kitchen garden (corn and pumpkins in rows)
	if garden != null:
		for row in garden.rows:
			var step := 1.0 if row.type == "corn" else 1.5
			var x: float = garden.x0
			while x <= garden.x1 + 0.01:
				if floori(x / CHUNK) == cx and floori(row.z / CHUNK) == cz:
					var jx := x + (rng.next() - 0.5) * 0.25; var jz: float = row.z + (rng.next() - 0.5) * 0.2
					list.append({"type": row.type, "x": jx, "z": jz, "y": W.get_height(jx, jz) + 0.02, "lx": jx - cx * CHUNK, "lz": jz - cz * CHUNK,
						"rot": 0.25 + rng.next() * 0.4, "scale": (1.15 + rng.next() * 0.2) if row.type == "corn" else (0.75 + rng.next() * 0.25), "lean": 0.0})
				x += step
	# a landmark here?
	var lm = null
	for U in unique_encounters():
		if U.cx == cx and U.cz == cz:
			_clear(list, U.x, U.z, 70.0)
			colliders.append_array(landmark_colliders.call(U.mark, U.x, U.z, U.rot))
			lm = {"key": "%d,%d,landmark" % [cx, cz], "kind": "landmark", "mark": U.mark, "land": U.land, "x": U.x, "y": maxf(0.0, W.get_height(U.x, U.z)), "z": U.z, "rot": U.rot, "guards": 0}
			break
	# guarded sites
	var sites := [lm] if lm != null else []
	var sx := cx * CHUNK + 8 + rng.next() * 16.0; var sz := cz * CHUNK + 8 + rng.next() * 16.0
	var sroll := rng.next()
	var far_from_farm: bool = W.flat == null or Vector2(sx - W.flat[0], sz - W.flat[1]).length() > 55.0
	var sreg := W.region_at(sx, sz)
	W.land_at(sx, sz); var sland := W.L_id
	var LS = LAND_SITES.get(sland) if sland != "home" else null
	var fen_ok := true
	if LS != null and LS.kind == "pearl":
		fen_ok = false
		for k in 6: fen_ok = fen_ok or W.is_water(sx + cos(k) * 4.0, sz + sin(k) * 4.0)
	var site_kind := ""
	if far_from_farm:
		if LS != null:
			if sroll < 0.22 and sreg != "water" and fen_ok: site_kind = LS.kind
			elif (sreg == "highland" or sreg == "peak") and sroll < 0.32: site_kind = "vein"
		elif (sreg == "highland" or sreg == "peak") and sroll < 0.4: site_kind = "vein"
		elif sreg == "forest" and sroll < 0.3: site_kind = "grove"
		elif sreg == "meadow" and sroll < 0.2: site_kind = "thicket"
	if site_kind != "" and W.range_at(sx, sz) < 0.08 and not blocked.call(sx, sz, 6.0) and not (lm != null and Vector2(sx - lm.x, sz - lm.z).length() < 18.0):
		var sy := W.get_height(sx, sz)
		_clear(list, sx, sz, 36.0)
		var ring := func(type: String, n: int, r0: float, r1: float, scale: float) -> void:
			for i in n:
				var a := (float(i) / n) * PI * 2.0 + rng.next() * 0.6; var d := r0 + rng.next() * (r1 - r0); var rot := rng.next() * 6.28; var sc := 0.9 + rng.next() * 0.3
				var x := sx + cos(a) * d; var z := sz + sin(a) * d
				if W.is_water(x, z) and type != "pearl": continue
				if type == "pearl" and W.get_height(x, z) > 0.6: continue
				var p := {"type": type, "x": x, "z": z, "y": maxf(0.02, W.get_height(x, z)), "lx": x - cx * CHUNK, "lz": z - cz * CHUNK, "rot": rot, "scale": scale * sc, "lean": 0.0}
				if PROP_TINT.has(sland) and PROP_TINT[sland].has(type): p.tint = PROP_TINT[sland][type]
				list.append(p)
		if LS != null and site_kind == LS.kind:
			var n: int = {"sang": 6, "silver": 5, "pearl": 7, "geode": 5, "amber": 5}[site_kind]
			ring.call(site_kind, n, 1.4, 5.0, 1.45 if site_kind == "sang" else 1.0)
			if site_kind == "amber": ring.call("pine", 4, 5.0, 7.0, 1.1)
			if site_kind == "silver": ring.call("rock", 4, 4.0, 6.5, 1.0)
			sites.append({"key": "%d,%d,site" % [cx, cz], "kind": site_kind, "land": sland, "guard": LS.guard, "x": sx, "y": sy, "z": sz, "guards": LS.guards})
			return {"list": list, "colliders": colliders, "sites": sites}
		if site_kind == "vein": ring.call("ore", 7, 2.2, 5.5, 1.0); ring.call("rock", 3, 4.0, 6.0, 0.9)
		elif site_kind == "grove": ring.call("hive", 3, 1.2, 2.8, 1.0); ring.call("mushroom", 6, 3.0, 6.0, 0.9)
		else: ring.call("bush", 8, 1.2, 5.0, 1.1); ring.call("mushroom", 3, 3.0, 5.5, 0.9); ring.call("apples", 2, 2.0, 4.0, 1.0)
		var home: float = atan2(W.flat[0] - sx, W.flat[1] - sz) if W.flat != null else rng.next() * 6.28
		for da in [0.0, 0.6, -0.6, 1.2, -1.2, PI]:
			var a: float = home + da; var x := sx + sin(a) * 7.5; var z := sz + cos(a) * 7.5
			if W.is_water(x, z) or blocked.call(x, z, 1.0): continue
			for i in range(list.size() - 1, -1, -1):
				var q: Dictionary = list[i]
				if (q.x - x) * (q.x - x) + (q.z - z) * (q.z - z) < 7.0 and q.type != "hive": list.remove_at(i)
			var sign_type := "signvein" if site_kind == "vein" else ("signthicket" if site_kind == "thicket" else "signgrove")
			list.append({"type": sign_type, "x": x, "z": z, "y": W.get_height(x, z), "lx": x - cx * CHUNK, "lz": z - cz * CHUNK, "rot": a + (rng.next() - 0.5) * 0.3, "scale": 1.45, "lean": 0.0})
			break
		sites.append({"key": "%d,%d,site" % [cx, cz], "kind": site_kind, "x": sx, "y": sy, "z": sz, "guards": 3 if site_kind == "vein" else (2 if site_kind == "thicket" else 1)})
	return {"list": list, "colliders": colliders, "sites": sites}

static func _clear(list: Array, x: float, z: float, r2: float) -> void:
	for i in range(list.size() - 1, -1, -1):
		var q: Dictionary = list[i]
		if (q.x - x) * (q.x - x) + (q.z - z) * (q.z - z) < r2: list.remove_at(i)

## The layout of _place, as a coroutine that waits a frame between rows once it has used budget_us of one (the
## world lays new chunks out this way, so walking into new country never stalls a frame on it). A line-for-line
## copy with only the waits added: keep the two in step (tools/test_place_sliced.gd checks they agree).
static func _place_co(cx: int, cz: int, exclusions: Array, budget_us: int) -> Dictionary:
	var _t0 := Time.get_ticks_usec()
	var rng := PNoise.Mulberry32.new(PNoise.hash2(cx, cz, Terrain.SEED + 7))
	var list := []
	var colliders := []
	var spacing := 2.9
	var x0 := cx * CHUNK - 8.0; var x1 := (cx + 1) * CHUNK + 8.0; var z0 := cz * CHUNK - 8.0; var z1 := (cz + 1) * CHUNK + 8.0
	var near := []
	for e in exclusions:
		if e.x + e.r > x0 and e.x - e.r < x1 and e.z + e.r > z0 and e.z - e.r < z1: near.append(e)
	var blocked := func(x: float, z: float, pad := 0.0) -> bool:
		for e in near:
			if (e.x - x) * (e.x - x) + (e.z - z) * (e.z - z) < (e.r + pad) * (e.r + pad): return true
		return false
	var W := Terrain
	var gz := 0.0
	while gz < CHUNK:
		var gx := 0.0
		while gx < CHUNK:
			var lx := gx + rng.next() * spacing; var lz := gz + rng.next() * spacing
			var x := cx * CHUNK + lx; var z := cz * CHUNK + lz
			var roll := rng.next(); var s := rng.next(); var rot := rng.next() * PI * 2.0; var lean := (rng.next() - 0.5) * 0.08
			gx += spacing
			var region := W.region_at(x, z)
			if region == "water" or W.path_field(x, z) < 0.05 or blocked.call(x, z): continue
			if W.last_range() > 0.03 or W.mtn_lattice(x, z) > 0.25: continue
			var near_water := W.is_water(x + 1.5, z) or W.is_water(x - 1.5, z) or W.is_water(x, z + 1.5) or W.is_water(x, z - 1.5)
			if near_water and not (roll < 0.35 and not W.is_water(x, z)): continue
			W.land_at(x, z); var lid := W.L_id
			var LT = LAND_TABLES.get(lid) if lid != "home" else null
			var type
			if near_water: type = "clay"
			else:
				var table: Array
				if LT != null: table = LT.get(region, LT.get("any", LT.get("forest")))
				else: table = TABLES[region]
				type = _pick(roll, table)
			if type == null: continue
			var scale: float
			if type == "clay": scale = 0.8 + s * 0.5
			elif type == "rock": scale = 0.75 + s * 0.7
			elif type == "bush" or type == "flowers": scale = 0.75 + s * 0.45
			elif type == "grass": scale = 0.6 + s * 0.6
			else: scale = 0.85 + s * 0.45
			var y := W.get_height(x, z)
			if absf(W.get_height(x + 0.8, z) - y) + absf(W.get_height(x, z + 0.8) - y) > 0.7: continue
			var p := {"type": type, "x": x, "z": z, "y": y, "lx": lx, "lz": lz, "rot": rot, "scale": scale, "lean": lean}
			if lid != "home" and PROP_TINT.has(lid) and PROP_TINT[lid].has(type): p.tint = PROP_TINT[lid][type]
			list.append(p)
		gz += spacing
		if Time.get_ticks_usec() - _t0 > budget_us: await (Engine.get_main_loop() as SceneTree).process_frame; _t0 = Time.get_ticks_usec()
	# hills & peaks: no longer placed (the mountains are real terrain), but their draws stay in the stream
	gz = 0.0
	while gz < CHUNK:
		var gx := 0.0
		while gx < CHUNK:
			rng.next(); rng.next()
			gx += 11.0
		gz += 11.0
		if Time.get_ticks_usec() - _t0 > budget_us: await (Engine.get_main_loop() as SceneTree).process_frame; _t0 = Time.get_ticks_usec()
	# pond life (own seed): cattails on the banks, lily pads in the shallows, a beaver lodge out in open water
	var prng := PNoise.Mulberry32.new(PNoise.hash2(cx, cz, Terrain.SEED + 29))
	var lodged := false
	gz = 0.0
	while gz < CHUNK:
		var gx := 0.0
		while gx < CHUNK:
			var lx := gx + prng.next() * 2.2; var lz := gz + prng.next() * 2.2; var roll := prng.next(); var s := prng.next(); var rot := prng.next() * PI * 2.0
			gx += 2.2
			var x := cx * CHUNK + lx; var z := cz * CHUNK + lz
			if blocked.call(x, z): continue
			var h := W.get_height(x, z)
			var shore := func(d: float) -> bool: return W.get_height(x + d, z) > 0.32 or W.get_height(x - d, z) > 0.32 or W.get_height(x, z + d) > 0.32 or W.get_height(x, z - d) > 0.32
			var open_all := func() -> bool:
				for k in 8:
					if not W.is_water(x + cos(k * 0.785) * 2.8, z + sin(k * 0.785) * 2.8): return false
				return true
			if not lodged and h < 0.1 and roll > 0.9 and shore.call(6.0) and open_all.call():
				lodged = true
				list.append({"type": "lodge", "x": x, "z": z, "y": -0.18, "lx": lx, "lz": lz, "rot": rot, "scale": 0.95 + s * 0.3, "lean": 0.0})
				colliders.append({"x": x, "z": z, "r": 1.3})
			elif h > 0.1 and h < 0.45 and roll < 0.16:
				var n := 2 + (1 if roll < 0.06 else 0)
				for k in n:
					var ox := (prng.next() - 0.5) * 1.1; var oz := (prng.next() - 0.5) * 1.1
					list.append({"type": "cattail", "x": x + ox, "z": z + oz, "y": W.get_height(x + ox, z + oz), "lx": lx + ox, "lz": lz + oz, "rot": rot + k * 1.1, "scale": 1.05 + prng.next() * 0.5, "lean": 0.0})
			elif h < 0.1 and roll < 0.32 and shore.call(5.5):
				list.append({"type": "lilybloom" if roll < 0.08 else "lilypad", "x": x, "z": z, "y": h + 0.03, "lx": lx, "lz": lz, "rot": rot, "scale": 0.75 + s * 0.55, "lean": 0.0})
		gz += 2.2
		if Time.get_ticks_usec() - _t0 > budget_us: await (Engine.get_main_loop() as SceneTree).process_frame; _t0 = Time.get_ticks_usec()
	# the wild woods floor: now and then a fallen log (own seed)
	var wrng := PNoise.Mulberry32.new(PNoise.hash2(cx, cz, Terrain.SEED + 53))
	gz = 0.0
	while gz < CHUNK:
		var gx := 0.0
		while gx < CHUNK:
			var lx := gx + 1.0 + wrng.next() * 6.0; var lz := gz + 1.0 + wrng.next() * 6.0; var roll := wrng.next(); var rot := wrng.next() * PI * 2.0; var s := wrng.next()
			gx += 8.0
			var x := cx * CHUNK + lx; var z := cz * CHUNK + lz
			if roll > 0.22 or W.region_at(x, z) != "forest" or blocked.call(x, z, 1.6) or W.path_field(x, z) < 0.1 or W.is_water(x, z): continue
			list.append({"type": "log", "x": x, "z": z, "y": W.get_height(x, z), "lx": lx, "lz": lz, "rot": rot, "scale": 0.95 + s * 0.4, "lean": 0.0})
			for k in [-0.8, 0.0, 0.8]: colliders.append({"x": x + cos(rot) * k * (0.95 + s * 0.4), "z": z - sin(rot) * k * (0.95 + s * 0.4), "r": 0.45})
		gz += 8.0
		if Time.get_ticks_usec() - _t0 > budget_us: await (Engine.get_main_loop() as SceneTree).process_frame; _t0 = Time.get_ticks_usec()
	# field dressing: round bales on the mown hay, wheat stooked in short rows (own seed)
	var frng := PNoise.Mulberry32.new(PNoise.hash2(cx, cz, Terrain.SEED + 41))
	gz = 0.0
	while gz < CHUNK:
		var gx := 0.0
		while gx < CHUNK:
			var lx := gx + frng.next() * 4.5; var lz := gz + frng.next() * 4.5; var roll := frng.next(); var rot := frng.next() * PI * 2.0; var s := frng.next()
			gx += 4.5
			var x := cx * CHUNK + lx; var z := cz * CHUNK + lz
			if roll > 0.3 or W.region_at(x, z) != "field" or W.field_mask(x, z) < 0.62 or blocked.call(x, z, 1.0) or W.path_field(x, z) < 0.08: continue
			var kind := field_kind_at(x, z)
			if kind == "hay" and roll < 0.12:
				list.append({"type": "bale", "x": x, "z": z, "y": W.get_height(x, z), "lx": lx, "lz": lz, "rot": rot, "scale": 1.25 + s * 0.3, "lean": 0.0})
				colliders.append({"x": x, "z": z, "r": 0.7})
			elif kind == "wheat":
				for k in 2 + (1 if roll < 0.15 else 0):
					var sx := x + cos(rot) * k * 1.3; var sz := z + sin(rot) * k * 1.3
					if floori(sx / CHUNK) != cx or floori(sz / CHUNK) != cz or field_kind_at(sx, sz) != "wheat": continue
					list.append({"type": "stook", "x": sx, "z": sz, "y": W.get_height(sx, sz), "lx": sx - cx * CHUNK, "lz": sz - cz * CHUNK, "rot": rot + k * 0.9, "scale": 1.45 + s * 0.35, "lean": (s - 0.5) * 0.1})
		gz += 4.5
		if Time.get_ticks_usec() - _t0 > budget_us: await (Engine.get_main_loop() as SceneTree).process_frame; _t0 = Time.get_ticks_usec()
	# old orchards (own seed)
	var orng := PNoise.Mulberry32.new(PNoise.hash2(cx, cz, Terrain.SEED + 31))
	var ox := cx * CHUNK + 6 + orng.next() * 20.0; var oz := cz * CHUNK + 6 + orng.next() * 20.0
	if orng.next() < 0.3 and W.region_at(ox, oz) == "meadow" and not blocked.call(ox, oz, 6.0):
		var yaw := orng.next() * PI
		for i in range(-1, 2):
			for j in range(-1, 2):
				if orng.next() < 0.25: continue
				var gx := i * 5.5 + (orng.next() - 0.5) * 1.2; var gz2 := j * 5.5 + (orng.next() - 0.5) * 1.2
				var x := ox + gx * cos(yaw) - gz2 * sin(yaw); var z := oz + gx * sin(yaw) + gz2 * cos(yaw)
				if floori(x / CHUNK) != cx or floori(z / CHUNK) != cz or W.is_water(x, z) or blocked.call(x, z) or W.path_field(x, z) < 0.05: continue
				_clear(list, x, z, 6.5)
				list.append({"type": "appletree", "x": x, "z": z, "y": W.get_height(x, z), "lx": x - cx * CHUNK, "lz": z - cz * CHUNK, "rot": orng.next() * 6.28, "scale": 0.85 + orng.next() * 0.3, "lean": (orng.next() - 0.5) * 0.06})
				var a := orng.next() * PI * 2.0; var hx := x + cos(a) * 1.5; var hz := z + sin(a) * 1.5
				if floori(hx / CHUNK) == cx and floori(hz / CHUNK) == cz and not W.is_water(hx, hz):
					list.append({"type": "apples", "x": hx, "z": hz, "y": W.get_height(hx, hz), "lx": hx - cx * CHUNK, "lz": hz - cz * CHUNK, "rot": orng.next() * 6.28, "scale": 1.3 + orng.next() * 0.3, "lean": 0.0})
	# a lost satchel, now and then, far out (own seed)
	var srng := PNoise.Mulberry32.new(PNoise.hash2(cx, cz, Terrain.SEED + 37))
	var sx0 := cx * CHUNK + 4 + srng.next() * 24.0; var sz0 := cz * CHUNK + 4 + srng.next() * 24.0
	var far: bool = W.flat == null or Vector2(sx0 - W.flat[0], sz0 - W.flat[1]).length() > 60.0
	if srng.next() < 0.07 and far and not W.is_water(sx0, sz0) and not blocked.call(sx0, sz0, 2.0) and W.region_at(sx0, sz0) != "peak" and W.range_at(sx0, sz0) < 0.01:
		_clear(list, sx0, sz0, 4.0)
		list.append({"type": "satchel", "x": sx0, "z": sz0, "y": W.get_height(sx0, sz0), "lx": sx0 - cx * CHUNK, "lz": sz0 - cz * CHUNK, "rot": srng.next() * 6.28, "scale": 1.2, "lean": 0.0})
	# the kitchen garden (corn and pumpkins in rows)
	if garden != null:
		for row in garden.rows:
			var step := 1.0 if row.type == "corn" else 1.5
			var x: float = garden.x0
			while x <= garden.x1 + 0.01:
				if floori(x / CHUNK) == cx and floori(row.z / CHUNK) == cz:
					var jx := x + (rng.next() - 0.5) * 0.25; var jz: float = row.z + (rng.next() - 0.5) * 0.2
					list.append({"type": row.type, "x": jx, "z": jz, "y": W.get_height(jx, jz) + 0.02, "lx": jx - cx * CHUNK, "lz": jz - cz * CHUNK,
						"rot": 0.25 + rng.next() * 0.4, "scale": (1.15 + rng.next() * 0.2) if row.type == "corn" else (0.75 + rng.next() * 0.25), "lean": 0.0})
				x += step
	# a landmark here?
	var lm = null
	for U in unique_encounters():
		if U.cx == cx and U.cz == cz:
			_clear(list, U.x, U.z, 70.0)
			colliders.append_array(landmark_colliders.call(U.mark, U.x, U.z, U.rot))
			lm = {"key": "%d,%d,landmark" % [cx, cz], "kind": "landmark", "mark": U.mark, "land": U.land, "x": U.x, "y": maxf(0.0, W.get_height(U.x, U.z)), "z": U.z, "rot": U.rot, "guards": 0}
			break
	# guarded sites
	var sites := [lm] if lm != null else []
	var sx := cx * CHUNK + 8 + rng.next() * 16.0; var sz := cz * CHUNK + 8 + rng.next() * 16.0
	var sroll := rng.next()
	var far_from_farm: bool = W.flat == null or Vector2(sx - W.flat[0], sz - W.flat[1]).length() > 55.0
	var sreg := W.region_at(sx, sz)
	W.land_at(sx, sz); var sland := W.L_id
	var LS = LAND_SITES.get(sland) if sland != "home" else null
	var fen_ok := true
	if LS != null and LS.kind == "pearl":
		fen_ok = false
		for k in 6: fen_ok = fen_ok or W.is_water(sx + cos(k) * 4.0, sz + sin(k) * 4.0)
	var site_kind := ""
	if far_from_farm:
		if LS != null:
			if sroll < 0.22 and sreg != "water" and fen_ok: site_kind = LS.kind
			elif (sreg == "highland" or sreg == "peak") and sroll < 0.32: site_kind = "vein"
		elif (sreg == "highland" or sreg == "peak") and sroll < 0.4: site_kind = "vein"
		elif sreg == "forest" and sroll < 0.3: site_kind = "grove"
		elif sreg == "meadow" and sroll < 0.2: site_kind = "thicket"
	if site_kind != "" and W.range_at(sx, sz) < 0.08 and not blocked.call(sx, sz, 6.0) and not (lm != null and Vector2(sx - lm.x, sz - lm.z).length() < 18.0):
		var sy := W.get_height(sx, sz)
		_clear(list, sx, sz, 36.0)
		var ring := func(type: String, n: int, r0: float, r1: float, scale: float) -> void:
			for i in n:
				var a := (float(i) / n) * PI * 2.0 + rng.next() * 0.6; var d := r0 + rng.next() * (r1 - r0); var rot := rng.next() * 6.28; var sc := 0.9 + rng.next() * 0.3
				var x := sx + cos(a) * d; var z := sz + sin(a) * d
				if W.is_water(x, z) and type != "pearl": continue
				if type == "pearl" and W.get_height(x, z) > 0.6: continue
				var p := {"type": type, "x": x, "z": z, "y": maxf(0.02, W.get_height(x, z)), "lx": x - cx * CHUNK, "lz": z - cz * CHUNK, "rot": rot, "scale": scale * sc, "lean": 0.0}
				if PROP_TINT.has(sland) and PROP_TINT[sland].has(type): p.tint = PROP_TINT[sland][type]
				list.append(p)
		if LS != null and site_kind == LS.kind:
			var n: int = {"sang": 6, "silver": 5, "pearl": 7, "geode": 5, "amber": 5}[site_kind]
			ring.call(site_kind, n, 1.4, 5.0, 1.45 if site_kind == "sang" else 1.0)
			if site_kind == "amber": ring.call("pine", 4, 5.0, 7.0, 1.1)
			if site_kind == "silver": ring.call("rock", 4, 4.0, 6.5, 1.0)
			sites.append({"key": "%d,%d,site" % [cx, cz], "kind": site_kind, "land": sland, "guard": LS.guard, "x": sx, "y": sy, "z": sz, "guards": LS.guards})
			return {"list": list, "colliders": colliders, "sites": sites}
		if site_kind == "vein": ring.call("ore", 7, 2.2, 5.5, 1.0); ring.call("rock", 3, 4.0, 6.0, 0.9)
		elif site_kind == "grove": ring.call("hive", 3, 1.2, 2.8, 1.0); ring.call("mushroom", 6, 3.0, 6.0, 0.9)
		else: ring.call("bush", 8, 1.2, 5.0, 1.1); ring.call("mushroom", 3, 3.0, 5.5, 0.9); ring.call("apples", 2, 2.0, 4.0, 1.0)
		var home: float = atan2(W.flat[0] - sx, W.flat[1] - sz) if W.flat != null else rng.next() * 6.28
		for da in [0.0, 0.6, -0.6, 1.2, -1.2, PI]:
			var a: float = home + da; var x := sx + sin(a) * 7.5; var z := sz + cos(a) * 7.5
			if W.is_water(x, z) or blocked.call(x, z, 1.0): continue
			for i in range(list.size() - 1, -1, -1):
				var q: Dictionary = list[i]
				if (q.x - x) * (q.x - x) + (q.z - z) * (q.z - z) < 7.0 and q.type != "hive": list.remove_at(i)
			var sign_type := "signvein" if site_kind == "vein" else ("signthicket" if site_kind == "thicket" else "signgrove")
			list.append({"type": sign_type, "x": x, "z": z, "y": W.get_height(x, z), "lx": x - cx * CHUNK, "lz": z - cz * CHUNK, "rot": a + (rng.next() - 0.5) * 0.3, "scale": 1.45, "lean": 0.0})
			break
		sites.append({"key": "%d,%d,site" % [cx, cz], "kind": site_kind, "x": sx, "y": sy, "z": sz, "guards": 3 if site_kind == "vein" else (2 if site_kind == "thicket" else 1)})
	return {"list": list, "colliders": colliders, "sites": sites}


## Props.place, spread over frames (await it): the same layout and caching, no more than budget_us a frame.
static func place_sliced(cx: int, cz: int, exclusions: Array, budget_us: int) -> Dictionary:
	var out: Dictionary = await _place_co(cx, cz, exclusions, budget_us)
	_last_exclusions = exclusions
	return _finish(cx, cz, out)
