class_name Rumours
extends RefCounted
## rumour.js: word around the county. With no journal goal pressing (the goals are retired, so always), the talk is of
## the nearest wild-land landmark you haven't seen yet: a small torn note under the NEXT card says what folks tell
## of it and how many paces off, with an inked arrow pointing the way on screen. Sites are found by quietly laying
## out nearby chunks, one a frame.

const WANTS := {"ore": "vein", "iron": "vein", "ironaxe": "vein", "honey": "grove", "cake": "grove", "slay": "guarded", "legend": "guarded", "coat": "guarded"}
const TALES := {
	"vein": "Folks say dust-devil coyotes keep an iron vein",
	"grove": "They tell of an old boar watching a wild-hive grove",
	"thicket": "They tell of coyotes lying up in a berry thicket out in the meadow",
	"arch": "Prospectors tell of a great stone arch out in the red rock",
	"steamboat": "Old-timers tell of a riverboat sunk to her rails in the fen",
	"lookout": "They say there's a fire lookout in the high pines, with a view for miles",
	"schooner": "A drover tells of a lost wagon somewhere out on the prairie",
	"birch": "Grandmothers tell of a birch older than the county, deep in the Hollows",
	"babe": "Lumberjacks swear Babe the Blue Ox still grazes up in the high pines, partial to apples",
	"hermit": "They say an old hermit lives deep in the Hollows, and knows every strange corner of the county",
}
const RADIUS := 10

var world: World
var found := {}     ## site key -> site
var order: Array = []
var cursor := 0
var center := ""
var tick := 0

func _init(w: World) -> void:
	world = w
	for r in RADIUS + 1:
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dz)) == r: order.append(Vector2i(dx, dz))

func guarded(site: Dictionary) -> bool:
	for i in int(site.get("guards", 0)): if not world.destroyed.has("%s:g%d" % [site.key, i]): return true
	return false

## The note to show: {text, paces, dir (a world direction, unit)} or null.
func update(pos: Vector3, goals: Array, visited: Callable):
	var want := "landmark"
	for g in goals: if WANTS.has(g.id): want = WANTS[g.id]; break
	# scan outward from the player's chunk, one chunk a frame
	var pcx := floori(pos.x / Terrain.CHUNK); var pcz := floori(pos.z / Terrain.CHUNK)
	var c := "%d,%d" % [pcx, pcz]
	if c != center: center = c; cursor = 0
	# (the landmarks are placed once per world, so they're read straight off unique_encounters: laying a chunk out
	# costs 30-90 ms in GDScript, so the guarded sites the old goal-led talk needed would cost a frame each)
	if want == "landmark":
		for U in Props.unique_encounters():
			if absi(U.cx - pcx) > RADIUS or absi(U.cz - pcz) > RADIUS: continue
			var key := "%d,%d,landmark" % [U.cx, U.cz]
			if not found.has(key): found[key] = {"key": key, "kind": "landmark", "mark": U.mark, "land": U.land, "x": U.x, "z": U.z, "guards": 0}
	else:
		tick += 1
		while cursor < order.size():
			var d: Vector2i = order[cursor]
			var cached := Props.site_cache.has("%d,%d" % [pcx + d.x, pcz + d.y])
			if not cached and tick % 3 != 0: break
			cursor += 1
			for s in Props.sites_for(pcx + d.x, pcz + d.y, world.exclusions).sites: found[s.key] = s
			if not cached: break
	var best = null; var bd := INF
	for s in found.values():
		if (not guarded(s)) if want == "guarded" else (s.kind != want): continue
		if want == "landmark" and visited.call(s.key): continue
		var dd := Vector2(s.x - pos.x, s.z - pos.z).length()
		if dd < bd: bd = dd; best = s
	if best == null or bd < 14.0: return null
	return {"text": TALES.get(best.mark if best.kind == "landmark" else best.kind, ""), "paces": maxi(10, roundi(bd * 1.3 / 10.0) * 10), "dir": Vector3((best.x - pos.x) / bd, 0, (best.z - pos.z) / bd), "key": best.key}
