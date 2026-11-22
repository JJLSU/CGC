class_name Climbs
extends RefCounted
## climb.js: climbable structures register decks you can stand and walk on (flat, or following a curve like the top of
## the stone arch) and ladders (or scrambles) between the ground and a deck. E at the foot climbs; E at its head on
## the deck climbs down. Railed decks keep you on them; open ones you can walk off and drop to the ground below.
## A deck's curved top is named (y_at): "arch" (the middle flat's crest), "boat_deck", "boat_roof" (the Belle, sunk
## and listing).

var sets := {}

static func y_at(kind: String, lx: float) -> float:
	match kind:
		"arch": return 4.2 + 2.3 * sqrt(maxf(0.0, 1.0 - (lx / 4.6) ** 2))
		"boat_deck": return 1.18 + 0.09 * lx
		"boat_roof": return 2.76 + 0.09 * lx
	return 0.0

## spec: {decks: [{x, z, hw, hd, y, y_at?, rail?}], ladders: [{foot, via?, top, land, name}]} in local metres.
func add(key: String, x: float, y: float, z: float, rot: float, spec: Dictionary) -> void:
	var c := cos(rot); var s := sin(rot)
	var w := func(lx: float, ly: float, lz: float) -> Vector3: return Vector3(x + lx * c + lz * s, y + ly, z - lx * s + lz * c)
	var st := {"x": x, "z": z, "c": c, "s": s, "y": y, "decks": spec.get("decks", []), "ladders": []}
	for L in spec.get("ladders", []):
		var foot: Vector3 = w.call(L.foot[0], L.foot[1], L.foot[2]); var top: Vector3 = w.call(L.top[0], L.top[1], L.top[2])
		var land: Vector3 = w.call(L.land[0], L.top[1], L.land[1])
		var via := []
		for p in L.get("via", []): via.append(w.call(p[0], p[1], p[2]))
		var first: Vector3 = via[0] if via.size() else top
		st.ladders.append({"foot": foot, "via": via, "top": top, "land": land, "name": L.name, "face": atan2(top.x - first.x, top.z - first.z)})
	sets[key] = st
func remove(key: String) -> void: sets.erase(key)

## Each deck covering (x, z) with its surface height there: [[deck, set, top], ...].
func covering(x: float, z: float) -> Array:
	var out := []
	for st in sets.values():
		var dx: float = x - st.x; var dz: float = z - st.z
		if dx * dx + dz * dz > 400.0: continue
		var lx: float = dx * st.c - dz * st.s; var lz: float = dx * st.s + dz * st.c
		for d in st.decks:
			if absf(lx - d.x) > d.hw or absf(lz - d.z) > d.hd: continue
			out.append([d, st, st.y + (y_at(d.y_at, lx) if d.has("y_at") else d.y)])
	return out

## The highest deck surface under (x, z) you could step up onto from height y (or -INF).
func surface_at(x: float, z: float, y: float) -> float:
	var best := -INF
	for e in covering(x, z): if e[2] <= y + 0.65 and e[2] > best: best = e[2]
	return best

## The deck you're standing on: [deck, set, top] or null.
func standing(pos: Vector3):
	var out = null
	for e in covering(pos.x, pos.z): if absf(pos.y - e[2]) < 0.3 and (out == null or e[2] > out[2]): out = e
	return out

## Keep you on a railed deck you were standing on: step back if this step leaves it.
func keep_on(pos: Vector3, prev_x: float, prev_z: float, was) -> Vector3:
	if was == null or not was[0].get("rail", false): return pos
	for e in covering(pos.x, pos.z): if e[0] == was[0]: return pos
	return Vector3(prev_x, pos.y, prev_z)

## A ladder you can use from pos: {ladder, up} (at its foot on the ground, or at its head on the deck), or null.
func ladder_at(pos: Vector3):
	for st in sets.values():
		for L in st.ladders:
			if Vector2(pos.x - L.foot.x, pos.z - L.foot.z).length() < 1.4 and absf(pos.y - L.foot.y) < 1.6: return {"ladder": L, "up": true}
			if Vector2(pos.x - L.land.x, pos.z - L.land.z).length() < 1.2 and absf(pos.y - L.top.y) < 0.4: return {"ladder": L, "up": false}
	return null

## The path for a climb: its points, length and how long it takes.
func path(hit: Dictionary, pos: Vector3) -> Dictionary:
	var L: Dictionary = hit.ladder
	var via: Array = L.via.duplicate()
	var pts: Array
	if hit.up: pts = [pos, L.foot] + via + [L.top, L.land]
	else:
		via.reverse(); pts = [pos, L.top] + via + [L.foot]
	var length := 0.0
	for i in range(1, pts.size()): length += (pts[i] as Vector3).distance_to(pts[i - 1])
	return {"pts": pts, "len": length, "dur": maxf(1.2, length / (2.4 if hit.up else 3.2)), "face": L.face, "t": 0.0}

## Where a point is along a path of segments, k in 0..1 of its length.
static func along_path(pts: Array, length: float, k: float) -> Vector3:
	var d := k * length
	for i in range(1, pts.size()):
		var seg := (pts[i] as Vector3).distance_to(pts[i - 1])
		if d <= seg or i == pts.size() - 1: return (pts[i - 1] as Vector3).lerp(pts[i], minf(1.0, d / seg) if seg > 0.0 else 1.0)
		d -= seg
	return pts[pts.size() - 1]
