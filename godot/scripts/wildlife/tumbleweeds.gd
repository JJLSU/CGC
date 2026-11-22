class_name Tumbleweeds
extends Node3D
## tumbleweed.js: on dry days in town and out in the Redrock Breaks, now and then a ball of dry brush comes bowling
## down the wind (out of the west), hopping and spinning, and rolls on past you. Five ragged discs of pale straw card
## slotted through each other; never more than two about, none in the rain or away from the dry country.

const MAX := 2

var list: Array = []
var wait := 8.0
var geos: Array = []
var mats: Array = []

static func ball_mesh(seed: int) -> ArrayMesh:
	var s := seed
	var rnd := func() -> float:
		s = (s * 16807) % 2147483647
		return float(s) / 2147483647.0
	var disc := func() -> ArrayMesh: # a ragged round of brush: chunky lobes, a few deeper notches, never thin spikes
		var pts := PackedVector2Array()
		for i in 22:
			var a := (i / 22.0) * TAU
			var r: float = 0.5 * ((0.78 + rnd.call() * 0.12) if i % 2 else (0.95 + rnd.call() * 0.12))
			pts.append(Vector2(cos(a) * r, sin(a) * r))
		return CardMesh.build(pts, 0.03)
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var xforms := [Basis(), Basis(Vector3.UP, PI / 3.0), Basis(Vector3.UP, 2.0 * PI / 3.0), Basis(Vector3.RIGHT, PI / 2.0), Basis(Vector3.UP, PI / 6.0) * Basis(Vector3.RIGHT, PI / 4.0)]
	for b in xforms: st.append_from(disc.call(), 0, Transform3D(b, Vector3.ZERO))
	return st.commit()

func _init() -> void:
	geos = [ball_mesh(7), ball_mesh(31), ball_mesh(97)]
	mats = [PaperMats.paper(Color.hex(0xd2b47cff)), PaperMats.paper(Color.hex(0xc4a468ff))]

## Is (x, z) tumbleweed country: the Redrock Breaks? (main adds the town)
static func dry_at(x: float, z: float) -> bool:
	Terrain.land_at(x, z)
	return Terrain.L_w.breaks > 0.5

## dry: is it dry country here (town or the Breaks), with no rain?
func update(dt: float, player: Player, dry: bool, colliders: Array = []) -> void:
	wait -= dt
	if dry and wait <= 0.0 and list.size() < MAX:
		wait = 18.0 + randf() * 25.0
		var x := player.pos.x - 26.0 - randf() * 6.0; var z := player.pos.z + (randf() - 0.5) * 22.0
		if not Terrain.is_water(x, z):
			var r := 0.45 + randf() * 0.25
			var mesh := MeshInstance3D.new(); mesh.mesh = geos[randi() % 3]; mesh.material_override = mats[randi() % 2]
			mesh.rotation_order = EULER_ORDER_XYZ
			mesh.scale = Vector3.ONE * r * 2.0; mesh.rotation = Vector3(randf() * 6.0, randf() * 6.0, 0)
			add_child(mesh)
			list.append({"mesh": mesh, "r": r, "x": x, "z": z, "v": 2.6 + randf() * 1.6, "t": randf() * 5.0, "drift": (randf() - 0.5) * 0.4, "hop": 0.9 + randf() * 0.6})
	for i in range(list.size() - 1, -1, -1):
		var w: Dictionary = list[i]
		w.t += dt
		var gust: float = 0.75 + 0.35 * sin(w.t * 0.9 + w.r * 9.0) # (it slows, then the wind catches it again)
		w.drift *= 1.0 - dt * 0.4 # (a shove off a wall dies away)
		w.x += w.v * gust * dt; w.z += (w.drift + sin(w.t * 0.6) * 0.25) * dt
		# it fetches up against walls, posts and tents and is shoved round them, never through
		for c in colliders:
			var dx: float = w.x - c.x; var dz: float = w.z - c.z; var rr: float = c.r + w.r * 0.8; var d2 := dx * dx + dz * dz
			if d2 < rr * rr and d2 > 1e-6:
				var d := sqrt(d2); w.x = c.x + (dx / d) * rr; w.z = c.z + (dz / d) * rr; w.drift = (signf(dz) if dz != 0.0 else 1.0) * 0.9
		var hop: float = absf(sin(w.t * w.hop * 2.2)) * 0.45 * gust # (bouncing along on its twigs)
		var mesh: MeshInstance3D = w.mesh
		mesh.position = Vector3(w.x, Terrain.get_height(w.x, w.z) + w.r + hop, w.z)
		mesh.rotation.z -= (w.v * gust * dt) / w.r; mesh.rotation.x += w.drift * dt
		if w.x > player.pos.x + 34.0 or absf(w.z - player.pos.z) > 40.0 or Terrain.is_water(w.x, w.z):
			mesh.queue_free(); list.remove_at(i)
