class_name LeafPiles
extends Node3D
## leafpiles.js: four heaps of die-cut autumn leaves raked up round the yard. Run through one (or let Old Blue barrel
## into it) and the leaves burst up, flutter and spin down, lying scattered where they land; after a while the breeze
## sweeps them back into a heap, one by one. One MultiMesh, written only while leaves are on the move.

const PER := 46
const COLS := [0xe08a3a, 0xc8552f, 0xd9a441, 0xb8452e, 0xe6b45a, 0xa8642e]
const LEAF := [[0, -0.02], [0.03, 0.04], [0.12, 0.02], [0.09, 0.08], [0.14, 0.13], [0.07, 0.13], [0.06, 0.2], [0, 0.15], [-0.06, 0.2], [-0.07, 0.13], [-0.14, 0.13], [-0.09, 0.08], [-0.12, 0.02], [-0.03, 0.04]]

var spots: Array = []
var leaves: Array = []
var mm := MultiMesh.new()
var moving := 0
var cool: Array = []
var on_kick: Callable

func _init(center: Vector3) -> void:
	for o in [[-2.4, 3.2], [5.2, 3.8], [8.6, -1.4], [-5.4, 1.2]]:
		var v := Vector3(center.x + o[0], 0, center.z + o[1]); v.y = Terrain.get_height(v.x, v.z); spots.append(v); cool.append(0.0)
	var card := Town.card(LEAF, "res://assets/baked/wildlife/leafpile", 0.006, 0.0)
	mm.transform_format = MultiMesh.TRANSFORM_3D; mm.use_colors = true; mm.mesh = Footprints._flat(card.mesh); mm.instance_count = PER * spots.size()
	var mi := MultiMeshInstance3D.new(); mi.multimesh = mm; mi.material_override = card.material_override; add_child(mi)
	var rng := PNoise.Mulberry32.new(243)
	for pi in spots.size():
		var s: Vector3 = spots[pi]
		for i in PER:
			# stacked into a dome: more leaves low and wide, fewer up top
			var h := pow(rng.next(), 1.6); var r := (1.0 - h * 0.8) * 0.95 * sqrt(rng.next()); var a := rng.next() * TAU
			var home := Vector3(s.x + cos(a) * r, s.y + 0.02 + h * 0.5, s.z + sin(a) * r)
			var L := {"pile": pi, "home": home, "pos": home, "vel": Vector3.ZERO, "rot": Vector3((rng.next() - 0.5) * 0.9, rng.next() * 6.28, (rng.next() - 0.5) * 0.9), "spin": Vector3.ZERO, "state": "heap", "t": 0.0, "scale": 1.6 + rng.next() * 0.8}
			leaves.append(L)
			mm.set_instance_color(leaves.size() - 1, Color.hex((int(COLS[floori(rng.next() * COLS.size())]) << 8) | 0xff))
			_write(leaves.size() - 1)

func _write(i: int) -> void:
	var L: Dictionary = leaves[i]
	mm.set_instance_transform(i, Transform3D(Basis.from_euler(L.rot, EULER_ORDER_XYZ).scaled_local(Vector3.ONE * L.scale), L.pos))

## kickers: [{pos, speed}] (the farmer, Old Blue). Returns the pile kicked this frame, or -1.
func update(dt: float, kickers: Array) -> int:
	var kicked := -1
	for pi in spots.size():
		var s: Vector3 = spots[pi]
		cool[pi] = maxf(0.0, cool[pi] - dt)
		for k in kickers:
			if k.speed < 1.2 or cool[pi] > 0.0: continue
			if Vector2(k.pos.x - s.x, k.pos.z - s.z).length() > 1.1: continue
			# whoosh: every leaf of the heap still near it bursts up and away from whoever ran through
			cool[pi] = 1.5; kicked = pi
			for L in leaves:
				if L.pile != pi or Vector2(L.pos.x - s.x, L.pos.z - s.z).length() > 1.4: continue
				var ax: float = L.pos.x - k.pos.x; var az: float = L.pos.z - k.pos.z; var al := maxf(0.0001, sqrt(ax * ax + az * az))
				var f := 1.2 + randf() * 2.2
				L.vel = Vector3(ax / al * f + (randf() - 0.5), 2.2 + randf() * 3.2, az / al * f + (randf() - 0.5))
				L.spin = Vector3((randf() - 0.5) * 12, (randf() - 0.5) * 8, (randf() - 0.5) * 12)
				L.state = "fly"; L.t = 0.0
	if kicked >= 0 and on_kick.is_valid(): on_kick.call(kicked)
	# fluttering down, lying still a while, then swept home by the breeze
	var n := 0
	for i in leaves.size():
		var L: Dictionary = leaves[i]
		if L.state == "heap": continue
		n += 1; L.t += dt
		if L.state == "fly":
			L.vel.y -= 6.0 * dt # (light paper: gravity is gentle, and air drags it)
			L.vel *= 1.0 - minf(1.0, dt * 1.6)
			if L.vel.y < -1.2: L.vel.y = -1.2 + sin(L.t * 6 + i) * 0.3 # (a falling leaf flutters)
			L.pos += L.vel * dt; L.pos.x += sin(L.t * 4 + i) * 0.4 * dt
			L.rot += L.spin * dt
			var g := Terrain.get_height(L.pos.x, L.pos.z) + 0.02
			if L.pos.y <= g and L.vel.y < 0:
				L.pos.y = g; L.state = "lie"; L.t = 0.0; L.rot.x = (randf() - 0.5) * 0.2; L.rot.z = (randf() - 0.5) * 0.2
		elif L.state == "lie":
			if L.t > 25.0 + (i % 17): L.state = "home"; L.t = 0.0
		elif L.state == "home": # skitters back over the grass, a hop at a time
			var to: Vector3 = L.home - L.pos; var d := to.length()
			if d < 0.05: L.pos = L.home; L.state = "heap"
			else:
				L.pos += to.normalized() * minf(d, dt * 0.6)
				L.pos.y = maxf(Terrain.get_height(L.pos.x, L.pos.z) + 0.02, L.pos.y) + absf(sin(L.t * 5 + i)) * 0.004
				L.rot.y += dt * 0.8
		_write(i)
	moving = n
	return kicked
